* CLASS.S  the COBOL class conditions
* LIBRARY MODULE - slot 102, vector CLASS.
* IF X IS NUMERIC, IS ALPHABETIC, IS POSITIVE, and
* the user classes SPECIAL-NAMES declares with
* CLASS ... IS.  Opcode $62 in the interpreter.
*
* THE COMPILER PICKS THE TEST, NOT THE RUNTIME
* An earlier shape of this took the item's type and
* flags as parameters and worked out for itself
* which test applied.  It does not need to: the
* compiler has the data descriptor in front of it
* when it emits the opcode, so it can name the
* exact test and the runtime never looks at a type
* byte at all.  That is two fewer parameters, two
* fewer things to disagree about, and it is why
* NUMERIC is three different class codes rather
* than one test with a switch inside it.
*
* PARAMETERS
*   ZPT2  -> the item.  ZPT2 and not ZPT1 so the
*         sign tests can hand it straight to BTEST,
*         which reads the operand it calls B.
*   CLCLS  which test - the table below
*   CLLEN  the item's length in bytes.  Ignored by
*          the three NUM8 tests, which know it.
*   CLTAB  -> a 32-byte membership bitmap, for
*          class 10 only
*
* ANSWER
*   A = 0 the condition is TRUE, 1 FALSE.
* Zero for true so that the byte drops straight
* into the interpreter's condition register and the
* branch after it is the same VBEQ any other
* comparison uses.  A compiled IF NOT is VBNE and
* costs nothing.
*
* CLOBBERS ZPT1 (class 10 only) - zone S, which is
* caller-saved.  Never zone P.
*
*   0  NUMERIC, unsigned display item
*   1  NUMERIC, signed display item
*   2  NUMERIC, a NUM8 cell
*   3  ALPHABETIC - letters of either case, space
*   4  ALPHABETIC-UPPER
*   5  ALPHABETIC-LOWER
*   6  POSITIVE
*   7  NEGATIVE
*   8  ZERO, a NUM8 cell
*   9  ZERO, a display item - digits zero or spaces
*  10  a user class, CLTAB

* ---- CLTEST: the entry ----
CLTEST LDA CLCLS
 CMP #3
 BCS CLT1
 JMP CLNUM
CLT1 CMP #6
 BCS CLT2
 JMP CLALP
CLT2 CMP #9
 BCS CLT3
 JMP CLSGN
CLT3 CMP #9
 BNE CLT4
 JMP CLZA
CLT4 CMP #10
 BNE CLNO
 JMP CLUSR
* An unknown class is FALSE, not a fault.  Nothing
* the compiler emits can reach here; a corrupt
* object can, and answering no is the answer that
* cannot make anything worse.
CLNO LDA #1
 RTS
CLYES LDA #0
 RTS

* ---- CLSGN: POSITIVE, NEGATIVE, ZERO ----
* BTEST already draws exactly this distinction on a
* NUM8 cell and leaves it in BCMPR: 1 above zero,
* $FF below, 0 equal.  Three COBOL conditions and
* one library routine that had them all along.
CLSGN JSR BTEST
 LDA CLCLS
 CMP #6
 BEQ CLSP
 CMP #7
 BEQ CLSN
 LDA BCMPR
 BEQ CLYES
 BNE CLNO
CLSP LDA BCMPR
 CMP #1
 BEQ CLYES
 BNE CLNO
CLSN LDA BCMPR
 CMP #$FF
 BEQ CLYES
 BNE CLNO

* ---- CLNUM: the three NUMERIC tests ----
CLNUM CMP #2
 BEQ CLN8
 LDA CLLEN
 BEQ CLNO
 STA CLCNT
 LDA #0
 STA CLIX
 LDA CLCLS
 BEQ CLNL
* Signed: COBOL allows an operational sign at
* either end and never at both, so a sign found in
* front means the back is not looked at.
 LDY #0
 LDA (ZPT2),Y
 JSR CLSIGN
 BCC CLNS1
 INC CLIX
 DEC CLCNT
 BEQ CLNO
 BNE CLNL
CLNS1 LDY CLLEN
 DEY
 LDA (ZPT2),Y
 JSR CLSIGN
 BCC CLNL
 DEC CLCNT
 BEQ CLNO
CLNL LDY CLIX
CLNL1 LDA (ZPT2),Y
 CMP #$30
 BCC CLNO
 CMP #$3A
 BCS CLNO
 INY
 DEC CLCNT
 BNE CLNL1
 BEQ CLYES

