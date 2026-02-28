/**
 * Cloudflare Worker proxy for Alpha Vantage.
 *
 * Required secret:
 * - ALPHA_VANTAGE_KEY
 *
 * Optional vars:
 * - ALLOWED_ORIGIN (e.g. https://bullrithm.pages.dev or http://localhost:3000)
 *
 * Endpoints:
 * - GET /query?function=SYMBOL_SEARCH&keywords=TSLA
 * - GET /query?function=OVERVIEW&symbol=AAPL
 * - GET /query?function=TIME_SERIES_DAILY&symbol=MSFT
 * - GET /query?function=NEWS_SENTIMENT&tickers=NVDA&limit=20
 * - GET /query?function=TOP_GAINERS_LOSERS
 * - GET /quote?symbol=AAPL (shortcut for GLOBAL_QUOTE)
 */

const CACHE_TTL_SECONDS = 30;
const ALLOWED_FUNCTIONS = new Set([
  "SYMBOL_SEARCH",
  "TIME_SERIES_DAILY",
  "OVERVIEW",
  "NEWS_SENTIMENT",
  "TOP_GAINERS_LOSERS",
  "GLOBAL_QUOTE",
]);

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const origin = request.headers.get("Origin");

    const corsHeaders = buildCorsHeaders(env, origin);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    if (request.method !== "GET") {
      return json({ error: "Method Not Allowed" }, 405, corsHeaders);
    }

    if (!env.ALPHA_VANTAGE_KEY) {
      return json({ error: "Missing ALPHA_VANTAGE_KEY secret" }, 500, corsHeaders);
    }

    if (url.pathname === "/quote") {
      const symbol = (url.searchParams.get("symbol") || "").trim().toUpperCase();
      if (!symbol) {
        return json({ error: "Missing symbol" }, 400, corsHeaders);
      }
      const params = new URLSearchParams({
        function: "GLOBAL_QUOTE",
        symbol,
      });
      return proxyToAlphaVantage(params, env, corsHeaders, ctx);
    }

    if (url.pathname === "/query") {
      const fn = (url.searchParams.get("function") || "").trim().toUpperCase();
      if (!fn) {
        return json({ error: "Missing function" }, 400, corsHeaders);
      }
      if (!ALLOWED_FUNCTIONS.has(fn)) {
        return json({ error: "Function not allowed" }, 400, corsHeaders);
      }

      const params = new URLSearchParams();
      for (const [key, value] of url.searchParams.entries()) {
        if (key.toLowerCase() === "apikey") {
          continue;
        }
        params.set(key, value);
      }
      params.set("function", fn);

      return proxyToAlphaVantage(params, env, corsHeaders, ctx);
    }

    return json({ error: "Not Found" }, 404, corsHeaders);
  },
};

async function proxyToAlphaVantage(params, env, corsHeaders, ctx) {
  const upstream = new URL("https://www.alphavantage.co/query");
  for (const [k, v] of params.entries()) {
    upstream.searchParams.set(k, v);
  }
  upstream.searchParams.set("apikey", env.ALPHA_VANTAGE_KEY);

  const cache = caches.default;
  const cacheKeyUrl = new URL("https://cache-key.local/query");
  for (const [k, v] of params.entries()) {
    cacheKeyUrl.searchParams.set(k, v);
  }
  const cacheKey = new Request(cacheKeyUrl.toString(), { method: "GET" });

  const cached = await cache.match(cacheKey);
  if (cached) {
    const headers = new Headers(cached.headers);
    for (const [k, v] of corsHeaders.entries()) {
      headers.set(k, v);
    }
    headers.set("X-Cache", "HIT");
    return new Response(cached.body, { status: cached.status, headers });
  }

  let upstreamResp;
  try {
    upstreamResp = await fetch(upstream.toString());
  } catch (e) {
    return json(
      { error: "Upstream fetch failed", detail: String(e) },
      502,
      corsHeaders,
    );
  }

  if (!upstreamResp.ok) {
    return json(
      {
        error: "Upstream non-200",
        status: upstreamResp.status,
        statusText: upstreamResp.statusText,
      },
      502,
      corsHeaders,
    );
  }

  let payload;
  try {
    payload = await upstreamResp.json();
  } catch {
    return json({ error: "Invalid JSON from upstream" }, 502, corsHeaders);
  }

  if (payload["Error Message"]) {
    return json({ error: payload["Error Message"] }, 400, corsHeaders);
  }

  if (payload["Note"]) {
    return json(
      { error: "Upstream rate limit", detail: payload["Note"] },
      429,
      corsHeaders,
      { "Retry-After": String(CACHE_TTL_SECONDS) },
    );
  }

  const response = json(payload, 200, corsHeaders, {
    "Cache-Control": `public, max-age=${CACHE_TTL_SECONDS}`,
    "X-Cache": "MISS",
  });

  ctx.waitUntil(cache.put(cacheKey, response.clone()));
  return response;
}

function buildCorsHeaders(env, origin) {
  const allowedOrigin = (env.ALLOWED_ORIGIN || "*").trim();
  const allowOriginValue = allowedOrigin === "*" ? "*" : origin === allowedOrigin ? origin : "null";

  return new Headers({
    "Access-Control-Allow-Origin": allowOriginValue,
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  });
}

function json(body, status, corsHeaders, extraHeaders = {}) {
  const headers = new Headers(corsHeaders);
  headers.set("Content-Type", "application/json; charset=utf-8");
  for (const [k, v] of Object.entries(extraHeaders)) {
    headers.set(k, v);
  }
  return new Response(JSON.stringify(body), { status, headers });
}
