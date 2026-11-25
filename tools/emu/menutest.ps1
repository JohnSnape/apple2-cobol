# menutest.ps1 - the main menu, the RUN prompt (option 6) and a message (5 with nothing edited)
$s = $PSScriptRoot
function K($t, $w = 1) { & "$s\aw.ps1" keys $t | Out-Null; Start-Sleep $w }
function O($c, $w = 1) { & "$s\aw.ps1" raw $c | Out-Null; Start-Sleep $w }
function Shot($n) { & "$s\aw.ps1" shot "$s\$n.png" | Out-Null }
& "$s\aw.ps1" start | Out-Null; Start-Sleep 3
O "{F2}" 6
Shot "m-menu"
K "6" 2
Shot "m-run"
O "{ESC}" 3
K "5" 12
Shot "m-msg"
& "$s\aw.ps1" stop | Out-Null
"done"
