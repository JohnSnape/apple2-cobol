* SELECT2.S  choosing records: the predicate
* A library module, PUT from LIB.S straight after
* SELECT.S - the second half of one module, split
* only because Merlin 8 will not PUT a file over
* 24K.  One symbol table spans every PUT.

* ============== THE PREDICATE =================
* A postfix program over a boolean stack eight
* deep.  The program counter is a one-byte OFFSET
* into QPROG, indexed absolutely: zone S is
* caller-saved and this loop calls AXGET between
* every opcode, so a zero page pointer would have
* been destroyed by the first comparison.  That is
* the whole reason QPMAX is 96 and not 4096.
*
* ---- SLEVAL: QPROG against QREC -> QRES ---------
SLEVAL LDA #0
 STA QBSP
 STA QSTAT
 STA QPCO
 STA QRES
* The dispatch is a chain of CMP / BNE / JMP rather
* than CMP / BEQ, because eight handlers spread
* over four hundred bytes are none of them within
* branch range of the test.  A jump table would be
* shorter and would have to be built with self-
* modifying code or an RTS trick; eight comparisons
* on a path that already reads a record is not
* worth either.
SLE1 LDY QPCO
 LDA QPROG,Y
 INC QPCO
 CMP #0
 BEQ SLEEND
 CMP #1
 BNE SLED2
 JMP SLECL
SLED2 CMP #2
 BNE SLED3
 JMP SLECF
SLED3 CMP #3
 BNE SLED4
 JMP SLEHAS
SLED4 CMP #4
 BNE SLED5
 JMP SLEAND
SLED5 CMP #5
 BNE SLED6
 JMP SLEOR
SLED6 CMP #6
 BNE SLED7
 JMP SLENOT
SLED7 CMP #7
 BNE SLED8
 JMP SLEALL
SLED8 LDA #2
 STA QSTAT
 RTS

* ---- $00 END ------------------------------------
* Exactly one value must be left, or the program
* was not a predicate.
SLEEND LDA QBSP
 CMP #1
 BNE SLEB6
 LDA QBST
 STA QRES
 RTS
SLEB6 LDA #6
 STA QSTAT
 LDA #0
 STA QRES
 RTS

* ---- $01 CMPL  f, r, n, literal -----------------
* QN stays the TRUE length of the literal, because
* QPCO must step over all of it however long it is
* - cap the step and the leftover bytes get run as
* opcodes.  QNC is the capped length, and only the
* copy and the comparison use it.
SLECL JSR SLARG3
 LDA QN
 CMP #QFMAX+1
 BCC SLCL1
 LDA #QFMAX
SLCL1 STA QNC
 LDX #0
 LDY QPCO
SLCL2 CPX QNC
 BCS SLCL3
 LDA QPROG,Y
 STA QLBUF,X
 INY
 INX
 JMP SLCL2
SLCL3 CLC
 LDA QPCO
 ADC QN
 STA QPCO
 LDA QNC
 STA QLLEN
 JSR SLFLD
 LDA QSTAT
 BEQ SLCL4
 RTS
SLCL4 LDA QFTYP
 CMP #2
 BCC SLCL5
 JSR SLLCEL
 JSR SLCMPC
 JMP SLCL6
SLCL5 JSR SLCMPB
SLCL6 JSR SLRELT
 JMP SLEPSH

* ---- $02 CMPF  f, r, g --------------------------
* Field f is fetched first and parked in QLBUF, so
* by the time g arrives the LEFT operand is in the
* buffer SLCMPB treats as the RIGHT one.  The
* answer therefore comes out backwards and is
* negated once, here, rather than by growing a
* second compare routine.
SLECF LDY QPCO
 LDA QPROG,Y
 STA QFNO
 INY
 LDA QPROG,Y
 STA QREL
 INY
 LDA QPROG,Y
 STA QSAV
 INY
 STY QPCO
 JSR SLFLD
 LDA QSTAT
 BEQ SLCF1
 RTS
SLCF1 LDX #0
SLCF2 CPX QFLEN
 BCS SLCF3
 LDA QFBUF,X
 STA QLBUF,X
 INX
 JMP SLCF2
SLCF3 LDA QFLEN
 STA QLLEN
 LDA QSAV
 STA QFNO
 JSR SLFLD
 LDA QSTAT
 BEQ SLCF3A
 RTS
