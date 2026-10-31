import { useEffect, useState } from "react";
import { ExternalLink } from "lucide-react";
import { EmptyState } from "../../components/EmptyState";
import { DocumentFileLink } from "../../components/DocumentFileLink";
import { partnerService } from "../../services/partnerService";
import type { KnowledgeBaseItem } from "../../types";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";

export const PartnerKnowledgeBasePage = () => {
  const { language } = useLanguage();
  const isArabic = language === "ar";
  const [items, setItems] = useState<KnowledgeBaseItem[]>([]);
  const [error, setError] = useState("");

  useEffect(() => {
    partnerService
      .getKnowledgeBase()
      .then(setItems)
      .catch((issue) =>
        setError(getErrorMessage(issue, isArabic ? "تعذر تحميل قاعدة المعرفة." : "Unable to load the knowledge base."))
      );
  }, [isArabic]);

  if (error) {
    return <EmptyState title={isArabic ? "تعذر التحميل" : "Unable to load"} description={error} />;
  }

  if (!items.length) {
    return <EmptyState title={isArabic ? "لا يوجد محتوى بعد" : "No content yet"} description={isArabic ? "سيضيف الأدمن محتوى الشرح هنا." : "Admin-managed training content will appear here."} />;
  }

  return (
    <div className="space-y-4">
      {items.map((item) => (
        <article key={item._id} className="panel p-6">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div className="text-xs font-semibold uppercase tracking-[0.18em] text-orange-500">{item.category || "general"}</div>
              <h1 className="mt-2 text-2xl font-semibold text-slate-900">{item.title}</h1>
            </div>
            {item.videoUrl ? (
              <a href={item.videoUrl} target="_blank" rel="noreferrer" className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">
                <ExternalLink className="h-4 w-4" />
                {isArabic ? "فتح الفيديو" : "Open Video"}
              </a>
            ) : null}
            {item.fileUrl ? <DocumentFileLink path={item.fileUrl} className="inline-flex items-center gap-2 rounded-full border border-slate-200 px-4 py-2 text-sm font-semibold text-slate-700">
              <ExternalLink className="h-4 w-4" />
              {isArabic ? "فتح المورد" : "Open resource"}
            </DocumentFileLink> : null}
          </div>
          <p className="mt-4 whitespace-pre-line text-sm leading-7 text-slate-600">{item.body}</p>
        </article>
      ))}
    </div>
  );
};
