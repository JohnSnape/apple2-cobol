* PICTURE.S  the edit engine
* A library module (PUT it from LIB.S).
*
* Every number a person ever sees comes through
* here.  A NUM8 cell is fourteen digits and a flag
* byte; a PICTURE says how those digits are to be
* shown - which of them, where the point goes, what
* fills the empty places, where the currency sign
* and the sign itself land.  MOVE AMOUNT TO
* PRINT-LINE is this file.
*
* THE PICTURE CHARACTERS
*   9  a digit, always shown
*   Z  a digit, shown as a space while suppressing
*   *  a digit, shown as an asterisk instead
*   $  currency: fixed if it stands alone, floating
*      if there is a run of them
*   +  sign: '+' or '-'.  Fixed, floating, or
*      trailing
*   -  sign: '-' or a space.  The same three forms
*   ,  a separator, shown only once digits are
*   .  the decimal point, and the alignment point
*   B  a space,  0  a zero,  /  a slash
*   CR DB  shown when negative, two spaces when not
*
* THE ONE IDEA WORTH THE PAGE: BACK-FILLING
* A floating $ has to end up immediately left of
* the first digit that prints, and we do not know
* where that is until we get there.  So while
* suppressing we write the fill character and
* remember WHERE we wrote it; when a significant
* digit finally arrives we reach back into the
* buffer and drop the $ into the last remembered
* place.  One byte of memory turns a problem that
* looks like it needs two passes into one pass.
*
* WHY NOTHING IS SHIFTED
* The cell is not modified and not aligned.  Every
* picture position is mapped to a digit index
* instead: the units digit is at 13 - PICSCL, and
* each position to the left is one index lower.
* Positions that fall outside the cell are zeros.
* An edit that shifted the source would have to put
* it back, and a MOVE that alters its source is a
* bug waiting to be written.
*
* CALLING CONVENTION
* PICEDIT reads the cell, so the cell is operand A
* (ZPT1) as it is everywhere else in the library.
* PICDEED writes the cell, so there it is operand B
* (ZPT2).  The data always sits in the pointer its
* direction says it should.

* ---- PIINIT: the three characters SPECIAL-NAMES
* may change ----------------------------------
* CURRENCY SIGN IS and DECIMAL-POINT IS COMMA are
* compile-time clauses that set one byte each.
PIINIT LDA #$24
 STA PICCUR
 LDA #$2E
 STA PICDPT
 LDA #$2C
 STA PICCOM
 RTS

* ---- PIEDIT: cell + picture -> PICBUF -----------
* in:  ZPT1 -> NUM8 cell
*      ZPT2 -> picture, length-prefixed
*      PICSCL = implied decimals of the cell
*      PICFLG bit0 = BLANK WHEN ZERO
* out: PICBUF, PICLEN
PIEDIT LDY #0
 LDA (ZPT2),Y
 STA PLEN
 STZ PICLEN
 LDA PLEN
 BNE PIE1
 RTS
PIE1 JSR PISCAN
 JSR PISIGN
 JSR PIZERO
* PDIDX = 14 - PICSCL - PINT, and it may go
* negative: a picture with more integer positions
* than the cell holds simply starts in leading
* zeros.
 SEC
 LDA #14
 SBC PICSCL
 SEC
 SBC PINT
 STA PDIDX
 LDA #1
 STA PSUP
 STZ POUT
 STZ PFCH
 STZ PFPOS
 STZ PFIRST
 LDA #$20
 STA PFILL
 LDA #1
 STA PIDX
PIEL LDA PIDX
 CMP PLEN
 BEQ PIEL2
 BCS PIEDN
PIEL2 LDY PIDX
 LDA (ZPT2),Y
 STA PCH
 JSR PIONE
 INC PIDX
 JMP PIEL
PIEDN LDA POUT
 STA PICLEN
* BLANK WHEN ZERO is the last word: whatever the
* picture built, a zero value blanks it.
 LDA PICFLG
 AND #1
 BEQ PIED2
 LDA PZERO
 BEQ PIED2
 JSR PIBLNK
PIED2 RTS

* ---- PIONE: deal with one picture character -----
PIONE LDA PCH
 CMP #$39
 BNE PIO1
 JMP PEDIG9
PIO1 CMP #$5A
 BNE PIO2
 JMP PEDIGZ
PIO2 CMP #$2A
 BNE PIO3
 JMP PEDIGA
PIO3 CMP #$24
 BEQ PIOFL
 CMP #$2B
 BEQ PIOFL
 CMP #$2D
 BNE PIO4
PIOFL JMP PEFLT
PIO4 CMP #$2C
 BNE PIO5
 JMP PECOM
PIO5 CMP #$2E
 BNE PIO6
 JMP PEPT
