<#
.SYNOPSIS
  把上游（berhbro/dsh-cyrene-theme）最新版 rebase 到 personal 分支，并跑三套自检。

.DESCRIPTION
  这是 PERSONAL.md 里「同步上游」一节的自动化版本：
    1. git fetch upstream --prune
    2. git switch personal && git rebase upstream/main
    3. node test/host.smoke.mjs / client.smoke.mjs / contrast.mjs（398 条断言）
    4. git tag -f sync/upstream-<sha>

  冲突只可能落在个人钩子或「必须就地改上游」的那几个小提交上。解完
  `git add -A; git rebase --continue`，再重跑本脚本即可（rerere 已开启）。

.EXAMPLE
  .\sync-upstream.ps1

.EXAMPLE
  .\sync-upstream.ps1 -Push
#>
[CmdletBinding()]
param(
  [string]$Node = '',
  [switch]$Push
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repo

function Resolve-Node {
  param([string]$Explicit)
  if ($Explicit) { return $Explicit }
  if ($env:DSH_DESKTOP_NODE_EXECUTABLE) { return $env:DSH_DESKTOP_NODE_EXECUTABLE }
  $cmd = Get-Command node -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  # DSH 桌面版自带的 Node（node.cmd 依赖 DSH_DESKTOP_NODE_EXECUTABLE，直接调 exe 更稳）。
  $guess = Join-Path $env:USERPROFILE '.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe'
  if (Test-Path $guess) { return $guess }
  throw '找不到 node：用 -Node <path> 指定（例如 %USERPROFILE%\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe）'
}

function Assert-Ok {
  param([string]$What)
  if ($LASTEXITCODE -ne 0) { throw "$What 失败（exit $LASTEXITCODE）" }
}

$node = Resolve-Node -Explicit $Node

# 没加过 upstream 的话补上（例如重新 clone 之后）。
$remotes = git remote
if ($remotes -notcontains 'upstream') {
  Write-Host '添加 upstream remote…'
  git remote add upstream https://github.com/berhbro/dsh-cyrene-theme.git
  Assert-Ok 'git remote add upstream'
}

$current = (git rev-parse --abbrev-ref HEAD).Trim()
if ($current -ne 'personal') {
  Write-Host "当前在 $current 分支，切到 personal…"
  git switch personal
  Assert-Ok 'git switch personal'
}

$dirty = git status --porcelain
if ($dirty) {
  Write-Host '工作区有未提交改动，先 commit 或 stash 再同步：' -ForegroundColor Yellow
  $dirty | ForEach-Object { Write-Host "  $_" }
  exit 1
}

Write-Host '拉取上游…'
git fetch upstream --prune
Assert-Ok 'git fetch upstream'

$target = (git rev-parse --short upstream/main).Trim()
$before = (git rev-parse --short HEAD).Trim()
Write-Host "personal HEAD = $before，upstream/main = $target"

git rebase upstream/main
if ($LASTEXITCODE -ne 0) {
  Write-Host ''
  Write-Host 'rebase 停在冲突上。处理方式：' -ForegroundColor Yellow
  Write-Host '  1. 改冲突文件（大概率是 PERSONAL_CSS 或 applyPersonal 那几处）'
  Write-Host '  2. git add -A; git rebase --continue'
  Write-Host '  3. 重新运行 .\sync-upstream.ps1'
  exit 1
}

Write-Host ''
Write-Host '跑自检…'
# 自检里有些用例故意打印 warn 到 stderr（例如"槽位冲突被兜住"）。Windows PowerShell
# 在 $ErrorActionPreference='Stop' 下会把原生命令的 stderr 当成终止错误，所以这里
# 临时放开，只看退出码。
$previousEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  & $node test\host.smoke.mjs
  $hostCode = $LASTEXITCODE
  & $node test\client.smoke.mjs
  $clientCode = $LASTEXITCODE
  & $node test\contrast.mjs
  $contrastCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousEap
}
if ($hostCode -ne 0) { throw "host.smoke.mjs 失败（exit $hostCode）" }
if ($clientCode -ne 0) { throw "client.smoke.mjs 失败（exit $clientCode）" }
if ($contrastCode -ne 0) { throw "contrast.mjs 失败（exit $contrastCode）" }

git tag -f "sync/upstream-$target" | Out-Null
Write-Host ''
Write-Host "同步完成：personal 现在基于 upstream/main@$target（之前 $before）" -ForegroundColor Green
Write-Host '个人提交：'
git log --oneline upstream/main..personal

if ($Push) {
  Write-Host ''
  Write-Host '推送到 origin（备份）…'
  git push origin personal --force-with-lease
  Assert-Ok 'git push origin personal'
}

Write-Host ''
Write-Host '下一步：刷新 DSH 页面；改过 lib/index.js 的话再重载一次插件行。'
