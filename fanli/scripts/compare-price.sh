#!/usr/bin/env bash
# name: compare-price
# description: 跨平台比价，输入商品链接/淘口令，返回全网最低价 TOP3
# tags: 比价,省钱,全网最低

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
用法: compare-price --productIdentifier <链接> [选项]

必填:
  --productIdentifier <链接>   商品链接或淘口令

选项:
  --shopType <平台>            指定平台筛选（如 淘宝、京东）
  --format json|table          输出格式（默认 json）
  --help                       显示此帮助

示例:
  compare-price --productIdentifier "https://e.tb.cn/h.xxx"
  compare-price --productIdentifier "https://u.jd.com/xxx" --format table

数据流向: 商品链接会被发送到 https://api-ai-brain.fenxianglife.com 进行解析
HELP
  exit 0
}

PRODUCT_IDENTIFIER="" SHOP_TYPE="" FORMAT="json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) help;;
    --productIdentifier) PRODUCT_IDENTIFIER="$2"; shift 2;;
    --shopType) SHOP_TYPE="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    *) shift;;
  esac
done

if [[ -z "$PRODUCT_IDENTIFIER" ]]; then
  echo '{"status":"error","error_type":"missing_parameter","missing":"productIdentifier","suggestion":"请提供商品链接或淘口令，例如 --productIdentifier https://u.jd.com/xxx"}' >&2
  exit 1
fi

fx_check_auth

BODY=$(python3 -c "
import json, sys
d = {'productIdentifier': sys.argv[1]}
if sys.argv[2]:
    d['shopType'] = sys.argv[2]
print(json.dumps(d))
" "$PRODUCT_IDENTIFIER" "${SHOP_TYPE:-}")

RESP=$(fx_post "skill/api/compare-price" "$BODY" "比价服务暂时不可用，请稍后重试")

export _RESP="$RESP"
python3 -c "
import json, os, sys

resp = json.loads(os.environ['_RESP'])
fmt = sys.argv[1]
data = resp.get('data', resp)

if resp.get('code') == 200 and data:
    if fmt == 'table':
        total = data.get('totalCount', 0)
        print(f'比价商品总数: {total}')
        items = data.get('topLowestItems') or []
        if items:
            print(f'全网最低价 TOP{len(items)}:')
            print(f'{\"平台\":<8} {\"店铺\":<20} {\"价格\":<10} {\"标签\"}')
            print('─' * 60)
            for item in items:
                shop = item.get('shopName', '')[:18]
                price = item.get('price', '-')
                badge = item.get('badge', '')
                shop_type = item.get('shopType', '')
                print(f'{shop_type:<8} {shop:<20} ¥{price:<9} {badge}')
        else:
            print('暂无跨平台比价数据')
    else:
        print(json.dumps(data, ensure_ascii=False, indent=2))
else:
    print(json.dumps({'status': 'error', 'message': resp.get('message', '比价失败')}, ensure_ascii=False, indent=2))
" "$FORMAT"
