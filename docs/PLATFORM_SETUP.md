# Study Birds

Study Birds is a full-stack MERN study abroad platform with original branding, a student application flow, and an admin operations dashboard.

Deployment guide: see `DEPLOYMENT.md` (same folder).
Render-only deployment is supported with `render.yaml` for both frontend and backend services.

## Stack

- Frontend: React, TypeScript, Vite, Tailwind CSS, React Router, Axios, React Hook Form, Zod, Lucide React, Framer Motion
- Backend: Node.js, Express, MongoDB, Mongoose, JWT, bcrypt, Multer, dotenv, cors

## Structure

```text
study-birds/ (see the root README for the current layout)
  client/
  server/
```

## Server setup

1. `cd server`
2. `copy .env.example .env`
3. Update `MONGODB_URI` and `JWT_SECRET`
4. Optional: add `GOOGLE_CLIENT_ID` to enable Sign in with Google
5. Add `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET` for persistent file uploads
6. `npm install`
7. `npm run seed`
8. `npm run dev`

### MongoDB Atlas

- Use a `mongodb+srv://...` connection string in `MONGODB_URI`
- Example:

```env
MONGODB_URI=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/study-birds?retryWrites=true&w=majority
```

- In MongoDB Atlas, allow the server IP in Network Access
- If your database password contains special characters, URL-encode it before placing it in `MONGODB_URI`
- Seed your Atlas database once with `npm run seed` after updating `server/.env`

Seeded accounts:

- Admin: `admin@studybirds.net` / `Admin123!`
- Student: `ava@student.com` / `Student123!`
- Student: `noah@student.com` / `Student123!`
- Student: `sara@student.com` / `Student123!`
- Partner: `partner@studybirds.net` / `Partner123!`

## Client setup

1. `cd client`
2. `npm install`
3. Optional: create `.env` with:
   - `VITE_API_URL=http://localhost:5000/api`
   - `VITE_GOOGLE_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com`
   - `NEXT_PUBLIC_SITE_URL=https://studybirds.net`
   - `VITE_SITE_URL=https://studybirds.net`
4. `npm run dev`

## Core features

- JWT authentication with role-based route protection
- Student profile management
- Program search and filtering
- Online application submission
- Persistent image and document uploads via Cloudinary
- In-app assistant guidance without external AI provider setup
- Admin stats and application management
- Seed data for countries, universities, programs, testimonials, and users

## Deployment env vars

Server:

- `MONGODB_URI`: MongoDB Atlas connection string
- `JWT_SECRET`: production secret
- `CLIENT_URL`: main frontend URL
- `CLIENT_URLS`: optional comma-separated list of allowed frontend URLs
- `SITE_URL`: canonical public site URL for SEO, sitemap, and robots generation
- `GOOGLE_CLIENT_ID`: optional if using Google sign-in
- `UPLOAD_DIR`: optional writable uploads path on the host
- `CLOUDINARY_CLOUD_NAME`: Cloudinary cloud name for persistent uploads
- `CLOUDINARY_API_KEY`: Cloudinary API key
- `CLOUDINARY_API_SECRET`: Cloudinary API secret

Client:

- `VITE_API_URL`: deployed backend API URL, for example `https://api.example.com/api`
- `VITE_GOOGLE_CLIENT_ID`: optional if using Google sign-in
- `NEXT_PUBLIC_SITE_URL`: official public site URL for SEO metadata on Vercel or compatible hosts
- `VITE_SITE_URL`: deployed frontend URL, for example `https://studybirds.net`
- `VITE_CONTACT_EMAIL`: public support email shown in the footer and contact page
- `VITE_WHATSAPP_URL`: WhatsApp chat link
- `VITE_FACEBOOK_URL`: Facebook page link
- `VITE_INSTAGRAM_URL`: Instagram profile link
- `VITE_TIKTOK_URL`: TikTok profile link

## Deployment note

- MongoDB Atlas solves the database hosting part only
- Uploaded files should use Cloudinary in production so they persist across deploys and server restarts

## Verification checklist

- `npm install` should work in both `client` and `server`
- Backend should run on `http://localhost:5000`
- Frontend should run on `http://localhost:5173`
- Run seed before first login to populate demo data
