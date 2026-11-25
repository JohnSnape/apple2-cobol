* EDITDSP.S  EDIT keystroke dispatch
* PUT from EDIT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* EDIT resolve against each other in pass two.
*
* ================= DISPATCH =================
* BOTH APPLE KEYS DOWN IS NOT OPEN-APPLE.  Testing
* bit 7 first makes $C0 indistinguishable from $80,
* so a fumbled chord ran whatever OA command the
* letter happened to name - and OA-N is New
* program, which throws the buffer away.  The
* modifier has to be read as a PAIR before either
* bit is looked at on its own.
* Nothing in EDIT defines an OA+SA chord, so the
* honest answer is to do nothing at all: the same
* rule VBAD follows for an opcode it does not know.
EDISP LDA CHMOD
 AND #$C0
 CMP #$C0
 BNE EDSPR
 RTS
* A VIEW lets through only what moves the cursor.
EDSPR LDA VIEWMO
 BEQ EDSPQ
 JSR VWKEY
 BCC EDSPQ
 RTS
* a selection ends on any key that does not act on
* it (EDITCLP); ESC that ends one does nothing more
EDSPQ JSR SELCHK
 BCC EDSQ1
 RTS
EDSQ1 LDA CHMOD
 BPL EDS0
 JMP EDOA
EDS0 AND #$40
 BEQ EDS1
 JMP EDSA
EDS1 LDA CHKEY
 CMP #$1B
 BNE ED10
 JMP DQUIT
ED10 CMP #$08
 BNE ED11
 JMP DLEFT
ED11 CMP #$15
 BNE ED12
 JMP DRIGHT
ED12 CMP #$0B
 BNE ED13
 JMP DUPL
ED13 CMP #$0A
 BNE ED14
 JMP DDOWNL
ED14 CMP #$0D
 BNE ED15
 JMP DRET
ED15 CMP #$09
 BNE ED16
 JMP DTAB
ED16 CMP #$7F
 BNE ED17
 JMP DBS
* Ctrl-C Copy, Ctrl-X Cut, Ctrl-P Paste (EDITCLP)
ED17 CMP #$03
 BNE ED18
 JMP DCOPY
ED18 CMP #$18
 BNE ED19
 JMP DCUT
ED19 CMP #$10
 BNE ED20
 JMP DPASTE
ED20 CMP #$20
 BCC EDXX
 JMP DTYPE
EDXX RTS

* ---- the Open-Apple commands ----
* AND #$DF folds a letter to upper case without
* touching the arrows, whose codes have no bit 5.
EDOA LDA CHKEY
 AND #$DF
 CMP #$4E
 BNE EOA1
 JMP DNEW
EOA1 CMP #$47
 BNE EOA2
 JMP DGOTO
* OA-Up and OA-Down select lines (EDITCLP).  Paging
* and the ends of the line moved to Solid-Apple, and
* OA-Left and OA-Right do nothing (2026-11-11).
EOA2 CMP #$0B
 BNE EOA3
 JMP DSELU
EOA3 CMP #$0A
 BNE EOA6
 JMP DSELD
EOA6 CMP #$4F
 BNE EOA7
 JMP DOPEN
EOA7 CMP #$53
 BNE EOA8
 JMP DSAVE
EOA8 CMP #$50
 BNE EOA9
 JMP DPRINT
EOA9 RTS

* ---- the Solid-Apple commands ----
EDSA LDA CHKEY
 AND #$DF
 CMP #$49
 BNE ESA1
 JMP DINS
ESA1 CMP #$44
 BNE ESA2
 JMP DDEL
* SA-K: insert or overtype (was SA-M, 2026-11-08);
* the bar shows which in inverse, so it is redrawn
ESA2 CMP #$4B
 BNE ESA3
 LDA MODE
 EOR #1
 STA MODE
 LDA #1
 STA BARDRT
 RTS
ESA3 CMP #$50
 BNE ESA4
 JMP DPLACE
* SA-Up/Down page, SA-Left/Right go to the start and
* the end of the line - OA's moves until 2026-11-11
ESA4 CMP #$0B
 BNE ESA5
 JMP DPGUP
ESA5 CMP #$0A
 BNE ESA6
 JMP DPGDN
ESA6 CMP #$08
 BNE ESA7
 STZ CURCOL
 RTS
ESA7 CMP #$15
 BNE ESA8
 JMP DEOL
ESA8 RTS

DQUIT LDA #1
 STA QUIT
 RTS

