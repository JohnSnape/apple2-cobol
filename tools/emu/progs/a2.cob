 IDENTIFICATION DIVISION.
 PROGRAM-ID. A2.
 DATA DIVISION.
 WORKING-STORAGE SECTION.
 01  T.
     05  N   PIC 9(3) OCCURS 5.
 01  NT.
     05  NM  PIC X(4) OCCURS 3.
 01  G.
     05  ROW OCCURS 3.
         10  RA  PIC XX.
         10  RB  PIC 99.
 01  Z   PIC X(3) VALUE "ZZZ".
 01  I   PIC 99.
 01  X   PIC 9(4).
 PROCEDURE DIVISION.
 MAIN-PARA.
     MOVE 1 TO I.
     PERFORM UNTIL I > 5
         COMPUTE N(I) = I * 10
         ADD 1 TO I
     END-PERFORM.
     DISPLAY "N 010 020 050 " N(1) " " N(2) " " N(5).
     MOVE 3 TO I.
     DISPLAY "N(I) 030 " N(I).
     MOVE SPACES TO NT.
     MOVE "ABCD" TO NM(2).
     DISPLAY "[    ][ABCD][    ] [" NM(1) "][" NM(2) "][" NM(3) "]".
     MOVE "XY" TO RA(3).
     MOVE 42 TO RB(3).
     MOVE "PQ" TO RA(1).
     DISPLAY "XY 42 PQ ZZZ " RA(3) " " RB(3) " " RA(1) " " Z.
     IF N(2) = 20 DISPLAY "IF OK" ELSE DISPLAY "IF FAIL".
     ADD N(1) TO N(2).
     COMPUTE X = N(1) + N(2) + N(3).
     DISPLAY "SUM 0070 " X.
     MOVE 6 TO I.
     DISPLAY N(I).
     DISPLAY "NOT HERE".
     STOP RUN.
