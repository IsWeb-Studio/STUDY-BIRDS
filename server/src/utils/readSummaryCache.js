const entries = new Map();
let generation = 0;
module.exports = {
  generation: () => generation,
  get(key) { const item = entries.get(key); if (!item || item.expires <= Date.now()) { entries.delete(key); return null; } return item.value; },
  set(key, value, stamp) { if (stamp !== generation) return; if (entries.size > 512) entries.clear(); entries.set(key, { value, expires: Date.now() + 5000 }); },
  clear() { generation++; entries.clear(); },
};
