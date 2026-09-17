$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$outDir = 'C:\path\to\チェックひろ\store'
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
  $barW = 110 + (($i * 37) % 60)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(110, 255, 255, 255))), 90, $y + 11, $barW, 12)
}

Draw-Text $g 'チェックひろ' 222 74 38 $white 'Bold'
Draw-Text $g 'Shift + クリックで' 226 132 19 $white
Draw-Text $g 'チェックボックスを' 226 160 19 $white
Draw-Text $g '範囲選択' 226 188 19 $white

$g.Dispose()
$bmp.Save((Join-Path $outDir 'promo-small.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Get-ChildItem $outDir -Filter *.png | Select-Object Name, Length
