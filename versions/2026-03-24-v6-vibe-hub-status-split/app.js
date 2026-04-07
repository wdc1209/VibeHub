const STORAGE_KEY = 'openclaw-vibe-hub-v6-vibe-hub-status-split-cn-v1';
const BRIDGE_URL = 'http://127.0.0.1:4765';

const TARGETS = ['Codex', '财神', '当前应用', 'OpenClaw 调度器', 'Echo 审阅'];
const INPUT_TERMINAL = '微信';

const SEED_STATE = {
  currentCard: {
    id: 'draft-current',
    title: 'Vibe Hub',
    status: '待发送',
    target: 'Codex',
    mode: '长描述',
    body:
      '请把这段关于 Vibe Hub 的产品想法整理成可执行前端原型任务：保留 companion app 定位，突出浮空卡片感、Token Stack 历史，以及短指令直发 / 长描述进卡片这两条路径。优先做成本地可手动测试版本，再预留 OpenClaw bridge 接口。',
    rawInput:
      '我想做一个跟 OpenClaw 深度绑定的 companion app，不是单纯聊天框。短命令可以直接发，但长描述应该先进一个卡片，用户可以看到整理后的机器化文本，手动改一下再发给 Codex 或别的 agent。卡片要浮空、像 Mac HUD，一打开就有历史栈可以翻看。',
  },
  stack: [
    {
      id: crypto.randomUUID(),
      title: '生产部署与低延迟链路',
      status: '已送出',
      target: 'Codex',
      body:
        '请给出面向生产环境的低延迟部署方案，覆盖：VPS 选型、地域布局、币安消息接入、内部流程压缩、Polygon 下单广播、失败重试与主备链路。最后输出最小生产可用方案。',
      rawInput:
        '如果我要正式部署生产环境，我应该怎么用这套规则，怎样减少延迟，怎样尽快把消息发送到 Polygon，你帮我做一版完整方案。',
      summary: '让 Codex 产出一版面向生产的低延迟部署与执行方案。',
      timestamp: new Date(Date.now() - 1000 * 60 * 16).toISOString(),
    },
    {
      id: crypto.randomUUID(),
      title: 'Codex 单实例调度模板',
      status: '已送出',
      target: 'OpenClaw 调度器',
      body:
        '固化 Codex 单实例调度模板：使用 9333 端口启动，验证 opencli 的 status / send / read 链路，并整理为可复用模板。',
      rawInput:
        '先别搞多实例切换，先把一个 Codex 跑稳，把启动方式、怎么连、怎么发消息写成模板。',
      summary: '沉淀单实例 Codex + opencli 的稳定调用模板。',
      timestamp: new Date(Date.now() - 1000 * 60 * 44).toISOString(),
    },
  ],
  selectedStackId: null,
  stackOpen: false,
  settingsOpen: false,
  filters: {
    search: '',
    target: 'all',
    time: 'all',
    date: '',
  },
  ui: {
    floatingPosition: null,
    sendAnimating: false,
  },
};

const state = loadState();
const els = {};
let toastTimer = null;
let feedbackTimer = null;
let sendProgressTimer = null;
let dragState = null;
let bridgeStatus = null;

