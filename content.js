/**
 * チェックひろ - content script
 *
 * 1. Shift キーを押しながらチェックボックスをクリックすると、
 *    直前にクリックしたチェックボックスとの間にあるチェックボックスを
 *    まとめて同じ状態（ON / OFF）にする。
 * 2. コンテキストメニューから「ページ上のチェックボックスを全てチェック」
 *    「ページ上のチェックボックスを全て解除」を実行できる。
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
 *  - React などの制御コンポーネント（Trello のチェックリストなど）は、.click() の直後に
 *    いったん元の値へ戻され、新しい状態はマイクロタスク以降の再描画で反映される。
 *    そのため、クリックした項目の状態は同期的に読まず、反映を待ってから範囲に適用する
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

  // ---- クリック結果の確定待ち -------------------------------------------------

  /** 状態の反映を待つ上限。これを過ぎたら、その時点の状態を確定値として扱う */
  const SETTLE_TIMEOUT_MS = 200;
  const SETTLE_POLL_MS = 16;

  /**
   * クリックしたチェックボックスの状態が確定してから callback(checked) を呼ぶ。
   *
   * React などの制御コンポーネントでは、クリック直後の checked は元の値に戻されており、
   * 新しい状態は再描画（マイクロタスク以降）で反映される。そこで次のタスクで状態を読み、
   * まだ before のままなら少し待って読み直す。上限まで変わらなければ、ページ側が
   * 切り替えを拒否したものとみなし、その時点の状態で callback を呼ぶ。
   *
   * 再描画で要素が差し替えられていても、同じ位置（index）の要素から状態を読む。
   */
  function whenSettled(root, index, element, before, callback) {
    const startedAt = Date.now();

    const check = () => {
      const current = element.isConnected ? element : collectCheckboxes(root)[index];
      if (!current) return;
      if (current.checked !== before || Date.now() - startedAt >= SETTLE_TIMEOUT_MS) {
        callback(current.checked);
        return;
      }
      setTimeout(check, SETTLE_POLL_MS);
    };

    setTimeout(check, 0);
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

      const before = cb.checked;
      cb.click(); // 合成クリック → 自身は isTrusted=false なので再入しない
      if (fromIndex !== -1) {
        // 制御コンポーネントでは click() 直後の checked が元の値に戻っているため、
        // 反映を待ってから最終状態を読み取る
        whenSettled(root, toIndex, cb, before, (checked) => {
          applyRange(root, fromIndex, toIndex, checked);
        });
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

    // ブラウザはクリック時点（このハンドラが呼ばれる前）でチェック状態を切り替えている。
    // ただしページ側が preventDefault したり、制御コンポーネントが値を戻したりするため、
    // クリック処理と再描画が終わってから最終状態を読み取る。
    const before = !target.checked;
    whenSettled(root, toIndex, target, before, (checked) => {
      applyRange(root, fromIndex, toIndex, checked);
    });
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

  // ---- 一括チェック／一括解除 -----------------------------------------------

  /**
   * 指定したルート配下のチェックボックスを再帰的に収集する。
   * Shadow DOM (open) や同一オリジンの iframe / frame の内部も探索対象に含む。
   */
  function collectAllCheckboxes(root) {
    const checkboxes = [];

    function scan(node) {
      if (!node) return;

      if (typeof node.querySelectorAll === 'function') {
        const inputs = node.querySelectorAll(CHECKBOX_SELECTOR);
        for (let i = 0; i < inputs.length; i++) {
          checkboxes.push(inputs[i]);
        }

        // 同一オリジンの iframe / frame 内のドキュメントも探索
        const frames = node.querySelectorAll('iframe, frame');
        for (let i = 0; i < frames.length; i++) {
          try {
            if (frames[i].contentDocument) {
              scan(frames[i].contentDocument);
            }
          } catch (_) {
            // クロスオリジン等でアクセス制限がある場合はスキップ
          }
        }

        // Shadow DOM (open) を持つ要素の内部も探索
        const allElements = node.querySelectorAll('*');
        for (let i = 0; i < allElements.length; i++) {
          if (allElements[i].shadowRoot) {
            scan(allElements[i].shadowRoot);
          }
        }
      }
    }

    scan(root);
    return checkboxes;
  }

  /**
   * ページ上のすべてのチェックボックスを desired（true: 全てチェック, false: 全て解除）にする。
   *
   * 実装方針:
   *  - disabled のチェックボックスはスキップする
   *  - 既に desired の状態になっているものは何もしない
   *  - .click() で切り替えることでページ側／フレームワーク（React / Vue 等）のイベントを発火させる
   *  - 途中で再描画が発生して要素が差し替えられても、最新の DOM から追従して残りを処理する
   *  - preventDefault 等で状態が変わらない要素があっても無限ループしないよう除外管理する
   *  - 処理後、Shift クリックの起点はリセットする
   */
  function setAllCheckboxes(desired) {
    anchor = null;

    const unchangeable = new Set();
    const MAX_PASSES = 200;

    for (let pass = 0; pass < MAX_PASSES; pass++) {
      const all = collectAllCheckboxes(document);
      const targets = all.filter(
        (cb) => !cb.disabled && cb.checked !== desired && !unchangeable.has(cb)
      );
      if (targets.length === 0) break;

      let changedAnyInPass = false;
      for (let i = 0; i < targets.length; i++) {
        const cb = targets[i];
        if (!cb.isConnected) {
          // 再描画等で要素が DOM から外れた場合は、最新の DOM を取り直すためにパスを抜ける
          break;
        }
        if (cb.disabled || cb.checked === desired || unchangeable.has(cb)) {
          continue;
        }

        cb.click();

        if (cb.isConnected && cb.checked !== desired) {
          unchangeable.add(cb);
        } else {
          changedAnyInPass = true;
        }
      }

      // このパスで1つも状態を変更できなかった場合は終了（無限ループ防止）
      if (!changedAnyInPass) {
        break;
      }
    }
  }

  // ---- バックグラウンド（コンテキストメニュー）からのメッセージ受信 ---------
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (!message || typeof message.action !== 'string') return;

    if (message.action === 'checkAll') {
      setAllCheckboxes(true);
      sendResponse({ success: true });
    } else if (message.action === 'uncheckAll') {
      setAllCheckboxes(false);
      sendResponse({ success: true });
    }
  });

  document.addEventListener('mousedown', onMouseDown, true);
  document.addEventListener('click', onClick, true);
})();
