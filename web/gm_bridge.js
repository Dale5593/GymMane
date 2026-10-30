// GymMane web bridge: small browser helpers the Flutter app calls through
// dart:js_interop (see lib/platform/*_web.dart).
(function () {
  'use strict';

  // ---- File store (IndexedDB) -------------------------------------------
  var DB_NAME = 'gymmane-files';
  var STORE = 'files';
  var dbPromise = null;

  function db() {
    if (!dbPromise) {
      dbPromise = new Promise(function (resolve, reject) {
        var req = indexedDB.open(DB_NAME, 1);
        req.onupgradeneeded = function () { req.result.createObjectStore(STORE); };
        req.onsuccess = function () { resolve(req.result); };
        req.onerror = function () { reject(req.error); };
      });
    }
    return dbPromise;
  }

  window.gmVfsLoadAll = function () {
    return db().then(function (d) {
      return new Promise(function (resolve, reject) {
        var out = [];
        var req = d.transaction(STORE, 'readonly').objectStore(STORE).openCursor();
        req.onsuccess = function () {
          var c = req.result;
          if (!c) { resolve(out); return; }
          out.push(String(c.key));
          var v = c.value;
          out.push(v instanceof Uint8Array ? v : new Uint8Array(v));
          c.continue();
        };
        req.onerror = function () { reject(req.error); };
      });
    }).catch(function (e) { console.warn('GymMane file store unavailable', e); return []; });
  };

  function tx(mode, fn) {
    return db().then(function (d) {
      return new Promise(function (resolve, reject) {
        var t = d.transaction(STORE, mode);
        fn(t.objectStore(STORE));
        t.oncomplete = function () { resolve(null); };
        t.onerror = function () { reject(t.error); };
        t.onabort = function () { reject(t.error); };
      });
    });
  }

  window.gmVfsPut = function (path, bytes) {
    // Store a standalone ArrayBuffer copy (most reliable in Safari).
    var copy = bytes.slice().buffer;
    return tx('readwrite', function (s) { s.put(copy, path); });
  };

  window.gmVfsDelete = function (path) {
    return tx('readwrite', function (s) { s.delete(path); });
  };

  window.gmFetchBytes = function (url) {
    return fetch(url).then(function (r) { return r.arrayBuffer(); })
      .then(function (b) { return new Uint8Array(b); });
  };

  window.gmBlobUrl = function (bytes, mime) {
    return URL.createObjectURL(new Blob([bytes], { type: mime }));
  };

  // Ask the browser not to evict our data.
  try { if (navigator.storage && navigator.storage.persist) navigator.storage.persist(); } catch (e) {}

  // ---- Safe-area insets ---------------------------------------------------
  var probe = null;
  window.gmSafeInsets = function () {
    if (!probe) {
      probe = document.createElement('div');
      probe.style.cssText = 'position:fixed;top:0;left:0;width:0;height:0;visibility:hidden;pointer-events:none;' +
        'padding-top:env(safe-area-inset-top);padding-right:env(safe-area-inset-right);' +
        'padding-bottom:env(safe-area-inset-bottom);padding-left:env(safe-area-inset-left);';
      document.documentElement.appendChild(probe);
    }
    var cs = getComputedStyle(probe);
    return [cs.paddingTop, cs.paddingRight, cs.paddingBottom, cs.paddingLeft].map(function (v) {
      return parseFloat(v) || 0;
    });
  };

  // ---- Keep screen on (Wake Lock) ----------------------------------------
  var lock = null;
  var wantLock = false;
  function acquire() {
    if (!wantLock || lock || !('wakeLock' in navigator)) return;
    navigator.wakeLock.request('screen').then(function (l) {
      lock = l;
      l.addEventListener('release', function () { lock = null; });
    }).catch(function () {});
  }
  window.gmKeepAwake = function (on) {
    wantLock = !!on;
    if (wantLock) acquire();
    else if (lock) { lock.release().catch(function () {}); lock = null; }
  };
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible') acquire();
  });

  // ---- Sounds (Web Audio, unlocked on first touch) ------------------------
  var ctx = null;
  var buffers = {};
  function audio() {
    if (!ctx) {
      var C = window.AudioContext || window.webkitAudioContext;
      if (C) ctx = new C();
    }
    return ctx;
  }
  function unlock() {
    var c = audio();
    if (!c || c.state === 'running') return;
    c.resume().catch(function () {});
    try {
      var s = c.createBufferSource();
      s.buffer = c.createBuffer(1, 1, 22050);
      s.connect(c.destination);
      s.start(0);
    } catch (e) {}
  }
  ['touchend', 'pointerup', 'mouseup', 'keydown'].forEach(function (ev) {
    window.addEventListener(ev, unlock, { capture: true, passive: true });
  });

  function decode(c, bytes) {
    var buf = bytes.slice().buffer;
    return new Promise(function (resolve, reject) {
      var p = c.decodeAudioData(buf, resolve, reject);
      if (p && p.then) p.then(resolve, reject);
    });
  }

  window.gmPlaySound = function (key, bytes, volume) {
    var c = audio();
    if (!c) return Promise.resolve(null);
    var ready = buffers[key]
      ? Promise.resolve(buffers[key])
      : (bytes ? decode(c, bytes).then(function (b) { buffers[key] = b; return b; }) : Promise.resolve(null));
    return ready.then(function (buf) {
      if (!buf) return null;
      if (c.state !== 'running') c.resume().catch(function () {});
      var src = c.createBufferSource();
      src.buffer = buf;
      var gain = c.createGain();
      gain.gain.value = volume == null ? 1 : volume;
      src.connect(gain);
      gain.connect(c.destination);
      src.start(0);
      return null;
    }).catch(function () { return null; });
  };

  window.gmAudioDuration = function (bytes) {
    var c = audio();
    if (!c) return Promise.resolve(null);
    return decode(c, bytes).then(function (b) { return b.duration; }).catch(function () { return null; });
  };

  // ---- Share / save files --------------------------------------------------
  function download(file) {
    var url = URL.createObjectURL(file);
    var a = document.createElement('a');
    a.href = url;
    a.download = file.name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 60000);
  }

  // iOS only opens the share sheet straight from a tap. When the file took a
  // moment to build, offer a button so the tap is fresh.
  function shareWithButton(data, file) {
    return new Promise(function (resolve) {
      var wrap = document.createElement('div');
      wrap.className = 'gm-share';
      wrap.innerHTML =
        '<div class="gm-share-card">' +
        '<div class="gm-share-name"></div>' +
        '<button class="gm-share-go" type="button">Share</button>' +
        '<button class="gm-share-save" type="button">Save to Files</button>' +
        '<button class="gm-share-cancel" type="button">Cancel</button>' +
        '</div>';
      wrap.querySelector('.gm-share-name').textContent = file.name;
      function close() { wrap.remove(); resolve(null); }
      wrap.querySelector('.gm-share-go').onclick = function () {
        navigator.share(data).catch(function () {}).then(close);
      };
      wrap.querySelector('.gm-share-save').onclick = function () { download(file); close(); };
      wrap.querySelector('.gm-share-cancel').onclick = close;
      wrap.addEventListener('click', function (e) { if (e.target === wrap) close(); });
      document.body.appendChild(wrap);
    });
  }

  window.gmShareFile = function (bytes, name, mime, title) {
    var file = new File([bytes], name, { type: mime });
    var data = { files: [file] };
    if (title) data.title = title;
    var can = false;
    try { can = !!(navigator.canShare && navigator.canShare({ files: [file] })); } catch (e) {}
    if (!can) { download(file); return Promise.resolve(null); }
    return navigator.share(data).then(function () { return null; }, function (e) {
      if (e && e.name === 'AbortError') return null;
      return shareWithButton(data, file);
    });
  };
})();
