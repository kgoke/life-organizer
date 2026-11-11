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

ActiveRecord::Schema[8.1].define(version: 2026_11_11_000003) do
  create_table "api_keys", force: :cascade do |t|
    t.string "name", null: false
    t.string "prefix", null: false
    t.string "token_digest", null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_api_keys_on_token_digest", unique: true
  end

  create_table "app_settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_app_settings_on_key", unique: true
  end

  create_table "calendars", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", default: "#3b6ef5", null: false
    t.boolean "is_default", default: false, null: false
    t.boolean "include_in_feed", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "events", force: :cascade do |t|
    t.integer "calendar_id", null: false
    t.string "title", null: false
    t.text "description", default: "", null: false
    t.string "location", default: "", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.datetime "series_ends_at"
    t.string "time_zone", null: false
    t.boolean "all_day", default: false, null: false
    t.string "recurrence"
    t.json "exdates", default: [], null: false
    t.json "reminders", default: [], null: false
    t.string "color"
    t.string "kind", default: "event", null: false
    t.integer "task_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_id"], name: "index_events_on_calendar_id"
    t.index ["kind"], name: "index_events_on_kind"
    t.index ["series_ends_at"], name: "index_events_on_series_ends_at"
    t.index ["starts_at"], name: "index_events_on_starts_at"
    t.index ["task_id"], name: "index_events_on_task_id"
  end

  create_table "jots", force: :cascade do |t|
    t.text "body", null: false
    t.boolean "pinned", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pinned", "updated_at"], name: "index_jots_on_pinned_and_updated_at"
  end

  create_table "oauth_authorization_codes", force: :cascade do |t|
    t.integer "oauth_client_id", null: false
    t.string "code_digest", null: false
    t.string "redirect_uri", null: false
    t.string "code_challenge", null: false
    t.string "scope"
    t.string "resource"
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code_digest"], name: "index_oauth_authorization_codes_on_code_digest", unique: true
    t.index ["oauth_client_id"], name: "index_oauth_authorization_codes_on_oauth_client_id"
  end

  create_table "oauth_clients", force: :cascade do |t|
    t.string "client_id", null: false
    t.string "name", null: false
    t.json "redirect_uris", default: [], null: false
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_oauth_clients_on_client_id", unique: true
  end

  create_table "oauth_tokens", force: :cascade do |t|
    t.integer "oauth_client_id", null: false
    t.string "access_digest", null: false
    t.string "refresh_digest", null: false
    t.string "scope"
    t.string "resource"
    t.datetime "access_expires_at", null: false
    t.datetime "refresh_expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_digest"], name: "index_oauth_tokens_on_access_digest", unique: true
    t.index ["oauth_client_id"], name: "index_oauth_tokens_on_oauth_client_id"
    t.index ["refresh_digest"], name: "index_oauth_tokens_on_refresh_digest", unique: true
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.string "color", default: "#5b8def", null: false
    t.boolean "archived", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tasks", force: :cascade do |t|
    t.string "title", null: false
    t.text "notes", default: "", null: false
    t.string "status", default: "todo", null: false
    t.integer "priority", default: 0, null: false
    t.date "due_date"
    t.string "due_time"
    t.integer "estimate_minutes"
    t.integer "project_id"
    t.integer "parent_id"
    t.json "tags", default: [], null: false
    t.string "recurrence"
    t.integer "position", default: 0, null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["due_date"], name: "index_tasks_on_due_date"
    t.index ["parent_id"], name: "index_tasks_on_parent_id"
    t.index ["project_id"], name: "index_tasks_on_project_id"
    t.index ["status"], name: "index_tasks_on_status"
  end

  add_foreign_key "events", "calendars", on_delete: :cascade
  add_foreign_key "events", "tasks", on_delete: :cascade
  add_foreign_key "oauth_authorization_codes", "oauth_clients", on_delete: :cascade
  add_foreign_key "oauth_tokens", "oauth_clients", on_delete: :cascade
  add_foreign_key "tasks", "projects", on_delete: :nullify
  add_foreign_key "tasks", "tasks", column: "parent_id", on_delete: :cascade
end