const bridge = {
  async fetchStatus() {
    const response = await fetch(`${BRIDGE_URL}/status`);
    if (!response.ok) throw new Error(`status ${response.status}`);
    bridgeStatus = await response.json();
    return bridgeStatus;
  },
  async routeInput(text) {
    const response = await fetch(`${BRIDGE_URL}/route`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ sessionId: WEBCHAT_SESSION_ID, text }),
    });
    if (!response.ok) throw new Error(`route ${response.status}`);
    return response.json();
  },
  async fetchTokenSession() {
    const response = await fetch(`${BRIDGE_URL}/token-session?sessionId=${encodeURIComponent(WEBCHAT_SESSION_ID)}`);
    if (!response.ok) throw new Error(`token-session ${response.status}`);
    return response.json();
  },
  async sendVibeHub(payload) {
    if (payload.target !== 'Codex') {
      await wait(200);
      return {
        ok: true,
        sentAt: new Date().toISOString(),
        target: payload.target,
        mode: 'mock',
      };
    }
    const response = await fetch(`${BRIDGE_URL}/send/codex`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ text: payload.body }),
    });
    const result = await response.json();
    if (!response.ok || !result.ok) {
      throw new Error(result.error || `send ${response.status}`);
    }
    return {
      ok: true,
      sentAt: new Date().toISOString(),
      target: 'Codex',
      mode: 'bridge',
      output: result.output,
    };
  },
  async rewriteToken(payload) {
    const lines = payload.body.split(/[\n。；]/).map((line) => line.trim()).filter(Boolean);
    const first = lines[0] || payload.body.trim();
    const rest = lines.slice(1, 5);
    return {
      body: [
        `目标：${first}`,
        ...rest.map((line) => `- ${line}`),
        rest.length === 0 ? '- 请给出明确步骤、交付物与结果输出。' : '',
      ].filter(Boolean).join('\n'),
      status: '已重写',
    };
  },
  async shortenToken(payload) {
    const compact = payload.body.replace(/\s+/g, ' ').split(/[。；]/).map((part) => part.trim()).filter(Boolean).slice(0, 2).join('；');
    return { body: compact || payload.body.slice(0, 60), status: '已压缩' };
  },
};

init();

async function init() {
  normalizeState();
  bindElements();
  renderTargetOptions();
  renderHistoryTargetFilter();
  bindEvents();
  render();
  queueMicrotask(() => {
    centerCardIfNeeded(true);
    applyFloatingPosition();
  });
  await refreshBridgeStatus();
}

function normalizeState() {
  state.ui ||= { floatingPosition: null, sendAnimating: false };
  state.filters ||= { search: '', target: 'all', time: 'all', date: '' };
  if (!state.currentCard?.target) state.currentCard.target = 'Codex';
}

function bindElements() {
  [
    'tokenCard', 'dragHandle', 'targetSelect', 'cardBody', 'rawInput', 'cardStatus', 'bodyStats', 'feedbackBadge', 'sendBtn', 'rewriteBtn', 'shortenBtn', 'cancelBtn',
    'stackToggleBtn', 'closeStackBtn', 'stackDrawer', 'stackList', 'stackCount', 'detailEmpty', 'detailContent', 'historySearchInput', 'historyTargetFilter', 'historyTimeFilter', 'historyDateFilter',
    'settingsToggleBtn', 'settingsDrawer', 'closeSettingsBtn', 'toast', 'sendProgress', 'inputTerminalText', 'pairStatusText', 'inputTerminalList', 'outputTerminalList'
  ].forEach((id) => {
    els[id] = document.getElementById(id);
  });
}

function bindEvents() {
  els.targetSelect.addEventListener('change', (event) => {
    state.currentCard.target = event.target.value;
    persistAndRender();
  });

  els.cardBody.addEventListener('input', async (event) => {
    state.currentCard.body = event.target.value;
    state.currentCard.status = '待发送';
    hideFeedbackBadge();
    persistAndRender(false);
    await updateRouteMode();
  });

  els.rawInput.addEventListener('input', async (event) => {
    state.currentCard.rawInput = event.target.value;
    persistAndRender(false);
    await updateRouteMode();
  });

  els.historySearchInput.addEventListener('input', (event) => {
    state.filters.search = event.target.value;
    state.selectedStackId = null;
    persistAndRender(false);
  });

  els.historyTargetFilter.addEventListener('change', (event) => {
    state.filters.target = event.target.value;
    state.selectedStackId = null;
    persistAndRender();
  });

  els.historyTimeFilter.addEventListener('change', (event) => {
    state.filters.time = event.target.value;
    if (state.filters.time !== 'date') state.filters.date = '';
    state.selectedStackId = null;
    persistAndRender();
  });

  els.historyDateFilter.addEventListener('change', (event) => {
    state.filters.date = event.target.value;
    state.selectedStackId = null;
    persistAndRender();
  });

  els.settingsToggleBtn.addEventListener('click', async () => {
    state.settingsOpen = !state.settingsOpen;
    persistAndRender();
    if (state.settingsOpen) await refreshBridgeStatus();
  });

  els.closeSettingsBtn.addEventListener('click', () => {
    state.settingsOpen = false;
    persistAndRender();
  });

  els.stackToggleBtn.addEventListener('click', () => {
    state.stackOpen = true;
    persistAndRender();
  });

  els.closeStackBtn.addEventListener('click', () => {
    state.stackOpen = false;
    persistAndRender();
  });

  els.sendBtn.addEventListener('click', handleSendCurrentCard);
  els.rewriteBtn.addEventListener('click', handleRewrite);
  els.shortenBtn.addEventListener('click', handleShorten);
  els.cancelBtn.addEventListener('click', handleCancel);

  bindDrag();
  window.addEventListener('resize', handleResize);
}

