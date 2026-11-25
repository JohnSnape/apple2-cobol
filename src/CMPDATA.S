* CMPDATA.S  the DATA DIVISION  -  COMPILE slice 4
* PUT from COMPILE.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* Pass one.  It reads every data description, gives
* each item a descriptor and a place in the data
* segment, and puts its name in the symbol table.
* Nothing in the PROCEDURE DIVISION can be compiled
* until this has finished, which is why it is a pass
* of its own and not a mode.
*
* IT EMITS CODE, WHICH IS NOT OBVIOUS.
* An object file carries no data image at all: ENTER
* clears the segment and every VALUE clause is an
* instruction that follows it.  So this pass emits
*
*     ENTER <size>
*     MOVL / MOVF for each VALUE
*
* and the size is not known until the last item has
* been allocated.  ENTER therefore goes out FIRST
* with a placeholder, and the placeholder is patched
* at the end through EMSETW - the same primitive the
* forward-branch chain uses, doing ordinary work.
*
* THE LEVEL STACK IS WHAT MAKES A GROUP A GROUP.
* An item with no PICTURE that has subordinates is a
* group, and its length is the sum of theirs - which
* is not known when its descriptor is written.  So
* each open level is pushed with the data-segment
* offset it started at, and closing it patches its
* descriptor with how far the segment has moved
* since.  A group is measured, never declared.

LVLMAX EQU 16

* ---- DATDIV: the whole division ----------------
* out: C=1 if it stopped on PROCEDURE DIVISION
DATDIV JSR SYMINIT
 STZ DDSTA
 STZ NLVL
 STZ DDONE
 STZ CURIT
 STZ CURIT+1
* ENTER goes out first, with a size nobody knows
* yet.  Remember where the operand landed.
 STZ EMWV
 STZ EMWV+1
 LDA #OENTER
 JSR EMOP1
 LDA #1
 STA ENTOFF
 LDA #0
 STA ENTOFF+1
* error first, then the next token - as in PROCDIV,
* so the line reported is the line that was wrong
DD1 LDA CMPERR
 BNE DDERR
 JSR LEXNEXT
 BCS DD9
 LDA LEXERR
 BNE DDERR
 LDA CMPERR
 BNE DDERR
 LDA TOKTYP
 CMP #TKPUNC
 BEQ DD1
 CMP #TKNUM
 BNE DD1W
* In the IDENTIFICATION DIVISION a number is text -
* DATE-WRITTEN. 11 NOV 2026. (CMPENV.S)
 LDA DDSTA
 BEQ DD1
* DDLVL is a SUBROUTINE - it ends in RTS - so it is
* called, never branched to.  It was BEQ DDLVL, and
* the first item's RTS returned from DATDIV itself
* with carry clear: pass one stopped after one 01,
* said nothing, and pass two began in the middle of
* the DATA DIVISION (BETA1, error 10, 2026-11-07).
 JSR DDLVL
 JMP DD1
DD1W CMP #TKWORD
 BNE DD1
* FD, SELECT, a header: the record before it ends
 JSR DDCLOS
* A word here is SELECT, FD, a division or section
* header, a SPECIAL-NAMES clause - or, since
* 2026-11-12, error 50 (ENWORD, CMPENV.S).  It was
* noise, skipped.  PROCEDURE is where this pass
* stops, from the free text too, as it always did.
 JSR DDISPR
 BCS DD1P
 LDA DDSTA
 BNE DD1R
 JSR ENIDN
 JMP DD1
DD1R JSR FCTL
 BCS DD1J
 JSR ENWORD
DD1J JMP DD1
DD1P LDA #1
 STA DDONE
DD9 JSR DDCLOS
 JSR FCRES
 JSR QSRES
 JSR DDENT
 LDA CMPERR
 BNE DDER2
 LDA DDONE
 BEQ DDER3
 CLC
 RTS
DDERR SEC
 RTS
DDER2 SEC
 RTS
