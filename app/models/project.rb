class Project < ApplicationRecord
  has_many :tasks, dependent: :nullify

  validates :name, presence: true, length: { maximum: 200 }

  scope :active, -> { where(archived: false) }
  scope :ordered, -> { order(:position, :name) }

  def self.find_by_name_ci(name)
    where("lower(name) = ?", name.to_s.strip.downcase).first
  end

  def as_api_json
    { id: id, name: name, color: color, archived: archived, position: position }
  end
end
