class CreateCoreTables < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :color, null: false, default: "#5b8def"
      t.boolean :archived, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    create_table :tasks do |t|
      t.string :title, null: false
      t.text :notes, null: false, default: ""
      t.string :status, null: false, default: "todo"
      t.integer :priority, null: false, default: 0
      t.date :due_date
      t.string :due_time # "HH:MM", in the app time zone
      t.integer :estimate_minutes
      t.references :project, foreign_key: { on_delete: :nullify }
      t.references :parent, foreign_key: { to_table: :tasks, on_delete: :cascade }
      t.json :tags, null: false, default: []
      t.string :recurrence
      t.integer :position, null: false, default: 0
      t.datetime :completed_at
      t.timestamps
    end
    add_index :tasks, :status
    add_index :tasks, :due_date

    create_table :calendars do |t|
      t.string :name, null: false
      t.string :color, null: false, default: "#3b6ef5"
      t.boolean :is_default, null: false, default: false
      t.boolean :include_in_feed, null: false, default: true
      t.timestamps
    end

    create_table :events do |t|
      t.references :calendar, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.text :description, null: false, default: ""
      t.string :location, null: false, default: ""
      t.datetime :starts_at, null: false   # UTC
      t.datetime :ends_at, null: false     # UTC; all-day events end at the next local midnight
      t.datetime :series_ends_at           # UTC end of the last occurrence; NULL = repeats forever
      t.string :time_zone, null: false
      t.boolean :all_day, null: false, default: false
      t.string :recurrence
      t.json :exdates, null: false, default: []   # ISO 8601 starts of skipped occurrences
      t.json :reminders, null: false, default: [] # minutes before start
      t.string :color
      t.string :kind, null: false, default: "event" # "event" or "time_block"
      t.references :task, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :events, :starts_at
    add_index :events, :series_ends_at
    add_index :events, :kind
  end
end
