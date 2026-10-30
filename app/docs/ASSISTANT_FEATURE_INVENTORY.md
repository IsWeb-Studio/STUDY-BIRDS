# Study Birds assistant feature inventory

Version 2026.10.22.3. This inventory describes reviewed local code, not hosted availability.

- version: 2026.10.22.2
- sourceFiles: 641
- screenDeclarations: 167
- sourceFilesWithScreens: 82
- topicCount: 62
- studentTopics: 48
- restrictedTopics: 14
- screenDeclarationsInReferencedFiles: 166
- screenDeclarationsWithoutDirectTopicSource: 1
- shortcutCount: 23
- skippedLinks: 0
- scope: Local code verification only; no production feature-flag, external-provider or device verification.

The declaration count includes supporting and restricted screens. A source-file reference is not a claim that every class in that file has been functionally tested. Unmatched declarations remain explicitly unverified, rather than receiving invented instructions.

## applications — Applications / الطلبات

Open your applications and select one to see its overview, documents and timeline. To start an application, open a university and program in the catalog and review its details before applying. Requirements vary by program; I cannot confirm an unrecorded admission or response date.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Home → My Applications / الرئيسية ← طلباتي.
- Navigation: ApplicationsListScreen via MaterialPageRoute; action applications
- Sources: mobile:lib/screens/applications_documents_payments/applications_screens.dart.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Availability depends on your account; this chat performs no sensitive actions. / المعلومات حسب ما يعرضه حسابك؛ لا تنفذ المحادثة أي إجراء حساس.

1. Open your applications and select one to see its overview, documents and timeline. To start an application, open a university and program in the catalog and review its details before applying. Requirements vary by program; I cannot confirm an unrecorded admission or response date.

1. افتح قائمة طلباتك، ثم اختر الطلب لعرض نظرة عامة والمستندات والجدول الزمني. لبدء طلب، افتح الجامعة والبرنامج في دليل الجامعات وراجع تفاصيله قبل التقديم. تختلف المتطلبات حسب البرنامج؛ لا يمكنني تأكيد قبول أو موعد رد غير مسجل.

## documents — Documents / المستندات

Open your documents to manage files. For a specific application, open it and use its Documents tab or document completion action. You can reuse an existing file or upload another version. Do not send identity images or verification codes in this chat.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: My Documents or Application → Documents / مستنداتي أو الطلب ← المستندات.
- Navigation: MyDocumentsScreen via MaterialPageRoute; action documents
- Sources: mobile:lib/screens/applications_documents_payments/documents_screens.dart.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Availability depends on your account; this chat performs no sensitive actions. / المعلومات حسب ما يعرضه حسابك؛ لا تنفذ المحادثة أي إجراء حساس.

1. Open your documents to manage files. For a specific application, open it and use its Documents tab or document completion action. You can reuse an existing file or upload another version. Do not send identity images or verification codes in this chat.

1. افتح مستنداتك لإدارة الملفات. لمستندات طلب معين، افتح الطلب ثم المستندات أو استكمال مستندات الطلب. عند وجود ملف سابق، يمكنك استخدامه أو رفع نسخة أخرى. لا ترسل صور الهوية أو رموز التحقق في هذه المحادثة.

## catalog — University and program catalog / دليل الجامعات والبرامج

Open the universities or programs catalog, use search and filters, then open the institution or program details. Those entries are the current reference. I cannot confirm fees, deadlines or requirements that are not listed. For missing information, create a ticket in Support Center.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student, parent, partner, employee, admin, university.
- Location: Explore → Universities / Programs / الاستكشاف ← الجامعات / البرامج.
- Navigation: UniversitiesExplorerScreen via MaterialPageRoute; action universities
- Sources: mobile:lib/screens/universities_programs_countries/universities_screens.dart.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Availability depends on your account; this chat performs no sensitive actions. / المعلومات حسب ما يعرضه حسابك؛ لا تنفذ المحادثة أي إجراء حساس.

1. Open the universities or programs catalog, use search and filters, then open the institution or program details. Those entries are the current reference. I cannot confirm fees, deadlines or requirements that are not listed. For missing information, create a ticket in Support Center.

1. افتح دليل الجامعات أو البرامج واستخدم البحث والفلاتر، ثم افتح تفاصيل الجامعة أو البرنامج. المعلومات المتاحة هناك هي المرجع الحالي؛ لا أملك تأكيدًا لرسوم أو مواعيد أو متطلبات غير معروضة. للمعلومات الناقصة، أرسل تذكرة من مركز الدعم.

## account — Login and account / تسجيل الدخول والحساب

Use the login screen to sign in and My Account to manage your account. Complete email verification when prompted. Never share your password or email code here. If sign-in fails, contact support without sending secrets.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student, parent, partner, employee, admin, university.
- Location: Login / My Account / الدخول / حسابي.
- Navigation: SettingsScreen via MaterialPageRoute; action settings
- Sources: mobile:lib/screens/profile_account/profile_account_screens.dart, mobile:lib/screens/auth/email_challenge_screen.dart, mobile:lib/screens/auth/login_register_screens.dart.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Availability depends on your account; this chat performs no sensitive actions. / المعلومات حسب ما يعرضه حسابك؛ لا تنفذ المحادثة أي إجراء حساس.

1. Use the login screen to sign in and My Account to manage your account. Complete email verification when prompted. Never share your password or email code here. If sign-in fails, contact support without sending secrets.

1. استخدم شاشة تسجيل الدخول للدخول إلى حسابك، وصفحة حسابي لإدارة حسابك. أكمل توثيق البريد عندما تطلبه الشاشة. لا تشارك كلمة المرور أو كود البريد هنا. إذا تعذر الدخول، تواصل مع الدعم بدل إرسال بياناتك السرية.

## notifications — Notifications / الإشعارات

Open Notifications to see alerts and Notification Preferences to choose the categories for your account. Security and urgent help alerts remain enabled. If notifications do not arrive, also check Study Birds notification permission in device settings.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Home → Notifications; My Account → Settings → Notification Preferences / الرئيسية ← الإشعارات؛ حسابي ← الإعدادات ← تفضيلات الإشعارات.
- Navigation: NotificationsScreen via MaterialPageRoute; action notifications
- Sources: mobile:lib/screens/profile_account/notification_preferences_screen.dart, mobile:lib/screens/home_journey/notifications_screen.dart.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Availability depends on your account; this chat performs no sensitive actions. / المعلومات حسب ما يعرضه حسابك؛ لا تنفذ المحادثة أي إجراء حساس.

1. Open Notifications to see alerts and Notification Preferences to choose the categories for your account. Security and urgent help alerts remain enabled. If notifications do not arrive, also check Study Birds notification permission in device settings.

1. افتح الإشعارات لعرض تنبيهاتك، وتفضيلات الإشعارات لاختيار الفئات المتاحة لحسابك. تنبيهات الأمان والمساعدة العاجلة تبقى مفعّلة. إذا لم تصل التنبيهات، تحقق أيضًا من إذن إشعارات Study Birds في إعدادات الجهاز.

## community — Student Community / مجتمع الطلاب

Use Student Community for posts, discussions and stories. My Streak is in your profile; tap its card for details and recovery eligibility determined by the server. I cannot publish content or restore a streak on your behalf.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Bottom navigation → Community / الشريط السفلي ← المجتمع.
- Navigation: Manual workflow in stories/student_stories.dart; no executable action.
- Sources: mobile:lib/screens/stories/student_stories.dart, mobile:lib/screens/profile_account/my_streak.dart, mobile:lib/screens/community/student_community_hub.dart.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Availability depends on your account; this chat performs no sensitive actions. / المعلومات حسب ما يعرضه حسابك؛ لا تنفذ المحادثة أي إجراء حساس.

1. Use Student Community for posts, discussions and stories. My Streak is in your profile; tap its card for details and recovery eligibility determined by the server. I cannot publish content or restore a streak on your behalf.

