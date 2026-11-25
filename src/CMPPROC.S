* CMPPROC.S  PROCEDURE DIVISION - COMPILE slice 5
* PUT from COMPILE.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* Pass two.  Statements in, p-code out.  Every byte
* it emits is specified in COMPILE.md 3, which was
* transcribed from the handlers that execute them.
*
* THE DESTINATION IS EMITTED FIRST.
* VMOVN calls VOPD before VOPS, so MOVE X TO Y is
* the opcode, then Y, then X - the opposite order to
* the way COBOL writes it.  Backwards it still runs
* and quietly moves the wrong way, which is why it
* is said here as well as in the design.
*
* A FORWARD PERFORM COSTS NO MEMORY.
* The operand word of an unresolved reference holds
* the offset of the PREVIOUS unresolved reference,
* and the symbol holds the head of that list.  So a
* paragraph referred to nine times before it is
* defined has nine placeholders threaded together in
* the code stream itself, and defining it walks them
* - reading each link out before overwriting it.
*
* WHAT IS HERE
*   paragraph names, MOVE, DISPLAY (screen and
*   printer), ACCEPT, ADD/SUBTRACT/MULTIPLY/DIVIDE,
*   IF/ELSE/END-IF, PERFORM, PERFORM THRU, GO TO,
*   STOP RUN, GOBACK, EXIT, CONTINUE
* WHAT IS NOT
*   COMPUTE (slice 6, and it needs the expression
*   evaluator), EVALUATE, the file verbs - which
*   trap in the interpreter anyway - and the
*   three-operand GIVING forms, which COMPILE.md 3
*   says to lower as MOVN + the two-operand form and
*   which slice 5a does not yet do.

IFMAX EQU 8

* ---- PDNEXT: the next token, held or new --------
* A statement that reads one word too far hands it
* back by setting PDHELD.  Only PROCDIV used to look
* at that flag; everything else went to the lexer
* and silently skipped the held word - WHEN "1" lost
* its "1", ADD A B GIVING lost its B (2026-11-07).
* Every token read in the PROCEDURE DIVISION comes
* through here now.  C=1 at end of source, as LEXNEXT.
PDNEXT LDA PDHELD
 BEQ PDNX1
 STZ PDHELD
 LDA TOKTYP
 CMP #TKEOF
 BEQ PDNX2
 CLC
 RTS
PDNX2 SEC
 RTS
PDNX1 JMP LEXNEXT

* ---- PROCDIV: the whole division ---------------
PROCDIV LDA #0
 STA NIFS
 LDA #$FF
 STA PDCUR
 LDA #0
 STA PDONE
 STA PDHELD
 STA PDQDEP
* A statement with an OPTIONAL trailing clause has
* to read the word that might not be the clause,
* and the lexer cannot un-read it.  PDHELD says the
* token in TOKBUF was read by the last statement
* and belongs to this one.
* An error stops here, BEFORE the next token is
* read: reading it first moved TOKLIN on, and
* DISPLAY WS-NOPE on line 8 was reported at line 9.
PD1 LDA CMPERR
 BNE PDX
 LDA PDHELD
 BEQ PD1R
 STZ PDHELD
 JMP PD1C
PD1R JSR PDNEXT
 BCS PD9
PD1C LDA LEXERR
 BNE PDX
 LDA CMPERR
 BNE PDX
 LDA TOKTYP
 CMP #TKPUNC
 BNE PD1W
* a full stop ends the sentence and its open IFs
 LDA TOKBUF
 CMP #$2E
 BNE PD1
 JSR PDDOT
 JMP PD1
PD1W CMP #TKWORD
 BNE PD1
* Area A is a paragraph name or a division header;
* Area B is a statement.  That difference is the
* whole of fixed-form COBOL's grammar and it is why
* the lexer hands back a column.
 LDA TOKCOL
 CMP #6
 BCS PDSTMT
 JSR PDHDR
 BCS PD1
* a paragraph cannot start inside an IF
 JSR PDOPEN
 BCS PDX
