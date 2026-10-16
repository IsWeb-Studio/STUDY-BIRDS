# Birds AI — Gemini provider

Birds AI uses the existing authenticated `/api/assistant` endpoints. Gemini is
called by the backend; the mobile app and its APK contain no provider key.

Server configuration:

- `AI_PROVIDER=gemini`
- `GEMINI_MODEL=gemini-3.5-flash-lite`
- `GEMINI_API_KEY`: configure privately in Render, never in this repository.

`gemini-provider.patch` backs up the matching backend implementation and tests
from the Study Birds monorepo. It preserves student context, conversation history,
ownership checks, daily quotas and existing response shapes. Thought parts are
excluded from student replies. Provider failures do not expose provider bodies or
credentials.

Apply the patch from the monorepo root if restoring this integration. Existing
mobile installations use the new provider after the backend deployment; no APK
update is required solely for switching the AI provider.
