* EDITRUL.S  EDIT rule, bars, repaint
* PUT from EDIT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* EDIT resolve against each other in pass two.
*
* ================= THE RULE =================
* ---- DRULE: row 1 - where you are ---------------
* With no gutter this is the only place a line
* number appears, so it is redrawn every time round
* the loop rather than being flagged: one row is
* 1200 cycles and correctness is worth more.
* Since 2026-11-08 the numbers sit at the right in
* fixed places, so nothing shifts as they grow:
*   ----...---- L 99999/99999 C 99--
* columns 59-77, the fields right-justified.
DRULE LDA #$AD
 LDX #79
DRU1 STA ROWBUF,X
 DEX
 BPL DRU1
 LDA #59
 STA RCOL
 LDA #$20
 JSR RPUT
 LDA #$4C
 JSR RPUT
 LDA #$20
 JSR RPUT
 CLC
 LDA CURLIN
 ADC #1
 STA SVAL
 LDA CURLIN+1
 ADC #0
 STA SVAL+1
 LDA #5
 JSR RNUMP
 LDA #$2F
 JSR RPUT
 LDA NLINES
 STA SVAL
 LDA NLINES+1
 STA SVAL+1
 LDA #5
 JSR RNUMP
 LDA #$20
 JSR RPUT
 LDA #$43
 JSR RPUT
 LDA #$20
 JSR RPUT
 LDA CURCOL
 CLC
 ADC #1
 STA SVAL
 STZ SVAL+1
 LDA #2
 JSR RNUMP
 LDX #1
 JMP PUTROW

* ---- RNUMP: SVAL in A columns, right-justified ---
* the last A of five digits, leading zeros as
* spaces (never the last digit)
RNUMP STA RWID
 LDX #4
RNP1 JSR DIV10
 CLC
 ADC #$30
 STA NBUF,X
 DEX
 BPL RNP1
 LDX #0
RNP2 CPX #4
 BCS RNP3
 LDA NBUF,X
 CMP #$30
 BNE RNP3
 LDA #$20
 STA NBUF,X
 INX
 BNE RNP2
RNP3 SEC
 LDA #5
 SBC RWID
 TAX
RNP4 LDA NBUF,X
 STX RSAV
 JSR RPUT
 LDX RSAV
 INX
 CPX #5
 BCC RNP4
 RTS

* ---- RPUT: A = character, at column RCOL --------
* ROWBUF is split, so the column's parity picks the
* half - exactly as it picks the memory bank on the
* screen itself.
RPUT PHA
 LDA RCOL
 LSR
 STA RIX
 LDA RCOL
 AND #1
 BEQ RP1
 LDA RIX
 CLC
 ADC #40
 STA RIX
RP1 PLA
 ORA #$80
 LDX RIX
 STA ROWBUF,X
 INC RCOL
 RTS

* ---- RPUTS: A/X -> a length-prefixed string -----
RPUTS STA ZPT1
 STX ZPT1+1
 LDY #0
 LDA (ZPT1),Y
 STA RLEN
 BEQ RPSD
 LDA #1
 STA RSAV
RPS1 LDY RSAV
 LDA (ZPT1),Y
 JSR RPUT
 INC RSAV
 LDA RLEN
 CMP RSAV
 BCS RPS1
RPSD RTS

* ---- RNUM: SVAL in decimal, no leading zeros ----
RNUM LDX #4
RN1 JSR DIV10
 CLC
 ADC #$30
 STA NBUF,X
 DEX
 BPL RN1
 LDX #0
RN2 CPX #4
 BCS RN3
 LDA NBUF,X
 CMP #$30
 BNE RN3
 INX
 JMP RN2
RN3 LDA NBUF,X
 STX RSAV
 JSR RPUT
 LDX RSAV
 INX
 CPX #5
 BCC RN3
 RTS

* ---- DIV10: SVAL /= 10, remainder -> A ----------
* X is preserved: the caller is using it as the
* digit index, and the shift loop needs a counter
* of its own.
DIV10 TXA
 PHA
 LDX #16
 LDA #0
 STA DREM
DV1 ASL SVAL
 ROL SVAL+1
 ROL DREM
 LDA DREM
 CMP #10
 BCC DV2
 SBC #10
 STA DREM
 INC SVAL
DV2 DEX
 BNE DV1
 PLA
 TAX
 LDA DREM
 RTS

* ---- PRMPT: the bottom two rows become the prompt
* The user's rule, 2026-11-08: a command clears the
* command bars and asks there; EDRAW puts the bars
* back when the command is over (BARDRT).  Prompts
* were on the rule, row 1.
PRMPT LDX #22
 JSR CLRROW
 LDX #23
 JSR CLRROW
 LDA #22
 STA SCRROW
 LDA #1
 STA SCRCOL
 STZ SCRATR
 LDA #1
 STA BARDRT
 RTS

* ---- ASK: STRPTR -> question.  A = the key ------
ASK JSR PRMPT
 JSR PUTS
 JSR WAITKEY
 AND #$7F
 AND #$DF
 PHA
 JSR DRULE
 PLA
 RTS

* ---- DRAWBAR: rows 22 and 23 --------------------
* the two rows are cleared first: a prompt left its
* text in the gaps between the commands
DRAWBAR LDX #22
 JSR CLRROW
 LDX #23
 JSR CLRROW
 LDX #0
 LDA VIEWMO
 BEQ DBR1
 LDX #VBARTB-BARTAB
DBR1 LDA BARTAB,X
 CMP #$FF
 BEQ DBRD
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
 JMP DBR1
DBRD LDA VIEWMO
 BNE DMX
* ---- DMODE: Ins or Ovr in inverse, whichever is on
DMODE LDA #22
 STA SCRROW
 LDA MODE
 BNE DMD1
 LDA #<MINS
 LDX #>MINS
 LDY #53
 JMP DMD2
DMD1 LDA #<MOVR
 LDX #>MOVR
 LDY #57
DMD2 STA STRPTR
 STX STRPTR+1
 STY SCRCOL
 LDA #1
 STA SCRATR
 JSR PUTS
 STZ SCRATR
DMX RTS

* ---- EDRAW: repaint whatever changed ------------
* A cursor move inside the window draws the rule
* only; a keystroke draws one row; a scroll or a
* change in the number of lines draws twenty.
EDRAW LDA RFLAG
 AND #2
 BEQ EDR1
 JSR DRAWWIN
 JMP EDR2
EDR1 LDA RFLAG
 AND #1
 BEQ EDR2
 JSR DRAWCUR
EDR2 LDA RFLAG
 AND #4
 BEQ EDR3
 JSR DFREE
EDR3 LDA #0
 STA RFLAG
 LDA BARDRT
 BEQ EDR4
 STZ BARDRT
 JSR DRAWBAR
EDR4 JMP DRULE

