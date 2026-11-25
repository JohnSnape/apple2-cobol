 IDENTIFICATION DIVISION.
 PROGRAM-ID. PTEXT.
 DATA DIVISION.
 WORKING-STORAGE SECTION.
*    TEXT - data (PROCS/TEXT.SNP; the notes are there)
 01  TX-TEXT      PIC X(80).
 01  TX-T REDEFINES TX-TEXT.
     05  TX-C     PIC X OCCURS 80.
 01  TX-WORK      PIC X(80).
 01  TX-WT REDEFINES TX-WORK.
     05  TX-WC    PIC X OCCURS 80.
 01  TX-ABC.
     05  FILLER   PIC X(26) VALUE "abcdefghijklmnopqrstuvwxyz".
     05  FILLER   PIC X(26) VALUE "ABCDEFGHIJKLMNOPQRSTUVWXYZ".
 01  TX-ABT REDEFINES TX-ABC.
     05  TX-AC    PIC X OCCURS 52.
 77  TX-LEN       PIC 99.
 77  TX-WIDTH     PIC 99.
 77  TX-I         PIC 99.
 77  TX-J         PIC 99.
 77  TX-K         PIC 99.
 77  SHOW         PIC X(20).
 PROCEDURE DIVISION.
 MAIN-PARA.
     MOVE "   Hello, World" TO TX-TEXT.
     PERFORM TX-LENGTH. DISPLAY "T1 15 " TX-LEN.
     PERFORM TX-TRIM. MOVE TX-TEXT TO SHOW.
     DISPLAY "T2 [Hello, World        ] [" SHOW "]".
     PERFORM TX-UPPER. MOVE TX-TEXT TO SHOW.
     DISPLAY "T3 [HELLO, WORLD        ] [" SHOW "]".
     PERFORM TX-LOWER. MOVE TX-TEXT TO SHOW.
     DISPLAY "T4 [hello, world        ] [" SHOW "]".
     MOVE 20 TO TX-WIDTH.
     PERFORM TX-CENTER. MOVE TX-TEXT TO SHOW.
     DISPLAY "T5 [    hello, world    ] [" SHOW "]".
     PERFORM TX-RIGHT. MOVE TX-TEXT TO SHOW.
     DISPLAY "T6 [        hello, world] [" SHOW "]".
     MOVE SPACES TO TX-TEXT.
     PERFORM TX-LENGTH. DISPLAY "T7 00 " TX-LEN.
     STOP RUN.
*    TEXT - the paragraphs
 TX-LENGTH.
*    from the end back to the first non-space
     MOVE 0 TO TX-LEN.
     MOVE 80 TO TX-I.
     PERFORM UNTIL TX-I = 0 OR TX-LEN > 0
         IF TX-C(TX-I) NOT = SPACE
             MOVE TX-I TO TX-LEN
         END-IF
         SUBTRACT 1 FROM TX-I
     END-PERFORM.
 TX-TRIM.
*    find the first non-space, then copy from there
     MOVE 0 TO TX-J.
     PERFORM VARYING TX-I FROM 1 BY 1
             UNTIL TX-I > 80 OR TX-J > 0
         IF TX-C(TX-I) NOT = SPACE
             MOVE TX-I TO TX-J
         END-IF
     END-PERFORM.
     IF TX-J > 1
         MOVE SPACES TO TX-WORK
         MOVE 1 TO TX-K
         PERFORM VARYING TX-I FROM TX-J BY 1 UNTIL TX-I > 80
             MOVE TX-C(TX-I) TO TX-WC(TX-K)
             ADD 1 TO TX-K
         END-PERFORM
         MOVE TX-WORK TO TX-TEXT
     END-IF.
 TX-UPPER.
*    a lower-case letter is found in the first half of
*    TX-AC; the same place in the second half is its
*    capital
     PERFORM VARYING TX-I FROM 1 BY 1 UNTIL TX-I > 80
         IF TX-C(TX-I) IS ALPHABETIC-LOWER
                 AND TX-C(TX-I) NOT = SPACE
             MOVE 0 TO TX-K
             PERFORM VARYING TX-J FROM 1 BY 1
                     UNTIL TX-J > 26 OR TX-K > 0
                 IF TX-AC(TX-J) = TX-C(TX-I)
                     COMPUTE TX-K = TX-J + 26
                 END-IF
             END-PERFORM
             MOVE TX-AC(TX-K) TO TX-C(TX-I)
         END-IF
     END-PERFORM.
 TX-LOWER.
     PERFORM VARYING TX-I FROM 1 BY 1 UNTIL TX-I > 80
         IF TX-C(TX-I) IS ALPHABETIC-UPPER
                 AND TX-C(TX-I) NOT = SPACE
             MOVE 0 TO TX-K
             PERFORM VARYING TX-J FROM 27 BY 1
                     UNTIL TX-J > 52 OR TX-K > 0
                 IF TX-AC(TX-J) = TX-C(TX-I)
                     COMPUTE TX-K = TX-J - 26
                 END-IF
             END-PERFORM
             MOVE TX-AC(TX-K) TO TX-C(TX-I)
         END-IF
     END-PERFORM.
 TX-CENTER.
     PERFORM TX-TRIM.
     PERFORM TX-LENGTH.
     IF TX-LEN < TX-WIDTH
         COMPUTE TX-K = (TX-WIDTH - TX-LEN) / 2
         PERFORM TX-SHIFT
     END-IF.
 TX-RIGHT.
     PERFORM TX-TRIM.
     PERFORM TX-LENGTH.
     IF TX-LEN < TX-WIDTH
         COMPUTE TX-K = TX-WIDTH - TX-LEN
         PERFORM TX-SHIFT
     END-IF.
 TX-SHIFT.
*    the first TX-LEN characters, TX-K places right
     MOVE SPACES TO TX-WORK.
     PERFORM VARYING TX-I FROM 1 BY 1 UNTIL TX-I > TX-LEN
         COMPUTE TX-J = TX-I + TX-K
         MOVE TX-C(TX-I) TO TX-WC(TX-J)
     END-PERFORM.
     MOVE TX-WORK TO TX-TEXT.
