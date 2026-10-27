const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const policy = require('../InstagramInbox/Resources/navigation-policy.js');
const cases = require('./navigation-cases.json');
for (const c of cases) assert.equal(policy.allows(c.url), c.allowed, c.url);
assert.equal(policy.allows('/reel/abc/'), false);
assert.equal(policy.allows('/direct/t/123/'), true);
console.log(`PASS: ${cases.length} URL cases and relative links`);

// Exercise the actual injected guard in an isolated browser-like environment.
// This verifies event wiring and policy decisions, not real WebKit/Instagram behavior.
const handlers = {}, documentHandlers = {}, events = [], originalNavigations = [];
class Media { play() { return Promise.resolve(); } }
class Video extends Media { pause() {} }
const context = {
  URL, DOMException, Promise, HTMLMediaElement: Media, HTMLVideoElement: Video,
  location: { href: policy.inbox },
  history: Object.fromEntries(['pushState','replaceState'].map(method => [method, (...args) => originalNavigations.push([method,...args])])),
  document: {
    documentElement: { style: {}, appendChild(el) { el.isConnected = true; } },
    createElement() { return { isConnected: false }; },
    querySelectorAll() { return []; },
    addEventListener(name, fn) { documentHandlers[name] = fn; }
  },
  MutationObserver: class { observe() {} }, queueMicrotask,
  setInterval() {}, setTimeout(fn) { fn(); },
  addEventListener(name, fn) { handlers[name] = fn; },
  webkit: { messageHandlers: { inboxGuard: { postMessage(message) { events.push(message); } } } }
};
context.window = context; context.top = context;
vm.createContext(context);
for (const file of ['navigation-policy.js','inbox-guard.js']) {
  vm.runInContext(fs.readFileSync(path.join(__dirname,'../InstagramInbox/Resources',file),'utf8'),context);
}
assert.equal(context.__inboxGuardReady, true);
assert.equal(documentHandlers.submit, undefined, 'Framework sign-in handlers must receive submit events; native navigation guards enforce destinations');
context.history.pushState({}, '', '/reel/blocked/');
assert.equal(originalNavigations.length, 0);
assert.equal(events.at(-1), 'blocked');
context.history.pushState({}, '', '/direct/t/123/');
assert.equal(originalNavigations.length, 1);
context.history.replaceState({}, '', '/explore/');
assert.equal(originalNavigations.length, 1);
let cancelled = false;
documentHandlers.click({target: {closest: () => ({href:'https://example.com/video'})}, preventDefault(){cancelled=true;},stopImmediatePropagation(){}});
assert.equal(cancelled,true);
context.location.href = 'https://www.instagram.com/reels/';
handlers.popstate();
assert.equal(context.document.documentElement.style.visibility, 'hidden');
new Video().play().then(() => { throw new Error('Video playback allowed'); }, error => {
  assert.equal(error.name, 'NotAllowedError');
  console.log('PASS: SPA navigation, external click, history change, and video-play guards');
});
