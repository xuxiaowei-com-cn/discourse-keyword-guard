# frozen_string_literal: true

module ::DiscourseKeywordGuard
  module ChatMessageExtensions
    def self.prepended(base)
      base.validate :keyword_guard_validate_message,
                    if: :keyword_guard_validate_message?

      base.after_commit :keyword_guard_enforce_after_publish,
                        on: %i[create update],
                        if: :keyword_guard_message_saved_change?
    end

    def keyword_guard_validate_message?
      new_record? || will_save_change_to_message?
    end

    def keyword_guard_message_saved_change?
      saved_change_to_message?
    end

    def keyword_guard_validate_message
      DiscourseKeywordGuard::Validation.check(
        record: self,
        scope: :chat_message,
        text: message,
        attribute: :base,
        user: user,
        target: self,
        core_block: true,
      )
    end

    def keyword_guard_enforce_after_publish
      DiscourseKeywordGuard::Enforcer.after_publish(
        scope: :chat_message,
        record: self,
        user: user,
        text: message,
      )
    end
  end
end
