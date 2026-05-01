#!/usr/bin/env node
// fx-api.mjs — feima-lab 公共请求库
// 用法：在领域 skill 脚本中 import { fxCheckAuth, fxPost, fxCheckResponse, FX_BASE_URL, readPeerIdentity } from './fx-api.mjs'

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

// ── 常量 ──
export const FX_BASE_URL = 'https://api-ai-brain.fenxianglife.com/fenxiang-ai-brain';

// ── fxCheckAuth ──
// 校验 FX_AI_API_KEY，未设置则输出标准错误 JSON 并 exit 1
export function fxCheckAuth() {
  const key = process.env.FX_AI_API_KEY;
  if (!key) {
    process.stderr.write(
      '{"status":"error","error_type":"missing_api_key","suggestion":"请设置环境变量 FX_AI_API_KEY，从 https://platform.feima.ai/ 登录获取"}\n'
    );
    process.exit(1);
  }
  return key;
}

// ── fxPost(endpoint, body, errMsg) ──
// 发送 POST 请求到 feima-lab 后端，返回响应 JSON 字符串
// 参数：
//   endpoint — API 路径（如 skill/api/convert），不含 BASE_URL 前缀
//   body     — 请求体对象（会被 JSON.stringify）
//   errMsg   — 可选，失败时的用户提示（默认"服务暂时不可用，请稍后重试"）
// 失败时输出错误 JSON 到 stderr 并 exit 1
export async function fxPost(endpoint, body, errMsg = '服务暂时不可用，请稍后重试') {
  const key = process.env.FX_AI_API_KEY;
  const url = `${FX_BASE_URL}/${endpoint}`;

  let resp;
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 30000);
    try {
      resp = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Fx-Ai-Api-Key': `Bearer ${key}`,
        },
        body: typeof body === 'string' ? body : JSON.stringify(body),
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timer);
    }
  } catch (e) {
    process.stderr.write(
      JSON.stringify({ status: 'error', error_type: 'api_unavailable', suggestion: errMsg }) + '\n'
    );
    process.exit(1);
  }

  if (!resp.ok) {
    process.stderr.write(
      JSON.stringify({ status: 'error', error_type: 'api_unavailable', suggestion: errMsg }) + '\n'
    );
    process.exit(1);
  }

  return resp.text();
}

// ── readPeerIdentity() ──
// 读取当前用户目录下的 identity.json（由 openclaw 微信插件在用户首次对话时落盘）。
// 文件不存在、解析失败或缺字段都返回 null，调用方自行降级到老链路。
// 依赖 spawn 子进程的 cwd 指向 per-user workspaceDir（这是 openclaw Bash 工具的默认行为）。
export function readPeerIdentity() {
  try {
    const raw = readFileSync(join(process.cwd(), 'identity.json'), 'utf-8');
    const data = JSON.parse(raw);
    if (data && typeof data.peerId === 'string' && data.peerId.length > 0) {
      return data;
    }
    return null;
  } catch {
    return null;
  }
}

// ── fxCheckResponse(respJson) ──
// 校验响应：code==200 返回 data 对象，否则输出错误到 stderr 并 exit 1
// 参数：
//   respJson — 完整的响应 JSON 字符串
export function fxCheckResponse(respJson) {
  let resp;
  try {
    resp = JSON.parse(respJson);
  } catch (e) {
    process.stderr.write(
      JSON.stringify({ status: 'error', error_type: 'api_unavailable', suggestion: '响应解析失败' }) + '\n'
    );
    process.exit(1);
  }

  const data = resp.data !== undefined ? resp.data : resp;

  if (resp.code === 200 && data) {
    return data;
  } else {
    const msg = resp.message || '请求失败';
    const err = (data && typeof data === 'object' && data.errorMessage) ? data.errorMessage : msg;
    process.stderr.write(
      JSON.stringify({ status: 'error', message: err }, null, 2) + '\n'
    );
    process.exit(1);
  }
}

