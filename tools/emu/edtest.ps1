# edtest.ps1 - the 2026-11-08 editor: bars, rule, Ins/Ovr, prompts on the
# bottom rows, PLACE (FORMAT pieces with their defaults, a QUERY) and PRINT.
# Needs CUSTSCR.SNP, CUST.DCT and BIGBAL.QRY (designers.ps1).  The printer
# is slot 1, which applewin-cobol.ini sends to print-test.txt.
$s = $PSScriptRoot
function A($c, $x = "") { & "$s\aw.ps1" $c $x | Out-Null }
Remove-Item "$s\print-test.txt" -ErrorAction SilentlyContinue
A start; Start-Sleep 3; A raw "{F2}"; Start-Sleep 6
# Utilities: printer in slot 1
A keys "8"; Start-Sleep 2; A shot "$s\u-menu.png"
A keys "6"; Start-Sleep 1; A keys "1~"; Start-Sleep 2; A raw "{ESC}"; Start-Sleep 2
A keys "1"; Start-Sleep 4
A shot "$s\ed-main.png"
A sa K; Start-Sleep 1; A shot "$s\ed-ins.png"; A sa K; Start-Sleep 1
A keys " IDENTIFICATION DIVISION.~ PROGRAM-ID. PL.~ DATA DIVISION.~ WORKING-STORAGE SECTION.~ 01  X PIC 9.~ PROCEDURE DIVISION.~ MAIN-PARA.~     STOP RUN."
Start-Sleep 8
A raw "%g"; Start-Sleep 1; A shot "$s\ed-goto.png"; A keys "5~"; Start-Sleep 2
# above PROCEDURE DIVISION: Record is the default
A sa P; Start-Sleep 1; A shot "$s\pl-ask.png"; A keys "F"; Start-Sleep 1
A keys "CUSTSCR~"; Start-Sleep 4; A shot "$s\pl-rec.png"; A keys "~"; Start-Sleep 4
# below it: Paint, then Accept once the paint paragraph is in
A raw "%g"; Start-Sleep 1; A keys "99~"; Start-Sleep 2
A sa P; Start-Sleep 1; A keys "F"; Start-Sleep 1
A keys "CUSTSCR~"; Start-Sleep 4; A shot "$s\pl-paint.png"; A keys "~"; Start-Sleep 4
A raw "%g"; Start-Sleep 1; A keys "99~"; Start-Sleep 2
A sa P; Start-Sleep 1; A keys "F"; Start-Sleep 1
A keys "CUSTSCR~"; Start-Sleep 4; A shot "$s\pl-acc.png"; A keys "~"; Start-Sleep 4
# a QUERY
A raw "%g"; Start-Sleep 1; A keys "99~"; Start-Sleep 2
A sa P; Start-Sleep 1; A keys "Q"; Start-Sleep 1; A keys "BIGBAL~"; Start-Sleep 1
A keys "CUST~"; Start-Sleep 5
A raw "%g"; Start-Sleep 1; A keys "1~"; Start-Sleep 2; A shot "$s\pl-top.png"
A raw "%g"; Start-Sleep 1; A keys "21~"; Start-Sleep 2; A shot "$s\pl-mid.png"
# PRINT
A raw "%p"; Start-Sleep 2; A shot "$s\pr-run.png"; Start-Sleep 20; A shot "$s\pr-done.png"
A keys " "; Start-Sleep 1
A raw "{ESC}"; Start-Sleep 3; A shot "$s\ed-menu.png"
A stop
"done"
