module Mcp
  # A Model Context Protocol server over "streamable HTTP" in its simplest form: stateless,
  # one JSON-RPC message per POST, JSON responses (no SSE stream). That is all Claude needs
  # to list and call tools.
  class Server
    PROTOCOL_VERSIONS = %w[2025-11-25 2025-06-18 2025-03-26 2024-11-05].freeze
    VERSION = "0.1.0".freeze

    INSTRUCTIONS = <<~TEXT.freeze
      This is the owner's personal life organizer: their tasks, calendar and jots (quick notes to
      sort out later). Times without an offset are in the owner's time zone (get_agenda shows it
      and the current time). Start with get_agenda to see the day. The owner plans by
      time-blocking: to plan work, find open time with find_free_time and reserve it with
      schedule_task. The owner keeps notes on tasks, so read a task's notes before working on it
      and add to them rather than replacing them. A jot that is really a to-do can become a task
      with convert_jot_to_task. Prefer completing or cancelling tasks over deleting them, and only
      delete events or jots when the owner asks.
    TEXT

    def initialize(tools)
      @tools = tools.index_by(&:name)
    end

    # Returns the JSON response body, or nil when the message needs no response (notifications).
    def handle(message)
      return { jsonrpc: "2.0", id: nil, error: { code: -32600, message: "Invalid Request" } } unless message.is_a?(Hash)
      return nil unless message.key?("id") && message.key?("method") # notifications and responses

      id = message["id"]
      result = dispatch(message["method"], message["params"] || {})
      { jsonrpc: "2.0", id: id, result: result }
    rescue RpcError => e
      { jsonrpc: "2.0", id: id, error: { code: e.code, message: e.message } }
    end

    class RpcError < StandardError
      attr_reader :code

      def initialize(code, message)
        super(message)
        @code = code
      end
    end

    private

    def dispatch(method, params)
      case method
      when "initialize" then initialize_result(params)
      when "ping" then {}
      when "tools/list" then { tools: @tools.values.map(&:definition) }
      when "tools/call" then call_tool(params)
      when "resources/list" then { resources: [] }
      when "resources/templates/list" then { resourceTemplates: [] }
      when "prompts/list" then { prompts: [] }
      else raise RpcError.new(-32601, "Method not found: #{method}")
      end
    end

    def initialize_result(params)
      requested = params["protocolVersion"]
      {
        protocolVersion: PROTOCOL_VERSIONS.include?(requested) ? requested : PROTOCOL_VERSIONS.first,
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: "life-organizer", title: "Life Organizer", version: VERSION },
        instructions: INSTRUCTIONS
      }
    end

    def call_tool(params)
      tool = @tools[params["name"]] || raise(RpcError.new(-32602, "Unknown tool: #{params['name']}"))
      result = tool.call(params["arguments"])
      { content: [ { type: "text", text: JSON.generate(result) } ], structuredContent: result, isError: false }
    rescue Organizer::Invalid, ArgumentError => e
      tool_error(e.message)
    rescue ActiveRecord::RecordNotFound => e
      tool_error("#{e.model || 'Record'} #{e.id} not found")
    rescue ActiveRecord::RecordInvalid => e
      tool_error(e.record.errors.full_messages.to_sentence)
    rescue ActiveRecord::RecordNotDestroyed => e
      tool_error(e.record.errors.full_messages.to_sentence)
    end

    def tool_error(message)
      { content: [ { type: "text", text: message } ], isError: true }
    end
  end
end
