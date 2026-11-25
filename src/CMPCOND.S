* CMPCOND.S  conditions - IF, PERFORM UNTIL, WHEN
* PUT from COMPILE2.S - no ORG, not assembled alone.
* One symbol table spans every PUT.  Its own file
* because CMPPROC.S would otherwise pass Merlin 8's
* 24K PUT limit.  Added 2026-11-07; rewritten
* 2026-11-08 (FIXLIST B) as a real grammar:
*
*   cond    := and { OR and }
*   and     := not { AND not }
*   not     := NOT not | ( cond ) | simple
*   simple  := a rel b | a IS [NOT] class | cond-name
*            | rel b            (the subject left out)
*            | b                (subject and relation)
*
* so AND binds tighter than OR, parentheses group,
* and A = 1 OR 2 and A > 1 AND < 10 mean what they
* say.  The old one took one kind of joiner per
* condition and refused a mix with error 23.
*
* JUMPING CODE.  Each simple condition is a compare
* and a branch taken when it is FALSE, and falls
* through when it is TRUE.  Every condition, however
* built, keeps that shape: it falls through when TRUE
* and ends with a branch taken when its last test
* fails.  The other exits are two lists of branches
* not yet aimed - T, taken when the whole condition
* is true, and F, when it is false - and the last
* branch is always the head of F.
*
* THE LISTS COST NO MEMORY.  A branch's target word
* is a placeholder until it is aimed, and while it
* waits it holds the offset of the next placeholder
* on its list, 0 at the end.  A list is just the
* offset of its first placeholder.
*
*   a AND b   T of a -> the start of b; F = F(b)+F(a)
*   a OR b    a's last branch turned round onto T;
*             the rest of F(a) -> the start of b
*   NOT a     a's last branch turned round onto F;
*             the rest of F(a) becomes T
*
* The caller still gets ONE placeholder in PDT, taken
* when the condition is false - or, with PDCTRU set
* (PERFORM UNTIL), when it is true - so IF, ELSE,
* PERFORM and WHEN did not change.

* ---- PDCOND: a whole condition -----------------
* in:  PDCTRU 1 = branch when TRUE (used and cleared)
* out: PDT = the placeholder, C=1 on error
PDCOND LDA PDCTRU
 STA PDCWNT
 STZ PDCTRU
 STZ PDCSV
 STZ PDCDP
 JSR CXOR
 BCC PDCZ0
 RTS
* PERFORM UNTIL: the branch it wants is the one
* taken when the condition holds - NOT, once more
PDCZ0 LDA PDCWNT
 BEQ PDCZ1
 JSR CXNEG
* one false exit is the placeholder the caller gets
PDCZ1 LDA PDCF
 STA EMWO
 LDA PDCF+1
 STA EMWO+1
 JSR EMGETW
 LDA EMWV
 ORA EMWV+1
 BNE PDCZ2
 JSR CXTHERE
 LDA PDCF
 STA PDT
 LDA PDCF+1
 STA PDT+1
 CLC
 RTS
* several: they all go to one BRA, which is the
* caller's.  BRA OK / L: BRA <PDT> / OK:
PDCZ2 JSR PDCBRA
 BCS PDCZX
 LDA PDT
 STA PDCOK
 LDA PDT+1
 STA PDCOK+1
 LDX #2
 JSR CXHERE
 JSR PDCBRA
 BCS PDCZX
 LDA PDCOK
 STA EMWO
 LDA PDCOK+1
 STA EMWO+1
 JSR PDCHERE
 JSR CXTHERE
 CLC
PDCZX RTS

* ---- CXOR: and { OR and } ----------------------
CXOR JSR CXAND
 BCS CXOX
CXO1 JSR PDCJN
 BCS CXOOK
 CMP #2
 BEQ CXO2
* an AND here was not ours to take: hand it back
 LDA #1
 STA PDHELD
