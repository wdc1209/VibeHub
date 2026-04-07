const STORAGE_KEY = 'openclaw-vibe-hub-v2-cn';

const TARGETS = ['Codex', '财神', '当前应用', 'OpenClaw 调度器', 'Echo 审阅'];
const SHAPES = ['envelope', 'bubble', 'token'];

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
    lastAction: '已载入演示卡片',
  },
  stack: [
    {
      id: crypto.randomUUID(),
      title: '生产部署与低延迟链路',
      status: '已发送',
      target: 'Codex',
      mode: '已发送卡片',
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
      status: '已发送',
      target: 'OpenClaw 调度器',
      mode: '已发送卡片',
      body:
        '固化 Codex 单实例调度模板：使用 9333 端口启动，验证 opencli 的 status / send / read 链路，并整理为可复用模板。',
      rawInput:
        '先别搞多实例切换，先把一个 Codex 跑稳，把启动方式、怎么连、怎么发消息写成模板。',
      summary: '沉淀单实例 Codex + opencli 的稳定调用模板。',
      timestamp: new Date(Date.now() - 1000 * 60 * 44).toISOString(),
    },
    {
      id: crypto.randomUUID(),
      title: 'Companion 交互拆分',
      status: '已发送',
      target: '财神',
      mode: '已发送卡片',
      body:
        '把 companion app 的交互拆成两条：短指令直发、长描述进 Vibe Hub。UI 上必须能一眼看懂，不要把两种行为都塞进一个输入框。',
      rawInput:
        '现在最关键的是语义分流：短话一句就发，长描述得先过卡片。这一点在 UI 上要看得见。',
      summary: '明确直发与卡片编辑两条交互路径。',
      timestamp: new Date(Date.now() - 1000 * 60 * 92).toISOString(),
    },
  ],
  selectedStackId: null,
  stackOpen: false,
  ui: {
    shape: 'envelope',
    floatingPosition: null,
  },
};

const state = loadState();
const els = {};
let toastTimer = null;
let feedbackTimer = null;
let dragState = null;

const bridge = {
  async createVibeHub(payload) {
    return {
      id: crypto.randomUUID(),
      title: payload.title || 'Vibe Hub',
      status: '已整理',
      target: payload.target,
      mode: payload.mode || '长描述',
      body: payload.body,
      rawInput: payload.rawInput,
      lastAction: '已通过本地桥接创建',
    };
  },

  async sendVibeHub(payload) {
    return {
      ok: true,
      dispatchId: `mock-${Math.random().toString(36).slice(2, 9)}`,
      sentAt: new Date().toISOString(),
      target: payload.target,
    };
  },

  async rewriteToken(payload) {
    const lines = payload.body
      .split(/[\n。；]/)
      .map((line) => line.trim())
      .filter(Boolean);

    const first = lines[0] || payload.body.trim();
    const rest = lines.slice(1, 5);

    const rewritten = [
      `目标：${first}`,
      ...rest.map((line) => `- ${line}`),
      rest.length === 0 ? '- 请给出明确步骤、交付物与结果输出。' : '',
    ]
      .filter(Boolean)
      .join('\n');

    return {
      body: rewritten,
      status: '已重写',
    };
  },

  async shortenToken(payload) {
    const compact = payload.body
      .replace(/\s+/g, ' ')
      .split(/[。；]/)
      .map((part) => part.trim())
      .filter(Boolean)
      .slice(0, 2)
      .join('；');

    return {
      body: compact || payload.body.slice(0, 60),
      status: '已压缩',
    };
  },
};

init();

function init() {
  normalizeState();
  bindElements();
  renderTargetOptions();
  bindEvents();
  render();
  queueMicrotask(() => {
    centerCardIfNeeded();
    applyFloatingPosition();
  });
}

function normalizeState() {
  state.ui = state.ui || { shape: 'envelope', floatingPosition: null };
  if (!SHAPES.includes(state.ui.shape)) state.ui.shape = 'envelope';
}

function bindElements() {
  [
    'tokenCard',
    'dragHandle',
    'targetSelect',
    'cardBody',
    'rawInput',
    'cardStatus',
    'bodyStats',
    'feedbackBadge',
    'sendBtn',
    'rewriteBtn',
    'shortenBtn',
    'cancelBtn',
    'stackToggleBtn',
    'closeStackBtn',
    'stackDrawer',
    'stackList',
    'stackCount',
    'detailEmpty',
    'detailContent',
    'detailTarget',
    'detailTime',
    'detailSummary',
    'detailBody',
    'detailResendBtn',
    'detailEditResendBtn',
    'detailSendAnotherBtn',
    'toast',
  ].forEach((id) => {
    els[id] = document.getElementById(id);
  });

  els.shapeChips = [...document.querySelectorAll('.shape-chip')];
}

function renderTargetOptions() {
  els.targetSelect.innerHTML = TARGETS.map((target) => `<option value="${target}">${target}</option>`).join('');
}

