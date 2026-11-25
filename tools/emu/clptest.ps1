# clptest.ps1 - the editor's selection, Copy, Cut and Paste (2026-11-11)
# Six lines AAA..FFF; select BBB-DDD with OA-Down, cut, paste above FFF,
# copy one line with nothing selected and paste it at the top; ESC with a
# selection; SA-Right (end of line).  Leaves CLIPBOARD.CLP on the volume.
$s = $PSScriptRoot
function A($c, $x = "") { & "$s\aw.ps1" $c $x | Out-Null }
function K($t, $w = 1) { A keys $t; Start-Sleep $w }
A start; Start-Sleep 3; A raw "{F2}"; Start-Sleep 6
K "1" 4
K "AAA~BBB~CCC~DDD~EEE~FFF" 4
# BBB, then select it and the two below
A raw "%g"; Start-Sleep 1; K "2~" 2
A raw "%{DOWN}"; Start-Sleep 1; A raw "%{DOWN}"; Start-Sleep 1
A shot "$s\clp-sel.png"
A raw "^x"; Start-Sleep 4; A shot "$s\clp-cut.png"
# above FFF
A raw "%g"; Start-Sleep 1; K "3~" 2
A raw "^p"; Start-Sleep 5; A shot "$s\clp-paste.png"
# nothing selected: copy the cursor line (FFF), paste it at the top
A raw "^c"; Start-Sleep 4
A raw "%g"; Start-Sleep 1; K "1~" 2
A raw "^p"; Start-Sleep 5; A shot "$s\clp-paste2.png"
# a selection, then ESC: the selection goes, the editor stays
A raw "%{DOWN}"; Start-Sleep 1; A shot "$s\clp-sel2.png"
A raw "{ESC}"; Start-Sleep 2; A shot "$s\clp-esc.png"
# SA-Right: the end of the line
A sa RIGHT; Start-Sleep 1; A shot "$s\clp-end.png"
A stop
"done"
