* PREFIX.S  the prefixes */ 0/ 1/-9/
* PUT from AUXLC.S - runs in the auxiliary language
* card, reached through the gate (GATE.S, PXGATE,
* entry 24).  No ORG, not assembled alone.
*
* THE IDEA IS PRODOS 16's, AND THE NAMES ARE TOO.
* ProDOS 8 has one prefix.  ProDOS 16 has nine and
* names them in a pathname - 1/ means "the
* directory prefix 1 holds" - so a program can say
* where its data lives once, in one place, and use
* short names everywhere after.  The user asked for
* the same thing here (2026-11-11), numbered this
* way:
*   */      the BOOT prefix - where COBOL.SYSTEM and
*           its overlays are.  Set at boot, and not
*           settable: it is a fact, not a choice
*   0/      the PROGRAM prefix - ProDOS's own current
*           prefix, where programs and their objects
*           are.  It is not kept here at all: a name
*           that starts 0/ just loses the 0/, and
*           ProDOS puts the current prefix in front
*           of a partial name by itself
*   1/-9/   nine more, for data and anything else.
*           Utilities sets them and saves them in
*           */COBOL.SETTINGS; a program can set them
*           too (SET PREFIX n TO ...)
* A name that starts with anything else is passed
* through as it was, so nothing written before this
* existed changes.
*
* WHY UP HERE.  Ten prefixes of 64 bytes is 640
* bytes that every tool and every running program
* must be able to read - so it cannot live in an
* overlay - and main memory has no 640 bytes to
* give: COBOL.SYSTEM had ten bytes left and the
* library fifty-five.  The card had nearly eight
* kilobytes.  Expanding a name is string work and
* nothing else, which is exactly what may run up
* here (no ProDOS, no ROM - see GATE.S).
*
* ONE ENTRY, FOUR SERVICES, X picks:
*   X=0 EXPAND  in:  ZPT1 -> a length-prefixed name
*               out: FNBUF1 = the name with its
*                    prefix name replaced, upper
*                    cased, at most 64 characters.
*                    FNBUF1 is in main memory, where
*                    the caller can read it.  ZPT1
*                    may point at FNBUF1 itself.
*   X=1 GET     in:  Y = 0 (*/) or 1-9, ZPT2 -> 64
*                    bytes of main memory
*               out: the prefix there, length-
*                    prefixed; length 0 = not set
*   X=2 SET     in:  Y = 1-9; 0 (*/) only at boot,
*                    while it is empty - refused C=1
*                    after that
*                    ZPT1 -> the new value
*               The value is expanded first, so SET
*               PREFIX 2 TO "1/BACKUP" works; it is
*               upper cased and given a trailing
*               slash.  An empty value clears it.
*   X=3 CLEAR   every prefix empty - at boot, before
*               */ and the settings are put in
* ZPT1 and ZPT2 are left as they came: the gate
* copies them back down to the caller, and FISPLT's
* callers keep a pointer in ZPT2.

* the table: entry n (0 = */) at PXTAB + 64n, a
* length byte and up to 63 characters.  An ADDRESS
* in the card, not a DS - 640 bytes of zeros have no
* business in COBOL.AUX on the disk; X=3 clears it.
* $F800-$FA7F: far above AUXEND, far below the
* card's vectors at $FFFA.
PXTAB EQU $F800
* the card's own pointer, in the AUXILIARY zero
* page - which is separate memory from the main
* one, and $F8-$F9 is free in both maps (EQUATES)
PXP EQU $F8

PXAUX CPX #1
 BEQ PXGET
 BCC PXEXP
 CPX #3
 BEQ PXCLR
 JMP PXSET

