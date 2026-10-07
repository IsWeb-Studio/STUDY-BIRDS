/**
 * k6 load test for Study Birds API
 * Run: k6 run k6_load_test.js
 * Docs: https://k6.io/docs/
 *
 * Required env vars:
 *   BASE_URL   — e.g. https://study-birds1.onrender.com/api
 *   STUDENT_TOKEN — valid student JWT
 *   ADMIN_TOKEN   — valid admin JWT
 */

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const BASE_URL   = __ENV.BASE_URL   || 'https://study-birds1.onrender.com/api';
const STUDENT_TOK = __ENV.STUDENT_TOKEN || '';
const ADMIN_TOK   = __ENV.ADMIN_TOKEN   || '';

const errorRate  = new Rate('errors');
const p95Latency = new Trend('p95_latency', true);

export const options = {
  stages: [
    { duration: '30s', target: 10 },   // ramp-up
    { duration: '1m',  target: 50 },   // sustained load
    { duration: '30s', target: 100 },  // peak
    { duration: '30s', target: 0 },    // ramp-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<3000'],  // 95% of requests under 3s
    errors:            ['rate<0.05'],   // error rate below 5%
  },
};

function studentHeaders() {
  return { Authorization: `Bearer ${STUDENT_TOK}`, 'Content-Type': 'application/json' };
}
function adminHeaders() {
  return { Authorization: `Bearer ${ADMIN_TOK}`, 'Content-Type': 'application/json' };
}

function checkOk(res, name) {
  const ok = check(res, {
    [`${name} status 2xx`]: (r) => r.status >= 200 && r.status < 300,
  });
  errorRate.add(!ok);
  p95Latency.add(res.timings.duration);
}

export default function () {
  // ── Health ────────────────────────────────────────────────────────────────
  group('health', () => {
    const res = http.get(`${BASE_URL}/health`);
    checkOk(res, 'health');
  });

  sleep(0.5);

  // ── Student — public endpoints ────────────────────────────────────────────
  group('student-public', () => {
    let res = http.get(`${BASE_URL}/universities?limit=10`);
    checkOk(res, 'universities list');

    res = http.get(`${BASE_URL}/programs?limit=10`);
    checkOk(res, 'programs list');

    res = http.get(`${BASE_URL}/scholarships?limit=10`);
    checkOk(res, 'scholarships list');
  });

  sleep(0.5);

  // ── Student — authenticated ───────────────────────────────────────────────
  if (STUDENT_TOK) {
    group('student-auth', () => {
      let res = http.get(`${BASE_URL}/students/overview`, { headers: studentHeaders() });
      checkOk(res, 'student overview');

      res = http.get(`${BASE_URL}/students/applications`, { headers: studentHeaders() });
      checkOk(res, 'student applications');

      res = http.get(`${BASE_URL}/students/financials`, { headers: studentHeaders() });
      checkOk(res, 'student financials');

      res = http.get(`${BASE_URL}/service-requests`, { headers: studentHeaders() });
      checkOk(res, 'service requests');

      res = http.get(`${BASE_URL}/alumni/jobs`, { headers: studentHeaders() });
      checkOk(res, 'alumni jobs');
    });
  }

  sleep(0.5);

  // ── Messaging ─────────────────────────────────────────────────────────────
  if (STUDENT_TOK) {
    group('messaging', () => {
      const res = http.get(`${BASE_URL}/mobile-workspace/contacts`, { headers: studentHeaders() });
      checkOk(res, 'contacts');
    });
  }

  sleep(0.5);

  // ── Admin — unified search ────────────────────────────────────────────────
  if (ADMIN_TOK) {
    group('admin-search', () => {
      const res = http.get(`${BASE_URL}/admin/search?q=test`, { headers: adminHeaders() });
      checkOk(res, 'unified search');
    });
  }

  sleep(1);
}
