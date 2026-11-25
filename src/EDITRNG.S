* EDITRNG.S  EDIT line-cache ring
* PUT from EDIT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* EDIT resolve against each other in pass two.
*
* ================= THE RING =================
* ---- CADDR: CLINE -> CPTR, its slot -------------
* Address = EDCACHE + (line AND 63) * 80, by shift
* and add - the same long multiplication AMMAP
* does, and for the same reason: there is no
* multiply on this processor.
CADDR LDA CLINE
 AND #CMASK
 STA CT
 STZ CT+1
 STZ CPTR
 STZ CPTR+1
 LDA #RECSZ
 STA CMA
CAD1 LDA CMA
 BEQ CAD3
 LSR CMA
 BCC CAD2
 CLC
 LDA CPTR
 ADC CT
 STA CPTR
 LDA CPTR+1
 ADC CT+1
 STA CPTR+1
CAD2 ASL CT
 ROL CT+1
 JMP CAD1
CAD3 CLC
 LDA CPTR
 ADC #<EDCACHE
 STA CPTR
 LDA CPTR+1
 ADC #>EDCACHE
 STA CPTR+1
 RTS

* ---- SETCUR: EDPTR -> the cursor's line ---------
SETCUR LDA CURLIN
 STA CLINE
 LDA CURLIN+1
 STA CLINE+1
 JSR CADDR
 LDA CPTR
 STA EDPTR
 LDA CPTR+1
 STA EDPTR+1
 RTS

* ---- CADDRD: EDPTR2 -> CLINE's slot -------------
CADDRD JSR CADDR
 LDA CPTR
 STA EDPTR2
 LDA CPTR+1
 STA EDPTR2+1
 RTS

* ---- CFETCH: read CLINE from aux into its slot --
CFETCH JSR CADDRD
 LDA EDPTR2
 STA AXBUF
 LDA EDPTR2+1
 STA AXBUF+1
 JSR CSETRC
 JMP AXGET

* ---- CSETRC: AXREC = CLINE, then map it ---------
CSETRC LDA CLINE
 STA AXREC
 LDA CLINE+1
 STA AXREC+1
 JMP AXMAP

* ---- EDFLSH: write the line back if it changed --
* The only place the editor writes to auxiliary
* memory during ordinary typing, and it happens
* when the cursor LEAVES a line - not per key.
EDFLSH LDA LDIRTY
 BEQ EFL1
 LDA CURLIN
 STA CLINE
 LDA CURLIN+1
 STA CLINE+1
 JSR CADDRD
 LDA EDPTR2
 STA AXBUF
 LDA EDPTR2+1
 STA AXBUF+1
 JSR CSETRC
 JSR AXPUT
 LDA #0
 STA LDIRTY
EFL1 RTS

* ---- EDDIRT: the line has been changed ----------
EDDIRT LDA #1
 STA LDIRTY
 LDA RFLAG
 ORA #1
 STA RFLAG
 RTS

* ---- CMP16: C1 against C2 -----------------------
* C=1 if C1 >= C2, Z=1 if they are equal.
CMP16 LDA C1+1
 CMP C2+1
 BNE CM16D
 LDA C1
 CMP C2
CM16D RTS

* ---- CWANT: the range the window wants cached ---
* Sixteen either side of the window, clipped to the
* program.
CWANT SEC
 LDA TOPLIN
 SBC #CBACK
 STA DLO
 LDA TOPLIN+1
 SBC #0
 STA DLO+1
 BCS CWA1
 LDA #0
 STA DLO
 STA DLO+1
CWA1 CLC
 LDA TOPLIN
 ADC #NPROG-1+CBACK
 STA DHI
 LDA TOPLIN+1
 ADC #0
 STA DHI+1
 SEC
 LDA NLINES
 SBC #1
 STA C2
 LDA NLINES+1
 SBC #0
 STA C2+1
 LDA DHI
 STA C1
 LDA DHI+1
 STA C1+1
 JSR CMP16
 BCC CWA2
 LDA C2
 STA DHI
 LDA C2+1
 STA DHI+1
