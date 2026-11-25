* EDITSHF.S  EDIT record insert/delete
* PUT from EDIT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* EDIT resolve against each other in pass two.
*
* ================= AUX SHUFFLING =================
* SHFBUF is the staging buffer an insert or a delete
* moves records through.  It is not the ring: those
* moves walk the whole file and would otherwise
* sweep the ring away line by line.
SHFGET LDA #<SHFBUF
 STA AXBUF
 LDA #>SHFBUF
 STA AXBUF+1
 JSR CSETRC
 JMP AXGET
SHFPUT LDA #<SHFBUF
 STA AXBUF
 LDA #>SHFBUF
 STA AXBUF+1
 JSR CSETRC
 JMP AXPUT
SHFBLK LDA #$20
 LDY #RECSZ-1
SHB1 STA SHFBUF,Y
 DEY
 BPL SHB1
 RTS

* ---- INSLIN: a blank line at INSP ---------------
* Records INSP..NLINES-1 each move up one, from the
* end backwards so nothing is overwritten before it
* has been read.  C=1 if there is no room.
INSLIN LDA NLINES
 STA C1
 LDA NLINES+1
 STA C1+1
 LDA AXCAPV
 STA C2
 LDA AXCAPV+1
 STA C2+1
 JSR CMP16
 BCC INS1
 SEC
 RTS
INS1 SEC
 LDA NLINES
 SBC #1
 STA SRCL
 LDA NLINES+1
 SBC #0
 STA SRCL+1
INS2 LDA SRCL
 STA C1
 LDA SRCL+1
 STA C1+1
 LDA INSP
 STA C2
 LDA INSP+1
 STA C2+1
 JSR CMP16
 BCC INS3
 LDA SRCL
 STA CLINE
 LDA SRCL+1
 STA CLINE+1
 JSR SHFGET
 CLC
 LDA SRCL
 ADC #1
 STA CLINE
 LDA SRCL+1
 ADC #0
 STA CLINE+1
 JSR SHFPUT
 SEC
 LDA SRCL
 SBC #1
 STA SRCL
 LDA SRCL+1
 SBC #0
 STA SRCL+1
 BCS INS2
INS3 JSR SHFBLK
 LDA INSP
 STA CLINE
 LDA INSP+1
 STA CLINE+1
 JSR SHFPUT
 INC NLINES
 BNE INS4
 INC NLINES+1
INS4 JSR EDSTAL
 CLC
 RTS

* ---- DELLIN: remove the line at INSP ------------
DELLIN CLC
 LDA INSP
 ADC #1
 STA SRCL
 LDA INSP+1
 ADC #0
 STA SRCL+1
DEL1 LDA SRCL
 STA C1
 LDA SRCL+1
 STA C1+1
 LDA NLINES
 STA C2
 LDA NLINES+1
 STA C2+1
 JSR CMP16
 BCS DEL2
 LDA SRCL
 STA CLINE
 LDA SRCL+1
 STA CLINE+1
 JSR SHFGET
 SEC
 LDA SRCL
 SBC #1
 STA CLINE
 LDA SRCL+1
 SBC #0
 STA CLINE+1
 JSR SHFPUT
 CLC
 LDA SRCL
 ADC #1
 STA SRCL
 LDA SRCL+1
 ADC #0
 STA SRCL+1
 JMP DEL1
DEL2 SEC
 LDA NLINES
 SBC #1
 STA NLINES
 LDA NLINES+1
 SBC #0
 STA NLINES+1
 JMP EDSTAL

* ---- EDSTAL: the ring and the count are stale ---
EDSTAL LDA #0
 STA CVALID
 LDA RFLAG
 ORA #6
 STA RFLAG
 RTS

