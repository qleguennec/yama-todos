# User Tag Ordering & Expanded Colors

## Overview

Add per-user tag ordering in the global view via drag-and-drop in the tags tab. Expand color palette from 12 to 20 colors.

## Data Model

### New Resource: UserTagOrder

Join table linking users to tags with a position:

```elixir
defmodule Todos.Tasks.UserTagOrder do
  use Ash.Resource,
    otp_app: :todos,
    domain: Todos.Tasks,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "user_tag_orders"
    repo Todos.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :position, :integer, allow_nil?: false, public?: true
  end

  relationships do
    belongs_to :user, Todos.Accounts.User, allow_nil?: false
    belongs_to :tag, Todos.Tasks.Tag, allow_nil?: false
  end

  identities do
    identity :unique_user_tag, [:user_id, :tag_id]
  end
end
```

Cascade delete when tag is deleted.

## Tags Tab UI

### Drag-and-Drop Reordering

Add sortable.js hook to tags list. Each tag row gets a drag handle:

```
┌─────────────────────────────────────┐
│ All Tags                            │
├─────────────────────────────────────┤
│ ⠿  ■ Work                [EDIT][DEL]│
│ ⠿  ■ Personal            [EDIT][DEL]│
│ ⠿  ■ Urgent              [EDIT][DEL]│
└─────────────────────────────────────┘
```

### Flow

1. User drags tag to new position
2. sortable.js fires `onEnd` event
3. LiveView receives `reorder-tags` event with new order
4. Server bulk-upserts UserTagOrder records for that user
5. Stream updates to reflect new order

### JavaScript Hook

```javascript
import Sortable from "sortablejs"

export const SortableTags = {
  mounted() {
    new Sortable(this.el, {
      animation: 150,
      handle: "[data-drag-handle]",
      ghostClass: "opacity-50",
      onEnd: (evt) => {
        const ids = [...this.el.children].map(el => el.dataset.tagId)
        this.pushEvent("reorder-tags", { tag_ids: ids })
      }
    })
  }
}
```

## Expanded Color Palette

From 12 to 20 colors:

```elixir
defp tag_colors do
  [
    "#ef4444",  # red
    "#f97316",  # orange
    "#f59e0b",  # amber (new)
    "#eab308",  # yellow
    "#84cc16",  # lime (new)
    "#22c55e",  # green
    "#10b981",  # emerald (new)
    "#14b8a6",  # teal
    "#06b6d4",  # cyan
    "#0ea5e9",  # sky (new)
    "#3b82f6",  # blue
    "#6366f1",  # indigo
    "#8b5cf6",  # violet
    "#a855f7",  # purple
    "#d946ef",  # fuchsia (new)
    "#ec4899",  # pink
    "#f43f5e",  # rose
    "#78716c",  # stone (new)
    "#71717a",  # zinc (new)
    "#64748b",  # slate (new)
  ]
end
```

## Global View Integration

Modify `load_tags_with_todos/1` to accept current user and respect their ordering:

```elixir
defp load_tags_with_todos(user) do
  # Get user's tag order preferences
  user_orders =
    UserTagOrder
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.read!()
    |> Map.new(&{&1.tag_id, &1.position})

  tags = Ash.read!(Todos.Tasks.Tag, action: :list_all)

  # Sort: ordered tags first (by position), then unordered (alphabetically)
  sorted_tags = Enum.sort_by(tags, fn tag ->
    case Map.get(user_orders, tag.id) do
      nil -> {1, tag.name}        # unordered: sort alphabetically after
      pos -> {0, pos}             # ordered: sort by position
    end
  end)

  # ... rest of function uses sorted_tags
end
```

### Behavior

- Tags with explicit order appear first, in position order
- Tags without order appear after, alphabetically
- Each user sees their own ordering

## Implementation Tasks

1. Create UserTagOrder resource and migration
2. Add sortable.js dependency and hook
3. Update tags_live.ex with drag-and-drop UI and reorder-tags handler
4. Update global_live.ex to load user's tag order
5. Expand color palette in tags_live.ex
