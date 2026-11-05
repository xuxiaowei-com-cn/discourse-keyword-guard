# frozen_string_literal: true

module ::DiscourseKeywordGuard
  module UserProfileExtensions
    def self.prepended(base)
      base.validate :keyword_guard_validate_bio, if: :will_save_change_to_bio_raw?

      base.after_commit :keyword_guard_enforce_bio,
                        on: %i[create update],
                        if: :keyword_guard_bio_changed?
    end

    def keyword_guard_bio_changed?
      saved_change_to_bio_raw?
    end

    def keyword_guard_validate_bio
      DiscourseKeywordGuard::Validation.check(
        record: self,
        scope: :bio,
        text: bio_raw,
        attribute: :bio_raw,
        user: user,
        target: self,
        core_block: true,
      )
    end

    def keyword_guard_enforce_bio
      DiscourseKeywordGuard::Enforcer.after_publish(
        scope: :bio,
        record: self,
        user: user,
        text: bio_raw,
      )
    end
  end
end