1. استخدم مجتمع الطلاب للمنشورات والنقاشات والقصص. سلسلة نشاطي موجودة في ملفك الشخصي؛ اضغط البطاقة لعرض التفاصيل والاسترجاع المتاح حسب توقيت السيرفر. لا أستطيع نشر محتوى أو استرجاع السلسلة نيابة عنك.

## support — Support Center / مركز الدعم

From My Account, open Support Center. Choose a new support ticket to describe the issue and follow replies in My Tickets. Do not include passwords or verification codes. Which screen has the problem?

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: My Account → Support Center / حسابي ← مركز الدعم.
- Navigation: SupportCenterScreen via MaterialPageRoute; action support
- Sources: mobile:lib/screens/services_support/support_team_ai_screens.dart, mobile:lib/screens/services_support/bird_ai_screen.dart.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Availability depends on your account; this chat performs no sensitive actions. / المعلومات حسب ما يعرضه حسابك؛ لا تنفذ المحادثة أي إجراء حساس.

1. From My Account, open Support Center. Choose a new support ticket to describe the issue and follow replies in My Tickets. Do not include passwords or verification codes. Which screen has the problem?

1. من حسابي افتح مركز الدعم. اختر تذكرة دعم جديدة لشرح المشكلة، ثم تابع الردود في تذاكري. لا تضف كلمات مرور أو أكواد تحقق. ما الشاشة التي تواجه فيها المشكلة؟

## passport — Passport scanning / قراءة جواز السفر

In My Account, choose Passport, then use the camera or select a file from your phone.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: My Account → Passport / حسابي ← جواز السفر.
- Navigation: EditProfileScreen via MaterialPageRoute; action passport
- Sources: mobile:lib/screens/profile_account/edit_profile_screen.dart, server:src/routes/studentRoutes.js, mobile:lib/screens/profile_account/passport_scanner_screen.dart.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Camera capture requires permission; recognition may require correction or a clearer image. / تحتاج إذن الكاميرا عند التصوير؛ القراءة الآلية قد تحتاج تصحيحًا أو صورة أوضح.

1. In My Account, choose Passport, then use the camera or select a file from your phone.
2. Review extracted fields on the passport review screen before saving. Never send the passport in chat.

1. من حسابي اختر جواز السفر، ثم افتح الكاميرا أو اختر ملفًا من الهاتف.
2. راجع البيانات المستخرجة في شاشة مراجعة بيانات الجواز قبل الحفظ. لا ترسل الجواز إلى المحادثة.

## upload-failure — Upload troubleshooting / مشكلة رفع الملفات

Check connectivity, file validity and camera/file-selection permissions.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Documents / المستندات.
- Navigation: MyDocumentsScreen via MaterialPageRoute; action documents
- Sources: mobile:lib/screens/applications_documents_payments/documents_screens.dart, server:src/routes/studentRoutes.js.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Check connectivity, file validity and camera/file-selection permissions.
2. Use retry after a failed upload, then open the application to verify document status.
3. If it persists, open Support Center and create a ticket without secrets.

1. تحقق من الاتصال وصلاحية الملف وأذونات الكاميرا أو اختيار الملفات.
2. في حالة فشل الرفع استخدم إعادة المحاولة؛ افتح الطلب نفسه للتأكد من حالة المستند.
3. إذا استمرت المشكلة، افتح مركز الدعم وأرسل تذكرة دون إرفاق أسرار.

## password — Change password / تغيير كلمة المرور

Open My Account, Settings, then Change password.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: My Account → Settings → Change password / حسابي ← الإعدادات ← تغيير كلمة المرور.
- Navigation: SettingsScreen via MaterialPageRoute; action settings
- Sources: mobile:lib/screens/profile_account/profile_account_screens.dart, server:src/routes/authRoutes.js, server:src/routes/mobileSecurityRoutes.js.
- Backend: server:src/routes/authRoutes.js, server:src/routes/mobileSecurityRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open My Account, Settings, then Change password.
2. If you cannot sign in, use account recovery on the login screen. Never share passwords or codes here.

1. من حسابي افتح الإعدادات ثم تغيير كلمة المرور.
2. إذا لم تستطع الدخول، استخدم استعادة الحساب في شاشة الدخول. لا تشارك كلمة المرور أو الكود هنا.

## security — Account security / أمان الحساب

Open Security from My Account settings.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student, parent, partner, employee, admin, university.
- Location: My Account → Settings → Security / حسابي ← الإعدادات ← الأمان.
- Navigation: SecuritySettingsScreen via MaterialPageRoute; action security
- Sources: mobile:lib/screens/profile_account/security_settings_screen.dart, server:src/routes/mobileSecurityRoutes.js, mobile:lib/screens/profile_account/account_security_screen.dart.
- Backend: server:src/routes/mobileSecurityRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open Security from My Account settings.
2. Review the security and session options offered to your account and complete any required verification before changing them.

1. افتح الأمان من إعدادات حسابي.
2. راجع خيارات الأمان والجلسات المعروضة لحسابك، واتبع التحقق الذي تطلبه الشاشة قبل أي تغيير.

## profile — Edit profile / تعديل الملف الشخصي

Open My Account and tap the photo to change it, or select Personal information, Academic information or Study preferences.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: My Account / حسابي.
- Navigation: ProfileScreen via MaterialPageRoute; action profile
- Sources: mobile:lib/screens/profile_account/profile_account_screens.dart, server:src/routes/studentRoutes.js.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open My Account and tap the photo to change it, or select Personal information, Academic information or Study preferences.
2. Edit the relevant section and save on its edit screen.

1. افتح حسابي واضغط الصورة لتغييرها، أو اختر المعلومات الشخصية أو الأكاديمية أو تفضيلات الدراسة.
2. عدّل الحقول في القسم المطلوب واحفظ من شاشة التعديل.

## streak — My Streak / سلسلة نشاطي

Open My Account and tap My Streak below the profile header.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: My Account → My Streak / حسابي ← سلسلة نشاطي.
- Navigation: ProfileScreen via MaterialPageRoute; action profile
- Sources: mobile:lib/screens/profile_account/my_streak.dart, server:src/routes/storyRoutes.js, server:src/utils/storyRules.js.
- Backend: server:src/routes/storyRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open My Account and tap My Streak below the profile header.
2. Details show your current and longest streak, recent activity and the server deadline.
3. Recovery is available for 24 hours after expiry, up to 3 successful restores per calendar month in the server timezone; unused restores do not roll over.
4. Check time and remaining allowance in the confirmation sheet. A monthly reset does not reopen an expired window.

1. افتح حسابي واضغط بطاقة سلسلة نشاطي أسفل رأس الملف الشخصي.
2. تعرض التفاصيل السلسلة الحالية والأطول والنشاط الأخير والموعد الفعلي من السيرفر.
3. يمكن استرجاع السلسلة خلال 24 ساعة بعد انتهائها، حتى 3 استرجاعات ناجحة في الشهر حسب منطقة توقيت السيرفر؛ المتبقي لا يتراكم.
4. راجع الوقت والمتبقي في ورقة التأكيد قبل الاسترجاع. بداية الشهر لا تعيد فتح مهلة انتهت.

## stories — Stories and viewers / القصص والمشاهدات

Open Stories in Student Community to view stories or use the displayed publishing controls.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Student Community → Stories / مجتمع الطلاب ← القصص.
- Navigation: StudentCommunityHub via MaterialPageRoute; action community
- Sources: mobile:lib/screens/stories/student_stories.dart, server:src/routes/storyRoutes.js, mobile:lib/screens/stories/story_viewers_screen.dart.
- Backend: server:src/routes/storyRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open Stories in Student Community to view stories or use the displayed publishing controls.
2. Open your own story and tap the viewer count to see its list. Another student’s private viewer list is not available to you.

