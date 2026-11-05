# frozen_string_literal: true

module ::DiscourseKeywordGuard
  class Hit < ActiveRecord::Base
    self.table_name = "keyword_guard_hits"

    belongs_to :user, optional: true

    validates :scope, presence: true, inclusion: { in: ::DiscourseKeywordGuard::SCOPES }
    validates :action, presence: true, inclusion: { in: ::DiscourseKeywordGuard::ACTIONS }

    scope :recent, -> { order(created_at: :desc) }
  end
end

# == Schema Information
#
# Table name: keyword_guard_hits
#
#  id           :bigint           not null, primary key
#  action       :string           default("blocked"), not null
#  details      :jsonb            not null
#  keyword      :string           not null
#  matched_text :text
#  scope        :string           not null
#  target_type  :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  target_id    :bigint
#  user_id      :bigint
#
# Indexes
#
#  index_keyword_guard_hits_on_action_and_created_at      (action,created_at)
#  index_keyword_guard_hits_on_created_at                 (created_at)
#  index_keyword_guard_hits_on_scope_and_created_at       (scope,created_at)
#  index_keyword_guard_hits_on_target_type_and_target_id  (target_type,target_id)
#  index_keyword_guard_hits_on_user_id_and_created_at     (user_id,created_at)
#
