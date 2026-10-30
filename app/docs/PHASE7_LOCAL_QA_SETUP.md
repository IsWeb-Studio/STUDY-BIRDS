# Phase 7 — البيئة المحلية المعزولة

21 أكتوبر 2026. **IMPLEMENTED / VERIFIED محليًا**؛ ليس اعتماد إنتاج أو Android device QA. استُخدمت الملفات الحالية من deployment worktree؛ لم تُنسخ مجلدات التطبيق الأساسي إلى نسخة النشر.

## المواقع والحالة

- Backend: `D:\work\studybirds_session_release\server`.
- Android target: `D:\work\studybirds_session_release\app`.
- البيانات والإعدادات الخاصة الجديدة: `D:\work\studybirds_qa_phase7`، خارج المستودعات، مع `.gitignore` يستبعد محتوياته وACL للمالك وSYSTEM فقط.
- MongoDB: `127.0.0.1:27029`، replica set باسم `studybirds_qa_rs`، قاعدة `studybirds_qa_phase7`؛ PID وقت التحقق 21696.
- HTTP للكمبيوتر فقط: `http://127.0.0.1:5008`.
- HTTPS المطلوب لعميل Flutter: `https://localhost:5448/api`؛ backend PID وقت التحقق 23368. المنافذ الثلاثة رُصدت مربوطة بـ127.0.0.1 فقط.
- ملف الإعداد الخاص: `D:\work\studybirds_qa_phase7\.env.qa`. قيم الأسرار لا تُنسخ إلى التقارير.
- قالب المصدر: `server/qa.local.env.example`؛ placeholders فقط، غير صالح كما هو.

Docker CLI موجود لكن محرك Docker غير متاح. لم يُشغّل Docker Desktop أو تُنشأ حاويات/volumes أو تُسحب صور. لا mongod أو mongosh في PATH، لكن binary موجود مسبقًا واشتغل فعليًا:

`C:\Users\Abood\.cache\mongodb-binaries\mongod-x64-win32-8.2.6.exe`

الإصدار 8.2.6؛ SHA-256 مسجل في validation. لم يُنزّل أو يُثبت برنامج أو dependency أو WSL أو خدمة نظام. ملفات التنزيل القديمة غير المكتملة لم تُمس.

## MongoDB والمفاتيح

أنشأ `scripts/qa-provision.cjs` مجلدًا جديدًا فقط، ورفض الكتابة فوق مجلد موجود أو استعمال منفذ مشغول. كانت bootstrap قصيرة على loopback بلا بيانات مستخدم لإنشاء replica/users، ثم أُغلقت العملية التي أنشأها السكربت وأُعيد تشغيل نفس بيانات QA بالمصادقة وkeyfile. لم يُستخدم خادم MongoDB سابق أو قاعدة تحتوي بيانات حقيقية.

المستخدم `qa_phase7` يملك `readWrite` على قاعدة QA المحددة فقط. حساب إدارة منفصل يحتفظ به المالك في ملف خاص، ولا يُمرر إلى backend. نجح ping بالمصادقة، ورُفضت قراءة قاعدة أخرى بكود MongoDB 13. صار هذا الحد يُتحقق منه أيضًا في connectDatabase عند بدء QA؛ إذا لم تُفرض الصلاحيات يتوقف البدء.

JWT_SECRET وQA_OTP_SECRET وQA_STORAGE_SECRET مستقلة، مولّدة بـcrypto.randomBytes، ولكل منها 48 بايت عشوائية مع بادئة QA. كلمات مرور MongoDB وحسابات الاختبار عشوائية جديدة. لا إعادة استخدام لأسرار الإنتاج أو OTP. المخزن الخاص منفصل عن Git؛ لا تعرض ملف accounts-private أو owner-private أو رسائل البريد في تقرير أو شاشة مشاركة.

## تشغيل البيئة القائمة لاحقًا

من مجلد backend، بعد التأكد من هوية العمليات الحالية وعدم تشغيل نسخة ثانية:

```powershell
node scripts/qa-mongo-start.cjs D:\work\studybirds_qa_phase7\.env.qa
node scripts/qa-local.cjs D:\work\studybirds_qa_phase7\.env.qa
```

أول أمر يتحقق من binary المعروف ومن مصادقة قاعدة QA، أو يعيد تشغيل بياناتها القائمة بالمصادقة إذا كان المنفذ خاليًا. لا bootstrap جديد ولا reset ولا takeover. الفرع already-running اختُبر؛ فرع restart بعد إعادة تشغيل Windows لم يُنفّذ خلال هذه المرحلة.

