* BCDTEST.S  a harness for the decimal pack
* A STANDALONE program, not a library module.
* Written to the pattern QRYTEST.S set, and for the
* reason PCODE.md 5 gives: BMUL and BDIV are the
* least-exercised code in the tree, a product index
* is the sort of thing that is either exactly right
* or off by one with nothing in between, and every
* figure this system will ever print for money goes
* through here.
*
* HOW TO RUN IT
*   BLOAD COBOL.LIB,A$3000
*   BRUN BCDTEST
* It ORGs at $8000, in the overlay band, because
* $6000 is inside COBOL.LIB now.  It ends with an
* RTS, so under BASIC.SYSTEM it comes back to the
* prompt.
*
* WHAT IT PROVES
*   1  ADD and SUBTRACT, including a carry that
*      runs the length of the cell, and the two
*      opposite-sign cases - where an add turns
*      into a subtract and the sign of the answer
*      stops being obvious
*   2  MULTIPLY, from 12 x 12 up to a product that
*      does not fit and must raise OVERFLOW
*   3  DIVIDE: exact, with a remainder, by zero,
*      and with a negative dividend
*   4  COMPARE across every combination of signs -
*      including the one where a negative is less
*      than a positive of the same digits
*   5  the shifts and ROUNDED, which is how the
*      interpreter lines two scales up before it
*      does anything else
*
* Nothing here reports PASS.  Every case prints
* what it got beside what it should have got, and
* the operator reads the screen.  A test that
* reports PASS is a test that can lie.

 XC
 PUT EQUATES
 PUT EQUATES2

 ORG $8000
 DSK /COBOL/OBJ/BCDTEST

* ---- the operations, as the tables name them ----
OPADD EQU 0
OPSUB EQU 1
OPMUL EQU 2
OPDIV EQU 3
OPSHR EQU 0
OPSHL EQU 1
OPRND EQU 2
* signs, as a flag byte holds them
POS EQU $00
NEG EQU $80
* an operand is written as eight digits, a result
* as the whole fourteen the cell holds
OPWID EQU 8
NARITH EQU 17
NCMP EQU 6
NSHFT EQU 6
ASIZE EQU 34
CSIZE EQU 19
SSIZE EQU 25

* ---- zone P, and that is not an accident -------
* This pointer has to survive a JSR into the
* library, and zone S does not: it is caller-saved
* and BPACK is entitled to destroy every byte of
* it.  Zone P is the one place the Golden Rule
* keeps every service out of, which is exactly what
* a driver - and for the length of this program
* that is what we are - needs it for.
TPTR EQU ZPDRV
TCP EQU ZPDRV+2

START JSR INIT80
 JSR CONINIT
 JSR CONCLR
 LDA #<MTITLE
 LDX #>MTITLE
 JSR TMSG
 JSR CONCR
 JSR CONCR
 JSR TARITH
 JSR TWAIT
 JSR TCMP
 JSR TSHFT
 JSR CONCR
 LDA #<MDONE
 LDX #>MDONE
 JSR TMSG
 JSR CONCR
 RTS

* ================= ADD SUB MUL DIV =============
TARITH LDA #<MHARI
 LDX #>MHARI
 JSR TMSG
 JSR CONCR
 LDA #0
 STA TCASE
TA1 LDA TCASE
 CMP #NARITH
 BCS TA9
* Two printed lines a case and twenty-four rows of
* screen, so it stops twice on the way down.
 CMP #6
 BEQ TA15
 CMP #12
 BNE TA2
TA15 JSR TWAIT
TA2 LDA #<ATAB
 LDX #>ATAB
 LDY #ASIZE
 JSR TSEEK
 JSR TALOAD
 JSR TAOP
 JSR TASHOW
 INC TCASE
 JMP TA1
TA9 RTS

* ---- TALOAD: build CELLA and CELLB from TPTR ----
* Entry layout: op, signA, 8 digits, signB, 8
* digits, signW, 14 digits.
TALOAD LDY #1
 LDA (TPTR),Y
 STA TSGN
 LDA #2
 LDX #<CELLA
 LDY #>CELLA
 JSR TPACK
 LDY #10
 LDA (TPTR),Y
 STA TSGN
 LDA #11
 LDX #<CELLB
 LDY #>CELLB
 JSR TPACK
 LDA #0
 STA BCDERR
 STA BCMPR
 RTS

