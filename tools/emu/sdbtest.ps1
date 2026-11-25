# sdbtest.ps1 - 2026-11-22: SALESDB.cob, all seven menu items, end to end.
# Like runfile.ps1, but the printer is set to slot 1 first (Utilities 6),
# so option 5's P goes to print-test.txt.  Screenshots sdb-*.png; EAST.DAT
# and WEST.DAT are left on the image for a look and deleted by the next run.
param([int]$RunWait = 8)
$s = $PSScriptRoot
$cp2 = "D:\cp2_1.2.0_win-x64_sc\cp2.exe"; $img = "D:\AppleWin1.32.0.0\COBOL32.po"
function A($c, $x = "") { & "$s\aw.ps1" $c $x | Out-Null }
$had = (& $cp2 catalog $img | Select-String ' COBOL.SETTINGS$') -ne $null
Remove-Item "$s\print-test.txt" -ErrorAction SilentlyContinue
$w = Join-Path $s "runfile-stage"
if (Test-Path $w) { Remove-Item -Recurse -Force $w }
New-Item -ItemType Directory -Force $w | Out-Null
$text = (Get-Content "$s\progs\SALESDB.cob" | ForEach-Object { $_.TrimEnd() }) -join "`r"
[IO.File]::WriteAllText("$w\SALESDB.COB#040000", $text + "`r", [Text.Encoding]::ASCII)
Push-Location $w
foreach ($f in "SALESDB.OBJ", "EAST.DAT", "WEST.DAT") { & $cp2 delete $img $f 2>$null | Out-Null }
& $cp2 add --overwrite --from-naps $img "SALESDB.COB#040000" | Out-Null
Pop-Location
A start; Start-Sleep 3; A raw "{F2}"; Start-Sleep 6
# Utilities: printer in slot 1 (as edtest.ps1)
A keys "8"; Start-Sleep 2; A keys "6"; Start-Sleep 1; A keys "1~"; Start-Sleep 2
A raw "{ESC}"; Start-Sleep 2
A keys "1"; Start-Sleep 4
A raw "%o"; Start-Sleep 1; A keys "SALESDB.COB~"; Start-Sleep 6
A raw "{ESC}"; Start-Sleep 4
A keys "5"; Start-Sleep 60
A shot "$s\sdb-compile.png"
A keys " "; Start-Sleep 2
A keys "6"; Start-Sleep 3
A keys "SALESDB~"; Start-Sleep $RunWait
A shot "$s\sdb-menu.png"
$steps = @(
 "2|sdb-01-nodb",
 " 1EAST.DAT~|sdb-02-new",
 " 2ACME TOOLS~BOSTON~MA~1500.00~BAY PAPER~TAMPA~FL~250.75~CAPE FISH~HYANNIS~MA~4200.00~DOWNEAST INN~BANGOR~ME~99.95~|sdb-03-enter",
 "~|sdb-04-menu",
 "3|sdb-05-viewall",
 " 4MA~1000~|sdb-06-filter",
 " 5~0~S~|sdb-07-preview",
 " |sdb-08",
 " 72~~ORLANDO~~N~S~|sdb-09-edit",
 " 71~~~~N~D~|sdb-10-delete",
 " 3|sdb-11-east",
 " 6WEST.DAT~|sdb-12-copy",
 " 1WEST.DAT~U~|sdb-13-use",
 " 3|sdb-14-west",
 " 2SEQUOIA SUPPLY~FRESNO~CA~800.00~~3|sdb-15-westadd",
 " 1EAST.DAT~U~ 3|sdb-16-eastagain",
 " 5MA~0~P~|sdb-17-paper",
 " Q|sdb-18-quit"
)
foreach ($st in $steps) {
  $p = $st.Split('|')
  A keys $p[0]; Start-Sleep $RunWait
  A shot "$s\$($p[1]).png"
}
A stop; Start-Sleep 1
& $cp2 delete $img "SALESDB.COB" 2>$null | Out-Null
& $cp2 delete $img "SALESDB.OBJ" 2>$null | Out-Null
if (-not $had) { & $cp2 delete $img "COBOL.SETTINGS" 2>$null | Out-Null }
Remove-Item -Recurse -Force $w
"done: sdbtest"
