* RPTADD.S  REPORT add and delete an entry
* PUT from REPORT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* REPORT resolve against each other in pass two.
*
* ================= SLICE 2 =================
* OA-A asks Line, Column, Kind and then whatever
* that kind needs; OA-D takes an entry away again.
*
* FOUR KINDS, NOT TWO.  The design said slice 2
* would do literals and rules, "the two kinds that
* need no dictionary".  That was a miscount: the
* page number and the date need one no more than a
* rule does.  All four are here, so a page heading
* with a title, a rule under it, a page number and
* a date can be laid out before FORMAT has ever
* been opened.  FIELD and TOTAL wait for slice 3,
* because those really do need a dictionary to
* name.
*
* ENTRIES ARE KEPT IN PRINTING ORDER - by line,
* then by column - rather than in the order they
* were typed.  FORMAT keeps its fields in creation
* order and REPORT.md §5 already promised this
* file would not, so the insert finds its place
* and opens a gap.  It costs one more table walk
* per add and it is what lets the emitter build a
* line's group item in one pass, with the FILLER
* gaps falling out of the differences between
* neighbouring columns.  Sorting at export time
* instead would need somewhere to sort into.

* ---- RPADD: OA-A, place a new entry ------------
RPADD LDA HECNT
 CMP #MAXENT
 BCC RPA0
 JMP RPAFUL
RPA0 JSR BLNKTXT
 JSR BLNKPIC
 JSR ASKLINE
 LDA AKRES
 BEQ RPA1
 JMP RPADN
RPA1 JSR ASKCOL
 LDA AKRES
 BEQ RPA2
 JMP RPADN
RPA2 JSR ASKKIND
 LDA AKRES
 BEQ RPA3
 JMP RPADN
RPA3 JSR ASKREST
 LDA AKRES
 BEQ RPA4
 JMP RPADN
RPA4 JSR ADDENT
RPADN JMP CLRLINE
RPAFUL LDA #<MFULL
 STA STRPTR
 LDA #>MFULL
 STA STRPTR+1
 JSR SHOWERR
 JMP RPADN

* ================= THE QUESTIONS ================
* Every ASK routine answers in AKRES: 0 it was
* answered, 1 abandon the whole chain.  ESC gives
* 1, and so does an Open-Apple command typed at a
* prompt - the command is dropped rather than
* dispatched, because every REPORT command is one
* keystroke from the page anyway and re-entering
* the chain from inside itself is not worth the
* stack it would cost.

* ---- ASKLINE: Line? 1..pagelen -> NLINE --------
* Asked 1-based, stored 0-based.  One DEC, in one
* place, is the whole of the conversion.
ASKLINE LDA #<MLINEQ
 STA STRPTR
 LDA #>MLINEQ
 STA STRPTR+1
 JSR LINEIN
 LDA LIRES
 BNE ALNO
 LDA LLEN
 BEQ ALNO
 JSR ATOI
 STA NLINE
 BEQ ALNO
 CMP HPLEN
 BEQ ALOK
 BCS ALNO
ALOK DEC NLINE
 LDA #0
 STA AKRES
 RTS
ALNO LDA #1
 STA AKRES
 RTS

* ---- ASKCOL: Column? 1..80 -> NCOL -------------
ASKCOL LDA #<MCOLQ
 STA STRPTR
 LDA #>MCOLQ
 STA STRPTR+1
 JSR LINEIN
 LDA LIRES
 BNE ACNO
 LDA LLEN
 BEQ ACNO
 JSR ATOI
 STA NCOL
 BEQ ACNO
 CMP #81
 BCS ACNO
 DEC NCOL
 LDA #0
 STA AKRES
 RTS
ACNO LDA #1
 STA AKRES
 RTS

* ---- ASKKIND: one key -> NKIND -----------------
* L literal, R rule, P page number, D date.  A key
* that is none of them is ignored rather than
* rejected: there is nothing to correct.
ASKKIND JSR PROMPT23
 LDA #<MKIND
 STA STRPTR
 LDA #>MKIND
 STA STRPTR+1
 JSR PUTS
