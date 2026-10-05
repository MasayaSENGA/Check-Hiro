# チェックひろ - Chrome ウェブストア掲載用の画像を作成する
#
# 使い方:
#   powershell -ExecutionPolicy Bypass -File .\scripts\make-store-images.ps1
#
# 出力: store\screenshot-1.png（範囲選択）, store\screenshot-2.png（オン／オフとプライバシー）,
#       store\promo-small.png（小プロモーションタイル）, store\promo-marquee.png（マーキー プロモーション タイル）

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root 'store'
New-Item -ItemType Directory -Force $outDir | Out-Null

$blue   = [System.Drawing.Color]::FromArgb(255, 37, 99, 235)
$blueDk = [System.Drawing.Color]::FromArgb(255, 29, 78, 216)
$text   = [System.Drawing.Color]::FromArgb(255, 17, 24, 39)
$muted  = [System.Drawing.Color]::FromArgb(255, 107, 114, 128)
$border = [System.Drawing.Color]::FromArgb(255, 209, 213, 219)
$bg     = [System.Drawing.Color]::FromArgb(255, 243, 244, 246)
$white  = [System.Drawing.Color]::White
$fontName = 'Yu Gothic UI'

function New-RoundedPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

function Draw-Check($g, [single]$x, [single]$y, [single]$size, [bool]$checked) {
  $path = New-RoundedPath $x $y $size $size ($size * 0.2)
  if ($checked) {
    $g.FillPath((New-Object System.Drawing.SolidBrush $blue), $path)
    $pen = New-Object System.Drawing.Pen $white, ([single]($size * 0.13))
    $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
    $pts = [System.Drawing.PointF[]]@(
      (New-Object System.Drawing.PointF ($x + $size*0.25), ($y + $size*0.52)),
      (New-Object System.Drawing.PointF ($x + $size*0.43), ($y + $size*0.70)),
      (New-Object System.Drawing.PointF ($x + $size*0.76), ($y + $size*0.32)))
    $g.DrawLines($pen, $pts)
  } else {
    $g.FillPath((New-Object System.Drawing.SolidBrush $white), $path)
    $g.DrawPath((New-Object System.Drawing.Pen $border, 2), $path)
  }
}

function Draw-Text($g, [string]$s, [single]$x, [single]$y, [single]$px, $color, [string]$style = 'Regular') {
  $font = New-Object System.Drawing.Font $fontName, $px, ([System.Drawing.FontStyle]::$style), ([System.Drawing.GraphicsUnit]::Pixel)
  $g.DrawString($s, $font, (New-Object System.Drawing.SolidBrush $color), $x, $y)
}

# 文字列を横に並べるとき用（余白なしで描画し、描いた幅を返す）
$typo = [System.Drawing.StringFormat]::GenericTypographic.Clone()
$typo.FormatFlags = $typo.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces
function Draw-TextRun($g, [string]$s, [single]$x, [single]$y, [single]$px, $color, [string]$style = 'Regular') {
  $font = New-Object System.Drawing.Font $fontName, $px, ([System.Drawing.FontStyle]::$style), ([System.Drawing.GraphicsUnit]::Pixel)
  $g.DrawString($s, $font, (New-Object System.Drawing.SolidBrush $color), $x, $y, $typo)
  return [single]$g.MeasureString($s, $font, 10000, $typo).Width
}

$icon = [System.Drawing.Image]::FromFile((Join-Path $root 'icons\icon128.png'))

function New-Canvas([int]$w, [int]$h, $fill) {
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.TextRenderingHint = 'AntiAliasGridFit'
  $g.Clear($fill)
  return @($bmp, $g)
}

# ---------------------------------------------------------------- screenshot 1280x800
$c = New-Canvas 1280 800 $bg; $bmp = $c[0]; $g = $c[1]

# 左: ブラウザ風カード
$cardX = 72; $cardY = 96; $cardW = 640; $cardH = 620
$shadow = New-RoundedPath ($cardX + 4) ($cardY + 8) $cardW $cardH 16
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 0, 0, 0))), $shadow)
$card = New-RoundedPath $cardX $cardY $cardW $cardH 16
$g.FillPath((New-Object System.Drawing.SolidBrush $white), $card)
$g.DrawPath((New-Object System.Drawing.Pen $border, 1), $card)

