const categories = Object.freeze([
  "payments",
  "admission",
  "documents",
  "consultations",
  "visa",
  "support",
  "announcements",
  "community",
]);

const defaults = Object.freeze(Object.fromEntries(categories.map((key) => [key, true])));

function shapePreferences(row) {
  return {
    ...Object.fromEntries(categories.map((key) => [key, row?.[key] !== false])),
    // Existing clients use this marker to upload their account-scoped local
    // preferences once instead of overwriting them with defaults on first read.
    _initialized: Boolean(row),
  };
}

function validatePreferenceUpdate(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) return false;
  const entries = Object.entries(input);
  return entries.length > 0 && entries.every(([key, value]) => categories.includes(key) && typeof value === "boolean");
}

module.exports = { categories, defaults, shapePreferences, validatePreferenceUpdate };
