* SORT.S  putting the cursor in order
* A library module (PUT it from LIB.S).
*
* The design is QUERY.md.  This module knows
* NOTHING about records, dictionaries, field types
* or directions: SELECT.S built every cursor entry
* as a byte string that already sorts the right way
* round, so all that is left here is to put a small
* array of byte strings in order.
*
* WHY SHELL SORT
* Every reason is about what this machine has not
* got.
*   No recursion and no stack.  Quicksort needs a
* partition stack, which on a 6502 is either a
* hardware stack you have to bound or a software
* one you have to write.  This needs three
* counters.
*   No second array.  A merge sort needs somewhere
* to merge INTO, which here means a second cursor
* and twice the auxiliary memory.
*   The inner loop is an insertion, so a cursor
* that is nearly in order already - which is the
* common case, because data tends to be entered in
* something close to an order - finishes in close
* to linear time.
*   It is not stable.  That does not matter, and
* the reason is worth knowing: the comparison
* covers the WHOLE entry, and the last two bytes of
* an entry are the record number, high byte first.
* Equal keys are therefore ordered by record
* number, which is the order the scan visited them.
* Ties come out in file order every time, for
* nothing.
*
* WHAT ONE COMPARISON COSTS
* One aux read of QESZ bytes.  The held element is
* read out of the cursor once per outer step and
* stays in main memory, so only the other side is
* fetched.  About eight thousand comparisons for a
* thousand entries, and about five seconds.  It is
* not instant and the manual should not say it is.
*
* A NOTE ON THE BRANCHES
* The inner loop is long enough that several tests
* are written as BCC over / JMP.  That is not
* clumsiness: the natural branch is out of range,
* and finding that out from the assembler after
* every edit is worse than writing it down once.

* ---- SRSORT: the cursor, into key order ---------
* in:  QCOUNT entries at QBASE in bank QBANK
* out: the same entries, in order
SRSORT LDA QCOUNT
 STA SRN
 LDA QCOUNT+1
 STA SRN+1
 ORA SRN
 BEQ SRRTS
 LDA SRN+1
 BNE SRG0
 LDA SRN
 CMP #2
 BCS SRG0
SRRTS RTS

* Knuth's 3h+1 gaps, largest first that is still
* smaller than the count.  GAPS(0) is 1 and the
* count is at least 2 by here, so the search always
* lands.
SRG0 LDX #8
SRG1 LDA GAPLO,X
 CMP SRN
 LDA GAPHI,X
 SBC SRN+1
 BCC SRG2
 DEX
 BPL SRG1
 RTS
SRG2 STX SRGX

SRPASS LDX SRGX
 LDA GAPLO,X
 STA SRH
 LDA GAPHI,X
 STA SRH+1
 STA SRI+1
 LDA SRH
 STA SRI

SRILP LDA SRI
 CMP SRN
 LDA SRI+1
 SBC SRN+1
 BCC SRIL0
 JMP SRNEXG
* the held element, read once for this whole
* insertion - which is what makes a comparison one
* aux read instead of two
SRIL0 LDA SRI
 STA QI
 LDA SRI+1
 STA QI+1
 LDA #<QEBUF
 STA QBP
 LDA #>QEBUF
 STA QBP+1
 JSR SLRDIX
 LDA SRI
 STA SRJ
 LDA SRI+1
 STA SRJ+1

SRJLP SEC
 LDA SRJ
 SBC SRH
 STA SRT
 LDA SRJ+1
 SBC SRH+1
 STA SRT+1
 BCC SRPLC
 LDA SRT
 STA QI
 LDA SRT+1
 STA QI+1
 LDA #<QEBF2
 STA QBP
 LDA #>QEBF2
 STA QBP+1
 JSR SLRDIX
 JSR SRCMP
 BCC SRPLC
 LDA SRJ
 STA QI
 LDA SRJ+1
 STA QI+1
 LDA #<QEBF2
 STA QBP
 LDA #>QEBF2
 STA QBP+1
 JSR SLWRIX
 LDA SRT
 STA SRJ
 LDA SRT+1
 STA SRJ+1
 JMP SRJLP

SRPLC LDA SRJ
 STA QI
 LDA SRJ+1
 STA QI+1
 LDA #<QEBUF
 STA QBP
 LDA #>QEBUF
 STA QBP+1
 JSR SLWRIX
 INC SRI
 BNE SRIL2
 INC SRI+1
SRIL2 JMP SRILP

SRNEXG DEC SRGX
 BMI SRDONE
 JMP SRPASS
SRDONE RTS

* ---- SRCMP: is QEBF2 greater than QEBUF? --------
* out: C=1 if it is, C=0 if it is equal or less
* Unsigned, most significant byte first, over the
* whole entry - key and record number together.
* The record number on the end is what makes
* "equal" mean the same record and nothing else.
SRCMP LDY #0
SRC1 LDA QEBF2,Y
 CMP QEBUF,Y
 BNE SRC2
 INY
 CPY QESZ
 BCC SRC1
 CLC
 RTS
* The bytes differ, and CMP left the carry set
* exactly when QEBF2's byte is the greater.  That
* carry IS the answer.
SRC2 RTS

* ---- the gaps -----------------------------------
* 1, 4, 13, 40, 121, 364, 1093, 3280, 9841.  The
* next would be 29524, and a cursor cannot hold
* that many entries in one bank.
GAPLO DFB $01,$04,$0D,$28,$79,$6C,$45,$D0,$71
GAPHI DFB $00,$00,$00,$00,$00,$01,$04,$0C,$26

* ================= VARIABLES ==================
SRN DS 2
SRI DS 2
SRJ DS 2
SRH DS 2
SRT DS 2
SRGX DFB 0