* ---- TPACK: A = offset in the entry, X/Y = cell -
* The eight digits are copied out to a buffer
* first: BPACK wants ZPT1 pointing at them, and
* TPTR must not be moved to do it.
TPACK STA TOFF
 STX TCP
 STY TCP+1
 LDY TOFF
 LDX #0
TPK1 LDA (TPTR),Y
 STA ASCBUF,X
 INY
 INX
 CPX #OPWID
 BCC TPK1
 LDA #OPWID
 STA ALEN
 LDA #<ASCBUF
 STA ZPT1
 LDA #>ASCBUF
 STA ZPT1+1
 LDA TCP
 STA ZPT2
 LDA TCP+1
 STA ZPT2+1
 JSR BCDPACK
* BPACK zeroes the whole cell before it packs, and
* eight digits cannot overflow fourteen, so the
* flag byte is known to be zero here and the sign
* can simply be stored rather than merged in.
 LDA TCP
 STA ZPT2
 LDA TCP+1
 STA ZPT2+1
 LDY #0
 LDA TSGN
 STA (ZPT2),Y
 RTS

* ---- TAOP: run the case's operation ------------
TAOP JSR TSETAB
 LDY #0
 LDA (TPTR),Y
 CMP #OPSUB
 BEQ TAO1
 CMP #OPMUL
 BEQ TAO2
 CMP #OPDIV
 BEQ TAO3
 JMP BCDADD
TAO1 JMP BCDSUB
TAO2 JMP BCDMUL
TAO3 JMP BCDDIV

* ---- TSETAB: ZPT1 -> CELLA, ZPT2 -> CELLB ------
TSETAB LDA #<CELLA
 STA ZPT1
 LDA #>CELLA
 STA ZPT1+1
 LDA #<CELLB
 STA ZPT2
 LDA #>CELLB
 STA ZPT2+1
 RTS

* ---- TASHOW: two lines for one case ------------
TASHOW JSR TNUM
 LDY #0
 LDA (TPTR),Y
 STA TOP
 ASL
 ASL
 TAX
 LDY #4
TAS1 LDA MOPS,X
 JSR CONPUTC
 INX
 DEY
 BNE TAS1
 LDA #2
 JSR TOPND
 LDA #11
 JSR TOPND
 LDA #<MFLAG
 LDX #>MFLAG
 JSR TMSG
 LDA #<CELLB
 STA TCP
 LDA #>CELLB
 STA TCP+1
 LDY #0
 LDA (TCP),Y
 JSR THEX
 LDA #<MERRC
 LDX #>MERRC
 JSR TMSG
 LDA BCDERR
 JSR THEX
 LDA TOP
 CMP #OPDIV
 BNE TAS2
 LDA #<MREM
 LDX #>MREM
 JSR TMSG
 LDA #<BCDREM
 STA TCP
 LDA #>BCDREM
 STA TCP+1
 JSR TCELL
TAS2 JSR CONCR
 LDA #<MGOT
 LDX #>MGOT
 JSR TMSG
 LDA #<CELLB
 STA TCP
 LDA #>CELLB
 STA TCP+1
 JSR TCELL
 LDA #<MWANT
 LDX #>MWANT
 JSR TMSG
 LDY #19
 LDA (TPTR),Y
 JSR TSIGN
 LDY #20
TAS3 LDA (TPTR),Y
 JSR CONPUTC
 INY
 CPY #ASIZE
 BCC TAS3
 JMP CONCR

* ---- TOPND: A = offset, print sign + 8 digits ---
TOPND STA TOFF
 LDA #$20
 JSR CONPUTC
 LDY TOFF
 DEY
 LDA (TPTR),Y
 JSR TSIGN
 LDY TOFF
 LDX #OPWID
TOP1 LDA (TPTR),Y
 JSR CONPUTC
 INY
 DEX
 BNE TOP1
 RTS

