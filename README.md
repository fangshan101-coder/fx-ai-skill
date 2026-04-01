# fx-ai-skill

fenxiang-ai 后端的 Claude Code Skill 集合。

## Skill 列表

| Skill | 说明 | ClawHub |
|-------|------|---------|
| **fx-base** | 公共基础（认证 + 请求 + 错误处理） | [fangshan101-coder/fx-base](https://clawhub.ai/fangshan101-coder/fx-base) |
| **fanli** | 省钱购物助手（转链 + 比价 + 历史价） | [fangshan101-coder/fanli](https://clawhub.ai/fangshan101-coder/fanli) |

## 安装

```bash
# 先安装公共基础
npx skills install fangshan101-coder/fx-base

# 再安装需要的领域 skill
npx skills install fangshan101-coder/fanli
```

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `FX_AI_API_KEY` | 是 | 从 [fenxiang-ai 开放平台](https://platform.fenxiang-ai.com/) 获取 |
