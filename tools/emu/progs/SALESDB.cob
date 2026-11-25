 IDENTIFICATION DIVISION.
 PROGRAM-ID. SALESDB.
*
* A small database program: one record layout, as
* many databases as you like - EAST.DAT for the east
* coast, WEST.DAT for the west - because the file's
* name is a data item (ASSIGN TO WS-DBNAME), read at
* every OPEN.  Seven menu items:
*
*   1 start a new database (or use one that exists)
*   2 enter records         5 filter and print them
*   3 view all records      6 copy the database
*   4 filter and view them  7 edit or delete one
*
* Written 2026-11-22 as the first program to use
* ASSIGN TO a data name.  It is close to the 2,816
* bytes of p-code one program may have: the first
* draft stopped with error 1 four lines from the end,
* and was cut down by checking for a database once,
* in the menu loop, and by taking one-letter answers
* with a plain ACCEPT (which upper-cases them) rather
* than FROM KEY plus a test for each case.
*
 ENVIRONMENT DIVISION.
 INPUT-OUTPUT SECTION.
 FILE-CONTROL.
     SELECT DB-FILE ASSIGN TO WS-DBNAME
         ORGANIZATION IS RELATIVE
         ACCESS MODE IS DYNAMIC
         RELATIVE KEY IS DB-KEY
         FILE STATUS IS DB-STAT.
     SELECT CP-FILE ASSIGN TO WS-CPNAME
         ORGANIZATION IS RELATIVE
         ACCESS MODE IS DYNAMIC
         RELATIVE KEY IS CP-KEY
         FILE STATUS IS CP-STAT.
*
 DATA DIVISION.
 FILE SECTION.
 FD  DB-FILE.
 01  DB-REC.
     05  DB-NAME         PIC X(20).
     05  DB-CITY         PIC X(15).
     05  DB-STATE        PIC XX.
     05  DB-SALES        PIC S9(7)V99 COMP-3.
* The copy's record is the same 45 bytes as one
* field: 20 + 15 + 2, and 8 for the number (every
* number is an eight-byte cell here).
 FD  CP-FILE.
 01  CP-REC              PIC X(45).
*
 WORKING-STORAGE SECTION.
 01  WS-DBNAME           PIC X(30) VALUE SPACES.
 01  WS-CPNAME           PIC X(30) VALUE SPACES.
 01  WS-NEWNAME          PIC X(30).
 01  DB-KEY              PIC 9(4) COMP.
 01  CP-KEY              PIC 9(4) COMP.
 01  DB-STAT             PIC XX.
     88  DB-OK           VALUE "00".
 01  CP-STAT             PIC XX.
 01  WS-CHOICE           PIC X.
 01  WS-KEYHIT           PIC X.
 01  WS-DONE             PIC X VALUE "N".
     88  ALL-DONE        VALUE "Y".
 01  WS-EOF              PIC X.
     88  END-OF-FILE     VALUE "Y".
 01  WS-HIT              PIC X.
     88  IS-HIT          VALUE "Y".
 01  WS-PAPER            PIC X.
     88  ON-PAPER        VALUE "Y".
 01  WS-LAST             PIC 9(4) COMP VALUE 0.
 01  WS-LINES            PIC 99.
 01  WS-COUNT            PIC 9(4).
 01  WS-TOTAL            PIC S9(9)V99 COMP-3.
 01  WS-F-STATE          PIC XX.
 01  WS-F-MIN            PIC S9(7)V99 COMP-3.
 01  WS-IN               PIC X(20).
 01  WS-SHOWN            PIC ZZZ9.
 01  WS-MONEY            PIC $$$,$$$,$$9.99.
*
 PROCEDURE DIVISION.
 MAIN-PARA.
     PERFORM UNTIL ALL-DONE
         PERFORM SHOW-MENU
         ACCEPT WS-CHOICE FROM KEY
         DISPLAY ERASE
         IF WS-DBNAME = SPACES AND WS-CHOICE > "1"
                 AND WS-CHOICE NOT > "7"
             MOVE "0" TO WS-CHOICE
             DISPLAY "START A DATABASE FIRST (OPTION 1)."
             PERFORM PAUSE
         END-IF
         EVALUATE WS-CHOICE
             WHEN "1" PERFORM NEW-DB
             WHEN "2" PERFORM ENTER-RECS
             WHEN "3" PERFORM VIEW-ALL
             WHEN "4" PERFORM FILTER-VIEW
             WHEN "5" PERFORM FILTER-PRINT
             WHEN "6" PERFORM COPY-DB
             WHEN "7" PERFORM EDIT-REC
             WHEN "Q" MOVE "Y" TO WS-DONE
             WHEN "q" MOVE "Y" TO WS-DONE
         END-EVALUATE
     END-PERFORM.
     DISPLAY ERASE.
     STOP RUN.