PIO6 CMP #$42
 BNE PIO7
 LDA #$20
 JMP PEPUT
PIO7 CMP #$30
 BNE PIO8
 LDA #$30
 JMP PEPUT
PIO8 CMP #$2F
 BNE PIO9
 LDA #$2F
 JMP PEPUT
PIO9 CMP #$43
 BNE PIO10
 JMP PECR
PIO10 CMP #$44
 BNE PIO11
 JMP PEDB
* anything else is passed through, which is how a
* picture may carry a character we never thought of
PIO11 LDA PCH
 JMP PEPUT

* ---- PEDIG9: a 9 - always shown -----------------
* A 9 also ends suppression for everything to its
* right, which is what makes 99Z9 mean what it
* looks like.
PEDIG9 JSR PINEXT
 JSR PEFLSH
 STZ PSUP
 LDA PDIG
 CLC
 ADC #$30
 JMP PEPUT

* ---- PEDIGZ / PEDIGA: suppressible digits -------
PEDIGZ LDA #$20
 STA PFILL
 JMP PEDIGS
PEDIGA LDA #$2A
 STA PFILL
PEDIGS JSR PINEXT
 LDA PSUP
 BEQ PEDS2
 LDA PDIG
 BNE PEDS2
* still suppressing and the digit is zero: write
* the fill, and remember the place in case a
* floating character has to land here
 LDA PFPOS
 STA PTMP
 LDA PFILL
 JSR PEPUT
 LDA POUT
 SEC
 SBC #1
 STA PFPOS
 RTS
PEDS2 JSR PEFLSH
 STZ PSUP
 LDA PDIG
 CLC
 ADC #$30
 JMP PEPUT

* ---- PEFLT: $ + or - ----------------------------
* The FIRST one in a picture is the character
* itself - a fixed sign, a fixed currency, or the
* head of a floating run.  Every later one is a
* digit position that the character may float
* across.
PEFLT LDA PFIRST
 BNE PEFL5
 LDA #1
 STA PFIRST
* is the next character the same?  Then this is a
* floating run and this position holds no digit.
 LDY PIDX
 INY
 CPY PLEN
 BEQ PEFL1
 BCS PEFL3
PEFL1 LDA (ZPT2),Y
 CMP PCH
 BNE PEFL3
* floating: put the fill down and remember where
 JSR PESCH
 STA PFCH
 LDA #$20
 JSR PEPUT
 LDA POUT
 SEC
 SBC #1
 STA PFPOS
 RTS
* fixed: the character goes down here and now
PEFL3 JSR PESCH
 JMP PEPUT
* a later one: a digit position inside the run
PEFL5 LDA #$20
 STA PFILL
 JMP PEDIGS

* ---- PESCH: -> A = the character to show --------
* '+' shows the sign either way; '-' shows only a
* minus and a space for positive; '$' is always the
* currency character, whatever SPECIAL-NAMES made
* it.
PESCH LDA PCH
 CMP #$24
 BNE PES1
 LDA PICCUR
 RTS
PES1 CMP #$2B
 BNE PES2
 LDA PSGN
 BNE PESM
 LDA #$2B
 RTS
PES2 LDA PSGN
 BNE PESM
 LDA #$20
 RTS
PESM LDA #$2D
 RTS

* ---- PEFLSH: back-fill the floating character ---
* Called the moment suppression ends.  This is the
* whole trick: the character was never written
* where the picture put it, only where the number
* turned out to need it.
PEFLSH LDA PFCH
 BEQ PEFD
 LDX PFPOS
 STA PICBUF,X
 LDA #0
 STA PFCH
PEFD RTS

* ---- PECOM: a separator -------------------------
* Shown only if a digit has been shown, or it would
* print ,123 and look like a mistake.
PECOM LDA PSUP
 BEQ PEC1
 LDA PFILL
 JSR PEPUT
 LDA POUT
 SEC
 SBC #1
 STA PFPOS
 RTS
PEC1 LDA PICCOM
 JMP PEPUT

* ---- PEPT: the decimal point --------------------
* Suppression stops here whatever happens: the
* digits after a point are the ones people read
* even when they are zeros.
PEPT JSR PEFLSH
 STZ PSUP
 LDA PICDPT
 JMP PEPUT

* ---- PECR / PEDB: the trailing credit marks -----
PECR LDY PIDX
 INY
 CPY PLEN
 BEQ PECR1
 BCS PECRX
PECR1 LDA (ZPT2),Y
 CMP #$52
 BNE PECRX
 INC PIDX
 LDA #$43
 LDX #$52
 JMP PESHOW
PECRX LDA PCH
 JMP PEPUT
PEDB LDY PIDX
 INY
 CPY PLEN
 BEQ PEDB1
 BCS PEDBX