1. افتح القصص في مجتمع الطلاب لعرض القصص أو نشر قصتك من أدوات النشر المعروضة.
2. لمعرفة المشاهدين، افتح قصتك واضغط عدد المشاهدات لعرض القائمة. لا تُتاح قائمة مشاهدي قصة طالب آخر لك.

## friends — Friends / الأصدقاء

Open Friends from My Account.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: My Account → Friends / حسابي ← الأصدقاء.
- Navigation: FriendsScreen via MaterialPageRoute; action friends
- Sources: mobile:lib/screens/stories/friends_screen.dart, server:src/routes/friendRoutes.js.
- Backend: server:src/routes/friendRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open Friends from My Account.
2. Use the search and friend-request controls shown; review a request before accepting or sending it.

1. من حسابي افتح الأصدقاء.
2. استخدم البحث وخيارات طلبات الصداقة المعروضة، وراجع الطلب قبل قبوله أو إرساله.

## messages — Messaging and urgent help / المراسلات والمساعدة العاجلة

Open conversations in Student Community to access the chats permitted for your account.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Student Community / Support Center / مجتمع الطلاب / مركز الدعم.
- Navigation: StudentCommunityHub via MaterialPageRoute; action community
- Sources: mobile:lib/screens/services_support/messaging_and_emergency_screens.dart, server:src/routes/mobileMessagingRoutes.js.
- Backend: server:src/routes/mobileMessagingRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open conversations in Student Community to access the chats permitted for your account.
2. For urgent help, open Support Center, Emergency Help, then Open internal conversation. Only your assigned support team appears. If no team is assigned, create a support ticket. Never send secrets to the assistant.

1. افتح المحادثات في مجتمع الطلاب للوصول إلى المحادثات المسموحة لحسابك.
2. للمساعدة العاجلة افتح مركز الدعم ثم مساعدة عاجلة ثم فتح المحادثة الداخلية؛ تظهر فقط أسماء فريق الدعم المعيّن لك. إذا لم يوجد فريق، أرسل تذكرة دعم. لا ترسل أسرارًا للمساعد.

## game — The Winker game / لعبة الغمّازة

Open The Winker from bottom navigation.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Bottom navigation → The Winker / الشريط السفلي ← الغمّازة.
- Navigation: WinkScreen via MaterialPageRoute; action game
- Sources: mobile:lib/screens/games/wink_screen.dart, server:src/routes/winkRoutes.js.
- Backend: server:src/routes/winkRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open The Winker from bottom navigation.
2. Choose single-device practice, Create room, or join with a code to play with friends.
3. Group play requires at least 4 ready players. Keep your secret role private.

1. افتح الغمّازة من الشريط السفلي.
2. اختر جرّبها بجهاز واحد للتدريب الخاص، أو إنشاء غرفة أو الانضمام بكود للعب مع أصدقائك.
3. لعب المجموعة يحتاج 4 لاعبين على الأقل والجميع جاهز؛ لا تشارك دورك السري.

## countries — Country universities / جامعات الدولة

Open Explore, Countries, then choose a country.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Explore → Countries / الاستكشاف ← الدول.
- Navigation: CountriesExplorerScreen via MaterialPageRoute; action countries
- Sources: mobile:lib/screens/universities_programs_countries/countries_scholarships_screens.dart, server:src/routes/contentRoutes.js, server:src/routes/universityRoutes.js.
- Backend: server:src/routes/contentRoutes.js, server:src/routes/universityRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open Explore, Countries, then choose a country.
2. The university count represents catalog entries only; zero means none are listed for that country. Open its universities to browse them.

1. من الاستكشاف افتح الدول واختر الدولة المطلوبة.
2. عدد الجامعات يعبّر عن الجامعات الموجودة في دليل المنصة فقط؛ إذا كان صفرًا فلا توجد جامعات مسجلة لها. افتح جامعات الدولة لعرضها.

## finder — Program finder / مكتشف البرنامج

Open Program finder from Explore.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Explore → Program finder / الاستكشاف ← مكتشف البرنامج.
- Navigation: ProgramsExplorerScreen via MaterialPageRoute; action programs
- Sources: mobile:lib/screens/universities_programs_countries/programs_screens.dart, server:src/routes/programRoutes.js.
- Backend: server:src/routes/programRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open Program finder from Explore.
2. Use the available selections and filters, then review program details and requirements before applying.

1. افتح مكتشف البرنامج من الاستكشاف.
2. استخدم اختيارات وفلاتر البحث المعروضة، ثم راجع تفاصيل البرنامج ومتطلباته قبل تقديم طلب.

## compare — Compare universities and programs / مقارنة الجامعات والبرامج

Add universities or programs using the catalog comparison controls.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Explore → Comparison list / الاستكشاف ← قائمة المقارنة.
- Navigation: CompareListScreen via MaterialPageRoute; action compare
- Sources: mobile:lib/screens/universities_programs_countries/compare_list_screen.dart, server:src/routes/universityRoutes.js, server:src/routes/programRoutes.js.
- Backend: server:src/routes/universityRoutes.js, server:src/routes/programRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Add universities or programs using the catalog comparison controls.
2. Open Comparison list in Explore to review the selected items.

1. أضف الجامعات أو البرامج إلى المقارنة من أدوات الدليل.
2. من الاستكشاف افتح قائمة المقارنة لمراجعة العناصر المختارة.

## favorites — Favorites / المفضلة

Use the save control on a university or program.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Explore → Favorites / الاستكشاف ← المفضلة.
- Navigation: FavoritesScreen via MaterialPageRoute; action favorites
- Sources: mobile:lib/screens/universities_programs_countries/explore_hub_screen.dart, server:src/routes/studentRoutes.js.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Use the save control on a university or program.
2. Open Favorites from Explore and switch between saved universities and programs.

1. استخدم علامة الحفظ على الجامعة أو البرنامج.
2. افتح المفضلة من الاستكشاف وبدّل بين الجامعات والبرامج المحفوظة.

## journey — Journey tracking / متابعة الرحلة

Open My Journey and select an application if you have several.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Bottom navigation → My Journey / الشريط السفلي ← رحلتي.
- Navigation: JourneyTrackerScreen via MaterialPageRoute; action journey
- Sources: mobile:lib/screens/home_journey/journey_tracker_screen.dart, server:src/routes/studentRoutes.js, server:src/routes/applicationRoutes.js.
- Backend: server:src/routes/studentRoutes.js, server:src/routes/applicationRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open My Journey and select an application if you have several.
2. Review the current stage, requirements and next action displayed. Completing a local step is not an official admission decision.

1. افتح رحلتي واختر طلبك إذا كان لديك أكثر من طلب.
2. راجع المرحلة الحالية والمتطلبات والإجراء التالي المعروض. لا يعني اكتمال خطوة محلية حصولك على قبول رسمي.

## payments — Invoices and payment proof / الفواتير وإثبات الدفع

Open Payments summary and select an invoice to view its recorded amount and status.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Payments summary in your application workflow / ملخص المدفوعات في مسار الطلب.
- Navigation: PaymentsSummaryScreen via MaterialPageRoute; action payments
- Sources: mobile:lib/screens/applications_documents_payments/payments_screens.dart, server:src/routes/studentRoutes.js, server:src/routes/paymentProofAccessRoutes.js.
- Backend: server:src/routes/studentRoutes.js, server:src/routes/paymentProofAccessRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open Payments summary and select an invoice to view its recorded amount and status.
2. When payment-proof upload is offered, check the invoice before attaching proof. Upload does not mean automatic approval.

1. افتح ملخص المدفوعات واختر الفاتورة لعرض المبلغ والحالة المسجلين.
2. عند توفر رفع إثبات الدفع، راجع الفاتورة قبل إرفاق الإثبات. رفع الإثبات لا يعني اعتماده تلقائيًا.

