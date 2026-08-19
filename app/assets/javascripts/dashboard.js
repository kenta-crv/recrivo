//= require turbo
//= require rails-ujs
//= require activestorage
//= require meetia_page_init
//= require db_v2_pricing_slider

/* Dashboard-only UI. Loaded by dashboard layouts — NOT mixed into LP application.js */
(function(window, document) {
  'use strict';

  function onReady(fn) {
    if (window.MeetiaPageInit && typeof window.MeetiaPageInit.onPageReady === 'function') {
      window.MeetiaPageInit.onPageReady(fn);
      return;
    }
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', fn);
    } else {
      fn();
    }
    document.addEventListener('turbo:load', fn);
    document.addEventListener('turbolinks:load', fn);
  }

  function clickEl(e) {
    var t = e && e.target;
    if (!t) return null;
    if (t.nodeType !== 1) t = t.parentElement;
    while (t && typeof t.closest !== 'function') t = t.parentElement;
    return t || null;
  }

// ログインドロップダウン（Turbo未ロードでも動くよう onPageReady）
function initLoginDropdown() {
  var toggleBtn = document.querySelector('[data-toggle-login]');
  if (!toggleBtn || toggleBtn.getAttribute('data-login-bound') === 'true') return;
  toggleBtn.setAttribute('data-login-bound', 'true');

  var menu = toggleBtn.parentElement && toggleBtn.parentElement.querySelector('.dropdown-menu-login');
  if (!menu) return;

  toggleBtn.addEventListener('click', function(e) {
    e.stopPropagation();
    var isOpen = menu.style.display === 'block';
    menu.style.display = isOpen ? 'none' : 'block';
  });

  document.addEventListener('click', function() {
    menu.style.display = 'none';
  });

  menu.addEventListener('click', function(e) {
    e.stopPropagation();
  });
}

var MEETIA_DASHBOARD_THEME_KEY = 'meetia-dashboard-theme';

function getDashboardTheme() {
  try {
    var stored = localStorage.getItem(MEETIA_DASHBOARD_THEME_KEY);
    return stored === 'dark' ? 'dark' : 'light';
  } catch (e) {
    return 'light';
  }
}

function dashboardThemeBackground(theme) {
  var teal = document.documentElement.getAttribute('data-dashboard-palette') === 'teal';
  if (theme === 'light') return teal ? '#f1f5f9' : '#ffffff';
  return teal ? '#0f172a' : '#0a0a12';
}

function applyDashboardTheme(theme) {
  if (typeof window.applyMeetiaDashboardTheme === 'function') {
    window.applyMeetiaDashboardTheme(theme);
    return;
  }
  var nextTheme = theme === 'light' ? 'light' : 'dark';
  var root = document.documentElement;
  root.setAttribute('data-dashboard-theme', nextTheme);
  root.classList.toggle('dashboard-theme-dark', nextTheme === 'dark');
  root.classList.toggle('dashboard-theme-light', nextTheme === 'light');
  root.style.backgroundColor = dashboardThemeBackground(nextTheme);
  root.style.colorScheme = nextTheme;

  var container = document.getElementById('dashboard-v2-container');
  if (container) {
    container.classList.toggle('is-theme-dark', nextTheme === 'dark');
    container.classList.toggle('is-theme-light', nextTheme === 'light');
  }

  try {
    localStorage.setItem(MEETIA_DASHBOARD_THEME_KEY, nextTheme);
  } catch (e) {
    /* ignore */
  }

  document.querySelectorAll('[data-dashboard-theme-value]').forEach(function(btn) {
    var isActive = btn.getAttribute('data-dashboard-theme-value') === nextTheme;
    btn.classList.toggle('is-active', isActive);
    btn.setAttribute('aria-pressed', isActive ? 'true' : 'false');
  });
}

function initDashboardTheme() {
  var container = document.getElementById('dashboard-v2-container');
  if (!container) return;
  applyDashboardTheme(getDashboardTheme());

  if (container.getAttribute('data-dashboard-theme-ready') === 'true') return;
  container.setAttribute('data-dashboard-theme-ready', 'true');
  container.addEventListener('click', function(e) {
    var t = clickEl(e);
    var themeBtn = t && t.closest('[data-dashboard-theme-value]');
    if (!themeBtn) return;
    e.preventDefault();
    applyDashboardTheme(themeBtn.getAttribute('data-dashboard-theme-value'));
  });
}

function initDashboardSidebar() {
  var container = document.getElementById('dashboard-v2-container');
  if (!container) return;

  var open = function() {
    container.classList.add('db-v2-sidebar--open');
    document.body.style.overflow = 'hidden';
  };

  var close = function() {
    container.classList.remove('db-v2-sidebar--open');
    document.body.style.overflow = '';
  };

  var closeAccountMenus = function() {
    container.querySelectorAll('[data-sidebar-account].is-open').forEach(function(el) {
      el.classList.remove('is-open');
      var toggle = el.querySelector('[data-sidebar-account-toggle]');
      if (toggle) toggle.setAttribute('aria-expanded', 'false');
    });
  };

  // 委譲なので多重バインドしても open/close が二重になるだけ。ready フラグで死なせない
  if (container.getAttribute('data-dashboard-sidebar-ready') === 'true') return;
  container.setAttribute('data-dashboard-sidebar-ready', 'true');

  container.addEventListener('click', function(e) {
    var t = clickEl(e);
    if (!t) return;
    if (t.closest('[data-dashboard-sidebar-toggle]')) {
      e.preventDefault();
      open();
      return;
    }
    if (t.closest('[data-dashboard-sidebar-close]')) {
      e.preventDefault();
      close();
      return;
    }
    if (t.closest('[data-dashboard-sidebar-overlay]')) {
      close();
      return;
    }

    var accountToggle = t.closest('[data-sidebar-account-toggle]');
    if (accountToggle) {
      e.preventDefault();
      e.stopPropagation();
      var account = accountToggle.closest('[data-sidebar-account]');
      if (!account) return;
      var willOpen = !account.classList.contains('is-open');
      closeAccountMenus();
      if (willOpen) {
        account.classList.add('is-open');
        accountToggle.setAttribute('aria-expanded', 'true');
      }
      return;
    }

    if (!t.closest('[data-sidebar-account]')) {
      closeAccountMenus();
    }

    var link = t.closest('.db-v2-sidebar__link');
    if (link && window.matchMedia('(max-width: 1023px)').matches) {
      close();
    }
  });

  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') closeAccountMenus();
  });
}

