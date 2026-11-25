* RPTDRW.S  REPORT window, rule and header
* PUT from REPORT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* REPORT resolve against each other in pass two.
*
* ================= THE WINDOW =================
* ---- RPWIN: rows 2-21 from PTOP ----------------
* A page line past the end of the page draws as a
* cleared row rather than a blank built row: it is
* not part of the page and should not look like a
* line of it you could type on.
RPWIN LDA #0
 STA WROW
RPW1 LDA WROW
 CMP #NPAGE
 BCS RPWDN
 CLC
 LDA PTOP
 ADC WROW
 STA PLINE
 CMP HPLEN
 BCC RPW2
 CLC
 LDA WROW
 ADC #PGROW
 TAX
 JSR CLRROW
 JMP RPWNX
RPW2 JSR RPLINE
RPWNX INC WROW
 JMP RPW1
RPWDN RTS

* ---- RPLINE: build page line PLINE, then blit --
* Clear the row, then walk every entry looking for
* one on this line.  Sixty-four compares a row and
* twenty rows is about thirteen hundred, under
* the blit's own twelve hundred cycles - which is
* the whole argument for having no cache at all.
RPLINE JSR RPBLANK
 LDA #0
 STA ENTIX
RPL1 LDA ENTIX
 CMP HECNT
 BCS RPL2
 LDA ENTIX
 JSR RPSETP
 LDY #ELINE
 LDA (RPTR),Y
 CMP PLINE
 BNE RPLNX
 JSR RPPAINT
RPLNX INC ENTIX
 JMP RPL1
RPL2 CLC
 LDA WROW
 ADC #PGROW
 TAX
 JMP PUTROW

* ---- RPBLANK: ROWBUF to eighty spaces ----------
* $A0 is a space with the high bit already on, so
* the fill goes straight in without CONV.
RPBLANK LDA #$A0
 LDX #79
RPB1 STA ROWBUF,X
 DEX
 BPL RPB1
 RTS

* ---- RPSETP: A = entry number -> RPTR ----------
* Times sixty-four is six shifts.  The same trick
* AUXMEM uses on a record number and the editor on
* a ring slot, for the same reason: there is no
* multiply on this processor.
* The index arrives in A rather than in a variable
* because four callers walk this table now, and
* one of them is the drawing.
RPSETP STA RPTR
 LDA #0
 STA RPTR+1
 LDX #6
RPS1 ASL RPTR
 ROL RPTR+1
 DEX
 BNE RPS1
 CLC
 LDA RPTR
 ADC #<RPTENT
 STA RPTR
 LDA RPTR+1
 ADC #>RPTENT
 STA RPTR+1
 RTS

* ================= PAINTING AN ENTRY ============
* ---- RPPAINT: draw the entry at (RPTR) ---------
* Literals and rules are furniture, so they render
* NORMAL; a field, a total, the page number and
* date are places data lands, so they render
* INVERSE.  That is the attribute rule from
* DICTIONARY.md, and it means the same thing on
* paper as on a form: inverse says something goes
* here.
RPPAINT LDY #ECOL
 LDA (RPTR),Y
 STA RCOL
 LDY #EKIND
 LDA (RPTR),Y
 STA PKIND
 STZ SCRATR
 LDA PKIND
 BEQ PDISP
 CMP #KRULE
 BEQ PDISP
 LDA #1
 STA SCRATR
PDISP LDA PKIND
 BNE PDA
 JMP PLIT
PDA CMP #KRULE
 BNE PDB
 JMP PRUL
PDB JMP PFLD

* ---- a literal: its own text -------------------
PLIT LDY #ELLEN
 LDA (RPTR),Y
 STA PCNT
 BEQ PPDN
 LDA #ETEXT
 STA PIX
PLI1 LDY PIX
 LDA (RPTR),Y
 JSR RPTPUT
 INC PIX
 DEC PCNT
 BNE PLI1
PPDN RTS

