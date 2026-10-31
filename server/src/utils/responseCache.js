const cacheStore = new Map();
const pendingReads = new Map();
const maxEntries = 256;
const maxBytes = 16 * 1024 * 1024;
let storedBytes = 0;
const removeEntry = (key) => {
  storedBytes -= cacheStore.get(key)?.bytes || 0;
  cacheStore.delete(key);
};
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
    removeEntry(key);
    return null;
  }

  return cached.payload;
};

const setCachedResponse = (key, payload, ttlMs) => {
  const bytes = Buffer.byteLength(payload.body);
  // Large legacy exports must not crowd out interactive catalog pages.
  if (bytes > 2 * 1024 * 1024) return;
  removeEntry(key);
  while (cacheStore.size >= maxEntries || storedBytes + bytes > maxBytes) {
    removeEntry(cacheStore.keys().next().value);
  }
  cacheStore.set(key, {
    bytes,
    payload,
    expiresAt: Date.now() + ttlMs,
  });
  storedBytes += bytes;
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

  // These routes serve public catalog data only. Share a successful read, never
  // errors, cookies, or headers from another request. Writes detach old readers.
  const pending = pendingReads.get(key);
  if (pending && pending.generation === cacheGeneration && pending.waiters < 100) {
    pending.waiters++;
    pending.done.then(() => {
      if (!res.destroyed && !res.writableEnded) cacheRoute(ttlMs)(req, res, next);
    });
    return;
  }
  let complete;
  const entry = { generation: cacheGeneration, waiters: 0, done: new Promise(resolve => { complete = resolve; }) };
  // Bound the number of unique in-flight keys; excess requests run normally.
  if (pendingReads.size < maxEntries && !pending) pendingReads.set(key, entry);
  const release = () => {
    if (pendingReads.get(key) === entry) pendingReads.delete(key);
    complete();
  };
  res.once?.('finish', release);
  res.once?.('close', release);

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
      if (requestGeneration === cacheGeneration && (typeof body === 'string' || Buffer.isBuffer(body))) setCachedResponse(key, payload, ttlMs);
      res.set("X-Cache", "MISS");
    }

    const sent = originalSend(body);
    release();
    return sent;
  };

  next();
};

const clearResponseCache = () => {
  cacheGeneration++;
  cacheStore.clear();
  storedBytes = 0;
  pendingReads.clear();
};

module.exports = {
  cacheRoute,
  clearResponseCache,
};