var DEAL_SHOW_TAB_ALIASES = {
  'content-edit': 'studio',
  'deal-knowledge': 'studio',
  'presentation-cta': 'distribution',
  'follow-up-settings': 'follow-up',
  'presentation-analytics': 'analytics'
};

function scrollDashboardAnchor() {
  if (!document.getElementById('dashboard-v2-container')) return;

  var hash = (window.location.hash || '').replace(/^#/, '');
  var section = '';
  try {
    section = new URLSearchParams(window.location.search).get('section') || '';
  } catch (e) {
    section = '';
  }
  var id = hash || section;
  if (!id) return;

  var el = document.getElementById(id);
  if (!el) return;

  var details = el.tagName === 'DETAILS' ? el : el.closest('details');
  if (details) {
    details.open = true;
    details.setAttribute('open', '');
  }

  window.setTimeout(function() {
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }, 120);
}

function resolveDealShowTabId(raw) {
  if (!raw) return 'studio';
  var id = raw.replace(/^#/, '');
  var mapped = DEAL_SHOW_TAB_ALIASES[id] || id;
  var valid = ['studio', 'distribution', 'follow-up', 'analytics'];
  return valid.indexOf(mapped) >= 0 ? mapped : 'studio';
}

function activateDealShowTab(tabId) {
  var root = document.querySelector('.db-v2-deal-show');
  if (!root) return;

  var nextTab = resolveDealShowTabId(tabId);
  var buttons = root.querySelectorAll('[data-deal-tab]');
  var panels = root.querySelectorAll('.db-v2-tab-panel');

  buttons.forEach(function(btn) {
    var isActive = btn.getAttribute('data-deal-tab') === nextTab;
    btn.classList.toggle('is-active', isActive);
    btn.setAttribute('aria-selected', isActive ? 'true' : 'false');
  });

  panels.forEach(function(panel) {
    var isActive = panel.id === 'deal-tab-' + nextTab;
    panel.classList.toggle('is-active', isActive);
    panel.hidden = !isActive;
  });

  if (window.history && window.history.replaceState) {
    window.history.replaceState(null, '', '#' + nextTab);
  }
}

function initDealShowTabs() {
  var root = document.querySelector('.db-v2-deal-show');
  if (!root || root.getAttribute('data-deal-tabs-ready') === 'true') return;
  root.setAttribute('data-deal-tabs-ready', 'true');

  root.addEventListener('click', function(e) {
    var btn = e.target.closest('[data-deal-tab]');
    if (!btn || !root.contains(btn)) return;
    activateDealShowTab(btn.getAttribute('data-deal-tab'));
  });

  activateDealShowTab(window.location.hash || 'studio');
}

function initSituationForm() {
  var form = document.querySelector('[data-situation-form="1"]');
  if (!form || form.getAttribute('data-situation-form-ready') === 'true') return;
  form.setAttribute('data-situation-form-ready', 'true');

  var toggle = form.querySelector('[data-auto-reject-toggle="1"]');
  var details = form.querySelector('[data-auto-reject-details="1"]');
  if (!toggle || !details) return;

  var sync = function() {
    details.classList.toggle('is-disabled', !toggle.checked);
  };
  toggle.addEventListener('change', sync);
  sync();
}

function csrfToken() {
  if (window.MeetiaPageInit && typeof window.MeetiaPageInit.csrfToken === 'function') {
    return window.MeetiaPageInit.csrfToken();
  }
  var meta = document.querySelector('meta[name="csrf-token"]');
  return meta ? meta.getAttribute('content') : '';
}

function copyTextToClipboard(text) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    return navigator.clipboard.writeText(text);
  }
  return new Promise(function(resolve, reject) {
    try {
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.setAttribute('readonly', '');
      ta.style.position = 'fixed';
      ta.style.left = '-9999px';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
      resolve();
    } catch (err) {
      reject(err);
    }
  });
}

