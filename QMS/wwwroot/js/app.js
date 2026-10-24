/* Har page ka common hissa: login check, menu (permission ke hisaab se), dukaan ka naam/logo, messages. */
(function (global, $) {
  'use strict';

  /* Naya page banay to yahan ek line barhayein. permission na likhein to sab ko dikhega. */
  var MENU = [
    { key: 'dashboard',    text: 'Dashboard',    href: '/index.html' },
    { key: 'shop-profile', text: 'Shop Profile', href: '/shop-profile.html', permission: 'Settings.Edit' },
    { key: 'change-password', text: 'Password badlein', href: '/change-password.html' }
  ];

  function hasPermission(code) {
    var u = Api.user();
    return !!u && Array.isArray(u.permissions) && u.permissions.indexOf(code) !== -1;
  }

  function notify(message, type) {
    var $box = $('#toastBox');
    if (!$box.length) $box = $('<div id="toastBox" class="toast-container position-fixed top-0 end-0 p-3"></div>').appendTo('body');
    var $t = $('<div class="toast align-items-center border-0" role="alert"><div class="d-flex">' +
               '<div class="toast-body"></div>' +
               '<button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Band"></button>' +
               '</div></div>').addClass('text-bg-' + (type || 'success'));
    $t.find('.toast-body').text(message);
    $box.append($t);
    $t.on('hidden.bs.toast', function () { $t.remove(); });
    new bootstrap.Toast($t[0], { delay: 4500 }).show();
  }

  /* Page ka title: "<Page> - <Dukaan ka naam>" */
  function renderLayout(activeKey, pageTitle) {
    var u = Api.user();
    var $nav = $(
      '<nav class="navbar navbar-expand-md navbar-dark bg-primary">' +
      '<div class="container-fluid">' +
      '<a class="navbar-brand d-flex align-items-center gap-2" href="/index.html">' +
      '<img id="navLogo" class="nav-logo d-none" alt=""><span id="navShop"></span></a>' +
      '<button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navMenu" aria-controls="navMenu" aria-expanded="false" aria-label="Menu"><span class="navbar-toggler-icon"></span></button>' +
      '<div class="collapse navbar-collapse" id="navMenu">' +
      '<ul class="navbar-nav me-auto" id="navItems"></ul>' +
      '<span class="navbar-text me-3" id="navUser"></span>' +
      '<button class="btn btn-outline-light btn-sm" id="logoutBtn" type="button">Logout</button>' +
      '</div></div></nav>');

    MENU.filter(function (m) { return !m.permission || hasPermission(m.permission); })
        .forEach(function (m) {
          var $a = $('<a class="nav-link"></a>').attr('href', m.href).text(m.text);
          if (m.key === activeKey) $a.addClass('active');
          $('<li class="nav-item"></li>').append($a).appendTo($nav.find('#navItems'));
        });

    $nav.find('#navUser').text(u ? u.fullName : '');
    $nav.find('#logoutBtn').on('click', function () { Api.logout(); });
    $('#appNav').replaceWith($nav);

    $.getJSON('/api/shop-profile/public').done(function (p) {
      $('#navShop').text(p.shopName);
      if (p.logoPath) $('#navLogo').attr('src', p.logoPath).removeClass('d-none');
      document.title = (pageTitle ? pageTitle + ' - ' : '') + p.shopName;
    });
  }

  /* Page ke shuru mein:
       App.init('dashboard', 'Dashboard').then(function (user) { ...page ka kaam... });
     Login na ho to login page par bhej deta hai; permission na ho to dashboard par. */
  function init(activeKey, pageTitle, permission) {
    var never = new Promise(function () {});   // page ka baqi script na chale
    return Api.me().then(function () {
      if (permission && !hasPermission(permission)) { location.replace('/index.html'); return never; }
      renderLayout(activeKey, pageTitle);
      return Api.user();
    }).catch(function (xhr) {
      if (xhr && xhr.status !== 401) notify(Api.errorMessage(xhr), 'danger');
      return never;
    });
  }

  global.App = { init: init, hasPermission: hasPermission, notify: notify };
})(window, jQuery);
