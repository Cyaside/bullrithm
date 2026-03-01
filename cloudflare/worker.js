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

const CACHE_HARD_TTL_SECONDS = 60 * 60 * 24; // 24h retention in Cloudflare cache
const DEFAULT_SOFT_TTL_SECONDS = 60; // fresh window fallback
const CACHE_KEY_NAMESPACE = "v2";
const RATE_LIMIT_COOLDOWN_SECONDS = 60 * 5; // 5m
const RATE_LIMIT_CACHE_KEY = `https://cache-key.local/${CACHE_KEY_NAMESPACE}/meta/rate_limit`;
const FUNCTION_SOFT_TTL_SECONDS = Object.freeze({
  SYMBOL_SEARCH: 60 * 60 * 6, // 6h
  OVERVIEW: 60 * 60 * 24, // 24h
  TIME_SERIES_DAILY: 60 * 60 * 2, // 2h
  NEWS_SENTIMENT: 60 * 10, // 10m
  TOP_GAINERS_LOSERS: 60 * 5, // 5m
  GLOBAL_QUOTE: 60, // 1m
});
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
  const fn = (params.get("function") || "").trim().toUpperCase();
  const softTtlSeconds = getSoftTtlForFunction(fn);

  const upstream = new URL("https://www.alphavantage.co/query");
  for (const [k, v] of params.entries()) {
    upstream.searchParams.set(k, v);
  }
  upstream.searchParams.set("apikey", env.ALPHA_VANTAGE_KEY);

  const cache = caches.default;
  const cacheKey = buildCacheKey(params);

  const cached = await cache.match(cacheKey);
  if (cached && isCacheFresh(cached, softTtlSeconds)) {
    return respondFromCache(cached, corsHeaders, "HIT");
  }

  const inRateLimitCooldown = await isRateLimitCooldown(cache);
  if (inRateLimitCooldown) {
    if (cached) {
      return respondFromCache(cached, corsHeaders, "STALE", "rate_limit_cooldown");
    }
    return json(
      {
        error: "Upstream rate limit",
        detail: "Rate limit cooldown active. Please retry later.",
      },
      429,
      corsHeaders,
      { "Retry-After": String(RATE_LIMIT_COOLDOWN_SECONDS) },
    );
  }

  let upstreamResp;
  try {
    upstreamResp = await fetch(upstream.toString());
  } catch (e) {
    if (cached) {
      return respondFromCache(cached, corsHeaders, "STALE", "upstream_fetch_failed");
    }
    return json(
      { error: "Upstream fetch failed", detail: String(e) },
      502,
      corsHeaders,
    );
  }

  if (!upstreamResp.ok) {
    if (upstreamResp.status === 429) {
      ctx.waitUntil(markRateLimitCooldown(cache));
    }
    if (cached) {
      return respondFromCache(cached, corsHeaders, "STALE", "upstream_non_200");
    }
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
    if (cached) {
      return respondFromCache(cached, corsHeaders, "STALE", "invalid_upstream_json");
    }
    return json({ error: "Invalid JSON from upstream" }, 502, corsHeaders);
  }

  if (payload["Error Message"]) {
    if (cached) {
      return respondFromCache(cached, corsHeaders, "STALE", "upstream_error_message");
    }
    return json({ error: payload["Error Message"] }, 400, corsHeaders);
  }

  if (payload["Note"]) {
    const safeDetail = sanitizeRateLimitDetail(payload["Note"]);
    ctx.waitUntil(markRateLimitCooldown(cache));
    if (cached) {
      return respondFromCache(cached, corsHeaders, "STALE", "upstream_rate_limited");
    }
    return json(
      { error: "Upstream rate limit", detail: safeDetail },
      429,
      corsHeaders,
      { "Retry-After": String(softTtlSeconds) },
    );
  }

  if (typeof payload["Information"] === "string" && payload["Information"].trim().length > 0) {
    const safeDetail = sanitizeRateLimitDetail(payload["Information"]);
    ctx.waitUntil(markRateLimitCooldown(cache));
    if (cached) {
      return respondFromCache(cached, corsHeaders, "STALE", "upstream_rate_limited");
    }
    return json(
      { error: "Upstream rate limit", detail: safeDetail },
      429,
      corsHeaders,
      { "Retry-After": String(softTtlSeconds) },
    );
  }

  const nowMs = Date.now();
  const response = json(payload, 200, corsHeaders, {
    "Cache-Control": `public, max-age=${CACHE_HARD_TTL_SECONDS}, stale-while-revalidate=${CACHE_HARD_TTL_SECONDS}`,
    "X-Cache": "MISS",
    "X-Cache-Function": fn || "UNKNOWN",
    "X-Cache-Soft-TTL": String(softTtlSeconds),
    "X-Cached-At": String(nowMs),
  });

  ctx.waitUntil(cache.put(cacheKey, response.clone()));
  return response;
}