# タイトルバー
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 249, 250, 251))), $cardX + 1, $cardY + 16, $cardW - 2, 56)
$g.DrawLine((New-Object System.Drawing.Pen $border, 1), $cardX, $cardY + 72, $cardX + $cardW, $cardY + 72)
Draw-Text $g '注文一覧' ($cardX + 28) ($cardY + 30) 22 $text 'Bold'
Draw-Text $g '12 件中 6 件を選択' ($cardX + 470) ($cardY + 34) 16 $muted

$rows = @('A-1001  ○○商店　ステッカーセット', 'A-1002  △△書店　アクリルスタンド', 'A-1003  □□ストア　缶バッジ 6種',
          'A-1004  ◇◇通販　クリアファイル', 'A-1005  ☆☆百貨店　Tシャツ', 'A-1006  ◎◎ショップ　マグカップ',
          'A-1007  ▽▽商事　タペストリー', 'A-1008  ▲▲文具　ボールペン', 'A-1009  ●●雑貨　キーホルダー', 'A-1010  ◆◆企画　ポスター')
$rowH = 50; $rowY0 = $cardY + 96
for ($i = 0; $i -lt $rows.Count; $i++) {
  $y = $rowY0 + $i * $rowH
  $checked = ($i -ge 1 -and $i -le 6)
  if ($checked) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 239, 246, 255))), $cardX + 1, $y - 6, $cardW - 2, $rowH)
  }
  Draw-Check $g ($cardX + 32) ($y + 6) 24 $checked
  Draw-Text $g $rows[$i] ($cardX + 76) ($y + 8) 18 $text
  if ($i -lt $rows.Count - 1) {
    $g.DrawLine((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 243, 244, 246)), 1), $cardX + 20, $y + $rowH - 6, $cardX + $cardW - 20, $y + $rowH - 6)
  }
}

# 吹き出し（① クリック / ② Shift + クリック）
function Draw-Badge($g, [string]$s, [single]$x, [single]$y, [single]$w) {
  $p = New-RoundedPath $x $y $w 40 20
  $g.FillPath((New-Object System.Drawing.SolidBrush $blueDk), $p)
  Draw-Text $g $s ($x + 18) ($y + 9) 17 $white 'Bold'
}
# 行の右側（カード内）にバッジを置く
$y1 = $rowY0 + 1 * $rowH + 18 - 20
$y2 = $rowY0 + 6 * $rowH + 18 - 20
Draw-Badge $g '① 先頭をクリック' ($cardX + $cardW - 216) $y1 188
Draw-Badge $g '② Shift ＋ クリック' ($cardX + $cardW - 236) $y2 208

# 右: コピー
$rx = 770
Draw-Text $g 'チェックひろ' $rx 100 54 $text 'Bold'
Draw-Text $g 'Shift + クリックで' $rx 178 34 $blue 'Bold'
Draw-Text $g 'チェックボックスを範囲選択' $rx 222 34 $blue 'Bold'

Draw-Text $g '間のチェックボックスがまとめて ON / OFF に。' $rx 290 20 $muted
Draw-Text $g 'どの Web サイトでも使えます。' $rx 322 20 $muted

$fy = 560
$features = @('label クリック型のチェックボックスにも対応', 'React / Vue 製のページでも安全に動作', 'ツールバーからワンクリックでオン／オフ')
for ($i = 0; $i -lt $features.Count; $i++) {
  $yy = $fy + $i * 44
  Draw-Check $g $rx ($yy + 2) 22 $true
  Draw-Text $g $features[$i] ($rx + 36) $yy 19 $text
}