// ── 价格单位格式化 ──
// brain ComparePriceDTO / HistoryPriceDTO 内部价格字段类型 Long 单位"分"，
// 给 brain 内部 agent skill 用；fanli skill 出口必须转 "X.XX元" 字符串保持口径一致。
// 不能改 brain 底层 DTO（13+ processor 共用），所以在 fanli skill 出口转。

// 分(number) → "X.XX元" 字符串。非 number 透传（已是字符串、null 都安全 → 幂等）
export const fmtYuan = (cents) =>
  typeof cents === 'number' ? (cents / 100).toFixed(2) + '元' : cents;

// ComparePriceItemVO 字段就地转换，字段名一一显式赋值与 brain-domain ComparePriceDTO.ComparePriceItemVO 对齐
export function formatPriceItemVO(item) {
  if (!item || typeof item !== 'object') return;
  item.price = fmtYuan(item.price);
  item.commission = fmtYuan(item.commission);
  item.itemDiscountPrice = fmtYuan(item.itemDiscountPrice);
  item.itemPrice = fmtYuan(item.itemPrice);
  item.finalPrice = fmtYuan(item.finalPrice);
  item.savingMoney = fmtYuan(item.savingMoney);
  item.totalComm = fmtYuan(item.totalComm);
  item.shareComm = fmtYuan(item.shareComm);
  item.vipMoreComm = fmtYuan(item.vipMoreComm);
  if (item.coupon) item.coupon.couponMoney = fmtYuan(item.coupon.couponMoney);
  if (Array.isArray(item.foldedItems)) item.foldedItems.forEach(formatPriceItemVO);
}

// ComparePriceDTO 就地转换：topLowestItems + floorPriceItem + platforms
export function formatComparePriceData(cpd) {
  if (!cpd || typeof cpd !== 'object') return;
  formatPriceItemVO(cpd.floorPriceItem);
  if (Array.isArray(cpd.topLowestItems)) cpd.topLowestItems.forEach(formatPriceItemVO);
  if (Array.isArray(cpd.platforms)) {
    cpd.platforms.forEach((p) => { if (p) p.price = fmtYuan(p.price); });
  }
}

// HistoryPriceDTO 就地转换：itemHistoryStatisticsResult + itemPriceMonitorResult + subResults + priceAnalyzeItemResults
export function formatHistoryPriceData(hpd) {
  if (!hpd || typeof hpd !== 'object') return;
  const stats = hpd.itemHistoryStatisticsResult;
  if (stats) {
    stats.historyLowestPrice = fmtYuan(stats.historyLowestPrice);
    stats.usuallySellPrice = fmtYuan(stats.usuallySellPrice);
    stats.historyLowestPriceBy30Days = fmtYuan(stats.historyLowestPriceBy30Days);
    stats.lowest60DaysPrice = fmtYuan(stats.lowest60DaysPrice);
    stats.lowest180DaysPrice = fmtYuan(stats.lowest180DaysPrice);
    stats.lowest618Price = fmtYuan(stats.lowest618Price);
    stats.lowest1111Price = fmtYuan(stats.lowest1111Price);
  }
  const monitor = hpd.itemPriceMonitorResult;
  if (monitor) monitor.monitorPrice = fmtYuan(monitor.monitorPrice);
  if (Array.isArray(hpd.subResults)) {
    hpd.subResults.forEach((p) => {
      if (!p) return;
      p.price = fmtYuan(p.price);
      p.originalPrice = fmtYuan(p.originalPrice);
    });
  }
  if (Array.isArray(hpd.priceAnalyzeItemResults)) {
    hpd.priceAnalyzeItemResults.forEach((p) => {
      if (!p) return;
      p.itemDiscountPrice = fmtYuan(p.itemDiscountPrice);
      p.savingMoney = fmtYuan(p.savingMoney);
    });
  }
}