function render(save = true) {
  renderCurrentCard();
  renderStack();
  renderDrawers();
  renderSendProgress();
  renderBridgePanels();
  applyFloatingPosition();
  if (save) saveState();
}

function renderCurrentCard() {
  els.targetSelect.value = state.currentCard.target;
  els.cardBody.value = state.currentCard.body;
  els.rawInput.value = state.currentCard.rawInput;
  els.cardStatus.textContent = state.currentCard.status;
  els.bodyStats.textContent = `${state.currentCard.body.trim().length} 字`;
  els.historySearchInput.value = state.filters.search || '';
  els.historyTargetFilter.value = state.filters.target || 'all';
  els.historyTimeFilter.value = state.filters.time || 'all';
  els.historyDateFilter.value = state.filters.date || '';
  els.historyDateFilter.classList.toggle('hidden', state.filters.time !== 'date');
}

function renderBridgePanels() {
  const inputTerminal = bridgeStatus?.inputTerminal || INPUT_TERMINAL;
  if (els.inputTerminalText) els.inputTerminalText.textContent = inputTerminal;
  if (els.pairStatusText) {
    els.pairStatusText.textContent = bridgeStatus?.codex?.connected ? 'OpenClaw 已连接' : 'OpenClaw bridge 已启动';
  }

  if (els.inputTerminalList) {
    els.inputTerminalList.innerHTML = `
      <div class="availability-row"><div><strong>${escapeHtml(inputTerminal)}</strong><p class="settings-copy">当前输入终端</p></div><span class="availability-badge connected">当前</span></div>
      <div class="availability-row"><div><strong>OpenClaw Web Chat</strong><p class="settings-copy">Web · 可作为网页输入入口</p></div><span class="availability-badge idle">可输入</span></div>
      <div class="availability-row"><div><strong>Telegram</strong><p class="settings-copy">消息终端 · 预留输入入口</p></div><span class="availability-badge idle">可输入</span></div>
      <div class="availability-row"><div><strong>Session：Codex</strong><p class="settings-copy">该 session 已支持 Vibe Hub 输入链路</p></div><span class="availability-badge ${bridgeStatus?.codex?.connected ? 'connected' : 'idle'}">${bridgeStatus?.codex?.connected ? '已挂载' : '可接入'}</span></div>
      <div class="availability-row"><div><strong>Session：财神</strong><p class="settings-copy">该 session 已支持 Vibe Hub 输入链路</p></div><span class="availability-badge idle">可接入</span></div>
      <div class="availability-row"><div><strong>Session：Echo 审阅</strong><p class="settings-copy">可用于输入后的摘要 / 审阅流程</p></div><span class="availability-badge idle">可审阅</span></div>
    `;
  }

  if (els.outputTerminalList) {
    const apps = bridgeStatus?.apps || [];
    const appMap = new Map(apps.map((item) => [item.name, item.installed]));
    const outputItems = [
      ['Codex App', bridgeStatus?.codex?.connected ? '已连接' : appMap.get('Codex') ? '可连接' : '未安装', bridgeStatus?.codex?.connected ? 'connected' : appMap.get('Codex') ? 'idle' : 'disabled', 'App · 第一真实输出目标'],
      ['Google Chrome', appMap.get('Google Chrome') ? '可连接' : '未安装', appMap.get('Google Chrome') ? 'idle' : 'disabled', '浏览器 · 可作为网页输出终端'],
      ['Safari', appMap.get('Safari') ? '可连接' : '未安装', appMap.get('Safari') ? 'idle' : 'disabled', '浏览器 · 可作为网页输出终端'],
      ['Telegram', appMap.get('Telegram') ? '未连接' : '未安装', appMap.get('Telegram') ? 'disabled' : 'disabled', 'App · 本机已安装但未接入输出链路'],
      ['WeChat', appMap.get('WeChat') ? '未连接' : '未安装', appMap.get('WeChat') ? 'disabled' : 'disabled', 'App · 当前作为输入终端，暂未做输出链路'],
      ['Cursor', '未连接', 'disabled', 'IDE · 当前未检测到本机安装或 bridge'],
      ['Anti Gravity', '未连接', 'disabled', 'IDE · 当前未检测到本机安装'],
      ['Claude Code', '未连接', 'disabled', 'IDE / Agent 终端 · 当前未检测到本机安装'],
    ];

    els.outputTerminalList.innerHTML = outputItems.map(([name, status, cls, copy]) => `
      <div class="availability-row">
        <div><strong>${escapeHtml(name)}</strong><p class="settings-copy">${escapeHtml(copy)}</p></div>
        <span class="availability-badge ${cls}">${escapeHtml(status)}</span>
      </div>
    `).join('');
  }
}

