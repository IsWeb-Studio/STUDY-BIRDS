import { useEffect, useState } from "react";
import { AdminCommunityComposer } from "../../components/AdminCommunityComposer";
import { CommunityPostPhoto } from "../../components/CommunityPostPhoto";
import { api } from "../../lib/api";
import { useLanguage } from "../../hooks/useLanguage";
import { getErrorMessage } from "../../utils/errors";

type Person = { _id?: string; name: string; email?: string };
type Post = {
  _id: string; title: string; body: string; topic: string; status: string; commentCount: number; createdAt: string;
  author?: Person; moderationNote?: string; moderatedBy?: Person; openReports?: number; studyField?: { name: string }; imagePath?: string;
};
type Comment = { _id: string; body: string; status: string; createdAt: string; author?: Person; moderationNote?: string; reportCount: number };
type Report = {
  _id: string; targetType: "post" | "comment"; target: string; reason: string; details: string; status: string; createdAt: string;
  reporter?: Person; reviewedBy?: Person; post?: { _id: string; title: string; status: string } | string;
};
type LogEntry = {
  _id: string; targetType: string; fromStatus: string; toStatus: string; note: string; reportsClosed: number; createdAt: string;
  actor?: Person; subject?: Person; suspendedUntil?: string; post?: { _id: string; title: string } | string;
};
type Suspension = { _id: string; user?: Person; until: string | null; reason: string; suspendedBy?: Person; createdAt: string };
type Detail = { post: Post; comments: Comment[]; reports: Report[]; log: LogEntry[] };

const TOPIC_LABELS: Record<string, [string, string]> = {
  experience: ["تجارب", "Experiences"], housing: ["السكن", "Housing"], tips: ["نصائح", "Tips"],
  student_life: ["الحياة الطلابية", "Student life"], faq: ["أسئلة شائعة", "FAQ"], other: ["أخرى", "Other"],
};
const REASON_LABELS: Record<string, [string, string]> = {
  spam: ["إعلان/تكرار", "Spam"], abuse: ["إساءة", "Abuse"], misinformation: ["معلومات مضللة", "Misinformation"],
  privacy: ["معلومات شخصية", "Private info"], other: ["أخرى", "Other"],
};

