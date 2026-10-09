const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g,
  (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));

function publicOrigin(value, fallback) {
  try {
    const url = new URL(value || fallback);
    return ['https:', 'http:'].includes(url.protocol) ? url.origin : fallback;
  } catch { return fallback; }
}

const websiteOrigin = () => publicOrigin(process.env.SITE_URL, 'https://studybirds.net');
const assetOrigin = () => publicOrigin(process.env.EMAIL_ASSET_ORIGIN, 'https://study-birds1.onrender.com');

function renderBrandedEmail({ subject, text = '', html, emailContent = {} }) {
  const site = websiteOrigin();
  const assets = assetOrigin();
  const title = emailContent.title || subject || 'رسالة من Study Birds';
  const body = html || `<p style="margin:0;line-height:1.9;white-space:pre-line">${escapeHtml(emailContent.bodyText ?? text)}</p>`;
  const rows = (emailContent.details || []).map(([label, value]) => `<tr>
    <td style="padding:13px 16px;border-bottom:1px solid #e8edf3;color:#63758a;width:35%;vertical-align:top">${escapeHtml(label)}</td>
    <td style="padding:13px 16px;border-bottom:1px solid #e8edf3;color:#0c223a;font-weight:bold;overflow-wrap:anywhere;word-break:break-word">${escapeHtml(value)}</td></tr>`).join('');
  const code = emailContent.code ? `<div dir="ltr" style="margin:22px 0;padding:20px;border:1px solid #ffdaa7;border-radius:12px;background:#fff7ed;text-align:center;font-size:32px;letter-spacing:8px;font-weight:bold;color:#0c223a">${escapeHtml(emailContent.code)}</div>` : '';
  let action = '';
  if (emailContent.actionPath && /^\/(?!\/)/.test(emailContent.actionPath)) {
    action = `<table role="presentation" align="center" style="margin:26px auto"><tr><td bgcolor="#ff8a00" style="border-radius:10px;text-align:center"><a href="${escapeHtml(site + emailContent.actionPath)}" style="display:inline-block;padding:15px 32px;color:#ffffff;text-decoration:none;font-weight:bold;font-size:16px">${escapeHtml(emailContent.actionLabel || 'فتح حسابي')}</a></td></tr></table>`;
  }
  return `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeHtml(title)}</title></head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Tahoma,sans-serif;color:#34465b">
<div style="display:none;max-height:0;overflow:hidden;mso-hide:all">${escapeHtml(emailContent.preview || title)}</div>
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#f1f5f9" style="table-layout:fixed;width:100%"><tr><td align="center" style="padding:24px 12px">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="width:100%;max-width:600px;table-layout:fixed;background:#ffffff;border:1px solid #e2e8f0;border-radius:16px;overflow:hidden">
<tr><td style="border-top:5px solid #ff8a00"><a href="${site}"><img src="${assets}/email-assets/header.png" width="600" alt="Study Birds — Your Future. Our Guidance. Worldwide." style="display:block;width:100%;height:auto;border:0"></a></td></tr>
<tr><td dir="rtl" style="padding:28px 24px 16px;text-align:right">
<p style="margin:0 0 10px;color:#d66f00;font-size:12px;letter-spacing:1px;font-weight:bold">STUDY BIRDS · معك في كل خطوة</p>
<h1 style="margin:0 0 18px;font-size:24px;line-height:1.5;color:#0c223a">${escapeHtml(title)}</h1>
${body}${code}
${rows ? `<table width="100%" cellspacing="0" cellpadding="0" style="table-layout:fixed;margin-top:22px;border:1px solid #e8edf3;border-radius:10px;font-size:14px;text-align:right">${rows}</table>` : ''}
${action}<p style="margin:22px 0 0;line-height:1.8;color:#63758a;font-size:14px">مع أطيب التحيات،<br><strong style="color:#0c223a">فريق Study Birds</strong></p>
</td></tr>
<tr><td align="center" style="padding:22px 24px;border-top:1px solid #e8edf3;background:#f8fafc"><img src="${assets}/email-assets/logo.png" width="112" alt="Study Birds" style="display:block;border:0;height:auto;margin-bottom:12px"><a href="${site}" style="color:#0c223a;font-size:13px;text-decoration:none">${escapeHtml(new URL(site).hostname)}</a><p style="margin:8px 0 0;color:#7a8a9c;font-size:11px">مستقبلك. إرشادنا. حول العالم.</p></td></tr>
</table></td></tr></table></body></html>`;
}

module.exports = { escapeHtml, renderBrandedEmail, websiteOrigin };