function renderTargetOptions() {
  els.targetSelect.innerHTML = TARGETS.map((target) => `<option value="${target}">${target}</option>`).join('');
}

function renderHistoryTargetFilter() {
  els.historyTargetFilter.innerHTML = [`<option value="all">全部目标</option>`, ...TARGETS.map((target) => `<option value="${target}">${target}</option>`)].join('');
}

function renderStack() {
  const stack = getFilteredStack();
  els.stackCount.textContent = `${stack.length} 张`;
  if (stack.length === 0) {
    els.stackList.innerHTML = '<div class="stack-empty">没有符合条件的发送记录。</div>';
    return;
  }

  els.stackList.innerHTML = stack.map((card) => {
    const active = state.selectedStackId === card.id;
    return `
      <article class="stack-card ${active ? 'active' : ''}" data-id="${card.id}">
        <div class="stack-card-head">
          <strong>${escapeHtml(card.target)}</strong>
          <span class="stack-count">${escapeHtml(card.status)}</span>
        </div>
        <p class="stack-card-summary">${escapeHtml(card.summary || summarize(card.body))}</p>
        <div class="stack-meta">
          <small>${formatTime(card.timestamp)}</small>
          <small>${escapeHtml(card.title)}</small>
        </div>
        ${active ? renderExpandedCard(card) : ''}
      </article>
    `;
  }).join('');

  els.stackList.querySelectorAll('.stack-card').forEach((node) => {
    node.addEventListener('click', (event) => {
      if (event.target.closest('[data-action]')) return;
      const cardId = node.dataset.id;
      state.selectedStackId = state.selectedStackId === cardId ? null : cardId;
      persistAndRender();
    });
  });

  bindInlineActions();
}

function renderExpandedCard(card) {
  return `
    <div class="stack-card-expand">
      <div class="detail-close-row">
        <button class="ghost-button close-detail-button" data-action="close-inline" aria-label="收起详情">×</button>
      </div>
      <div class="detail-meta-row">
        <div class="detail-meta-box">
          <span class="field-label">发送给</span>
          <strong>${escapeHtml(card.target)}</strong>
        </div>
        <div class="detail-meta-box">
          <span class="field-label">发送时间</span>
          <strong>${escapeHtml(formatTime(card.timestamp, true))}</strong>
        </div>
      </div>
      <div class="detail-section">
        <span class="field-label">摘要</span>
        <p class="detail-summary">${escapeHtml(card.summary || summarize(card.body))}</p>
      </div>
      <div class="detail-section">
        <span class="field-label">卡片正文</span>
        <pre class="detail-pre">${escapeHtml(card.body)}</pre>
      </div>
      <div class="detail-actions">
        <button class="ghost-button" data-action="resend">再次发送</button>
        <button class="ghost-button" data-action="edit-resend">编辑后发送</button>
        <button class="primary-button alt" data-action="send-another">转发给其他目标</button>
      </div>
    </div>
  `;
}