CWA2 RTS

* ---- CSYNC: make the ring cover the window ------
* One line of movement fetches one record.  A jump
* that lands clear of the ring reloads it.
CSYNC JSR CWANT
 LDA CVALID
 BNE CSY1
 JMP CSRLD
* reload if the window has left the ring entirely
CSY1 LDA TOPLIN
 STA C1
 LDA TOPLIN+1
 STA C1+1
 LDA CHIGH
 STA C2
 LDA CHIGH+1
 STA C2+1
 JSR CMP16
 BEQ CSY2
 BCC CSY2
 JMP CSRLD
CSY2 LDA CLOW
 STA C1
 LDA CLOW+1
 STA C1+1
 CLC
 LDA TOPLIN
 ADC #NPROG-1
 STA C2
 LDA TOPLIN+1
 ADC #0
 STA C2+1
 JSR CMP16
 BEQ CSXD
 BCC CSXD
 JMP CSRLD
* extend downward, one record a line
CSXD LDA CHIGH
 STA C1
 LDA CHIGH+1
 STA C1+1
 LDA DHI
 STA C2
 LDA DHI+1
 STA C2+1
 JSR CMP16
 BCS CSXU
 CLC
 LDA CHIGH
 ADC #1
 STA CHIGH
 STA CLINE
 LDA CHIGH+1
 ADC #0
 STA CHIGH+1
 STA CLINE+1
 JSR CFETCH
 JSR CTRIMU
 JMP CSXD
* extend upward
CSXU LDA DLO
 STA C1
 LDA DLO+1
 STA C1+1
 LDA CLOW
 STA C2
 LDA CLOW+1
 STA C2+1
 JSR CMP16
 BCS CSXZ
 SEC
 LDA CLOW
 SBC #1
 STA CLOW
 STA CLINE
 LDA CLOW+1
 SBC #0
 STA CLOW+1
 STA CLINE+1
 JSR CFETCH
 JSR CTRIMD
 JMP CSXU
CSXZ RTS

* ---- CTRIMU: drop the top if the ring is full ---
CTRIMU JSR CSPANV
 BCC CTU1
 SEC
 LDA CHIGH
 SBC #CSPAN-1
 STA CLOW
 LDA CHIGH+1
 SBC #0
 STA CLOW+1
CTU1 RTS

* ---- CTRIMD: drop the bottom instead ------------
CTRIMD JSR CSPANV
 BCC CTD1
 CLC
 LDA CLOW
 ADC #CSPAN-1
 STA CHIGH
 LDA CLOW+1
 ADC #0
 STA CHIGH+1
CTD1 RTS

* ---- CSPANV: C=1 if the ring holds > CSPAN ------
CSPANV SEC
 LDA CHIGH
 SBC CLOW
 STA C1
 LDA CHIGH+1
 SBC CLOW+1
 BNE CSPY
 LDA C1
 CMP #CSPAN-1
 BCC CSPN
 BEQ CSPN
CSPY SEC
 RTS
CSPN CLC
 RTS

* ---- CSRLD: fill the ring from DLO --------------
CSRLD LDA DLO
 STA CLOW
 STA CLINE
 LDA DLO+1
 STA CLOW+1
 STA CLINE+1
 LDA #0
 STA CNT
CSR1 JSR CFETCH
 LDA CLINE
 STA CHIGH
 LDA CLINE+1
 STA CHIGH+1
 INC CNT
 LDA CNT
 CMP #CSPAN
 BCS CSR2
 CLC
 LDA CLINE
 ADC #1
 STA CLINE
 STA C1
 LDA CLINE+1
 ADC #0
 STA CLINE+1
 STA C1+1
 LDA DHI
 STA C2
 LDA DHI+1
 STA C2+1
 JSR CMP16
 BEQ CSR3
 BCC CSR3
CSR2 LDA #1
 STA CVALID
 RTS
CSR3 JMP CSR1

