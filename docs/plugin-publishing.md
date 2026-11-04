# Claude Code 插件：生成、发布、分发、使用

这份文档解决三个问题：**怎么做插件**、**怎么发布（以及发不上去怎么办）**、**别人怎么找到、怎么用**。

先记住一句话：

> **发布 = 把一个 `marketplace.json` 推进 git 仓库。没有提交表单，没有审核。**
> 让别人「搜得到」是另一件事，那要进 Anthropic 的官方目录。

事实来源：本机 `claude` 2.1.317 的 `--help` 实测 + 官方文档 `code.claude.com/docs/en/plugins/publish`、`/plugin-marketplaces`、`/plugins-reference`、`/discover-plugins`（2026-11 检索）。Claude Code 迭代很快，命令参数以 `claude plugin <子命令> --help` 为准。

## 一、三层概念，别混

| 层 | 是什么 | 谁看得见 |
| --- | --- | --- |
| **插件** | 一个目录：`.claude-plugin/plugin.json` + `commands/`、`skills/` 等组件 | 装了它的人 |
| **市场** | 一个 git 仓库里的 `.claude-plugin/marketplace.json`，列出一个或多个插件 | 加了这个市场的人 |
| **目录** | Anthropic 官方目录（claude.ai、Cowork、Discover 里能搜到） | 所有人，需要提交审核 |

一个仓库可以同时是插件和市场（本项目就是这样：`source: "./"`）。**市场本身不装任何东西**，它只是一份目录，用户还要再执行一次 `install`。

## 二、生成插件

### 1. 目录结构

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json          # 清单，只有 name 是必需的
├── commands/                 # 斜杠命令，一个 .md 一个命令
│   └── deploy.md
├── agents/                   # 子代理
├── skills/                   # 技能，每个子目录一个 SKILL.md
│   └── my-skill/SKILL.md
├── hooks/
│   └── hooks.json            # 事件钩子
├── .mcp.json                 # MCP 服务器
└── scripts/                  # 自己的脚本，用 ${CLAUDE_PLUGIN_ROOT} 引用
```

三条硬规则：

1. **`.claude-plugin/` 里只放清单**。`commands/`、`skills/`、`hooks/` 必须在插件根目录，塞进 `.claude-plugin/` 不会被发现。
2. **组件是按目录自动发现的**，不需要在 `plugin.json` 里登记。只有放在非标准位置时才写路径，且必须 `./` 开头、不能 `../`、不能绝对路径。
3. **钩子 JSON 语法错会让整个插件不加载**，不是只坏那一条钩子。

### 2. plugin.json

最小可用：

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "一句话说清这个插件解决什么问题"
}
```

常用字段：

| 字段 | 作用 | 注意 |
| --- | --- | --- |
| `name` | 唯一标识，kebab-case | 组件命名空间用它：`/my-plugin:deploy`；不能和已装插件重名 |
| `version` | 语义化版本 | **用户是否收到更新看它**。不写就按 commit SHA，每次提交都算新版 |
| `description` | 市场里显示的一句话 | 写「做什么」，不要写「很棒的工具」 |
| `author` | `{name, email, url}` | 提交官方目录时会看 |
| `license` | SPDX 标识 | `MIT`、`Apache-2.0` |
| `keywords` | 发现用的标签 | 数组，不是字符串 |
| `defaultEnabled` | 装完是否默认启用 | 默认 `true`；会改用户配置的插件建议设 `false` |

`name` 用大写、空格或下划线时，本地能跑，但 **claude.ai 同步会拒**。别赌。

### 3. 本地跑起来

```bash
# 不起市场，直接把目录挂进会话
claude --plugin-dir ./my-plugin

# 改了文件不想重启
/reload-plugins

# 官方校验：清单、路径、hooks JSON、commands 的 description
claude plugin validate ./my-plugin --strict
```

`--strict` 把警告当错误，CI 里用它。`--profile directory` 会额外按「提交官方目录」的标准检查（比如缺 README 直接失败），准备上架时值得跑。

`claude plugin init my-plugin --with commands,hooks` 可以生成脚手架，但它建在 `~/.claude/skills/` 下并以 `skills-dir` 形式加载，只适合起步参考。

## 三、发布：自己的市场

### 1. 同仓库单插件（最常见）

在 `.claude-plugin/` 里放两个文件，`source` 指向仓库根：

```json
{
  "name": "my-marketplace",
  "description": "这个市场收什么插件",
  "owner": { "name": "your-name" },
  "plugins": [
    {
      "name": "my-plugin",
      "source": "./",
      "description": "市场列表里显示的一句话"
    }
  ]
}
```

要点：

- `source: "./"` 是**仓库根**，不是 `.claude-plugin/`。
- 市场 `name` 在所有用户机器上必须唯一——重名时用户无法同时添加两个，起名前先搜一下。
- 插件条目的 `name` 要和 `plugin.json` 的 `name` 一致，`claude plugin tag` 会校验这一点。
- `source` 只能是 `./` 开头的仓库内路径，**不能 `../`**。

### 2. 一个仓库多个插件