function bindInlineActions() {
  els.stackList.querySelectorAll('[data-action="close-inline"]').forEach((node) => {
    node.addEventListener('click', (event) => {
      event.stopPropagation();
      clearDetailSelection();
    });
  });

  els.stackList.querySelectorAll('[data-action="resend"]').forEach((node) => {
    node.addEventListener('click', async (event) => {
      event.stopPropagation();
      await handleDetailResend();
    });
  });

  els.stackList.querySelectorAll('[data-action="edit-resend"]').forEach((node) => {
    node.addEventListener('click', (event) => {
      event.stopPropagation();
      handleDetailEditResend();
    });
  });

  els.stackList.querySelectorAll('[data-action="send-another"]').forEach((node) => {
    node.addEventListener('click', (event) => {
      event.stopPropagation();
      handleDetailSendAnother();
    });
  });
}

function getFilteredStack() {
  const search = (state.filters.search || '').trim().toLowerCase();
  const target = state.filters.target || 'all';
  const time = state.filters.time || 'all';
  const date = state.filters.date || '';
  const now = Date.now();

  return [...state.stack]
    .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
    .filter((card) => {
      if (target !== 'all' && card.target !== target) return false;
      const cardDate = new Date(card.timestamp);
      const age = now - cardDate.getTime();
      if (time === '30m' && age > 30 * 60 * 1000) return false;
      if (time === '1h' && age > 60 * 60 * 1000) return false;
      if (time === '24h' && age > 24 * 60 * 60 * 1000) return false;
      if (time === 'date' && date) {
        const ymd = cardDate.toISOString().slice(0, 10);
        if (ymd !== date) return false;
      }
      if (!search) return true;
      return [card.title, card.target, card.summary, card.body, card.rawInput].join(' ').toLowerCase().includes(search);
    });
}

function renderDrawers() {
  els.stackDrawer.classList.toggle('hidden', !state.stackOpen);
  els.settingsDrawer.classList.toggle('hidden', !state.settingsOpen);
  if (state.settingsOpen) {
    positionSettingsDrawer();
  } else {
    els.settingsDrawer.style.top = '';
    els.settingsDrawer.style.left = '';
  }
}

function renderSendProgress() {
  if (!els.sendProgress) return;
  els.sendProgress.classList.toggle('hidden', !state.ui.sendAnimating);
  els.sendProgress.classList.toggle('show', !!state.ui.sendAnimating);
}

function bindDrag() {
  const start = (event) => {
    if (window.innerWidth <= 900) return;
    if (isInteractiveTarget(event.target)) return;
    const point = getPoint(event);
    const rect = els.tokenCard.getBoundingClientRect();
    dragState = {
      pointerOffsetX: point.clientX - rect.left,
      pointerOffsetY: point.clientY - rect.top,
    };
    els.tokenCard.classList.add('is-dragging');
    document.addEventListener('mousemove', onDrag);
    document.addEventListener('mouseup', endDrag);
    document.addEventListener('touchmove', onDrag, { passive: false });
    document.addEventListener('touchend', endDrag);
  };

  const onDrag = (event) => {
    if (!dragState) return;
    if (event.cancelable) event.preventDefault();
    const point = getPoint(event);
    const width = els.tokenCard.offsetWidth;
    const height = els.tokenCard.offsetHeight;
    const margin = 18;
    const maxLeft = Math.max(margin, window.innerWidth - width - margin);
    const maxTop = Math.max(margin, window.innerHeight - height - margin);
    state.ui.floatingPosition = {
      left: clamp(point.clientX - dragState.pointerOffsetX, margin, maxLeft),
      top: clamp(point.clientY - dragState.pointerOffsetY, margin, maxTop),
    };
    applyFloatingPosition();
    saveState();
  };

  const endDrag = () => {
    if (!dragState) return;
    dragState = null;
    els.tokenCard.classList.remove('is-dragging');
    document.removeEventListener('mousemove', onDrag);
    document.removeEventListener('mouseup', endDrag);
    document.removeEventListener('touchmove', onDrag);
    document.removeEventListener('touchend', endDrag);
  };

  els.dragHandle.addEventListener('mousedown', start);
  els.dragHandle.addEventListener('touchstart', start, { passive: true });
}