* ---- X=0: EXPAND ---------------------------------
* BAD NAMES ARE REFUSED, NOT MENDED (DECISIONS 8.10,
* the user's call: "Check and refuse").  A name that
* breaks ProDOS's rules - PXCHK says which - or that
* comes out over 64 characters goes on as "!", a
* name ProDOS can only refuse ($40, bad pathname),
* and NAMBAD says so in main memory.  Every load,
* save and OPEN in the system comes through here,
* so that one byte is how each tool knows to say
* "Bad file name" and a program gets status "31",
* whatever the call that failed would have said.
*   Mending was turned down: MY FILE! and MY.FILE.
* would become one file, and a leading digit or a
* sixteenth character has no mend at all.
PXEXP JSR PXIN
 JSR PXBLD
 BCS PXEBAD
 JSR PXCHK
 BCS PXEBAD
 LDA #0
 BRA PXE0
PXEBAD LDA #1
 STA PXOUT
 LDA #$21
 STA PXOUT+1
 LDA #1
PXE0 STA NAMBAD
* PXOUT -> FNBUF1, the length byte too.  Never more
* than 64, so BPL ends it.
 LDY PXOUT
PXE1 LDA PXOUT,Y
 STA FNBUF1,Y
 DEY
 BPL PXE1
 CLC
 RTS

* ---- X=1: GET ------------------------------------
PXGET TYA
 JSR PXADR
 LDY #0
 LDA (PXP),Y
 TAY
PXG1 LDA (PXP),Y
 STA (ZPT2),Y
 DEY
 BPL PXG1
 CLC
 RTS

* ---- X=3: CLEAR ----------------------------------
PXCLR LDA #9
 STA PXN2
PXC1 LDA PXN2
 JSR PXADR
 LDA #0
 STA (PXP)
 DEC PXN2
 BPL PXC1
 CLC
 RTS

* ---- X=2: SET ------------------------------------
* */ IS SET ONCE.  It is where the system booted - a
* fact, not a setting - and the user asked that
* nothing be able to change it (2026-11-11).  So
* entry 0 takes a value only while it is empty,
* which is between CLEAR and PXINIT at boot; after
* that a SET of it is refused, C=1, whoever asks.
* Utilities offers only 0-9, the compiler takes only
* a digit, and COBOL.SETTINGS does not hold */ -
* this is the lock behind all three.
PXSET STY PXN2
 CPY #0
 BNE PXS0
 LDA PXTAB
 BEQ PXS0
PXSNO SEC
 RTS
* A value that is not a good directory name, or is
* over 64 once expanded, is refused the same way:
* C=1, nothing changed.  Storing it would only make
* every name under it bad later, far from the cause.
PXS0
 JSR PXIN
 JSR PXBLD
 BCS PXSNO
 JSR PXCHK
 BCS PXSNO
* a directory ends in a slash, so the expansion is
* name-after-prefix with nothing to remember.  An
* empty value stays empty: that is "not set".
 LDY PXOUT
 BEQ PXS2
 LDA PXOUT,Y
 CMP #$2F
 BEQ PXS2
 CPY #63
 BCS PXS2
 INY
 LDA #$2F
 STA PXOUT,Y
 STY PXOUT
PXS2 LDA PXN2
 JSR PXADR
 LDY PXOUT
 CPY #64
 BCC PXS3
 LDY #63
 STY PXOUT
PXS3 LDA PXOUT,Y
 STA (PXP),Y
 DEY
 BPL PXS3
 CLC
 RTS

* ---- PXIN: (ZPT1) -> PXSRC, upper case ----------
* Copied first, because EXPAND may be asked to
* write its answer over its own question (FNAMP
* pointing at FNBUF1 is allowed - FILEIO.S).
* 79 characters at most; ProDOS takes 64, and a
* longer name fails there with its own error.
PXIN LDY #0
 LDA (ZPT1),Y
 CMP #80
 BCC PXI0
 LDA #79
PXI0 STA PXSRC
 TAY
 BEQ PXI3
PXI1 LDA (ZPT1),Y
 AND #$7F
 CMP #$61
 BCC PXI2
 CMP #$7B
 BCS PXI2
 AND #$DF
PXI2 STA PXSRC,Y
 DEY
 BNE PXI1
PXI3 RTS

* ---- PXBLD: PXSRC -> PXOUT, expanded -------------
* X is where the rest of the name starts in PXSRC:
* 1 for a name with no prefix name, 3 after one.
PXBLD STZ PXOUT
 LDX #1
 JSR PXWHO
 BCS PXB3
 LDX #3
 CMP #$FF
 BEQ PXB3
 JSR PXADR
 LDY #0
 LDA (PXP),Y
 BNE PXB0
* that prefix is not set: the name goes on as
* written, and PXCHK refuses it - "2" is not a name,
* it starts with a digit - so the answer is "Bad
* file name", as ProDOS's own was ($40)
 LDX #1
 BRA PXB3
PXB0 STA PXOUT
 TAY
PXB1 LDA (PXP),Y
 STA PXOUT,Y
 DEY
 BNE PXB1
* the rest of the name, from X to the end
* out: C=0 it fitted, C=1 it came to more than 64.
* It used to stop at 64 and say nothing, and the
* name cut short could be ANOTHER file - DECISIONS
* 8.10.  PXEXP and PXSET refuse it now.
PXB3 CPX PXSRC
 BEQ PXB4
 BCS PXB9
PXB4 LDY PXOUT
 CPY #64
 BCS PXB8
 INY
 LDA PXSRC,X
 STA PXOUT,Y
 STY PXOUT
 INX
 BNE PXB3
PXB9 CLC
 RTS
PXB8 SEC
 RTS

* ---- PXCHK: is PXOUT a name ProDOS takes? --------
* out: C=0 yes, C=1 no.  ProDOS's rules, from the
* technical reference: every part between slashes
* is 1 to 15 characters, the first a letter, the
* rest letters, digits and periods.  One slash may
* lead (a full name: the volume) and one may end it
* (a directory, as SET PREFIX gives).  Two together
* are an empty part, which is refused.  PXIN has
* already upper cased it and cleared bit 7.
*   An empty name passes: it is not a name anyone
* is about to open, and the callers that take one
* - "clear this prefix" - mean it.
PXCHK LDX #1
 LDA PXOUT
 BEQ PXKOK
 LDA PXOUT+1
 CMP #$2F
 BNE PXK1
 INX
* a new part: PXKN counts its characters
PXK1 STZ PXKN
PXK2 CPX PXOUT
 BEQ PXK3
* past the end.  A trailing slash leaves PXKN 0,
* and so does a name of "/" alone: both are fine.
 BCS PXKOK
PXK3 LDA PXOUT,X
 CMP #$2F
 BEQ PXKSL
 LDY PXKN
 BNE PXK4
* the first character of a part: a letter
 JSR PXKLET
 BCS PXKBAD
 BRA PXK5
* the rest: a letter, a digit or a period
PXK4 CMP #$2E
 BEQ PXK5
 CMP #$30
 BCC PXKBAD
 CMP #$3A
 BCC PXK5
 JSR PXKLET
 BCS PXKBAD
PXK5 INC PXKN
 LDA PXKN
 CMP #16
 BCS PXKBAD
 INX
 BRA PXK2
* a slash ends a part, and the part must not be
* empty - "A//B"
PXKSL LDA PXKN
 BEQ PXKBAD
 INX
 BRA PXK1
PXKOK CLC
 RTS
PXKBAD SEC
 RTS

* PXKLET: C=0 if A is A-Z, C=1 if not
PXKLET CMP #$41
 BCC PXKL1
 CMP #$5B
 BCS PXKL2
 CLC
 RTS
PXKL1 SEC
PXKL2 RTS

* ---- PXWHO: which prefix does PXSRC name? --------
* out: C=0, A = 0 for */, 1-9 for n/, $FF for 0/
*      C=1, none - an ordinary name
PXWHO LDA PXSRC
 CMP #2
 BCC PXWN
 LDA PXSRC+2
 CMP #$2F
 BNE PXWN
 LDA PXSRC+1
 CMP #$2A
 BNE PXW1
 LDA #0
 CLC
 RTS
PXW1 SEC
 SBC #$30
 CMP #10
 BCS PXWN
 CMP #0
 BNE PXW2
 LDA #$FF
PXW2 CLC
 RTS
PXWN SEC
 RTS

* ---- PXADR: A = entry -> PXP = PXTAB + 64A -------
PXADR STA PXN
 LSR
 LSR
 CLC
 ADC #>PXTAB
 STA PXP+1
 LDA PXN
 ASL
 ASL
 ASL
 ASL
 ASL
 ASL
 CLC
 ADC #<PXTAB
 STA PXP
 BCC PXA1
 INC PXP+1
PXA1 RTS

* ---- variables, in the card beside the code ------
PXN DFB 0
PXN2 DFB 0
* PXCHK: characters in the part it is reading
PXKN DFB 0
PXSRC DS 80
PXOUT DS 80
