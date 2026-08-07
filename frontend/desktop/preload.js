const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
    getVersion: () => ipcRenderer.invoke('get-version'),
    login: (username, password, apiUrl) => ipcRenderer.invoke('login', username, password, apiUrl),
    ask: (query, token, apiUrl) => ipcRenderer.invoke('ask', query, token, apiUrl),
    saveSettings: (settings) => ipcRenderer.invoke('save-settings', settings),
    loadSettings: () => ipcRenderer.invoke('load-settings'),
});