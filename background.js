/**
 * チェックひろ - service worker
 * オフのときはツールバーアイコンに「OFF」バッジを表示する。
 */
const STORAGE_KEY = 'enabled';

function updateBadge(enabled) {
  chrome.action.setBadgeText({ text: enabled ? '' : 'OFF' });
  chrome.action.setBadgeBackgroundColor({ color: '#6b7280' });
}

function refreshBadge() {
  chrome.storage.sync.get({ [STORAGE_KEY]: true }, (items) => {
    updateBadge(Boolean(items[STORAGE_KEY]));
  });
}

chrome.runtime.onInstalled.addListener(() => {
  // 初回インストール時は有効で始める（既存の設定があればそのまま）
  chrome.storage.sync.get(STORAGE_KEY, (items) => {
    if (typeof items[STORAGE_KEY] !== 'boolean') {
      chrome.storage.sync.set({ [STORAGE_KEY]: true });
    }
    refreshBadge();
  });
});

chrome.runtime.onStartup.addListener(refreshBadge);

chrome.storage.onChanged.addListener((changes, area) => {
  if (area !== 'sync' || !(STORAGE_KEY in changes)) return;
  updateBadge(Boolean(changes[STORAGE_KEY].newValue));
});

// service worker が再起動した場合にもバッジを合わせる
refreshBadge();
