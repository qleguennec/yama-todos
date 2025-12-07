# Todos

Advanced task management app with state machine workflows, tags, subtasks, and recurring tasks.

## Features

- **State Machine Workflow**: inbox → pending → in_progress → waiting → done/cancelled
- **Quick Capture**: Minimal input to inbox, organize later
- **Tags**: Color-coded labels for organization
- **Subtasks**: Checklists within todos
- **Recurring Todos**: Daily, weekly, monthly patterns
- **Today View**: Due today + pinned items
- **Waiting View**: Track blocked items
- **Soft Delete**: Archive with Ash Archival
- **Tailscale Auth**: Shared between users on the same tailnet

## Getting Started

```bash
cd apps/todos
nix develop
mix setup
mix phx.server
```

Visit [`localhost:4001`](http://localhost:4001) from your browser.

## Tech Stack

- Phoenix 1.8 + LiveView 1.1
- Ash Framework 3.0 + AshPostgres
- AshStateMachine for workflow
- AshArchival for soft delete
- Tailwind CSS v4 + daisyUI