CXOOK CLC
CXOX RTS
* the last branch turned round onto T, the rest of
* F aimed at the next term
CXO2 JSR CXNEG
 JSR CXSWAP
 LDX #2
 JSR CXHERE
 LDA PDCT
 PHA
 LDA PDCT+1
 PHA
 JSR CXAND
 PLA
 STA PDCQ+1
 PLA
 STA PDCQ
 BCS CXOX
 LDX #0
 JSR CXCAT
 JMP CXO1

* ---- CXAND: not { AND not } ---------------------
CXAND JSR CXNOT
 BCS CXAX
CXA1 JSR PDCJN
 BCS CXAOK
 CMP #1
 BEQ CXA2
 LDA #1
 STA PDHELD
CXAOK CLC
CXAX RTS
* true so far: on to the next term
CXA2 JSR CXTHERE
 LDA PDCF
 PHA
 LDA PDCF+1
 PHA
 JSR CXNOT
 PLA
 STA PDCQ+1
 PLA
 STA PDCQ
 BCS CXAX
 LDX #2
 JSR CXCAT
 JMP CXA1

* ---- CXNOT: NOT not | ( cond ) | simple ---------
CXNOT JSR PDNEXT
 BCS CXNB
 LDA TOKTYP
 CMP #TKPUNC
 BNE CXN1
 LDA TOKBUF
 CMP #$28
 BEQ CXPAR
 BNE CXNH
CXN1 CMP #TKWORD
 BNE CXNH
 LDA TOKLEN
 CMP #3
 BNE CXNH
 LDA TOKBUF
 CMP #$4E
 BNE CXNH
 LDA TOKBUF+1
 CMP #$4F
 BNE CXNH
 LDA TOKBUF+2
 CMP #$54
 BNE CXNH
 JSR CXNOT
 BCS CXNX
 JSR CXNEG
 CLC
CXNX RTS
* a simple condition: one branch, the head of F
CXNH LDA #1
 STA PDHELD
 JSR PDCND1
 BCS CXNX
 LDA PDT
 STA PDCF
 LDA PDT+1
 STA PDCF+1
 STZ PDCT
 STZ PDCT+1
 CLC
 RTS
CXNB LDA #23
 STA CMPERR
 SEC
 RTS
* ( cond ): eight deep at most, as COMPUTE's are -
* the 6502's stack is what holds the nesting
CXPAR LDA PDCDP
 CMP #8
 BCC CXP1
 LDA #25
 STA CMPERR
 SEC
 RTS
CXP1 INC PDCDP
 JSR CXOR
 DEC PDCDP
 BCS CXNX
 JSR PDNEXT
 BCS CXNB
 LDA TOKTYP
 CMP #TKPUNC
 BNE CXNB
 LDA TOKBUF
 CMP #$29
 BNE CXNB
 CLC
 RTS

* ---- CXNEG: NOT ---------------------------------
* The last branch (the head of F) is turned round
* and stays on F, with T after it; the rest of F
* becomes T.
CXNEG LDA PDCF
 STA EMWO
 LDA PDCF+1
 STA EMWO+1
 JSR EMGETW
 LDA EMWV
 STA PDCQ
 LDA EMWV+1
 STA PDCQ+1
 JSR CXFLIP
 LDA PDCF
 STA EMWO
 LDA PDCF+1
 STA EMWO+1
 LDA PDCT
 STA EMWV
 LDA PDCT+1
 STA EMWV+1
 JSR EMSETW
 LDA PDCQ
 STA PDCT
 LDA PDCQ+1
 STA PDCT+1
 RTS

* ---- CXSWAP: T and F change places --------------
CXSWAP LDX PDCT
 LDA PDCF
 STA PDCT
 STX PDCF
 LDX PDCT+1
 LDA PDCF+1
 STA PDCT+1
 STX PDCF+1
 RTS

