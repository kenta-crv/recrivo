//= require rails-ujs
// app/assets/javascripts/interview.js
(function() {
  function initInterviewRoom() {
    var root = document.querySelector('.interview-room');
    if (!root) return;

    function byId(id) { return document.getElementById(id); }

    var situationId = parseInt(root.getAttribute('data-situation-id'), 10);
    var inviteToken = root.getAttribute('data-invite-token');
    var defaultLanguage = root.getAttribute('data-language') || 'ja';

    var errorEl = byId('interview-error');
    var phaseIdentity = byId('phase-identity');
    var phaseOverlay = byId('phase-overlay');
    var phaseRoom = byId('phase-room');
    var phaseResult = byId('phase-result');
    var phaseCompleteModal = byId('phase-complete-modal');
    var confirmCompleteBtn = byId('confirm_complete');
    var resultDetails = byId('result_details');

    var enterBtn = byId('enter_room');
    var startBtn = byId('start_interview');
    var submitBtn = byId('submit_answer');
    var statusEl = byId('interview_status');
    var progressBar = byId('progress_bar');
    var questionCount = byId('question_count');
    var questionText = byId('question_text');
    var questionAudio = byId('question_audio');
    var mcqOptions = byId('mcq_options');
    var avatarStage = byId('avatar_stage');
    var avatarStateLabel = byId('avatar_state_label');
    var replayBtn = byId('replay_question');
    var voiceStartBtn = byId('voice_answer_start');
    var voiceStopBtn = byId('voice_answer_stop');
    var voiceStatus = byId('voice_answer_status');
    var resultStatus = byId('result_status');
    var resultFinal = byId('result_final_status');
    var resultAvg = byId('result_avg_score');
    var resultQs = byId('result_qs');
    var resultSummary = byId('result_summary');
    var resultStrengths = byId('result_strengths');
    var resultWeaknesses = byId('result_weaknesses');
    var resultRecommendation = byId('result_recommendation');
    var resultFailurePanel = byId('result_failure_panel');
    var resultFailureReason = byId('result_failure_reason');

    var interviewId = null;
    var currentQuestion = null;
    var mediaRecorder = null;
    var recordedChunks = [];
    var recordedBlob = null;
    var selectedOption = null;
    var isSubmitting = false;
    var candidateName = '';
    var candidateEmail = '';
    var candidateTel = '';
    var candidateAddress = '';
    var lastSpokenText = '';
    var lastAudioUrl = null;
    var speechRecognition = null;
    var interviewLanguage = defaultLanguage;
    // 再生の世代番号。古い play / TTS コールバックを無効化する
    var playbackGeneration = 0;
    // マイク／SpeechRecognition 使用後はブラウザTTSが壊れやすい（Chrome既知）
    var micWasUsed = false;

    if (root.getAttribute('data-interview-bound') === '1') return;
    root.setAttribute('data-interview-bound', '1');

    function showError(msg) {
      if (!errorEl) return;
      errorEl.hidden = false;
      errorEl.textContent = msg || 'エラーが発生しました。';
    }

    function clearError() {
      if (!errorEl) return;
      errorEl.hidden = true;
      errorEl.textContent = '';
    }

    function showPhase(name) {
      [phaseIdentity, phaseOverlay, phaseRoom, phaseResult, phaseCompleteModal].forEach(function(el) {
        if (!el) return;
        el.hidden = true;
        el.classList.remove('is-active');
      });
      if (name === 'identity' && phaseIdentity) {
        phaseIdentity.hidden = false;
        phaseIdentity.classList.add('is-active');
      } else if (name === 'overlay' && phaseOverlay) {
        phaseOverlay.hidden = false;
        phaseOverlay.classList.add('is-active');
      } else if (name === 'room' && phaseRoom) {
        phaseRoom.hidden = false;
        phaseRoom.classList.add('is-active');
      } else if (name === 'complete' && phaseCompleteModal) {
        // ルームは残しつつ送信モーダルを前面に
        if (phaseRoom) {
          phaseRoom.hidden = false;
          phaseRoom.classList.add('is-active');
        }
        phaseCompleteModal.hidden = false;
        phaseCompleteModal.classList.add('is-active');
      } else if (name === 'result' && phaseResult) {
        phaseResult.hidden = false;
        phaseResult.classList.add('is-active');
      }
    }

    function setStatus(msg) {
      if (statusEl) statusEl.textContent = msg;
    }

    function setProgress(progress, answered, total) {
      var pct = Math.max(0, Math.min(100, progress || 0));
      if (progressBar) progressBar.style.width = pct + '%';
      if (questionCount) questionCount.textContent = (answered || 0) + ' / ' + (total || 0) + ' 問';
    }

    function saveSession(id, language, token) {
      localStorage.setItem('aiInterviewId', String(id));
      localStorage.setItem('aiInterviewLanguage', String(language || 'ja'));
      if (token) {
        localStorage.setItem('aiInterviewToken', token);
        window.accessToken = token;
      }
    }

    function clearSession() {
      localStorage.removeItem('aiInterviewId');
      localStorage.removeItem('aiInterviewLanguage');
      localStorage.removeItem('aiInterviewToken');
      window.accessToken = null;
    }

    function restoreToken() {
      var token = localStorage.getItem('aiInterviewToken');
      if (token) window.accessToken = token;
      return token;
    }

    function authHeaders(extra) {
      var headers = extra || {};
      if (window.accessToken) headers['X-Interview-Token'] = window.accessToken;
      return headers;
    }

    async function apiRequest(url, options) {
      options = options || {};
      options.headers = authHeaders(options.headers || {});

      var res;
      try {
        res = await fetch(url, options);
      } catch (netErr) {
        throw new Error('ネットワークエラー: ' + netErr.message);
      }

      var contentType = res.headers.get('content-type') || '';
      var data;
      if (contentType.indexOf('application/json') !== -1) {
        try {
          data = await res.json();
        } catch (e) {
          throw new Error('サーバー応答の解析に失敗しました。');
        }
      } else {
        data = { success: false, error: 'サーバーエラー (' + res.status + ')' };
      }

      if (res.status === 410 && data.reason === 'timeout') data.__timeout = true;
      if (res.status === 401) data.__unauthorized = true;
      if (data.__timeout || data.__unauthorized) clearSession();

      return { status: res.status, ok: res.ok, data: data };
    }

    function enterRoom() {
      clearError();
      unlockAudioPlayback();
      candidateName = (byId('candidate_name').value || '').trim();
      candidateEmail = (byId('candidate_email').value || '').trim();
      candidateTel = (byId('candidate_tel') && byId('candidate_tel').value || '').trim();
      candidateAddress = (byId('candidate_address') && byId('candidate_address').value || '').trim();
      if (!candidateName || !candidateEmail || !candidateTel || !candidateAddress) {
        showError('お名前・メールアドレス・電話番号・住所を入力してください。');
        return;
      }
      showPhase('overlay');
    }

    function unlockAudioPlayback() {
      // speechSynthesis の cancel/speak は後続TTSを壊すので使わない。HTML Audio のみ解錠する。
      try {
        if (!questionAudio) return;
        var silent = 'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBIAAAABAAEARKwAAIhYAQACABAAAABkYXRhAgAAAAEA';
        questionAudio.src = silent;
        var p = questionAudio.play();
        if (p && p.then) {
          p.then(function() {
            try { questionAudio.pause(); } catch (e1) {}
          }).catch(function() {});
        }
      } catch (e) {}
    }

    async function startInterview() {
      clearError();
      unlockAudioPlayback();
      startBtn.disabled = true;
      startBtn.textContent = '開始中...';

      var language = (byId('language') && byId('language').value) || defaultLanguage;

      try {
        var result = await apiRequest('/api/interviews/start', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            situation_id: situationId,
            invite_token: inviteToken,
            language: language,
            candidate_name: candidateName,
            candidate_email: candidateEmail,
            candidate_tel: candidateTel,
            candidate_address: candidateAddress
          })
        });
        var data = result.data;

        if (data.reason === 'already_completed') {
          showPhase('result');
          displayResults({
            message: 'この面接は既に受験済みです。同じ面接は1回のみ受験できます。',
            result: { final_status: 'completed' }
          });
          return;
        }

        if (!data.success) {
          showError(data.error || '面接の開始に失敗しました。');
          showPhase('identity');
          startBtn.disabled = false;
          startBtn.textContent = '面接を開始';
          return;
        }

        interviewId = data.interview_id;
        interviewLanguage = data.language || language;
        saveSession(interviewId, interviewLanguage, data.access_token);
        showPhase('room');
        if (startBtn) {
          startBtn.disabled = false;
          startBtn.textContent = '面接を開始';
        }

        var greetingText = (data.greeting && data.greeting.text) || '';
        if (greetingText) {
          setStatus('ご挨拶を再生中...');
          if (questionText) questionText.textContent = greetingText;
          // 挨拶は流れを優先。再生開始に失敗したら待たず次へ進む
          await playSpokenContent({
            text: greetingText,
            audioUrl: (data.greeting && data.greeting.audio_url) || null,
            waitUntilEnd: true
          });
          await waitMs(200);
        }

        await loadNextQuestion();
      } catch (e) {
        showError(e.message);
        showPhase('identity');
        startBtn.disabled = false;
        startBtn.textContent = '面接を開始';
      }
    }

    async function loadNextQuestion() {
      if (!interviewId) return false;
      clearError();
      setStatus('質問を読み込み中...');
      if (submitBtn) submitBtn.disabled = true;
      setAnswerActionHint('');

      try {
        var result = await apiRequest('/api/interviews/' + interviewId + '/next_question', {});
        var data = result.data;

        if (data.__timeout) {
          showError('セッションがタイムアウトしました。招待リンクから再度お試しください。');
          return false;
        }

        if (!data.success) {
          // 自動不合格などでセッション終了済みの場合は結果へ
          var errMsg = data.error || '';
          if (/not in progress|failed|completed/i.test(errMsg)) {
            setStatus('面接が終了しました。結果を表示します...');
            await completeInterview();
            return true;
          }
          showError(errMsg || '質問の取得に失敗しました。');
          return false;
        }

        if (data.interview_complete) {
          clearAnswerForm();
          await finishInterviewWithClosing();
          return true;
        }

        currentQuestion = data.question || {};
        // 次問が取れた時点で回答欄を空にする（再生完了を待たない）
        clearAnswerForm();
        var order = currentQuestion.order || 0;
        var total = currentQuestion.total_questions || 0;
        var bridge = questionBridgeText(order, total);

        // ブリッジは表示のみ（発話しない）。ブラウザTTS依存を排除する。
        if (questionText) questionText.textContent = bridge;
        renderOptions(null);
        setAvatarState('speaking');
        setStatus(bridge);
        setSubmitButtonState('questioning');
        setVoiceControlsForQuestioning(true);
        await waitMs(micWasUsed ? 500 : 350);
        await preparePlaybackAfterMic();

        if (questionText) questionText.textContent = currentQuestion.question_text || '（質問文なし）';
        renderOptions(currentQuestion.options);

        var answered = order ? Math.max(0, order - 1) : 0;
        setProgress(total ? (answered / total) * 100 : 0, answered, total);
        setStatus('質問を再生中...');
        setSubmitButtonState('questioning');
        setVoiceControlsForQuestioning(true);

        // 質問は HTML Audio を最後まで再生する（サーバーTTS）
        var played = await playSpokenContent({
          text: currentQuestion.question_text || '',
          audioUrl: currentQuestion.audio_url,
          waitUntilEnd: true
        });
        setStatus(played ? '回答を入力してください' : '音声の自動再生がブロックされました。「音声を再生」を押してください。');
        setSubmitButtonState('ready');
        setVoiceControlsForQuestioning(false);
        refreshStatus().catch(function() {});
        return true;
      } catch (e) {
        showError(e.message || '質問の取得に失敗しました。');
        setSubmitButtonState('ready');
        setVoiceControlsForQuestioning(false);
        return false;
      }
    }

    function questionBridgeText(order, total) {
      var isLast = total > 0 && order === total;
      if (interviewLanguage === 'en') {
        return isLast ? 'This is the last question.' : 'Next question.';
      }
      return isLast ? '最後の質問です。' : '次の質問です';
    }

    function closingMessageText() {
      if (interviewLanguage === 'en') {
        return 'That concludes the interview.';
      }
      return '面接は以上となります。';
    }

    function completeModalDescText() {
      if (interviewLanguage === 'en') {
        return 'We will send the interview results to your registered email address. Submit your interview information to finish.';
      }
      return '面接結果はご登録のメールアドレス宛にお送りします。内容を送信して面接を完了してください。';
    }

    function setSubmitButtonState(state) {
      if (!submitBtn) return;
      submitBtn.hidden = false;
      if (state === 'questioning') {
        submitBtn.disabled = true;
        submitBtn.textContent = '質問中';
      } else if (state === 'submitting') {
        submitBtn.disabled = true;
        submitBtn.textContent = '送信中...';
      } else {
        // ready
        submitBtn.disabled = false;
        submitBtn.textContent = '回答を送信';
      }
    }

    function setVoiceControlsForQuestioning(isQuestioning) {
      if (voiceStartBtn) {
        voiceStartBtn.hidden = false;
        voiceStartBtn.disabled = !!isQuestioning;
      }
      if (voiceStopBtn) {
        voiceStopBtn.hidden = false;
        voiceStopBtn.disabled = true;
      }
    }

    function setAnswerActionHint(msg) {
      var hint = byId('answer_action_hint');
      if (hint) hint.textContent = msg || '';
    }

    function clearAnswerForm() {
      recordedChunks = [];
      recordedBlob = null;
      selectedOption = null;
      voiceFinalText = '';
      voiceRecordedBlob = null;
      voiceRecordedChunks = [];
      if (byId('text_answer')) byId('text_answer').value = '';
      if (voiceStatus) voiceStatus.textContent = '';
      if (mcqOptions) {
        mcqOptions.querySelectorAll('.interview-room__mcq-option').forEach(function(b) {
          b.classList.remove('is-selected');
        });
      }
    }

    async function finishInterviewWithClosing() {
      var closing = closingMessageText();
      setStatus('面接終了');
      setAvatarState('idle');
      if (questionText) questionText.textContent = closing;
      if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.hidden = true;
      }
      if (voiceStartBtn) voiceStartBtn.hidden = true;
      if (voiceStopBtn) voiceStopBtn.hidden = true;
      if (replayBtn) replayBtn.hidden = true;
      setAnswerActionHint('');

      var modalDesc = byId('complete-modal-desc');
      if (modalDesc) modalDesc.textContent = completeModalDescText();

      // メール案内は画面本文に出さず、送信モーダルだけに表示する
      showPhase('complete');
    }

    function setAvatarState(state) {
      if (!avatarStage) return;
      avatarStage.classList.remove('is-idle', 'is-speaking', 'is-listening');
      avatarStage.classList.add('is-' + state);
      if (avatarStateLabel) {
        avatarStateLabel.textContent = state === 'speaking' ? '発話中'
          : state === 'listening' ? '回答待ち'
          : '待機中';
      }
    }

    function stopBrowserSpeech() {
      try {
        if (window.speechSynthesis) window.speechSynthesis.cancel();
      } catch (e) {}
    }

    function hardStopSpeechRecognition() {
      clearTimeout(voiceRestartTimer);
      voiceListening = false;
      if (!speechRecognition) return;
      try { speechRecognition.onend = null; } catch (e) {}
      try { speechRecognition.onresult = null; } catch (e) {}
      try { speechRecognition.onerror = null; } catch (e) {}
      try { speechRecognition.abort(); } catch (e1) {
        try { speechRecognition.stop(); } catch (e2) {}
      }
      speechRecognition = null;
    }

    function waitMs(ms) {
      return new Promise(function(resolve) { setTimeout(resolve, ms); });
    }

    async function preparePlaybackAfterMic() {
      hardStopSpeechRecognition();
      stopBrowserSpeech();
      if (!micWasUsed) return;
      // マイク解放後、HTML Audio を再解錠してから少し待つ
      unlockAudioPlayback();
      await waitMs(400);
    }

    function playHtmlAudio(url, waitUntilEnd, generation) {
      return new Promise(function(resolve) {
        if (!questionAudio || !url) {
          resolve(false);
          return;
        }
        if (generation != null && generation !== playbackGeneration) {
          resolve(false);
          return;
        }

        var finished = false;
        var started = false;

        questionAudio.hidden = false;
        questionAudio.onplay = null;
        questionAudio.onplaying = null;
        questionAudio.onended = null;
        questionAudio.onerror = null;
        questionAudio.onpause = null;

        // 長さ不明でも止まらないよう上限を設ける（質問は通常60秒未満）
        var safetyMs = waitUntilEnd ? 90000 : 8000;
        var startFailTimer = setTimeout(function() {
          if (!started) done(false);
        }, 4000);
        var safetyTimer = setTimeout(function() {
          done(started || !!(questionAudio && !questionAudio.paused && questionAudio.currentTime > 0));
        }, safetyMs);

        function done(ok) {
          if (finished) return;
          finished = true;
          clearTimeout(safetyTimer);
          clearTimeout(startFailTimer);
          if (generation != null && generation !== playbackGeneration) {
            resolve(false);
            return;
          }
          if (ok && waitUntilEnd) {
            setAvatarState('listening');
          } else if (ok) {
            setAvatarState('speaking');
          } else {
            setAvatarState('listening');
          }
          resolve(!!ok);
        }

        function markStarted() {
          if (generation != null && generation !== playbackGeneration) return;
          if (started) return;
          started = true;
          clearTimeout(startFailTimer);
          setAvatarState('speaking');
          if (!waitUntilEnd) done(true);
        }

        questionAudio.onplaying = markStarted;
        questionAudio.onplay = markStarted;
        questionAudio.onended = function() { done(true); };
        questionAudio.onerror = function() { done(false); };

        try { questionAudio.pause(); } catch (e) {}
        // 同一URLでも確実に再生し直す
        questionAudio.src = url + (url.indexOf('?') >= 0 ? '&' : '?') + 't=' + Date.now();
        try { questionAudio.load(); } catch (e2) {}

        var playPromise = questionAudio.play();
        if (playPromise && playPromise.then) {
          playPromise.then(function() {
            // playing イベントで開始確定
          }).catch(function() {
            done(false);
          });
        } else {
          done(false);
        }
      });
    }

    function speakWithBrowser(text, waitUntilEnd, generation) {
      // 最終手段のみ。Chromeでは cancel 後に壊れやすいので短時間で諦める。
      return new Promise(function(resolve) {
        if (!text || !window.speechSynthesis) {
          resolve(false);
          return;
        }
        if (generation != null && generation !== playbackGeneration) {
          resolve(false);
          return;
        }

        var finished = false;
        var started = false;
        var utter = new SpeechSynthesisUtterance(text);
        utter.lang = interviewLanguage === 'en' ? 'en-US' : 'ja-JP';
        utter.rate = 1;

        var startFailTimer = setTimeout(function() {
          if (!started) done(false);
        }, 1500);
        var safetyTimer = setTimeout(function() {
          done(started);
        }, waitUntilEnd ? Math.min(20000, Math.max(4000, String(text).length * 80)) : 4000);

        function done(ok) {
          if (finished) return;
          finished = true;
          clearTimeout(startFailTimer);
          clearTimeout(safetyTimer);
          if (generation != null && generation !== playbackGeneration) {
            resolve(false);
            return;
          }
          setAvatarState('listening');
          resolve(!!ok);
        }

        utter.onstart = function() {
          started = true;
          clearTimeout(startFailTimer);
          setAvatarState('speaking');
          if (!waitUntilEnd) done(true);
        };
        utter.onend = function() { done(true); };
        utter.onerror = function() { done(started); };

        try {
          window.speechSynthesis.speak(utter);
        } catch (e) {
          done(false);
        }
      });
    }

    async function playSpokenContent(opts) {
      opts = opts || {};
      var text = opts.text || '';
      var url = opts.audioUrl || null;
      var waitUntilEnd = !!opts.waitUntilEnd;
      lastSpokenText = text;
      lastAudioUrl = url;

      playbackGeneration += 1;
      var generation = playbackGeneration;

      stopBrowserSpeech();
      if (replayBtn) {
        replayBtn.hidden = false;
        replayBtn.textContent = '🔊 音声を再生';
      }

      // 1) サーバーTTS（HTML Audio）を最優先。これが本線。
      if (url) {
        var ok = await playHtmlAudio(url, waitUntilEnd, generation);
        if (generation !== playbackGeneration) return false;
        if (ok) return true;
      }

      // 2) URLが無い／失敗時のみブラウザTTS（短時間）。マイク使用後は使わない。
      if (text && !micWasUsed) {
        await waitMs(200);
        var spoken = await speakWithBrowser(text, waitUntilEnd, generation);
        if (generation !== playbackGeneration) return false;
        if (spoken) return true;
      }

      setAvatarState('listening');
      if (replayBtn) replayBtn.textContent = '🔊 タップして音声を再生';
      return false;
    }

    async function replayQuestionAudio() {
      unlockAudioPlayback();
      clearError();
      hardStopSpeechRecognition();
      await waitMs(200);
      setStatus('音声を再生中...');
      setSubmitButtonState('questioning');
      setVoiceControlsForQuestioning(true);
      var played = await playSpokenContent({
        text: lastSpokenText || (currentQuestion && currentQuestion.question_text) || '',
        audioUrl: lastAudioUrl || (currentQuestion && currentQuestion.audio_url) || null,
        waitUntilEnd: true
      });
      setStatus(played ? '回答を入力してください' : '再生に失敗しました。もう一度お試しください。');
      setSubmitButtonState('ready');
      setVoiceControlsForQuestioning(false);
    }

    function getSpeechRecognition() {
      var Ctor = window.SpeechRecognition || window.webkitSpeechRecognition;
      return Ctor ? new Ctor() : null;
    }

    var voiceListening = false;
    var voiceFinalText = '';
    var voiceMediaRecorder = null;
    var voiceRecordedChunks = [];
    var voiceRecordedBlob = null;
    var voiceRestartTimer = null;

    function pauseInterviewerAudio() {
      stopBrowserSpeech();
      if (questionAudio) {
        try { questionAudio.pause(); } catch (e) {}
      }
    }

    async function startVoiceAnswer() {
      clearError();
      pauseInterviewerAudio();
      hardStopSpeechRecognition();
      playbackGeneration += 1; // 進行中の再生を無効化

      if (!interviewId) {
        showError('面接が開始されていません。');
        return;
      }

      micWasUsed = true;
      voiceListening = true;
      voiceFinalText = (byId('text_answer').value || '').trim();
      voiceRecordedChunks = [];
      voiceRecordedBlob = null;

      if (voiceStatus) voiceStatus.textContent = 'マイク準備中…';
      if (voiceStartBtn) voiceStartBtn.disabled = true;
      if (voiceStopBtn) voiceStopBtn.disabled = false;
      setAvatarState('listening');

      try {
        await startVoiceRecording();
      } catch (e) {
        voiceListening = false;
        if (voiceStartBtn) voiceStartBtn.disabled = false;
        if (voiceStopBtn) voiceStopBtn.disabled = true;
        showError('マイクを開始できませんでした。ブラウザのマイク許可を確認してください。');
        if (voiceStatus) voiceStatus.textContent = 'マイク開始に失敗しました';
        return;
      }

      // SpeechRecognition は後続の HTML Audio 再生を壊す（Chrome既知）ため使わない。
      // 録音 → サーバーSTT のみで進める。
      if (voiceStatus) {
        voiceStatus.textContent = '録音中です。回答を話してください。終わったら「録音を止める」を押します。';
      }
    }

    async function startVoiceRecording() {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('mediaDevices unavailable');
      }
      var stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      var mime = MediaRecorder.isTypeSupported('audio/webm;codecs=opus')
        ? 'audio/webm;codecs=opus'
        : (MediaRecorder.isTypeSupported('audio/webm') ? 'audio/webm' : '');
      voiceMediaRecorder = mime ? new MediaRecorder(stream, { mimeType: mime }) : new MediaRecorder(stream);
      voiceRecordedChunks = [];
      voiceMediaRecorder._interviewStream = stream;
      voiceMediaRecorder.ondataavailable = function(e) {
        if (e.data && e.data.size > 0) voiceRecordedChunks.push(e.data);
      };
      voiceMediaRecorder.start(250);
    }

    function stopVoiceRecordingAndWait() {
      return new Promise(function(resolve) {
        if (!voiceMediaRecorder || voiceMediaRecorder.state === 'inactive') {
          resolve();
          return;
        }
        var stream = voiceMediaRecorder._interviewStream;
        voiceMediaRecorder.onstop = function() {
          if (stream) stream.getTracks().forEach(function(t) { t.stop(); });
          if (!voiceRecordedChunks.length) {
            voiceRecordedBlob = null;
          } else {
            voiceRecordedBlob = new Blob(voiceRecordedChunks, {
              type: voiceMediaRecorder.mimeType || 'audio/webm'
            });
          }
          resolve();
        };
        try {
          voiceMediaRecorder.stop();
        } catch (e) {
          if (stream) stream.getTracks().forEach(function(t) { t.stop(); });
          resolve();
        }
      });
    }

    function startVoiceRecognitionLoop() {
      // 無効化: SpeechRecognition と speechSynthesis/HTMLAudio の競合を避ける
      return;
    }

    async function stopVoiceAnswer() {
      if (!voiceListening && !voiceMediaRecorder) return;
      voiceListening = false;
      clearTimeout(voiceRestartTimer);

      hardStopSpeechRecognition();

      if (voiceStatus) voiceStatus.textContent = '録音を停止して文字起こししています…';
      if (voiceStopBtn) voiceStopBtn.disabled = true;

      await stopVoiceRecordingAndWait();

      if (voiceRecordedBlob && voiceRecordedBlob.size > 0) {
        recordedBlob = voiceRecordedBlob;
      }

      var textEl = byId('text_answer');

      if (!voiceRecordedBlob || voiceRecordedBlob.size < 1000) {
        showError('音声を十分に取得できませんでした。もう一度「音声で回答」から話してください。');
        if (voiceStatus) voiceStatus.textContent = '音声未検出';
        if (voiceStartBtn) voiceStartBtn.disabled = false;
        return;
      }

      try {
        var form = new FormData();
        var cleanBlob = new Blob([voiceRecordedBlob], { type: 'audio/webm' });
        form.append('audio_file', cleanBlob, 'answer.webm');
        var result = await apiRequest('/api/interviews/' + interviewId + '/transcribe', {
          method: 'POST',
          body: form
        });
        var data = result.data;
        if (!data.success || !data.transcript) {
          var failMsg = data.error || '文字起こしに失敗しました。テキストで入力するか、もう一度録音してください。';
          showError(failMsg);
          if (voiceStatus) voiceStatus.textContent = '文字起こし失敗（詳細は上部メッセージ）';
          if (voiceStartBtn) voiceStartBtn.disabled = false;
          return;
        }
        if (textEl) textEl.value = data.transcript;
        recordedBlob = voiceRecordedBlob;
        if (voiceStatus) {
          voiceStatus.textContent = '文字起こし完了。内容を確認して「回答を送信」を押してください。';
        }
      } catch (e) {
        showError(e.message);
        if (voiceStatus) voiceStatus.textContent = '文字起こしエラー';
      } finally {
        if (voiceStartBtn) voiceStartBtn.disabled = false;
      }
    }

    function renderOptions(options) {
      if (!mcqOptions) return;
      mcqOptions.innerHTML = '';
      selectedOption = null;
      var choices = options && (options.choices || options);
      if (!choices || !choices.length) return;

      choices.forEach(function(choice) {
        var btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'interview-room__mcq-option';
        btn.textContent = choice;
        btn.addEventListener('click', function() {
          selectedOption = choice;
          mcqOptions.querySelectorAll('.interview-room__mcq-option').forEach(function(b) {
            b.classList.remove('is-selected');
          });
          btn.classList.add('is-selected');
        });
        mcqOptions.appendChild(btn);
      });
    }

    async function refreshStatus() {
      if (!interviewId) return;
      try {
        var result = await apiRequest('/api/interviews/' + interviewId + '/status', {});
        var data = result.data;
        if (!data.success || !data.state) return;
        var state = data.state;
        setProgress(state.progress, state.answered_questions, state.total_questions);
      } catch (e) {
        // ignore
      }
    }

    async function submitAnswer() {
      if (isSubmitting) return;
      if (!interviewId) {
        showError('面接が開始されていません。最初からやり直してください。');
        return;
      }
      if (!currentQuestion || !currentQuestion.question_id) {
        showError('質問の読み込みが完了していません。数秒待つか、ページを再読み込みしてください。');
        return;
      }

      var textAnswer = (byId('text_answer').value || '').trim();
      var hasRecording = recordedBlob !== null && recordedBlob.size > 0;
      var hasSelection = !!selectedOption;

      if (!textAnswer && !hasRecording && !hasSelection) {
        showError('回答を入力してください（テキストまたは音声）。');
        return;
      }

      isSubmitting = true;
      clearError();
      setSubmitButtonState('submitting');
      setStatus('回答を送信しています...');

      var form = new FormData();
      form.append('question_id', currentQuestion.question_id);
      if (hasSelection) form.append('selected_option', selectedOption);
      if (textAnswer) form.append('text_answer', textAnswer);
      if (hasRecording) form.append('audio_file', recordedBlob, 'recording.webm');

      try {
        var result = await apiRequest('/api/interviews/' + interviewId + '/submit_answer', {
          method: 'POST',
          body: form
        });
        var data = result.data;
        if (!data.success) {
          showError(data.error || '回答の送信に失敗しました。');
          setSubmitButtonState('ready');
          return;
        }

        hardStopSpeechRecognition();
        stopBrowserSpeech();
        setSubmitButtonState('questioning');
        setVoiceControlsForQuestioning(true);
        setStatus('次の質問を読み込み中...');
        await loadNextQuestion();
      } catch (e) {
        showError(e.message || '回答の送信に失敗しました。');
        setSubmitButtonState('ready');
      } finally {
        isSubmitting = false;
        if (submitBtn && submitBtn.textContent === '送信中...') {
          setSubmitButtonState('ready');
        }
      }
    }

    async function completeInterview() {
      if (!interviewId) return;
      clearError();
      setStatus('結果を確定しています...');

      var attempts = 0;
      var maxAttempts = 20;

      while (attempts < maxAttempts) {
        attempts += 1;
        try {
          var result = await apiRequest('/api/interviews/' + interviewId + '/complete', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
          });
          var data = result.data;

          if (data.success) {
            clearSession();
            showPhase('result');
            displayResults(data);
            return;
          }

          if (data.error && data.error.indexOf('pending evaluation') !== -1) {
            setStatus('評価処理中... (' + attempts + '/' + maxAttempts + ')');
            await sleep(1000);
            continue;
          }

          showError(data.error || '結果の確定に失敗しました。');
          return;
        } catch (e) {
          showError(e.message);
          return;
        }
      }

      showError('評価の完了待ちがタイムアウトしました。ページを再読み込みして再度お試しください。');
    }

    function sleep(ms) {
      return new Promise(function(resolve) { setTimeout(resolve, ms); });
    }

    function fillList(el, items) {
      if (!el) return;
      el.innerHTML = '';
      (items || []).forEach(function(item) {
        var li = document.createElement('li');
        li.textContent = item;
        el.appendChild(li);
      });
      if (!items || !items.length) {
        var empty = document.createElement('li');
        empty.textContent = '—';
        el.appendChild(empty);
      }
    }

    function displayResults(data) {
      var result = data.result || {};
      var visibility = result.candidate_result_visibility || data.candidate_result_visibility || 'immediate';
      var hideFromCandidate = visibility === 'hidden';
      var finalStatus = result.final_status || '-';
      var isPendingReview = finalStatus === 'pending_review';
      var failureReason = result.failure_reason || result.rejection_reason || '';

      if (hideFromCandidate) {
        if (resultStatus) {
          resultStatus.textContent = '面接情報を受け付けました。結果は後日ご連絡します。';
        }
        if (resultDetails) resultDetails.hidden = true;
        return;
      }

      if (resultDetails) resultDetails.hidden = false;

      if (resultStatus) {
        if (isPendingReview) {
          resultStatus.textContent = '面接情報を受け付けました。結果は確認後にご連絡します。';
        } else if (finalStatus === 'failed' && failureReason) {
          resultStatus.textContent = '面接が完了しました。平均点とは別に、設定した不合格条件に該当しました。';
        } else {
          resultStatus.textContent = data.message || '面接が完了しました。';
        }
      }

      if (resultFinal) {
        resultFinal.textContent = finalStatus === 'passed' ? '合格'
          : finalStatus === 'failed' ? '不合格'
          : finalStatus === 'pending_review' ? '確認待ち'
          : finalStatus;
        resultFinal.className = 'interview-room__score-value is-' + finalStatus;
      }

      var avgScore = result.average_score;
      if (resultAvg) {
        if (isPendingReview) {
          resultAvg.textContent = '—';
        } else {
          resultAvg.textContent = avgScore != null ? Number(avgScore).toFixed(1) + ' / 100' : '-';
        }
      }
      if (resultQs) {
        resultQs.textContent = (result.answered_questions || 0) + ' / ' + (result.total_questions || 0) + ' 問';
      }

      if (resultFailurePanel && resultFailureReason) {
        if (finalStatus === 'failed' && failureReason) {
          resultFailurePanel.hidden = false;
          resultFailureReason.textContent = failureReason;
        } else {
          resultFailurePanel.hidden = true;
          resultFailureReason.textContent = '';
        }
      }

      if (resultSummary) resultSummary.textContent = result.summary || '—';
      fillList(resultStrengths, result.strengths);
      fillList(resultWeaknesses, result.weaknesses);
      if (resultRecommendation) resultRecommendation.textContent = result.recommendation || '—';
    }

    if (enterBtn) enterBtn.onclick = enterRoom;
    if (startBtn) startBtn.onclick = startInterview;
    if (submitBtn) submitBtn.onclick = submitAnswer;
    if (replayBtn) replayBtn.onclick = replayQuestionAudio;
    if (voiceStartBtn) voiceStartBtn.onclick = startVoiceAnswer;
    if (voiceStopBtn) voiceStopBtn.onclick = stopVoiceAnswer;
    if (confirmCompleteBtn) {
      confirmCompleteBtn.onclick = async function() {
        if (confirmCompleteBtn.disabled) return;
        confirmCompleteBtn.disabled = true;
        confirmCompleteBtn.textContent = '送信中...';
        try {
          await completeInterview();
        } finally {
          confirmCompleteBtn.disabled = false;
          confirmCompleteBtn.textContent = '面接情報を送信する';
        }
      };
    }

    restoreToken();
    setAvatarState('idle');
    showPhase('identity');
  }

  function boot() {
    var root = document.querySelector('.interview-room');
    if (root) root.removeAttribute('data-interview-bound');
    initInterviewRoom();
  }

  if (document.readyState !== 'loading') boot();
  else document.addEventListener('DOMContentLoaded', boot);
  document.addEventListener('turbo:load', boot);
  document.addEventListener('turbolinks:load', boot);
  document.addEventListener('turbo:before-cache', function() {
    var root = document.querySelector('.interview-room');
    if (root) root.removeAttribute('data-interview-bound');
  });
})();
