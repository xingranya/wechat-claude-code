# 用微信调戏 Claude Code？居然真的实现了

## 先说能做什么

简单说，这是一个桥接工具——让你在微信里直接和 Claude Code 对话。

很多人可能觉得这没什么意思，但真正用起来会发现几个很爽的场景：

**出门在外，手机上直接问 Claude 问题**
不用开电脑，不用打开 Terminal。Claude Code 擅长的代码补全、文件编辑、任务执行，你可以在任何地方通过微信发起。Claude 写好代码后，你回来直接在电脑上看结果。

**拍张照片让 Claude 看看**
工地上拍了张错误日志、笔记本上写了段伪代码，拍个照发给微信，Claude 帮你分析。

**权限审批不用切窗口**
Claude 要执行危险操作时，微信弹个通知，你回复 `y` 就放行，`n` 就拒绝——不用在终端和 Claude 来回切换。

**跨消息接着聊**
Claude 写代码写到一半没完，你下一条消息接着问，它记得上下文。

---

## 工作原理

```
微信（手机） ←→ ilink 机器人 API ←→ Node.js 守护进程 ←→ Claude Code SDK（本地）
```

守护进程跑在你的电脑上，微信通过 ilink 机器人收发消息。消息经过 `@anthropic-ai/claude-agent-sdk` 转发给 Claude Code，回复再从微信推回来。

架构很简单，没有中间服务器劫持你的数据——所有东西都在你自己机器上。

---

## 安装有多复杂？

3 步。

**1. 克隆项目**

```bash
git clone https://github.com/xingranya/wechat-claude-code.git ~/.claude/skills/wechat-claude-code
cd ~/.claude/skills/wechat-claude-code
npm install
```

**2. 扫码绑定微信**

```bash
npm run setup
```

会自动弹出二维码，微信扫一下就绑定了。

**3. 启动服务**

```bash
npm run daemon -- start
```

---

## 微信里能干什么

| 命令 | 效果 |
|------|------|
| `/help` | 看所有可用命令 |
| `/clear` | 清空会话，重新开始 |
| `/model opus` | 切换到 Opus 4 |
| `/status` | 看当前会话状态 |
| `/skills` | 列出所有 Skill |
| `/optimize` | 直接触发其他 Skill |

发图片给 Claude，它也能看图说话。

---

## 数据安全吗

本地运行。微信账号信息、聊天记录、会话数据都存在你电脑的 `~/.wechat-claude-code/` 目录下，不经过任何第三方服务器。

---

## 支持的平台

Windows / macOS / Linux 都能跑。

---

## 适合谁

- 经常需要在移动场景下和 AI 协作的开发者
- 喜欢用微信当工作流通知渠道的人
- 想在手机上监督 Claude 执行任务的人

---

**GitHub**: https://github.com/xingranya/wechat-claude-code

有问题或建议欢迎提 Issue，也欢迎 Star ⭐