function dashboardI18n(el, key, fallback) {
  var node = el;
  while (node && node.getAttribute) {
    var val = node.getAttribute('data-i18n-' + key);
    if (val) return val;
    node = node.parentElement;
  }
  var root = document.getElementById('dashboard-v2-container');
  if (root) {
    var fromRoot = root.getAttribute('data-i18n-' + key);
    if (fromRoot) return fromRoot;
  }
  return fallback;
}

function refreshSuggestApplyState(card, listSelector, applySelector, emptyLabel, selectedLabel) {
  var list = card.querySelector(listSelector || '[data-ai-suggest-list]');
  var applyBtn = card.querySelector(applySelector || '[data-ai-suggest-apply]');
  if (!list || !applyBtn) return;
  var n = list.querySelectorAll('input[type="checkbox"]:checked').length;
  applyBtn.disabled = n === 0;
  var span = applyBtn.querySelector('span');
  if (span) {
    var base = emptyLabel || dashboardI18n(card, 'add-questions', 'Add selected questions');
    var withCount = selectedLabel || base;
    var tpl = dashboardI18n(card, 'apply-count', '%{label} (%{count})');
    span.textContent = n > 0 ? tpl.replace('%{label}', withCount).replace('%{count}', n) : base;
  }
}

function refreshBasicSuggestApplyState(card) {
  var label = dashboardI18n(card, 'add-basic', 'Add selected basics');
  refreshSuggestApplyState(
    card,
    '[data-basic-suggest-list]',
    '[data-basic-suggest-apply]',
    label,
    label
  );
}

