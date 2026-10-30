# Phase 8 — بوابة البناء والموافقة

## تحديث التخزين فقط — 22 أكتوبر 2026

تم تجهيز وجهة QA على C فقط؛ التفاصيل في `PHASE8_QA_C_STORAGE_PREPARATION.md`. وجهة APK الحالية المتوقعة هي `C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8\gradle-build\app\outputs\flutter-apk\app-qa-debug.apk`. مسار manifest للفحص المستقبلي هو `gradle-build\app\intermediates\merged_manifest\qaDebug\processQaDebugMainManifest\AndroidManifest.xml` تحت الجذر نفسه. لا رجوع تلقائي إلى دليل D القديم؛ يبقى دليلًا تاريخيًا محفوظًا. إعداد `QA_MERGED_MANIFEST` يتطلب اختيار الملف الفعلي الجديد بعد إنشائه، ولم يُضبط هنا. ما زالت أوامر البناء أدناه ممنوعة، وحدود المساحة التاريخية ليست سياسة سعة جديدة معتمدة. الحاجز و`QA_RESOURCES_VERIFIED=false` لم يتغيرا.

## التحقق النهائي قبل البناء — أحدث قرار، 22 أكتوبر 2026

**BLOCKED / طلب موافقة محدد جاهز للمراجعة، لا إذن تنفيذ حاليًا.** هذه الفقرة تتقدم على الأوامر والاستنتاجات التاريخية أدناه. لا تعديل للحاجز أو المصدر أو config أو مفتاح أو جهاز جرى في هذه الجولة.

### المتحقق الآن

- مصدر مصنع QA وملفات دليل JVM لم تتغير عن الجولة الناجحة. manifest الحالي مطابق للبصمة السابقة ويحتوي binding واحدًا لـcct إلى المصنع المحلي، والهوية com.studybirds.app.qa.
- قورنت 201 من ملفات lib ومصادر Android الإنتاجية في deployment ببصمات نهاية Phase 7: لا اختلافات. مفاتيح/config المحمية وكتل signing/applicationId وAPK القديم تحفظ وتتحقق في preBuildVerification داخل JSON. لا يُقصد بهذا إعلان أن كل التعديلات المحلية الأقدم committed أو منشورة.
- Java المصنع ترجمت بـjavac فعلًا في harness السابق مع SDK interfaces المثبتة، ومصدرها مطابق. هذا ليس compileQaDebugJavaWithJavac لتطبيق Android كله.
- **Kotlin QaMainActivity غير مترجمة بعد.** فحص Gradle dry-run للترجمة أظهر compileFlutterBuildQaDebug وresource/asset/manifest processing ثم compileQaDebugKotlin وcompileQaDebugJavaWithJavac. ليست مهمة مستقلة صغيرة، والحاجز رفضها exit 1. init script للفحص طبع graph فقط ثم ترك الحاجز يرفضه. لم تُنفذ أي مهمة app compile أو cleanMergeQaDebugAssets التي ظهرت في graph، ولم يُستخدم -x أو تعديل gate أو compiler يدوي لتجاوزها.
- API محلي healthy/db connected. OpenSSL loopback بشهادة localhost الحالية نجح exit 0؛ hostname خاطئ على الاتصال نفسه رُفض exit 1. الشهادة صالحة حتى 20 نوفمبر 2026، SAN localhost و127.0.0.1. لا trust-store change أو TLS bypass.
- config Android ما زالت pending: APP_ENV=qa، origin=https://localhost:5448/api، QA_RESOURCES_VERIFIED=false، وشهادة base64 فارغة. لا ملف android-approved.defines.json معتمد. public certificate فقط يمكن تضمينها لاحقًا؛ لا أسرار backend.

### المساحة والهدف

المقاس عند بداية التحقق **5922160640 بايت ≈5.52 GiB**؛ القياس النهائي في JSON. أقل من الحد المتفق عليه 6 GiB بنحو 0.49 GiB. تقدير workspace لبناء debug أولي x86_64 هو **2–4 GiB إضافية** مع احتياطي 2 GiB؛ تقدير تخطيطي غير مقاس ببناء QA فعلي، وقد يزيد. لذلك لا يُخفض حد 6 GiB ولا يُضمن نجاح البناء عنده. APK الإنتاجي الموجود 320844144 بايت محفوظ، وليس مساحة قابلة للاسترداد.