أمر backend لا يحمل `.env` المعتاد مطلقًا، ويستبدل البيئة الموروثة بقائمة محدودة من إعداد QA وإعدادات تشغيل Windows الأساسية. يرفض أسماء APP_ENV غير المعروفة والإعداد الناقص وأي provider credentials. يفحص TLS قبل MongoDB، ولا يستمع قبل اكتمال تحقق قاعدة البيانات. إذا فشل إنشاء listener يغلق موارده الخاصة ويفصل اتصاله؛ لا يقتل خدمة أخرى.

العمليتان المحليتان بقيتا تعملان عند نهاية العمل. بدء نسخة backend أخرى سيُرفض إذا كانت منافذها مشغولة. لا تستخدم `qa-provision.cjs` لإعادة تهيئة المجلد؛ هو سيرفض وجوده. لإيقاف عملية يدويًا، يتحقق المالك أولًا من PID وCommandLine والمسار ووقت البدء؛ لا تقتل عملية اعتمادًا على رقم PID قديم. لا حذف للبيانات عند الإيقاف العادي.

فحص صحة الكمبيوتر دون بيانات اعتماد:

```powershell
Invoke-RestMethod http://127.0.0.1:5008/api/health
```

هذا HTTP loopback للكمبيوتر فقط، وليس قيمة مسموحة لـQA_API_BASE_URL في Flutter. شهادة HTTPS محلية جديدة لـlocalhost و127.0.0.1، لمدة 30 يومًا. لم تُثبت في مخزن ثقة Windows أو Android.

## البيانات الخيالية والـseed

```powershell
node scripts/qa-seed.cjs D:\work\studybirds_qa_phase7\.env.qa
```

يتحقق من mode/URI/اسم القاعدة قبل الكتابة، وينشئ records حتمية بـsetOnInsert أو create المحمي من تضارب الهوية، دون deleteMany أو drop أو reset. كلمات المرور يقرأها من الملف الخاص الجديد، ولا يضمّنها في المصدر ولا يطبعها. إعادة التنفيذ اختُبرت: الأعداد وبصمات كلمات المرور لم تتغير.

الحسابات الأولية: `qa.student@example.invalid` و`qa.peer@example.invalid` كلاهما student، و`qa.admin@example.invalid` و`qa.university@example.invalid`. أضاف اختبار المصادقة حسابًا خامسًا غير موثق `qa.unverified@example.invalid`. كلها خيالية وغير قابلة للتسليم.

البيانات: بلد وجامعة وبرنامج وطلب جامعي ومستند خيالي وstory نصية وتفضيلات حساب وalumni وscholarship. بعد الاختبارات: 5 users، و1 country، و1 university، و1 program، و1 application، و2 documents، و1 story محفوظة بعد soft deletion، و1 alumni، و1 scholarship، و2 student profiles. لا صور Cloudinary أو جوازات أو بيانات مستوردة.

الـseed لا يعيد إحياء story حُذفت أثناء اختبار ولا يعيد ضبط تفضيلات عدّلها المستخدم. هذا مقصود لتجنب reset مقنّع. المداخل القديمة الماسحة للبيانات في `src/seed/seed.js` صارت ترفض التنفيذ قبل dotenv أو الاتصال؛ يبقى نصها محفوظًا للمراجعة. أي إعادة إتاحة لأداة reset تحتاج مراجعة وموافقة مستقلة.

## البريد والتخزين

- **VERIFIED:** Email OTP الحقيقي لهذا backend يُلتقط كملفات في مجلد `mail` الخاص؛ لا SMTP أو Brevo. النطاق المقبول هو `example.invalid` فقط. تُرفض عناوين غير خيالية في طلبات QA، والحساب غير الموثق لا يحصل على login OTP. الاستهلاك أحادي الاستخدام اختُبر. ملفات الالتقاط تتضمن رموزًا خيالية؛ لا تُنشر أو تُدرج في التقرير.
- **VERIFIED:** المستندات تستخدم adapter محليًا في `src/qa/storage.js` عبر واجهة privateDocumentStorage القائمة. لا تعديل schema أو تجاوز لمسارات صلاحيات الوصول. تُحفظ bytes بأسماء content-hash محصورة، خارج المصدر، مع فحص النوع/التوقيع والحجم القائم 5 MiB ورفض أسماء traversal. لا مجلد static عام لملفات QA أو لمجلد uploads القديم.
- رابط التنزيل capability موقّع قصير 120 ثانية، يُصدر بعد ownership/role checks الحالية، مثل عقد التنزيل الموقّع السابق. لا يحتاج GET بعد ذلك إلى Bearer آخر؛ يلزمه توقيع صالح ضمن audience/issuer مخصصين. اختُبر رفض غير المالك والتوقيع المنتهي وtraversal. لا تُسجّل query tokens في QA logs.
- أول رفع HTTP للملف الخيالي الجديد أعاد 201، وتكراره أعاد 200 مع reused=true ونفس المستند. البيانات والأصول الأصلية لم تُنسخ.
- **NOT TESTED:** رفع صور/فيديو stories أو avatar أو chat media بمزوّد حي؛ مخرجات Cloudinary الأصلية ممنوعة. stories النصية/حذفها/feed اختُبرت، وتُرفض image/video routes بـ503. لا عامل حذف وسائط خارجي يعمل.

