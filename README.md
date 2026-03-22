# wechat-claude-code

一个 [Claude Code](https://claude.ai/claude-code) Skill，将个人微信桥接到本地 Claude Code。通过手机微信与 Claude 对话——文字、图片、权限审批、斜杠命令，全部支持。

## 功能特性

- 通过微信与 Claude Code 进行文字对话
- 图片识别——发送照片让 Claude 分析
- 权限审批——在微信中回复 `y`/`n` 控制工具执行
- 斜杠命令——`/help`、`/clear`、`/model`、`/status`、`/skills`
- 在微信中触发任意已安装的 Claude Code Skill
- 跨平台守护进程——支持 macOS / Linux / Windows
- 会话持久化——跨消息恢复上下文

## 系统要求

- Node.js >= 18
- Windows / macOS / Linux
- 个人微信账号（需扫码绑定）
- 已安装 [Claude Code](https://docs.anthropic.com/en/docs/claude-code)，并安装 `@anthropic-ai/claude-agent-sdk`

## 安装

### 1. 克隆项目

```bash
# Windows PowerShell
git clone https://github.com/xingranya/wechat-claude-code.git $env:USERPROFILE\.claude\skills\wechat-claude-code
cd $env:USERPROFILE\.claude\skills\wechat-claude-code

# macOS / Linux
git clone https://github.com/xingranya/wechat-claude-code.git ~/.claude/skills/wechat-claude-code
cd ~/.claude/skills/wechat-claude-code
```

### 2. 安装依赖

```bash
npm install
```

`postinstall` 会自动编译 TypeScript。

## 快速开始

### 首次设置（扫码绑定）

```bash
npm run setup
```

1. 自动弹出二维码图片
2. 打开微信 → 扫一扫
3. 绑定成功后，设置工作目录（Claude Code 运行时的当前目录）

### 启动服务

```bash
npm run daemon -- start
```

### 开始聊天

在微信中向你的机器人发送消息即可。

## 守护进程管理

```bash
npm run daemon -- start   # 启动服务
npm run daemon -- stop    # 停止服务
npm run daemon -- restart # 重启服务
npm run daemon -- status  # 查看状态
npm run daemon -- logs    # 查看日志
```

## 微信端命令

| 命令 | 说明 |
|------|------|
| `/help` | 显示帮助信息 |
| `/clear` | 清除当前会话，从头开始 |
| `/model <名称>` | 切换 Claude 模型（如 `claude-opus-4`、`claude-sonnet-4`） |
| `/status` | 查看当前会话状态 |
| `/skills` | 列出所有已安装的 Skill |
| `/<skill> [参数]` | 触发任意已安装的 Skill |

## 权限审批

Claude 需要执行工具时，会在你的微信发送权限请求：

- 回复 `y` 或 `yes` — 允许执行
- 回复 `n` 或 `no` — 拒绝执行
- 60 秒内无回复 — 自动拒绝

## 工作原理

```
微信（手机） ←→ ilink bot API ←→ Node.js 守护进程 ←→ Claude Code SDK（本地）
```

1. 守护进程通过长轮询监听微信 ilink bot API 的新消息
2. 消息通过 `@anthropic-ai/claude-agent-sdk` 转发给 Claude Code
3. Claude 的回复发送回微信

## 数据存储

所有数据位于 `~/.wechat-claude-code/`（Windows 为 `%USERPROFILE%\.wechat-claude-code\`）：

| 目录/文件 | 说明 |
|----------|------|
| `accounts/` | 微信账号凭证 |
| `config.json` | 全局配置（工作目录、模型、权限模式） |
| `sessions/` | 会话数据 |
| `get_updates_buf` | 消息轮询同步缓冲 |
| `logs/` | 运行日志 |

## Windows 开机自启（可选）

使用任务计划程序实现开机自启：

1. 打开「任务计划程序」
2. 创建基本任务，命名为 `wechat-claude-code`
3. 触发器：计算机启动时
4. 操作：启动程序
   - 程序/脚本：`node`
   - 参数：`dist\main.js start`
   - 起始位置：`%USERPROFILE%\.claude\skills\wechat-claude-code`
5. 完成向导

## 常见问题

**Q: 提示 `'open' is not recognized` 或 `'node' is not recognized`？**

确保 Node.js 已安装并添加到系统 PATH。重启终端后重试。

**Q: 二维码不显示？**

手动打开图片路径：`%USERPROFILE%\.wechat-claude-code\qrcode.png`

**Q: 守护进程启动失败？**

检查日志：`%USERPROFILE%\.wechat-claude-code\logs\`

## 开发

```bash
npm run build  # 编译 TypeScript
npm run dev    # 监听模式（文件变更自动编译）
```

## License

[MIT](LICENSE)
