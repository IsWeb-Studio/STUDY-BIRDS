# Phase 8 — عزل المزودين الأصليين

**أحدث تحديث، 22 أكتوبر 2026: LOCAL QA TRANSPORT IMPLEMENTED / JVM VERIFIED / APK STILL BLOCKED.** نُفذ البديل A بعد موافقة المالك. manifest يختار المحلي وحده للاسم cct، ونجحت اختبارات manifest/native الثمانية مع 14 حالة JVM. Android runtime وOCR الفعلي لم يُثبتا؛ حاجز APK باقٍ. القسم التالي هو النتيجة الحالية؛ بقية الأقسام تحفظ تاريخ التحقيق السابق.

## البديل A المعتمد — التنفيذ والنتائج الحالية

### مصدر QA فقط

أضيف `android/app/src/qa/java/com/studybirds/app/qa/QaLocalTransportBackendFactory.java`، الذي ينفذ واجهة SDK العامة المسماة فعليًا BackendFactory ويعيد TransportBackend محليًا. create لا يقرأ Context، وdecorate يعيد الحدث نفسه، وsend لا يقرأ payload/events/extras أو يحتفظ بها، ويعيد BackendResponse.ok(0). لا HTTP/DNS/socket/logging أو كتابة ملف، ولا حقول تخزن أحداثًا.

في QA manifest فقط أزيلت `backend:com.google.android.datatransport.cct.CctBackendFactory` وأضيف binding وحيد `backend:com.studybirds.app.qa.QaLocalTransportBackendFactory=cct`. تحقق الدمج الفعلي من غياب الأصلي وكل binding مجهول أو مكرر. بقيت CCTDestination وdependencies وML Kit provider/discovery والـregistrars الثلاثة وPassportScanner كما كانت؛ لا تعديل Gradle أو production manifest أو signing أو applicationId. الواجهة والتوقيعات ترجمت بالفعل مقابل runtime/CCT 3.1.9 وAPI 3.1.0 المثبتة.

**حد التخزين:** المصنع لا يكتب telemetry إلى قرص، لكن DataTransport المحيط به ما زال يستطيع حفظ أحداث مؤقتة في SQLite قبل تقديمها للـbackend. لم يُغير هذا العقد ولم يُدّع تعطيل التخزين لكل SDK. المخزن في الاختبارات ذاكرة فقط، دون بيانات جهاز أو payload حقيقي.

### إثبات الاختيار والمسار، دون whitelist

الاختبار الصارم يقرأ XML المدمج ثم يشغّل `tool/qa_transport_jvm/verify.cjs`. يترجم المصدر الحالي بـjavac، ويدقق bytecode كامل المصنع وLocalBackend باستدعاءات مسموحة محصورة في constructors وBackendResponse.ok. يمنع IO/logging/reflection وكتابة الحقول. fixture سلبية تحتوي socket/logging تُرفض بالتدقيق ولا تُنفذ. binding وحده أو تقرير قديم لا يكفيان للنجاح: يعاد التحقق التنفيذي خلال اختبار manifest.

MetadataBackendRegistry وDefaultScheduler وUploader وTransportRuntime وForcedSender وCCTDestination وDTOs/serialization هي كلاسات المكتبات المثبتة نفسها. حدود Android PackageManager/Bundle/connectivity/logging ونقاط EventStore/WorkScheduler/health-metrics store نماذج اختبار في الذاكرة. الوصول إلى constructors وwithInstance يتم عبر bridge خاصة بالاختبار؛ كود التطبيق يستخدم الواجهات العامة فقط، ولا يبدل كلاسات vendor.

عملية Java 17 تمنع network/DNS/listen وكتابة/حذف الملفات أثناء السيناريوهات. ضوابط سلبية تؤكد الرفض قبل dial أو إنشاء ملف. تحذير SecurityManager المتقادم يخص harness JVM فقط؛ لا آلية كهذه في Android أو الإنتاج. التدقيق الإيجابي للمصنع يمنع logging أيضًا، بدل افتراض أن حارس الشبكة يمنع كل IO.

### الحالات الـ14 الفعلية

1. registry الأصلية تكتشف مصنع XML المدمج وتحمّل LocalBackend فعليًا.
2. اختيار محلي في registry جديدة والتحقق من cache في الحالية.
3. backend مفقود وmetadata فارغة يعيدان null دون fallback شبكي.
4. 100 إقرار محلي دون قراءة payload/extras؛ getters ترمي إن قُرئت، وdecorate يحافظ على هوية الحدث.
5. DefaultScheduler الحقيقي يمر عبر decorator المحلي ويحفظ/يجدول في نماذج الذاكرة.
6. Uploader.upload الحقيقي ينهي دفعة مؤجلة محليًا.
7. محاولة retry=5 تنتهي دون فشل أو retry إضافي.
8. WorkInitializer الحقيقي يعيد جدولة سياق محفوظ في الذاكرة ثم يصرفه uploader محليًا.
9. scheduler/uploader يرفضان backend غير معروف دون fallback.
10. ForcedSender الحقيقي يصرف حدث TransportImpl عبر المحلي.
11. إنشاء transport بـCCTDestination.INSTANCE كما تطلب ML Kit وجدولته بالاسم cct.
12. CCT extras وhealth-metrics serialization الحقيقيتان تمران إلى uploader وتنتهيان بإقرار محلي؛ store فقط مُنمذج.
13. ForcedSender مع CCT extras الفعلية يصرف الدفعة أيضًا.
14. صفر محاولات network/file-write في المسارات السابقة، ثم نجاح ضوابط رفض اصطناعية للشبكة والكتابة.

