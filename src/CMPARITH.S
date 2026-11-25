* CMPARITH.S  PROCEDURE DIVISION: the arithmetic
* PUT from COMPILE2.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* Split from CMPPROC4.S on 2026-11-11, when ON SIZE
* ERROR and REMAINDER took it past Merlin 8's 24K
* PUT-file limit.  PUT straight after CMPPROC4, so
* the code is in the order it was.

* ================= ARITHMETIC ==================
* ---- PDARSZ / PDCOSZ: the size-error wrapper ----
* Every ADD, SUBTRACT, MULTIPLY, DIVIDE and COMPUTE
* goes out as
*
*     SZON  <the statement>  SZCHK
*
* or, with [ON] SIZE ERROR,
*
*     SZON  <the statement>  BSIZ E
*     BRA P
*   E <the one statement>
*   P ...
*
* which is AT END's layout through PDQCLS, so the
* clause is one statement - or an IF, EVALUATE or
* inline PERFORM and everything to its end - exactly
* as a file verb's is.  SZON turns the run time's
* checking on for this statement only: the
* compiler's own arithmetic (VARYING, TIMES) is not
* the programmer's and is never checked.  SZCHK with
* no clause stops the run on a size error - the
* user's choice, 2026-11-11: a business program does
* not go on with a wrong number.  See VMMATH, SIZE
* ERRORS, for what a size error is.
* NOT ON SIZE ERROR is not built: NOT is handed back
* and read as a statement, error 12.
PDARSZ LDA #OSZON
 JSR EMB
 BCS PDSZX
 JSR PDARITH
 BRA PDSZ0
PDCOSZ LDA #OSZON
 JSR EMB
 BCS PDSZX
 JSR PDCOMP
PDSZ0 LDA CMPERR
 BNE PDSZX
* the statement may have handed a word back: ON or
* SIZE is the clause, anything else is the next
* statement's and stays held
 JSR PDQOPT
 BCS PDSZN
 CMP #7
 BNE PDSZ1
 JSR PDQNEED
 BCS PDSZB
 CMP #26
 BNE PDSZB
 BRA PDSZ2
PDSZ1 CMP #26
 BNE PDSZH
PDSZ2 JSR PDQNEED
 BCS PDSZB
 CMP #8
 BNE PDSZB
 LDA #OBSIZ
 JSR EMB
 BCS PDSZX
 LDA #1
 STA PDQHAS
 JMP PDQCLS
PDSZH LDA #1
 STA PDHELD
PDSZN LDA #OSZCHK
 JMP EMB
* ON without SIZE ERROR, or SIZE without ERROR
PDSZB LDA #16
 STA CMPERR
PDSZX RTS

* ---- PDARTL: GIVING, ROUNDED, and the emit -------
* in: PDSVAL/PDSKND the first operand, PDAR2V/
*     PDAR2K the second, PDAVN the verb (3-6)
* ADD a TO b with two items and nothing after goes
* out as ADDP.  Everything else - a literal a,
* GIVING, ROUNDED - goes the expression-stack way:
*     PUSH b  PUSH a  EADD (ESUB EMUL EDIV)  POPD d
* d is b, or c with GIVING; POPDR when ROUNDED.
* The stack keeps every digit at its own scale until
* the store, so ROUNDED has digits to round on
* (FIXLIST A15) - ADDP cuts its source to the
* destination's scale before it adds.  And GIVING
* used to start with MOVN c, b, which cut b to c's
* decimals before the arithmetic: ADD .05 TO 1.06
* GIVING C, PIC 9V9, gave 1.0 and not 1.1.
PDARTL STZ EMMODE
 STZ PDARGV
 STZ PDARRM
 LDA PDAR2V
 STA PDARDV
 LDA PDAR2V+1
 STA PDARDV+1
 JSR PDQOPT
 BCS PDAT5
 CMP #6
 BNE PDAT3
 JSR PDOPND
 BCS PDAEX
 LDA PDKIND
 BNE PDARE
 LDA PDVAL
 STA PDARDV
 LDA PDVAL+1
 STA PDARDV+1
 INC PDARGV
 JSR PDQOPT
 BCS PDAT5
* ROUNDED and REMAINDER are the only words allowed
* after; anything else belongs to the next statement
PDAT3 CMP #23
 BEQ PDAT4
 CMP #27
 BEQ PDATR
PDATH LDA #1
 STA PDHELD
 BRA PDAT5
PDAT4 INC EMMODE
* ROUNDED may have REMAINDER after it
 JSR PDQOPT
 BCS PDAT5
 CMP #27
 BNE PDATH
 JMP PDATR
* without GIVING, b is written to: an item only
PDAT5 LDA PDARGV
 BNE PDAT6
 LDA PDAR2K
 BNE PDARE
 LDA EMMODE
 ORA PDSKND
 BNE PDAT6
 LDA PDARDV
 STA EMWV
 LDA PDARDV+1
 STA EMWV+1
 LDA PDSVAL
 STA EMWV2
 LDA PDSVAL+1
 STA EMWV2+1
 LDX PDAVN
 LDA ARIOPS-3,X
 JMP EMARI
