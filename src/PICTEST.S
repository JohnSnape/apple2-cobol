* PICTEST.S  a harness for the edit engine
* A STANDALONE program, not a library module.
* The second of the two PCODE.md 5 asks for, and
* the one that decides whether a person can read
* what this system prints.  BCDTEST proves the
* arithmetic; this proves the only thing anybody
* outside the program ever actually sees.
*
* HOW TO RUN IT
*   BLOAD COBOL.LIB,A$3000
*   BRUN PICTEST
* ORGs at $8000 and ends with an RTS, so under
* BASIC.SYSTEM it comes back to the prompt.
*
* WHAT IT PROVES
*   1  a floating $ lands immediately left of the
*      first digit that prints - the BACK-FILL, and
*      PICTURE.S says in its own header that this
*      is the one idea worth the page.  It is also
*      the part most likely to be off by one place,
*      so the same picture is run against a value
*      that fills it, one that leaves most of it
*      suppressed, and one that is zero
*   2  suppression that runs INTO a comma: ZZZ,ZZ9
*      against 42 must not print a comma with
*      nothing on its left
*   3  CR and DB appear when negative and become
*      two spaces when not
*   4  a value too wide for its picture - 9(5)
*      against six digits - truncates on the LEFT,
*      which is what COBOL says and what surprises
*      people
*   5  * protection, BLANK WHEN ZERO, the fixed and
*      floating and trailing forms of + and -
*   6  PIDEED, the way back: what a person types
*      into a field turns into the same cell the
*      editor came from
*
* Nothing here reports PASS.  Every case prints
* what it got between brackets, beside what it
* should have got, and the operator reads the
* screen.  Brackets because trailing spaces are
* half of what these pictures do and an unbracketed
* line cannot show them.

 XC
 PUT EQUATES
 PUT EQUATES2

 ORG $8000
 DSK /COBOL/OBJ/PICTEST

* A case: one length-prefixed picture, one sign, 14
* digits of cell, one scale, one flag byte, then a
* length-prefixed expected result.  Everything is
* fixed width so the table can be indexed; the two
* lengths are still written down because that is
* what the routines take.
PICW EQU 16
EXPW EQU 20
CSIZE EQU 53
NCASE EQU 18
* de-edit cases: a length-prefixed typed string, a
* scale, then the sign and 14 digits it should make
DEDW EQU 16
DSIZE EQU 32
NDED EQU 8
POS EQU $00
NEG EQU $80

* ---- zone P: this pointer must survive a JSR ----
* Zone S is caller-saved and PIEDIT is entitled to
* destroy all of it.  Zone P is the one region the
* Golden Rule keeps every service out of.
TPTR EQU ZPDRV

START JSR INIT80
 JSR CONINIT
 JSR CONCLR
 JSR PICINIT
 LDA #<MTITLE
 LDX #>MTITLE
 JSR TMSG
 JSR CONCR
 JSR CONCR
 JSR TEDIT
 JSR TWAIT
 JSR TDEED
 JSR CONCR
 LDA #<MDONE
 LDX #>MDONE
 JSR TMSG
 JSR CONCR
 RTS

* ================= EDITING =====================
TEDIT LDA #<MHEDT
 LDX #>MHEDT
 JSR TMSG
 JSR CONCR
 LDA #0
 STA TCASE
TE1 LDA TCASE
 CMP #NCASE
 BCC TE2
 RTS
* two lines a case, so it stops twice going down
TE2 CMP #6
 BEQ TE15
 CMP #12
 BNE TE3
TE15 JSR TWAIT
TE3 LDA #<CTAB
 LDX #>CTAB
 LDY #CSIZE
 JSR TSEEK
 JSR TELOAD
 JSR TERUN
 JSR TESHOW
 INC TCASE
 JMP TE1

* ---- TELOAD: build the cell from the entry ------
* Entry: picture 16, sign 1, digits 14, scale 1,
* flags 1, expected 20.
TELOAD LDY #PICW
 LDA (TPTR),Y
 STA TSGN
 LDY #PICW+1
 LDX #0
TEL1 LDA (TPTR),Y
 STA ASCBUF,X
 INY
 INX
 CPX #NDIG
 BCC TEL1
 LDA #NDIG
 STA ALEN
 LDA #<ASCBUF
 STA ZPT1
 LDA #>ASCBUF
 STA ZPT1+1
 LDA #<CELL
 STA ZPT2
 LDA #>CELL
 STA ZPT2+1
 JSR BCDPACK
