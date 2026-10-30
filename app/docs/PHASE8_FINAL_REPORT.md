# Phase 8 — تحضير Android QA الآمن

التاريخ: 2026-10-22؛ بدأ العمل في 21 أكتوبر. النتيجة **PREPARATION COMPLETE / BUILD BLOCKED**. أُنجز التحضير المأذون، وتوقف العمل قبل APK أو تركيب جهاز أو نشر. عزل native لم ينجح، لذلك لا موافقة بناء جاهزة الآن.

## 1. اختلافات مصدر التطبيق الأساسي

فُحص `lib/main.dart` و`lib/app_shell.dart` دون تعديلهما. إعادة تكوين نسختيهما من Git HEAD مع CRLF أعطت بصمتي بداية Phase 7 تمامًا:

- main: `20bf9ce3d51e2c5c2f7d28e76476288fb1c226d07fde6900ca1c68f3dcd8dc7f`.
- app_shell: `4156e00b1d625106591442c0e0a7eebb0af94bde9ebd887ca157c2d62e1e0e99`.

النص خارج import directives مطابق في المقارنة، وكذلك أجسام الأصناف والدوال. التغيير استبدل استيرادات منفردة باستيراد exports من `screens/screen.dart` و`core/core_import.dart`، مع استيرادات مباشرة إضافية وhide ScholarshipsScreen. الملفان التجميعيان غير متتبعين حاليًا، وscreen.dart يصدر نفسه أيضًا. هذا يوسع namespace والاعتماد على ملفات محلية؛ لا يكفي التطابق النصي للأجسام لإثبات تطابق كل سلوك runtime أو bindings.

`dart analyze lib/main.dart lib/app_shell.dart` نجح دون ملاحظات. لم يُختبر التطبيق الأساسي على جهاز، ولم يُبنَ. هوية العملية/الشخص الذي أنشأ التغييرات غير مثبتة من Git أو mtime؛ لم تُخمن. بصمات الملفات الأربعة بقيت كما كانت عند بداية Phase 8. **تظل المزامنة بين checkouts متوقفة**، دون revert أو overwrite أو merge.

## 2. هوية QA والإخراج

في تطبيق النشر وحده أُضيفت flavor اختيارية عبر `-PstudybirdsQa=true`: الهوية `com.studybirds.app.qa`، اسم Study Birds QA وأيقونة QA منفصلة، debug فقط، ومجلد Gradle مستقل في `D:\work\studybirds_qa_phase7\android-build`. غياب الخاصية يحافظ على المسار الإنتاجي دون flavors أو تغيير applicationId والتوقيع.

main وdebug manifests الإنتاجيان لم يُعدلا. overlay QA يستبدل MainActivity بفلاتر launcher فقط، ويعطل deep-link handling ويزيل autoinit/SignInHub المعروفة. overlay qaDebug يفرض HTTPS فوق إعداد debug الأصلي. أُنتج merged manifest فعلي offline، لا مجرد قراءة XML المصدر: الهوية صحيحة، cleartext=false، ولا production scheme/host/autoVerify.

أول دمج فشل بسبب تعارض cleartext مع src/debug؛ أُصلح بأولوية overlay qaDebug ثم نجح. السجل الفاشل محفوظ. توجد تحذيرات markers احترازية لا تجد تصريحًا أصليًا، وتحذيرات deprecation من Gradle؛ لم تُخفَ.

## 3. native isolation — مانع مثبت

كشف الناتج المدمج 22 مكونًا غير محسوم في فئات OneSignal وFirebase وML Kit وDataTransport وCredentials، وكذلك initializer خاص بـOneSignal داخل androidx.startup. MainActivity ما زالت تسجل plugins تلقائيًا. نجاح تعطيل Dart أو إزالة بعض providers لا يثبت عدم بدء بقية SDKs. لا ادعاء بأنها اتصلت فعلًا بالإنتاج؛ لكنها تمنع اعتماد العزل.

فشل اختبار native النهائي وبقي أحمر. لم تُحذف dependencies أو تُعطّل OCR عشوائيًا لتجاوزه. أضيف حاجز Gradle لا ينتج QA APK في الحالة الحالية، وتحقق رفضه بأمر dry-run. لا runtime QA أو مراقبة Android network أُجريت.

## 4. الاختبارات الفعلية

