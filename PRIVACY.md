# チェックひろ プライバシーポリシー / Privacy Policy

最終更新日: 2026年9月14日

## 日本語

「チェックひろ」（以下「本拡張機能」）は、Web ページ上のチェックボックスを Shift + クリックで範囲選択できるようにする Chrome 拡張機能です。

### 収集する情報

本拡張機能は、**個人情報・閲覧履歴・ページ内容を含む一切のユーザーデータを収集、送信、保存しません。**

- 外部サーバーとの通信は一切行いません
- 閲覧しているページの URL や内容を記録しません
- アクセス解析や広告のためのコードは含みません

### ブラウザ内に保存する設定

本拡張機能は、機能のオン／オフ設定（真偽値 1 つ）のみを Chrome の `chrome.storage.sync` に保存します。この設定は Chrome の同期機能によってユーザー自身の Google アカウントに紐づく Chrome 間で同期されることがありますが、開発者を含む第三者がこの値にアクセスすることはありません。拡張機能を削除すると、この設定も削除されます。

### 権限の利用目的

| 権限 | 目的 |
| --- | --- |
| すべてのサイトへのアクセス（ホスト権限） | 任意の Web ページ上のチェックボックスに対して Shift + クリックの範囲選択を提供するため、ページにスクリプトを挿入します。ページの内容を読み取って外部に送ることはありません。 |
| `storage` | 機能のオン／オフ設定を保存するため |

### お問い合わせ

本ポリシーに関するお問い合わせは、GitHub リポジトリの Issue からお願いします。
https://github.com/MasayaSENGA/Check-Hiro/issues

---

## English

"Check-Hiro" (the "Extension") is a Chrome extension that lets you select a range of checkboxes on a web page with Shift + click.

### Data collection

**The Extension does not collect, transmit, or store any user data**, including personal information, browsing history, or page content.

- It never communicates with any external server.
- It does not record the URL or content of pages you visit.
- It contains no analytics or advertising code.

### Settings stored in your browser

The Extension stores a single boolean value (whether the feature is enabled) in `chrome.storage.sync`. Chrome may sync this value across your own signed-in Chrome browsers. No third party, including the developer, can access it. Uninstalling the Extension removes this setting.

### Permissions

| Permission | Purpose |
| --- | --- |
| Access to all sites (host permission) | To inject the content script that provides Shift + click range selection on any web page. Page content is never read for any other purpose or sent anywhere. |
| `storage` | To persist the on/off setting. |

### Contact

Please open an issue on GitHub: https://github.com/MasayaSENGA/Check-Hiro/issues
