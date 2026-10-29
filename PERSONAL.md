# 个人层（PERSONAL）

这个仓库是 [`berhbro/dsh-cyrene-theme`](https://github.com/berhbro/dsh-cyrene-theme) 的个人副本。
目标只有一条：**上游永远可快进，个人改动永远可重放。**

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

已备好的现成修复（macOS 桌面版窗口拖不动 / 双击不缩放，上游 issue #2、PR #3）——需要时把下面三行从注释里放出来：

```css
html body[data-dsh-cyrene] > .cyre-bg{
  -webkit-app-region:initial !important;
  app-region:initial !important;
}
```

## 同步上游（发版后跑一次）

```powershell
.\sync-upstream.ps1            # fetch → rebase → 跑三套自检 → 打 sync 标签
.\sync-upstream.ps1 -Push      # 顺带把 personal 推到 origin 备份
```

脚本做的事：

1. `git fetch upstream --prune`
2. `git switch personal && git rebase upstream/main`
3. `node test/host.smoke.mjs`、`client.smoke.mjs`、`contrast.mjs`（共 285 条断言）
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

## 生效粒度

| 改了 | 怎么生效 |
| --- | --- |
| `PERSONAL_CSS` / `lib/client.js` | 刷新页面（F5） |
| `lib/index.js` / `cordis.patch.yml` | 重载插件行，或重启 DSH |
| 面板里的设定 | 立刻 |
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
- **别在 `main` 上提交**：`main` 只做 `--ff-only` 快进，否则下次同步会很痛。

## 个人改动登记

| 日期 | 改动 | 位置 | 上游合并后可删 |
| --- | --- | --- | --- |
| 2026-10-29 | 建立个人层（5 处钩子 + 空区块），未启用任何业务改动 | `lib/client.js`、`lib/index.js` | 否（永久基础设施） |