function getSoftTtlForFunction(fn) {
  return FUNCTION_SOFT_TTL_SECONDS[fn] || DEFAULT_SOFT_TTL_SECONDS;
}

function buildCacheKey(params) {
  const sorted = Array.from(params.entries()).sort(([aKey, aValue], [bKey, bValue]) => {
    if (aKey === bKey) return aValue.localeCompare(bValue);
    return aKey.localeCompare(bKey);
  });

  const cacheKeyUrl = new URL(`https://cache-key.local/${CACHE_KEY_NAMESPACE}/query`);
  for (const [k, v] of sorted) {
    cacheKeyUrl.searchParams.set(k, v);
  }

  return new Request(cacheKeyUrl.toString(), { method: "GET" });
}

function isCacheFresh(cachedResponse, softTtlSeconds) {
  const ageSeconds = getCacheAgeSeconds(cachedResponse.headers);
  if (ageSeconds === null) {
    // Legacy entries without timestamp are treated as fresh until hard TTL expires.
    return true;
  }
  return ageSeconds <= softTtlSeconds;
}

function getCacheAgeSeconds(headers) {
  const cachedAtMs = Number.parseInt(headers.get("X-Cached-At") || "", 10);
  if (!Number.isFinite(cachedAtMs) || cachedAtMs <= 0) {
    return null;
  }
  return Math.max(0, Math.floor((Date.now() - cachedAtMs) / 1000));
}

function respondFromCache(cachedResponse, corsHeaders, cacheStatus, reason) {
  const headers = new Headers(cachedResponse.headers);
  for (const [k, v] of corsHeaders.entries()) {
    headers.set(k, v);
  }

  headers.set("X-Cache", cacheStatus);
  if (reason) {
    headers.set("X-Cache-Reason", reason);
    headers.set("Warning", '110 - "Response is stale"');
  }

  const ageSeconds = getCacheAgeSeconds(cachedResponse.headers);
  if (ageSeconds !== null) {
    headers.set("Age", String(ageSeconds));
  }

  return new Response(cachedResponse.body, {
    status: cachedResponse.status,
    headers,
  });
}

function sanitizeRateLimitDetail(rawDetail) {
  const detail = String(rawDetail || "");
  return detail.replace(/(API key(?:\s+as)?\s+)[A-Z0-9]+/gi, "$1[REDACTED]");
}

async function isRateLimitCooldown(cache) {
  const marker = await cache.match(new Request(RATE_LIMIT_CACHE_KEY, { method: "GET" }));
  return !!marker;
}

async function markRateLimitCooldown(cache) {
  const markerResponse = new Response("1", {
    status: 200,
    headers: {
      "Cache-Control": `public, max-age=${RATE_LIMIT_COOLDOWN_SECONDS}`,
      "Content-Type": "text/plain",
    },
  });
  await cache.put(new Request(RATE_LIMIT_CACHE_KEY, { method: "GET" }), markerResponse);
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
