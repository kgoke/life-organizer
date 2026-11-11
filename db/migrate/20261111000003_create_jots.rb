class CreateJots < ActiveRecord::Migration[8.1]
  def change
    create_table :jots do |t|
      t.text :body, null: false
      t.boolean :pinned, null: false, default: false
      t.timestamps
    end
    add_index :jots, [ :pinned, :updated_at ]
  end
end