* Fourteen digits into a fourteen-digit cell cannot
* overflow, so BPACK has left the flag byte zero
* and the sign can simply be stored.
 LDA TSGN
 STA CELL
 LDY #PICW+15
 LDA (TPTR),Y
 STA PICSCL
 LDY #PICW+16
 LDA (TPTR),Y
 STA PICFLG
 RTS

* ---- TERUN: ZPT1 -> the cell, ZPT2 -> the picture
* The picture is copied out of the entry rather
* than pointed at, because ZPT2 has to be a pointer
* the library may follow and TPTR must not move.
TERUN LDY #0
 LDX #0
TER1 LDA (TPTR),Y
 STA PICSTR,X
 INY
 INX
 CPX #PICW
 BCC TER1
 LDA #<CELL
 STA ZPT1
 LDA #>CELL
 STA ZPT1+1
 LDA #<PICSTR
 STA ZPT2
 LDA #>PICSTR
 STA ZPT2+1
 JMP PICEDIT

* ---- TESHOW: two lines for one case -------------
TESHOW JSR TNUM
 LDA #<PICSTR
 LDX #>PICSTR
 JSR TMSG
 LDA #<MSP
 LDX #>MSP
 JSR TMSG
 LDA TSGN
 JSR TSIGN
 LDY #PICW+1
 LDX #NDIG
TES1 LDA (TPTR),Y
 JSR CONPUTC
 INY
 DEX
 BNE TES1
 LDA #<MSCL
 LDX #>MSCL
 JSR TMSG
 LDA PICSCL
 JSR THEX
 JSR CONCR
 LDA #<MGOT
 LDX #>MGOT
 JSR TMSG
 LDA #$5B
 JSR CONPUTC
 LDX #0
TES2 CPX PICLEN
 BCS TES3
 LDA PICBUF,X
 JSR CONPUTC
 INX
 JMP TES2
TES3 LDA #$5D
 JSR CONPUTC
 LDA #<MWANT
 LDX #>MWANT
 JSR TMSG
 LDA #$5B
 JSR CONPUTC
 LDY #PICW+17
 LDA (TPTR),Y
 STA TCNT
 BEQ TES5
 INY
TES4 LDA (TPTR),Y
 JSR CONPUTC
 INY
 DEC TCNT
 BNE TES4
TES5 LDA #$5D
 JSR CONPUTC
 JMP CONCR

* ================= DE-EDITING ==================
* The way back.  A person types 1,234.50- into a
* field and the record has to end up holding the
* same cell an edit of -123450 with scale 2 came
* from - which is the only test that says the two
* halves of the engine agree with each other.
TDEED JSR CONCR
 LDA #<MHDED
 LDX #>MHDED
 JSR TMSG
 JSR CONCR
 LDA #0
 STA TCASE
TD1 LDA TCASE
 CMP #NDED
 BCC TD2
 RTS
TD2 LDA #<DTAB
 LDX #>DTAB
 LDY #DSIZE
 JSR TSEEK
 LDY #0
 LDX #0
TD3 LDA (TPTR),Y
 STA PICSTR,X
 INY
 INX
 CPX #DEDW
 BCC TD3
 LDY #DEDW
 LDA (TPTR),Y
 STA PICSCL
 LDA #<PICSTR
 STA ZPT1
 LDA #>PICSTR
 STA ZPT1+1
 LDA #<CELL
 STA ZPT2
 LDA #>CELL
 STA ZPT2+1
 LDA #0
 STA PICERR
 JSR PICDEED
 JSR TNUM
 LDA #$5B
 JSR CONPUTC
 LDX #1
TD4 CPX PICSTR
 BEQ TD5
 BCS TD5
 LDA PICSTR,X
 JSR CONPUTC
 INX
 JMP TD4
