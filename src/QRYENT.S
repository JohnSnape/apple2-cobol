* QRYENT.S  QUERY entry, screen and key dispatch
* PUT from QUERY.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* THE WHOLE QUERY FITS ON ONE SCREEN, so there is no
* window and no scrolling - eight conditions and
* four sort keys are twelve rows and the screen has
* twenty.  EDIT's ring exists for documents that do
* not fit and REPORT's scroll exists for a page that
* does not fit; neither applies here, and inventing
* one anyway would be work that only made the tool
* slower to read.

* ---- QSTART: the overlay entry -----------------
QSTART STZ QQUIT
 STZ QSEL
 JSR QNEW
QM1 JSR QDRAW
 JSR GETCHORD
 JSR QKEY
 LDA QQUIT
 BEQ QM1
 RTS

* ---- QKEY: one keystroke -----------------------
* Both Apple keys down is not Open-Apple - see
* KEYS.md 4.  QUERY defines no OA+SA chord, so it
* does nothing at all.
QKEY LDA CHMOD
 AND #$C0
 CMP #$C0
 BNE QK0
 RTS
QK0 LDA CHMOD
 BMI QKOA
 LDA CHKEY
 CMP #$1B
 BNE QK1
 INC QQUIT
 RTS
QK1 CMP #$0B
 BNE QK2
 JMP QUPSEL
QK2 CMP #$0A
 BNE QK3
 JMP QDNSEL
QK3 RTS

* ---- the Open-Apple commands -------------------
* AND #$DF folds a letter to upper case without
* touching the arrows, whose codes have no bit 5.
* OA-D deletes the selected condition, which by the
* rule in KEYS.md 9 ought to be SA-D - it is OA-D
* here to match FORMAT and REPORT, and when that
* question is settled all three change together.
QKOA LDA CHKEY
 AND #$DF
 CMP #$41
 BNE QKA1
 JMP QADDC
QKA1 CMP #$44
 BNE QKA2
 JMP QDELC
QKA2 CMP #$4B
 BNE QKA3
 JMP QADDK
QKA3 CMP #$52
 BNE QKA4
 JMP QDELK
QKA4 CMP #$49
 BNE QKA5
 JMP QOPEND
QKA5 CMP #$4E
 BNE QKA6
 JMP QNEW
QKA6 CMP #$4F
 BNE QKA7
 JMP QOPENQ
QKA7 CMP #$53
 BNE QKA8
 JMP QSAVEQ
QKA8 RTS

* ---- DOPREV: PROMPT calls this for SA-C ---------
* FORMAT previews its generated COBOL here and
* REPORT will preview its page.  A query has nothing
* to look at that the screen is not already showing,
* so this is an RTS and says why.
DOPREV RTS

* ---- QUPSEL / QDNSEL: move the selection --------
* The selection walks the conditions and then the
* sort keys as one list, because that is how it
* looks on the screen and a cursor that skipped a
* section would be lying about the layout.
QUPSEL LDA QSEL
 BEQ QUPX
 DEC QSEL
QUPX RTS
QDNSEL JSR QNROWS
 STA QT
 LDA QSEL
 CLC
 ADC #1
 CMP QT
 BCS QDNX
 STA QSEL
QDNX RTS

* ---- QNROWS: how many selectable rows? ----------
QNROWS LDA QNCOND
 CLC
 ADC QNKEY
 RTS

* ================= DRAWING =====================
QDRAW JSR CLRSCR
 STZ SCRROW
 LDA #1
 STA SCRCOL
 STZ SCRATR
 LDA #<QSHDR
 STA STRPTR
 LDA #>QSHDR
 STA STRPTR+1
 JSR PUTS
* the dictionary's name on the right, or a warning
* that there is none - which is the first thing that
* stops anything else working
 LDA QHASD
 BNE QD1
 LDA #<QSNOD
 STA STRPTR
 LDA #>QSNOD
 STA STRPTR+1
 JMP QD2
QD1 LDA #<QDNAME
 STA STRPTR
 LDA #>QDNAME
 STA STRPTR+1
QD2 JSR NFPUTR
* ---- the conditions ----------------------------
 LDA #2
 STA SCRROW
 LDA #1
 STA SCRCOL
 STZ SCRATR
 LDA #<QSCND
 STA STRPTR
 LDA #>QSCND
 STA STRPTR+1
 JSR PUTS
 STZ QIX
QDRA LDA QIX
 CMP QNCOND
 BCC QDRC
 JMP QDRB
QDRC JSR QDROW
 INC QIX
 JMP QDRA
* ---- the sort keys -----------------------------
QDRB LDA #12
 STA SCRROW
 LDA #1
 STA SCRCOL
 STZ SCRATR
 LDA #<QSKEY
 STA STRPTR
 LDA #>QSKEY
 STA STRPTR+1
 JSR PUTS
 STZ QJX
QDK1 LDA QJX
 CMP QNKEY
 BCS QDK2
 JSR QKROW
 INC QJX
 JMP QDK1
QDK2 JMP QBAR

* ---- QDROW: draw condition QIX ------------------
* The selected row is drawn INVERSE, which is the
* system's one rule about attributes turned to a new
* use: inverse means "this is the one you are
* typing at", and here the whole row is.
QDROW LDA QIX
 CLC
 ADC #3
 STA SCRROW
 LDA #1
 STA SCRCOL
 LDA QIX
 CMP QSEL
 BNE QDR1
 LDA #1
 BNE QDR2