*
 SHOW-MENU.
     DISPLAY ERASE "SALES DATABASE".
     IF WS-DBNAME = SPACES
         DISPLAY "NO DATABASE YET - START WITH 1"
     ELSE
         DISPLAY "DATABASE: " WS-DBNAME
     END-IF.
     DISPLAY " ".
     DISPLAY "1) START A NEW DATABASE".
     DISPLAY "2) ENTER RECORDS".
     DISPLAY "3) VIEW ALL RECORDS".
     DISPLAY "4) FILTER AND VIEW RECORDS".
     DISPLAY "5) FILTER AND PRINT RECORDS".
     DISPLAY "6) COPY DATABASE".
     DISPLAY "7) EDIT RECORDS".
     DISPLAY "Q) QUIT".
     DISPLAY " ".
     DISPLAY "CHOICE? ".
*
* ---- 1: start a database --------------------------
* A name is a PIC X(30), so it goes LAST on a line:
* its trailing spaces then cost nothing.
* The name typed becomes the file's name at the next
* OPEN.  A name that is already on the disk is not
* wiped without asking: it can be used as it is.
 NEW-DB.
     DISPLAY "NEW DATABASE NAME (BLANK TO CANCEL)? ".
     MOVE SPACES TO WS-NEWNAME.
     ACCEPT WS-NEWNAME.
     IF WS-NEWNAME NOT = SPACES
         MOVE WS-NEWNAME TO WS-DBNAME
         OPEN INPUT DB-FILE
         IF DB-OK
             CLOSE DB-FILE
             DISPLAY "ALREADY ON THE DISK: " WS-DBNAME
             DISPLAY "U)SE IT AS IT IS OR R)EPLACE IT? "
             ACCEPT WS-KEYHIT
             IF WS-KEYHIT = "R"
                 PERFORM MAKE-DB
             ELSE
                 DISPLAY "USING " WS-DBNAME
             END-IF
         ELSE
             PERFORM MAKE-DB
         END-IF
     END-IF.
     PERFORM PAUSE.
*
 MAKE-DB.
     OPEN OUTPUT DB-FILE.
     IF DB-OK
         CLOSE DB-FILE
         DISPLAY "STARTED, EMPTY: " WS-DBNAME
     ELSE
         DISPLAY "COULD NOT CREATE IT - STATUS " DB-STAT
         MOVE SPACES TO WS-DBNAME
     END-IF.
*
* ---- 2: enter records -----------------------------
 ENTER-RECS.
     OPEN I-O DB-FILE.
     PERFORM FIND-LAST.
     DISPLAY "ENTER RECORDS - A BLANK NAME STOPS.".
     MOVE "N" TO WS-EOF.
     PERFORM UNTIL END-OF-FILE
         MOVE SPACES TO DB-REC
         MOVE 0 TO DB-SALES
         DISPLAY " "
         DISPLAY "NAME?  "
         ACCEPT DB-NAME
         IF DB-NAME = SPACES
             MOVE "Y" TO WS-EOF
         ELSE
             DISPLAY "CITY?  "
             ACCEPT DB-CITY
             DISPLAY "STATE? "
             ACCEPT DB-STATE
             DISPLAY "SALES? "
             ACCEPT DB-SALES
             ADD 1 TO WS-LAST
             MOVE WS-LAST TO DB-KEY
             WRITE DB-REC
                 INVALID KEY DISPLAY "COULD NOT WRITE"
             END-WRITE
         END-IF
     END-PERFORM.
     CLOSE DB-FILE.
*
* The next record number: one past the last record in
* the file.  READ NEXT leaves each record's number in
* DB-KEY, and skips deleted ones.
 FIND-LAST.
     MOVE 0 TO WS-LAST.
     PERFORM START-FIRST.
     PERFORM UNTIL END-OF-FILE
         READ DB-FILE NEXT RECORD
             AT END MOVE "Y" TO WS-EOF
         END-READ
         IF NOT END-OF-FILE
             MOVE DB-KEY TO WS-LAST
         END-IF
     END-PERFORM.
