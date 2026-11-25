 IDENTIFICATION DIVISION.
 PROGRAM-ID. MEDIA.
*
* A minimal media catalogue - books, records,
* films.  One relative file, one record per item.
* Deliberately bare: add fields and validation as
* you like.  The shape is the lesson.
*
 ENVIRONMENT DIVISION.
 INPUT-OUTPUT SECTION.
 FILE-CONTROL.
     SELECT MEDIA-FILE ASSIGN TO "MEDIA.DAT"
         ORGANIZATION IS RELATIVE
         ACCESS MODE IS DYNAMIC
         RELATIVE KEY IS MEDIA-KEY
         FILE STATUS IS FILE-STAT.
*
 DATA DIVISION.
 FILE SECTION.
 FD  MEDIA-FILE.
 01  MEDIA-REC.
     05  MR-TITLE        PIC X(30).
     05  MR-CREATOR      PIC X(20).
     05  MR-KIND         PIC X(6).
     05  MR-YEAR         PIC 9(4).
     05  MR-SHELF        PIC X(8).
*
 WORKING-STORAGE SECTION.
 01  MEDIA-KEY           PIC 9(4) COMP.
 01  FILE-STAT           PIC XX.
     88  STAT-OK         VALUE "00".
 01  WS-CHOICE           PIC X.
 01  WS-DONE             PIC X VALUE "N".
     88  ALL-DONE        VALUE "Y".
 01  WS-EOF              PIC X VALUE "N".
     88  END-OF-FILE     VALUE "Y".
 01  WS-LAST             PIC 9(4) COMP VALUE 0.
 01  WS-SHOWN            PIC ZZZ9.
*
 PROCEDURE DIVISION.
 MAIN-PARA.
     PERFORM OPEN-FILE.
     PERFORM COUNT-RECS.
     PERFORM UNTIL ALL-DONE
         PERFORM SHOW-MENU
         PERFORM GET-CHOICE
         EVALUATE WS-CHOICE
             WHEN "1" PERFORM ADD-ITEM
             WHEN "2" PERFORM LIST-ALL
             WHEN "3" PERFORM FIND-ONE
             WHEN "9" MOVE "Y" TO WS-DONE
         END-EVALUATE
     END-PERFORM.
     CLOSE MEDIA-FILE.
     STOP RUN.
*
* Open I-O; if the file is not there yet, create
* it with OPEN OUTPUT and reopen.
 OPEN-FILE.
     OPEN I-O MEDIA-FILE.
     IF NOT STAT-OK
         OPEN OUTPUT MEDIA-FILE
         CLOSE MEDIA-FILE
         OPEN I-O MEDIA-FILE
     END-IF.
*
* Find the highest key in use, so that adding an
* item after a restart appends instead of
* overwriting record 1.
 COUNT-RECS.
     MOVE "N" TO WS-EOF.
     MOVE 0 TO WS-LAST.
     MOVE 1 TO MEDIA-KEY.
     START MEDIA-FILE KEY NOT LESS THAN MEDIA-KEY
         INVALID KEY MOVE "Y" TO WS-EOF
     END-START.
     PERFORM UNTIL END-OF-FILE
         READ MEDIA-FILE NEXT RECORD
             AT END MOVE "Y" TO WS-EOF
         END-READ
         IF NOT END-OF-FILE
             MOVE MEDIA-KEY TO WS-LAST
         END-IF
     END-PERFORM.
*
 SHOW-MENU.
     DISPLAY " ".
     DISPLAY "MEDIA CATALOGUE".
     DISPLAY " ".
     DISPLAY "1) ADD AN ITEM".
     DISPLAY "2) LIST EVERYTHING".
     DISPLAY "3) FIND BY NUMBER".
     DISPLAY "9) QUIT".
     DISPLAY " ".
*
 GET-CHOICE.
     DISPLAY "CHOICE? ".
     ACCEPT WS-CHOICE.
*
 ADD-ITEM.
     MOVE SPACE TO MEDIA-REC.
     DISPLAY "TITLE?   ".
     ACCEPT MR-TITLE.
     DISPLAY "CREATOR? ".
     ACCEPT MR-CREATOR.
     DISPLAY "KIND?    ".
     ACCEPT MR-KIND.
     DISPLAY "YEAR?    ".
     ACCEPT MR-YEAR.
     DISPLAY "SHELF?   ".
     ACCEPT MR-SHELF.
     ADD 1 TO WS-LAST.
     MOVE WS-LAST TO MEDIA-KEY.
     WRITE MEDIA-REC
         INVALID KEY DISPLAY "COULD NOT WRITE"
     END-WRITE.
*
 LIST-ALL.
     MOVE "N" TO WS-EOF.
     MOVE 1 TO MEDIA-KEY.
     START MEDIA-FILE KEY NOT LESS THAN MEDIA-KEY
         INVALID KEY MOVE "Y" TO WS-EOF
     END-START.
     PERFORM UNTIL END-OF-FILE
         READ MEDIA-FILE NEXT RECORD
             AT END MOVE "Y" TO WS-EOF
         END-READ
         IF NOT END-OF-FILE
             PERFORM SHOW-REC
         END-IF
     END-PERFORM.
*
 FIND-ONE.
     DISPLAY "ITEM NUMBER? ".
     ACCEPT MEDIA-KEY.
     READ MEDIA-FILE
         INVALID KEY DISPLAY "NO SUCH ITEM"
     END-READ.
     IF STAT-OK
         PERFORM SHOW-REC
     END-IF.
*
 SHOW-REC.
     MOVE MEDIA-KEY TO WS-SHOWN.
     DISPLAY WS-SHOWN " " MR-TITLE.
     DISPLAY "     " MR-CREATOR " " MR-KIND " " MR-YEAR.