$g.Dispose()
$bmp.Save((Join-Path $outDir 'screenshot-1.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# ---------------------------------------------------------------- screenshot 2 1280x800
$c = New-Canvas 1280 800 $bg; $bmp = $c[0]; $g = $c[1]
$g.InterpolationMode = 'HighQualityBicubic'

# 左: ブラウザ風カード（ツールバーからポップアップを開いた状態）
$shadow = New-RoundedPath ($cardX + 4) ($cardY + 8) $cardW $cardH 16
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 0, 0, 0))), $shadow)
$card = New-RoundedPath $cardX $cardY $cardW $cardH 16
$g.FillPath((New-Object System.Drawing.SolidBrush $white), $card)
$g.DrawPath((New-Object System.Drawing.Pen $border, 1), $card)

# ツールバー（アドレスバー + 拡張機能アイコン）
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 249, 250, 251))), $cardX + 1, $cardY + 16, $cardW - 2, 56)
$g.DrawLine((New-Object System.Drawing.Pen $border, 1), $cardX, $cardY + 72, $cardX + $cardW, $cardY + 72)
$addr = New-RoundedPath ($cardX + 24) ($cardY + 26) 520 36 18
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 237, 239, 242))), $addr)
Draw-Text $g 'example.com/orders' ($cardX + 44) ($cardY + 34) 16 $muted
$iconX = $cardX + 578; $iconY = $cardY + 28
$g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 226, 232, 240))), $iconX - 8, $iconY - 8, 48, 48)
$g.DrawImage($icon, $iconX, $iconY, 32, 32)

# 背景のページ（ポップアップの下に見える一覧）
$fade = [System.Drawing.Color]::FromArgb(255, 156, 163, 175)
for ($i = 0; $i -lt 10; $i++) {
  $y = $rowY0 + $i * $rowH
  Draw-Check $g ($cardX + 32) ($y + 6) 24 $false
  Draw-Text $g $rows[$i] ($cardX + 76) ($y + 8) 18 $fade
}
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(110, 255, 255, 255))), $cardX + 1, $cardY + 73, $cardW - 2, $cardH - 90)

# ポップアップ（popup.html を 1.6 倍で再現）
$s = 1.6
$popW = 280 * $s; $popX = $cardX + $cardW - 24 - $popW; $popY = $cardY + 84
$popH = 352
$pshadow = New-RoundedPath ($popX + 2) ($popY + 6) $popW $popH 12
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(50, 0, 0, 0))), $pshadow)
$pop = New-RoundedPath $popX $popY $popW $popH 12
$g.FillPath((New-Object System.Drawing.SolidBrush $white), $pop)
$g.DrawPath((New-Object System.Drawing.Pen $border, 1), $pop)

$px = $popX + 16 * $s
$g.DrawImage($icon, $px, ($popY + 14 * $s), (24 * $s), (24 * $s))
Draw-Text $g 'チェックひろ' ($px + 32 * $s) ($popY + 15 * $s) (15 * $s) $text 'Bold'

$tgX = $px; $tgY = $popY + 50 * $s; $tgW = $popW - 32 * $s; $tgH = 74 * $s
$tg = New-RoundedPath $tgX $tgY $tgW $tgH (8 * $s)
$g.DrawPath((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 229, 231, 235)), 1.5), $tg)
Draw-Text $g '機能を有効にする' ($tgX + 10 * $s) ($tgY + 9 * $s) (13 * $s) $text 'Bold'
Draw-Text $g 'オン：Shift+クリックで' ($tgX + 10 * $s) ($tgY + 31 * $s) (12 * $s) $muted
Draw-Text $g '範囲選択できます' ($tgX + 10 * $s) ($tgY + 48 * $s) (12 * $s) $muted
$swW = 40 * $s; $swH = 22 * $s
$swX = $tgX + $tgW - 12 * $s - $swW; $swY = $tgY + ($tgH - $swH) / 2
$g.FillPath((New-Object System.Drawing.SolidBrush $blue), (New-RoundedPath $swX $swY $swW $swH ($swH / 2)))
$knob = 18 * $s
$g.FillEllipse((New-Object System.Drawing.SolidBrush $white), ($swX + $swW - 2 * $s - $knob), ($swY + 2 * $s), $knob, $knob)

