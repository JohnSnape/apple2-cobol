# viewtest.ps1 - menu option 7: VIEW CUST (needs qfile.cob's CUST.DAT), then
# the keys a view must refuse, then ESC and COMPILE (must find no program)
$s = $PSScriptRoot
function K($t, $w = 1) { & "$s\aw.ps1" keys $t | Out-Null; Start-Sleep $w }
function O($c, $w = 1) { & "$s\aw.ps1" raw $c | Out-Null; Start-Sleep $w }
function Shot($n) { & "$s\aw.ps1" shot "$s\$n.png" | Out-Null }
& "$s\aw.ps1" start | Out-Null; Start-Sleep 3
O "{F2}" 6
Shot "v-menu"
K "7" 6
Shot "v-prompt"
K "CUST~" 6
Shot "v-view"
K "XYZ~"; O "%s" 2; O "%n" 2
Shot "v-refuse"
O "{ESC}" 4
K "7" 6
K "NOSUCH~" 5
Shot "v-nofile"
K " " 4
Shot "v-back"
K "5" 15
Shot "v-compile"
& "$s\aw.ps1" stop | Out-Null
"done"
