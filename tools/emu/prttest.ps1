# prttest.ps1 - printer slot 1 (Utilities 6), then runprog-style compile and
# run of a program that prints.  AppleWin's printer goes to print-test.txt.
param([string]$File = "$PSScriptRoot\progs\prt.cob", [string]$Tag = "prt", [int]$RunWait = 8)
$s = $PSScriptRoot
function A($c, $x = "") { & "$s\aw.ps1" $c $x | Out-Null }
Remove-Item "$s\print-test.txt" -ErrorAction SilentlyContinue
$lines = Get-Content $File | ForEach-Object { $_.TrimEnd() }
A start; Start-Sleep 3; A raw "{F2}"; Start-Sleep 6
A keys "8"; Start-Sleep 2; A keys "6"; Start-Sleep 1; A keys "1~"; Start-Sleep 2; A raw "{ESC}"; Start-Sleep 2
A keys "1"; Start-Sleep 4
A keys ($lines -join "~"); Start-Sleep ([Math]::Max(6, [int]($lines.Count / 2)))
A raw "{ESC}"; Start-Sleep 4
A keys "5"; Start-Sleep 40; A shot "$s\$Tag-compile.png"
A keys " "; Start-Sleep 2
A keys "6"; Start-Sleep 3; A keys "UNTITLED~"; Start-Sleep $RunWait
A shot "$s\$Tag-run.png"
A keys " "; Start-Sleep 12
A stop
"done"
