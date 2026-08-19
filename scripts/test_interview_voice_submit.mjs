#!/usr/bin/env node
/**
 * 面接の録音停止・文字起こし・送信を Playwright で検証する。
 * Usage: node scripts/test_interview_voice_submit.mjs
 */
import { chromium } from "playwright";
import { writeFileSync, mkdirSync, readFileSync } from "fs";
import { createServer } from "http";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const ROOT = process.env.RECRIVO_ROOT || join(dirname(fileURLToPath(import.meta.url)), "..");
const INTERVIEW_JS = readFileSync(join(ROOT, "app/assets/javascripts/interview.js"), "utf8");

const SILENT_WAV =
  "data:audio/wav;base64,UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA";

function htmlFixture() {
  return `<!DOCTYPE html>
<html lang="ja"><head><meta charset="UTF-8"><title>interview e2e</title></head>
<body class="interview-room-body">
<div class="interview-room" data-situation-id="1" data-invite-token="test" data-language="ja"
     data-allow-text="1" data-allow-voice="1" data-record-camera="0" data-preview="1"
     data-skip-registration="1" data-enable-satisfaction="0">
  <div id="interview-error" hidden></div>
  <div id="phase-identity" class="is-active">
    <select id="language"><option value="ja" selected>日本語</option></select>
    <button id="enter_room" type="button">面接室に入る</button>
  </div>
  <div id="phase-overlay" hidden>
    <button id="start_interview" type="button">面接を開始</button>
  </div>
  <div id="phase-room" hidden>
    <span id="interview_status" hidden></span>
    <span id="question_count"></span>
    <div id="avatar_stage" class="interview-cinema__avatar is-idle">
      <span id="avatar_state_label"></span>
    </div>
    <p id="question_text"></p>
    <div class="interview-cinema__audio-row" hidden>
      <audio id="question_audio" hidden preload="auto"></audio>
      <button id="replay_question" class="presentation-play-btn" type="button" aria-label="再生"></button>
    </div>
    <div id="answer_stage" hidden>
      <div id="mcq_options"></div>
      <div id="answer_mode_picker" hidden>
        <button id="answer_mode_text" type="button">テキストで回答</button>
        <button id="answer_mode_voice" type="button">音声で回答</button>
      </div>
      <div id="text_answer_block" hidden>
        <label id="text_answer_label" for="text_answer">あなたの回答</label>
        <textarea id="text_answer"></textarea>
      </div>
      <div id="voice_answer_block" hidden>
        <button id="voice_answer_start" type="button" hidden>録音開始</button>
        <button id="voice_answer_stop" type="button" hidden>録音を止める</button>
        <span id="voice_answer_status"></span>
      </div>
      <button id="submit_answer" type="button" hidden>回答を送信</button>
      <p id="answer_action_hint" hidden></p>
    </div>
    <div id="interview_chat"></div>
  </div>
  <div id="phase-complete-modal" hidden>
    <p id="complete-modal-desc"></p>
    <button id="confirm_complete" type="button">送信</button>
  </div>
  <div id="phase-result" hidden>
    <p id="result_status"></p>
    <div id="result_details"></div>
    <strong id="result_final_status"></strong>
    <strong id="result_avg_score"></strong>
    <strong id="result_qs"></strong>
    <p id="result_summary"></p>
    <ul id="result_strengths"></ul>
    <ul id="result_weaknesses"></ul>
    <p id="result_recommendation"></p>
    <div id="result_failure_panel" hidden><p id="result_failure_reason"></p></div>
  </div>
</div>
<script>
window.__e2e = { fetches: [], hangOnstop: false, hangTranscribe: false, submitted: null, useGreeting: false, audioHoldMs: 0 };
(function() {
  var origFetch = window.fetch;
  window.fetch = function(url, opts) {
    url = String(url);
    var rec = { url: url, method: (opts && opts.method) || 'GET' };
    if (opts && opts.body && typeof FormData !== 'undefined' && opts.body instanceof FormData) {
      rec.fileName = opts.body.get('audio_file') && opts.body.get('audio_file').name;
      rec.hasAudio = !!opts.body.get('audio_file');
      rec.textAnswer = opts.body.get('text_answer');
      rec.questionId = opts.body.get('question_id');
    }
    window.__e2e.fetches.push(rec);
    var json = function(body, status) {
      status = status || 200;
      return Promise.resolve({
        ok: status >= 200 && status < 300,
        status: status,
        headers: { get: function(k) { return String(k).toLowerCase() === 'content-type' ? 'application/json' : null; } },
        json: function() { return Promise.resolve(body); }
      });
    };
    if (url.indexOf('/start') !== -1) {
      var greeting = window.__e2e.useGreeting
        ? { text: '本日は面接にご参加いただきありがとうございます。', audio_url: '${SILENT_WAV}#greeting' }
        : null;
      return json({ success: true, interview_id: 42, access_token: 'tok', language: 'ja',
        answer_settings: { allow_text_answer: true, allow_voice_answer: true, record_camera: false }, greeting: greeting });
    }
    if (url.indexOf('/next_question') !== -1) {
      return json({ success: true, interview_complete: false, question: {
        question_id: 7, question_text: '自己紹介をお願いします', audio_url: '${SILENT_WAV}',
        order: 1, total_questions: 2, options: []
      }});
    }
    if (url.indexOf('/transcribe') !== -1) {
      if (window.__e2e.hangTranscribe) return new Promise(function() {});
      return json({ success: true, transcript: '私はエンジニアです' });
    }
    if (url.indexOf('/submit_answer') !== -1) {
      window.__e2e.submitted = rec;
      return json({ success: true, response_id: 99 }, 201);
    }
    if (url.indexOf('/status') !== -1) {
      return json({ success: true, state: { progress: 0, answered_questions: 0, total_questions: 2 } });
    }
    return origFetch.apply(this, arguments);
  };
})();
</script>
<script>
${INTERVIEW_JS}
</script>
</body></html>`;
}