* Running off the end of the source before
* PROCEDURE DIVISION is an error and not an empty
* program: a program with no procedure has nothing
* to run, and saying so here is kinder than an
* object file with no code in it.
DDER3 LDA #6
 STA CMPERR
 SEC
 RTS

* ---- DDENT: patch ENTER with the real size ------
DDENT LDA ENTOFF
 STA EMWO
 LDA ENTOFF+1
 STA EMWO+1
 LDA DSEG
 STA EMWV
 LDA DSEG+1
 STA EMWV+1
 JMP EMSETW

* ---- DDISPR: is this word PROCEDURE? ------------
* out: C=1 if it is
DDISPR LDA TOKLEN
 CMP #9
 BNE DDIPNO
 LDX #0
DDIP1 LDA TOKBUF,X
 CMP WPROC,X
 BNE DDIPNO
 INX
 CPX #9
 BCC DDIP1
 SEC
 RTS
DDIPNO CLC
 RTS
WPROC ASC 'PROCEDURE'

* ================= ONE DATA ITEM ===============
* ---- DDLVL: a level number was just read --------
* A 77 closes like an 01: it is never part of a
* group (FIXLIST A9, 2026-11-08)
DDLVL LDA TOKLIN
 STA ENTLIN
 LDA TOKLIN+1
 STA ENTLIN+1
 JSR DDNUM
 STA THISLV
* 01-49, 77 and 88 are the levels there are.  66
* (RENAMES) is not in this COBOL, and anything else
* is not a level at all - both error 50 (2026-11-12;
* until then any number was taken as given).
 BEQ DDLVBD
 CMP #50
 BCC DDLVG
 CMP #77
 BEQ DDLVG
 CMP #88
 BEQ DDLVG
DDLVBD JMP ENBAD
DDLVG LDA THISLV
 CMP #77
 BNE DDLV1
 JSR DDCLOS
 LDA #77
 STA THISLV
DDLV1 JSR DDCLOSE
 LDA THISLV
 CMP #88
 BNE DDL0
 JMP DD88
* the name, or FILLER
DDL0 JSR LEXNEXT
 BCC DDL1
 JMP DDLEOF
DDL1 LDA TOKTYP
 CMP #TKWORD
 BEQ DDL2
 LDA #7
 STA CMPERR
 RTS
DDL2 JSR DDFILL
 BCC DDL3
 LDA #1
 STA ISFILL
 JMP DDL4
DDL3 LDA #0
 STA ISFILL
* ---- start the descriptor with the defaults -----
DDL4 LDA #TGROUP
 STA DTYP
 STZ DLENV
 STZ DDECV
 STZ DFLGV
 STZ DEDTV
 STZ DEDTV+1
 STZ HASPIC
 STZ REDF
 STZ VALKND
 STZ OCCN
* the name is still in TOKBUF, and the clause loop
* is about to destroy it, so the symbol goes in now
* with the item number it is ABOUT to get
 LDA ISFILL
 BNE DDL5
 LDA NITEMS
 STA SYMVAL
 LDA NITEMS+1
 STA SYMVAL+1
 LDA #KDATA
 JSR SYMADD
 BCS DDL4X
* A level 01 immediately after an FD is that file's
* record area.  COBOL names it that way and not by
* pointing at it, so the link is made by ADJACENCY -
* which is why DDFREC is called here and not from
* anywhere that can see the FD.
 LDA THISLV
 CMP #1
 BNE DDL5
 JSR FCREC
 JMP DDL5
DDL4X RTS
DDL5 JSR DDCLAU
 LDA CMPERR
 BEQ DDL6
 RTS
* ---- allocate and describe ---------------------
DDL6 JSR DDRDA
 JSR EMALLOC
 JSR EMDESC
 BCC DDL7
 RTS
DDL7 LDA EMIT
 STA CURIT
 LDA EMIT+1
 STA CURIT+1
* OCCURS: the table list, and an item's other
* occurrences (CMPDATA2.S)
 JSR DDTAB
* An item with no PICTURE is a group until something
* subordinate proves it; push it so the next lower
* level can close it and measure it.
 LDA HASPIC
 BNE DDL8
 JSR DDPUSH
