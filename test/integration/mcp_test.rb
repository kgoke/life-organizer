require "test_helper"

class McpTest < ActionDispatch::IntegrationTest
  test "unauthenticated requests point to the OAuth metadata" do
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "initialize" }.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
    assert_includes response.headers["WWW-Authenticate"], "https://organizer.example.test/.well-known/oauth-protected-resource/mcp"
  end

  test "initialize, notifications and tool listing" do
    body = mcp("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "1" } })
    assert_equal "2025-06-18", body["result"]["protocolVersion"]
    assert body["result"]["capabilities"]["tools"]

    post "/mcp", params: { jsonrpc: "2.0", method: "notifications/initialized" }.to_json, headers: auth_headers
    assert_response :accepted

    tools = mcp("tools/list")["result"]["tools"]
    names = tools.map { |t| t["name"] }
    %w[list_tasks create_task complete_task create_event schedule_task find_free_time get_agenda].each { |n| assert_includes names, n }
    delete_tool = tools.find { |t| t["name"] == "delete_task" }
    assert_equal true, delete_tool["annotations"]["destructiveHint"]
    assert_equal true, tools.find { |t| t["name"] == "list_tasks" }["annotations"]["readOnlyHint"]
  end

  test "tools create, schedule and complete work" do
    _, task = call_tool("create_task", { title: "Call the bank", due_date: "2026-11-12", estimate_minutes: 30 })
    assert_equal "Call the bank", task["title"]
    _, block = call_tool("schedule_task", { task_id: task["id"], start: "2026-11-12T09:30" })
    assert_equal "2026-11-12T10:00:00-05:00", block["end"]
    _, ev = call_tool("create_event", { title: "Haircut", start: "2026-11-13T17:00", duration_minutes: 45 })
    _, listed = call_tool("list_events", { start: "2026-11-12", end: "2026-11-14" })
    assert_equal [ block["id"], ev["id"] ].sort, listed["events"].map { |e| e["id"] }.sort
    _, done = call_tool("complete_task", { task_id: task["id"] })
    assert_equal "done", done["task"]["status"]
  end

  test "tool errors are reported as tool results, unknown tools as protocol errors" do
    result, = call_tool("create_task", { due_date: "2026-11-12" })
    assert_equal true, result["isError"]
    result, = call_tool("get_task", { task_id: 999_999 })
    assert_equal true, result["isError"]
    body = mcp("tools/call", { name: "nope", arguments: {} })
    assert_equal(-32602, body["error"]["code"])
    assert_equal(-32601, mcp("does/not/exist")["error"]["code"])
  end

  test "batched requests get batched replies" do
    post "/mcp", params: [ { jsonrpc: "2.0", id: 1, method: "ping" }, { jsonrpc: "2.0", id: 2, method: "tools/list" } ].to_json,
                 headers: auth_headers
    assert_equal [ 1, 2 ], response.parsed_body.map { |r| r["id"] }
  end

  test "GET is not offered" do
    get "/mcp", headers: auth_headers
    assert_response :method_not_allowed
  end
end
