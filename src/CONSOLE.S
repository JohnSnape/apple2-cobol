* CONSOLE.S  scrolling console output and input
* A library module (PUT it from LIB.S).
*
* This is the half of DISPLAY and ACCEPT that has
* no coordinates: text arrives at the cursor, the
* cursor advances, the line wraps at column 80, and
* the screen scrolls when it reaches the bottom.
* It is what our three sample programs use and what
* any COBOL that says plain DISPLAY expects.
* DSCREEN is the other half - positioned, framed,
* and never scrolling.
*
* WHY THERE IS A SHADOW
* Scrolling means reading the line below and
* writing it one line up.  Reading the auxiliary
* half of the screen means turning RAMRD on, and
* RAMRD redirects instruction fetch as well as
* data - the routine doing the scroll would bank
* itself out mid-loop.  The firmware's own scroll
* escapes this only because it runs with 80STORE
* on, which we cannot use because 80STORE is what
* makes text page 2 unreachable.
*   So we never read the screen at all.  A shadow
* copy of the 24 VISIBLE lines lives in main
* memory, every character written goes to both, and
* scrolling is a move within the shadow followed by
* a repaint.  Reading main memory is safe and the
* same code serves both text pages.
*
* THE SHADOW IS NOT SCROLLBACK
* It is exactly 24 rows - a mirror of what is on
* the screen this instant, and nothing more.  A
* line that scrolls off the top is overwritten in
* the shadow at the same moment it leaves the
* display, and it is gone, exactly as it is gone on
* an unmodified Apple II.  Nothing here remembers
* history and nothing here should: a console is a
* place text goes past, not a place it is kept.
*   EDIT keeps its lines because EDIT is an editor.
* Its lines are records in auxiliary memory reached
* through AMGET/AMPUT, it never calls this module,
* and the two have nothing to do with each other.
*
* THE SHADOW HAS THE SCREEN'S SHAPE
* A shadow row is 80 bytes: the first 40 are the
* even columns, which live in auxiliary memory, and
* the last 40 are the odd columns, which live in
* main.  That is the same split the display uses,
* so a repaint is two straight forty-byte copies
* per row with one bank switch each - rather than
* eighty switches and a shift per character.
* Characters are stored as screen codes, already
* converted, so the repaint copies and does not
* think.

CROWS EQU 24
CCOLS EQU 80

* ---- CONINIT: take over as a scrolling console --
CNINIT JSR CNCLR
 RTS

* ---- CONCLR: blank shadow and screen, home ------
CNCLR LDA #0
 STA CRI
CCL1 LDX CRI
 JSR CROWAD
 LDY #0
 LDA #$A0
CCL2 STA (ZPT1),Y
 INY
 CPY #CCOLS
 BCC CCL2
 INC CRI
 LDA CRI
 CMP #CROWS
 BCC CCL1
 JSR CLRSCR
 LDA #0
 STA SCRROW
 STA SCRCOL
 TAX
 JMP SCRADDR

* ---- CROWAD: X = row -> ZPT1 = shadow row -------
* row * 80, built as row*64 + row*16 because there
* is no multiply and those are both shifts.
CROWAD TXA
 STA CT1
 LDA #0
 STA CT1+1
 ASL CT1
 ROL CT1+1
 ASL CT1
 ROL CT1+1
 ASL CT1
 ROL CT1+1
 ASL CT1
 ROL CT1+1
 LDA CT1
 STA CT2
 LDA CT1+1
 STA CT2+1
 ASL CT1
 ROL CT1+1
 ASL CT1
 ROL CT1+1
 CLC
 LDA CT1
 ADC CT2
 STA ZPT1
 LDA CT1+1
 ADC CT2+1
 STA ZPT1+1
 CLC
 LDA ZPT1
 ADC #<CSHADOW
 STA ZPT1
 LDA ZPT1+1
 ADC #>CSHADOW
 STA ZPT1+1
 RTS

* CROWAD2, which returned a second row address in
* ZPT2, went with the two row-by-row scrolls.  The
* block move needs a source and a destination that
* are set once, not once a row, so there is nothing
* left that wants two shadow row addresses at the
* same time.

* ---- CONPUTC: A = ASCII, write at the cursor ----
* Converted once, stored twice - to the shadow and
* to the screen - then the cursor moves, wrapping
* and scrolling as needed.
*
* X, Y, ZPT1 AND ZPT2 COME BACK AS THEY WENT IN -
* the promise the monitor's COUT makes, and then
* some.  A caller printing a run of characters
* counts them in X or Y and reads them through a
* pointer, and the console uses all four itself:
* CSHAD loads X and points ZPT1 at the shadow row,
* PUTC uses Y, and a scroll moves ZPT2 to ZPT1.
* Found 2026-11-07: BCDTEST's digit loop never
* counted down (X), and CONPUTS - whose STRPTR IS
* ZPT1 - printed each message's first letter and
* then the shadow's blanks.  CONGETLN reads its
* buffer through ZPT2, which a scroll during echo
* would have lost the same way.
CNPUTC PHX
 PHY
 TAX
 LDA ZPT1
 PHA
 LDA ZPT1+1
 PHA
 LDA ZPT2
 PHA
 LDA ZPT2+1
 PHA
 TXA
 JSR CONV
 STA CCH
 JSR CSHAD
 LDA CCH
 JSR PUTC
 LDA SCRCOL
 CMP #CCOLS
 BCC CPCD
 JSR CNCR