* two cells compare as numbers, anything else as
* text; the type of the SECOND field decides
SLCF3A LDA QFTYP
 CMP #2
 BCC SLCF4
 JSR SLCMPL
 JMP SLCF5
SLCF4 JSR SLCMPB
SLCF5 SEC
 LDA #0
 SBC QCR
 STA QCR
 JSR SLRELT
 JMP SLEPSH

* ---- $03 HAS  f, n, literal ---------------------
SLEHAS LDY QPCO
 LDA QPROG,Y
 STA QFNO
 INY
 LDA QPROG,Y
 STA QN
 INY
 STY QPCO
 LDA QN
 CMP #QFMAX+1
 BCC SLH0
 LDA #QFMAX
SLH0 STA QNC
 LDX #0
 LDY QPCO
SLH1 CPX QNC
 BCS SLH2
 LDA QPROG,Y
 STA QLBUF,X
 INY
 INX
 JMP SLH1
SLH2 CLC
 LDA QPCO
 ADC QN
 STA QPCO
 LDA QNC
 STA QLLEN
 JSR SLFLD
 LDA QSTAT
 BEQ SLH3
 RTS
SLH3 JSR SLFIND
 JMP SLEPSH

* ---- SLFIND: is QLBUF inside QFBUF? -------------
* Case sensitive, and it does no folding.  Fold the
* field with the dictionary's upper-case flag if
* that matters.
SLFIND SEC
 LDA QFLEN
 SBC QLLEN
 BCC SLFN4
 STA QHLIM
 LDA #0
 STA QHI
SLFN1 LDA #0
 STA QHJ
SLFN2 LDA QHJ
 CMP QLLEN
 BCS SLFN5
 CLC
 ADC QHI
 TAY
 LDA QFBUF,Y
 STA QSAV
 LDY QHJ
 LDA QLBUF,Y
 CMP QSAV
 BNE SLFN3
 INC QHJ
 JMP SLFN2
SLFN3 LDA QHI
 CMP QHLIM
 BCS SLFN4
 INC QHI
 JMP SLFN1
SLFN4 LDA #0
 RTS
SLFN5 LDA #1
 RTS

* ---- $04 $05 $06 $07 ----------------------------
SLEAND JSR SLPOP
 STA QSAV
 JSR SLPOP
 AND QSAV
 JMP SLEPSH
SLEOR JSR SLPOP
 STA QSAV
 JSR SLPOP
 ORA QSAV
 JMP SLEPSH
SLENOT JSR SLPOP
 EOR #1
 JMP SLEPSH
SLEALL LDA #1
 JMP SLEPSH

* ---- the boolean stack --------------------------
* Entered with the value in A, which is why the
* first thing it does is put it somewhere: the
* QSTAT test that follows would otherwise destroy
* the very thing being pushed.
SLEPSH STA QSAV
 LDA QSTAT
 BNE SLERT
 LDX QBSP
 CPX #8
 BCC SLEP1
 JMP SLEB6
SLEP1 LDA QSAV
 STA QBST,X
 INC QBSP
 JMP SLE1
SLERT RTS

SLPOP LDX QBSP
 BEQ SLPO1
 DEC QBSP
 LDX QBSP
 LDA QBST,X
 RTS
SLPO1 LDA #6
 STA QSTAT
 LDA #0
 RTS

* ---- SLARG3: f, r, n from the program -----------
SLARG3 LDY QPCO
 LDA QPROG,Y
 STA QFNO
 INY
 LDA QPROG,Y
 STA QREL
 INY
 LDA QPROG,Y
 STA QN
 INY
 STY QPCO
 RTS

* ---- SLLCEL: the literal -> a cell in QKBUF ----
* A NUM or BOOL field is a NUM8 cell in the record
* (DICTIONARY.md 3), so the literal is turned into
* one and the two are compared as NUMBERS - which
* is right for 5 against 00005, for -3 against 2,
* and for 1.5 against 1.50, where no text compare
* could be.
*
* PICDEED is the converter, the same call ACCEPT
* makes, at the field's own decimals.  It wants a
* length-prefixed string, and the byte in front of
* QLBUF is the last byte of QFBUF - which a cell
* uses eight of - so the length goes there and the
* literal is not copied.
*
* QKBUF takes the cell because nothing else is
* using it while a predicate runs: a key is built
* after SLEVAL and never during it.
*
* A BOOL's literal is Y, y, 1 or $01 for true and
* anything else for false; it becomes "1" or "0"
* and goes through the same door.
SLLCEL LDA QFTYP
 CMP #3
 BNE SLLC3
 LDX #$30
 LDA QLBUF
 CMP #$59
 BEQ SLLC1
 CMP #$79
 BEQ SLLC1
 CMP #$31
 BEQ SLLC1
 CMP #1
 BNE SLLC2