AKK1 JSR GETCHORD
 LDA CHKEY
 CMP #$1B
 BEQ AKNO
 AND #$DF
 CMP #$4C
 BEQ AKKL
 CMP #$52
 BEQ AKKR
 CMP #$50
 BEQ AKKP
 CMP #$44
 BEQ AKKD
 CMP #$46
 BEQ AKKF
 CMP #$54
 BEQ AKKT
 JMP AKK1
* F and T are picked from the dictionary
AKKF LDA #KFLD
 JMP AKKDC
AKKT LDA #KTOT
AKKDC STA NKIND
 LDA RDCTOK
 BNE AKKOK
 LDA #<MNEEDD
 STA STRPTR
 LDA #>MNEEDD
 STA STRPTR+1
 JSR SHOWERR
 JMP AKNO
AKKOK LDA #0
 STA AKRES
 RTS
AKKL LDA #KLIT
 JMP AKKSET
AKKR LDA #KRULE
 JMP AKKSET
AKKP LDA #KPAGE
 JMP AKKSET
AKKD LDA #KDATE
AKKSET STA NKIND
 LDA #0
 STA AKRES
 RTS
AKNO LDA #1
 STA AKRES
 RTS

* ---- ASKREST: whatever this kind still needs ---
ASKREST LDA NKIND
 CMP #KLIT
 BNE ASR1
 JMP ASKTEXT
ASR1 CMP #KRULE
 BNE ASR2
 JMP ASKRULE
ASR2 CMP #KPAGE
 BNE ASR2A
 JMP ASKPICT
ASR2A CMP #KDATE
 BEQ ASR3
 JMP ASKFLD
* A date asks nothing.  Eight columns of MM/DD/YY,
* which the emitter formats in slice 6 out of the
* six digits ACCEPT FROM DATE hands over.
ASR3 LDA #8
 STA NWID
 LDA #0
 STA NLLEN
 STA AKRES
 RTS

* ---- ASKTEXT: a literal's own words ------------
* Longer than thirty-two is TRUNCATED, not
* refused - the same choice SAVENAME makes about a
* data name.  The entry still lands where it was
* asked for, and what fitted is on the screen to
* be seen.
ASKTEXT LDA #<MTEXTQ
 STA STRPTR
 LDA #>MTEXTQ
 STA STRPTR+1
 JSR LINEIN
 LDA LIRES
 BNE ATNO
 LDA LLEN
 BEQ ATNO
 CMP #33
 BCC ATT1
 LDA #32
ATT1 STA NLLEN
 STA NWID
 LDX #0
ATT2 CPX NLLEN
 BCS ATT3
 LDA LBUF,X
 STA NTEXT,X
 INX
 JMP ATT2
ATT3 LDA #0
 STA AKRES
 RTS
ATNO LDA #1
 STA AKRES
 RTS

* ---- ASKRULE: a character, and how far ---------
ASKRULE JSR PROMPT23
 LDA #<MCHARQ
 STA STRPTR
 LDA #>MCHARQ
 STA STRPTR+1
 JSR PUTS
ARU1 JSR GETCHORD
 LDA CHKEY
 CMP #$1B
 BEQ ARNO
 CMP #$20
 BCC ARU1
 CMP #$7F
 BCS ARU1
 STA NTEXT
 LDA #1
 STA NLLEN
 LDA #<MWIDQ
 STA STRPTR
 LDA #>MWIDQ
 STA STRPTR+1
 JSR LINEIN
 LDA LIRES
 BNE ARNO
 LDA LLEN
 BEQ ARNO
 JSR ATOI
 STA NWID
 BEQ ARNO
 LDA #0
 STA AKRES
 RTS
ARNO LDA #1
 STA AKRES
 RTS

* ---- ASKPICT: the page number's picture --------
* An empty answer takes ZZ9, which is what a page
* number wants nine times in ten, and saves the
* operator typing the obvious.
ASKPICT LDA #<MPICTQ
 STA STRPTR
 LDA #>MPICTQ
 STA STRPTR+1
 JSR LINEIN
 LDA LIRES
 BNE APNO
 LDA LLEN
 BNE APC1
 LDA #$5A
 STA NPICT
 STA NPICT+1
 LDA #$39
 STA NPICT+2
 LDA #3
 STA NWID
 JMP APCOK
APC1 CMP #15
 BCC APC2
 LDA #14
APC2 STA NWID
 LDX #0
