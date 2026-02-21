/**
 * Habit Tracker AI — Admin Panel
 * Vanilla JS SPA for platform management.
 */

const API_BASE = window.location.port === '8080'
    ? 'http://localhost:8000/api'
    : `${window.location.protocol}//${window.location.hostname}:8000/api`;

let token = localStorage.getItem('admin_token');
let currentTab = 'analytics';
let usersPage = 0;
let habitsPage = 0;
let chatsPage = 0;
const PAGE_SIZE = 20;

// ─── Toast ───

function toast(message, type = 'success') {
    const container = document.getElementById('toast-container');
    const el = document.createElement('div');
    el.className = `toast toast-${type}`;
    el.textContent = message;
    container.appendChild(el);
    setTimeout(() => el.remove(), 3000);
}

// ─── API Helper ───

async function api(method, path, body = null) {
    const opts = {
        method,
        headers: { 'Content-Type': 'application/json' },
    };
    if (token) opts.headers['Authorization'] = `Bearer ${token}`;
    if (body) opts.body = JSON.stringify(body);

    const res = await fetch(`${API_BASE}${path}`, opts);
    if (res.status === 401) {
        logout();
        throw new Error('Unauthorized');
    }
    if (res.status === 403) {
        throw new Error('Нет прав администратора');
    }
    if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail || `Error ${res.status}`);
    }
    return res.json();
}

// ─── Auth ───

function showScreen(id) {
    document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
    document.getElementById(id).classList.add('active');
}