## services — Service requests / طلب خدمة

Open Services and select a published service to read its details.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Bottom navigation → Services / الشريط السفلي ← الخدمات.
- Navigation: ServicesCenterScreen via MaterialPageRoute; action services
- Sources: mobile:lib/screens/services_support/services_consultation_screens.dart, server:src/routes/serviceRequestRoutes.js.
- Backend: server:src/routes/serviceRequestRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open Services and select a published service to read its details.
2. Review conditions and inputs before submitting the request yourself. Follow its status from My Requests in the service center.

1. افتح الخدمات واختر خدمة منشورة لقراءة التفاصيل.
2. راجع الشروط والبيانات قبل إرسال الطلب بنفسك. تابع حالته من طلباتي داخل مركز الخدمات.

## consultation — Consultations / حجز استشارة

Open the consultation option when offered on Home.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: Consultation booking when offered on Home / الحجز عند عرض خيار الاستشارة في الرئيسية.
- Navigation: Manual workflow in services_support/services_consultation_screens.dart; no executable action.
- Sources: mobile:lib/screens/services_support/services_consultation_screens.dart, server:src/routes/consultationRoutes.js.
- Backend: server:src/routes/consultationRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open the consultation option when offered on Home.
2. Choose an available slot and review booking details before confirming. No listed slots does not imply an off-platform booking is available.

1. افتح خيار الاستشارة عندما يظهر في الرئيسية.
2. اختر من المواعيد المتاحة وراجع تفاصيل الحجز قبل التأكيد. عدم وجود مواعيد لا يعني توفر حجز خارج النظام.

## scholarships — Scholarships / المنح الدراسية

Open Scholarships to review published opportunities and each set of requirements.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Explore or My Account → Scholarships / الاستكشاف أو حسابي ← المنح الدراسية.
- Navigation: ScholarshipsScreen via MaterialPageRoute; action scholarships
- Sources: mobile:lib/screens/services_support/student_life_alumni_screens.dart, server:src/routes/scholarshipRoutes.js, mobile:lib/screens/universities_programs_countries/countries_scholarships_screens.dart.
- Backend: server:src/routes/scholarshipRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open Scholarships to review published opportunities and each set of requirements.
2. Review your submitted scholarship applications and statuses in its applications section. Eligibility, admission and unlisted deadlines are not guaranteed.

1. افتح المنح الدراسية لمراجعة المنح المنشورة وشروط كل منها.
2. راجع الطلبات المقدمة وحالتها في قسم طلبات المنح. لا أضمن أهلية أو قبولًا أو موعدًا غير منشور.

## events — Student life events / الحياة الطلابية والفعاليات

Open Student life and events from My Account.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: My Account → Student life and events / حسابي ← الحياة الطلابية والفعاليات.
- Navigation: StudentLifeOffersScreen via MaterialPageRoute; action events
- Sources: mobile:lib/screens/services_support/student_life_alumni_screens.dart, server:src/routes/contentRoutes.js.
- Backend: server:src/routes/contentRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open Student life and events from My Account.
2. Select a published event, read its details and use Register attendance when available.

1. افتح الحياة الطلابية والفعاليات من حسابي.
2. اختر فعالية منشورة واقرأ التفاصيل، ثم استخدم سجّل حضورك إذا كان متاحًا.

## alumni — Alumni and opportunities / شبكة الخريجين والفرص

Open Alumni network from My Account.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: My Account → Alumni network / حسابي ← شبكة الخريجين.
- Navigation: AlumniNetworkScreen via MaterialPageRoute; action alumni
- Sources: mobile:lib/screens/services_support/student_life_alumni_screens.dart, server:src/routes/alumniRoutes.js.
- Backend: server:src/routes/alumniRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open Alumni network from My Account.
2. Choose the directory, jobs/internships, student listings or postgraduate scholarships. Records depend on published content and your permissions.

1. افتح شبكة الخريجين من حسابي.
2. اختر دليل الخريجين أو الوظائف والتدريب أو إعلانات الطلاب أو منح الدراسات العليا. ظهور السجلات يعتمد على المنشور وصلاحياتك.

## rewards — Rewards and wallet / المكافآت والمحفظة

Open Rewards or Wallet from My Account.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: My Account → Rewards / Wallet / حسابي ← المكافآت / المحفظة.
- Navigation: StudentRewardsScreen via MaterialPageRoute; action rewards
- Sources: mobile:lib/screens/profile_account/student_rewards_currency_screens.dart, server:src/routes/studentRoutes.js.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open Rewards or Wallet from My Account.
2. Review your points, balance and the conditions displayed. I cannot grant points, redeem credit or make payments for you.

1. افتح المكافآت أو المحفظة من حسابي.
2. راجع النقاط والرصيد والشروط التي يعرضها حسابك. لا أستطيع منح نقاط أو تنفيذ استبدال أو دفع بالنيابة عنك.

## referral — Referral code / رمز الإحالة

Open Referral code from My Account.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: My Account → Referral code / حسابي ← رمز الإحالة.
- Navigation: ProfileScreen via MaterialPageRoute; action profile
- Sources: mobile:lib/screens/profile_account/profile_account_screens.dart, server:src/routes/studentRoutes.js.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open Referral code from My Account.
2. Copy or share the code when one exists; otherwise use the displayed Support Center link.

1. افتح رمز الإحالة من حسابي.
2. استخدم نسخ الرمز أو المشاركة إذا كان لديك رمز؛ إذا لم يظهر رمز، استخدم رابط مركز الدعم المعروض.

## language — App language / لغة التطبيق

Open My Account settings, then Language.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student, parent, partner, employee, admin, university.
- Location: My Account → Settings → Language / حسابي ← الإعدادات ← اللغة.
- Navigation: SettingsScreen via MaterialPageRoute; action settings
- Sources: mobile:lib/screens/profile_account/profile_account_screens.dart, server:src/routes/authRoutes.js, mobile:lib/core/services/locale_controller.dart.
- Backend: server:src/routes/authRoutes.js.
- Restrictions: Chat cannot enable a disabled build flag. / لا يمكن للمحادثة تفعيل علم بناء غير مفعّل.

1. Open My Account settings, then Language.
2. The default build offers Arabic only. English selection requires an ENABLE_EN build; an absent choice is not enabled in your version.

1. افتح إعدادات حسابي ثم اللغة.
2. النسخة الافتراضية تعرض العربية فقط. اختيار الإنجليزية متاح فقط في بناء ENABLE_EN؛ إذا لم يظهر الخيار فهو غير مفعّل في هذه النسخة.

## theme — App appearance / مظهر التطبيق

There is no standalone theme toggle in the reviewed app settings.

- Availability: unavailable (code verified; live prerequisites not tested).
- Roles: student, parent, partner, employee, admin, university.
- Location: Current settings / الإعدادات الحالية.
- Navigation: Manual workflow in profile_account/profile_account_screens.dart; no executable action.
- Sources: mobile:lib/screens/profile_account/profile_account_screens.dart, server:src/routes/authRoutes.js, mobile:lib/main.dart.
- Backend: server:src/routes/authRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. There is no standalone theme toggle in the reviewed app settings.
2. I cannot invent a dark-mode page or button; the assistant respects the theme supplied by the app.

1. لا يوجد مفتاح مستقل لتغيير الثيم في إعدادات التطبيق التي تمت مراجعتها.
2. لا أستطيع اختراع صفحة أو زر للوضع الداكن؛ المساعد يدعم ألوان الثيم الذي يوفّره التطبيق.

## delete-account — Delete account / حذف الحساب