كل تحقق يبدأ بعملية JVM جديدة، مع اختبار registry جديدة إضافي. هذا ليس cold start لتطبيق مثبت، ولا تسليم job من Android OS. لا اختبار SQLite فعلي أو provider/Dagger boot أو OCR recognition ضمن harness.

### النتائج وحدودها

- manifest offline: exit 0.
- manifest/native الصارمة: **8 نجاحات، صفر فشل**؛ تتضمن تنفيذ الحالات الـ14 وتدقيق bytecode والضوابط السلبية. الشرط القديم «لا backend إطلاقًا» استُبدل بتحقق أقوى للخطة المعتمدة، لا whitelist لاسم غير مختبر.
- اختبارات المصدر/bytecode السابقة: **15 نجاحًا**. بقاء كود CCT في dependencies معلوم، لكن المصنع الأصلي ليس binding مختارًا.
- Flutter QA/TLS/login/document: **31 نجاحًا** على Windows loopback.
- assembleQaDebug **dry-run فقط**: رفض مقصود، exit 1، قبل APK. الحاجز لم يُغير.

المحاولتان الأوليان للـharness فشلتا بسبب constructor غير عام لـWorkInitializer ثم classpath ناقصة ProtoEnum. عُولج الوصول في bridge الاختبار، وأضيفت encoders jars الموجودة أصلًا إلى classpath الاختبار دون تغيير dependencies التطبيق أو تنزيل. سجلات الفشل والتحذيرات محفوظة؛ نجح الفحص النهائي بما فيه health-metrics extras. لا APK أو ADB أو جهاز أو خدمة إنتاج استُخدمت.

النسخ المتحققة والأدلة في `.git/phase8-local-transport-20261022`؛ التفاصيل الحالية في approvedLocalTransport داخل PHASE8_VALIDATION.json. ملفات الإنتاج والتوقيع والـAPK القديم وHEAD/index/worktrees جرى التحقق منها مقابل البداية. ملف Android pending ما زال QA_RESOURCES_VERIFIED=false.

**OCR محفوظ في المصدر والتهيئة، لكن توافق التعرف الفعلي ما زال pending.** ترجمة المصنع وبقاء CCTDestination ومسارات transport ليست إثباتًا لتشغيل TextRecognition/native model على Android. مراقبة شبكة Android، وprovider boot، وأول OCR، وrestart/jobs المؤجلة، وأي مسارات أخرى في ML Kit/plugins تظل مطلوبة. التالي مراجعة هذه الأدلة وخطة تحقق Android معزولة ومأذونة وحسم بوابات الجهاز/TLS/المساحة وموافقة بناء منفصلة. لا يُرفع حاجز APK ضمن هذه المهمة.

## سجل التحقيق السابق — النتائج أدناه تاريخية

أحدث تحقيق متخصص في DataTransport أدناه: **لم يُعثر على إعداد opt-out مدعوم ومتحقق في الإصدارات المثبتة. لم يتغير مصدر OCR أو manifest أو dependencies في هذه الجولة؛ أضيفت اختبارات أدلة فقط**. البديل المحلي موصوف للموافقة ولم يُنفذ.

الأقسام التالية حتى «متابعة العزل» تحفظ نتائج الفحص الأول؛ النتيجة الأحدث والتصنيف الفردي أدناه هما المرجع الحالي.

## دليل فعلي، وليس تعطيل Dart وحده

فُحصت مصادر plugins الموجودة في Pub cache، وتصريحات AAR الموجودة في Gradle cache دون استخراج شامل أو تنزيل، وGeneratedPluginRegistrant وMainActivity، ثم ناتج `processQaDebugMainManifest` الفعلي offline. أدلة محلية محفوظة في `.git/phase8-20261021`: cached-native-manifests.json وmerged-manifest-summary.json وسجلات الدمج والاختبارات. محتويات cache قد تتضمن إصدارات متعددة؛ الاستنتاج النهائي أدناه يعتمد الناتج المدمج نفسه، لا مجرد وجود AAR في cache.

