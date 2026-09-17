# チェックひろ - Chrome ウェブストア提出用 zip を作成する
#
# 使い方:
#   powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
#
# 出力: dist\check-hiro-v<version>.zip
#   manifest.json の version を読み取ってファイル名に使う。
#   開発用のファイル（test.html, README.md, PRIVACY.md, store/ など）は含めない。

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $root 'manifest.json'
$manifest = Get-Content -Raw -Encoding UTF8 $manifestPath | ConvertFrom-Json
$version = $manifest.version

# 配布物に含めるファイル
$files = @(
  'manifest.json',
  'content.js',
  'background.js',
  'popup.html',
  'popup.css',
  'popup.js'
)
$dirs = @('icons')

$dist = Join-Path $root 'dist'
$stage = Join-Path $dist 'stage'
$zip = Join-Path $dist "check-hiro-v$version.zip"

if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null

foreach ($f in $files) {
  $src = Join-Path $root $f
  if (-not (Test-Path $src)) { throw "必要なファイルがありません: $f" }
  Copy-Item $src $stage
}
foreach ($d in $dirs) {
  Copy-Item (Join-Path $root $d) (Join-Path $stage $d) -Recurse
}

if (Test-Path $zip) { Remove-Item $zip -Force }

# Compress-Archive や ZipFile.CreateFromDirectory は Windows PowerShell 5.1 上では
# zip 内のパス区切りに "\" を使ってしまい（icons\icon16.png）、Chrome ウェブストア側で
# アイコンが見つからない原因になる。そのためエントリ名を "/" 区切りで明示して 1 件ずつ追加する。
# また PS 5.1 ではスクリプト内で [IO.Compression.ZipFile] 型リテラルが解決できないことが
# あるため、アセンブリから型を直接取り出す。
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$fsAsm = [AppDomain]::CurrentDomain.GetAssemblies() |
  Where-Object { $_.GetName().Name -eq 'System.IO.Compression.FileSystem' } |
  Select-Object -First 1
if (-not $fsAsm) { throw 'System.IO.Compression.FileSystem を読み込めませんでした' }
$zipFile = $fsAsm.GetType('System.IO.Compression.ZipFile')
$zipExt = $fsAsm.GetType('System.IO.Compression.ZipFileExtensions')

$archive = $zipFile::Open($zip, 'Create')
try {
  Get-ChildItem $stage -Recurse -File | Sort-Object FullName | ForEach-Object {
    $entryName = $_.FullName.Substring($stage.Length + 1).Replace('\', '/')
    [void]$zipExt::CreateEntryFromFile($archive, $_.FullName, $entryName)
  }
} finally {
  $archive.Dispose()
}

Remove-Item $stage -Recurse -Force

Write-Host "作成しました: $zip" -ForegroundColor Green
Write-Host "--- 内容 ---"
$archive = $zipFile::OpenRead($zip)
try {
  $archive.Entries | ForEach-Object { Write-Host ("  {0,8:N0} bytes  {1}" -f $_.Length, $_.FullName) }
} finally {
  $archive.Dispose()
}
