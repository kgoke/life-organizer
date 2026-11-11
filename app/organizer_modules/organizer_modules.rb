# The module registry. Each life-organizer area (tasks, calendar, and later habits, notes,
# finances...) is a module that contributes MCP tools for Claude and a navigation entry for
# the web app. Models, controllers and routes follow normal Rails conventions.
# See docs/MODULES.md for how to add one.
module OrganizerModules
  module_function

  def all
    [ TasksModule, CalendarModule, AgendaModule ]
  end

  def tools
    all.flat_map(&:tools)
  end

  def navigation
    all.flat_map(&:navigation)
  end

  def mcp_server
    Mcp::Server.new(tools)
  end
end
