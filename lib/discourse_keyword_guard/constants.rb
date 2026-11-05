# frozen_string_literal: true

module ::DiscourseKeywordGuard
  SCOPES = %w[username name bio chat_channel_name chat_message].freeze
  ACTIONS = %w[
    blocked
    logged
    silenced
    silenced_and_deleted
    suspended
    suspended_and_deleted
  ].freeze
  MAX_KEYWORDS = 1000
  ZERO_WIDTH_CHARACTERS = /[\u200B-\u200D\u2060\uFEFF]/
end
