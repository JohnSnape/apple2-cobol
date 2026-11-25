* EDITCMD.S  EDIT's keystroke handlers
* PUT from EDIT.S - not assembled on its own, and
* it has no ORG.  PUT drops it in at the point of
* the PUT line, so every address is exactly what it
* would be inline; the split is purely so EDIT.S
* fits Merlin's editor.
*
* This is the MOVING and CHANGING sections: cursor
* motion (arrows, TAB, page up/down, go-to-line),
* the edits (type, backspace, insert/delete line,
* new program) and GETPFX, the prefix read used at
* start-up.
*
* ONE SYMBOL TABLE SPANS THE PUT.  These handlers
* are the JMP targets of the dispatch in EDIT.S
* (EDISP / EDOA / EDSA), and they call back into
* the ring (SETCUR, CSYNC, EDFLSH, EDMOVE, CMP16),
* the shuffle (INSLIN, DELLIN, SHFBLK, EDSTAL), the
* rule prompt (ASK), the messages and the
* variables - all of which live in EDIT.S.  Merlin
* resolves it in its second pass, as if the files
* were one.
*
* ================= MOVING =================
DLEFT LDA CURCOL
 BEQ DLR
 DEC CURCOL
DLR RTS

DRIGHT LDA CURCOL
 CMP #RECSZ-1
 BCS DRR
 INC CURCOL
DRR RTS

* TAB is four columns because that is the step from
* Area A to Area B.
* Tab stops are the 1-based columns 1, 5, 9, 13,
* 17 ... - CURCOL 0, 4, 8, 12, 16 - so TAB snaps to
* the next multiple of four rather than just adding
* four.  AND #$FC rounds the current column DOWN to
* a stop; +4 is then the next stop up.  Off a stop
* (after typing) it still lands on the grid instead
* of drifting: from column 1 the first TAB reaches
* column 5, and every TAB after lands on 9, 13, 17.
DTAB LDA CURCOL
 AND #$FC
 CLC
 ADC #4
 CMP #RECSZ
 BCC DTB1
 LDA #RECSZ-1
DTB1 STA CURCOL
 RTS

* ---- DEOL: past the last character on the line --
DEOL LDY #RECSZ-1
DEO1 LDA (EDPTR),Y
 CMP #$20
 BNE DEO2
 DEY
 BPL DEO1
 LDY #$FF
DEO2 INY
 CPY #RECSZ
 BCC DEO3
 LDY #RECSZ-1
DEO3 STY CURCOL
 RTS

* ---- EDMOVE: the cursor has changed line --------
EDMOVE JSR VSCROLL
 JSR CSYNC
 JMP SETCUR

DUPL LDA CURLIN
 ORA CURLIN+1
 BEQ DUR
 JSR EDFLSH
 SEC
 LDA CURLIN
 SBC #1
 STA CURLIN
 LDA CURLIN+1
 SBC #0
 STA CURLIN+1
 JMP EDMOVE
DUR RTS

DDOWNL CLC
 LDA CURLIN
 ADC #1
 STA C1
 LDA CURLIN+1
 ADC #0
 STA C1+1
 LDA NLINES
 STA C2
 LDA NLINES+1
 STA C2+1
 JSR CMP16
 BCS DDR
 JSR EDFLSH
 LDA C1
 STA CURLIN
 LDA C1+1
 STA CURLIN+1
 JMP EDMOVE
DDR RTS

DPGUP JSR EDFLSH
 SEC
 LDA CURLIN
 SBC #NPROG
 STA CURLIN
 LDA CURLIN+1
 SBC #0
 STA CURLIN+1
 BCS DPU1
 LDA #0
 STA CURLIN
 STA CURLIN+1
DPU1 JMP EDMOVE

DPGDN JSR EDFLSH
 CLC
 LDA CURLIN
 ADC #NPROG
 STA C1
 LDA CURLIN+1
 ADC #0
 STA C1+1
 SEC
 LDA NLINES
 SBC #1
 STA C2
 LDA NLINES+1
 SBC #0
 STA C2+1
 JSR CMP16
 BCC DPD1
 LDA C2
 STA C1
 LDA C2+1
 STA C1+1
