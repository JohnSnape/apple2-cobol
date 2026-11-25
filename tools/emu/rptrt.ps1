# rptrt.ps1 - REPORT round trip: open LIST.RPT, save as LIST2; the two
# files must be identical.  Then the regression set.
$s = $PSScriptRoot
function A($c, $x = "") { & "$s\aw.ps1" $c $x | Out-Null }
$cp2 = "D:\cp2_1.2.0_win-x64_sc\cp2.exe"
A stop
A start; Start-Sleep 3; A raw "{F2}"; Start-Sleep 6
A keys "4"; Start-Sleep 5
A raw "%o"; Start-Sleep 1; A keys "LIST~"; Start-Sleep 4; A shot "$s\rp-open.png"
A raw "%s"; Start-Sleep 1; A keys "LIST2~"; Start-Sleep 4; A keys " "; Start-Sleep 1
A raw "{ESC}"; Start-Sleep 2
A stop
$t = Join-Path $env:TEMP "rptrt"; Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue; New-Item -ItemType Directory $t | Out-Null
Push-Location $t
& $cp2 extract --raw "D:\AppleWin1.32.0.0\COBOL32.po" LIST.RPT LIST2.RPT | Out-Null
Pop-Location
$a = [IO.File]::ReadAllBytes("$t\LIST.RPT"); $b = [IO.File]::ReadAllBytes("$t\LIST2.RPT")
if ($a.Length -eq $b.Length -and -not (Compare-Object $a $b -SyncWindow 0)) { "ROUND TRIP IDENTICAL, $($a.Length) bytes" } else { "ROUND TRIP DIFFERS: $($a.Length) vs $($b.Length)" }
& "$s\regress.ps1"
