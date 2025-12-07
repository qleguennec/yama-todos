# Todos - Advanced Task Management App

A feature-rich todo app with state machine workflows, tags, subtasks, and recurring tasks. Built with Phoenix LiveView and Ash Framework.

## App Overview

Todos is designed for daily use between multiple users (via Tailscale auth). Key features:

- **State Machine Workflow**: inbox → pending → in_progress → waiting → done/cancelled
- **Quick Capture**: Minimal input to inbox, organize later
- **Tags**: Color-coded labels for organization
- **Subtasks**: Checklists within todos
- **Recurring Todos**: Daily, weekly, monthly patterns
- **Today View**: Due today + pinned items
- **Waiting View**: Track blocked items
- **Soft Delete**: Archive with Ash Archival

## Domain Model

### Todo (with State Machine)

States:
- `inbox` - Quick captured, needs organizing
- `pending` - Organized, ready to work on
- `in_progress` - Actively working
- `waiting` - Blocked on someone/something
- `done` - Completed
- `cancelled` - Abandoned

Transitions:
- `organize`: inbox → pending
- `start`: inbox/pending → in_progress
- `pause`: in_progress → pending
- `wait`: in_progress → waiting
- `resume`: waiting → in_progress
- `unblock`: waiting → pending
- `complete`: in_progress/pending → done
- `cancel`: any active → cancelled
- `reopen`: done/cancelled → pending

### Tag
Reusable labels with customizable colors.

### Subtask
Checklist items within a todo. Supports drag-to-reorder.

### RecurringPattern
Defines recurrence rules:
- `daily` - Every N days
- `weekly` - Specific days of week
- `monthly` - Specific day of month
- `yearly` - Specific date each year

## Navigation

Five main tabs:
1. **Inbox** - Quick captured todos needing organization
2. **Today** - Due today + pinned items
3. **All** - All todos with filter (active/done/all)
4. **Waiting** - Blocked todos
5. **Tags** - Manage tags

## Tech Stack

- **Framework**: Phoenix 1.8 + LiveView 1.1
- **Data Layer**: Ash Framework 3.0 + AshPostgres
- **State Machine**: AshStateMachine
- **Soft Delete**: AshArchival
- **Auth**: Tailscale ForwardAuth
- **Styling**: Tailwind CSS v4 + daisyUI
- **Dev Environment**: NixOS flake

## Running App & Logs

The app runs as a systemd user service in a tmux session. To check logs:

```bash
# View recent logs (last 100 lines)
tmux -S /run/user/1000/yama-todos.socket capture-pane -p -S -100

# Attach to the tmux session interactively
tmux -S /run/user/1000/yama-todos.socket attach

# Manage the service
systemctl --user restart yama-todos
systemctl --user status yama-todos
```

## Project Guidelines

See the parent AGENTS.md for NixOS, jujutsu, and general guidelines.

### Ash Resource Patterns

State transitions use `transition_state/1`:

```elixir
update :start do
  change transition_state(:in_progress)
end
```

Archive with related records:

```elixir
archive do
  archive_related [:subtasks]
end
```

### LiveView Patterns

Use streams for todo lists:

```elixir
stream(:todos, todos)
stream_insert(socket, :todos, updated_todo)
stream_delete(socket, :todos, todo)
```

Use AshPhoenix.Form for all forms:

```elixir
form = AshPhoenix.Form.for_update(todo, :update, domain: Todos.Tasks, as: "todo") |> to_form()
```

### AshPhoenix Forms with Relationships

**For selecting existing records** (e.g., tags in a many-to-many):
- Use checkboxes or `multiple: true` select - NOT `inputs_for`
- `inputs_for` is for nested creation/editing of related records
- Filter empty strings from array params (hidden inputs send `[""]`):

```elixir
def handle_event("save", %{"todo" => params}, socket) do
  params =
    case params["tag_ids"] do
      list when is_list(list) ->
        Map.put(params, "tag_ids", Enum.filter(list, &(&1 != "")))
      _ ->
        params
    end
  # ... submit form
end
```

**For actions with `manage_relationship`**:
- Add `require_atomic? false` to avoid atomic update errors:

```elixir
update :update do
  require_atomic? false
  argument :tag_ids, {:array, :uuid}
  change manage_relationship(:tag_ids, :tags, type: :append_and_remove)
end
```

See: https://ash-project.github.io/ash_phoenix/forms-for-relationships-between-existing-records.html