function renderSuggestedQuestions(card, questions) {
  var list = card.querySelector('[data-ai-suggest-list]');
  var results = card.querySelector('[data-ai-suggest-results]');
  if (!list || !results) return;

  list.innerHTML = '';
  (questions || []).forEach(function(q, idx) {
    var item = document.createElement('label');
    item.className = 'db-v2-suggest-item db-v2-suggest-item--selectable';

    var cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.className = 'db-v2-suggest-item__input';
    cb.checked = false;
    cb.dataset.question = JSON.stringify({
      question_text: q.question_text,
      question_type: q.question_type || 'open',
      required: !!q.required,
      category: q.category || dashboardI18n(card, 'general', 'General')
    });

    var check = document.createElement('span');
    check.className = 'db-v2-suggest-item__check';
    check.setAttribute('aria-hidden', 'true');

    var body = document.createElement('span');
    body.className = 'db-v2-suggest-item__body';

    var text = document.createElement('span');
    text.className = 'db-v2-suggest-item__text';
    text.textContent = (idx + 1) + '. ' + (q.question_text || '');

    var meta = document.createElement('span');
    meta.className = 'db-v2-suggest-item__meta';
    var metaParts = [];
    if (q.category) metaParts.push(q.category);
    metaParts.push(q.required ? dashboardI18n(card, 'required', 'Required') : dashboardI18n(card, 'optional', 'Optional'));
    if (q.reason) metaParts.push(q.reason);
    meta.textContent = metaParts.join(dashboardI18n(card, 'sep', ' / '));

    body.appendChild(text);
    body.appendChild(meta);
    item.appendChild(cb);
    item.appendChild(check);
    item.appendChild(body);
    list.appendChild(item);
  });

  results.hidden = false;
  refreshSuggestApplyState(card);
}

function setSuggestStatus(card, text, kind) {
  var statusEl = card.querySelector('[data-ai-suggest-status]');
  if (!statusEl) return;
  statusEl.textContent = text || '';
  statusEl.classList.toggle('is-error', kind === 'error' && !!text);
}

function selectedQuestionsFromList(list) {
  if (!list) return [];
  return Array.prototype.slice.call(list.querySelectorAll('input[type="checkbox"]:checked')).map(function(cb) {
    return JSON.parse(cb.dataset.question);
  });
}

function selectedSuggestedQuestions(card) {
  return selectedQuestionsFromList(card.querySelector('[data-ai-suggest-list]'));
}

function applyQuestionsFromList(card, listSelector, applyBtn, statusText) {
  var applyUrl = card.getAttribute('data-apply-url');
  var list = card.querySelector(listSelector);
  var questions = selectedQuestionsFromList(list);
  if (!applyUrl || !questions.length) return;

  if (applyBtn) applyBtn.disabled = true;
  if (statusText) setSuggestStatus(card, statusText);

  var form = document.createElement('form');
  form.method = 'POST';
  form.action = applyUrl;
  form.setAttribute('data-turbo', 'false');

  var token = document.createElement('input');
  token.type = 'hidden';
  token.name = 'authenticity_token';
  token.value = csrfToken();
  form.appendChild(token);

  var field = document.createElement('input');
  field.type = 'hidden';
  field.name = 'questions';
  field.value = JSON.stringify(questions);
  form.appendChild(field);

  document.body.appendChild(form);
  form.submit();
}

function applySuggestedQuestions(card) {
  applyQuestionsFromList(
    card,
    '[data-ai-suggest-list]',
    card.querySelector('[data-ai-suggest-apply]'),
    dashboardI18n(card, 'adding', 'Adding questions…')
  );
}

function applyBasicSuggestedQuestions(card) {
  applyQuestionsFromList(
    card,
    '[data-basic-suggest-list]',
    card.querySelector('[data-basic-suggest-apply]')
  );
}

