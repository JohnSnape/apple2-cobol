* RPTIO.S  REPORT: dictionary, bands, new/open/save
* PUT from REPORT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* REPORT resolve against each other in pass two.
*
* Slices 3, 4 and 5 of REPORT.md section 9, written
* 2026-11-08.
*   OA-I  bind a dictionary (.DCT) - FIELD and TOTAL
*         entries are picked from it by name
*   OA-B  set a band: heading, detail or footing,
*         first and last page line
*   OA-N  a new, empty report
*   OA-O  open a .RPT, and its dictionary with it
*   OA-S  save as a .RPT
* The .RPT is the memory image of RPTHDR and RPTENT
* (REPORT.md 5), so save is one FSAVE and open one
* FLOAD - nothing is built or parsed.

* ================= THE DICTIONARY ==============
* ---- RPDICT: OA-I --------------------------------
RPDICT LDA #<MDCTQ
 STA STRPTR
 LDA #>MDCTQ
 STA STRPTR+1
 JSR LINEIN
 JSR CLRLINE
 LDA LIRES
 BNE RPDX
 LDA LLEN
 BEQ RPDX
* the typed name becomes HDNAME, twelve characters
* space padded, and is loaded from there
 LDX #0
RPD1 LDA #$20
 CPX LLEN
 BCS RPD2
 LDA LBUF,X
 JSR RPUPC
RPD2 STA HDNAME,X
 INX
 CPX #12
 BCC RPD1
 JSR RPLDCT
 BCC RPD3
 LDA #<MNODF
 LDX #>MNODF
 JSR RPERR
RPD3 JMP RPHDR
RPDX RTS

* ---- RPLDCT: HDNAME.DCT -> DCTBUF ---------------
* out: C=1 if it would not load; RDCTOK says which
RPLDCT STZ RDCTOK
 JSR RPHNM
 LDA #$49
 JSR RPSFX
 LDA #<DCTBUF
 STA FADDR
 LDA #>DCTBUF
 STA FADDR+1
 STZ FLEN
 LDA #3
 STA FLEN+1
 JSR FLOAD
 BCS RPLDX
 INC RDCTOK
 CLC
RPLDX RTS

* ---- RPHNM: HDNAME (trimmed) -> RFNAME ----------
RPHNM LDX #0
RPH3 CPX #12
 BCS RPH4
 LDA HDNAME,X
 CMP #$21
 BCC RPH4
 STA RFNAME+1,X
 INX
 BNE RPH3
RPH4 STX RFNAME
 RTS

* ---- RPSFX: RFNAME with suffix type A -> FNBUF1 --
* and FNAMP pointing at it, ready for FLOAD/FSAVE
RPSFX PHA
 LDA #<RFNAME
 STA FNAMP
 LDA #>RFNAME
 STA FNAMP+1
 PLA
 LDX #1
 JSR SETSFX
 LDA #<FNBUF1
 STA FNAMP
 LDA #>FNBUF1
 STA FNAMP+1
 RTS

* ---- RPUPC: A to upper case ---------------------
RPUPC CMP #$61
 BCC RPUX
 CMP #$7B
 BCS RPUX
 SEC
 SBC #$20
RPUX RTS

* ---- RPERR: A/X -> a message, then a key --------
RPERR STA STRPTR
 STX STRPTR+1
 JMP SHOWERR

* ---- RFFIND: LBUF/LLEN as a field of the dictionary
* out: C=0 and ZPT2 -> its 24-byte descriptor; C=1
* if there is no such field.  The name is compared
* in capitals, and must END where the typed name
* ends: CUST does not find CUST-NAME.
RFFIND LDA RDCTOK
 BEQ RFFNO
 STZ RFI
RFF1 LDA RFI
 CMP DCTBUF+8
 BCS RFFNO
 JSR RFDESC
 LDY #0
RFF2 CPY LLEN
 BCS RFF3
 LDA LBUF,Y
 JSR RPUPC
 CMP (ZPT2),Y
 BNE RFFNX
 INY
 CPY #10
 BCC RFF2
RFF3 CPY #10
 BCS RFFYES
 LDA (ZPT2),Y
 CMP #$21
 BCC RFFYES
RFFNX INC RFI
 JMP RFF1
RFFYES CLC
 RTS
RFFNO SEC
 RTS

