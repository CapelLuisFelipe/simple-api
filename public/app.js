// Dashboard JS — vanilla fetch, zero dependencies

const base = window.location.origin

// ── DOM refs ──────────────────────────────────────────────────────────────────
const resultInner = document.getElementById('result-inner')

// ── helpers ───────────────────────────────────────────────────────────────────
function showLoading(label) {
  resultInner.innerHTML = `
    <div class="status-bar loading">
      <span class="dot loading"></span>
      <span>${label}</span>
    </div>`
}

function showResult(status, ms, data, isStress) {
  const ok    = status >= 200 && status < 300
  const cls   = ok ? 'success' : 'error'
  const emoji = isStress ? '🔥' : ok ? '✅' : '❌'

  resultInner.innerHTML = `
    <div class="status-bar ${cls}">
      <span class="dot ${cls}"></span>
      <span>${emoji} HTTP ${status}</span>
      <span class="meta">${ms} ms</span>
    </div>
    <pre>${syntaxHighlight(data)}</pre>`
}

function showError(msg) {
  resultInner.innerHTML = `
    <div class="status-bar error">
      <span class="dot error"></span>
      <span>❌ ${msg}</span>
    </div>`
}

function syntaxHighlight(obj) {
  const json = JSON.stringify(obj, null, 2)
  return json.replace(
    /("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g,
    (m) => {
      if (/^"/.test(m)) return /:$/.test(m) ? `<span class="key">${m}</span>` : `<span class="str">${m}</span>`
      if (/true|false/.test(m)) return `<span class="bool">${m}</span>`
      if (/null/.test(m)) return `<span class="null">${m}</span>`
      return `<span class="num">${m}</span>`
    }
  )
}

function formatElapsed(ms) {
  const s = Math.floor(ms / 1000)
  if (s < 60) return `${s}s`
  return `${Math.floor(s / 60)}m ${s % 60}s`
}

async function call(path, label, isStress) {
  showLoading(label)
  const t0 = performance.now()
  try {
    const r    = await fetch(base + path)
    const ms   = Math.round(performance.now() - t0)
    const data = await r.json()
    showResult(r.status, ms, data, isStress)
  } catch (e) {
    showError(e.message)
  }
}

// ── API buttons ───────────────────────────────────────────────────────────────
document.getElementById('btn-root').addEventListener('click', () =>
  call('/', 'Chamando GET /', false))

document.getElementById('btn-connect').addEventListener('click', () =>
  call('/connect', 'Chamando GET /connect — aguarde conexão PostgreSQL…', false))

// ── Continuous stress ─────────────────────────────────────────────────────────
let loopRunning = false
let loopStart   = null

document.getElementById('btn-stress-loop').addEventListener('click', async () => {
  const btn   = document.getElementById('btn-stress-loop')
  const label = document.getElementById('loop-label')
  const icon  = document.getElementById('loop-icon')

  if (loopRunning) {
    loopRunning = false
    btn.classList.remove('active')
    icon.textContent  = '🔥'
    label.textContent = 'Iniciar Stress Contínuo'
    return
  }

  loopRunning = true
  loopStart   = Date.now()
  btn.classList.add('active')
  icon.textContent = '⏹'
  let round = 0

  while (loopRunning) {
    round++
    const elapsed = formatElapsed(Date.now() - loopStart)
    label.textContent = `Parar — rodada ${round} · ${elapsed}`
    await call(
      '/stress?seconds=30',
      `🔥 Stress contínuo — rodada ${round} · ${elapsed} em execução…`,
      true
    )
  }

  label.textContent = 'Iniciar Stress Contínuo'
  icon.textContent  = '🔥'
})

// ── Open-in-tab buttons ───────────────────────────────────────────────────────
document.getElementById('btn-open-root').addEventListener('click', () =>
  window.open(base + '/', '_blank'))

document.getElementById('btn-open-connect').addEventListener('click', () =>
  window.open(base + '/connect', '_blank'))

// ── Observability panel ───────────────────────────────────────────────────────

async function obsFetch(path) {
  try {
    const r = await fetch(base + path)
    return r.ok ? r.json() : null
  } catch { return null }
}

function fmtTime(iso) {
  if (!iso) return '—'
  return new Date(iso).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

function fmtDateTime(val) {
  if (!val) return '—'
  const d = new Date(val)
  return d.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' }) + ' ' +
         d.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
}

async function refreshStatus() {
  const el   = document.getElementById('obs-status')
  const data = await obsFetch('/obs/status')
  if (!data || data.error) {
    el.innerHTML = '<div class="obs-loading">Sem permissão IAM ainda</div>'
    return
  }
  const MAX = 4
  const squares = Array.from({ length: MAX }, (_, i) =>
    `<div class="task-sq${i < data.running ? ' active' : ''}"></div>`
  ).join('')
  el.innerHTML = `
    <div class="task-squares">${squares}</div>
    <div class="task-num">${data.running}</div>
    <div class="task-detail">
      running<br>
      desired: ${data.desired} &nbsp;·&nbsp; pending: ${data.pending}
    </div>`
}

async function refreshScalingEvents() {
  const el   = document.getElementById('obs-events')
  const data = await obsFetch('/obs/scaling-events')
  if (!data || data.error) {
    el.innerHTML = '<div class="obs-loading">Sem permissão IAM ainda</div>'
    return
  }
  if (!data.events.length) {
    el.innerHTML = '<div class="obs-loading">Nenhum evento de scaling ainda</div>'
    return
  }
  const items = data.events.map(e => {
    const isOut  = e.cause.includes('AlarmHigh')
    const dir    = isOut ? '↑' : '↓'
    const cls    = isOut ? 'out' : 'in'
    const match  = e.description.match(/(\d+)\.?$/)
    const count  = match ? match[1] : '?'
    const label  = isOut ? `Scale Out → ${count} tasks` : `Scale In → ${count} task${count === '1' ? '' : 's'}`
    return `
      <div class="event-item">
        <span class="event-dir ${cls}">${dir}</span>
        <div style="flex:1">
          <div class="event-desc">${label}</div>
          <div class="event-cause">${e.status}</div>
        </div>
        <span class="event-time">${fmtDateTime(e.startTime)}</span>
      </div>`
  }).join('')
  el.innerHTML = `<div class="event-list">${items}</div>`
}

async function refreshAlarmHistory() {
  const el   = document.getElementById('obs-alarms')
  const data = await obsFetch('/obs/alarm-history')
  if (!data || data.error) {
    el.innerHTML = '<div class="obs-loading">Sem permissão IAM ainda</div>'
    return
  }
  if (!data.items.length) {
    el.innerHTML = '<div class="obs-loading">Nenhum evento de alarme ainda</div>'
    return
  }
  const alarmLabel = { 'simple-api-cpu-high': 'CPU Alta (≥30%)', 'simple-api-cpu-low': 'CPU Baixa (≤20%)' }
  const items = data.items.map(item => {
    const cls   = item.state === 'ALARM' ? 'alarm' : item.state === 'OK' ? 'ok' : 'insufficient'
    const label = alarmLabel[item.alarm] || item.alarm
    return `
      <div class="alarm-item ${cls}">
        <span class="alarm-dot"></span>
        <div style="flex:1;min-width:0">
          <div class="alarm-name">${label}</div>
          ${item.metric ? `<span class="alarm-metric">CPU: ${item.metric}</span>` : ''}
        </div>
        <span class="alarm-state">${item.state}</span>
        <span class="alarm-time">${fmtDateTime(item.ts)}</span>
      </div>`
  }).join('')
  el.innerHTML = `<div class="alarm-list">${items}</div>`
}

async function refreshAllObs() {
  const icon = document.getElementById('obs-refresh-icon')
  icon.style.display = 'inline-block'
  icon.style.animation = 'spin 0.7s linear infinite'
  await Promise.all([refreshStatus(), refreshScalingEvents(), refreshAlarmHistory()])
  icon.style.animation = ''
}

document.getElementById('btn-obs-refresh').addEventListener('click', refreshAllObs)

// Auto-refresh obs every 10s while stress loop is active
let obsInterval = null
function startObsRefresh() {
  if (obsInterval) return
  obsInterval = setInterval(refreshAllObs, 10000)
}
function stopObsRefresh() {
  clearInterval(obsInterval)
  obsInterval = null
}

// Wire into stress loop toggle
document.getElementById('btn-stress-loop').addEventListener('click', () => {
  // loopRunning is toggled before this listener fires (defined above), so check state after tick
  setTimeout(() => {
    if (loopRunning) startObsRefresh()
    else stopObsRefresh()
  }, 0)
})

// Initial load on page open
refreshAllObs()
