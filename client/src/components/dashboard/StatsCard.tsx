import type { ReactNode } from "react";
import { AccentWave } from "../ui/AccentWave";

export const StatsCard = ({ label, value, icon }: { label: string; value: string | number; icon?: ReactNode }) => (
  <div className="dashboard-stat panel relative overflow-hidden border-t-4 border-t-accent-700 bg-[linear-gradient(180deg,rgba(20,45,93,0.98)_0%,rgba(10,25,49,0.98)_100%)] p-4 sm:p-5 lg:p-6">
    <AccentWave
      className="dashboard-stat-decoration right-0 top-0 h-20 w-28 rounded-bl-[2.1rem] rounded-tl-[3rem] rounded-br-[0.4rem] opacity-95"
      shadowClassName="-left-[4%] -top-[54%] h-[78%] w-[112%]"
      glowClassName="bottom-[-30%] h-[50%]"
    />
    <div className="flex items-start justify-between gap-3">
      <p className="dashboard-stat-label relative z-10 text-[11px] uppercase tracking-[0.12em] text-brand-100/80 sm:text-xs lg:text-sm">{label}</p>
      {icon ? (
        <span className="dashboard-stat-icon relative z-10 inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-2xl border border-white/10 bg-white/10 text-accent-300 shadow-sm backdrop-blur-sm sm:h-10 sm:w-10 lg:h-11 lg:w-11">
          {icon}
        </span>
      ) : null}
    </div>
    <p className="dashboard-stat-value relative z-10 mt-3 text-2xl font-semibold text-white sm:text-[2rem] lg:mt-4 lg:text-3xl">{value}</p>
  </div>
);