PEDB1 LDA (ZPT2),Y
 CMP #$42
 BNE PEDBX
 INC PIDX
 LDA #$44
 LDX #$42
 JMP PESHOW
PEDBX LDA PCH
 JMP PEPUT

* PESHOW: A/X are the two characters, printed only
* when the value is negative
PESHOW STA PTMP
 STX PTMP+1
 LDA PSGN
 BNE PESH1
 LDA #$20
 JSR PEPUT
 LDA #$20
 JMP PEPUT
PESH1 LDA PTMP
 JSR PEPUT
 LDA PTMP+1
 JMP PEPUT

* ---- PEPUT: A -> the next place in PICBUF -------
PEPUT LDX POUT
 CPX #PICMAX
 BCS PEPD
 STA PICBUF,X
 INC POUT
PEPD RTS

* ---- PINEXT: -> PDIG = the next source digit ----
* Positions outside the cell read as zero, which is
* what makes a picture wider than its data print
* leading and trailing noughts rather than
* rubbish.
PINEXT LDA #0
 STA PDIG
 LDA PDIDX
 BMI PINX2
 CMP #NDIG
 BCS PINX2
 TAX
 JSR PIGETD
 STA PDIG
PINX2 INC PDIDX
 RTS

* ---- PIGETD: X = digit index -> A, through ZPT1 -
* NGETD reads operand B; the cell is operand A
* here, so this is its twin.  Ten lines is cheaper
* than a pointer swap the caller would have to
* remember to undo.
PIGETD STX PDX
 TXA
 LSR
 CLC
 ADC #NMSB
 TAY
 LDA (ZPT1),Y
 STA PDT
 LDA PDX
 AND #1
 BNE PIGD1
 LDA PDT
 LSR
 LSR
 LSR
 LSR
 RTS
PIGD1 LDA PDT
 AND #$0F
 RTS

* ---- PISCAN: count the digit positions ----------
* The first $, + or - is the character itself and
* holds no digit; every later one does.  That one
* rule covers $9,999.99 and $$,$$9.99 and ----9 and
* 9999- without a special case for any of them.
PISCAN LDA #0
 STA PINT
 STA PDEC
 STA PFIRST
 STA PSEEN
 LDA #1
 STA PIDX
PIS1 LDA PIDX
 CMP PLEN
 BEQ PIS2
 BCS PISD
PIS2 LDY PIDX
 LDA (ZPT2),Y
 STA PCH
 JSR PISCLS
 BCC PIS4
 LDA PSEEN
 BNE PIS3
 INC PINT
 JMP PIS4
PIS3 INC PDEC
PIS4 INC PIDX
 JMP PIS1
PISD RTS

* PISCLS: C=1 if PCH is a digit position
PISCLS LDA PCH
 CMP #$2E
 BNE PSL1
 LDA #1
 STA PSEEN
 CLC
 RTS
PSL1 CMP #$39
 BEQ PSLY
 CMP #$5A
 BEQ PSLY
 CMP #$2A
 BEQ PSLY
 CMP #$24
 BEQ PSL2
 CMP #$2B
 BEQ PSL2
 CMP #$2D
 BEQ PSL2
 CLC
 RTS
PSL2 LDA PFIRST
 BNE PSLY
 LDA #1
 STA PFIRST
 CLC
 RTS
PSLY SEC
 RTS

* ---- PISIGN / PIZERO: what the cell is ----------
PISIGN LDY #0
 LDA (ZPT1),Y
 AND #FNEG
 STA PSGN
 RTS

* A value is zero when all fourteen digits are, and
* BLANK WHEN ZERO needs to know before the first
* character is written.
PIZERO LDA #1
 STA PZERO
 LDY #NMSB
PIZ1 LDA (ZPT1),Y
 BEQ PIZ2
 LDA #0
 STA PZERO
 RTS
PIZ2 INY
 CPY #NCELL
 BCC PIZ1
 RTS

* ---- PIBLNK: blank the whole result -------------
PIBLNK LDX #0
PIB1 CPX PICLEN
 BCS PIBD
 LDA #$20
 STA PICBUF,X
 INX
 JMP PIB1
PIBD RTS

* ================= DE-EDITING ===================
* ---- PIDEED: a typed string -> a NUM8 cell ------
* in:  ZPT1 -> the string, length-prefixed
*      ZPT2 -> the destination cell
*      PICSCL = implied decimals of the cell
* out: PICERR = 1 if anything unusable was in it
*
* The picture is NOT consulted.  What a person
* types is not what the picture would have printed
* - they leave the commas out, or put a minus where
* the picture wanted CR - so this reads the
* intent instead: digits, one point, and any of the
* several ways to say negative.
PIDEED LDA #0
 STA PICERR
 STA PNI
 STA PNF
 STA PSGN
 STA PSEEN
 JSR PIDZRO
 LDY #0
 LDA (ZPT1),Y
 STA PLEN
 BEQ PIDPL
 LDA #1
 STA PIDX