```
marketplace-repo/
├── .claude-plugin/marketplace.json
└── plugins/
    ├── plugin-a/.claude-plugin/plugin.json
    └── plugin-b/.claude-plugin/plugin.json
```

```json
{ "name": "plugin-a", "source": "./plugins/plugin-a" }
```

也可以把插件放在别的仓库，用外部源：

```json
{ "source": { "source": "github", "repo": "owner/repo", "ref": "v1.2.0" } }
```

| source 类型 | 写法 | 适用 |
| --- | --- | --- |
| 仓库内路径 | `"./plugins/a"` | 同仓库，git 方式添加市场时有效 |
| GitHub | `{"source":"github","repo":"owner/repo","ref":"v1.2.0"}` | 跨仓库，可钉版本 |
| Git URL | `{"source":"url","url":"https://git.example.com/p.git"}` | 自建 git |
| 子目录 | `{"source":"git-subdir","url":"...","path":"packages/p"}` | monorepo |
| npm | `{"source":"npm","package":"@acme/plugin"}` | 走 npm 发版 |
| archive | `{"source":"archive","url":"https://.../p.zip","sha256":"..."}` | 只给一个 zip |

### 3. 发布动作

```bash
claude plugin validate . --strict     # 先自检
git push                              # 推上去就等于发布了
claude plugin tag --push              # 可选：打 ai-dev-standards--v1.5.0 这样的 tag
```

没有提交表单，没有审核队列。**私有仓库 = 私有市场**：能 clone 的人才能装。

版本在这里是唯一的更新开关：改了内容不 bump `version`，用户 `update` 时拿到的还是旧版。用 `scripts/release.sh` 之类的东西把「改版本 + 写 CHANGELOG + 自检」固定成一条命令，比靠记性可靠。

### 4. 更新怎么到达用户

- 用户主动：`claude plugin update my-plugin@my-marketplace`
- 自动：`/plugin` → **Marketplaces** → 选市场 → **Enable auto-update**
- 官方市场默认开自动更新，**第三方和本地市场默认关**
- 自动更新跑完会提示 `/reload-plugins`，或者下次启动生效

## 四、别人怎么找到你的插件

按可控程度从高到低：

### 1. 你直接给两条命令（最有效）

README 里写清楚，别人复制粘贴就能装：

```bash
claude plugin marketplace add your-name/your-repo
claude plugin install my-plugin@my-marketplace
```

新版本还能合成一条（v2.1.292+）：

```bash
claude plugin install my-plugin --marketplace your-name/your-repo
```

这一步不需要任何人审核，但**前提是对方知道你**。仓库名、README 首段、GitHub topics 就是你的「搜索入口」。

### 2. Anthropic 官方目录（能搜到，但要审核）

官方目录是 claude.ai、Cowork 和 Discover 里浏览的那个目录，收录后三个地方都能看到。

- 提交入口：`claude.ai/directory/manage`（开发者门户）
- **需要付费的 claude.ai 计划**：Pro / Max / Ultra 用自己的账号提交；Team / Enterprise 要 Owner 提交，Enterprise 还能给成员授 Directory 权限
- 本地先跑 `claude plugin validate ./my-plugin --strict --profile directory`，门户的规则比 CLI 多，本地过了不等于门户能过
- Anthropic 的官方市场 `claude-plugins-official` **不接受门户提交**，只能通过合作伙伴渠道谈

### 3. 社区 / 第三方聚合站

存在一些第三方站点（例如 claude-plugins.dev）按安装量和 star 排序收录插件。**这不是官方渠道**：收录规则各家自定、可能随时变、也可能收录了过期版本。当作锦上添花，别当发布路径。

### 4. 团队内自动铺开

项目 `.claude/settings.json`：

```json
{
  "extraKnownMarketplaces": {
    "my-team-tools": {
      "source": { "source": "github", "repo": "your-org/claude-plugins" }
    }
  }
}
```

成员信任这个仓库目录后，市场会自动添加。注意：**添加市场不等于安装插件**，来自外部源的插件仍要各自 `install` 一次。

## 五、别人怎么用

### 装上

```bash
# 1. 注册市场（只做一次）
claude plugin marketplace add your-name/your-repo

# 2. 装插件，默认 scope=user（所有项目生效）
claude plugin install my-plugin@my-marketplace

# 只在这个项目生效（写进 .claude/settings.json，可以提交给团队）
claude plugin install my-plugin@my-marketplace --scope project

# 只在本机这个目录生效（不进版本控制）
claude plugin install my-plugin@my-marketplace --scope local
```

会话里也行：`/plugin` 打开管理器，Discover（浏览）、Marketplaces（管市场）、Installed（已装）。或 `/plugin install my-plugin --marketplace your-name/your-repo`（v2.1.275+）。

### 管起来

| 动作 | 命令 |
| --- | --- |
| 看已装 | `claude plugin list`，会话里 `/plugin list` |
| 临时关掉 | `/plugin disable my-plugin@my-marketplace` |
| 更新 | `claude plugin update my-plugin@my-marketplace` |
| 卸载 | `claude plugin uninstall my-plugin@my-marketplace --scope local` |
| 刷新市场列表 | `claude plugin marketplace update` |
| 移除市场 | `claude plugin marketplace remove my-marketplace` |

