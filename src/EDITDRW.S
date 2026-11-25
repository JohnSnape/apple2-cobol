* EDITDRW.S  EDIT window drawing
* PUT from EDIT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* EDIT resolve against each other in pass two.
*
* ================= DRAWING =================
* ---- DRAWWIN: rows 2-21 from the ring -----------
DRAWWIN LDA #0
 STA DROW
DW1 LDA DROW
 CMP #NPROG
 BCS DWDN
 CLC
 LDA TOPLIN
 ADC DROW
 STA CLINE
 STA C1
 LDA TOPLIN+1
 ADC #0
 STA CLINE+1
 STA C1+1
 LDA NLINES
 STA C2
 LDA NLINES+1
 STA C2+1
 JSR CMP16
 BCS DWBLK
 JSR DRAWLN
 JMP DWNX
DWBLK CLC
 LDA DROW
 ADC #TOPROW
 TAX
 JSR CLRROW
DWNX INC DROW
 JMP DW1
DWDN RTS

* ---- DRAWCUR: just the line being typed on ------
DRAWCUR SEC
 LDA CURLIN
 SBC TOPLIN
 STA DROW
 LDA CURLIN
 STA CLINE
 LDA CURLIN+1
 STA CLINE+1
* fall into DRAWLN

* ---- DRAWLN: CLINE at window row DROW -----------
* The line is copied into ROWBUF split the way the
* screen is - even columns into the first forty
* bytes, odd into the last forty - so PUTROW can
* blit it as two straight copies.  The split costs
* nothing here: we are walking every byte to set
* the high bit anyway.
* A selected line (EDITCLP) is drawn in inverse, by
* a loop of its own so the ordinary one is no
* slower.
DRAWLN JSR DLSEL
 STA DLINV
 JSR CADDRD
 LDA DLINV
 BNE DLSL
 LDY #0
 LDX #0
DL1 LDA (EDPTR2),Y
 AND #$7F
 ORA #$80
 STA ROWBUF,X
 INY
 LDA (EDPTR2),Y
 AND #$7F
 ORA #$80
 STA ROWBUF+40,X
 INY
 INX
 CPX #40
 BCC DL1
 CLC
 LDA DROW
 ADC #TOPROW
 TAX
 JMP PUTROW
* inverse: high bit clear, and $40-$5F down to
* $00-$1F, as TDCONV does it
DLSL LDY #0
 LDX #0
DLS1 LDA (EDPTR2),Y
 JSR DLIC
 STA ROWBUF,X
 INY
 LDA (EDPTR2),Y
 JSR DLIC
 STA ROWBUF+40,X
 INY
 INX
 CPX #40
 BCC DLS1
 CLC
 LDA DROW
 ADC #TOPROW
 TAX
 JMP PUTROW
DLIC AND #$7F
 CMP #$40
 BCC DLICX
 CMP #$60
 BCS DLICX
 AND #$3F
DLICX RTS
DLINV DFB 0

* ---- HDRAW: row 0, prefix and name --------------
HDRAW LDX #0
 JSR CLRROW
 STZ SCRROW
 STZ SCRCOL
 STZ SCRATR
 LDA #<PFXBUF
 STA STRPTR
 LDA #>PFXBUF
 STA STRPTR+1
 JSR PUTS
 LDA #<EDNAME
 STA STRPTR
 LDA #>EDNAME
 STA STRPTR+1
 JSR PUTS
* fall into DFREE

* ---- DFREE: the space remaining, right-justified
* Free records times the record size, which is why
* the count is 24 bits wide: 65,535 lines of 80
* bytes is 5,242,720, and sixteen bits would have
* run out in the first bank.
DFREE LDA NLINES
 STA AXUSED
 LDA NLINES+1
 STA AXUSED+1
 JSR AMFREE
 LDA AXFREE
 STA NFVAL
 LDA AXFREE+1
 STA NFVAL+1
 LDA AXFREE+2
 STA NFVAL+2
 JSR NFCOMMA
 LDA #0
 STA HIX
 LDX #0
DFR1 INX
 LDA NFBUF,X
 LDY HIX
 STA HDRBUF+1,Y
 INC HIX
 CPX NFBUF
 BCC DFR1
 LDX #0
DFR2 LDA FRTAIL,X
 LDY HIX
 STA HDRBUF+1,Y
 INC HIX
 INX
 CPX #16
 BCC DFR2
 LDA HIX
 STA HDRBUF
 LDA #<HDRBUF
 STA STRPTR
 LDA #>HDRBUF
 STA STRPTR+1
 LDA #0
 STA SCRROW
 STA SCRATR
 JMP NFPUTR

