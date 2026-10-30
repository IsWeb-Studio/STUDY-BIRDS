# خطة تحقق Android QA — غير منفذة

22 أكتوبر 2026. **خطة مستقبلية مشروطة بموافقات منفصلة، وليست تعليمات تنفيذ الآن.** لا APK أو ADB أو تشغيل محاكي أو تثبيت أو تغيير شبكة نُفّذ في هذه الجولة. بناء ملف APK شيء، والموافقة على تثبيته وتشغيله شيء آخر.

## الدليل المتاح والهدف المرشح

المثبت محليًا: emulator.exe، وADB، وصورة API 36 Google Play x86_64، وAVD باسم Pixel_9_Pro. إعداده يعلن RAM=2048 MiB وقسم بيانات 6442450944 بايت. لم تُقرأ بياناته الشخصية أو تُستخدم، ولم يُشغّل. Google Play image ليست بيئة معزولة افتراضيًا. لم يظهر emulator/qemu قيد التشغيل في الفحص؛ يوجد adb.exe مسبق PID 1100، لم يُستدعَ أو يُتصل بخادمه أو يُوقف. لم يظهر USB مرشح في فلتر Windows PnP؛ هذا لا يثبت غياب كل هاتف، ولا يثبت ترخيص USB debugging.

**لا هدف Android معزول متحقق متاح حاليًا.** لا تستخدم Pixel_9_Pro الشخصي تلقائيًا. الخيار المقترح لاحقًا: AVD جديدة مملوكة لـQA باسم StudyBirds_QA_Offline_API36، باستخدام الصورة المثبتة نفسها دون تنزيل وبدون نسخ userdata للـAVD القديمة. إنشاء هذه الـAVD وحجمها ومنع خروجها وتشغيلها يحتاج موافقة؛ لم تُنشأ. بديلها جهاز USB مخصص يختاره المالك ويتحقق من خلوه من حسابات/بيانات الإنتاج.

## بوابات لا يجوز تجاوزها

1. موافقة مستقلة على هدف محدد ومعرّف serial يؤكده المالك، وعلى التشغيل/ADB/reverse/التثبيت/الصلاحيات والمراقبة. لا serial مخمن ولا adb -e/-d يختار جهازًا تلقائيًا.
2. منع خروج مستقل **قبل أول boot/launch**، مع إثبات DNS وIPv4 وIPv6 وWi-Fi/mobile/tethering/VPN وبقية transports. لا يكفي airplane mode أو ADB reverse أو certificate pinning. لا firewall/VM/device setting يُعدل ضمن التفويض الحالي. لا نقل لبيانات إنتاج.
3. مراقب شبكة موثوق مع إسناد traffic إلى UID/العمليات عند الحاجة. emulator -tcpdump يلتقط ولا يمنع الخروج. tshark/Wireshark لم يُعثَر عليهما في PATH أو المسار المعتاد؛ لا تثبيت أو تنزيل. غياب أداة تحليل/إسناد مناسب = STOP قبل runtime.
4. API/DB/storage/mail المحلية متحققة، HTTPS شهادة عامة صحيحة فقط، وحسابات وصور اصطناعية. لا .env أو password أو JWT أو مفتاح خاص داخل APK أو التقارير.
5. APK معروف البصمة والـABI والـmanifest؛ إنتاج com.studybirds.app وAPK القديم محفوظان. موافقة بناء لا تشمل تثبيتًا تلقائيًا.
6. مساحة مناسبة للبناء والمراقبة والمحاكي. حد البناء المبدئي 6 GiB؛ إنشاء AVD ذات قسم 6 GiB على D يحتاج مساحة إضافية مستقلة، لا يُعتبر مغطى بهذا الحد. تقدير إجمالي متحفظ للتجربة بمحاكي جديد على D: 12–14 GiB، غير مقاس ببناء فعلي.

## مرحلتان لتجنب اعتماد نتيجة runtime قبل وجود APK