DPD1 LDA C1
 STA CURLIN
 LDA C1+1
 STA CURLIN+1
 JMP EDMOVE

* ---- DGOTO: OA-G, go to a line by number --------
* What the gutter used to be for.  COMPILE will
* reach the same place by setting CURLIN itself.
DGOTO JSR PRMPT
 LDA #<MGOTO
 STA STRPTR
 LDA #>MGOTO
 STA STRPTR+1
 JSR PUTS
 LDA #<GBUF
 STA ZPT2
 LDA #>GBUF
 STA ZPT2+1
 LDA #5
 JSR GETLN80
 BCS DGO9
 STY GLEN
 LDA GLEN
 BEQ DGO9
 JSR ED10V
 LDA SVAL
 ORA SVAL+1
 BEQ DGO9
 SEC
 LDA SVAL
 SBC #1
 STA C1
 LDA SVAL+1
 SBC #0
 STA C1+1
 SEC
 LDA NLINES
 SBC #1
 STA C2
 LDA NLINES+1
 SBC #0
 STA C2+1
 JSR CMP16
 BCC DGO1
 LDA C2
 STA C1
 LDA C2+1
 STA C1+1
DGO1 JSR EDFLSH
 LDA C1
 STA CURLIN
 LDA C1+1
 STA CURLIN+1
 LDA #0
 STA CURCOL
 JSR EDMOVE
 LDA RFLAG
 ORA #2
 STA RFLAG
DGO9 RTS

* ---- ED10V: GBUF, GLEN digits -> SVAL -----------
* val = val*10 + digit, and *10 is ((val*4)+val)*2
* because there is no multiply.
ED10V LDA #0
 STA SVAL
 STA SVAL+1
 LDX #0
ED1A CPX GLEN
 BCS ED1D
 LDA GBUF,X
 CMP #$30
 BCC ED1D
 CMP #$3A
 BCS ED1D
 SEC
 SBC #$30
 STA CMA
 LDA SVAL
 STA CT
 LDA SVAL+1
 STA CT+1
 ASL SVAL
 ROL SVAL+1
 ASL SVAL
 ROL SVAL+1
 CLC
 LDA SVAL
 ADC CT
 STA SVAL
 LDA SVAL+1
 ADC CT+1
 STA SVAL+1
 ASL SVAL
 ROL SVAL+1
 CLC
 LDA SVAL
 ADC CMA
 STA SVAL
 LDA SVAL+1
 ADC #0
 STA SVAL+1
 INX
 JMP ED1A
ED1D RTS

* ---- VSCROLL: keep the cursor in the window -----
VSCROLL SEC
 LDA CURLIN
 SBC TOPLIN
 STA VT
 LDA CURLIN+1
 SBC TOPLIN+1
 STA VT+1
 BCC VSUP
 LDA VT+1
 BNE VSDN
 LDA VT
 CMP #NPROG
 BCS VSDN
 RTS
VSUP LDA CURLIN
 STA TOPLIN
 LDA CURLIN+1
 STA TOPLIN+1
 JMP VSCHG
VSDN SEC
 LDA CURLIN
 SBC #NPROG-1
 STA TOPLIN
 LDA CURLIN+1
 SBC #0
 STA TOPLIN+1
VSCHG LDA RFLAG
 ORA #2
 STA RFLAG
 RTS

* ================= CHANGING =================
* ---- DTYPE: a character at the cursor -----------
DTYPE LDA CURCOL
 CMP #RECSZ
 BCS DTR
 LDA MODE
 BNE DTOVR
* insert: everything from the cursor rightward
* moves up one, and the last character falls off
* the end of the line.
 LDY #RECSZ-1
DTI1 CPY CURCOL
 BEQ DTI2
 DEY
 LDA (EDPTR),Y
 INY
 STA (EDPTR),Y
 DEY
 JMP DTI1
DTI2 LDA CHKEY
 LDY CURCOL
 STA (EDPTR),Y
 JSR EDDIRT
 JMP ADVCOL
