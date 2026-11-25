 IDENTIFICATION DIVISION.
 PROGRAM-ID. PAGET.
* SET PRINTER TO SCREEN: a page of 30 lines, padded
* with 10 blank lines as REPORT pads, then a page of
* 3.  Expect: PAGE 1 + LINE 01-21, a pause; LINE
* 22-30, a pause (the next page's ERASE); PAGE 2 +
* LINE 01-03 with no blank lines before it; END.
 DATA DIVISION.
 WORKING-STORAGE SECTION.
 01  L   PIC 99.
 01  PG  PIC 9.
 01  PL.
     05  FILLER  PIC X(5) VALUE "LINE ".
     05  PL-N    PIC Z9.
 01  PH.
     05  FILLER  PIC X(5) VALUE "PAGE ".
     05  PH-N    PIC Z.
 PROCEDURE DIVISION.
 MAIN-PARA.
     SET PRINTER TO SCREEN.
     MOVE 1 TO PG.
     PERFORM PG-HEAD.
     PERFORM VARYING L FROM 1 BY 1 UNTIL L > 30
         MOVE L TO PL-N
         DISPLAY PL UPON PRINTER
     END-PERFORM.
     PERFORM 10 TIMES
         DISPLAY " " UPON PRINTER
     END-PERFORM.
     MOVE 2 TO PG.
     PERFORM PG-HEAD.
     PERFORM VARYING L FROM 1 BY 1 UNTIL L > 3
         MOVE L TO PL-N
         DISPLAY PL UPON PRINTER
     END-PERFORM.
     SET PRINTER TO PAPER.
     DISPLAY "END".
     STOP RUN.
 PG-HEAD.
     DISPLAY ERASE UPON PRINTER.
     MOVE PG TO PH-N.
     DISPLAY PH UPON PRINTER.
