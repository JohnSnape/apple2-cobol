* EDITVW.S  EDIT's VIEW: a data file, read only
* PUT from EDIT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* EDIT resolve against each other in pass two.
*
* ================= WHAT VIEW IS ================
* Menu option 7.  COBOL.SYSTEM enters EDIT at
* $8003 instead of $8000, and EDVIEW asks for a
* data file, turns every record into one line of
* text in the editor's own document, and hands it
* to the ordinary editor loop with VIEWMO set.
* Everything that moves the cursor works - arrows,
* page up and down, go to line - and nothing that
* changes the text is let through (VWKEY, below).
* The file is opened INPUT and read with READ
* NEXT, so there is no path by which a view can
* write to it.
*
* THE DICTIONARY SAYS HOW TO READ IT.  NAME.DAT is
* shown through NAME.DCT - the same base name, the
* pair FORMAT and a program's SELECT make between
* them.  A text field is its characters, a NUM
* field is a NUM8 cell turned back into digits and
* a BOOL is Y or N (DICTIONARY.md 3).  The first
* line names the columns.  With no dictionary each
* record is shown as its raw bytes, unprintable
* ones as dots, which is still better than
* refusing.
*
*   RECORD CUST-NAME            CUST-BAL
*   0002   AMY                   00000050
*
* Deleted records are not shown: READ NEXT steps
* over them, so the view and a program agree about
* what is in the file.  The number at the left is
* the RELATIVE KEY, the one a program would READ.
*
* WHAT IS LEFT IN AUX AFTERWARDS IS NOT A PROGRAM.
* The listing is built in the records EDIT keeps a
* program in, so SRCSIG is cleared on the way in
* and EDPUB is skipped on the way out: COMPILE
* straight after a VIEW finds no program, rather
* than compiling a listing.

* the column the first field starts in: the record
* number, under "RECORD", and a space
VWC0 EQU 7

* ---- EDVIEW: the $8003 entry -------------------
EDVIEW JSR EDINIT
 LDA #1
 STA VIEWMO
 STZ SRCSIG
 JSR EDFULL
 LDA #<MVIEW
 STA STRPTR
 LDA #>MVIEW
 STA STRPTR+1
 JSR EPROMP
 BCS EDVX
 JSR VWLOAD
 BCS EDVX
 JSR EDFULL
 JMP EMAIN
EDVX RTS

* ---- VWLOAD: NAMBUF's file -> the document ------
* out: C=1 if it could not be opened at all - the
*      message has been shown, and the menu is the
*      right place to go back to
VWLOAD STZ VHASD
 JSR VWFNAM
 LDA #$49
 LDX #1
 JSR SETSFX
* SETSFX answers in FNBUF1 and leaves FNAMP alone
 LDA #<FNBUF1
 STA FNAMP
 LDA #>FNBUF1
 STA FNAMP+1
 LDA #<DCTBUF
 STA FADDR
 LDA #>DCTBUF
 STA FADDR+1
 STZ FLEN
 LDA #3
 STA FLEN+1
 JSR FLOAD
 BCS VWL1
 INC VHASD
 LDA DCTBUF+4
 STA VVER
VWL1 JSR VWFNAM
 LDA #$04
 LDX #1
 JSR SETSFX
 JSR ESETNM
* A program that stopped without CLOSE leaves file
* 0 marked open, and OPEN would then say 41.
* Closing first costs nothing when nothing is open:
* RECMAN answers 42, which nobody reads.
 JSR VWCLOS
 STZ RMFNO
 LDA #1
 STA RMMODE
 LDA #<FNBUF1
 STA RMNAMP
 LDA #>FNBUF1
 STA RMNAMP+1
 JSR FILOPEN
 BCC VWL2
 JSR VWSTMS
 SEC
 RTS
* A record goes into STAGE, which is 512 bytes; a
* longer one is refused with 34, the COBOL status
* for a record outside the file's bounds.
VWL2 LDA RMLEN+1
 CMP #2
 BCC VWL3
 BNE VWBIG
 LDA RMLEN
 BEQ VWL3
VWBIG JSR VWCLOS
 LDA #$33
 STA RMSTAT
 LDA #$34
 STA RMSTAT+1
 JSR VWSTMS
 SEC
 RTS
