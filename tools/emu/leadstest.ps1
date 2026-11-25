# leadstest.ps1 - compile LEADS; add two contacts, list, mark one sold, pipeline, quit
$s = $PSScriptRoot
function K($t, $w = 2) { & "$s\aw.ps1" keys $t | Out-Null; Start-Sleep $w }
function Shot($n) { & "$s\aw.ps1" shot "$s\$n.png" | Out-Null }
& "$s\runprog.ps1" -File "$s\progs\LEADS.cob" -Tag lt -CompileWait 60 -RunWait 6 | Out-Null
K "1~" 3; K "ADA LOVELACE~"; K "ENGINES LTD~"; K "555-1234~"; K "1500.00~" 4
K "1~" 3; K "ALAN TURING~"; K "BLETCHLEY~"; K "555-9876~"; K "250.75~" 4
K "2~" 6; Shot "lt-list"
K "4~" 3; K "1~" 5; Shot "lt-sold"
K "5~" 6; Shot "lt-pipe"
K "9~" 4; Shot "lt-quit"
"done"
