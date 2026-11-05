# frozen_string_literal: true

module ::DiscourseKeywordGuard
  module ChatChannelExtensions
    def self.prepended(base)
      base.validate :keyword_guard_validate_name, if: :will_save_change_to_name?
      base.validate :keyword_guard_validate_slug, if: :will_save_change_to_slug?

      base.after_commit :keyword_guard_enforce_after_publish,
                        on: %i[create update],
                        if: :keyword_guard_channel_content_changed?
    end

    def keyword_guard_channel_content_changed?
      saved_change_to_name? || saved_change_to_slug?
    end

    def keyword_guard_validate_name
      DiscourseKeywordGuard::Validation.check(
        record: self,
        scope: :chat_channel_name,
        text: name,
        attribute: :name,
        target: self,
      )
    end

    def keyword_guard_validate_slug
      return if slug.blank?

      DiscourseKeywordGuard::Validation.check(
        record: self,
        scope: :chat_channel_name,
        text: slug,
        attribute: :slug,
        target: self,
      )
    end

    def keyword_guard_enforce_after_publish
      text = saved_change_to_name? ? name : slug

      DiscourseKeywordGuard::Enforcer.after_publish(
        scope: :chat_channel_name,
        record: self,
        user: nil,
        text: text,
      )
    end
  end
end
