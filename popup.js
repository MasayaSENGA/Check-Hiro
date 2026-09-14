/**
 * チェックひろ - popup
 * 機能のオン／オフを chrome.storage.sync に保存する。
 */
(() => {
  'use strict';

  const STORAGE_KEY = 'enabled';
  const checkbox = document.getElementById('enabled');
  const status = document.getElementById('status');
  const note = document.getElementById('note');

  function render(enabled) {
    checkbox.checked = enabled;
    status.textContent = enabled ? 'オン：Shift+クリックで範囲選択できます' : 'オフ：通常のクリック動作になります';
  }

  chrome.storage.sync.get({ [STORAGE_KEY]: true }, (items) => {
    render(Boolean(items[STORAGE_KEY]));
  });

  checkbox.addEventListener('change', () => {
    const enabled = checkbox.checked;
    render(enabled);
    note.hidden = false;
    chrome.storage.sync.set({ [STORAGE_KEY]: enabled });
  });

  // 別のウィンドウのポップアップなどで変更された場合にも追従する
  chrome.storage.onChanged.addListener((changes, area) => {
    if (area !== 'sync' || !(STORAGE_KEY in changes)) return;
    render(Boolean(changes[STORAGE_KEY].newValue));
  });
})();
