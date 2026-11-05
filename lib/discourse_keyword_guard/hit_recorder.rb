# frozen_string_literal: true

module ::DiscourseKeywordGuard
  # Persists one row per blocked/enforced scope so admins can audit what the
  # guard saw and which action was taken.
  module HitRecorder
    module_function

    def record(scope:, matches:, text:, user: nil, target: nil, action: "blocked")
      return if !SiteSetting.keyword_guard_log_hits
      return if matches.blank?

      matches = Array(matches).compact
      keyword_list = matches.map(&:keyword).uniq.join(", ")

      Hit.create!(
        scope: scope.to_s,
        keyword: keyword_list.truncate(255),
        matched_text: text.to_s.truncate(1000),
        user_id: user&.id,
        target_type: target&.class&.name,
        target_id: target&.id,
        action: action.to_s,
        details: {
          sources: matches.map(&:source).compact.uniq,
          matches:
            matches.map do |match|
              {
                keyword: match.keyword,
                matched_text: match.matched_text,
                source: match.source,
              }
            end,
        },
      )
    rescue => e
      Rails.logger.warn(
        "[keyword-guard] Failed to record hit (#{scope}, #{action}): #{e.class}: #{e.message}",
      )
      nil
    end
  end
end
