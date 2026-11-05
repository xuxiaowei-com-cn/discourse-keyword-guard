# frozen_string_literal: true

module ::DiscourseKeywordGuard
  # Applies post-publication actions. Normal requests are stopped by model
  # validations; this path handles content that was created before a word was
  # added, imported content, and any code path that bypasses validations.
  class Enforcer
    def self.after_publish(scope:, record:, user:, text:)
      return if !SiteSetting.keyword_guard_enabled
      return if !Guard.enabled_for_scope?(scope)

      matcher = Matcher.new(text)
      return if !matcher.any?

      new(scope: scope, record: record, user: user, text: text, matcher: matcher).enforce
    end

    def initialize(scope:, record:, user:, text:, matcher:)
      @scope = scope.to_s
      @record = record
      @user = user
      @text = text.to_s
      @matcher = matcher
    end

    def enforce
      return if @user.present? && Guard.exempt_user?(@user)
      return if already_penalized?
      return if already_logged_recently?

      block_action =
        @matcher.block_matches.present? ? SiteSetting.keyword_guard_block_action.to_s : nil
      silence_action =
        @matcher.silence_matches.present? ? SiteSetting.keyword_guard_silence_action.to_s : nil

      if block_action&.start_with?("suspend")
        perform_suspend(delete: block_action == "suspend_and_delete")
      elsif silence_action&.start_with?("silence")
        perform_silence(delete: silence_action == "silence_and_delete")
      elsif block_action == "silence"
        perform_silence(delete: false)
      else
        record_action("logged")
      end
    end

    private

    def all_matches
      @all_matches ||= @matcher.block_matches + @matcher.silence_matches
    end

    def perform_suspend(delete:)
      if !suspendable?
        return record_action("logged")
      end

      if suspend_user
        deleted = delete && delete_content
        record_action(deleted ? "suspended_and_deleted" : "suspended")
        notify_moderators("suspended")
      else
        record_action("logged")
      end
    end

    def perform_silence(delete:)
      if !silenceable?
        return record_action("logged")
      end

      if silence_user
        deleted = delete && delete_content
        record_action(deleted ? "silenced_and_deleted" : "silenced")
      else
        record_action("logged")
      end
    end

    def record_action(action)
      HitRecorder.record(
        scope: @scope,
        matches: all_matches,
        text: @text,
        user: @user,
        target: @record,
        action: action,
      )
      notify_moderators(action) if action == "logged"
      action
    end

    def suspendable?
      @user.present? && @user.regular? && !@user.suspended?
    end

    def silenceable?
      @user.present? && @user.regular? && !@user.silenced?
    end

    def suspend_user
      with_validation_skipped do
        UserSuspender.new(
          @user,
          suspended_till: suspend_days.days.from_now,
          reason: reason(:suspend),
          by_user: Discourse.system_user,
          message: suspension_message,
        ).suspend
      end
      true
    rescue => e
      Rails.logger.warn(
        "[keyword-guard] Failed to suspend user #{@user&.id}: #{e.class}: #{e.message}",
      )
      false
    end

    def silence_user
      silencer = nil

      with_validation_skipped do
        silencer =
          UserSilencer.new(
            @user,
            Discourse.system_user,
            keep_posts: true,
            silenced_till: silence_days.days.from_now,
            reason: reason(:silence),
          )

        return false if !silencer.auto_silence
      end

      if SiteSetting.keyword_guard_notify_user && silencer&.user_history.present?
        Jobs.enqueue(
          :critical_user_email,
          type: "account_silenced",
          user_id: @user.id,
          user_history_id: silencer.user_history.id,
        )
      end
      true
    rescue => e
      Rails.logger.warn(
        "[keyword-guard] Failed to silence user #{@user&.id}: #{e.class}: #{e.message}",
      )
      false
    end

    # Suspending or silencing a user whose username contains a blocked word
    # must still be able to save the penalty. Skip both the plugin validation
    # and Discourse's built-in username watched-word validation for this
    # internal save only.
    def with_validation_skipped
      @user.keyword_guard_skip_validation = true
      if @user.respond_to?(:skip_username_watched_words_validation=)
        @user.skip_username_watched_words_validation = true
      end
      yield
    ensure
      @user.keyword_guard_skip_validation = false
      if @user.respond_to?(:skip_username_watched_words_validation=)
        @user.skip_username_watched_words_validation = false
      end
    end

    def delete_content
      return false if !defined?(::Chat::Message) || !@record.is_a?(::Chat::Message)
      return false if @record.id.blank?

      ::Chat::MessageDestroyer.new.destroy_in_batches(::Chat::Message.where(id: @record.id))
      !::Chat::Message.where(id: @record.id).exists?
    rescue => e
      Rails.logger.warn(
        "[keyword-guard] Failed to delete chat message #{@record&.id}: #{e.class}: #{e.message}",
      )
      false
    end

    def suspend_days
      SiteSetting.keyword_guard_suspend_days.to_i.clamp(1, 36_500)
    end

    def silence_days
      SiteSetting.keyword_guard_silence_days.to_i.clamp(1, 36_500)
    end

    # The user-facing reason is deliberately generic. The matched keyword is
    # stored only in the audit hit and in the moderator notification, never in
    # the suspension/silence email, so the filter cannot be reverse engineered
    # from an automated message.
    def reason(action)
      I18n.t("keyword_guard.moderation.#{action}_reason").truncate(300)
    end

    def suspension_message
      return nil if !SiteSetting.keyword_guard_notify_user

      SiteSetting.keyword_guard_suspend_message.presence ||
        I18n.t("keyword_guard.moderation.suspension_message")
    end

    def already_penalized?
      return false if @record.blank? || @record.id.blank?

      Hit
        .where(
          scope: @scope,
          target_type: @record.class.name,
          target_id: @record.id,
          action: %w[silenced silenced_and_deleted suspended suspended_and_deleted],
        )
        .exists?
    end

    # Avoid writing the same "logged only" audit row on every scheduled scan.
    def already_logged_recently?
      return false if @record.blank? || @record.id.blank?

      Hit
        .where(
          scope: @scope,
          target_type: @record.class.name,
          target_id: @record.id,
          action: "logged",
        )
        .where("created_at > ?", 1.day.ago)
        .exists?
    end

    def notify_moderators(action)
      return if !SiteSetting.keyword_guard_notify_moderators

      params = {
        scope: I18n.t("keyword_guard.scopes.#{@scope}"),
        keywords: Guard.keywords_for_message(all_matches),
        action: I18n.t("keyword_guard.actions.#{action}"),
      }

      opts = { limit_once_per: 1.hour, message_params: params }
      opts[:user] = @user if @user.present?

      GroupMessage.create(Group[:moderators].name, :keyword_guard_hit, opts)
    rescue => e
      Rails.logger.warn(
        "[keyword-guard] Failed to notify moderators: #{e.class}: #{e.message}",
      )
    end
  end
end
