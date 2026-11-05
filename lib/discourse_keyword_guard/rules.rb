# frozen_string_literal: true

module ::DiscourseKeywordGuard
  # Compiles the optional extra keyword list into matchers.
  #
  # Supported line formats:
  #
  #   plain text           matched according to keyword_guard_extra_match_mode
  #   re:<regular expr>    always treated as a regular expression
  #   # comment            ignored
  #   \#literal            a literal keyword starting with "#"
  #
  # Substring mode is the default because it is the only mode that reliably
  # works for languages without word separators, such as Chinese.
  class Rules
    Entry = Struct.new(:type, :keyword, :regexp, :normalized, keyword_init: true)
    Match = Struct.new(:keyword, :matched_text, keyword_init: true)

    attr_reader :mode, :case_sensitive, :entries

    class << self
      def current
        signature = [
          SiteSetting.keyword_guard_extra_keywords.to_s,
          SiteSetting.keyword_guard_extra_match_mode.to_s,
          SiteSetting.keyword_guard_extra_case_sensitive.to_s,
        ].join("\u0000")

        if @signature != signature
          @current =
            new(
              raw: SiteSetting.keyword_guard_extra_keywords,
              mode: SiteSetting.keyword_guard_extra_match_mode,
              case_sensitive: SiteSetting.keyword_guard_extra_case_sensitive,
            )
          @signature = signature
        end

        @current
      end

      def reset!
        @current = nil
        @signature = nil
      end
    end

    def initialize(raw:, mode:, case_sensitive:)
      @mode = (mode.presence || "substring").to_s
      @case_sensitive = !!case_sensitive
      @entries = parse(raw)
    end

    def empty?
      entries.empty?
    end

    def size
      entries.size
    end

    def match(text)
      return [] if text.blank? || entries.empty?

      # Substring and word matchers compare case-folded text. Regular
      # expressions run against NFKC-normalized text and use the IGNORECASE
      # flag so that inline regexp features keep working as expected.
      plain_text = Guard.normalize(text, downcase: !case_sensitive)
      regexp_text = Guard.normalize(text, downcase: false)

      entries.filter_map do |entry|
        case entry.type
        when :substring
          if plain_text.include?(entry.normalized)
            Match.new(keyword: entry.keyword, matched_text: entry.keyword)
          end
        when :word
          if (matched = entry.regexp.match(plain_text))
            Match.new(keyword: entry.keyword, matched_text: matched[0])
          end
        when :regex
          if (matched = entry.regexp.match(regexp_text))
            Match.new(keyword: entry.keyword, matched_text: matched[0])
          end
        end
      end
    end

    private

    def parse(raw)
      seen = Set.new

      raw
        .to_s
        .each_line
        .filter_map do |line|
          line = line.strip
          next if line.blank?
          next if line.start_with?("#")

          literal_hash = line.start_with?("\\#")
          line = line[1..] if literal_hash

          type = :substring
          if !literal_hash && line.match?(/\Are:/i)
            type = :regex
            line = line.sub(/\Are:/i, "").strip
          elsif mode == "regex"
            type = :regex
          elsif mode == "word"
            type = :word
          end

          next if line.blank?

          key = [type, case_sensitive ? line : line.downcase]
          next if seen.include?(key)

          seen << key
          build_entry(type, line)
        end
        .first(MAX_KEYWORDS)
    end

    def build_entry(type, source)
      normalized = Guard.normalize(source, downcase: !case_sensitive)

      regexp =
        case type
        when :word
          Regexp.new(
            "(?<![\\p{L}\\p{N}_])#{Regexp.escape(normalized)}(?![\\p{L}\\p{N}_])",
          )
        when :regex
          Regexp.new(source, case_sensitive ? nil : Regexp::IGNORECASE)
        end

      Entry.new(type: type, keyword: source, regexp: regexp, normalized: normalized)
    rescue RegexpError => e
      Rails.logger.warn(
        "[keyword-guard] Ignoring invalid regular expression #{source.inspect}: #{e.message}",
      )
      nil
    end
  end
end
