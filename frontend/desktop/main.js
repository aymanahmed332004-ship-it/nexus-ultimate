const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const fs = require('fs');
const axios = require('axios');

const SETTINGS_FILE = path.join(app.getPath('userData'), 'settings.json');

function loadSettings() {
    try {
        if (fs.existsSync(SETTINGS_FILE)) {
            return JSON.parse(fs.readFileSync(SETTINGS_FILE, 'utf8'));
        }
    } catch (e) {}
    return { apiUrl: 'https://your-server.onrender.com' };
}

function saveSettings(settings) {
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2));
}

function createWindow() {
    const win = new BrowserWindow({
        width: 1200,
        height: 800,
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            preload: path.join(__dirname, 'preload.js'),
        },
    });
    win.loadFile('renderer.html');
    win.setMenuBarVisibility(false);
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});

ipcMain.handle('get-version', () => 'NEXUS-ULTIMATE v4.1.0');

ipcMain.handle('login', async (event, username, password, apiUrl) => {
    try {
        const response = await axios.post(`${apiUrl}/auth/login`, { username, password });
        return { success: true, token: response.data.access_token, user_id: response.data.user_id };
    } catch (error) {
        return { success: false, error: error.response?.data?.detail || error.message };
    }
});

ipcMain.handle('ask', async (event, query, token, apiUrl) => {
    try {
        const response = await axios.post(`${apiUrl}/ask`, { query, language: 'auto' }, { headers: { Authorization: `Bearer ${token}` } });
        return { success: true, response: response.data.response };
    } catch (error) {
        return { success: false, error: error.response?.data?.detail || error.message };
    }
});

ipcMain.handle('save-settings', (event, settings) => {
    saveSettings(settings);
    return { success: true };
});

ipcMain.handle('load-settings', () => {
    return loadSettings();
});