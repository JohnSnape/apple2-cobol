* TEXTDRV.S  resident 80-column text driver
* Part I - the first module of the runtime library
* (see LIB.S), which every program loads at $3000.
* Owns BOTH text pages and every soft switch that
* touches them.  PUT this from LIB.S, not alone:
* the jump table that reaches these routines lives
* there, at the frozen library base.
*
* WHY THIS EXISTS
* The IIe firmware drives text page 1 only, and so
* did our old SCREEN.S.  The reason is one switch
* wearing two hats: with 80STORE ON, $C054/$C055
* stop selecting the display page and instead pick
* main or aux for the $0400-$07FF window.  That is
* the trick that makes 80 columns work - and it is
* exactly what makes page 2 unreachable.
* So this driver runs with 80STORE OFF for the
* life of the system.  Bank selection moves to
* RAMWRT ($C004/$C005), and $C054/$C055 go back to
* being what they were named for: the display page.
*
* THE ONE INVARIANT
* Every routine here leaves RAMWRT pointing at MAIN
* and 80STORE OFF.  Aux is banked in for the single
* store that needs it and banked straight back out.
* Nothing outside this file may touch those
* switches - that is the whole point of the file.
*
* Callers reach us through the library jump table
* at $3000 (see EQUATES).  Those addresses are
* frozen: APPEND new entries, never reorder, or
* every already-compiled p-code object breaks.

* ================= INIT =================
* TDINIT: take over the text screen.
* 80 columns, 80STORE OFF, alt charset, text,
* both pages blanked, page 1 showing, normal attr.
TDINIT STA SET80V
 STA CLR80S
 STA ALTCHR
 STA TXTSET
 STA MIXCLR
 STA MAINWR
 STA MAINRD
 LDA #0
 STA SCRATR
 STA CCOL
 LDX #1
TDI1 STA TDSROW,X
 STA TDSCOL,X
 STA TDSATR,X
 DEX
 BPL TDI1
* blank page 2 first, then land on page 1
 LDA #1
 JSR TDSETPG
 JSR TDCLRS
 LDA #0
 JSR TDSETPG
 JMP TDHOME

* ================= PAGE CONTROL =================
* TDSETPG: A = 0 or 1.  Selects the page for both
* display and drawing - we never split them, so
* what you write is always what you see.
* TDPGHI is the trick that keeps SCRADDR branchless:
* page 1 rows start $04xx-$07xx, page 2 rows start
* $08xx-$0Bxx, so the only difference is +$04 on
* the high byte.  We keep that addend in a byte and
* add it unconditionally.
TDSETPG AND #1
 STA SCRPAGE
 ASL
 ASL
 STA TDPGHI
 LDA SCRPAGE
 BNE TDSP2
 STA PG1SEL
 RTS
TDSP2 STA PG2SEL
 RTS

* TDGETPG: -> A = current page (0 or 1)
TDGETPG LDA SCRPAGE
 RTS

* TDSWAP: flip to the other page.
* Each page remembers its own cursor and attribute,
* so you can pop up a help screen on page 2 and
* come back to find the form exactly as you left
* it.  This is what replaces saving the screen to
* aux memory.
TDSWAP JSR TDSAVC
 LDA SCRPAGE
 EOR #1
 JSR TDSETPG
 JMP TDRESC

* TDSAVC: stash the cursor of the CURRENT page
TDSAVC LDX SCRPAGE
 LDA SCRROW
 STA TDSROW,X
 LDA SCRCOL
 STA TDSCOL,X
 LDA SCRATR
 STA TDSATR,X
 RTS

* TDRESC: restore the cursor of the CURRENT page
TDRESC LDX SCRPAGE
 LDA TDSROW,X
 STA SCRROW
 LDA TDSCOL,X
 STA SCRCOL
 LDA TDSATR,X
 STA SCRATR
 LDX SCRROW
 JMP TDSCRAD

* ================= ADDRESSING =================
* TDSCRAD: X = row (0-23) -> SCRPTR = row base.
* X is preserved, so the clear loops can index on
* it.  The base table is page 1; TDPGHI moves the
* whole thing to page 2 with one add.
TDSCRAD LDA SCRTBL,X
 STA SCRPTR
 CLC
 LDA SCRTBH,X
 ADC TDPGHI
 STA SCRPTR+1
 RTS

* ================= CHARACTER CONVERSION =========
* TDCONV: A = ASCII, SCRATR 0/1 -> A = screen code.
* Attribute 0 = normal (high bit set), 1 = inverse.
* Inverse has no lowercase form, so $40-$5F folds
* down to $00-$1F.  Clobbers X.
TDCONV AND #$7F
 LDX SCRATR
 BEQ TDCVN
 CMP #$40
 BCC TDCVD
 CMP #$60
 BCS TDCVD
 AND #$3F
