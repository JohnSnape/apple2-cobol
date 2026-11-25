* VMSCRN.S  DISPLAY/ACCEPT opcodes
* PUT from VM.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* ================= SCREEN =================
* DISPLAY of an item.  A number goes through the
* edit engine on its way out - which is the whole
* reason PICTURE is a runtime module and not a
* compiler trick.
VDISP JSR VOPS
 LDA VMD1+DTYPE
 CMP #TNUM
 BNE VDS2
 LDA VMO1
 STA VMO2
 LDA VMO1+1
 STA VMO2+1
 LDY #7
VDS0 LDA VMD1,Y
 STA VMD2,Y
 DEY
 BPL VDS0
 LDA VMO1
 STA ZPT1
 LDA VMO1+1
 STA ZPT1+1
* a negative number shows its minus sign in front.
* The default picture has no sign position, and
* giving it one would put a space in front of every
* positive number the programs already print - so
* the sign is written only when there is one
* (FIXLIST A13).  CONPUTC keeps ZPT1.
 LDA (ZPT1)
 BPL VDSPOS
 LDA #$2D
 JSR VPUTC
VDSPOS JSR VDEFP
 LDA VMD1+DDEC
 STA PICSCL
 LDA #0
 STA PICFLG
 JSR PICEDIT
 LDA #<PICBUF
 STA ZPT1
 LDA #>PICBUF
 STA ZPT1+1
 LDA PICLEN
 STA VMT1
 JMP VDSOUT
VDS2 LDA VMO1
 STA ZPT1
 LDA VMO1+1
 STA ZPT1+1
 LDA VMD1+DLEN
 STA VMT1
VDSOUT LDY #0
VDSO1 CPY VMT1
 BCS VDSO2
 LDA (ZPT1),Y
 STY VMT2
 JSR VPUTC
 LDY VMT2
 INY
 JMP VDSO1
* DISP ends the line and DISPN does not.  One flag
* is the whole difference, and it is what lets
*   DISPLAY "CHOICE? "  then  ACCEPT X
* prompt and read on one line - which every one of
* the sample programs does.  The compiler emits DISPN
* for every operand of a DISPLAY but the last, and
* DISP for the last.
VDSO2 LDA VPRMOD
 BEQ VDSO2C
 CMP #2
 BNE VDSO2P
* the screen for the printer: one line, counted
 STZ VPRMOD
 JSR CONCR
 INC VPGN
 JMP VDSO3
* a printer line ends - unless this is DISPPN, an
* operand before the last (VMNONL, 2026-11-22)
VDSO2P STZ VPRMOD
 LDA VMNONL
 BNE VDSO3
 JSR PRCR
 JMP VDSO3
VDSO2C LDA VMNONL
 BNE VDSO3
 JSR CONCR
VDSO3 STZ VMNONL
 JMP VMLOOP

VDISPL JSR VLIT
 LDA VMPT
 STA STRPTR
 LDA VMPT+1
 STA STRPTR+1
 JSR CONPUTS
 LDA VMNONL
 BNE VDSL1
 JSR CONCR
VDSL1 STZ VMNONL
 JMP VMLOOP

* ---- the printer: $88 DISPP and $89 DISPPL ------
* DISPLAY ... UPON PRINTER.  The device byte that
* follows the opcode picks one of four printers in
* the design (PRINTER.md); today there is the one
* Utilities sets, and the byte is read and passed
* over.  The text goes out exactly as DISPLAY
* draws it - a number through its picture - by the
* same code, with VPUTC sending the characters to
* the printer instead.  These trapped as VBAD until
* 2026-11-08: REPORT's programs are the first to
* print.  With no printer slot set nothing is sent
* and the program runs on.
VDISPP JSR VFETCH
 LDA VPRSCR
 BEQ VDPP1
 JMP VDPS
VDPP1 JSR VPRUP
 LDA #1
 STA VPRMOD
 JMP VDISP
