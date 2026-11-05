# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseKeywordGuard::Rules do
  before do
    SiteSetting.keyword_guard_extra_keywords = "违禁词\nre:spam\\d+"
    SiteSetting.keyword_guard_extra_match_mode = "substring"
    SiteSetting.keyword_guard_extra_case_sensitive = false
    described_class.reset!
  end

  after do
    SiteSetting.keyword_guard_extra_keywords = ""
    described_class.reset!
  end

  it "matches Chinese substrings" do
    matches = described_class.current.match("这是违禁词测试")

    expect(matches.map(&:keyword)).to eq(["违禁词"])
  end

  it "supports re: regular expressions" do
    matches = described_class.current.match("spam123")

    expect(matches.map(&:keyword)).to eq(["spam\\d+"])
  end

  it "ignores comments and blank lines" do
    SiteSetting.keyword_guard_extra_keywords = "# comment\n\n违禁词"
    described_class.reset!

    expect(described_class.current.match("违禁词").size).to eq(1)
  end
end
