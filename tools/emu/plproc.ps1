# plproc.ps1 - SA-P, P)rocedure: place PROCS/DATES.SNP into a skeleton.
# Above PROCEDURE DIVISION the default is the data; at the end, the
# paragraphs.  Needs deployprocs.ps1 run first.
$s = $PSScriptRoot
function A($c, $x = "") { & "$s\aw.ps1" $c $x | Out-Null }
function K($t, $w = 1) { A keys $t; Start-Sleep $w }
A start; Start-Sleep 3; A raw "{F2}"; Start-Sleep 6
K "1" 4
K " IDENTIFICATION DIVISION.~ PROGRAM-ID. X.~ DATA DIVISION.~ WORKING-STORAGE SECTION.~ PROCEDURE DIVISION.~ MAIN-PARA.~     STOP RUN." 6
# on PROCEDURE DIVISION: the data goes above it
A raw "%g"; Start-Sleep 1; K "5~" 2
A sa P; Start-Sleep 1; A shot "$s\pp-ask.png"; K "P"
K "DATES~" 5; A shot "$s\pp-data.png"; K "~" 6
A shot "$s\pp-data2.png"
# past the end: the paragraphs
A raw "%g"; Start-Sleep 1; K "999~" 2
A sa P; Start-Sleep 1; K "P"; K "DATES~" 5; K "~" 8
A shot "$s\pp-paras.png"
A stop
"done"
