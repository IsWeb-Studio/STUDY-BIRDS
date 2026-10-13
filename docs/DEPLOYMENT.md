# Deployment Guide

This repository is prepared for:

- `client/` on Render Static Site
- `server/` on Render Web Service
- MongoDB on Atlas

## Frontend on Render

Official reference:

- Static Sites: https://render.com/docs/static-sites/
- Blueprint spec: https://render.com/docs/blueprint-spec
- Create React App routing rewrite guidance: https://render.com/docs/deploy-create-react-app

Project settings:

- Service type: `Static Site`
- Root directory: `client`
- Build command: `npm install && npm run build`
- Publish directory: `dist`

Environment variables:

- `VITE_API_URL=https://your-render-service.onrender.com/api`
- `NEXT_PUBLIC_SITE_URL=https://studybirds.net`
- `VITE_SITE_URL=https://studybirds.net`
- `VITE_GOOGLE_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com`

Notes:

- `render.yaml` already defines a catch-all rewrite from `/*` to `/index.html` for React Router deep links.
- The frontend is set up as the `study-birds-web` static site inside the shared Blueprint.

## Backend on Render

Official reference:

- Blueprint spec: https://render.com/docs/blueprint-spec
- Persistent disks: https://render.com/docs/disks

Project settings:

- Service type: `Web Service`
- Root directory: `server`
- Build command: `npm install`
- Start command: `npm start`
- Health check path: `/api/health`

This repo includes `render.yaml` for a Render Blueprint.

Important:

- The Blueprint uses `plan: starter` because the app stores uploaded files locally and attaches a persistent disk.
- Render's filesystem is ephemeral without a disk, so uploads would be lost on redeploy if you switch to `free`.

Environment variables to provide:

- `MONGODB_URI`
  Use your MongoDB Atlas connection string.
- `JWT_SECRET`
  A strong production secret. The Blueprint can generate one automatically.
- `CLIENT_URL`
  Your main Render frontend URL.
- `CLIENT_URLS`
  Optional comma-separated allowed origins if you use multiple frontend URLs.
- `SITE_URL`
  Canonical public site URL used for SEO tags, sitemap, and robots output.
- `GOOGLE_CLIENT_ID`
  Optional if you use Google sign-in.
- `UPLOAD_DIR`
  Already configured in the Blueprint as `/opt/render/project/src/uploads`.

## Recommended Order

1. Deploy the Blueprint on Render from this repository.
2. Wait for Render to create both services:
   - `study-birds-web`
   - `study-birds-api`
3. Open the backend URL and confirm `/api/health` is healthy.
4. Copy the public Render backend URL into `VITE_API_URL` on the static site.
5. Copy the public Render frontend URL into `CLIENT_URL` on the web service.
6. If you use more than one frontend hostname, add them to `CLIENT_URLS`.
7. If Google sign-in is enabled, add both Render URLs to your Google OAuth allowed origins.
8. Redeploy both services after setting the final env vars.

## Example Production Values

Frontend:

```env
VITE_API_URL=https://study-birds-api.onrender.com/api
NEXT_PUBLIC_SITE_URL=https://studybirds.net
VITE_SITE_URL=https://studybirds.net
VITE_GOOGLE_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
```

Backend:

```env
MONGODB_URI=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/study-birds?retryWrites=true&w=majority
JWT_SECRET=change-me
JWT_EXPIRES_IN=7d
CLIENT_URL=https://study-birds-web.onrender.com
CLIENT_URLS=https://study-birds-web.onrender.com,https://studybirds.net,https://www.studybirds.net
SITE_URL=https://studybirds.net
GOOGLE_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
UPLOAD_DIR=/opt/render/project/src/uploads
```

## Render-Only Notes

- This setup keeps the database on Atlas, but both app services on Render.
- The frontend does not need Vercel in this configuration.
- The backend keeps a persistent disk for `uploads`, so it should stay on a paid Render plan.