To review the conditions, open Settings then Delete account permanently.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student, parent, partner, employee, admin, university.
- Location: My Account → Settings → Delete account permanently / حسابي ← الإعدادات ← حذف الحساب نهائيًا.
- Navigation: SettingsScreen via MaterialPageRoute; action settings
- Sources: mobile:lib/screens/profile_account/profile_account_screens.dart, server:src/routes/mobileSecurityRoutes.js, mobile:lib/screens/profile_account/delete_account_screen.dart.
- Backend: server:src/routes/mobileSecurityRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. To review the conditions, open Settings then Delete account permanently.
2. Review deletion and required verification carefully. The assistant never deletes an account or bypasses confirmation.

1. للاطلاع على الشروط افتح الإعدادات ثم حذف الحساب نهائيًا.
2. راجع شاشة الحذف والتحقق المطلوب بعناية. لا ينفذ المساعد الحذف ولا يتجاوز التأكيد.

## travel — Visa travel and accommodation / التأشيرة والسفر والسكن

Open your application and My Journey to see its available stage/services, such as visa, travel, accommodation or university registration.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: Journey workflow and available Home services / مسار الرحلة والخدمات المتاحة في الرئيسية.
- Navigation: JourneyTrackerScreen via MaterialPageRoute; action journey
- Sources: mobile:lib/screens/visa_travel_accommodation/visa_travel_screens.dart, server:src/routes/studentRoutes.js, server:src/routes/applicationRoutes.js, mobile:lib/screens/visa_travel_accommodation/accommodation_arrival_screens.dart.
- Backend: server:src/routes/studentRoutes.js, server:src/routes/applicationRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open your application and My Journey to see its available stage/services, such as visa, travel, accommodation or university registration.
2. Use the requirements recorded for your application; rules, fees and deadlines are not identical across countries or universities.

1. افتح طلبك ورحلتي لعرض المرحلة والخدمة المتاحة، مثل التأشيرة أو السفر أو السكن أو التسجيل الجامعي.
2. راجع المتطلبات المسجلة لطلبك فقط؛ لا توجد قواعد أو رسوم أو مواعيد موحدة لجميع الدول والجامعات.

## calendar — Calendar dates and activity / التقويم والمواعيد والنشاط

Review Calendar, Important dates and Activity log when shown in Home or your application workflow.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: Calendar and activity views in Home/Journey / التقويم وسجل النشاط من واجهات الرئيسية والرحلة.
- Navigation: Manual workflow in home_journey/calendar_screen.dart; no executable action.
- Sources: mobile:lib/screens/home_journey/calendar_screen.dart, server:src/routes/studentRoutes.js, mobile:lib/screens/home_journey/important_dates_screen.dart, mobile:lib/screens/home_journey/activity_log_screen.dart.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Review Calendar, Important dates and Activity log when shown in Home or your application workflow.
2. Select a day or event to inspect recorded details. No recorded event does not establish an external deadline.

1. راجع التقويم والمواعيد المهمة وسجل النشاط عند عرضها في الرئيسية أو مسار الطلب.
2. اختر اليوم أو الحدث لقراءة التفاصيل المسجلة. عدم وجود موعد مسجل لا يعني تأكيد موعد خارجي.

## knowledge — Knowledge FAQ and exhibitions / المعرفة والأسئلة الشائعة والمعارض

Open Knowledge Center or FAQ when offered to your account, or Exhibitions from Explore.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: Knowledge Center / Explore → Exhibitions / مركز المعرفة / الاستكشاف ← محطة المعارض.
- Navigation: Manual workflow in services_support/knowledge_base_screen.dart; no executable action.
- Sources: mobile:lib/screens/services_support/knowledge_base_screen.dart, server:src/routes/contentRoutes.js, server:src/routes/studentRoutes.js, mobile:lib/screens/services_support/faq_screen.dart.
- Backend: server:src/routes/contentRoutes.js, server:src/routes/studentRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open Knowledge Center or FAQ when offered to your account, or Exhibitions from Explore.
2. Read the published material. Ask Support Center if current information is missing.

1. افتح مركز المعرفة أو الأسئلة الشائعة عندما تظهر في حسابك، أو محطة المعارض من الاستكشاف.
2. اقرأ المواد المنشورة؛ إذا غابت معلومة حديثة، اسأل مركز الدعم بدل الاعتماد على تقدير.

## parent — Parent dashboard / حساب ولي الأمر

Use the Parent dashboard to review link requests and approved linked children.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: parent.
- Location: Parent dashboard after authorized sign-in / لوحة ولي الأمر بعد تسجيل الدخول بالدور المصرّح.
- Navigation: Manual workflow in roles/parent_dashboard_screen.dart; no executable action.
- Sources: mobile:lib/screens/roles/parent_dashboard_screen.dart, server:src/routes/parentRoutes.js.
- Backend: server:src/routes/parentRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Use the Parent dashboard to review link requests and approved linked children.
2. Open a linked child to see only permitted overview/payment information; the assistant cannot expose unlinked students.

1. من لوحة ولي الأمر راجع طلبات ربط الطلاب والأبناء المرتبطين المعتمدين.
2. افتح ابنًا مرتبطًا لعرض المعلومات والمدفوعات المسموح بها فقط؛ لا يتيح المساعد بيانات طالب غير مرتبط.

## partner — Agent dashboard / لوحة الوكيل

Review your permitted students and application stages in the Agent dashboard.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: partner.
- Location: Agent dashboard after sign-in / لوحة الوكيل بعد الدخول.
- Navigation: Manual workflow in roles/agent_dashboard_screen.dart; no executable action.
- Sources: mobile:lib/screens/roles/agent_dashboard_screen.dart, server:src/routes/partnerRoutes.js.
- Backend: server:src/routes/partnerRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Review your permitted students and application stages in the Agent dashboard.
2. Use Add student, My wallet or the displayed commission controls within your permissions; the assistant changes no prices or funds.

1. راجع الطلاب ومراحل طلباتهم المتاحة في لوحة الوكيل.
2. استخدم إضافة طالب أو محفظتي أو العمولة المعروضة ضمن صلاحياتك؛ المساعد لا يعدل أسعارًا أو يحوّل أموالًا.

## university-role — University dashboard / لوحة الجامعة

Open an authorized application from the University dashboard.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: university.
- Location: University dashboard after sign-in / لوحة الجامعة بعد الدخول.
- Navigation: Manual workflow in roles/university_dashboard_screen.dart; no executable action.
- Sources: mobile:lib/screens/roles/university_dashboard_screen.dart, server:src/routes/universityPortalRoutes.js, mobile:lib/screens/roles/university_application_review_screen.dart.
- Backend: server:src/routes/universityPortalRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open an authorized application from the University dashboard.
2. Review its details in application review and use only actions permitted for your role; the assistant makes no admission decisions.

1. افتح الطلب المصرّح لجامعتك من لوحة الجامعة.
2. راجع البيانات في شاشة مراجعة الطلبات واستخدم الأفعال المتاحة لدورك فقط؛ المساعد لا يقرر قبولًا أو رفضًا.

## staff — Staff dashboard / لوحة الموظف والإدارة

Open the staff dashboard to see only sections authorized for your account.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: admin, employee.
- Location: Staff dashboard after sign-in with section permissions / لوحة الموظف بعد الدخول وصلاحيات الأقسام.
- Navigation: Manual workflow in roles/employee_dashboard_screen.dart; no executable action.
- Sources: mobile:lib/screens/roles/employee_dashboard_screen.dart, server:src/routes/adminRoutes.js, server:src/routes/crmRoutes.js.
- Backend: server:src/routes/adminRoutes.js, server:src/routes/crmRoutes.js.
- Restrictions: Requires connectivity and your account permissions. Published data may be empty. / تحتاج اتصالًا وصلاحيات حسابك. البيانات المنشورة قد تكون فارغة.

1. Open the staff dashboard to see only sections authorized for your account.
2. Use the student, application and ticket lists actually visible to you. A missing section requires an administrator review, never bypassing permissions.