function bindEvents() {
  els.targetSelect.addEventListener('change', (event) => {
    state.currentCard.target = event.target.value;
    state.currentCard.lastAction = `目标改为：${event.target.value}`;
    persistAndRender();
  });

  els.cardBody.addEventListener('input', (event) => {
    state.currentCard.body = event.target.value;
    state.currentCard.status = '待发送';
    state.currentCard.lastAction = '已本地修改正文';
    hideFeedbackBadge();
    persistAndRender(false);
  });

  els.rawInput.addEventListener('input', (event) => {
    state.currentCard.rawInput = event.target.value;
    state.currentCard.lastAction = '已修改原始输入';
    persistAndRender(false);
  });

  els.shapeChips.forEach((chip) => {
    chip.addEventListener('click', () => {
      setShape(chip.dataset.shape);
    });
  });

  els.sendBtn.addEventListener('click', handleSendCurrentCard);
  els.rewriteBtn.addEventListener('click', handleRewrite);
  els.shortenBtn.addEventListener('click', handleShorten);
  els.cancelBtn.addEventListener('click', handleCancel);
  els.stackToggleBtn.addEventListener('click', () => {
    state.stackOpen = true;
    persistAndRender();
  });
  els.closeStackBtn.addEventListener('click', () => {
    state.stackOpen = false;
    persistAndRender();
  });
  els.detailResendBtn.addEventListener('click', handleDetailResend);
  els.detailEditResendBtn.addEventListener('click', handleDetailEditResend);
  els.detailSendAnotherBtn.addEventListener('click', handleDetailSendAnother);

  bindDrag();
  window.addEventListener('resize', handleResize);
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

    const nextLeft = clamp(point.clientX - dragState.pointerOffsetX, margin, maxLeft);
    const nextTop = clamp(point.clientY - dragState.pointerOffsetY, margin, maxTop);

    state.ui.floatingPosition = { left: nextLeft, top: nextTop };
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

function render(save = true) {
  renderCurrentCard();
  renderShape();
  renderStack();
  renderDetail();
  renderDrawer();
  applyFloatingPosition();
  if (save) saveState();
}

function renderCurrentCard() {
  const card = state.currentCard;
  els.targetSelect.value = card.target;
  els.cardBody.value = card.body;
  els.rawInput.value = card.rawInput;
  els.cardStatus.textContent = card.status;
  els.bodyStats.textContent = `${card.body.trim().length} 字`;
}

function renderShape() {
  els.tokenCard.dataset.shape = state.ui.shape;
  els.tokenCard.classList.remove('shape-envelope', 'shape-bubble', 'shape-token');
  els.tokenCard.classList.add(`shape-${state.ui.shape}`);

  els.shapeChips.forEach((chip) => {
    chip.classList.toggle('active', chip.dataset.shape === state.ui.shape);
  });
}

function renderStack() {
  const stack = [...state.stack].sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
  els.stackCount.textContent = `${stack.length} 张`;

  els.stackList.innerHTML = stack
    .map((card) => {
      const active = state.selectedStackId === card.id ? 'active' : '';
      return `
        <article class="stack-card ${active}" data-id="${card.id}">
          <div class="stack-card-head">
            <strong>${escapeHtml(card.target)}</strong>
            <span class="stack-count">${escapeHtml(card.status)}</span>
          </div>
          <p class="stack-card-summary">${escapeHtml(card.summary || summarize(card.body))}</p>
          <div class="stack-meta">
            <small>${formatTime(card.timestamp)}</small>
            <small>${escapeHtml(card.title)}</small>
          </div>
        </article>
      `;
    })
    .join('');

  els.stackList.querySelectorAll('.stack-card').forEach((node) => {
    node.addEventListener('click', () => {
      state.selectedStackId = node.dataset.id;
      persistAndRender();
    });
  });
}

function renderDetail() {
  const card = state.stack.find((item) => item.id === state.selectedStackId);

  if (!card) {
    els.detailEmpty.classList.remove('hidden');
    els.detailContent.classList.add('hidden');
    return;
  }

  els.detailEmpty.classList.add('hidden');
  els.detailContent.classList.remove('hidden');
  els.detailTarget.textContent = card.target;
  els.detailTime.textContent = formatTime(card.timestamp, true);
  els.detailSummary.textContent = card.summary || summarize(card.body);
  els.detailBody.textContent = card.body;
}

function renderDrawer() {
  els.stackDrawer.classList.toggle('hidden', !state.stackOpen);
}

function applyFloatingPosition() {
  if (window.innerWidth <= 900) {
    els.tokenCard.style.left = '';
    els.tokenCard.style.top = '';
    els.tokenCard.style.transform = '';
    return;
  }

  if (!state.ui.floatingPosition) {
    centerCardIfNeeded();
  }

  const width = els.tokenCard.offsetWidth;
  const height = els.tokenCard.offsetHeight;
  const margin = 18;
  const maxLeft = Math.max(margin, window.innerWidth - width - margin);
  const maxTop = Math.max(margin, window.innerHeight - height - margin);

  state.ui.floatingPosition.left = clamp(state.ui.floatingPosition.left, margin, maxLeft);
  state.ui.floatingPosition.top = clamp(state.ui.floatingPosition.top, margin, maxTop);

  els.tokenCard.style.left = `${state.ui.floatingPosition.left}px`;
  els.tokenCard.style.top = `${state.ui.floatingPosition.top}px`;
  els.tokenCard.style.transform = 'translate3d(0, 0, 0)';
}

function centerCardIfNeeded() {
  if (state.ui.floatingPosition || window.innerWidth <= 900) return;

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
    saveState();
  }
}