VDISPPL JSR VFETCH
 LDA VPRSCR
 BEQ VDPL0
 JMP VDPLS
VDPL0 JSR VPRUP
 JSR VLIT
 LDA VMPT
 STA STRPTR
 LDA VMPT+1
 STA STRPTR+1
 JSR PRPUTS
 JSR PRCR
 JMP VMLOOP
* VPRUP: PRINIT, once a run
VPRUP LDA VPRON
 BNE VPRU1
 INC VPRON
 JSR PRINIT
VPRU1 RTS
* VPUTC: A to the screen, or to the printer
* VPRMOD 2 is the screen standing in for the
* printer (SET PRINTER TO SCREEN): the console
VPUTC PHA
 LDA VPRMOD
 CMP #1
 BEQ VPUT1
 PLA
 JMP CONPUTC
VPUT1 PLA
 JMP PRPUTC

* ---- $85 ACCF: ACCEPT item FROM DATE | TIME -----
* DTDATE leaves six digits YYMMDD in DTBUF, DTTIME
* eight HHMMSSss.  Into text they go as the digits,
* space filled; into a number through PICDEED, as
* if the operator had typed them.
VACCF JSR VOPD
 JSR VFETCH
 CMP #0
 BNE VAF1
 JSR DTDATE
 LDA #6
 BNE VAF2
* 2 KEY and 3 PREFIX n (2026-11-11)
VAF1 CMP #2
 BNE VAF1P
 JMP VAFK
VAF1P CMP #3
 BNE VAF1T
 JMP VAFP
VAF1T JSR DTTIME
 LDA #8
VAF2 STA VMTLEN
 LDY #0
VAF3 LDA DTBUF,Y
 STA VMTXT,Y
 INY
 CPY VMTLEN
 BCC VAF3
* VMTXT holds VMTLEN characters: into the item, as
* text or through PICDEED as a number
VAFT LDA VMD2+DTYPE
 CMP #TNUM
 BEQ VAF6
 JSR VACZ2
 LDY #0
VAF4 CPY VMD2+DLEN
 BCS VAF7
 LDA #$20
 CPY VMTLEN
 BCS VAF5
 LDA VMTXT,Y
VAF5 STA (ZPT2),Y
 INY
 BNE VAF4
VAF6 LDY VMTLEN
 JMP VAC1T
VAF7 JMP VMLOOP

* $84 DISPN and $8A DISPLN: set the flag, fall in
VDISPN LDA #1
 STA VMNONL
 JMP VDISP
VDISPLN LDA #1
 STA VMNONL
 JMP VDISPL

* ---- $97 DISPPN and $98 DISPPLN (2026-11-22) ----
* An operand of DISPLAY a b c UPON PRINTER that is
* not the last: an item or a literal, no device
* byte, and the line is NOT ended - the last
* operand's DISPP or DISPPL ends it.  Before these
* the compiler sent every operand but the last to
* the SCREEN (FIXLIST A22).
*
* Under SET PRINTER TO SCREEN the line is begun by
* its first operand: VPLBEG lets the held blank
* lines out and makes room, once, and VPLIN says a
* line is open, so the last operand only ends it.
* A line of several operands is never held back as
* blank, even if every one is spaces - the hold is
* for the one-item lines REPORT pads pages with.
VDISPPN LDA VPRSCR
 BNE VDPN1
 JSR VPRUP
 LDA #1
 STA VPRMOD
 STA VMNONL
 JMP VDISP
VDPN1 JSR VPLBEG
 LDA #1
 STA VMNONL
 JMP VDISP
VDISPPLN LDA VPRSCR
 BNE VDPLN1
 JSR VPRUP
 JSR VLIT
 LDA VMPT
 STA STRPTR
 LDA VMPT+1
 STA STRPTR+1
 JSR PRPUTS
 JMP VMLOOP