*
 START-FIRST.
     MOVE "N" TO WS-EOF.
     MOVE 1 TO DB-KEY.
     START DB-FILE KEY NOT LESS THAN DB-KEY
         INVALID KEY MOVE "Y" TO WS-EOF
     END-START.
*
* ---- 3: view all -----------------------------------
 VIEW-ALL.
     MOVE SPACES TO WS-F-STATE.
     MOVE 0 TO WS-F-MIN.
     MOVE "N" TO WS-PAPER.
     PERFORM LIST-RECS.
*
* ---- 4: filter and view ----------------------------
 FILTER-VIEW.
     PERFORM GET-FILTER.
     MOVE "N" TO WS-PAPER.
     PERFORM LIST-RECS.
*
* ---- 5: filter and print ---------------------------
* The same list, UPON PRINTER.  S shows it first:
* SET PRINTER TO SCREEN pages it, a screen at a time.
 FILTER-PRINT.
     PERFORM GET-FILTER.
     DISPLAY "P)RINTER OR S)CREEN FIRST? ".
     ACCEPT WS-KEYHIT.
     IF WS-KEYHIT = "S"
         SET PRINTER TO SCREEN
     END-IF.
     MOVE "Y" TO WS-PAPER.
     PERFORM LIST-RECS.
     SET PRINTER TO PAPER.
*
 GET-FILTER.
     DISPLAY "STATE, 2 LETTERS (BLANK = EVERY STATE)? ".
     MOVE SPACES TO WS-F-STATE.
     ACCEPT WS-F-STATE.
     DISPLAY "LEAST SALES (0 = ANY AMOUNT)? ".
     MOVE 0 TO WS-F-MIN.
     ACCEPT WS-F-MIN.
*
* One loop for options 3, 4 and 5.  The filter is
* empty for 3; WS-PAPER sends the lines UPON PRINTER
* for 5.
 LIST-RECS.
     OPEN INPUT DB-FILE.
     IF NOT DB-OK
         DISPLAY "CANNOT OPEN (" DB-STAT "): " WS-DBNAME
     ELSE
         MOVE 0 TO WS-COUNT
         MOVE 0 TO WS-TOTAL
         MOVE 0 TO WS-LINES
         IF ON-PAPER
             DISPLAY ERASE UPON PRINTER
             DISPLAY "SALES - " WS-DBNAME UPON PRINTER
             DISPLAY " " UPON PRINTER
         END-IF
         PERFORM START-FIRST
         PERFORM UNTIL END-OF-FILE
             READ DB-FILE NEXT RECORD
                 AT END MOVE "Y" TO WS-EOF
             END-READ
             IF NOT END-OF-FILE
                 PERFORM TEST-REC
                 IF IS-HIT
                     PERFORM SHOW-REC
                 END-IF
             END-IF
         END-PERFORM
         CLOSE DB-FILE
         MOVE WS-COUNT TO WS-SHOWN
         MOVE WS-TOTAL TO WS-MONEY
         IF ON-PAPER
             DISPLAY " " UPON PRINTER
             DISPLAY WS-SHOWN " RECORDS  TOTAL " WS-MONEY
                 UPON PRINTER
         ELSE
             DISPLAY " "
             DISPLAY WS-SHOWN " RECORDS  TOTAL " WS-MONEY
         END-IF
     END-IF.
     PERFORM PAUSE.
*
 TEST-REC.
     MOVE "Y" TO WS-HIT.
     IF WS-F-STATE NOT = SPACES
         IF DB-STATE NOT = WS-F-STATE
             MOVE "N" TO WS-HIT
         END-IF
     END-IF.
     IF DB-SALES < WS-F-MIN
         MOVE "N" TO WS-HIT
     END-IF.
