* CMPCOM.S  what BOTH compiler passes need
* PUT from COMPILE1.S and COMPILE2.S - no ORG, not
* assembled alone.  One symbol table spans every PUT.
*
* ================= WHY THIS FILE EXISTS ========
* Splitting COMPILE in two was supposed to be a
* clean cut - DATA DIVISION in pass one, PROCEDURE
* DIVISION in pass two - and it very nearly was.
* Two routines crossed the line:
*
*   DDFIGN  lived in CMPDATA, and PDOPND calls it,
*           because SPACES and ZERO are operands in
*           the PROCEDURE DIVISION as well as VALUEs
*           in the DATA DIVISION
*   DDVSCL  lived in CMPPIC, and PDONUM calls it,
*           because a numeric literal has to be
*           packed at a scale whether it is a VALUE
*           or an operand of a MOVE
*
* Both are cases of the same thing: a LITERAL is a
* literal wherever it appears, and the two divisions
* were never as separate as their names suggest.
*
* The alternative was to PUT CMPPIC and CMPDATA into
* pass two as well - 1,836 bytes to get 200 - which
* would also have carried the whole PICTURE parser
* into a pass that never sees a PICTURE.  This is
* the same operation PROMPT.S was, one level down:
* when two programs need the same routine, the
* routine gets its own file rather than a second
* copy or a second reason to load the first program.

* ================= FIGURATIVE CONSTANTS ========
* ---- DDFIGN: VALBUF -> a figurative number ------
* in: VALBUF, VALLEN.  out: A = the number, C=0;
* C=1 if it is not one.
* 0 SPACE 1 ZERO 2 HIGH-VALUE 3 LOW-VALUE 4 QUOTE,
* which is the order VFIGT is in.
* THE WHOLE WORD, every spelling.  It compared the
* first four letters, so HIGH-SCORE, ZERO-FLAG and
* QUOTA were figuratives and never reached the
* symbol table (FIXLIST A16, 2026-11-08).
DDFIGN LDX #0
DDFG1 LDA FIGTAB,X
 BEQ DDFGNO
 STX DDWS
 CMP VALLEN
 BNE DDFG3
 LDY #0
DDFG2 INX
 LDA FIGTAB,X
 CMP VALBUF,Y
 BNE DDFG3
 INY
 CPY VALLEN
 BCC DDFG2
* matched: the number is the byte after the text
 LDA FIGTAB+1,X
 STA FIGN
 CLC
 RTS
DDFG3 LDX DDWS
 TXA
 SEC
 ADC FIGTAB,X
 TAX
 INX
 JMP DDFG1
DDFGNO SEC
 RTS
* length, the word, its number
FIGTAB DFB 5
 ASC 'SPACE'
 DFB 0
 DFB 6
 ASC 'SPACES'
 DFB 0
 DFB 4
 ASC 'ZERO'
 DFB 1
 DFB 5
 ASC 'ZEROS'
 DFB 1
 DFB 6
 ASC 'ZEROES'
 DFB 1
 DFB 10
 ASC 'HIGH-VALUE'
 DFB 2
 DFB 11
 ASC 'HIGH-VALUES'
 DFB 2
 DFB 9
 ASC 'LOW-VALUE'
 DFB 3
 DFB 10
 ASC 'LOW-VALUES'
 DFB 3
 DFB 5
 ASC 'QUOTE'
 DFB 4
 DFB 6
 ASC 'QUOTES'
 DFB 4
 DFB 0

* ================= VALUE SCALING ===============
* ---- PPDIG: is A a digit? ----------------------
* Came across with DDVSCL, which is its only caller
* here; CMPPIC still has its own use for it and
* still calls this one.
PPDIG CMP #$30
 BCC PPDNO
 CMP #$3A
 BCS PPDNO
 SEC
 RTS
PPDNO CLC
 RTS

* ---- DDVSCL: VALBUF -> digits at the item's scale
* A numeric literal has to be packed at the SCALE OF
* THE ITEM, not at the scale it was written with,
* because MOVL copies a cell raw - VMOVL does eight
* bytes and no alignment.  The interpreter aligns
* for MOVN and not for MOVL, and this is where that
* difference is paid for.
*
* VALUE 123.45 into PIC S9(4)V99 is 12345 scale 2.
* VALUE 123    into the same item is 12300, because
* the fraction is padded, not because anybody said
* so.
DDVSCL LDA #0
 STA VSNEG
 STA VSI
 STA VSN
 STA VSFRAC
 STA VSSEEN
* a leading sign is not a digit
 LDA VALBUF
 CMP #$2D
 BNE DVS0
 LDA #1
 STA VSNEG
 INC VSI
 JMP DVS1
DVS0 CMP #$2B
 BNE DVS1
 INC VSI
DVS1 LDX VSI
 CPX VALLEN
 BCS DVS4
 LDA VALBUF,X
 CMP #$2E
 BNE DVS2
 LDA #1
 STA VSSEEN
 INC VSI
 JMP DVS1
DVS2 JSR PPDIG
 BCC DVS3
 LDX VSN
 STA VSBUF,X
 INC VSN
 LDA VSSEEN
 BEQ DVS3
 INC VSFRAC
DVS3 INC VSI
 JMP DVS1
* pad or trim the fraction to the item's scale
DVS4 LDA VSFRAC
 CMP DDECV
 BCC DVS5
 BEQ DVS7
* too many fraction digits: drop from the right
 LDX VSN
 DEX
 STX VSN
 DEC VSFRAC
 JMP DVS4
DVS5 LDX VSN
 LDA #$30
 STA VSBUF,X
 INC VSN
 INC VSFRAC
 JMP DVS4
DVS7 LDX #0
DVS8 CPX VSN
 BCS DVS9
 LDA VSBUF,X
 STA VALBUF,X
 INX
 JMP DVS8
DVS9 LDA VSN
 STA VALLEN
 RTS
