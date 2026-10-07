// Server-Sent Events (SSE) client registry for real-time messaging.
// Each connected user can have multiple tabs; all receive the same events.
// Clients are keyed by userId (string) → Set of response objects.

const clients = new Map();

function register(userId, res) {
  const id = String(userId);
  if (!clients.has(id)) clients.set(id, new Set());
  clients.get(id).add(res);
}

function unregister(userId, res) {
  const id = String(userId);
  const set = clients.get(id);
  if (!set) return;
  set.delete(res);
  if (set.size === 0) clients.delete(id);
}

function push(userId, eventName, data) {
  const id = String(userId);
  const set = clients.get(id);
  if (!set || !set.size) return;
  const payload = `event: ${eventName}\ndata: ${JSON.stringify(data)}\n\n`;
  for (const res of set) {
    try { res.write(payload); } catch { /* client disconnected */ }
  }
}

module.exports = { register, unregister, push };
