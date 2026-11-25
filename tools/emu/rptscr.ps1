# rptscr.ps1 - a REPORT on the screen a page at a time (2026-11-11).
# Needs rpttest.ps1 first: it designs LIST and exports LISTR.SNP, whose
# RPT-HEAD now starts with DISPLAY ERASE UPON PRINTER.  The .SNP comes off
# the disk image, mkproc.js puts its pieces into progs\rptscr.drv, and the
# program runs with SET PRINTER TO SCREEN.  rs-run is page 1 waiting,
# rs-2 page 2, rs-end the end.
$s = $PSScriptRoot
$cp2 = "D:\cp2_1.2.0_win-x64_sc\cp2.exe"; $img = "D:\AppleWin1.32.0.0\COBOL32.po"
# node: from PATH, or else the copy under %LOCALAPPDATA%
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) {
  $node = @("$env:LOCALAPPDATA\claude-tools\node-v22.14.0-win-x64\node.exe",
    "$env:LOCALAPPDATA\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Local\claude-tools\node-v22.14.0-win-x64\node.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $node) { "node not found - put it on PATH"; exit 1 }
& "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
$w = Join-Path $s "rptscr-stage"
if (Test-Path $w) { Remove-Item -Recurse -Force $w }
New-Item -ItemType Directory -Force $w | Out-Null
Push-Location $w; & $cp2 extract $img LISTR.SNP | Out-Null; Pop-Location
$snp = Get-ChildItem $w -Filter "LISTR.SNP*" | Select-Object -First 1
$t = [IO.File]::ReadAllText($snp.FullName) -replace "`r", "`n"
[IO.File]::WriteAllText("$w\LISTR.SNP", $t)
& $node "$s\mkproc.js" "$s\progs\rptscr.drv" "$s\progs\rptscr.cob" "$w\LISTR.SNP" | Out-Null
& "$s\runfile.ps1" -File "$s\progs\rptscr.cob" -Name RPTS -Tag rs -CompileWait 55 -RunWait 8 -Steps " |rs-2"," |rs-end" | Out-Null
"done"
