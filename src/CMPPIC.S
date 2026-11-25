* CMPPIC.S  PICTURE parsing  -  COMPILE slice 4
* PUT from COMPILE.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* A picture string in, a descriptor out: type,
* length, decimals and the signed flag.
*
* THE CLASSIFICATION IS THE WHOLE JOB.
* Six types, and which one an item gets is decided
* by what characters its picture contains rather
* than by anything the programmer says:
*
*   any of Z * $ + - , . / B 0 CR DB  ->  EDITED
*   otherwise any X or A              ->  ALPHA
*   otherwise any 9                   ->  NUMERIC
*
* and the order matters, because $9,999.99 has 9s in
* it and is not a numeric item - it is a picture a
* number is edited INTO.
*
* WHAT "LENGTH" MEANS IS DIFFERENT FOR EACH
*   numeric  ALWAYS EIGHT.  A NUM8 cell is eight
*            bytes whatever the picture says, so the
*            digit count decides the SCALE and
*            nothing else.  This is the one place
*            where the count is thrown away on
*            purpose.
*   alpha    one byte a character position
*   edited   one byte a PRINTED position, which
*            includes the commas, the point and the
*            currency sign - the mask is what will
*            be laid down, and PICTURE.S lays down
*            all of it
*
* An edited item also keeps its picture: EDTREF
* points into the literal pool, and VEDIT reads it
* there at MOVE time.

* ---- PICPARS: TOKBUF/TOKLEN -> the descriptor ---
PICPARS LDA #0
 STA PCNT
 STA PDEC
 STA PSEENV
 STA PISNUM
 STA PISALF
 STA PISEDT
 STA PSIGN
 STA PIX
PP1 LDX PIX
 CPX TOKLEN
 BCS PPDONE
 LDA TOKBUF,X
 STA PLAST
 JSR PPONE
 INC PIX
* a repeat count applies to the character just
* counted, so it is read after it and not before
 LDX PIX
 CPX TOKLEN
 BCS PP1
 LDA TOKBUF,X
 CMP #$28
 BNE PP1
 JSR PPREP
 JMP PP1

* ---- PPDONE: decide what it is ------------------
PPDONE LDA PISEDT
 BEQ PPD1
 LDA #TEDIT
 STA DTYP
 LDA PCNT
 STA DLENV
 LDA PDEC
 STA DDECV
 JMP PPEDT
PPD1 LDA PISALF
 BEQ PPD2
 LDA #TALPHA
 STA DTYP
 LDA PCNT
 STA DLENV
 LDA #0
 STA DDECV
 RTS
PPD2 LDA PISNUM
 BNE PPD3
* a picture with nothing countable in it is not a
* picture
 LDA #9
 STA CMPERR
 RTS
* EIGHT BYTES, always.  The digit count settled the
* scale on the way past - but DISPLAY needs it too:
* PIC 9(6) shows six digits, not the cell's
* fourteen.  So the INTEGER digit count, PCNT-PDEC,
* rides in the top four bits of the flags byte
* (bits 0-2 are signed/justified/blank-when-zero).
* Zero there means "not recorded", and VDEFP falls
* back to all fourteen.  Added 2026-11-07.
PPD3 LDA #TNUMB
 STA DTYP
 LDA #NCELL
 STA DLENV
 LDA PDEC
 STA DDECV
 LDA PSIGN
 BEQ PPD4
 LDA DFLGV
 ORA #1
 STA DFLGV
PPD4 SEC
 LDA PCNT
 SBC PDEC
 CMP #15
 BCC PPD5
 LDA #14
PPD5 ASL
 ASL
 ASL
 ASL
 ORA DFLGV
 STA DFLGV
 RTS

* ---- PPEDT: pool the picture for VEDIT ----------
* The mask itself goes in the literal pool and the
* descriptor points at it, which is why an edited
* MOVE needs no extra instruction: the interpreter
* finds the picture through the destination.
* The mask goes in EXPANDED: -(7)9.99 is pooled as
* --------9.99.  It went in as written, and the edit
* engine, which knows nothing of brackets, printed
* "(7)" (found 2026-11-11 by the SCREEN procedure).
* PPREP has already checked the brackets and counted
* the positions; this only writes them out.  39 is
* what LITBUF holds after its first byte.
PPEDT LDX #0
 LDY #0
PPE1 CPX TOKLEN
 BCS PPE2
 LDA TOKBUF,X
 CMP #$28
 BEQ PPEN
 STA PLAST
 JSR PPEPUT
 BCS PPEX
 INX
 JMP PPE1
