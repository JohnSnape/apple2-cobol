# designers.ps1 - FORMAT (save CUST, export CUSTSCR), QUERY (BIGBAL on CUST), back to the menu
$s = $PSScriptRoot
function K($t, $w = 1) { & "$s\aw.ps1" keys $t | Out-Null; Start-Sleep $w }
function O($c, $w = 1) { & "$s\aw.ps1" raw $c | Out-Null; Start-Sleep $w }
function Shot($n) { & "$s\aw.ps1" shot "$s\$n.png" | Out-Null }
& "$s\aw.ps1" start | Out-Null; Start-Sleep 3
O "{F2}" 6
K "2" 6
K "2~"; K "5~"; K "NAME~"; K "CUST-NAME~"; K "20~"; K "A~" 2
K "4~"; K "5~"; K "BALANCE~"; K "CUST-BAL~"; K "8~"; K "N~" 2
O "%s"; K "CUST~" 3; Shot "d-fsave"; K " "
O "%e"; K "CUSTSCR~" 3; Shot "d-fexp"; K " "
O "{ESC}" 4
K "3" 6
O "%i"; K "CUST~" 3
O "%a"; K "1~"; K ">~"; K "100~" 2
O "%k"; K "0~"; K "A~" 2
O "%s"; K "BIGBAL~" 3; Shot "d-qsave"; K " "
O "{ESC}" 4
Shot "d-menu"
"done"