APC3 CPX NWID
 BCS APCOK
 LDA LBUF,X
 STA NPICT,X
 INX
 JMP APC3
APCOK LDA #0
 STA NLLEN
 STA AKRES
 RTS
APNO LDA #1
 STA AKRES
 RTS

* ---- PROMPT23: clear row 23 and sit on it ------
* The two single-key questions draw their own
* prompt because they do not go through LINEIN.
PROMPT23 JSR CLRLINE
 LDA #23
 STA SCRROW
 LDA #0
 STA SCRCOL
 STA SCRATR
 RTS

* ---- BLNKTXT / BLNKPIC: clear the staging ------
* Not tidiness: the staged bytes are copied into
* the entry whole, and the entry is written to
* disk whole, so a stale byte from the last add
* would end up in the file.
BLNKTXT LDA #$20
 LDX #0
BT1 STA NTEXT,X
 INX
 CPX #32
 BCC BT1
 LDX #9
BT2 STA NNAME,X
 DEX
 BPL BT2
 STZ NDECS
 RTS
* ---- ASKFLD: a FIELD or TOTAL by name ----------
* The dictionary supplies the rest: its name goes
* in ENAME for the export's MOVE, a text field is
* printed X(width), and a number gets a picture -
* typed, or by default Z's and a 9 for its digits,
* and .99 for its decimals.  A TOTAL must be a
* number, and gets two more digits of room.
ASKFLD LDA #<MFLDQ
 STA STRPTR
 LDA #>MFLDQ
 STA STRPTR+1
 JSR LINEIN
 LDA LIRES
 BNE AFNO
 LDA LLEN
 BEQ AFNO
 JSR RFFIND
 BCC AF1
 LDA #<MNOFLD
 STA STRPTR
 LDA #>MNOFLD
 STA STRPTR+1
 JSR SHOWERR
AFNO LDA #1
 STA AKRES
 RTS
* ZPT2 -> the descriptor: name 0-9, type 10,
* width 11, decimals 12, string length 15
AF1 LDY #0
AF2 LDA (ZPT2),Y
 CMP #$21
 BCS AF3
 LDA #$20
AF3 STA NNAME,Y
 INY
 CPY #10
 BCC AF2
 LDY #12
 LDA (ZPT2),Y
 STA NDECS
 LDY #10
 LDA (ZPT2),Y
 STA NFTYP
 CMP #2
 BCS AF5
* text: X(width) at export, no picture here
 LDA NKIND
 CMP #KTOT
 BEQ AFNUMB
 LDY #15
 LDA (ZPT2),Y
 STA NWID
 LDA #0
 STA NLLEN
 STA AKRES
 RTS
AFNUMB LDA #<MNUMF
 STA STRPTR
 LDA #>MNUMF
 STA STRPTR+1
 JSR SHOWERR
 JMP AFNO
AF5 CMP #3
 BNE AF6
* yes/no: one digit, 1 or 0
 LDA NKIND
 CMP #KTOT
 BEQ AFNUMB
 LDA #$39
 STA NPICT
 LDA #1
 STA NWID
 STZ NDECS
 JMP APCOK
* a number: the default picture, then ask
AF6 LDY #11
 LDA (ZPT2),Y
 SEC
 SBC NDECS
 BEQ AF6A
 BCS AF6B
AF6A LDA #1
AF6B LDX NKIND
 CPX #KTOT
 BNE AF7
 CLC
 ADC #2
AF7 STA RFT
 LDX #0
AF8 LDA RFT
 CMP #2
 BCC AF9
 CPX #13
 BCS AF9
 LDA #$5A
 STA NPICT,X
 INX
 DEC RFT
 JMP AF8
AF9 LDA #$39
 STA NPICT,X
 INX
 LDA NDECS
 BEQ AF11
 LDA #$2E
 STA NPICT,X
 INX
 LDY NDECS
AF10 CPX #14
 BCS AF11
 LDA #$39
 STA NPICT,X
 INX
 DEY
 BNE AF10
AF11 STX NWID
* a picture typed now replaces the default
 LDA #<MPICTQ
 STA STRPTR
 LDA #>MPICTQ
 STA STRPTR+1
 JSR LINEIN
 LDA LIRES
 BEQ AF11A
 JMP AFNO
