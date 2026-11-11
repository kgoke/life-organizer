require "test_helper"

class JotsTest < ActionDispatch::IntegrationTest
  test "jot from the Today page, then make it a task" do
    sign_in_owner
    post "/jots", params: { jot: { body: "Renew passport\nPhotos first" } }
    jot = Jot.last
    get "/"
    assert_select ".jot-title", "Renew passport"
    get "/jots"
    assert_response :success
    get "/jots/#{jot.id}/edit"
    assert_response :success
    post "/jots/#{jot.id}/convert", params: { task: { due_date: "2026-12-01", priority: "high" } }
    task = Task.last
    assert_redirected_to "/tasks/#{task.id}/edit"
    assert_equal [ "Renew passport", "Photos first", "high" ], [ task.title, task.notes, task.priority_name ]
    get "/calendar"
    assert_response :success
  end

  test "pin and delete from the list" do
    sign_in_owner
    jot = Jot.create!(body: "idea")
    patch "/jots/#{jot.id}", params: { jot: { pinned: true } }
    assert jot.reload.pinned
    delete "/jots/#{jot.id}"
    assert_not Jot.exists?(jot.id)
  end

  test "API: create, list and convert with a time block" do
    jot = api(:post, "/api/v1/jots", { body: "Write blog post\noutline in notes app" })
    assert_response :created
    assert_equal [ jot["id"] ], api(:get, "/api/v1/jots?q=blog").map { |j| j["id"] }
    result = api(:post, "/api/v1/jots/#{jot["id"]}/convert", { schedule_start: "2026-11-12T15:00", duration_minutes: 45 })
    assert_response :created
    assert_equal "Write blog post", result["task"]["title"]
    assert_equal "2026-11-12T15:45:00-05:00", result["time_block"]["end"]
    assert_empty api(:get, "/api/v1/jots")
  end

  test "MCP: Claude can jot and convert" do
    _, jot = call_tool("add_jot", { body: "Look into standing desks" })
    _, listed = call_tool("list_jots")
    assert_equal [ jot["id"] ], listed["jots"].map { |j| j["id"] }
    _, out = call_tool("convert_jot_to_task", { jot_id: jot["id"], tags: [ "home" ] })
    assert_equal [ "home" ], out["task"]["tags"]
    assert_equal 0, Jot.count
  end
end
