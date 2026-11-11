require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  test "task lifecycle" do
    task = api(:post, "/api/v1/tasks", { title: "Write report", due_date: "2026-11-12", due_time: "14:00", priority: "high",
                                          tags: [ "work" ], project: "Job", subtasks: [ "outline" ] })
    assert_response :created
    assert_equal "high", task["priority"]
    assert_equal [ "outline" ], task["subtasks"].map { |s| s["title"] }

    assert_equal [ task["id"] ], api(:get, "/api/v1/tasks?tag=work").map { |t| t["id"] }
    assert_equal [ task["id"] ], api(:get, "/api/v1/tasks?q=report").map { |t| t["id"] }

    updated = api(:patch, "/api/v1/tasks/#{task["id"]}", { notes: "draft first", due_time: "" })
    assert_equal "draft first", updated["notes"]
    assert_nil updated["due_time"]

    done = api(:post, "/api/v1/tasks/#{task["id"]}/complete")
    assert_equal "done", done["task"]["status"]
    reopened = api(:post, "/api/v1/tasks/#{task["id"]}/reopen")
    assert_equal "todo", reopened["status"]

    delete "/api/v1/tasks/#{task["id"]}", headers: auth_headers
    assert_response :no_content
    get "/api/v1/tasks/#{task["id"]}", headers: auth_headers
    assert_response :not_found
  end

  test "validation errors come back as 422 with a message" do
    body = api(:post, "/api/v1/tasks", { title: "" })
    assert_response :unprocessable_entity
    assert body["error"].present?
    body = api(:post, "/api/v1/events", { title: "Bad", start: "tomorrow" })
    assert_response :unprocessable_entity
    assert_match "start", body["error"]
  end

  test "events, occurrences and scheduling" do
    ev = api(:post, "/api/v1/events", { title: "Standup", start: "2026-11-09T09:00", duration_minutes: 15, recurrence: "weekdays" })
    assert_response :created
    list = api(:get, "/api/v1/events?start=2026-11-09&end=2026-11-14")
    assert_equal 5, list.size

    moved = api(:patch, "/api/v1/events/#{ev["id"]}?occurrence=2026-11-11T09:00", { start: "2026-11-11T10:00" })
    assert_equal false, moved["recurring"]
    delete "/api/v1/events/#{ev["id"]}?occurrence=2026-11-12T09:00", headers: auth_headers
    assert_response :no_content
    starts = api(:get, "/api/v1/events?start=2026-11-09&end=2026-11-14").map { |e| e["start"][0, 16] }
    assert_equal %w[2026-11-09T09:00 2026-11-10T09:00 2026-11-11T10:00 2026-11-13T09:00], starts.sort

    task = api(:post, "/api/v1/tasks", { title: "Deep work", estimate_minutes: 120 })
    block = api(:post, "/api/v1/tasks/#{task["id"]}/schedule", { start: "2026-11-12T13:00" })
    assert_response :created
    assert_equal "time_block", block["kind"]
    assert_equal "2026-11-12T15:00:00-05:00", block["end"]
    assert_equal 1, api(:get, "/api/v1/events?start=2026-11-12&end=2026-11-13&kind=time_block").size
  end

  test "agenda, free time, connection info and modules" do
    freeze_now do
      api(:post, "/api/v1/events", { title: "Lunch", start: "2026-11-11T12:00", end: "2026-11-11T13:00" })
      agenda = api(:get, "/api/v1/agenda?days=2")
      assert_equal %w[2026-11-11 2026-11-12], agenda["days"].map { |d| d["date"] }
      free = api(:get, "/api/v1/free_time?date=2026-11-11&min_minutes=60")
      assert_equal "2026-11-11T10:00:00-05:00", free.first["start"]
      info = api(:get, "/api/v1/connection")
      assert_equal "https://organizer.example.test/mcp", info["mcp_url"]
      assert_equal %w[tasks calendar agenda], api(:get, "/api/v1/modules").map { |m| m["name"] }
    end
  end

  test "the calendar feed needs its secret token" do
    EventWriter.create!("title" => "Dinner", "start" => "2026-11-20T19:00")
    get "/feed/wrong-token.ics"
    assert_response :not_found
    get "/feed/#{AppSetting.feed_token}.ics"
    assert_response :success
    assert_includes response.body, "SUMMARY:Dinner"
    assert_equal "text/calendar", response.media_type
  end
end