* (n): n-1 more of the character before it
PPEN STZ PREPN
PPEN1 INX
 LDA TOKBUF,X
 CMP #$29
 BEQ PPEN2
 AND #$0F
 STA PRT
 LDA PREPN
 ASL
 ASL
 CLC
 ADC PREPN
 ASL
 CLC
 ADC PRT
 STA PREPN
 JMP PPEN1
PPEN2 INX
PPEN3 DEC PREPN
 BEQ PPE1
 LDA PLAST
 JSR PPEPUT
 BCS PPEX
 JMP PPEN3
PPE2 TYA
 STA LITN
 JSR EMLTXT
 BCS PPEX
 LDA EMLO
 STA DEDTV
 LDA EMLO+1
 STA DEDTV+1
PPEX RTS

* PPEPUT: A onto the pooled mask at Y.  C=1 and
* error 9 if it will not fit.
PPEPUT CPY #39
 BCS PPEPF
 STA LITBUF+1,Y
 INY
 CLC
 RTS
PPEPF LDA #9
 STA CMPERR
 SEC
 RTS

* ---- PPONE: count one picture character ---------
PPONE CMP #$39
 BEQ PPO9
 CMP #$58
 BEQ PPOX
 CMP #$41
 BEQ PPOX
 CMP #$53
 BEQ PPOS
 CMP #$56
 BEQ PPOV
 CMP #$50
 BEQ PPOP
* CR and DB are two printed positions, and the
* second letter of each is consumed here so the
* loop does not count it again
 CMP #$43
 BEQ PPOCR
 CMP #$44
 BEQ PPOCR
* everything else that is legal in a picture is an
* editing character
 JSR PPEDCH
 BCC PPOBAD
 LDA #1
 STA PISEDT
 JSR PPINC
 RTS
PPO9 LDA #1
 STA PISNUM
 JSR PPINC
 LDA PSEENV
 BEQ PPO9X
 INC PDEC
PPO9X RTS
PPOX LDA #1
 STA PISALF
 JSR PPINC
 RTS
PPOS LDA #1
 STA PSIGN
 RTS
PPOV LDA #1
 STA PSEENV
 RTS
* P is a scaling position: it moves the decimal
* point without occupying a byte, and in a NUM8
* cell it costs nothing at all.
PPOP LDA #1
 STA PISNUM
 RTS
PPOCR LDA #1
 STA PISEDT
 JSR PPINC
 JSR PPINC
 INC PIX
 RTS
PPOBAD LDA #9
 STA CMPERR
 RTS

* ---- PPEDCH: C=1 if A may edit ------------------
PPEDCH LDX #0
PPEC1 LDA EDCHRS,X
 BEQ PPECNO
 CMP PLAST
 BEQ PPECY
 INX
 JMP PPEC1
PPECY SEC
 RTS
PPECNO CLC
 RTS
* Z * $ + - , . / B 0
EDCHRS DFB $5A,$2A,$24,$2B,$2D,$2C,$2E,$2F,$42,$30,$00

* ---- PPREP: (n) repeats the last character ------
* The character has been counted once already, so
* the repeat adds n-1 more of it.  X(13) is thirteen
* positions and not fourteen, and getting that wrong
* would make every alphanumeric item one byte too
* long - which nothing would catch until two fields
* overlapped in a record.
PPREP INC PIX
 LDA #0
 STA PREPN
PPR1 LDX PIX
 CPX TOKLEN
 BCS PPRBAD
 LDA TOKBUF,X
 CMP #$29
 BEQ PPR3
 JSR PPDIG
 BCC PPRBAD
 LDA PREPN
 CMP #26
 BCS PPRBIG
 ASL
 STA PRT
 ASL
 ASL
 CLC
 ADC PRT
 STA PREPN
 LDX PIX
 LDA TOKBUF,X
 AND #$0F
 CLC
 ADC PREPN
 BCS PPRBIG
 STA PREPN
 INC PIX
 JMP PPR1
PPR3 INC PIX
 LDA PREPN
 BEQ PPRX
 DEC PREPN
 BEQ PPRX
PPR4 LDA PLAST
 JSR PPONE
 DEC PREPN
 BNE PPR4
PPRX RTS
PPRBAD LDA #9
 STA CMPERR
 RTS
* ---- PPINC: one more position, and no more than
* 255 of them.  The count is a byte, and X(300) was
* an X(44) without a word (FIXLIST A10).
* The scan stops too: PIX goes to the end, or the
* digits still to come were read as picture
* characters and error 9 replaced this one.
PPINC INC PCNT
 BNE PPIX
PPRBIG LDA #33
 STA CMPERR
 LDA TOKLEN
 STA PIX
PPIX RTS

* PPDIG and DDVSCL moved to CMPCOM.S on
* 2026-08-16: PDONUM needs DDVSCL and CMPPIC is
* pass one only.  This file still CALLS PPDIG.
