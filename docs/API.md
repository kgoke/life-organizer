# API

Everything the web app does is also available over a JSON REST API and to Claude over MCP.
Both use the same code underneath, so they behave the same way.

## Authentication

Send an API key (make one in **Settings → API keys**) in either header:

```
Authorization: Bearer lo_...
X-API-Key: lo_...
```

OAuth access tokens (`loa_...`) issued to claude.ai work the same way. Requests without a valid
token get `401`.

## Conventions

- JSON in, JSON out. Send `Content-Type: application/json`.
- **Dates** are `YYYY-MM-DD`. **Date-times** are ISO 8601. A date-time without an offset, such as
  `2026-11-12T14:00`, is read in the app's time zone (`APP_TIMEZONE`). Responses always include
  the offset.
- **All-day events** use dates, and `end` is exclusive: a one-day event on the 13th has
  `start: "2026-11-13", end: "2026-11-14"`.
- **Repeats** take `daily`, `weekdays`, `weekly`, `biweekly`, `monthly`, `yearly` or any RFC 5545
  RRULE such as `FREQ=WEEKLY;BYDAY=TU,TH` or `FREQ=MONTHLY;BYMONTHDAY=1;COUNT=12`.
- In updates, only the fields you send change, and an empty string clears a field.
- Errors come back as `{"error": "message"}` with `400`, `404` or `422`.

## Tasks

| Method and path | What it does |
| --- | --- |
| `GET /api/v1/tasks` | List tasks. Filters: `status` (`open`, `todo`, `in_progress`, `done`, `cancelled`, `all`), `project_id`, `tag`, `due_on`, `due_before`, `due_after`, `q`, `parent_id`, `top_level_only`, `unscheduled`, `limit`, `offset`. |
| `GET /api/v1/tasks/:id` | One task with its subtasks and time blocks. |
| `POST /api/v1/tasks` | Create. Fields below. |
| `PATCH /api/v1/tasks/:id` | Update. Setting `status` to `done` completes it (and makes the next one if it repeats). |
| `DELETE /api/v1/tasks/:id` | Delete with its subtasks and time blocks. |
| `POST /api/v1/tasks/:id/complete` | Mark done. Returns `{task, next_occurrence}`. |
| `POST /api/v1/tasks/:id/reopen` | Mark to-do again. |
| `POST /api/v1/tasks/:id/schedule` | Time-block the task: `{start, end?, duration_minutes?, calendar_id?}`. The length defaults to the task's estimate, or 30 minutes. |

Task fields: `title` (required), `notes`, `status`, `priority` (`none`, `low`, `medium`,
`high`, `urgent`), `due_date`, `due_time` (`HH:MM`), `estimate_minutes`, `project_id` or
`project` (a name, created if new), `parent_id`, `tags` (array), `recurrence`, `position`, and
on create `subtasks` (array of titles).

A repeating task repeats on a schedule. When you complete it, the next one is created on the
next date in the rule (after today, if the task was late), with fresh copies of its subtasks.

```sh
curl -X POST https://organizer.example.com/api/v1/tasks \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"title":"Pay rent","due_date":"2026-12-01","recurrence":"monthly","tags":["home"]}'
```

## Projects

`GET /api/v1/projects`, `POST /api/v1/projects` (`name`, `color`), `PATCH /api/v1/projects/:id`,
`DELETE /api/v1/projects/:id` (its tasks are kept, without a project).

## Events and time blocks

| Method and path | What it does |
| --- | --- |
| `GET /api/v1/events?start=&end=` | Events in a range (default the next 7 days, at most 800 days). Repeating events are expanded, one entry per occurrence, each with `occurrence` and `series_start`. Filters: `calendar_id`, `kind` (`event` or `time_block`), `task_id`, `q`. |
| `GET /api/v1/events/:id` | One event (the series, for a repeating one). |
| `POST /api/v1/events` | Create. |
| `PATCH /api/v1/events/:id` | Update the event or whole series. Add `?occurrence=<start>` to change only that occurrence; it's split off into its own event. |
| `DELETE /api/v1/events/:id` | Delete. Add `?occurrence=<start>` to skip only that occurrence. |

Event fields: `title` (required), `start` (required), `end` or `duration_minutes` (default 60),
`all_day`, `description`, `location`, `calendar_id` or `calendar` (name), `recurrence`,
`reminders` (minutes before, such as `[10, 60]`), `color`, `time_zone`, and `kind`
(`event` or `time_block`, with `task_id` for a block). When you move only `start`, the event
keeps its length.

