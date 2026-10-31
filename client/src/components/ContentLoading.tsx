import { useLanguage } from '../hooks/useLanguage';

/** Reserve content space during the first read; use the compact state on refresh. */
export const ContentLoading = ({ layout = 'rows', compact = false }: {
  layout?: 'rows' | 'cards'; compact?: boolean;
}) => {
  const { language } = useLanguage();
  return (
    <div role="status" aria-live="polite" className={compact ? 'py-3' : 'space-y-4 py-4'}>
      <div className="flex items-center gap-3 text-sm font-medium text-brand-700">
        <span aria-hidden="true" className="h-5 w-5 shrink-0 rounded-full border-2 border-brand-100 border-t-brand-700 motion-safe:animate-spin" />
        <span>{language === 'ar' ? (compact ? 'جارٍ تحديث البيانات…' : 'جارٍ تحميل البيانات…') : (compact ? 'Updating data…' : 'Loading data…')}</span>
      </div>
      {!compact && <div aria-hidden="true" className={layout === 'cards' ? 'grid gap-5 md:grid-cols-2 lg:grid-cols-3' : 'space-y-3'}>
        {Array.from({ length: layout === 'cards' ? 6 : 4 }, (_, index) => (
          <div key={index} className="rounded-2xl border border-slate-200 bg-white p-5 motion-safe:animate-pulse">
            {layout === 'cards' && <div className="mb-5 h-40 rounded-xl bg-slate-100" />}
            <div className="flex items-center gap-4">
              <div className="h-12 w-12 shrink-0 rounded-xl bg-brand-50" />
              <div className="flex-1 space-y-3"><div className="h-4 w-2/3 rounded bg-slate-200" /><div className="h-3 w-1/2 rounded bg-slate-100" /></div>
            </div>
            <div className="mt-5 h-3 w-5/6 rounded bg-slate-100" />
          </div>
        ))}
      </div>}
    </div>
  );
};
