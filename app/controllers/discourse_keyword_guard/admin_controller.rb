# frozen_string_literal: true

module ::DiscourseKeywordGuard
  class AdminController < ::Admin::AdminController
    requires_plugin "discourse-keyword-guard"

    PAGE_SIZE = 50

    # Serves the Ember admin route. The route map and template live in
    # admin/assets/javascripts; this action only makes the URL addressable.
    def page
      respond_to do |format|
        format.html { render body: nil }
        format.json { raise Discourse::NotFound }
      end
    end

    def hits
      scope = Hit.includes(:user).order(created_at: :desc)
      scope = scope.where(scope: params[:scope]) if DiscourseKeywordGuard::SCOPES.include?(params[:scope])
      scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?

      page = [params[:page].to_i, 1].max
      total = scope.count
      hits = scope.offset((page - 1) * PAGE_SIZE).limit(PAGE_SIZE)

      render json: {
               hits: hits.map { |hit| serialize_hit(hit) },
               total: total,
               page: page,
               per_page: PAGE_SIZE,
               stats: stats,
             }
    end

    def scan
      mode = params[:mode] == "full" ? "full" : "recent"
      Jobs.enqueue(::Jobs::DiscourseKeywordGuard::Scan, mode: mode)

      render json: {
               success: true,
               mode: mode,
               message: I18n.t("keyword_guard.admin.scan_enqueued"),
             }
    end

    def test
      text = params[:text].to_s
      matcher = Matcher.new(text)

      render json: {
               block: serialize_matches(matcher.block_matches),
               silence: serialize_matches(matcher.silence_matches),
               blocked_message:
                 (
                   if matcher.block_matches.present?
                     Guard.blocked_message(matcher.block_matches)
                   end
                 ),
             }
    end

    def destroy
      deleted = Hit.delete_all
      render json: {
               success: true,
               deleted: deleted,
             }
    end

    private

    def stats
      now = Time.zone.now
      base = Hit.all

      {
        enabled: SiteSetting.keyword_guard_enabled,
        total: base.count,
        today: base.where("created_at > ?", now - 1.day).count,
        blocked: base.where(action: "blocked").count,
        silenced: base.where(action: %w[silenced silenced_and_deleted]).count,
        suspended: base.where(action: %w[suspended suspended_and_deleted]).count,
        watched_block_words:
          WatchedWord.where(action: WatchedWord.actions[:block]).count,
        watched_silence_words:
          WatchedWord.where(action: WatchedWord.actions[:silence]).count,
        extra_keywords: Rules.current.size,
        last_scan_at: PluginStore.get(PLUGIN_NAME, Scan::CURSOR_KEY),
      }
    end

    def serialize_hit(hit)
      {
        id: hit.id,
        scope: hit.scope,
        keyword: hit.keyword,
        matched_text: hit.matched_text,
        action: hit.action,
        username: hit.user&.username,
        user_id: hit.user_id,
        target_type: hit.target_type,
        target_id: hit.target_id,
        details: hit.details,
        created_at: hit.created_at.iso8601,
      }
    end

    def serialize_matches(matches)
      matches.map do |match|
        {
          keyword: match.keyword,
          matched_text: match.matched_text,
          source: match.source,
        }
      end
    end
  end
end
