# steptest.ps1 - type a program, ESC, compile: screenshots during the compile
param([string]$File = "beta1.cob")
$s = $PSScriptRoot
function K($t, $w = 1) { & "$s\aw.ps1" keys $t | Out-Null; Start-Sleep $w }
function O($c, $w = 1) { & "$s\aw.ps1" raw $c | Out-Null; Start-Sleep $w }
function Shot($n) { & "$s\aw.ps1" shot "$s\$n.png" | Out-Null }
$lines = Get-Content "$s\progs\$File" | ForEach-Object { $_.TrimEnd() }
& "$s\aw.ps1" start | Out-Null; Start-Sleep 3
O "{F2}" 6
K "1" 4
K ($lines -join "~") 10
O "{ESC}" 3
K "5" 2
Shot "s-c1"
Start-Sleep 6
Shot "s-c2"
Start-Sleep 20
Shot "s-c3"
& "$s\aw.ps1" stop | Out-Null
"done"