- **OneSignal:** تسجيل plugin ما زال تلقائيًا بواسطة MainActivity التي تستدعي super.configureFlutterEngine. الناتج يحوي `androidx.startup.InitializationProvider` وداخله `com.onesignal.core.internal.application.impl.ActivityLifecycleInitializer`، إضافة إلى boot/upgrade/FCM receivers وSyncJobService. هذا مسار بدء قبل حارس Dart، ولا يكفي عدم استدعاء OneSignal.initialize من Dart لضمان العزل.
- **Firebase/FCM:** أزيل FirebaseInitProvider في QA، وقيمتا auto-init/analytics false في الناتج. لكن FirebaseMessagingService وFirebaseInstanceIdReceiver وComponentDiscoveryService ما زالت موجودة. لا ملفات google-services أو مفاتيح جديدة أُنشئت، ولا مشروع provider اختُبر. لا ادعاء بأن هذه المكونات اتصلت فعلًا بالإنتاج؛ وجودها ومسارات بدء غير محسومة يمنع اعتماد العزل.
- **Google authentication/OAuth:** SignInHubActivity محذوفة، وMainActivity بلا VIEW filters أو autoVerify. ما زالت CredentialProviderMetadataHolder وHiddenActivity وIdentityCredentialApiHiddenActivity وخدمة revocation ومكونات plugins موجودة؛ تعطيل Dart لا يثبت عدم التهيئة الأصلية. لا هوية OAuth QA مطلوبة إذا بقيت هذه الميزة معطلة، لكن يجب إكمال استبعاد/تحييد native قبل السماح بالبناء.
- **Sentry:** SentryInitProvider وSentryPerformanceProvider غائبان بعد الدمج، وauto-init=false. plugin ما زال مسجلًا في المحرك؛ لم يُراقب سلوكه على جهاز.
- **PostHog:** المصدر المثبت يقرأ `com.posthog.posthog.AUTO_INIT` أثناء onAttachedToEngine، ويعود عند false. أضيفت false إلى QA وظهرت في الناتج. هذه حماية مثبتة على مستوى المصدر والدمج فقط، وليس إثبات شبكة runtime.
- **ML Kit/OCR:** MlKitInitProvider وMlKitComponentDiscoveryService موجودان؛ native PassportScanner يستخدم ML Kit الحالي. ظهرت أيضًا DataTransport discovery/job/alarm components. لا يُفترض أن bundled OCR يلغي كل telemetry. إزالتها عشوائيًا قد تكسر OCR؛ يلزم تصميم عزل QA يُراجع ويُختبر قبل تعديل هذه العقود.
- **Browser/media:** WebViewActivity وurl_launcher وimage picker/video plugins ما زالت جزءًا من التطبيق. حارس payload/API يرفض مصادر الإنتاج الواردة عبر API، لكن مسارات المتصفح/الوسائط والروابط المضمنة في UI لا تُعتمد كلها على هذا الحارس أو جذر TLS الخاص بـDart. لم يُفتح browser أو media على جهاز.
- **Background:** بقيت WorkManager وlocal-notification boot receivers وغيرها. لم تُعطل الوظائف الإنتاجية أو تُحذف تبعياتها لمجرد جعل الاختبار أخضر. يلزم جرد قابل للوصول فعليًا وقرار بشأن وظائف QA المطلوبة.

## الاختبارات والحد التالي

اختبار merged manifest أعاد 3 نجاحات و**فشلًا واحدًا**: اكتمال عزل native. كشف 22 مكونًا في مجموعات المزودين التي يفحصها، فضلًا عن initializer داخل androidx.startup. لم يُتخط الاختبار ولم تُخفّف شروطه. اختبارات المصدر الثمانية لا تحل محل هذا الفشل.

توقف العمل قبل APK وفق بند 3 وBuild Gate من طلب Phase 8. لا تزال هذه بيئة تحضير محمية بحاجز بناء، وليست variant معتمدة للتثبيت.

العمل التالي المطلوب: تصميم registration/dependency/component isolation خاص بـQA، يحافظ على الإنتاج وعلى وظائف المستندات والكاميرا المطلوبة، مع اختيار صريح هل OCR والإشعارات الأصلية مطلوبة في QA. بعد ذلك إعادة الدمج، جعل اختبار native ينجح بالدليل، وفحص موارد native/Google configuration ثم مراقبة الشبكة على جهاز معزول وفق موافقة منفصلة. لا حاجة لتغيير provider consoles أو مفاتيح الإنتاج لتحقيق التحضير المحلي.

## متابعة العزل — 22 أكتوبر 2026

حُفظت حالة Git ونسخ الملفات المتغيرة وبصمات ملفات الإنتاج في `.git/phase8-native-20261022/before.json` وbefore/. لم تُعدّل تبعيات أو ملفات المصدر المشتركة مع الإنتاج أو التوقيع أو applicationId. ملفا Gradle وحاجز APK بقيا كما كانا. لا إعداد قاعدة أو seed أو cache cleanup أو تنزيل.

### طريقة الإثبات وحدوده

طُوبق كل مكون مع تقرير manifest merger ومكتبة مالكة، وفُحص bytecode المحلي بواسطة javap من JDK الموجود. ملفات classes.jar الصغيرة المستخرجة إلى checkpoint مصدرها AAR cache القائمة؛ لا تعديلات cache أو تنزيل. حُفظت الأدلة في component-origins.json وnative-component-bytecode.log وfirebase-discovery-bytecode.log وocr-transport-bytecode.log وflutter-engine-bytecode.log. أصدر الفحص الأول خطأ class-not-found لـFirebase discovery لأن تنفيذه موجود في firebase-common؛ فُحص هذا الكلاس من المكتبة الصحيحة لاحقًا. لم تُفسر نتيجة javap الإجمالية وحدها كنجاح لكل كلاس.

