class CreateBuddyRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :buddy_requests, id: :uuid do |t|
      t.uuid :sender_id, null: false
      t.uuid :recipient_id, null: false
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_index :buddy_requests, :sender_id
    add_index :buddy_requests, :recipient_id
    add_index :buddy_requests, %i[sender_id recipient_id],
              unique: true,
              where: "status = 'pending'",
              name: "index_unique_pending_buddy_requests"
  end
end
