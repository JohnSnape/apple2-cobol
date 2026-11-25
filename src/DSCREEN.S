* DSCREEN.S  positioned screen output and input
* A library module (PUT it from LIB.S).
*
* The other half of DISPLAY and ACCEPT: the half
* with coordinates.  Nothing here scrolls, nothing
* wraps, and there is no cursor that advances on
* its own - every operation says where it goes.
* This is what FORMAT-generated code calls, and
* what a hand-written
*     DISPLAY "NAME:" AT LINE 4 COLUMN 5
* compiles into.
*
* CONSOLE is the other half.  A program uses one or
* the other; mixing them means a screen that is
* half document and half form, which is a way of
* having neither.  Both are in the library because
* together they are about 1500 bytes out of twelve
* thousand, and deciding at load time which one a
* program needs would cost more than it saves.
*
* COBOL COUNTS FROM ONE
* DSLINE and DSCOL are 1-based, because LINE 1
* COLUMN 1 is what a COBOL programmer writes and
* what FORMAT prints in its designer. The driver
* counts rows and columns from zero.  DSAT is the
* one place that conversion happens, so nothing
* else has to remember which convention it is in.
*
* ON FLASHING
* The specification lists NORMAL, INVERSE and
* FLASHING.  We have the first two.  Flashing
* characters live in the $40-$7F screen range, and
* the driver turns the alternate character set on
* at startup - which is what puts MouseText in that
* range instead.  A system cannot have both, and
* MouseText is worth more than blinking text.

* ---- DSAT: position from DSLINE / DSCOL ---------
* 1-based in, 0-based out, SCRPTR set up ready.
* Out-of-range coordinates are clamped rather than
* refused: a report that runs one line long should
* print oddly, not stop.
DZAT LDA DSLINE
 BNE DSA1
 LDA #1
DSA1 SEC
 SBC #1
 CMP #24
 BCC DSA2
 LDA #23
DSA2 STA SCRROW
 LDA DSCOL
 BNE DSA3
 LDA #1
DSA3 SEC
 SBC #1
 CMP #80
 BCC DSA4
 LDA #79
DSA4 STA SCRCOL
 LDX SCRROW
 JMP SCRADDR

* ---- DSPUTS: length-prefixed string at DSLINE ---
* in: STRPTR -> the string, SCRATR = attribute
DZPUTS JSR DZAT
 JMP PUTS

* ---- DSPBUF: ALEN raw bytes at DSLINE / DSCOL ---
* No length prefix: this is for record fields and
* edited PICTURE output, which arrive as a buffer
* and a length rather than as a literal.
DZPBUF JSR DZAT
 LDA #0
 STA DSI
DSB1 LDA DSI
 CMP ALEN
 BCS DSBD
 LDY DSI
 LDA (ZPT1),Y
 JSR CONV
 JSR PUTC
 INC DSI
 JMP DSB1
DSBD RTS

* ---- DSACC: read one field at DSLINE / DSCOL ----
* in:  ZPT2 -> caller's buffer
*      DSLEN  = field width
*      DSFLGS = bit7 numeric only
*               bit6 fold to upper case
*               bit5 required (may not be empty)
* out: Y = length typed
*      C=1 if ESC cancelled
*
* The field is repainted on every keystroke.  That
* is wasteful and completely invisible at one
* megahertz, and it means backspace needs no
* special case at all - the field simply gets one
* character shorter and is drawn again.
DZACC LDA #0
 STA DSLEN2
DSAC1 JSR DSDRAW
 JSR DSKEY
 JSR KEYCHRD
 BCS DSACCM
 CMP #$0D
 BEQ DSACOK
 CMP #$09
 BEQ DSACTB
 CMP #$1B
 BEQ DSACES
 CMP #$08
 BEQ DSACBS
 CMP #$20
 BCC DSAC1
