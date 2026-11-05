# frozen_string_literal: true

module ::DiscourseKeywordGuard
  # Shared helpers for keyword matching and user exemptions.
  module Guard
    module_function

    def enabled_for_scope?(scope)
      return false if !SiteSetting.keyword_guard_enabled
      return false if !SCOPES.include?(scope.to_s)

      SiteSetting.public_send("keyword_guard_scope_#{scope}") == true
    end

    def exempt_user?(user)
      return false if user.blank?

      if user.id.present?
        return true if user.id == Discourse.system_user.id
        return true if user.respond_to?(:bot?) && user.bot?
      end

      if SiteSetting.keyword_guard_exempt_staff && user.respond_to?(:staff?) && user.staff?
        return true
      end

      exempt_usernames =
        SiteSetting
          .keyword_guard_exempt_usernames
          .to_s
          .split(/[\s,|]+/)
          .reject(&:blank?)
          .map(&:downcase)

      if user.respond_to?(:username) && user.username.present?
        return true if exempt_usernames.include?(user.username.downcase)
      end

      exempt_groups = SiteSetting.keyword_guard_exempt_groups_map
      if exempt_groups.present? && user.respond_to?(:in_any_groups?)
        return true if user.in_any_groups?(exempt_groups)
      end

      false
    end

    # NFKC folds full-width Latin characters into their ASCII equivalents and
    # removes zero-width characters that are commonly used to evade filters.
    def normalize(text, downcase: true)
      value = text.to_s.unicode_normalize(:nfkc).gsub(ZERO_WIDTH_CHARACTERS, "")
      downcase ? value.downcase : value
    end

    def blocked_message(matches)
      keywords = SiteSetting.keyword_guard_show_keywords ? describe_matches(matches) : "-"
      I18n.t("keyword_guard.errors.blocked", keywords: keywords)
    end

    def describe_matches(matches)
      keywords = matches.map(&:keyword).uniq
      shown = keywords.first(3).map { |keyword| CGI.escapeHTML(keyword.to_s) }

      text = shown.join(I18n.t("keyword_guard.list_separator"))
      if keywords.size > 3
        text += I18n.t("keyword_guard.more_keywords", count: keywords.size - 3)
      end
      text
    end

    def keywords_for_message(matches)
      matches.map(&:keyword).uniq.map(&:to_s).join(", ")
    end
  end
end
