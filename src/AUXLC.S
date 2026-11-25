* AUXLC.S  COBOL.AUX - library code that runs from
* the auxiliary language card, $D000 upward
*
* The other half of GATE.S, which says why this
* exists and what the code in it may not do.  In
* short: no ProDOS, no ROM, no bank switching, and
* nothing a caller reads may be left up here.
*
* COBOL.SYSTEM loads this file into the overlay
* band at boot and copies it up into the card
* (LOADAUX, SYSLOAD.S).  It stays there for the
* whole session - no overlay touches $D000.
*
* BUILD ORDER: LIB, then this.  Neither needs the
* other's symbols - LIB reaches in here only
* through the table below, at addresses that do not
* move - so the order is a habit, not a rule.
 XC
 PUT EQUATES
 PUT EQUATES2

 ORG AUXBASE
 DSK /COBOL/OBJ/COBOL.AUX

* ================= THE TABLE ===================
* Entry n at AUXBASE + 3n.  FROZEN, in step with
* the stubs in GATE.S: the gate jumps here by
* offset, and an entry that moved would send every
* call to the wrong routine.  Growth goes on the
* end.
 JMP BADD
 JMP BSUB
 JMP BMUL
 JMP BDIV
 JMP BCMP
 JMP BZERO
 JMP BMOVE
 JMP BNEG
 JMP BSHR
 JMP BSHL
 JMP BROUND
 JMP BTEST
 JMP BPACK
 JMP BUNPK
 JMP BTOBIN
 JMP BFRBIN
 JMP BMOVA
 JMP BCMPA
 JMP BFILL
 JMP PIEDIT
 JMP PIDEED
 JMP PIINIT
 JMP ERMSG
 JMP NGETD
* 24: the prefixes (PREFIX.S), 2026-11-11
 JMP PXAUX
* 25: the compiler's symbol table (SYMAUX.S),
* 2026-11-11
 JMP SYAUX

* ================= THE CODE ====================
 PUT BCD
 PUT PICTURE
 PUT ERRMSG
 PUT PREFIX
* SYMAUX LAST, and above $E000: it swaps the card's
* $D000 bank to reach the names, and code under
* $E000 would be swapped out from under itself
 PUT SYMAUX

AUXEND EQU *
* AUXEND must stay below $FFFA, where the card's
* own interrupt vectors would be.  check.js tests
* it; read it after every assembly as well.