function runAiSuggest(card) {
  var suggestUrl = card.getAttribute('data-suggest-url');
  if (!suggestUrl) {
    setSuggestStatus(card, dashboardI18n(card, 'no-suggest-url', 'Suggestion URL is missing.'), 'error');
    return;
  }

  var industryEl = card.querySelector('[data-ai-suggest-industry]');
  var jobEl = card.querySelector('[data-ai-suggest-job]');
  var countEl = card.querySelector('[data-ai-suggest-count]');
  var btn = card.querySelector('[data-ai-suggest-run]');
  var industry = industryEl ? (industryEl.value || '').trim() : '';
  var jobTitle = jobEl ? (jobEl.value || '').trim() : '';
  var count = countEl ? (countEl.value || '5') : '5';

  if (!industry || !jobTitle) {
    setSuggestStatus(card, dashboardI18n(card, 'need-industry-job', 'Enter industry and job title.'), 'error');
    return;
  }

  if (btn) btn.disabled = true;
  setSuggestStatus(card, dashboardI18n(card, 'generating', 'Generating suggestions…'));

  var body = new URLSearchParams();
  body.set('authenticity_token', csrfToken());
  body.set('industry', industry);
  body.set('job_title', jobTitle);
  body.set('count', String(count));
  body.set('persist', '1');

  var controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
  var timer = window.setTimeout(function() {
    if (controller) controller.abort();
  }, 20000);

  fetch(suggestUrl, {
    method: 'POST',
    credentials: 'same-origin',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      'X-CSRF-Token': csrfToken(),
      'X-Requested-With': 'XMLHttpRequest'
    },
    body: body.toString(),
    signal: controller ? controller.signal : undefined
  }).then(function(res) {
    return res.text().then(function(text) {
      var data = null;
      if (text) {
        try {
          data = JSON.parse(text);
        } catch (err) {
          data = null;
        }
      }
      if (!data) {
        var err = new Error('non_json');
        err.status = res.status;
        throw err;
      }
      return { ok: res.ok, status: res.status, data: data };
    });
  }).then(function(result) {
    if (!result.ok || !result.data.success) {
      setSuggestStatus(card, (result.data && result.data.error) || dashboardI18n(card, 'suggest-failed', 'Suggestion failed.'), 'error');
      return;
    }
    var questions = result.data.questions || [];
    if (!questions.length) {
      setSuggestStatus(card, dashboardI18n(card, 'suggest-failed', 'Suggestion failed.'), 'error');
      return;
    }
    setSuggestStatus(card, dashboardI18n(card, 'suggested', 'Suggested %{count}.').replace('%{count}', questions.length));
    renderSuggestedQuestions(card, questions);
  }).catch(function(err) {
    if (err && err.name === 'AbortError') {
      setSuggestStatus(card, dashboardI18n(card, 'suggest-timeout', 'Suggestion timed out. Please try again.'), 'error');
      return;
    }
    if (err && err.message === 'non_json') {
      if (err.status === 401 || err.status === 403) {
        setSuggestStatus(card, dashboardI18n(card, 'session-expired', 'Your session expired. Please sign in again.'), 'error');
      } else if (err.status >= 500) {
        setSuggestStatus(card, dashboardI18n(card, 'server-error', 'Server error. Try again in a moment.'), 'error');
      } else {
        setSuggestStatus(card, dashboardI18n(card, 'parse-error', 'Could not parse the response. Reload and try again.'), 'error');
      }
      return;
    }
    setSuggestStatus(card, dashboardI18n(card, 'network-error', 'Network error. Check your connection and try again.'), 'error');
  }).finally(function() {
    window.clearTimeout(timer);
    if (btn) btn.disabled = false;
  });
}

function questionFormFrom(el) {
  return el && el.closest ? el.closest('[data-question-form]') : null;
}

function handleChoiceRowClick(e, t) {
  var addBtn = t.closest('[data-choice-add]');
  if (addBtn) {
    e.preventDefault();
    var addForm = questionFormFrom(addBtn);
    if (addForm) addChoiceRow(addForm, '');
    return true;
  }
  var removeBtn = t.closest('[data-choice-remove]');
  if (!removeBtn) return false;
  e.preventDefault();
  var form = questionFormFrom(removeBtn);
  var row = removeBtn.closest('[data-choice-row]');
  if (!form || !row) return true;
  var rows = form.querySelectorAll('[data-choice-row]');
  if (rows.length <= 2) {
    var input = row.querySelector('[data-choice-text]');
    if (input) input.value = '';
    syncCorrectChoiceOptions(form);
    return true;
  }
  row.remove();
  renumberChoiceRows(form);
  syncCorrectChoiceOptions(form);
  return true;
}