فُحص بعد التعديل **merged manifest فعلي جديد**؛ لا اعتماد على مجرد قراءة overlay. الإزالة المثبتة تعني غياب مدخل OS/manifest المحدد، ولا تعني حذف كلاس المكتبة من APK أو إثبات انعدام كل مسار انعكاس/شبكة في runtime.

### تصنيف كل مكون من الـ22 الأصلية

التصنيفات حرفيًا: Required local functionality، Safe with verified QA configuration، Must be disabled in QA، Requires further runtime verification. لم يُمنح أي مكون تصنيف Safe with verified QA configuration دون دليل كافٍ.

1. `androidx.credentials.playservices.CredentialProviderMetadataHolder` — **Must be disabled in QA**. المالك `androidx.credentials:credentials-play-services-auth:1.6.0`. خدمة metadata لا ترسل HTTP بذاتها، لكنها تعلن مزود Play Services الذي يُكتشف لتنفيذ credentials. لا حاجة له مع تعطيل الدخول الخارجي. **أزيلت من الناتج**.
2. `androidx.credentials.playservices.controllers.identityauth.HiddenActivity` — **Must be disabled in QA**. نفس المكتبة. onCreate/intent ينفذ تدفق credentials عبر Google/Play Services، وقد يسبب اتصال مزود خارج العملية. **أزيلت**.
3. `androidx.credentials.playservices.controllers.identitycredentials.IdentityCredentialApiHiddenActivity` — **Must be disabled in QA**. نفس المكتبة؛ نشاط وسيط لطلبات identity credentials عبر Play Services، وليس وظيفة محلية مطلوبة. **أزيلت**.
4. `com.google.mlkit.common.internal.MlKitComponentDiscoveryService` — **Required local functionality**. تنفيذ الكلاس في `com.google.mlkit:common:18.11.0`؛ تصريح الخدمة وregistrars مدمجان من common و`vision-common:17.3.0` و`com.google.android.gms:play-services-mlkit-text-recognition-common:19.1.0`. جسم الخدمة constructor وonBind يعيد null، دون كود شبكة بذاته. تُقرأ metadata منها لتكوين OCR. **حُفظت** مع CommonComponentRegistrar وVisionCommonRegistrar وTextRegistrar، exported=false. إثبات سلامة الخدمة نفسها لا يثبت سلامة كل registrar/logger لاحق.
5. `com.google.mlkit.common.internal.MlKitInitProvider` — **Requires further runtime verification**. المالك common:18.11.0. ContentProvider يبدأ قبل Activity؛ onCreate يستدعي MlKitContext، الذي يكتشف المكونات ويهيئ eager components. إزالة هذا provider بلا بديل متحقق قد تعطل TextRecognition.getClient. **حُفظ** مع authority خاصة بحزمة QA وexported=false. انعدام شبكة التهيئة أو أول OCR لم يُثبت.
6. `com.onesignal.notifications.receivers.FCMBroadcastReceiver` — **Must be disabled in QA**. المالك `com.onesignal:notifications:5.10.2`. onReceive لمعالجة FCM يمكنه الوصول إلى SDK ومعالجة إشعار/وسائط. **أزيل**.
7. `com.onesignal.notifications.services.HmsMessageServiceOneSignal` — **Must be disabled in QA**. نفس المكتبة؛ callbacks للرسائل/الرموز في Huawei تصل إلى خدمات OneSignal، وقد تبدأ معالجة مزود. **أزيلت**.
8. `com.onesignal.NotificationOpenedActivityHMS` — **Must be disabled in QA**. نفس المكتبة؛ فتح إشعار HMS يمرر intent إلى SDK وتدفق فتح الإشعار. قد تنجم عنه آثار شبكة/تتبع. **أزيلت**.
9. `com.onesignal.notifications.receivers.NotificationDismissReceiver` — **Must be disabled in QA**. نفس المكتبة؛ حدث dismissal يُمرر إلى منطق الإشعارات. لا ادعاء بوجود HTTP مباشر في جسم receiver، لكن وصول SDK غير مطلوب. **أزيل**.
10. `com.onesignal.notifications.receivers.BootUpReceiver` — **Must be disabled in QA**. نفس المكتبة؛ BOOT_COMPLETED قد يعيد جدولة عمل SDK. **أزيل**.
11. `com.onesignal.notifications.receivers.UpgradeReceiver` — **Must be disabled in QA**. نفس المكتبة؛ MY_PACKAGE_REPLACED قد يعيد بدء/جدولة خدمات SDK. **أزيل**.
12. `com.onesignal.notifications.activities.NotificationOpenedActivity` — **Must be disabled in QA**. نفس المكتبة؛ نشاط معالجة فتح الإشعار وتوجيهه إلى SDK. **أزيلت**.
13. `com.onesignal.notifications.activities.NotificationOpenedActivityAndroid22AndOlder` — **Must be disabled in QA**. نفس المكتبة؛ مسار قديم لفتح الإشعار، لا حاجة له أيضًا ولو كان جهاز QA أحدث. **أزيلت**.
14. `com.google.firebase.iid.FirebaseInstanceIdReceiver` — **Must be disabled in QA**. المالك `com.google.firebase:firebase-messaging:24.0.0`. استقبال cloud messaging/ack قد يصل إلى خدمات Google؛ ليس بريد OTP المحلي. **أزيل**.
15. `com.google.firebase.messaging.FirebaseMessagingService` — **Must be disabled in QA**. نفس المكتبة؛ message/token callbacks وتدفق FCM يمكن أن يصلا إلى تهيئة Firebase/المزوّد. **أزيلت**.
16. `com.google.firebase.components.ComponentDiscoveryService` — **Must be disabled in QA**. تنفيذ الكلاس في `firebase-common:21.0.0`؛ metadata مجمعة من firebase-messaging وinstallations وcommon/ktx وغيرها. الخدمة نفسها stub وonBind يعيد null دون شبكة، لكن registrars الخاصة بـFirebaseApp تعلن messaging/installations/transport. لا حاجة لهذا السجل في QA. **أزيلت**؛ لم تُحذف خدمة ML Kit المنفصلة أو مكتبة Firebase component container التي يستخدمها OCR.
17. `com.onesignal.core.services.SyncJobService` — **Must be disabled in QA**. المالك `com.onesignal:core:5.10.2`. JobService يشغّل عمل مزامنة SDK؛ مسار background يمكنه الوصول إلى مزود الشبكة. **أزيلت**.
18. `com.onesignal.SyncJobService` — **Must be disabled in QA**. نفس المكتبة؛ مدخل job إضافي/توافقي للمزامنة. **أزيلت**.
19. `com.onesignal.core.activities.PermissionsActivity` — **Must be disabled in QA**. نفس المكتبة؛ طلب أذونات ضمن lifecycle الخاص بـOneSignal. إذن Android ذاته محلي، لكن مدخل SDK غير مطلوب ولا يُعد آمنًا تلقائيًا من اسم النشاط. **أزيلت**؛ أذونات الكاميرا/local notifications لم تُلغَ.
20. `com.google.android.datatransport.runtime.backends.TransportBackendDiscovery` — **Requires further runtime verification**. التنفيذ في `transport-runtime:3.1.9`، وmetadata في `transport-backend-cct:3.1.9`. الخدمة نفسها discovery stub؛ MetadataBackendRegistry يقرأ `backend:com.google.android.datatransport.cct.CctBackendFactory=cct`. فُحص CctTransportBackend ووجد مسار `URL.openConnection` وHTTP POST. **حُفظت مؤقتًا ولم تُعتمد آمنة**؛ لا QA telemetry sink أو آلية تعطيل موثقة متحققة حاليًا.
21. `com.google.android.datatransport.runtime.scheduling.jobscheduling.JobInfoSchedulerService` — **Requires further runtime verification**. المالك `transport-runtime:3.1.9`. onStartJob يبني TransportContext ويستدعي uploader؛ تنفيذ Uploader يمكنه استدعاء backend.send. **حُفظت** لحين فصل telemetry بطريقة لا تكسر تهيئة OCR. لا دليل أن هذه الخدمة أرسلت فعليًا خلال العمل؛ لم يُشغّل Android.
22. `com.google.android.datatransport.runtime.scheduling.jobscheduling.AlarmManagerSchedulerBroadcastReceiver` — **Requires further runtime verification**. نفس المكتبة؛ onReceive يعيد تكوين السياق ويستدعي uploader للعمل المؤجل. **حُفظ**؛ منع jobs وحده لا يثبت منع إرسال مباشر أو foreground transport، لذلك لا إزالة جزئية لإخفاء الاختبار الأحمر.