async function installMediaMocks(page, { hangOnstop, hangTranscribe }) {
  await page.addInitScript(({ hangOnstop, hangTranscribe, silentWav }) => {
    window.__E2E_HANG_ONSTOP = hangOnstop;
    const mockPlaying = new WeakMap();
    const mockTime = new WeakMap();
    const mockEnded = new WeakMap();
    HTMLMediaElement.prototype.play = function () {
      mockPlaying.set(this, true);
      mockEnded.set(this, false);
      if ((mockTime.get(this) || 0) <= 0) mockTime.set(this, 0.4);
      this.dispatchEvent(new Event("play"));
      this.dispatchEvent(new Event("playing"));
      if (this._endTimer) window.clearTimeout(this._endTimer);
      const hold = (window.__e2e && window.__e2e.audioHoldMs) || 80;
      this._endTimer = window.setTimeout(() => {
        if (!mockPlaying.get(this)) return;
        mockPlaying.set(this, false);
        mockEnded.set(this, true);
        mockTime.set(this, 99);
        this.dispatchEvent(new Event("ended"));
      }, hold);
      return Promise.resolve();
    };
    HTMLMediaElement.prototype.pause = function () {
      mockPlaying.set(this, false);
      if (this._endTimer) {
        window.clearTimeout(this._endTimer);
        this._endTimer = null;
      }
      if ((mockTime.get(this) || 0) <= 0) mockTime.set(this, 0.4);
      this.dispatchEvent(new Event("pause"));
    };
    Object.defineProperty(HTMLMediaElement.prototype, "paused", {
      configurable: true,
      get() { return !mockPlaying.get(this); },
    });
    Object.defineProperty(HTMLMediaElement.prototype, "currentTime", {
      configurable: true,
      get() { return mockTime.get(this) || 0; },
      set(v) { mockTime.set(this, v); },
    });
    Object.defineProperty(HTMLMediaElement.prototype, "ended", {
      configurable: true,
      get() { return !!mockEnded.get(this); },
    });

    class FakeTrack { stop() {} get readyState() { return "live"; } }
    class FakeStream {
      constructor() { this._tracks = [new FakeTrack()]; }
      getTracks() { return this._tracks; }
    }
    navigator.mediaDevices = navigator.mediaDevices || {};
    navigator.mediaDevices.getUserMedia = async () => new FakeStream();

    class FakeRecorder {
      constructor(stream, opts) {
        this.state = "inactive";
        this.mimeType = (opts && opts.mimeType) || "audio/webm";
        this.ondataavailable = null;
        this.onstop = null;
        this._interviewStream = stream;
      }
      start() { this.state = "recording"; }
      requestData() {
        if (typeof this.ondataavailable === "function") {
          const blob = new Blob([new Uint8Array(2500)], { type: this.mimeType });
          this.ondataavailable({ data: blob });
        }
      }
      stop() {
        this.state = "inactive";
        this.requestData();
        if (window.__E2E_HANG_ONSTOP) return;
        if (typeof this.onstop === "function") this.onstop();
      }
    }
    FakeRecorder.isTypeSupported = (t) => String(t).indexOf("webm") !== -1;
    window.MediaRecorder = FakeRecorder;
  }, { hangOnstop, hangTranscribe, silentWav: SILENT_WAV });
}

