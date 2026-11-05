import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminPluginsShowDiscourseKeywordGuardController extends Controller {
  @service dialog;
  @service router;

  get stats() {
    return this.model.stats;
  }

  get hits() {
    return this.model.hits.map((hit) => ({
      ...hit,
      scopeLabel: i18n(`keyword_guard.scopes.${hit.scope}`),
      actionLabel: i18n(`keyword_guard.actions.${hit.action}`),
    }));
  }

  @action
  async scan() {
    try {
      await ajax("/admin/plugins/discourse-keyword-guard/api/scan.json", {
        type: "POST",
        data: { mode: "recent" },
      });
      this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  refresh() {
    this.router.refresh();
  }

  @action
  clear() {
    this.dialog.yesNoConfirm({
      message: i18n("keyword_guard.admin.confirm_clear"),
      didConfirm: async () => {
        try {
          await ajax("/admin/plugins/discourse-keyword-guard/api/hits.json", {
            type: "DELETE",
          });
          this.router.refresh();
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }
}