الإجمالي: **17 Must be disabled أزيلت، و1 Required local حُفظ، و4 Requires further runtime verification حُفظت ولم تُحسم سلامتها**. لا مكونات من القائمة الأصلية صُنفت Safe with verified QA configuration.

### AndroidX Startup والتسجيل التلقائي

أزيلت metadata الخاصة بـ`com.onesignal.core.internal.application.impl.ActivityLifecycleInitializer` فقط من InitializationProvider، بدل حذف كل AndroidX Startup. أثبت bytecode أنها prewarms dispatchers وتربط ApplicationService بالـApplication قبل Activity؛ لم يُدّع أنها ترسل HTTP بذاتها. حُفظت initializers المحلية القائمة لـWorkManager/lifecycle/emoji/profile؛ تشغيل workers أو plugins أخرى لاحقًا ليس مشمولًا بإثبات محلية هذه metadata.

أضيف `android/app/src/qa/kotlin/com/studybirds/app/qa/QaMainActivity.kt`. يحذف manifest QA مدخل MainActivity الإنتاجي ويعلن مدخل QA وحده. لا يُستدعى super.configureFlutterEngine أو GeneratedPluginRegistrant ثم حذف المزودين بعد تهيئتهم. يسجل المدخل **16 plugin محلية قائمة** ويستبقي PassportScanner.register، مستثنيًا Google/Apple/OneSignal/Sentry/PostHog. كود هذه المكتبات ما زال dependency؛ لم تُحذف globally.

