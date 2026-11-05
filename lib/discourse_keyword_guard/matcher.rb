# frozen_string_literal: true

module ::DiscourseKeywordGuard
  # Combines Discourse's built-in watched words with the optional extra keyword
  # list configured in the plugin settings.
  #
  # The two watched-word actions map naturally to the two halves of the guard:
  #
  #   /admin/customize/watched_words/action/block    -> reject before publish
  #   /admin/customize/watched_words/action/silence  -> act after publish
  class Matcher
    Match = Struct.new(:keyword, :matched_text, :source, :action, keyword_init: true)

    def initialize(text)
      @text = text.to_s
    end

    # Words that must never be published. This includes watched words with the
    # "block" action and the optional extra keywords.
    def block_matches
      @block_matches ||= watched_matches(:block) + extra_matches
    end

    # Words that trigger a post-publication action.
    def silence_matches
      @silence_matches ||= watched_matches(:silence)
    end

    def extra_matches
      return [] if !SiteSetting.keyword_guard_extra_keywords.present?

      @extra_matches ||=
        Rules.current.match(@text).map do |match|
          Match.new(
            keyword: match.keyword,
            matched_text: match.matched_text,
            source: :extra_keyword,
            action: :block,
          )
        end
    end

    def any?
      block_matches.present? || silence_matches.present?
    end

    private

    def watched_matches(action)
      return [] if !SiteSetting.keyword_guard_use_watched_words

      watcher = WordWatcher.new(@text)

      words =
        if action == :block
          watcher.should_block?
        else
          result = watcher.should_silence?
          result.is_a?(MatchData) ? [result[0]] : Array(result)
        end

      Array(words)
        .compact
        .uniq
        .map do |word|
          Match.new(
            keyword: word.to_s,
            matched_text: word.to_s,
            source: :"watched_word_#{action}",
            action: action,
          )
        end
    end
  end
end
