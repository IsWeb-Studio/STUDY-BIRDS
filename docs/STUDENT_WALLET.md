# Student referrals and wallet — 23 September 2026

Local implementation; no production data touched, no deployment.

## Implemented

- Every student gets a unique referral code, lazily generated on first read (`GET /api/students/wallet`) and returned with a ready-to-share link (`/register?ref=CODE`).
- Registering with `?ref=CODE` records a **pending** referral. It only becomes **qualified**, and only then rewards the referrer with wallet credit (`STUDENT_REFERRAL_REWARD_AMOUNT`, default 15), when the referred person submits their **first real application** — not at signup, and never more than once per referred person.
- `StudentWalletEntry` is an append-only ledger (`referral-reward` / `redemption` / `adjustment`); balance is the live sum, not a cached counter, so it can't drift out of sync.
- Students can spend their balance against their own unpaid invoices (`POST /api/students/wallet/redeem`), partially or fully; a fully-covered invoice is marked paid automatically. This is an internal credit ledger only — it does not touch the existing manual bank-transfer/payment-proof flow, which is unchanged.
- Staff with the existing `student-financials` permission can view the full transaction log and record manual adjustments (bonuses/corrections) with a required reason, at `/admin/wallet`. Students manage their own referral code and balance at `/student/wallet`.

## Deployment dependencies

None required to activate — this ships enabled by default, using the same MongoDB the rest of the app already uses. Optionally set `STUDENT_REFERRAL_REWARD_AMOUNT` to change the reward from its default of 15.

## Tests and limits

`server/tests/studentWallet.test.js` covers: code reuse across repeated reads, a pending referral that only qualifies after a real first application (not at signup), no double-reward on a second application, self-referral and invalid-code signups being silently ignored, partial and full invoice redemption (including auto-marking an invoice paid), rejecting redemption beyond the wallet balance or beyond what's still owed, and the `student-financials` permission gate on staff adjustments including the negative-balance guard.

This is **not** the full PRD scope for items 52–57: no discount/commission tiers, no student-facing leaderboard, no student community or alumni network, and redemption only applies to invoices (not yet to the consultation, housing, or other service requests added this cycle). Referral rewards are a fixed flat amount, not configurable per campaign.
