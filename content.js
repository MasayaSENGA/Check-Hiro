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
 *  - 起点（直前クリック）は要素だけでなく「何番目か」も記録し、再描画で input 要素が
 *    差し替えられるページでも位置ベースで復元する
 */
(() => {
  'use strict';

  const CHECKBOX_SELECTOR = 'input[type="checkbox"]';
  const STORAGE_KEY = 'enabled';

  /**
   * 直前に（人間が）クリックしたチェックボックス（範囲選択の起点）。
   * { element, root, index, count } の形で保持する。詳細は setAnchor を参照。
   */
  let anchor = null;

  /** ポップアップで切り替える有効／無効フラグ（既定は有効） */
  let enabled = true;

  // ---- 設定の読み込みと変更の追従 -------------------------------------------
  // sandbox 化された iframe などでは chrome.storage が使えない場合があるため防御的に扱う
  try {
    chrome.storage.sync.get({ [STORAGE_KEY]: true }, (items) => {
      if (chrome.runtime.lastError) return;
      enabled = Boolean(items[STORAGE_KEY]);
    });
    chrome.storage.onChanged.addListener((changes, area) => {
      if (area !== 'sync' || !(STORAGE_KEY in changes)) return;
      enabled = Boolean(changes[STORAGE_KEY].newValue);
      if (!enabled) anchor = null;
    });
  } catch (_) {
    // chrome.storage が無い環境では常に有効として動作する
  }

  // ---- ユーティリティ ---------------------------------------------------------

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

  /** 要素が属する Document または ShadowRoot */
  function ownerRoot(el) {
    const root = el.getRootNode();
    return root instanceof Document || root instanceof ShadowRoot ? root : document;
  }

  /** 対象となるチェックボックスを DOM 順に列挙 */
  function collectCheckboxes(root) {
    return Array.from(root.querySelectorAll(CHECKBOX_SELECTOR));
  }

  // ---- 起点（直前にクリックしたチェックボックス）の記録 -----------------------
  //
  // 要素そのものに加えて「ルート内で何番目のチェックボックスか」も覚えておく。
  // React / Vue などが再描画で input 要素を差し替えた場合でも、チェックボックスの
  // 総数が変わっていなければ同じ位置の要素を起点として使えるようにするため。

  function setAnchor(cb) {
    const root = ownerRoot(cb);
    const all = collectCheckboxes(root);
    anchor = {
      element: cb,
      root,
      index: all.indexOf(cb),
      count: all.length,
    };
  }

  /**
   * target と組み合わせて範囲選択できる起点の位置（インデックス）を返す。
   * 使えない場合は -1。
   */
  function resolveAnchorIndex(target, all) {
    if (!anchor) return -1;
    if (anchor.root !== ownerRoot(target)) return -1;

    // 通常はクリックした要素そのものが生きている
    if (anchor.element.isConnected) {
      const idx = all.indexOf(anchor.element);
      return anchor.element === target ? -1 : idx;
    }

    // 要素が差し替えられていた場合は、位置ベースで復元を試みる
    if (all.length !== anchor.count || anchor.index < 0 || anchor.index >= all.length) return -1;
    return all[anchor.index] === target ? -1 : anchor.index;
  }

  // ---- 範囲の適用 -----------------------------------------------------------

  /**
   * root 内のチェックボックス列で fromIndex と toIndex の間（両端を除く）を
   * desired の状態にする。戻り値は切り替えた個数。
   *
   * 途中でページが再描画して要素が差し替わっても続行できるよう、
   * 要素が DOM から外れていたら同じ位置の要素を取り直す。
   */
  function applyRange(root, fromIndex, toIndex, desired) {
    let all = collectCheckboxes(root);
    if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return 0;
    if (fromIndex >= all.length || toIndex >= all.length) return 0;

    const start = Math.min(fromIndex, toIndex);
    const end = Math.max(fromIndex, toIndex);

    // 両端が同じ form に属している場合は、その form 内だけを対象にする
    const form = all[fromIndex].form;
    const sameForm = form === all[toIndex].form;

    let changed = 0;
    for (let i = start + 1; i < end; i++) {
      let cb = all[i];
      if (!cb.isConnected) {
        // 再描画で差し替えられた → 同じ並びなら同じ位置の要素を使う
        const fresh = collectCheckboxes(root);
        if (fresh.length !== all.length) break;
        all = fresh;
        cb = all[i];
      }
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

  // ---- イベントハンドラ -------------------------------------------------------

  function onClick(event) {
    if (!enabled) return;
    // 自分が発火させた .click() や、ページ側スクリプトの合成クリックは無視
    if (!event.isTrusted) return;
    if (event.button !== 0) return;

    const target = realTarget(event);

    // --- <label> 経由のクリック ---------------------------------------------
    if (!isCheckbox(target)) {
      const cb = checkboxFromLabel(target);
      if (!cb || cb.disabled) return;

      if (!event.shiftKey) {
        // Shift なし: 起点として記録するだけ。
        // ブラウザが input へクリックを転送してくれる場合はそちらでも同じ記録が行われるが、
        // ページ側が label の click を preventDefault して自前で切り替えるサイトでは
        // 転送が起きないため、ここで確実に記録しておく。
        setAnchor(cb);
        return;
      }

      // Shift あり: ブラウザの既定動作（選択拡張／label の活性化）を止めて自前で切り替える。
      // ページ側の label クリックハンドラが独自にトグルすると二重に切り替わってしまうため、
      // 伝播も止めて「チェックボックス自体をクリックした」のと同じ扱いにする。
      event.preventDefault();
      event.stopPropagation();

      const root = ownerRoot(cb);
      const all = collectCheckboxes(root);
      const fromIndex = resolveAnchorIndex(cb, all);
      const toIndex = all.indexOf(cb);
      setAnchor(cb);

      cb.click(); // 合成クリック → 自身は isTrusted=false なので再入しない
      if (fromIndex !== -1) {
        // click() 後に再描画されていても位置で追えるよう、状態は取り直す
        const current = collectCheckboxes(root)[toIndex];
        const desired = current ? current.checked : cb.checked;
        applyRange(root, fromIndex, toIndex, desired);
      }
      return;
    }

    // --- チェックボックス自体のクリック ---------------------------------------
    const root = ownerRoot(target);
    const all = collectCheckboxes(root);
    const fromIndex = event.shiftKey ? resolveAnchorIndex(target, all) : -1;
    const toIndex = all.indexOf(target);
    setAnchor(target);

    if (fromIndex === -1) return;

    // ブラウザはクリック時点でチェック状態を切り替えている。
    // ただしページ側が preventDefault すると元に戻るため、
    // クリック処理が完了した次のタイミングで最終状態を読み取る。
    setTimeout(() => {
      // 再描画で target が差し替えられていても、同じ位置の要素から状態を読む
      const current = target.isConnected ? target : collectCheckboxes(root)[toIndex];
      if (!current) return;
      applyRange(root, fromIndex, toIndex, current.checked);
    }, 0);
  }

  /** Shift+mousedown による不要なテキスト選択の拡張を抑止する */
  function onMouseDown(event) {
    if (!enabled) return;
    if (!event.isTrusted || !event.shiftKey || event.button !== 0) return;
    const target = realTarget(event);
    if (isCheckbox(target) || checkboxFromLabel(target)) {
      event.preventDefault();
    }
  }

  document.addEventListener('mousedown', onMouseDown, true);
  document.addEventListener('click', onClick, true);
})();
