#!/usr/bin/env node
/**
 * 面接ページ再生ボタンの動作検証（Playwright）
 * Usage: node scripts/verify_interview_playback.mjs
 */
import { chromium } from "playwright";
import { writeFileSync, mkdtempSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";

const SILENT_WAV =
  "data:audio/wav;base64,UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA";

const html = `<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8" />
  <title>interview playback test</title>
  <link rel="stylesheet" href="http://127.0.0.1:3000/assets/interview.css" />
</head>
<body class="interview-room-body">
  <div class="interview-room" data-situation-id="1" data-invite-token="test" data-language="ja"
       data-allow-text="1" data-allow-voice="1" data-record-camera="0" data-preview="1"
       data-skip-registration="1" data-enable-satisfaction="0">
    <div id="phase-identity" class="interview-room__phase is-active">
      <button id="enter_room" type="button">面接室に入る</button>
    </div>
    <div id="phase-overlay" class="interview-room__overlay" hidden>
      <button id="start_interview" type="button">面接を開始</button>
    </div>
    <div id="phase-room" class="interview-room__phase interview-room__phase--cinema" hidden>
      <span id="question_count">1/1</span>
      <p id="question_text">テスト質問</p>
      <div class="interview-cinema__audio-row" hidden>
        <audio id="question_audio" class="interview-room__audio" hidden preload="auto"></audio>
        <button class="presentation-play-btn" type="button" id="replay_question" aria-label="再生"></button>
      </div>
      <div id="answer_stage" class="interview-cinema__answer-stage" hidden>
        <div id="answer_mode_picker" hidden>
          <button id="answer_mode_text" type="button">テキスト</button>
          <button id="answer_mode_voice" type="button">音声</button>
        </div>
        <div id="text_answer_block" hidden>
          <textarea id="text_answer"></textarea>
        </div>
        <div id="voice_answer_block" hidden></div>
        <button id="submit_answer" type="button" hidden>回答を送信</button>
        <p id="answer_action_hint"></p>
      </div>
      <span id="interview_status"></span>
      <div id="avatar_stage"></div>
      <span id="avatar_state_label"></span>
      <div id="interview_chat"></div>
      <div id="mcq_options"></div>
    </div>
  </div>
  <script>
    window.fetch = function(url) {
      var u = String(url);
      if (u.indexOf('/api/interviews/start') !== -1) {
        return Promise.resolve({
          ok: true, status: 200,
          json: function() {
            return Promise.resolve({
              success: true, interview_id: 999, access_token: 'tok', language: 'ja',
              answer_settings: { allow_text: true, allow_voice: true }, greeting: null
            });
          }
        });
      }
      if (u.indexOf('/api/interviews/999/next_question') !== -1) {
        return Promise.resolve({
          ok: true, status: 200,
          json: function() {
            return Promise.resolve({
              success: true, interview_complete: false,
              question: {
                id: 1,
                question_text: '自己紹介をお願いします',
                audio_url: '${SILENT_WAV}',
                order: 1, total_questions: 1, options: []
              }
            });
          }
        });
      }
      if (u.indexOf('/api/interviews/999/status') !== -1) {
        return Promise.resolve({
          ok: true, status: 200,
          json: function() { return Promise.resolve({ success: true, remaining_seconds: 3600 }); }
        });
      }
      return Promise.reject(new Error('unexpected fetch: ' + u));
    };
  </script>
  <script src="http://127.0.0.1:3000/assets/interview.js"></script>
</body>
</html>`;

const dir = mkdtempSync(join(tmpdir(), "interview-playback-"));
const filePath = join(dir, "test.html");
writeFileSync(filePath, html);

function audioState(page) {
  return page.evaluate(() => {
    const a = document.getElementById("question_audio");
    return {
      paused: a.paused,
      ended: a.ended,
      currentTime: a.currentTime,
      src: a.currentSrc || a.src || "",
    };
  });
}

async function clickPlay(page) {
  await page.evaluate(() => document.getElementById("replay_question").click());
}

async function main() {
  const browser = await chromium.launch({
    headless: true,
    args: ["--autoplay-policy=no-user-gesture-required"],
  });
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(String(e)));

  await page.goto(`file://${filePath}`, { waitUntil: "networkidle" });
  await page.click("#enter_room");
  await page.click("#start_interview");

  await page.waitForFunction(
    () => {
      const btn = document.getElementById("replay_question");
      return btn && !btn.hidden && document.getElementById("question_text").textContent.indexOf("自己紹介") >= 0;
    },
    { timeout: 20000 }
  );

  await page.waitForTimeout(800);
  let state = await audioState(page);
  console.log("after question load:", state);

  // 手動再生（1回目）
  await clickPlay(page);
  await page.waitForTimeout(400);
  state = await audioState(page);
  console.log("after play click:", state);
  if (state.paused) {
    throw new Error("FAIL: play click did not start audio");
  }

  // 停止
  await clickPlay(page);
  await page.waitForTimeout(300);
  state = await audioState(page);
  console.log("after pause click:", state);
  if (!state.paused) {
    throw new Error("FAIL: pause click did not pause audio");
  }
  if (state.currentTime <= 0) {
    throw new Error("FAIL: paused but currentTime is 0 — cannot resume");
  }

  const answerBefore = await page.evaluate(() => !document.getElementById("answer_stage").hidden);
  const textBefore = await page.evaluate(() => {
    const el = document.getElementById("text_answer");
    el.value = "テスト回答";
    return el.value;
  });

  // 再開
  await clickPlay(page);
  await page.waitForTimeout(400);
  state = await audioState(page);
  console.log("after resume click:", state);
  if (state.paused) {
    throw new Error("FAIL: resume click did not restart audio");
  }

  const answerAfter = await page.evaluate(() => !document.getElementById("answer_stage").hidden);
  const textAfter = await page.evaluate(() => document.getElementById("text_answer").value);
  if (answerBefore !== answerAfter) {
    throw new Error("FAIL: answer stage visibility changed");
  }
  if (textBefore !== textAfter) {
    throw new Error("FAIL: answer text was cleared");
  }

  // 停止して最初から再生
  await clickPlay(page);
  await page.waitForTimeout(200);
  await clickPlay(page);
  await page.waitForTimeout(400);
  state = await audioState(page);
  console.log("after replay from start:", state);
  if (state.paused) {
    throw new Error("FAIL: replay from start did not play audio");
  }

  if (errors.length) {
    throw new Error("FAIL: page errors: " + errors.join(" | "));
  }

  console.log("PASS: play -> pause -> resume -> replay verified");
  await browser.close();
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