* ---- CXFLIP: turn the head of F's branch round --
* BEQ<->BNE, BLT<->BGE, BGT<->BLE.  The opcode is the
* byte in front of its placeholder.
*   The new opcode goes back through EMSETW, as a
* WORD: EMGETW read the byte after it into EMWV+1,
* so that byte is written back unchanged.  It used
* to be STA (ZPT1),Y - a store into the old main-
* memory code buffer.  Since the code moved to aux
* (CODAUX, 2026-11-22) that store hit nothing, and
* every PERFORM UNTIL and every NOT ran backwards:
* FIXLIST A25.
CXFLIP SEC
 LDA PDCF
 SBC #1
 STA EMWO
 LDA PDCF+1
 SBC #0
 STA EMWO+1
 JSR EMGETW
 LDA EMWV
 SEC
 SBC #OBEQ
 TAX
 LDA FLIPT,X
 STA EMWV
 JMP EMSETW
* indexed by opcode - BEQ BNE BLT BGT BLE BGE
FLIPT DFB OBNE,OBEQ,OBGE,OBLE,OBGT,OBLT

* ---- CXTHERE / CXHERE: aim a list here ----------
* X = 0 the T list, 2 the F list.  It is empty after.
CXTHERE LDX #0
CXHERE LDA PDCT,X
 STA PDCP
 LDA PDCT+1,X
 STA PDCP+1
 STZ PDCT,X
 STZ PDCT+1,X
CXH1 LDA PDCP
 ORA PDCP+1
 BEQ CXH9
 LDA PDCP
 STA EMWO
 LDA PDCP+1
 STA EMWO+1
 JSR EMGETW
 LDA EMWV
 STA PDCP
 LDA EMWV+1
 STA PDCP+1
 JSR PDCHERE
 JMP CXH1
CXH9 RTS

* ---- CXCAT: list X (0 T, 2 F) += the list PDCQ ---
* PDCQ goes on the END, so the head - the last
* branch, for F - stays where it is
CXCAT LDA PDCT,X
 ORA PDCT+1,X
 BNE CXC1
 LDA PDCQ
 STA PDCT,X
 LDA PDCQ+1
 STA PDCT+1,X
 RTS
CXC1 LDA PDCT,X
 STA EMWO
 LDA PDCT+1,X
 STA EMWO+1
CXC2 JSR EMGETW
 LDA EMWV
 ORA EMWV+1
 BEQ CXC3
 LDA EMWV
 STA EMWO
 LDA EMWV+1
 STA EMWO+1
 JMP CXC2
CXC3 LDA PDCQ
 STA EMWV
 LDA PDCQ+1
 STA EMWV+1
 JMP EMSETW

* ---- PDCJN: is the next word AND (1) or OR (2)? --
* C=1 and the token held if it is neither
PDCJN JSR PDNEXT
 BCS PDCJH
 LDA TOKTYP
 CMP #TKWORD
 BNE PDCJH
 JSR PDANDOR
 BCC PDCJX
PDCJH LDA #1
 STA PDHELD
 SEC
PDCJX RTS

* PDCHERE: the word at EMWO gets CODLEN
PDCHERE LDA CODLEN
 STA EMWV
 LDA CODLEN+1
 STA EMWV+1
 JMP EMSETW
* PDCBRA: BRA <placeholder>; PDT = its operand
PDCBRA STZ EMWV
 STZ EMWV+1
 LDA #OBRA
 JSR EMB
 BCS PDCBX
 LDA CODLEN
 STA PDT
 LDA CODLEN+1
 STA PDT+1
 JMP EMW
PDCBX RTS
* PDANDOR: TOKBUF is AND (A=1) or OR (A=2), C=0
PDANDOR LDA TOKLEN
 CMP #2
 BNE PDAO3
 LDA TOKBUF
 CMP #$4F
 BNE PDAONO
 LDA TOKBUF+1
 CMP #$52
 BNE PDAONO
 LDA #2
 CLC
 RTS
PDAO3 CMP #3
 BNE PDAONO
 LDA TOKBUF
 CMP #$41
 BNE PDAONO
 LDA TOKBUF+1
 CMP #$4E
 BNE PDAONO
 LDA TOKBUF+2
 CMP #$44
 BNE PDAONO
 LDA #1
 CLC
 RTS
PDAONO SEC
 RTS