## Calendars

`GET /api/v1/calendars`, `POST /api/v1/calendars` (`name`, `color`, `include_in_feed`),
`PATCH /api/v1/calendars/:id` (also `is_default: true`), `DELETE /api/v1/calendars/:id`
(not the default one; its events are deleted).

## Planning

| Method and path | What it does |
| --- | --- |
| `GET /api/v1/agenda?date=&days=` | For each day: events, time blocks and tasks due, plus all overdue tasks. Defaults to today, 1 day (up to 31). |
| `GET /api/v1/free_time?date=&min_minutes=&day_start=&day_end=` | Open slots between timed events and blocks within working hours. Today starts from now. |
| `GET /api/v1/connection` | The connector address, feed address, time zone and working hours. |
| `GET /api/v1/modules` | The modules installed and the MCP tools each adds. |

## Calendar feed

`GET /feed/<token>.ics` serves an iCalendar feed of every calendar marked "include in feed",
time blocks (titled "[Focus] ..."), and open tasks with due dates. The token is in Settings.

## MCP (Claude connector)

`POST /mcp` speaks MCP over Streamable HTTP. It is stateless and answers with plain JSON
(protocol versions 2025-11-25, 2025-06-18, 2025-03-26 and 2024-11-05). `GET` returns 405,
since the server never pushes messages.

An unauthenticated request gets `401` with a `WWW-Authenticate` header that points to
`/.well-known/oauth-protected-resource/mcp`. From there clients find the OAuth 2.1
authorization server: dynamic client registration at `/oauth/register`, authorization code
with PKCE (S256) at `/oauth/authorize`, tokens and refresh at `/oauth/token`, and revocation at
`/oauth/revoke`. Access tokens last 8 hours and refresh tokens 90 days; refresh tokens rotate
on every use.

### MCP tools

Required arguments are in bold. Read-only tools are marked as such, and `delete_task` and
`delete_event` are marked destructive, so Claude's apps can ask you before they run.

| Tool | What it does | Arguments |
| --- | --- | --- |
| `list_tasks` | List tasks. Defaults to open tasks (to-do and in progress), soonest due first. Dates are | status, project, tag, due_on, due_before, due_after, search, unscheduled_only, limit |
| `get_task` | Get one task with notes, subtasks and time blocks. | **task_id** |
| `create_task` | Create a task. Only title is required. | **title**, notes, due_date, due_time, priority, project, tags, estimate_minutes, recurrence, parent_id, subtasks |
| `update_task` | Change a task. Only the fields you pass change. Pass an empty string to clear a field | **task_id**, title, status, notes, due_date, due_time, priority, project, tags, estimate_minutes, recurrence, parent_id |
| `complete_task` | Mark a task done. If it repeats, the next one is created and returned. | **task_id** |
| `delete_task` | Permanently delete a task with its subtasks and time blocks. Prefer complete_task, or status | **task_id** |
| `list_projects` | List projects (groups of tasks). |  |
| `create_project` | Create a project. | **name**, color |
| `list_events` | List calendar events between start and end (dates or ISO date-times; end is exclusive). | start, end, calendar, search, include_time_blocks |
| `get_event` | Get one event (the whole series for a repeating event). | **event_id** |
| `create_event` | Create a calendar event. If end is omitted, duration_minutes is used (default 60). To reserve | **title**, **start**, end, duration_minutes, all_day, description, location, calendar, recurrence, reminders, time_zone |
| `update_event` | Change an event or time block. Only the fields you pass change; an empty string clears | **event_id**, occurrence, title, start, end, duration_minutes, all_day, description, location, calendar, recurrence, reminders |
| `delete_event` | Delete an event or time block. For a repeating event, pass occurrence to skip only that one; | **event_id**, occurrence |
| `schedule_task` | Time-block a task: reserve calendar time to work on it. start is an ISO date-time such as | **task_id**, **start**, duration_minutes, end, calendar |
| `find_free_time` | Open slots on a day between events and time blocks, within working hours. For today, slots | date, min_minutes, day_start, day_end |
| `list_calendars` | List calendars. Events go to the default calendar unless one is named. |  |
| `create_calendar` | Create a calendar (e.g. Work, Family). | **name**, color |
| `get_agenda` | The owner's plan: for each day from date (default today) for `days` days, the events, time | date, days |
