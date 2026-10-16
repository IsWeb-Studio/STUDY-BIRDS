const { test } = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const path = require("node:path");
const mongoose = require("mongoose");
const { encodeCBOR } = require("@levischuck/tiny-cbor");
const { MongoMemoryServer } = require(
  process.env.STUDY_BIRDS_TEST_TOOLS
    ? path.join(
        process.env.STUDY_BIRDS_TEST_TOOLS,
        "node_modules/mongodb-memory-server-core",
      )
    : "mongodb-memory-server-core",
);

test("identity: signed passkeys, Apple nonce, SMS ownership, scholarship workflow", async () => {
  process.env.JWT_SECRET = "isolated-identity-test";
  process.env.WEBAUTHN_RP_ID = "localhost";
  process.env.WEBAUTHN_ORIGINS = "http://localhost:4173";
  process.env.APPLE_CLIENT_ID = "test.apple.service";
  process.env.APPLE_REDIRECT_URI = "https://example.test/login";
  process.env.TWILIO_ACCOUNT_SID = "test";
  process.env.TWILIO_AUTH_TOKEN = "test";
  process.env.TWILIO_VERIFY_SERVICE_SID = "test";
  const originalFetch = global.fetch;
  let mongo,
    server,
    smsCalls = 0;
  try {
    mongo = await MongoMemoryServer.create({ instance: { ip: "127.0.0.1" } });
    await mongoose.connect(mongo.getUri());
    const jose = await import("jose");
    const appleKey = await jose.generateKeyPair("RS256");
    const jwk = await jose.exportJWK(appleKey.publicKey);
    jwk.kid = "test-key";
    global.fetch = async (input, init) => {
      const url = String(input);
      if (url === "https://appleid.apple.com/auth/keys")
        return new Response(JSON.stringify({ keys: [jwk] }), {
          headers: { "Content-Type": "application/json" },
        });
      if (url.startsWith("https://verify.twilio.com/")) {
        smsCalls++;
        const values = new URLSearchParams(init.body);
        if (url.endsWith("VerificationCheck"))
          return new Response(
            JSON.stringify({
              status: values.get("Code") === "123456" ? "approved" : "pending",
            }),
          );
        return new Response(JSON.stringify({ sid: "VE-test" }));
      }
      return originalFetch(input, init);
    };
    const mailer = require("../src/utils/mailer");
    const emails = [];
    mailer.isMailerConfigured = () => true;
    mailer.sendContactEmail = async (mail) => emails.push(mail);
    const sms = require('../src/utils/cashMisrSms');
    sms.ready = () => true;
    sms.generate = () => '123456';
    sms.send = async () => { smsCalls++; };
    const app = require("../src/app");
    const User = require("../src/models/User");
    const {
      Challenge,
      Credential,
    } = require("../src/models/IdentityCredential");
    await Promise.all(
      Object.values(mongoose.models).map((model) => model.init()),
    );
    server = await new Promise((resolve) => {
      const s = app.listen(0, "127.0.0.1", () => resolve(s));
    });
    const origin = `http://127.0.0.1:${server.address().port}/api`;
    const call = async (method, route, token, body, status = 200) => {
      const response = await fetch(origin + route, {
        method,
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: body ? JSON.stringify(body) : undefined,
      });
      const data = await response.json();
      assert.equal(
        response.status,
        status,
        route + ": " + JSON.stringify(data),
      );
      return data;
    };
    const a = await call(
      "POST",
      "/auth/register",
      null,
      { name: "A", email: "a@example.test", password: "TestPassword123!" },
      201,
    );
    const b = await call(
      "POST",
      "/auth/register",
      null,
      { name: "B", email: "b@example.test", password: "TestPassword123!" },
      201,
    );
    await call(
      "POST",
      "/identity/passkeys/register/options",
      a.token,
      { currentPassword: "wrong" },
      401,
    );
    const registration = await call(
      "POST",
      "/identity/passkeys/register/options",
      a.token,
      { currentPassword: "TestPassword123!" },
    );
    const pair = crypto.generateKeyPairSync("ec", { namedCurve: "prime256v1" });
    const publicJwk = pair.publicKey.export({ format: "jwk" });
    const cose = Buffer.from(
      encodeCBOR(
        new Map([
          [1, 2],
          [3, -7],
          [-1, 1],
          [-2, new Uint8Array(Buffer.from(publicJwk.x, "base64url"))],
          [-3, new Uint8Array(Buffer.from(publicJwk.y, "base64url"))],
        ]),
      ),
    );
    const id = crypto.randomBytes(32),
      idString = id.toString("base64url");
    const size = Buffer.alloc(2);
    size.writeUInt16BE(id.length);
    const hash = (data) => crypto.createHash("sha256").update(data).digest();
    const clientData = Buffer.from(
      JSON.stringify({
        type: "webauthn.create",
        challenge: registration.options.challenge,
        origin: "http://localhost:4173",
      }),
    );
    const authData = Buffer.concat([
      hash("localhost"),
      Buffer.from([0x45]),
      Buffer.alloc(4),
      Buffer.alloc(16),
      size,
      id,
      cose,
    ]);
    const response = {
      id: idString,
      rawId: idString,
      type: "public-key",
      clientExtensionResults: {},
      response: {
        clientDataJSON: clientData.toString("base64url"),
        attestationObject: Buffer.from(
          encodeCBOR(
            new Map([
              ["fmt", "none"],
              ["attStmt", new Map()],
              ["authData", new Uint8Array(authData)],
            ]),
          ),
        ).toString("base64url"),
        transports: ["internal"],
      },
    };
    await call(
      "POST",
      "/identity/passkeys/register/verify",
      b.token,
      { challengeId: registration.challengeId, response },
      400,
    );
    await call(
      "POST",
      "/identity/passkeys/register/verify",
      a.token,
      { challengeId: registration.challengeId, response },
      201,
    );
    await call(
      "POST",
      "/identity/passkeys/register/verify",
      a.token,
      { challengeId: registration.challengeId, response },
      400,
    );
    const login = await call(
      "POST",
      "/identity/passkeys/login/options",
      null,
      {},
    );
    const data = Buffer.from(
      JSON.stringify({
        type: "webauthn.get",
        challenge: login.options.challenge,
        origin: "http://localhost:4173",
      }),
    );
    const counter = Buffer.alloc(4);
    counter.writeUInt32BE(1);
    const assertionData = Buffer.concat([
      hash("localhost"),
      Buffer.from([5]),
      counter,
    ]);
    const assertion = {
      id: idString,
      rawId: idString,
      type: "public-key",
      clientExtensionResults: {},
      response: {
        clientDataJSON: data.toString("base64url"),
        authenticatorData: assertionData.toString("base64url"),
        signature: crypto
          .sign(
            "sha256",
            Buffer.concat([assertionData, hash(data)]),
            pair.privateKey,
          )
          .toString("base64url"),
        userHandle: Buffer.from(a.user._id).toString("base64url"),
      },
    };
    assert.ok(
      (
        await call("POST", "/identity/passkeys/login/verify", null, {
          challengeId: login.challengeId,
          response: assertion,
        })
      ).token,
    );
    await call(
      "POST",
      "/identity/passkeys/login/verify",
      null,
      { challengeId: login.challengeId, response: assertion },
      400,
    );
    const keys = await call("GET", "/identity/passkeys", a.token);
    await call(
      "DELETE",
      `/identity/passkeys/${keys[0]._id}`,
      b.token,
      undefined,
      404,
    );
    await call(
      "POST",
      "/identity/phone/request",
      a.token,
      { phone: "bad" },
      400,
    );
    await call("POST", "/identity/phone/request", a.token, {
      phone: "+905551234567",
    });
    await call(
      "POST",
      "/identity/phone/request",
      a.token,
      { phone: "+905551234567" },
      429,
    );
    await call(
      "POST",
      "/identity/phone/confirm",
      b.token,
      { code: "123456" },
      400,
    );
    await call(
      "POST",
      "/identity/phone/confirm",
      a.token,
      { code: "000000" },
      400,
    );
    assert.equal(
      (
        await call("POST", "/identity/phone/confirm", a.token, {
          code: "123456",
        })
      ).verifiedPhone,
      "+905551234567",
    );
    await call(
      "POST",
      "/identity/phone/confirm",
      a.token,
      { code: "123456" },
      400,
    );
    assert.equal(smsCalls, 1);
    process.env.CLIENT_URL = "https://example.test";
    const verifier = crypto.randomBytes(32).toString("base64url");
    const handoff = await call("POST", "/identity/mobile/start", null, {
      challenge: hash(verifier).toString("base64url"),
    });
    assert.ok(handoff.url.startsWith("https://example.test/mobile-sign-in?"));
    await call(
      "POST",
      "/identity/mobile/exchange",
      null,
      { challengeId: handoff.challengeId, verifier },
      202,
    );
    await call("POST", "/identity/mobile/approve", a.token, {
      challengeId: handoff.challengeId,
    });
    await call(
      "POST",
      "/identity/mobile/exchange",
      null,
      {
        challengeId: handoff.challengeId,
        verifier: crypto.randomBytes(32).toString("base64url"),
      },
      400,
    );
    const mobile = await call("POST", "/identity/mobile/exchange", null, {
      challengeId: handoff.challengeId,
      verifier,
    });
    assert.equal(mobile.user._id, a.user._id);
    await call(
      "POST",
      "/identity/mobile/exchange",
      null,
      { challengeId: handoff.challengeId, verifier },
      400,
    );
    const apple = await call("POST", "/identity/apple/options", null, {});
    const identityToken = await new jose.SignJWT({
      nonce: apple.nonce,
      email: "apple@example.test",
      email_verified: true,
    })
      .setProtectedHeader({ alg: "RS256", kid: "test-key" })
      .setIssuer("https://appleid.apple.com")
      .setAudience(process.env.APPLE_CLIENT_ID)
      .setSubject("apple-test-subject")
      .setIssuedAt()
      .setExpirationTime("5m")
      .sign(appleKey.privateKey);
    const appleLogin = await call("POST", "/identity/apple/verify", null, {
      challengeId: apple.state,
      identityToken,
    });
    assert.equal(appleLogin.user.authProvider, "apple");
    await call(
      "POST",
      "/identity/apple/verify",
      null,
      { challengeId: apple.state, identityToken },
      400,
    );
    const other = await call("POST", "/identity/apple/options", null, {});
    await call(
      "POST",
      "/identity/apple/verify",
      null,
      { challengeId: other.state, identityToken },
      401,
    );
    await call("POST", "/scholarships", a.token, { title: "Not allowed" }, 403);
    await User.updateOne({ _id: b.user._id }, { $set: { role: "admin" } });
    const grant = await call(
      "POST",
      "/scholarships",
      b.token,
      { title: "Real grant", active: true },
      201,
    );
    assert.equal((await call("GET", "/scholarships")).length, 1);
    const entry = await call(
      "POST",
      `/scholarships/${grant._id}/apply`,
      a.token,
      {},
    );
    assert.equal(
      (await call("POST", `/scholarships/${grant._id}/apply`, a.token, {}))._id,
      entry._id,
    );
    await call(
      "PATCH",
      `/scholarships/${entry._id}/status`,
      a.token,
      { status: "accepted" },
      403,
    );
    await call("PATCH", `/scholarships/${entry._id}/status`, b.token, {
      status: "accepted",
    });
    assert.equal(
      (await call("GET", "/scholarships/mine", a.token))[0].status,
      "accepted",
    );
  } finally {
    global.fetch = originalFetch;
    if (server) await new Promise((resolve) => server.close(resolve));
    await mongoose.disconnect();
    if (mongo) await mongo.stop();
  }
});
