module Mcp
  # Small helpers for JSON Schema properties.
  module Schema
    module_function

    def string(description, enum: nil) = { type: "string", description: description }.tap { |h| h[:enum] = enum if enum }
    def integer(description) = { type: "integer", description: description }
    def boolean(description) = { type: "boolean", description: description }
    def strings(description) = { type: "array", items: { type: "string" }, description: description }
    def integers(description) = { type: "array", items: { type: "integer" }, description: description }
  end
end
