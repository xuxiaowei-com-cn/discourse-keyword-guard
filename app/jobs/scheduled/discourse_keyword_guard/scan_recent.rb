# frozen_string_literal: true

module Jobs
  module DiscourseKeywordGuard
    class ScanRecent < ::Jobs::Scheduled
      every 10.minutes

      def execute(args = {})
        return if !SiteSetting.keyword_guard_enabled

        DiscourseKeywordGuard::Scan.recent
      end
    end
  end
end
