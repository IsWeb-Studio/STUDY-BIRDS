const sections = require("../constants/employeeSections.json");
const permissionKeys = new Set(sections.map((section) => section.key));

const validPermissions = (value) => Array.isArray(value) && value.every((key) => typeof key === "string" && permissionKeys.has(key));
const hasSection = (user, section) => user?.role === "admin" || (user?.role === "employee" && user.permissions?.includes(section));
const forbidden = (res) => res.status(403).json({ message: "You do not have access to this section" });
const requireSection = (section) => (req, res, next) => hasSection(req.user, section) ? next() : forbidden(res);

// Deny unknown endpoints by default. User/employee management stays admin-only.
const authorizeAdminSection = (req, res, next) => {
  if (req.user?.role === "admin") return next();
  if (req.user?.role !== "employee") return forbidden(res);
  if (/^\/students\/[^/]+\/(insurance|equivalency)$/.test(req.path)) {
    return hasSection(req.user, 'services') ? next() : forbidden(res);
  }
  const resource = req.path.split("/").filter(Boolean)[0];
  const section = sections.find((item) => item.resources.includes(resource));
  if (section && hasSection(req.user, section.key)) return next();
  // Read-only lookup data needed by specific editors, never write access.
  if (["GET", "HEAD"].includes(req.method)) {
    if (req.path.replace(/\/$/, "") === "/countries" && ["universities", "services", "faqs", "exhibitions"].some((key) => hasSection(req.user, key))) return next();
    if (req.path.replace(/\/$/, "") === "/study-fields" && hasSection(req.user, "programs")) return next();
    if (req.path.replace(/\/$/, "") === "/students" && hasSection(req.user, "student-financials")) return next();
  }
  return forbidden(res);
};

const authorizeApplicationRead = (req, res, next) => {
  if (req.user?.role === "student" || hasSection(req.user, "applications")) return next();
  return forbidden(res);
};

module.exports = { validPermissions, hasSection, requireSection, authorizeAdminSection, authorizeApplicationRead };
