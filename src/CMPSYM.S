* CMPSYM.S  the symbol table  -  COMPILE slice 4
* PUT from COMPILE.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* THE TABLE ITSELF LIVES IN THE AUX CARD since
* 2026-11-11 (SYMAUX.S, reached through LIB slot
* 108, SYMSVC).  What is left here are the same
* seven entry points the passes have always called,
* with the same inputs and outputs, so not one
* caller changed:
*   SYMINIT  empty it
*   SYMFIND  TOKBUF/TOKLEN -> SYMIX, C=0 found
*   SYMADD   A = kind, SYMVAL = value -> SYMIX;
*            C=1 and CMPERR 4 duplicate, 5 full,
*            48 a name over thirty characters
*   SYMGET   SYMIX -> SYMVAL, SYKIND (and A = kind)
*   SYMPUT   SYMVAL -> entry SYMIX
*   SYMCHG   SYMIX -> FIXHD, the fixup chain
*   SYMCHS   FIXHD -> entry SYMIX
* Each keeps X, as the old code did, and leaves ZPT1
* alone; ZPT2 is used, as SYMPTR always used it.
*
* NAMES OF UP TO THIRTY CHARACTERS, 128 of them (the
* user's choice, 2026-11-11; it was ten and 64).  A
* name exists only while compiling - the object has
* item numbers, never names - so a long name costs
* the finished program nothing at all.
*
* WHAT value AND chain MEAN DEPENDS ON kind:
*   KDATA  value = the descriptor's item number
*   KCOND  value = the pool offset of the 88's
*          literal, chain = the parent's item number
*   KPARA  value = the code offset of the paragraph,
*          chain = the head of its fixup chain
* One table for all three, because a COBOL program
* has one name space and a paragraph called TOTAL
* really does collide with an 01 called TOTAL.

KFREE EQU 0
KDATA EQU 1
KCOND EQU 2
KPARA EQU 3
* KFILE  value = the index into CMPFIL, 0 or 1.
* A file name is a name like any other and belongs
* in the one symbol table, not a second one beside
* it - which is also what stops a program using the
* same word for a file and a data item.
KFILE EQU 4

* ---- SYMINIT: empty the table ------------------
SYMINIT STX SYXS
 LDX #0
 JSR SYMSVC
 LDX SYXS
 RTS

* ---- SYMFIND: TOKBUF/TOKLEN -> SYMIX -----------
* out: C=0 found, C=1 not (SYMIX = NSYMS then)
SYMFIND STX SYXS
 JSR SYMTOK
 LDX #1
 JSR SYMSVC
 STA SYMIX
 LDX SYXS
 RTS

* ---- SYMADD: add TOKBUF as kind A --------------
* in:  A = kind, SYMVAL = the value
* out: SYMIX = the new entry, C=1 on error
SYMADD STX SYXS
 STA SYKIND
 JSR SYMTOK
 LDA SYKIND
 LDX #2
 JSR SYMSVC
 BCC SYA1
 STA CMPERR
 LDX SYXS
 RTS
SYA1 STA SYMIX
* the value; the chain is already $FFFF, empty
 JSR SYMPUT
 LDX SYXS
 CLC
 RTS

* ---- SYMGET / SYMPUT: the value of entry SYMIX --
SYMGET STX SYXS
 LDY SYMIX
 LDX #3
 JSR SYMSVC
 STA SYKIND
 LDA ZPT2
 STA SYMVAL
 LDA ZPT2+1
 STA SYMVAL+1
 LDX SYXS
 LDA SYKIND
 RTS
SYMPUT STX SYXS
 LDA SYMVAL
 STA ZPT2
 LDA SYMVAL+1
 STA ZPT2+1
 LDY SYMIX
 LDX #4
 JSR SYMSVC
 LDX SYXS
 RTS

* ---- SYMCHG / SYMCHS: the chain of entry SYMIX --
* Only a paragraph uses it, and it is what makes a
* forward PERFORM possible: the operand word of
* every unresolved reference holds the offset of the
* previous one, and this is where the head of that
* list lives between references.
SYMCHG STX SYXS
 LDY SYMIX
 LDX #5
 JSR SYMSVC
 LDA ZPT2
 STA FIXHD
 LDA ZPT2+1
 STA FIXHD+1
 LDX SYXS
 RTS
SYMCHS STX SYXS
 LDA FIXHD
 STA ZPT2
 LDA FIXHD+1
 STA ZPT2+1
 LDY SYMIX
 LDX #6
 JSR SYMSVC
 LDX SYXS
 RTS

* ---- SYMTOK: ZPT2 -> TOKBUF, Y = TOKLEN ---------
SYMTOK LDA #<TOKBUF
 STA ZPT2
 LDA #>TOKBUF
 STA ZPT2+1
 LDY TOKLEN
 RTS
