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
    if (t.nodeType === 3) t = t.parentElement;
    return t && t.closest ? t : null;
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
    return stored === 'light' ? 'light' : 'dark';
  } catch (e) {
    return 'dark';
  }
}

function dashboardThemeBackground(theme) {
  var teal = document.documentElement.getAttribute('data-dashboard-palette') === 'teal';
  if (theme === 'light') return teal ? '#f1f5f9' : '#e8ebf0';
  return teal ? '#0f172a' : '#0a0a12';
}

function applyDashboardTheme(theme) {
  var nextTheme = theme === 'light' ? 'light' : 'dark';
  document.documentElement.setAttribute('data-dashboard-theme', nextTheme);
  document.documentElement.style.backgroundColor = dashboardThemeBackground(nextTheme);

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
  if (!document.getElementById('dashboard-v2-container')) return;
  applyDashboardTheme(getDashboardTheme());
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
    var link = t.closest('.db-v2-sidebar__link');
    if (link && window.matchMedia('(max-width: 1023px)').matches) {
      close();
    }
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
  if (!document.getElementById('dashboard-v2-container') || !window.location.hash) return;
  var el = document.querySelector(window.location.hash);
  if (el) {
    window.setTimeout(function() {
      el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 80);
  }
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

function refreshSuggestApplyState(card) {
  var list = card.querySelector('[data-ai-suggest-list]');
  var applyBtn = card.querySelector('[data-ai-suggest-apply]');
  if (!list || !applyBtn) return;
  var n = list.querySelectorAll('input[type="checkbox"]:checked').length;
  applyBtn.disabled = n === 0;
  var span = applyBtn.querySelector('span');
  if (span) span.textContent = n > 0 ? ('選択した質問を追加（' + n + '）') : '選択した質問を追加';
}

function renderSuggestedQuestions(card, questions) {
  var list = card.querySelector('[data-ai-suggest-list]');
  var results = card.querySelector('[data-ai-suggest-results]');
  if (!list || !results) return;

  list.innerHTML = '';
  (questions || []).forEach(function(q, idx) {
    var item = document.createElement('label');
    item.className = 'db-v2-suggest-item';

    var cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.checked = true;
    cb.dataset.question = JSON.stringify({
      question_text: q.question_text,
      question_type: q.question_type || 'open',
      required: !!q.required,
      category: q.category || '一般'
    });

    var body = document.createElement('span');
    body.className = 'db-v2-suggest-item__body';

    var text = document.createElement('span');
    text.className = 'db-v2-suggest-item__text';
    text.textContent = (idx + 1) + '. ' + (q.question_text || '');

    var meta = document.createElement('span');
    meta.className = 'db-v2-suggest-item__meta';
    var metaParts = [];
    if (q.category) metaParts.push(q.category);
    metaParts.push(q.required ? '必須' : '任意');
    if (q.reason) metaParts.push(q.reason);
    meta.textContent = metaParts.join(' ／ ');

    body.appendChild(text);
    body.appendChild(meta);
    item.appendChild(cb);
    item.appendChild(body);
    list.appendChild(item);
  });

  results.hidden = false;
  refreshSuggestApplyState(card);
}

function setSuggestStatus(card, text) {
  var statusEl = card.querySelector('[data-ai-suggest-status]');
  if (statusEl) statusEl.textContent = text || '';
}

function selectedSuggestedQuestions(card) {
  var list = card.querySelector('[data-ai-suggest-list]');
  if (!list) return [];
  return Array.prototype.slice.call(list.querySelectorAll('input[type="checkbox"]:checked')).map(function(cb) {
    return JSON.parse(cb.dataset.question);
  });
}

function runAiSuggest(card) {
  var suggestUrl = card.getAttribute('data-suggest-url');
  if (!suggestUrl) {
    setSuggestStatus(card, '提案URLが設定されていません。');
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
    setSuggestStatus(card, '業種と募集職種を入力してください。');
    return;
  }

  if (btn) btn.disabled = true;
  setSuggestStatus(card, '提案を生成中…');

  fetch(suggestUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-CSRF-Token': csrfToken()
    },
    body: JSON.stringify({
      industry: industry,
      job_title: jobTitle,
      count: count,
      persist: '1'
    })
  }).then(function(res) {
    return res.json().then(function(data) {
      return { ok: res.ok, data: data };
    });
  }).then(function(result) {
    if (!result.ok || !result.data.success) {
      setSuggestStatus(card, (result.data && result.data.error) || '提案に失敗しました。');
      return;
    }
    var questions = result.data.questions || [];
    setSuggestStatus(card, questions.length + '問を提案しました。必要なものだけ選んで追加できます。');
    renderSuggestedQuestions(card, questions);
  }).catch(function() {
    setSuggestStatus(card, '通信エラーが発生しました。');
  }).finally(function() {
    if (btn) btn.disabled = false;
  });
}

