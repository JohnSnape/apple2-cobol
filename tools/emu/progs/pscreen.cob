 IDENTIFICATION DIVISION.
 PROGRAM-ID. PSCREEN.
 DATA DIVISION.
 WORKING-STORAGE SECTION.
*    SCREEN - data (PROCS/SCREEN.SNP; the notes are there)
 77  SC-REPLY     PIC X.
 77  SC-ANSWER    PIC X.
 77  SC-CHOICE    PIC 99.
 77  SC-MAX       PIC 99.
 77  SC-PICK      PIC Z9.
 77  SC-NUMBER    PIC S9(7)V99.
 77  SC-LOW       PIC S9(7)V99.
 77  SC-HIGH      PIC S9(7)V99.
 77  SC-SHOW      PIC -(7)9.99.
 77  SC-SHOW2     PIC -(7)9.99.
 PROCEDURE DIVISION.
 MAIN-PARA.
     DISPLAY "Q1 Go on (x then y)?".
     PERFORM SC-YES-NO. DISPLAY "S1 Y " SC-ANSWER.
     DISPLAY "Q2 Pick 1-5 (7 then 3)".
     MOVE 5 TO SC-MAX.
     PERFORM SC-MENU-PICK. DISPLAY "S2 03 " SC-CHOICE.
     DISPLAY "Q3 Amount 1-100 (500 then 42.5)".
     MOVE 1 TO SC-LOW. MOVE 100 TO SC-HIGH.
     PERFORM SC-GET-NUMBER. MOVE SC-NUMBER TO SC-SHOW.
     DISPLAY "S3       42.50 " SC-SHOW.
     PERFORM SC-PRESS-KEY.
     DISPLAY "S4 END".
     STOP RUN.
*    SCREEN - the paragraphs
 SC-YES-NO.
     MOVE SPACE TO SC-ANSWER.
     PERFORM UNTIL SC-ANSWER NOT = SPACE
         ACCEPT SC-REPLY
         IF SC-REPLY = "Y" OR "y"
             MOVE "Y" TO SC-ANSWER
         END-IF
         IF SC-REPLY = "N" OR "n"
             MOVE "N" TO SC-ANSWER
         END-IF
         IF SC-ANSWER = SPACE
             DISPLAY "Please type Y or N"
         END-IF
     END-PERFORM.
 SC-PRESS-KEY.
     DISPLAY "Press RETURN to go on".
     ACCEPT SC-REPLY.
 SC-MENU-PICK.
     MOVE 0 TO SC-CHOICE.
     PERFORM UNTIL SC-CHOICE > 0
         ACCEPT SC-CHOICE
         IF SC-CHOICE > SC-MAX
             MOVE 0 TO SC-CHOICE
         END-IF
         IF SC-CHOICE = 0
             MOVE SC-MAX TO SC-PICK
             DISPLAY "Please type a number from 1 to " SC-PICK
         END-IF
     END-PERFORM.
 SC-GET-NUMBER.
     MOVE "N" TO SC-ANSWER.
     PERFORM UNTIL SC-ANSWER = "Y"
         ACCEPT SC-NUMBER
         IF SC-NUMBER < SC-LOW OR SC-NUMBER > SC-HIGH
             MOVE SC-LOW TO SC-SHOW
             MOVE SC-HIGH TO SC-SHOW2
             DISPLAY "Please type a number from" SC-SHOW
                 " to" SC-SHOW2
         ELSE
             MOVE "Y" TO SC-ANSWER
         END-IF
     END-PERFORM.
