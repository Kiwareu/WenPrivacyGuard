// Wen Privacy Guard WebUI
// Storage: KernelSU / MMRL WebUI can read/write via ksu.exec.
// Fallback (plain browser preview): localStorage, so the UI is testable
// without a device. On device, ksu.exec is tried first.
// Config path on device: /data/adb/wenprivacyguard/config.json
// Root status: /data/adb/wenprivacyguard/root_status.json
// Telemetry DB: bundled in the module at scripts/telemetry_db.json -
// the WebUI fetches a copy shipped in webroot/ (see build: copy it in).
const CFG_KEY = 'wpg_config_v1';
const DEFAULTS = { version: 1, global: { enabled: false, telemetry_guard: false, app_list_guard: false, strict_mode: false }, components: {} };

let state = JSON.parse(JSON.stringify(DEFAULTS));
let db = null;

async function ksuExec(cmd) {
  if (window.ksu && window.ksu.exec) {
    const r = await window.ksu.exec(cmd);
    return (r && r.stdout) || '';
  }
  throw new Error('no ksu');
}
async function readFile(path) {
  try { return await ksuExec(`cat ${path} 2>/dev/null`); } catch (e) { return localStorage.getItem(CFG_KEY) || ''; }
}
async function writeFile(path, text) {
  try {
    const b64 = btoa(unescape(encodeURIComponent(text)));
    await ksuExec(`echo ${b64} | base64 -d > ${path} && chmod 0600 ${path}`);
    return true;
  } catch (e) {
    localStorage.setItem(CFG_KEY, text);
    return false; // preview mode
  }
}
function setSwitch(id, on) {
  const el = document.getElementById(id);
  if (el) el.setAttribute('aria-checked', on ? 'true' : 'false');
}
function bindSwitch(id, get, set) {
  const el = document.getElementById(id);
  el.addEventListener('click', () => { const v = !get(); set(v); setSwitch(id, v); renderStatus(); });
}
function renderStatus() {
  document.getElementById('modStatus').textContent = state.global.enabled ? '已启用' : '未启用';
  setSwitch('swEnabled', !!state.global.enabled);
  setSwitch('swAppList', !!state.global.app_list_guard);
}
function renderVendors(highRiskAllowed) {
  const host = document.getElementById('vendorList');
  host.innerHTML = '';
  (db.vendors || []).forEach(v => {
    const h = document.createElement('div');
    h.className = 'vendor'; h.textContent = v.vendor;
    host.appendChild(h);
    v.packages.forEach(p => {
      const row = document.createElement('div');
      row.className = 'pkg';
      const on = !!state.components[p.package];
      const disabled = !highRiskAllowed && p.risk === 'medium';
      row.innerHTML = `<div class="info"><div class="name">${p.name}</div>
        <div class="desc">${p.what} · <code>${p.package}</code></div>
        <div class="breaks">停用后影响：${p.breaks_what}</div></div>
        <button class="switch" role="switch" aria-checked="${on}" ${disabled ? 'disabled' : ''}><span class="knob"></span></button>`;
      const sw = row.querySelector('.switch');
      sw.addEventListener('click', () => {
        const cur = !!state.components[p.package];
        state.components[p.package] = !cur;
        sw.setAttribute('aria-checked', String(!cur));
      });
      host.appendChild(row);
    });
  });
}
async function load() {
  // Telemetry DB: try bundled webroot copy, else fall back to a minimal list.
  try {
    const r = await fetch('telemetry_db.json');
    db = await r.json();
  } catch (e) {
    db = { vendors: [{ vendor: 'Xiaomi / Redmi / POCO', packages: [
      { package: 'com.miui.analytics', name: '小米分析', what: '系统分析上报', breaks_what: '系统使用统计' },
      { package: 'com.mobiletools.systemhelper', name: 'SystemHelper', what: '联通终端管理模块', breaks_what: '联通终端管理；不影响通话/上网' } ] }] };
  }
  let raw = await readFile('/data/adb/wenprivacyguard/config.json');
  if (raw) { try { state = Object.assign(JSON.parse(JSON.stringify(DEFAULTS)), JSON.parse(raw)); } catch (e) {} }
  let root = {};
  try { const rr = await readFile('/data/adb/wenprivacyguard/root_status.json'); if (rr) root = JSON.parse(rr); } catch (e) {}
  document.getElementById('rootSolution').textContent = root.root_solution || '—';
  document.getElementById('blState').textContent = root.bootloader_locked === 'false' ? '已解锁' : root.bootloader_locked === 'true' ? '已锁定' : '—';
  document.getElementById('rootType').textContent = root.root_type === 'formal' ? '正式 Root' : root.root_type === 'temporary' ? '临时 Root' : '—';
  const temp = root.root_type === 'temporary';
  const banner = document.getElementById('tempBanner');
  if (temp) {
    banner.classList.remove('hidden');
    banner.textContent = '检测到临时 Root（未解锁 Bootloader）：高风险功能已隐藏。先解锁 BL 并正式安装 Root，再用完整功能，否则后续可能变砖。';
  }
  const highRisk = root.high_risk_allowed !== false;
  renderStatus();
  renderVendors(highRisk);
  bindSwitch('swEnabled', () => !!state.global.enabled, v => { state.global.enabled = v; });
  bindSwitch('swAppList', () => !!state.global.app_list_guard, v => { state.global.app_list_guard = v; });
  document.getElementById('btnClearAll').addEventListener('click', () => {
    state.components = {}; state.global.app_list_guard = false; state.global.telemetry_guard = false;
    renderStatus(); renderVendors(highRisk);
    document.getElementById('saveMsg').classList.remove('hidden');
  });
  document.getElementById('btnSave').addEventListener('click', async () => {
    state.updated_at = new Date().toISOString();
    await writeFile('/data/adb/wenprivacyguard/config.json', JSON.stringify(state, null, 2));
    document.getElementById('saveMsg').classList.remove('hidden');
  });
}
load();
