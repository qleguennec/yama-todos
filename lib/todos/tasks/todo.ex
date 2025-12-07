defmodule Todos.Tasks.Todo do
  use Ash.Resource,
    otp_app: :todos,
    domain: Todos.Tasks,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStateMachine, AshArchival.Resource],
    notifiers: [Todos.Tasks.TodoNotifier]

  @doc """
  Todo states:
  - inbox: Quick capture, needs organizing
  - pending: Organized, ready to work on
  - in_progress: Actively working on
  - waiting: Blocked on something/someone
  - done: Completed
  - cancelled: Abandoned
  """

  state_machine do
    initial_states [:inbox, :pending]
    default_initial_state :inbox

    transitions do
      # From inbox - organize or start directly
      transition :organize, from: :inbox, to: :pending
      transition :start, from: [:inbox, :pending], to: :in_progress

      # From in_progress
      transition :pause, from: :in_progress, to: :pending
      transition :wait, from: :in_progress, to: :waiting
      transition :complete, from: [:in_progress, :pending], to: :done

      # From waiting
      transition :resume, from: :waiting, to: :in_progress
      transition :unblock, from: :waiting, to: :pending

      # Cancel from any active state
      transition :cancel, from: [:inbox, :pending, :in_progress, :waiting], to: :cancelled

      # Reopen from terminal states
      transition :reopen, from: [:done, :cancelled], to: :pending
    end
  end

  archive do
    archive_related [:subtasks]
  end

  postgres do
    table "todos"
    repo Todos.Repo

    custom_indexes do
      index [:user_id]
      index [:state]
      index [:due_date]
    end
  end

  actions do
    defaults [:read, :destroy]

    # Add a subtask to this todo (used by courses quick action)
    update :add_subtask do
      require_atomic? false
      argument :subtask_title, :string, allow_nil?: false

      change {Todos.Tasks.Todo.Changes.AddSubtask, []}
    end

    # Quick capture - minimal input, goes to inbox
    create :capture do
      accept [:title]

      argument :user_id, :uuid, allow_nil?: false

      change set_attribute(:user_id, arg(:user_id))
      change set_attribute(:state, :inbox)
    end

    # Full create with all fields
    create :create do
      accept [:title, :description, :priority, :due_date, :pinned_to_today, :waiting_on]

      argument :user_id, :uuid, allow_nil?: false
      argument :tag_ids, {:array, :uuid}, default: []
      argument :assignee_ids, {:array, :uuid}, default: []
      argument :initial_state, :atom, default: :pending

      change set_attribute(:user_id, arg(:user_id))
      change set_attribute(:state, arg(:initial_state))
      change manage_relationship(:tag_ids, :tags, type: :append_and_remove)
      change manage_relationship(:assignee_ids, :assignees, type: :append_and_remove)
    end

    update :update do
      require_atomic? false
      accept [:title, :description, :priority, :due_date, :pinned_to_today, :waiting_on]

      argument :tag_ids, {:array, :uuid}
      argument :assignee_ids, {:array, :uuid}

      change manage_relationship(:tag_ids, :tags, type: :append_and_remove)
      change manage_relationship(:assignee_ids, :assignees, type: :append_and_remove)
    end

    # State transitions
    update :organize do
      require_atomic? false
      accept [:title, :description, :priority, :due_date]

      argument :tag_ids, {:array, :uuid}, default: []

      change transition_state(:pending)
      change manage_relationship(:tag_ids, :tags, type: :append_and_remove)
    end

    update :start do
      require_atomic? false
      change {Todos.Tasks.Todo.Changes.SavePreviousState, []}
      change transition_state(:in_progress)
    end

    update :pause do
      require_atomic? false
      change {Todos.Tasks.Todo.Changes.SavePreviousState, []}
      change transition_state(:pending)
    end

    update :wait do
      require_atomic? false
      accept [:waiting_on]
      change {Todos.Tasks.Todo.Changes.SavePreviousState, []}
      change transition_state(:waiting)
    end

    update :resume do
      require_atomic? false
      change {Todos.Tasks.Todo.Changes.SavePreviousState, []}
      change transition_state(:in_progress)
      change set_attribute(:waiting_on, nil)
    end

    update :unblock do
      require_atomic? false
      change {Todos.Tasks.Todo.Changes.SavePreviousState, []}
      change transition_state(:pending)
      change set_attribute(:waiting_on, nil)
    end

    update :complete do
      require_atomic? false
      change {Todos.Tasks.Todo.Changes.SavePreviousState, []}
      change transition_state(:done)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      change relate_actor(:completed_by)
    end

    update :cancel do
      require_atomic? false
      change {Todos.Tasks.Todo.Changes.SavePreviousState, []}
      change transition_state(:cancelled)
    end

    update :reopen do
      require_atomic? false
      change {Todos.Tasks.Todo.Changes.SavePreviousState, []}
      change transition_state(:pending)
      change set_attribute(:completed_at, nil)
    end

    update :undo do
      require_atomic? false

      change fn changeset, _context ->
        previous = Ash.Changeset.get_data(changeset, :previous_state)

        if previous do
          changeset
          |> Ash.Changeset.force_change_attribute(:state, previous)
          |> Ash.Changeset.force_change_attribute(:previous_state, nil)
        else
          Ash.Changeset.add_error(changeset, field: :previous_state, message: "No previous state to undo to")
        end
      end
    end

    # Direct state change (bypasses state machine but saves previous state for undo)
    update :set_state do
      require_atomic? false
      accept [:state]

      change fn changeset, _context ->
        new_state = Ash.Changeset.get_attribute(changeset, :state)
        current_state = Ash.Changeset.get_data(changeset, :state)

        if new_state != current_state do
          Ash.Changeset.force_change_attribute(changeset, :previous_state, current_state)
        else
          changeset
        end
      end
    end

    # Pin/unpin to today view
    update :pin_to_today do
      change set_attribute(:pinned_to_today, true)
    end

    update :unpin_from_today do
      change set_attribute(:pinned_to_today, false)
    end

    # List actions
    read :list_all do
      prepare build(sort: [inserted_at: :desc])
    end

    read :inbox do
      filter expr(state == :inbox)
      prepare build(sort: [inserted_at: :desc])
    end

    read :today do
      filter expr(
               pinned_to_today == true or
                 (not is_nil(due_date) and due_date <= ^Date.utc_today())
             )

      prepare build(sort: [priority: :desc, due_date: :asc])
    end

    read :waiting do
      filter expr(state == :waiting)
      prepare build(sort: [updated_at: :desc])
    end

    read :by_state do
      argument :state, :atom, allow_nil?: false

      filter expr(state == ^arg(:state))
      prepare build(sort: [priority: :desc, inserted_at: :desc])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :description, :string do
      allow_nil? true
      public? true
    end

    attribute :state, :atom do
      allow_nil? false
      default :inbox
      constraints one_of: [:inbox, :pending, :in_progress, :waiting, :done, :cancelled]
      public? true
    end

    attribute :priority, :atom do
      allow_nil? true
      default :medium
      constraints one_of: [:low, :medium, :high, :urgent]
      public? true
    end

    attribute :due_date, :date do
      allow_nil? true
      public? true
    end

    attribute :completed_at, :utc_datetime do
      allow_nil? true
      public? true
    end

    attribute :pinned_to_today, :boolean do
      allow_nil? false
      default false
      public? true
    end

    attribute :waiting_on, :string do
      allow_nil? true
      public? true
      description "Who/what this todo is waiting on"
    end

    attribute :previous_state, :atom do
      allow_nil? true
      constraints one_of: [:inbox, :pending, :in_progress, :waiting, :done, :cancelled]
      public? true
      description "Previous state for undo functionality"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Todos.Accounts.User do
      allow_nil? false
    end

    has_many :subtasks, Todos.Tasks.Subtask do
      destination_attribute :todo_id
    end

    many_to_many :tags, Todos.Tasks.Tag do
      through Todos.Tasks.TodoTag
      source_attribute_on_join_resource :todo_id
      destination_attribute_on_join_resource :tag_id
    end

    many_to_many :assignees, Todos.Accounts.User do
      through Todos.Tasks.TodoAssignee
      source_attribute_on_join_resource :todo_id
      destination_attribute_on_join_resource :user_id
    end

    belongs_to :recurring_pattern, Todos.Tasks.RecurringPattern do
      allow_nil? true
    end

    belongs_to :completed_by, Todos.Accounts.User do
      allow_nil? true
    end
  end

  calculations do
    calculate :overdue?,
              :boolean,
              expr(
                not is_nil(due_date) and
                  due_date < ^Date.utc_today() and
                  state not in [:done, :cancelled]
              )

    calculate :subtasks_completed,
              :integer,
              expr(count(subtasks, query: [filter: expr(completed == true)]))

    calculate :subtasks_total, :integer, expr(count(subtasks))

    calculate :progress_percent,
              :integer,
              expr(
                if subtasks_total > 0 do
                  fragment("ROUND(? * 100.0 / ?)", subtasks_completed, subtasks_total)
                else
                  if state == :done, do: 100, else: 0
                end
              )
  end
end
