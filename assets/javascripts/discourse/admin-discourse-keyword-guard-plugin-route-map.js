export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route("discourse-keyword-guard", { path: "keyword-guard" });
  },
};