# ヒント文（Shift はキーボード風の枠で囲む）
$hx = $px; $hy = $popY + 138 * $s; $hpx = 13 * $s; $lh = 21 * $s
$w = Draw-TextRun $g '先頭をクリック → ' $hx $hy $hpx $muted
$kw = Draw-TextRun $g 'Shift' ($hx + $w + 6) ($hy + 1) (12 * $s) $muted
$kbd = New-RoundedPath ($hx + $w) ($hy - 2) ($kw + 12) ($hpx + 6) 5
$g.DrawPath((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 209, 213, 219)), 1.5), $kbd)
[void](Draw-TextRun $g ' を押しながら' ($hx + $w + $kw + 12) $hy $hpx $muted)
[void](Draw-TextRun $g '末尾をクリックで、間のチェック' $hx ($hy + $lh) $hpx $muted)
[void](Draw-TextRun $g 'ボックスをまとめて切り替えます。' $hx ($hy + $lh * 2) $hpx $muted)

# 右: コピー
Draw-Text $g 'チェックひろ' $rx 100 54 $text 'Bold'
Draw-Text $g 'ツールバーから' $rx 178 34 $blue 'Bold'
Draw-Text $g 'ワンクリックでオン／オフ' $rx 222 34 $blue 'Bold'

Draw-Text $g '切り替えは開いているページにも即時反映。' $rx 290 20 $muted
Draw-Text $g 'ページの再読み込みは不要です。' $rx 322 20 $muted

# オフ時のバッジ表示の例
$by = 392
$g.DrawImage($icon, $rx, $by, 40, 40)
$badge = New-RoundedPath ($rx + 16) ($by + 24) 34 18 5
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 107, 114, 128))), $badge)
Draw-Text $g 'OFF' ($rx + 20) ($by + 25) 12 $white 'Bold'
Draw-Text $g 'オフのときはアイコンに「OFF」を表示' ($rx + 64) ($by + 8) 19 $text

$privacy = @('ユーザーデータの収集・送信は一切なし', '外部サーバーとの通信なし', '保存するのはオン／オフの設定だけ')
for ($i = 0; $i -lt $privacy.Count; $i++) {
  $yy = $fy + $i * 44
  Draw-Check $g $rx ($yy + 2) 22 $true
  Draw-Text $g $privacy[$i] ($rx + 36) $yy 19 $text
}

$g.Dispose()
$bmp.Save((Join-Path $outDir 'screenshot-2.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# ---------------------------------------------------------------- promo tile 440x280
$c = New-Canvas 440 280 $blue; $bmp = $c[0]; $g = $c[1]
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point 440, 280), $blue, $blueDk
$g.FillRectangle($grad, 0, 0, 440, 280)

# 左に大きなチェックボックス列
for ($i = 0; $i -lt 4; $i++) {
  $y = 52 + $i * 50
  $chk = ($i -ge 0 -and $i -le 2)
  $p = New-RoundedPath 40 $y 34 34 7
  if ($chk) {
    $g.FillPath((New-Object System.Drawing.SolidBrush $white), $p)
    $pen = New-Object System.Drawing.Pen $blue, 4.5
    $pen.StartCap = 'Round'; $pen.EndCap = 'Round'; $pen.LineJoin = 'Round'
    $pts = [System.Drawing.PointF[]]@(
      (New-Object System.Drawing.PointF (40 + 34*0.25), ($y + 34*0.52)),
      (New-Object System.Drawing.PointF (40 + 34*0.43), ($y + 34*0.70)),
      (New-Object System.Drawing.PointF (40 + 34*0.76), ($y + 34*0.32)))
    $g.DrawLines($pen, $pts)
  } else {
    $g.DrawPath((New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(160, 255, 255, 255)), 2.5), $p)
  }
  # 右側の文字（x = 222〜）に重ならない長さにする
  $barW = 70 + (($i * 37) % 50)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(110, 255, 255, 255))), 90, $y + 11, $barW, 12)
}

