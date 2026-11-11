module Mcp
  # One MCP tool: a name, a description for the model, a JSON Schema for its arguments
  # and a block that receives the arguments as a Hash with string keys.
  class Tool
    attr_reader :name, :title, :description, :properties, :required, :annotations, :handler

    ANNOTATIONS = {
      read: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
      write: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false },
      destructive: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false }
    }.freeze

    def initialize(name:, description:, properties: {}, required: [], kind: :write, title: nil, &handler)
      @name = name
      @title = title || name.tr("_", " ").capitalize
      @description = description.strip
      @properties = properties
      @required = required
      @annotations = ANNOTATIONS.fetch(kind)
      @handler = handler
    end

    def definition
      {
        name: name, title: title, description: description,
        inputSchema: { type: "object", properties: properties, required: required, additionalProperties: false },
        annotations: annotations.merge(title: title)
      }
    end

    def call(arguments)
      args = (arguments || {}).to_h.stringify_keys
      missing = required.map(&:to_s) - args.keys
      raise Organizer::Invalid, "missing argument(s): #{missing.join(', ')}" if missing.any?
      unknown = args.keys - properties.keys.map(&:to_s)
      raise Organizer::Invalid, "unknown argument(s): #{unknown.join(', ')}" if unknown.any?
      handler.call(args)
    end
  end
end
