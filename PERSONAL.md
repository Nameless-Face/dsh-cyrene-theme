# 个人层（PERSONAL）

这个仓库是 [`berhbro/dsh-cyrene-theme`](https://github.com/berhbro/dsh-cyrene-theme) 的个人副本。
目标只有一条：**上游永远可快进，个人改动永远可重放。**

当前基线：`upstream/main` @ `47cf4bf`（**v0.4.1**，2026-11-02 同步）。
个人提交：6 个（钩子 / 文档与脚本 / 欢迎页管理器 / 冷启动背景修复 + 本次同步与回归测试 2 个），全部重放在 0.4.1 之上。

```
upstream/main ──●──●──●──●        （berhbro 的发布线，只读）
                       ╲
personal      ──●──●──●─╲─●──●    （= upstream + 个人提交，桌面 profile 装的是这个）
                          ╲
main          ────────────●        （上游镜像，只 fast-forward）
```

## 分支约定

| 分支 | 用途 | 规矩 |
| --- | --- | --- |
| `upstream/main` | 上游发布线 | 只 fetch，永不提交 |
| `main` | 上游镜像 | 只 `git merge --ff-only upstream/main`，不写个人改动 |
| `personal` | 日常开发 | 所有个人提交都在这里；装进 profile 的也是这里 |

## 钩子（只有 5 处，都是稳定锚点）

| 文件 | 位置 | 作用 |
| --- | --- | --- |
| `lib/client.js` | CSS 模板上方 | `const PERSONAL_CSS = \`...\`` |
| `lib/client.js` | CSS 模板末尾 | `${PERSONAL_CSS}` 拼进上游样式表 |
| `lib/client.js` | `apply()` 末尾 | `applyPersonal(ctx)` |
| `lib/client.js` | factory 末尾 | `function applyPersonal(ctx) { ... }` |
| `lib/index.js` | `apply()` 末尾 + 文件末尾 | `applyPersonalHost(ctx)` + 函数体 |

区块和上游代码在同一个闭包 / 模块作用域里，所以能直接调用内部函数：

- 客户端半：`state`、`save()`、`load()`、`applySkin()`、`openPanel()`、`createEditor()`、`loadStickers()`、`loadBackgrounds()`、`showBackground()` …
- 宿主半：`state`、`persist()`、`remountPersona()`、`ensureStickers()`、`ensureBackgrounds()`、`PLUGIN_DIR`、`statePath()` …

## 个人改动放哪

| 想改什么 | 放哪 | 上游更新时 |
| --- | --- | --- |
| 人格 / 贴图 / 背景 / 开关 / 贴图大小 | 面板或 `$DSH_HOME/cyrene-theme.json` | 0 成本，不碰代码 |
| 颜色 / 字体 / 间距 / 隐藏元素 / 局部样式 | `PERSONAL_CSS` | 0 冲突 |
| 新面板 / 快捷键 / 行为调整 | `applyPersonal()` / `applyPersonalHost()` | 0 冲突（内部函数改名时改这一处） |
| 必须改上游逻辑（例如关掉 5 秒诊断扫描） | 单独一个小提交，就地几行 | 偶尔冲突，解一次就好（rerere 会记住） |

个人 CSS 的写法约定：**每条选择器加 `html ` 前缀**抬一档特异性，这样不依赖样式表插入顺序也能压过上游同名规则。

```css
html body[data-dsh-cyrene][data-cyrene-skin="on"]{ /* 例如换主色 */ }
```

已备好的现成修复（macOS 桌面版窗口拖不动 / 双击不缩放，上游 issue #2、PR #3）——**上游 0.2.1 已经合并**，就在样式表的「窗口拖拽区」一段里（`body[data-dsh-cyrene] > .cyre-bg{ -webkit-app-region:initial !important; app-region:initial !important }`）。个人层不再保留第二份；同步上游时如果这段被改坏，以上游自带的回归断言为准。

## 同步上游（发版后跑一次）

```powershell
.\sync-upstream.ps1            # fetch → rebase → 跑三套自检 → 打 sync 标签
.\sync-upstream.ps1 -Push      # 顺带把 personal 推到 origin 备份
```

脚本做的事：

1. `git fetch upstream --prune`
2. `git switch personal && git rebase upstream/main`
3. `node test/host.smoke.mjs`、`client.smoke.mjs`、`contrast.mjs`（共 **398** 条断言：165 + 199 + 34）
4. `git tag -f sync/upstream-<sha>`

手动等价命令：

```powershell
git fetch upstream
git switch personal
git rebase upstream/main
node test/host.smoke.mjs; node test/client.smoke.mjs; node test/contrast.mjs
```

冲突时：

```powershell
# 只会在「钩子那 5 处」或「必须就地改上游」的提交上冲突
# 解决后：
git add -A
git rebase --continue
```

`rerere` 已在本仓库开启（`git config rerere.enabled true`），同一个冲突只需要解一次。
解完想确认个人提交都还在：

```powershell
git log --oneline upstream/main..personal
```

## 上游 0.4.1 带来的变化（2026-11-02 同步）

上游从 `7dfe963`（0.2.0）到 `47cf4bf`（0.4.1）一共 6 个提交，新增：

- **长期记忆**（0.3.0）：`$DSH_HOME/cyrene-memory.json`、四条 `/cyrene/memory*` 路由、`cyrene_memory_add` / `cyrene_memory_search` / `cyrene_memory_forget` 三个工具、`cyrene:memory` section、设置页「✦ 长期记忆」整页管理器。
- **世界书**（0.4.0 / 0.4.1）：`$DSH_HOME/cyrene-worldbook.json`、`cyrene:worldbook` 一行索引、`cyrene_worldbook_search` 工具、`tools/build-worldbook.mjs` 抓取脚本、设置页「✦ 世界书」整页管理器。**本机目前没有抓取**，库是空的；需要时自己在面板里点「从官方 wiki 抓取 / 更新」。
- **macOS 拖拽修复**（PR #3）：上游样式表已经带 `-webkit-app-region:initial !important`，个人层不再重复。
- **工具契约修复**：工具 `execute()` 必须返回对象，`output` 必须同时带 `schema` 与 `render`——与 rc.5 的 `@deepseek-ai/dsh-tools` 校验一致。
- **运行环境**：桌面版为 `0.2.1-rc.5`（build `d4db512a`）。已确认 rc.5 的 `tools` 服务存在（`register(definition)` 要求 `output.schema` + `output.render`），上游 3 个记忆工具 + 世界书工具的定义与之一致；新路由与工具要**重启宿主**后才会注册。

这次 rebase 只有 **1 处冲突**：`lib/client.js` 设置页入口区，上游加 `memoryNote` / `worldbookNote` 两行概况，个人层加 `heroSummary` 一行概况；处理方式是**两边都保留**。原有 4 个个人提交全部重放成功，欢迎页、背景冷启动修复与新面板共存；之后又补了 2 个同步/回归提交。

## 已实现的个人改动

### 欢迎页管理器（贴纸 + 欢迎语）

入口：设置 →「昔涟 · 主题」→「✦ 欢迎页」（在「表情包管理」上方）→ 打开管理器。

- **显示贴纸**开关：关掉后欢迎页只剩那行欢迎语，形象不再挂上去。
- **欢迎语内容**：输入框 + 「保存欢迎语」（Enter 也能存）；留空＝用默认那句「让昔涟来帮帮你吧🎵」。
- **艺术字样式**开关：关掉后走普通无衬线正文色（`.cyre-hero-title-plain`），不再渐变裁字，跟着深浅色走。
- **从表情包里选图**：点清单里任意一张（含自己上传的）就设为欢迎页贴纸，当前那张有粉色描边；改完立刻生效。
- 顶部是**所见即所得的预览**：和页面上的欢迎页同一套 `.cyre-hero` 结构，只是尺寸小一号。

状态文件里的 `hero`：

| 字段 | 含义 |
| --- | --- |
| `image` | 形象路径；包内是相对路径，自添加目录改道到包外时是绝对路径 |
| `title` | 欢迎语；空串＝回默认。写入时 trim，按码点截到 60 |
| `showImage` | 是否显示贴纸，默认 `true` |
| `styled` | 是否用艺术字，默认 `true` |

行为边界：

- 删掉某张自添加表情包时，如果它正好是当前欢迎页形象，**自动退回默认形象**（不留悬空路径，和删背景图时清 `current` 同一个道理）。
- 形象只在包内 `meme/` 与 `stickers-custom/`（可改道）两个根下解析，越界一律「未就绪」。
- 旧状态文件没有这两个开关时按「开」处理，不需要迁移。

实现位置（同步上游时按这份清单看冲突）：

- **就地改上游**：`DEFAULT_HERO` / `publicState().hero` / `applyPatch()` 的 hero 分支 / `persist()` / `ensureHero()` 的两个根 / `publicStickers()` 的 `heroPath` / 删除贴纸时的回退——都在 `lib/index.js`。0.4.1 重构后逐项确认过，仍然完整。
- **冲突面很小**：`CyreneHero` 的两个条件与编辑器里的一行入口（`lib/client.js` 上游段）；管理器、预览、普通文字样式全部在个人区块（`PERSONAL_CSS` 与 `applyPersonal` 之后）。0.4.1 只在这一段新增了记忆 / 世界书两行概况，已与欢迎页概况并排保留。

### 冷启动背景图闪烁修复

症状：完全退出 DSH 后第一次进来，背景先显示目录里的第一张图，再跳回真正选中的那张。

原因：页面启动时 `/cyrene/backgrounds` 与 `/cyrene/state` 是并发的。清单先回来时
`state.background.current` 还是空串，`anchoredIndex()` 就落到清单第一张；等状态回来
才改成真正那张 —— 两帧不同的图，看起来就是闪了一下。

修法（只改 `lib/client.js`）：

- **`backgroundKnown` 闸门**：在知道「该铺哪张」之前整层先不显示（只留渐变底），绝不拿清单第一张顶替；
- **首屏缓存**：把上一次的 background 设定写进 localStorage，同一进程内的页面重载可以直接铺对那张
  （localStorage 按 origin 含端口隔离，DSH 每次启动端口不同，所以跨启动主要靠闸门）；
- 状态请求失败时放行，退回「缓存 / 第一张」，不会因为一次失败的 GET 把背景永远扣着。

行为变化：冷启动最多先看到几十毫秒渐变底，不会再闪一张错的图。
这是通用 bug，值得给上游提 PR；合并后这一段可以删掉。

## 生效粒度

| 改了 | 怎么生效 |
| --- | --- |
| `PERSONAL_CSS` / `lib/client.js` | 刷新页面（F5） |
| `lib/index.js` / `cordis.patch.yml` | 重载插件行，或重启 DSH |
| 面板里的设定 | 立刻 |
| 面板里的记忆 / 世界书 | 立刻（写 `$DSH_HOME` 下各自的 JSON） |
| `Background/` 里的图 | 刷新页面 |

## 安装方式

桌面 profile 用的是 `link:`，改文件不用重装：

```powershell
dsh plugin --profile desktop add D:\JUST_FOR_AI\dsh-cyrene-theme
```

`dsh plugin update` 不会再动它；上游同步只走 git。
想退回 npm 版：`dsh plugin --profile desktop add dsh-cyrene-theme`。

## 已知坑

- **行尾**：系统 gitconfig 是 `autocrlf=true`（索引 LF / 工作区 CRLF）。rebase 没问题，但别把别处生成的 diff 直接 `git apply`。
- **上传素材**：`stickers-custom/`、`backgrounds-custom/` 在包目录里（已 gitignore）。重装插件会丢图但状态文件里的条目还在；想长期留存，用 `CYRENE_CUSTOM_STICKER_DIR` / `CYRENE_CUSTOM_BACKGROUND_DIR` 把目录挪到仓库外（要给宿主进程设环境变量）。
- **记忆 / 世界书不在仓库里**：分别在 `$DSH_HOME/cyrene-memory.json`、`$DSH_HOME/cyrene-worldbook.json`。本机世界书目前是空的（没有抓取），需要时自己在面板里点「从官方 wiki 抓取 / 更新」；抓取会写几百 KB 到 `$DSH_HOME`，不进 git。
- **别在 `main` 上提交**：`main` 只做 `--ff-only` 快进，否则下次同步会很痛。

## 个人改动登记

| 日期 | 改动 | 位置 | 上游合并后可删 |
| --- | --- | --- | --- |
| 2026-10-29 | 建立个人层（5 处钩子 + 空区块），未启用任何业务改动 | `lib/client.js`、`lib/index.js` | 否（永久基础设施） |
| 2026-10-29 | 欢迎页管理器：贴纸显示 / 艺术字开关、从表情包选图、欢迎语编辑、删除当前形象自动回退 | `lib/index.js`（7 处）、`lib/client.js`（组件与编辑器 4 处 + 个人区块） | 否（除非上游也做） |
| 2026-10-29 | 自检：新增 13 条宿主断言 + 16 条客户端断言（当次总计 125 / 155 / 34） | `test/host.smoke.mjs`、`test/client.smoke.mjs` | 否 |
| 2026-10-30 | 冷启动背景图闪烁：`backgroundKnown` 闸门 + 首屏缓存；客户端断言 155 → 159 | `lib/client.js`、`test/client.smoke.mjs` | 是（通用修复，上游合并后可删） |
| 2026-11-02 | 同步上游 v0.4.1（长期记忆 / 世界书 / macOS 拖拽修复 / 工具契约）；rebase 仅 1 处冲突，保留双方入口概况 | `lib/index.js`、`lib/client.js`、`test/*` | 否 |
| 2026-11-02 | 移除个人层里重复的 macOS 拖拽修复注释；文档与同步脚本改为 0.4.1 基线（398 条断言）；新增「设置页五类入口顺序」回归断言 | `lib/client.js`、`PERSONAL.md`、`sync-upstream.ps1`、`test/client.smoke.mjs` | 否 |
