const crypto = require("node:crypto");

const MUTATING = new Set(["POST", "PUT", "PATCH", "DELETE"]);
const KEY_PATTERN = /^[A-Za-z0-9_.:-]{8,128}$/;
const MAX_STORED_BODY = 64 * 1024;

// Responses of these areas contain credentials or one-time codes, so they are
// never stored (or replayed). They keep their own replay protection.
const EXCLUDED_PREFIXES = ["/auth", "/identity", "/mobile-security", "/payments/stripe/webhook"];

const sha = (value) => crypto.createHash("sha256").update(value).digest("hex");

/**
 * Makes unsafe requests safe to retry.
 *
 * A client sends `Idempotency-Key: <unique id>` with a POST/PUT/PATCH/DELETE.
 *  - first time:   the request runs normally and its (non-5xx) answer is stored;
 *  - same key again after it finished: the stored answer is replayed
 *    (`Idempotent-Replay: true`) and the handler does NOT run again;
 *  - same key while the first is still running: 409, retry shortly;
 *  - same key with a different method/path/body: 422 (client bug).
 * 5xx answers are not stored, so a failed attempt can be retried with the
 * same key. Requests without the header behave exactly as before. If the
 * store is unavailable the request proceeds (fail open): this guard must
 * never take the API down.
 */
function createIdempotency(store) {
  return async function idempotency(req, res, next) {
    const key = req.get("Idempotency-Key");
    if (!key || !MUTATING.has(req.method)) return next();
    if (EXCLUDED_PREFIXES.some((p) => req.path === p || req.path.startsWith(`${p}/`))) return next();
    if (!KEY_PATTERN.test(key)) {
      return res.status(400).json({ message: "Idempotency-Key is invalid." });
    }

    // The caller's identity (token) or network address separates tenants, so one
    // user can never replay or block another user's key.
    const caller = req.get("Authorization") || req.ip || "anonymous";
    const scope = sha(String(caller));
    const bodyText = req.body === undefined ? "" : JSON.stringify(req.body);
    const fingerprint = sha(`${req.method} ${req.baseUrl}${req.path} ${bodyText}`);

    let begun;
    try {
      begun = await store.begin(scope, key, fingerprint);
    } catch {
      return next(); // fail open
    }

    if (begun.state === "mismatch") {
      return res.status(422).json({ message: "Idempotency-Key was already used with a different request." });
    }
    if (begun.state === "in_progress") {
      res.set("Retry-After", "1");
      return res.status(409).json({ message: "A request with this Idempotency-Key is still being processed." });
    }
    if (begun.state === "done") {
      res.set("Idempotent-Replay", "true");
      return res.status(begun.record.status).json(begun.record.body);
    }

    // state === "new": run the handler and remember its answer.
    let captured;
    let settled = false;
    const originalJson = res.json.bind(res);
    res.json = (body) => {
      captured = body;
      return originalJson(body);
    };
    res.on("finish", () => {
      settled = true;
      const keep =
        res.statusCode < 500 &&
        captured !== undefined &&
        JSON.stringify(captured).length <= MAX_STORED_BODY;
      const task = keep
        ? store.complete(scope, key, res.statusCode, captured)
        : store.release(scope, key);
      Promise.resolve(task).catch(() => undefined);
    });
    res.on("close", () => {
      // Connection dropped before an answer: free the key for the retry.
      if (!settled) Promise.resolve(store.release(scope, key)).catch(() => undefined);
    });
    return next();
  };
}

/** MongoDB-backed store (production). */
function mongoStore(Model) {
  return {
    async begin(scope, key, fingerprint) {
      try {
        await Model.create({ scope, key, fingerprint });
        return { state: "new" };
      } catch (error) {
        if (!error || error.code !== 11000) throw error;
      }
      const record = await Model.findOne({ scope, key }).lean();
      if (!record) return { state: "new" };
      if (record.fingerprint !== fingerprint) return { state: "mismatch" };
      if (record.state === "done") return { state: "done", record };
      return { state: "in_progress" };
    },
    complete: (scope, key, status, body) =>
      Model.updateOne({ scope, key }, { $set: { state: "done", status, body } }),
    release: (scope, key) => Model.deleteOne({ scope, key }),
  };
}

module.exports = { createIdempotency, mongoStore, KEY_PATTERN };
