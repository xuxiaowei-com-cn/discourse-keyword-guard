# frozen_string_literal: true

require "rails_helper"

RSpec.describe User do
  fab!(:user)

  before do
    SiteSetting.keyword_guard_enabled = true
    SiteSetting.keyword_guard_use_watched_words = true
    WatchedWord.create_or_update_word(word: "blockedname", action_key: "block")
    WordWatcher.clear_cache!
  end

  after do
    WatchedWord.where(word: "blockedname").destroy_all
    WordWatcher.clear_cache!
  end

  it "rejects a display name containing a block word" do
    user.name = "blockedname"

    expect(user).not_to be_valid
    expect(user.errors[:name]).to be_present
  end

  it "rejects a username containing a block word" do
    user.username = "blockedname"

    expect(user).not_to be_valid
  end
end
