# Adding a module

Life Organizer is meant to grow past tasks and calendar into habits, notes, finances and more.
Each area is a **module**: ordinary Rails models, controllers and views, plus a small Ruby
module that tells the app which MCP tools and navigation tab the area adds.

Today there are four:

- `TasksModule` (`app/organizer_modules/tasks_module.rb`): the Tasks tab and the task tools.
- `CalendarModule` (`calendar_module.rb`): the Calendar tab and the event and time-block tools.
- `JotsModule` (`jots_module.rb`): the Jots tab and the jot tools, including turning a jot into a task.
- `AgendaModule` (`agenda_module.rb`): the Today tab and `get_agenda`, which reads across modules.

## Steps, using "habits" as the example

1. **Data.** Add a migration and a model as usual:

   ```sh
   bin/rails generate model Habit name:string cadence:string streak:integer
   bin/rails db:migrate
   ```

   Give the model an `as_api_json` method, so the API, the MCP tools and the pages share one shape.

2. **Logic.** Put anything beyond simple CRUD in a service under `app/services`
   (see `TaskWriter` and `CalendarQuery`). Raise `Organizer::Invalid, "field: what's wrong"`
   for bad input: the web pages show it as a message, the API returns it as a `422`, and MCP
   tools return it to Claude as a tool error it can correct.

3. **The module.** Create `app/organizer_modules/habits_module.rb`:

   ```ruby
   module HabitsModule
     extend OrganizerModule

     self.module_name = "habits"
     self.description = "Habits and streaks."
     nav "Habits", :habits_path, icon: "repeat"

     tool "list_habits", "List habits with their current streaks.", kind: :read do |_args|
       Habit.order(:name).map(&:as_api_json)
     end

     tool "log_habit", "Record that a habit was done today.",
       properties: { habit_id: integer("Habit id") }, required: %w[habit_id] do |args|
       Habit.find(args["habit_id"]).log!.as_api_json
     end
   end
   ```

   - `kind:` is `:read`, `:write` (the default) or `:destructive`. They're sent to Claude as hints,
     and Claude's apps can ask you before a destructive tool runs.
   - Argument helpers: `string`, `integer`, `boolean`, `strings`, `integers` (from `Mcp::Schema`),
     with an optional `enum:` on `string`.
   - Unknown or missing arguments are rejected before your block runs.
   - Whatever the block returns is sent to Claude as JSON.
   - Write tool descriptions for Claude: say what the tool does, the formats it takes, and when
     to prefer another tool.

4. **Register it** in `app/organizer_modules/organizer_modules.rb`:

   ```ruby
   def all
     [ TasksModule, CalendarModule, JotsModule, HabitsModule, AgendaModule ]
   end
   ```

   The tab appears in the app's navigation (on a phone, in the bottom bar) and the tools appear
   in Claude after it reconnects. `GET /api/v1/modules` lists what's installed.

5. **Web pages and REST.** Add routes, a controller and views like the existing ones. REST
   controllers inherit `Api::BaseController`, which handles API keys, browser sessions with a
   CSRF token, and JSON errors.

6. **The agenda.** If the area belongs in the daily plan, add it to `Agenda.build` so
   `get_agenda` and the Today page include it.

7. **Tests.** Add model tests and an integration test that calls your tools through `/mcp`
   (see `test/integration/mcp_test.rb`).

Keep the phone in mind: an icon for the tab (add one to `ICONS` in `ApplicationHelper`), short
labels, and at most five tabs in the bottom bar. There are five today (Today, Tasks, Calendar, Jots,
Settings), so a new module's tab should replace one or live inside another page.
