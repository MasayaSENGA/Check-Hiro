# チェックひろ

Web ページ上のチェックボックスを **Shift + クリック** で範囲選択できる Chrome 拡張機能です。

1. 先頭のチェックボックスを普通にクリック
2. Shift キーを押しながら末尾のチェックボックスをクリック
3. 間にあるチェックボックスがすべて同じ状態（ON または OFF）になる

## インストール（Chrome ウェブストア）

Chrome ウェブストアで公開しています。掲載ページで「Chrome に追加」を押すとインストールできます。

https://chromewebstore.google.com/detail/fddljingadaoookjbhjngcofbaibodof

## インストール（開発者モード）

このリポジトリは非公開です。開発中のコードを試すときは、手元のフォルダを開発者モードで読み込みます。

1. Chrome で `chrome://extensions` を開く
2. 右上の「デベロッパーモード」を ON にする
3. 「パッケージ化されていない拡張機能を読み込む」をクリック
4. このリポジトリのフォルダ（`Check-Hiro`）を選択する

コードを変更したときは、拡張機能一覧の「更新」ボタン（🔄）を押してから、対象ページを再読み込みしてください。

`test.html` をローカルファイル（`file://`）として開いて動作確認するときは、拡張機能の「詳細」で「ファイルの URL へのアクセスを許可する」を ON にしてください（既定では OFF で、content script が注入されません）。

## オン／オフの切り替え

ツールバーの「チェックひろ」アイコンをクリックするとポップアップが開き、トグルで機能のオン／オフを切り替えられます。

- 設定は `chrome.storage.sync` に保存され、同じ Google アカウントの Chrome 間で同期されます
- 切り替えは開いているページにも即時反映されます（再読み込み不要）
- オフのときはアイコンに「OFF」バッジが表示されます

## 動作の仕組み

- すべてのページ（`<all_urls>`）に `content.js` を注入します
- `click` イベントを捕捉し、直前にクリックしたチェックボックスとの間にある `<input type="checkbox">` を DOM 順にまとめて切り替えます
- 切り替えは `.click()` で行うため、React / Vue などフレームワークが管理しているチェックボックスでも正しく状態が反映されます
- 起点（直前にクリックしたチェックボックス）は Shift の有無に関係なく記録します。label のクリックをページ側が `preventDefault` して自前で切り替えるサイトでも、label クリックの時点で起点を記録するため範囲選択できます
- 起点は要素だけでなく「何番目のチェックボックスか」も記録するため、React / Vue などの再描画で input 要素が差し替えられても、総数が同じなら位置ベースで復元します
- 両端が同じ `<form>` に属する場合は、その form 内のチェックボックスだけを対象にします
- `disabled` のチェックボックスは対象外です
- `<label>` を Shift + クリックした場合も対応しています
  - Chrome は Shift + クリックを「テキスト選択の拡張」と解釈するため、通常は label をクリックしてもチェックボックスが切り替わりません
  - 本拡張はこの既定動作を止め、拡張機能側でチェックボックスを切り替えます（不要なテキスト選択も発生しません）

## 制限事項

- Shadow DOM の内側にあるチェックボックスは、同じ Shadow Root 内での範囲選択のみ対応しています
- `<input type="checkbox">` ではない独自実装（`role="checkbox"` の div など）は対象外です

## Chrome ウェブストアへの提出

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

`dist/check-hiro-v<version>.zip` が生成されます。申請フォームに入力する情報（説明文・カテゴリ・権限の説明・データ使用の申告・審査用のテスト手順・提出前チェックリストなど）は [store/listing.md](store/listing.md) にまとめています。

掲載用の画像（スクリーンショット・プロモーションタイル）は次のコマンドで作り直せます。

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\make-store-images.ps1
```

## プライバシーポリシー

https://privacy.love-live.jp/ で公開しています。全拡張機能で共通のポリシーで、このリポジトリとは別の、プライバシーポリシー用のリポジトリで管理しています。

## ファイル構成

```
Check-Hiro/
├── manifest.json   拡張機能の定義（Manifest V3）
├── content.js      範囲選択のロジック
├── popup.html      ツールバーから開くポップアップ（オン／オフ切り替え）
├── popup.css       ポップアップのスタイル
├── popup.js        ポップアップのロジック（設定の読み書き）
├── background.js   Service Worker（オフ時の「OFF」バッジ表示）
├── icons/          アイコン画像
├── test.html       動作確認用のサンプルページ（配布物には含めない）
├── scripts/
│   ├── build.ps1              ストア提出用 zip の作成スクリプト
│   └── make-store-images.ps1  掲載用画像の作成スクリプト
├── store/
│   ├── listing.md        ストア申請フォームの入力内容まとめ
│   ├── screenshot-1.png  スクリーンショット 1：範囲選択（1280×800）
│   ├── screenshot-2.png  スクリーンショット 2：オン／オフとプライバシー（1280×800）
│   ├── promo-small.png   小プロモーションタイル（440×280）
│   └── promo-marquee.png マーキー プロモーションタイル（1400×560）
└── README.md
```
