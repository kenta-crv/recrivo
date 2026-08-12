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
    // マイク／SpeechRecognition 使用後はブラウザTTSが壊れやすい（Chrome既知）
    var micWasUsed = false;
    var voiceListening = false;
    var voiceFinalText = '';
    var lastVoiceTranscript = '';
    var voiceMediaRecorder = null;
    var voiceRecordedChunks = [];
    var voiceRecordedBlob = null;
    var voiceRestartTimer = null;

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
      statusEl.hidden = false;
      statusEl.textContent = msg || '';
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
          // 挨拶は最後まで再生してから質問へ（並行再生すると audio が壊れる）
          await playSpokenContent({
            text: greetingText,
            audioUrl: (data.greeting && data.greeting.audio_url) || null,
            waitUntilEnd: true,
            keepControl: false
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
        hideAnswerStage();
        renderOptions(null);
        setAvatarState('speaking');
        setStatus(bridge);
        setSubmitButtonState('questioning');
        await waitMs(micWasUsed ? 500 : 350);
        await preparePlaybackAfterMic();

        if (questionText) questionText.textContent = currentQuestion.question_text || '（質問文なし）';
        appendChatMessage('ai', currentQuestion.question_text || '（質問文なし）');

        var answered = order ? Math.max(0, order - 1) : 0;
        setProgress(total ? (answered / total) * 100 : 0, answered, total);
        setStatus('質問を再生中...');
        setSubmitButtonState('questioning');

        // 質問は HTML Audio を最後まで再生する（サーバーTTS）
        var played = await playSpokenContent({
          text: currentQuestion.question_text || '',
          audioUrl: currentQuestion.audio_url,
          waitUntilEnd: true,
          keepControl: true
        });
        setStatus(played ? '回答を入力してください' : '音声の自動再生がブロックされました。再生ボタンを押してください。');
        revealAnswerStage();
        if (recordCamera) {
          startAnswerVideoRecording().catch(function() {});
        }
        refreshStatus().catch(function() {});
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
      answerInputMode = null;
      if (answerModePicker) answerModePicker.hidden = false;
      if (textAnswerBlock) textAnswerBlock.hidden = true;
      setVoiceControlsMode('off');
      if (submitBtn) {
        submitBtn.hidden = true;
        submitBtn.disabled = true;
      }
      setAnswerActionHint(interviewLanguage === 'en' ? 'Choose how to answer.' : '回答方法を選んでください。');
    }

    function revealAnswerStage() {
      if (!answerStage) return;
      answerStage.hidden = false;

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
      answerActionHint.textContent = msg || '';
    }

    function applyAnswerModeUi() {
      revealAnswerStage();
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
        if (!videoMediaRecorder || videoMediaRecorder.state === 'inactive') {
          if (videoRecordedChunks.length) {
            recordedVideoBlob = new Blob(videoRecordedChunks, {
              type: (videoMediaRecorder && videoMediaRecorder.mimeType) || 'video/webm'
            });
          }
          videoMediaRecorder = null;
          if (candidateCameraRec) candidateCameraRec.hidden = true;
          resolve();
          return;
        }
        var recorder = videoMediaRecorder;
        recorder.onstop = function() {
          if (videoRecordedChunks.length) {
            recordedVideoBlob = new Blob(videoRecordedChunks, {
              type: recorder.mimeType || 'video/webm'
            });
          } else {
            recordedVideoBlob = null;
          }
          videoMediaRecorder = null;
          if (candidateCameraRec) candidateCameraRec.hidden = true;
          resolve();
        };
        try {
          recorder.stop();
        } catch (e) {
          videoMediaRecorder = null;
          if (candidateCameraRec) candidateCameraRec.hidden = true;
          resolve();
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

        // hidden のままだとブラウザによっては再生に失敗する
        questionAudio.hidden = false;
        var audioRow = questionAudio.closest('.interview-cinema__audio-row');
        if (audioRow) audioRow.hidden = false;

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

    function setPlayButtonVisible(visible) {
      if (!replayBtn) return;
      replayBtn.hidden = !visible;
      var row = replayBtn.closest('.interview-cinema__audio-row');
      if (row) row.hidden = !visible;
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

    function isAudioPlaying() {
      if (questionAudio && !questionAudio.paused && !questionAudio.ended) {
        return true;
      }
      if (window.speechSynthesis && window.speechSynthesis.speaking && !window.speechSynthesis.paused) {
        return true;
      }
      return false;
    }

    function hasResumableAudio() {
      return !!(questionAudio && questionAudio.paused && !questionAudio.ended && questionAudio.currentTime > 0);
    }

    function pauseInterviewerAudio() {
      playbackGeneration += 1;
      stopBrowserSpeech();
      if (questionAudio) {
        try { questionAudio.pause(); } catch (e) {}
      }
      setPlayButtonPlaying(false);
      setAvatarState('listening');
    }

    async function playSpokenContent(opts) {
      opts = opts || {};
      var text = opts.text || '';
      var url = opts.audioUrl || null;
      var waitUntilEnd = !!opts.waitUntilEnd;
      var keepControl = !!opts.keepControl;
      lastSpokenText = text;
      lastAudioUrl = url;

      playbackGeneration += 1;
      var generation = playbackGeneration;

      stopBrowserSpeech();
      setPlayButtonVisible(true);
      setPlayButtonPlaying(true);

      // 1) サーバーTTS（HTML Audio）を最優先。これが本線。
      if (url) {
        var ok = await playHtmlAudio(url, waitUntilEnd, generation);
        if (generation !== playbackGeneration) return false;
        if (ok) {
          setPlayButtonPlaying(false);
          if (!keepControl) hidePlayButton();
          return true;
        }
      }

      // 2) URLが無い／失敗時のみブラウザTTS（短時間）。マイク使用後は使わない。
      if (text && !micWasUsed) {
        await waitMs(200);
        if (generation !== playbackGeneration) return false;
        var spoken = await speakWithBrowser(text, waitUntilEnd, generation);
        if (generation !== playbackGeneration) return false;
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

    async function resumeInterviewerAudio() {
      if (!hasResumableAudio() || !questionAudio) return false;
      setPlayButtonPlaying(true);
      setAvatarState('speaking');
      setStatus('音声を再生中...');
      setSubmitButtonState('questioning');
      setVoiceControlsForQuestioning(true);
      try {
        var playPromise = questionAudio.play();
        if (playPromise && playPromise.then) await playPromise;
        await new Promise(function(resolve) {
          var finished = false;
          function done() {
            if (finished) return;
            finished = true;
            questionAudio.removeEventListener('ended', done);
            questionAudio.removeEventListener('pause', onPause);
            resolve();
          }
          function onPause() {
            if (questionAudio.ended) return;
            done();
          }
          questionAudio.addEventListener('ended', done);
          questionAudio.addEventListener('pause', onPause);
        });
        setPlayButtonPlaying(false);
        setAvatarState('listening');
        setStatus('回答を入力してください');
        setSubmitButtonState('ready');
        setVoiceControlsForQuestioning(false);
        return true;
      } catch (e) {
        setPlayButtonPlaying(false);
        return false;
      }
    }

    async function toggleQuestionAudio() {
      unlockAudioPlayback();
      clearError();

      if (isAudioPlaying() && !hasResumableAudio()) {
        pauseInterviewerAudio();
        setStatus('回答を入力してください');
        revealAnswerStage();
        return;
      }

      if (hasResumableAudio()) {
        hideAnswerStage();
        var resumed = await resumeInterviewerAudio();
        if (resumed) return;
      }

      hardStopSpeechRecognition();
      await waitMs(200);
      hideAnswerStage();
      setStatus('音声を再生中...');
      var played = await playSpokenContent({
        text: lastSpokenText || (currentQuestion && currentQuestion.question_text) || '',
        audioUrl: lastAudioUrl || (currentQuestion && currentQuestion.audio_url) || null,
        waitUntilEnd: true,
        keepControl: true
      });
      setStatus(played ? '回答を入力してください' : '再生に失敗しました。もう一度お試しください。');
      setPlayButtonVisible(true);
      setPlayButtonPlaying(false);
      revealAnswerStage();
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
      setVoiceControlsMode('recording');
      if (voiceStopBtn) voiceStopBtn.disabled = true;
      setAvatarState('listening');

      try {
        // インタビュアー音声の残響を拾わないよう一瞬待ってから録音開始
        await waitMs(250);
        await startVoiceRecording();
        if (voiceStopBtn) voiceStopBtn.disabled = false;
      } catch (e) {
        voiceListening = false;
        setVoiceControlsMode('idle');
        showError('マイクを開始できませんでした。ブラウザのマイク許可を確認してください。');
        if (voiceStatus) voiceStatus.textContent = 'マイク開始に失敗しました';
        return;
      }

      // SpeechRecognition は後続の HTML Audio 再生を壊す（Chrome既知）ため使わない。
      // 録音 → サーバーSTT のみで進める。
      if (voiceStatus) {
        voiceStatus.textContent = '録音中です。マイクに向かってはっきり話してください。終わったら「録音を止める」を押します。';
      }
    }

    async function startVoiceRecording() {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('mediaDevices unavailable');
      }
      var stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          channelCount: 1
        }
      });
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
        showError('音声を十分に取得できませんでした。もう一度録音してください。');
        if (voiceStatus) voiceStatus.textContent = '音声未検出';
        setVoiceControlsMode('idle');
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
          setVoiceControlsMode('idle');
          return;
        }
        if (textEl && allowTextAnswer) textEl.value = data.transcript;
        lastVoiceTranscript = data.transcript || '';
        recordedBlob = voiceRecordedBlob;
        if (voiceStatus) {
          if (allowTextAnswer) {
            voiceStatus.textContent = '文字起こし完了。内容を確認して「回答を送信」を押してください。';
          } else {
            voiceStatus.textContent = '文字起こし: ' + lastVoiceTranscript + '　→「回答を送信」で確定';
          }
        }
      } catch (e) {
        showError(e.message);
        if (voiceStatus) voiceStatus.textContent = '文字起こしエラー';
      } finally {
        setVoiceControlsMode('idle');
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
      if (!interviewId) {
        showError('面接が開始されていません。最初からやり直してください。');
        return;
      }
      if (!currentQuestion || !currentQuestion.question_id) {
        showError('質問の読み込みが完了していません。数秒待つか、ページを再読み込みしてください。');
        return;
      }

      var textAnswer = (byId('text_answer').value || '').trim();
      if (!allowTextAnswer && lastVoiceTranscript) {
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
        // テキスト不可時、文字起こしだけで音声なし送信は不可
        showError('音声で回答してください。');
        return;
      }

      isSubmitting = true;
      clearError();
      setSubmitButtonState('submitting');
      setStatus('回答を送信しています...');

      var answerPreview = currentAnswerPreview();

      // 録画停止は短時間で打ち切り（送信待ちを延ばさない）
      await Promise.race([
        stopAnswerVideoRecordingAndWait(),
        waitMs(700)
      ]);
      if (videoMediaRecorder && videoMediaRecorder.state !== 'inactive') {
        stopAnswerVideoRecordingSync();
      }

      var form = new FormData();
      form.append('question_id', currentQuestion.question_id);
      if (hasSelection) form.append('selected_option', selectedOption);
      // テキスト可、または音声の文字起こし確認用として送る（サーバー側の再STT回避）
      if (textAnswer) form.append('text_answer', textAnswer);
      if (hasRecording) form.append('audio_file', recordedBlob, 'recording.webm');
      // テキスト/選択肢のみの送信では動画アップロードを省略して速くする
      var textOnlySubmit = !hasRecording && !!(textAnswer || hasSelection);
      if (!textOnlySubmit && recordCamera && recordedVideoBlob && recordedVideoBlob.size > 0 && recordedVideoBlob.size < 8 * 1024 * 1024) {
        form.append('video_file', recordedVideoBlob, 'answer.webm');
      }

      try {
        var result = await apiRequest('/api/interviews/' + interviewId + '/submit_answer', {
          method: 'POST',
          body: form
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