export const AdminCommunityPage = () => {
  const { language } = useLanguage();
  const ar = language === "ar";
  const t = (a: string, b: string) => (ar ? a : b);
  const label = (map: Record<string, [string, string]>, key: string) => (map[key] ? (ar ? map[key][0] : map[key][1]) : key);
  const statusLabel = (s: string) => ({
    published: t("منشور", "Published"), hidden: t("مخفي", "Hidden"), active: t("نشط", "Active"), suspended: t("موقوف", "Suspended"),
  } as Record<string, string>)[s] || s;
  const date = (value: string) => new Date(value).toLocaleString(ar ? "ar" : "en");
  const [tab, setTab] = useState<"posts" | "reports" | "log" | "suspensions" | "terms">("reports");
  const [posts, setPosts] = useState<Post[]>([]);
  const [suspensions, setSuspensions] = useState<Suspension[]>([]);
  const [termsText, setTermsText] = useState("");
  const [notice, setNotice] = useState("");
  const [reports, setReports] = useState<Report[]>([]);
  const [log, setLog] = useState<LogEntry[]>([]);
  const [statusFilter, setStatusFilter] = useState("");
  const [reportStatus, setReportStatus] = useState("open");
  const [detail, setDetail] = useState<Detail | null>(null);
  const [loading, setLoading] = useState(true), [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const button = "rounded-xl px-3 py-1.5 text-sm disabled:opacity-50";
  const chip = (active: boolean) => `${button} ${active ? "bg-brand-primary text-white" : "border border-slate-300"}`;

  async function load() {
    setLoading(true); setError("");
    try {
      if (tab === "posts") setPosts((await api.get<Post[]>("/admin/community-posts", { params: statusFilter === "reported" ? { reported: "1" } : statusFilter ? { status: statusFilter } : {} })).data);
      if (tab === "reports") setReports((await api.get<Report[]>("/admin/community-reports", { params: { status: reportStatus } })).data);
      if (tab === "log") setLog((await api.get<LogEntry[]>("/admin/community-moderation-log")).data);
      if (tab === "suspensions") setSuspensions((await api.get<Suspension[]>("/admin/community-suspensions")).data);
      if (tab === "terms") setTermsText((await api.get<{ blockedTerms: string[] }>("/admin/community-settings")).data.blockedTerms.join("\n"));
    } catch (e) { setError(getErrorMessage(e, t("تعذر تحميل البيانات", "Unable to load data"))); }
    finally { setLoading(false); }
  }
  useEffect(() => { if (!detail) void load(); }, [tab, statusFilter, reportStatus, detail]);

  async function openDetail(postId: string) {
    setBusy(true); setError("");
    try { setDetail((await api.get<Detail>(`/admin/community-posts/${postId}`)).data); }
    catch (e) { setError(getErrorMessage(e, t("تعذر فتح الموضوع", "Unable to open the post"))); }
    finally { setBusy(false); }
  }

  // Hiding always requires a reason; it is shown to the author and kept in the audit log.
  async function moderate(kind: "post" | "comment", id: string, status: "published" | "hidden") {
    const note = window.prompt(status === "hidden"
      ? t("سبب الإخفاء (يظهر للكاتب ويُحفظ في السجل):", "Reason for hiding (shown to the author and kept in the log):")
      : t("ملاحظة (اختياري) — إبقاء المحتوى يغلق البلاغات المفتوحة عليه:", "Note (optional) — keeping the content dismisses its open reports:"), "");
    if (note === null) return;
    if (status === "hidden" && !note.trim()) { setError(t("سبب الإخفاء مطلوب", "A reason is required to hide content")); return; }
    setBusy(true); setError("");
    try {
      await api.patch(`/admin/community-${kind === "post" ? "posts" : "comments"}/${id}`, { status, moderationNote: note });
      if (detail) await openDetail(detail.post._id); else await load();
    } catch (e) { setError(getErrorMessage(e, t("تعذر تحديث الحالة", "Unable to update status"))); }
    finally { setBusy(false); }
  }

  // Suspension blocks posting, commenting and reporting; the student can still read.
  async function suspend(person?: Person) {
    if (!person?._id) return;
    const reason = window.prompt(t(`سبب إيقاف ${person.name} عن النشر (يصل للطالب ويُحفظ في السجل):`, `Reason for suspending ${person.name} (sent to the student and logged):`), "");
    if (reason === null) return;
    if (!reason.trim()) { setError(t("سبب الإيقاف مطلوب", "A reason is required")); return; }
    const rawDays = window.prompt(t("عدد الأيام (1–365)، أو اتركه فارغًا ليبقى حتى رفعه يدويًا:", "Number of days (1–365), or leave empty until lifted:"), "7");
    if (rawDays === null) return;
    const days = rawDays.trim() ? Number(rawDays) : null;
    if (days !== null && (!Number.isInteger(days) || days < 1 || days > 365)) { setError(t("عدد الأيام غير صالح", "Invalid number of days")); return; }
    setBusy(true); setError(""); setNotice("");
    try {
      await api.post("/admin/community-suspensions", { user: person._id, reason, days });
      setNotice(t(`تم إيقاف ${person.name}`, `${person.name} was suspended`));
      if (detail) await openDetail(detail.post._id);
    } catch (e) { setError(getErrorMessage(e, t("تعذر الإيقاف", "Unable to suspend"))); }
    finally { setBusy(false); }
  }

  async function lift(s: Suspension) {
    if (!s.user?._id) return;
    const note = window.prompt(t("ملاحظة رفع الإيقاف (اختياري):", "Note (optional):"), "");
    if (note === null) return;
    setBusy(true); setError("");
    try { await api.delete(`/admin/community-suspensions/${s.user._id}`, { data: { note } }); await load(); }
    catch (e) { setError(getErrorMessage(e, t("تعذر رفع الإيقاف", "Unable to lift the suspension"))); }
    finally { setBusy(false); }
  }

  async function saveTerms() {
    setBusy(true); setError(""); setNotice("");
    try {
      const blockedTerms = termsText.split("\n").map((term) => term.trim()).filter(Boolean);
      setTermsText((await api.put<{ blockedTerms: string[] }>("/admin/community-settings", { blockedTerms })).data.blockedTerms.join("\n"));
      setNotice(t("حُفظت قائمة الكلمات المحظورة", "Blocked terms saved"));
    } catch (e) { setError(getErrorMessage(e, t("تعذر حفظ القائمة", "Unable to save the list"))); }
    finally { setBusy(false); }
  }

  const suspendButton = (person?: Person) => person?._id && <button className={`${button} mt-3 border border-amber-300 text-amber-800`} disabled={busy} onClick={() => void suspend(person)}>{t("إيقاف الكاتب عن النشر", "Suspend author")}</button>;

  const actions = (kind: "post" | "comment", id: string, status: string, openReports = 0) => <div className="mt-3 flex flex-wrap gap-2">
    {status === "published"
      ? <>
        <button className={`${button} border border-red-300 text-red-700`} disabled={busy} onClick={() => void moderate(kind, id, "hidden")}>{t("إخفاء", "Hide")}</button>
        {openReports > 0 && <button className={`${button} border border-slate-300`} disabled={busy} onClick={() => void moderate(kind, id, "published")}>{t("إبقاء ورفض البلاغات", "Keep and dismiss reports")}</button>}
      </>
      : <button className={`${button} border border-emerald-300 text-emerald-700`} disabled={busy} onClick={() => void moderate(kind, id, "published")}>{t("إظهار", "Show")}</button>}
  </div>;
  const postTitle = (post: Report["post"] | LogEntry["post"]) => (typeof post === "object" && post ? post.title : t("موضوع محذوف", "Deleted post"));
  const postId = (post: Report["post"] | LogEntry["post"]) => (typeof post === "object" && post ? post._id : typeof post === "string" ? post : "");
  const logLine = (entry: LogEntry, withTitle = false) => <li key={entry._id} className="rounded-xl bg-slate-50 p-3 text-sm">
    {withTitle && <p className="text-xs font-semibold text-slate-700">{entry.targetType === "user" ? `${t("الطالب", "Student")}: ${entry.subject?.name || "—"}` : postTitle(entry.post)}</p>}
    <p><b>{entry.actor?.name}</b> · {entry.targetType === "post" ? t("موضوع", "Post") : entry.targetType === "comment" ? t("تعليق", "Comment") : t("إيقاف", "Suspension")}: {statusLabel(entry.fromStatus)} ← {statusLabel(entry.toStatus)}
      {entry.suspendedUntil && ` · ${t("حتى", "until")} ${date(entry.suspendedUntil)}`}
      {entry.reportsClosed > 0 && ` · ${t("أُغلق", "closed")} ${entry.reportsClosed} ${t("بلاغ", "reports")}`}</p>
    {entry.note && <p className="text-slate-600">{entry.note}</p>}
    <p className="text-xs text-slate-500">{date(entry.createdAt)}</p>
  </li>;

  if (detail) {
    const openFor = (kind: string, id: string) => detail.reports.filter((r) => r.status === "open" && r.targetType === kind && r.target === id).length;
    return <div className="space-y-6" dir={ar ? "rtl" : "ltr"}>
      <button className="text-sm underline" onClick={() => setDetail(null)}>{t("رجوع", "Back")}</button>
      {error && <p role="alert" className="rounded-xl bg-red-50 p-3 text-red-800">{error}</p>}
      {notice && <p role="status" className="rounded-xl bg-green-50 p-3 text-green-800">{notice}</p>}
      <article className="rounded-2xl border bg-white p-5">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h1 className="text-xl font-bold">{detail.post.title}</h1>
          <span className="rounded-full bg-slate-100 px-3 py-1 text-xs">{statusLabel(detail.post.status)}</span>
        </div>
        <p className="mt-1 text-sm text-slate-600">{detail.post.author?.name} — {detail.post.author?.email} · {label(TOPIC_LABELS, detail.post.topic)} · {date(detail.post.createdAt)}</p>
        <p className="mt-3 whitespace-pre-wrap">{detail.post.body}</p>
        {detail.post.imagePath && <CommunityPostPhoto key={detail.post.imagePath} path={detail.post.imagePath} alt={t('صورة المنشور', 'Post photo')} />}
        {detail.post.moderationNote && <p className="mt-2 text-sm text-amber-800">{t("ملاحظة الإشراف", "Moderation note")}: {detail.post.moderationNote}</p>}
        <div className="flex flex-wrap gap-2">
          {actions("post", detail.post._id, detail.post.status, openFor("post", detail.post._id))}
          {suspendButton(detail.post.author)}
        </div>
      </article>
      <section className="space-y-3">
        <h2 className="font-semibold">{t("التعليقات (بما فيها المخفية)", "Comments (including hidden)")}</h2>
        {!detail.comments.length && <p className="text-sm">{t("لا توجد تعليقات", "No comments")}</p>}
        {detail.comments.map((c) => <div key={c._id} className={`rounded-xl border p-3 text-sm ${c.status === "hidden" ? "border-amber-300 bg-amber-50" : "bg-white"}`}>
          <p className="font-semibold">{c.author?.name} <span className="text-xs font-normal text-slate-500">— {statusLabel(c.status)}{openFor("comment", c._id) ? ` · ${openFor("comment", c._id)} ${t("بلاغ مفتوح", "open reports")}` : ""}</span></p>
          <p className="whitespace-pre-wrap">{c.body}</p>
          {c.moderationNote && <p className="text-xs text-amber-800">{c.moderationNote}</p>}
          <div className="flex flex-wrap gap-2">
            {actions("comment", c._id, c.status, openFor("comment", c._id))}
            {suspendButton(c.author)}
          </div>
        </div>)}
      </section>
      <section className="space-y-3">
        <h2 className="font-semibold">{t("البلاغات", "Reports")}</h2>
        {!detail.reports.length && <p className="text-sm">{t("لا توجد بلاغات", "No reports")}</p>}
        <ul className="space-y-2">{detail.reports.map((r) => <li key={r._id} className="rounded-xl bg-slate-50 p-3 text-sm">
          <p><b>{label(REASON_LABELS, r.reason)}</b> · {r.targetType === "post" ? t("على الموضوع", "on post") : t("على تعليق", "on a comment")} · {r.reporter?.name} · {r.status === "open" ? t("مفتوح", "Open") : r.status === "resolved" ? t("مُعتمد", "Upheld") : t("مرفوض", "Dismissed")}</p>
          {r.details && <p className="text-slate-600">{r.details}</p>}
        </li>)}</ul>
      </section>
      <section className="space-y-3">
        <h2 className="font-semibold">{t("سجل الإشراف", "Moderation log")}</h2>
        {!detail.log.length && <p className="text-sm">{t("لا توجد قرارات بعد", "No decisions yet")}</p>}
        <ul className="space-y-2">{detail.log.map((entry) => logLine(entry))}</ul>
      </section>
    </div>;
  }

  return <div className="space-y-6" dir={ar ? "rtl" : "ltr"}>
    <h1 className="text-2xl font-bold">{t("إشراف مجتمع الطلاب", "Student Community Moderation")}</h1>
    <AdminCommunityComposer onPublished={() => { if (tab === 'posts') void load(); else setTab('posts'); }} />
    {error && <p role="alert" className="rounded-xl bg-red-50 p-3 text-red-800">{error}</p>}
    {notice && <p role="status" className="rounded-xl bg-green-50 p-3 text-green-800">{notice}</p>}
    <div className="flex flex-wrap gap-2">
      <button className={chip(tab === "reports")} onClick={() => setTab("reports")}>{t("البلاغات", "Reports")}</button>
      <button className={chip(tab === "posts")} onClick={() => setTab("posts")}>{t("المواضيع", "Posts")}</button>
      <button className={chip(tab === "suspensions")} onClick={() => setTab("suspensions")}>{t("الطلاب الموقوفون", "Suspended students")}</button>
      <button className={chip(tab === "terms")} onClick={() => setTab("terms")}>{t("الكلمات المحظورة", "Blocked terms")}</button>
      <button className={chip(tab === "log")} onClick={() => setTab("log")}>{t("سجل الإشراف", "Moderation log")}</button>
    </div>
    {loading && <p>{t("جارٍ التحميل…", "Loading…")}</p>}

    {tab === "reports" && <section className="space-y-3">
      <div className="flex flex-wrap gap-2">
        {[["open", t("مفتوحة", "Open")], ["resolved", t("مُعتمدة", "Upheld")], ["dismissed", t("مرفوضة", "Dismissed")]].map(([s, l]) => <button key={s} className={chip(reportStatus === s)} onClick={() => setReportStatus(s)}>{l}</button>)}
      </div>
      {!loading && !reports.length && <p>{t("لا توجد بلاغات", "No reports")}</p>}
      {reports.map((r) => <article key={r._id} className="rounded-2xl border bg-white p-4 text-sm">
        <p className="font-semibold">{postTitle(r.post)}</p>
        <p className="mt-1">{label(REASON_LABELS, r.reason)} · {r.targetType === "post" ? t("على الموضوع", "on post") : t("على تعليق", "on a comment")} · {r.reporter?.name} · {date(r.createdAt)}</p>
        {r.details && <p className="mt-1 text-slate-600">{r.details}</p>}
        {r.reviewedBy && <p className="mt-1 text-xs text-slate-500">{t("راجعه", "Reviewed by")} {r.reviewedBy.name}</p>}
        {postId(r.post) && typeof r.post === "object" && <button className={`${button} mt-3 border border-slate-300`} disabled={busy} onClick={() => void openDetail(postId(r.post))}>{t("مراجعة", "Review")}</button>}
      </article>)}
    </section>}

    {tab === "posts" && <section className="space-y-3">
      <div className="flex flex-wrap gap-2">
        {[["", t("الكل", "All")], ["reported", t("عليها بلاغات", "Reported")], ["published", t("منشور", "Published")], ["hidden", t("مخفي", "Hidden")]].map(([s, l]) => <button key={s} className={chip(statusFilter === s)} onClick={() => setStatusFilter(s)}>{l}</button>)}
      </div>
      {!loading && !posts.length && <p>{t("لا توجد مواضيع", "No posts")}</p>}
      {posts.map((p) => <article key={p._id} className="rounded-2xl border bg-white p-4">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h3 className="font-semibold">{p.title}</h3>
          <span className="rounded-full bg-slate-100 px-3 py-1 text-xs">{statusLabel(p.status)}{p.openReports ? ` · ${p.openReports} ${t("بلاغ", "reports")}` : ""}</span>
        </div>
        <p className="mt-2 text-sm text-slate-600">{p.author?.name} — {p.author?.email} · {label(TOPIC_LABELS, p.topic)} · {p.commentCount} {t("تعليق", "comments")}</p>
        <p className="mt-2 line-clamp-3 whitespace-pre-wrap text-sm">{p.body}</p>
        <div className="flex flex-wrap items-center gap-2">
          {actions("post", p._id, p.status)}
          <button className={`${button} mt-3 border border-slate-300`} disabled={busy} onClick={() => void openDetail(p._id)}>{t("التفاصيل والتعليقات", "Details and comments")}</button>
        </div>
      </article>)}
    </section>}

    {tab === "suspensions" && <section className="space-y-3">
      <p className="text-sm text-slate-600">{t("الطالب الموقوف يقرأ المجتمع ولا ينشر أو يعلّق أو يبلّغ. يُوقف الطالب من تفاصيل موضوعه أو تعليقه.", "A suspended student can read but not post, comment or report. Suspend from a post's or comment's details.")}</p>
      {!loading && !suspensions.length && <p>{t("لا يوجد طلاب موقوفون", "No suspended students")}</p>}
      {suspensions.map((s) => <article key={s._id} className="rounded-2xl border bg-white p-4 text-sm">
        <p className="font-semibold">{s.user?.name} — {s.user?.email}</p>
        <p className="mt-1">{s.until ? `${t("حتى", "Until")} ${date(s.until)}` : t("حتى رفعه يدويًا", "Until lifted")} · {t("بواسطة", "by")} {s.suspendedBy?.name}</p>
        <p className="mt-1 text-slate-600">{s.reason}</p>
        <button className={`${button} mt-3 border border-emerald-300 text-emerald-700`} disabled={busy} onClick={() => void lift(s)}>{t("رفع الإيقاف", "Lift suspension")}</button>
      </article>)}
    </section>}

    {tab === "terms" && <section className="space-y-3 rounded-2xl border bg-white p-5">
      <p className="text-sm text-slate-600">{t("كلمة أو عبارة في كل سطر (حتى 300، و60 حرفًا لكل منها). يُرفض المنشور أو التعليق الذي يحتوي إحداها ككلمة كاملة، مع تجاهل التشكيل واختلاف الهمزات.", "One word or phrase per line (up to 300, 60 characters each). Posts and comments containing one as a whole word are rejected; diacritics and hamza variants are ignored.")}</p>
      <textarea rows={10} className="block w-full rounded-xl border border-slate-300 p-3" value={termsText} onChange={(e) => setTermsText(e.target.value)} aria-label={t("الكلمات المحظورة", "Blocked terms")} />
      <button className="rounded-xl bg-brand-primary px-4 py-2 text-white disabled:opacity-50" disabled={busy} onClick={() => void saveTerms()}>{t("حفظ", "Save")}</button>
    </section>}

    {tab === "log" && <section>
      {!loading && !log.length && <p>{t("لا توجد قرارات بعد", "No decisions yet")}</p>}
      <ul className="space-y-2">{log.map((entry) => logLine(entry, true))}</ul>
    </section>}
  </div>;
};
