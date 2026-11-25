* CMPPROC3.S  PROCEDURE DIVISION, part 3 of 3
* The file verbs, COMPUTE, EVALUATE, literals.
* PUT from COMPILE2.S straight after CMPPROC2 - no
* ORG, not assembled alone.  Split from CMPPROC.S
* (51K) on 2026-11-07: Merlin 8 cannot PUT a file
* over about 24K.  The bytes assembled are the same.

* ================= THE FILE VERBS ===============
* OPEN CLOSE READ WRITE REWRITE DELETE START, added
* 2026-08-16.  Seven verbs, one parser, one emitter -
* which is possible because VMFILE gave all seven
* opcodes the SAME ten-byte shape:
*
*   $9x ctl(b) op1(w) op2(w) status(w) target(w)
*
* so the differences between the verbs are all in
* where the operands come FROM, and every one of
* those is in the file table that FILE-CONTROL
* filled in during pass one.  The parser reads a
* name, looks the file up, and copies four words out
* of a table.
*
* TWO STATED LIMITS.  One file per OPEN - COBOL
* allows OPEN I-O A, B and the samples never use it.
* And the clause is one statement, as it is for
* QUERY, because there is no END-READ to say where a
* second would stop.
*
* The trailing clause machinery is QUERY's, reused
* whole: PDQPAIR reads AT END and INVALID KEY, and
* PDQCLS emits the target, the skip branch and the
* one statement.  They were written for a different
* verb and needed no change for this one, which is
* the return on having made them separate routines.

PDFILE SEC
 LDA PDVN
 SBC #17
 STA PFIX
 STZ PFCTL
 STZ PDQHAS
 LDA #$FF
 LDX #0
PDFI1 STA PFO1,X
 INX
 CPX #6
 BCC PDFI1
* OPEN, and only OPEN, has a mode in front of the
* name.  It goes in the high nibble of ctl, where
* VMFILE looks for it.
 LDA PFIX
 BNE PDFF1
 JSR PDQNEED
 BCS PDFBAD
 SEC
 SBC #13
 BEQ PDFBAD
 CMP #5
 BCS PDFBAD
 ASL
 ASL
 ASL
 ASL
 STA PFCTL
* the name.  WRITE and REWRITE name a RECORD and
* everything else names a FILE - which is COBOL's
* rule and not ours, and the reason the file table
* keeps the record's item number as well as the
* file's own name.
PDFF1 JSR PDNEXT
 BCS PDFBAD
 LDA TOKTYP
 CMP #TKWORD
 BEQ PDFF2
PDFBAD LDA #21
 STA CMPERR
PDFX RTS
PDFF2 LDA PFIX
 CMP #3
 BCC PDFF3
 CMP #5
 BCS PDFF3
 JSR PFBYREC
 JMP PDFF4
PDFF3 JSR PFBYNAM
PDFF4 BCS PDFBAD

* ---- four words out of the file table -----------
 JSR PFX
 LDA PFNO
 ORA PFCTL
 STA PFCTL
 LDA PFIX
 BNE PDFF5
* OPEN takes the pathname where the others take the
* RELATIVE KEY.  ASSIGN TO a data name (2026-11-22):
* FLFLG bit 2 becomes ctl bit 2, and the "path" is
* then an item number for VMFILE to read the name
* out of at run time.  Bits 2-3 of ctl were unused.
 LDA CMPFIL+FLFLG,X
 AND #4
 ORA PFCTL
 STA PFCTL
 LDA CMPFIL+FLPATH,X
 STA PFO1
 LDA CMPFIL+FLPATH+1,X
 STA PFO1+1
 JMP PDFF6
PDFF5 LDA CMPFIL+FLKEY,X
 STA PFO1
 LDA CMPFIL+FLKEY+1,X
 STA PFO1+1
* The record area goes out for every verb, including
* the two that do not move a record.  CLOSE ignores
* it, and one unconditional copy is smaller than the
* test that would avoid it.
PDFF6 LDA CMPFIL+FLREC,X
 STA PFO2
 LDA CMPFIL+FLREC+1,X
 STA PFO2+1
 LDA CMPFIL+FLSTAT,X
 STA PFST
 LDA CMPFIL+FLSTAT+1,X
 STA PFST+1

