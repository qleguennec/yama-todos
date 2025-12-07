defmodule Todos.Tasks.RecurringPattern do
  use Ash.Resource,
    otp_app: :todos,
    domain: Todos.Tasks,
    data_layer: AshPostgres.DataLayer

  @doc """
  Defines recurring patterns for todos.

  Frequency types:
  - daily: Every N days
  - weekly: Specific days of the week
  - monthly: Specific day of month
  - yearly: Specific date each year
  """

  postgres do
    table "recurring_patterns"
    repo Todos.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:frequency, :interval, :days_of_week, :day_of_month, :ends_at]
    end

    update :update do
      accept [:frequency, :interval, :days_of_week, :day_of_month, :ends_at, :paused]
    end

    update :pause do
      change set_attribute(:paused, true)
    end

    update :resume do
      change set_attribute(:paused, false)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :frequency, :atom do
      allow_nil? false
      constraints one_of: [:daily, :weekly, :monthly, :yearly]
      public? true
    end

    attribute :interval, :integer do
      allow_nil? false
      default 1
      public? true
      description "Every N days/weeks/months/years"
    end

    attribute :days_of_week, {:array, :integer} do
      allow_nil? true
      public? true
      description "For weekly: 1=Mon, 2=Tue, ... 7=Sun"
    end

    attribute :day_of_month, :integer do
      allow_nil? true
      public? true
      description "For monthly: 1-31"
    end

    attribute :last_generated_at, :utc_datetime do
      allow_nil? true
      public? true
    end

    attribute :ends_at, :date do
      allow_nil? true
      public? true
      description "Stop generating after this date"
    end

    attribute :paused, :boolean do
      allow_nil? false
      default false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :todos, Todos.Tasks.Todo do
      destination_attribute :recurring_pattern_id
    end
  end

  calculations do
    calculate :next_occurrence,
              :date,
              expr(
                # This is a simplified calculation - in practice you'd want
                # a more sophisticated algorithm
                fragment(
                  "CASE WHEN ? = 'daily' THEN CURRENT_DATE + (? || ' days')::interval
              WHEN ? = 'weekly' THEN CURRENT_DATE + (? * 7 || ' days')::interval
              WHEN ? = 'monthly' THEN CURRENT_DATE + (? || ' months')::interval
              ELSE CURRENT_DATE + (? || ' years')::interval
         END",
                  frequency,
                  interval,
                  frequency,
                  interval,
                  frequency,
                  interval,
                  interval
                )
              )
  end
end