* ---- RFDESC: field RFI's descriptor -> ZPT2 -----
* RFI * 24 + the table offset at DCTBUF+12 - the
* same arithmetic as VIEW's VWDESC
RFDESC LDA RFI
 ASL
 CLC
 ADC RFI
 STA RFT
 STZ RFT+1
 ASL RFT
 ROL RFT+1
 ASL RFT
 ROL RFT+1
 ASL RFT
 ROL RFT+1
 CLC
 LDA RFT
 ADC DCTBUF+12
 STA RFT
 LDA RFT+1
 ADC DCTBUF+13
 STA RFT+1
 CLC
 LDA RFT
 ADC #<DCTBUF
 STA ZPT2
 LDA RFT+1
 ADC #>DCTBUF
 STA ZPT2+1
 RTS

* ================= BANDS =======================
* ---- RPBAND: OA-B --------------------------------
* Which band, then its first and last page line.
* An empty first line clears that band.
RPBAND JSR PROMPT23
 LDA #<MBNDQ
 STA STRPTR
 LDA #>MBNDQ
 STA STRPTR+1
 JSR PUTS
RPBD1 JSR GETCHORD
 LDA CHKEY
 CMP #$1B
 BNE RPBK
 JMP CLRLINE
RPBK AND #$DF
 LDX #0
 CMP #$48
 BEQ RPBD2
 LDX #2
 CMP #$44
 BEQ RPBD2
 LDX #4
 CMP #$46
 BEQ RPBD2
 JMP RPBD1
RPBD2 STX RBIX
 LDA #<MFRSTQ
 STA STRPTR
 LDA #>MFRSTQ
 STA STRPTR+1
 JSR LINEIN
 LDA LIRES
 BNE RPBX
 LDA LLEN
 BNE RPBD3
* nothing typed: the band is cleared
 LDX RBIX
 LDA #$FF
 STA HHTOP,X
 STA HHBOT,X
 JMP RPBDN
RPBD3 JSR ATOI
 BEQ RPBBAD
 CMP HPLEN
 BEQ RPBD4
 BCS RPBBAD
RPBD4 STA RBTOP
 LDA #<MLASTQ
 STA STRPTR
 LDA #>MLASTQ
 STA STRPTR+1
 JSR LINEIN
 LDA LIRES
 BNE RPBX
 LDA LLEN
 BEQ RPBX
 JSR ATOI
 CMP RBTOP
 BCC RPBBAD
 CMP HPLEN
 BEQ RPBD5
 BCS RPBBAD
RPBD5 LDX RBIX
 SEC
 SBC #1
 STA HHBOT,X
 LDA RBTOP
 SEC
 SBC #1
 STA HHTOP,X
RPBDN JSR CLRLINE
 JMP RPDRAW
RPBBAD LDA #<MBAD
 LDX #>MBAD
 JSR RPERR
RPBX JMP CLRLINE

* ================= NEW, OPEN, SAVE =============
* ---- RPNEW: OA-N --------------------------------
RPNEW JSR PROMPT23
 LDA #<MNEWQ
 STA STRPTR
 LDA #>MNEWQ
 STA STRPTR+1
 JSR PUTS
 JSR GETCHORD
 LDA CHKEY
 AND #$DF
 CMP #$59
 BNE RPNX
 JSR RPINIT
 STZ RDCTOK
 JSR RPUNT
 JMP RPFULL
RPNX JMP CLRLINE

* RPUNT: the name back to UNTITLED
RPUNT LDX #8
RPU1 LDA MUNT,X
 STA RPNAME,X
 DEX
 BPL RPU1
 RTS

* ---- RPOPEN: OA-O --------------------------------
RPOPEN LDA #<MOPENQ
 STA STRPTR
 LDA #>MOPENQ
 STA STRPTR+1
 JSR RPASKN
 BCS RPOX
 LDA #$4C
 JSR RPSFX
 LDA #<RPTHDR
 STA FADDR
 LDA #>RPTHDR
 STA FADDR+1
 LDA #<MAXENT*ENTSZ+32
 STA FLEN
 LDA #>MAXENT*ENTSZ+32
 STA FLEN+1
 JSR FLOAD
 BCS RPOERR
* is it one of ours?
 LDX #3
RPO1 LDA HSIG,X
 CMP MSIG,X
 BNE RPOBAD
 DEX
 BPL RPO1
 JSR RPSETN
