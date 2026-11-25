 IDENTIFICATION DIVISION.
 PROGRAM-ID. CCOPY.
* COPY (2026-11-11): MYREC from 0/ (a plain book,
* copied whole), CUSTSCR (FORMAT's .SNP: the record
* here, the paint and accept paragraphs below), and
* MYPARA by a prefix name.  Expect
*   NAME / BALANCE painted at lines 3 and 5
*   C1 COPIED     42 Y
*   F1 AMY       00000050
*   C2 COPIED     42
 DATA DIVISION.
 WORKING-STORAGE SECTION.
     COPY MYREC.
 01  X          PIC X VALUE "Y".
     copy custscr.
 PROCEDURE DIVISION.
 MAIN-PARA.
     DISPLAY ERASE.
     PERFORM CUSTSCR-PAINT.
     DISPLAY "C1 " MY-NAME " " MY-NUM " " X AT LINE 8 COLUMN 1.
     MOVE "AMY" TO CUST-NAME. MOVE 50 TO CUST-BAL.
     DISPLAY "F1 " CUST-NAME " " CUST-BAL.
     PERFORM SHOW-IT.
     STOP RUN.
     COPY CUSTSCR.
     COPY "*/CPYT/MYPARA".