1. افتح لوحة الموظف لمراجعة الأقسام المصرّح بها لحسابك فقط.
2. استخدم قوائم الطلاب والطلبات والتذاكر التي تظهر لك؛ غياب قسم يحتاج مراجعة المدير، وليس تجاوز الصلاحية.

## registration — Registration and verification / التسجيل والتوثيق

Choose an available account type and complete required registration details.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student, parent, partner, employee, admin, university.
- Location: Start → Register / شاشة البداية ← إنشاء حساب.
- Navigation: Manual workflow in auth/login_register_screens.dart; no executable action.
- Sources: mobile:lib/screens/auth/login_register_screens.dart, mobile:lib/screens/auth/student_registration_wizard_screen.dart, mobile:lib/screens/auth/email_challenge_screen.dart, mobile:lib/screens/auth/verify_contact_screen.dart, mobile:lib/screens/auth/onboarding_and_account_type_screens.dart, mobile:lib/screens/auth/splash_screen.dart, server:src/routes/authRoutes.js.
- Backend: server:src/routes/authRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Choose an available account type and complete required registration details.
2. Follow password setup and email-code verification when prompted. Enter the code only on the verification screen.

1. اختر نوع الحساب المتاح وأكمل نموذج التسجيل والبيانات المطلوبة.
2. اتبع خطوة تعيين كلمة المرور وتوثيق البريد بالكود عند طلبها. أدخل الكود في شاشة التحقق فقط.

## recovery — Account recovery / استعادة الحساب

Open Account recovery from Login and follow the verification path offered for your account.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student, parent, partner, employee, admin, university.
- Location: Login → Account recovery / شاشة الدخول ← استعادة الحساب.
- Navigation: Manual workflow in auth/account_recovery_screen.dart; no executable action.
- Sources: mobile:lib/screens/auth/account_recovery_screen.dart, mobile:lib/screens/auth/otp_and_password_reset_screens.dart, server:src/routes/authRoutes.js.
- Backend: server:src/routes/authRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open Account recovery from Login and follow the verification path offered for your account.
2. Enter recovery codes only in their dedicated screens. Contact support if verification fails; never share a secret here.

1. من شاشة الدخول افتح استعادة الحساب واتبع مسار التحقق المتاح لحسابك.
2. أدخل أكواد الاستعادة في الشاشات المخصصة فقط؛ عند تعذر التحقق استخدم الدعم ولا تشارك السر هنا.

## browser-login — Browser sign-in / الدخول بالمتصفح

When using browser sign-in, finish authentication in the opened page and return to the app.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student, parent, partner, employee, admin, university.
- Location: Login → Browser sign-in option / شاشة تسجيل الدخول ← خيار المتصفح.
- Navigation: Manual workflow in auth/browser_sign_in_screen.dart; no executable action.
- Sources: mobile:lib/screens/auth/browser_sign_in_screen.dart, mobile:lib/screens/auth/login_register_screens.dart, server:src/routes/authRoutes.js.
- Backend: server:src/routes/authRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. When using browser sign-in, finish authentication in the opened page and return to the app.
2. Provider availability depends on build configuration. Do not enter account credentials in this chat.

1. عند اختيار الدخول بالمتصفح، أكمل تسجيل الدخول في الصفحة المفتوحة ثم ارجع إلى التطبيق.
2. توفر مزود الدخول يعتمد على إعدادات النسخة؛ لا تدخل بيانات حسابك في هذه المحادثة.

## submit-application — Review and submit an application / مراجعة وإرسال طلب

Open program details and choose Apply to program.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: Program details → Apply to program / تفاصيل البرنامج ← التقديم على البرنامج.
- Navigation: Manual workflow in applications_documents_payments/program_application_screen.dart; no executable action.
- Sources: mobile:lib/screens/applications_documents_payments/program_application_screen.dart, mobile:lib/screens/universities_programs_countries/catalog_detail.dart, server:src/routes/applicationRoutes.js.
- Backend: server:src/routes/applicationRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open program details and choose Apply to program.
2. Check your information and the documents required for that specific program, then choose Review and submit.
3. Read the confirmation before sending it yourself; the assistant cannot submit it.

1. افتح تفاصيل البرنامج واختر التقديم على البرنامج.
2. راجع المعلومات والمستندات المطلوبة لهذا البرنامج تحديدًا، ثم اضغط مراجعة وإرسال الطلب.
3. اقرأ نافذة التأكيد قبل إرسال الطلب بنفسك؛ المساعد لا يرسله.

## application-documents — Complete application documents / استكمال مستندات الطلب

Open the application and choose Complete application documents or its Documents tab.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: My Applications → Application → Complete documents / طلباتي ← الطلب ← استكمال مستندات الطلب.
- Navigation: Manual workflow in applications_documents_payments/application_documents_screen.dart; no executable action.
- Sources: mobile:lib/screens/applications_documents_payments/application_documents_screen.dart, mobile:lib/screens/applications_documents_payments/applications_screens.dart, server:src/routes/studentRoutes.js.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open the application and choose Complete application documents or its Documents tab.
2. Reuse a suitable library document or upload a new version according to that application’s displayed requirements.

1. افتح الطلب ثم استكمال مستندات الطلب أو تبويب المستندات.
2. اختر مستندًا مناسبًا من مكتبتك أو ارفع نسخة جديدة وفق المتطلبات المعروضة لهذا الطلب.

## search — Global search / البحث العام

Open Search from Home and enter your query.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: Home → Search / الرئيسية ← البحث.
- Navigation: Manual workflow in home_journey/global_search_screen.dart; no executable action.
- Sources: mobile:lib/screens/home_journey/global_search_screen.dart, mobile:lib/screens/home_journey/home_dashboard_screen.dart, server:src/routes/studentRoutes.js.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open Search from Home and enter your query.
2. Open a relevant result; availability depends on catalog data and your account permissions.

1. افتح البحث من الرئيسية واكتب ما تبحث عنه.
2. افتح النتيجة المناسبة؛ ظهور النتائج يعتمد على بيانات المنصة وصلاحيات حسابك.

## community-posts — Posts and comments / المنشورات والتعليقات

Open Student Community and Posts to read discussions.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student.
- Location: Student Community → Posts / مجتمع الطلاب ← المنشورات.
- Navigation: Manual workflow in services_support/community_screen.dart; no executable action.
- Sources: mobile:lib/screens/services_support/community_screen.dart, mobile:lib/screens/community/student_community_hub.dart, mobile:lib/screens/community/student_public_profile.dart, server:src/routes/communityRoutes.js.
- Backend: server:src/routes/communityRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open Student Community and Posts to read discussions.
2. Open a post to reply or use Create post when offered, reviewing content before publishing.
3. A public student profile does not expose private account data or private viewer lists.

1. افتح مجتمع الطلاب ثم المنشورات لقراءة النقاشات.
2. افتح منشورًا للرد أو استخدم إنشاء منشور عندما يظهر لحسابك، وراجع المحتوى قبل النشر.
3. صفحة الطالب العامة لا تعرض بياناته الخاصة أو قائمة المشاهدات الخاصة به.

## alumni-directory — Alumni directory and profile / دليل الخريجين وملفي

Open Directory and my profile in Alumni network.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: Alumni network → Directory and my profile / شبكة الخريجين ← دليل الخريجين وملفي.
- Navigation: Manual workflow in services_support/alumni_directory_screen.dart; no executable action.
- Sources: mobile:lib/screens/services_support/alumni_directory_screen.dart, mobile:lib/screens/services_support/student_life_alumni_screens.dart, server:src/routes/alumniRoutes.js.
- Backend: server:src/routes/alumniRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open Directory and my profile in Alumni network.
2. Use search and the mentoring filter. Only published profiles appear; review your profile before publishing.

1. افتح دليل الخريجين وملفي من شبكة الخريجين.
2. استخدم البحث وفلتر المتاحين للإرشاد؛ لا تظهر سوى الملفات المنشورة. راجع بيانات ملفك قبل نشرها.