function applySuggestedQuestions(card) {
  var applyUrl = card.getAttribute('data-apply-url');
  var questions = selectedSuggestedQuestions(card);
  var applyBtn = card.querySelector('[data-ai-suggest-apply]');
  if (!applyUrl || !questions.length) return;

  if (applyBtn) applyBtn.disabled = true;
  setSuggestStatus(card, '質問を追加中…');

  var form = document.createElement('form');
  form.method = 'POST';
  form.action = applyUrl;

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

// ダッシュボード操作はすべて document 委譲（インライン Slim JS 禁止）
document.addEventListener('click', function(e) {
  var t = clickEl(e);
  if (!t) return;
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
        label.textContent = 'コピーしました';
        window.setTimeout(function() { label.textContent = original || 'リンクをコピー'; }, 1600);
      }
    }).catch(function() {
      if (label) label.textContent = 'コピーに失敗しました';
    });
    return;
  }

  var suggestCard = t.closest('[data-ai-suggest-card]');
  if (suggestCard) {
    if (t.closest('[data-ai-suggest-run]')) {
      e.preventDefault();
      runAiSuggest(suggestCard);
      return;
    }
    if (t.closest('[data-ai-suggest-apply]')) {
      e.preventDefault();
      applySuggestedQuestions(suggestCard);
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
    if (t.closest('[data-ai-suggest-clear]')) {
      e.preventDefault();
      var listClear = suggestCard.querySelector('[data-ai-suggest-list]');
      if (listClear) {
        listClear.querySelectorAll('input[type="checkbox"]').forEach(function(cb) { cb.checked = false; });
        refreshSuggestApplyState(suggestCard);
      }
      return;
    }
  }
});

document.addEventListener('change', function(e) {
  var t = clickEl(e);
  if (!t) return;
  var card = t.closest('[data-ai-suggest-card]');
  if (!card) return;
  if (e.target.matches('input[type="checkbox"]')) {
    refreshSuggestApplyState(card);
  }
});

function isChoiceQuestionType(type) {
  return type === 'mcq' || type === 'choice' || type === 'multiple_choice';
}

function syncQuestionChoiceUi(form) {
  var typeSelect = form.querySelector('[data-question-type-select]');
  var panel = form.querySelector('[data-choice-options-panel]');
  if (!typeSelect || !panel) return;
  panel.style.display = isChoiceQuestionType(typeSelect.value) ? '' : 'none';
  renumberChoiceRows(form);
  syncCorrectChoiceOptions(form);
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
  empty.textContent = '正解なし（情報確認のみ）';
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
  row.innerHTML =
    '<span class="db-v2-choice-row__num"></span>' +
    '<input class="db-v2-form-control" type="text" name="question[choice_texts][]" value="" placeholder="例: はい / いいえ / 具体的な選択肢" data-choice-text="1" autocomplete="off">' +
    '<button class="db-v2-btn db-v2-btn--ghost db-v2-btn--xs" type="button" data-choice-remove="1" aria-label="この選択肢を削除">' +
      '<i class="fa-solid fa-trash" aria-hidden="true"></i><span>削除</span>' +
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

  var typeSelect = form.querySelector('[data-question-type-select]');
  if (typeSelect) {
    typeSelect.addEventListener('change', function() {
      syncQuestionChoiceUi(form);
      if (isChoiceQuestionType(typeSelect.value)) {
        var rows = form.querySelectorAll('[data-choice-row]');
        if (rows.length < 2) {
          while (form.querySelectorAll('[data-choice-row]').length < 2) addChoiceRow(form, '');
        }
      }
    });
  }

  form.addEventListener('click', function(e) {
    var t = clickEl(e);
    if (!t) return;
    if (t.closest('[data-choice-add]')) {
      e.preventDefault();
      addChoiceRow(form, '');
      return;
    }
    var removeBtn = t.closest('[data-choice-remove]');
    if (removeBtn) {
      e.preventDefault();
      var rows = form.querySelectorAll('[data-choice-row]');
      var row = removeBtn.closest('[data-choice-row]');
      if (!row) return;
      if (rows.length <= 2) {
        var input = row.querySelector('[data-choice-text]');
        if (input) input.value = '';
        syncCorrectChoiceOptions(form);
        return;
      }
      row.remove();
      renumberChoiceRows(form);
      syncCorrectChoiceOptions(form);
    }
  });

  form.addEventListener('input', function(e) {
    if (e.target && e.target.matches('[data-choice-text]')) {
      syncCorrectChoiceOptions(form);
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
  document.documentElement.setAttribute('data-dashboard-js', 'ready');
}

onReady(bootDashboardUi);

document.addEventListener('turbo:before-cache', function() {
  var container = document.getElementById('dashboard-v2-container');
  if (container) container.removeAttribute('data-dashboard-sidebar-ready');
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