async function login(username, password) {
    const res = await fetch(`${API_BASE}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `username=${encodeURIComponent(username)}&password=${encodeURIComponent(password)}`,
    });
    if (!res.ok) throw new Error('Неверный логин или пароль');
    const data = await res.json();
    token = data.access_token;
    localStorage.setItem('admin_token', token);

    const me = await api('GET', '/auth/me');
    if (!me.is_admin) {
        localStorage.removeItem('admin_token');
        token = null;
        throw new Error('Учётная запись не имеет прав администратора');
    }
    document.getElementById('admin-info').textContent = `👤 ${me.username}`;
    showScreen('dashboard-screen');
    loadTab('analytics');
}

function logout() {
    token = null;
    localStorage.removeItem('admin_token');
    showScreen('login-screen');
    document.getElementById('login-error').textContent = '';
}

// ─── Tab Navigation ───

function loadTab(tab) {
    currentTab = tab;
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.getElementById(`tab-${tab}`).classList.add('active');
    document.querySelectorAll('.nav-link').forEach(l => {
        l.classList.toggle('active', l.dataset.tab === tab);
    });

    switch (tab) {
        case 'analytics': loadAnalytics(); break;
        case 'users': usersPage = 0; loadUsers(); break;
        case 'habits': habitsPage = 0; loadHabits(); break;
        case 'chats': chatsPage = 0; loadChats(); break;
    }
}

// ─── Analytics ───

async function loadAnalytics() {
    const grid = document.getElementById('stats-grid');
    grid.innerHTML = '<div class="loading">Загрузка</div>';

    try {
        const data = await api('GET', '/admin/analytics');
        grid.innerHTML = `
            ${statCard('👥', data.total_users, 'Всего пользователей')}
            ${statCard('✅', data.active_users, 'Активных')}
            ${statCard('🆕', data.new_users_7d, 'Новых за 7 дней')}
            ${statCard('🎯', data.total_habits, 'Всего привычек')}
            ${statCard('📈', data.active_habits, 'Активных привычек')}
            ${statCard('🆕', data.new_habits_7d, 'Новых привычек / 7д')}
            ${statCard('📝', data.total_logs, 'Всего записей')}
            ${statCard('🏆', data.completion_rate + '%', 'Выполнение')}
        `;

        const catEl = document.getElementById('top-categories');
        if (data.top_categories.length === 0) {
            catEl.innerHTML = '<p style="color:var(--text-secondary)">Нет данных</p>';
            return;
        }
        const maxCount = Math.max(...data.top_categories.map(c => c.count));
        catEl.innerHTML = data.top_categories.map(c => `
            <div class="category-bar">
                <span class="cat-name">${categoryLabel(c.category)}</span>
                <div class="cat-track">
                    <div class="cat-fill" style="width:${(c.count / maxCount * 100)}%"></div>
                </div>
                <span class="cat-count">${c.count}</span>
            </div>
        `).join('');
    } catch (e) {
        grid.innerHTML = `<p class="error-text">${e.message}</p>`;
    }
}

function statCard(icon, value, label) {
    return `<div class="stat-card">
        <div class="stat-icon">${icon}</div>
        <div class="stat-value">${value}</div>
        <div class="stat-label">${label}</div>
    </div>`;
}

const CATEGORY_LABELS = {
    health: '❤️ Здоровье', fitness: '💪 Фитнес', nutrition: '🥗 Питание',
    mindfulness: '🧘 Осознанность', productivity: '⚡ Продуктивность',
    learning: '📚 Обучение', social: '🤝 Общение', sleep: '😴 Сон',
    finance: '💰 Финансы', other: '📦 Другое',
};

function categoryLabel(cat) {
    return CATEGORY_LABELS[cat] || cat;
}

// ─── Users ───

async function loadUsers() {
    const tbody = document.getElementById('users-tbody');
    tbody.innerHTML = '<tr><td colspan="8" class="loading">Загрузка</td></tr>';
    const search = document.getElementById('users-search').value;

    try {
        const data = await api('GET', `/admin/users?skip=${usersPage * PAGE_SIZE}&limit=${PAGE_SIZE}&search=${encodeURIComponent(search)}`);
        const users = data.items;

        if (users.length === 0) {
            tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:30px;color:var(--text-secondary)">Пользователи не найдены</td></tr>';
        } else {
            tbody.innerHTML = users.map(u => `
                <tr>
                    <td>${u.id}</td>
                    <td><strong>${esc(u.username)}</strong></td>
                    <td>${esc(u.email)}</td>
                    <td>${u.habits_count}</td>
                    <td><span class="badge ${u.is_active ? 'badge-active' : 'badge-blocked'}">${u.is_active ? 'Активен' : 'Заблокирован'}</span></td>
                    <td><span class="badge ${u.is_admin ? 'badge-admin' : 'badge-user'}">${u.is_admin ? 'Админ' : 'Юзер'}</span></td>
                    <td>${formatDate(u.created_at)}</td>
                    <td class="actions">
                        ${u.is_active
                            ? `<button class="btn btn-warning btn-xs" onclick="blockUser(${u.id})">Блок</button>`
                            : `<button class="btn btn-success btn-xs" onclick="unblockUser(${u.id})">Разблок</button>`}
                        <button class="btn btn-outline btn-xs" onclick="toggleAdmin(${u.id})">${u.is_admin ? '⬇ Юзер' : '⬆ Админ'}</button>
                        <button class="btn btn-danger btn-xs" onclick="deleteUser(${u.id}, '${esc(u.username)}')">✕</button>
                    </td>
                </tr>
            `).join('');
        }

        renderPagination('users-pagination', data.total, usersPage, PAGE_SIZE, (p) => { usersPage = p; loadUsers(); });
    } catch (e) {
        tbody.innerHTML = `<tr><td colspan="8" class="error-text">${e.message}</td></tr>`;
    }
}

async function blockUser(id) {
    if (!confirm('Заблокировать пользователя?')) return;
    try { await api('PATCH', `/admin/users/${id}/block`); toast('Пользователь заблокирован'); loadUsers(); }
    catch(e) { toast(e.message, 'error'); }
}

async function unblockUser(id) {
    try { await api('PATCH', `/admin/users/${id}/unblock`); toast('Пользователь разблокирован'); loadUsers(); }
    catch(e) { toast(e.message, 'error'); }
}

async function deleteUser(id, name) {
    if (!confirm(`Удалить пользователя "${name}" и все его данные?`)) return;
    try { await api('DELETE', `/admin/users/${id}`); toast('Пользователь удалён'); loadUsers(); }
    catch(e) { toast(e.message, 'error'); }
}

async function toggleAdmin(id) {
    try {
        const r = await api('PATCH', `/admin/users/${id}/toggle-admin`);
        toast(r.message); loadUsers();
    } catch(e) { toast(e.message, 'error'); }
}

// ─── Habits ───

async function loadHabits() {
    const tbody = document.getElementById('habits-tbody');
    tbody.innerHTML = '<tr><td colspan="10" class="loading">Загрузка</td></tr>';
    const search = document.getElementById('habits-search').value;

    try {
        const data = await api('GET', `/admin/habits?skip=${habitsPage * PAGE_SIZE}&limit=${PAGE_SIZE}&search=${encodeURIComponent(search)}`);
        const habits = data.items;

        if (habits.length === 0) {
            tbody.innerHTML = '<tr><td colspan="10" style="text-align:center;padding:30px;color:var(--text-secondary)">Привычки не найдены</td></tr>';
        } else {
            tbody.innerHTML = habits.map(h => `
                <tr>
                    <td>${h.id}</td>
                    <td><strong>${esc(h.name)}</strong></td>
                    <td>${esc(h.username)}</td>
                    <td>${categoryLabel(h.category)}</td>
                    <td>${h.cooldown_days}д</td>
                    <td>${h.target_time || '—'}${h.reminder_time ? ' 🔔' + h.reminder_time : ''}</td>
                    <td>${h.logs_count}</td>
                    <td>${h.completion_rate}%</td>
                    <td><span class="badge ${h.is_active ? 'badge-active' : 'badge-blocked'}">${h.is_active ? 'Да' : 'Нет'}</span></td>
                    <td class="actions">
                        <button class="btn btn-primary btn-xs" onclick="openHabitLogs(${h.id}, '${esc(h.name)}')">📅 Логи</button>
                        <button class="btn btn-warning btn-xs" onclick="generateLogs(${h.id})">⚡ Генерация</button>
                        <button class="btn btn-danger btn-xs" onclick="deleteHabit(${h.id}, '${esc(h.name)}')">✕</button>
                    </td>
                </tr>
            `).join('');
        }

        renderPagination('habits-pagination', data.total, habitsPage, PAGE_SIZE, (p) => { habitsPage = p; loadHabits(); });
    } catch (e) {
        tbody.innerHTML = `<tr><td colspan="10" class="error-text">${e.message}</td></tr>`;
    }
}

async function deleteHabit(id, name) {
    if (!confirm(`Удалить привычку "${name}"?`)) return;
    try { await api('DELETE', `/admin/habits/${id}`); toast('Привычка удалена'); loadHabits(); }
    catch(e) { toast(e.message, 'error'); }
}

async function generateLogs(habitId) {
    const days = prompt('Сколько дней сгенерировать?', '30');
    if (!days) return;
    const pct = prompt('Процент выполнения (0-100)?', '75');
    if (!pct) return;
    try {
        const r = await api('POST', '/admin/logs/generate', {
            habit_id: habitId,
            days: parseInt(days),
            completion_percent: parseInt(pct),
        });
        toast(r.message);
        loadHabits();
    } catch(e) { toast(e.message, 'error'); }
}

// ─── Modal: Habit Logs ───

function openModal() { document.getElementById('modal-overlay').style.display = 'flex'; }
function closeModal() { document.getElementById('modal-overlay').style.display = 'none'; }

async function openHabitLogs(habitId, habitName) {
    document.getElementById('modal-title').textContent = `📅 ${habitName} — Логи`;
    document.getElementById('modal-body').innerHTML = '<div class="loading">Загрузка</div>';
    openModal();

    try {
        const logs = await api('GET', `/admin/habits/${habitId}/logs?days=60`);

        // Build calendar
        const logMap = {};
        logs.forEach(l => { logMap[l.date] = l; });

        const today = new Date();
        let calendarHTML = '<div class="log-calendar">';
        // Day headers
        ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'].forEach(d => {
            calendarHTML += `<div style="text-align:center;font-size:10px;color:var(--text-secondary);font-weight:600">${d}</div>`;
        });

        for (let i = 59; i >= 0; i--) {
            const d = new Date(today);
            d.setDate(d.getDate() - i);
            const dateStr = d.toISOString().split('T')[0];
            const log = logMap[dateStr];
            let cls = 'empty';
            if (log && log.completed) cls = 'completed';
            else if (log && !log.completed) cls = 'missed';

            calendarHTML += `<div class="log-day ${cls}" title="${dateStr}" onclick="toggleLogDay(${habitId}, '${dateStr}', ${log ? (log.completed ? 'true' : 'false') : 'null'}, '${habitName}')">${d.getDate()}</div>`;
        }
        calendarHTML += '</div>';

        // Log list
        let listHTML = '<h3 style="margin:12px 0 8px">Последние записи</h3>';
        if (logs.length === 0) {
            listHTML += '<p style="color:var(--text-secondary)">Нет записей</p>';
        } else {
            listHTML += '<table style="width:100%"><thead><tr><th>Дата</th><th>Статус</th><th>Заметка</th><th></th></tr></thead><tbody>';
            logs.slice(0, 30).forEach(l => {
                listHTML += `<tr>
                    <td>${l.date}</td>
                    <td><span class="badge ${l.completed ? 'badge-active' : 'badge-blocked'}">${l.completed ? '✅' : '❌'}</span></td>
                    <td>${esc(l.note || '—')}</td>
                    <td><button class="btn btn-danger btn-xs" onclick="deleteLog(${l.id}, ${habitId}, '${habitName}')">✕</button></td>
                </tr>`;
            });
            listHTML += '</tbody></table>';
        }

        document.getElementById('modal-body').innerHTML = calendarHTML + listHTML;
    } catch (e) {
        document.getElementById('modal-body').innerHTML = `<p class="error-text">${e.message}</p>`;
    }
}

async function toggleLogDay(habitId, dateStr, currentCompleted, habitName) {
    const newCompleted = currentCompleted === null ? true : !currentCompleted;
    try {
        await api('POST', '/admin/logs/edit', {
            habit_id: habitId,
            date: dateStr,
            completed: newCompleted,
            note: 'Edited by admin',
        });
        toast(`${dateStr}: ${newCompleted ? '✅' : '❌'}`);
        openHabitLogs(habitId, habitName); // Refresh
    } catch(e) { toast(e.message, 'error'); }
}

async function deleteLog(logId, habitId, habitName) {
    try {
        await api('DELETE', `/admin/logs/${logId}`);
        toast('Запись удалена');
        openHabitLogs(habitId, habitName);
    } catch(e) { toast(e.message, 'error'); }
}

// ─── Chats ───

async function loadChats() {
    const log = document.getElementById('chat-log');
    log.innerHTML = '<div class="loading">Загрузка</div>';

    try {
        const data = await api('GET', `/admin/chats?skip=${chatsPage * PAGE_SIZE}&limit=${PAGE_SIZE}`);
        const msgs = data.items;

        if (msgs.length === 0) {
            log.innerHTML = '<p style="text-align:center;padding:30px;color:var(--text-secondary)">Сообщений нет</p>';
        } else {
            log.innerHTML = msgs.map(m => `
                <div class="chat-entry ${m.role === 'user' ? 'user-msg' : 'assistant-msg'}">
                    <div class="chat-meta">
                        <strong>${esc(m.username)} (${m.role})</strong>
                        <span>${formatDateTime(m.timestamp)}</span>
                    </div>
                    ${esc(m.content)}
                </div>
            `).join('');
        }

        renderPagination('chats-pagination', data.total, chatsPage, PAGE_SIZE, (p) => { chatsPage = p; loadChats(); });
    } catch (e) {
        log.innerHTML = `<p class="error-text">${e.message}</p>`;
    }
}

// ─── Pagination ───

function renderPagination(elId, total, page, size, onPage) {
    const el = document.getElementById(elId);
    const totalPages = Math.ceil(total / size);
    if (totalPages <= 1) { el.innerHTML = ''; return; }

    el.innerHTML = `
        <button class="btn btn-outline btn-sm" ${page === 0 ? 'disabled' : ''} id="${elId}-prev">← Назад</button>
        <span class="page-info">${page + 1} / ${totalPages} (${total} записей)</span>
        <button class="btn btn-outline btn-sm" ${page >= totalPages - 1 ? 'disabled' : ''} id="${elId}-next">Вперёд →</button>
    `;
    document.getElementById(`${elId}-prev`).onclick = () => { if (page > 0) onPage(page - 1); };
    document.getElementById(`${elId}-next`).onclick = () => { if (page < totalPages - 1) onPage(page + 1); };
}

// ─── Helpers ───

function esc(str) {
    if (!str) return '';
    const d = document.createElement('div');
    d.textContent = str;
    return d.innerHTML;
}

function formatDate(iso) {
    return new Date(iso).toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

function formatDateTime(iso) {
    return new Date(iso).toLocaleString('ru-RU', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });
}

// ─── Init ───

document.getElementById('login-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const errEl = document.getElementById('login-error');
    const btn = document.getElementById('login-btn');
    errEl.textContent = '';
    btn.disabled = true;
    btn.textContent = 'Вход...';

    try {
        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;
        await login(username, password);
    } catch (err) {
        errEl.textContent = err.message;
    } finally {
        btn.disabled = false;
        btn.textContent = 'Войти';
    }
});

document.getElementById('logout-btn').addEventListener('click', logout);

document.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', (e) => {
        e.preventDefault();
        loadTab(link.dataset.tab);
    });
});

// Search debounce for users and habits
let searchTimeout;
document.getElementById('users-search').addEventListener('input', () => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => { usersPage = 0; loadUsers(); }, 400);
});

let habitsSearchTimeout;
document.getElementById('habits-search').addEventListener('input', () => {
    clearTimeout(habitsSearchTimeout);
    habitsSearchTimeout = setTimeout(() => { habitsPage = 0; loadHabits(); }, 400);
});

// Close modal on overlay click
document.getElementById('modal-overlay').addEventListener('click', (e) => {
    if (e.target === e.currentTarget) closeModal();
});

// Auto-login if token exists
(async () => {
    if (token) {
        try {
            const me = await api('GET', '/auth/me');
            if (me.is_admin) {
                document.getElementById('admin-info').textContent = `👤 ${me.username}`;
                showScreen('dashboard-screen');
                loadTab('analytics');
                return;
            }
        } catch (_) {}
        localStorage.removeItem('admin_token');
        token = null;
    }
    showScreen('login-screen');
})();

