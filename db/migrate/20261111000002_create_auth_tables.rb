class CreateAuthTables < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys do |t|
      t.string :name, null: false
      t.string :prefix, null: false
      t.string :token_digest, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :api_keys, :token_digest, unique: true

    create_table :oauth_clients do |t|
      t.string :client_id, null: false
      t.string :name, null: false
      t.json :redirect_uris, null: false, default: []
      t.json :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :oauth_clients, :client_id, unique: true

    create_table :oauth_authorization_codes do |t|
      t.references :oauth_client, null: false, foreign_key: { on_delete: :cascade }
      t.string :code_digest, null: false
      t.string :redirect_uri, null: false
      t.string :code_challenge, null: false
      t.string :scope
      t.string :resource
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end
    add_index :oauth_authorization_codes, :code_digest, unique: true

    create_table :oauth_tokens do |t|
      t.references :oauth_client, null: false, foreign_key: { on_delete: :cascade }
      t.string :access_digest, null: false
      t.string :refresh_digest, null: false
      t.string :scope
      t.string :resource
      t.datetime :access_expires_at, null: false
      t.datetime :refresh_expires_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :oauth_tokens, :access_digest, unique: true
    add_index :oauth_tokens, :refresh_digest, unique: true

    create_table :app_settings do |t|
      t.string :key, null: false
      t.text :value
      t.timestamps
    end
    add_index :app_settings, :key, unique: true
  end
end