// ダッシュボード操作はすべて document 委譲（インライン Slim JS 禁止）
document.addEventListener('click', function(e) {
  var t = clickEl(e);
  if (!t) return;
  if (handleChoiceRowClick(e, t)) return;
  var themeBtn = t.closest('[data-dashboard-theme-value]');
  if (themeBtn && document.getElementById('dashboard-v2-container')) {
    e.preventDefault();
    applyDashboardTheme(themeBtn.getAttribute('data-dashboard-theme-value'));
    return;
  }

  var copyBtn = t.closest('[data-copy-text-from]');
  if (copyBtn) {
    e.preventDefault();
    var selector = copyBtn.getAttribute('data-copy-text-from');
    var field = selector ? document.querySelector(selector) : null;
    if (!field) return;
    var label = copyBtn.querySelector('span');
    var original = label ? label.textContent : '';
    copyTextToClipboard(field.value || field.textContent || '').then(function() {
      if (label) {
        label.textContent = dashboardI18n(copyBtn, 'copied', 'Copied');
        window.setTimeout(function() { label.textContent = original || dashboardI18n(copyBtn, 'copy', 'Copy link'); }, 1600);
      }
    }).catch(function() {
      if (label) label.textContent = dashboardI18n(copyBtn, 'copy-failed', 'Copy failed');
    });
    return;
  }

  var suggestCard = t.closest('[data-ai-suggest-card]');
  if (suggestCard) {
    if (t.closest('[data-ai-suggest-apply]')) {
      e.preventDefault();
      applySuggestedQuestions(suggestCard);
      return;
    }
    if (t.closest('[data-basic-suggest-apply]')) {
      e.preventDefault();
      applyBasicSuggestedQuestions(suggestCard);
      return;
    }
    if (t.closest('[data-ai-suggest-select-all]')) {
      e.preventDefault();
      var listAll = suggestCard.querySelector('[data-ai-suggest-list]');
      if (listAll) {
        listAll.querySelectorAll('input[type="checkbox"]').forEach(function(cb) { cb.checked = true; });
        refreshSuggestApplyState(suggestCard);
      }
      return;
    }
    if (t.closest('[data-basic-suggest-select-all]')) {
      e.preventDefault();
      var basicListAll = suggestCard.querySelector('[data-basic-suggest-list]');
      if (basicListAll) {
        basicListAll.querySelectorAll('input[type="checkbox"]').forEach(function(cb) { cb.checked = true; });
        refreshBasicSuggestApplyState(suggestCard);
      }
      return;
    }
    if (t.closest('[data-ai-suggest-clear]')) {
      e.preventDefault();
      var listClear = suggestCard.querySelector('[data-ai-suggest-list]');
      if (listClear) {
        listClear.querySelectorAll('input[type="checkbox"]').forEach(function(cb) { cb.checked = false; });
        refreshSuggestApplyState(suggestCard);
      }
      return;
    }
    if (t.closest('[data-basic-suggest-clear]')) {
      e.preventDefault();
      var basicListClear = suggestCard.querySelector('[data-basic-suggest-list]');
      if (basicListClear) {
        basicListClear.querySelectorAll('input[type="checkbox"]').forEach(function(cb) { cb.checked = false; });
        refreshBasicSuggestApplyState(suggestCard);
      }
      return;
    }
  }
});

document.addEventListener('submit', function(e) {
  var form = e.target;
  if (!form || !form.classList.contains('db-v2-suggest-form')) return;
  var card = form.closest('[data-ai-suggest-card]');
  if (!card) return;
  e.preventDefault();
  runAiSuggest(card);
});

