require "test_helper"

class RecurrenceTest < ActiveSupport::TestCase
  test "aliases expand to RRULEs" do
    assert_equal "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR", Recurrence.normalize("weekdays")
    assert_equal "FREQ=WEEKLY;INTERVAL=2", Recurrence.normalize("biweekly")
    assert_equal "FREQ=MONTHLY", Recurrence.normalize("RRULE:FREQ=MONTHLY")
    assert_nil Recurrence.normalize("")
  end

  test "rejects nonsense" do
    assert_raises(Organizer::Invalid) { Recurrence.normalize("every blue moon") }
  end
end