* ---- the trailing words, then the clause --------
* NEXT sets the mode nibble and turns READ into READ
* NEXT.  RECORD and KEY are noise - they read well
* and mean nothing - and are skipped by name.
PDFF7 JSR PDQOPT
 BCS PDFF9
 CMP #0
 BNE PDFF8
 LDA PFCTL
 ORA #$10
 STA PFCTL
 JMP PDFF7
PDFF8 CMP #13
 BEQ PDFFK
 CMP #12
 BEQ PDFFK
 STA PDQCLA
 CMP #9
 BEQ PDFFC
 CMP #11
 BEQ PDFFC
* a keyword belonging to the next statement
 LDA #1
 STA PDHELD
 JMP PDFF9
* KEY / RECORD: noise - except that on START the KEY
* is followed by a relation and the key's name,
*   START F KEY NOT LESS THAN K
* which used to come back as a statement called NOT
* (error 12, MEDIA, 2026-11-07).  START is always
* NOT LESS THAN at run time - RMSTRT positions at
* the key and READ NEXT goes up from there - and K
* is the file's RELATIVE KEY already, so the words
* are read and dropped.  = and > read the same way.
PDFFK LDA PFIX
 CMP #6
 BNE PDFFKX
 JSR PFSKR
 BCC PDFFKX
 JMP PDFBAD
PDFFKX JMP PDFF7
PDFFC JSR PDQPAIR
 BCS PDFXE

* ---- emit ---------------------------------------
* Its own exit, at its own foot.  PDFX is at the
* head of the statement and the emitter is two
* hundred bytes below it - further than a branch
* reaches, which is the third time this block has
* had to say so.
PDFF9 CLC
 LDA PFIX
 ADC #$90
 JSR EMB
 BCS PDFXE
 LDA PFCTL
 JSR EMB
 BCS PDFXE
 LDX #0
 JSR PFEW
 BCS PDFXE
 LDX #2
 JSR PFEW
 BCS PDFXE
 LDX #4
 JSR PFEW
 BCS PDFXE
 JMP PDQCLS
PDFXE RTS

* ---- PFSKR: START's relation and key name -------
* Skips = < > and IS NOT LESS GREATER THAN EQUAL TO,
* then takes one data name and drops it.  C=1 if
* the source ends first or something else is there.
PFSKR JSR PDNEXT
 BCS PFSKX
 LDA TOKTYP
 CMP #TKPUNC
 BEQ PFSKR
 CMP #TKWORD
 BNE PFSKX
 JSR PFRELW
 BCC PFSKR
 CLC
 RTS
PFSKX SEC
 RTS
* PFRELW: C=0 if TOKBUF is one of RELWT's words
* PDCONW: C=0 if TOKBUF is TO / FROM / BY / INTO
PDCONW LDX #CONWT-RELWT
 JMP PFRW1
PFRELW LDX #0
PFRW1 LDA RELWT,X
 BEQ PFRWNO
 STA PFRL
 STX PFRT
 CMP TOKLEN
 BNE PFRWN
 LDY #0
PFRW2 INX
 LDA RELWT,X
 CMP TOKBUF,Y
 BNE PFRWN
 INY
 CPY TOKLEN
 BCC PFRW2
 CLC
 RTS
PFRWN LDA PFRT
 SEC
 ADC PFRL
 TAX
 JMP PFRW1
PFRWNO SEC
 RTS
PFRT DFB 0
PFRL DFB 0
RELWT DFB 2
 ASC 'IS'
 DFB 3
 ASC 'NOT'
 DFB 4
 ASC 'LESS'
 DFB 7
 ASC 'GREATER'
 DFB 4
 ASC 'THAN'
 DFB 5
 ASC 'EQUAL'
 DFB 2
 ASC 'TO'
 DFB 0
* the connecting words of ADD/SUBTRACT/MULTIPLY/DIVIDE
CONWT DFB 2
 ASC 'TO'
 DFB 4
 ASC 'FROM'
 DFB 2
 ASC 'BY'
 DFB 4
 ASC 'INTO'
 DFB 0
