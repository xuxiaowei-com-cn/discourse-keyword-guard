# frozen_string_literal: true

class CreateKeywordGuardHits < ActiveRecord::Migration[8.0]
  def change
    create_table :keyword_guard_hits do |t|
      t.string :scope, null: false
      t.string :keyword, null: false
      t.text :matched_text
      t.bigint :user_id
      t.string :target_type
      t.bigint :target_id
      t.string :action, null: false, default: "blocked"
      t.jsonb :details, null: false, default: {}
      t.timestamps
    end

    add_index :keyword_guard_hits, :created_at
    add_index :keyword_guard_hits, %i[user_id created_at]
    add_index :keyword_guard_hits, %i[target_type target_id]
    add_index :keyword_guard_hits, %i[scope created_at]
    add_index :keyword_guard_hits, %i[action created_at]
  end
end
