require "test_helper"

class WebTest < ActionDispatch::IntegrationTest
  setup { sign_in_owner }

  test "quick add, toggle and edit a task" do
    post "/tasks", params: { task: { title: "Buy milk", due_date: "2026-11-12", priority_name: "high", tags: "home, errands" } }
    task = Task.last
    assert_equal %w[home errands], task.tags
    post "/tasks/#{task.id}/toggle"
    assert_equal "done", task.reload.status
    get "/tasks/#{task.id}/edit"
    assert_response :success
    patch "/tasks/#{task.id}", params: { task: { title: "Buy oat milk", recurrence: "custom", recurrence_custom: "FREQ=WEEKLY;BYDAY=SA" } }
    assert_equal "FREQ=WEEKLY;BYDAY=SA", task.reload.recurrence
  end

  test "create and edit events from the forms" do
    get "/events/new", params: { start: "2026-11-13", all_day: "true" }
    assert_response :success
    post "/events", params: { event: { title: "Trip", all_day: "1", start: "2026-11-13", end: "2026-11-15", calendar_id: Calendar.default.id } }
    trip = Event.last
    assert trip.all_day
    assert_equal "2026-11-16", trip.as_api_json[:end], "the form's last day is inclusive"

    post "/events", params: { event: { title: "Standup", all_day: "0", start: "2026-11-09T09:00", end: "2026-11-09T09:15", recurrence: "weekdays" } }
    standup = Event.last
    get "/events/#{standup.id}/edit", params: { occurrence: "2026-11-11T09:00:00-05:00" }
    assert_response :success
    patch "/events/#{standup.id}", params: { occurrence: "2026-11-11T09:00:00-05:00", scope: "all",
                                             event: { title: "Standup", all_day: "0", start: "2026-11-11T09:30", end: "2026-11-11T09:45", recurrence: "weekdays" } }
    assert_equal "09:30", standup.reload.local_start.strftime("%H:%M")
    assert_equal Date.new(2026, 11, 9), standup.local_start.to_date, "editing all from one day shifts the series, keeping its first day"
  end

  test "settings: make a key, add a calendar and a project, rotate the feed" do
    post "/settings/api_keys", params: { name: "laptop" }
    follow_redirect!
    assert_match(/lo_[A-Za-z0-9_-]{20,}/, response.body)
    post "/settings/calendars", params: { calendar: { name: "Work", color: "#ff8800" } }
    assert Calendar.find_by(name: "Work")
    post "/settings/projects", params: { project: { name: "House", color: "#00aa88" } }
    assert Project.find_by(name: "House")
    old = AppSetting.feed_token
    post "/settings/feed_token"
    refute_equal old, AppSetting.feed_token
  end
end