## student-listings — Student offers and opportunities / عروض وفرص الطلاب

Open Student listings and opportunities and choose the available list.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: Alumni network → Student listings and opportunities / شبكة الخريجين ← إعلانات وفرص الطلاب.
- Navigation: Manual workflow in services_support/student_listings_screen.dart; no executable action.
- Sources: mobile:lib/screens/services_support/student_listings_screen.dart, mobile:lib/screens/services_support/student_life_alumni_screens.dart, server:src/routes/studentRoutes.js.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open Student listings and opportunities and choose the available list.
2. Review conditions and expiry; do not assume an unlisted offer or job is available.

1. افتح إعلانات وفرص الطلاب واختر القائمة المعروضة.
2. راجع الشروط وموعد انتهاء الإعلان؛ لا تفترض توفر عرض أو وظيفة غير منشورة.

## live-consultation — Live consultation / الاستشارة المباشرة

Open an authorized booking that offers live consultation.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: Authorized booking → Live consultation / الحجز المصرّح ← الاستشارة المباشرة.
- Navigation: Manual workflow in services_support/live_consultation_screen.dart; no executable action.
- Sources: mobile:lib/screens/services_support/live_consultation_screen.dart, mobile:lib/screens/services_support/services_consultation_screens.dart, server:src/routes/consultationRoutes.js.
- Backend: server:src/routes/consultationRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open an authorized booking that offers live consultation.
2. Check permissions and connectivity and use only the room controls offered by your booking; the assistant cannot create or join meetings for you.

1. افتح حجز الاستشارة الذي يتيح لك الدخول إلى الاستشارة المباشرة.
2. تحقق من الأذونات والاتصال واتبع خيارات الغرفة التي يعرضها حجزك؛ لا يستطيع المساعد إنشاء اجتماع أو ضم شخص نيابة عنك.

## arrival-request — Arrival service request / طلب خدمات الوصول

Open Arrival services when offered in your application workflow.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: student.
- Location: Application workflow → Arrival services / مسار الطلب ← خدمات الوصول.
- Navigation: Manual workflow in visa_travel_accommodation/arrival_services_screen.dart; no executable action.
- Sources: mobile:lib/screens/visa_travel_accommodation/arrival_services_screen.dart, mobile:lib/screens/visa_travel_accommodation/accommodation_arrival_screens.dart, server:src/routes/studentRoutes.js.
- Backend: server:src/routes/studentRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open Arrival services when offered in your application workflow.
2. Review the service and required details before saving or submitting. Recorded status is the reference, not an assistant estimate.

1. افتح خدمات الوصول عندما تتاح في مسار طلبك.
2. راجع تفاصيل الخدمة والبيانات المطلوبة قبل حفظ أو إرسال طلبك. الحالات المسجلة هي المرجع وليس تقدير المساعد.

## admin-catalog — Catalog and content administration / إدارة الجامعات والبرامج والمحتوى

Open the authorized section visible in your administration dashboard.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: admin.
- Location: Staff/admin dashboard → Authorized section / لوحة الموظف / الإدارة ← القسم المصرّح.
- Navigation: Manual workflow in roles/admin_content_crud_screens.dart; no executable action.
- Sources: mobile:lib/screens/roles/admin_content_crud_screens.dart, mobile:lib/screens/roles/admin_simple_lists_screens.dart, mobile:lib/screens/roles/generic_crud_screen.dart, server:src/routes/adminRoutes.js.
- Backend: server:src/routes/adminRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open the authorized section visible in your administration dashboard.
2. Review its records and fields, then use only the available create/edit/review controls with required confirmation. The assistant never mutates records or bypasses access controls.

1. من لوحة الإدارة افتح القسم المصرّح الذي يظهر لحسابك.
2. راجع السجلات والحقول المعروضة، واستخدم أزرار الإضافة أو التعديل أو المراجعة المتاحة فقط بعد التأكيد المطلوب. لا ينفذ المساعد تغييرًا أو تجاوزًا للصلاحيات.

## admin-applications — Application and document administration / إدارة الطلبات والمستندات

Open the authorized section visible in your administration dashboard.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: admin.
- Location: Staff/admin dashboard → Authorized section / لوحة الموظف / الإدارة ← القسم المصرّح.
- Navigation: Manual workflow in roles/admin_applications_documents_screens.dart; no executable action.
- Sources: mobile:lib/screens/roles/admin_applications_documents_screens.dart, mobile:lib/screens/roles/admin_approval_screens.dart, mobile:lib/screens/roles/generic_approval_list_screen.dart, server:src/routes/adminRoutes.js.
- Backend: server:src/routes/adminRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open the authorized section visible in your administration dashboard.
2. Review its records and fields, then use only the available create/edit/review controls with required confirmation. The assistant never mutates records or bypasses access controls.

1. من لوحة الإدارة افتح القسم المصرّح الذي يظهر لحسابك.
2. راجع السجلات والحقول المعروضة، واستخدم أزرار الإضافة أو التعديل أو المراجعة المتاحة فقط بعد التأكيد المطلوب. لا ينفذ المساعد تغييرًا أو تجاوزًا للصلاحيات.

## admin-finance — Finance and marketing administration / الإدارة المالية والتسويق

Open the authorized section visible in your administration dashboard.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: admin.
- Location: Staff/admin dashboard → Authorized section / لوحة الموظف / الإدارة ← القسم المصرّح.
- Navigation: Manual workflow in roles/admin_financials_marketing_screens.dart; no executable action.
- Sources: mobile:lib/screens/roles/admin_financials_marketing_screens.dart, server:src/routes/crmFinanceRoutes.js.
- Backend: server:src/routes/crmFinanceRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open the authorized section visible in your administration dashboard.
2. Review its records and fields, then use only the available create/edit/review controls with required confirmation. The assistant never mutates records or bypasses access controls.

1. من لوحة الإدارة افتح القسم المصرّح الذي يظهر لحسابك.
2. راجع السجلات والحقول المعروضة، واستخدم أزرار الإضافة أو التعديل أو المراجعة المتاحة فقط بعد التأكيد المطلوب. لا ينفذ المساعد تغييرًا أو تجاوزًا للصلاحيات.

## admin-access — Users and access administration / إدارة المستخدمين والصلاحيات

Open the authorized section visible in your administration dashboard.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: admin.
- Location: Staff/admin dashboard → Authorized section / لوحة الموظف / الإدارة ← القسم المصرّح.
- Navigation: Manual workflow in roles/admin_users_access_screen.dart; no executable action.
- Sources: mobile:lib/screens/roles/admin_users_access_screen.dart, mobile:lib/screens/roles/admin_university_accounts_screen.dart, mobile:lib/screens/roles/admin_parent_links_screen.dart, server:src/routes/adminRoutes.js.
- Backend: server:src/routes/adminRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open the authorized section visible in your administration dashboard.
2. Review its records and fields, then use only the available create/edit/review controls with required confirmation. The assistant never mutates records or bypasses access controls.

1. من لوحة الإدارة افتح القسم المصرّح الذي يظهر لحسابك.
2. راجع السجلات والحقول المعروضة، واستخدم أزرار الإضافة أو التعديل أو المراجعة المتاحة فقط بعد التأكيد المطلوب. لا ينفذ المساعد تغييرًا أو تجاوزًا للصلاحيات.

## admin-support — Support and knowledge administration / إدارة الدعم والمعرفة

Open the authorized section visible in your administration dashboard.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: admin.
- Location: Staff/admin dashboard → Authorized section / لوحة الموظف / الإدارة ← القسم المصرّح.
- Navigation: Manual workflow in roles/admin_support_knowledge_screens.dart; no executable action.
- Sources: mobile:lib/screens/roles/admin_support_knowledge_screens.dart, server:src/routes/adminRoutes.js.
- Backend: server:src/routes/adminRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open the authorized section visible in your administration dashboard.
2. Review its records and fields, then use only the available create/edit/review controls with required confirmation. The assistant never mutates records or bypasses access controls.