SLLC1 LDX #$31
SLLC2 STX QLBUF
 LDA #1
 STA QLLEN
SLLC3 LDA QLLEN
 STA QLPFX
 LDA #<QLPFX
 STA ZPT1
 LDA #>QLPFX
 STA ZPT1+1
 LDA #<QKBUF
 STA ZPT2
 LDA #>QKBUF
 STA ZPT2+1
 LDA QFDEC
 STA PICSCL
 JMP PIDEED

* ---- SLCMPC / SLCMPL: two cells -> QCR --------
* The field in QFBUF is operand B and the other
* cell is A, so BCMP's answer already describes the
* FIELD - 1 when it is the greater - which is what
* QCR means.  No negate, unlike SLCMPB.
* SLCMPC: against the literal's cell in QKBUF.
* SLCMPL: against a field parked in QLBUF.
SLCMPL LDA #<QLBUF
 LDX #>QLBUF
 BNE SLCMQ
SLCMPC LDA #<QKBUF
 LDX #>QKBUF
SLCMQ STA ZPT1
 STX ZPT1+1
 LDA #<QFBUF
 STA ZPT2
 LDA #>QFBUF
 STA ZPT2+1
 JSR BCMP
 LDA BCMPR
 STA QCR
 RTS

* ---- SLCMPB: QFBUF against QLBUF -> QCR ---------
* CMPALP reports 0 equal, 1 if B is greater, $FF if
* B is less.  QCR is wanted the other way about -
* it describes the FIELD, not the literal - and a
* negate is the whole conversion.
SLCMPB LDA #<QFBUF
 STA ZPT1
 LDA #>QFBUF
 STA ZPT1+1
 LDA #<QLBUF
 STA ZPT2
 LDA #>QLBUF
 STA ZPT2+1
 LDA QFLEN
 STA ALEN
 LDA QLLEN
 STA BLEN
 JSR CMPALP
 SEC
 LDA #0
 SBC BCMPR
 STA QCR
 RTS

* ---- SLRELT: QREL applied to QCR -> A ----------
SLRELT LDA QREL
 CMP #0
 BEQ SLRQ
 CMP #1
 BEQ SLRN
 CMP #2
 BEQ SLRL
 CMP #3
 BEQ SLRLE
 CMP #4
 BEQ SLRG
 CMP #5
 BEQ SLRGE
 LDA #2
 STA QSTAT
 LDA #0
 RTS
SLRQ LDA QCR
 BEQ SLRT
 BNE SLRF
SLRN LDA QCR
 BNE SLRT
 BEQ SLRF
SLRL LDA QCR
 CMP #$FF
 BEQ SLRT
 BNE SLRF
SLRLE LDA QCR
 CMP #1
 BEQ SLRF
 BNE SLRT
SLRG LDA QCR
 CMP #1
 BEQ SLRT
 BNE SLRF
SLRGE LDA QCR
 CMP #$FF
 BEQ SLRF
 BNE SLRT
SLRT LDA #1
 RTS
SLRF LDA #0
 RTS

* ================= VARIABLES ==================
* Scalars only.  Every buffer this module uses is
* an address in the data region - see EQUATES - so
* none of them costs a byte of COBOL.LIB.
* QI, QAD and QBP are shared with SORT.S: one
* symbol table spans every PUT.
QT DS 2
QT2 DFB 0
QP DS 3
QMUL DFB 0
QI DS 2
QAD DS 2
QAT DS 2
QAM DFB 0
QBP DS 2
QK DFB 0
QW DFB 0
QD DFB 0
QDIR DFB 0
QKOFF DFB 0
QFILL DFB 0
QROFF DS 2
QSAV DFB 0
QW1 DS 2
QR1 DS 2
QPCO DFB 0
QREL DFB 0
QN DFB 0
QNC DFB 0
QLLEN DFB 0
QCR DFB 0
QBSP DFB 0
QBST DS 8
QHI DFB 0
QHJ DFB 0
QHLIM DFB 0
* the record CATBLK holds; $FF high = none
QRCREC DFB $FF,$FF
QFDEC DFB 0