async function snapshot(page) {
  return page.evaluate(() => {
    const submit = document.getElementById("submit_answer");
    const stage = document.getElementById("answer_stage");
    const start = document.getElementById("voice_answer_start");
    const stop = document.getElementById("voice_answer_stop");
    const err = document.getElementById("interview-error");
    const replay = document.getElementById("replay_question");
    return {
      question: (document.getElementById("question_text") || {}).textContent,
      answerHidden: !!(stage && stage.hidden),
      submitHidden: !!(submit && submit.hidden),
      submitDisabled: !!(submit && submit.disabled),
      submitText: submit ? submit.textContent : null,
      voiceStartHidden: !!(start && start.hidden),
      voiceStopHidden: !!(stop && stop.hidden),
      voiceStatus: (document.getElementById("voice_answer_status") || {}).textContent,
      error: err && !err.hidden ? err.textContent : "",
      playingClass: !!(replay && replay.classList.contains("presentation-play-btn--playing")),
      audioPaused: document.getElementById("question_audio").paused,
      textarea: (document.getElementById("text_answer") || {}).value,
      fetches: (window.__e2e && window.__e2e.fetches) || [],
      submitted: window.__e2e && window.__e2e.submitted,
    };
  });
}

async function runCase(browser, origin, name, opts) {
  const results = [];
  const page = await browser.newPage();
  page.on("pageerror", (e) => results.push({ ok: false, name: name + ":pageerror", detail: e.message }));
  try {
  await installMediaMocks(page, opts);
  await page.goto(origin);
  await page.evaluate((hang) => { window.__e2e.hangTranscribe = hang; }, opts.hangTranscribe);

  await page.evaluate(() => document.getElementById("enter_room").click());
  await page.evaluate(() => document.getElementById("start_interview").click());
  await page.waitForFunction(() => {
    const q = document.getElementById("question_text");
    const a = document.getElementById("answer_stage");
    return q && q.textContent.indexOf("自己紹介") !== -1 && a && !a.hidden;
  }, null, { timeout: 20000 });
  await page.waitForTimeout(400);

  let s = await snapshot(page);
  results.push({
    ok: !s.answerHidden && !s.submitHidden && !s.submitDisabled && s.submitText === "回答を送信",
    name: name + ":質問表示と同時に回答・送信が出る",
    detail: JSON.stringify({ answerHidden: s.answerHidden, submitHidden: s.submitHidden, submitDisabled: s.submitDisabled, submitText: s.submitText }),
  });
  results.push({
    ok: !s.voiceStartHidden,
    name: name + ":音声録音ボタンが出る",
    detail: "voiceStartHidden=" + s.voiceStartHidden,
  });

  // 再生停止しても回答欄が消えない
  const playing = await page.evaluate(() => !document.getElementById("question_audio").paused);
  if (playing) {
    await page.locator("#replay_question").click({ force: true });
    await page.waitForTimeout(200);
  }
  s = await snapshot(page);
  results.push({
    ok: s.audioPaused && !s.playingClass && !s.answerHidden && !s.submitDisabled,
    name: name + ":音声停止後も送信できる",
    detail: JSON.stringify({ audioPaused: s.audioPaused, playingClass: s.playingClass, answerHidden: s.answerHidden, submitDisabled: s.submitDisabled }),
  });

  await page.locator("#voice_answer_start").click({ force: true });
  await page.waitForTimeout(400);
  s = await snapshot(page);
  results.push({
    ok: !s.voiceStopHidden && s.submitDisabled,
    name: name + ":録音中は停止ボタンが出て送信は無効",
    detail: JSON.stringify({ voiceStopHidden: s.voiceStopHidden, submitDisabled: s.submitDisabled, submitText: s.submitText }),
  });

  const t0 = Date.now();
  await page.locator("#voice_answer_stop").click({ force: true });
  await page.waitForFunction(() => {
    const btn = document.getElementById("submit_answer");
    const start = document.getElementById("voice_answer_start");
    return btn && !btn.disabled && start && !start.hidden;
  }, null, { timeout: opts.hangOnstop ? 6000 : 4000 });
  const elapsed = Date.now() - t0;
  s = await snapshot(page);
  results.push({
    ok: !s.submitDisabled && s.submitText === "回答を送信" && !s.voiceStartHidden,
    name: name + ":録音停止後に送信できる",
    detail: JSON.stringify({ elapsedMs: elapsed, submitDisabled: s.submitDisabled, submitText: s.submitText, voiceStatus: s.voiceStatus, error: s.error }),
  });
  if (opts.hangOnstop) {
    results.push({
      ok: elapsed < 6500,
      name: name + ":onstop未発火でも数秒以内に復帰",
      detail: "elapsedMs=" + elapsed,
    });
  }

  if (!opts.hangTranscribe) {
    await page.waitForFunction(() => {
      const el = document.getElementById("text_answer");
      return el && el.value.indexOf("エンジニア") !== -1;
    }, null, { timeout: 4000 }).catch(() => {});
    s = await snapshot(page);
    results.push({
      ok: (s.textarea || "").indexOf("エンジニア") !== -1,
      name: name + ":文字起こしがテキスト欄に入る",
      detail: "textarea=" + JSON.stringify(s.textarea) + " status=" + s.voiceStatus,
    });
  }

  await page.locator("#submit_answer").click({ force: true });
  await page.waitForFunction(() => window.__e2e && window.__e2e.submitted, null, { timeout: 4000 });
  s = await snapshot(page);
  results.push({
    ok: !!(s.submitted && s.submitted.hasAudio && s.submitted.questionId === "7"),
    name: name + ":回答を送信できる",
    detail: JSON.stringify(s.submitted),
  });
  results.push({
    ok: !!(s.submitted && s.submitted.fileName && s.submitted.fileName !== "recording.webm" || (s.submitted && s.submitted.fileName === "answer.webm")),
    name: name + ":音声ファイル名が正しい",
    detail: "fileName=" + (s.submitted && s.submitted.fileName),
  });

  await page.close();
  return results;
  } catch (e) {
    let snap = {};
    try { snap = await snapshot(page); } catch (e2) {}
    results.push({ ok: false, name: name + ":exception", detail: String(e && e.message) + " :: " + JSON.stringify(snap) });
    try { await page.close(); } catch (e3) {}
    return results;
  }
}

