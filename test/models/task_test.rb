require "test_helper"

class TaskTest < ActiveSupport::TestCase
  test "completing a repeating task makes the next one, with its subtasks" do
    freeze_now do
      task, = TaskWriter.create!("title" => "Water plants", "due_date" => "2026-11-11", "recurrence" => "weekly", "subtasks" => [ "front", "back" ])
      _, nxt = TaskWriter.update!(task, "status" => "done")
      assert_equal "done", task.reload.status
      assert_nil task.recurrence
      assert_equal Date.new(2026, 11, 18), nxt.due_date
      assert_equal %w[front back], nxt.subtasks.order(:position).map(&:title)
      assert nxt.subtasks.all? { |s| s.status == "todo" }
    end
  end

  test "a long-overdue repeating task skips ahead instead of piling up" do
    freeze_now do
      task, = TaskWriter.create!("title" => "Trash", "due_date" => "2026-10-01", "recurrence" => "weekly")
      _, nxt = TaskWriter.update!(task, "status" => "done")
      assert_operator nxt.due_date, :>=, Date.new(2026, 11, 11)
      assert_equal Date.new(2026, 10, 1).wday, nxt.due_date.wday
    end
  end

  test "tags are normalised and projects are created by name" do
    task, = TaskWriter.create!("title" => "Taxes", "tags" => [ " Money ", "money", "Home" ], "project" => "Admin")
    assert_equal %w[Money Home], task.tags, "trimmed and de-duplicated, ignoring case"
    assert_equal "Admin", task.project.name
    task2, = TaskWriter.create!("title" => "More", "project" => "admin")
    assert_equal task.project_id, task2.project_id
  end

  test "an empty string clears a field" do
    task, = TaskWriter.create!("title" => "Thing", "due_date" => "2026-11-20", "due_time" => "9:30")
    assert_equal "09:30", task.due_time
    TaskWriter.update!(task, "due_date" => "", "due_time" => "")
    assert_nil task.reload.due_date
    assert_nil task.due_time
  end

  test "bad input raises a readable error" do
    err = assert_raises(Organizer::Invalid) { TaskWriter.create!("title" => "x", "due_date" => "next tuesday") }
    assert_match "due_date", err.message
    assert_raises(Organizer::Invalid) { TaskWriter.create!("title" => "x", "priority" => "extreme") }
  end
end
