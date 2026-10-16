const http = require('node:http');
const https = require('node:https');
const tls = require('node:tls');
const local = host => ['localhost', '127.0.0.1', '::1', '[::1]'].includes(String(host).split(':')[0]) || host === '::1';
const fetchOriginal = global.fetch;
global.fetch = (input, init) => {
  const url = new URL(typeof input === 'string' || input instanceof URL ? input : input.url);
  if (!local(url.hostname)) throw new Error('AUDIT: blocked external request to ' + url.hostname);
  return fetchOriginal(input, init);
};
for (const module of [http, https]) {
 const original = module.request;
 module.request = function(input, ...args) {
  const options = typeof input === 'string' || input instanceof URL ? new URL(input) : input || {};
  const host = options.hostname || options.host || 'localhost';
  if (!local(host)) throw new Error('AUDIT: blocked external HTTP request to ' + host);
  return original.call(this, input, ...args);
 };
}
const tlsOriginal = tls.connect;
tls.connect = function(...args) {
 const options = args.find(a => a && typeof a === 'object' && !Buffer.isBuffer(a)) || {};
 const host = options.host || options.servername || (typeof args[1] === 'string' ? args[1] : 'localhost');
 if (!local(host)) throw new Error('AUDIT: blocked external TLS request to ' + host);
 return tlsOriginal.apply(this, args);
};
