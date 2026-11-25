* EDITPRT.S  OA-P, print the program
* PUT from EDIT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* EDIT resolve against each other in pass two.
*
* Added 2026-11-08.  The listing goes to the printer
* slot set in Utilities, sixty-six lines a page:
*   NAME    8/15/2026    Page 1
*   (blank)
*   sixty numbered lines
*   four blank lines, to the next page
* The numbers are the line numbers the compiler's
* errors and the rule use.  Trailing spaces are not
* sent, so most lines are short; a line that runs
* past the paper's width is the printer's to wrap.
* ESC between lines stops it.

PGLIN EQU 66
* header lines + body lines: past this, eject
PGBODY EQU 62

* ---- DPRINT: OA-P ------------------------------
DPRINT JSR EDFLSH
 JSR PRMPT
 LDA #<MPRTNG
 STA STRPTR
 LDA #>MPRTNG
 STA STRPTR+1
 JSR PUTS
 JSR PRINIT
 BCC DPR0
 LDA #<MNOPR
 LDX #>MNOPR
 JMP EMSG
DPR0 STZ PPAGE
 STZ PPL
 STZ SLINE
 STZ SLINE+1
* every line, or until ESC
DPR1 LDA SLINE
 STA C1
 LDA SLINE+1
 STA C1+1
 LDA NLINES
 STA C2
 LDA NLINES+1
 STA C2+1
 JSR CMP16
 BCS DPRDN
 LDA $C000
 BPL DPR2
 CMP #$9B
 BNE DPR2
 STA $C010
 JMP DPRDN
DPR2 LDA PPL
 BNE DPR3
 JSR DPHEAD
DPR3 LDA SLINE
 STA CLINE
 LDA SLINE+1
 STA CLINE+1
 JSR SHFGET
 JSR SGTRIM
* the number, five wide, then two spaces
 CLC
 LDA SLINE
 ADC #1
 STA SVAL
 LDA SLINE+1
 ADC #0
 STA SVAL+1
 SEC
 JSR DPNUM
 LDA #$20
 JSR PRPUTC
 LDA #$20
 JSR PRPUTC
 LDY #0
DPR4 CPY SLEN
 BCS DPR5
 LDA SHFBUF,Y
 AND #$7F
 STY PRY
 JSR PRPUTC
 LDY PRY
 INY
 BNE DPR4
DPR5 JSR PRCR
 INC PPL
 LDA PPL
 CMP #PGBODY
 BCC DPR6
 JSR DPEJCT
DPR6 INC SLINE
 BNE DPR7
 INC SLINE+1
DPR7 JMP DPR1
* the last page goes out of the printer too
DPRDN LDA PPL
 BEQ DPRD1
 JSR DPEJCT
DPRD1 LDA #<MPRTD
 LDX #>MPRTD
 JMP EMSG

* ---- DPEJCT: blank lines to the end of the page -
DPEJCT LDA PPL
 CMP #PGLIN
 BCS DPEJ1
 JSR PRCR
 INC PPL
 JMP DPEJCT
DPEJ1 STZ PPL
 RTS

* ---- DPHEAD: the page heading -------------------
DPHEAD INC PPAGE
 LDA #<EDNAME
 STA STRPTR
 LDA #>EDNAME
 STA STRPTR+1
 JSR PRPUTS
 JSR DPSP4
 JSR DTMDATE
 LDA #<DTBUF
 STA STRPTR
 LDA #>DTBUF
 STA STRPTR+1
 JSR PRPUTS
 JSR DPSP4
 LDA #<MPAGE
 STA STRPTR
 LDA #>MPAGE
 STA STRPTR+1
 JSR PRPUTS
 LDA PPAGE
 STA SVAL
 STZ SVAL+1
 CLC
 JSR DPNUM
 JSR PRCR
 JSR PRCR
 LDA #2
 STA PPL
 RTS
DPSP4 LDA #$20
 JSR PRPUTC
 LDA #$20
 JSR PRPUTC
 LDA #$20
 JSR PRPUTC
 LDA #$20
 JMP PRPUTC

* ---- DPNUM: SVAL to the printer ------------------
* C=1: five wide, leading spaces.  C=0: no padding.
DPNUM ROR PRPAD
 LDX #4
DPN1 JSR DIV10
 CLC
 ADC #$30
 STA NBUF,X
 DEX
 BPL DPN1
 LDX #0
DPN2 CPX #4
 BCS DPN4
 LDA NBUF,X
 CMP #$30
 BNE DPN4
 BIT PRPAD
 BPL DPN3
 LDA #$20
 STX PRY
 JSR PRPUTC
 LDX PRY
DPN3 INX
 BNE DPN2
DPN4 LDA NBUF,X
 STX PRY
 JSR PRPUTC
 LDX PRY
 INX
 CPX #5
 BCC DPN4
 RTS

MPRTNG DFB 22
 ASC 'Printing - ESC to stop'
MNOPR DFB 52
 ASC 'No printer - set its slot in Utilities.  Press a key'
MPRTD DFB 21
 ASC 'Printed - press a key'
MPAGE DFB 5
 ASC 'Page '
PPAGE DFB 0
PPL DFB 0
PRY DFB 0
PRPAD DFB 0
