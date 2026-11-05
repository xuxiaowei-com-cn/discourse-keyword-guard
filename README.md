# discourse-keyword-guard

Discourse 关键词守卫插件。插件直接复用 Discourse 内置的「关注词（Watched Words）」配置，把 `block` 和 `silence` 两个列表扩展应用到用户名、昵称、个人简介、聊天群名称和聊天内容。

## 功能

| 范围 | `block` 词条 | `silence` 词条 |
| --- | --- | --- |
| 用户名 | 发布前拦截 | 发布后禁言 |
| 昵称 | 发布前拦截 | 发布后禁言 |
| 个人简介 | 发布前拦截（Discourse 核心 + 插件审计） | 发布后禁言 |
| 聊天群名称 / Slug | 发布前拦截 | 记录并通知管理员 |
| 聊天内容 | 发布前拦截（Discourse 核心 + 插件审计） | 发布后禁言，可选删除消息 |

- 发布前：在模型校验阶段直接拒绝保存，用户会收到本地化的错误提示。
- 发布后：定时扫描和历史扫描会处理导入内容、绕过校验的内容，以及添加关键词之前已经存在的内容。
- 封禁 / 禁言通知：自动以 system 用户发送通用邮件，只说明账号被封禁或禁言，**不会提及命中的关键词或具体规则**。
- 审计：所有拦截和发布后操作都会记录到后台「守卫记录」页面。
- 豁免：可豁免管理员/版主、指定用户组和指定用户名。
- 可选额外关键词：支持子串、单词边界和正则表达式三种模式。

## 关键词配置

关键词使用 Discourse 自带页面管理，不需要在插件里重复维护：

- 禁止词（发布前拦截）：`/admin/customize/watched_words/action/block`
- 禁言词（发布后处理）：`/admin/customize/watched_words/action/silence`

## 设置

在 `后台 → 插件 → discourse-keyword-guard → 设置` 中配置。

### 关键词来源

- `keyword_guard_use_watched_words`：使用内置 `block` / `silence` 列表（默认开启）。
- `keyword_guard_extra_keywords`：可选的额外关键词，每行一个。可写 `re:正则`，以 `#` 开头表示注释，以 `\#` 开头表示字面量 `#`。
- `keyword_guard_extra_match_mode`：`substring`（默认，适合中文）、`word` 或 `regex`。
- `keyword_guard_extra_case_sensitive`：额外关键词是否区分大小写。

### 检查范围

- `keyword_guard_scope_username`
- `keyword_guard_scope_name`
- `keyword_guard_scope_bio`
- `keyword_guard_scope_chat_channel_name`
- `keyword_guard_scope_chat_message`

### 豁免

- `keyword_guard_exempt_staff`：默认豁免管理员和版主。
- `keyword_guard_exempt_groups`：豁免指定用户组。
- `keyword_guard_exempt_usernames`：豁免指定用户名。

### 发布后动作

- `keyword_guard_block_action`：已发布内容命中 `block` 词条或额外关键词时：
  - `none`：只记录
  - `silence`：禁言作者
  - `suspend`：封禁作者（默认）
  - `suspend_and_delete`：封禁作者并删除命中的聊天消息
- `keyword_guard_silence_action`：已发布内容命中 `silence` 词条时：
  - `none`：只记录
  - `silence`：禁言作者（默认）
  - `silence_and_delete`：禁言作者并删除命中的聊天消息
- `keyword_guard_suspend_days` / `keyword_guard_silence_days`：封禁/禁言天数，最大值相当于永久。
- `keyword_guard_suspend_message`：可选的自定义封禁消息。**请保持通用，不要在这里写具体规则或关键词。**
- `keyword_guard_notify_user`：是否自动发送通用邮件，默认开启。
- `keyword_guard_notify_moderators`：是否向版主发送私信通知，默认开启。

### 审计

- `keyword_guard_log_hits`：记录命中，默认开启。
- `keyword_guard_hit_retention_days`：审计记录保留天数，默认 90 天。

## 管理页面

插件后台页面：

```text
/admin/plugins/discourse-keyword-guard/keyword-guard
```

页面展示命中总数、最近 24 小时数量、拦截/禁言/封禁数量、`block` / `silence` 词条数量，以及最近命中记录。可以手动触发「扫描最近内容」。

## 历史内容扫描

```bash
cd /var/www/discourse
RAILS_ENV=production bundle exec rake keyword_guard:scan
```

定时任务每 10 分钟扫描最近更新的用户、简介、聊天群和聊天消息。手动任务会扫描全部历史内容；执行前请确认 `block` / `silence` 的发布后动作符合预期。

## 安装

把插件放入 Discourse 的 `plugins` 目录，例如：

```bash
cd /var/www/discourse/plugins
git clone https://cnb.cool/xuxiaowei.com.cn/discourse-keyword-guard.git
```

然后在容器中执行数据库迁移、构建前端资源并重启：

```bash
cd /var/www/discourse
RAILS_ENV=production bundle exec rake db:migrate
RAILS_ENV=production bundle exec rake assets:precompile:build_plugins
```

使用 Docker Compose 部署时，可以把克隆命令加入 Web 容器的启动命令，参考 `docker-compose.yml` 中其他插件的做法。

## 通知说明

封禁使用 `UserSuspender` 并发送 `account_suspended` 邮件；禁言使用 `UserSilencer` 并发送 `account_silenced` 邮件。邮件内容只包含：

- 账号被封禁 / 禁言
- 处理期限
- 通用原因「违反社区准则」

命中关键词、检查范围等细节只写入管理员审计记录和版主通知，不会进入用户邮件。

## 开发与验证

- Ruby 代码位于 `lib/discourse_keyword_guard/`。
- 模型扩展位于 `lib/discourse_keyword_guard/*_extensions.rb`。
- 后台 API 位于 `app/controllers/discourse_keyword_guard/admin_controller.rb`。
- 后台前端位于 `admin/assets/javascripts/`。

常用检查：

```bash
ruby -c lib/discourse_keyword_guard/enforcer.rb
RAILS_ENV=production bundle exec rails runner 'puts DiscourseKeywordGuard::Matcher.new("违禁词").block_matches.inspect'
```

## 注意事项

- `block` 词条在用户名、简介和聊天内容上同时受 Discourse 核心校验保护；插件不会重复显示核心已经给出的错误，但仍会记录审计命中。
- `silence` 词条不会在发布前拦截，而是在发布后执行配置的动作，因此适合「先发布、后处理」的场景。
- 中文没有空格，额外关键词默认使用 `substring` 子串匹配；`word` 模式依赖单词边界，不建议用于中文。
- 发布后动作只会对普通用户执行，不会封禁或禁言管理员/版主。
- 如果用户因用户名命中关键词而需要被封禁，插件会在内部保存时跳过相关校验，确保封禁/禁言操作可以完成。
