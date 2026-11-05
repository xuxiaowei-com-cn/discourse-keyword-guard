# frozen_string_literal: true

# name: discourse-keyword-guard
# about: Blocks prohibited keywords in usernames, display names, bios, chat channel names and chat messages, and can suspend authors after publication.
# version: 0.1.0
# authors: 徐晓伟
# url: https://cnb.cool/xuxiaowei.com.cn/discourse-keyword-guard
# required_version: 3.2.0

enabled_site_setting :keyword_guard_enabled

add_admin_route "keyword_guard.title", "discourse-keyword-guard", use_new_show_route: true

register_svg_icon "shield-halved"
register_svg_icon "user-shield"

register_asset "stylesheets/admin/keyword-guard.scss", :admin

module ::DiscourseKeywordGuard
  PLUGIN_NAME = "discourse-keyword-guard"
end

require_relative "lib/discourse_keyword_guard/constants"
require_relative "lib/discourse_keyword_guard/engine"

after_initialize do
  require_relative "lib/discourse_keyword_guard/guard"
  require_relative "lib/discourse_keyword_guard/rules"
  require_relative "lib/discourse_keyword_guard/matcher"
  require_relative "app/models/discourse_keyword_guard/hit"
  require_relative "lib/discourse_keyword_guard/hit_recorder"
  require_relative "lib/discourse_keyword_guard/validation"
  require_relative "lib/discourse_keyword_guard/enforcer"
  require_relative "lib/discourse_keyword_guard/scan"
  require_relative "lib/discourse_keyword_guard/user_extensions"
  require_relative "lib/discourse_keyword_guard/user_profile_extensions"
  require_relative "lib/discourse_keyword_guard/chat_channel_extensions"
  require_relative "lib/discourse_keyword_guard/chat_message_extensions"

  reloadable_patch do
    ::User.prepend(DiscourseKeywordGuard::UserExtensions)
    ::UserProfile.prepend(DiscourseKeywordGuard::UserProfileExtensions)

    if defined?(::Chat::Channel)
      ::Chat::Channel.prepend(DiscourseKeywordGuard::ChatChannelExtensions)
    end

    if defined?(::Chat::Message)
      ::Chat::Message.prepend(DiscourseKeywordGuard::ChatMessageExtensions)
    end
  end

  # The compiled keyword list is cached in memory. Invalidate it whenever a
  # setting that affects matching or scope selection changes.
  on(:site_setting_changed) do |name, _old_value, _new_value|
    DiscourseKeywordGuard::Rules.reset! if name.to_s.start_with?("keyword_guard_")
  end
end
