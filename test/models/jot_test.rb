require "test_helper"

class JotTest < ActiveSupport::TestCase
  test "the first line becomes the task title and the rest its notes" do
    jot = Jot.create!(body: "Call the plumber\nAsk about the leak under the sink.\nMornings are best.")
    task, block = jot.to_task!
    assert_equal "Call the plumber", task.title
    assert_equal "Ask about the leak under the sink.\nMornings are best.", task.notes
    assert_nil block
    assert_not Jot.exists?(jot.id)
  end

  test "converting can set task fields and block time for it" do
    jot = Jot.create!(body: "Plan the garden")
    task, block = jot.to_task!({ "due_date" => "2026-11-20", "project" => "Home" }, schedule_start: "2026-11-14T10:00", duration_minutes: 90)
    assert_equal Date.new(2026, 11, 20), task.due_date
    assert_equal "Home", task.project.name
    assert_equal "time_block", block.kind
    assert_equal 90.minutes, block.duration
  end

  test "a failed conversion keeps the jot" do
    jot = Jot.create!(body: "Something")
    assert_raises(Organizer::Invalid) { jot.to_task!({ "due_date" => "someday" }) }
    assert Jot.exists?(jot.id)
    assert_equal 0, Task.count
  end

  test "pinned jots come first" do
    old = Jot.create!(body: "old", pinned: true)
    Jot.create!(body: "new")
    assert_equal old, Jot.ordered.first
  end
end
