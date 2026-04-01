#!/usr/bin/env bash
# 统一执行引擎：调度脚本，支持快捷命令和标准调用
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$SCRIPT_DIR"

usage() {
  cat <<'HELP'
用法:
  快捷命令（推荐）:
    run.sh convert "<链接>"                    # 转链（含比价+历史价）
    run.sh compare-price "<链接>"              # 仅比价

  标准调用:
    run.sh call <接口名> [参数...]              # 调用指定接口
    run.sh call convert --help                 # 查看接口帮助

  辅助:
    run.sh list                                # 列出所有可用接口
    run.sh show <接口名>                       # 查看接口源码

数据流向: 商品链接会被发送到 https://api-ai-brain.fenxianglife.com 进行解析
HELP
}

cmd="${1:-}"
case "$cmd" in
  --help|-h)
    usage
    ;;

  list)
    echo "可用接口："
    python3 -c "
import os, sys, re
api_dir = sys.argv[1]
rows = []
for f in sorted(os.listdir(api_dir)):
    if not f.endswith('.sh') or f == 'run.sh':
        continue
    name = f[:-3]
    desc = ''
    with open(os.path.join(api_dir, f)) as fp:
        for line in fp:
            m = re.match(r'^#\s*description:\s*(.+)', line)
            if m:
                desc = m.group(1).strip()
                break
    rows.append((name, desc))
if rows:
    w0 = max(len(r[0]) for r in rows)
    for name, desc in rows:
        print(f'  {name:<{w0}}  {desc}')
" "$API_DIR"
    ;;

  show)
    name="${2:-}"
    [ -z "$name" ] && { echo "错误: 请指定接口名"; exit 1; }
    sh_file="$API_DIR/$name.sh"
    [ ! -f "$sh_file" ] && { echo "错误: 接口 '$name' 不存在"; exit 1; }
    cat "$sh_file"
    ;;

  call)
    name="${2:-}"
    [ -z "$name" ] && { echo "错误: 请指定接口名"; exit 1; }
    shift 2

    if [ -f "$API_DIR/$name.sh" ]; then
      bash "$API_DIR/$name.sh" "$@"
    else
      echo "错误: 接口 '$name' 不存在，运行 'bash run.sh list' 查看可用接口" >&2
      exit 1
    fi
    ;;

  # 快捷命令：run.sh convert "<链接>" → call convert --tpwd "<链接>"
  convert)
    link="${2:-}"
    [ -z "$link" ] && { echo "错误: 请提供商品链接，例如 run.sh convert \"https://e.tb.cn/h.xxx\""; exit 1; }
    shift 2
    bash "$API_DIR/convert.sh" --tpwd "$link" "$@"
    ;;

  # 快捷命令：run.sh compare-price "<链接>" → call compare-price --productIdentifier "<链接>"
  compare-price)
    link="${2:-}"
    [ -z "$link" ] && { echo "错误: 请提供商品链接，例如 run.sh compare-price \"https://e.tb.cn/h.xxx\""; exit 1; }
    shift 2
    bash "$API_DIR/compare-price.sh" --productIdentifier "$link" "$@"
    ;;

  *)
    usage
    ;;
esac
