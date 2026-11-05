# frozen_string_literal: true

module ::DiscourseKeywordGuard
  module UserExtensions
    def self.prepended(base)
      base.attr_accessor :keyword_guard_skip_validation

      base.validate :keyword_guard_validate_username, if: :will_save_change_to_username?
      base.validate :keyword_guard_validate_name, if: :will_save_change_to_name?

      base.after_commit :keyword_guard_enforce_after_publish,
                        on: %i[create update],
                        if: :keyword_guard_content_changed?
    end

    def keyword_guard_skip_validation?
      !!@keyword_guard_skip_validation
    end

    def keyword_guard_content_changed?
      saved_change_to_username? || saved_change_to_name?
    end

    def keyword_guard_validate_username
      return if keyword_guard_skip_validation?

      DiscourseKeywordGuard::Validation.check(
        record: self,
        scope: :username,
        text: username,
        attribute: :username,
        user: self,
        target: self,
        core_block: true,
      )
    end

    def keyword_guard_validate_name
      return if keyword_guard_skip_validation?

      DiscourseKeywordGuard::Validation.check(
        record: self,
        scope: :name,
        text: name,
        attribute: :name,
        user: self,
        target: self,
      )
    end

    def keyword_guard_enforce_after_publish
      return if keyword_guard_skip_validation?

      if saved_change_to_username?
        DiscourseKeywordGuard::Enforcer.after_publish(
          scope: :username,
          record: self,
          user: self,
          text: username,
        )
      end

      if saved_change_to_name?
        DiscourseKeywordGuard::Enforcer.after_publish(
          scope: :name,
          record: self,
          user: self,
          text: name,
        )
      end
    end
  end
end