DDL8 JSR DDRDB
 JSR DDVAL
 RTS
DDLEOF LDA #8
 STA CMPERR
 RTS

* ---- DDCLAU: the clauses, up to the full stop ---
* It stops at the FIRST error.  A missing full stop
* (35, from DDXVAL) used to go round again: the next
* entry's name is not a clause word, so error 50
* overwrote the 35 (2026-11-12, the e35 test).
DDCLAU LDA CMPERR
 BNE DDCX
 JSR LEXNEXT
 BCS DDCEOF
 LDA LEXERR
 BNE DDCX
 LDA TOKTYP
 CMP #TKPUNC
 BNE DDC1
 LDA TOKBUF
 CMP #$2E
 BEQ DDCX
 JMP DDCLAU
DDC1 CMP #TKWORD
 BEQ DDC2
 JSR DDXVAL
 JMP DDCLAU
DDC2
 JSR DDWHAT
 JMP DDCLAU
DDCEOF LDA #8
 STA CMPERR
DDCX RTS

* ---- DDWHAT: dispatch one clause word -----------
* The words, and why each is taken or refused, are
* in CLWTAB (CMPENV.S).  A word not there is error
* 50.  It used to be SKIPPED, deliberately, so that
* SIGN, JUSTIFIED and BLANK WHEN ZERO would not stop
* the sample programs - and so JUSTIFIED RIGHT and
* BLANK WHEN ZERO compiled and did nothing, and
* COMP-1 compiled to whatever the PICTURE said.
DDWHAT LDA #<CLWTAB
 LDX #>CLWTAB
 JSR WDLKAX
 BCS DDWGO
 JMP ENBAD
DDWGO CMP #2
 BCS DDWG1
 JMP DDPIC
DDWG1 CMP #4
 BCS DDWG2
 JMP DDVALC
DDWG2 BNE DDWG3
 JMP DDOCC
DDWG3 CMP #5
 BNE DDWG4
 JMP DDREDF
DDWG4 CMP #8
 BCS DDWG5
 JMP DDXTHR
DDWG5 CMP #17
 BCS DDWG6
 JMP DDCOMP
DDWG6 RTS

* ---- PIC: take the string and read it -----------
DDPIC JSR LEXPIC
 BCC DDP1
 LDA #8
 STA CMPERR
 RTS
DDP1 LDA #1
 STA HASPIC
 JMP PICPARS

* ---- OCCURS n -----------------------------------
DDOCC JSR LEXNEXT
 BCS DDOX
 LDA TOKTYP
 CMP #TKNUM
 BNE DDOX
 JSR DDNUM
 STA OCCN
 CMP #0
 BNE DDOX
 LDA #36
 STA CMPERR
DDOX RTS

* ---- COMP / COMP-3 ------------------------------
* COMP-3 is ACCEPTED AND IGNORED, and that is the
* whole of it: what a numeric item gets is a NUM8
* cell whatever anybody writes, so COMP-3 is a hint
* about intent and not a layout request.  COMP is
* different - two bytes of binary, for subscripts
* and keys - and that one does change the storage.
*
* CHANGED 2026-11-07: COMP is now a NUM8 cell too.
* Two bytes of binary was right for keys, but the
* interpreter has no binary arithmetic, move or
* display - TBIN is tested nowhere in the VM - so
* MOVE 1 TO a COMP key wrote eight bytes into two,
* and DISPLAYing it printed 5920 for 1 (MEDIA).
* The file layer reads a key either way (VQGETN
* runs a NUM8 cell through BCDBIN), so nothing
* needs the binary form.  Only COMP with no PICTURE
* has anything to set: the PICTURE already did it.
DDCOMP LDA HASPIC
 BNE DDCPX
 LDA #TNUMB
 STA DTYP
 LDA #NCELL
 STA DLENV
 STZ DDECV
 LDA #1
 STA HASPIC
DDCPX RTS

