// ===== Hamburger Menu Toggle =====
document.addEventListener('DOMContentLoaded', function () {
  var hamburger = document.getElementById('hamburger-btn');
  var nav = document.querySelector('.header-nav');
  if (!hamburger || !nav) return;

  // Hamburger toggle
  hamburger.addEventListener('click', function () {
    hamburger.classList.toggle('active');
    nav.classList.toggle('open');
  });

  // Close hamburger menu when a direct nav-link is clicked (not dropdown toggle)
  nav.querySelectorAll('a.nav-link').forEach(function (link) {
    link.addEventListener('click', function () {
      hamburger.classList.remove('active');
      nav.classList.remove('open');
    });
  });

  // Close hamburger menu when clicking outside
  document.addEventListener('click', function (e) {
    if (!hamburger.contains(e.target) && !nav.contains(e.target)) {
      hamburger.classList.remove('active');
      nav.classList.remove('open');
    }
  });

  // ===== Category Dropdown Toggle =====
  var dropdowns = document.querySelectorAll('.nav-dropdown');
  dropdowns.forEach(function (dropdown) {
    var toggle = dropdown.querySelector('.nav-dropdown-toggle');
    if (!toggle) return;

    toggle.addEventListener('click', function (e) {
      e.preventDefault();
      e.stopPropagation();
      // Close other dropdowns
      dropdowns.forEach(function (d) {
        if (d !== dropdown) d.classList.remove('open');
      });
      dropdown.classList.toggle('open');
    });
  });

  // Close dropdown when clicking outside
  document.addEventListener('click', function (e) {
    dropdowns.forEach(function (dropdown) {
      if (!dropdown.contains(e.target)) {
        dropdown.classList.remove('open');
      }
    });
  });

  // Close dropdown menu items click (navigate)
  document.querySelectorAll('.nav-dropdown-menu a').forEach(function (link) {
    link.addEventListener('click', function () {
      hamburger.classList.remove('active');
      nav.classList.remove('open');
    });
  });

  // ===== Search Overlay Toggle =====
  var searchBtn = document.querySelector('.header-search');
  var searchOverlay = document.getElementById('searchOverlay');
  var searchClose = document.getElementById('searchClose');
  var searchInput = document.querySelector('.search-input');

  if (searchBtn && searchOverlay) {
    searchBtn.addEventListener('click', function () {
      searchOverlay.classList.add('open');
      setTimeout(function () {
        if (searchInput) searchInput.focus();
      }, 100);
    });

    if (searchClose) {
      searchClose.addEventListener('click', function () {
        searchOverlay.classList.remove('open');
      });
    }

    searchOverlay.addEventListener('click', function (e) {
      if (e.target === searchOverlay) {
        searchOverlay.classList.remove('open');
      }
    });

    // ESC key to close
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && searchOverlay.classList.contains('open')) {
        searchOverlay.classList.remove('open');
      }
    });
  }

  // Handle search form submission
  var searchForm = document.getElementById('searchForm');
  if (searchForm) {
    searchForm.addEventListener('submit', function (e) {
      e.preventDefault();
      var q = searchInput.value.trim();
      if (q) {
        // 現在の階層に合わせて遷移先を調整
        var currentPath = window.location.pathname;
        var newsPath = currentPath.includes('/news/') || currentPath.includes('/about/') ? '../news/index.html' : 'news/index.html';
        window.location.href = newsPath + '?q=' + encodeURIComponent(q);
      }
    });
  }
});
