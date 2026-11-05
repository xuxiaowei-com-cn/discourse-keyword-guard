# frozen_string_literal: true

module ::DiscourseKeywordGuard
  # Model validation helpers shared by User, UserProfile, Chat::Channel and
  # Chat::Message.
  module Validation
    module_function

    # Adds an error and records an audit hit when the content contains a
    # prohibited keyword.
    #
    # `core_block` is true for models where Discourse's built-in
    # WatchedWordsValidator already reports blocked words (UserProfile#bio_raw
    # and Chat::Message#message). In that case only the optional extra
    # keywords are added to the model errors to avoid duplicate messages; the
    # built-in matches are still recorded for auditing.
    def check(record:, scope:, text:, attribute:, user: nil, target: nil, core_block: false)
      return true if !Guard.enabled_for_scope?(scope)
      return true if Guard.exempt_user?(user)

      block_matches = Matcher.new(text).block_matches
      return true if block_matches.empty?

      record_hit(record, scope, text, block_matches, user, target)

      error_matches =
        if core_block
          block_matches.reject { |match| match.source == :watched_word_block }
        else
          block_matches
        end
      return true if error_matches.empty?

      record.errors.add(attribute, Guard.blocked_message(error_matches))
      false
    end

    def record_hit(record, scope, text, matches, user, target)
      recorded = record.instance_variable_get(:@keyword_guard_recorded_scopes) || {}
      return if recorded[scope.to_s]

      recorded[scope.to_s] = true
      record.instance_variable_set(:@keyword_guard_recorded_scopes, recorded)

      HitRecorder.record(
        scope: scope,
        matches: matches,
        text: text,
        user: user,
        target: target,
        action: "blocked",
      )
    end
  end
end
