import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default <template>
  <section class="admin-detail keyword-guard">
    <DPageSubheader
      @descriptionLabel={{i18n "keyword_guard.admin.description"}}
      @titleLabel={{i18n "keyword_guard.admin.title"}}
    >
      <:actions as |actions|>
        <actions.Default
          @action={{@controller.scan}}
          @icon="magnifying-glass"
          @label="keyword_guard.admin.scan"
        />
        <actions.Default
          @action={{@controller.refresh}}
          @icon="arrows-rotate"
          @label="keyword_guard.admin.refresh"
        />
        {{#if @controller.hits.length}}
          <actions.Danger
            @action={{@controller.clear}}
            @icon="trash-can"
            @label="keyword_guard.admin.clear"
          />
        {{/if}}
      </:actions>
    </DPageSubheader>

    <div class="keyword-guard__links">
      <a href="/admin/customize/watched_words/action/block">
        {{i18n "keyword_guard.admin.watched_words"}}
      </a>
      <a href="/admin/plugins/discourse-keyword-guard/settings">
        {{i18n "keyword_guard.admin.settings"}}
      </a>
    </div>

    <div class="keyword-guard__stats">
      <div class="keyword-guard__stat">
        <span class="keyword-guard__stat-value">{{@controller.stats.total}}</span>
        <span class="keyword-guard__stat-label">{{i18n
            "keyword_guard.admin.total"
          }}</span>
      </div>
      <div class="keyword-guard__stat">
        <span class="keyword-guard__stat-value">{{@controller.stats.today}}</span>
        <span class="keyword-guard__stat-label">{{i18n
            "keyword_guard.admin.today"
          }}</span>
      </div>
      <div class="keyword-guard__stat">
        <span class="keyword-guard__stat-value">{{@controller.stats.blocked}}</span>
        <span class="keyword-guard__stat-label">{{i18n
            "keyword_guard.admin.blocked"
          }}</span>
      </div>
      <div class="keyword-guard__stat">
        <span class="keyword-guard__stat-value">{{@controller.stats.silenced}}</span>
        <span class="keyword-guard__stat-label">{{i18n
            "keyword_guard.admin.silenced"
          }}</span>
      </div>
      <div class="keyword-guard__stat">
        <span class="keyword-guard__stat-value">{{@controller.stats.suspended}}</span>
        <span class="keyword-guard__stat-label">{{i18n
            "keyword_guard.admin.suspended"
          }}</span>
      </div>
      <div class="keyword-guard__stat">
        <span class="keyword-guard__stat-value">{{@controller.stats.watched_block_words}}</span>
        <span class="keyword-guard__stat-label">{{i18n
            "keyword_guard.admin.watched_block"
          }}</span>
      </div>
      <div class="keyword-guard__stat">
        <span class="keyword-guard__stat-value">{{@controller.stats.watched_silence_words}}</span>
        <span class="keyword-guard__stat-label">{{i18n
            "keyword_guard.admin.watched_silence"
          }}</span>
      </div>
    </div>

    {{#if @controller.hits.length}}
      <table class="d-table keyword-guard__table">
        <thead>
          <tr>
            <th>{{i18n "keyword_guard.admin.columns.time"}}</th>
            <th>{{i18n "keyword_guard.admin.columns.scope"}}</th>
            <th>{{i18n "keyword_guard.admin.columns.keyword"}}</th>
            <th>{{i18n "keyword_guard.admin.columns.user"}}</th>
            <th>{{i18n "keyword_guard.admin.columns.action"}}</th>
            <th>{{i18n "keyword_guard.admin.columns.content"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each @controller.hits as |hit|}}
            <tr class="d-table__row">
              <td>{{dFormatDate hit.created_at}}</td>
              <td>{{hit.scopeLabel}}</td>
              <td>{{hit.keyword}}</td>
              <td>
                {{#if hit.username}}
                  <a href="/u/{{hit.username}}">{{hit.username}}</a>
                {{else}}
                  -
                {{/if}}
              </td>
              <td>{{hit.actionLabel}}</td>
              <td class="keyword-guard__content">{{hit.matched_text}}</td>
            </tr>
          {{/each}}
        </tbody>
      </table>
    {{else}}
      <p class="keyword-guard__empty">{{i18n "keyword_guard.admin.empty"}}</p>
    {{/if}}
  </section>
</template>