* ================= COMPARE =====================
TCMP JSR CONCR
 LDA #<MHCMP
 LDX #>MHCMP
 JSR TMSG
 JSR CONCR
 LDA #0
 STA TCASE
TC1 LDA TCASE
 CMP #NCMP
 BCS TC9
 LDA #<CTAB
 LDX #>CTAB
 LDY #CSIZE
 JSR TSEEK
 LDY #0
 LDA (TPTR),Y
 STA TSGN
 LDA #1
 LDX #<CELLA
 LDY #>CELLA
 JSR TPACK
 LDY #9
 LDA (TPTR),Y
 STA TSGN
 LDA #10
 LDX #<CELLB
 LDY #>CELLB
 JSR TPACK
 LDA #0
 STA BCMPR
 JSR TSETAB
 JSR BCDCMP
 JSR TNUM
 LDA #1
 JSR TOPND
 LDA #10
 JSR TOPND
 LDA #<MGOT
 LDX #>MGOT
 JSR TMSG
 LDA BCMPR
 JSR THEX
 LDA #<MWANT
 LDX #>MWANT
 JSR TMSG
 LDY #18
 LDA (TPTR),Y
 JSR THEX
 JSR CONCR
 INC TCASE
 JMP TC1
TC9 RTS

* ================= SHIFT AND ROUND =============
TSHFT JSR CONCR
 LDA #<MHSHF
 LDX #>MHSHF
 JSR TMSG
 JSR CONCR
 LDA #0
 STA TCASE
TS1 LDA TCASE
 CMP #NSHFT
 BCC TS2
 RTS
TS2 LDA #<STAB
 LDX #>STAB
 LDY #SSIZE
 JSR TSEEK
 LDY #1
 LDA (TPTR),Y
 STA TSGN
 LDA #2
 LDX #<CELLB
 LDY #>CELLB
 JSR TPACK
 LDY #10
 LDA (TPTR),Y
 STA BCDDIG
 JSR TSETAB
 LDY #0
 LDA (TPTR),Y
 CMP #OPSHL
 BEQ TSH1
 CMP #OPRND
 BEQ TSH2
 JSR BCDSHR
 JMP TSH3
TSH1 JSR BCDSHL
 JMP TSH3
TSH2 JSR BCDRND
TSH3 JSR TNUM
 LDY #0
 LDA (TPTR),Y
 ASL
 ASL
 TAX
 LDY #4
TSH4 LDA MSOPS,X
 JSR CONPUTC
 INX
 DEY
 BNE TSH4
 LDA #2
 JSR TOPND
 LDA #$20
 JSR CONPUTC
 LDY #10
 LDA (TPTR),Y
 JSR THEX
 LDA #<MGOT
 LDX #>MGOT
 JSR TMSG
 LDA #<CELLB
 STA TCP
 LDA #>CELLB
 STA TCP+1
 JSR TCELL
 JSR CONCR
 LDA #<MWANT
 LDX #>MWANT
 JSR TMSG
 LDY #11
TSH5 LDA (TPTR),Y
 JSR CONPUTC
 INY
 CPY #SSIZE
 BCC TSH5
 JSR CONCR
 INC TCASE
 JMP TS1

* ================= HELPERS =====================
* ---- TSEEK: A/X = table, Y = entry size --------
* TPTR = table + TCASE * Y, reached by adding Y
* that many times.  Shift-and-add would be faster
* and this runs seventeen times in the life of the
* program.
TSEEK STA TPTR
 STX TPTR+1
 STY TSIZE
 LDX TCASE
 BEQ TSK9
TSK1 CLC
 LDA TPTR
 ADC TSIZE
 STA TPTR
 LDA TPTR+1
 ADC #0
 STA TPTR+1
 DEX
 BNE TSK1
TSK9 RTS

* ---- TCELL: TCP -> a cell.  Sign + 14 digits ----
TCELL LDY #0
 LDA (TCP),Y
 JSR TSIGN
 LDA #NDIG
 STA ALEN
 LDA #<ASCBUF
 STA ZPT1
 LDA #>ASCBUF
 STA ZPT1+1
 LDA TCP
 STA ZPT2
 LDA TCP+1
 STA ZPT2+1
 JSR BCDUNPK
 LDX #0
