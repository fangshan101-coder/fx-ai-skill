#!/usr/bin/env bash
# fx-api.sh — fenxiang-ai 公共请求库
# 用法：在领域 skill 脚本中 source 本文件，然后调用 fx_check_auth / fx_post / fx_check_response

# ── 常量 ──
FX_BASE_URL="https://api-ai-brain.fenxianglife.com/fenxiang-ai-brain"

# ── fx_check_auth ──
# 校验 FX_AI_API_KEY，未设置则输出标准错误 JSON 并 exit 1
fx_check_auth() {
  FX_API_KEY="${FX_AI_API_KEY:-}"
  if [[ -z "$FX_API_KEY" ]]; then
    echo '{"status":"error","error_type":"missing_api_key","suggestion":"请设置环境变量 FX_AI_API_KEY，从 https://platform.fenxiang-ai.com/ 登录获取"}' >&2
    exit 1
  fi
}

# ── fx_post <endpoint> <body> [error_suggestion] ──
# 发送 POST 请求到 fenxiang-ai 后端，返回响应 JSON 到 stdout
# 参数：
#   $1 — API 路径（如 skill/api/convert），不含 BASE_URL 前缀
#   $2 — JSON body
#   $3 — 可选，失败时的用户提示（默认"服务暂时不可用，请稍后重试"）
# 失败时输出错误 JSON 到 stderr 并 exit 1
fx_post() {
  local endpoint="$1" body="$2" err_msg="${3:-服务暂时不可用，请稍后重试}"
  local resp
  resp=$(curl -sf --max-time 30 -X POST \
    -H "Content-Type: application/json" \
    -H "Fx-Ai-Api-Key: Bearer $FX_API_KEY" \
    -d "$body" \
    "$FX_BASE_URL/$endpoint" 2>/dev/null) || {
    echo "{\"status\":\"error\",\"error_type\":\"api_unavailable\",\"suggestion\":\"$err_msg\"}" >&2
    exit 1
  }
  echo "$resp"
}

# ── fx_check_response <resp_json> ──
# 校验响应：code==200 输出 data JSON 到 stdout，否则输出错误到 stderr 并 exit 1
# 参数：
#   $1 — 完整的响应 JSON 字符串
fx_check_response() {
  python3 -c "
import json, sys
resp = json.loads(sys.argv[1])
data = resp.get('data', resp)
if resp.get('code') == 200 and data:
    print(json.dumps(data, ensure_ascii=False, indent=2))
else:
    msg = resp.get('message', '请求失败')
    err = data.get('errorMessage', msg) if isinstance(data, dict) else msg
    print(json.dumps({'status': 'error', 'message': err}, ensure_ascii=False, indent=2), file=sys.stderr)
    sys.exit(1)
" "$1"
}
