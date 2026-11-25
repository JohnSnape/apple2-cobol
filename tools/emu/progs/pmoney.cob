 IDENTIFICATION DIVISION.
 PROGRAM-ID. PMONEY.
 DATA DIVISION.
 WORKING-STORAGE SECTION.
*    MONEY - data (PROCS/MONEY.SNP; the notes are there)
 77  BM-AMOUNT    PIC S9(6)V99.
 77  BM-RATE      PIC 99V9999.
 77  BM-DAYS      PIC 9(4).
 77  BM-MONTHS    PIC 999.
 77  BM-RESULT    PIC S9(7)V99.
 77  BM-PAYMENT   PIC 9(7)V99.
 77  BM-I         PIC 999.
 77  BM-BAL       PIC S9(7)V99.
 77  BM-INT       PIC S9(7)V99.
 77  BM-PRIN      PIC S9(7)V99.
 77  BM-E1        PIC Z,ZZZ,ZZ9.99.
 77  BM-E2        PIC Z,ZZZ,ZZ9.99.
 77  BM-E3        PIC Z,ZZZ,ZZ9.99.
 77  BM-F         PIC 99V9(10).
 77  BM-FH        PIC 99V9(4).
 77  BM-FL        PIC V9(10).
 77  BM-G         PIC 99V9(8).
 77  BM-W6        PIC S9(8)V9(6).
 77  BM-W10       PIC S9(4)V9(10).
 77  BM-W2        PIC S9(10)V99.
 77  SHOW         PIC Z,ZZZ,ZZ9.99.
 PROCEDURE DIVISION.
 MAIN-PARA.
     MOVE 1234.56 TO BM-AMOUNT. MOVE 7.25 TO BM-RATE.
     PERFORM BM-PERCENT. MOVE BM-RESULT TO SHOW.
     DISPLAY "M1        89.51 " SHOW.
     MOVE 10000 TO BM-AMOUNT. MOVE 5.5 TO BM-RATE.
     MOVE 90 TO BM-DAYS.
     PERFORM BM-SIMPLE-INT. MOVE BM-RESULT TO SHOW.
     DISPLAY "M2       135.62 " SHOW.
     MOVE 5000 TO BM-AMOUNT. MOVE 4.5 TO BM-RATE.
     MOVE 120 TO BM-MONTHS.
     PERFORM BM-COMPOUND. MOVE BM-RESULT TO SHOW.
     DISPLAY "M3     7,834.96 " SHOW.
     MOVE 100000 TO BM-AMOUNT. MOVE 6 TO BM-RATE.
     MOVE 360 TO BM-MONTHS.
     PERFORM BM-LOAN-PMT. MOVE BM-PAYMENT TO SHOW.
     DISPLAY "M4       599.55 " SHOW.
     MOVE 12 TO BM-MONTHS.
     PERFORM BM-LOAN-PMT. MOVE BM-PAYMENT TO SHOW.
     DISPLAY "M5     8,606.64 " SHOW.
     MOVE 999999.99 TO BM-AMOUNT. MOVE 9.9999 TO BM-RATE.
     MOVE 480 TO BM-MONTHS.
     PERFORM BM-LOAN-PMT. MOVE BM-PAYMENT TO SHOW.
     DISPLAY "M6     8,491.38 " SHOW.
     MOVE 5000 TO BM-AMOUNT. MOVE 0 TO BM-RATE.
     MOVE 24 TO BM-MONTHS.
     PERFORM BM-LOAN-PMT. MOVE BM-PAYMENT TO SHOW.
     DISPLAY "M7       208.33 " SHOW.
     MOVE 1000 TO BM-AMOUNT. MOVE 12 TO BM-RATE.
     MOVE 6 TO BM-MONTHS.
     PERFORM BM-LOAN-PMT. MOVE BM-PAYMENT TO SHOW.
     DISPLAY "M8       172.55 " SHOW.
     DISPLAY "M9 006 1.71 170.82 0.00".
     PERFORM BM-SCHEDULE.
     STOP RUN.
*    MONEY - the paragraphs
 BM-PERCENT.
     COMPUTE BM-RESULT ROUNDED = BM-AMOUNT * BM-RATE / 100.
 BM-SIMPLE-INT.
*    amount times rate first, to the cent, so the
*    product with the days still fits fourteen digits
     COMPUTE BM-W2 ROUNDED = BM-AMOUNT * BM-RATE.
     COMPUTE BM-RESULT ROUNDED = BM-W2 * BM-DAYS / 36500.
 BM-GROWTH.
*    BM-F = (1 + BM-RATE / 1200) to the power BM-MONTHS,
*    ten decimals, one month at a time:
*        F = F + F * RATE / 1200
*    F times RATE needs more than fourteen digits, so F
*    is split: FH, its first four decimals, and FL, the
*    rest.  Each half times RATE fits.
     MOVE 1 TO BM-F.
     PERFORM BM-MONTHS TIMES
         MOVE BM-F TO BM-FH
         COMPUTE BM-FL = BM-F - BM-FH
         COMPUTE BM-W10 = BM-FH * BM-RATE
         COMPUTE BM-FL = BM-FL * BM-RATE
         COMPUTE BM-F = BM-F + (BM-W10 + BM-FL) / 1200
     END-PERFORM.
 BM-COMPOUND.
     PERFORM BM-GROWTH.
     MOVE BM-F TO BM-FH.
     COMPUTE BM-FL = BM-F - BM-FH.
     COMPUTE BM-W6 = BM-AMOUNT * BM-FH.
     COMPUTE BM-W10 = BM-AMOUNT * BM-FL.
     ADD BM-W10 TO BM-W6.
     COMPUTE BM-RESULT ROUNDED = BM-W6.
 BM-LOAN-PMT.
*    payment = I + I / (F - 1), where I is one month's
*    interest on the whole amount and F the growth
*    factor - the usual formula, P * r * F / (F - 1),
*    in a shape whose every step fits.  F - 1 is cut
*    to eight decimals: a divisor with fewer digits
*    leaves the quotient more.
     IF BM-RATE = 0
         COMPUTE BM-PAYMENT ROUNDED = BM-AMOUNT / BM-MONTHS
     ELSE
         PERFORM BM-GROWTH
         COMPUTE BM-W6 = BM-AMOUNT * BM-RATE / 1200
         COMPUTE BM-G = BM-F - 1
         COMPUTE BM-PAYMENT ROUNDED = BM-W6 + BM-W6 / BM-G
     END-IF.
 BM-SCHEDULE.
*    each month's interest, to the cent, comes off the
*    payment first; the last payment takes what is left
     MOVE BM-AMOUNT TO BM-BAL.
     PERFORM VARYING BM-I FROM 1 BY 1 UNTIL BM-I > BM-MONTHS
         COMPUTE BM-INT ROUNDED = BM-BAL * BM-RATE / 1200
         COMPUTE BM-PRIN = BM-PAYMENT - BM-INT
         IF BM-I = BM-MONTHS
             MOVE BM-BAL TO BM-PRIN
         END-IF
         SUBTRACT BM-PRIN FROM BM-BAL
         PERFORM BM-SHOW-LINE
     END-PERFORM.
 BM-SHOW-LINE.
     MOVE BM-INT TO BM-E1.
     MOVE BM-PRIN TO BM-E2.
     MOVE BM-BAL TO BM-E3.
     DISPLAY BM-I BM-E1 BM-E2 BM-E3.