**A — أول artifact تشخيصي:** الأمر المقترح في PHASE8_BUILD_APPROVAL.md يستخدم pending config بقيمة QA_RESOURCES_VERIFIED=false وشهادة فارغة. يصلح للتحقق من compilation/packaging فقط. المتوقع أن يمنع التطبيق استعادة جلسة وتشغيل الوظائف من Dart. لا تطلب login/OCR من هذا artifact ولا تعتبر حجب البداية فشلًا يجب تجاوزه. native providers قد تبدأ قبله؛ لذلك لا يُثبت أو يُشغّل دون احتواء الشبكة.

**B — artifact وظيفي للاختبار:** بعد التحقق من موارد QA وبيئة الجهاز والاحتواء والاتصال بموافقة المالك، يُنشأ إعداد منفصل بشهادة QA العامة وQA_RESOURCES_VERIFIED=true. هذه الراية إقرار بعزل الموارد، لا نتيجة نجاح OCR أو كل سلوك runtime. لم يُنشأ هذا الإعداد الآن. يحتاج البناء الثاني/تغيير الإعداد موافقة منفصلة، ثم موافقة تشغيل. اختبارات السلوك أدناه تخص B؛ native cold-start diagnostics يمكن التخطيط لها في A ضمن نفس الاحتواء.

## أوامر اتصال مقترحة — بعد تحقق البوابات فقط

الأوامر التالية **لم تُنفّذ**. من PowerShell، يحدد المالك serial وartifact حقيقيين؛ القيم الافتراضية تتوقف عمدًا:

مرجع صياغة اختيار الهدف وinstall/am: [Android Debug Bridge](https://developer.android.com/tools/adb). وجود الصياغة الموثقة لا يمنح إذن تنفيذها.

```powershell
$qaAdb = 'C:\Users\Abood\AppData\Local\Android\Sdk\platform-tools\adb.exe'
$qaSerial = 'OWNER_SELECTED_SERIAL'
$qaApk = 'OWNER_APPROVED_QA_APK_ABSOLUTE_PATH'
$qaPackage = 'com.studybirds.app.qa'
if ($qaSerial -eq 'OWNER_SELECTED_SERIAL' -or !(Test-Path -LiteralPath $qaApk)) { throw 'Owner-selected target/artifact required' }
& $qaAdb devices -l
& $qaAdb -s $qaSerial shell getprop ro.product.cpu.abi
& $qaAdb -s $qaSerial shell pm path com.studybirds.app
& $qaAdb -s $qaSerial shell dumpsys connectivity
& $qaAdb -s $qaSerial shell ip route
& $qaAdb -s $qaSerial shell ip -6 route
& $qaAdb -s $qaSerial reverse tcp:5448 tcp:5448
& $qaAdb -s $qaSerial reverse --list
```

النتيجة: serial مطابق ومصرح، ABI مطابق للـAPK، لا حساب/تطبيق إنتاج في الهدف المخصص، ولا مسار خارجي غير مضبوط، وreverse الوحيد المأذون 5448. وجود package إنتاج أو route/transport/هوية غير مفهومة = STOP. بيانات routes وحدها ليست إثبات منع الخروج، ويجب تأكيد الطبقة المستقلة.

```powershell
# بعد إذن تثبيت مستقل وفحص manifest والبصمة، لا استعمال -r فوق package قائمة.
Get-FileHash -LiteralPath $qaApk -Algorithm SHA256
& $qaAdb -s $qaSerial install -t $qaApk
& $qaAdb -s $qaSerial shell cmd package list packages -U $qaPackage
& $qaAdb -s $qaSerial shell am start -W -n "$qaPackage/com.studybirds.app.qa.QaMainActivity"
```

إذا كانت package QA موجودة، توقف وراجع ملكيتها وبياناتها؛ لا uninstall أو clear أو overwrite تلقائي. لا تحذف بيانات لتصنيع cold start. لا تمنح permissions تلقائيًا بـ-g؛ يوافق المالك عبر UI على صلاحيات الاختبار.

## التقاط الشبكة — شرط إضافي غير جاهز حاليًا

فقط بعد إنشاء AVD الجديدة والموافقة عليها وإثبات طبقة منع الخروج قبل boot، يمكن اقتراح:

```powershell
& C:\Users\Abood\AppData\Local\Android\Sdk\emulator\emulator.exe -avd StudyBirds_QA_Offline_API36 -no-snapshot-load -no-snapshot-save -no-boot-anim -tcpdump D:\work\studybirds_qa_phase7\captures\qa-runtime.pcap
```

المجلد والملف يجب أن يكونا جديدين ومملوكين لـQA وموافقًا عليهما. لا تشغيل للـAVD القديمة ولا -wipe-data. الأمر لا يعزل الشبكة بذاته؛ إن لم توجد طبقة منع خروج مستقلة متحققة فلا يُنفذ.

خيار tcpdump يلتقط حزم الشبكة الافتراضية للمحاكي، وليس TCP فقط؛ [مرجع Android Emulator](https://developer.android.com/studio/run/emulator-commandline). لا يُفسر غياب حزمة من هذا الموضع وحده كإثبات لمراقبة كل طبقات الجهاز.

بعد إتاحة analyzer بموافقة منفصلة، أمر الفحص المقترح:

```powershell
& 'C:\Program Files\Wireshark\tshark.exe' -r D:\work\studybirds_qa_phase7\captures\qa-runtime.pcap -Y 'dns || ip || ipv6' -T fields -e frame.time_relative -e ip.dst -e ipv6.dst -e tcp.dstport -e udp.dstport -e dns.qry.name
```

هذه الأداة غير مثبتة في المسار المفحوص، فلا يُدعى نجاح الأمر. PCAP وحده لا ينسب طلبًا إلى UID؛ يلزم مراقب/trace مأذون لذلك ومقارنة baseline قبل تثبيت QA. Google Play OS قد يحاول الاتصال بنفسه؛ لا تنسب اتصالاته للتطبيق أو تتجاهلها بلا دليل. ممنوع إرسال طلب إلى production «للتأكد أنه محجوب». اختبارات منع route تُجرى على endpoint اصطناعي مراقب بعد موافقة، لا Google أو Render أو بيانات اعتماد حقيقية.

المتوقع: API محلي 5448 فقط لمسارات التطبيق المختبرة؛ أي اتصال خارجي ناجح = STOP. أي محاولة QA نحو production أو egress غير منسوب تحتاج تحقيقًا ولا تُسجل نجاح عزل، حتى إن منعتها الطبقة الخارجية. تُحفظ captures/logs محليًا بصلاحيات محدودة ولا تُنشر raw payloads أو رموز جلسات.

## مصفوفة التشغيل والنتائج المطلوبة

1. **Cold start/native providers:** ابدأ capture قبل التطبيق. شغّل على process جديدة من تثبيت QA جديد مأذون؛ لا clear-data. المتوقع مدخل QaMainActivity، لا OneSignal/FCM/Credentials/Sentry/PostHog init، وML Kit provider/discovery موجودان، وcct محلي. افحص crash/NoClassDefFoundError وربط factory. JVM أثبت الاختيار ضمن نموذج Android؛ actual provider/Dagger boot ما زال اختبارًا جديدًا.
2. **Login HTTPS، artifact B فقط:** استخدم qa.student@example.invalid وكلمة مرور من المخزن الخاص يدويًا؛ لا تضمّنها في أمر shell أو APK/log. المتوقع origin https://localhost:5448/api وhealth local-qa، ونجاح جلسة QA فقط. تعذر reverse أو handshake = STOP، لا Render fallback.
3. **OCR:** جهّز PNG عالية التباين اصطناعية تحتوي QA OCR TEST 123456، ثم fixture MRZ اصطناعية ذات checksums معروفة إذا كان المطلوب اختبار passport parser. سجل توقع fixture قبل التشغيل وبصمتها؛ الملفات لم تُنشأ هنا. المتوقع استخراج النص المحدد عبر PassportScanner، وعدم تغير بيانات شخص حقيقي أو حدوث network request للنموذج/telemetry. نجاح transport لا يثبت التعرف.
4. **Camera/document upload:** صوّر ورقة اصطناعية فقط. وافق على camera permission يدويًا. جرّب رفع/تكرار رفع المستند والوصول من حساب الطالب ثم رفض الحساب القرين. المتوقع storage محلي، ملكية صحيحة وروابط محلية موقعة، دون Cloudinary/production. لا جواز حقيقي ولا gallery شخصية.
5. **Media/browser:** استعمل وسائط محلية وsynthetic URLs فقط. API Dart يثق بالشهادة العامة المحددة؛ browser/native media لا يرثان QA_CA_CERT_BASE64 تلقائيًا. قد يُرفض localhost بشهادة self-signed خارج Dart؛ سجل feature BLOCKED، ولا تتجاوز تحذير المتصفح أو تستخدم trust-all. أي QA-only native trust support يحتاج مراجعة منفصلة قبل اعتماده.
6. **TLS hostname:** على المضيف، اختبر localhost الصحيح ثم wrong.example.invalid مع اتصال 127.0.0.1 نفسه دون DNS خارجي؛ الأوامر أدناه. في التطبيق B المتوقع رفض شهادة/hostname خاطئين عبر fixture محلية مأذونة، دون تغيير production config. اختبارات Windows الحالية لا تحل محل Android.
7. **Production blocking:** اختبارات origin/payload الآلية الحالية تحققت دون اتصال خارجي. إن احتاج runtime اختبارًا سلبيًا، استخدم fixture داخل QA تعرض URL ممنوعًا ويجب رفضه قبل النقل، تحت طبقة منع الخروج؛ لا تفتح URL الإنتاج يدويًا. لا تُعدّل قاعدة QA أو server fixtures تلقائيًا ضمن هذه الخطة.
8. **Restart/deferred work:** على package QA فقط، أوقفها ثم أعد تشغيلها بالأوامر أدناه. لا reboot جهاز أو force job قبل موافقة إضافية محددة. سجل QA job IDs من dumpsys وراجع مالكها قبل أي تشغيل إجباري. راقب queued/retry work وprocess restart وفترة مراقبة موثقة؛ لا نجاح مفترض من صمت قصير. JVM غطى WorkInitializer/ForcedSender بذاكرة، لا OS JobScheduler/SQLite.

```powershell
# المضيف، بدون تعطيل TLS أو الاتصال بغير loopback:
'' | & 'C:\Program Files\OpenSSL-Win64\bin\openssl.exe' s_client -connect 127.0.0.1:5448 -servername localhost -verify_hostname localhost -CAfile D:\work\studybirds_qa_phase7\tls\localhost.crt -verify_return_error -brief
'' | & 'C:\Program Files\OpenSSL-Win64\bin\openssl.exe' s_client -connect 127.0.0.1:5448 -servername localhost -verify_hostname wrong.example.invalid -CAfile D:\work\studybirds_qa_phase7\tls\localhost.crt -verify_return_error -brief
# بعد إذن التشغيل، على QA فقط:
& $qaAdb -s $qaSerial shell am force-stop $qaPackage
& $qaAdb -s $qaSerial shell am start -W -n "$qaPackage/com.studybirds.app.qa.QaMainActivity"
$qaPid = (& $qaAdb -s $qaSerial shell pidof $qaPackage).Trim()
if (!$qaPid -or $qaPid -notmatch '^\d+$') { throw 'Single QA process not verified' }
& $qaAdb -s $qaSerial logcat --pid=$qaPid -d
& $qaAdb -s $qaSerial shell dumpsys jobscheduler
```

أوامر OpenSSL على المضيف نُفذت في pre-build ونجحت/رفضت كما هو متوقع؛ أوامر Android كلها **غير منفذة**. لا تشارك logs دون مراجعة الأسرار. غياب attribution أو capture أو التعرف أو jobs المطلوبة يمنع تسجيل QA runtime ناجحًا. رفع الموارد إلى verified أو رفع قيود بناء مستقبلية لا يتم تلقائيًا بنتيجة هذه الوثيقة.