* ---- PDTHEN: an optional THEN after IF's condition
* The condition always ends by reading one word too
* many - it had to, to see whether AND or OR came
* next - and hands that word back through PDHELD.
* If the word is THEN it belongs to the IF: drop it,
* and the next read gets the true part's first verb.
* Anything else stays held for the statement it
* starts.  THEN is optional in COBOL and common in
* code from other compilers; it used to be read as
* an unknown verb (2026-11-11).
PDTHEN LDA PDHELD
 BEQ PDTHX
 LDA TOKTYP
 CMP #TKWORD
 BNE PDTHX
 LDA TOKLEN
 CMP #4
 BNE PDTHX
 LDX #0
PDTH1 LDA TOKBUF,X
 CMP WTHEN,X
 BNE PDTHX
 INX
 CPX #4
 BCC PDTH1
 STZ PDHELD
PDTHX RTS
WTHEN ASC 'THEN'

* ================= ONE SIMPLE CONDITION ==========
* ---- PDCND1 -------------------------------------
* out: PDT = the placeholder of a branch taken when
*      the condition is FALSE; C=1 on error
* (Moved here from CMPPROC.S, 2026-11-08.)
* The condition is a <rel> b, a class or sign test,
* or a CONDITION NAME - an 88 - which is a compare
* with both halves and the relation looked up rather
* than read: parent = literal, branch on NE.
* NOT in front of any of them is CXNOT's business.
*
* THE ABBREVIATED FORMS.  PDCSUB and PDCRL keep the
* subject and the relation of the last relation in
* this condition, PDCSV saying they are there.  A
* term with no subject - A > 1 AND < 10 - borrows the
* subject; a term that is a lone operand - A = 1 OR 2
* - borrows both.
PDCND1 STZ PDCNOT
 JSR PDOPND
 BCC PDCN1
* no operand: a relation with the subject left out?
 LDA PDCSV
 BEQ PDCNE
 JSR PDRSTA
 BCS PDCNE
 STZ CMPERR
 LDA #1
 STA PDHELD
 LDA PDCSUB
 STA PDSVAL
 LDA PDCSUB+1
 STA PDSVAL+1
 STZ PDSKND
 JMP PDCNR
PDCNE LDA CMPERR
 BNE PDCNE1
 LDA #23
 STA CMPERR
PDCNE1 SEC
 RTS
PDCN1 LDA PDKIND
 BNE PDCN2
 LDA PDCKND
 CMP #KCOND
 BNE PDCN2
 STZ PDCSV
 JMP PDCN88
PDCN2 JSR PDMAT
 BCC PDCN2A
 RTS
PDCN2A JSR PDSAVE
PDCNR JSR PDRELOP
 BCC PDCNR1
* an operand and no relation: A = 1 OR 2's "2" -
* if nothing was read past it, it is handed back
 LDA PDCSV
 BEQ PDCNE
 LDA PDRCON
 BNE PDCNE
 LDA #1
 STA PDHELD
 LDA PDCSUB
 STA PDSVAL
 LDA PDCSUB+1
 STA PDSVAL+1
 LDA PDCRL
 STA PDREL
 JMP PDCN2B
PDCNR1 LDA PDRCLS
 BEQ PDCNR2
 JMP PDCNCL
PDCNR2 JSR PDOPND
 BCS PDCNE
* IF X < 11: the 11 becomes a temp item (PDMAT)
PDCN2B JSR PDMAT
 BCS PDCNX
* kept for an abbreviated term after this one
 LDA PDSVAL
 STA PDCSUB
 LDA PDSVAL+1
 STA PDCSUB+1
 LDA PDREL
 STA PDCRL
 LDA #1
 STA PDCSV
* left operand first
 LDA PDSVAL
 STA EMWV
 LDA PDSVAL+1
 STA EMWV+1
 LDA PDVAL
 STA EMWV2
 LDA PDVAL+1
 STA EMWV2+1
 LDA PDSVAL
 STA EMIT
 LDA PDSVAL+1
 STA EMIT+1
 JSR EMDGET
 LDA DTYP
 CMP #TNUMB
 BEQ PDI1
 LDA #OCMPA
 JMP PDI2
