# resave.ps1 - FORMAT: open CUST.DCT and save it again (upgrades a version 1 dictionary)
$s = $PSScriptRoot
function K($t, $w = 1) { & "$s\aw.ps1" keys $t | Out-Null; Start-Sleep $w }
function O($c, $w = 1) { & "$s\aw.ps1" raw $c | Out-Null; Start-Sleep $w }
function Shot($n) { & "$s\aw.ps1" shot "$s\$n.png" | Out-Null }
& "$s\aw.ps1" start | Out-Null; Start-Sleep 3
O "{F2}" 6
K "2" 6
O "%o"; K "CUST~" 4; Shot "r-open"
O "%s"; K "CUST~" 4; Shot "r-save"; K " "
O "{ESC}" 4
Shot "r-menu"
& "$s\aw.ps1" stop | Out-Null
"done"