VDPLN1 JSR VPLBEG
 JSR VLIT
 LDA VMPT
 STA STRPTR
 LDA VMPT+1
 STA STRPTR+1
 JSR CONPUTS
 JMP VMLOOP
VPLBEG LDA VPLIN
 BNE VPLB9
 JSR VPGPRE
 LDA #1
 STA VPLIN
VPLB9 RTS

* $82 AT line column - move the cursor.
* DISPLAY ... AT LINE n COLUMN n compiles to this,
* then the ordinary DISPN/DISPLN for each operand -
* so a positioned number is edited exactly as an
* unpositioned one, and the text goes through the
* console's shadow like any other.  It used to be
* DISPA, which took one item and wrote its raw
* bytes; nothing ever emitted it (2026-11-08).
* COBOL counts from 1.  0 is taken as 1 and anything
* past the edge as the edge, as DSCREEN does.
VAT JSR VATRC
 JMP VMLOOP
VATRC JSR VFETCH
 STA DSLINE
 JSR VFETCH
 STA DSCOL
 LDX DSLINE
 BNE VAT1
 INX
VAT1 CPX #25
 BCC VAT2
 LDX #24
VAT2 DEX
 STX SCRROW
 LDX DSCOL
 BNE VAT3
 INX
VAT3 CPX #81
 BCC VAT4
 LDX #80
VAT4 DEX
 STX SCRCOL
 LDX SCRROW
 JMP SCRADDR

* $87 ACCA line column item - ACCEPT ... AT.
* A form field: DSACC draws it in inverse, the
* operator types into it, RETURN or TAB ends it.
* The width is the item's length for text, and for
* a number the digits its picture allows plus a
* sign and a point.  The field is left inverse when
* it is done - that is DSCREEN's way of showing
* what was entered - but the ATTRIBUTE is put back
* to normal, or every DISPLAY after it would come
* out inverse too.
VACCA JSR VATRC
 JSR VOPD
 JSR VFNTAK
 LDA VMD2+DTYPE
 CMP #TNUM
 BEQ VAA1
 LDA VMD2+DLEN
* a file name: 64 at most.  The field is drawn its
* full width in inverse, so the operator sees the
* room; DSACC has no beep (8.11 - the library had
* no room for a second one)
 LDX VMFNX
 BEQ VAA0
 CMP #65
 BCC VAA0
 LDA #64
VAA0 STA DSLEN
* DSFLGS bit 6 is the field editor's own fold
 LDA VMCASE
 STA DSFLGS
 JSR VACZ2
 JSR DSACC
 STZ SCRATR
 JSR VACZ2
 JMP VAC0
* a number: into VMTXT, then de-edited like VACC's
VAA1 LDA VMD2+DFLG
 LSR
 LSR
 LSR
 LSR
 BNE VAA2
 SEC
 LDA #NDIG
 SBC VMD2+DDEC
* digits + decimals + 1 for the sign, + 1 more for
* the point when there are decimals
VAA2 SEC
 ADC VMD2+DDEC
 LDX VMD2+DDEC
 BEQ VAA3
 CLC
 ADC #1
VAA3 CMP #21
 BCC VAA4
 LDA #20
VAA4 STA DSLEN
 LDA #$80
 STA DSFLGS
 LDA #<VMTXT
 STA ZPT2
 LDA #>VMTXT
 STA ZPT2+1
 JSR DSACC
 STZ SCRATR
 JMP VAC1T

* ACCEPT into a field, then de-edit if the field is
* numeric.  What the operator types is not what the
* picture would have printed, so PICDEED reads the
* intent rather than matching the mask.
VACC JSR VOPD
 JSR VFNTAK
* ACCEPT reads at the CONSOLE cursor, through
* CONGETLN - the line DISPLAY just ended is where the
* operator expects to type.  It used DSACC, the
* positioned field editor, whose row and column
* nobody set, so every ACCEPT drew an inverse field
* at the top left over whatever was there
* (MEDIA, 2026-11-07).
 LDA VMD2+DTYPE
 CMP #TNUM
 BEQ VAC1
 JSR VACZ2
