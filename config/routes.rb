# frozen_string_literal: true

DiscourseKeywordGuard::Engine.routes.draw do
  get "/hits" => "admin#hits"
  post "/scan" => "admin#scan"
  post "/test" => "admin#test"
  delete "/hits" => "admin#destroy"
end

Discourse::Application.routes.draw do
  scope "/admin/plugins/discourse-keyword-guard", constraints: AdminConstraint.new do
    get "/keyword-guard(/*path)" => "discourse_keyword_guard/admin#page"
  end

  mount ::DiscourseKeywordGuard::Engine, at: "/admin/plugins/discourse-keyword-guard/api"
end
