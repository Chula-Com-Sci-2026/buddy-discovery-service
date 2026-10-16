class AddBuddiesAndOutbox < ActiveRecord::Migration[8.1]
  def change
    create_table :buddy_relationships, id: :uuid do |t|
      t.uuid :runner_a, null: false
      t.uuid :runner_b, null: false
      t.timestamps
    end
    add_index :buddy_relationships, [ :runner_a, :runner_b ], unique: true
    create_table :outbox_events, id: :uuid do |t|
      t.string :event_type, null: false
      t.jsonb :payload, null: false
      t.datetime :published_at
      t.timestamps
    end
  end
end