* CALLED, not jumped to: PDPARA returns (through
* SYMADD's RTS), and a JMP made that RTS leave
* PROCDIV after the first paragraph - "Compiled,
* 3 bytes" and nothing in it (2026-11-07).
 JSR PDPARA
 JMP PD1
PDSTMT JSR PDLMK
 JSR PDDISP
 JMP PD1
* end of source: every paragraph must have been
* defined, and a program that runs off the end
* without STOP RUN gets one anyway
* the last paragraph ends at the end of the source
PD9 JSR PDOPEN
 BCS PDX
 LDA PDCUR
 CMP #$FF
 BEQ PD9A
 JSR PDRETC
PD9A LDA #OHALT
 JSR EMOP
 JSR PDUNDEF
 RTS
PDX RTS

* ---- PDHDR: PROCEDURE or DIVISION? --------------
* out: C=1 if the word was a header and was eaten
* The two words of PROCEDURE DIVISION arrive
* separately and neither is a paragraph.
PDHDR LDX #0
PDH1 LDA HDRTAB,X
 BEQ PDHNO
 STX PDWS
 LDY #0
PDH2 CPY TOKLEN
 BCS PDHYES
 INX
 LDA HDRTAB,X
 CMP TOKBUF,Y
 BNE PDH3
 INY
 JMP PDH2
PDH3 LDX PDWS
 TXA
 CLC
 ADC HDRTAB,X
 TAX
 INX
 JMP PDH1
PDHYES LDX PDWS
 LDA HDRTAB,X
 CMP TOKLEN
 BNE PDHNO
 SEC
 RTS
PDHNO CLC
 RTS
HDRTAB DFB 9
 ASC 'PROCEDURE'
 DFB 8
 ASC 'DIVISION'
 DFB 7
 ASC 'SECTION'
 DFB 0

* ================= PARAGRAPHS ==================
* ---- PDPARA: define the paragraph in TOKBUF -----
* If it has been referred to already, its chain is
* walked here and every placeholder in the code
* stream is filled in with where we have got to.
* The paragraph before this one ends here, so its
* RET goes out first - RET n returns only if the
* innermost PERFORM ends at paragraph n, and falls
* through otherwise, which is how one paragraph can
* be both PERFORMed and fallen into.  No RET was ever
* emitted, so a PERFORMed paragraph never came back
* and ran on into the next (MEDIA, 2026-11-07).
PDPARA LDA PDCUR
 CMP #$FF
 BEQ PDPA0
 JSR PDRETC
 BCS PDPDX
PDPA0 JSR SYMFIND
 BCS PDPNEW
 JSR SYMGET
 LDA SYKIND
 CMP #KPARA
 BNE PDPDUP
 LDA SYMVAL
 CMP #$FF
 BNE PDPDUP
 LDA SYMVAL+1
 CMP #$FF
 BNE PDPDUP
* it was forward referenced: resolve the chain
 LDA CODLEN
 STA EMTGT
 LDA CODLEN+1
 STA EMTGT+1
 JSR SYMCHG
 JSR EMFIX
 JSR SYMCHS
 LDA CODLEN
 STA SYMVAL
 LDA CODLEN+1
 STA SYMVAL+1
 JSR SYMPUT
 JMP PDPCUR
PDPNEW LDA CODLEN
 STA SYMVAL
 LDA CODLEN+1
 STA SYMVAL+1
 LDA #KPARA
 JSR SYMADD
* this paragraph is the current one now
PDPCUR LDA SYMIX
 STA PDCUR
PDPDX RTS
* PDRETC: RET <PDCUR>, the current paragraph ends
PDRETC LDA #ORET
 JSR EMB
 BCS PDRCX
 LDA PDCUR
 JMP EMB
PDRCX RTS
PDPDUP LDA #10
 STA CMPERR
 RTS

* ---- PDREF: emit a reference to the paragraph ---
* in: A = the opcode, TOKBUF = the name
* Defined or not, the operand word goes out; what
* differs is whether it holds the answer or a link.
PDREF STA PDOP
 JSR SYMFIND
 BCC PDR1
* never seen: enter it undefined, chain empty
 LDA #$FF
 STA SYMVAL
 STA SYMVAL+1
 LDA #KPARA
 JSR SYMADD
 BCC PDR1
 RTS
PDR1 JSR SYMGET
 LDA SYKIND
 CMP #KPARA
 BNE PDRBAD
 LDA SYMVAL
 CMP #$FF
 BNE PDRHAVE
 LDA SYMVAL+1
 CMP #$FF
 BNE PDRHAVE
* undefined: thread this reference onto its chain
 JSR SYMCHG
 LDA PDOP
 JSR EMREF
 JMP SYMCHS
PDRHAVE LDA SYMVAL
 STA EMWV
 LDA SYMVAL+1
 STA EMWV+1
 LDA PDOP
 JMP EMOP1
PDRBAD LDA #11
 STA CMPERR
 RTS

* ---- PDUNDEF: any paragraph still undefined? ----
PDUNDEF LDA #0
 STA SYMIX
PDU1 LDA SYMIX
 CMP NSYMS
 BCS PDU9
 JSR SYMGET
 LDA SYKIND
 CMP #KPARA
 BNE PDU2
 LDA SYMVAL
 AND SYMVAL+1
 CMP #$FF
 BNE PDU2
 LDA #11
 STA CMPERR
 RTS
PDU2 INC SYMIX
 JMP PDU1
PDU9 RTS

* ================= STATEMENTS ==================
* ---- PDDISP: dispatch one statement -------------
PDDISP LDA #0
 STA PDVN
* every statement starts with all four subscript
* slots free (PDOSUB, CMPPROC4.S)
 STZ PDSUBN
 LDX #0
PDD1 LDA VERBTAB,X
 BEQ PDD9
 STX PDWS
 LDY #0
PDD2 CPY TOKLEN
 BCS PDD5
 INX
 LDA VERBTAB,X
 CMP TOKBUF,Y
 BNE PDD3
 INY
 JMP PDD2
PDD3 LDX PDWS
 TXA
 CLC
 ADC VERBTAB,X
 TAX
 INX
 INC PDVN
 JMP PDD1
PDD5 LDX PDWS
 LDA VERBTAB,X
 CMP TOKLEN
 BNE PDD3
 JMP PDGO
* not a verb we know.  A statement we cannot compile
* has to stop the compile: skipping it would produce
* a program that runs and silently does less than it
* says.
* END-ADD, END-SUBTRACT, END-MULTIPLY, END-DIVIDE and
* END-COMPUTE (ENDWT, CMPPROC3) are punctuation,
* like END-READ: the ON SIZE ERROR clause is one
* statement, so there is nothing for them to close.
* They live outside VERBTAB, which is full.
* SET is in ENDWT too, at SETW (2026-11-11): the
* same table, because VERBTAB is still full.
PDD9 LDX #ENDWT-RELWT
 JSR PFRW1
 BCS PDD9B
 LDA PFRT
 CMP #SETW-RELWT
 BEQ PDD9S
 RTS
PDD9S JMP PDSET
PDD9B LDA #12
 STA CMPERR
 RTS

VERBTAB DFB 4
 ASC 'MOVE'
 DFB 7
 ASC 'DISPLAY'
 DFB 6
 ASC 'ACCEPT'
 DFB 3
 ASC 'ADD'
 DFB 8
 ASC 'SUBTRACT'
 DFB 8
 ASC 'MULTIPLY'
 DFB 6
 ASC 'DIVIDE'
 DFB 2
 ASC 'IF'
 DFB 4
 ASC 'ELSE'
 DFB 6
 ASC 'END-IF'
 DFB 7
 ASC 'PERFORM'
 DFB 2
 ASC 'GO'
 DFB 4
 ASC 'STOP'
 DFB 6
 ASC 'GOBACK'
 DFB 4
 ASC 'EXIT'
 DFB 8
 ASC 'CONTINUE'
 DFB 5
 ASC 'QUERY'
 DFB 4
 ASC 'OPEN'
 DFB 5
 ASC 'CLOSE'
 DFB 4
 ASC 'READ'
 DFB 5
 ASC 'WRITE'
 DFB 7
 ASC 'REWRITE'
 DFB 6
 ASC 'DELETE'
 DFB 5
 ASC 'START'
 DFB 7
 ASC 'COMPUTE'
 DFB 8
 ASC 'EVALUATE'
 DFB 4
 ASC 'WHEN'
 DFB 12
 ASC 'END-EVALUATE'
 DFB 11
 ASC 'END-PERFORM'
 DFB 8
 ASC 'END-READ'
 DFB 9
 ASC 'END-WRITE'
 DFB 11
 ASC 'END-REWRITE'
 DFB 9
 ASC 'END-START'
 DFB 10
 ASC 'END-DELETE'
* 249 bytes: PDDISP walks it with X, so it is full.
* More words go in a table of their own - ENDWT,
* below, for END-ADD and the rest.
 DFB 0

PDGO LDA PDVN
 CMP #0
 BNE PDG1
 JMP PDMOVE
PDG1 CMP #1
 BNE PDG2
 JMP PDDSP0
PDG2 CMP #2
 BNE PDG3
 JMP PDACC
PDG3 CMP #7
 BNE PDG4
 JMP PDIF
PDG4 CMP #8
 BNE PDG5
 JMP PDELSE
PDG5 CMP #9
 BNE PDG6
 JMP PDENDIF
PDG6 CMP #10
 BNE PDG7
 JMP PDPERF
PDG7 CMP #11
 BNE PDG8
 JMP PDGOTO
PDG8 CMP #12
 BNE PDG9
 JMP PDSTRUN
PDG9 CMP #13
 BNE PDG10
 JMP PDSTOP
PDG10 CMP #14
 BEQ PDGNUL
 CMP #15
 BEQ PDGNUL
 CMP #16
 BNE PDG10A
 JMP PDQUERY
PDG10A CMP #24
 BCC PDG10B
 JMP PDG12
PDG10B CMP #17
 BCC PDG11
 JMP PDFILE
* 3 to 6 are the four arithmetic verbs, and they
* differ only in one opcode byte.  PDARSZ wraps them
* in the size-error check (CMPPROC4).
PDG11 JMP PDARSZ
* 24-27: COMPUTE, EVALUATE, WHEN, END-EVALUATE
PDG12 CMP #24
 BNE PDG13
 JMP PDCOSZ
PDG13 CMP #25
 BNE PDG14
 JMP PDEVAL
PDG14 CMP #26
 BNE PDG15
 JMP PDWHEN
PDG15 CMP #27
 BNE PDG16
 JMP PDENDEV
PDG16 CMP #28
 BNE PDG17
 JMP PDENDPF
* 29-33: END-READ, END-WRITE, END-REWRITE, END-START,
* END-DELETE.  The file verbs have no nested scope
* to close - the clause is one statement and the
* statement ends it - so these are punctuation and
* emit nothing, exactly as EXIT and CONTINUE do.
PDG17 RTS
* EXIT and CONTINUE are no-ops by definition.  They
* emit nothing at all, not even a NOP: a paragraph
* that exists to be PERFORMed THRU needs a name and
* not an instruction.
PDGNUL RTS

* ---- MOVE <source> TO <dest> --------------------
PDMOVE JSR PDOPND
 BCC PDMV1
 RTS
PDMV1 JSR PDSAVE
 JSR PDWORD
 BCC PDMV2
 RTS
PDMV2 JSR PDOPND
 BCC PDMV3
 RTS
PDMV3 LDA PDKIND
 BEQ PDMV4
 JMP PDMBAD
* the destination's item number goes out FIRST
PDMV4 LDA PDVAL
 STA EMWV
 LDA PDVAL+1
 STA EMWV+1
 LDA PDSVAL
 STA EMWV2
 LDA PDSVAL+1
 STA EMWV2+1
 LDA PDSKND
* which MOVE, from the two types: CMPPROC4 PDMVTY
 JMP PDMVTY
PDMFIG LDA #OMOVF
 JSR EMB
 BCS PDMX
 JSR EMW
 BCS PDMX
 LDA PDSVAL
 JMP EMB
PDMBAD LDA #13
 STA CMPERR
PDMX RTS

* ---- DISPLAY <thing> [UPON <device>] ------------
* The device is a byte in the instruction, so more
* than one printer costs nothing: SPECIAL-NAMES gave
* each slot a mnemonic and the mnemonic is an index.
* DISPLAY a b "c" ... [UPON PRINTER]
* Each operand is its own DISP or DISPL and there is
* no newline between them - which needs a DISP that
* does NOT end the line.  VDISP always does, so a
* multi-operand DISPLAY to the screen is emitted as
* a run of DISPs and READS AS A RUN OF LINES until
* VDISP grows a no-newline variant.  Stated here
* rather than hidden: the samples print 'CHOICE? '
* and then ACCEPT on the same line, and that will
* come out on two lines until the VM side is done.
* PDDST is where this DISPLAY's code starts, kept so
* that an AT found after the operands can put the
* cursor move in front of them (PDDAT, CMPPROC3).
* DISPLAY ERASE first (CMPSET.S): it may be all
* there is, or it may come before the operands
PDDSP0 JSR PDERAS
 BCS PDDSPA
 CMP #0
 BNE PDDSPA
 RTS
PDDSPA LDA CODLEN
 STA PDDST
 LDA CODLEN+1
 STA PDDST+1
 STZ PDDNOP
PDDSPL JSR PDOPND
 BCC PDDSP1
 RTS
* DISPLAY ZERO / SPACE: a figurative is a number,
* not an item, and was displayed AS item number 0
* or 1 (FIXLIST A16).  PDMAT puts it in a temp.
PDDSP1 LDA PDKIND
 CMP #2
 BNE PDDSP2
 JSR PDMAT
 BCC PDDSP2
 RTS
PDDSP2 JSR PDSAVE
 JSR PDUPON
 LDA PDDEV
 BNE PDDPR
* to the screen
* every operand goes out as the NO-NEWLINE form, and
* the opcode byte of the LAST one is patched to the
* newline form once we know it was the last.  That
* is one byte written twice, against the alternative
* of reading one token further ahead than the lexer
* can hand back.
PDDS0 LDA CODLEN
 STA PDDLOP
 LDA CODLEN+1
 STA PDDLOP+1
 JSR PDDREC
 LDA PDSVAL
 STA EMWV
 LDA PDSVAL+1
 STA EMWV+1
 LDA PDSKND
 CMP #1
 BEQ PDDSL
 LDA #ODISPN
 JMP PDDS1
PDDSL LDA #ODISPLN
PDDS1 JSR EMOP1
 BCC PDDS1A
 RTS
PDDS1A
* another operand?  A word that is not a keyword, a
* literal, or a figurative constant continues the
* DISPLAY; anything else is the next statement and
* PDUPON has already handed it back
 LDA PDHELD
 BEQ PDDLST
 LDA TOKTYP
 CMP #TKSTR
 BEQ PDDS2
 CMP #TKNUM
 BEQ PDDS2
 CMP #TKWORD
 BNE PDDLST
 JSR PDQKW
 BCC PDDKW
 JSR SYMFIND
 BCC PDDS2
 JSR PDISFG
 BCS PDDLST
PDDS2 JMP PDDSPL
* AT is QKWTAB word 9: the DISPLAY is positioned
PDDKW CMP #9
 BNE PDDLST
 JMP PDDAT
* that was the last: patch its opcode to end the
* line.  PDSKND still says which form the last one
* was, so there is nothing to read back.  EMSETW
* writes a WORD; the byte after the opcode is the
* low byte of the operand we already emitted, so it
* is read first and written back unchanged.
PDDLST LDA PDDLOP
 STA EMWO
 LDA PDDLOP+1
 STA EMWO+1
 JSR EMGETW
 LDA PDSKND
 CMP #1
 BEQ PDDL1
 LDA #ODISP
 JMP PDDL2
PDDL1 LDA #ODISPL
PDDL2 STA EMWV
 JMP EMSETW
* to a printer: opcode, device byte, then the operand
* - for the LAST operand.  UPON comes after all of
* them, so every operand before it has already gone
* out as a SCREEN DISPN or DISPLN; PDDPAT turns
* those into their printer forms first.  Until
* 2026-11-22 it did not, and DISPLAY A " " B UPON
* PRINTER sent A and the space to the screen and
* only B to the printer (FIXLIST A22).
PDDPR JSR PDDPAT
 BCC PDDPR1
 RTS
PDDPR1 LDA PDSKND
 CMP #1
 BEQ PDDPL
 LDA #ODISPP
 JMP PDDPE
PDDPL LDA #ODISPPL
PDDPE JSR EMB
 BCS PDDX
 LDA PDDEV
 JSR EMB
 BCS PDDX
 LDA PDSVAL
 STA EMWV
 LDA PDSVAL+1
 STA EMWV+1
 JMP EMW
PDDX RTS

* ---- PDDREC: where this operand's opcode is -----
* Kept for every operand that goes out in the screen
* form, sixteen at most, in case an UPON PRINTER
* turns up after them.  The count goes on past
* sixteen so PDDPAT can tell that some were not kept.
PDDREC LDA PDDNOP
 CMP #16
 BCS PDDRC9
 ASL
 TAX
 LDA CODLEN
 STA PDDOFS,X
 LDA CODLEN+1
 STA PDDOFS+1,X
PDDRC9 INC PDDNOP
 RTS

* ---- PDDPAT: screen forms -> printer forms ------
* DISPN ($84) becomes DISPPN ($97) and DISPLN ($8A)
* DISPPLN ($98); the operand word stays.  EMGETW
* reads the opcode and the operand's low byte as one
* word, so both go back unchanged but the opcode.
* More than sixteen operands before UPON PRINTER is
* error 13 rather than a line half on the screen.
* out: C=1 on that error
PDDPAT LDA PDDNOP
 CMP #17
 BCC PDDPT0
 LDA #13
 STA CMPERR
 SEC
 RTS
PDDPT0 STZ PDDI
PDDPT1 LDA PDDI
 CMP PDDNOP
 BCS PDDPT9
 ASL
 TAX
 LDA PDDOFS,X
 STA EMWO
 LDA PDDOFS+1,X
 STA EMWO+1
 JSR EMGETW
 LDA EMWV
 CMP #ODISPN
 BNE PDDPT2
 LDA #ODISPPN
 JMP PDDPT3
PDDPT2 LDA #ODISPPLN
PDDPT3 STA EMWV
 JSR EMSETW
 INC PDDI
 JMP PDDPT1
PDDPT9 CLC
 RTS
PDDNOP DFB 0
PDDI DFB 0
PDDOFS DS 32

* (PDUPON and PDACC are in CMPPROC4.S)

* ---- ADD a TO b / SUBTRACT a FROM b / ... -------
* dest = dest op src, so ADD B TO A is ADDP A, B.
* The connecting word - TO, FROM, BY, INTO - is read
* and thrown away: which verb it was has already
* been decided and the words cannot be interchanged
* in the subset.
* ADD a TO b                  ADDP b, a
* ADD a TO b GIVING c         PUSHD b PUSHD a EADD POPD c
* ADD a b GIVING c            the same - a missing TO
*                             is read as the form with
*                             GIVING, which COBOL allows
* ... ROUNDED                 the stack form, POPDR
* (PDARTL in CMPPROC4.S says why.)
* ADD ZERO TO X has no meaning worth compiling: a
* figurative here was taken as an item number (A16)
PDARITH LDA PDVN
 STA PDAVN
 JSR PDOPND
 BCS PDARX0
 LDA PDKIND
 CMP #2
 BNE PDARI1
 JMP PDARB
* any token, not PDWORD: a literal second operand
* with no TO is legal with GIVING (2026-11-11)
PDARI1 JSR PDSAVE
 JSR PDNEXT
 BCS PDARX0
 JMP PDARW
PDARX0 RTS
* was that TO/FROM/BY/INTO, or is it already the
* second operand?  A data name here means the
* connecting word was left out, which is legal only
* with GIVING
* It asked PDQKW, whose table has no TO - so TO was
* taken for the second operand.  That only worked
* because PDOPND used to skip a held word; once it
* stopped, ADD 1 TO X said "unknown data name".
* PDCONW asks the real question (2026-11-07).
* PDARBY remembers that the word was BY: DIVIDE a BY
* b is a / b, the other way round from INTO.
* A number or a quoted literal here is the second
* operand too: ADD X 20 GIVING Y read the 20 as its
* TO and threw it away (found 2026-11-11).
PDARW STZ PDARBY
 LDA TOKTYP
 CMP #TKWORD
 BNE PDARSEC
 JSR PDCONW
 BCS PDARSEC
 LDA PFRT
 CMP #CONWT-RELWT+8
 BNE PDAR0
 INC PDARBY
PDAR0 JSR PDOPND
 BCS PDARX0
 JMP PDAR1
* the token in hand IS the second operand
PDARSEC LDA #1
 STA PDHELD
 JSR PDOPND
 BCS PDARX0
* The second operand may be a literal now - DIVIDE X
* BY 2 GIVING C - but only with GIVING, where it is
* moved and not written to: PDARG2 refuses it as a
* destination.
PDAR1 LDA PDVAL
 STA PDAR2V
 LDA PDVAL+1
 STA PDAR2V+1
 LDA PDKIND
 STA PDAR2K
* DIVIDE a BY b: swap, and it is DIVIDE b INTO a.
* It was compiled as INTO, so DIVIDE 10 BY 4 GIVING
* C gave 0.4 (2026-11-08, FIXLIST A8).
 LDA PDARBY
 BEQ PDAR1C
 LDA PDAVN
 CMP #6
 BNE PDAR1C
 LDX PDSVAL
 LDA PDAR2V
 STA PDSVAL
 STX PDAR2V
 LDX PDSVAL+1
 LDA PDAR2V+1
 STA PDSVAL+1
 STX PDAR2V+1
 LDX PDSKND
 LDA PDAR2K
 STA PDSKND
 STX PDAR2K
PDAR1C LDA PDAR2K
 CMP #2
 BCC PDAR1A
 JMP PDARB
* GIVING, ROUNDED and the emit are in CMPPROC4.S
PDAR1A JMP PDARTL
PDARB LDA #13
 STA CMPERR
PDARX RTS
ARIOPS DFB OADDP,OSUBP,OMULP,ODIVP

* ---- IF a <rel> b -------------------------------
* The compare and the branch are always a pair, and
* the branch goes on the OPPOSITE relation: the code
* that follows is the true part, so the jump is what
* happens when it is false.
PDIF JSR PDCOND
 BCS PDIX
* an optional THEN after the condition (CMPCOND)
 JSR PDTHEN
 JMP PDIPUSH
PDIX RTS

* (PDCOND, PDCND1, the condition names and the
* relation tables are in CMPCOND.S since 2026-11-08.)

* ---- ELSE ---------------------------------------
* Jump over the else-part, then point the IF's
* branch here.  One entry on the stack does both:
* it is replaced, not added to.
PDELSE LDA #0
 STA EMWV
 STA EMWV+1
 LDA #OBRA
 JSR EMB
 BCS PDEX
 LDA CODLEN
 STA PDT
 LDA CODLEN+1
 STA PDT+1
 JSR EMW
 BCS PDEX
* The new placeholder rides the 6502 stack across
* PDIPOP, which loads the IF's into PDT.  It used to
* be lost there: the IF's was pushed back instead,
* END-IF patched it a second time, and the ELSE's
* jump stayed at zero - every IF/ELSE looped back to
* the start of the program (2026-11-07).
 LDA PDT
 PHA
 LDA PDT+1
 PHA
 JSR PDIPOP
 JSR PDIHERE
 PLA
 STA PDT+1
 PLA
 STA PDT
 JMP PDIPUSH
PDEX RTS

* ---- END-IF -------------------------------------
PDENDIF JSR PDIPOP
 JMP PDIHERE

* ---- the IF stack -------------------------------
PDIPUSH LDA NIFS
 CMP #IFMAX
 BCC PDIP1
 LDA #14
 STA CMPERR
 RTS
PDIP1 LDA NIFS
 ASL
 TAX
 LDA PDT
 STA IFSTK,X
 LDA PDT+1
 STA IFSTK+1,X
 INC NIFS
 RTS
PDIPOP LDA NIFS
 BNE PDIO1
 LDA #14
 STA CMPERR
 RTS
PDIO1 DEC NIFS
 LDA NIFS
 ASL
 TAX
 LDA IFSTK,X
 STA PDT
 LDA IFSTK+1,X
 STA PDT+1
 RTS
* PDIHERE: the placeholder at PDT gets where we are
PDIHERE LDA PDT
 STA EMWO
 LDA PDT+1
 STA EMWO+1
 LDA CODLEN
 STA EMWV
 LDA CODLEN+1
 STA EMWV+1
 JMP EMSETW

* (continued in CMPPROC2.S - Merlin 8 cannot PUT a
* file over about 24K, so the PROCEDURE parser is
* three files.  COMPILE2 PUTs all three, in order.)