TDCVD RTS
TDCVN ORA #$80
 RTS

* ================= OUTPUT =================
* TDPUTC: A = screen code, written at SCRCOL on the
* current row, then SCRCOL advances.
* One LSR does two jobs: the quotient is the byte
* offset within the row, and the bit shifted into
* carry says which bank.  Even columns live in aux,
* odd columns in main.
TDPUTC STA TDCHR
 LDA SCRCOL
 LSR
 TAY
 LDA TDCHR
 BCS TDPCM
 STA AUXWR
 STA (SCRPTR),Y
 STA MAINWR
 INC SCRCOL
 RTS
TDPCM STA (SCRPTR),Y
 INC SCRCOL
 RTS

* TDPUTAT: A = screen code at CCOL, no advance.
* Used for the blinking cursor, which must not
* disturb SCRCOL.
TDPUTAT STA TDCHR
 LDA CCOL
 LSR
 TAY
 LDA TDCHR
 BCS TDPAM
 STA AUXWR
 STA (SCRPTR),Y
 STA MAINWR
 RTS
TDPAM STA (SCRPTR),Y
 RTS

* TDPUTS: length-prefixed string at STRPTR, drawn
* at SCRROW / SCRCOL with attribute SCRATR.
TDPUTS LDX SCRROW
 JSR TDSCRAD
 LDY #0
 LDA (STRPTR),Y
 STA TDLEN
 BEQ TDPSD
 LDA #1
 STA TDIDX
TDPSL LDY TDIDX
 LDA (STRPTR),Y
 JSR TDCONV
 JSR TDPUTC
 INC TDIDX
 LDA TDLEN
 CMP TDIDX
 BCS TDPSL
TDPSD RTS

* TDPUTSX: as TDPUTS, but a $00 byte means "the
* next byte is a raw screen code" - written with no
* conversion.  That is how MouseText gets on the
* screen, since it has no ASCII to convert from.
TDPUTSX LDX SCRROW
 JSR TDSCRAD
 LDY #0
 LDA (STRPTR),Y
 STA TDLEN
 BEQ TDSXD
 LDA #1
 STA TDIDX
TDSXL LDY TDIDX
 LDA (STRPTR),Y
 BNE TDSXC
 INC TDIDX
 LDY TDIDX
 LDA (STRPTR),Y
 JSR TDPUTC
 JMP TDSXN
TDSXC JSR TDCONV
 JSR TDPUTC
TDSXN INC TDIDX
 LDA TDLEN
 CMP TDIDX
 BCS TDSXL
TDSXD RTS

* TDPUTRW: X = row.  Draws all 80 columns from
* ROWBUF, 80 screen codes already converted.
*
* ROWBUF HAS THE SCREEN'S SHAPE, NOT THE LINE'S
* The first 40 bytes are the EVEN columns, which
* live in auxiliary memory, and the last 40 are the
* ODD columns, which live in main - the same split
* CONSOLE's shadow uses, and the same one the
* display itself uses.  So a row is two straight
* forty-byte copies with one bank switch each: no
* shift, no parity test, no conversion, and Y
* indexes source and destination together.
*   Held the other way round - one linear line of
* eighty - the loop would have to step the source
* by two and would cost about a third more.  The
* caller does the splitting once, while it is
* already touching every byte for another reason.
*
* About 1200 cycles a row against about 5600
* through PUTC.  An editor repainting twenty lines
* is what makes that worth having.
*
* WHY THE BUFFER IS AT A FIXED ADDRESS
* Absolute,Y reaches it while (SCRPTR),Y reaches
* the screen.  Behind a pointer it would need the
* processor's one indirect index for itself.
TDPUTRW JSR TDSCRAD
 STA AUXWR
 LDY #39
TDRW1 LDA ROWBUF,Y
 STA (SCRPTR),Y
 DEY
 BPL TDRW1
 STA MAINWR
 LDY #39
TDRW2 LDA ROWBUF+40,Y
 STA (SCRPTR),Y
 DEY
 BPL TDRW2
 RTS

* ================= CLEARING =================
* TDCLRRW: X = row.  Blanks that row on the current
* page, both banks.  X survives.
TDCLRRW JSR TDSCRAD
 LDA #$A0
 LDY #39
TDCR1 STA (SCRPTR),Y
 DEY
 BPL TDCR1
 STA AUXWR
 LDY #39
TDCR2 STA (SCRPTR),Y
 DEY
 BPL TDCR2
 STA MAINWR
 RTS

* TDCLRS: blank all 24 rows of the current page.
TDCLRS LDX #0
TDCS1 JSR TDCLRRW
 INX
 CPX #24
 BCC TDCS1
 RTS