* its dictionary, if it names one
 STZ RDCTOK
 LDA HDNAME
 CMP #$21
 BCC RPO2
 JSR RPLDCT
 BCC RPO2
 JSR RPFULL
 LDA #<MNODF
 LDX #>MNODF
 JMP RPERR
RPO2 STZ PTOP
 JMP RPFULL
RPOBAD JSR RPINIT
 JSR RPFULL
 LDA #<MNOTR
 LDX #>MNOTR
 JMP RPERR
RPOERR JSR RPINIT
 JSR RPFULL
 LDA #<MNOTF
 LDX #>MNOTF
 JMP RPERRN
RPOX JMP CLRLINE

* ---- RPSAVE: OA-S --------------------------------
RPSAVE LDA #<MSAVEQ
 STA STRPTR
 LDA #>MSAVEQ
 STA STRPTR+1
 JSR RPASKN
 BCS RPOX
 LDA #$4C
 JSR RPSFX
* the length: 32 + entries * 64, into the header
 LDA HECNT
 STA HFEND
 STZ HFEND+1
 LDX #6
RPS3 ASL HFEND
 ROL HFEND+1
 DEX
 BNE RPS3
 CLC
 LDA HFEND
 ADC #32
 STA HFEND
 STA FLEN
 LDA HFEND+1
 ADC #0
 STA HFEND+1
 STA FLEN+1
 LDA #<RPTHDR
 STA FADDR
 LDA #>RPTHDR
 STA FADDR+1
 JSR FSAVE
 BCS RPSERR
 JSR RPSETN
 JSR RPHDR
 LDA #<MSAVED
 LDX #>MSAVED
 JMP RPERR
RPSERR LDA #<MSAVF
 LDX #>MSAVF
* ---- RPERRN: RPERR, unless the NAME was why ------
* NAMBAD: the name just expanded broke ProDOS's
* rules (PREFIX.S, DECISIONS 8.10).  Then "Save
* failed" or "File not found" would be a wrong
* answer, and "Bad file name" is the right one.
RPERRN LDY NAMBAD
 BEQ RPEN1
 LDA #<MBADN
 LDX #>MBADN
RPEN1 JMP RPERR

* ---- RPASKN: ask for a name -> RFNAME -----------
* out: C=1 if nothing was typed or ESC
RPASKN JSR LINEIN
 JSR CLRLINE
 LDA LIRES
 BNE RPANO
 LDA LLEN
 BEQ RPANO
 CMP #16
 BCC RPAN1
 LDA #15
RPAN1 STA RFNAME
 TAX
RPAN2 LDA LBUF-1,X
 JSR RPUPC
 STA RFNAME,X
 DEX
 BNE RPAN2
 CLC
 RTS
RPANO SEC
 RTS

* ---- RPSETN: RFNAME -> RPNAME, for row 0 --------
* without the suffix, if one was typed
RPSETN LDX #0
RPSN1 CPX RFNAME
 BCS RPSN2
 LDA RFNAME+1,X
 CMP #$2E
 BEQ RPSN2
 STA RPNAME+1,X
 INX
 BNE RPSN1
RPSN2 STX RPNAME
 RTS

* ================= STRINGS =====================
MDCTQ DFB 12
 ASC 'Dictionary? '
MNODF DFB 30
 ASC 'Dictionary will not load (key)'
MBNDQ DFB 32
 ASC 'Band H)eading D)etail F)ooting? '
MFRSTQ DFB 33
 ASC 'First line (RETURN = no band)?   '
MLASTQ DFB 11
 ASC 'Last line? '
MNEWQ DFB 25
 ASC 'Clear the report?  Y/N   '
MOPENQ DFB 6
 ASC 'Open? '
MSAVEQ DFB 9
 ASC 'Save as? '
MSAVED DFB 11
 ASC 'Saved (key)'
MSAVF DFB 17
 ASC 'Save failed (key)'
MNOTF DFB 20
 ASC 'File not found (key)'
MBADN DFB 19
 ASC 'Bad file name (key)'
MNOTR DFB 21
 ASC 'Not a report (key)   '
MSIG ASC 'ADR1'
MUNT DFB 8
 ASC 'UNTITLED'

* ================= VARIABLES ===================
RDCTOK DFB 0
RFI DFB 0
RFT DS 2
RBIX DFB 0
RBTOP DFB 0
RFNAME DS 18
