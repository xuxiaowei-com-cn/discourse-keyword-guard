import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "keyword-guard-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon("discourse-keyword-guard", "shield-halved");
      api.addAdminPluginConfigurationNav("discourse-keyword-guard", [
        {
          label: "keyword_guard.admin.nav_title",
          route: "adminPlugins.show.discourse-keyword-guard",
          description: "keyword_guard.admin.nav_description",
        },
      ]);
    });
  },
};