function applyFloatingPosition() {
  if (window.innerWidth <= 900) {
    els.tokenCard.style.left = '';
    els.tokenCard.style.top = '';
    els.tokenCard.style.marginLeft = '';
    els.tokenCard.style.marginTop = '';
    return;
  }
  if (!state.ui.floatingPosition) centerCardIfNeeded();
  const width = els.tokenCard.offsetWidth;
  const height = els.tokenCard.offsetHeight;
  const margin = 18;
  const maxLeft = Math.max(margin, window.innerWidth - width - margin);
  const maxTop = Math.max(margin, window.innerHeight - height - margin);
  state.ui.floatingPosition.left = clamp(state.ui.floatingPosition.left, margin, maxLeft);
  state.ui.floatingPosition.top = clamp(state.ui.floatingPosition.top, margin, maxTop);
  els.tokenCard.style.left = `${state.ui.floatingPosition.left}px`;
  els.tokenCard.style.top = `${state.ui.floatingPosition.top}px`;
  els.tokenCard.style.marginLeft = '0';
  els.tokenCard.style.marginTop = '0';
}

function centerCardIfNeeded(force = false) {
  if ((!force && state.ui.floatingPosition) || window.innerWidth <= 900) return;
  const width = els.tokenCard.offsetWidth || Math.min(760, window.innerWidth - 88);
  const height = els.tokenCard.offsetHeight || 620;
  state.ui.floatingPosition = {
    left: Math.max(18, (window.innerWidth - width) / 2),
    top: Math.max(18, (window.innerHeight - height) / 2),
  };
}

function handleResize() {
  if (window.innerWidth > 900) {
    centerCardIfNeeded();
    applyFloatingPosition();
  }
  if (state.settingsOpen) positionSettingsDrawer();
  saveState();
}

function positionSettingsDrawer() {
  const trigger = els.settingsToggleBtn;
  const drawer = els.settingsDrawer;
  if (!trigger || !drawer) return;

  const rect = trigger.getBoundingClientRect();
  const drawerWidth = drawer.offsetWidth || 286;
  const drawerHeight = drawer.offsetHeight || 420;
  const gap = 8;

  let left = rect.right - drawerWidth;
  let top = rect.bottom + gap;

  left = Math.max(12, Math.min(left, window.innerWidth - drawerWidth - 12));
  top = Math.max(12, Math.min(top, window.innerHeight - drawerHeight - 12));

  drawer.style.left = `${left}px`;
  drawer.style.top = `${top}px`;
}

async function handleSendCurrentCard() {
  if (state.ui.sendAnimating) return;
  state.ui.sendAnimating = true;
  state.currentCard.status = '发送中';
  persistAndRender();

  const payload = structuredClone(state.currentCard);

  try {
    const result = await bridge.sendVibeHub(payload);
    state.stack.unshift({
      id: crypto.randomUUID(),
      title: 'Vibe Hub',
      status: result.mode === 'bridge' ? '已送出（真实）' : '已送出',
      target: payload.target,
      body: payload.body,
      rawInput: payload.rawInput,
      summary: summarize(payload.body),
      timestamp: result.sentAt,
    });
    state.selectedStackId = state.stack[0].id;
    state.currentCard.status = '已送出';
    state.stackOpen = true;
    showToast(`已发送到 ${payload.target}`);
    await refreshBridgeStatus();
  } catch (error) {
    state.currentCard.status = '发送失败';
    showToast(`发送失败：${error.message}`);
  } finally {
    persistAndRender();
    clearTimeout(sendProgressTimer);
    sendProgressTimer = setTimeout(() => {
      state.ui.sendAnimating = false;
      persistAndRender();
    }, 1100);
  }
}

async function handleRewrite() {
  const result = await bridge.rewriteToken(state.currentCard);
  state.currentCard.body = result.body;
  state.currentCard.status = '已重写';
  showFeedbackBadge('已重写成更清晰的版本', 'rewrite');
  showToast('已重写');
  persistAndRender();
}

async function handleShorten() {
  const result = await bridge.shortenToken(state.currentCard);
  state.currentCard.body = result.body;
  state.currentCard.status = '已压缩';
  showFeedbackBadge('已压缩为更短版本', 'shorten');
  showToast('已压缩');
  persistAndRender();
}

function handleCancel() {
  state.currentCard.status = '已取消';
  showToast('已取消');
  persistAndRender();
}

async function handleDetailResend() {
  const card = getSelectedCard();
  if (!card) return;
  try {
    await bridge.sendVibeHub(card);
    showToast(`已再次发送到 ${card.target}`);
  } catch (error) {
    showToast(`重发失败：${error.message}`);
  }
}

