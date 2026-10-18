# Financial write safety

Wallet redemptions, staff wallet adjustments, referral credits and Stripe receipt processing require MongoDB replica-set or sharded-cluster transactions. Standalone MongoDB returns 503 for financial mutations; there is no non-transactional fallback. Read-only financial views remain available.

## Deployment

- Use a MongoDB replica set (including a single-node replica set for local development), or Atlas. Verify transaction support before releasing the change.
- No balance-table migration is required. Balances still come from StudentWalletEntry, aggregated as integer cents. Invalid sub-cent legacy entries or balances outside the safe integer range fail closed for financial reconciliation.
- Ensure the new models/indexes are initialized before accepting production traffic: FinancialLock, FinancialOutbox, StripePaymentReceipt and the unique partial operationKey index on StudentWalletEntry. Existing ledger rows without operationKey remain compatible.
- The code was tested using isolated MongoDB. No deployment, production balance modification, provider payment or production reconciliation was performed.

## Wallet transactions

Every writer first updates a persistent FinancialLock row inside its transaction. This serializes reads/writes for the same wallet across server instances without expiring leases. The debit and invoice credit commit together. Ambiguous commits are handled by the MongoDB driver's transaction machinery; the application never deletes a debit to compensate for a failed acknowledgement.

Amounts use validated minor units. Send a stable Idempotency-Key when retrying wallet redemptions or manual adjustments. Reusing a key with different financial data is rejected; omitting it means a new requested operation. Store and replay this key across network retries in integrations.

## Referrals and notifications

Referral qualification, its unique operation-keyed reward and the notification outbox row commit together. Every successful application can retry qualification safely. The server's financial scheduler retries pending notices and repairs referrals that have an application but no reward entry, including legacy qualified rows. Repairs use the currently configured STUDENT_REFERRAL_REWARD_AMOUNT. Review historical reward-policy changes before deployment if older rewards need a different rate. Notifications have deterministic IDs to prevent duplication.

## Stripe

Checkout first persists a reservation, exact parameters and an idempotency key in a transaction. The API call runs outside the transaction, uses that key, and retries the same parameters. A lost provider response does not create a new payment attempt. Unknown attempts older than 23 hours are held for reconciliation instead of reusing a potentially pruned Stripe idempotency key.

An outstanding card attempt blocks wallet redemption and invoice editing/deletion, even after its local expiry timestamp. The owner can POST /api/payments/stripe/cancel-checkout with invoiceId. The server checks/requests expiration at Stripe before releasing the reservation. A paid/completed or uncertain attempt is never released using the clock alone. If checkout creation lost its response, retry checkout to recover the session identity before cancellation.

The webhook verifies the signature over the original raw body and checks the timestamp. A durable receipt keyed by Stripe Checkout Session ID is inserted in the same transaction as payment application. Duplicate deliveries are safe. Amount, currency, owner, session identity and the current financial snapshot must agree before an invoice becomes paid. Old or mismatched payments are recorded as reconciliation items without falsely settling the invoice.

Authorized finance staff can GET /api/admin/student-financials/stripe-receipts to see reconciliation receipts; CRM invoice reconciliation also includes stripePayments. Reconciliation records preserve collected funds for an explicit finance decision; they do not automatically apply mismatched funds or issue refunds. Do not manually clear a reservation while its Stripe status is uncertain.

## Verification

Set STUDY_BIRDS_TEST_TOOLS to the tooling directory that contains mongodb-memory-server-core. From the repository root:

```powershell
node --test server/tests/financialSecurity.test.js server/tests/studentWallet.test.js server/tests/concurrencyFixes.test.js server/tests/crmFinancePolicy.test.js server/tests/crmIntegration.test.js
```

Tests cover actual pauses beyond the previous lease lifetime, competing debits, lost write and commit acknowledgements, idempotent financial retries, referral recovery, outbox recovery, stable Stripe creation keys, stale payment snapshots, signature rejection, duplicate delivery, confirmed expiration and standalone fail-closed behavior.
