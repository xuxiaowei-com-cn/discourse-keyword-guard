# frozen_string_literal: true

namespace :keyword_guard do
  desc "Scan all existing users, profiles, chat channels and chat messages for prohibited keywords"
  task scan: :environment do
    puts "Scanning all existing content. This may take a while..."
    DiscourseKeywordGuard::Scan.full
    puts "Done."
  end
end
