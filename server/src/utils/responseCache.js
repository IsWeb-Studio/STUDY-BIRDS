const cacheStore = new Map();
let cacheGeneration = 0;
// Keep the fast server cache, but require browsers and proxies to revalidate.
const cacheControl = "public, max-age=0, must-revalidate";

const buildCacheKey = (req) => `${req.originalUrl}`;

const getCachedResponse = (key) => {
  const cached = cacheStore.get(key);

  if (!cached) {
    return null;
  }

  if (cached.expiresAt <= Date.now()) {
    cacheStore.delete(key);
    return null;
  }

  return cached.payload;
};

const setCachedResponse = (key, payload, ttlMs) => {
  cacheStore.set(key, {
    payload,
    expiresAt: Date.now() + ttlMs,
  });
};

const cacheRoute = (ttlMs = 60_000) => (req, res, next) => {
  if (req.method !== "GET") {
    next();
    return;
  }

  const key = buildCacheKey(req);
  const requestGeneration = cacheGeneration;
  const cached = getCachedResponse(key);

  if (cached) {
    res.set("X-Cache", "HIT");
    Object.entries(cached.headers).forEach(([header, value]) => {
      res.set(header, value);
    });
    res.status(cached.statusCode).send(cached.body);
    return;
  }

  const originalSend = res.send.bind(res);

  res.send = (body) => {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      res.set("Cache-Control", cacheControl);
      const payload = {
        statusCode: res.statusCode,
        body,
        headers: {
          "Content-Type": res.get("Content-Type") || "application/json; charset=utf-8",
          "Cache-Control": cacheControl,
        },
      };
      // A read started before a mutation must not restore invalidated data.
      if (requestGeneration === cacheGeneration) setCachedResponse(key, payload, ttlMs);
      res.set("X-Cache", "MISS");
    }

    return originalSend(body);
  };

  next();
};

const clearResponseCache = () => {
  cacheGeneration++;
  cacheStore.clear();
};

module.exports = {
  cacheRoute,
  clearResponseCache,
};
