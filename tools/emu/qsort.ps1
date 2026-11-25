# qsort.ps1 - QUERY designer: BALDESC = CUST, no condition, field 1 descending;
# then progs\qsort.cob lists CUST.DAT through it (needs qfile.cob's CUST.DAT)
$s = $PSScriptRoot
function K($t, $w = 1) { & "$s\aw.ps1" keys $t | Out-Null; Start-Sleep $w }
function O($c, $w = 1) { & "$s\aw.ps1" raw $c | Out-Null; Start-Sleep $w }
function Shot($n) { & "$s\aw.ps1" shot "$s\$n.png" | Out-Null }
& "$s\aw.ps1" start | Out-Null; Start-Sleep 3
O "{F2}" 6
K "3" 6
O "%i"; K "CUST~" 3
O "%k"; K "1~"; K "D~" 2
O "%s"; K "BALDESC~" 3; Shot "q-bsave"; K " "
O "{ESC}" 4
& "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
& "$s\deploy.ps1" -Delete UNTITLED.OBJ | Out-Null
& "$s\runprog.ps1" -File "$s\progs\qsort.cob" -Tag qsort -CompileWait 40 -RunWait 15 | Out-Null
& "$s\aw.ps1" stop | Out-Null
"done"
