require "test_helper"

class CalendarQueryTest < ActiveSupport::TestCase
  setup { @zone = Time.find_zone("America/New_York") }

  test "free time skips events and starts from now today" do
    freeze_now do
      EventWriter.create!("title" => "Lunch", "start" => "2026-11-11T12:00", "end" => "2026-11-11T13:00")
      slots = CalendarQuery.free_slots(Date.new(2026, 11, 11), min_minutes: 30)
      assert_equal [ [ "10:00", "12:00" ], [ "13:00", "18:00" ] ], slots.map { |s| [ s[:start][11, 5], s[:end][11, 5] ] }
    end
  end

  test "scheduling a task creates a time block that uses its estimate" do
    task, = TaskWriter.create!("title" => "Write", "estimate_minutes" => 90)
    block = CalendarQuery.schedule_task!(task, start: "2026-11-12T09:00")
    assert_equal "time_block", block.kind
    assert_equal 90.minutes, block.duration
    assert_equal "Write", block.display_title
    assert_equal [ block ], task.time_blocks.to_a
  end

  test "the agenda lists the day's events, blocks and due tasks" do
    freeze_now do
      EventWriter.create!("title" => "Dentist", "start" => "2026-11-11T15:00")
      task, = TaskWriter.create!("title" => "Report", "due_date" => "2026-11-11")
      TaskWriter.create!("title" => "Late", "due_date" => "2026-11-01")
      CalendarQuery.schedule_task!(task, start: "2026-11-11T11:00")
      day = Agenda.build(Date.new(2026, 11, 11), 1)[:days].first
      assert_equal [ "Dentist" ], day[:events].map { |e| e[:title] }
      assert_equal [ "Report" ], day[:time_blocks].map { |e| e[:title] }
      assert_equal [ "Report" ], day[:tasks_due].map { |t| t[:title] }
      assert_equal [ "Late" ], Agenda.build(Date.new(2026, 11, 11), 1)[:overdue_tasks].map { |t| t[:title] }
    end
  end

  test "the ICS feed has events, repeats, reminders and due tasks" do
    EventWriter.create!("title" => "Standup", "start" => "2026-11-09T09:00", "recurrence" => "weekdays", "reminders" => [ 10 ])
    TaskWriter.create!("title" => "Pay rent", "due_date" => "2026-12-01")
    ics = IcsFeed.build(include_tasks: true)
    assert_includes ics, "SUMMARY:Standup"
    assert_includes ics, "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"
    assert_includes ics, "TRIGGER:-PT10M"
    assert_includes ics, "Due: Pay rent"
    assert_includes ics, "BEGIN:VTIMEZONE"
  end
end
