(function (root) {
  'use strict';
  function allows(raw, base = 'https://www.instagram.com/direct/inbox/') {
    try {
      const u = new URL(raw, base);
      if (u.protocol !== 'https:' || !['instagram.com', 'www.instagram.com'].includes(u.hostname) ||
          u.port || u.username || u.password) return false;
      const p = decodeURIComponent(u.pathname);
      if (p.includes('%') || p.includes('\\') || p.split('/').includes('..')) return false;
      return [/^\/direct\/inbox\/?$/, /^\/direct\/new\/?$/, /^\/direct\/t\/[A-Za-z0-9_-]+\/?$/,
        /^\/accounts\/login\/?$/, /^\/accounts\/login\/two_factor\/?$/,
        /^\/accounts\/onetap\/?$/,
        /^\/auth_platform\/?$/,
        /^\/auth_platform\/(?:recaptcha|codeentry)\/?$/,
        /^\/challenge(?:\/[A-Za-z0-9_-]+)*\/?$/].some(re => re.test(p));
    } catch { return false; }
  }
  function isAuthentication(raw, base) {
    if (!allows(raw, base)) return false;
    const p = new URL(raw, base || 'https://www.instagram.com/direct/inbox/').pathname;
    return /^\/(accounts|challenge|auth_platform)(\/|$)/.test(p);
  }
  const policy = Object.freeze({ allows, isAuthentication, inbox: 'https://www.instagram.com/direct/inbox/' });
  if (typeof module !== 'undefined' && module.exports) module.exports = policy;
  else Object.defineProperty(root, '__inboxPolicy', { value: policy, configurable: false });
})(globalThis);
