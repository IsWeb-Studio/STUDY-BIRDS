# Permanent backend authentication

The CRM can use a dedicated random credential instead of an expiring website
login JWT. This changes authentication only; it does not enable synchronization,
bypass backup gates, or change any database records. Existing JWT clients keep
working unchanged.

After deploying this version of the website backend, identify the existing website
admin account used for the integration. Never create or elevate an account
automatically. Generate the values locally, with its MongoDB user ID:

```powershell
node server/scripts/create-crm-service-credential.cjs --user-id <24-character-admin-id> --output D:\private\crm-credential.json
```

The output directory must already exist, be private, and be outside the repository.
The script refuses to overwrite a file or print credentials. On Windows, protect
the directory using its Windows access permissions (POSIX mode alone is insufficient).

In Render service **STUDY-BIRDS1**, copy the three values under `website` into
Environment. Only the SHA-256 hash is stored on the website server. In Render
service **CRM-Study-birds**, replace `STUDY_BIRDS_API_TOKEN` with the raw credential
under `crm`. Save and deploy both services. Do not place the raw credential in
frontend/VITE variables, browser storage, Git, screenshots, or chat.

The existing CRM gateway already sends this value as a backend Bearer credential;
no CRM application change is needed. The website resolves the configured account
on every request, requires an active admin, and retains existing route permissions.
The credential cannot call login or mobile session/security endpoints and rejects
browser client headers. It can call the administrative API families used by the
CRM, including GET `/api/auth/me` for the connection check.

Verify the CRM integration connection check and a normal authorized read after
deployment. Do not test writes on production records. The credential has no
automatic expiry. To revoke it, set `CRM_SERVICE_AUTH_ENABLED=false` or remove the
hash and deploy the website service. To rotate, generate a new private file and
replace the website hash and CRM token together; the old token stops working.
Disabling/demoting the linked user also stops access. User login JWTs, password
expiry and tokenVersion changes are separate from service credential revocation.

Keep the private output securely only while applying the configuration, then remove
it or store it in an approved secret manager. This credential grants the linked
admin's access, so use a dedicated existing integration admin where available.
