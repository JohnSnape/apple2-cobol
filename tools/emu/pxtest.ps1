# pxtest.ps1 - the prefixes (2026-11-11): Utilities 8 sets 1/ to
# /COBOL/PROCS, EDIT opens 1/DATES.SNP, a reboot still has 1/ (it was
# saved in COBOL.SETTINGS), 0/ moved to /COBOL/SRC still loads the
# overlays from */, then 0/ and 1/ are put back and COBOL.SETTINGS is
# deleted so the other tests start from the defaults.
$s = $PSScriptRoot
function A($c, $x = "") { & "$s\aw.ps1" $c $x | Out-Null }
function K($t, $w = 2) { A keys $t; Start-Sleep $w }
function Shot($n) { A shot "$s\$n.png" }
A stop; Start-Sleep 1
A start; Start-Sleep 3; A raw "{F2}"; Start-Sleep 7
K "8" 4; K "8" 3
K "1~" 1; K "/cobol/procs~" 4
Shot "px-set1"
A raw "{ESC}"; Start-Sleep 2; A raw "{ESC}"; Start-Sleep 3
# EDIT, open 1/DATES.SNP
K "1" 6; A raw "%o"; Start-Sleep 2; K "1/DATES.SNP~" 8
Shot "px-edit"
A raw "{ESC}"; Start-Sleep 4
# reboot: 1/ must still be there
A stop; Start-Sleep 1
A start; Start-Sleep 3; A raw "{F2}"; Start-Sleep 7
K "8" 4; K "8" 3
Shot "px-boot"
# 0/ to the SRC folder; the overlays still come from */
K "0~" 1; K "/COBOL/SRC~" 4
Shot "px-set0"
A raw "{ESC}"; Start-Sleep 2; A raw "{ESC}"; Start-Sleep 3
K "1" 6; Shot "px-edit0"
A raw "{ESC}"; Start-Sleep 4
# put it all back
K "8" 4; K "8" 3
K "0~" 1; K "/COBOL~" 4
K "1~" 1; K "~" 4
Shot "px-back"
A raw "{ESC}"; Start-Sleep 2; A raw "{ESC}"; Start-Sleep 3
A stop; Start-Sleep 1
& "$s\deploy.ps1" -Delete COBOL.SETTINGS | Out-Null
"done"
