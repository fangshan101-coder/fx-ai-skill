#!/usr/bin/env bash
# name: convert
# description: 商品转链，输入商品链接/淘口令，返回商品信息、到手价、优惠券、推广链接等

set -euo pipefail

# ── 加载公共库 ──
_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
_FX_API="$_SCRIPT_DIR/../../fx-base/scripts/fx-api.sh"
if [[ ! -f "$_FX_API" ]]; then
  echo '{"status":"error","error_type":"missing_dependency","suggestion":"缺少 fx-base，请安装：npx skills install fangshan101-coder/fx-base"}' >&2
  exit 1
fi
source "$_FX_API"

help() {
  cat <<'HELP'
用法: convert --tpwd <链接或口令> [选项]

必填:
  --tpwd <链接>                 商品链接或淘口令

选项:
  --includeComparePrice true|false  是否包含比价数据（默认 true）
  --includeHistoryPrice true|false  是否包含历史价数据（默认 true）
  --format json|table               输出格式（默认 json）
  --help                            显示此帮助

示例:
  convert --tpwd "https://e.tb.cn/h.xxx"
  convert --tpwd "https://u.jd.com/xxx" --includeComparePrice false
  convert --tpwd "￥xxx￥" --format table

数据流向: 商品链接会被发送到 https://api-ai-brain.fenxianglife.com 进行解析
HELP
  exit 0
}

TPWD="" FORMAT="json" INCLUDE_COMPARE="true" INCLUDE_HISTORY="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) help;;
    --tpwd) TPWD="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    --includeComparePrice) INCLUDE_COMPARE="$2"; shift 2;;
    --includeHistoryPrice) INCLUDE_HISTORY="$2"; shift 2;;
    *) shift;;
  esac
done

if [[ -z "$TPWD" ]]; then
  echo '{"status":"error","error_type":"missing_parameter","missing":"tpwd","suggestion":"请提供商品链接或淘口令，例如 --tpwd https://u.jd.com/xxx"}' >&2
  exit 1
fi

fx_check_auth

BODY=$(python3 -c "
import json, sys
d = {'tpwd': sys.argv[1]}
if sys.argv[2] != 'true':
    d['includeComparePrice'] = False
if sys.argv[3] != 'true':
    d['includeHistoryPrice'] = False
print(json.dumps(d))
" "$TPWD" "$INCLUDE_COMPARE" "$INCLUDE_HISTORY")

RESP=$(fx_post "skill/api/convert" "$BODY" "转链服务暂时不可用，请稍后重试")

export _RESP="$RESP"
python3 -c "
import json, os, sys

resp = json.loads(os.environ['_RESP'])
fmt = sys.argv[1]
data = resp.get('data', resp)

if resp.get('code') == 200 and data:
    if fmt == 'table':
        for k, v in data.items():
            if v is not None and v != '' and v != False:
                print(f'{k}: {v}')
    else:
        print(json.dumps(data, ensure_ascii=False, indent=2))
else:
    msg = resp.get('message', '转链失败')
    err = data.get('errorMessage', msg) if isinstance(data, dict) else msg
    print(json.dumps({'status': 'error', 'message': err, 'suggestion': '请检查链接是否正确'}, ensure_ascii=False, indent=2))
" "$FORMAT"
