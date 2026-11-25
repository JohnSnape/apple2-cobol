* FMTMNU.S  FORMAT's menu mode
* PUT from FORMAT.S, before FORMATD - no ORG, not
* assembled alone.  One symbol table spans every
* PUT.  Written 2026-11-11.
*
* A MENU IS A SCREEN WITH NOTHING TO TYPE INTO.  The
* user asked for menus designed in FORMAT, saved as
* .MNU so the compiler knows one when it sees it,
* and shown by a program with one statement:
*     ACCEPT CHOICE FROM MENU "MAIN"
* which clears the screen, draws MAIN.MNU - in the
* middle of the screen if it was saved that way -
* and waits for one of its keys (CMPSET.S, VMSCRN.S).
*
* OA-M starts one.  Each line is a row, a column and
* its text, up to 72 characters - FORMAT's fields
* have 15-character labels, too short for "1) Add a
* contact", so a menu keeps its own lines.  A line
* written "1) ..." or "A) ..." answers to the key
* before the ")"; any other line is a title or a
* note and is only drawn.  OA-D takes a line out by
* its row; OA-S saves NAME.MNU and asks whether to
* centre it; OA-O opens one again (type NAME.MNU);
* OA-N goes back to designing a form.
*
* THE LINES LIVE AT $6000, the band under FORMAT,
* which loads at $8000 and leaves $6000-$7FFF to
* nobody.  Slot n is MNTAB + 80n: row, column,
* length, then the text - so slot+2 is a length-
* prefixed string PUTS can draw as it is.  The file
* is built at MNIMG, $7000, the same way.
*
* THE FILE, type $4E MNU (FILETYPES.md):
*     'MNU1'  flags  count  then per line:
*     row  column  length  the text
* flags bit 0 = centre it.  The compiler copies
* everything after the signature into the program
* unchanged, so the file IS the instruction's tail.
MNTAB EQU $6000
MNIMG EQU $7000
MNMAX EQU 22

* ---- MNENT: a menu line, after Row? --------------
* EROW is in hand.  GETENT comes here instead of to
* Column? when the design is a menu.
MNENT LDA #<PCOL
 STA STRPTR
 LDA #>PCOL
 STA STRPTR+1
 JSR LINEIN
 LDA LIRES
 BNE MNEX
 LDA LLEN
 BEQ MNEX
 JSR ATOI
 STA ECOL
* the text may be long: LINEIN takes up to 72 here
 LDA #72
 STA LIMAX
 LDA #<PTXT
 STA STRPTR
 LDA #>PTXT
 STA STRPTR+1
 JSR LINEIN
 LDA #38
 STA LIMAX
 LDA LIRES
 BNE MNEX
 LDA LLEN
 BEQ MNEX
 JSR MNADD
MNEX JMP GETENT

* ---- MNADD: EROW ECOL and LBUF/LLEN -> a slot ----
MNADD LDA MNCNT
 CMP #MNMAX
 BCC MNA1
 LDA #<EMFUL
 LDX #>EMFUL
 JMP AESHOW
MNA1 LDA EROW
 CMP #22
 BCS MNABAD
 LDA ECOL
 CMP #80
 BCS MNABAD
 CLC
 ADC LLEN
 CMP #81
 BCC MNA2
MNABAD LDA #<EMBAD
 LDX #>EMBAD
 JMP AESHOW
* A line "x)" may not take a key another line has
* already: the program gets the key alone, so two
* "Q)" lines - or "q)" and "Q)", since the key is
* upper cased - could never be told apart, and the
* second would be a choice nobody can make.  The
* new line's key is the first character when the
* second is ")", the rule VMSCRN.S uses to find
* keys when it draws the menu (2026-11-11).
MNA2 LDA LLEN
 CMP #2
 BCC MNA2K
 LDA LBUF+1
 CMP #$29
 BNE MNA2K
 LDA LBUF
 JSR MNUPC
 STA MNKC
* every line already there, the same test; MNSLOT
* uses MNT and MNT2, so the walk counts in MNJ
 STZ MNJ
MNK1 LDA MNJ
 CMP MNCNT
 BCS MNA2K
 JSR MNSLOT
 LDY #2
 LDA (ZPWORK),Y
 CMP #2
 BCC MNK2
 LDY #4
 LDA (ZPWORK),Y
 CMP #$29
 BNE MNK2
 DEY
 LDA (ZPWORK),Y
 JSR MNUPC
 CMP MNKC
 BNE MNK2
 LDA #<EMDUP
 LDX #>EMDUP
 JMP AESHOW
MNK2 INC MNJ
 BRA MNK1