⚠️ 移除市场会**连带卸载**从它装的插件。

装了之后插件的命令带命名空间：`/my-plugin:deploy`。技能（skill）不用手动调用，按 `description` 自动触发。

## 六、发不上去 / 别人装不上

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `Marketplace "x" not found` | 市场没添加成功，或名字拼错 | `claude plugin marketplace list` 看一眼，重新 `add` |
| `The plugin is not found in the marketplace` | 市场正常，插件名错 | 用 marketplace.json 里 `plugins[].name` 的值，不是仓库名 |
| 装上了但报 `path not found` | **用 URL 方式加的市场，只下载了 json 本身**，相对路径源指不到文件 | 改用 git 方式添加（`owner/repo`），或把 `source` 换成 github / npm 源 |
| `Git clone timed out after 120s` | 仓库大或网络慢，git 操作超时是 120s | `export CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS=300000` |
| 私有仓库认证失败 | git 没配凭证 | `gh auth status`、`git config --global credential.helper`；后台自动更新要环境里有 `GITHUB_TOKEN`（repo scope） |
| 离线时更新后插件全没了 | pull 失败会清掉旧缓存再重克隆 | `export CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1` |
| 安装成功但插件自己找不到文件 | 插件被复制到缓存目录，`../shared` 这类越界路径不跟着复制 | 用 `${CLAUDE_PLUGIN_ROOT}`，或把共享目录挪进插件里 |
| 整个插件不加载 | `hooks/hooks.json` JSON 语法错 | `claude plugin validate .` 会指出 |
| 提交官方目录被拒 | 命名不是 kebab-case、缺 README、清单里有 CLI 不检查的字段 | `claude plugin validate . --strict --profile directory` |
| 改了内容用户收不到新版 | 没 bump `version` | 发版流程里加一步改版本，见 `scripts/release.sh` |
| 国内拉 GitHub 慢/断 | 网络 | 优先 HTTPS（CI 里 `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1`）、调大超时；长期方案是把市场放内网 git |
| `/plugin` 命令不存在 | 版本太老，或在非 CLI 环境（桌面端 / VS Code 插件 / 云端会话） | `claude --version` 看版本；桌面端用插件浏览器，VS Code 用 Manage plugins |

## 七、本仓库就是实例

| 文件 | 作用 |
| --- | --- |
| `.claude-plugin/plugin.json` | 插件清单，`version` 是更新开关，唯一版本来源 |
| `.claude-plugin/marketplace.json` | 市场清单，`source: "./"` 指向仓库根 |
| `commands/install.md`、`commands/upgrade.md` | 斜杠命令 `/ai-dev-standards:install`、`:upgrade` |
| `skills/ai-dev-standards/SKILL.md` | 技能入口（正文在根 `SKILL.md`） |
| `hooks/hooks.json` | SessionStart 只读提醒 |
| `install.sh` / `install.ps1` | 真正干活的安装器，命令只是壳 |
| `scripts/release.sh` | 改版本 + 补 CHANGELOG + 自检 + 打印 tag 命令 |
| `.claude-plugin/icon.png` | 官方目录要求的 512px 方形图标 |

发布三步：

```bash
bash scripts/release.sh 1.6.0     # 改版本、补 CHANGELOG、跑自检
git push                          # 推上去即发布
claude plugin tag --push          # 打 ai-dev-standards--v1.6.0 并推 tag
```

## 八、发版前检查清单

- [ ] `claude plugin validate . --strict` 通过
- [ ] 需要上架官方目录时，加 `--profile directory` 也通过
- [ ] `plugin.json` 的 `version` 已 bump，`CHANGELOG.md` 首条与它一致
- [ ] `marketplace.json` 的 `plugins[].name` 与 `plugin.json` 的 `name` 一致
- [ ] 市场名在全网不撞（搜一下 `owner/repo` 和市场名）
- [ ] 插件内所有路径都在插件目录内，没有 `../`
- [ ] 组件里没有硬编码绝对路径，脚本用 `${CLAUDE_PLUGIN_ROOT}`
- [ ] README 首段写清了「这个插件做什么、怎么装」，两条命令可直接复制
- [ ] 本地用一个空项目实测：`marketplace add` → `install` → 触发一次命令
- [ ] 卸载路径想清楚了：插件被删掉后，它写进项目的文件怎么办

## 九、常见误解

- **「发布了就等于能被搜到」** —— 不是。发布只是让别人能按名字装；能被搜到要进官方目录。
- **「市场里加了我的插件，用户就装上了」** —— 不是，市场只是目录，装是第二个动作。
- **「改代码用户就更新了」** —— 不是，`version` 不变就没有更新。
- **「插件目录会被原地使用」** —— 不是，会复制到缓存，越界引用会失效。
- **「hooks 和 git hooks 是一回事」** —— 不是。插件 hooks 是 Claude Code 的事件钩子；`.git/hooks/` 是 git 的，两者互不干涉。