PDI1 LDA #OCMPN
PDI2 JSR EMOP2
 BCS PDCNX
* the branch taken when it is FALSE: the inverse
* relation, with a placeholder target
PDCNBR LDX PDREL
 LDA INVBR,X
 STA PDOP
 STZ EMWV
 STZ EMWV+1
 LDA PDOP
 JSR EMB
 BCS PDCNX
 LDA CODLEN
 STA PDT
 LDA CODLEN+1
 STA PDT+1
 JMP EMW
PDCNX RTS

* ---- a class or sign condition ------------------
* X IS [NOT] NUMERIC, ALPHABETIC, ALPHABETIC-UPPER,
* ALPHABETIC-LOWER, POSITIVE, NEGATIVE, ZERO.
*   CLASS item, test, 0
* CLASS answers 0 for TRUE, the condition register's
* EQ, so the relation is EQ - NE after a NOT - and
* the branch after it is the ordinary one.  The test
* number is CLASS.S's, picked here by the item's
* type: NUMERIC on a number checks the cell, on text
* checks for digits.  POSITIVE and NEGATIVE on text,
* and ALPHABETIC on a number, are error 13.
PDCNCL STZ PDCSV
 LDA PDSKND
 BNE PDCCB
 LDA PDSVAL
 STA EMIT
 LDA PDSVAL+1
 STA EMIT+1
 JSR EMDGET
 LDX PDRCLS
 LDA DTYP
 CMP #TNUMB
 BEQ PDCC1
 LDA CLTTXT-1,X
 JMP PDCC2
PDCC1 LDA CLTNUM-1,X
PDCC2 CMP #$FF
 BEQ PDCCB
 STA PDCLC
 LDA #OCLASS
 JSR EMB
 BCS PDCCX
 LDA PDSVAL
 STA EMWV
 LDA PDSVAL+1
 STA EMWV+1
 JSR EMW
 BCS PDCCX
 LDA PDCLC
 JSR EMB
 BCS PDCCX
 STZ EMWV
 STZ EMWV+1
 JSR EMW
 BCS PDCCX
 JMP PDCNBR
PDCCB LDA #13
 STA CMPERR
 SEC
PDCCX RTS
* PDRCLS 1-7: NUMERIC ALPHABETIC -UPPER -LOWER
* POSITIVE NEGATIVE ZERO -> CLASS.S's test numbers
CLTTXT DFB 0,3,4,5,$FF,$FF,9
CLTNUM DFB 2,$FF,$FF,$FF,6,7,8

* ---- a condition name ---------------------------
* CMPx parent, literal - and the relation is EQ, so
* the inverse branch is BNE.  Text or numeric is
* read off the PARENT, as it is for any other
* compare.  The 88's VALUE is a LITERAL - a pool
* offset - and CMPN/CMPA take item numbers, so it
* goes through PDMAT into a temp first, as text or
* as a number by the parent's type.  It went in as a
* pool offset read as an item: IF NOT STAT-OK
* compared FILE-STAT with WS-EOF (MEDIA, 2026-11-07).
PDCN88 LDA PDCPAR
 STA EMIT
 LDA PDCPAR+1
 STA EMIT+1
 JSR EMDGET
 LDX #0
 LDA DTYP
 CMP #TNUMB
 BNE PDC88A
 INX
PDC88A STX PDLTYP
 LDA #1
 STA PDKIND
 STZ LITSCL
 JSR PDMAT
 BCC PDC88B
 RTS
PDC88B LDA PDCPAR
 STA EMWV
 LDA PDCPAR+1
 STA EMWV+1
 LDA PDVAL
 STA EMWV2
 LDA PDVAL+1
 STA EMWV2+1
 LDA PDCPAR
 STA EMIT
 LDA PDCPAR+1
 STA EMIT+1
 JSR EMDGET
 LDA DTYP
 CMP #TNUMB
 BEQ PDCN3
 LDA #OCMPA
 JMP PDCN4
