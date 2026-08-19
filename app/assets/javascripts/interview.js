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
    // 未指定時は現状どおり両方可（後方互換）
    var allowTextAnswer = root.getAttribute('data-allow-text') !== '0';
    var allowVoiceAnswer = root.getAttribute('data-allow-voice') !== '0';
    var recordCamera = root.getAttribute('data-record-camera') === '1';
    var previewMode = root.getAttribute('data-preview') === '1';
    var skipRegistration = root.getAttribute('data-skip-registration') === '1';
    var enableSatisfaction = root.getAttribute('data-enable-satisfaction') === '1';
    var candidateExtra = {};

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
    var questionCount = byId('question_count');
    var progressBar = byId('progress_bar');
    var questionText = byId('question_text');
    var questionAudio = byId('question_audio');
    var mcqOptions = byId('mcq_options');
    var interviewChat = byId('interview_chat');
    var avatarStage = byId('avatar_stage');
    var avatarStateLabel = byId('avatar_state_label');
    var replayBtn = byId('replay_question');
    var voiceStartBtn = byId('voice_answer_start');
    var voiceStopBtn = byId('voice_answer_stop');
    var voiceStatus = byId('voice_answer_status');
    var textAnswerBlock = byId('text_answer_block');
    var voiceAnswerBlock = byId('voice_answer_block');
    var textAnswerLabel = byId('text_answer_label');
    var answerStage = byId('answer_stage');
    var answerActionHint = byId('answer_action_hint');
    var answerModePicker = byId('answer_mode_picker');
    var answerModeTextBtn = byId('answer_mode_text');
    var answerModeVoiceBtn = byId('answer_mode_voice');
    var answerInputMode = null; // 'text' | 'voice' | 'both' | null
    var candidateCameraEl = byId('candidate_camera');
    var candidateCameraPreview = byId('candidate_camera_preview');
    var candidateCameraRec = byId('candidate_camera_rec');
    var cameraRetryBtn = byId('camera_retry_btn');
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
    var recordedVideoBlob = null;
    var cameraStream = null;
    var videoMediaRecorder = null;
    var videoRecordedChunks = [];
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
    // ユーザーが停止したら進行中の TTS / 再生コールバックだけ無効化する
    var playbackStoppedByUser = false;
    var pendingAfterGreeting = null;
    // 案内の再生中／停止中は質問取得に進ませない（停止ボタン誤作動の保険）
    var greetingBlocksAdvance = false;
    // マイク／SpeechRecognition 使用後はブラウザTTSが壊れやすい（Chrome既知）
    var micWasUsed = false;
    var voiceListening = false;
    var voiceFinalText = '';
    var lastVoiceTranscript = '';
    var voiceMediaRecorder = null;
    var voiceRecordedChunks = [];
    var voiceRecordedBlob = null;
    var voiceRestartTimer = null;
    var voiceStopBusy = false;
    var voiceSession = 0;

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
      if (!statusEl) return;
      if (!msg) {
        statusEl.hidden = true;
        statusEl.textContent = '';
        return;
      }
      statusEl.hidden = false;
      statusEl.textContent = msg;
    }

    function clearStatus() {
      setStatus('');
    }

    function setProgress(progress, answered, total) {
      if (progressBar) progressBar.style.width = Math.max(0, Math.min(100, progress || 0)) + '%';
      if (questionCount) {
        questionCount.textContent = (answered || 0) + '/' + (total || 0);
      }
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
      var timeoutMs = options.timeoutMs;
      if (Object.prototype.hasOwnProperty.call(options, 'timeoutMs')) {
        options = Object.assign({}, options);
        delete options.timeoutMs;
      }
      options.headers = authHeaders(options.headers || {});

      var controller = null;
      var abortTimer = null;
      if (timeoutMs && typeof AbortController !== 'undefined' && !options.signal) {
        controller = new AbortController();
        options.signal = controller.signal;
        abortTimer = setTimeout(function() { controller.abort(); }, timeoutMs);
      }

      var res;
      try {
        res = await fetch(url, options);
      } catch (netErr) {
        if (netErr && netErr.name === 'AbortError') {
          throw new Error('リクエストがタイムアウトしました。もう一度お試しください。');
        }
        throw new Error('ネットワークエラー: ' + netErr.message);
      } finally {
        if (abortTimer) clearTimeout(abortTimer);
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
      if (previewMode || skipRegistration) {
        candidateName = previewMode ? 'プレビュー' : '';
        candidateEmail = '';
        candidateTel = '';
        candidateAddress = '';
        candidateExtra = {};
        // 入室クリック時点で許可ダイアログを出す（後続API待ちだと出ない）
        if (recordCamera) ensureCameraPreview({ quiet: true });
        showPhase('overlay');
        return;
      }

      var missing = [];
      candidateExtra = {};
      root.querySelectorAll('[data-candidate-field]').forEach(function(input) {
        var key = input.getAttribute('data-candidate-field');
        var val = (input.value || '').trim();
        if (input.getAttribute('data-required') === '1' && !val) {
          missing.push(key);
        }
        if (key === 'name') candidateName = val;
        else if (key === 'email') candidateEmail = val;
        else if (key === 'tel') candidateTel = val;
        else if (key === 'address') candidateAddress = val;
        else candidateExtra[key] = val;
      });
      if (missing.length) {
        showError('必須項目を入力してください。');
        return;
      }
      if (recordCamera) ensureCameraPreview({ quiet: true });
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

      // API待ちの後だとユーザージェスチャが切れ、許可ダイアログが出ないことがある
      if (recordCamera) {
        await ensureCameraPreview({ quiet: true });
      }

      var language = (byId('language') && byId('language').value) || defaultLanguage;

      try {
        var result = await apiRequest('/api/interviews/start', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            situation_id: situationId,
            invite_token: inviteToken,
            language: language,
            preview: previewMode,
            candidate_name: candidateName,
            candidate_email: candidateEmail,
            candidate_tel: candidateTel,
            candidate_address: candidateAddress,
            candidate_job_title: candidateExtra.job_title || '',
            candidate_company: candidateExtra.company || '',
            candidate_url: candidateExtra.url || ''
          })
        });
        var data = result.data;

        if (data.reason === 'monthly_limit') {
          showError(data.error || '今月の面接上限に達しています。');
          showPhase('identity');
          startBtn.disabled = false;
          startBtn.textContent = '面接を開始';
          return;
        }

        if (data.reason === 'already_completed') {
          showPhase('result');
          displayResults({
            message: 'この面接は既に受験済みです。同じ面接は1回のみ受験できます。',
            result: { final_status: 'completed' }
          });
          return;
        }

        if (data.reason === 'no_questions') {
          showError(data.error || '出題できる質問がありません。');
          showPhase('identity');
          startBtn.disabled = false;
          startBtn.textContent = '面接を開始';
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
        applyAnswerSettingsFromApi(data.answer_settings);
        saveSession(interviewId, interviewLanguage, data.access_token);
        showPhase('room');
        if (startBtn) {
          startBtn.disabled = false;
          startBtn.textContent = '面接を開始';
        }
        if (recordCamera && !cameraStream) {
          await ensureCameraPreview();
        } else if (recordCamera && cameraStream && candidateCameraEl) {
          candidateCameraEl.hidden = false;
          if (cameraRetryBtn) cameraRetryBtn.hidden = true;
        }

        var greetingText = (data.greeting && data.greeting.text) || '';
        if (greetingText) {
          if (questionText) questionText.textContent = greetingText;
          appendChatMessage('ai', greetingText);
          hideAnswerStage();
          greetingBlocksAdvance = true;
          var greetingFinished = await playSpokenContent({
            text: greetingText,
            audioUrl: (data.greeting && data.greeting.audio_url) || null,
            waitUntilEnd: true,
            keepControl: true
          });
          if (!greetingFinished) {
            pendingAfterGreeting = function() {
              greetingBlocksAdvance = false;
              waitMs(150).then(function() { return loadNextQuestion(); });
            };
            bindManualAudioHandlers();
            setPlayButtonVisible(true);
            setPlayButtonPlaying(false);
            setAvatarState('listening');
            clearStatus();
            return;
          }
          greetingBlocksAdvance = false;
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
      if (greetingBlocksAdvance) return false;
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
          var errMsg = data.error || '';
          if (data.reason === 'no_questions') {
            showError(errMsg || '出題できる質問がありません。');
            return false;
          }
          // 自動不合格などでセッション終了済みの場合は結果へ
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
        clearAnswerForm();
        var order = currentQuestion.order || 0;
        var total = currentQuestion.total_questions || 0;

        if (questionText) questionText.textContent = currentQuestion.question_text || '（質問文なし）';
        appendChatMessage('ai', currentQuestion.question_text || '（質問文なし）');

        var answered = order ? Math.max(0, order - 1) : 0;
        setProgress(total ? (answered / total) * 100 : 0, answered, total);

        revealAnswerStage();
        beginAnswerCapture();
        refreshStatus().catch(function() {});

        setStatus('質問を再生中...');
        await preparePlaybackAfterMic();
        playSpokenContent({
          text: currentQuestion.question_text || '',
          audioUrl: currentQuestion.audio_url,
          waitUntilEnd: true,
          keepControl: true
        }).then(function() {
          clearStatus();
        }).catch(function() {
          clearStatus();
        });
        return true;
      } catch (e) {
        showError(e.message || '質問の取得に失敗しました。');
        revealAnswerStage();
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
      if (state === 'questioning') {
        submitBtn.hidden = false;
        submitBtn.disabled = true;
        submitBtn.textContent = '質問中';
      } else if (state === 'submitting') {
        submitBtn.hidden = false;
        submitBtn.disabled = true;
        submitBtn.textContent = '送信中...';
      } else {
        // ready
        submitBtn.hidden = false;
        submitBtn.disabled = false;
        submitBtn.textContent = '回答を送信';
      }
    }

    function currentQuestionHasOptions() {
      if (!currentQuestion) return false;
      var options = currentQuestion.options;
      var choices = options && (options.choices || options);
      return !!(choices && choices.length);
    }

    function hideAnswerStage() {
      answerInputMode = null;
      if (answerStage) answerStage.hidden = true;
      if (answerModePicker) answerModePicker.hidden = true;
      if (textAnswerBlock) textAnswerBlock.hidden = true;
      if (voiceAnswerBlock) voiceAnswerBlock.hidden = true;
      if (voiceStatus) voiceStatus.textContent = '';
      setSubmitButtonState('questioning');
      setAnswerActionHint('');
      renderOptions(null);
    }

    function setVoiceControlsMode(mode) {
      if (voiceStartBtn) {
        voiceStartBtn.hidden = !(mode === 'idle');
        voiceStartBtn.disabled = mode !== 'idle';
      }
      if (voiceStopBtn) {
        voiceStopBtn.hidden = !(mode === 'recording');
        voiceStopBtn.disabled = mode !== 'recording';
      }
      if (mode === 'recording' || mode === 'idle') {
        if (voiceAnswerBlock) voiceAnswerBlock.hidden = false;
        if (mode === 'idle' && voiceStartBtn) {
          voiceStartBtn.textContent = '🎤 音声で回答';
        }
      } else if (voiceAnswerBlock) {
        voiceAnswerBlock.hidden = true;
      }
    }

    function showTextAnswerUi() {
      answerInputMode = 'text';
      if (answerModePicker) answerModePicker.hidden = true;
      if (textAnswerBlock) textAnswerBlock.hidden = false;
      setVoiceControlsMode('off');
      var textEl = byId('text_answer');
      if (textEl) {
        textEl.readOnly = false;
        textEl.placeholder = 'テキストで回答してください';
      }
      if (textAnswerLabel) textAnswerLabel.textContent = 'あなたの回答';
      setSubmitButtonState('ready');
      setAnswerActionHint('');
    }

    function showVoiceAnswerUi() {
      answerInputMode = 'voice';
      if (answerModePicker) answerModePicker.hidden = true;
      if (textAnswerBlock) textAnswerBlock.hidden = true;
      setVoiceControlsMode('idle');
      if (voiceStatus) voiceStatus.textContent = '';
      setSubmitButtonState('ready');
      setAnswerActionHint(interviewLanguage === 'en' ? 'Record your answer, then submit.' : '録音してから送信してください。');
    }

    function showBothAnswerUi() {
      answerInputMode = 'both';
      if (answerModePicker) answerModePicker.hidden = true;
      if (textAnswerBlock) textAnswerBlock.hidden = false;
      setVoiceControlsMode('idle');
      var textEl = byId('text_answer');
      if (textEl) {
        textEl.readOnly = false;
        textEl.placeholder = 'テキスト入力、または下のボタンで音声回答';
      }
      if (textAnswerLabel) textAnswerLabel.textContent = 'あなたの回答';
      if (voiceStatus) voiceStatus.textContent = '';
      setSubmitButtonState('ready');
      setAnswerActionHint('');
    }

    function showAnswerModePicker() {
      showBothAnswerUi();
    }

    function beginAnswerCapture() {
      if (recordCamera) {
        startAnswerVideoRecording().catch(function() {});
      }
    }

    function revealAnswerStage() {
      if (!answerStage) return;
      answerStage.hidden = false;
      clearStatus();

      var hasOptions = currentQuestionHasOptions();
      renderOptions(hasOptions ? currentQuestion.options : null);

      if (hasOptions) {
        if (answerModePicker) answerModePicker.hidden = true;
        if (textAnswerBlock) textAnswerBlock.hidden = true;
        setVoiceControlsMode('off');
        setSubmitButtonState('ready');
        setAnswerActionHint(interviewLanguage === 'en' ? 'Select an option, then submit.' : '選択肢を選んで送信してください。');
        return;
      }

      if (allowTextAnswer && allowVoiceAnswer) {
        showAnswerModePicker();
        return;
      }
      if (allowTextAnswer) {
        showTextAnswerUi();
        return;
      }
      if (allowVoiceAnswer) {
        showVoiceAnswerUi();
        return;
      }

      showError('回答方法が設定されていません。管理者に連絡してください。');
    }

    function setVoiceControlsForQuestioning(isQuestioning) {
      if (isQuestioning) {
        setSubmitButtonState('questioning');
        if (voiceStartBtn) voiceStartBtn.disabled = true;
        if (voiceStopBtn) voiceStopBtn.disabled = true;
      } else {
        revealAnswerStage();
      }
    }

    function setAnswerActionHint(msg) {
      if (!answerActionHint) return;
      answerActionHint.textContent = '';
      answerActionHint.hidden = true;
    }

    function applyAnswerModeUi() {
      hideAnswerStage();
    }

    function applyAnswerSettingsFromApi(settings) {
      if (!settings) return;
      if (typeof settings.allow_text_answer === 'boolean') allowTextAnswer = settings.allow_text_answer;
      if (typeof settings.allow_voice_answer === 'boolean') allowVoiceAnswer = settings.allow_voice_answer;
      if (typeof settings.record_camera === 'boolean') recordCamera = settings.record_camera;
    }

    function showCameraRetryUi(message) {
      if (candidateCameraEl) candidateCameraEl.hidden = false;
      if (cameraRetryBtn) cameraRetryBtn.hidden = false;
      if (message) showError(message);
    }

    async function ensureCameraPreview(opts) {
      opts = opts || {};
      if (!recordCamera) return false;
      if (cameraStream) {
        var live = cameraStream.getTracks().some(function(t) { return t.readyState === 'live'; });
        if (live) {
          if (candidateCameraEl) candidateCameraEl.hidden = false;
          if (cameraRetryBtn) cameraRetryBtn.hidden = true;
          return true;
        }
        stopCameraPreview();
      }
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        if (!opts.quiet) showError('このブラウザではカメラを利用できません。');
        showCameraRetryUi();
        return false;
      }
      try {
        // 音声マイク経路と競合しないよう、カメラは映像のみ取得する
        cameraStream = await navigator.mediaDevices.getUserMedia({
          video: { facingMode: 'user' },
          audio: false
        });
        if (candidateCameraPreview) {
          candidateCameraPreview.srcObject = cameraStream;
          try { await candidateCameraPreview.play(); } catch (e) {}
        }
        if (candidateCameraEl) candidateCameraEl.hidden = false;
        if (cameraRetryBtn) cameraRetryBtn.hidden = true;
        clearError();
        return true;
      } catch (e) {
        var denied = e && (e.name === 'NotAllowedError' || e.name === 'PermissionDeniedError');
        var msg = denied
          ? 'カメラが拒否されています。アドレスバー左のサイト設定からカメラを「許可」にし、「カメラを再試行」を押してください。'
          : 'カメラを開始できませんでした。ブラウザのカメラ許可を確認し、「カメラを再試行」を押してください。';
        if (!opts.quiet) showCameraRetryUi(msg);
        else showCameraRetryUi();
        return false;
      }
    }

    function stopCameraPreview() {
      stopAnswerVideoRecordingSync();
      if (cameraStream) {
        cameraStream.getTracks().forEach(function(t) { t.stop(); });
        cameraStream = null;
      }
      if (candidateCameraPreview) candidateCameraPreview.srcObject = null;
      if (candidateCameraEl) candidateCameraEl.hidden = true;
      if (candidateCameraRec) candidateCameraRec.hidden = true;
      if (cameraRetryBtn) cameraRetryBtn.hidden = true;
    }

    function pickVideoMimeType() {
      if (!window.MediaRecorder) return '';
      if (MediaRecorder.isTypeSupported('video/webm;codecs=vp9,opus')) return 'video/webm;codecs=vp9,opus';
      if (MediaRecorder.isTypeSupported('video/webm;codecs=vp8,opus')) return 'video/webm;codecs=vp8,opus';
      if (MediaRecorder.isTypeSupported('video/webm')) return 'video/webm';
      return '';
    }

    function pickAudioMimeType() {
      if (!window.MediaRecorder) return '';
      var candidates = [
        'audio/webm;codecs=opus',
        'audio/webm',
        'audio/mp4',
        'audio/aac',
        'audio/ogg;codecs=opus'
      ];
      for (var i = 0; i < candidates.length; i++) {
        if (MediaRecorder.isTypeSupported(candidates[i])) return candidates[i];
      }
      return '';
    }

    function normalizeAudioMime(type) {
      type = String(type || '').split(';')[0].trim().toLowerCase();
      if (!type || type === 'application/octet-stream') return 'audio/webm';
      return type;
    }

    function audioFilenameForType(type) {
      type = normalizeAudioMime(type);
      if (type.indexOf('mp4') !== -1 || type.indexOf('aac') !== -1 || type.indexOf('m4a') !== -1) return 'answer.m4a';
      if (type.indexOf('ogg') !== -1) return 'answer.ogg';
      if (type.indexOf('wav') !== -1) return 'answer.wav';
      if (type.indexOf('mpeg') !== -1 || type.indexOf('mp3') !== -1) return 'answer.mp3';
      return 'answer.webm';
    }

    async function startAnswerVideoRecording() {
      if (!recordCamera) return;
      recordedVideoBlob = null;
      videoRecordedChunks = [];
      var ok = await ensureCameraPreview();
      if (!ok || !cameraStream) return;
      if (!window.MediaRecorder) return;
      if (videoMediaRecorder && videoMediaRecorder.state !== 'inactive') return;

      var mime = pickVideoMimeType();
      try {
        videoMediaRecorder = mime
          ? new MediaRecorder(cameraStream, { mimeType: mime })
          : new MediaRecorder(cameraStream);
      } catch (e) {
        videoMediaRecorder = null;
        return;
      }
      videoMediaRecorder.ondataavailable = function(e) {
        if (e.data && e.data.size > 0) videoRecordedChunks.push(e.data);
      };
      try {
        videoMediaRecorder.start(500);
        if (candidateCameraRec) candidateCameraRec.hidden = false;
      } catch (e2) {
        videoMediaRecorder = null;
      }
    }

    function stopAnswerVideoRecordingSync() {
      if (!videoMediaRecorder) return;
      try {
        if (videoMediaRecorder.state !== 'inactive') videoMediaRecorder.stop();
      } catch (e) {}
      videoMediaRecorder = null;
      if (candidateCameraRec) candidateCameraRec.hidden = true;
    }

    function stopAnswerVideoRecordingAndWait() {
      return new Promise(function(resolve) {
        var finished = false;
        var recorder = videoMediaRecorder;

        function finish() {
          if (finished) return;
          finished = true;
          clearTimeout(safetyTimer);
          if (videoRecordedChunks.length) {
            recordedVideoBlob = new Blob(videoRecordedChunks, {
              type: (recorder && recorder.mimeType) || 'video/webm'
            });
          }
          if (recorder) {
            try { recorder.onstop = null; } catch (e) {}
          }
          videoMediaRecorder = null;
          if (candidateCameraRec) candidateCameraRec.hidden = true;
          resolve();
        }

        var safetyTimer = setTimeout(function() {
          try {
            if (recorder && recorder.state !== 'inactive') recorder.stop();
          } catch (e) {}
          finish();
        }, 2000);

        if (!recorder || recorder.state === 'inactive') {
          finish();
          return;
        }

        recorder.onstop = finish;
        try {
          if (typeof recorder.requestData === 'function' && recorder.state === 'recording') {
            recorder.requestData();
          }
          recorder.stop();
        } catch (e) {
          finish();
        }
      });
    }

    function clearAnswerForm() {
      recordedChunks = [];
      recordedBlob = null;
      recordedVideoBlob = null;
      videoRecordedChunks = [];
      selectedOption = null;
      voiceFinalText = '';
      lastVoiceTranscript = '';
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

    function appendChatMessage(role, text) {
      if (!interviewChat || !text) return;
      var empty = interviewChat.querySelector('.interview-cinema__chat-empty');
      if (empty) empty.remove();

      var msg = document.createElement('div');
      msg.className = 'interview-cinema__chat-msg interview-cinema__chat-msg--' + (role === 'user' ? 'user' : 'ai');

      var roleEl = document.createElement('span');
      roleEl.className = 'interview-cinema__chat-msg-role';
      roleEl.textContent = role === 'user' ? 'あなた' : 'AI';

      var body = document.createElement('div');
      body.textContent = text;

      msg.appendChild(roleEl);
      msg.appendChild(body);
      interviewChat.appendChild(msg);
      interviewChat.scrollTop = interviewChat.scrollHeight;
    }

    function currentAnswerPreview() {
      if (selectedOption) return String(selectedOption);
      var textAnswer = ((byId('text_answer') && byId('text_answer').value) || '').trim();
      if (textAnswer) return textAnswer;
      if (lastVoiceTranscript) return lastVoiceTranscript;
      if (recordedBlob && recordedBlob.size > 0) {
        return interviewLanguage === 'en' ? '(Voice answer)' : '（音声回答）';
      }
      return '';
    }

    async function finishInterviewWithClosing() {
      await stopAnswerVideoRecordingAndWait();
      stopCameraPreview();
      var closing = closingMessageText();
      setStatus('面接終了');
      setAvatarState('idle');
      if (questionText) questionText.textContent = closing;
      appendChatMessage('ai', closing);
      hideAnswerStage();
      hidePlayButton();
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
      if (avatarStateLabel) avatarStateLabel.textContent = '';
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

        // hidden のままだとブラウザによっては再生に失敗する
        questionAudio.hidden = false;
        ensureAudioRowVisible();

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
          var stillPlaying = !!(questionAudio && !questionAudio.paused && !questionAudio.ended);
          done(stillPlaying);
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

        var allowPauseAbort = false;
        questionAudio.onpause = function() {
          if (questionAudio.ended) return;
          if (generation != null && generation !== playbackGeneration) {
            done(false);
            return;
          }
          if (allowPauseAbort) done(false);
        };

        function markStarted() {
          if (generation != null && generation !== playbackGeneration) {
            try { questionAudio.pause(); } catch (e) {}
            return;
          }
          if (started) return;
          started = true;
          allowPauseAbort = true;
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
            if (generation != null && generation !== playbackGeneration) {
              try { questionAudio.pause(); } catch (e) {}
            }
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
          if (generation != null && generation !== playbackGeneration) {
            stopBrowserSpeech();
            done(false);
            return;
          }
          started = true;
          clearTimeout(startFailTimer);
          setAvatarState('speaking');
          if (!waitUntilEnd) done(true);
        };
        utter.onend = function() {
          if (playbackStoppedByUser || (generation != null && generation !== playbackGeneration)) {
            done(false);
            return;
          }
          done(true);
        };
        utter.onerror = function() { done(started); };

        try {
          window.speechSynthesis.speak(utter);
        } catch (e) {
          done(false);
        }
      });
    }

    function playControlRoot() {
      if (replayBtn) {
        return replayBtn.closest('.interview-cinema__play-overlay')
          || replayBtn.closest('.interview-cinema__audio-row');
      }
      if (questionAudio) {
        return questionAudio.closest('.interview-cinema__play-overlay')
          || questionAudio.closest('.interview-cinema__audio-row');
      }
      return null;
    }

    function setPlayButtonVisible(visible) {
      if (!replayBtn) return;
      replayBtn.hidden = !visible;
      var root = playControlRoot();
      if (root) root.hidden = !visible;
    }

    function setPlayButtonPlaying(playing) {
      if (!replayBtn) return;
      if (playing) setPlayButtonVisible(true);
      replayBtn.classList.toggle('presentation-play-btn--playing', !!playing);
      replayBtn.setAttribute('aria-label', playing ? '停止' : '再生');
    }

    function hidePlayButton() {
      if (replayBtn) {
        replayBtn.classList.remove('presentation-play-btn--playing');
        replayBtn.setAttribute('aria-label', '再生');
      }
      setPlayButtonVisible(false);
    }

    function isQuestionAudioPlaying() {
      return !!(questionAudio && !questionAudio.paused && !questionAudio.ended);
    }

    function isAudioPlaying() {
      if (isQuestionAudioPlaying()) {
        return true;
      }
      if (window.speechSynthesis && window.speechSynthesis.speaking && !window.speechSynthesis.paused) {
        return true;
      }
      return false;
    }

    function clearQuestionAudioHandlers() {
      if (!questionAudio) return;
      questionAudio.onplay = null;
      questionAudio.onplaying = null;
      questionAudio.onended = null;
      questionAudio.onerror = null;
      questionAudio.onpause = null;
    }

    function ensureAudioRowVisible() {
      if (!questionAudio) return;
      questionAudio.hidden = false;
      var root = playControlRoot();
      if (root) root.hidden = false;
    }

    function continueAfterGreetingIfNeeded() {
      if (!pendingAfterGreeting) return false;
      var fn = pendingAfterGreeting;
      pendingAfterGreeting = null;
      try { fn(); } catch (e) {}
      return true;
    }

    function bindManualAudioHandlers() {
      if (!questionAudio) return;
      clearQuestionAudioHandlers();
      questionAudio.onended = function() {
        setPlayButtonPlaying(false);
        setAvatarState('listening');
        clearStatus();
        continueAfterGreetingIfNeeded();
      };
      questionAudio.onpause = function() {
        if (questionAudio.ended) return;
        setPlayButtonPlaying(false);
        setAvatarState('listening');
      };
    }

    function hasResumableAudio() {
      if (!questionAudio || !questionAudio.paused || questionAudio.ended || questionAudio.currentTime <= 0) {
        return false;
      }
      var src = questionAudio.currentSrc || questionAudio.src || '';
      if (src.indexOf('data:audio/wav') === 0) return false;
      return true;
    }

    function pauseInterviewerAudio() {
      playbackStoppedByUser = true;
      playbackGeneration += 1;
      stopBrowserSpeech();
      if (questionAudio) {
        try { questionAudio.pause(); } catch (e) {}
      }
      setPlayButtonPlaying(false);
      setAvatarState('listening');
    }

    async function playQuestionAudioDirect(url) {
      if (!questionAudio || !url) return false;
      playbackGeneration += 1;
      stopBrowserSpeech();
      ensureAudioRowVisible();
      setPlayButtonVisible(true);
      setPlayButtonPlaying(true);
      setAvatarState('speaking');
      bindManualAudioHandlers();
      try { questionAudio.pause(); } catch (e) {}
      questionAudio.src = url + (url.indexOf('?') >= 0 ? '&' : '?') + 't=' + Date.now();
      try { questionAudio.load(); } catch (e2) {}
      try {
        var playPromise = questionAudio.play();
        if (playPromise && playPromise.then) await playPromise;
        return true;
      } catch (e) {
        setPlayButtonPlaying(false);
        return false;
      }
    }

    async function playSpokenContent(opts) {
      opts = opts || {};
      var text = opts.text || '';
      var url = opts.audioUrl || null;
      var waitUntilEnd = !!opts.waitUntilEnd;
      var keepControl = !!opts.keepControl;
      lastSpokenText = text;
      lastAudioUrl = url;

      playbackStoppedByUser = false;
      playbackGeneration += 1;
      var generation = playbackGeneration;

      stopBrowserSpeech();
      setPlayButtonVisible(true);
      setPlayButtonPlaying(true);

      // 1) サーバーTTS（HTML Audio）を最優先。これが本線。
      if (url) {
        var ok = await playHtmlAudio(url, waitUntilEnd, generation);
        if (generation !== playbackGeneration || playbackStoppedByUser) return false;
        if (ok) {
          setPlayButtonPlaying(false);
          if (!keepControl) hidePlayButton();
          return true;
        }
        // URLがあるのに最後まで再生できなかった＝停止または失敗。
        // ここでブラウザTTSに落とすと「次の再生」が始まる。
        setAvatarState('listening');
        setPlayButtonPlaying(false);
        setPlayButtonVisible(true);
        return false;
      }

      // 2) URLが無いときのみブラウザTTS（短時間）。マイク使用後は使わない。
      if (text && !micWasUsed && !playbackStoppedByUser) {
        await waitMs(200);
        if (generation !== playbackGeneration || playbackStoppedByUser) return false;
        var spoken = await speakWithBrowser(text, waitUntilEnd, generation);
        if (generation !== playbackGeneration || playbackStoppedByUser) return false;
        if (spoken) {
          setPlayButtonPlaying(false);
          if (!keepControl) hidePlayButton();
          return true;
        }
      }

      setAvatarState('listening');
      setPlayButtonPlaying(false);
      setPlayButtonVisible(true);
      return false;
    }

    async function toggleQuestionAudio() {
      clearError();

      var buttonShowsStop = !!(replayBtn && replayBtn.classList.contains('presentation-play-btn--playing'));
      if (isAudioPlaying() || buttonShowsStop) {
        pauseInterviewerAudio();
        clearStatus();
        return;
      }

      stopBrowserSpeech();

      if (hasResumableAudio()) {
        ensureAudioRowVisible();
        setPlayButtonVisible(true);
        setPlayButtonPlaying(true);
        setAvatarState('speaking');
        setStatus('音声を再生中...');
        bindManualAudioHandlers();
        try {
          var resumePromise = questionAudio.play();
          if (resumePromise && resumePromise.then) await resumePromise;
          return;
        } catch (e) {
          setPlayButtonPlaying(false);
        }
      }

      var url = lastAudioUrl || (currentQuestion && currentQuestion.audio_url) || null;
      if (!url) {
        if (continueAfterGreetingIfNeeded()) return;
        setStatus('再生できる音声がありません');
        setPlayButtonVisible(true);
        return;
      }

      hardStopSpeechRecognition();
      setStatus('音声を再生中...');
      var played = await playQuestionAudioDirect(url);
      if (played) {
        clearStatus();
        setPlayButtonVisible(true);
        setPlayButtonPlaying(true);
      } else {
        setStatus('再生に失敗しました。もう一度お試しください。');
        setPlayButtonVisible(true);
        setPlayButtonPlaying(false);
      }
    }

    async function startVoiceAnswer() {
      clearError();
      pauseInterviewerAudio();
      hardStopSpeechRecognition();
      playbackGeneration += 1;

      if (!interviewId) {
        showError('面接が開始されていません。');
        return;
      }

      var session = ++voiceSession;
      micWasUsed = true;
      voiceListening = true;
      voiceFinalText = (byId('text_answer').value || '').trim();
      voiceRecordedChunks = [];
      voiceRecordedBlob = null;

      if (voiceStatus) voiceStatus.textContent = 'マイク準備中…';
      setVoiceControlsMode('recording');
      if (voiceStopBtn) voiceStopBtn.disabled = true;
      if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.textContent = '録音中';
      }
      setAvatarState('listening');

      try {
        await waitMs(250);
        if (session !== voiceSession || !voiceListening) return;
        await startVoiceRecording();
        if (session !== voiceSession || !voiceListening) {
          await stopVoiceRecordingAndWait();
          return;
        }
        if (voiceStopBtn) voiceStopBtn.disabled = false;
      } catch (e) {
        if (session !== voiceSession) return;
        voiceListening = false;
        setVoiceControlsMode('idle');
        setSubmitButtonState('ready');
        showError('マイクを開始できませんでした。ブラウザのマイク許可を確認してください。');
        if (voiceStatus) voiceStatus.textContent = 'マイク開始に失敗しました';
        return;
      }

      if (voiceStatus) {
        voiceStatus.textContent = '録音中です。マイクに向かってはっきり話してください。終わったら「録音を止める」を押します。';
      }
    }

    async function startVoiceRecording() {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('mediaDevices unavailable');
      }
      if (!window.MediaRecorder) {
        throw new Error('MediaRecorder unavailable');
      }
      var stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          channelCount: 1
        }
      });
      var mime = pickAudioMimeType();
      try {
        voiceMediaRecorder = mime ? new MediaRecorder(stream, { mimeType: mime }) : new MediaRecorder(stream);
      } catch (e) {
        voiceMediaRecorder = new MediaRecorder(stream);
      }
      voiceRecordedChunks = [];
      voiceMediaRecorder._interviewStream = stream;
      voiceMediaRecorder.ondataavailable = function(e) {
        if (e.data && e.data.size > 0) voiceRecordedChunks.push(e.data);
      };
      // timeslice なし。Safari では timeslice 指定で onstop が来ず固まることがある
      voiceMediaRecorder.start();
    }

    function stopVoiceRecordingAndWait() {
      return new Promise(function(resolve) {
        var finished = false;
        var recorder = voiceMediaRecorder;
        var stream = recorder && recorder._interviewStream;

        function finish() {
          if (finished) return;
          finished = true;
          clearTimeout(safetyTimer);
          if (stream) {
            try { stream.getTracks().forEach(function(t) { t.stop(); }); } catch (e) {}
          }
          if (recorder) {
            try { recorder.ondataavailable = null; } catch (e1) {}
            try { recorder.onstop = null; } catch (e2) {}
          }
          if (!voiceRecordedChunks.length) {
            voiceRecordedBlob = null;
          } else {
            var type = normalizeAudioMime(
              (recorder && recorder.mimeType) ||
              (voiceRecordedChunks[0] && voiceRecordedChunks[0].type)
            );
            voiceRecordedBlob = new Blob(voiceRecordedChunks, { type: type });
          }
          voiceMediaRecorder = null;
          resolve();
        }

        var safetyTimer = setTimeout(function() {
          try {
            if (recorder && recorder.state !== 'inactive') recorder.stop();
          } catch (e) {}
          finish();
        }, 3000);

        if (!recorder || recorder.state === 'inactive') {
          finish();
          return;
        }

        recorder.onstop = finish;
        try {
          if (recorder.state === 'paused') recorder.resume();
        } catch (e1) {}
        try {
          if (typeof recorder.requestData === 'function' && recorder.state === 'recording') {
            recorder.requestData();
          }
        } catch (e2) {}
        try {
          recorder.stop();
        } catch (e3) {
          finish();
        }
      });
    }

    function startVoiceRecognitionLoop() {
      // 無効化: SpeechRecognition と speechSynthesis/HTMLAudio の競合を避ける
      return;
    }

    async function stopVoiceAnswer() {
      if (voiceStopBusy) return;
      if (!voiceListening && !voiceMediaRecorder) return;
      voiceStopBusy = true;
      voiceSession += 1;
      voiceListening = false;
      clearTimeout(voiceRestartTimer);

      hardStopSpeechRecognition();

      if (voiceStopBtn) voiceStopBtn.disabled = true;

      try {
        if (voiceStatus) voiceStatus.textContent = '録音を停止しています…';
        await stopVoiceRecordingAndWait();

        if (voiceRecordedBlob && voiceRecordedBlob.size > 0) {
          recordedBlob = voiceRecordedBlob;
        }

        if (!voiceRecordedBlob || voiceRecordedBlob.size < 800) {
          showError('音声を十分に取得できませんでした。もう一度録音してください。');
          if (voiceStatus) voiceStatus.textContent = '音声未検出';
          return;
        }

        if (voiceStatus) voiceStatus.textContent = '文字起こししています…（完了を待たずに送信できます）';
        transcribeVoiceBlob(voiceRecordedBlob);
      } catch (e) {
        showError(e.message || '録音の停止に失敗しました。');
        if (voiceStatus) voiceStatus.textContent = '録音停止エラー';
      } finally {
        voiceStopBusy = false;
        setVoiceControlsMode('idle');
        if (!isSubmitting) setSubmitButtonState('ready');
      }
    }

    async function transcribeVoiceBlob(blob) {
      var textEl = byId('text_answer');
      try {
        var mime = normalizeAudioMime(blob.type);
        var form = new FormData();
        form.append('audio_file', blob, audioFilenameForType(mime));
        var result = await apiRequest('/api/interviews/' + interviewId + '/transcribe', {
          method: 'POST',
          body: form,
          timeoutMs: 45000
        });
        var data = result.data;
        if (isSubmitting) return;
        if (!data.success || !data.transcript) {
          if (voiceStatus) {
            voiceStatus.textContent = '文字起こしできませんでした。音声のまま「回答を送信」できます。';
          }
          return;
        }
        if (textEl && allowTextAnswer) textEl.value = data.transcript;
        lastVoiceTranscript = data.transcript || '';
        if (voiceStatus) {
          voiceStatus.textContent = allowTextAnswer
            ? '文字起こし完了。内容を確認して「回答を送信」を押してください。'
            : ('文字起こし: ' + lastVoiceTranscript + '　→「回答を送信」で確定');
        }
      } catch (e) {
        if (isSubmitting) return;
        if (voiceStatus) {
          voiceStatus.textContent = '文字起こしできませんでした。音声のまま「回答を送信」できます。';
        }
      }
    }

    function renderOptions(options) {
      if (!mcqOptions) return;
      mcqOptions.innerHTML = '';
      selectedOption = null;
      var choices = options && (options.choices || options);
      if (!choices || !choices.length) {
        mcqOptions.hidden = true;
        return;
      }

      mcqOptions.hidden = false;
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
          setSubmitButtonState('ready');
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
      if (voiceListening || (voiceMediaRecorder && voiceMediaRecorder.state === 'recording')) {
        showError('先に録音を止めてから送信してください。');
        return;
      }
      if (!interviewId) {
        showError('面接が開始されていません。最初からやり直してください。');
        return;
      }
      if (!currentQuestion || !currentQuestion.question_id) {
        showError('質問の読み込みが完了していません。数秒待つか、ページを再読み込みしてください。');
        return;
      }

      pauseInterviewerAudio();

      var textAnswer = (byId('text_answer').value || '').trim();
      if (!textAnswer && lastVoiceTranscript) {
        textAnswer = lastVoiceTranscript;
      }
      var hasRecording = recordedBlob !== null && recordedBlob.size > 0;
      var hasSelection = !!selectedOption;

      if (!allowTextAnswer && allowVoiceAnswer && !hasRecording && !hasSelection) {
        showError('音声で回答してください。');
        return;
      }
      if (allowTextAnswer && !allowVoiceAnswer && !textAnswer && !hasSelection) {
        showError('テキストで回答を入力してください。');
        return;
      }
      if (!textAnswer && !hasRecording && !hasSelection) {
        showError(allowVoiceAnswer && allowTextAnswer
          ? '回答を入力してください（テキストまたは音声）。'
          : '回答を入力してください。');
        return;
      }
      if (!allowTextAnswer && textAnswer && !hasRecording && !hasSelection) {
        showError('音声で回答してください。');
        return;
      }

      isSubmitting = true;
      clearError();
      setSubmitButtonState('submitting');
      setStatus('回答を送信しています...');

      var answerPreview = currentAnswerPreview();

      await Promise.race([
        stopAnswerVideoRecordingAndWait(),
        waitMs(800)
      ]);
      if (videoMediaRecorder && videoMediaRecorder.state !== 'inactive') {
        stopAnswerVideoRecordingSync();
      }

      var form = new FormData();
      form.append('question_id', currentQuestion.question_id);
      if (hasSelection) form.append('selected_option', selectedOption);
      if (textAnswer) form.append('text_answer', textAnswer);
      if (hasRecording) {
        form.append('audio_file', recordedBlob, audioFilenameForType(recordedBlob.type));
      }
      var textOnlySubmit = !hasRecording && !!(textAnswer || hasSelection);
      if (!textOnlySubmit && recordCamera && recordedVideoBlob && recordedVideoBlob.size > 0 && recordedVideoBlob.size < 8 * 1024 * 1024) {
        form.append('video_file', recordedVideoBlob, 'answer.webm');
      }

      try {
        var result = await apiRequest('/api/interviews/' + interviewId + '/submit_answer', {
          method: 'POST',
          body: form,
          timeoutMs: 100000
        });
        var data = result.data;
        if (!data.success) {
          showError(data.error || '回答の送信に失敗しました。');
          setSubmitButtonState('ready');
          if (recordCamera) startAnswerVideoRecording().catch(function() {});
          return;
        }

        if (answerPreview) appendChatMessage('user', answerPreview);

        hardStopSpeechRecognition();
        stopBrowserSpeech();
        hideAnswerStage();
        setStatus('次の質問を読み込み中...');
        await loadNextQuestion();
      } catch (e) {
        showError(e.message || '回答の送信に失敗しました。');
        setSubmitButtonState('ready');
        if (recordCamera) startAnswerVideoRecording().catch(function() {});
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
      var visibility = result.candidate_result_visibility || data.candidate_result_visibility || 'hidden';
      var hideFromCandidate = visibility !== 'immediate';
      var finalStatus = result.final_status || '-';
      var isPendingReview = finalStatus === 'pending_review';
      var failureReason = result.failure_reason || result.rejection_reason || '';

      if (hideFromCandidate) {
        if (resultStatus) {
          resultStatus.textContent = '面接情報を受け付けました。結果は後日ご連絡します。';
        }
        if (resultDetails) resultDetails.hidden = true;
        if (phaseResult) phaseResult.classList.add('is-complete-only');
        renderPostResultExtras(result);
        return;
      }

      if (phaseResult) phaseResult.classList.remove('is-complete-only');
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

      renderPostResultExtras(result);
    }

    function renderPostResultExtras(result) {
      var jobPanel = byId('result_job_info');
      var jobBody = byId('result_job_info_body');
      if (jobPanel && jobBody && result.job_info) {
        var labels = {
          job_title: '職種',
          employment_type: '雇用形態',
          location: '勤務地',
          salary_text: '給与',
          job_summary: '仕事内容',
          requirements_text: '応募条件',
          selection_flow: '選考の流れ'
        };
        var html = '';
        Object.keys(labels).forEach(function(key) {
          var val = result.job_info[key];
          if (!val) return;
          html += '<div class="interview-job-info-row"><span class="interview-job-info-label">' +
            escapeHtml(labels[key]) + '</span><p class="interview-job-info-value">' +
            escapeHtml(val) + '</p></div>';
        });
        if (html) {
          jobBody.innerHTML = html;
          jobPanel.hidden = false;
        }
      }

      var faqsPanel = byId('result_faqs');
      var faqsList = byId('result_faqs_list');
      if (faqsPanel && faqsList && result.faqs && result.faqs.length) {
        faqsList.innerHTML = '';
        result.faqs.forEach(function(faq) {
          var q = document.createElement('p');
          q.innerHTML = '<strong>' + escapeHtml(faq.question) + '</strong>';
          var a = document.createElement('p');
          a.className = 'interview-room__hint';
          a.textContent = faq.answer || '';
          faqsList.appendChild(q);
          faqsList.appendChild(a);
        });
        faqsPanel.hidden = false;
      }

      var materialsPanel = byId('result_materials');
      var materialsLink = byId('result_materials_link');
      if (materialsPanel && materialsLink && result.materials_url) {
        materialsLink.href = result.materials_url;
        materialsPanel.hidden = false;
      }

      var satPanel = byId('result_satisfaction');
      if (satPanel && enableSatisfaction && !previewMode && !result.preview) {
        satPanel.hidden = false;
      }
    }

    function escapeHtml(str) {
      return String(str || '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
    }

    async function submitSatisfaction(rating) {
      if (!interviewId || !accessToken) return;
      var status = byId('satisfaction_status');
      try {
        var result = await apiRequest('/api/interviews/' + interviewId + '/evaluate', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Interview-Token': accessToken
          },
          body: JSON.stringify({ rating: rating, access_token: accessToken })
        });
        if (status) status.textContent = result.data && result.data.success ? 'ご評価ありがとうございます。' : (result.data && result.data.error) || '送信に失敗しました';
      } catch (e) {
        if (status) status.textContent = '送信に失敗しました';
      }
    }

    if (enterBtn) enterBtn.onclick = enterRoom;
    if (startBtn) startBtn.onclick = startInterview;
    if (submitBtn) submitBtn.onclick = submitAnswer;
    if (replayBtn) replayBtn.onclick = toggleQuestionAudio;
    if (voiceStartBtn) voiceStartBtn.onclick = startVoiceAnswer;
    if (voiceStopBtn) voiceStopBtn.onclick = stopVoiceAnswer;
    if (answerModeTextBtn) answerModeTextBtn.onclick = showTextAnswerUi;
    if (answerModeVoiceBtn) answerModeVoiceBtn.onclick = showVoiceAnswerUi;
    if (cameraRetryBtn) {
      cameraRetryBtn.onclick = function() {
        ensureCameraPreview();
      };
    }

    document.querySelectorAll('[data-sat-rating]').forEach(function(btn) {
      btn.addEventListener('click', function() {
        submitSatisfaction(parseInt(btn.getAttribute('data-sat-rating'), 10));
      });
    });
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
    applyAnswerModeUi();
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