* the arithmetic scope terminators (PDDISP's PDD9)
ENDWT DFB 7
 ASC 'END-ADD'
 DFB 12
 ASC 'END-SUBTRACT'
 DFB 12
 ASC 'END-MULTIPLY'
 DFB 10
 ASC 'END-DIVIDE'
 DFB 11
 ASC 'END-COMPUTE'
* SET, the verb (CMPSET.S) - here because VERBTAB
* is full, like the END- words
SETW DFB 3
 ASC 'SET'
 DFB 0
* the words of AT LINE n COLUMN n.  PDATW gives back
* each one's offset from ATWT: 0 LINE, 5 NUMBER,
* 12 COLUMN, 19 COL.  It must stay after RELWT and
* inside 256 bytes of it - PFRW1 indexes RELWT,X.
ATWT DFB 4
 ASC 'LINE'
 DFB 6
 ASC 'NUMBER'
 DFB 6
 ASC 'COLUMN'
 DFB 3
 ASC 'COL'
 DFB 0
* SET's words and DISPLAY's ERASE (CMPSET.S), by
* their offsets from here: 0 PRINTER, 8 PREFIX,
* 15 SCREEN, 22 PAPER, 28 ERASE.  Inside 256 bytes
* of RELWT, like the rest.
SETWT DFB 7
 ASC 'PRINTER'
 DFB 6
 ASC 'PREFIX'
 DFB 6
 ASC 'SCREEN'
 DFB 5
 ASC 'PAPER'
 DFB 5
 ASC 'ERASE'
 DFB 0


* ---- PFBYNAM: a file name -> PFNO ---------------
PFBYNAM JSR SYMFIND
 BCS PFBNNO
 JSR SYMGET
 LDA SYKIND
 CMP #KFILE
 BNE PFBNNO
 LDA SYMVAL
 STA PFNO
 CLC
 RTS
PFBNNO SEC
 RTS

* ---- PFBYREC: a record name -> its file ---------
* WRITE names the record and the file is whichever
* one declared it.  Two entries to search, so the
* search is a loop of two and not an index of any
* kind.
PFBYREC JSR PDOW3
 BCS PFBRNO
 STZ PFNO
PFBR1 LDA PFNO
 CMP NFILES
 BCS PFBRNO
 JSR PFX
 LDA CMPFIL+FLREC,X
 CMP PDVAL
 BNE PFBR2
 LDA CMPFIL+FLREC+1,X
 CMP PDVAL+1
 BNE PFBR2
 CLC
 RTS
PFBR2 INC PFNO
 JMP PFBR1
PFBRNO SEC
 RTS

* ---- PFX: X = 16 * PFNO -------------------------
PFX LDA PFNO
 ASL
 ASL
 ASL
 ASL
 TAX
 RTS

* ---- PFEW: emit the word at PFO1,X --------------
PFEW LDA PFO1,X
 STA EMWV
 LDA PFO1+1,X
 STA EMWV+1
 JMP EMW

* ================= COMPUTE ======================
* Slice 6, 2026-08-16.
*
*   COMPUTE X = A + B * C
*
* RECURSIVE DESCENT EMITS POSTFIX FOR NOTHING.
* Parse the left operand - which emits it - then the
* right, then the operator.  That IS reverse Polish,
* and there is no operator stack anywhere in this
* file because the 6502's own stack is holding the
* half-finished expressions.  The shunting yard is
* the algorithm you need when you are NOT allowed to
* recurse.
*
*   expr   := term { (+|-) term }
*   term   := factor { (*|/) factor }
*   factor := [-] primary
*   primary:= identifier | literal | ( expr )
*
* Precedence falls out of which routine calls which:
* CEEXPR calls CETERM, so CETERM binds tighter, so
* multiply happens first.  Nothing tests a priority
* number anywhere.
*
* THE DEPTH IS BOUNDED because the hardware stack is
* 256 bytes and a runaway parenthesis would walk off
* it silently.  CEDEP counts parentheses and stops
* at eight, which is deeper than any expression
* anybody writes on an eighty-column line.
*
* ROUNDED stores through POPDR, which rounds the
* digits POPD would cut (2026-11-08, FIXLIST A15).
* It was refused with error 24 until there was an
* instruction to put it in: a COMPUTE that accepted
* ROUNDED and truncated money anyway would have been
* the exact bug this system exists to not have.
* Error 24 now means ROUNDED without the = after it.

CEMAX EQU 8

PDCOMP STZ EMMODE
 JSR PDOPND
 BCS PDCOBAD
 LDA PDKIND
 BNE PDCOBAD
 LDA PDVAL
 STA CETGT
 LDA PDVAL+1
 STA CETGT+1
 STZ CEDEP
* the '=' - or the words EQUAL / EQUALS, which read
* better and mean the same
 JSR CEOP
 BCS PDCOWD
 CMP #$3D
 BEQ PDCO1
PDCOBAD LDA #23
 STA CMPERR
PDCOX RTS
* a word here is EQUAL, or ROUNDED and then the =
* (CEOP held the word; it is used up here)
PDCOWD STZ PDHELD
 LDA TOKLEN
 CMP #7
 BNE PDCO1
 LDA TOKBUF
 CMP #$52
 BNE PDCO1
 LDA EMMODE
 BNE PDCORB
 INC EMMODE
 JSR CEOP
 BCS PDCOWD
 CMP #$3D
 BEQ PDCO1
PDCORB LDA #24
 STA CMPERR
 RTS
PDCO1 JSR CEEXPR
 BCS PDCOX
 LDA CETGT
 STA EMWV
 LDA CETGT+1
 STA EMWV+1
 LDA #OPOPD
 LDX EMMODE
 BEQ PDCO2
 LDA #OPOPDR
PDCO2 JMP EMOP1

* ---- CEEXPR: term { +|- term } ------------------
CEEXPR JSR CETERM
 BCS CEEX
CEE1 JSR CEOP
 BCS CEEHD
 CMP #$2B
 BEQ CEE2
 CMP #$2D
 BEQ CEE3
* not ours - it belongs to whatever called us
 LDA #1
 STA PDHELD
 CLC
 RTS
CEE2 JSR CETERM
 BCS CEEX
 LDA #OEADD
 JSR EMOP
 JMP CEE1
CEE3 JSR CETERM
 BCS CEEX
 LDA #OESUB
 JSR EMOP
 JMP CEE1
CEEHD CLC
CEEX RTS

* ---- CETERM: factor { *|/ factor } --------------
CETERM JSR CEFACT
 BCS CETX
CET1 JSR CEOP
 BCS CETHD
 CMP #$2A
 BEQ CET2
 CMP #$2F
 BEQ CET3
 LDA #1
 STA PDHELD
 CLC
 RTS
CET2 JSR CEFACT
 BCS CETX
 LDA #OEMUL
 JSR EMOP
 JMP CET1
CET3 JSR CEFACT
 BCS CETX
 LDA #OEDIV
 JSR EMOP
 JMP CET1
CETHD CLC
CETX RTS

* ---- CEFACT: [-] primary ------------------------
* Unary minus is the primary, then ENEG.  Which is
* postfix again, and the reason there is no special
* case for it in the arithmetic.
CEFACT JSR CEOP
 BCS CEF1
 CMP #$2D
 BNE CEF2
 JSR CEPRIM
 BCS CEFX
 LDA #OENEG
 JMP EMOP
* the token was punctuation but not a minus - it may
* be the opening bracket, so hand it back
CEF2 LDA #1
 STA PDHELD
 JMP CEPRIM
* the token was a word or a literal
CEF1 LDA #1
 STA PDHELD
 JMP CEPRIM
CEFX RTS

* ---- CEPRIM: identifier, literal, or ( expr ) ---
CEPRIM JSR PDOPND
 BCC CEP2
* PDOPND refuses punctuation, so a bracket arrives
* here as a failure.  It is in TOKBUF either way.
 LDA TOKTYP
 CMP #TKPUNC
 BNE CEPBAD
 LDA TOKBUF
 CMP #$28
 BNE CEPBAD
 INC CEDEP
 LDA CEDEP
 CMP #CEMAX
 BCS CEPDEEP
 JSR CEEXPR
 BCS CEPX
 JSR CEOP
 BCS CEPBAD
 CMP #$29
 BNE CEPBAD
 DEC CEDEP
 CLC
 RTS
* an item or a literal: push it
CEP2 LDA PDVAL
 STA EMWV
 LDA PDVAL+1
 STA EMWV+1
 LDA PDKIND
 BEQ CEP3
 CMP #1
 BNE CEPBAD
 LDA #OPUSHL
 JMP EMOP1
CEP3 LDA #OPUSHD
 JMP EMOP1
* An error already set - the pool full (3) as an
* operand was stored - is the one to report; 23
* over it said "invalid expression" about a line
* that was perfectly good (2026-11-11).
CEPBAD LDA CMPERR
 BNE CEPX
 LDA #23
 STA CMPERR
CEPX SEC
 RTS
CEPDEEP LDA #25
 STA CMPERR
 SEC
 RTS

* ---- CEOP: the next token, if it is punctuation -
* out: A = the character, C=0
*      C=1 and the token is HELD if it is not
* The lexer returns + - * / ( ) and = as TKPUNC with
* the character in TOKBUF, which is what PDRELOP
* already relies on.
CEOP JSR PDNEXT
 BCS CEOX
 LDA TOKTYP
 CMP #TKPUNC
 BNE CEOHD
 LDA TOKBUF
 CLC
 RTS
* The comment above always said HELD; the code
* never set it, so the verb after a COMPUTE that
* ended without a full stop was read as the end of
* the expression and thrown away (FIXLIST A6).
CEOHD LDA #1
 STA PDHELD
 SEC
 RTS
CEOX SEC
 RTS

* ================= EVALUATE =====================
* Slice 6, 2026-08-16.
*
*   EVALUATE WS-CHOICE
*       WHEN "1" PERFORM ADD-ITEM
*       WHEN "2" PERFORM LIST-ALL
*       WHEN OTHER PERFORM COMPLAIN
*   END-EVALUATE
*
* lowers to exactly what a person would write by
* hand:
*
*       CMPx subj, "1"
*       BNE  W2
*       <stmt>
*       BRA  END
*   W2  CMPx subj, "2"
*       BNE  W3
*       <stmt>
*       BRA  END
*   W3  <stmt>
*   END
*
* TWO KINDS OF FORWARD REFERENCE, AND THEY ARE NOT
* THE SAME SHAPE.  The BNE goes to the NEXT WHEN, so
* there is one outstanding at a time and it is
* patched by the next WHEN or by END-EVALUATE - one
* variable.  The BRAs all go to the SAME place and
* there may be any number of them, so they are a
* CHAIN - and the chain is EMREF and EMFIX, the
* paragraph fixup machinery, used on something that
* is not a paragraph.  FIXHD is a plain variable, so
* nothing had to change to lend it out.
*
* WHAT IS NOT HERE: EVALUATE TRUE with condition
* names.  LEADS.COB uses it and it needs an 88 to
* compile to a test, which IF cannot do either - so
* it is one piece of work that fixes both, and it is
* not this one.  Error 26 says which it was.

EVMAX EQU 4

* ---- EVALUATE subject ---------------------------
PDEVAL LDA NEVS
 CMP #EVMAX
 BCC PDEV1
 LDA #27
 STA CMPERR
 RTS
PDEV1 JSR PDQOPT
 BCS PDEV1A
 CMP #22
 BNE PDEVBAD
* EVALUATE TRUE: each WHEN is a whole condition.
* The subject is marked $FFFF and PDWHEN compiles a
* condition instead of a compare - and a condition
* name is the common case, which is the whole reason
* the form exists
 LDA #$FF
 STA PDVAL
 STA PDVAL+1
 JMP PDEV2
PDEV1A JSR PDOPND
 BCS PDEVBAD
 LDA PDKIND
 BNE PDEVBAD
* A subscripted subject would be read through its
* slot at every WHEN, and the statements between the
* WHENs reuse the slots: refused, error 38
 LDA PDVAL+1
 CMP #$FF
 BNE PDEV2
 LDA #38
 STA CMPERR
 RTS
PDEV2 JSR EVPUSH
 LDA PDVAL
 STA EVSUBJ
 LDA PDVAL+1
 STA EVSUBJ+1
 JSR EVSAVE
 RTS
PDEVBAD LDA #23
 STA CMPERR
 RTS

* ---- WHEN value / WHEN OTHER --------------------
PDWHEN LDA NEVS
 BNE PDWH1
 LDA #28
 STA CMPERR
 RTS
* close the previous WHEN, if there was one: its
* statements are done, so jump to the end, and its
* BNE lands here
PDWH1 JSR EVLOAD
 LDA EVOPEN
 BEQ PDWH2
 JSR EVBRAEND
 BCC PDWH1A
 RTS
PDWH1A JSR EVPATCH
PDWH2 JSR PDQOPT
 BCC PDWH2A
* not a keyword: a VALUE (WHEN "1", WHEN 3, WHEN X),
* which PDQOPT has held for PDOPND.  Only nothing at
* all - the end of the source - is an error.  It
* used to call every WHEN value an error (23).
 LDA PDHELD
 BNE PDWH3
 JMP PDWHBAD
PDWH2A
* WHEN OTHER has no compare and no branch: it is
* simply the code that runs when nothing matched
 CMP #18
 BNE PDWH3
 STZ EVOPEN
 JMP EVSAVE
PDWH3 LDA #1
 STA PDHELD
* EVALUATE TRUE: the WHEN is a condition, and
* PDCOND emits the compare AND the inverse branch,
* so the BNE below is already done
 LDA EVSUBJ
 AND EVSUBJ+1
 CMP #$FF
 BNE PDWH3A
 JSR PDCOND
 BCC PDWH3C
 RTS
PDWH3C LDA PDT
 STA EVNEXT
 LDA PDT+1
 STA EVNEXT+1
 LDA #1
 STA EVOPEN
 JMP EVSAVE
PDWH3A JSR PDOPND
 BCC PDWH3M
 JMP PDWHBAD
* a literal WHEN value becomes a temp item first:
* CMPN/CMPA take item numbers, never pool offsets
PDWH3M JSR PDMAT
 BCC PDWH3B
 RTS
PDWH3B
* the compare: subject first, because the compare is
* CMPx left, right and the subject is the left-hand
* side of the COBOL relation
 LDA EVSUBJ
 STA EMWV
 LDA EVSUBJ+1
 STA EMWV+1
 LDA PDVAL
 STA EMWV2
 LDA PDVAL+1
 STA EMWV2+1
 LDA PDKIND
 CMP #1
 BEQ PDWH4
 LDA EVSUBJ
 STA EMIT
 LDA EVSUBJ+1
 STA EMIT+1
 JSR EMDGET
 LDA DTYP
 CMP #TNUMB
 BEQ PDWH5
PDWH4 LDA #OCMPA
 JMP PDWH6
PDWH5 LDA #OCMPN
PDWH6 JSR EMOP2
 BCS PDWHX2
* the BNE to the next WHEN, with a placeholder
 STZ EMWV
 STZ EMWV+1
 LDA #OBNE
 JSR EMB
 BCS PDWHX2
 LDA CODLEN
 STA EVNEXT
 LDA CODLEN+1
 STA EVNEXT+1
 JSR EMW
 BCS PDWHX2
 LDA #1
 STA EVOPEN
 JMP EVSAVE
* Its own exit: PDWHX is at the head of the routine
* and the compare-and-branch block is past a branch
* from here.
PDWHX2 RTS
PDWHBAD LDA #23
 STA CMPERR
PDWHX RTS

* ---- END-EVALUATE -------------------------------
PDENDEV LDA NEVS
 BNE PDEE1
 LDA #28
 STA CMPERR
 RTS
PDEE1 JSR EVLOAD
 LDA EVOPEN
 BEQ PDEE2
* the last WHEN was a value, so it needs its jump to
* the end and its BNE patched to here
 JSR EVBRAEND
 BCS PDEEX
 JSR EVPATCH
* every BRA in the chain now lands here
PDEE2 LDA EVCHN
 STA FIXHD
 LDA EVCHN+1
 STA FIXHD+1
 LDA CODLEN
 STA EMTGT
 LDA CODLEN+1
 STA EMTGT+1
 JSR EMFIX
 DEC NEVS
PDEEX RTS

* ---- EVBRAEND: BRA onto the exit chain ----------
* EMREF threads the placeholder onto FIXHD and hands
* back a new head.  It was written for paragraph
* references and knows nothing about either.
EVBRAEND LDA EVCHN
 STA FIXHD
 LDA EVCHN+1
 STA FIXHD+1
 LDA #OBRA
 JSR EMREF
 BCS EVBEX
 LDA FIXHD
 STA EVCHN
 LDA FIXHD+1
 STA EVCHN+1
 CLC
EVBEX RTS

* ---- EVPATCH: the pending BNE lands here --------
EVPATCH LDA EVNEXT
 STA EMWO
 LDA EVNEXT+1
 STA EMWO+1
 LDA CODLEN
 STA EMWV
 LDA CODLEN+1
 STA EMWV+1
 JMP EMSETW

* ---- the EVALUATE stack -------------------------
* Six bytes an entry: the subject, the exit chain
* head, and the pending BNE.  Four deep, which is
* three more than the sample programs use and one
* more than anybody should write.
EVPUSH LDA #$FF
 STA EVCHN
 STA EVCHN+1
 STZ EVOPEN
 STZ EVNEXT
 STZ EVNEXT+1
 INC NEVS
 RTS
EVSAVE JSR EVSTX
 LDY #0
EVSV1 LDA EVSUBJ,Y
 STA EVSTK,X
 INX
 INY
 CPY #7
 BCC EVSV1
 RTS
EVLOAD JSR EVSTX
 LDY #0
EVLD1 LDA EVSTK,X
 STA EVSUBJ,Y
 INX
 INY
 CPY #7
 BCC EVLD1
 RTS
* X = 7 * (NEVS-1)
EVSTX LDA NEVS
 SEC
 SBC #1
 STA PDQN
 ASL
 ASL
 ASL
 SEC
 SBC PDQN
 TAX
 RTS

* ============ LITERAL ARITHMETIC ================
* ADD 1 TO X becomes PUSHD X / PUSHL 1 / EADD /
* POPD X.  The stack ops take the operands the
* right way round for all four verbs: SUBTRACT 1
* FROM X is X-1 because the item was pushed first,
* and DIVIDE 2 INTO X is X/2 for the same reason.
*
* The literal keeps its scale in the pool and PUSHL
* carries it onto the stack, and since 2026-11-08
* the stack operators line scales up properly - so
* ADD 1.5 TO X adds 1.5.  It used to be refused with
* error 29.
* The emit is PDARTL's now (CMPPROC4.S), which
* sends GIVING and ROUNDED this way too; the table
* stays here, beside the comment that explains it.
EOPTAB DFB OEADD,OESUB,OEMUL,OEDIV

* ============ MATERIALISING A LITERAL ===========
* IF X < 11 and WHEN "1" have to compare against an
* ITEM - CMPN and CMPA resolve descriptors, and a
* pool offset handed to them reads a descriptor
* that is not there.  So a literal operand becomes
* one: MOVL into a temp the compiler makes for
* itself, once, on first use.  MOVL already reads
* the pool the way the DESTINATION says - eight raw
* bytes into a NUM8 temp, length-prefixed text into
* an X(30) - so the split costs nothing new.
* The GIVING lowering, when it comes, reuses this.
*
* NOTHING CALLED IT until 2026-11-07, so ADD 1 TO X
* compiled as ADD X TO X and IF X < 11 compared
* against "item 18" - the literal's pool offset.
* PDARITH, PDCOND (both sides) and WHEN call it now.
* One temp per type, so IF 1 < 2 - both sides
* literal - would compare the temp with itself.
* An item comes back untouched with C=0.
PDMAT LDA PDKIND
 BNE PDMT0
 CLC
 RTS
PDMT0 CMP #1
 BEQ PDMT1
 CMP #2
 BEQ PDMTF
 LDA #13
 STA CMPERR
 SEC
 RTS
* a FIGURATIVE: IF X = ZERO, IF N = SPACES.  ZERO
* goes into the numeric temp and the rest into the
* text one, by MOVF - the same instruction MOVE
* ZERO TO X uses.  PDVAL holds its index.
PDMTF LDA PDVAL
 CMP #1
 BNE PDMTF1
 STZ LITSCL
 JSR PDTNUM
 BCS PDMTX
 JMP PDMTF2
PDMTF1 JSR PDTALP
 BCS PDMTX
PDMTF2 LDA PDQT2
 STA EMWV
 LDA PDQT2+1
 STA EMWV+1
 LDA #OMOVF
 JSR EMB
 BCS PDMTX
 JSR EMW
 BCS PDMTX
 LDA PDVAL
 JSR EMB
 BCS PDMTX
 JMP PDMTE
PDMT1 LDA PDLTYP
 BNE PDMTN
 JSR PDTALP
 BCS PDMTX
 JMP PDMTGO
* A numeric literal goes into the temp of its own
* scale, so IF X < 1.5 compares with 1.5 - CMPN
* lines the scales up (2026-11-08).  PDTNUM refuses
* more than four decimals with error 29.
PDMTN JSR PDTNUM
 BCS PDMTX
PDMTGO LDA PDQT2
 STA EMWV
 LDA PDQT2+1
 STA EMWV+1
 LDA PDVAL
 STA EMWV2
 LDA PDVAL+1
 STA EMWV2+1
 LDA #OMOVL
 JSR EMOP2
 BCS PDMTX
PDMTE LDA PDQT2
 STA PDVAL
 LDA PDQT2+1
 STA PDVAL+1
 STZ PDKIND
 CLC
PDMTX RTS
* ---- PDTALP / PDTNUM: the temp -> PDQT2 ---------
* Made on first use, one of each per compile.
PDTALP LDA PDTAI
 AND PDTAI+1
 CMP #$FF
 BNE PDTA9
 LDA #TALPHA
 STA DTYP
 LDA #30
 STA DLENV
 JSR PDMTMK
 BCS PDTX
 LDA EMIT
 STA PDTAI
 LDA EMIT+1
 STA PDTAI+1
PDTA9 LDA PDTAI
 STA PDQT2
 LDA PDTAI+1
 STA PDQT2+1
 CLC
PDTX RTS
* PDTNUM: one numeric temp PER SCALE, 0 to 4
* decimals, chosen by LITSCL.  A temp's descriptor
* says its scale and MOVL shifts the literal to it,
* so a literal keeps exactly the digits it was
* written with and nothing is ever shifted off the
* top.  Five words of PDTNI, $FFFF until made.
PDTNUM LDA LITSCL
 CMP #5
 BCC PDTN1
 LDA #29
 STA CMPERR
 SEC
 RTS
PDTN1 ASL
 TAX
 STX PDTNX
 LDA PDTNI,X
 AND PDTNI+1,X
 CMP #$FF
 BNE PDTN9
 LDA #TNUMB
 STA DTYP
 LDA #8
 STA DLENV
 LDA LITSCL
 STA DDECV
 JSR PDMTM2
 BCS PDTX
 LDX PDTNX
 LDA EMIT
 STA PDTNI,X
 LDA EMIT+1
 STA PDTNI+1,X
PDTN9 LDX PDTNX
 LDA PDTNI,X
 STA PDQT2
 LDA PDTNI+1,X
 STA PDQT2+1
 CLC
 RTS
* one temp from DTYP/DLENV - EMALLOC hands it DSEG
* space and EMDESC writes descriptor NITEMS, which
* pass two may grow: NITEMS crosses in CMPXFR and
* CMPWRT writes whatever it says
PDMTMK STZ DDECV
PDMTM2 STZ DFLGV
 STZ DEDTV
 STZ DEDTV+1
 JSR EMALLOC
 JMP EMDESC