1. من لوحة الإدارة افتح القسم المصرّح الذي يظهر لحسابك.
2. راجع السجلات والحقول المعروضة، واستخدم أزرار الإضافة أو التعديل أو المراجعة المتاحة فقط بعد التأكيد المطلوب. لا ينفذ المساعد تغييرًا أو تجاوزًا للصلاحيات.

## admin-settings — Site content and events administration / إدارة أقسام الموقع والفعاليات

Open the authorized section visible in your administration dashboard.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: admin.
- Location: Staff/admin dashboard → Authorized section / لوحة الموظف / الإدارة ← القسم المصرّح.
- Navigation: Manual workflow in roles/admin_singleton_hub_screens.dart; no executable action.
- Sources: mobile:lib/screens/roles/admin_singleton_hub_screens.dart, server:src/routes/adminRoutes.js.
- Backend: server:src/routes/adminRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open the authorized section visible in your administration dashboard.
2. Review its records and fields, then use only the available create/edit/review controls with required confirmation. The assistant never mutates records or bypasses access controls.

1. من لوحة الإدارة افتح القسم المصرّح الذي يظهر لحسابك.
2. راجع السجلات والحقول المعروضة، واستخدم أزرار الإضافة أو التعديل أو المراجعة المتاحة فقط بعد التأكيد المطلوب. لا ينفذ المساعد تغييرًا أو تجاوزًا للصلاحيات.

## admin-scholarships — Scholarship administration / إدارة المنح وطلبات المنح

Open the authorized section visible in your administration dashboard.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: admin.
- Location: Staff/admin dashboard → Authorized section / لوحة الموظف / الإدارة ← القسم المصرّح.
- Navigation: Manual workflow in roles/admin_scholarships_screen.dart; no executable action.
- Sources: mobile:lib/screens/roles/admin_scholarships_screen.dart, server:src/routes/scholarshipRoutes.js.
- Backend: server:src/routes/scholarshipRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open the authorized section visible in your administration dashboard.
2. Review its records and fields, then use only the available create/edit/review controls with required confirmation. The assistant never mutates records or bypasses access controls.

1. من لوحة الإدارة افتح القسم المصرّح الذي يظهر لحسابك.
2. راجع السجلات والحقول المعروضة، واستخدم أزرار الإضافة أو التعديل أو المراجعة المتاحة فقط بعد التأكيد المطلوب. لا ينفذ المساعد تغييرًا أو تجاوزًا للصلاحيات.

## admin-rewards — Reward rule administration / إدارة قواعد المكافآت

Open the authorized section visible in your administration dashboard.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: admin.
- Location: Staff/admin dashboard → Authorized section / لوحة الموظف / الإدارة ← القسم المصرّح.
- Navigation: Manual workflow in roles/admin_reward_rules_screen.dart; no executable action.
- Sources: mobile:lib/screens/roles/admin_reward_rules_screen.dart, server:src/routes/adminRoutes.js.
- Backend: server:src/routes/adminRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open the authorized section visible in your administration dashboard.
2. Review its records and fields, then use only the available create/edit/review controls with required confirmation. The assistant never mutates records or bypasses access controls.

1. من لوحة الإدارة افتح القسم المصرّح الذي يظهر لحسابك.
2. راجع السجلات والحقول المعروضة، واستخدم أزرار الإضافة أو التعديل أو المراجعة المتاحة فقط بعد التأكيد المطلوب. لا ينفذ المساعد تغييرًا أو تجاوزًا للصلاحيات.

## employee-workspace — Employee sections and follow-ups / أقسام ومتابعات الموظف

Open a section or follow-up list visible in the Employee dashboard.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: employee, admin.
- Location: Employee dashboard → Available section / لوحة الموظف ← القسم المتاح.
- Navigation: Manual workflow in roles/employee_extra_screens.dart; no executable action.
- Sources: mobile:lib/screens/roles/employee_extra_screens.dart, mobile:lib/screens/roles/employee_sections_picker_screen.dart, mobile:lib/screens/roles/follow_up_reminders_screen.dart, mobile:lib/screens/roles/employee_consultations_screen.dart, mobile:lib/screens/roles/employee_community_screen.dart, server:src/routes/crmRoutes.js.
- Backend: server:src/routes/crmRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Open a section or follow-up list visible in the Employee dashboard.
2. Review only your assigned students, messages, service requests or consultations. Hidden sections require an administrator to grant access.

1. افتح القسم أو قائمة المتابعات التي تظهر في لوحة الموظف.
2. راجع طلابك ورسائلك وطلبات الخدمات أو الاستشارات المعينة لك فقط. الأقسام المخفية تحتاج منح صلاحية من المدير.

## agent-students — Agent students pricing and commissions / ملف طالب الوكيل والأسعار والعمولات

Select one of your students in the Agent dashboard to open their file and application workflow.

- Availability: conditional (code verified; live prerequisites not tested).
- Roles: partner.
- Location: Agent dashboard → Student / My wallet / لوحة الوكيل ← الطالب / محفظتي.
- Navigation: Manual workflow in roles/agent_student_detail_screen.dart; no executable action.
- Sources: mobile:lib/screens/roles/agent_student_detail_screen.dart, mobile:lib/screens/roles/agent_program_pricing_screen.dart, mobile:lib/screens/roles/agent_dashboard_screen.dart, server:src/routes/partnerRoutes.js.
- Backend: server:src/routes/partnerRoutes.js.
- Restrictions: Use only options visible to your account; sensitive actions require confirmation and server authorization. / استخدم فقط الخيارات التي تظهر لحسابك؛ تأكيد الإجراءات الحساسة وصلاحيات السيرفر إلزاميان.

1. Select one of your students in the Agent dashboard to open their file and application workflow.
2. Review pricing and commissions allowed for the agent. Saving or editing happens only in the original authorized screen, never in chat.

1. اختر طالبًا تابعًا لك من لوحة الوكيل لعرض ملفه ومسار طلبه.
2. راجع الأسعار والعمولات المعروضة ضمن صلاحية الوكيل. أي حفظ أو تعديل يتم في الشاشة الأصلية وبصلاحيات السيرفر، وليس في المحادثة.

## assistant — Assistant capabilities / المساعد وإمكانياته

Verified Study Birds guidance only.

- Availability: available (code verified; live prerequisites not tested).
- Roles: student, parent, partner, employee, admin, university.
- Location: Assistant from main tabs or a screen help action / المساعد من التبويبات الرئيسية أو زر مساعدة الشاشة.
- Navigation: Manual workflow in ai/birds_ai_screen.dart; no executable action.
- Sources: mobile:lib/screens/ai/birds_ai_screen.dart, mobile:lib/screens/ai/assistant_help_button.dart, server:src/routes/assistantRoutes.js.
- Backend: server:src/routes/assistantRoutes.js.
- Restrictions: The current API has no conversation-deletion endpoint. Never send passwords or identity documents in chat. / لا يوجد حذف للمحادثات في API الحالي. لا ترسل كلمات المرور أو الهوية في الدردشة.

1. Ask about a screen or feature you want to use inside Study Birds.
2. I will not guess answers to general questions or unverified features. Your application statuses come only from your authorized account, and chat performs no sensitive actions.

1. اسأل عن الشاشة أو الميزة التي تريد استخدامها داخل Study Birds.
2. للأسئلة العامة أو ميزة غير موثقة لن أخمّن جوابًا. حالات طلباتك تأتي من حسابك المصرّح فقط، ولا تنفّذ المحادثة إجراءً حساسًا.

## Declarations without a direct topic-source binding

These are discovery results requiring further review, not advertised assistant capabilities.

- AccessDeniedScreen — mobile:lib/core/services/auth_session.dart
