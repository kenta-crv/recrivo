#!/usr/bin/env node
import { chromium } from "playwright";
import { writeFileSync, mkdtempSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";

const SILENT_WAV =
  "data:audio/wav;base64,UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA";

const html = `<!DOCTYPE html>
<html lang="ja"><head>
<meta charset="UTF-8" />
<link rel="stylesheet" href="http://127.0.0.1:3000/assets/interview.css" />
</head><body class="interview-room-body">
<div class="interview-room" data-situation-id="1" data-invite-token="test" data-language="ja"
     data-allow-text="1" data-allow-voice="1" data-record-camera="0" data-preview="1"
     data-skip-registration="1" data-enable-satisfaction="0">
<div id="phase-identity"><button id="enter_room">enter</button></div>
<div id="phase-overlay" hidden><button id="start_interview">start</button></div>
<div id="phase-room" class="interview-room__phase--cinema" hidden>
<div class="interview-cinema"><div class="interview-cinema__body"><div class="interview-cinema__main">
<div class="interview-cinema__stage">
<span id="question_count"></span>
<div id="avatar_stage" class="interview-cinema__avatar">
<div class="interview-cinema__halo"></div>
<div class="interview-cinema__ring"></div>
<img class="interview-cinema__portrait" src="http://127.0.0.1:3000/assets/avatar_3.png" alt="" />
<div class="interview-cinema__play-overlay" hidden>
<audio id="question_audio" class="interview-room__audio" hidden></audio>
<button class="presentation-play-btn" type="button" id="replay_question" hidden></button>
</div>
<div class="interview-cinema__wave"><span></span></div>
<p class="interview-cinema__avatar-label" aria-hidden="true"><span id="avatar_state_label"></span></p>
</div>
<div class="interview-cinema__caption">
<p id="question_text"></p>
<div id="answer_stage" hidden>
<div id="answer_mode_picker" hidden><button id="answer_mode_text"></button><button id="answer_mode_voice"></button></div>
<div id="text_answer_block" hidden><textarea id="text_answer"></textarea></div>
<div id="voice_answer_block" hidden></div>
<button id="submit_answer" hidden></button>
<p id="answer_action_hint" hidden></p>
</div>
</div>
</div></div></div></div>
<span id="interview_status"></span>
<div id="interview-error" hidden></div>
</div>
<script>
window.fetch=function(u){u=String(u);
var j=function(b){return Promise.resolve({ok:true,status:200,headers:{get:function(k){return k.toLowerCase()==='content-type'?'application/json':null;}},json:function(){return Promise.resolve(b);}});};
if(u.includes('/start'))return j({success:true,interview_id:999,access_token:'t',language:'ja',answer_settings:{allow_text:true,allow_voice:true},greeting:null});
if(u.includes('/next_question'))return j({success:true,interview_complete:false,question:{id:1,question_text:'自己紹介をお願いします',audio_url:'${SILENT_WAV}',order:1,total_questions:1,options:[]}});
if(u.includes('/status'))return j({success:true,remaining_seconds:3600});
return Promise.reject(new Error(u));};
</script>
<script src="http://127.0.0.1:3000/assets/interview.js"></script>
</body></html>`;

const file = join(mkdtempSync(join(tmpdir(), "recrivo-iv-")), "test.html");
writeFileSync(file, html);

const browser = await chromium.launch({ headless: true, args: ["--autoplay-policy=no-user-gesture-required"] });
const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
page.on("pageerror", (e) => console.log("PAGEERROR", e.message));

await page.addInitScript(() => {
  const mockPlaying = new WeakMap();
  const mockTime = new WeakMap();
  const mockEnded = new WeakMap();
  HTMLMediaElement.prototype.play = function () {
    mockPlaying.set(this, true);
    mockEnded.set(this, false);
    if ((mockTime.get(this) || 0) <= 0) mockTime.set(this, 0.5);
    this.dispatchEvent(new Event("play"));
    this.dispatchEvent(new Event("playing"));
    window.setTimeout(() => {
      if (!mockPlaying.get(this)) return;
      mockPlaying.set(this, false);
      mockEnded.set(this, true);
      mockTime.set(this, 999);
      this.dispatchEvent(new Event("ended"));
    }, 600);
    return Promise.resolve();
  };
  HTMLMediaElement.prototype.pause = function () {
    mockPlaying.set(this, false);
    if ((mockTime.get(this) || 0) <= 0) mockTime.set(this, 0.5);
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
});

await page.goto("file://" + file, { waitUntil: "networkidle" });
await page.click("#enter_room");
await page.click("#start_interview");
await page.waitForFunction(() => {
  const q = document.getElementById("question_text");
  const btn = document.getElementById("replay_question");
  return q && q.textContent.length > 0 && btn && !btn.hidden;
}, { timeout: 8000 });
await page.waitForTimeout(300);

const layout = await page.evaluate(() => {
  const portrait = document.querySelector(".interview-cinema__portrait");
  const caption = document.querySelector(".interview-cinema__caption");
  const btn = document.getElementById("replay_question");
  const label = document.querySelector(".interview-cinema__avatar-label");
  const hint = document.getElementById("answer_action_hint");
  const status = document.getElementById("interview_status");
  const pr = portrait.getBoundingClientRect();
  const br = btn.getBoundingClientRect();
  const cr = caption.getBoundingClientRect();
  return {
    portrait: { w: pr.width, h: pr.height, top: pr.top, left: pr.left },
    button: { top: br.top, left: br.left, w: br.width, inPortraitX: br.left >= pr.left && br.right <= pr.right, inPortraitY: br.top >= pr.top && br.bottom <= pr.bottom + 2 },
    captionTop: cr.top,
    portraitBottom: pr.bottom,
    captionBelowPortrait: cr.top >= pr.bottom - 2,
    labelHidden: getComputedStyle(label).visibility === "hidden",
    labelText: label.textContent,
    avatarHeight: document.getElementById("avatar_stage").getBoundingClientRect().height,
    hintHidden: hint.hidden,
    statusHidden: status.hidden,
    statusText: status.textContent,
  };
});

console.log("layout:", JSON.stringify(layout, null, 2));

const layoutChecks = [];
if (layout.portrait.w <= 0 || layout.portrait.h <= 0) layoutChecks.push("portrait size broken");
if (!layout.captionBelowPortrait) layoutChecks.push("caption overlaps portrait");
if (!layout.button.inPortraitX || !layout.button.inPortraitY) layoutChecks.push("button not on portrait");
if (!layout.labelHidden) layoutChecks.push("avatar label not hidden");
if (layout.labelText.includes("AI") || layout.labelText.includes("待ち") || layout.labelText.includes("回答")) layoutChecks.push("avatar label text shown");
if (layout.avatarHeight < layout.portrait.h + 10) layoutChecks.push("avatar block too short (label space lost)");

if (layoutChecks.length) {
  console.error("FAIL layout:", layoutChecks.join("; "));
  process.exit(1);
}
console.log("PASS layout");

await page.evaluate(() => {
  const stage = document.getElementById("answer_stage");
  if (stage) stage.hidden = true;
});

const playbackChecks = [];
await page.locator("#replay_question").click({ force: true });
await page.waitForTimeout(400);
let paused = await page.evaluate(() => document.getElementById("question_audio").paused);
if (paused) playbackChecks.push("manual play failed");

await page.locator("#replay_question").click({ force: true });
await page.waitForTimeout(250);
paused = await page.evaluate(() => document.getElementById("question_audio").paused);
if (!paused) playbackChecks.push("pause failed");

if (!(await page.evaluate(() => document.getElementById("answer_stage").hidden))) {
  playbackChecks.push("answer stage shown on pause");
}

await page.locator("#replay_question").click({ force: true });
await page.waitForTimeout(350);
paused = await page.evaluate(() => document.getElementById("question_audio").paused);
if (paused) playbackChecks.push("resume failed");

if (!(await page.evaluate(() => document.getElementById("answer_stage").hidden))) {
  playbackChecks.push("answer stage shown on resume");
}

await browser.close();

if (playbackChecks.length) {
  console.error("FAIL playback:", playbackChecks.join("; "));
  process.exit(1);
}
console.log("PASS playback");