* ---- a rule: one character, width times --------
PRUL LDY #EWIDTH
 LDA (RPTR),Y
 STA PCNT
 BEQ PPDN
 LDY #ETEXT
 LDA (RPTR),Y
 STA PCH
PRU1 LDA PCH
 JSR RPTPUT
 DEC PCNT
 BNE PRU1
 RTS

* ---- a field: its PICTURE, or X to its width ---
* Showing the picture rather than a row of X is
* what makes the layout readable: ZZ,ZZ9.99- has a
* shape, and the shape is the point of putting it
* at that column.
PFLD LDY #EWIDTH
 LDA (RPTR),Y
 STA PCNT
 BEQ PPDN
 LDY #EPICT
 LDA (RPTR),Y
 CMP #$21
 BCC PFX
 LDA #EPICT
 STA PIX
PF1 LDY PIX
 LDA (RPTR),Y
 CMP #$21
 BCS PF2
 LDA #$58
PF2 JSR RPTPUT
 INC PIX
 DEC PCNT
 BNE PF1
 RTS
PFX LDA #$58
 JSR RPTPUT
 DEC PCNT
 BNE PFX
 RTS

* ================= ROW BUILDING =================
* ---- RPTPUT: A = ASCII, at column RCOL ---------
* ROWBUF is split, so the column's parity picks
* the half - exactly as it picks the memory bank
* on the screen itself.  CONV does the fold,
* including the one that keeps an inverse capital
* from coming out as MouseText.
* Past column 79 the character is dropped rather
* than wrapped: an entry that runs off the page is
* the designer's problem to see, not ROWBUF's to
* absorb into the next row.
RPTPUT PHA
 LDA RCOL
 CMP #80
 BCC RPP0
 PLA
 RTS
RPP0 LSR
 STA RIX
 LDA RCOL
 AND #1
 BEQ RPP1
 LDA RIX
 CLC
 ADC #40
 STA RIX
RPP1 PLA
 AND #$7F
 JSR CONV
 LDX RIX
 STA ROWBUF,X
 INC RCOL
 RTS

* ---- RPPUTS: A/X -> a length-prefixed string ---
RPPUTS STA ZPT1
 STX ZPT1+1
 LDY #0
 LDA (ZPT1),Y
 STA RLEN
 BEQ RPSD
 LDA #1
 STA RSAV
RPS2 LDY RSAV
 LDA (ZPT1),Y
 JSR RPTPUT
 INC RSAV
 LDA RLEN
 CMP RSAV
 BCS RPS2
RPSD RTS

* ---- RPNUM: A = 0-255, decimal, no zeros ------
* Clobbers X, which is why every row builder here
* keeps its index in memory.
RPNUM LDX #0
 STX PD1
 STX PD2
 STX PANY
RPN1 CMP #100
 BCC RPN2
 SBC #100
 INC PD1
 JMP RPN1
RPN2 CMP #10
 BCC RPN3
 SBC #10
 INC PD2
 JMP RPN2
RPN3 STA PD3
 LDA PD1
 BEQ RPN4
 CLC
 ADC #$30
 JSR RPTPUT
 LDA #1
 STA PANY
RPN4 LDA PD2
 BNE RPN5
 LDA PANY
 BEQ RPN6
RPN5 LDA PD2
 CLC
 ADC #$30
 JSR RPTPUT
RPN6 LDA PD3
 CLC
 ADC #$30
 JMP RPTPUT

* ================= THE RULE =================
* ---- RPRULE: row 1 - where you are on the page -
* $AD is '-' with the high bit already set, so the
* fill goes straight into ROWBUF without RPTPUT.
* Line numbers here are 1-based, as they are on
* paper and in EDIT: PTOP counts from zero because
* it is an index, and one is added where it shows.
RPRULE LDA #$AD
 LDX #79