document.addEventListener('change', function(e) {
  var t = clickEl(e);
  if (!t) return;
  if (t.matches('[data-question-type-radio], [data-question-type-select]')) {
    var typeForm = questionFormFrom(t);
    if (typeForm) syncQuestionChoiceUi(typeForm);
  }
  if (t.matches('[data-branch-enabled], [data-branch-type]')) {
    var branchForm = questionFormFrom(t);
    if (branchForm) syncQuestionBranchUi(branchForm);
  }
  var card = t.closest('[data-ai-suggest-card]');
  if (!card) return;
  if (!e.target.matches('input[type="checkbox"]')) return;
  if (e.target.closest('[data-basic-suggest-list]')) {
    refreshBasicSuggestApplyState(card);
    return;
  }
  if (e.target.closest('[data-ai-suggest-list]')) {
    refreshSuggestApplyState(card);
  }
});

function isChoiceQuestionType(type) {
  return type === 'mcq' || type === 'choice' || type === 'multiple_choice';
}

function questionTypeValue(form) {
  var checked = form.querySelector('[data-question-type-radio]:checked');
  if (checked) return checked.value;
  var typeSelect = form.querySelector('[data-question-type-select]');
  return typeSelect ? typeSelect.value : 'open';
}

function syncQuestionChoiceUi(form) {
  var panel = form.querySelector('[data-choice-options-panel]');
  if (!panel) return;
  var isChoice = isChoiceQuestionType(questionTypeValue(form));
  if (isChoice) {
    var rows = form.querySelectorAll('[data-choice-row]');
    while (rows.length < 2) {
      addChoiceRow(form, '');
      rows = form.querySelectorAll('[data-choice-row]');
    }
  }
  renumberChoiceRows(form);
  syncCorrectChoiceOptions(form);
}

function syncQuestionBranchUi(form) {
  var enabled = form.querySelector('[data-branch-enabled]');
  var fields = form.querySelector('[data-branch-fields]');
  var typeSelect = form.querySelector('[data-branch-type]');
  var valueGroup = form.querySelector('[data-branch-value-group]');
  if (enabled && fields) {
    fields.hidden = !enabled.checked;
  }
  if (typeSelect && valueGroup) {
    var needsValue = typeSelect.value === 'selected_option' || typeSelect.value === 'score_above' || typeSelect.value === 'score_below';
    valueGroup.hidden = !needsValue;
  }
}

function renumberChoiceRows(form) {
  var rows = form.querySelectorAll('[data-choice-row]');
  rows.forEach(function(row, idx) {
    var num = row.querySelector('.db-v2-choice-row__num');
    if (num) num.textContent = String(idx + 1);
  });
}

function syncCorrectChoiceOptions(form) {
  var select = form.querySelector('[data-correct-choice]');
  var rows = form.querySelectorAll('[data-choice-text]');
  if (!select) return;

  var current = select.value;
  var texts = [];
  rows.forEach(function(input) {
    var v = (input.value || '').trim();
    if (v) texts.push(v);
  });

  select.innerHTML = '';
  var empty = document.createElement('option');
  empty.value = '';
  empty.textContent = dashboardI18n(form, 'no-correct', 'No correct answer (info only)');
  select.appendChild(empty);

  texts.forEach(function(text) {
    var opt = document.createElement('option');
    opt.value = text;
    opt.textContent = text;
    if (text === current) opt.selected = true;
    select.appendChild(opt);
  });

  if (current && texts.indexOf(current) === -1) {
    select.value = '';
  }
}

