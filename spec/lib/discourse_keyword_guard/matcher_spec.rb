# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseKeywordGuard::Matcher do
  before do
    SiteSetting.keyword_guard_use_watched_words = true
    WatchedWord.create_or_update_word(word: "blockedword", action_key: "block")
    WatchedWord.create_or_update_word(word: "silentword", action_key: "silence")
    WordWatcher.clear_cache!
  end

  after do
    WatchedWord.where(word: %w[blockedword silentword]).destroy_all
    WordWatcher.clear_cache!
  end

  it "reads block words before publishing" do
    matcher = described_class.new("this contains blockedword")

    expect(matcher.block_matches.map(&:keyword)).to include("blockedword")
    expect(matcher.silence_matches).to be_empty
  end

  it "reads silence words for post-publication actions" do
    matcher = described_class.new("this contains silentword")

    expect(matcher.silence_matches.map(&:keyword)).to include("silentword")
  end

  it "does not match a Latin block word inside another word" do
    matcher = described_class.new("blockedwordinside")

    expect(matcher.block_matches).to be_empty
  end
end