function handleDetailEditResend() {
  const card = getSelectedCard();
  if (!card) return;
  state.currentCard = {
    id: `draft-${card.id}`,
    title: 'Vibe Hub',
    status: '待发送',
    target: card.target,
    body: card.body,
    rawInput: card.rawInput || card.body,
  };
  state.stackOpen = false;
  showToast('已载入到当前卡片，可修改后再发送');
  persistAndRender();
}

function handleDetailSendAnother() {
  const card = getSelectedCard();
  if (!card) return;
  const currentIndex = TARGETS.indexOf(card.target);
  const nextTarget = TARGETS[(currentIndex + 1) % TARGETS.length];
  state.currentCard = {
    id: `draft-${card.id}-another`,
    title: 'Vibe Hub',
    status: '待发送',
    target: nextTarget,
    body: card.body,
    rawInput: card.rawInput || card.body,
  };
  state.stackOpen = false;
  showToast(`已切换到 ${nextTarget}`);
  persistAndRender();
}

function clearDetailSelection() {
  state.selectedStackId = null;
  persistAndRender();
}

function showFeedbackBadge(text, kind) {
  clearTimeout(feedbackTimer);
  els.feedbackBadge.textContent = text;
  els.feedbackBadge.classList.remove('hidden', 'rewrite', 'shorten');
  if (kind) els.feedbackBadge.classList.add(kind);
  feedbackTimer = setTimeout(hideFeedbackBadge, 2200);
}

function hideFeedbackBadge() {
  clearTimeout(feedbackTimer);
  els.feedbackBadge.textContent = '';
  els.feedbackBadge.classList.add('hidden');
  els.feedbackBadge.classList.remove('rewrite', 'shorten');
}

async function refreshBridgeStatus() {
  try {
    await bridge.fetchStatus();
  } catch (error) {
    bridgeStatus = { inputTerminal: INPUT_TERMINAL, codex: { connected: false, raw: error.message }, apps: [] };
  }
  persistAndRender(false);
}

async function updateRouteMode() {
  const text = state.currentCard.rawInput.trim() || state.currentCard.body.trim();
  if (!text) return;
  try {
    const routed = await bridge.routeInput(text);
    if (routed.mode === 'direct') {
      state.currentCard.status = '短指令直发';
    } else if (routed.mode === 'vibe-hub') {
      state.currentCard.status = '待发送';
    } else if (routed.mode === 'clarify') {
      state.currentCard.status = '需要澄清';
    }
    persistAndRender(false);
  } catch {
    // ignore route hint failures in UI
  }
}

function getSelectedCard() {
  return state.stack.find((item) => item.id === state.selectedStackId);
}

function summarize(text) {
  const cleaned = text.replace(/\s+/g, ' ').trim();
  return cleaned.slice(0, 56) + (cleaned.length > 56 ? '…' : '');
}

function formatTime(isoString, verbose = false) {
  const date = new Date(isoString);
  return verbose
    ? date.toLocaleString('zh-CN', { hour12: false })
    : date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', hour12: false });
}

function showToast(text) {
  clearTimeout(toastTimer);
  els.toast.textContent = text;
  els.toast.classList.add('show');
  toastTimer = setTimeout(() => els.toast.classList.remove('show'), 1800);
}

function persistAndRender(save = true) {
  render(save);
}

function loadState() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (!saved) return structuredClone(SEED_STATE);
    return mergeSeedState(structuredClone(SEED_STATE), JSON.parse(saved));
  } catch {
    return structuredClone(SEED_STATE);
  }
}

function mergeSeedState(seed, saved) {
  return {
    ...seed,
    ...saved,
    currentCard: { ...seed.currentCard, ...(saved.currentCard || {}) },
    stack: Array.isArray(saved.stack) ? saved.stack : seed.stack,
    filters: { ...seed.filters, ...(saved.filters || {}) },
    ui: { ...seed.ui, ...(saved.ui || {}) },
  };
}

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function escapeHtml(text) {
  return String(text)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function getPoint(event) {
  if (event.touches?.[0]) return event.touches[0];
  if (event.changedTouches?.[0]) return event.changedTouches[0];
  return event;
}

function isInteractiveTarget(node) {
  return Boolean(node.closest('button, select, textarea, summary, option, input'));
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
