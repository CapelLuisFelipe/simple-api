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