* TDCLRD: blank rows 0-21 only - the form area.
* Row 22 is the command bar, row 23 the line entry;
* both are left alone.
TDCLRD LDX #0
TDCD1 JSR TDCLRRW
 INX
 CPX #22
 BCC TDCD1
 RTS

* TDHOME: clear the current page, cursor to 0,0.
TDHOME JSR TDCLRS
 LDA #0
 STA SCRROW
 STA SCRCOL
 TAX
 JMP TDSCRAD

* ================= INPUT =================
* TDWAITK: wait for a key -> A, high bit still set.
* Return value deliberately unchanged from the old
* WAITKEY so existing callers keep working.
*
* The idle loop carries RNDSEED, a 32-bit counter,
* the way the monitor's KEYIN carried RNDL/RNDH.
* Waiting is otherwise dead time, and how long a
* person takes to press a key is the only thing on
* this machine that is not predictable.  Eight
* cycles in a loop that is doing nothing anyway.
TDWAITK LDA KBD
 BMI TDWKD
 INC RNDSEED
 BNE TDWAITK
 INC RNDSEED+1
 BNE TDWAITK
 INC RNDSEED+2
 BNE TDWAITK
 INC RNDSEED+3
 JMP TDWAITK
TDWKD JSR TDKMOD
 BIT KBDSTRB
 RTS

* ================ THE APPLE KEYS ===============
* ---- TDKMOD: record the Apple keys -------------
* out: KEYMOD, bit7 Open-Apple, bit6 Solid-Apple
*
* The convention is not new.  EDITCUR and PROMPT
* each invented it independently and each keeps its
* own copy of the fourteen instructions, which is
* the argument for it living here instead of in
* both of them and in the next one as well.
*
* IT HAS TO HAPPEN AT THE KEYSTROKE.  The key is
* latched and will wait for us; the Apple keys are
* not latched at all.  $C061 and $C062 are paddle
* button inputs and report what the button is doing
* NOW, so a read taken a few JSRs later reads a
* button the operator has already let go of.  That
* is why this sits inside the key wait rather than
* somewhere more convenient, and why EDITCUR taking
* its reading after HIDECUR was a window - a small
* one today, and one that grows the first time
* anybody puts work on that path.
*
* A, X AND Y ALL SURVIVE.  BIT does not disturb the
* accumulator, so both tests fold into one register
* and the keystroke rides through in A untouched -
* which is what lets TDWAITK call this without
* breaking its promise to return the key unchanged.
TDKMOD PHA
 LDA #0
 BIT OPNAPPL
 BPL TDKM1
 LDA #$80
TDKM1 BIT SLDAPPL
 BPL TDKM2
 ORA #$40
TDKM2 STA KEYMOD
 PLA
 RTS

* ---- TDKCHD: is this keystroke a command? ------
* in:  A = the key
* out: C=1 and KEYTERM/KEYCHAR set, or C=0.
*      A survives either way.
*
* IT IS OPT-IN, AND THAT IS THE WHOLE OF THE
* COMPATIBILITY STORY.  With KEYCMD zero - which is
* what it is unless a program asks otherwise - this
* returns C=0 every time and OA-P is simply P.
* Every accept routine in the library then behaves
* exactly as it did before for every program that
* never heard of the Apple keys.
*
* The key is folded to upper case, because OA-p and
* OA-P are the same command and no program should
* have to test for both.
TDKCHD LDX KEYCMD
 BEQ TDKC0
 LDX KEYMOD
 BEQ TDKC0
 PHA
 AND #$7F
 CMP #$61
 BCC TDKC1
 CMP #$7B
 BCS TDKC1
 SEC
 SBC #$20
TDKC1 STA KEYCHAR
 LDA KEYMOD
 AND #$C0
 CMP #$80
 BEQ TDKC2
 CMP #$40
 BEQ TDKC3
 LDA #$35
 BNE TDKC4
TDKC2 LDA #$33
 BNE TDKC4
TDKC3 LDA #$34
TDKC4 STA KEYTERM
 PLA
 SEC
 RTS
TDKC0 CLC
 RTS

* ---- TDKDNE: an ordinary terminator ------------
* in: A = '0' RETURN, '1' ESC, '2' TAB
* KEYCHAR gets a space, so a program that prints
* the two bytes without looking gets something
* printable rather than a control character.
TDKDNE STA KEYTERM
 LDA #$20
 STA KEYCHAR
 RTS

* TDGETLN: line input on the CURRENT page.
* The monitor's GETLN writes 40-column text to page
* 1 through COUT and knows nothing about either of
* those things, so we need our own.
*  in: SCRROW / SCRCOL = where to start,
*      SCRATR = attribute, A = max length,
*      ZPT2 -> caller's buffer.
* out: Y = length typed, C=1 if ESC cancelled.
TDGETLN STA TDGMAX
 LDA SCRROW
 STA TDGROW
 LDA SCRCOL
 STA TDGCOL
 LDA #0
 STA TDGLEN
