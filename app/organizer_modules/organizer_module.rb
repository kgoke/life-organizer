# Mixed into each module (TasksModule, CalendarModule...) to give it a small DSL.
module OrganizerModule
  include Mcp::Schema

  attr_accessor :module_name, :description

  def tools = (@tools ||= [])
  def navigation = (@navigation ||= [])

  def nav(label, path_helper, icon: nil)
    navigation << { label: label, path: path_helper, icon: icon }
  end

  def tool(name, description, properties: {}, required: [], kind: :write, &block)
    tools << Mcp::Tool.new(name: name, description: description, properties: properties, required: required, kind: kind, &block)
  end

  # In update tools an empty string means "clear this field".
  def only_given(args, *keys)
    args.slice(*keys.map(&:to_s)).reject { |_, v| v.nil? }
  end
end