TD5 LDA PICSTR,X
 JSR CONPUTC
 LDA #$5D
 JSR CONPUTC
 LDA #<MSCL
 LDX #>MSCL
 JSR TMSG
 LDA PICSCL
 JSR THEX
 LDA #<MERRC
 LDX #>MERRC
 JSR TMSG
 LDA PICERR
 JSR THEX
 JSR CONCR
 LDA #<MGOT
 LDX #>MGOT
 JSR TMSG
 JSR TCELL
 LDA #<MWANT
 LDX #>MWANT
 JSR TMSG
 LDY #DEDW+1
 LDA (TPTR),Y
 JSR TSIGN
 INY
TD6 LDA (TPTR),Y
 JSR CONPUTC
 INY
 CPY #DSIZE
 BCC TD6
 JSR CONCR
 INC TCASE
 JMP TD1

* ================= HELPERS =====================
* ---- TSEEK: A/X = table, Y = entry size --------
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

* ---- TCELL: CELL as sign + 14 digits -----------
TCELL LDA CELL
 JSR TSIGN
 LDA #NDIG
 STA ALEN
 LDA #<ASCBUF
 STA ZPT1
 LDA #>ASCBUF
 STA ZPT1+1
 LDA #<CELL
 STA ZPT2
 LDA #>CELL
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
* picture (1 length + 15), sign, 14 digits, scale,
* flags, expected (1 length + 19).
* The pictures are padded to fifteen and the
* expected results to nineteen; the length byte in
* front of each is what the routines read, so the
* padding is never looked at.
*
* CHECKED 2026-11-07, the first time this ran: nine
* length bytes were one out (the $$,$$9.99CR five,
* both DBs, +9999.99, ZZZZ9.99-) and two wants had a
* stray leading space.  The edit engine was right in
* every case; the table was wrong.  Count the
* characters, not the padding.
CTAB
* --- the floating dollar, three ways ---
* Full: every position used, the $ against the
* left edge because there is nowhere further left
* for it to go.
 DFB $0B
 ASC '$$,$$9.99CR    '
 DFB POS
 ASC '00000000123456'
 DFB $02
 DFB $00
 DFB $0B
 ASC '$1,234.56          '
* Mostly suppressed: this is the back-fill.  The $
* has to end up one place left of the 4, not at the
* left edge and not on top of it.
 DFB $0B
 ASC '$$,$$9.99CR    '
 DFB POS
 ASC '00000000000400'
 DFB $02
 DFB $00
 DFB $0B
 ASC '    $4.00          '
* Negative: the same picture, and CR appears.
 DFB $0B
 ASC '$$,$$9.99CR    '
 DFB NEG
 ASC '00000000123456'
 DFB $02
 DFB $00
 DFB $0B
 ASC '$1,234.56CR        '
* Zero: still a number, so it still prints.
 DFB $0B
 ASC '$$,$$9.99CR    '
 DFB POS
 ASC '00000000000000'
 DFB $02
 DFB $00
 DFB $0B
 ASC '    $0.00          '
* Zero with BLANK WHEN ZERO: the whole field goes.
 DFB $0B
 ASC '$$,$$9.99CR    '
 DFB POS
 ASC '00000000000000'
 DFB $02
 DFB $01
 DFB $0B
 ASC '                   '
* --- suppression running into a comma ---
* 42.00 in ZZZ,ZZ9.99.  The comma is inside the
* suppressed run and must not print with nothing
* to its left.
 DFB $0A
 ASC 'ZZZ,ZZ9.99     '
 DFB POS
 ASC '00000000004200'
 DFB $02
 DFB $00
 DFB $0A
 ASC '     42.00         '
* Now a value big enough to push past the comma,
* so the comma DOES print.
 DFB $0A
 ASC 'ZZZ,ZZ9.99     '
 DFB POS
 ASC '00000012345678'
 DFB $02
 DFB $00
 DFB $0A
 ASC '123,456.78         '
* Zero in ZZZ,ZZ9.99: the 9 is not suppressible, so
* one zero survives.
 DFB $0A
 ASC 'ZZZ,ZZ9.99     '
 DFB POS
 ASC '00000000000000'
 DFB $02
 DFB $00
 DFB $0A
 ASC '      0.00         '
* --- too wide for the picture ---
* Six digits into 9(5).  COBOL truncates on the
* LEFT, which is the answer that surprises people
* and the one the standard gives.
 DFB $05
 ASC '99999          '
 DFB POS
 ASC '00000000123456'
 DFB $00
 DFB $00
 DFB $05
 ASC '23456              '