PIDL LDA PIDX
 CMP PLEN
 BEQ PIDL2
 BCS PIDPL
PIDL2 LDY PIDX
 LDA (ZPT1),Y
 STA PCH
 JSR PIDCH
 INC PIDX
 JMP PIDL
* the digits are gathered; now place them
PIDPL JMP PIDPUT

* PIDCH: one typed character
PIDCH LDA PCH
 CMP #$30
 BCC PDC2
 CMP #$3A
 BCS PDC2
* a digit: integer or fraction depending on whether
* the point has gone by
 LDA PSEEN
 BNE PDC1
 LDA PCH
 SEC
 SBC #$30
 LDX PNI
 CPX #NDIG
 BCS PDCD
 STA PNBUF,X
 INC PNI
 RTS
PDC1 LDA PCH
 SEC
 SBC #$30
 LDX PNF
 CPX #NDIG
 BCS PDCD
 STA PFBUF,X
 INC PNF
 RTS
PDC2 CMP PICDPT
 BNE PDC3
 LDA #1
 STA PSEEN
 RTS
PDC3 CMP #$2D
 BNE PDC4
 LDA #FNEG
 STA PSGN
 RTS
PDC4 CMP #$43
 BEQ PDCN
 CMP #$44
 BEQ PDCN
 CMP #$28
 BNE PDC5
PDCN LDA #FNEG
 STA PSGN
 RTS
* spaces, commas, the currency sign, R, B and the
* closing bracket are decoration and are ignored;
* anything else is a typing error worth reporting
PDC5 CMP #$20
 BEQ PDCD
 CMP PICCOM
 BEQ PDCD
 CMP PICCUR
 BEQ PDCD
 CMP #$52
 BEQ PDCD
 CMP #$42
 BEQ PDCD
 CMP #$29
 BEQ PDCD
 CMP #$2B
 BEQ PDCD
 LDA #1
 STA PICERR
PDCD RTS

* PIDZRO: clear the destination cell
PIDZRO LDY #0
 LDA #0
PDZ1 STA (ZPT2),Y
 INY
 CPY #NCELL
 BCC PDZ1
 RTS

* PIDPUT: the gathered digits into the cell
* The units digit sits at 13 - PICSCL.  Integers
* are laid leftward from there, the fraction
* rightward, and anything that falls off either end
* is silently lost - which is exactly what COBOL
* says a MOVE does.
PIDPUT SEC
 LDA #NDIG-1
 SBC PICSCL
 STA PDIDX
 LDA #0
 STA PDX
* integers, least significant first, walking left
* until they run out or fall off the end of the
* cell
PIDP1 LDA PDX
 CMP PNI
 BCS PIDP2
 SEC
 LDA PNI
 SBC #1
 SEC
 SBC PDX
 TAY
 LDA PNBUF,Y
 STA PDV
 SEC
 LDA PDIDX
 SBC PDX
 BMI PIDP2
 TAX
 LDA PDV
 JSR NPUTD
 INC PDX
 JMP PIDP1
* the fraction, most significant first, walking
* right
PIDP2 LDA #0
 STA PDX
PIDP3 LDA PDX
 CMP PNF
 BCS PIDP4
 CLC
 LDA PDIDX
 ADC PDX
 CLC
 ADC #1
 CMP #NDIG
 BCS PIDP4
 TAX
 LDY PDX
 LDA PFBUF,Y
 STA PDV
 LDA PDV
 JSR NPUTD
 INC PDX
 JMP PIDP3
* The sign goes in last, and storing it as the
* whole flag byte is deliberate: it clears
* UNINITIALISED at the same time, which is exactly
* what has just stopped being true.
PIDP4 LDY #0
 LDA PSGN
 STA (ZPT2),Y
 RTS

* ================= VARIABLES ===================
* PICBUF and the two digit-gathering arrays are
* addresses in the data region - see EQUATES.
PLEN DFB 0
PIDX DFB 0
POUT DFB 0
PINT DFB 0
PDEC DFB 0
PSUP DFB 0
PSEEN DFB 0
PFCH DFB 0
PFPOS DFB 0
PFIRST DFB 0
PFILL DFB 0
PSGN DFB 0
PZERO DFB 0
PDIDX DFB 0
PDIG DFB 0
PCH DFB 0
PDX DFB 0
PDT DFB 0
PDV DFB 0
PNI DFB 0
PNF DFB 0
PTMP DS 2
