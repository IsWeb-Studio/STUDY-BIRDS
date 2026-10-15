# Bird AI with Claude

Configure the API service's environment in Render:

- `AI_PROVIDER=anthropic`
- `ANTHROPIC_API_KEY`: a Claude API key, stored only as a server secret.
- `ANTHROPIC_MODEL=claude-haiku-5-5` (the default).
- `AI_DAILY_LIMIT`: optional; defaults to 20 requests per user per day, capped at 100.

Deploy the API service after changing its environment. Claude API billing must
have sufficient credits. An accepted key or an enabled assistant configuration
does not by itself confirm that paid generation is available.

Responses are capped at 800 output tokens. Existing authentication, per-user
thread ownership, conversation persistence, rate limits and read-only student
context apply to Claude as well. Provider errors are returned without raw
provider response bodies or credentials.

For the previous compatible provider, set `AI_PROVIDER=openai` and configure
`AI_API_KEY`, `AI_BASE_URL` (HTTPS) and `AI_MODEL`.
