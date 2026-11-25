* OBJTEST.S  a harness for the emitter
* A STANDALONE program, not part of COMPILE.
* Built to the pattern QRYTEST set.
*
* HOW TO RUN IT
*   BLOAD COBOL.LIB,A$3000
*   BRUN OBJTEST
* It writes /COBOL/HELLO with type OBJ ($4A), which
* the interpreter can then be pointed at.
*
* WHY THIS EXISTS
* PCODE.md 5 ends its test order with "then the VM,
* with a hand-assembled object of a dozen
* instructions - hand-assembling it is not a chore
* to avoid, it is the only way to test the
* interpreter before there is a compiler, and it
* proves the object format at the same time."
*
* All of that is still true except the hand part.
* This drives the real emitter, so the object it
* writes is built by the same routines that will
* one day build every program - and if the format
* is wrong, it is wrong in the compiler too, which
* is exactly where you want the bug to be.
*
* THE PROGRAM IT BUILDS
*   ENTER 32
*   LINE 1 : MOVL  MSG, "HELLO, WORLD."
*            DISP  MSG
*   LINE 2 : MOVL  A, 100
*            MOVL  B, 23
*   LINE 3 : ADDP  A, B, 0        A = A + B
*            DISP  A
*            HALT
* Run it and the interpreter should print
* HELLO, WORLD. and then 123.  Three items, three
* literals, eleven instructions.

* XC turns on the 65C02 opcodes.  SYSBOOT already
* REFUSES to boot without a 65C02 - CHK65 - so the
* machine is guaranteed to have one, and until now
* we were paying that compatibility cost and taking
* none of the benefit.  STZ is the one that earns
* its keep: LDA #0 followed by a run of STA becomes
* a run of STZ, two bytes shorter every time.
 XC
 PUT EQUATES
 PUT EQUATES2
 PUT CMPCON

 ORG $8000
 DSK /COBOL/OBJ/OBJTEST

START JSR INIT80
 JSR CONINIT
 JSR CONCLR
 LDA #<MTITLE
 STA STRPTR
 LDA #>MTITLE
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR
 JSR EMINIT

* ================= THE ITEMS ==================
* Storage is handed out in declaration order and
* nothing is aligned.  MSG is thirteen characters;
* A and B are eight bytes each whatever they hold,
* because every numeric variable in this system is
* the same eight bytes.
* item 0: MSG, alphanumeric, 13
 LDA #TALPHA
 STA DTYP
 LDA #13
 STA DLENV
 LDA #0
 STA DDECV
 STA DFLGV
 STA DEDTV
 STA DEDTV+1
 JSR EMALLOC
 JSR EMDESC
* item 1: A, numeric
 LDA #TNUMB
 STA DTYP
 LDA #NCELL
 STA DLENV
 LDA #0
 STA DDECV
 STA DFLGV
 STA DEDTV
 STA DEDTV+1
 JSR EMALLOC
 JSR EMDESC
* item 2: B, numeric
 LDA #TNUMB
 STA DTYP
 LDA #NCELL
 STA DLENV
 LDA #0
 STA DDECV
 STA DFLGV
 STA DEDTV
 STA DEDTV+1
 JSR EMALLOC
 JSR EMDESC

* ================= THE LITERALS ===============
* The text one first, so its offset is zero and the
* dump below is easy to read against the file.
 LDX #0
TL1 LDA MSGTXT,X
 STA LITBUF+1,X
 INX
 CPX #13
 BCC TL1
 LDA #13
 STA LITN
 JSR EMLTXT
 LDA EMLO
 STA LMSG
 LDA EMLO+1
 STA LMSG+1
* 100, as a NUM8 cell: fourteen packed digits, most
* significant first, sign in the flag byte.  Then
* ONE BYTE OF SCALE, which is what lets a literal
* reach the expression stack with its scale intact.
 LDX #0
TL2 LDA CELL100,X
 STA LITBUF,X
 INX
 CPX #NCELL
 BCC TL2
 LDA #0
 STA LITSCL
 JSR EMLNUM
 LDA EMLO
 STA L100
 LDA EMLO+1
 STA L100+1
 LDX #0
TL3 LDA CELL23,X
 STA LITBUF,X
 INX
 CPX #NCELL
 BCC TL3
 LDA #0
 STA LITSCL
 JSR EMLNUM
 LDA EMLO
 STA L23
 LDA EMLO+1
 STA L23+1

* ================= THE CODE ===================
* ENTER: clear the data segment.  Its operand is
* the segment size, which EMALLOC has been counting
* all along.
 LDA DSEG
 STA EMWV
 LDA DSEG+1
 STA EMWV+1
 LDA #OENTER
 JSR EMOP1

 LDA #1
 STA EMWV
 LDA #0
 STA EMWV+1
 JSR EMLINE
* MOVL MSG, "HELLO, WORLD."  - destination first
 STZ EMWV
 STZ EMWV+1
 LDA LMSG
 STA EMWV2
 LDA LMSG+1
 STA EMWV2+1
 LDA #OMOVL
 JSR EMOP2
* DISP MSG
 STZ EMWV
 STZ EMWV+1
 LDA #ODISP
 JSR EMOP1

 LDA #2
 STA EMWV
 LDA #0
 STA EMWV+1
 JSR EMLINE