AF11A LDA LLEN
 BEQ AF13
 JSR BLNKPIC
 LDA LLEN
 CMP #15
 BCC AF12
 LDA #14
AF12 STA NWID
 LDX #0
AF12A LDA LBUF,X
 JSR RPUPC
 STA NPICT,X
 INX
 CPX NWID
 BCC AF12A
AF13 JMP APCOK

BLNKPIC LDA #$20
 LDX #0
BP1 STA NPICT,X
 INX
 CPX #14
 BCC BP1
 RTS

* ================= PLACING IT =================
* ---- ADDENT: validate, place, redraw -----------
ADDENT LDA NWID
 BNE AD1
 JMP ADBAD
AD1 CLC
 LDA NCOL
 ADC NWID
 CMP #81
 BCC AD2
 JMP ADBAD
AD2 CLC
 LDA NCOL
 ADC NWID
 SEC
 SBC #1
 STA NHI
 JSR OVERLAP
 BCC AD3
 JMP ADOVL
AD3 JSR FINDINS
 JSR OPENSLOT
 JSR STORENT
 INC HECNT
 JMP RPDRAW
ADBAD LDA #<MBAD
 LDX #>MBAD
 JMP ADSHOW
ADOVL LDA #<MOVL
 LDX #>MOVL
ADSHOW STA STRPTR
 STX STRPTR+1
 JMP SHOWERR

* ---- OVERLAP: C=1 if the new entry hits one ----
* Only entries on the SAME page line can collide,
* so the line test comes first and throws most of
* the table out in a single compare.
OVERLAP LDA #0
 STA OIX
OV1 LDA OIX
 CMP HECNT
 BCS OVNO
 LDA OIX
 JSR RPSETP
 LDY #ELINE
 LDA (RPTR),Y
 CMP NLINE
 BNE OVNX
 LDY #ECOL
 LDA (RPTR),Y
 STA OLO
 LDY #EWIDTH
 LDA (RPTR),Y
 CLC
 ADC OLO
 SEC
 SBC #1
 STA OHI
 LDA NCOL
 CMP OHI
 BEQ OVYES
 BCS OVNX
 LDA OLO
 CMP NHI
 BEQ OVYES
 BCS OVNX
OVYES SEC
 RTS
OVNX INC OIX
 JMP OV1
OVNO CLC
 RTS

* ---- FINDINS: where it belongs -> FIDX ---------
* The first entry that sorts AFTER the new one.
* Nothing found means it goes on the end, which is
* what FIDX = HECNT already says.
FINDINS LDA #0
 STA FIDX
FI1 LDA FIDX
 CMP HECNT
 BCS FIDN
 LDA FIDX
 JSR RPSETP
 LDY #ELINE
 LDA (RPTR),Y
 CMP NLINE
 BCC FINX
 BNE FIDN
 LDY #ECOL
 LDA (RPTR),Y
 CMP NCOL
 BCS FIDN
FINX INC FIDX
 JMP FI1
FIDN RTS

* ---- OPENSLOT: make room at FIDX ---------------
* From the END backwards, so no slot is written
* before it has been read - the same direction
* EDIT's INSLIN moves records, and for the same
* reason.
OPENSLOT LDA HECNT
 STA DIX
OS1 LDA DIX
 CMP FIDX
 BCC OSDN
 BEQ OSDN
 LDA DIX
 JSR RPSETP
 LDA RPTR
 STA ZPT1
 LDA RPTR+1
 STA ZPT1+1
 LDA DIX
 SEC
 SBC #1
 JSR RPSETP
 LDA RPTR
 STA ZPT2
 LDA RPTR+1
 STA ZPT2+1
 JSR SLOTCPY
 DEC DIX
 JMP OS1
OSDN RTS

* ---- SLOTCPY: 64 bytes (ZPT2) -> (ZPT1) --------
* One stride is one entry, so a move is a straight
* sixty-four bytes with no field-by-field copying
* and no parallel arrays to keep in step.  FORMAT
* shifts nine arrays to delete one field; this
* shifts one block.
SLOTCPY LDY #0
SC1 LDA (ZPT2),Y
 STA (ZPT1),Y
 INY
 CPY #ENTSZ
 BCC SC1
 RTS

