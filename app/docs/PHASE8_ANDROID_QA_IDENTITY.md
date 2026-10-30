# Phase 8 — هوية Android QA

الحالة: **مصدر ودمج manifest متحققان، APK غير مبني، تثبيت مستقل غير مختبر فعليًا**.

التعديل محصور في تطبيق النشر `D:\work\studybirds_session_release\app`. لا نسخ أو مزامنة من التطبيق الأساسي.

## اختيار QA

ملفا `android/build.gradle.kts` و`android/app/build.gradle.kts` يقرآن خاصية Gradle الصريحة `studybirdsQa=true`. غيابها يبقي التطبيق دون flavors كما كان؛ القيمة غير المعروفة تُرفض. عند تفعيلها فقط تُنشأ flavor باسم `qa` وبعد `environment`، مع `applicationIdSuffix=.qa` و`versionNameSuffix=-qa`. متغير QA الوحيد المتاح debug؛ إصدار QA release معطل، ولا يُستخدم توقيع الإنتاج له.

الهوية الإنتاجية تبقى `com.studybirds.app` وnamespace يبقى كما كان. الهوية المدمجة الفعلية لـQA هي `com.studybirds.app.qa`، مما يخصص package/data sandbox منفصلين وفق تصميم Android. لم يُثبت تطبيق لإثبات التعايش على جهاز.

الاسم `Study Birds QA` والأيقونة vector جديدة ذات علامتي QA ولونين مختلفين. الملفات:

- `android/app/src/qa/AndroidManifest.xml`
- `android/app/src/qa/res/drawable/ic_launcher_qa.xml`
- `android/app/src/qaDebug/AndroidManifest.xml`

استُبدل تصريح MainActivity في QA وحده، بما فيه filters الموروثة، وأبقي launcher فقط. لا scheme خاص ولا HTTPS App Links أو autoVerify للإنتاج في الناتج المدمج. عُطلت معالجة Flutter التلقائية للروابط، وأُزيلت SignInHubActivity ومواضع بدء Firebase/Sentry المعروفة. هذه ليست شهادة بعزل كل SDK.

ملف debug الموجود يسمح cleartext؛ محاولة الدمج الأولى كشفت تعارضًا مع QA. أُضيف overlay بأولوية qaDebug تفرض false دون تعديل debug أو main. نجح الدمج التالي وظهرت القيمة false فعلًا. بعض markers الاحترازية أعطت تحذيرًا لعدم وجود عنصر أصلي؛ لم تُخف التحذيرات.

## الإخراج والحماية

في QA فقط يُوجّه Gradle وكل subprojects إلى:

`D:\work\studybirds_qa_phase7\android-build`

المسار الافتراضي `app\build` يبقى كما كان خارج QA. الناتج المستقبلي المتوقع من Gradle/Flutter plugin:

`D:\work\studybirds_qa_phase7\android-build\app\outputs\flutter-apk\app-qa-debug.apk`

مراجعة SDK المحلي أثبتت أن plugin ينسخ الناتج إلى buildDirectory الخاصة بمشروع app باسم flavor. لم تُختبر الكتابة النهائية لأن APK لم يُبنَ. لا يُستخدم Flutter CLI مباشرة لهذا المقترح لأن اكتشافه للناتج يفترض المسار المعتاد؛ الأمر المقترح يستدعي Gradle مباشرة بإعدادات Dart صريحة.

حاجز task graph يمنع تجميع/حزم/assemble/install QA ما دام العزل غير متحقق؛ لا خاصية bypass. فحص `assembleQaDebug --dry-run` رُفض فعلًا قبل تنفيذ مهام APK. لا يعني النجاح في مهمة manifest نجاح بناء APK.

## دليل الدمج

شُغّل offline، دون تنزيل أو APK:

```powershell
# من deployment/app/android
.\gradlew.bat --offline --no-daemon --max-workers=1 -PstudybirdsQa=true :app:processQaDebugMainManifest
```

الناتج المفحوص:

`D:\work\studybirds_qa_phase7\android-build\app\intermediates\merged_manifest\qaDebug\processQaDebugMainManifest\AndroidManifest.xml`

نجحت اختبارات هوية الناتج وروابطه وإزالة autoinit المعروفة. فشل اختبار اكتمال عزل native؛ راجع التقرير المختص. البصمة الإنتاجية لـmain manifest بقيت `2392ff5f7cbffc76af69fb58e4cbc6438a15aa94ea5c634f66560e3cc552eae4`.

المرجع المستخدم لأولوية overlays وقواعد الاستبدال: [Android manifest merger](https://developer.android.com/build/manage-manifests).