* ---- VALUE --------------------------------------
* The literal is remembered, not emitted: ENTER has
* to clear the segment before anything is put in it,
* and ENTER's size is not known yet.  DDVAL emits
* once the item has an item number.
DDVALC JSR DDVPRE
 BCS DDVCX
 LDA TOKTYP
 CMP #TKSTR
 BEQ DDVCS
 CMP #TKNUM
 BEQ DDVCN
 CMP #TKWORD
 BEQ DDVCF
DDVCX RTS
DDVCS LDA #1
 STA VALKND
 JMP DDVSAV
DDVCN LDA #2
 STA VALKND
 JMP DDVSAV
DDVCF LDA #3
 STA VALKND
* fall into DDVSAV

* ---- DDVSAV: park the literal until DDVAL -------
DDVSAV LDX #0
DDVS1 CPX TOKLEN
 BCS DDVS2
 LDA TOKBUF,X
 STA VALBUF,X
 INX
 JMP DDVS1
DDVS2 LDA TOKLEN
 STA VALLEN
 RTS

* ---- DDVAL: emit the VALUE, if there was one ----
DDVAL LDA VALKND
 BNE DDV1
 RTS
DDV1 CMP #3
 BEQ DDVFIG
* a text or numeric literal: pool it, then MOVL
 LDX #0
DDV2 CPX VALLEN
 BCS DDV3
 LDA VALBUF,X
 STA LITBUF+1,X
 INX
 JMP DDV2
DDV3 LDA VALLEN
 STA LITN
 LDA VALKND
 CMP #2
 BEQ DDVNUM
 JSR EMLTXT
 JMP DDVEMIT
* A numeric VALUE has to become a NUM8 cell here,
* because the pool holds cells and not digits - the
* destination's type is what says how to read the
* pool, and there is no room in it for a tag.
DDVNUM JSR DDVSCL
 LDX #0
DDVN1 CPX VALLEN
 BCS DDVN2
 LDA VALBUF,X
 STA LITBUF,X
 INX
 JMP DDVN1
DDVN2 LDA #<VALBUF
 STA ZPT1
 LDA #>VALBUF
 STA ZPT1+1
 LDA #<LITBUF
 STA ZPT2
 LDA #>LITBUF
 STA ZPT2+1
 LDA VALLEN
 STA ALEN
 JSR BCDPACK
 JSR DDVNEG
 LDA DDECV
 STA LITSCL
 JSR EMLNUM
DDVEMIT LDA CURIT
 STA EMWV
 LDA CURIT+1
 STA EMWV+1
 LDA EMLO
 STA EMWV2
 LDA EMLO+1
 STA EMWV2+1
 LDA #OMOVL
 JMP EMOP2
* ---- a figurative constant: MOVF, one byte ------
DDVFIG JSR DDFIGN
 BCS DDVFX
 STA VALFIG
 LDA CURIT
 STA EMWV
 LDA CURIT+1
 STA EMWV+1
 LDA #OMOVF
 JSR EMB
 BCS DDVFX
 JSR EMW
 BCS DDVFX
 LDA VALFIG
 JMP EMB
DDVFX RTS

* DDFIGN and its FIGTAB moved to CMPCOM.S on
* 2026-08-16: PDOPND needs them too, and CMPDATA is
* pass one only.

* ================= THE LEVEL STACK =============
* ---- DDPUSH: this item is a group so far --------
* A SEVENTEENTH OPEN GROUP IS ERROR 51.  The stack
* has 80 bytes of OVLWORK, LVLMAX (16) entries of
* five, and PDPNAM starts right after it - so it
* cannot grow to the 49 levels the standard allows.
* Until 2026-11-22 the push simply did not happen:
* the group was never closed, so never measured,
* and its length stayed 0.  DISPLAY showed nothing
* and a MOVE from it gave spaces, with no word from
* the compiler (FIXLIST A21, test lvl17.cob).
* Refusing it at its own line is the honest answer;
* sixteen groups deep is far past any real record.
DDPUSH LDA NLVL
 CMP #LVLMAX
 BCC DDPU1
 LDA #51
 STA CMPERR
 RTS