PDCN3 LDA #OCMPN
PDCN4 JSR EMOP2
 BCS PDC8X
 STZ PDREL
 JMP PDCNBR
PDC8X RTS
* EQ NE LT LE GT GE -> the branch taken when FALSE
INVBR DFB OBNE,OBEQ,OBGE,OBGT,OBLE,OBLT
* the opposite relation: EQ<->NE, LT<->GE, LE<->GT
INVREL DFB 1,0,5,4,3,2

* ================= THE RELATION =================
* ---- PDRELOP: the relation ----------------------
* (Moved here from CMPPROC2.S, 2026-11-08.)
* out: C=0, PDREL 0 EQ 1 NE 2 LT 3 LE 4 GT 5 GE, and
*      PDRCLS 0 - or 1-7, a class or sign test, with
*      PDREL EQ or NE.
*      C=1 if there is no relation; PDRCON 0 then
*      means only one token was read, and it is in
*      TOKBUF for the caller to hand back.
*   =  <  >  <=  >=                 the symbols
*   [IS] [NOT] GREATER [THAN]       and LESS
*   [IS] [NOT] GREATER THAN OR EQUAL [TO]
*   [IS] [NOT] EQUAL [TO]
*   [IS] [NOT] NUMERIC ... ZERO     the class words
* NOT turns the relation over: NOT LESS is GE.  It
* used to flip the low bit, which makes NOT LESS
* into LE - and >=, <=, THAN and TO were not read.
PDRELOP STZ PDRNOT
 STZ PDRCLS
 STZ PDRCON
 JSR PDNEXT
 BCS PDRX
PDRL1 LDA TOKTYP
 CMP #TKPUNC
 BNE PDRL0
 JMP PDRSYM
PDRL0 CMP #TKWORD
 BNE PDRX
 LDX #<RLKW
 LDY #>RLKW
 JSR PDRKW
 BCS PDRX
 CMP #2
 BCS PDRL2
* IS, or NOT
 CMP #1
 BNE PDRL1A
 STA PDRNOT
PDRL1A INC PDRCON
 JSR PDNEXT
 BCS PDRX
 JMP PDRL1
PDRX SEC
 RTS
* NOT, if there was one, and done
PDRDN LDA PDRNOT
 BEQ PDRD1
 LDX PDREL
 LDA INVREL,X
 STA PDREL
PDRD1 CLC
 RTS
PDRL2 CMP #5
 BCS PDRCL
 TAX
 LDA PDRWV-2,X
 STA PDREL
 CPX #4
 BEQ PDREQW
* GREATER / LESS [THAN] [OR EQUAL [TO]]
 JSR PDRPK
 BCS PDRDN
 CMP #0
 BNE PDRG1
 JSR PDRPK
 BCS PDRDN
PDRG1 CMP #2
 BNE PDRHLD
* OR: then it must be EQUAL
 INC PDRCON
 JSR PDNEXT
 BCS PDRX
 LDA TOKTYP
 CMP #TKWORD
 BNE PDRX
 LDX #<RLKW2
 LDY #>RLKW2
 JSR PDRKW
 BCS PDRX
 CMP #3
 BNE PDRX
 INC PDREL
* EQUAL [TO]
PDREQW JSR PDRPK
 BCS PDRDN
 CMP #1
 BEQ PDRDN
PDRHLD LDA #1
 STA PDHELD
 JMP PDRDN
* a class or sign word
PDRCL TAX
 LDA PDRCV-5,X
 STA PDRCLS
 STZ PDREL
 JMP PDRDN
* = < > and <= >= - the lexer makes two tokens of
* the second pair
PDRSYM LDA TOKBUF
 CMP #$3D
 BNE PDRS1
 STZ PDREL
 JMP PDRDN
PDRS1 CMP #$3C
 BEQ PDRS2
 CMP #$3E
 BEQ PDRS4
 SEC
 RTS
PDRS4 LDA #4
 BNE PDRS3
