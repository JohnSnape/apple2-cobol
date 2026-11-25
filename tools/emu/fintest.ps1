# fintest.ps1 - compile FINANCE; deposit, two payments, list, balance, category total, quit
$s = $PSScriptRoot
function K($t, $w = 2) { & "$s\aw.ps1" keys $t | Out-Null; Start-Sleep $w }
function Shot($n) { & "$s\aw.ps1" shot "$s\$n.png" | Out-Null }
& "$s\runprog.ps1" -File "$s\progs\FINANCE.cob" -Tag ft -CompileWait 70 -RunWait 6 | Out-Null
K "1~" 3; K "110126~"; K "PAYCHECK~"; K "INCOME~"; K "D~"; K "2500.00~" 4
K "1~" 3; K "110326~"; K "LANDLORD~"; K "RENT~"; K "P~"; K "1200.50~" 4
K "1~" 3; K "110526~"; K "GROCER~"; K "FOOD~"; K "P~"; K "87.25~" 4
K "2~" 8; Shot "ft-list"
K "3~" 6; Shot "ft-bal"
K "4~" 3; K "RENT~" 6; Shot "ft-cat"
K "9~" 4; Shot "ft-quit"
"done"