فُحص Flutter embedding الموجود: delegate ينشئ محركه مع automaticallyRegisterPlugins=false ثم يستدعي configureFlutterEngine، بينما تنفيذ superclass يسجل generated plugins. override QA يمنع الخطوة الأخيرة، ويرفض cached engine وcached engine group بإرجاع null حتى لا يُعاد استعمال محرك مجهز بمزود. هذا دليل bytecode/source على المسار المختار، **وليس نجاح Kotlin compilation أو Android runtime**؛ كلاهما لم يُنفّذ.

### الاختبارات الأحدث

- `processQaDebugMainManifest` offline: **نجاح، exit 0**، دون APK compilation.
- اختبارات مصدر Android: **9 نجاحات، صفر فشل**. تشمل مطابقة مجموعة plugins المحلية الحالية، استثناء المزودين، حفظ قناة OCR، بقاء manifests والتوقيع الإنتاجيين وحاجز البناء.
- اختبارات merged manifest: **6 نجاحات وفشل واحد، exit 1**. نجحت إزالة كل مداخل OneSignal/Firebase/Credentials، وغياب initializer، ومدخل QA وحده، والحفاظ على OCR authority/registrars. الفشل المتبقي يفحص metadata الفعلية `backend:*` ويكشف CCT القادر على الشبكة؛ لا whitelist لأسماء ML Kit لتصنيع نجاح.
- اختبارات Flutter QA/TLS/login/document المحددة: **31 نجاحًا، صفر فشل** على Windows loopback؛ لا ادعاء بأنها تختبر QaMainActivity أو OCR على Android.
- حاجز `assembleQaDebug --dry-run`: **رُفض فعلًا بالرسالة المقصودة، exit 1** قبل مهام APK. لم يُنفذ assemble فعلي. نتائج الجولة الأولى محفوظة في initialPreparationSnapshot، والنتائج الأحدث في nativeIsolationFollowup داخل PHASE8_VALIDATION.json.

لا APK أو ADB أو جهاز أو provider console أو production endpoint استُخدم. QA_RESOURCES_VERIFIED في نموذج Android ما زالت false. TLS لم يُضعف. الأدلة والنتائج والبصمات الجديدة في `.git/phase8-native-20261022`، مع الاحتفاظ بأدلة الجولة الأولى.

### التوقف والخطوة الدقيقة التالية

**اختبار العزل الكلي ليس أخضر، والحاجز يبقى مفعّلًا.** توقف تعديل المصدر عند حد ML Kit/DataTransport: لا توجد ضمن الأدلة الحالية آلية QA موثقة ومثبتة توقف telemetry مع الحفاظ على OCR، وإزالة providers/backends اعتباطيًا قد تُعطل تهيئة مكتبة التعرف أو تُخفي مسار إرسال آخر.

الخطوة التالية قبل طلب بناء APK: تقديم حل QA محدد لـML Kit/DataTransport يمنع خروج telemetry بدليل، مثل آلية تعطيل مدعومة في الإصدارات الحالية أو transport محلي لا يرسل، والتحقق من أثره على OCR في harness معزول ومأذون. إذا تعذر ذلك، يلزم اعتماد تصميم تشغيل بلا خروج للشبكة مع إثبات مستقل، وليس مجرد ADB reverse أو تعطيل Dart. لا تنفيذ لأي harness/device أو بناء في هذه الجولة. سيظل فحص Android runtime للشبكة والأذونات وOCR والوسائط ضروريًا بعد توفر مسار اختبار معتمد؛ اختبار صامت قصير وحده لا يثبت انعدام jobs المؤجلة.

## تحقيق ML Kit / DataTransport المتخصص — 22 أكتوبر 2026

### الإصدارات الفعلية

أُعيد حل تقرير `qaDebugRuntimeClasspath` بأمر Gradle dependencies **offline** دون تحديث dependency أو تنزيل. الأرقام المختارة فعليًا، لا مجرد نسخ متعددة موجودة في cache:

- `com.google.mlkit:text-recognition:16.0.1` و`text-recognition-bundled-common:17.0.0`.
- `com.google.android.gms:play-services-mlkit-text-recognition:19.0.1` و`play-services-mlkit-text-recognition-common:19.1.0`.
- `com.google.mlkit:common:18.11.0` و`vision-common:17.3.0`.
- `com.google.android.datatransport:transport-api:3.1.0` و`transport-runtime:3.1.9` و`transport-backend-cct:3.1.9`.

طلبات ML Kit القديمة لـruntime:2.2.6 وCCT:2.3.3 حُلّت إلى 3.1.9 ضمن graph الحالي. الأدلة الجديدة محفوظة في `.git/phase8-transport-20261022`، منها runtime-dependencies.log وملفات javap وبصمات الاسترجاع.