VWL3 LDA #<STAGE
 STA RMBUF
 LDA #>STAGE
 STA RMBUF+1
 STZ OLINE
 STZ OLINE+1
 STZ OCOL
 STZ OFULL
 JSR VWHEAD
 JSR OSTORE
VWL4 LDA OFULL
 BNE VWL6
 STZ RMFNO
 JSR FILNEXT
 BCS VWL5
 JSR VWROW
 JSR OSTORE
 JMP VWL4
* 10 is the end of the file and the ordinary way
* out.  Anything else is a fault, and what was read
* before it is kept and shown.
VWL5 LDA RMSTAT
 CMP #$31
 BNE VWL5E
 LDA RMSTAT+1
 CMP #$30
 BEQ VWL6
VWL5E JSR VWDONE
 JSR VWSTMS
 CLC
 RTS
VWL6 JSR VWDONE
 LDA OFULL
 BEQ VWL7
 LDA #<MFULL
 LDX #>MFULL
 JSR EMSG
VWL7 CLC
 RTS

* ---- VWDONE: close it, and the lines are the doc -
VWDONE JSR VWCLOS
 LDA OLINE
 STA NLINES
 LDA OLINE+1
 STA NLINES+1
 JMP EDSTAL

VWCLOS STZ RMFNO
 JMP FILCLOS

* ---- VWFNAM: FNAMP -> what was typed -----------
VWFNAM LDA #<NAMBUF
 STA FNAMP
 LDA #>NAMBUF
 STA FNAMP+1
 RTS

* ---- VWSTMS: the file status, then a key -------
VWSTMS LDA RMSTAT
 STA MVWSC
 LDA RMSTAT+1
 STA MVWSC+1
 LDA #<MVWST
 LDX #>MVWST
 JMP EMSG

* ---- VWHEAD: the column names -> SHFBUF --------
VWHEAD JSR SHFBLK
 STZ VCOL
 LDA #<MVREC
 LDX #>MVREC
 JSR VSTR
 LDA #VWC0
 STA VSTRT
 STA VCOL
 LDA VHASD
 BNE VWH1
 LDA #<MVRAW
 LDX #>MVRAW
 JMP VSTR
VWH1 STZ VFI
VWH2 LDA VFI
 CMP DCTBUF+8
 BCS VWHX
 LDA VSTRT
 CMP #RECSZ
 BCS VWHX
 JSR VWDESC
 LDY #0
VWH3 CPY VNLEN
 BCS VWH4
 LDA (ZPT2),Y
 JSR VPUT
 INY
 JMP VWH3
VWH4 JSR VNEXTC
 INC VFI
 JMP VWH2
VWHX RTS

* ---- VWROW: the record in STAGE -> SHFBUF -------
VWROW JSR SHFBLK
 STZ VCOL
 JSR VRECN
 LDA #VWC0
 STA VSTRT
 STA VCOL
 LDA VHASD
 BNE VWR1
 JMP VWRAW
VWR1 STZ VFI
VWR2 LDA VFI
 CMP DCTBUF+8
 BCS VWRX
 LDA VSTRT
 CMP #RECSZ
 BCS VWRX
 JSR VWDESC
 CLC
 LDA #<STAGE
 ADC VROF
 STA ZPT1
 LDA #>STAGE
 ADC VROF+1
 STA ZPT1+1
 LDA VTYP
 CMP #2
 BEQ VWR3
 BCS VWR4
 JSR VTEXT
 JMP VWR5
VWR3 JSR VNUM
 JMP VWR5
VWR4 JSR VBOOL
VWR5 JSR VNEXTC
 INC VFI
 JMP VWR2
VWRX RTS

* ---- VWRAW: no dictionary - the bytes as they are
VWRAW LDA #<STAGE
 STA ZPT1
 LDA #>STAGE
 STA ZPT1+1
 LDA #RECSZ-VWC0
 STA VSTL
 LDA RMLEN+1
 BNE VRW1
 LDA RMLEN
 CMP VSTL
 BCS VRW1
 STA VSTL
VRW1 JMP VTEXT

