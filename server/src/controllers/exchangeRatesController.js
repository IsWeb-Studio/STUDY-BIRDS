const allowed = ['USD', 'EUR', 'GBP', 'SAR', 'AED', 'KWD', 'QAR', 'JOD', 'TRY', 'EGP'];
const cache = new Map();
const pending = new Map();
async function download(base) {
  const quotes = allowed.filter(code => code !== base).join(',');
  const url = new URL('https://api.frankfurter.dev/v2/rates');
  url.search = new URLSearchParams({ base, quotes }).toString();
  const response = await fetch(url, { signal: AbortSignal.timeout(8000) });
  if (!response.ok) throw new Error('Exchange rate provider unavailable');
  const rows = await response.json();
  if (!Array.isArray(rows)) throw new Error('Invalid exchange rates');
  const rates = { [base]: 1 };
  for (const row of rows) {
    if (row.base === base && allowed.includes(row.quote) &&
        typeof row.rate === 'number' && Number.isFinite(row.rate) && row.rate > 0) {
      rates[row.quote] = row.rate;
    }
  }
  if (!allowed.every(code => rates[code] > 0)) throw new Error('Incomplete exchange rates');
  const dates = rows.map(row => row.date).filter(date => /^\d{4}-\d{2}-\d{2}$/.test(date)).sort();
  const data = { base, date: dates[0], rates };
  cache.set(base, { at: Date.now(), data });
  return data;
}
async function getExchangeRates(req, res) {
  const base = String(req.query.base || 'USD').trim().toUpperCase();
  if (!allowed.includes(base)) return res.status(400).json({ message: 'Unsupported base currency' });
  const saved = cache.get(base);
  if (saved && Date.now() - saved.at < 3600000) return res.json(saved.data);
  try {
    if (!pending.has(base)) pending.set(base, download(base).finally(() => pending.delete(base)));
    return res.json(await pending.get(base));
  } catch {
    if (saved && Date.now() - saved.at < 86400000) return res.json({ ...saved.data, stale: true });
    return res.status(502).json({ message: 'تعذر جلب أسعار الصرف. حاول لاحقًا.' });
  }
}
module.exports = { getExchangeRates };