Draw-Text $g 'チェックひろ' 222 74 38 $white 'Bold'
Draw-Text $g 'Shift + クリックで' 226 132 19 $white
Draw-Text $g 'チェックボックスを' 226 160 19 $white
Draw-Text $g '範囲選択' 226 188 19 $white

$g.Dispose()
$bmp.Save((Join-Path $outDir 'promo-small.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# ---------------------------------------------------------------- marquee promo tile 1400x560
$c = New-Canvas 1400 560 $blue; $bmp = $c[0]; $g = $c[1]
$g.InterpolationMode = 'HighQualityBicubic'
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point 1400, 560), $blue, $blueDk
$g.FillRectangle($grad, 0, 0, 1400, 560)

# 左: アイコン・名前・キャッチコピー（アイコンは青地なので白い枠を付ける）
$g.FillPath((New-Object System.Drawing.SolidBrush $white), (New-RoundedPath 112 118 96 96 22))
$g.DrawImage($icon, 120, 126, 80, 80)
Draw-Text $g 'チェックひろ' 228 116 72 $white 'Bold'
Draw-Text $g 'Shift + クリックで' 114 262 42 $white 'Bold'
Draw-Text $g 'チェックボックスを範囲選択' 114 318 42 $white 'Bold'
Draw-Text $g 'どの Web サイトでも、間のチェックボックスをまとめて ON / OFF' 118 400 22 ([System.Drawing.Color]::FromArgb(225, 255, 255, 255))

# 右: チェックボックスの一覧（行の文字はバーで表す）
$mx = 800; $my = 82; $mw = 500; $mh = 396
$g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(60, 0, 0, 0))), (New-RoundedPath ($mx + 6) ($my + 12) $mw $mh 20))
$mcard = New-RoundedPath $mx $my $mw $mh 20
$g.FillPath((New-Object System.Drawing.SolidBrush $white), $mcard)

$mRowH = 56; $mRowY0 = $my + 40
for ($i = 0; $i -lt 6; $i++) {
  $y = $mRowY0 + $i * $mRowH
  $checked = ($i -ge 1 -and $i -le 4)
  if ($checked) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 239, 246, 255))), $mx, $y - 10, $mw, $mRowH)
  }
  Draw-Check $g ($mx + 36) ($y + 4) 28 $checked
  $barColor = if ($checked) { [System.Drawing.Color]::FromArgb(255, 191, 219, 254) } else { [System.Drawing.Color]::FromArgb(255, 229, 231, 235) }
  $barW = 150 + (($i * 53) % 90)
  $g.FillPath((New-Object System.Drawing.SolidBrush $barColor), (New-RoundedPath ($mx + 84) ($y + 11) $barW 14 7))
}

# 行の右側に操作のバッジ（① 先頭 / ② 末尾）
function Draw-MarqueeBadge($g, [string]$s, [single]$right, [single]$y) {
  $font = New-Object System.Drawing.Font $fontName, 19, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
  $tw = [single]$g.MeasureString($s, $font, 10000, $typo).Width
  $bw = $tw + 40
  $g.FillPath((New-Object System.Drawing.SolidBrush $blueDk), (New-RoundedPath ($right - $bw) $y $bw 42 21))
  $g.DrawString($s, $font, (New-Object System.Drawing.SolidBrush $white), ($right - $bw + 20), ($y + 9), $typo)
}
Draw-MarqueeBadge $g '① クリック' ($mx + $mw - 28) ($mRowY0 + 1 * $mRowH - 3)
Draw-MarqueeBadge $g '② Shift ＋ クリック' ($mx + $mw - 28) ($mRowY0 + 4 * $mRowH - 3)

$g.Dispose()
# ストアのプロモーション タイルは 24 ビット PNG（アルファなし）か JPEG のため、RGB に変換して保存する
$rgb = $bmp.Clone((New-Object System.Drawing.Rectangle 0, 0, $bmp.Width, $bmp.Height), [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$rgb.Save((Join-Path $outDir 'promo-marquee.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$rgb.Dispose()
$bmp.Dispose()
$icon.Dispose()

Get-ChildItem $outDir -Filter *.png | Select-Object Name, Length