إنشاء محاكي جديد على D يحتاج ميزانية منفصلة: الـAVD الموجودة تعلن قسم بيانات 6 GiB، ثم capture/overlays. لا يكفي حد بناء التطبيق وحده لإنشاء وتشغيل محاكي جديد. لم تُجرَ storage audit أو cleanup جديدة.

يوجد Pixel_9_Pro API36/x86_64 Google Play مثبت، لكن عزله غير متحقق ولم يُشغّل. لا USB candidate ظهر في فحص Windows؛ لم يُشغّل ADB لمعرفة serial/authorization، ولا يُدّعى غياب كل جهاز. adb.exe كان يعمل مسبقًا ولم يُلمس. **لا هدف runtime معزول متحقق حاليًا**، ولا analyzer للشبكة وجد في PATH/مسار Wireshark المعتاد. هذه قيود تشغيل/تثبيت، وليست نتائج يمكن افتراضها من اختبارات JVM.

### الموافقة المطلوبة بالضبط

المقترح لأول artifact هو **QA debug تشخيصي x86_64، دون تثبيت، وبـQA_RESOURCES_VERIFIED=false** من pending config الحالية. ستحجب البداية وظائف Dart؛ هذا مقصود. لا ادعاء OCR/login/runtime نجاح قبل وجود artifact. artifact وظيفي لاحق يتطلب تحقق عزل الموارد ثم إعدادًا وموافقة منفصلين. اختيار x86_64 يستند إلى صورة المحاكي الموجودة؛ إذا اختار المالك جهاز ARM فلابد من مراجعة ABI والأمر قبل الموافقة.

نص الموافقة المقترح للمالك، **غير ممنوح الآن**:

> بعد توفير مساحة البناء المطلوبة ومراجعة الفحوص، أوافق على مراجعة وتطبيق تعديل ضيق لسياسة gate يسمح فقط بسلسلة compile/assemble الخاصة بـqaDebug للأمر التشخيصي أدناه، مع بقاء فحص الهوية والمصنع المحلي والبصمات وconfig والمساحة وحظر release/install. ثم تشغيل compileQaDebugKotlin وcompileQaDebugJavaWithJavac، وعند نجاحهما assembleQaDebug مرة واحدة offline إلى مجلد QA المستقل. تبقى QA_RESOURCES_VERIFIED=false؛ لا APK install أو ADB أو محاكي أو تغيير شبكة أو signing أو cleanup أو production. أي فشل يوقف التسلسل ولا يُتجاوز.

موافقة «شغّل البناء» وحدها لا تجعل الأمر الحالي ممكنًا: gate يرفض كل compile/assemble QA عمدًا. يلزم تعديل سياسة **مراجع وموافق عليه صراحة**، لا تعطيل الحاجز أو إضافة bypass. لم يُعدّل في هذه المهمة، ولا تُعتبر هذه الوثيقة إذنًا لتعديله. بوابات runtime منفصلة في [خطة تشغيل Android](ANDROID_QA_RUNTIME_TEST_PLAN.md).

### الأوامر المقترحة للموافقة — محظورة التنفيذ حاليًا

المصدر وpending config والمجلدات يجب إعادة مطابقتها بالبصمات، وفحص ancestors/links، وتأكيد خلو الناتج من APK سابق، وحفظ SHA-256 للـAPK القديم ومفتاح debug الموجود دون كشفه. لا تغيير flutter config العام أو كتابة في app/build. لا secrets أو env server داخل defines.