- اختبارات مصدر Android: **8 نجاحات** بعد تعديل overlay النهائي.
- اختبارات manifest المدمج: **3 نجاحات وفشل واحد** لاكتمال عزل native؛ exit 1. الهوية/الروابط وإزالة providers المعروفة نجحت.
- Flutter المحددة: **31 نجاحًا**؛ إعداد fail-closed ومنع production origins/redirects/media payloads، TLS، تعطيل المزودين، login وتنزيل مستند محلي حقيقي على Windows. منها رفض certificate غير موثوق وhostname خاطئ عبر handshake حقيقي، لا mock TLS.
- تحليل ملف اختبار TLS الجديد: **لا ملاحظات**، exit 0.
- تحليل ملفي التطبيق الأساسي المذكورين: **لا ملاحظات**، exit 0.
- Gradle offline manifest dry-run ثم الدمج النهائي: exit 0؛ لم تُنفّذ مهام compileFlutterBuild أو assemble لإنتاج APK. مهمة manifest تشغّل resource/manifest tasks الخاصة بها فقط، مع compilation/configuration لأدوات Gradle القائمة عند الحاجة.
- QA assemble **dry-run فقط**: exit 1 بسبب الحاجز المقصود قبل مهام APK؛ ليس فشل بناء APK فعلي.
- لم تُعد حزمة backend أو website أو Flutter الكاملة؛ لا تغيير API/backend/website في هذه المرحلة. ملاحظات التحليل العام الـ275 من Phase 7 لم تُعد أو تُصلح هنا، ولا يُدعى أنها اختفت.

## 5. الاتصال والإعداد

أُعيد استخدام البيئة القائمة دون provision أو seed: health=ok/service=study-birds-local-qa/db=connected، المنافذ 27029 و5008 و5448 مربوطة بـ127.0.0.1، ونجح login/document عبر HTTPS. شهادة localhost الحالية صالحة من 21 أكتوبر إلى 20 نوفمبر 2026، وبها SAN localhost و127.0.0.1. لم تُثبت في trust store.

ملف Android pending يبقي QA_RESOURCES_VERIFIED=false والشهادة فارغة، دون أسرار. ملف Windows الاختباري من Phase 7 ذو true استُخدم فقط لاختبارات الكمبيوتر المعزولة المثبتة، ولم يصبح إعداد APK. لم يُنفّذ ADB أو يُلمس جهاز، ولا firewall/LAN/tunnel. دليل الموافقة يحدد reverse والأصل وفحوص الاتصال المقترحة.

## 6. السلامة والمساحة

مساحة D قرب الإنهاء نحو **5.52 GiB**، وأقل من هامش 6 GiB المتفق عليه. القياس الدقيق في JSON. لا تنظيف أو حذف أو flutter clean أو migration أو download/install تبعيات أُجري. محاولة قراءة AAR أولى عبر python لم تعمل لغياب الأمر، واستُخدمت ZipFile الموجودة في .NET دون تثبيت شيء.

APK القديم بقي 320844144 بايت وبصمة SHA-256 `9638b98f111bf25b4079555f4a48029d40a4892dc12f48f407b3894b61b9ce23`. لا APK في مجلد إخراج QA الجديد. ملفات config/signing المحمية وبصمات الاسترجاع تحققت دون كشف قيم. لم يتغير HEAD أو index أو ارتباط worktrees؛ أدلة baseline ومقارنة المصدر موثقة في JSON. لم يتغير مصدر backend أو website، ولم تُجرَ مزامنة checkouts. تعديلات Gradle السابقة محفوظة بنسخ استرجاع متحققة في `.git/phase8-20261021/before`.

## 7. الخطوة التالية والقرار

قبل أي بناء: إكمال عزل native وإعادة الاختبار الأحمر، اعتماد احتياجات OCR/الإشعارات في QA، تحقق جهاز وUSB/TLS/native media وegress، زيادة هامش المساحة بطريقة مأذونة، اعتماد إعداد Android صريح ومسار الناتج، ثم طلب موافقة المالك على أمر البناء. أمر Gradle المقترح كاملًا في [PHASE8_BUILD_APPROVAL.md](PHASE8_BUILD_APPROVAL.md)، وهو **غير معتمد وغير منفذ** الآن. لا رفع للحاجز أو تركيب APK تلقائي حتى بعد تعديل خطة لاحقة.

الملفات المصاحبة:

- [هوية Android](PHASE8_ANDROID_QA_IDENTITY.md)
- [دليل عزل native وموانعه](PHASE8_NATIVE_PROVIDER_ISOLATION.md)
- [النتائج والبصمات](PHASE8_VALIDATION.json)
- [بوابة البناء والأمر المقترح](PHASE8_BUILD_APPROVAL.md)