* bit 7 of the length asks CONGETLN to fold letters
* to capitals as they are typed - UPPERCASE ONLY,
* the default.  So the length is held under 128: a
* console ACCEPT takes 127 characters at most.
 LDA VMD2+DLEN
 BPL VACL1
 LDA #127
VACL1 STA VMT2
* A FILE NAME (DECISIONS 8.11, the user's request):
* 64 characters at most - ProDOS's whole pathname -
* however wide the item, and a short beep on each of
* the last seven, so the operator hears it getting
* long.  At 64 the keys stop taking; RETURN, ESC and
* DELETE still work.  A narrower item keeps its own
* width, and the beep is on ITS last seven.
 LDX VMFNX
 BEQ VACL2
 CMP #65
 BCC VACL3
 LDA #64
 STA VMT2
VACL3 SEC
 SBC #7
 BCS VACL4
 LDA #0
VACL4 STA CGWARN
VACL2 LDA VMCASE
 ASL
 ORA VMT2
 JSR CONGETLN
* off again at once: no other line is a file name
 STZ CGWARN
* the closing CR inside CONGETLN may scroll, and a
* scroll moves ZPT2 - so the field address is put
* back before the rest of it is filled with spaces,
* which DSACC used to do
 JSR VACZ2
VAC0 CPY VMD2+DLEN
 BCS VAC0X
 LDA #$20
 STA (ZPT2),Y
 INY
 BNE VAC0
VAC0X JMP VMLOOP
VACZ2 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 RTS

* ---- $99 FNAME: the next ACCEPT is a file name --
* The compiler puts it in front of an ACCEPT whose
* item a SELECT names in ASSIGN TO (CMPPROC4 PDAFN).
* VFNTAK takes it - into VMFNX - and clears it, at
* the start of BOTH ACCEPT handlers, so it can never
* be left over for a later ACCEPT, numeric or not.
VFNAMA LDA #1
 STA VMFNA
 JMP VMLOOP
VFNTAK LDA VMFNA
 STA VMFNX
 STZ VMFNA
 RTS
VMFNA DFB 0
VMFNX DFB 0
VAC1 LDA #<VMTXT
 STA ZPT2
 LDA #>VMTXT
 STA ZPT2+1
 LDA #20
 JSR CONGETLN
VAC1T STY VMTLEN
 LDA #<VMTLEN
 STA ZPT1
 LDA #>VMTLEN
 STA ZPT1+1
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDA VMD2+DDEC
 STA PICSCL
 JSR PICDEED
 JMP VMLOOP

VNL JSR CONCR
 JMP VMLOOP


* ================= 2026-11-11 ===================
* ERASE, SET PRINTER, SET PREFIX, ACCEPT FROM KEY
* and FROM PREFIX, and the menu.

* ---- $8B ERASE dev: a fresh page ----------------
* DISPLAY ERASE is device 0, the screen: cleared,
* and the cursor home.  DISPLAY ERASE UPON PRINTER
* is device 1.  On paper it does nothing - REPORT
* fills each page out with blank lines, and the
* printer's own page length is what turns them -
* but with SET PRINTER TO SCREEN it is the end of a
* report page: if anything is on the screen it
* waits for a key first, then clears.  That is what
* makes a report one page at a time.
VERASE JSR VFETCH
 CMP #0
 BEQ VER1
 LDA VPRSCR
 BEQ VERX
 LDA VPGN
 BEQ VER1
 JSR VPAUSE
VER1 JSR CONCLR
 STZ VPGN
 STZ VPGB
 STZ VPLIN
VERX JMP VMLOOP

* ---- $8C SETPR flag: SET PRINTER TO ... ---------
* 1 SCREEN, 0 PAPER.  Nothing is drawn or cleared
* here; the report's own ERASE UPON PRINTER does
* that at its first heading.
* ---- $8F CASE flag: UPPERCASE ONLY or ANYCASE ---
* $40 or 0, from the ENVIRONMENT DIVISION (CMPENV).
VCASE JSR VFETCH
 STA VMCASE
 JMP VMLOOP

VSETPR JSR VFETCH
 STA VPRSCR
 STZ VPGN
 STZ VPGB
 STZ VPLIN
 JMP VMLOOP

* ---- the screen standing in for the printer -----
* Every DISPLAY ... UPON PRINTER is one line.  A
* line of nothing but spaces is HELD, not shown -
* VPGB counts them - and goes out only when a line
* with something in it follows.  So the blank lines
* REPORT pads the end of a page with never reach
* the screen: the next page's ERASE UPON PRINTER
* throws them away.  The blank lines inside a page
* do show, just late.
* VPGN counts the lines on the screen since it was
* last cleared.  At 22 the next line waits for a
* key and starts a fresh screen: a report page
* longer than the screen comes a screenful at a
* time.  Rows 22 and 23 are left for the pause.
*
* an item: looked at first, then displayed by VDISP
* as on the screen - which fetches it again, so the
* instruction pointer is put back
* A LINE ALREADY BEGUN by DISPPN or DISPPLN is not
* tested for blanks: this last operand ends it.
VDPS LDA VPLIN
 BEQ VDPS0
 STZ VPLIN
 LDA #2
 STA VPRMOD
 JMP VDISP
VDPS0 LDA VMIP
 PHA
 LDA VMIP+1
 PHA
 JSR VOPS
 PLA
 STA VMIP+1
 PLA
 STA VMIP
 LDA VMD1+DTYPE
 CMP #TNUM
 BEQ VDPS2
 LDA VMO1
 STA ZPT1
 LDA VMO1+1
 STA ZPT1+1
 LDY #0
VDPS1 CPY VMD1+DLEN
 BCS VDPSB
 LDA (ZPT1),Y
 CMP #$20
 BNE VDPS2
 INY
 BNE VDPS1
* all spaces: held, and the operand stepped over
VDPSB JSR VFETW
 INC VPGB
 JMP VMLOOP
VDPS2 JSR VPGPRE
 LDA #2
 STA VPRMOD
 JMP VDISP
* a literal
VDPLS LDA VPLIN
 BEQ VDPLS0
 STZ VPLIN
 JSR VLIT
 LDA VMPT
 STA STRPTR
 LDA VMPT+1
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR
 INC VPGN
 JMP VMLOOP
VDPLS0 JSR VLIT
 LDA (VMPT)
 STA VMT2
 LDY #0
VDPL1 CPY VMT2
 BCS VDPLB
 INY
 LDA (VMPT),Y
 CMP #$20
 BEQ VDPL1
 JSR VPGPRE
 LDA VMPT
 STA STRPTR
 LDA VMPT+1
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR
 INC VPGN
 JMP VMLOOP
VDPLB INC VPGB
 JMP VMLOOP

* VPGPRE: the held blank lines, then room for one
* more - each of them may fill the screen
VPGPRE LDA VPGB
 BEQ VPGFUL
 JSR VPGFUL
 JSR CONCR
 INC VPGN
 DEC VPGB
 BRA VPGPRE
VPGFUL LDA VPGN
 CMP #22
 BCC VPGFX
 JSR VPAUSE
 JSR CONCLR
 STZ VPGN
VPGFX RTS

* VPAUSE: the prompt on the bottom row, and a key
VPAUSE LDA #23
 STA SCRROW
 STZ SCRCOL
 STZ SCRATR
 LDX #23
 JSR SCRADDR
 LDA #<MPAUSE
 STA STRPTR
 LDA #>MPAUSE
 STA STRPTR+1
 JSR CONPUTS
 JMP WAITKEY

* ---- $8D SETPX n kind operand: SET PREFIX -------
* n is 0-9 (the compiler takes nothing else, and
* */ cannot be set - PREFIX.S).  kind 1 = the
* operand is a literal, 0 = an item, whose trailing
* spaces are not part of the name.  1/-9/ go into
* the aux card's table; 0/ is ProDOS's own prefix,
* changed with SET_PREFIX after the value is
* expanded - SET PREFIX 0 TO "1/OLD" works.  A 0/
* that ProDOS cannot find is left as it was.
VSETPX JSR VFETCH
 STA VPXN
 JSR VFETCH
 CMP #0
 BEQ VSPI
 JSR VLIT
 LDA VMPT
 STA ZPT1
 LDA VMPT+1
 STA ZPT1+1
 JMP VSPG
VSPI JSR VOPS
 LDA VMO1
 STA ZPT1
 LDA VMO1+1
 STA ZPT1+1
 LDY VMD1+DLEN
VSPI1 CPY #0
 BEQ VSPI2
 DEY
 LDA (ZPT1),Y
 CMP #$20
 BEQ VSPI1
 INY
VSPI2 CPY #65
 BCC VSPI3
 LDY #64
VSPI3 STY VPXBUF
 LDY #0
VSPC CPY VPXBUF
 BCS VSPC2
 LDA (ZPT1),Y
 STA VPXBUF+1,Y
 INY
 BNE VSPC
VSPC2 LDA #<VPXBUF
 STA ZPT1
 LDA #>VPXBUF
 STA ZPT1+1
VSPG LDY VPXN
 BEQ VSP0
 LDX #2
 JSR PXSVC
 JMP VMLOOP
VSP0 LDA (ZPT1)
 BEQ VSPX
 LDX #0
 JSR PXSVC
 JSR MLI
 DFB $C6
 DA VSPP
VSPX JMP VMLOOP
VSPP DFB 1
 DA FNBUF1

* ---- ACCEPT ... FROM KEY ------------------------
* One keystroke, not shown - as typed under ANYCASE,
* a capital under UPPERCASE ONLY.  Into text it
* is the character and spaces; into a number, a
* digit is its value.
VAFK JSR WAITKEY
 AND #$7F
 LDX VMCASE
 BEQ VAFK1
 JSR VMUP
VAFK1 STA VMTXT
 LDA #1
 STA VMTLEN
 JMP VAFT

* ---- ACCEPT ... FROM PREFIX n -------------------
* The prefix as text - /HD/DATA/ - into the item,
* space filled; spaces if it is not set.  0/ is
* asked of ProDOS.
VAFP JSR VFETCH
 CMP #0
 BNE VAFP0
 JSR MLI
 DFB $C7
 DA VAFGP
 JMP VAFP1
VAFP0 TAY
 LDA #<VPXBUF
 STA ZPT2
 LDA #>VPXBUF
 STA ZPT2+1
 LDX #1
 JSR PXSVC
VAFP1 JSR VACZ2
 LDY #0
VAFP2 CPY VMD2+DLEN
 BCS VAFPX
 LDA #$20
 CPY VPXBUF
 BCS VAFP3
 LDA VPXBUF+1,Y
VAFP3 STA (ZPT2),Y
 INY
 BNE VAFP2
VAFPX JMP VMLOOP
VAFGP DFB 1
 DA VPXBUF

* ---- $8E MENU dest flags count lines... ---------
* ACCEPT item FROM MENU "NAME": the compiler read
* NAME.MNU and put its lines in the instruction, so
* the program needs nothing on the disk to show it.
*   flags  bit 0: centre it on the screen
*   count  how many lines
*   then each line: row, column, length, the text
* The screen is cleared and the lines drawn.  A
* line written "1) Add a contact" - a character and
* then ")" - answers to that character, a letter in
* either case; the rest are just drawn.  Any other
* key rings the bell.  A menu with no such line
* takes any key.  The key goes into the item as
* FROM KEY puts it there, upper cased.
* CENTRED: the box round all the lines is moved to
* the middle of the screen, rows and columns - the
* design keeps its shape, only its place changes.
VMENU JSR VOPD
 JSR VFETCH
 STA VMNF
 JSR VFETCH
 STA VMNC
 JSR CONCLR
 STZ VMNK
 STZ VMNDR
 STZ VMNDC
 LDA VMNF
 LSR
 BCS VMN0
 JMP VMN3
VMN0
* the box: rows VMNR0-VMNR1, columns VMNC0 to one
* past the last (VMNC1); then back to the lines
 LDA VMIP
 STA VMNIP
 LDA VMIP+1
 STA VMNIP+1
 LDA #$FF
 STA VMNR0
 STA VMNC0
 STZ VMNR1
 STZ VMNC1
 LDA VMNC
 STA VMNN
 BEQ VMN2
VMN1 JSR VFETCH
 CMP VMNR0
 BCS VMB1
 STA VMNR0
VMB1 CMP VMNR1
 BCC VMB2
 STA VMNR1
VMB2 JSR VFETCH
 STA VMNT1
 CMP VMNC0
 BCS VMB3
 STA VMNC0
VMB3 JSR VFETCH
 STA VMNL
 CLC
 ADC VMNT1
 CMP VMNC1
 BCC VMB4
 STA VMNC1
* past the text
VMB4 CLC
 LDA VMIP
 ADC VMNL
 STA VMIP
 BCC VMB5
 INC VMIP+1
VMB5 DEC VMNN
 BNE VMN1
* row offset: (24 - height) / 2 - top, where the
* height is VMNR1 - VMNR0 + 1
 SEC
 LDA VMNR1
 SBC VMNR0
 STA VMNT1
 SEC
 LDA #23
 SBC VMNT1
 LSR
 SEC
 SBC VMNR0
 STA VMNDR
* column offset: (80 - width) / 2 - left
 SEC
 LDA VMNC1
 SBC VMNC0
 STA VMNT1
 SEC
 LDA #80
 SBC VMNT1
 LSR
 SEC
 SBC VMNC0
 STA VMNDC
VMN2 LDA VMNIP
 STA VMIP
 LDA VMNIP+1
 STA VMIP+1
* draw: each line where it goes, its key noted
VMN3 LDA VMNC
 STA VMNN
 BEQ VMN8
VMN4 JSR VFETCH
 CLC
 ADC VMNDR
 STA SCRROW
 JSR VFETCH
 CLC
 ADC VMNDC
 STA SCRCOL
 STZ SCRATR
 LDX SCRROW
 JSR SCRADDR
 JSR VFETCH
 STA VMNL
 STZ VMNI
 STZ VMNT1
VMN5 LDA VMNI
 CMP VMNL
 BCS VMN6
 JSR VFETCH
 LDX VMNI
 BNE VMN5A
 STA VMNT1
VMN5A CPX #1
 BNE VMN5B
 CMP #$29
 BNE VMN5B
* "x)": x is a key
 LDX VMNK
 CPX #24
 BCS VMN5B
 PHA
 LDA VMNT1
 JSR VMUP
 STA VMNKEY,X
 INC VMNK
 PLA
VMN5B JSR CONPUTC
 INC VMNI
 BRA VMN5
VMN6 DEC VMNN
 BNE VMN4
* the key
VMN8 JSR WAITKEY
 AND #$7F
 JSR VMUP
 LDX VMNK
 BEQ VMN9
VMN8A DEX
 BMI VMN8B
 CMP VMNKEY,X
 BEQ VMN9
 BRA VMN8A
VMN8B JSR BELL
 BRA VMN8
VMN9 STA VMTXT
 LDA #1
 STA VMTLEN
 JMP VAFT
* VMUP: a lower-case letter in A to upper case
VMUP CMP #$61
 BCC VMUPX
 CMP #$7B
 BCS VMUPX
 AND #$DF
VMUPX RTS