```powershell
Set-Location D:\work\studybirds_session_release\app\android
$qaPendingPath = 'D:\work\studybirds_session_release\app\config\qa_android.pending.json'
$qaPending = Get-Content -LiteralPath $qaPendingPath -Raw | ConvertFrom-Json
$qaAllowed = @('APP_ENV','QA_API_BASE_URL','QA_RESOURCES_VERIFIED','QA_CA_CERT_BASE64','SENTRY_ENABLED','POSTHOG_API_KEY')
if (@($qaPending.PSObject.Properties | Where-Object Name -notin $qaAllowed).Count -gt 0) { throw 'Unexpected APK define' }
if ($qaPending.APP_ENV -ne 'qa' -or $qaPending.QA_API_BASE_URL -ne 'https://localhost:5448/api' -or $qaPending.QA_RESOURCES_VERIFIED -ne $false) { throw 'Diagnostic QA config required' }
if ($qaPending.QA_CA_CERT_BASE64 -ne '' -or $qaPending.SENTRY_ENABLED -ne $false -or $qaPending.POSTHOG_API_KEY -ne '') { throw 'Pending configuration changed' }
if ((Get-PSDrive D).Free -lt 6GB) { throw 'Insufficient D workspace' }
$qaOutput = 'C:\Users\Abood\AppData\Local\StudyBirds\qa-diagnostic-phase8\gradle-build\app\outputs\flutter-apk\app-qa-debug.apk'
if (Test-Path -LiteralPath $qaOutput) { throw 'QA artifact exists; do not overwrite' }
$qaEncodedDefines = ($qaPending.PSObject.Properties | ForEach-Object {
    $qaValue = if ($_.Value -is [bool]) { $_.Value.ToString().ToLowerInvariant() } else { [string]$_.Value }
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($_.Name)=$qaValue"))
}) -join ','
# لا تنفذ مع gate الحالية؛ يتطلب الموافقة والمراجعة المذكورتين أعلاه.
& .\gradlew.bat --offline --no-daemon --max-workers=1 -PstudybirdsQa=true '-Ptarget=lib/main.dart' '-Ptarget-platform=android-x64' "-Pdart-defines=$qaEncodedDefines" :app:compileQaDebugKotlin :app:compileQaDebugJavaWithJavac
if ($LASTEXITCODE -ne 0) { throw 'Compilation failed; stop' }
& .\gradlew.bat --offline --no-daemon --max-workers=1 -PstudybirdsQa=true '-Ptarget=lib/main.dart' '-Ptarget-platform=android-x64' "-Pdart-defines=$qaEncodedDefines" :app:assembleQaDebug
if ($LASTEXITCODE -ne 0) { throw 'QA assembly failed; stop' }
Get-FileHash -LiteralPath $qaOutput -Algorithm SHA256
```

هذه ليست build script معتمدة أو منفذة؛ مراقبة المساحة أثناء التسلسل مطلوبة. النطاق المراجع للتعديل المستقبلي يجب أن يحصر كل app tasks التابعة بـqaDebug، ويمنع install/release وسائر variants، ولا يلغي فحوص البصمات والهوية والمصنع. عند انخفاض المساحة أو ظهور اتصال خارجي/تعارض/تغير مصدر يُوقف عمل البناء الخاص بهذه المهمة بتحكم صاحبه دون إنهاء عمليات أخرى. لا تشغّل flutter clean أو Gradle clean أو تحذف cache لمعالجة الفشل.

## سجل القرارات والأوامر السابقة — ليس إذن تنفيذ

## أحدث قرار — تنفيذ البديل A المعتمد، 22 أكتوبر 2026

المصنع المحلي **نُفذ داخل QA** بعد موافقة المالك. XML المدمج يربط cct بمصنع QA وحده، دون مصنع CCT الشبكي. اختبارات manifest/native الثمانية نجحت، وتشمل ترجمة المصدر وتدقيقه و14 حالة JVM عبر registry/scheduler/uploader/ForcedSender المثبتة، مع ضوابط رفض IO. نجحت أيضًا 15 حالة source/bytecode و31 اختبار Flutter.

**APK ما زال BLOCKED**: النجاح يخص المسارات المختبرة، لا Android runtime أو OCR الفعلي. provider/Dagger boot وSQLite وOS jobs وmodel/native recognition ومراقبة الشبكة على Android لم تُنفذ. بقيت QA_RESOURCES_VERIFIED=false، وملف Gradle وحاجزه لم يتغيرا. تحقق dry-run من الرفض المقصود بالرمز 1؛ لا build/install/ADB.