* ---- STORENT: the staged entry -> slot FIDX ----
STORENT LDA FIDX
 JSR RPSETP
 LDY #EKIND
 LDA NKIND
 STA (RPTR),Y
 LDY #ELINE
 LDA NLINE
 STA (RPTR),Y
 LDY #ECOL
 LDA NCOL
 STA (RPTR),Y
 LDY #EWIDTH
 LDA NWID
 STA (RPTR),Y
 LDY #EFLAGS
 LDA #0
 STA (RPTR),Y
 LDY #EDECS
 LDA NDECS
 STA (RPTR),Y
 LDY #ELLEN
 LDA NLLEN
 STA (RPTR),Y
* The band is CACHED here rather than worked out
* again by the rule and the emitter.  Slice 4
* moves the marks, so it must walk the table and
* redo this byte - the price of caching it, and
* it is cheaper than computing it on every draw.
 LDA NLINE
 JSR BANDOF
 LDY #EBAND
 STA (RPTR),Y
* the COBOL data name stays blank until slice 3
* the dictionary field's name, for F and T
 LDX #0
 LDY #ENAME
ST1 LDA NNAME,X
 STA (RPTR),Y
 INX
 INY
 CPY #EPICT
 BCC ST1
 LDX #0
ST2 CPX #14
 BCS ST3
 TXA
 CLC
 ADC #EPICT
 TAY
 LDA NPICT,X
 STA (RPTR),Y
 INX
 JMP ST2
ST3 LDX #0
ST4 CPX #32
 BCS ST5
 TXA
 CLC
 ADC #ETEXT
 TAY
 LDA NTEXT,X
 STA (RPTR),Y
 INX
 JMP ST4
ST5 RTS

* ================= TAKING IT AWAY ===============
* ---- RPDEL: OA-D, remove an entry --------------
* Found by line and column, which is how it was
* placed.  FORMAT will also take a label; a report
* has too many literals for a label to identify
* one, so position is the only handle here.
RPDEL LDA HECNT
 BNE RPD0
 RTS
RPD0 JSR ASKLINE
 LDA AKRES
 BNE RPDDN
 JSR ASKCOL
 LDA AKRES
 BNE RPDDN
 JSR FINDLC
 LDA FIDX
 CMP #$FF
 BEQ RPDNF
 JSR DELIDX
 JSR CLRLINE
 JMP RPDRAW
RPDDN JMP CLRLINE
RPDNF LDA #<MNF
 STA STRPTR
 LDA #>MNF
 STA STRPTR+1
 JSR SHOWERR
 JMP RPDDN

* ---- FINDLC: entry at NLINE/NCOL -> FIDX -------
* A column ANYWHERE INSIDE the entry finds it, not
* only its first one.  The operator is pointing at
* something on the screen, not remembering where
* it began.  $FF says nothing is there.
FINDLC LDA #0
 STA FIDX
FL1 LDA FIDX
 CMP HECNT
 BCS FLNO
 LDA FIDX
 JSR RPSETP
 LDY #ELINE
 LDA (RPTR),Y
 CMP NLINE
 BNE FLNX
 LDY #ECOL
 LDA (RPTR),Y
 STA OLO
 CMP NCOL
 BEQ FLOK
 BCS FLNX
 LDY #EWIDTH
 LDA (RPTR),Y
 CLC
 ADC OLO
 SEC
 SBC #1
 CMP NCOL
 BCC FLNX
FLOK RTS
FLNX INC FIDX
 JMP FL1
FLNO LDA #$FF
 STA FIDX
 RTS

* ---- DELIDX: take slot FIDX out ----------------
* Forwards this time, because the gap is being
* closed rather than opened.
DELIDX LDA FIDX
 STA DIX
DL1 LDA DIX
 CLC
 ADC #1
 CMP HECNT
 BCS DLDN
 LDA DIX
 JSR RPSETP
 LDA RPTR
 STA ZPT1
 LDA RPTR+1
 STA ZPT1+1
 LDA DIX
 CLC
 ADC #1
 JSR RPSETP
 LDA RPTR
 STA ZPT2
 LDA RPTR+1
 STA ZPT2+1
 JSR SLOTCPY
 INC DIX
 JMP DL1
DLDN DEC HECNT
 RTS
