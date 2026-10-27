(() => {
  'use strict';
  const policy = window.__inboxPolicy;
  if (!policy || window.__inboxGuardReady) return;
  const topFrame = window.top === window;
  let notifying = false;
  function block(reason = 'other', target = '') {
    if (notifying) return;
    notifying = true;
    if (topFrame) {
      window.webkit?.messageHandlers?.inboxGuard?.postMessage('blocked');
      // Diagnostic events contain fixed categories only; never URL parameters or form data.
      let route = 'unknown';
      try {
        const u = new URL(target || location.href, location.href);
        route = !['www.instagram.com','instagram.com'].includes(u.hostname) ? 'external' :
          u.pathname === '/' ? 'root' : u.pathname.startsWith('/accounts/') ? 'accounts' :
          u.pathname.startsWith('/challenge') ? 'challenge' :
          u.pathname.startsWith('/direct/') ? 'direct' :
          /^\/(reel|reels|explore|stories)(\/|$)/.test(u.pathname) ? 'content' : 'other-instagram';
      } catch {}
      window.webkit?.messageHandlers?.inboxDiagnostics?.postMessage({reason, route});
    }
    setTimeout(() => { notifying = false; }, 600);
  }
  function stop(event, target = '') {
    event.preventDefault();
    event.stopImmediatePropagation();
    block('click', target);
  }
  function checkLocation() {
    if (!policy.allows(location.href)) {
      if (document.documentElement) document.documentElement.style.visibility = 'hidden';
      block('location', location.href);
    }
  }
  // SPA navigation does not always invoke WKNavigationDelegate.
  for (const method of ['pushState', 'replaceState']) {
    const original = history[method].bind(history);
    history[method] = function (state, unused, url) {
      if (url != null && !policy.allows(String(url), location.href)) { block('history', String(url)); return; }
      const result = original(state, unused, url);
      checkLocation();
      return result;
    };
  }
  window.addEventListener('popstate', checkLocation);
  window.addEventListener('hashchange', checkLocation);
  window.addEventListener('pageshow', checkLocation);
  document.addEventListener('click', event => {
    const link = event.target.closest?.('a[href]');
    if (link && !policy.allows(link.href, location.href)) stop(event, link.href);
    else if (event.target.closest?.('[data-inbox-blocked]')) stop(event);
  }, true);
  // Do not intercept submit events before the site's framework handles them.
  // React can use a javascript: sentinel action while handling sign-in itself.
  // Cancelling at capture phase prevents that handler and can strand its spinner.
  // Actual document/form navigations remain checked by WKNavigationDelegate.
  document.addEventListener('contextmenu', event => {
    if (event.target.closest?.('a,video')) event.preventDefault();
  }, true);
  document.addEventListener('play', event => {
    if (event.target instanceof HTMLVideoElement) { event.target.pause(); block('video'); }
  }, true);
  // Stop script-triggered playback as well as taps and autoplay.
  const play = HTMLMediaElement.prototype.play;
  HTMLMediaElement.prototype.play = function () {
    if (this instanceof HTMLVideoElement) {
      this.pause();
      return Promise.reject(new DOMException('Video is disabled in Inbox', 'NotAllowedError'));
    }
    return play.apply(this, arguments);
  };
  const style = document.createElement('style');
  function filter() {
    if (!document.documentElement) return;
    const css = (policy.isAuthentication(location.href) ? 'video' : 'video,iframe') + '{display:none!important}' +
      ' [data-inbox-hidden-nav]{display:none!important}' +
      ' [data-inbox-blocked]{display:block!important;background:#000!important;background-image:none!important;color:transparent!important;border:0!important;border-radius:12px!important;padding:0!important;min-width:96px!important;min-height:112px!important;max-width:280px!important;overflow:hidden!important;text-decoration:none!important;}' +
      ' [data-inbox-blocked]:focus-visible{outline:2px solid #7b8cff!important;outline-offset:3px!important;}';
    if (style.textContent !== css) style.textContent = css;
    if (!style.isConnected) document.documentElement.appendChild(style);
    checkLocation();
    document.querySelectorAll('video').forEach(video => {
      video.pause();
      if (video.hasAttribute('autoplay')) video.removeAttribute('autoplay');
    });
    // Replace only explicit shared-media links, not whole conversation containers.
    document.querySelectorAll('a[href]').forEach(link => {
      if (link.hasAttribute('data-inbox-blocked')) return;
      let url;
      try { url = new URL(link.href, location.href); } catch { return; }
      if (['instagram.com', 'www.instagram.com'].includes(url.hostname) && /^\/reels?\/?$/.test(url.pathname)) {
        // The Reels navigation icon isn't a shared message. Avoid turning the
        // narrow sidebar into a tall media placeholder.
        if (!link.hasAttribute('data-inbox-hidden-nav')) link.setAttribute('data-inbox-hidden-nav', 'true');
        return;
      }
      if (['instagram.com', 'www.instagram.com'].includes(url.hostname) &&
          /^\/(reels?|p|stories|tv)(\/|$)/.test(url.pathname)) {
        link.setAttribute('data-inbox-blocked', 'true');
        link.replaceChildren();
        link.removeAttribute('title');
        link.setAttribute('aria-label', 'Shared content blocked. Return to inbox');
      }
    });
  }
  let queued = false;
  new MutationObserver(() => {
    if (queued) return;
    queued = true;
    queueMicrotask(() => { queued = false; filter(); });
  }).observe(document, { childList: true, subtree: true, attributes: true, attributeFilter: ['href', 'src', 'autoplay'] });
  document.addEventListener('DOMContentLoaded', filter, { once: true });
  filter();
  // Backup for unexpected client-side navigation; not a substitute for native policy.
  setInterval(checkLocation, 400);
  window.__inboxGuardReady = true;
})();