DDPU1 JSR DDLPTR
 LDY #0
 LDA THISLV
 STA (ZPT1),Y
 INY
 LDA CURIT
 STA (ZPT1),Y
 INY
 LDA CURIT+1
 STA (ZPT1),Y
 INY
 LDA DSEG
 STA (ZPT1),Y
 INY
 LDA DSEG+1
 STA (ZPT1),Y
 INC NLVL
 RTS

* ---- DDCLOSE: close every level >= THISLV -------
DDCLOSE LDA NLVL
 BEQ DDCLX
 DEC NLVL
 JSR DDLPTR
 LDY #0
 LDA (ZPT1),Y
 CMP THISLV
 BCS DDCL1
* not deep enough to close: put it back
 INC NLVL
 RTS
DDCL1 JSR DDMEAS
 JMP DDCLOSE
DDCLX RTS

* ---- DDCLOS: close them all, at end of division --
DDCLOS LDA #1
 STA THISLV
 JMP DDCLOSE

* ---- DDMEAS: a group's length is what it holds ---
* DSEG has moved by exactly the size of everything
* subordinate, so the difference IS the length -
* nobody has to add anything up.
DDMEAS LDY #3
 LDA (ZPT1),Y
 STA DDT
 INY
 LDA (ZPT1),Y
 STA DDT+1
 SEC
 LDA DSEG
 SBC DDT
 STA DDT
 LDA DSEG+1
 SBC DDT+1
 STA DDT+1
 LDY #1
 LDA (ZPT1),Y
 STA EMIT
 INY
 LDA (ZPT1),Y
 STA EMIT+1
* the open OCCURS group?  Its stride is this length
 JSR DDTCLS
* a group of 256 bytes or more cannot be described:
* the length is a byte, and a 300-byte record was
* recorded as 44 (FIXLIST A10).  Error 33.
 LDA DDT+1
 BEQ DDMS1
 LDA #33
 STA CMPERR
DDMS1 LDA DDT
 JSR EMDLEN
 JMP DDRDC

* ---- DDLPTR: level NLVL -> ZPT1 -----------------
DDLPTR LDA NLVL
 STA DDT
 LDA #0
 STA DDT+1
 ASL DDT
 ROL DDT+1
 ASL DDT
 ROL DDT+1
 CLC
 LDA DDT
 ADC NLVL
 STA DDT
 LDA DDT+1
 ADC #0
 STA DDT+1
 CLC
 LDA #<LVLST
 ADC DDT
 STA ZPT1
 LDA #>LVLST
 ADC DDT+1
 STA ZPT1+1
 RTS

* (88 LEVELS are in CMPDATA2.S since 2026-11-08)

* ================= HELPERS =====================
* ---- DDNUM: TOKBUF digits -> A ------------------
DDNUM LDA #0
 STA DDT
 LDX #0
DDN1 CPX TOKLEN
 BCS DDN2
 LDA DDT
 ASL
 STA DDT2
 ASL
 ASL
 CLC
 ADC DDT2
 STA DDT
 LDA TOKBUF,X
 AND #$0F
 CLC
 ADC DDT
 STA DDT
 INX
 JMP DDN1
DDN2 LDA DDT
 RTS

* ---- DDFILL: is the name FILLER? ----------------
DDFILL LDA TOKLEN
 CMP #6
 BNE DDFNO
 LDX #0
DDF1 LDA TOKBUF,X
 CMP WFILL,X
 BNE DDFNO
 INX
 CPX #6
 BCC DDF1
 SEC
 RTS
DDFNO CLC
 RTS
WFILL ASC 'FILLER'

* (DDSIZE, which multiplied the DESCRIPTOR's length
* by OCCURS, is gone: a table's descriptor is one
* occurrence, and DDTAB in CMPDATA2.S allocates the
* rest - FIXLIST A2.)