*
* One line a record; on the screen, a pause every
* eighteen (the printer's screen mode pages itself).
 SHOW-REC.
     ADD 1 TO WS-COUNT.
     ADD DB-SALES TO WS-TOTAL.
     MOVE DB-KEY TO WS-SHOWN.
     MOVE DB-SALES TO WS-MONEY.
     IF ON-PAPER
         DISPLAY WS-SHOWN " " DB-NAME " " DB-CITY " "
             DB-STATE " " WS-MONEY UPON PRINTER
     ELSE
         DISPLAY WS-SHOWN " " DB-NAME " " DB-CITY " "
             DB-STATE " " WS-MONEY
         ADD 1 TO WS-LINES
         IF WS-LINES > 17
             DISPLAY "-- PRESS A KEY FOR MORE --"
             ACCEPT WS-KEYHIT FROM KEY
             MOVE 0 TO WS-LINES
         END-IF
     END-IF.
*
* ---- 6: copy the database --------------------------
* Live records only, numbered again from 1: a deleted
* record is skipped by READ NEXT, and leaving its
* number empty in the copy would read back as zeros.
 COPY-DB.
     DISPLAY "COPY " WS-DBNAME.
     DISPLAY "TO WHAT NAME (BLANK TO CANCEL)? ".
     MOVE SPACES TO WS-CPNAME.
     ACCEPT WS-CPNAME.
     IF WS-CPNAME = WS-DBNAME
         DISPLAY "THAT IS THE SAME DATABASE."
         MOVE SPACES TO WS-CPNAME
     END-IF.
     IF WS-CPNAME NOT = SPACES
         PERFORM COPY-RECS
     END-IF.
     PERFORM PAUSE.
*
 COPY-RECS.
     OPEN INPUT DB-FILE.
     OPEN OUTPUT CP-FILE.
     IF NOT DB-OK OR CP-STAT NOT = "00"
         DISPLAY "CANNOT COPY - " DB-STAT " " CP-STAT
     ELSE
         MOVE 0 TO CP-KEY
         PERFORM START-FIRST
         PERFORM UNTIL END-OF-FILE
             READ DB-FILE NEXT RECORD
                 AT END MOVE "Y" TO WS-EOF
             END-READ
             IF NOT END-OF-FILE
                 ADD 1 TO CP-KEY
                 MOVE DB-REC TO CP-REC
                 WRITE CP-REC
             END-IF
         END-PERFORM
         MOVE CP-KEY TO WS-SHOWN
         DISPLAY WS-SHOWN " RECORDS COPIED TO " WS-CPNAME
     END-IF.
     CLOSE DB-FILE.
     CLOSE CP-FILE.
*
* ---- 7: edit a record ------------------------------
* A blank answer keeps what is there.
 EDIT-REC.
     OPEN I-O DB-FILE.
     DISPLAY "RECORD NUMBER? ".
     ACCEPT DB-KEY.
     READ DB-FILE
         INVALID KEY DISPLAY "NO SUCH RECORD"
     END-READ.
     IF DB-OK
         PERFORM CHANGE-REC
     END-IF.
     CLOSE DB-FILE.
     PERFORM PAUSE.
*
 CHANGE-REC.
     MOVE "N" TO WS-PAPER.
     PERFORM SHOW-REC.
     DISPLAY " ".
     DISPLAY "NAME  [" DB-NAME "]? ".
     MOVE SPACES TO WS-IN.
     ACCEPT WS-IN.
     IF WS-IN NOT = SPACES
         MOVE WS-IN TO DB-NAME
     END-IF.
     DISPLAY "CITY  [" DB-CITY "]? ".
     MOVE SPACES TO WS-IN.
     ACCEPT WS-IN.
     IF WS-IN NOT = SPACES
         MOVE WS-IN TO DB-CITY
     END-IF.
     DISPLAY "STATE [" DB-STATE "]? ".
     MOVE SPACES TO WS-IN.
     ACCEPT WS-IN.
     IF WS-IN NOT = SPACES
         MOVE WS-IN TO DB-STATE
     END-IF.
     DISPLAY "CHANGE THE SALES (Y/N)? ".
     ACCEPT WS-KEYHIT.
     IF WS-KEYHIT = "Y"
         DISPLAY "SALES? "
         ACCEPT DB-SALES
     END-IF.
     DISPLAY "S)AVE, D)ELETE THE RECORD, OR C)ANCEL? ".
     ACCEPT WS-KEYHIT.
     EVALUATE WS-KEYHIT
         WHEN "S" PERFORM SAVE-REC
         WHEN "D" PERFORM DROP-REC
         WHEN OTHER DISPLAY "NOTHING CHANGED."
     END-EVALUATE.
*
 SAVE-REC.
     REWRITE DB-REC
         INVALID KEY DISPLAY "COULD NOT SAVE"
     END-REWRITE.
     IF DB-OK
         DISPLAY "SAVED."
     END-IF.
*
 DROP-REC.
     DELETE DB-FILE
         INVALID KEY DISPLAY "COULD NOT DELETE"
     END-DELETE.
     IF DB-OK
         DISPLAY "DELETED."
     END-IF.
*
 PAUSE.
     DISPLAY " ".
     DISPLAY "PRESS A KEY FOR THE MENU".
     ACCEPT WS-KEYHIT FROM KEY.