DTOVR LDA CHKEY
 LDY CURCOL
 STA (EDPTR),Y
 JSR EDDIRT
 JMP ADVCOL
DTR RTS

ADVCOL LDA CURCOL
 CMP #RECSZ-1
 BCS ADR
 INC CURCOL
ADR RTS

* ---- DBS: rub out the character behind ----------
DBS LDA CURCOL
 BEQ DBSR
 DEC CURCOL
 LDY CURCOL
DBS1 CPY #RECSZ-1
 BCS DBS2
 INY
 LDA (EDPTR),Y
 DEY
 STA (EDPTR),Y
 INY
 JMP DBS1
DBS2 LDA #$20
 LDY #RECSZ-1
 STA (EDPTR),Y
 JSR EDDIRT
DBSR RTS

* ---- DRET: a blank line below, and go to it -----
DRET JSR EDFLSH
 CLC
 LDA CURLIN
 ADC #1
 STA INSP
 LDA CURLIN+1
 ADC #0
 STA INSP+1
 JSR INSLIN
 BCS DRT1
 LDA INSP
 STA CURLIN
 LDA INSP+1
 STA CURLIN+1
 LDA #0
 STA CURCOL
 JSR EDMOVE
DRT1 RTS

* ---- DINS: a blank line above, and stay on it ---
DINS JSR EDFLSH
 LDA CURLIN
 STA INSP
 LDA CURLIN+1
 STA INSP+1
 JSR INSLIN
 BCS DIN1
 LDA #0
 STA CURCOL
 JSR EDMOVE
DIN1 RTS

* ---- DDEL: remove this line ---------------------
* A program is never empty: deleting the last line
* leaves one blank one.
DDEL LDA NLINES+1
 BNE DDL1
 LDA NLINES
 CMP #2
 BCS DDL1
 RTS
DDL1 LDA #0
 STA LDIRTY
 LDA CURLIN
 STA INSP
 LDA CURLIN+1
 STA INSP+1
 JSR DELLIN
 LDA CURLIN
 STA C1
 LDA CURLIN+1
 STA C1+1
 LDA NLINES
 STA C2
 LDA NLINES+1
 STA C2+1
 JSR CMP16
 BCC DDL2
 SEC
 LDA NLINES
 SBC #1
 STA CURLIN
 LDA NLINES+1
 SBC #0
 STA CURLIN+1
DDL2 LDA #0
 STA CURCOL
 JMP EDMOVE

* ---- DNEW: start again --------------------------
DNEW LDA #<MNEW
 STA STRPTR
 LDA #>MNEW
 STA STRPTR+1
 JSR ASK
 CMP #$59
 BEQ DNW1
 RTS
DNW1 LDA #0
 STA LDIRTY
 STA CURLIN
 STA CURLIN+1
 STA TOPLIN
 STA TOPLIN+1
 STA CURCOL
 STA CVALID
 STA CLINE
 STA CLINE+1
 LDA #1
 STA NLINES
 LDA #0
 STA NLINES+1
 JSR SHFBLK
 JSR SHFPUT
* A new program has no file, so the corner reverts
* to UNTITLED - keeping the last name there would
* invite a save over the wrong file.  EDFULL
* repaints row 0, so the name change shows at once.
 JSR ERSTNM
 JMP EDFULL

* ---- ERSTNM: EDNAME <- 'UNTITLED' ---------------
* Copies the length byte and eight characters; the
* padding after them is left alone.
ERSTNM LDX #8
ERN1 LDA UNTLBL,X
 STA EDNAME,X
 DEX
 BPL ERN1
 RTS
UNTLBL DFB 8
 ASC 'UNTITLED'

* ---- GETPFX: the volume we are working on -------
* Shown in the corner because a system with one
* prefix and no visible sign of it is a system that
* saves your program somewhere you did not mean.
GETPFX JSR MLI
 DFB $C7
 DA PFPARM
 BCC GPF1
 LDA #0
 STA PFXBUF
GPF1 RTS
PFPARM DFB 1
 DA PFXBUF

