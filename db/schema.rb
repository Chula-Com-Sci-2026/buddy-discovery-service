# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_11_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "buddy_relationships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "runner_a", null: false
    t.uuid "runner_b", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["runner_a", "runner_b"], name: "index_buddy_relationships_on_runner_a_and_runner_b", unique: true
  end

  create_table "buddy_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "sender_id", null: false
    t.uuid "recipient_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "note", limit: 180
    t.index ["recipient_id"], name: "index_buddy_requests_on_recipient_id"
    t.index ["sender_id", "recipient_id"], name: "index_unique_pending_buddy_requests", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["sender_id"], name: "index_buddy_requests_on_sender_id"
  end

  create_table "outbox_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "event_type", null: false
    t.jsonb "payload", null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
