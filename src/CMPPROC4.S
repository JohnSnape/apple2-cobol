* CMPPROC4.S  PROCEDURE DIVISION, part four
* PUT from COMPILE2.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* Started 2026-11-08 for the FIXLIST list A work,
* because CMPPROC.S and CMPPROC3.S are both within
* a couple of K of Merlin 8's 24K PUT-file limit.
* New PROCEDURE DIVISION code goes here.

* ================= DISPLAY UPON / ACCEPT =======
* Moved from CMPPROC.S, 2026-11-08, for room.
* ---- PDUPON: an optional UPON <device> ----------
* out: PDDEV = 0 for the screen, 1-4 for a printer
* A token read here and found NOT to be UPON is the
* next statement's first word, and must be handed
* back through PDHELD.  It used to be dropped, and
* dropping it eats the verb after every DISPLAY
* that has no UPON - which is most of them.
PDUPON LDA #0
 STA PDDEV
 JSR PDNEXT
 BCS PDUX
 LDA TOKTYP
 CMP #TKWORD
 BNE PDUHLD
 LDA TOKLEN
 CMP #4
 BNE PDUHLD
 LDX #0
PDU3 LDA TOKBUF,X
 CMP WUPON,X
 BNE PDUHLD
 INX
 CPX #4
 BCC PDU3
 JSR PDNEXT
 BCS PDUX
* UPON CONSOLE is the screen, which PDDEV already
* says - the word is read and nothing changes.  It
* used to fall through to the printer below, so a
* program written for another compiler, where
* UPON CONSOLE is the usual way to say "on the
* screen", printed every line instead (2026-11-11).
 LDA TOKLEN
 CMP #7
 BNE PDUPRT
 LDX #0
PDU5 LDA TOKBUF,X
 CMP WCONS,X
 BNE PDUPRT
 INX
 CPX #7
 BCC PDU5
 RTS
* PRINTER, or a mnemonic the ENVIRONMENT DIVISION
* declared.  Device 1 is the default printer and is
* what plain PRINTER means.
PDUPRT LDA #1
 STA PDDEV
PDUX RTS
PDUHLD LDA #1
 STA PDHELD
 RTS
WUPON ASC 'UPON'
WCONS ASC 'CONSOLE'

* ---- ACCEPT <item> [AT LINE n COLUMN n] ---------
* The word after the item is read to see whether it
* is AT; anything else belongs to the next
* statement and is handed back through PDHELD.
PDACC JSR PDOPND
 BCS PDAX
 LDA PDKIND
 BNE PDABAD
 JSR PDSAVE
 JSR PDNEXT
 BCS PDAC1
 LDA TOKTYP
 CMP #TKWORD
 BNE PDACH
 JSR PDQKW
 BCS PDACF
 CMP #9
 BNE PDACH
 JMP PDAAT
* FROM DATE / FROM TIME (2026-11-08, for REPORT)
PDACF JSR PDCONW
 BCS PDACH
 LDA PFRT
 CMP #CONWT-RELWT+3
 BNE PDACH
 JMP PDAFR
PDACH LDA #1
 STA PDHELD
PDAC1 JSR PDAFN
 BCS PDAX
 LDA PDSVAL
 STA EMWV
 LDA PDSVAL+1
 STA EMWV+1
 LDA #OACC
 JMP EMOP1
PDABAD LDA #13
 STA CMPERR
PDAX RTS

