class Calendar < ApplicationRecord
  has_many :events, dependent: :destroy

  validates :name, presence: true, length: { maximum: 200 }
  before_destroy :keep_default

  def self.default
    find_by(is_default: true) || first&.tap { |c| c.update!(is_default: true) } ||
      create!(name: "Personal", color: "#3b6ef5", is_default: true)
  end

  def make_default!
    transaction do
      Calendar.where.not(id: id).update_all(is_default: false)
      update!(is_default: true)
    end
  end

  def as_api_json
    { id: id, name: name, color: color, is_default: is_default, include_in_feed: include_in_feed }
  end

  private

  def keep_default
    return unless is_default
    errors.add(:base, "The default calendar can't be deleted. Make another calendar the default first.")
    throw :abort
  end
end
