# Study Birds

منصة دراسة بالخارج: **سيرفر (Backend)** + **تطبيق جوال (Flutter)** + **موقع ويب**.
A study-abroad platform: backend API, mobile app and website in one repository.

## هيكل المستودع / Layout

```text
.
├── server/    Backend: Node.js + Express + MongoDB (API)          ← يُنشر على Render (study-birds-api)
├── app/       Flutter mobile app (Android / iOS)
├── client/    Website: React + Vite (static site)                  ← يُنشر على Render (study-birds-web)
├── docs/      Feature guides, deployment and setup notes
├── load-test/ k6 load-test script for the API
├── render.yaml  Render blueprint (points at server/ and client/)
└── .github/workflows/  CI (server, app, web)
```

> `client/` يبقى في مكانه لأن `render.yaml` ينشر الموقع منه (`rootDir: client`).
> نقله أو حذفه يوقف الموقع المنشور.

## التشغيل السريع / Quick start

### 1) السيرفر — `server/`
```bash
cd server
cp .env.example .env        # ثم املأ MONGODB_URI و JWT_SECRET (لا ترفع .env إلى Git)
npm install
npm run seed                # بيانات تجريبية (مرة واحدة)
npm run dev                 # http://localhost:5000
```
تفاصيل الإعداد (Atlas، Cloudinary، البريد…): [`docs/PLATFORM_SETUP.md`](docs/PLATFORM_SETUP.md) و[`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).

### 2) التطبيق — `app/`
يتطلب Flutter **3.41.9**.
```bash
cd app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api   # محاكي Android مع السيرفر المحلي
```
الإصدار الرسمي: `flutter build apk --release --dart-define=API_BASE_URL=https://<API_HOST>/api`.
أعلام البناء الاختيارية: `API_PINNING=false` (إيقاف تثبيت الشهادات)، `SENTRY_ENABLED=true`، `ENABLE_EN=true`.
المزيد: [`app/README.md`](app/README.md).

### 3) الموقع — `client/`
```bash
cd client
npm install
npm run dev                 # http://localhost:5173
```

## الاختبارات / Tests

| المكوّن | الأمر |
|---|---|
| App | `cd app && flutter analyze && flutter test` |
| Server | `cd server && node --test tests/idempotency.test.js` (باقي الاختبارات تحتاج MongoDB مؤقتة: `mongodb-memory-server-core`) |
| Website | `cd client && npx tsc -b && npm test && npx vite build` |

يعمل CI تلقائيًا عند كل تغيير: [`app-ci.yml`](.github/workflows/app-ci.yml) و[`web-ci.yml`](.github/workflows/web-ci.yml) و[`ci.yml`](.github/workflows/ci.yml) (السيرفر). بناء APK يدوي عبر [`app-build.yml`](.github/workflows/app-build.yml).

## الأسرار / Secrets

- لا ترفع `.env` أو مفاتيح API أو ملفات `*.jks`/`*.keystore`/`key.properties` إلى Git — مستثناة في `.gitignore`.
- القوالب فقط: `server/.env.example` و`client/.env.example`.
- متغيرات Render (MongoDB، JWT، Brevo، Cloudinary…) تُضبط من لوحة Render لا من الكود.
- نقطتان جديدتان تُفعَّلان بمتغيرات على السيرفر (اختيارية): `APP_MIN_VERSION_ANDROID` / `APP_MIN_VERSION_IOS` / `APP_STORE_URL_*` للتحديث الإجباري للتطبيق.

## الأدلة / Docs

[`docs/`](docs/): الإعداد والنشر (`PLATFORM_SETUP`, `DEPLOYMENT`)، الهوية (`IDENTITY_SETUP`)، الإشعارات (`PUSH_NOTIFICATIONS`)، المحفظة (`STUDENT_WALLET`)، الاستشارات (`CONSULTATION_BOOKING`)، التوزيع التلقائي (`AUTOMATIC_ASSIGNMENT`)، التخزين الخاص للمستندات (`PRIVATE_DOCUMENT_STORAGE`)، وغيرها.
وثائق تدقيق التطبيق: [`app/docs/`](app/docs/).