* ================ FILE-CONTROL ==================
* Added 2026-08-16, with the file verbs.  Everything
* here is compile-time: not one byte of p-code comes
* out of the ENVIRONMENT DIVISION, which is what
* KEYWORDS.md has said all along.
*
* WHY IT IS IN PASS ONE.  The file verbs are
* compiled in pass two and need to know, for a name
* like LEAD-FILE, which of the two files it is and
* where its record, key and status items live.  All
* of that is declared here, divisions earlier.  The
* file table crosses the pass boundary in CMPFIL at
* $1F40; the names go in the ordinary symbol table.

* ---- FCTL: is this word SELECT or FD? ---------
* out: C=1 if it was, and has been dealt with
FCTL LDA TOKLEN
 CMP #6
 BNE FCT1
 LDX #0
FCT0 LDA TOKBUF,X
 CMP FCWSEL,X
 BNE FCT1
 INX
 CPX #6
 BCC FCT0
 JSR FCSEL
 SEC
 RTS
FCT1 JSR QSCL
 BCC FCT2
 RTS
FCT2 LDA TOKLEN
 CMP #2
 BNE FCTNO
 LDA TOKBUF
 CMP #$46
 BNE FCTNO
 LDA TOKBUF+1
 CMP #$44
 BNE FCTNO
 JSR FCFD
 SEC
 RTS
FCTNO CLC
 RTS
FCWSEL ASC 'SELECT'

* ---- QSCL: QUERY STATUS IS name ----------------
* The one SPECIAL-NAMES clause this pass reads.  It
* names an item the DATA DIVISION has not declared
* yet, so - like SELECT's KEY and STATUS - the name
* is kept as text and looked up by QSRES when the
* division closes.  Until 2026-11-07 nothing read it
* at all: QSTITM stayed $FFFF and every QUERY
* statement ran with no status item, so ON ERROR
* fired with the status still reading 00.
* out: C=1 if the word was QUERY (clause consumed)
QSCL LDA TOKLEN
 CMP #5
 BNE QSNO
 LDX #0
QSC1 LDA TOKBUF,X
 CMP QSWQ,X
 BNE QSNO
 INX
 CPX #5
 BCC QSC1
* skip STATUS and IS, keep the first other word
QSC2 JSR LEXNEXT
 BCS QSBAD
 LDA TOKTYP
 CMP #TKWORD
 BNE QSBAD
 JSR QSNOIS
 BCS QSC2
 LDA TOKLEN
 STA QSNLEN
 TAX
 DEX
QSC3 LDA TOKBUF,X
 STA QSNAM,X
 DEX
 BPL QSC3
 SEC
 RTS
QSBAD LDA #16
 STA CMPERR
 SEC
 RTS
QSNO CLC
 RTS
* ---- QSNOIS: C=1 if TOKBUF is STATUS or IS ------
QSNOIS LDA TOKLEN
 CMP #2
 BNE QSN1
 LDA TOKBUF
 CMP #$49
 BNE QSNN
 LDA TOKBUF+1
 CMP #$53
 BNE QSNN
 SEC
 RTS
QSN1 CMP #6
 BNE QSNN
 LDX #0
QSN2 LDA TOKBUF,X
 CMP QSWS,X
 BNE QSNN
 INX
 CPX #6
 BCC QSN2
 SEC
 RTS
QSNN CLC
 RTS
* ---- QSRES: the saved name -> QSTITM -----------
* Error 15 if it names nothing, rather than the
* silence that hid this for three months.
QSRES LDA QSNLEN
 BEQ QSRX
 STA TOKLEN
 TAX
 DEX
QSR1 LDA QSNAM,X
 STA TOKBUF,X
 DEX
 BPL QSR1
 JSR SYMFIND
 BCS QSRE
 JSR SYMGET
 LDA SYKIND
 CMP #KDATA
 BNE QSRE
 LDA SYMVAL
 STA QSTITM
 LDA SYMVAL+1
 STA QSTITM+1
QSRX RTS
QSRE LDA #15
 STA CMPERR
 RTS
QSWQ ASC 'QUERY'
QSWS ASC 'STATUS'
QSNLEN DFB 0
QSNAM DS TOKMAX