لا حاجة لإذن آخر لتنفيذ المصنع؛ الإذن المعطى نُفذ. قبل أي APK يلزم مراجعة دليل الاختبارات وحدودها وخطة تحقق Android معزولة ومأذونة، وحسم بوابات TLS/الجهاز/المساحة وموافقة البناء المنفصلة. مراقبة runtime تظل مطلوبة، ولا يصبح SDK كله بلا شبكة لمجرد أن backend المختبر محلي. لا تنفّذ أمر البناء التاريخي أدناه أو ترفع الحاجز تلقائيًا.

تفاصيل التنفيذ: [أحدث تقرير العزل](PHASE8_NATIVE_PROVIDER_ISOLATION.md)، وapprovedLocalTransport في PHASE8_VALIDATION.json. المصنع لا يكتب payloads إلى قرص؛ runtime الأصلي قد يستعمل SQLite queue، وهو حد معلن ولم يُغير. بقية الأقسام التالية تحفظ تاريخ البوابات والخطط السابقة؛ هذا القرار هو الأحدث.

**NOT READY FOR BUILD APPROVAL. لا تنفّذ الأمر أدناه حاليًا.** بند 7 من طلب Phase 8 يشترط تحقق جميع البوابات ثم موافقة المالك قبل تنفيذ البناء. بعض البوابات فشلت، ولذلك لا يُطلب إذن تنفيذ بناء غير جاهز.

## البوابات

- هوية QA واسم/أيقونة وHTTPS بلا روابط إنتاج: متحققة من manifest مدمج فعليًا.
- backend/MongoDB المحليان: health ناجح، db=connected، ونجح تسجيل الدخول وتنزيل مستند عبر HTTPS المحلي على Windows. لا setup أو seed جديد.
- عزل native، تحديث 22 أكتوبر: **جزئي وغير معتمد للبناء**؛ أزيل 17 مكونًا وOneSignal initializer، وعُزل تسجيل plugins بمدخل QA مستقل مع حفظ OCR. اختبارات manifest: 6 نجاحات وفشل واحد بسبب CCT/DataTransport؛ الأربعة المرتبطة بسلامة شبكة ML Kit/transport تحتاج إثباتًا إضافيًا. حاجز Gradle يمنع التجميع ولم يُغيّر.
- TLS: جذر شهادة QA العامة الصريح يعمل لعميل Dart، ونجح رفض جذر غير موثوق وhostname خاطئ. ثقة Android/browser/media وADB reverse **غير متحققة**.
- QA_RESOURCES_VERIFIED: ملف `config/qa_android.pending.json` يبقيها false والشهادة فارغة. لا إعداد Android معتمد بقيمة true، ولا نسخ لقيمة true من اختبارات Windows.
- مسار Gradle مستقل: مُعد ومهمة manifest تكتب فيه. مسار APK النهائي لم يُختبر بالكتابة؛ CLI Flutter الافتراضي لا يُستخدم. APK القديم محفوظ دون استبدال.
- مساحة D: نحو 5.52 GiB، أقل من الحد التخطيطي المتفق عليه 6 GiB؛ يلزم قياس جديد وهامش كافٍ قبل التنفيذ. لا تنظيف إضافي مأذون هنا.
- موافقة بناء APK: **غير مطلوبة الآن لعدم جاهزية البوابات؛ مطلوبة قبل التنفيذ مستقبلًا**. لا تركيب على جهاز ضمن هذه المرحلة حتى مع موافقة البناء.

## اتصال USB المقترح — لم يُنفّذ

بعد اختيار جهاز QA صريح وموافقة التعامل معه والتحقق من عزله، تُستخدم الأوامر التالية باستبدال serial بالقيمة التي يؤكدها المالك:

```powershell
& C:\Users\Abood\AppData\Local\Android\Sdk\platform-tools\adb.exe devices -l
& C:\Users\Abood\AppData\Local\Android\Sdk\platform-tools\adb.exe -s <OWNER_SELECTED_SERIAL> reverse tcp:5448 tcp:5448
& C:\Users\Abood\AppData\Local\Android\Sdk\platform-tools\adb.exe -s <OWNER_SELECTED_SERIAL> reverse --list
```