MNA2K LDA MNCNT
 JSR MNSLOT
 LDY #0
 LDA EROW
 STA (ZPWORK),Y
 INY
 LDA ECOL
 STA (ZPWORK),Y
 INY
 LDA LLEN
 STA (ZPWORK),Y
 LDX #0
MNA3 CPX LLEN
 BCS MNA4
 INY
 LDA LBUF,X
 STA (ZPWORK),Y
 INX
 BNE MNA3
MNA4 LDA MNCNT
 INC MNCNT
* and fall into MNONE to draw it

* ---- MNONE: draw slot A --------------------------
MNONE JSR MNSLOT
 LDA (ZPWORK)
 STA SCRROW
 LDY #1
 LDA (ZPWORK),Y
 STA SCRCOL
 STZ SCRATR
 CLC
 LDA ZPWORK
 ADC #2
 STA STRPTR
 LDA ZPWORK+1
 ADC #0
 STA STRPTR+1
 JMP PUTS

* ---- MNUPC: A upper cased if a lower-case letter -
* the same as the VM's VMUP, so FORMAT and the
* running program agree on what one key is
MNUPC CMP #$61
 BCC MNU1
 CMP #$7B
 BCS MNU1
 AND #$DF
MNU1 RTS

* ---- MNDRAW: every line --------------------------
MNDRAW STZ MNI
MND1 LDA MNI
 CMP MNCNT
 BCS MND2
 JSR MNONE
 INC MNI
 BRA MND1
MND2 RTS

* ---- MNSLOT: A = slot -> ZPWORK = MNTAB + 80A ----
* 80 is 64 + 16
MNSLOT STA MNT
 STZ ZPWORK+1
 ASL
 ASL
 ASL
 ASL
 STA ZPWORK
 ROL ZPWORK+1
 LDA MNT
 STZ MNT2
 ASL
 ROL MNT2
 ASL
 ROL MNT2
 ASL
 ROL MNT2
 ASL
 ROL MNT2
 ASL
 ROL MNT2
 ASL
 ROL MNT2
 CLC
 ADC ZPWORK
 STA ZPWORK
 LDA MNT2
 ADC ZPWORK+1
 ADC #>MNTAB
 STA ZPWORK+1
 RTS

* ---- MNNEW: OA-M, a new menu ---------------------
* The same question OA-N asks, and on Y the same
* clearing (CONFNEW), then menu mode.
MNNEW JSR CONFNEW
 LDA CFK
 AND #$DF
 CMP #$59
 BNE MNNX
 LDA #1
 STA FMENU
 JSR DRAWBAR
MNNX RTS

* ---- MNDEL: OA-D in a menu: the lines on a row ---
MNDEL LDA #<PROW
 STA STRPTR
 LDA #>PROW
 STA STRPTR+1
 JSR LINEIN
 LDA LIRES
 BNE MNDX
 LDA LLEN
 BEQ MNDX
 JSR ATOI
 STA DROW
* walk the slots; a match is closed up by moving
* every later slot down one, 80 bytes at a time
 STZ MNI
MNL1 LDA MNI
 CMP MNCNT
 BCS MNL9
 JSR MNSLOT
 LDA (ZPWORK)
 CMP DROW
 BEQ MNL2
 INC MNI
 BRA MNL1
MNL2 LDA MNI
 STA MNJ
MNL3 LDA MNJ
 CLC
 ADC #1
 CMP MNCNT
 BCS MNL5
 JSR MNSLOT
 LDA ZPWORK
 STA ZPT1
 LDA ZPWORK+1
 STA ZPT1+1
 LDA MNJ
 JSR MNSLOT
 LDY #79
MNL4 LDA (ZPT1),Y
 STA (ZPWORK),Y
 DEY
 BPL MNL4
 INC MNJ
 BRA MNL3
MNL5 DEC MNCNT
 BRA MNL1
MNL9 JSR CLRDAT
 JSR MNDRAW
MNDX RTS

* ---- MNSAVE: OA-S in a menu -> NAME.MNU ----------
* NAMEBUF has the name; .MNU is put on whatever was
* typed, and a prefix name in it works (FISPLT).
MNSAVE LDA #<NAMEBUF
 STA FNAMP
 LDA #>NAMEBUF
 STA FNAMP+1
 LDA #$4E
 LDX #1
 JSR SETSFX
* centred?
 JSR CLRLINE
 LDA #<PCTR
 STA STRPTR
 LDA #>PCTR
 STA STRPTR+1
 LDA #23
 STA SCRROW
 STZ SCRCOL
 STZ SCRATR
 JSR PUTS
 STZ MNFLG
MNS0 LDA KBD
 BPL MNS0
 BIT KBDSTRB
 AND #$5F
 CMP #$4E
 BEQ MNS1
 CMP #$59
 BNE MNS0
 INC MNFLG
