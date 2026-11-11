require "test_helper"

class EventTest < ActiveSupport::TestCase
  setup { @zone = Time.find_zone("America/New_York") }

  test "a weekly event keeps its local time across a DST change" do
    event = EventWriter.create!("title" => "Yoga", "start" => "2026-10-27T18:00", "duration_minutes" => 60, "recurrence" => "weekly")
    starts = event.occurrences_between(@zone.local(2026, 10, 20), @zone.local(2026, 11, 12)).map { |o| o.in_time_zone(@zone) }
    assert_equal [ "2026-10-27 18:00", "2026-11-03 18:00", "2026-11-10 18:00" ], starts.map { |t| t.strftime("%F %H:%M") }
  end

  test "moving one occurrence splits it off and skips it in the series" do
    event = EventWriter.create!("title" => "Standup", "start" => "2026-11-09T09:00", "duration_minutes" => 15, "recurrence" => "weekdays")
    moved = EventWriter.update_occurrence!(event, "2026-11-11T09:00", "start" => "2026-11-11T11:00")
    refute moved.recurring?
    assert_equal "11:00", moved.local_start.strftime("%H:%M")
    assert_equal 15.minutes, moved.duration
    day = CalendarQuery.occurrences(@zone.local(2026, 11, 11), @zone.local(2026, 11, 12))
    assert_equal [ moved.id ], day.map { |ev, _| ev.id }
  end

  test "deleting one occurrence leaves the others" do
    event = EventWriter.create!("title" => "Gym", "start" => "2026-11-09T07:00", "recurrence" => "daily")
    EventWriter.delete_occurrence!(event, "2026-11-10T07:00")
    days = event.occurrences_between(@zone.local(2026, 11, 9), @zone.local(2026, 11, 12)).map { |t| t.in_time_zone(@zone).day }
    assert_equal [ 9, 11 ], days
  end

  test "all-day events cover whole local days with an exclusive end" do
    event = EventWriter.create!("title" => "Trip", "start" => "2026-11-13", "end" => "2026-11-16", "all_day" => true)
    json = event.as_api_json
    assert_equal "2026-11-13", json[:start]
    assert_equal "2026-11-16", json[:end]
    assert_equal 1, CalendarQuery.occurrences(@zone.local(2026, 11, 15), @zone.local(2026, 11, 16)).size
  end

  test "the default calendar cannot be deleted" do
    assert_not Calendar.default.destroy
  end
end
