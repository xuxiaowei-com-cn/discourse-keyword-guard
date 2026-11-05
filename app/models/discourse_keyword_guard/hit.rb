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