RPR1 STA ROWBUF,X
 DEX
 BPL RPR1
 STZ SCRATR
 LDA #2
 STA RCOL
 LDA #<MPAGE
 LDX #>MPAGE
 JSR RPPUTS
 LDA PTOP
 CLC
 ADC #1
 JSR RPNUM
 LDA #<MOF
 LDX #>MOF
 JSR RPPUTS
 LDA HPLEN
 JSR RPNUM
 LDA #<MBAND
 LDX #>MBAND
 JSR RPPUTS
 LDA PTOP
 JSR BANDOF
 JSR RPBNAM
 LDA #$20
 JSR RPTPUT
 LDX #1
 JMP PUTROW

* ---- BANDOF: page line in A -> band code -------
* 0 none, 1 heading, 2 detail, 3 footing.  The six
* marks are contiguous in the header, so this
* them as three pairs instead of testing six named
* bytes.  An unset mark is $FF and no page line
* reaches $FF, so an absent band never matches and
* needs no test of its own.
BANDOF STA BTMP
 LDA #0
 STA BIX
BO1 LDA BIX
 CMP #3
 BCS BONO
 LDA BIX
 ASL
 TAX
 LDA BTMP
 CMP HHTOP,X
 BCC BONX
 INX
 LDA HHTOP,X
 CMP BTMP
 BCC BONX
 LDA BIX
 CLC
 ADC #1
 RTS
BONX INC BIX
 JMP BO1
BONO LDA #0
 RTS

* ---- RPBNAM: band code in A -> its name --------
RPBNAM ASL
 TAX
 LDA BNTAB+1,X
 STA BNHI
 LDA BNTAB,X
 LDX BNHI
 JMP RPPUTS

* ================= ROW 0 AND THE BARS ===========
* ---- RPHDR: the report name and the dictionary -
* A report with no dictionary bound can still be
* laid out: only FIELD and TOTAL entries need one,
* so this says NO DICTIONARY rather than refusing.
RPHDR LDX #0
 JSR CLRROW
 STZ SCRROW
 STZ SCRCOL
 STZ SCRATR
 LDA #<RPNAME
 STA STRPTR
 LDA #>RPNAME
 STA STRPTR+1
 JSR PUTS
 LDA HDNAME
 CMP #$21
 BCS RPH1
 LDA #<MNODCT
 LDX #>MNODCT
 JMP RPH2
RPH1 JSR RPMKD
 LDA #<DNBUF
 LDX #>DNBUF
RPH2 STA STRPTR
 STX STRPTR+1
 LDA #0
 STA SCRROW
 STA SCRATR
 JMP NFPUTR

* ---- RPMKD: HDNAME -> DNBUF, length-prefixed ---
* The header keeps the name padded to twelve,
* which is what the file wants; the screen wants
* trimmed, which is what this does.
RPMKD LDX #11
RMK1 LDA HDNAME,X
 CMP #$21
 BCS RMK2
 DEX
 BPL RMK1
RMK2 INX
 STX DNBUF
 BEQ RMKD
 LDX #0
RMK3 LDA HDNAME,X
 STA DNBUF+1,X
 INX
 CPX DNBUF
 BCC RMK3
RMKD RTS

* ---- RPBARS: row 22 ----------------------------
* Row, string, column - and $FF at the end, the
* same table shape EDIT's and FORMAT's bars use.
* Only row 22 today: row 23 belongs to LINEIN, and
* a command bar that a prompt keeps erasing is
* worse than no command bar.
RPBARS LDX #0
RPBR1 LDA BARTAB,X
 CMP #$FF
 BEQ RPBRD
 STA SCRROW
 LDA BARTAB+1,X
 STA STRPTR
 LDA BARTAB+2,X
 STA STRPTR+1
 LDA BARTAB+3,X
 STA SCRCOL
 LDA #0
 STA SCRATR
 STX BSAV
 JSR PUTSX
 LDX BSAV
 TXA
 CLC
 ADC #4
 TAX
 JMP RPBR1
RPBRD RTS