* the error exit, in the middle so both halves reach
PDARE LDA #13
 STA CMPERR
 SEC
PDAEX RTS
* REMAINDER r: DIVIDE with GIVING only, and r an
* item (2026-11-11)
PDATR LDA PDAVN
 CMP #6
 BNE PDARE
 LDA PDARGV
 BEQ PDARE
 JSR PDOPND
 BCS PDAEX
 LDA PDKIND
 BNE PDARE
 LDA PDVAL
 STA PDARRV
 LDA PDVAL+1
 STA PDARRV+1
 INC PDARRM
 JMP PDAT5
* the stack form
PDAT6 JSR PDATQ
 BCS PDAEX
 LDA PDARRM
 BEQ PDAT6A
 JMP PDATRE
PDAT6A LDA PDARDV
 STA EMWV
 LDA PDARDV+1
 STA EMWV+1
 LDA #OPOPD
 LDX EMMODE
 BEQ PDAT7
 LDA #OPOPDR
PDAT7 JMP EMOP1

* ---- PDATPU: push EMWV - an item (X=0) or a
* literal (X=1) ------------------------------------
PDATPU CPX #2
 BCS PDARE
 LDA #OPUSHD
 CPX #0
 BEQ PDTP1
 LDA #OPUSHL
PDTP1 JMP EMOP1

* ---- PDATQ: PUSH b  PUSH a  <the operator> -------
PDATQ LDA PDAR2V
 STA EMWV
 LDA PDAR2V+1
 STA EMWV+1
 LDX PDAR2K
 JSR PDATPU
 BCS PDATQX
 LDA PDSVAL
 STA EMWV
 LDA PDSVAL+1
 STA EMWV+1
 LDX PDSKND
 JSR PDATPU
 BCS PDATQX
 LDX PDAVN
 LDA EOPTAB-3,X
 JMP EMOP
PDATQX RTS

* ---- PDATRE: DIVIDE ... GIVING q REMAINDER r -----
* The remainder is the dividend less the quotient
* AS STORED times the divisor - COBOL's rule, so a
* quotient cut to q's decimals gives the remainder
* that goes with it:
*
*     (b a EDIV, from PDATQ)  POPD q
*     SZSKP L                   q failed: leave r
*     PUSH b  PUSH q  PUSH a  EMUL  ESUB  POPD r
*     [PUSH b  PUSH a  EDIV  POPDR q]   ROUNDED
*   L
*
* With ROUNDED, q is stored twice: truncated first,
* for the remainder, then rounded.  If only the
* rounding overflows, q keeps the truncated value
* rather than its old one - a corner COBOL would
* leave q untouched in, and not worth a temporary.
PDATRE LDA PDARDV
 STA EMWV
 LDA PDARDV+1
 STA EMWV+1
 LDA #OPOPD
 JSR EMOP1
 BCS PDATQX
 LDA #OSZSKP
 JSR EMB
 BCS PDATQX
 LDA CODLEN
 STA PDARSK
 LDA CODLEN+1
 STA PDARSK+1
 STZ EMWV
 STZ EMWV+1
 JSR EMW
 BCS PDATQX
* b
 LDA PDAR2V
 STA EMWV
 LDA PDAR2V+1
 STA EMWV+1
 LDX PDAR2K
 JSR PDATPU
 BCS PDATQX
* q
 LDA PDARDV
 STA EMWV
 LDA PDARDV+1
 STA EMWV+1
 LDX #0
 JSR PDATPU
 BCS PDATR8
* a
 LDA PDSVAL
 STA EMWV
 LDA PDSVAL+1
 STA EMWV+1
 LDX PDSKND
 JSR PDATPU
 BCS PDATR8
 LDA #OEMUL
 JSR EMOP
 BCS PDATR8
 LDA #OESUB
 JSR EMOP
 BCS PDATR8
 LDA PDARRV
 STA EMWV
 LDA PDARRV+1
 STA EMWV+1
 LDA #OPOPD
 JSR EMOP1
 BCS PDATR8
 LDA EMMODE
 BEQ PDATR9
 JSR PDATQ
 BCS PDATR8
 LDA PDARDV
 STA EMWV
 LDA PDARDV+1
 STA EMWV+1
 LDA #OPOPDR
 JSR EMOP1
 BCS PDATR8
* L: SZSKP lands here
PDATR9 LDA PDARSK
 STA EMWO
 LDA PDARSK+1
 STA EMWO+1
 LDA CODLEN
 STA EMWV
 LDA CODLEN+1
 STA EMWV+1
 JSR EMSETW
 CLC
* the far half's error exit: C=1 stays set
PDATR8 RTS
* REMAINDER: 1 if there is one, r, and SZSKP's
* operand to patch
PDARRM DFB 0
PDARRV DS 2
PDARSK DS 2