function addChoiceRow(form, value) {
  var list = form.querySelector('[data-choice-rows]');
  if (!list) return;

  var row = document.createElement('div');
  row.className = 'db-v2-choice-row';
  row.setAttribute('data-choice-row', '1');
  var choicePh = dashboardI18n(form, 'choice-ph', 'e.g. Full-time');
  var choiceRemove = dashboardI18n(form, 'choice-remove', 'Remove this option');
  var deleteLabel = dashboardI18n(form, 'delete', 'Delete');
  row.innerHTML =
    '<span class="db-v2-choice-row__num"></span>' +
    '<input class="db-v2-form-control" type="text" name="question[choice_texts][]" value="" placeholder="' + choicePh.replace(/"/g, '&quot;') + '" data-choice-text="1" autocomplete="off">' +
    '<button class="db-v2-btn db-v2-btn--ghost db-v2-btn--xs" type="button" data-choice-remove="1" aria-label="' + choiceRemove.replace(/"/g, '&quot;') + '">' +
      '<i class="fa-solid fa-trash" aria-hidden="true"></i><span>' + deleteLabel + '</span>' +
    '</button>';
  if (value) row.querySelector('[data-choice-text]').value = value;
  list.appendChild(row);
  renumberChoiceRows(form);
  syncCorrectChoiceOptions(form);
  row.querySelector('[data-choice-text]').focus();
}

function initQuestionForm() {
  var form = document.querySelector('[data-question-form="1"]');
  if (!form || form.getAttribute('data-question-form-ready') === 'true') return;
  form.setAttribute('data-question-form-ready', 'true');

  syncQuestionChoiceUi(form);
  syncQuestionBranchUi(form);
}

document.addEventListener('input', function(e) {
  if (!e.target || !e.target.matches('[data-choice-text]')) return;
  var form = questionFormFrom(e.target);
  if (form) syncCorrectChoiceOptions(form);
});

var problemModalBound = false;

function initProblemModal() {
  var modal = document.querySelector('[data-problem-modal]');
  if (!modal || problemModalBound) return;
  problemModalBound = true;

  var open = function() {
    var current = document.querySelector('[data-problem-modal]');
    if (!current) return;
    current.classList.add('is-open');
    current.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';
    var focusEl = current.querySelector('input, textarea, button');
    if (focusEl) {
      window.setTimeout(function() { focusEl.focus(); }, 30);
    }
  };

  var close = function() {
    var current = document.querySelector('[data-problem-modal]');
    if (!current) return;
    current.classList.remove('is-open');
    current.setAttribute('aria-hidden', 'true');
    var container = document.getElementById('dashboard-v2-container');
    if (!container || !container.classList.contains('db-v2-sidebar--open')) {
      document.body.style.overflow = '';
    }
  };

  document.addEventListener('click', function(e) {
    var t = clickEl(e);
    if (!t) return;
    if (t.closest('[data-problem-modal-open]')) {
      e.preventDefault();
      open();
      return;
    }
    if (t.closest('[data-problem-modal-close]')) {
      e.preventDefault();
      close();
    }
  });

  document.addEventListener('keydown', function(e) {
    if (e.key !== 'Escape') return;
    var current = document.querySelector('[data-problem-modal]');
    if (current && current.classList.contains('is-open')) {
      close();
    }
  });
}

function bootDashboardUi() {
  if (!document.getElementById('dashboard-v2-container')) return;
  initLoginDropdown();
  initDashboardSidebar();
  initDashboardTheme();
  initDealShowTabs();
  scrollDashboardAnchor();
  initSituationForm();
  initQuestionForm();
  initProblemModal();
  document.querySelectorAll('[data-ai-suggest-card]').forEach(function(card) {
    refreshSuggestApplyState(card);
    refreshBasicSuggestApplyState(card);
  });
  document.documentElement.setAttribute('data-dashboard-js', 'ready');
}

onReady(bootDashboardUi);
window.addEventListener('pageshow', function() {
  scrollDashboardAnchor();
});
window.addEventListener('hashchange', function() {
  scrollDashboardAnchor();
});

document.addEventListener('turbo:before-cache', function() {
  var container = document.getElementById('dashboard-v2-container');
  if (container) {
    container.removeAttribute('data-dashboard-sidebar-ready');
    container.removeAttribute('data-dashboard-theme-ready');
  }
  document.querySelectorAll('[data-deal-tabs-ready]').forEach(function(el) {
    el.removeAttribute('data-deal-tabs-ready');
  });
  document.querySelectorAll('[data-situation-form-ready]').forEach(function(el) {
    el.removeAttribute('data-situation-form-ready');
  });
  document.querySelectorAll('[data-question-form-ready]').forEach(function(el) {
    el.removeAttribute('data-question-form-ready');
  });
  document.querySelectorAll('[data-login-bound]').forEach(function(el) {
    el.removeAttribute('data-login-bound');
  });
});

})(window, document);
