# توصيل Android ببيئة Phase 7 المحلية

**PROPOSED / NOT EXECUTED على جهاز.** backend وقاعدة البيانات والتخزين والبريد تحققوا محليًا. لا APK QA جديد ولا تثبيت ولا جلسة ADB أو تغيير firewall أو LAN أو tunnel نُفّذ.

## الكمبيوتر

MongoDB يبقى `127.0.0.1:27029`. backend يستمع فقط على `127.0.0.1:5008` و`127.0.0.1:5448`. HTTPS أصل التطبيق هو `https://localhost:5448/api`. لا تنشر MongoDB أو backend على 0.0.0.0 ولا تفتح router ports.

شهادة localhost محلية ذات SAN لـlocalhost و127.0.0.1. تدعم طبقة API في QA الآن شهادة عامة صريحة عبر QA_CA_CERT_BASE64، بثقة محصورة بهذه الشهادة؛ لا تعطيل TLS أو hostname validation. غياب الشهادة يفشل الاتصال. شهادة الجهاز/المتصفح/native media لم تُتحقق.

## USB / ADB — الخيار المفضل

ADB موجود في `C:\Users\Abood\AppData\Local\Android\Sdk\platform-tools\adb.exe`. بعد أن يختار المالك جهاز اختبار مخصصًا دون نسخة إنتاج أو بيانات حقيقية، ويوافق على USB debugging، تكون الخطوات المقترحة:

```powershell
adb devices -l
adb -s <OWNER_SELECTED_SERIAL> reverse tcp:5448 tcp:5448
adb -s <OWNER_SELECTED_SERIAL> reverse --list
```

لا تستعمل serial مخمّنًا. عند نجاح reverse، يصبح localhost:5448 على الجهاز نفقًا إلى منفذ QA loopback على Windows. **localhost على Android من دون reverse يعني Android نفسه، لا الكمبيوتر**. لا يحتاج هذا الخيار LAN أو firewall أو نفقًا عامًا. لم تُنفّذ هذه الأوامر في Phase 7.

يمكن للمالك اختيار جهاز USB مخصص مع تعطيل كل اتصال إنترنت آخر عليه، مع بقاء USB debugging، والتحقق من ذلك فعليًا. هذا يمنع اتصالات OS/browser/native غير المصرح بها؛ reverse ليس اتصال إنترنت عامًا. لا تُفترض العزلة من airplane mode وحده دون مراجعة Wi-Fi/data/tethering/VPN وبقية transports. لا نغيّر إعدادات الجهاز تلقائيًا.

## المحاكي

يمكن استخدام reverse نفسه مع serial محاكي يحدده المالك بعد الجرد. العنوان 10.0.2.2 في محاكي Android المعتاد يشير إلى المضيف، لكنه **ليس إعدادًا معتمدًا هنا**: الشهادة والأصل والروابط الموقّعة الحالية لـlocalhost. تبديل العنوان عشوائيًا سيكسر TLS أو origin checks. لا تُحل المشكلة بتعطيل الحواجز. يلزم أيضًا التحقق من منع خروج المحاكي للإنترنت قبل اختباره.

## LAN

**BLOCKED لحين موافقة مستقلة.** لم يُخمن IP خاص ولم تُعدّل قواعد firewall أو bind addresses. إذا تعذّر USB، تُجهّز خطة تحدد عنوان المضيف الحقيقي وقتها، subnet موثوقة، rule ضيقة لمنفذ HTTPS فقط، وشهادة SAN وأصل QA متوافقين. تبقى MongoDB على loopback. لا public tunnel ولا router forwarding.

## حواجز Android قبل أي تثبيت

- applicationId وnamespace الحاليان `com.studybirds.app`. التوقيع لم يتغير. لا تثبيت فوق تطبيق إنتاج؛ ملف Android آخر وحده ليس ضمانًا ضد تحديث package مشتركة على الجهاز. استخدم جهازًا/محاكيًا مخصصًا بلا التطبيق الإنتاجي، أو اعتمد تصميم QA applicationId منفصلًا أولًا.
- manifest الحالي يحتوي `studybirds://` وApp Links مع autoVerify لـstudybirds.app. قد تتصل طبقة OS بالهوست الإنتاجي عند التثبيت، قبل حارس Dart. يلزم QA manifest/variant مناسب أو عزل شبكة مثبت يمنع هذا الاتصال، قبل التثبيت.
- لم تُبنَ merged manifest جديدة بعد تنظيف intermediates؛ لا نجاح مفترض لدمج manifest أو native provider initialization.
- Google/Apple/OneSignal/Sentry/PostHog معطلة في QA Dart. لا تفعيل بمفاتيح الإنتاج. يجب التحقق من native persistence/autoinit وملف الجهاز الجديد أيضًا.
- Image.network وnative video وurl_launcher والمتصفح لا تستخدم كلها طبقة API أو QA_CA_CERT_BASE64. نجاح تنزيل HTTP عبر Flutter على Windows لا يثبت نجاح فتح الملف في متصفح Android. أي trust-store أو loader/QA variant إضافي يحتاج قرارًا وفحصًا، دون إضعاف سياسة الإنتاج.
- OCR/الكاميرا والأذونات والعودة من الخلفية وnative media تظل NOT TESTED. استعمل صورًا وجوازات خيالية فقط.

## الإعداد والبناء لاحقًا

APP_ENV=qa، وQA_API_BASE_URL=https://localhost:5448/api، وشهادة QA العامة الصحيحة. تبقى QA_RESOURCES_VERIFIED غير مفعلة لتطبيق مثبت حتى يكتمل تحقق الجهاز والاتصال والموارد. قيم true في loopback-tests-only.defines.json تخص اختبارات الكمبيوتر فقط، وليست ملف build جاهزًا.

لا بناء الآن: مساحة D أقل من هامش 6 GiB التخطيطي، كما أن شروط Android أعلاه غير متحققة. لا يشغّل الأمر الافتراضي الذي يستبدل app-debug.apk. قبل بناء مستقبلي يجب اعتماد مسار إخراج معزول يحافظ على APK الموجود **قبل** أي كتابة، ثم artifact باسم مستقل مثل:

`D:\work\studybirds_qa_phase7\artifacts\studybirds-qa-<timestamp>.apk`

هذه وجهة مقترحة فقط؛ لا يكفي نقل الناتج إليها بعد أن يكون البناء قد استبدل APK القديم. لم يُغيّر flutter config العام أو Gradle build directory أو signing لإجبار مسار جديد. يلزم حل إخراج/variant معزول مُراجع قبل تنفيذ build، ثم تسجيل hashes/defines/exit والمساحة طوال البناء. لا تثبيت تلقائي.