يجب مطابقة serial والمنفذ ونجاح health بهوية local-qa من النقل الحقيقي للتطبيق. لا يُفترض أن localhost على Android يصل للكمبيوتر قبل إثبات reverse. يبقى أصل التطبيق `https://localhost:5448/api` دون تعطيل hostname validation. لا LAN أو firewall أو tunnel أو تعديل trust store تلقائي.

## الأمر الدقيق المقترح للمراجعة لاحقًا

ليس أمرًا معتمدًا للتنفيذ. يجب أولًا إكمال عزل native ومراجعة رفع حاجز Gradle، وتأمين المساحة، والتحقق من الجهاز والموارد، ثم إنشاء الملف الجديد التالي بموافقة المالك:

`D:\work\studybirds_qa_phase7\android-approved.defines.json`

محتواه المسموح: APP_ENV=qa، QA_API_BASE_URL=https://localhost:5448/api، QA_RESOURCES_VERIFIED=true **فقط بعد التحقق الحقيقي**، QA_CA_CERT_BASE64 للشهادة العامة الحالية، SENTRY_ENABLED=false وPOSTHOG_API_KEY فارغ. لا كلمة مرور أو JWT أو OTP أو مفتاح خاص أو server env في APK. الملف غير موجود حاليًا؛ النموذج pending ليس بديلًا معتمدًا.

```powershell
Set-Location D:\work\studybirds_session_release\app\android
$qaDefines = Get-Content -LiteralPath D:\work\studybirds_qa_phase7\android-approved.defines.json -Raw | ConvertFrom-Json
if ($qaDefines.APP_ENV -ne 'qa' -or $qaDefines.QA_API_BASE_URL -ne 'https://localhost:5448/api' -or $qaDefines.QA_RESOURCES_VERIFIED -ne $true) { throw 'QA configuration not verified' }
$qaAllowedKeys = @('APP_ENV','QA_API_BASE_URL','QA_RESOURCES_VERIFIED','QA_CA_CERT_BASE64','SENTRY_ENABLED','POSTHOG_API_KEY')
if (@($qaDefines.PSObject.Properties | Where-Object Name -notin $qaAllowedKeys).Count -gt 0) { throw 'Unexpected APK define' }
if ([string]::IsNullOrEmpty($qaDefines.QA_CA_CERT_BASE64) -or $qaDefines.SENTRY_ENABLED -ne $false -or $qaDefines.POSTHOG_API_KEY -ne '') { throw 'Unsafe provider/TLS configuration' }
$qaPublicPem = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($qaDefines.QA_CA_CERT_BASE64))
if ($qaPublicPem -match 'PRIVATE KEY' -or $qaPublicPem -notmatch 'BEGIN CERTIFICATE') { throw 'Public QA certificate required' }
if ((Get-PSDrive D).Free -lt 6GB) { throw 'Insufficient D build headroom' }
$qaEncodedDefines = ($qaDefines.PSObject.Properties | ForEach-Object {
    $qaValue = if ($_.Value -is [bool]) { $_.Value.ToString().ToLowerInvariant() } else { [string]$_.Value }
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("$($_.Name)=$qaValue"))
}) -join ','
& .\gradlew.bat --offline --no-daemon --max-workers=1 -PstudybirdsQa=true '-Ptarget=lib/main.dart' '-Ptarget-platform=android-arm64' "-Pdart-defines=$qaEncodedDefines" :app:assembleQaDebug
```

الـABI هنا arm64 مقترح فقط؛ يجب أن يؤكد جهاز المالك أنه متوافق قبل اعتماد الأمر. عند اختلافه تُراجع الخطة. قبل التنفيذ الفعلي يلزم أيضًا فحص تواريخ الشهادة ومطابقة bytes للشهادة الحالية، صحة backend، links/ancestors للمسار، بصمة APK القديم، وعدم وجود عملية بناء أخرى. مراقبة المساحة مطلوبة أثناء البناء؛ هذا النص لا ينشئ موافقة أو يحقق البوابات تلقائيًا.

وجهة APK المقترحة: `D:\work\studybirds_qa_phase7\android-build\app\outputs\flutter-apk\app-qa-debug.apk`. لا نسخ إلى app-debug.apk القديم. أي تغليف artifact لاحق له اسم جديد مستقل. لم يُبنَ أو يُثبت APK في Phase 8.

