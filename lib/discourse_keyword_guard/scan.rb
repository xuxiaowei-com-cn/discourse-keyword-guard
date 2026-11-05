# frozen_string_literal: true

module ::DiscourseKeywordGuard
  # Re-scans content that was created or updated after the last cursor. This
  # catches records that existed before a keyword was added and records that
  # were written by imports or other validation bypasses.
  class Scan
    CURSOR_KEY = "keyword_guard_scan_cursor"
    BATCH_SIZE = 500

    def self.recent
      new(since: cursor || 1.hour.ago).run
    end

    def self.full
      new(since: Time.at(0)).run
    end

    def self.cursor
      value = PluginStore.get(PLUGIN_NAME, CURSOR_KEY)
      Time.zone.parse(value) if value.present?
    rescue ArgumentError
      nil
    end

    def initialize(since:)
      @since = since
    end

    def run
      started_at = Time.zone.now
      scan_users
      scan_user_profiles
      scan_chat_channels
      scan_chat_messages
      cleanup_old_hits
      PluginStore.set(PLUGIN_NAME, CURSOR_KEY, started_at.iso8601)
    rescue => e
      Rails.logger.warn(
        "[keyword-guard] Scan failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}",
      )
    end

    private

    def scan_users
      User
        .where("updated_at > ?", @since)
        .where.not(id: Discourse.system_user.id)
        .find_in_batches(batch_size: BATCH_SIZE) do |users|
          users.each do |user|
            next if Guard.exempt_user?(user)

            if user.username.present?
              Enforcer.after_publish(
                scope: :username,
                record: user,
                user: user,
                text: user.username,
              )
            end

            if user.name.present?
              Enforcer.after_publish(scope: :name, record: user, user: user, text: user.name)
            end
          end
        end
    end

    def scan_user_profiles
      UserProfile
        .where("updated_at > ?", @since)
        .find_in_batches(batch_size: BATCH_SIZE) do |profiles|
          profiles.each do |profile|
            user = profile.user
            next if user.blank? || profile.bio_raw.blank?

            Enforcer.after_publish(
              scope: :bio,
              record: profile,
              user: user,
              text: profile.bio_raw,
            )
          end
        end
    end

    def scan_chat_channels
      return if !defined?(::Chat::Channel)

      ::Chat::Channel
        .where("updated_at > ?", @since)
        .find_in_batches(batch_size: BATCH_SIZE) do |channels|
          channels.each do |channel|
            if channel.name.present?
              Enforcer.after_publish(
                scope: :chat_channel_name,
                record: channel,
                user: nil,
                text: channel.name,
              )
            end
          end
        end
    end

    def scan_chat_messages
      return if !defined?(::Chat::Message)

      ::Chat::Message
        .where("updated_at > ?", @since)
        .find_in_batches(batch_size: BATCH_SIZE) do |messages|
          messages.each do |message|
            next if message.message.blank?

            Enforcer.after_publish(
              scope: :chat_message,
              record: message,
              user: message.user,
              text: message.message,
            )
          end
        end
    end

    def cleanup_old_hits
      retention_days = SiteSetting.keyword_guard_hit_retention_days.to_i
      return if retention_days <= 0

      Hit.where("created_at < ?", retention_days.days.ago).delete_all
    end
  end
end