PDRS2 LDA #2
PDRS3 STA PDREL
 JSR PDNEXT
 BCS PDRSH
 LDA TOKTYP
 CMP #TKPUNC
 BNE PDRSH
 LDA TOKBUF
 CMP #$3D
 BNE PDRSH
 INC PDREL
 JMP PDRDN
PDRSH LDA #1
 STA PDHELD
 JMP PDRDN
* GREATER LESS EQUAL -> GT LT EQ
PDRWV DFB 4,2,0
* NUMERIC ... ZEROES -> PDRCLS
PDRCV DFB 1,2,3,4,5,6,7,7,7

* ---- PDRPK: the next word, if it is one of these
* THAN (0) TO (1) OR (2) EQUAL (3) - C=0, A = which.
* Anything else is held, C=1.  The caller holds a
* word it was not expecting, too.
PDRPK JSR PDNEXT
 BCS PDRPH
 LDA TOKTYP
 CMP #TKWORD
 BNE PDRPH
 LDX #<RLKW2
 LDY #>RLKW2
 JSR PDRKW
 BCC PDRPX
PDRPH LDA #1
 STA PDHELD
 SEC
PDRPX RTS

* ---- PDRSTA: can TOKBUF begin a relation? -------
* For A > 1 AND < 10: = < > or IS GREATER LESS EQUAL
PDRSTA LDA TOKTYP
 CMP #TKPUNC
 BNE PDRSW
 LDA TOKBUF
 CMP #$3C
 BEQ PDRSY
 CMP #$3D
 BEQ PDRSY
 CMP #$3E
 BEQ PDRSY
 SEC
 RTS
PDRSW CMP #TKWORD
 BNE PDRSN
 LDX #<RLKW
 LDY #>RLKW
 JSR PDRKW
 BCS PDRSN
 CMP #1
 BEQ PDRSN
 CMP #5
 BCS PDRSN
PDRSY CLC
 RTS
PDRSN SEC
 RTS

* ---- PDRKW: TOKBUF in the word list at X/Y ------
* out: C=0 A = its index; C=1 not there
* A list is length-prefixed words, 0 at the end.
PDRKW STX ZPT2
 STY ZPT2+1
 STZ PDRKI
PDRK1 LDY #0
 LDA (ZPT2),Y
 BEQ PDRKN
 CMP TOKLEN
 BNE PDRK3
 TAX
PDRK2 INY
 LDA (ZPT2),Y
 CMP TOKBUF-1,Y
 BNE PDRK3
 DEX
 BNE PDRK2
 LDA PDRKI
 CLC
 RTS
PDRK3 LDY #0
 LDA (ZPT2),Y
 SEC
 ADC ZPT2
 STA ZPT2
 BCC PDRK4
 INC ZPT2+1
PDRK4 INC PDRKI
 JMP PDRK1
PDRKN SEC
 RTS
* 0 IS 1 NOT 2 GREATER 3 LESS 4 EQUAL 5 NUMERIC
* 6 ALPHABETIC 7 -UPPER 8 -LOWER 9 POSITIVE
* 10 NEGATIVE 11 ZERO 12 ZEROS 13 ZEROES
RLKW DFB 2
 ASC 'IS'
 DFB 3
 ASC 'NOT'
 DFB 7
 ASC 'GREATER'
 DFB 4
 ASC 'LESS'
 DFB 5
 ASC 'EQUAL'
 DFB 7
 ASC 'NUMERIC'
 DFB 10
 ASC 'ALPHABETIC'
 DFB 16
 ASC 'ALPHABETIC-UPPER'
 DFB 16
 ASC 'ALPHABETIC-LOWER'
 DFB 8
 ASC 'POSITIVE'
 DFB 8
 ASC 'NEGATIVE'
 DFB 4
 ASC 'ZERO'
 DFB 5
 ASC 'ZEROS'
 DFB 6
 ASC 'ZEROES'
 DFB 0
* 0 THAN 1 TO 2 OR 3 EQUAL
RLKW2 DFB 4
 ASC 'THAN'
 DFB 2
 ASC 'TO'
 DFB 2
 ASC 'OR'
 DFB 5
 ASC 'EQUAL'
 DFB 0
