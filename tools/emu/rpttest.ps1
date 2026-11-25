# rpttest.ps1 - REPORT end to end: design LIST on CUST.DCT, bands, save,
# export LISTR.SNP, view the code (SA-C); then a program that PLACEs both
# pieces, compiles, runs and prints (slot 1 -> print-test.txt).
$s = $PSScriptRoot
function A($c, $x = "") { & "$s\aw.ps1" $c $x | Out-Null }
function K($t, $w = 1) { A keys $t; Start-Sleep $w }
function OA($l, $w = 1) { A raw "%$l"; Start-Sleep $w }
Remove-Item "$s\print-test.txt" -ErrorAction SilentlyContinue
A start; Start-Sleep 3; A raw "{F2}"; Start-Sleep 6
K "8" 2; K "6"; K "1~" 2; A raw "{ESC}"; Start-Sleep 2
# ---- the designer
K "4" 5
OA i; K "CUST~" 3
OA a; K "1~"; K "30~"; K "L"; K "CUSTOMER LIST~" 2
OA a; K "1~"; K "70~"; K "P"; K "~" 2
OA a; K "2~"; K "70~"; K "D" 2
OA a; K "3~"; K "5~"; K "L"; K "NAME~" 2
OA a; K "3~"; K "30~"; K "L"; K "BALANCE~" 2
OA a; K "4~"; K "5~"; K "R"; K "-"; K "35~" 2
OA a; K "5~"; K "5~"; K "F"; K "CUST-NAME~" 2
OA a; K "5~"; K "30~"; K "F"; K "CUST-BAL~"; K "~" 2
OA a; K "8~"; K "5~"; K "L"; K "TOTAL~" 2
OA a; K "8~"; K "30~"; K "T"; K "CUST-BAL~"; K "~" 2
OA b; K "H"; K "1~"; K "4~" 2
OA b; K "D"; K "5~"; K "5~" 2
OA b; K "F"; K "8~"; K "8~" 2
A shot "$s\rp-design.png"
OA s; K "LIST~" 3; A shot "$s\rp-saved.png"; K " " 1
OA e; K "LISTR~" 4; A shot "$s\rp-exp.png"; K " " 1
A sa C; Start-Sleep 3; A shot "$s\rp-code1.png"; K " " 3; A shot "$s\rp-code2.png"; K " " 3; A shot "$s\rp-code3.png"
A raw "{ESC}"; Start-Sleep 3
A raw "{ESC}"; Start-Sleep 3
# ---- the program
K "1" 4
$prog = @(
 " IDENTIFICATION DIVISION.", " PROGRAM-ID. RPTT.", " DATA DIVISION.", " WORKING-STORAGE SECTION.",
 " 01  CUST-NAME  PIC X(20).", " 01  CUST-BAL   PIC 9(8).", " PROCEDURE DIVISION.", " MAIN-PARA.",
 "     PERFORM RPT-BEGIN.",
 "     MOVE ""AMY"" TO CUST-NAME. MOVE 50 TO CUST-BAL. PERFORM RPT-DETAIL.",
 "     MOVE ""BOB"" TO CUST-NAME. MOVE 101 TO CUST-BAL. PERFORM RPT-DETAIL.",
 "     MOVE ""CAL"" TO CUST-NAME. MOVE 99 TO CUST-BAL. PERFORM RPT-DETAIL.",
 "     MOVE ""DEE"" TO CUST-NAME. MOVE 1000 TO CUST-BAL. PERFORM RPT-DETAIL.",
 "     MOVE ""EVE"" TO CUST-NAME. MOVE 7 TO CUST-BAL. PERFORM RPT-DETAIL.",
 "     PERFORM RPT-END.", "     STOP RUN.", " LAST-PARA.")
K ($prog -join "~") 12
OA g; K "7~" 2
A sa P; Start-Sleep 1; K "R"; K "LISTR~" 4; A shot "$s\rp-pl1.png"; K "~" 5
OA g; K "999~" 2
A sa P; Start-Sleep 1; K "R"; K "LISTR~" 4; A shot "$s\rp-pl2.png"; K "~" 6
OA s; K "RPTT~" 4; K " " 1
A raw "{ESC}"; Start-Sleep 4
K "5" 50; A shot "$s\rp-compile.png"; K " " 2
K "6"; Start-Sleep 3; K "RPTT~" 25; A shot "$s\rp-run.png"
K " " 10
A stop
"done"
