 IDENTIFICATION DIVISION.
 PROGRAM-ID. E42.
* DUP.MNU (mnutest.ps1 makes it by hand) has "Q) Quit"
* and "q) Again": one key twice, compile error 42.
 DATA DIVISION.
 WORKING-STORAGE SECTION.
 01  C   PIC X.
 PROCEDURE DIVISION.
 MAIN-PARA.
     ACCEPT C FROM MENU "DUP".
     STOP RUN.