* the image at MNIMG: signature, flags, count, then
* each slot's row, column, length and text
MNS1 LDX #3
MNS2 LDA MNSIGF,X
 STA MNIMG,X
 DEX
 BPL MNS2
 LDA MNFLG
 STA MNIMG+4
 LDA MNCNT
 STA MNIMG+5
 LDA #<MNIMG+6
 STA ZPT2
 LDA #>MNIMG+6
 STA ZPT2+1
 STZ MNI
MNS3 LDA MNI
 CMP MNCNT
 BCS MNS5
 JSR MNSLOT
 LDY #2
 LDA (ZPWORK),Y
 CLC
 ADC #2
 TAY
MNS4 LDA (ZPWORK),Y
 STA (ZPT2),Y
 DEY
 BPL MNS4
 LDY #2
 LDA (ZPWORK),Y
 SEC
 ADC #2
 CLC
 ADC ZPT2
 STA ZPT2
 BCC MNS4A
 INC ZPT2+1
MNS4A INC MNI
 BRA MNS3
* the length is how far ZPT2 got
MNS5 SEC
 LDA ZPT2
 SBC #<MNIMG
 STA FLEN
 LDA ZPT2+1
 SBC #>MNIMG
 STA FLEN+1
 LDA #<FNBUF1
 STA FNAMP
 LDA #>FNBUF1
 STA FNAMP+1
 LDA #<MNIMG
 STA FADDR
 LDA #>MNIMG
 STA FADDR+1
 STZ FAUX
 STZ FAUX+1
 JSR FSAVE
 BCS MNSER
 LDA #<MSAVED
 LDX #>MSAVED
 JMP AESHOW
MNSER LDA #<MSVERR
 LDX #>MSVERR
 JMP FESHOW

* ---- MNISM: is NAMEBUF NAME.MNU?  C=0 if so ------
MNISM LDX NAMEBUF
 CPX #5
 BCC MNIN
 LDY #3
MNI1 LDA NAMEBUF,X
 AND #$7F
 CMP #$61
 BCC MNI2
 AND #$DF
MNI2 CMP MNSFX,Y
 BNE MNIN
 DEX
 DEY
 BPL MNI1
 CLC
 RTS
MNIN SEC
 RTS

* ---- MNOPEN: OA-O of a NAME.MNU ------------------
MNOPEN LDA #<NAMEBUF
 STA FNAMP
 LDA #>NAMEBUF
 STA FNAMP+1
 LDA #<MNIMG
 STA FADDR
 LDA #>MNIMG
 STA FADDR+1
 STZ FLEN
 LDA #8
 STA FLEN+1
 JSR FLOAD
 BCS MNOER
 LDX #3
MNO1 LDA MNIMG,X
 CMP MNSIGF,X
 BNE MNOER
 DEX
 BPL MNO1
* into the slots, the reverse of MNSAVE
 LDA #0
 STA FCOUNT
 STA RECTOT
 STA RECTOT+1
 LDA MNIMG+5
 CMP #MNMAX+1
 BCS MNOER
 STA MNCNT
 LDA #<MNIMG+6
 STA ZPT2
 LDA #>MNIMG+6
 STA ZPT2+1
 STZ MNI
MNO2 LDA MNI
 CMP MNCNT
 BCS MNO4
 JSR MNSLOT
 LDY #2
 LDA (ZPT2),Y
 CMP #73
 BCS MNOER
 CLC
 ADC #2
 TAY
MNO3 LDA (ZPT2),Y
 STA (ZPWORK),Y
 DEY
 BPL MNO3
 LDY #2
 LDA (ZPT2),Y
 SEC
 ADC #2
 CLC
 ADC ZPT2
 STA ZPT2
 BCC MNO3A
 INC ZPT2+1
MNO3A INC MNI
 BRA MNO2
MNO4 LDA #1
 STA FMENU
 JSR CLRDAT
 JSR DRAWBAR
 JMP MNDRAW
MNOER STZ MNCNT
 LDA #<MOPERR
 LDX #>MOPERR
 JMP FESHOW

* ---- strings and variables -----------------------
PTXT DFB 6
 ASC 'Text? '
PCTR DFB 30
 ASC 'Centre it on the screen? Y/N  '
MBARM DFB 7
 ASC 'Menu:  '
* 'MNU1' and '.MNU', as bytes
MNSIGF DFB $4D,$4E,$55,$31
MNSFX DFB $2E,$4D,$4E,$55
FMENU DFB 0
MNCNT DFB 0
MNFLG DFB 0
MNI DFB 0
MNJ DFB 0
MNT DFB 0
MNT2 DFB 0
* the new line's key, for the duplicate test
MNKC DFB 0
EMDUP DFB 22
 ASC 'Key already used (key)'