* MOVL A, 100
 LDA #1
 STA EMWV
 STZ EMWV+1
 LDA L100
 STA EMWV2
 LDA L100+1
 STA EMWV2+1
 LDA #OMOVL
 JSR EMOP2
* MOVL B, 23
 LDA #2
 STA EMWV
 STZ EMWV+1
 LDA L23
 STA EMWV2
 LDA L23+1
 STA EMWV2+1
 LDA #OMOVL
 JSR EMOP2

 LDA #3
 STA EMWV
 LDA #0
 STA EMWV+1
 JSR EMLINE
* ADDP A, B, 0   ->   A = A + B
* dest = dest op src, so ADD B TO A is ADDP A, B.
 LDA #1
 STA EMWV
 STZ EMWV+1
 LDA #2
 STA EMWV2
 STZ EMWV2+1
 STZ EMMODE
 LDA #OADDP
 JSR EMARI
* DISP A
 LDA #1
 STA EMWV
 STZ EMWV+1
 LDA #ODISP
 JSR EMOP1
* HALT
 LDA #OHALT
 JSR EMOP

* ================= REPORT AND WRITE ===========
 LDA CMPERR
 BEQ TOK
 JMP TFAIL
TOK JSR TSHOW
 LDA #<OBJNAME
 STA FNAMP
 LDA #>OBJNAME
 STA FNAMP+1
 JSR SPLITNM
 JSR CMPWRT
 BCS TWERR
 LDA #<MWROTE
 STA STRPTR
 LDA #>MWROTE
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR
 RTS
TWERR PHA
 LDA #<MWERR
 STA STRPTR
 LDA #>MWERR
 STA STRPTR+1
 JSR CONPUTS
 PLA
 JSR THEX
 JSR CONCR
 RTS
TFAIL LDA #<MFAIL
 STA STRPTR
 LDA #>MFAIL
 STA STRPTR+1
 JSR CONPUTS
 LDA CMPERR
 CLC
 ADC #$30
 JSR CONPUTC
 JSR CONCR
 RTS

* ---- TSHOW: the four numbers that matter --------
* Read them against the file with a hex dump: the
* header says descoff 20, litoff 20 + items*8, and
* codeoff litoff + litlen.  If the file does not
* agree with what is printed here, the writer and
* the emitter disagree, and that is worth knowing
* before the interpreter is ever pointed at it.
TSHOW LDA #<MITEMS
 STA STRPTR
 LDA #>MITEMS
 STA STRPTR+1
 JSR CONPUTS
 LDA NITEMS
 JSR THEX
 JSR CONCR
 LDA #<MLIT
 STA STRPTR
 LDA #>MLIT
 STA STRPTR+1
 JSR CONPUTS
 LDA LITLEN+1
 JSR THEX
 LDA LITLEN
 JSR THEX
 JSR CONCR
 LDA #<MCODE
 STA STRPTR
 LDA #>MCODE
 STA STRPTR+1
 JSR CONPUTS
 LDA CODLEN+1
 JSR THEX
 LDA CODLEN
 JSR THEX
 JSR CONCR
 LDA #<MDSEG
 STA STRPTR
 LDA #>MDSEG
 STA STRPTR+1
 JSR CONPUTS
 LDA DSEG+1
 JSR THEX
 LDA DSEG
 JSR THEX
 JMP CONCR

* ---- THEX: A as two hex digits ------------------
THEX PHA
 LSR
 LSR
 LSR
 LSR
 JSR THEX1
 PLA
 AND #$0F
THEX1 CMP #10
 BCC THEX2
 CLC
 ADC #7
THEX2 CLC
 ADC #$30
 JMP CONPUTC

* ================= DATA =======================
MSGTXT ASC 'HELLO, WORLD.'
* 100 and 23 as NUM8 cells: flags, then seven bytes
* of packed BCD, fourteen digits, most significant
* first.  The sign is in the flag byte and NOT in
* the last nibble, which is the change that deleted
* all the masking packed arithmetic normally needs.
CELL100 DFB $00,$00,$00,$00,$00,$00,$01,$00
CELL23 DFB $00,$00,$00,$00,$00,$00,$00,$23

OBJNAME DFB 9
 ASC 'HELLO.OBJ'

MTITLE DFB 31
 ASC 'OBJTEST - build a p-code object'
MITEMS DFB 8
 ASC 'ITEMS   '
MLIT DFB 8
 ASC 'LITLEN  '
MCODE DFB 8
 ASC 'CODELEN '
MDSEG DFB 8
 ASC 'DATASEG '
MWROTE DFB 15
 ASC 'WROTE HELLO.OBJ'
MWERR DFB 11
 ASC 'MLI ERROR $'
MFAIL DFB 12
 ASC 'EMITTER ERR '

* ================= VARIABLES ==================
LMSG DS 2
L100 DS 2
L23 DS 2

* ================= THE MODULES UNDER TEST ========
* PUT here, at the END, and not up with EQUATES.
* Code PUT before ORG and DSK is assembled but never
* written to the object - Merlin 8 left this file
* holding only its own tail (2026-11-07).  Only
* EQU-only files may come before ORG.  CMPVAR stays
* last, as in the compiler stubs.
 PUT CMPEMIT
 PUT CMPOBJ
 PUT CMPVAR
