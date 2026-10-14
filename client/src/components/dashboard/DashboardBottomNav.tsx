import { useEffect, useRef } from "react";
import { Link, useLocation } from "react-router-dom";
import type { LucideIcon } from "lucide-react";
import { useLanguage } from "../../hooks/useLanguage";

type NavigationLink = { label: string; href: string; icon?: LucideIcon; description?: string };

export function DashboardBottomNav({ links }: { links: NavigationLink[] }) {
  const { language } = useLanguage();
  const { pathname } = useLocation();
  const activeLink = useRef<HTMLAnchorElement>(null);
  const uniqueLinks = links.filter((link, index) => links.findIndex(item => item.href === link.href) === index);
  const activeHref = uniqueLinks.filter(link => pathname === link.href || pathname.startsWith(`${link.href}/`))
    .sort((a, b) => b.href.length - a.href.length)[0]?.href;
  useEffect(() => {
    activeLink.current?.scrollIntoView({ block: "nearest", inline: "nearest" });
  }, [activeHref]);
  return <nav data-dashboard-bottom-nav aria-label={language === "ar" ? "التنقل في لوحة التحكم" : "Dashboard navigation"}
    dir={language === "ar" ? "rtl" : "ltr"}
    className="fixed inset-x-0 bottom-0 z-40 border-t border-slate-200 bg-white pb-[env(safe-area-inset-bottom)] shadow-[0_-4px_16px_rgba(15,23,42,0.06)]">
    <div className="mx-auto flex max-w-[1800px] gap-1 overflow-x-auto px-3 py-2">
      {uniqueLinks.map(link => {
        const active = activeHref === link.href;
        const Icon = link.icon;
        return <Link key={link.href} to={link.href} ref={active ? activeLink : undefined}
          aria-current={active ? "page" : undefined} title={link.description || link.label}
          className={`flex min-h-14 min-w-20 shrink-0 flex-col items-center justify-center gap-1 rounded-xl px-3 text-center text-xs font-semibold transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 ${active ? "bg-blue-50 text-blue-800" : "text-slate-500 hover:bg-slate-50 hover:text-slate-900"}`}>
          {Icon && <Icon className="h-5 w-5" aria-hidden="true" />}
          <span className="whitespace-nowrap">{link.label}</span>
        </Link>;
      })}
    </div>
  </nav>;
}