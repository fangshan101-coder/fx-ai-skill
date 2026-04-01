# fx-ai-skill 仓库规则

本仓库是 fenxiang-ai 后端的 Skill 集合，包含公共基础 `fx-base` + 多个领域 Skill。

## 架构

```
fx-ai-skill/
├── fx-base/          # 公共基础（认证 + 请求 + 错误处理）
├── fanli/            # 省钱购物助手
└── <future-skill>/   # 未来领域 skill
```

- `fx-base/` 提供 `fx-api.sh` 脚本，领域 skill 通过 `source` 引用
- 领域 skill 不自己写 curl 请求，统一用 `fx_check_auth` + `fx_post`
- 每个领域 skill 的 SKILL.md 开头必须声明 fx-base 依赖

## fx-api.sh 函数

| 函数 | 签名 | 说明 |
|------|------|------|
| `fx_check_auth` | 无参数 | 校验 `FX_AI_API_KEY`，未设置则 exit 1 |
| `fx_post` | `<endpoint> <body> [err_msg]` | POST 请求到 `FX_BASE_URL/<endpoint>`，失败则 exit 1 |
| `fx_check_response` | `<resp_json>` | `code==200` 输出 data，否则 exit 1 |

常量：`FX_BASE_URL=https://api-ai-brain.fenxianglife.com/fenxiang-ai-brain`

## 路径解析

领域 skill 被 symlink 后，通过 `pwd -P` 解析到物理路径，`../../fx-base/` 始终指向正确位置：

```bash
_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
_FX_API="$_SCRIPT_DIR/../../fx-base/scripts/fx-api.sh"
if [[ ! -f "$_FX_API" ]]; then
  echo '{"status":"error","error_type":"missing_dependency","suggestion":"缺少 fx-base，请安装：npx skills install fangshan101-coder/fx-base"}' >&2
  exit 1
fi
source "$_FX_API"
```

## 新增领域 Skill 检查清单

1. 在仓库根目录创建 `<skill名>/` 目录，含 `SKILL.md` + `scripts/` + `references/`
2. SKILL.md frontmatter 之后第一行添加 fx-base 依赖声明：
   ```markdown
   > **CRITICAL** — 开始前 **必须**用 Read 工具读取 [`../fx-base/SKILL.md`](../fx-base/SKILL.md)，其中包含 fenxiang-ai API 认证和请求规范。
   >
   > fx-base 未安装？执行 `npx skills install fangshan101-coder/fx-base` 安装到同目录下。
   ```
3. 脚本头部 source fx-api.sh（使用上方路径解析代码）
4. 用 `fx_check_auth` + `fx_post` 替代 curl 直接调用
5. 在 `/Users/eamanc/Documents/pe/skills/.publish/config.json` 注册（account: fangshangithub, repo_type: multi）
6. README.md 安装说明中注明需同时安装 fx-base

## 发布信息

| 项目 | 值 |
|------|-----|
| GitHub | fangshan101-coder/fx-ai-skill |
| SSH Host | github.com-fangshangithub |
| 发布账号 | fangshangithub |
| fx-base slug | fx-base |
| fanli slug | fanli（不可改） |

## 共享环境变量

| 变量 | 说明 |
|------|------|
| `FX_AI_API_KEY` | fenxiang-ai 开放平台 API Key，所有领域 Skill 共用 |