* ---- VWDESC: field VFI's descriptor ------------
* out: ZPT2 -> it, and VTYP VWID VDEC VROF VSTL,
*      VNLEN the name's length, VCW the column's
* VFI * 24 is SIXTEEN bits - field 11 is at 264 -
* the same trap SLDESC and GETFLD document.
VWDESC LDA VFI
 ASL
 CLC
 ADC VFI
 STA VWT
 STZ VWT+1
 ASL VWT
 ROL VWT+1
 ASL VWT
 ROL VWT+1
 ASL VWT
 ROL VWT+1
 CLC
 LDA VWT
 ADC DCTBUF+12
 STA VWT
 LDA VWT+1
 ADC DCTBUF+13
 STA VWT+1
 CLC
 LDA VWT
 ADC #<DCTBUF
 STA ZPT2
 LDA VWT+1
 ADC #>DCTBUF
 STA ZPT2+1
* A version 1 dictionary kept NUM as digit text, so
* there every field is shown as text - which is
* what it is in a file written under it.
 LDY #10
 LDA (ZPT2),Y
 LDX VVER
 CPX #2
 BCS VWD1
 LDA #1
VWD1 STA VTYP
 INY
 LDA (ZPT2),Y
 STA VWID
 INY
 LDA (ZPT2),Y
 STA VDEC
 INY
 LDA (ZPT2),Y
 STA VROF
 INY
 LDA (ZPT2),Y
 STA VROF+1
 INY
 LDA (ZPT2),Y
 STA VSTL
* how wide the value is when shown
 LDA VTYP
 CMP #2
 BEQ VWD2
 BCS VWD3
 LDA VSTL
 JMP VWD4
* a sign, the digits, and a point if it has one
VWD2 LDA VWID
 CMP #NDIG+1
 BCC VWD2A
 LDA #NDIG
 STA VWID
VWD2A CLC
 ADC #1
 LDX VDEC
 BEQ VWD4
 ADC #1
 JMP VWD4
VWD3 LDA #1
VWD4 STA VDW
* the name, trailing spaces and zeros trimmed
 LDY #10
VWD5 DEY
 BMI VWD6
 LDA (ZPT2),Y
 AND #$7F
 CMP #$21
 BCC VWD5
VWD6 INY
 STY VNLEN
* the column is as wide as the wider of the two
 LDA VDW
 CMP VNLEN
 BCS VWD7
 LDA VNLEN
VWD7 STA VCW
 RTS

* ---- VNEXTC: on to the next column -------------
VNEXTC CLC
 LDA VSTRT
 ADC VCW
 ADC #1
 STA VSTRT
 STA VCOL
 RTS

* ---- VTEXT: VSTL bytes at ZPT1 ------------------
* A zero byte is a space: it is what a record the
* file grew past holds, and a dot for every one
* would make a gap look like damage.
VTEXT LDY #0
VTX1 CPY VSTL
 BCS VTX4
 LDA (ZPT1),Y
 AND #$7F
 BEQ VTX2
 CMP #$20
 BCS VTX3
 LDA #$2E
 BNE VTX3
VTX2 LDA #$20
VTX3 JSR VPUT
 INY
 JMP VTX1
VTX4 RTS

* ---- VNUM: the NUM8 cell at ZPT1 ----------------
* A sign column, then the last VWID of the cell's
* fourteen digits, with a point before the last
* VDEC.  Digit i is in byte 1 + i/2, the high
* nibble when i is even - BCD.S's own numbering.
VNUM LDY #0
 LDA (ZPT1),Y
 AND #$80
 BEQ VNM0
 LDA #$2D
 BNE VNM1
VNM0 LDA #$20
VNM1 JSR VPUT
 SEC
 LDA #NDIG
 SBC VWID
 STA VDI
VNM2 LDA VDI
 CMP #NDIG
 BCS VNM6
 LDA VDEC
 BEQ VNM3
 SEC
 LDA #NDIG
 SBC VDI
 CMP VDEC
 BNE VNM3
 LDA #$2E
 JSR VPUT
VNM3 LDA VDI
 LSR
 TAY
 INY
 LDA (ZPT1),Y
 PHA
 LDA VDI
 AND #1
 BNE VNM4
 PLA
 LSR
 LSR
 LSR
 LSR
 JMP VNM5
VNM4 PLA
 AND #$0F
VNM5 ORA #$30
 JSR VPUT
 INC VDI
 JMP VNM2
VNM6 RTS