* The key is seven bits by now, so the only code
* left at $7F or above is $7F itself - DELETE.
* This line used to be BCS DSAC1, which threw
* it away; now it erases, the same as the left
* arrow, as it does in EDIT.  The //e's DELETE
* key is where a typist reaches to fix a slip.
* Same size, so nothing moves (user, 2026-11-24)
 CMP #$7F
 BEQ DSACBS
 JSR DSVALID
 BCC DSAC1
 LDY DSLEN2
 CPY DSLEN
 BCS DSAC1
 STA (ZPT2),Y
 INC DSLEN2
 JMP DSAC1
DSACBS LDA DSLEN2
 BEQ DSAC1
 DEC DSLEN2
 JMP DSAC1
* TAB and RETURN both finish the field, and both
* leave the carry clear, but they are not the same
* thing to a program walking a form - so they are
* not the same thing in KEYTERM either.
DSACTB LDA #$32
 BNE DSACT1
DSACOK LDA #$30
DSACT1 STA DSTRM
 LDA DSFLGS
 AND #$20
 BEQ DSACD
 LDA DSLEN2
 BNE DSACD
 JMP DSAC1
DSACD LDA DSTRM
 JSR KEYDONE
 JSR DSDRAW2
 LDY DSLEN2
 CLC
 RTS
DSACES LDA #$31
 JSR KEYDONE
 JSR DSDRAW2
 LDY DSLEN2
 SEC
 RTS
DSACCM JSR DSDRAW2
 LDY DSLEN2
 SEC
 RTS

* ---- DSVALID: A = key.  C=1 if it may be typed --
* Numeric fields take digits, a leading minus and
* one decimal point; everything else takes any
* printable character.  Upper-case folding happens
* here rather than at storage time, so what the
* operator sees is what is stored.
DSVALID STA DSCH
 LDA DSFLGS
 AND #$40
 BEQ DSV1
 LDA DSCH
 CMP #$61
 BCC DSV1
 CMP #$7B
 BCS DSV1
 SEC
 SBC #$20
 STA DSCH
DSV1 LDA DSFLGS
 BPL DSVOK
 LDA DSCH
 CMP #$30
 BCC DSV2
 CMP #$3A
 BCC DSVOK
DSV2 CMP #$2D
 BEQ DSVOK
 CMP #$2E
 BEQ DSVOK
 CLC
 RTS
DSVOK LDA DSCH
 SEC
 RTS

* ---- DSDRAW / DSDRAW2: paint the field ----------
* Data-entry areas are inverse.  That is not
* decoration: inverse is the system's way of saying
* "you may type here", and it is why the command
* bar and status line stay normal even though they
* would look smarter reversed.
DSDRAW LDA #1
 STA DSCUR
 BNE DSD0
DSDRAW2 LDA #0
 STA DSCUR
DSD0 JSR DZAT
* DSAT leaves SCRCOL at the field's start, but PUTC
* advances it as we paint, so keep the start for
* the cursor calculation at the end.
 LDA SCRCOL
 STA DSCOL0
 LDA #1
 STA SCRATR
 LDA #0
 STA DSI
DSD1 LDA DSI
 CMP DSLEN
 BCS DSD3
 CMP DSLEN2
 BCS DSD2
 LDY DSI
 LDA (ZPT2),Y
 JSR CONV
 JSR PUTC
 JMP DSDN
DSD2 LDA #$20
 JSR CONV
 JSR PUTC
DSDN INC DSI
 JMP DSD1
DSD3 LDA DSCUR
 BEQ DSD4
 LDA DSLEN2
 CMP DSLEN
 BCS DSD4
 CLC
 ADC DSCOL0
 STA CCOL
 LDA #$5F
 JSR CONV
 JSR PUTAT
DSD4 RTS

* ---- DSKEY: wait for a key, stripped ------------
DSKEY JSR WAITKEY
 AND #$7F
 RTS

* ================= VARIABLES ===================
DSI DFB 0
DSCH DFB 0
DSCUR DFB 0
DSTRM DFB 0
DSLEN2 DFB 0
DSCOL0 DFB 0