* And with a scale, so the truncation and the point
* have to be got right together.
 DFB $08
 ASC '99999.99       '
 DFB POS
 ASC '00000012345678'
 DFB $02
 DFB $00
 DFB $08
 ASC '23456.78           '
* --- asterisk protection ---
 DFB $0A
 ASC '***,**9.99     '
 DFB POS
 ASC '00000000004200'
 DFB $02
 DFB $00
 DFB $0A
 ASC '*****42.00         '
 DFB $0A
 ASC '***,**9.99     '
 DFB POS
 ASC '00000012345678'
 DFB $02
 DFB $00
 DFB $0A
 ASC '123,456.78         '
* --- DB, which is DEBIT and prints on a negative
* the same way CR does ---
 DFB $0C
 ASC 'ZZZ,ZZ9.99DB   '
 DFB NEG
 ASC '00000000004200'
 DFB $02
 DFB $00
 DFB $0C
 ASC '     42.00DB       '
 DFB $0C
 ASC 'ZZZ,ZZ9.99DB   '
 DFB POS
 ASC '00000000004200'
 DFB $02
 DFB $00
 DFB $0C
 ASC '     42.00         '
* --- the sign characters, fixed and floating ---
* A leading + is fixed when it stands alone.
 DFB $08
 ASC '+9999.99       '
 DFB NEG
 ASC '00000000004200'
 DFB $02
 DFB $00
 DFB $08
 ASC '-0042.00           '
* A run of - floats, and a positive value leaves a
* space where the sign would have been.
 DFB $08
 ASC '----9.99       '
 DFB POS
 ASC '00000000004200'
 DFB $02
 DFB $00
 DFB $08
 ASC '   42.00           '
 DFB $08
 ASC '----9.99       '
 DFB NEG
 ASC '00000000004200'
 DFB $02
 DFB $00
 DFB $08
 ASC '  -42.00           '
* A trailing sign, which is where a minus goes on a
* form somebody has to read down a column of.
 DFB $09
 ASC 'ZZZZ9.99-      '
 DFB NEG
 ASC '00000000004200'
 DFB $02
 DFB $00
 DFB $09
 ASC '   42.00-          '

* typed string (1 length + 15), scale, sign, 14
* digits expected
DTAB
 DFB $04
 ASC '1234           '
 DFB $00
 DFB POS
 ASC '00000000001234'
* A typed decimal point places the digits against
* the field's scale, not against where the point
* happens to be in what was typed.
 DFB $07
 ASC '1234.56        '
 DFB $02
 DFB POS
 ASC '00000000123456'
* Fewer decimals typed than the field has: the rest
* are zeros, which is what a person means by 12.5
* in a field of two places.
 DFB $04
 ASC '12.5           '
 DFB $02
 DFB POS
 ASC '00000000001250'
* More typed than the field has: the extra is
* dropped, not rounded - DEEDIT is a reader, and a
* reader that quietly rounded would disagree with
* the ROUNDED clause that exists to ask for it.
 DFB $07
 ASC '12.5678        '
 DFB $02
 DFB POS
 ASC '00000000001256'
* The commas a person types are theirs, not the
* picture's, and come out again.
 DFB $08
 ASC '1,234.56       '
 DFB $02
 DFB POS
 ASC '00000000123456'
* Three ways to say negative, all of which somebody
* will type into the same field.
 DFB $08
 ASC '-1234.56       '
 DFB $02
 DFB NEG
 ASC '00000000123456'
 DFB $08
 ASC '1234.56-       '
 DFB $02
 DFB NEG
 ASC '00000000123456'
* And something unusable, which must set PICERR
* rather than make a number up.
 DFB $06
 ASC '12X.34         '
 DFB $02
 DFB POS
 ASC '00000000001234'

* ---- the fixed strings ----
MTITLE DFB 25
 ASC 'PICTEST - the edit engine'
MHEDT DFB 24
 ASC 'PICTURE -> what is shown'
MHDED DFB 24
 ASC 'What is typed -> PICTURE'
MSP DFB 2
 ASC '  '
MSCL DFB 4
 ASC '  s='
MERRC DFB 3
 ASC ' e='
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
TSGN DFB 0
TCNT DFB 0
TWRK DFB 0
CELL DS 8
ASCBUF DS 16
PICSTR DS 20