### نتيجة البحث عن إعداد مدعوم

واجهات النسخ المثبتة: MlKit يتيح initialize(Context)، وTextRecognizerOptions.Builder يتيح setExecutor/build، ولا يظهر opt-out عام لـtelemetry في هذه الواجهات. المرجع الرسمي لـ[تهيئة MlKit](https://developers.google.com/android/reference/com/google/mlkit/common/MlKit) يشرح التهيئة اليدوية بعد إزالة provider، وليس تعطيل telemetry. و[خيارات النص اللاتيني](https://developers.google.com/android/reference/com/google/mlkit/vision/text/latin/TextRecognizerOptions) لا تعرض تحكمًا عامًا كهذا. [إفصاح بيانات ML Kit](https://developers.google.com/ml-kit/android-data-disclosure) يوضح وجود بيانات diagnostics/usage حتى مع bundled features؛ يخص أحدث SDKs ولا يُستخدم وحده كدليل bytecode للنسخ المحلية.

وجد الفحص سببًا أدق لرفض حلول reflection المتداولة: `com.google.android.gms.internal.mlkit_common.zzrs.zza(boolean)` و`com.google.android.gms.internal.mlkit_vision_text_common.zzto.zza(boolean)` في النسخ المثبتة تنفذان `iconst_1` ثم تخزين boolean؛ لا تقرآن argument عبر iload_1. أي تمرير false لهذا الـbuilder الداخلي لا يعطّل القيمة. اسم enableFirelog الداخلي لا يجعله API مدعومًا. لا تعديل bytecode أو reflection أو shadow classes أو Firebase flags جديدة طُبق.

طلب opt-out في [مستودع ML Kit الرسمي، issue 593](https://github.com/googlesamples/mlkit/issues/593) ظهر مفتوحًا وقت الفحص؛ هذا قرينة إضافية وليس برهانًا وحده على كل إعداد ممكن. الاستنتاج المحدود: **لم أجد آلية تعطيل مدعومة ومثبتة للنسخ الحالية ضمن المصادر والواجهات والوثائق المفحوصة**، فلا تُطبّق رقعة runtime تخمينية.

### مسارات الإرسال المباشر والمؤجل

1. logger المشترك `mlkit_common.zzsp` وlogger النص `mlkit_vision_text_common.zzuk` ينشئان `CCTDestination.INSTANCE` ويستدعيان TransportRuntime.initialize/getInstance/newFactory مباشرة. إزالة FirebaseInitProvider أو FirebaseApp discovery لا توقف هذا الإنشاء. كلاهما يُرسل Event عبر Transport.send؛ سجل النص يستخدم ofData وofTelemetry بحسب نوع الحدث.
2. TransportImpl/TransportRuntime يمرران الحدث إلى DefaultScheduler، الذي يستعلم عن BackendRegistry، ثم يزخرف الحدث ويحفظه ويجدوله. Uploader يستعلم عن backend ثم يستدعي TransportBackend.send. CctTransportBackend يحوي URL.openConnection وHTTP POST؛ لا طلب شبكة حقيقي شُغل أثناء الفحص.
3. JobInfoSchedulerService وAlarmManagerSchedulerBroadcastReceiver يوجهان إلى uploader. **حذف هذين المدخلين وحدهما غير كافٍ:** `ForcedSender.sendBlocking` يستدعي `Uploader.logAndUpdateState` مباشرة دون انتظار job أو alarm. لم يُثبت أن ML Kit يستدعي ForcedSender في السيناريو الحالي؛ وجود هذا المسار العام يمنع تعميم أن كل uploads تعتمد على خدمة manifest واحدة.
4. WorkInitializer.ensureContextsScheduled يقرأ EventStore.loadActiveContexts ويعيد جدولة السياقات عند البدء. SQLiteEventStore يحتفظ بأحداث؛ فحص صامت قصير لا يغطي restart/retry أو jobs مؤجلة.
5. MetadataBackendRegistry يكتشف factories من metadata ويحتفظ بكائنات backend في Map. تغيير XML لا يسحب كائنًا مُنشأ من عملية حية. أي خطة مستقبلية يجب اختبارها من cold start وrestart وبيانات QA فقط، دون reset لبيانات المستخدم الحالية.

### لماذا لم تُحذف CCT metadata أو dependency؟

في registry جديد، حذف `backend:...CctBackendFactory=cct` يمنع اكتشاف هذه factory عبر مسار metadata المفحوص. وُجد أن DefaultScheduler يبلّغ callback بخطأ عند backend مفقود، وأن Uploader يعامل دفعة backend غير معروف كرفض fatal وحذف دفعة؛ **لم يظهر fallback HTTP في فرعي null المفحوصين**. هذه معلومة إيجابية محدودة، لكنها ليست API موثقة لتعطيل telemetry ولا إثباتًا لتوافق OCR أو كل مسارات runtime/caching.

حذف مكتبة CCT نفسها أخطر: loggers المذكورة تشير إلى CCTDestination مباشرة، فيمكن أن يسبب الاستبعاد خطأ ربط كلاس عند إنشاء logger. لا يجوز افتراض أن OCR سيظل يعمل لأن لا HTTP حدث. لم تُحذف dependency عالميًا أو في QA، ولم تُحذف metadata لمجرد جعل الاختبار أخضر. إزالة MlKitInitProvider ثم استدعاء MlKit.initialize يدويًا تؤخر التهيئة فقط، ولا تقدم opt-out للـlogger عند استعمال OCR.

### بديلان محددان للمراجعة — غير منفذين

**البديل A: transport محلي خاص بـQA.** الإبقاء على المكتبات وقناة OCR والـregistrars، وإضافة BackendFactory/TransportBackend داخل src/qa فقط، وربط الاسم `cct` بهذه factory بدل factory الأصلية عبر QA metadata. الواجهتان public في bytecode المثبت، لكن هذا تخصيص SPI يحتاج اعتمادًا واختبارًا، وليس إعداد ML Kit رسميًا جاهزًا.

التصميم المقترح: create يعيد backend محليًا، decorate يعيد الحدث دون إضافة معرفات، send لا يفتح socket أو HTTP/DNS ولا يكتب payload/صور/نص OCR إلى log أو ملف، ويعيد BackendResponse.ok(0) لإنهاء دفعة QA دون retry. لا overwrite لكلاسات vendor ولا حذف CCTDestination الذي تحتاجه loggers. يجب أن يكون هناك binding واحد فقط للاسم cct؛ تعدد factories أو fallback ممنوع.

التحقق المطلوب قبل اعتماده: فحص binding الفعلي قبل provider initialization، وإثبات اختيار factory المحلية من registry، واختبارات عدم IO مع factory/network mutations سلبية، واختبارات الفشل/الدفعات/الاستئناف وForcedSender، واختبار نص صورة خيالية معروف عبر OCR وإغلاق recognizer وإعادة تشغيله، مع مراقبة مستقلة لكل outbound traffic. الاختبار الحالي الذي يرفض backend:* لا يُخفف إلى whitelist اسم؛ أي تغيير لاحق له يجب أن يثبت التنفيذ المحلي والتوجيه فعليًا. **لم تُنشأ هذه الكلاسات أو يُعدّل binding؛ يلزم إذن منفصل لتطبيق هذا البديل.**

**البديل B: بيئة Android بلا خروج مثبت مستقلًا.** جهاز/محاكي داخل بيئة لا تملك مسار إنترنت، مع QA API محلي فقط، وإثبات DNS/IPv4/IPv6 وسائر transports قبل أي تهيئة SDK. يحتفظ USB reverse أو مسار محلي مضبوط بـTLS/hostname verification؛ ليس reverse نفسه آلية منع خروج. لا تتغير إعدادات الجهاز/Windows/firewall/VM تلقائيًا. المطلوب اعتماد مخطط محدد ثم اختبارات منع على endpoint اصطناعي مراقب، cold start وOCR وrestart وjobs المؤجلة؛ لا اتصال بخدمات Google/الإنتاج لإثبات المنع.

هذا البديل لا يزيل قدرة telemetry من الكود؛ يثبت احتواءها خارج العملية. يحتاج موافقة منفصلة وإثبات مراقبة مستقلًا. لم يُنشأ VM أو emulator ولم يُشغل ADB أو يُغيّر firewall.

### نتائج الجولة الحالية وحدودها

- Offline dependencies وprocessQaDebugMainManifest: نجحا، exit 0.
- اختبارات المصدر التسعة + ستة اختبارات bytecode الجديدة: **15 نجاحًا، صفر فشل**. الاختبارات الجديدة تكشف المخاطر الموجودة؛ نجاحها ليس شهادة عزل runtime.
- اختبارات merged manifest الحالية دون تخفيف: **6 نجاحات وفشل واحد، exit 1** بسبب CCT metadata.
- اختبارات Flutter QA/TLS/login/document المحددة: **31 نجاحًا** على Windows loopback.
- dry-run لحاجز APK: النتيجة النهائية مسجلة في transportInvestigation داخل PHASE8_VALIDATION.json؛ لا assemble حقيقي.

أول محاولة فحص public API لم تجد TextRecognizerOptions في jar text-recognition wrapper؛ عُثر عليه في play-services-mlkit-text-recognition:19.0.1 وأُعيد الفحص دون class-not-found. الفحص الجديد يفشل صراحة إذا كتب javap خطأ حتى مع exit 0.

لم يتغير manifest أو PassportScanner أو QaMainActivity أو التبعيات أو توقيع الإنتاج في هذه الجولة. **OCR محفوظ في المصدر وتهيئته، لكنه لم يُختبر على Android هنا.** لا APK، ولا جهاز، ولا ادعاء بعزل شبكة runtime. الحاجز يبقى مفعّلًا. التوقف الحالي قبل تطبيق بديل transport أو بيئة منع خروج؛ المطلوب التالي هو اعتماد أحد البديلين المحددين واختباره بالدليل، لا طلب تجاوز الحاجز للحصول على APK.