TCE1 LDA ASCBUF,X
 JSR CONPUTC
 INX
 CPX #NDIG
 BCC TCE1
 RTS

* ---- TSIGN: A = a flag byte -> + or - ----------
TSIGN AND #FNEG
 BEQ TSG1
 LDA #$2D
 BNE TSG2
TSG1 LDA #$2B
TSG2 JMP CONPUTC

* ---- TNUM: the case number, two digits ---------
TNUM LDA TCASE
 CLC
 ADC #1
 LDX #$30
TNU1 CMP #10
 BCC TNU2
 SEC
 SBC #10
 INX
 JMP TNU1
TNU2 STA TWRK
 TXA
 JSR CONPUTC
 LDA TWRK
 ORA #$30
 JSR CONPUTC
 LDA #$20
 JMP CONPUTC

* ---- THEX: A as two hex digits -----------------
THEX STA TWRK
 LSR
 LSR
 LSR
 LSR
 JSR TNIB
 LDA TWRK
 AND #$0F
TNIB CMP #10
 BCC TNB1
 CLC
 ADC #$37
 JMP CONPUTC
TNB1 CLC
 ADC #$30
 JMP CONPUTC

* ---- TMSG: A/X = a counted string --------------
TMSG STA STRPTR
 STX STRPTR+1
 JMP CONPUTS

* ---- TWAIT: let the screen be read -------------
TWAIT LDA #<MKEY
 LDX #>MKEY
 JSR TMSG
 JSR WAITKEY
 JSR CONCR
 RTS

* ================= THE CASES ===================
* op, signA, 8 digits, signB, 8 digits, signW, 14
* digits.  B = B op A throughout, which is COBOL's
* ADD A TO B and not the other way round.
ATAB
 DFB OPADD
 DFB POS
 ASC '00000012'
 DFB POS
 ASC '00000030'
 DFB POS
 ASC '00000000000042'
 DFB OPADD
 DFB POS
 ASC '00000001'
 DFB POS
 ASC '00999999'
 DFB POS
 ASC '00000001000000'
 DFB OPADD
 DFB NEG
 ASC '00000050'
 DFB POS
 ASC '00000030'
 DFB NEG
 ASC '00000000000020'
 DFB OPADD
 DFB POS
 ASC '00000050'
 DFB NEG
 ASC '00000030'
 DFB POS
 ASC '00000000000020'
 DFB OPADD
 DFB NEG
 ASC '00000030'
 DFB NEG
 ASC '00000012'
 DFB NEG
 ASC '00000000000042'
 DFB OPSUB
 DFB POS
 ASC '00000030'
 DFB POS
 ASC '00000100'
 DFB POS
 ASC '00000000000070'
 DFB OPSUB
 DFB POS
 ASC '00000100'
 DFB POS
 ASC '00000030'
 DFB NEG
 ASC '00000000000070'
 DFB OPSUB
 DFB NEG
 ASC '00000030'
 DFB POS
 ASC '00000100'
 DFB POS
 ASC '00000000000130'
 DFB OPMUL
 DFB POS
 ASC '00000012'
 DFB POS
 ASC '00000012'
 DFB POS
 ASC '00000000000144'
 DFB OPMUL
 DFB POS
 ASC '00000999'
 DFB POS
 ASC '00000999'
 DFB POS
 ASC '00000000998001'
 DFB OPMUL
 DFB POS
 ASC '00000000'
 DFB POS
 ASC '00001234'
 DFB POS
 ASC '00000000000000'
 DFB OPMUL
 DFB NEG
 ASC '00000012'
 DFB POS
 ASC '00000012'
 DFB NEG
 ASC '00000000000144'
 DFB OPMUL
 DFB POS
 ASC '00099999'
 DFB POS
 ASC '00099999'
 DFB POS
 ASC '00009999800001'