* ---- VBOOL: the cell 1 or 0 as Y or N -----------
VBOOL LDY #NCELL-1
 LDA (ZPT1),Y
 BEQ VBL1
 LDA #$59
 BNE VBL2
VBL1 LDA #$4E
VBL2 JMP VPUT

* ---- VRECN: RMREC in decimal at VCOL ------------
* Four digits, or five once the key passes 9999 -
* repeated subtraction, which is four comparisons a
* digit at worst and no division routine.
VRECN LDA RMREC
 STA VWT
 LDA RMREC+1
 STA VWT+1
 LDX #0
VRN1 LDY #$30
VRN2 SEC
 LDA VWT
 SBC VPOW,X
 STA VWT2
 LDA VWT+1
 SBC VPOW+1,X
 BCC VRN3
 STA VWT+1
 LDA VWT2
 STA VWT
 INY
 JMP VRN2
VRN3 TYA
 CPX #0
 BNE VRN4
 CMP #$30
 BEQ VRN5
VRN4 STX VSAV
 JSR VPUT
 LDX VSAV
VRN5 INX
 INX
 CPX #10
 BCC VRN1
 RTS
VPOW DA 10000
 DA 1000
 DA 100
 DA 10
 DA 1

* ---- VSTR: A/X -> a string, out at VCOL ---------
VSTR STA ZPT1
 STX ZPT1+1
 LDY #0
 LDA (ZPT1),Y
 STA VWT
VST1 CPY VWT
 BCS VST2
 INY
 LDA (ZPT1),Y
 JSR VPUT
 JMP VST1
VST2 RTS

* ---- VPUT: A -> SHFBUF at VCOL, then step -------
* Keeps Y.  Seven bits, because the editor's lines
* are low ASCII and Merlin's ASC is not.  Past
* column 80 the character is dropped: a line is
* eighty and a record wider than that is cut, the
* same rule Open follows.
VPUT LDX VCOL
 CPX #RECSZ
 BCS VPU1
 AND #$7F
 STA SHFBUF,X
 INC VCOL
VPU1 RTS

* ---- VWKEY: may this key run in a view? ---------
* out: C=1 to refuse it.  Cursor movement, page
* up and down, go to line, and ESC.  Not typing,
* not RETURN (which splits a line), not delete,
* not any Solid-Apple command, and not OA-N, OA-O
* or OA-S - a view has nothing to save and nothing
* to start over.
* Cut and Paste change the text: refused.  Copy and
* the selection are let through, and Solid-Apple's
* arrows, which page since 2026-11-11.
VWKEY LDA CHMOD
 BMI VWK2
 AND #$40
 BNE VWKSA
 LDA CHKEY
 CMP #$0D
 BEQ VWKN
 CMP #$18
 BEQ VWKN
 CMP #$10
 BEQ VWKN
 CMP #$20
 BCS VWKN
 CLC
 RTS
VWKSA LDA CHKEY
 CMP #$0B
 BEQ VWKY
 CMP #$0A
 BEQ VWKY
 CMP #$08
 BEQ VWKY
 CMP #$15
 BNE VWKN
VWKY CLC
 RTS
VWK2 LDA CHKEY
 AND #$DF
 CMP #$4E
 BEQ VWKN
 CMP #$4F
 BEQ VWKN
 CMP #$53
 BEQ VWKN
 CLC
 RTS
VWKN SEC
 RTS

* ---- strings ----
MVIEW DFB 20
 ASC 'Data file to view?  '
MVREC DFB 6
 ASC 'RECORD'
MVRAW DFB 27
 ASC '(no dictionary - raw bytes)'
* the two dots become the file status
MVWST DFB 28
 ASC 'File status '
MVWSC ASC '..'
 ASC ' - press a key'

* ---- variables ----
* 1 while EDIT is a VIEW; EDIT's own entry clears it
VIEWMO DFB 0
VHASD DFB 0
VVER DFB 0
VFI DFB 0
VCOL DFB 0
VSTRT DFB 0
VTYP DFB 0
VWID DFB 0
VDEC DFB 0
VROF DS 2
VSTL DFB 0
VDW DFB 0
VNLEN DFB 0
VCW DFB 0
VDI DFB 0
VSAV DFB 0
VWT DS 2
VWT2 DFB 0
