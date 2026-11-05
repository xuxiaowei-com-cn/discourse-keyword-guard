# frozen_string_literal: true

module Jobs
  module DiscourseKeywordGuard
    class Scan < ::Jobs::Base
      sidekiq_options retry: 1

      def execute(args = {})
        return if !SiteSetting.keyword_guard_enabled

        case args["mode"].presence || args[:mode].presence || "recent"
        when "full"
          DiscourseKeywordGuard::Scan.full
        else
          DiscourseKeywordGuard::Scan.recent
        end
      end
    end
  end
end