QDR1 LDA #0
QDR2 STA SCRATR
* the connector, on every row but the first
 LDA QIX
 BEQ QDR4
 LDX QIX
 LDA QCCON,X
 BEQ QDR3
 LDA #<QSOR
 STA STRPTR
 LDA #>QSOR
 STA STRPTR+1
 JMP QDR5
QDR3 LDA #<QSAND
 STA STRPTR
 LDA #>QSAND
 STA STRPTR+1
 JMP QDR5
QDR4 LDA #<QSBLK
 STA STRPTR
 LDA #>QSBLK
 STA STRPTR+1
QDR5 JSR PUTS
* the field's name, out of the dictionary
 LDX QIX
 LDA QCFLD,X
 JSR QFNAME
 JSR PUTS
* the relation
 LDX QIX
 LDA QCREL,X
* ONE shift: QRELTB is DA entries, two bytes each.
* Two shifts read every relation one entry late and
* > or >= past the end of the table (2026-11-07).
 ASL
 TAX
 LDA QRELTB,X
 STA STRPTR
 LDA QRELTB+1,X
 STA STRPTR+1
 JSR PUTS
* and what it is being compared with
 JMP QDTXT

* ---- QDTXT: condition QIX's literal -------------
QDTXT LDA QIX
 JSR QTXPTR
 LDX QIX
 LDA QCLEN,X
 STA QT
 STZ QT2
QDTA LDA QT2
 CMP QT
 BCC QDTC
 RTS
QDTC LDY QT2
 LDA (ZPT2),Y
 JSR CONV
 JSR PUTC
 INC QT2
 JMP QDTA
QDTB RTS

* ---- QKROW: draw sort key QJX -------------------
QKROW LDA QJX
 CLC
 ADC #13
 STA SCRROW
 LDA #1
 STA SCRCOL
 LDA QJX
 CLC
 ADC QNCOND
 CMP QSEL
 BNE QKR1
 LDA #1
 BNE QKR2
QKR1 LDA #0
QKR2 STA SCRATR
 LDX QJX
 LDA QKFLD,X
 JSR QFNAME
 JSR PUTS
 LDX QJX
 LDA QKDIR,X
 BEQ QKR3
 LDA #<QSDESC
 STA STRPTR
 LDA #>QSDESC
 STA STRPTR+1
 JMP QKR4
QKR3 LDA #<QSASC
 STA STRPTR
 LDA #>QSASC
 STA STRPTR+1
QKR4 JMP PUTS

* ---- QBAR: the command bar ----------------------
QBAR LDA #22
 STA SCRROW
 LDA #1
 STA SCRCOL
 STZ SCRATR
 LDA #<QSBAR1
 STA STRPTR
 LDA #>QSBAR1
 STA STRPTR+1
 JSR PUTS
 LDA #23
 STA SCRROW
 LDA #1
 STA SCRCOL
 LDA #<QSBAR2
 STA STRPTR
 LDA #>QSBAR2
 STA STRPTR+1
 JMP PUTS

* ================= THE DICTIONARY ==============
* ---- QFNAME: field A's name -> STRPTR -----------
* out: STRPTR points at a length-prefixed name
* The ten bytes at the front of a field descriptor
* are its COBOL data name, and DICTIONARY.md calls
* them the format's one piece of luck: they were
* reserved as ten zeros before anybody knew what for.
* This is one of the things they turned out to be
* for.
QFNAME STA QT
 JSR QDESC
 LDY #0
 LDX #0
QFN1 LDA (ZPFLD),Y
 STA QNBUF+1,X
 INY
 INX
 CPX #10
 BCC QFN1
 LDA #10
 STA QNBUF
 LDA #<QNBUF
 STA STRPTR
 LDA #>QNBUF
 STA STRPTR+1
 RTS

* ---- QDESC: field QT's descriptor -> ZPFLD ------
* Sixteen bits, because a descriptor is 24 bytes and
* FORMAT allows fifteen fields: 11 x 24 is 264 and
* eight bits stopped being enough four fields ago.
QDESC LDA QT
 STA QT2
 LDA #0
 STA QDT+1
 LDA QT2
 ASL
 ROL QDT+1
 STA QDT
 CLC
 LDA QDT
 ADC QT2
 STA QDT
 LDA QDT+1
 ADC #0
 STA QDT+1
 ASL QDT
 ROL QDT+1
 ASL QDT
 ROL QDT+1
 ASL QDT
 ROL QDT+1
 LDA #<DCTBUF
 STA ZPDICT
 LDA #>DCTBUF
 STA ZPDICT+1
 LDY #12
 LDA (ZPDICT),Y
 CLC
 ADC QDT
 STA ZPFLD
 INY
 LDA (ZPDICT),Y
 ADC QDT+1
 STA ZPFLD+1
 CLC
 LDA ZPFLD
 ADC ZPDICT
 STA ZPFLD
 LDA ZPFLD+1
 ADC ZPDICT+1
 STA ZPFLD+1
 RTS

* ---- QTXPTR: condition A's literal -> ZPT2 ------
QTXPTR STA QDT
 LDA #0
 STA QDT+1
 ASL QDT
 ROL QDT+1
 ASL QDT
 ROL QDT+1
 CLC
 LDA QDT
 ADC QDT
 STA QDT2
 LDA QDT+1
 ADC QDT+1
 STA QDT2+1
 CLC
 LDA QDT
 ADC QDT2
 STA QDT
 LDA QDT+1
 ADC QDT2+1
 STA QDT+1
 CLC
 LDA #<QCTXT
 ADC QDT
 STA ZPT2
 LDA #>QCTXT
 ADC QDT+1
 STA ZPT2+1
 RTS

QDT DS 2
QDT2 DS 2
QNBUF DS 12
