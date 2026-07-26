# Zen-O 自动签到 🤖

> 每天 UTC+8 08:17 自动签到 [Zen-O](https://app.zen-o.xyz/)，使用 GitHub Actions 部署。
> ⚡ 每次执行仅 ~10 秒，不浪费 Actions 免费额度。

## 目录

- [工作原理](#工作原理)
- [快速开始](#快速开始)
- [获取 Auth Token](#获取-auth-token)
- [配置 GitHub Secrets](#配置-github-secrets)
- [手动触发测试](#手动触发测试)
- [查看签到记录](#查看签到记录)
- [通知配置（可选）](#通知配置可选)
- [文件结构](#文件结构)
- [常见问题](#常见问题)

---

## 工作原理

```
GitHub Actions (cron: 00:17 UTC = 08:17 UTC+8)
        │
        ▼
  GET /attendance-info  → 查询本周签到状态
        │
        ▼
  POST /attendance-check-in  → 执行签到
        │
        ▼
  输出结果到 Actions 日志（全程 ~10 秒）
```

## 快速开始

### 前置条件

- 一个 GitHub 账号
- 一个已注册的 [Zen-O](https://app.zen-o.xyz/) 账号

### 步骤

1. **将本仓库 fork 或 clone 到你的 GitHub**

2. **获取你的 Auth Token**（见下方）

3. **配置 GitHub Secret**
   - 仓库 → Settings → Secrets and variables → Actions
   - 点击 **New repository secret**
   - Name: `ZENO_AUTH_TOKEN`
   - Secret: 填入你获取的 token
   - 点击 **Add secret**

4. **启用 GitHub Actions**
   - 仓库 → Actions 标签页
   - 确认 `zeno-daily-checkin` workflow 已启用
   - 下次 cron 触发时（每天 00:00 UTC）会自动运行

---

## 获取 Auth Token

Zen-O 使用 Bearer Token 认证，你需要从浏览器中提取：

### 方法一：通过 LocalStorage（推荐）

1. 在浏览器中打开 [https://app.zen-o.xyz/](https://app.zen-o.xyz/) 并**登录你的账号**
2. 打开开发者工具：
   - **Chrome**: `F12` 或右键 → **检查**
   - **Edge**: `F12` 或右键 → **检查**
3. 切换到 **Application**（应用）标签页
4. 左侧找到 **Local Storage** → `https://app.zen-o.xyz`
5. 找到 key 为 `auth` 的条目
6. 双击 value 区域，复制全部 JSON
7. 从中提取 `"token"` 字段的值，类似：
   ```json
   {"state":{"token":"eyJhbGciOiJIUzI1NiIs...InR5cCI6IkpXVCJ9..."},"version":0}
   ```
   👆 复制 `eyJhbGci...` 这一整段（以 `eyJ` 开头的一长串字符）

### 方法二：通过 Network 请求

1. 登录后刷新页面，打开 DevTools → **Network** 标签
2. 过滤 `attendance` 或 `auth-me`
3. 点击任意请求 → **Request Headers**
4. 找到 `Authorization: Bearer eyJhbGci...` 复制 `eyJhbGci...` 部分

### 注意

- Token 有**有效期**，过期后需要重新获取
- 建议每隔几个月检查一次 token 是否仍然有效
- 如果签到失败，先检查 token 是否过期

---

## 手动触发测试

> 配置好 Secret 后，可以先手动触发一次测试

1. 打开 GitHub 仓库 → **Actions** 标签页
2. 左侧点击 **Daily Check-in**
3. 点击 **Run workflow** → **Run workflow**
4. 等待几秒后点击运行中的 job 查看日志
5. 日志中会显示 `[OK] Check-in successful! 🎉` 或错误信息

---

## 查看签到记录

签到结果会记录在 GitHub Actions 的运行日志中：

1. 仓库 → **Actions** → **Daily Check-in**
2. 点击任意一次运行记录
3. 展开 **Daily Check-in** job → **Run daily check-in** step
4. 可以看到本周签到进度、签到日期等信息

---

## 通知配置（可选）

### Telegram 通知

在 workflow 最后添加步骤：

```yaml
- name: 📬 Telegram 通知
  if: always()
  uses: appleboy/telegram-action@master
  with:
    to: ${{ secrets.TELEGRAM_CHAT_ID }}
    token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    message: |
      🤖 Zen-O Check-in ${{ job.status }}
      Time: ${{ env.CHECKIN_TIME }}
      Status: ${{ steps.checkin.outcome }}
```

### 企业微信 / Slack / 钉钉

- 使用 [wechat-work-bot](https://github.com/marketplace/actions/wechat-work-bot)
- 使用 [slack-notify](https://github.com/marketplace/actions/slack-notify)
- 使用 [dingtalk-notify](https://github.com/marketplace/actions/dingtalk-notify)

---

## 文件结构

```
├── .github/workflows/
│   └── zeno-checkin.yml      # GitHub Actions 工作流配置
├── scripts/
│   └── zeno-checkin.sh       # 签到自动化脚本
└── README.md                 # 本文件
```

## 常见问题

### Q: 签到时间如何确定？
A: 工作流在 00:17 UTC（08:17 UTC+8）触发，落在 08:00–10:00 UTC+8 窗口内。选 17 分而非整点/半点，避开 cron 全局拥堵。每次执行仅 ~10 秒，不消耗 Actions 免费额度。

### Q: 周六日会签到吗？
A: 会的，每天都会触发。如果只需要工作日，将 cron 改为 `0 0 * * 1-5`。

### Q: Token 过期了怎么办？
A: 重新登录网页，按上述方法提取新 token，在 GitHub 设置中更新 Secret。

### Q: 如何停止自动签到？
A: 在仓库 → Actions 中 Disable 该 workflow，或直接删除 `.github/workflows/zeno-checkin.yml`。

### Q: 签到失败可能的原因？
A: 1) Token 过期 2) 网络问题 3) 服务器维护 4) 当天已签到（日志会显示 `already checked in`）

---

## 免责声明

本工具仅供学习研究使用。使用前请确保遵守 Zen-O 的服务条款。作者不对因使用本工具导致的任何账户问题承担责任。