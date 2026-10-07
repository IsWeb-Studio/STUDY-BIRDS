import { ChevronDown, Search, X, type LucideIcon } from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { useLanguage } from "../../hooks/useLanguage";
import { dt } from "../../utils/dashboardTranslations";

export const DashboardSidebar = ({
  links,
  sectionLabel,
  title,
  subtitle,
  onNavigate,
  onClose,
}: {
  links: Array<{ label: string; href: string; icon?: LucideIcon; description?: string; group?: string }>;
  sectionLabel?: string;
  title: string;
  subtitle: string;
  onNavigate?: () => void;
  onClose?: () => void;
}) => {
  const location = useLocation();
  const { language } = useLanguage();
  const [query, setQuery] = useState("");
  const uniqueLinks = useMemo(() => links.filter((link, index) => links.findIndex((item) => item.href === link.href) === index), [links]);
  const activeHref = uniqueLinks.filter((link) => location.pathname === link.href || location.pathname.startsWith(`${link.href}/`)).sort((a, b) => b.href.length - a.href.length)[0]?.href;
  const groups = useMemo(() => {
    const result = new Map<string, typeof links>();
    const search = query.trim().toLocaleLowerCase();
    for (const link of uniqueLinks) {
      if (search && !`${link.label} ${link.description || ""}`.toLocaleLowerCase().includes(search)) continue;
      const group = link.group || (language === "ar" ? "مساحة العمل" : "Workspace");
      result.set(group, [...(result.get(group) || []), link]);
    }
    return Array.from(result.entries());
  }, [uniqueLinks, query, language]);

  return (
    <aside className="dashboard-sidebar panel overflow-hidden p-0">
      <div className="border-b border-slate-100 px-5 py-5">
        <div className="flex items-center justify-between gap-3">
          <p className="text-xs font-medium text-blue-600">{sectionLabel || dt(language, "controlCenter")}</p>
          {onClose && <button type="button" onClick={onClose} aria-label={language === "ar" ? "إغلاق القائمة الجانبية" : "Close sidebar"} title={language === "ar" ? "إغلاق القائمة الجانبية" : "Close sidebar"} className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-slate-400 transition hover:bg-slate-100 hover:text-slate-900"><X className="h-4 w-4" aria-hidden="true" /></button>}
        </div>
        <h2 className="mt-2 text-lg font-bold text-slate-900">{title}</h2>
        <p className="mt-2 text-xs leading-6 text-slate-500">{subtitle}</p>
      </div>
      <div className="relative mx-3 mt-4">
        <Search className="pointer-events-none absolute start-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
        <input type="search" value={query} onChange={(event) => setQuery(event.target.value)} aria-label={language === "ar" ? "البحث في القائمة" : "Search navigation"} placeholder={language === "ar" ? "ابحث عن قسم..." : "Find a section..."} className="w-full rounded-xl border border-slate-200 bg-slate-50 py-2.5 pe-8 ps-9 text-xs outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100" />
        {query && <button type="button" onClick={() => setQuery("")} aria-label={language === "ar" ? "مسح البحث" : "Clear search"} className="absolute end-2 top-1/2 -translate-y-1/2 rounded p-1 text-slate-400 hover:text-slate-700"><X className="h-3.5 w-3.5" /></button>}
      </div>
      <nav aria-label={title} className="space-y-3 p-3">
        {groups.map(([group, items]) => <div key={group}>
          <p className="px-3 pb-2 pt-3 text-[11px] font-semibold text-slate-400">{group}</p>
          <div className="space-y-1">
        {items.map((link) => {
          const active = activeHref === link.href;
          const Icon = link.icon;
          return (
            <Link
              key={`${link.href}:${link.label}`}
              to={link.href}
              onClick={onNavigate}
              aria-current={active ? "page" : undefined}
              title={link.description || link.label}
              className={`block rounded-xl border px-3 py-2.5 transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 ${
                active
                  ? "border-blue-100 bg-blue-50 text-blue-800"
                  : "border-transparent text-slate-600 hover:bg-slate-50 hover:text-slate-900"
              }`}
            >
              <div className="flex items-center gap-3">
                {Icon ? <Icon className={`h-4 w-4 shrink-0 ${active ? "text-blue-600" : "text-slate-400"}`} /> : null}
                <span className="min-w-0 flex-1 text-xs font-semibold leading-5">{link.label}</span>
                {active && <ChevronDown className="h-3 w-3 shrink-0 -rotate-90 rtl:rotate-90" />}
              </div>
            </Link>
          );
        })}
          </div>
        </div>)}
        {groups.length === 0 && <p role="status" className="px-3 py-6 text-center text-xs text-slate-500">{language === "ar" ? "لا توجد أقسام مطابقة" : "No matching sections"}</p>}
      </nav>
    </aside>
  );
};