* ---- PDAFN: is the ACCEPT's item a file name? ---
* If a SELECT says ASSIGN TO this very item - the
* compiler's file table has FLFLG bit 2 and the item
* number in FLPATH (CMPFILE.S) - $99 FNAME goes in
* first, and the VM takes the line as a file name:
* 64 characters at most, a beep on the last seven
* (DECISIONS 8.11, the user's request).  Nothing to
* write in the program: the ASSIGN already says it.
* out: C=1 only if the emitter failed
PDAFN LDX #0
 LDY NFILES
PDFN1 BEQ PDFN3
 LDA CMPFIL+FLFLG,X
 AND #4
 BEQ PDFN2
 LDA CMPFIL+FLPATH,X
 CMP PDSVAL
 BNE PDFN2
 LDA CMPFIL+FLPATH+1,X
 CMP PDSVAL+1
 BNE PDFN2
 LDA #OFNAME
 JMP EMB
* the next entry: sixteen bytes on.  DEY last, so
* BRA carries its zero flag back to PDFN1.
PDFN2 TXA
 CLC
 ADC #16
 TAX
 DEY
 BRA PDFN1
PDFN3 CLC
 RTS

* ---- PDAFR: ACCEPT item FROM DATE | TIME --------
* The FROM is in hand.  One instruction:
*     $85 ACCF  item  code      0 DATE, 1 TIME
* DATE is YYMMDD and TIME HHMMSSss, as the standard
* has them; the library's clock routines (DATIME.S)
* make both.  Anything else after FROM is error 12.
PDAFR JSR PDNEXT
 BCS PDAFE
 LDA TOKTYP
 CMP #TKWORD
 BNE PDAFE
* DATE, TIME and MENU by length and first letter,
* KEY and PREFIX the same (2026-11-11): codes 2 KEY
* and 3 PREFIX n go on the ACCF instruction; MENU
* is an instruction of its own (CMPSET.S)
 LDA TOKBUF
 LDX TOKLEN
 CPX #4
 BNE PDAF3
 LDX #0
 CMP #$44
 BEQ PDAF1
 INX
 CMP #$54
 BEQ PDAF1
 CMP #$4D
 BNE PDAFE
 JMP PDAMN
PDAFE LDA #12
 STA CMPERR
 RTS
PDAF3 CPX #3
 BNE PDAF4
 CMP #$4B
 BNE PDAFE
 LDX #2
 BRA PDAF1
PDAF4 CPX #6
 BNE PDAFE
 CMP #$50
 BNE PDAFE
* PREFIX n: one digit, 0-9
 JSR PDNEXT
 BCS PDAFE
 LDA TOKTYP
 CMP #TKNUM
 BNE PDAFE
 LDA TOKLEN
 CMP #1
 BNE PDAFE
 LDA TOKBUF
 SEC
 SBC #$30
 CMP #10
 BCS PDAFE
 STA PDAPX
 LDX #3
PDAF1 STX PDATL
 LDA PDSVAL
 STA EMWV
 LDA PDSVAL+1
 STA EMWV+1
 LDA #OACCF
 JSR EMOP1
 BCS PDAFX
 LDA PDATL
 JSR EMB
 BCS PDAFX
 LDA PDATL
 CMP #3
 BNE PDAFX
 LDA PDAPX
 JMP EMB
PDAFB LDA #12
 STA CMPERR
PDAFX RTS

* ================= AT LINE n COLUMN n ==========
* ---- PDDAT: DISPLAY ... AT LINE n COLUMN n ------
* The AT is in hand (held).  By now every operand
* has been emitted, each in its no-newline form, so
* the cursor move has to go IN FRONT of them: the
* code from PDDST up moves three bytes higher and
*     $82 AT  line  column
* goes into the gap.  That stretch is nothing but
* DISPN and DISPLN - no branch, no fixup link - so
* moving it breaks nothing.  The last operand keeps
* its no-newline form: on a form the cursor stays
* where the text ended, and the screen does not
* scroll under it.
PDDAT STZ PDHELD
 JSR PDATP
 BCS PDDAX0
* three bytes on the end first: EMB does the full
* check, so the move below can never run past it
 LDA #0
 JSR EMB
 BCS PDDAX0
 LDA #0
 JSR EMB
 BCS PDDAX0
 LDA #0
 JSR EMB
 BCC PDDAT1
PDDAX0 RTS
PDDAT1
* THE CODE IS IN AUX (CMPCON.S, 2026-11-22): the
* stretch from PDDST to the old end - CODLEN-3 -
* comes out into CODSTG and goes back three bytes
* higher, and the AT goes into the gap.  It was a
* byte loop over main memory.  At least one operand
* (three bytes) was emitted, so the stretch is never
* empty; a DISPLAY's code is never near CODSTG's
* 2,816 bytes, but the test costs four lines.
 SEC
 LDA CODLEN
 SBC #3
 STA EMXN
 LDA CODLEN+1
 SBC #0
 STA EMXN+1
 SEC
 LDA EMXN
 SBC PDDST
 STA EMXN
 LDA EMXN+1
 SBC PDDST+1
 STA EMXN+1
 CMP #>CODSTN
 BCC PDDA1
 LDA #1
 STA CMPERR
 SEC
 RTS
PDDA1 LDA #<CODSTG
 STA EMXB
 LDA #>CODSTG
 STA EMXB+1
 LDA PDDST
 STA EMXO
 LDA PDDST+1
 STA EMXO+1
 CLC
 JSR EMXMOV
 CLC
 LDA PDDST
 ADC #3
 STA EMXO
 LDA PDDST+1
 ADC #0
 STA EMXO+1
 SEC
 JSR EMXMOV
* the gap: $82 AT line column, at PDDST
 LDA #OAT
 STA CODSTG
 LDA PDATL
 STA CODSTG+1
 LDA PDATC
 STA CODSTG+2
 LDA PDDST
 STA EMXO
 LDA PDDST+1
 STA EMXO+1
 LDA #3
 STA EMXN
 STZ EMXN+1
 SEC
 JSR EMXMOV
 CLC
PDDATX RTS

* ---- PDAAT: ACCEPT item AT LINE n COLUMN n ------
* The item is in PDSVAL.  One instruction:
*     $87 ACCA  line  column  item
PDAAT JSR PDATP
 BCS PDAAX
 JSR PDAFN
 BCS PDAAX
 LDA #OACCA
 JSR EMB
 BCS PDAAX
 LDA PDATL
 JSR EMB
 BCS PDAAX
 LDA PDATC
 JSR EMB
 BCS PDAAX
 LDA PDSVAL
 STA EMWV
 LDA PDSVAL+1
 STA EMWV+1
 JMP EMW
PDAAX RTS

* ---- PDATP: LINE [NUMBER] n COLUMN [NUMBER] n ---
* The AT has been read.  out: PDATL, PDATC, C=0;
* C=1 with error 12 if it is not that shape.
* COL is taken for COLUMN.  The numbers must be
* 1-255; the interpreter clamps them to the screen,
* as DSCREEN always has.
PDATP JSR PDNEXT
 BCS PDATB
 JSR PDATW
 BCS PDATB
 CMP #0
 BNE PDATB
 JSR PDATN
 BCS PDATB
 STA PDATL
 JSR PDNEXT
 BCS PDATB
 JSR PDATW
 BCS PDATB
 CMP #12
 BEQ PDAT2
 CMP #19
 BNE PDATB
PDAT2 JSR PDATN
 BCS PDATB
 STA PDATC
 CLC
 RTS
PDATB LDA #12
 STA CMPERR
 SEC
 RTS
* PDATN: [NUMBER] n -> A.  C=1 if not a number 1-255
PDATN JSR PDNEXT
 BCS PDANX
 JSR PDATW
 BCS PDAN1
 CMP #5
 BNE PDANX
 JSR PDNEXT
 BCS PDANX
PDAN1 LDA TOKTYP
 CMP #TKNUM
 BNE PDANX
 JSR PDQNUM
 BCS PDANX
 LDA PDVAL+1
 BNE PDANX
 LDA PDVAL
 BEQ PDANX
 CLC
 RTS
PDANX SEC
 RTS
* PDATW: the token is one of ATWT's words?
* out: C=0 and A = its offset in ATWT; C=1 if not
PDATW LDA TOKTYP
 CMP #TKWORD
 BNE PDAWN
 LDX #ATWT-RELWT
 JSR PFRW1
 BCS PDAWN
 LDA PFRT
 SEC
 SBC #ATWT-RELWT
 CLC
 RTS
PDAWN SEC
 RTS

* ================= SCOPE =======================
* ---- PDDOT: a full stop closes every open IF -----
* A sentence ends at a full stop, and so does every
* IF in it that has no END-IF - the way COBOL-74
* programs and most books write them:
*     IF X > 5 DISPLAY "BIG" ELSE DISPLAY "SMALL".
* Without this the IF stayed open, its false branch
* was never patched, and it jumped to the start of
* the program (FIXLIST A4).
* The IF stack is shared with the inline PERFORM,
* which pushes TWO entries: its top, marked with
* bit 7 of the high byte, then its exit.  So the
* top entry is an IF's unless it is marked, or the
* entry beneath it is - then it is a PERFORM exit,
* which only END-PERFORM closes, and the closing
* stops there.
PDDOT LDA CMPERR
 BNE PDDOTX
 LDA NIFS
 BEQ PDDOTX
 ASL
 TAX
 LDA IFSTK-1,X
 BMI PDDOTX
 CPX #4
 BCC PDDOT1
 LDA IFSTK-3,X
 BMI PDDOTX
PDDOT1 JSR PDENDIF
 JMP PDDOT
PDDOTX RTS

* ---- PDOPEN: nothing may be left open -----------
* At a paragraph name and at the end of the source.
* An IF or inline PERFORM still open is error 14,
* an EVALUATE error 28.  out: C=1 if one was.
PDOPEN LDA NIFS
 BEQ PDOP1
 LDA #14
 BNE PDOPE
PDOP1 LDA NEVS
 BEQ PDOP2
 LDA #28
PDOPE STA CMPERR
 SEC
 RTS
PDOP2 CLC
 RTS

* ================= LINE MARKERS ================
* ---- PDLMK: LINE n before a statement ------------
* Run-time stops say "at line n", and n comes from
* the LINE instruction - which nothing emitted, so
* every stop said "at line 0" (FIXLIST A19).  One
* marker per SOURCE LINE that starts a statement:
* three bytes, and only when the line has changed,
* so a line of three statements costs one marker.
PDLMK LDA TOKLIN
 CMP PDLLIN
 BNE PDLM1
 LDA TOKLIN+1
 CMP PDLLIN+1
 BEQ PDLMX
PDLM1 LDA TOKLIN
 STA PDLLIN
 STA EMWV
 LDA TOKLIN+1
 STA PDLLIN+1
 STA EMWV+1
 JMP EMLINE
PDLMX RTS
* $FFFF: no line yet.  The overlay is loaded fresh
* for every compile, so this is reset every time.
PDLLIN DFB $FF,$FF

* ================= MOVE ========================
* ---- PDMVTY: which MOVE instruction -------------
* in: A = PDSKND, EMWV = dest, EMWV2 = source.
* Decided from the two types and nothing the
* programmer said.  FIXLIST A17: every mismatched
* pair compiled to MOVA or MOVL, which copy bytes,
* so MOVE N TO X(8) put the cell's bytes in X and
* MOVE X TO N put letters in the cell.  Now:
*   number -> text, group or edited   MOVE (edit)
*   text or group -> number           MOVD (de-edit)
*   number -> number                  MOVN
*   anything else                     MOVA, MOVG
* and a literal or figurative that cannot go where
* it is sent - "ABC" or SPACE into a number, 5 into
* text - is error 13 rather than garbage.
PDMVTY CMP #1
 BEQ PDMVL
 CMP #2
 BEQ PDMVF
 JSR PDMDST
 CMP #TEDIT
 BEQ PDMVE
 PHA
 JSR PDMSRC
 STA PDMST
 PLA
 CMP #TNUMB
 BNE PDMV5
* to a number
 LDA PDMST
 CMP #TNUMB
 BEQ PDMVN
 LDA #OMOVD
 JMP EMOP2
PDMVN LDA #OMOVN
 JMP EMOP2
* to text or a group
PDMV5 LDX PDMST
 CPX #TNUMB
 BEQ PDMVE
 CMP #TGROUP
 BEQ PDMVG
 LDA #OMOVA
 JMP EMOP2
PDMVG LDA #OMOVG
 JMP EMOP2
PDMVE LDA #OMOVE
 JMP EMOP2
* a literal: text into a number, or a number into
* text or a group, cannot be read the way MOVL reads
* it - the pool entry is the other kind
PDMVL JSR PDMDST
 LDX PDLTYP
 CMP #TNUMB
 BEQ PDML1
 CMP #TEDIT
 BEQ PDML2
 CPX #1
 BEQ PDMVBD
 BNE PDML2
PDML1 CPX #1
 BNE PDMVBD
PDML2 LDA #OMOVL
 JMP EMOP2
* a figurative into a number: ZERO only
PDMVF JSR PDMDST
 CMP #TNUMB
 BNE PDMF1
 LDA PDSVAL
 CMP #1
 BNE PDMVBD
PDMF1 JMP PDMFIG
PDMVBD LDA #13
 STA CMPERR
 RTS
* PDMDST / PDMSRC: the type of the destination /
* source item.  EMDGET leaves EMWV and EMWV2 alone.
PDMDST LDA EMWV
 STA EMIT
 LDA EMWV+1
 STA EMIT+1
 JSR EMDGET
 LDA DTYP
 RTS
PDMSRC LDA EMWV2
 STA EMIT
 LDA EMWV2+1
 STA EMIT+1
 JSR EMDGET
 LDA DTYP
 RTS
PDMST DFB 0

* ---- PDISFG: is the word in TOKBUF a figurative?
* out: C=0 if it is.  DISPLAY "A" SPACE "B" - the
* test for "another operand" asked only the symbol
* table, so SPACE ended the DISPLAY and was read as
* a statement: error 12 (found testing A16).
PDISFG LDX #0
PDIF1 CPX TOKLEN
 BCS PDIF2
 LDA TOKBUF,X
 STA VALBUF,X
 INX
 BNE PDIF1
PDIF2 LDA TOKLEN
 STA VALLEN
 JMP DDFIGN

* (ARITHMETIC - PDARSZ, PDARTL, REMAINDER - is in
* CMPARITH.S, PUT next, since 2026-11-11.)

* ================= SUBSCRIPTS ==================
* ---- PDOSUB: a table item takes its subscript ----
* FIXLIST A2, 2026-11-08.  PDOPND has just read an
* operand.  If it is a data name in the table list
* ($1F60, written by pass one), a subscript must
* follow - ( n ) or ( name ) - and a SUBS
* instruction goes out in front of the statement:
*
*     SUBS slot, item, subscript, count, stride
*
* which at run time builds the element's descriptor
* in one of four slots.  The operand handed back is
* the SLOT, $FFF0-$FFF3, and every instruction that
* takes an item takes a slot: the interpreter's
* VDESC reads the slot's descriptor instead of the
* table's.  So MOVE, DISPLAY, ADD, IF and COMPUTE
* needed no change at all.
* Four slots per statement, each used once; a
* statement starts with all four free (PDDISP).
* A condition name whose item is in a table cannot
* be subscripted in the subset: error 38.
* not a table item: as it was
PDSBOK CLC
 RTS
PDOSUB LDA PDKIND
 BNE PDSBOK
 LDA PDCKND
 CMP #KCOND
 BNE PDSB1
 LDA PDCPAR
 LDY PDCPAR+1
 JSR PDTFND
 BCS PDSBOK
 JMP PDSBAD
PDSB1 LDA PDVAL
 STA PDSIT
 LDA PDVAL+1
 STA PDSIT+1
 LDY PDVAL+1
 LDA PDVAL
 JSR PDTFND
 BCS PDSBOK
 STX PDSTX
* ( ...
 JSR PDNEXT
 BCS PDSBAD
 LDA TOKTYP
 CMP #TKPUNC
 BNE PDSBAD
 LDA TOKBUF
 CMP #$28
 BNE PDSBAD
 JSR PDNEXT
 BCS PDSBAD
 LDA TOKTYP
 CMP #TKNUM
 BEQ PDSBN
 CMP #TKWORD
 BNE PDSBAD
* ... a data name: a whole number, not a table item
 JSR SYMFIND
 BCS PDSBAD
 JSR SYMGET
 LDA SYKIND
 CMP #KDATA
 BNE PDSBAD
 LDA SYMVAL
 STA PDSIX
 STA EMIT
 LDA SYMVAL+1
 STA PDSIX+1
 STA EMIT+1
 JSR EMDGET
 LDA DTYP
 CMP #TNUMB
 BNE PDSBAD
 LDA DDECV
 BNE PDSBAD
 LDA PDSIX
 LDY PDSIX+1
 JSR PDTFND
 BCC PDSBAD
 STZ PDSFLG
 BRA PDSBC
PDSBAD LDA #38
 STA CMPERR
 SEC
 RTS
* ... or a number, 1 to the count
PDSBN JSR PDSNUM
 BCS PDSBAD
 BEQ PDSBAD
 LDX PDSTX
 CMP OCCTAB+2,X
 BEQ PDSBN1
 BCS PDSBAD
PDSBN1 STA PDSIX
 STZ PDSIX+1
 LDA #$80
 STA PDSFLG
* ... )
PDSBC JSR PDNEXT
 BCS PDSBAD
 LDA TOKTYP
 CMP #TKPUNC
 BNE PDSBAD
 LDA TOKBUF
 CMP #$29
 BNE PDSBAD
* a slot
 LDX PDSUBN
 CPX #4
 BCC PDSBS
 LDA #39
 STA CMPERR
 SEC
 RTS
PDSBS LDA PDSIT
 STA PDSLL,X
 LDA PDSIT+1
 STA PDSLH,X
 LDA #OSUBS
 JSR EMB
 BCS PDSBX
 LDA PDSUBN
 ORA PDSFLG
 JSR EMB
 BCS PDSBX
 LDA PDSIT
 STA EMWV
 LDA PDSIT+1
 STA EMWV+1
 JSR EMW
 BCS PDSBX
 LDA PDSIX
 STA EMWV
 LDA PDSIX+1
 STA EMWV+1
 JSR EMW
 BCS PDSBX
 LDX PDSTX
 LDA OCCTAB+2,X
 JSR EMB
 BCS PDSBX
 LDX PDSTX
 LDA OCCTAB+3,X
 JSR EMB
 BCS PDSBX
* the operand is the slot now
 LDA PDSUBN
 ORA #$F0
 STA PDVAL
 LDA #$FF
 STA PDVAL+1
 INC PDSUBN
 CLC
PDSBX RTS

* ---- PDTFND: is item A (Y = high) in a table? ---
* out: C=0 and X = its entry's offset in OCCTAB;
*      C=1 if it is in none
PDTFND CPY #0
 BNE PDTFN
 STA PDSTW
 LDX #0
 LDY NOCC
 BEQ PDTFN
PDTF1 LDA PDSTW
 CMP OCCTAB,X
 BCC PDTF2
 LDA OCCTAB+1,X
 CMP PDSTW
 BCC PDTF2
 CLC
 RTS
PDTF2 INX
 INX
 INX
 INX
 DEY
 BNE PDTF1
PDTFN SEC
 RTS

* ---- PDSNUM: TOKBUF, digits only, -> A (1-255) --
* out: C=1 if it is not a whole number under 256;
*      Z set if it is zero
PDSNUM STZ PDSTW
 LDX #0
PDSN1 CPX TOKLEN
 BCS PDSN9
 LDA TOKBUF,X
 SEC
 SBC #$30
 CMP #10
 BCS PDSNB
 STA PDSTD
* PDSTW = PDSTW * 10 + digit, refusing a carry
 LDA PDSTW
 CMP #26
 BCS PDSNB
 ASL
 STA PDSTW
 ASL
 ASL
 CLC
 ADC PDSTW
 BCS PDSNB
 ADC PDSTD
 BCS PDSNB
 STA PDSTW
 INX
 BNE PDSN1
PDSN9 LDA PDSTW
 CLC
 RTS
PDSNB SEC
 RTS

* ================= PERFORM TIMES AND VARYING ===
* FIXLIST B, 2026-11-08.  Both forms, in line (to
* END-PERFORM) and out of line (a paragraph, THRU a
* paragraph), on the same loop layout PERFORM UNTIL
* has: a top, an exit placeholder, and - in line -
* both on the IF stack, the top marked, so that
* END-PERFORM closes them with BRA top as it always
* has.  That is why each loop does its stepping AT
* THE TOP: END-PERFORM emits nothing else.

* ---- PDPF4: the word after PERFORM --------------
*   UNTIL     the inline PERFORM UNTIL (PDPINL)
*   VARYING   an inline PERFORM VARYING
*   a number, or a data name: n TIMES, inline
*   anything else is a paragraph name (PDPF00)
PDPF4 LDA TOKTYP
 CMP #TKNUM
 BEQ PDP4T
 CMP #TKWORD
 BNE PDPTB
 JSR PDQKW
 BCS PDP4N
 CMP #20
 BNE PDP41
 JMP PDPINL
PDP41 CMP #25
 BNE PDPTB
 LDA #1
 STA PDPINF
 JMP PDPVAR
PDP4N JSR SYMFIND
 BCS PDP4P
 JSR SYMGET
 LDA SYKIND
 CMP #KDATA
 BEQ PDP4T
PDP4P JMP PDPF00
PDP4T LDA #1
 STA PDHELD
 STA PDPINF
 JMP PDPTIM

* ---- PDPTO: PERFORM para [THRU p] - and then? ----
* A count in hand (held by PDQOPT) is para n TIMES;
* otherwise the plain PERF.
PDPTO LDA PDHELD
 BEQ PDPTP
 LDA TOKTYP
 CMP #TKNUM
 BEQ PDPT1
 CMP #TKWORD
 BNE PDPTP
 JSR SYMFIND
 BCS PDPTP
 JSR SYMGET
 LDA SYKIND
 CMP #KDATA
 BNE PDPTP
PDPT1 STZ PDPINF
 JMP PDPTIM
PDPTP JMP PDPEMT
PDPTB LDA #13
 STA CMPERR
 SEC
PDPTX RTS

* ---- PDPTIM: n TIMES ----------------------------
* A hidden counter, one per statement so that loops
* nest:
*       PUSH n  POPD c
*   T:  CLASS c, POSITIVE   BNE X
*       PUSHD c  PUSHL 1  ESUB  POPD c
*       PERF p  -  or the statements in line
*       BRA T
*   X:
PDPTIM JSR PDOPND
 BCS PDPTB
 JSR PDPVOK
 BCS PDPTB
 LDA PDVAL
 STA PDPCNT
 LDA PDVAL+1
 STA PDPCNT+1
 LDA PDKIND
 STA PDPCK
 JSR PDQNEED
 BCS PDPTB
 CMP #21
 BNE PDPTB
 LDA #TNUMB
 STA DTYP
 LDA #8
 STA DLENV
 STZ DDECV
 JSR PDMTM2
 BCS PDPTX
 LDA EMIT
 STA PDPCTR
 LDA EMIT+1
 STA PDPCTR+1
 LDA PDPCNT
 STA EMWV
 LDA PDPCNT+1
 STA EMWV+1
 LDX PDPCK
 JSR PDATPU
 BCS PDPTX
 JSR PDPPOP
 BCS PDPTX
 LDA CODLEN
 STA PDPTOP
 LDA CODLEN+1
 STA PDPTOP+1
* CLASS c, POSITIVE, 0 - true (0) while c > 0
 LDA #OCLASS
 JSR EMB
 BCS PDPTZ
 JSR PDPCW
 BCS PDPTZ
 LDA #6
 JSR EMB
 BCS PDPTZ
 STZ EMWV
 STZ EMWV+1
 JSR EMW
 BCS PDPTZ
 LDA #OBNE
 JSR EMB
 BCS PDPTZ
 LDA CODLEN
 STA PDPXIT
 LDA CODLEN+1
 STA PDPXIT+1
 JSR EMW
 BCS PDPTZ
* c = c - 1
 JSR PDPCW1
 LDA #OPUSHD
 JSR EMOP1
 BCS PDPTZ
 JSR PDONE1
 BCS PDPTZ
 LDA #OPUSHL
 JSR EMOP1
 BCS PDPTZ
 LDA #OESUB
 JSR EMB
 BCS PDPTZ
 JSR PDPPOP
 BCS PDPTZ
 JMP PDPBODY
PDPTZ RTS

* ---- PDPVAR: VARYING i FROM a BY b UNTIL cond ---
*       PUSH a  POPD i
*       BRA C
*   T:  PUSHD i  PUSH b  EADD  POPD i
*   C:  <cond, TRUE -> X>
*       PERF p  -  or the statements in line
*       BRA T
*   X:
* AFTER - a second variable - is not in the subset.
* None of i, a, b may be subscripted: the slots are
* reused by the statements in the loop before the
* step at the top reads them again.
PDPVAR JSR PDOPND
 BCS PDPVB
 LDA PDKIND
 BNE PDPVB
 JSR PDPVOK
 BCS PDPVB
 LDA PDVAL
 STA PDPVI
 LDA PDVAL+1
 STA PDPVI+1
 LDX #3
 JSR PDPVW
 BCS PDPVB
 JSR PDOPND
 BCS PDPVB
 JSR PDPVOK
 BCS PDPVB
 LDA PDVAL
 STA PDPVA
 LDA PDVAL+1
 STA PDPVA+1
 LDA PDKIND
 STA PDPVAK
 LDX #8
 JSR PDPVW
 BCS PDPVB
 JSR PDOPND
 BCS PDPVB
 JSR PDPVOK
 BCS PDPVB
 LDA PDVAL
 STA PDPVB2
 LDA PDVAL+1
 STA PDPVB2+1
 LDA PDKIND
 STA PDPVBK
 JSR PDQNEED
 BCS PDPVB
 CMP #20
 BEQ PDPV1
PDPVB LDA #13
 STA CMPERR
 SEC
PDPVX RTS
PDPV1 LDA PDPVA
 STA EMWV
 LDA PDPVA+1
 STA EMWV+1
 LDX PDPVAK
 JSR PDATPU
 BCS PDPVX
 JSR PDPVPI
 BCS PDPVX
 JSR PDCBRA
 BCS PDPVX
 LDA PDT
 STA PDPVC
 LDA PDT+1
 STA PDPVC+1
 LDA CODLEN
 STA PDPTOP
 LDA CODLEN+1
 STA PDPTOP+1
 LDA PDPVI
 STA EMWV
 LDA PDPVI+1
 STA EMWV+1
 LDA #OPUSHD
 JSR EMOP1
 BCS PDPVX
 LDA PDPVB2
 STA EMWV
 LDA PDPVB2+1
 STA EMWV+1
 LDX PDPVBK
 JSR PDATPU
 BCS PDPVX
 LDA #OEADD
 JSR EMB
 BCS PDPVX
 JSR PDPVPI
 BCS PDPVX
 LDA PDPVC
 STA EMWO
 LDA PDPVC+1
 STA EMWO+1
 JSR PDCHERE
 LDA #1
 STA PDCTRU
 JSR PDCOND
 BCS PDPVZ
 LDA PDT
 STA PDPXIT
 LDA PDT+1
 STA PDPXIT+1
 JMP PDPBODY
PDPVZ RTS
* fall into PDPBODY

* ---- PDPBODY: the loop's body and its way round ---
* in: PDPTOP the top, PDPXIT the exit placeholder
PDPBODY LDA PDPINF
 BEQ PDPBO
 LDA PDPTOP
 STA PDT
 LDA PDPTOP+1
 ORA #$80
 STA PDT+1
 JSR PDIPUSH
 LDA PDPXIT
 STA PDT
 LDA PDPXIT+1
 STA PDT+1
 JMP PDIPUSH
PDPBO JSR PDPEMT
 LDA CMPERR
 BNE PDPBX
 LDA PDPTOP
 STA EMWV
 LDA PDPTOP+1
 STA EMWV+1
 LDA #OBRA
 JSR EMOP1
 BCS PDPBX
 LDA PDPXIT
 STA PDT
 LDA PDPXIT+1
 STA PDT+1
 JMP PDIHERE
PDPBX RTS

* ---- helpers --------------------------------------
* PDPVOK: the operand just read is an item or a
* number, and not a subscript slot.  C=1 if not.
PDPVOK LDA PDKIND
 CMP #2
 BCS PDPVN
 LDA PDVAL+1
 CMP #$FF
 BEQ PDPVN
 CLC
 RTS
PDPVN SEC
 RTS
* PDPVW: the next word is CONWT's word at offset X
* (3 FROM, 8 BY).  C=1 if not.
PDPVW STX PDPVT
 JSR PDNEXT
 BCS PDPVN
 LDA TOKTYP
 CMP #TKWORD
 BNE PDPVN
 JSR PDCONW
 BCS PDPVN
 LDA PFRT
 SEC
 SBC #CONWT-RELWT
 CMP PDPVT
 BNE PDPVN
 CLC
 RTS
* PDPVPI: POPD i
PDPVPI LDA PDPVI
 STA EMWV
 LDA PDPVI+1
 STA EMWV+1
 LDA #OPOPD
 JMP EMOP1
* PDPPOP: POPD c.  PDPCW: the word c.  PDPCW1: c
* into EMWV and nothing more.
PDPPOP JSR PDPCW1
 LDA #OPOPD
 JMP EMOP1
PDPCW JSR PDPCW1
 JMP EMW
PDPCW1 LDA PDPCTR
 STA EMWV
 LDA PDPCTR+1
 STA EMWV+1
 RTS
* PDONE1: the number 1 in the pool -> EMWV
PDONE1 LDX #NCELL-1
PDO1A STZ LITBUF,X
 DEX
 BPL PDO1A
 LDA #1
 STA LITBUF+NCELL-1
 STZ LITSCL
 JSR EMLNUM
 BCS PDO1X
 LDA EMLO
 STA EMWV
 LDA EMLO+1
 STA EMWV+1
 CLC
PDO1X RTS