async function runGreetingStopCase(browser, origin) {
  const results = [];
  const page = await browser.newPage();
  page.on("pageerror", (e) => results.push({ ok: false, name: "案内停止:pageerror", detail: e.message }));
  try {
    await installMediaMocks(page, { hangOnstop: false, hangTranscribe: false });
    await page.goto(origin);
    await page.evaluate(() => {
      window.__e2e.useGreeting = true;
      window.__e2e.audioHoldMs = 30000;
    });
    await page.evaluate(() => document.getElementById("enter_room").click());
    await page.evaluate(() => document.getElementById("start_interview").click());
    await page.waitForFunction(() => {
      const q = document.getElementById("question_text");
      const replay = document.getElementById("replay_question");
      return q && q.textContent.indexOf("ご参加") !== -1
        && replay && replay.classList.contains("presentation-play-btn--playing");
    }, null, { timeout: 20000 });

    await page.locator("#replay_question").click({ force: true });
    await page.waitForTimeout(800);

    const s = await snapshot(page);
    const nextQ = (s.fetches || []).filter((f) => String(f.url).indexOf("/next_question") !== -1);
    results.push({
      ok: s.question && s.question.indexOf("ご参加") !== -1 && s.question.indexOf("自己紹介") === -1,
      name: "案内停止:案内文のまま止まる",
      detail: JSON.stringify({ question: s.question }),
    });
    results.push({
      ok: s.answerHidden === true,
      name: "案内停止:回答欄が出ない（画面サイズが変わらない）",
      detail: "answerHidden=" + s.answerHidden,
    });
    results.push({
      ok: nextQ.length === 0,
      name: "案内停止:次の質問を取りに行かない",
      detail: "next_question=" + nextQ.length + " fetches=" + JSON.stringify(s.fetches),
    });
    results.push({
      ok: s.audioPaused && !s.playingClass,
      name: "案内停止:再生ボタンが停止状態になる",
      detail: JSON.stringify({ audioPaused: s.audioPaused, playingClass: s.playingClass }),
    });

    await page.close();
    return results;
  } catch (e) {
    let snap = {};
    try { snap = await snapshot(page); } catch (e2) {}
    results.push({ ok: false, name: "案内停止:exception", detail: String(e && e.message) + " :: " + JSON.stringify(snap) });
    try { await page.close(); } catch (e3) {}
    return results;
  }
}

const html = htmlFixture();
console.log("fixture bytes", html.length);
const server = createServer((req, res) => {
  res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
  res.end(html);
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const origin = "http://127.0.0.1:" + server.address().port;

const browser = await chromium.launch({
  headless: true,
  channel: "chrome",
  args: ["--autoplay-policy=no-user-gesture-required"],
});

const all = [];
try {
  all.push(...await runGreetingStopCase(browser, origin));
  all.push(...await runCase(browser, origin, "通常", { hangOnstop: false, hangTranscribe: false }));
  all.push(...await runCase(browser, origin, "onstop固まり", { hangOnstop: true, hangTranscribe: false }));
  all.push(...await runCase(browser, origin, "文字起こし無応答", { hangOnstop: false, hangTranscribe: true }));
} finally {
  await browser.close();
  await new Promise((resolve) => server.close(resolve));
}

let failed = 0;
for (const r of all) {
  const mark = r.ok ? "PASS" : "FAIL";
  if (!r.ok) failed += 1;
  console.log(mark + "  " + r.name + (r.ok ? "" : "  :: " + r.detail));
}
console.log(failed ? "\nRESULT FAIL (" + failed + " failed)" : "\nRESULT PASS (" + all.length + " checks)");
process.exit(failed ? 1 : 0);
