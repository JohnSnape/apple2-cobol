# mnutest.ps1 - a menu designed in FORMAT (2026-11-11): OA-M, four lines,
# a fifth line "q) ..." refused as a duplicate key (mn-dup); OA-S MAIN centred; OA-N then OA-O MAIN.MNU brings it back; then
# progs\menu.cob shows it with ACCEPT FROM MENU (X refused, q, 2), and
# e40 (no such menu) and e41 (SET PREFIX 12) are compile errors.
# Leaves MAIN.MNU on the disk for menu.cob, and deletes it at the end.
$s = $PSScriptRoot
function A($c, $x = "") { & "$s\aw.ps1" $c $x | Out-Null }
function K($t, $w = 1) { A keys $t; Start-Sleep $w }
function OA($l, $w = 1) { A raw "%$l"; Start-Sleep $w }
A stop; Start-Sleep 1
A start; Start-Sleep 3; A raw "{F2}"; Start-Sleep 7
K "2" 6
OA m; K "Y" 2
K "2~"; K "10~"; K "MAIN MENU~" 2
K "4~"; K "10~"; K "1) Add a contact~" 2
K "5~"; K "10~"; K "2) List everyone~" 2
K "7~"; K "10~"; K "Q) Quit~" 2
# a second Q (lower case) is refused: "Key already used (key)"
K "9~"; K "10~"; K "q) Quit again~" 2
A shot "$s\mn-dup.png"; K " " 2
A shot "$s\mn-design.png"
OA s; K "MAIN~" 2; A shot "$s\mn-centre.png"; K "Y" 3
A shot "$s\mn-saved.png"; K " " 2
OA n; K "Y" 2
OA o; K "MAIN.MNU~" 4
A shot "$s\mn-open.png"
A raw "{ESC}"; Start-Sleep 4
A stop; Start-Sleep 1
& "$s\runfile.ps1" -File "$s\progs\menu.cob" -Name MENUT -Tag mn -CompileWait 45 -RunWait 6 -Steps "X|mn-bell","q|mn-again","2|mn-end" | Out-Null
# DUP.MNU by hand - "Q) Quit" and "q) Again" - for e42 (one key twice)
$w = Join-Path $s "deploy-stage"; if (Test-Path $w) { Remove-Item -Recurse -Force $w }
New-Item -ItemType Directory -Force $w | Out-Null
$b = [byte[]](0x4D,0x4E,0x55,0x31, 0, 3) + [byte[]](2,10,4) + [Text.Encoding]::ASCII.GetBytes("MENU") +
     [byte[]](4,10,7) + [Text.Encoding]::ASCII.GetBytes("Q) Quit") +
     [byte[]](5,10,8) + [Text.Encoding]::ASCII.GetBytes("q) Again")
[IO.File]::WriteAllBytes("$w\DUP.MNU#4e0000", $b)
Push-Location $w; & "D:\cp2_1.2.0_win-x64_sc\cp2.exe" add --overwrite --from-naps "D:\AppleWin1.32.0.0\COBOL32.po" "DUP.MNU#4e0000" | Out-Null; Pop-Location
foreach ($e in "e40","e41","e42") {
  & "$s\runfile.ps1" -File "$s\progs\$e.cob" -Name ($e.ToUpper()) -Tag $e -CompileWait 40 -RunWait 4 | Out-Null
}
& "$s\deploy.ps1" -Delete MAIN.MNU,DUP.MNU | Out-Null
"done"
