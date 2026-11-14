class AddNoteToBuddyRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :buddy_requests, :note, :string, limit: 180
  end
end