TDGL1 JSR TDGDRW
 JSR TDWAITK
 AND #$7F
 CMP #$0D
 BEQ TDGLOK
 CMP #$1B
 BEQ TDGLES
 CMP #$08
 BEQ TDGLBS
 CMP #$20
 BCC TDGL1
* The key is seven bits by now, so the only code
* left at $7F or above is $7F itself - DELETE.
* This line used to be BCS TDGL1, which threw
* it away; now it erases, the same as the left
* arrow, as it does in EDIT.  The //e's DELETE
* key is where a typist reaches to fix a slip.
* Same size, so nothing moves (user, 2026-11-24)
 CMP #$7F
 BEQ TDGLBS
 LDY TDGLEN
 CPY TDGMAX
 BCS TDGL1
 STA (ZPT2),Y
 INC TDGLEN
 JMP TDGL1
TDGLBS LDA TDGLEN
 BEQ TDGL1
 DEC TDGLEN
 JMP TDGL1
TDGLOK JSR TDGDRW2
 LDY TDGLEN
 CLC
 RTS
TDGLES JSR TDGDRW2
 LDY TDGLEN
 SEC
 RTS

* TDGDRW: repaint the input field, with cursor.
* TDGDRW2: the same, without - used on exit.
* Repainting the whole field on every keystroke is
* wasteful and completely invisible at 1 MHz; it
* also means backspace needs no special case.
TDGDRW LDA #1
 STA TDGCUR
 BNE TDGD0
TDGDRW2 LDA #0
 STA TDGCUR
TDGD0 LDX TDGROW
 JSR TDSCRAD
 LDA TDGCOL
 STA SCRCOL
 LDA #0
 STA TDGI
TDGD1 LDA TDGI
 CMP TDGMAX
 BCS TDGD3
 CMP TDGLEN
 BCS TDGD2
 LDY TDGI
 LDA (ZPT2),Y
 JSR TDCONV
 JSR TDPUTC
 JMP TDGDN
TDGD2 LDA #$20
 JSR TDCONV
 JSR TDPUTC
TDGDN INC TDGI
 JMP TDGD1
TDGD3 LDA TDGCUR
 BEQ TDGD4
 LDA TDGLEN
 CMP TDGMAX
 BCS TDGD4
 CLC
 ADC TDGCOL
 STA CCOL
 LDA #$5F
 JSR TDCONV
 JSR TDPUTAT
TDGD4 RTS

* ================= ROW BASE TABLE =================
* Page 1 bases.  The IIe interleaves rows in thirds
* - rows 0,8,16 share a page, and so on - which is
* why this is a table and not arithmetic.
SCRTBL DFB $00,$80,$00,$80,$00,$80,$00,$80
 DFB $28,$A8,$28,$A8,$28,$A8,$28,$A8
 DFB $50,$D0,$50,$D0,$50,$D0,$50,$D0
SCRTBH DFB $04,$04,$05,$05,$06,$06,$07,$07
 DFB $04,$04,$05,$05,$06,$06,$07,$07
 DFB $04,$04,$05,$05,$06,$06,$07,$07

* ================= PRIVATE DATA =================
* Public variables (SCRROW SCRCOL SCRATR CCOL
* SCRPAGE) live in the library's variable block at
* $0C60 - see EQUATES.  Only these are private.
TDPGHI DFB 0
TDCHR DFB 0
TDLEN DFB 0
TDIDX DFB 0
TDSROW DS 2
TDSCOL DS 2
TDSATR DS 2
TDGMAX DFB 0
TDGROW DFB 0
TDGCOL DFB 0
TDGLEN DFB 0
TDGI DFB 0
TDGCUR DFB 0
TDEND EQU *

* ---- TDBELL: the ProDOS tone, not the monitor's --
* out: A destroyed, Z set
*
* The monitor's BELL at $FBDD is a 1 kHz tone for a
* tenth of a second and it is ALARMING in a room -
* loud, high, and long enough to make somebody look
* up.  This is the one ProDOS itself uses: lower,
* shorter, and it reads as "no" rather than as an
* emergency.  A data-entry program rejects a
* keystroke hundreds of times an hour and the
* difference matters more than it sounds like it
* should.
*
* The delay is the monitor's own WAIT at $FCA8,
* which is where the original listing's copy came
* from.  We call the ROM rather than carry a second
* copy of it, exactly as the system already calls
* COUT, HOME and AUXMOVE - twelve bytes saved and
* one fewer thing that can drift.
TDBELL LDA #$20
 STA TDBLEN
TDBL1 LDA #$02
 JSR MONWAIT
 STA SPKR
 LDA #$20
 JSR MONWAIT
 STA SPKR
 DEC TDBLEN
 BNE TDBL1
 RTS
TDBLEN DFB 0
