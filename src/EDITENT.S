* EDITENT.S  EDIT entry and screen setup
* PUT from EDIT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* EDIT resolve against each other in pass two.
*
* ================= ENTRY =================
EDIT STZ VIEWMO
 JSR EDINIT
 JSR EDFULL
EMAIN JSR EKEY
 JSR EDISP
 JSR EDRAW
 LDA QUIT
 BEQ EMAIN
 JSR EDFLSH
* a view's lines are a listing, not a program, and
* are not published - EDITVW.S
 LDA VIEWMO
 BNE EMX
 JSR EDPUB
EMX RTS

* ---- EDPUB: publish what is left in aux ---------
* The last thing EDIT does.  EDFLSH has just written
* the line being edited back to its record, so what
* is in auxiliary memory now IS the program - and
* the next overlay has no other way to find out how
* much of it there is, because NLINES goes away with
* this one.
*
* Cheap enough to do unconditionally: a program that
* is never compiled has still cost twenty-four bytes
* and no disk.
EDPUB LDA #$53
 STA SRCSIG
 LDA #$52
 STA SRCSIG+1
 LDA NLINES
 STA SRCLIN
 LDA NLINES+1
 STA SRCLIN+1
* the geometry, from the equates EDINIT set them
* from - not from AXSHIFT and AXRSZ themselves,
* which anything could have changed since
 LDA #AXSH
 STA SRCSHF
 LDA #RECSZ
 STA SRCRSZ
 LDY #0
EDPB1 LDA EDNAME,Y
 STA SRCNAM,Y
 INY
 CPY #17
 BCC EDPB1
 RTS

* ---- EDINIT: an empty program of one line -------
EDINIT JSR INIT80
 JSR CLRSCR
 LDA NBANKS
 BNE EDI1
 JSR FINDBNK
EDI1 LDA #AXSH
 STA AXSHIFT
 LDA #RECSZ
 STA AXRSZ
 STA AXLEN
 LDA #0
 STA AXLEN+1
 JSR AXCAP
 STZ CURLIN
 STZ CURLIN+1
 STZ TOPLIN
 STZ TOPLIN+1
 STZ CURCOL
* overtype is the default (2026-11-08)
 LDA #1
 STA MODE
 STZ QUIT
 STZ LDIRTY
 STZ SELON
 STZ RFLAG
 STZ CVALID
 STZ CLINE
 STZ CLINE+1
 LDA #1
 STA NLINES
 LDA #0
 STA NLINES+1
 JSR SHFBLK
 JSR SHFPUT
 JMP GETPFX

* ---- EDFULL: draw the whole screen --------------
EDFULL JSR HDRAW
 JSR DRAWBAR
 JSR CSYNC
 JSR SETCUR
 JSR DRAWWIN
 JMP DRULE

