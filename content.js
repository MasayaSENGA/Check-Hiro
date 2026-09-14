/**
 * チェックひろ - content script
 *
 * Shift キーを押しながらチェックボックスをクリックすると、
 * 直前にクリックしたチェックボックスとの間にあるチェックボックスを
 * まとめて同じ状態（ON / OFF）にする。
 *
 * 実装方針:
 *  - document の click を capture フェーズで監視（ページ側の stopPropagation に影響されない）
 *  - 範囲内のチェックボックスは .click() で切り替える
 *    → React / Vue などフレームワークの change ハンドラも正しく発火する
 *  - .click() が生む合成イベントは isTrusted === false なので無視して再入を防ぐ
 *  - Chrome は Shift+クリックを「テキスト選択の拡張」と解釈し、<label> を Shift+クリック
 *    しても関連付けられた input への click を転送しない。そのため label の Shift+クリックは
 *    ブラウザの既定動作を止めて、拡張機能側でチェックボックスを切り替える。
 */
(() => {
  'use strict';

  const CHECKBOX_SELECTOR = 'input[type="checkbox"]';

  /** 直前に（人間が）クリックしたチェックボックス */
  let lastClicked = null;

  function isCheckbox(el) {
    return el instanceof HTMLInputElement && el.type === 'checkbox';
  }

  /** イベントの本当のターゲット（Shadow DOM 内でも取得できる） */
  function realTarget(event) {
    const path = typeof event.composedPath === 'function' ? event.composedPath() : null;
    return path && path.length ? path[0] : event.target;
  }

  /** label クリック時に関連付けられているチェックボックスを返す */
  function checkboxFromLabel(el) {
    const label = el instanceof Element ? el.closest('label') : null;
    if (!label) return null;
    const control = label.control;
    return isCheckbox(control) ? control : null;
  }

  /** 対象となるチェックボックスを DOM 順に列挙 */
  function collectCheckboxes(root) {
    return Array.from(root.querySelectorAll(CHECKBOX_SELECTOR));
  }

  /**
   * from と to の間（両端を除く）にあるチェックボックスを desired の状態にする。
   * 戻り値は切り替えた個数。
   */
  function applyRange(from, to, desired) {
    const root = to.getRootNode();
    const all = collectCheckboxes(
      root instanceof Document || root instanceof ShadowRoot ? root : document
    );

    const fromIndex = all.indexOf(from);
    const toIndex = all.indexOf(to);
    if (fromIndex === -1 || toIndex === -1 || fromIndex === toIndex) return 0;

    const start = Math.min(fromIndex, toIndex);
    const end = Math.max(fromIndex, toIndex);

    // 両端が同じ form に属している場合は、その form 内だけを対象にする
    const sameForm = from.form === to.form;
    const form = from.form;

    let changed = 0;
    for (let i = start + 1; i < end; i++) {
      const cb = all[i];
      if (cb.disabled) continue;
      if (sameForm && cb.form !== form) continue;
      if (cb.checked === desired) continue;

      // .click() で切り替えることでページ側の change / input ハンドラも発火させる。
      // ページ側が preventDefault で拒否した場合は状態を強制しない。
      cb.click();
      changed++;
    }
    return changed;
  }

  /** 範囲選択の起点として使える直前クリックか */
  function isUsableAnchor(previous, target) {
    return (
      previous &&
      previous !== target &&
      previous.isConnected &&
      previous.getRootNode() === target.getRootNode()
    );
  }

  function onClick(event) {
    // 自分が発火させた .click() や、ページ側スクリプトの合成クリックは無視
    if (!event.isTrusted) return;
    if (event.button !== 0) return;

    const target = realTarget(event);

    // --- <label> 経由のクリック ---------------------------------------------
    if (!isCheckbox(target)) {
      const cb = checkboxFromLabel(target);
      if (!cb || !event.shiftKey || cb.disabled) return;

      // ブラウザの既定動作（選択拡張／label の活性化）を止めて自前で切り替える
      event.preventDefault();

      const previous = lastClicked;
      lastClicked = cb;

      cb.click(); // 合成クリック → 自身は isTrusted=false なので再入しない
      if (isUsableAnchor(previous, cb)) {
        applyRange(previous, cb, cb.checked);
      }
      return;
    }

    // --- チェックボックス自体のクリック ---------------------------------------
    const previous = lastClicked;
    lastClicked = target;

    if (!event.shiftKey) return;
    if (!isUsableAnchor(previous, target)) return;

    // ブラウザはクリック時点でチェック状態を切り替えている。
    // ただしページ側が preventDefault すると元に戻るため、
    // クリック処理が完了した次のタイミングで最終状態を読み取る。
    setTimeout(() => {
      if (!target.isConnected) return;
      applyRange(previous, target, target.checked);
    }, 0);
  }

  /** Shift+mousedown による不要なテキスト選択の拡張を抑止する */
  function onMouseDown(event) {
    if (!event.isTrusted || !event.shiftKey || event.button !== 0) return;
    const target = realTarget(event);
    if (isCheckbox(target) || checkboxFromLabel(target)) {
      event.preventDefault();
    }
  }

  document.addEventListener('mousedown', onMouseDown, true);
  document.addEventListener('click', onClick, true);
})();
