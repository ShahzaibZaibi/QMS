/* Ek hi $.ajax wrapper. Login cookie browser khud bhejta hai, token ka koi intezam nahi.
   401 aaye to seedha login page par. */
(function (global, $) {
  'use strict';

  var currentUser = null;

  function toLogin() { location.replace('/login.html'); }

  function request(method, url, data, isForm) {
    return new Promise(function (resolve, reject) {
      var opts = { url: url, method: method };
      if (isForm) {
        opts.data = data; opts.processData = false; opts.contentType = false;
      } else if (data !== undefined && data !== null) {
        if (method === 'GET') { opts.data = data; }
        else { opts.data = JSON.stringify(data); opts.contentType = 'application/json'; }
      }
      $.ajax(opts)
        .done(function (result) { resolve(result); })
        .fail(function (xhr) {
          if (xhr.status === 401) toLogin();
          reject(xhr);
        });
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

    /* Login hai to user + permissions (taza, server se), warna login page */
    me: function () {
      return request('GET', '/api/auth/me').then(function (u) { currentUser = u; return u; });
    },
    user: function () { return currentUser; },

    /* Login 401 par redirect nahi karta (ghalat password normal baat hai) */
    login: function (username, password) {
      return new Promise(function (resolve, reject) {
        $.ajax({
          url: '/api/auth/login', method: 'POST', contentType: 'application/json',
          data: JSON.stringify({ username: username, password: password })
        }).done(function (u) { currentUser = u; resolve(u); })
          .fail(function (xhr) { reject(xhr); });
      });
    },

    logout: function () {
      $.ajax({ url: '/api/auth/logout', method: 'POST' }).always(toLogin);
    }
  };
})(window, jQuery);
