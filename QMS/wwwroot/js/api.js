/* Ek hi $.ajax wrapper: token lagata hai, 401 par ek martaba refresh try karta hai, phir login par bhejta hai. */
(function (global, $) {
  'use strict';

  var KEYS = { access: 'qms.access', refresh: 'qms.refresh', user: 'qms.user' };
  var refreshing = null;

  var store = {
    access: function () { return localStorage.getItem(KEYS.access); },
    refresh: function () { return localStorage.getItem(KEYS.refresh); },
    user: function () {
      try { return JSON.parse(localStorage.getItem(KEYS.user)); } catch (e) { return null; }
    },
    save: function (r) {
      localStorage.setItem(KEYS.access, r.accessToken);
      localStorage.setItem(KEYS.refresh, r.refreshToken);
      localStorage.setItem(KEYS.user, JSON.stringify(r.user));
    },
    clear: function () {
      localStorage.removeItem(KEYS.access);
      localStorage.removeItem(KEYS.refresh);
      localStorage.removeItem(KEYS.user);
    }
  };

  function toLogin() {
    store.clear();
    location.replace('/login.html');
  }

  function doRefresh() {
    if (!store.refresh()) return $.Deferred().reject().promise();
    if (!refreshing) {
      refreshing = $.ajax({
        url: '/api/auth/refresh', method: 'POST', contentType: 'application/json',
        data: JSON.stringify({ refreshToken: store.refresh() })
      }).done(function (r) { store.save(r); })
        .always(function () { refreshing = null; });
    }
    return refreshing;
  }

  function request(method, url, data, isForm) {
    return new Promise(function (resolve, reject) {
      function send(canRetry) {
        var opts = { url: url, method: method, headers: {} };
        if (store.access()) opts.headers.Authorization = 'Bearer ' + store.access();
        if (isForm) {
          opts.data = data; opts.processData = false; opts.contentType = false;
        } else if (data !== undefined && data !== null) {
          if (method === 'GET') { opts.data = data; }
          else { opts.data = JSON.stringify(data); opts.contentType = 'application/json'; }
        }
        $.ajax(opts)
          .done(function (result) { resolve(result); })
          .fail(function (xhr) {
            if (xhr.status === 401) {
              if (canRetry && store.refresh()) {
                doRefresh().done(function () { send(false); })
                           .fail(function () { toLogin(); reject(xhr); });
              } else { toLogin(); reject(xhr); }
            } else { reject(xhr); }
          });
      }
      send(true);
    });
  }

  /* Server ka saaf message nikalta hai (SP ki ghalti, validation, ya generic) */
  function errorMessage(xhr) {
    if (!xhr || xhr.status === 0) return 'Server se rabta nahi ho raha. Internet/LAN check karein.';
    var j = xhr.responseJSON;
    if (j) {
      if (j.message) return j.message;
      if (j.errors) {
        var first = Object.keys(j.errors)[0];
        if (first) return j.errors[first][0];
      }
      if (j.title) return j.title;
    }
    if (xhr.status === 403) return 'Aap ko is kaam ki ijazat nahi.';
    if (xhr.status === 429) return 'Bohat zyada koshishein. Thori der baad try karein.';
    return 'Kuch masla aa gaya, dobara koshish karein.';
  }

  global.Api = {
    get: function (url, data) { return request('GET', url, data); },
    post: function (url, data) { return request('POST', url, data); },
    put: function (url, data) { return request('PUT', url, data); },
    del: function (url) { return request('DELETE', url); },
    upload: function (url, formData) { return request('POST', url, formData, true); },
    errorMessage: errorMessage,
    isLoggedIn: function () { return !!store.access() && !!store.user(); },
    user: function () { return store.user(); },

    /* Login 401 par redirect nahi karta (ghalat password normal baat hai) */
    login: function (username, password) {
      return new Promise(function (resolve, reject) {
        $.ajax({
          url: '/api/auth/login', method: 'POST', contentType: 'application/json',
          data: JSON.stringify({ username: username, password: password })
        }).done(function (r) { store.save(r); resolve(r); })
          .fail(function (xhr) { reject(xhr); });
      });
    },

    logout: function () {
      var token = store.refresh();
      var done = function () { toLogin(); };
      if (!token) { done(); return; }
      $.ajax({
        url: '/api/auth/logout', method: 'POST', contentType: 'application/json',
        data: JSON.stringify({ refreshToken: token })
      }).always(done);
    }
  };
})(window, jQuery);