* ---- CLN8: is a NUM8 cell a number ----
* The question is real even though every NUM8 cell
* holds digits by construction: the flag byte has a
* bit for never-assigned and a bit for the last
* thing written here was not a number, and a cell
* carrying either is exactly what IS NUMERIC is
* asked to catch.  COMP-3 had nowhere to put those
* two bits, which is the whole argument for giving
* the sign its own byte - see BCD.S.
CLN8 LDY #0
 LDA (ZPT2),Y
 AND #FUNIN+FINVD
 BEQ CLYES
 BNE CLNO2

* ---- CLNO2 / CLYES2: the same two exits, nearer --
* This module grew past the reach of a relative
* branch: the tests below are more than 128 bytes
* from CLNO and CLYES, and a branch that cannot
* reach is one of the few errors Merlin catches and
* the PC-side checker also catches.  Two three-byte
* trampolines are the cheapest fix and they read
* better than turning a dozen branches into
* branch-over-a-jump pairs.
CLNO2 JMP CLNO
CLYES2 JMP CLYES

* ---- CLALP: ALPHABETIC and its two halves ----
* A space is alphabetic in COBOL.  That is not a
* convenience: an alphabetic item is space-filled
* by MOVE, so a rule that excluded the space would
* make almost every alphabetic item fail its own
* class test.
CLALP LDA CLLEN
 BEQ CLNO2
 STA CLCNT
 LDY #0
CLAL1 LDA (ZPT2),Y
 CMP #$20
 BEQ CLAL2
 LDX CLCLS
 CPX #4
 BEQ CLAU
 CPX #5
 BEQ CLAO
 JSR CLISUP
 BCS CLAL2
 JSR CLISLO
 BCS CLAL2
 BCC CLNO2
CLAU JSR CLISUP
 BCS CLAL2
 BCC CLNO2
CLAO JSR CLISLO
 BCC CLNO2
CLAL2 INY
 DEC CLCNT
 BNE CLAL1
 BEQ CLYES2

* ---- CLZA: a display item that reads as zero ----
CLZA LDA CLLEN
 BEQ CLNO2
 STA CLCNT
 LDY #0
CLZA1 LDA (ZPT2),Y
 CMP #$30
 BEQ CLZA2
 CMP #$20
 BNE CLNO2
CLZA2 INY
 DEC CLCNT
 BNE CLZA1
 BEQ CLYES2

* ---- CLUSR: a class the program declared ----
* SPECIAL-NAMES writes CLASS DIGIT IS "0" THRU "9"
* and the compiler turns the ranges into a 256-bit
* map in the literal pool.  Every range, every
* single character and every union of them collapse
* into the same thirty-two bytes, and the runtime
* is one shift and one AND however complicated the
* declaration was.
CLUSR LDA CLLEN
 BEQ CLNO2
 STA CLCNT
 LDA CLTAB
 STA ZPT1
 LDA CLTAB+1
 STA ZPT1+1
 LDY #0
CLU1 LDA (ZPT2),Y
 STY CLIX
 JSR CLBIT
 LDY CLIX
 BCC CLUNO
 INY
 DEC CLCNT
 BNE CLU1
 JMP CLYES
CLUNO JMP CLNO

* ---- CLBIT: A = char, C=1 if it is in the map ----
CLBIT PHA
 LSR
 LSR
 LSR
 TAY
 PLA
 AND #7
 TAX
 LDA CLMASK,X
 STA CLTMP
 LDA (ZPT1),Y
 AND CLTMP
 BEQ CLBT0
 SEC
 RTS
CLBT0 CLC
 RTS

* ---- CLSIGN: A = char, C=1 if + or - ----
CLSIGN CMP #$2B
 BEQ CLSG1
 CMP #$2D
 BEQ CLSG1
 CLC
 RTS
CLSG1 SEC
 RTS

* ---- CLISUP / CLISLO: A = char, C=1 if a letter --
* Hex, not character constants: the Merlin editor
* upper-cases what you type, so #'a' assembles as
* #'A' and the lower-case test silently becomes the
* upper-case one.
CLISUP CMP #$41
 BCC CLIU0
 CMP #$5B
 BCS CLIU0
 SEC
 RTS
CLIU0 CLC
 RTS
CLISLO CMP #$61
 BCC CLIL0
 CMP #$7B
 BCS CLIL0
 SEC
 RTS
CLIL0 CLC
 RTS

CLMASK DFB $01,$02,$04,$08,$10,$20,$40,$80

* ---- variables ----
CLCNT DFB 0
CLIX DFB 0
CLTMP DFB 0
