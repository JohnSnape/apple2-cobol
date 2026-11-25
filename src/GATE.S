* GATE.S  the door into the auxiliary language card
* PUT from LIB.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* ================= WHY THIS EXISTS =============
* BCD, PICTURE and ERRMSG moved out of COBOL.LIB on
* 2026-11-08, into COBOL.AUX, which COBOL.SYSTEM
* copies into the AUXILIARY LANGUAGE CARD at boot -
* sixteen kilobytes at $D000-$FFFF that every 128K
* IIe has and that nothing in this system used.
* Main memory between $3000 and $AFFF is what the
* library, the interpreter and a running program
* share, and every byte that moves up there is a
* byte they get back.
*
* ================= WHAT A CALL COSTS ===========
* Code up there runs only with ALTZP on, and ALTZP
* swaps more than the language card: zero page and
* the stack page become the auxiliary ones too.  So
* a call has to carry across the four things the
* moved code reads from the caller -
*   A X Y and the flags
*   ZPT1 and ZPT2, the two pointers (STRPTR is
*     ZPT1 under another name)
*   the stack pointer, because the return address
*     the caller pushed is on the MAIN stack page
* - and carry them back.  About two hundred cycles
* a call.  The arithmetic it wraps costs as much or
* more, and the interpreter spends its time on the
* screen and the disk, not here.
*
* THE STUBS KEEP THE OLD NAMES.  BADD, BCMP, PIDEED
* and the rest are defined below as three-
* instruction stubs, so the library's jump table and
* the three modules that call them directly - CLASS
* (BTEST), SCRINP (NGETD, PIDEED) and SELECT2 (BCMP,
* PIDEED) - did not change at all.
*
* ================= THE RULES ===================
* For the code in COBOL.AUX, not for its callers:
* - It may not call ProDOS, the ROM or anything that
*   selects a RamWorks bank: the ROM is hidden while
*   the card is switched in, ProDOS keeps itself in
*   the MAIN card, and a bank switch would take the
*   running code away.  BANKSEL is 0 whenever this
*   gate is called; every routine that changes it
*   puts it back before it returns.
* - Anything a caller reads afterwards must be in
*   main memory: the data region, or a buffer.  A
*   pointer into $D000-$FFFF means nothing to main
*   code, which sees the ROM there - which is why
*   ERRMSG copies its text down to ERRBUF.
* - Interrupts are off while it runs; the caller's
*   I flag is put back on the way out.
*
* ENTRY n IS AT AUXBASE + 3n, and the order in
* AUXLC.S is FROZEN in step with the stubs below.

* ---- the stubs: A saved, entry offset in A ------
BADD STA GTA
 LDA #0
 JMP GATE
BSUB STA GTA
 LDA #3
 JMP GATE
BMUL STA GTA
 LDA #6
 JMP GATE
BDIV STA GTA
 LDA #9
 JMP GATE
BCMP STA GTA
 LDA #12
 JMP GATE
BZERO STA GTA
 LDA #15
 JMP GATE
BMOVE STA GTA
 LDA #18
 JMP GATE
BNEG STA GTA
 LDA #21
 JMP GATE
BSHR STA GTA
 LDA #24
 JMP GATE
BSHL STA GTA
 LDA #27
 JMP GATE
BROUND STA GTA
 LDA #30
 JMP GATE
BTEST STA GTA
 LDA #33
 JMP GATE
BPACK STA GTA
 LDA #36
 JMP GATE
BUNPK STA GTA
 LDA #39
 JMP GATE
BTOBIN STA GTA
 LDA #42
 JMP GATE
BFRBIN STA GTA
 LDA #45
 JMP GATE
BMOVA STA GTA
 LDA #48
 JMP GATE
BCMPA STA GTA
 LDA #51
 JMP GATE
BFILL STA GTA
 LDA #54
 JMP GATE
PIEDIT STA GTA
 LDA #57
 JMP GATE
PIDEED STA GTA
 LDA #60
 JMP GATE
PIINIT STA GTA
 LDA #63
 JMP GATE
ERMSG STA GTA
 LDA #66
 JMP GATE
NGETD STA GTA
 LDA #69
 JMP GATE
* the prefixes: X = the service (PREFIX.S)
PXGATE STA GTA
 LDA #72
 JMP GATE
* the compiler's symbol table: X = the service
* (SYMAUX.S), 2026-11-11
SYGATE STA GTA
 LDA #75
 JMP GATE

* ---- GATE: A = entry offset, GTA = caller's A ----
* The offset goes straight into the low byte of the
* JSR below.  Self-modifying, and the honest way to
* do it: an indirect JSR does not exist, and JMP
* (abs) to a stub that JSRs would cost a second
* page of stubs to save nothing.
GATE STA GTJ+1
 STX GTX
 STY GTY
 PHP
 PLA
 STA GTP
* the two pointers, out of MAIN zero page while it
* is still the one we can see
 LDA ZPT1
 STA GTZ
 LDA ZPT1+1
 STA GTZ+1
 LDA ZPT2
 STA GTZ+2
 LDA ZPT2+1
 STA GTZ+3
 TSX
 STX GTSP
* Over the line.  From the STA on, zero page and
* the stack are the auxiliary ones; the two BITs
* read $C083, which maps the card's RAM bank 2 in
* for reading AND writing - BCD and PICTURE keep
* their working variables beside their code, and a
* write-protected card silently drops every one of
* them (found the first time it ran, 2026-11-08).
* The auxiliary stack is started fresh at
* $FF every time: nothing up there calls back down,
* so nothing is ever left on it.
 SEI
 STA ALTZPON
 BIT LCRW2
 BIT LCRW2
 LDX #$FF
 TXS
 LDA GTZ
 STA ZPT1
 LDA GTZ+1
 STA ZPT1+1
 LDA GTZ+2
 STA ZPT2
 LDA GTZ+3
 STA ZPT2+1
* The caller's registers and flags, exactly - some
* entries take X or the carry - but with I SET, so
* an interrupt cannot arrive while the vectors at
* $FFFE are the card's and not the ROM's.
 LDA GTP
 ORA #$04
 PHA
 LDX GTX
 LDY GTY
 LDA GTA
 PLP
GTJ JSR AUXBASE
* and back: results first, while they are live
 PHP
 STA GTA
 STX GTX
 STY GTY
 PLA
 STA GTR
 LDA ZPT1
 STA GTZ
 LDA ZPT1+1
 STA GTZ+1
 LDA ZPT2
 STA GTZ+2
 LDA ZPT2+1
 STA GTZ+3
 BIT ROMIN2
 STA ALTZPOFF
 LDX GTSP
 TXS
 LDA GTZ
 STA ZPT1
 LDA GTZ+1
 STA ZPT1+1
 LDA GTZ+2
 STA ZPT2
 LDA GTZ+3
 STA ZPT2+1
* the routine's N V Z C, the caller's I
 LDA GTP
 AND #$04
 STA GTP
 LDA GTR
 AND #$FB
 ORA GTP
 PHA
 LDX GTX
 LDY GTY
 LDA GTA
 PLP
 RTS

* ---- variables, in MAIN memory where the gate
* can reach them on both sides of the line ----
GTA DFB 0
GTX DFB 0
GTY DFB 0
GTP DFB 0
GTR DFB 0
GTSP DFB 0
GTZ DS 4
