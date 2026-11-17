/**
 * チェックひろ - service worker
 * - オフのときはツールバーアイコンに「OFF」バッジを表示する。
 * - コンテキストメニュー（全てチェック／全て解除）の管理とイベント中継を行う。
 */
const STORAGE_KEY = 'enabled';

const MENU_CHECK_ALL = 'check-hiro-check-all';
const MENU_UNCHECK_ALL = 'check-hiro-uncheck-all';

function updateBadge(enabled) {
  chrome.action.setBadgeText({ text: enabled ? '' : 'OFF' });
  chrome.action.setBadgeBackgroundColor({ color: '#6b7280' });
}

function refreshBadge() {
  chrome.storage.sync.get({ [STORAGE_KEY]: true }, (items) => {
    updateBadge(Boolean(items[STORAGE_KEY]));
  });
}

function setupContextMenus() {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: MENU_CHECK_ALL,
      title: 'ページ上のチェックボックスを全てチェック',
      contexts: ['all'],
    });
    chrome.contextMenus.create({
      id: MENU_UNCHECK_ALL,
      title: 'ページ上のチェックボックスを全て解除',
      contexts: ['all'],
    });
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
  setupContextMenus();
});

chrome.runtime.onStartup.addListener(refreshBadge);

chrome.storage.onChanged.addListener((changes, area) => {
  if (area !== 'sync' || !(STORAGE_KEY in changes)) return;
  updateBadge(Boolean(changes[STORAGE_KEY].newValue));
});

// コンテキストメニューのクリックイベント
chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (!tab || typeof tab.id !== 'number') return;
  if (info.menuItemId !== MENU_CHECK_ALL && info.menuItemId !== MENU_UNCHECK_ALL) return;

  const action = info.menuItemId === MENU_CHECK_ALL ? 'checkAll' : 'uncheckAll';
  const message = { action };

  // 右クリックしたフレームに直接送信し、サブフレームへの送信に失敗した場合はメインフレームへフォールバック
  if (typeof info.frameId === 'number' && info.frameId !== 0) {
    chrome.tabs.sendMessage(tab.id, message, { frameId: info.frameId }, () => {
      if (chrome.runtime.lastError) {
        chrome.tabs.sendMessage(tab.id, message, { frameId: 0 }, () => {
          void chrome.runtime.lastError;
        });
      }
    });
  } else {
    chrome.tabs.sendMessage(tab.id, message, { frameId: 0 }, () => {
      void chrome.runtime.lastError;
    });
  }
});

// service worker が再起動した場合にもバッジを合わせる
refreshBadge();