CPCD PLA
 STA ZPT2+1
 PLA
 STA ZPT2
 PLA
 STA ZPT1+1
 PLA
 STA ZPT1
 PLY
 PLX
 RTS

* ---- CSHAD: put CCH into the shadow at the cursor
* Column parity picks the half, exactly as it picks
* the memory bank on the screen itself.
CSHAD LDX SCRROW
 JSR CROWAD
 LDA SCRCOL
 LSR
 STA CIX
 LDA SCRCOL
 AND #1
 BEQ CSH1
 LDA CIX
 CLC
 ADC #40
 STA CIX
CSH1 LDY CIX
 LDA CCH
 STA (ZPT1),Y
 RTS

* ---- CONPUTS: length-prefixed string at STRPTR --
CNPUTS LDY #0
 LDA (STRPTR),Y
 STA CSLEN
 BEQ CPSD
 LDA #1
 STA CSIX
CPS1 LDY CSIX
 LDA (STRPTR),Y
 JSR CNPUTC
 INC CSIX
 LDA CSLEN
 CMP CSIX
 BCS CPS1
CPSD RTS

* ---- CONCR: end the line ------------------------
CNCR LDA #0
 STA SCRCOL
 INC SCRROW
 LDA SCRROW
 CMP #CROWS
 BCC CCRD
 JSR CNSCRU
 LDA #CROWS-1
 STA SCRROW
CCRD LDX SCRROW
 JMP SCRADDR

* ---- CONSCRU: scroll up one line ----------------
* Rows 1..23 move to 0..22, the last row blanks,
* and the screen is repainted from the shadow.
*
* THE WHOLE SCROLL IS ONE BLOCK MOVE.
* The shadow is row-major and every row is exactly
* CCOLS wide, so moving 23 rows up by one row is
* moving 1840 bytes down by 80 - a single straight
* copy that has no idea rows exist.  The aux/main
* split WITHIN a row never comes into it: the split
* is identical in every row, so it moves along with
* the bytes.  There is no per-row arithmetic here
* and CROWAD is not called at all.
*   The destination is BELOW the source, so a
* forward copy can never overtake itself.
*   1840 = (24-1) * 80 = 7 whole pages + 48 bytes.
* If CROWS or CCOLS ever change, change CSPAGE and
* CSTAIL to match.  They are written out rather
* than computed because Merlin evaluates strictly
* left to right with no operator precedence, and a
* constant that is quietly wrong is worse than one
* that has to be maintained by hand.
CSPAGE EQU 7
CSTAIL EQU 48
CSHSRC EQU CSHADOW+CCOLS

CNSCRU LDA #<CSHSRC
 STA ZPT2
 LDA #>CSHSRC
 STA ZPT2+1
 LDA #<CSHADOW
 STA ZPT1
 LDA #>CSHADOW
 STA ZPT1+1
 LDX #CSPAGE
 LDY #0
CSU1 LDA (ZPT2),Y
 STA (ZPT1),Y
 INY
 BNE CSU1
 INC ZPT1+1
 INC ZPT2+1
 DEX
 BNE CSU1
CSU2 LDA (ZPT2),Y
 STA (ZPT1),Y
 INY
 CPY #CSTAIL
 BCC CSU2
 LDX #CROWS-1
 JSR CBLANK
 JMP CONBLIT

* CONSCRD, scroll down, was here and is gone.  It
* moved rows 0..22 down to 1..23 and blanked row 0,
* losing the bottom row.  It could not bring back a
* line that had scrolled off the top - there is no
* such line to bring back - so all it did was open
* a blank line at the top, which no COBOL verb
* wants.  Nothing ever called it.  Slot 49 in the
* jump table is retired: left as an RTS, never
* reused, because a frozen table stays frozen.

* ---- CBLANK: X = row, blank it in the shadow ----
CBLANK JSR CROWAD
 LDY #0
 LDA #$A0
CBK1 STA (ZPT1),Y
 INY
 CPY #CCOLS
 BCC CBK1
 RTS

* ---- CONBLIT: repaint the screen from the shadow
* Two forty-byte copies a row, one bank switch
* each.  The shadow is already in screen codes and
* already split the way the display is, so nothing
* here converts or shifts.
CONBLIT LDA #0
 STA CRI
CBT1 LDX CRI
 JSR SCRADDR
 LDX CRI
 JSR CROWAD