## جرد الاعتماد والآثار الجانبية

- `src/server.js`: البدء الإنتاجي المعتاد يستمع ثم يتصل بـMongo ويشغّل migration خدمة ومهام media maintenance وfinancial outbox وWink وapplication email delivery وconsultation reminders وautomatic assignment وfollow-up. مسار QA منفصل ولا يستدعي هذه الدوال. **كلها معطلة عند بدء QA**.
- `src/app.js`: يستورد routers/models دون تشغيل DB seed. QA يثبت حارس الشبكة قبل هذه الاستيرادات، ويقيّد CORS ويعلّم الردود local-qa؛ يُعطّل عرض uploads القديم وwell-known routes الإنتاجية. لا تغيير على normal authentication middleware.
- `src/config/db.js`: mongoose؛ QA يرفض SRV/Atlas والهوستات البعيدة والقواعد/ports/options غير المحددة، ويثبت حد الصلاحيات قبل الجاهزية.
- `User` وauthController وgenerateToken وMobileWorkspace: bcrypt الحالي، JWT، refresh hash/expiry وCAS rotation، tokenVersion وrevoked sessions. لا تجاوز للمصادقة أو الأدوار. اختُبرت حسابات الطالب والقرين والإدارة والجامعة وصلاحيات الطلب والمستندات وrefresh/logout.
- `mobileEmailCodes` وmailer: HMAC للرموز بسر QA مستقل والتقاط محلي؛ لا تسليم خارجي. بقية أسرار JWT/session جديدة داخل QA أيضًا.
- Google OAuth وApple/identity وphone OTP وpush tokens وStripe وAI/translation وCRM/shared-read: **محجوبة في QA**؛ providers أو webhooks لا تُفعّل ببيئة إنتاج موروثة.
- Cloudinary وprivate documents/chat/avatar/story video وlegacy media migration: config الإنتاج لا يُحمّل في QA؛ للمستندات adapter محلي فقط. بقية المزوّدين محجوبون أو غير مهيئين، وحارس الشبكة يمنع أي محاولة اتصال أخرى.
- `src/qa/network.js`: في عملية backend/seed فقط، يسمح net.Socket.connect بمنفذ MongoDB loopback المحدد ويمنع HTTP/HTTPS/TLS/fetch الصادر قبل dial/DNS. ليس sandbox لنظام Windows أو للعمليات الأخرى، ولا بديلًا لعزل Android.
- `migrateVerificationDocuments.js` و`backfillDocumentHashes.js` وbackup/CRM credential utilities: أوامر إدارية مستقلة **لم تُنفّذ ولم تُعتمد لبيئة QA**. لا تشغيل لها بملف env مجهول؛ يلزم فحص وموافقة منفصلان إذا طُلبت.
- الموقع لم يُشغّل ولم يتغير؛ لا تُعد fallbacks أو provider IDs الخاصة به جزءًا من هذه البيئة المحلية. لا telemetry أو مزوّد حي اختُبر.

## Flutter

حواجز Phase 6 محفوظة: APP_ENV وQA_API_BASE_URL وQA_RESOURCES_VERIFIED، ومنع fallback/redirects والمزوّدين. أضيف `QA_CA_CERT_BASE64` كجذر ثقة صريح للمسار QA فقط، دون trusted roots أخرى أو badCertificateCallback. تبقى مطابقة hostname وتوقيع TLS؛ لم يُضعف pinning الإنتاج أو HTTPS أو Android cleartext policy.

document resolver يسمح في QA فقط بالرابط المحلي الذي اجتاز فحص الأصل نفسه؛ شرط Cloudinary الإنتاجي بقي كما هو خارج QA. نجح اتصال Flutter IO على الكمبيوتر عبر HTTPS وتسجيل الدخول وتنزيل المستند. هذا ليس نجاح native UI أو Android. ملف defines في checkpoint اسمه loopback-tests-only، ولا يُستخدم لبناء أو تثبيت APK.
