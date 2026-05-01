#!/usr/bin/env node
// name: convert
// description: 商品转链，输入商品链接/淘口令，返回商品信息、到手价、优惠券、推广链接等

import { fileURLToPath } from 'url';
import { join, dirname } from 'path';
import { existsSync } from 'fs';

// ── 加载公共库 ──
const _scriptDir = dirname(fileURLToPath(import.meta.url));
const _fxApiPath = join(_scriptDir, '../../fx-base/scripts/fx-api.mjs');
if (!existsSync(_fxApiPath)) {
  process.stderr.write(
    '{"status":"error","error_type":"missing_dependency","suggestion":"缺少 fx-base，请安装：npx skills install fangshan101-coder/fx-base"}\n'
  );
  process.exit(1);
}

const { fxCheckAuth, fxPost, readPeerIdentity, formatComparePriceData, formatHistoryPriceData } = await import(_fxApiPath);

function help() {
  process.stdout.write(`用法: convert --tpwd <链接或口令> [选项]

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
  convert --tpwd "https://click.meituan.com/t?t=1&c=2&p=xxx"
  convert --tpwd "￥xxx￥" --format table

数据流向: 商品链接会被发送到 https://api-ai-brain.fenxianglife.com 进行解析
`);
  process.exit(0);
}

// ── 参数解析 ──
const args = process.argv.slice(2);
let tpwd = '';
let format = 'json';
let includeCompare = 'true';
let includeHistory = 'true';

for (let i = 0; i < args.length; i++) {
  switch (args[i]) {
    case '--help':
    case '-h':
      help();
      break;
    case '--tpwd':
      tpwd = args[++i] || '';
      break;
    case '--format':
      format = args[++i] || 'json';
      break;
    case '--includeComparePrice':
      includeCompare = args[++i] || 'true';
      break;
    case '--includeHistoryPrice':
      includeHistory = args[++i] || 'true';
      break;
  }
}

if (!tpwd) {
  process.stderr.write(
    '{"status":"error","error_type":"missing_parameter","missing":"tpwd","suggestion":"请提供商品链接或淘口令，例如 --tpwd https://u.jd.com/xxx"}\n'
  );
  process.exit(1);
}

fxCheckAuth();

const body = { tpwd };
if (includeCompare !== 'true') body.includeComparePrice = false;
if (includeHistory !== 'true') body.includeHistoryPrice = false;

// 存在 identity.json 时带上 peerId 走 fanli 返利模式；读不到则走老链路（参数可选）
const _identity = readPeerIdentity();
if (_identity?.peerId) {
  body.peerId = _identity.peerId;
  if (_identity.nickname) body.nickname = _identity.nickname;
  if (_identity.avatar) body.avatar = _identity.avatar;
}

const respText = await fxPost('skill/api/convert', body, '转链服务暂时不可用，请稍后重试');

let resp;
try {
  resp = JSON.parse(respText);
} catch (e) {
  process.stderr.write('{"status":"error","error_type":"api_unavailable","suggestion":"响应解析失败"}\n');
  process.exit(1);
}

const data = resp.data !== undefined ? resp.data : resp;

// brain /skill/api/convert 顶层字段已是元字符串(LLMFieldTransformer 转过)，
// 但聚合的 comparePriceData / historyPriceData 嵌套对象内部仍是分 Long，这里转换。
if (data && typeof data === 'object') {
  formatComparePriceData(data.comparePriceData);
  formatHistoryPriceData(data.historyPriceData);
}

if (resp.code === 200 && data) {
  if (format === 'table') {
    for (const [k, v] of Object.entries(data)) {
      if (v !== null && v !== '' && v !== false) {
        process.stdout.write(`${k}: ${v}\n`);
      }
    }
  } else {
    process.stdout.write(JSON.stringify(data, null, 2) + '\n');
  }
} else {
  const msg = resp.message || '转链失败';
  const err = (data && typeof data === 'object' && data.errorMessage) ? data.errorMessage : msg;
  process.stdout.write(
    JSON.stringify({ status: 'error', message: err, suggestion: '请检查链接是否正确' }, null, 2) + '\n'
  );
}
