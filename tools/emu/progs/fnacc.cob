 IDENTIFICATION DIVISION.
 PROGRAM-ID. FNACC.
* 2026-11-22, DECISIONS 8.11: an ACCEPT into an item
* a SELECT names in ASSIGN TO takes 64 characters at
* most and beeps on the last seven; any other ACCEPT
* is as it was.  Also the names an end user types:
* a prefix name and a full path (8.10).
* Typed: 70 characters, 70 characters, then
* 3/FN3.DAT, then /cobol/fn3.dat, then 9/X.DAT
* Expected: F1 = the first 64 only / F2 = all 70 /
* P1 00 / P2 00 HELLO / P3 31 / DONE
* (leaves FN3.DAT - cp2 delete it)
 ENVIRONMENT DIVISION.
 INPUT-OUTPUT SECTION.
 FILE-CONTROL.
     SELECT F ASSIGN TO WS-NAME
         ORGANIZATION IS RELATIVE
         ACCESS MODE IS DYNAMIC
         RELATIVE KEY IS K
         FILE STATUS IS S.
 DATA DIVISION.
 FILE SECTION.
 FD  F.
 01  R           PIC X(10).
 WORKING-STORAGE SECTION.
 01  WS-NAME     PIC X(80).
 01  WS-OTHER    PIC X(80).
 01  K           PIC 9(4) COMP.
 01  S           PIC XX.
 PROCEDURE DIVISION.
 MAIN-PARA.
     DISPLAY "F1?".
     ACCEPT WS-NAME.
     DISPLAY "[" WS-NAME "]".
     DISPLAY "F2?".
     ACCEPT WS-OTHER.
     DISPLAY "[" WS-OTHER "]".
     SET PREFIX 3 TO "/COBOL/".
     DISPLAY "P1?".
     ACCEPT WS-NAME.
     OPEN OUTPUT F.
     DISPLAY "P1 " S.
     MOVE 1 TO K. MOVE "HELLO" TO R. WRITE R.
     CLOSE F.
     DISPLAY "P2?".
     ACCEPT WS-NAME.
     OPEN INPUT F.
     MOVE 1 TO K. MOVE SPACES TO R. READ F.
     DISPLAY "P2 " S " " R.
     CLOSE F.
     DISPLAY "P3?".
     ACCEPT WS-NAME.
     OPEN INPUT F.
     DISPLAY "P3 " S.
     DISPLAY "DONE".
     STOP RUN.
