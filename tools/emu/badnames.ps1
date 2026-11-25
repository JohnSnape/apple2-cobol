# badnames.ps1 - 2026-11-22, DECISIONS 8.10: a name that breaks ProDOS's
# rules typed into each tool.  Expected, one screenshot each:
#   bn-run    RUN "MY FILE!"         Bad file name (key)
#   bn-udel   Utilities DELETE       Bad file name
#   bn-edit   EDIT OA-O "MY FILE!"   Bad file name - press a key
#   bn-fmt    FORMAT OA-O            Bad file name (key)
#   bn-qry    QUERY OA-O             Bad file name (key)
#   bn-rpt    REPORT OA-O            Bad file name (key)
#   bn-view   VIEW "BAD NAME"        File status 31
# progs\badnm.cob is the program half (FILE STATUS "31").
$s = $PSScriptRoot
function K($t, $w = 1) { & "$s\aw.ps1" keys $t | Out-Null; Start-Sleep $w }
function O($c, $w = 1) { & "$s\aw.ps1" raw $c | Out-Null; Start-Sleep $w }
function Shot($n) { & "$s\aw.ps1" shot "$s\$n.png" | Out-Null }
& "$s\aw.ps1" stop | Out-Null; Start-Sleep 1
& "$s\aw.ps1" start | Out-Null; Start-Sleep 3
O "{F2}" 6
K "6" 3; K "MY FILE!~" 4; Shot "bn-run"; K " " 2
K "8" 4; K "3" 2; K "BAD NAME~" 3; Shot "bn-udel"; K " " 2
O "{ESC}" 4
K "1" 5; O "%o"; K "MY FILE!~" 4; Shot "bn-edit"; K " " 2; O "{ESC}" 4
K "2" 6; O "%o"; K "BAD NAME~" 3; Shot "bn-fmt"; K " " 2; O "{ESC}" 4
K "3" 6; O "%o"; K "BAD NAME~" 3; Shot "bn-qry"; K " " 2; O "{ESC}" 4
K "4" 6; O "%o"; K "BAD NAME~" 3; Shot "bn-rpt"; K " " 2; O "{ESC}" 4
K "7" 4; K "BAD NAME~" 5; Shot "bn-view"; K " " 2
Shot "bn-end"
& "$s\aw.ps1" stop | Out-Null
"done"