async function handleSendCurrentCard() {
  const payload = structuredClone(state.currentCard);
  const result = await bridge.sendVibeHub(payload);
  const sentCard = createSentCard({
    ...payload,
    title: 'Vibe Hub',
    status: '已发送',
    summary: summarize(payload.body),
    timestamp: result.sentAt,
  });

  state.stack.unshift(sentCard);
  state.selectedStackId = sentCard.id;
  state.stackOpen = true;
  state.currentCard.status = '已发送';
  state.currentCard.lastAction = `已发送到 ${payload.target}`;
  hideFeedbackBadge();
  showToast(`已发送到 ${payload.target}`);
  persistAndRender();
}

async function handleRewrite() {
  const before = state.currentCard.body;
  const result = await bridge.rewriteToken(state.currentCard);
  state.currentCard.body = result.body;
  state.currentCard.status = result.status;
  state.currentCard.lastAction = '已重写正文';
  showFeedbackBadge(before !== result.body ? '已重写成更清晰的版本' : '已按当前内容重写', 'rewrite');
  showToast(before !== result.body ? '已重写成更清晰的版本' : '已按当前内容重写');
  persistAndRender();
}

async function handleShorten() {
  const before = state.currentCard.body;
  const result = await bridge.shortenToken(state.currentCard);
  state.currentCard.body = result.body;
  state.currentCard.status = result.status;
  state.currentCard.lastAction = '已压缩正文';
  showFeedbackBadge(before !== result.body ? '已压缩为更短版本' : '内容已经很短了', 'shorten');
  showToast(before !== result.body ? '已压缩卡片内容' : '内容已经很短了');
  persistAndRender();
}

function handleCancel() {
  state.currentCard.status = '已取消';
  state.currentCard.lastAction = '本次发送已取消';
  hideFeedbackBadge();
  showToast('已取消');
  persistAndRender();
}

async function handleDetailResend() {
  const card = getSelectedCard();
  if (!card) return;

  await bridge.sendVibeHub(card);
  showToast(`已再次发送到 ${card.target}`);
}

function handleDetailEditResend() {
  const card = getSelectedCard();
  if (!card) return;

  state.currentCard = {
    id: `draft-${card.id}`,
    title: 'Vibe Hub',
    status: '待发送',
    target: card.target,
    mode: '历史卡片再编辑',
    body: card.body,
    rawInput: card.rawInput || card.body,
    lastAction: '已从历史卡片载入',
  };
  state.stackOpen = false;
  hideFeedbackBadge();
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
    mode: '转发',
    body: card.body,
    rawInput: card.rawInput || card.body,
    lastAction: `准备转发到 ${nextTarget}`,
  };
  state.stackOpen = false;
  hideFeedbackBadge();
  showToast(`已切换到 ${nextTarget}，可确认后发送`);
  persistAndRender();
}

function setShape(shape) {
  if (!SHAPES.includes(shape)) return;
  state.ui.shape = shape;
  showToast(`已切换到${shapeLabel(shape)}`);
  persistAndRender();
}

function shapeLabel(shape) {
  if (shape === 'envelope') return '透明信封';
  if (shape === 'bubble') return '透明对话气泡';
  return '切角 Token 牌';
}

function showFeedbackBadge(text, kind) {
  clearTimeout(feedbackTimer);
  els.feedbackBadge.textContent = text;
  els.feedbackBadge.classList.remove('hidden', 'rewrite', 'shorten');
  if (kind) els.feedbackBadge.classList.add(kind);
  feedbackTimer = setTimeout(() => {
    hideFeedbackBadge();
  }, 2600);
}

function hideFeedbackBadge() {
  clearTimeout(feedbackTimer);
  if (!els.feedbackBadge) return;
  els.feedbackBadge.textContent = '';
  els.feedbackBadge.classList.add('hidden');
  els.feedbackBadge.classList.remove('rewrite', 'shorten');
}

function getSelectedCard() {
  return state.stack.find((item) => item.id === state.selectedStackId);
}

function createSentCard(card) {
  return {
    id: crypto.randomUUID(),
    title: card.title,
    status: card.status || '已发送',
    target: card.target,
    mode: card.mode || '已发送卡片',
    body: card.body,
    rawInput: card.rawInput,
    summary: card.summary || summarize(card.body),
    timestamp: card.timestamp || new Date().toISOString(),
  };
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
  toastTimer = setTimeout(() => {
    els.toast.classList.remove('show');
  }, 1800);
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
  if (event.touches && event.touches[0]) return event.touches[0];
  if (event.changedTouches && event.changedTouches[0]) return event.changedTouches[0];
  return event;
}

function isInteractiveTarget(node) {
  return Boolean(node.closest('button, select, textarea, summary, option'));
}