## قرار المتابعة بعد تحقيق native المحدد — 22 أكتوبر

الأمر أعلاه ما زال **مقترحًا محظور التنفيذ**. لا يغيّر نجاح إزالة مداخل المزودين شرط منع telemetry: MlKitInitProvider وخدمة discovery الخاصة بالتعرف محفوظان، وكذلك DataTransport backend/job/alarm؛ backend CCT المكتشف لديه قدرة HTTP فعلية في bytecode. لم يُشغّل Android ولم يُثبت أن هذه المسارات لن تبدأ شبكة عند أول OCR أو لاحقًا.

الخطوة الدقيقة التالية: حسم آلية QA تمنع ML Kit/DataTransport من الإرسال دون تعطيل OCR، وإثباتها في تحقق معزول مأذون قبل تغيير قرار البناء. لا حذف عشوائي لخدمات OCR/transport، ولا تجاوز للحاجز، ولا إعادة تسمية الاختبار الفاشل إلى نجاح. بعد حل هذا المانع فقط تُراجع بوابات الجهاز/TLS/المساحة وإعداد Android وموافقة المالك على الأمر؛ ثم يكون فحص الشبكة الفعلي جزءًا إلزاميًا من خطة جهاز معتمدة، لا نتيجة مفترضة لاختبارات manifest.

تقرير التصنيف الفردي للمكونات الـ22 ونتائج 9 اختبارات المصدر و31 اختبار Flutter و6 نجاحات/فشل واحد للـmanifest موجود في [تقرير العزل المحدث](PHASE8_NATIVE_PROVIDER_ISOLATION.md). لا تطبيق لموارد production أو تسجيل native SDKs الخارجية في مدخل QA الجديد، لكن Kotlin compilation وruntime لهذا المدخل لم يُنفذا؛ يلزم تضمينهما في التحقق المأذون اللاحق. توقيع الإنتاج وmain manifest ومدخل MainActivity الإنتاجي لم تُعدّل.

## نتيجة تحقيق DataTransport المتخصص — 22 أكتوبر

**قرار البناء لم يتغير: BLOCKED.** runtime/CCT المختاران فعليًا هما 3.1.9، وtransport-api هو 3.1.0. logger المشترك والنصي ينشئان CCT transport برمجيًا؛ لا مفتاح opt-out عام مدعوم ومتحقق في الواجهات المثبتة. الـbuilder الداخلي enableFirelog لا يحترم false في bytecode المفحوص، فلا reflection workaround.

حذف CCT metadata قد يمنع الاكتشاف في registry جديد، لكنه لا يثبت توافق OCR أو إبطال cached backends أو كل مسارات الإرسال. حذف dependency قد يكسر الربط بـCCTDestination. حذف jobs وحدها لا يغطي ForcedSender أو إعادة جدولة event store. لم يُطبق أي من هذه الحلول التخمنية، وOCR/manifest/dependencies بقيت كما كانت.

النتائج الجديدة: **15 اختبار source/bytecode ناجحًا؛ manifest: 6 نجاحات وفشل واحد؛ Flutter QA: 31 نجاحًا**. نجاح فحوص المخاطر الستة الجديدة لا يحوّل فشل عزل runtime إلى نجاح. ما زالت قيمة QA_RESOURCES_VERIFIED الخاصة بـAndroid false.

قبل النظر في أمر APK، يلزم اعتماد خطة **A**: QA-only local BackendFactory/TransportBackend وتوجيه cct إليها مع إثبات عدم IO وتوافق OCR، أو خطة **B**: بيئة Android بمنع خروج مفروض ومتحقق خارج العملية. التفاصيل والعقود واختبارات القبول في القسم الأخير من [تحقيق العزل](PHASE8_NATIVE_PROVIDER_ISOLATION.md). البديلان **مقترحان فقط**؛ لا تنفيذ دون موافقة مستقلة، ولا تعديل للحاجز الآن. يبقى فحص Android runtime للشبكة وOCR وعمليات restart/deferred upload مطلوبًا؛ لا يثبت غياب الشبكة بمجرد XML أو تجربة صامتة قصيرة.