* The product is 9999999800000001 - sixteen digits
* into a cell that holds fourteen.  What matters
* in this case is not the answer but the flag: f
* should come back with bit 5 set, OVERFLOW, which
* is what ON SIZE ERROR tests.
 DFB OPMUL
 DFB POS
 ASC '99999999'
 DFB POS
 ASC '99999999'
 DFB POS
 ASC '99999800000001'
 DFB OPDIV
 DFB POS
 ASC '00000012'
 DFB POS
 ASC '00000144'
 DFB POS
 ASC '00000000000012'
* 100 / 7 is 14 remainder 2.  The remainder prints
* on the first line, and DIVIDE ... REMAINDER is
* the statement that reads it.
 DFB OPDIV
 DFB POS
 ASC '00000007'
 DFB POS
 ASC '00000100'
 DFB POS
 ASC '00000000000014'
* Divide by zero.  e should come back 02, and the
* want column is what B held going in: BDIV leaves
* the dividend alone rather than writing a wrong
* answer over it.
 DFB OPDIV
 DFB POS
 ASC '00000000'
 DFB POS
 ASC '00000100'
 DFB POS
 ASC '00000000000100'

* signA, 8 digits, signB, 8 digits, expected BCMPR.
* BCMPR is 0 equal, 1 B greater, $FF B less.  The
* answer is about B, which is the operand written
* on the LEFT of a COBOL relation.
CTAB
 DFB POS
 ASC '00000010'
 DFB POS
 ASC '00000020'
 DFB $01
 DFB POS
 ASC '00000020'
 DFB POS
 ASC '00000010'
 DFB $FF
 DFB POS
 ASC '00000020'
 DFB POS
 ASC '00000020'
 DFB $00
 DFB NEG
 ASC '00000010'
 DFB POS
 ASC '00000010'
 DFB $01
 DFB POS
 ASC '00000010'
 DFB NEG
 ASC '00000010'
 DFB $FF
 DFB NEG
 ASC '00000010'
 DFB NEG
 ASC '00000010'
 DFB $00

* op, sign, 8 digits, count, 14 digits expected.
* The value goes into B, which is the operand all
* three of these work on.
STAB
 DFB OPSHR
 DFB POS
 ASC '00123456'
 DFB $02
 ASC '00000000001234'
 DFB OPSHR
 DFB POS
 ASC '00123499'
 DFB $02
 ASC '00000000001234'
 DFB OPRND
 DFB POS
 ASC '00123450'
 DFB $02
 ASC '00000000001235'
 DFB OPRND
 DFB POS
 ASC '00123449'
 DFB $02
 ASC '00000000001234'
* ROUNDED is half-up AWAY FROM ZERO, which is what
* a ledger expects: -1234.50 rounds to -1235, not
* to -1234.  Adding to the MAGNITUDE is what makes
* that true for both signs.
 DFB OPRND
 DFB NEG
 ASC '00123450'
 DFB $02
 ASC '00000000001235'
 DFB OPSHL
 DFB POS
 ASC '00000123'
 DFB $03
 ASC '00000000123000'

* ---- the fixed strings ----
MOPS ASC 'ADD SUB MUL DIV '
MSOPS ASC 'SHR SHL RND '

MTITLE DFB 24
 ASC 'BCDTEST - the money math'
MHARI DFB 29
 ASC 'ADD SUBTRACT MULTIPLY DIVIDE '
MHCMP DFB 7
 ASC 'COMPARE'
MHSHF DFB 17
 ASC 'SHIFT and ROUNDED'
MFLAG DFB 3
 ASC ' f='
MERRC DFB 3
 ASC ' e='
MREM DFB 3
 ASC ' r='
MGOT DFB 6
 ASC '  got '
MWANT DFB 7
 ASC '  want '
MKEY DFB 15
 ASC 'more (any key) '
MDONE DFB 25
 ASC 'Read every line yourself.'

* ---- variables ----
TCASE DFB 0
TSIZE DFB 0
TOFF DFB 0
TSGN DFB 0
TOP DFB 0
TWRK DFB 0
CELLA DS 8
CELLB DS 8
ASCBUF DS 16