* even columns -> auxiliary
 STA AUXWR
 LDY #0
CBT2 LDA (ZPT1),Y
 STA (SCRPTR),Y
 INY
 CPY #40
 BCC CBT2
 STA MAINWR
* odd columns -> main
 CLC
 LDA ZPT1
 ADC #40
 STA ZPT1
 LDA ZPT1+1
 ADC #0
 STA ZPT1+1
 LDY #0
CBT3 LDA (ZPT1),Y
 STA (SCRPTR),Y
 INY
 CPY #40
 BCC CBT3
 INC CRI
 LDA CRI
 CMP #CROWS
 BCC CBT1
 RTS

* ---- CONGETLN: read a line at the cursor --------
* in:  A = maximum length, ZPT2 -> caller's buffer
*      A bit 7 set: fold a-z (and {|}~) to capitals
*      as typed - the VM's UPPERCASE ONLY.  Every
*      older caller passes 80 or less, so bit 7 was
*      always clear and nothing they see changes.
*      CGWARN (public, $0E7D) nonzero: beep on each
*      character past that many - file names, 8.11
* out: Y = length typed, C=1 if ESC cancelled
* Echo goes through CONPUTC, so a line typed at the
* bottom of the screen scrolls exactly as printed
* output does.  Backspace erases on the screen as
* well as in the buffer, which is why this cannot
* simply repaint the field the way GETLN80 does -
* there is no field, only a cursor.
* ASL puts the fold bit in carry, ROR parks it in
* bit 7 of CGFLD, LSR gives back the length.
CNGETLN ASL
 ROR CGFLD
 LSR
 STA CGMAX
 LDA #0
 STA CGLEN
CGL1 JSR WAITKEY
 JSR KEYCHRD
 BCS CGLCMD
 AND #$7F
 CMP #$0D
 BEQ CGLOK
 CMP #$1B
 BEQ CGLES
 CMP #$08
 BEQ CGLBS
 CMP #$20
 BCC CGL1
* The key is seven bits by now, so the only code
* left at $7F or above is $7F itself - DELETE.
* This line used to be BCS CGL1, which threw
* it away; now it erases, the same as the left
* arrow, as it does in EDIT.  The //e's DELETE
* key is where a typist reaches to fix a slip.
* Same size, so nothing moves (user, 2026-11-24)
 CMP #$7F
 BEQ CGLBS
* $61 up, which is a-z and {|}~, loses bit 5: the
* four marks become []^, as on a keyboard with no
* lower case.  Two bytes cheaper than stopping at z,
* and the library had eighteen.
 BIT CGFLD
 BPL CGL2
 CMP #$61
 BCC CGL2
 AND #$DF
CGL2 LDY CGLEN
 CPY CGMAX
 BCS CGL1
 STA (ZPT2),Y
 INC CGLEN
 JSR CNPUTC
* the warning: a short beep for each character past
* CGWARN, so a file name near its 64 is heard
* getting long before the keys stop taking
 LDA CGWARN
 BEQ CGL3
 CMP CGLEN
 BCS CGL3
 JSR TDBELL
CGL3 JMP CGL1
CGLBS LDA CGLEN
 BEQ CGL1
 DEC CGLEN
 JSR CBACK
 JMP CGL1
CGLOK LDA #$30
 JSR KEYDONE
 JSR CNCR
 LDY CGLEN
 CLC
 RTS
CGLES LDA #$31
 JSR KEYDONE
 JSR CNCR
 LDY CGLEN
 SEC
 RTS
* A command chord ends the input the way ESC does -
* C=1, nothing accepted.  That is deliberate: a
* caller written before any of this existed tests
* only the carry, and treating an unhandled command
* as a cancel is the safe reading of it.  A caller
* that cares looks at KEYTERM.
CGLCMD JSR CNCR
 LDY CGLEN
 SEC
 RTS

* ---- CBACK: rub out the character behind the
* cursor, stepping back a line if need be --------
CBACK LDA SCRCOL
 BNE CBK2
 LDA SCRROW
 BEQ CBKD
 DEC SCRROW
 LDA #CCOLS-1
 STA SCRCOL
 LDX SCRROW
 JSR SCRADDR
 JMP CBK3
CBK2 DEC SCRCOL
CBK3 LDA #$20
 JSR CONV
 STA CCH
 JSR CSHAD
 LDA SCRCOL
 STA CCOL
 LDA CCH
 JSR PUTAT
CBKD RTS

* ================= VARIABLES ===================
* CSHADOW itself is an address in the data region -
* 1920 bytes have no business inside a file that is
* loaded from a floppy at every program start.
CCH DFB 0
CIX DFB 0
CRI DFB 0
CSLEN DFB 0
CSIX DFB 0
CGMAX DFB 0
CGLEN DFB 0
CGFLD DFB 0
CT1 DS 2
CT2 DS 2
