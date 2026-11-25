* SCRPRV.S  the generated-code preview
* PUT from FORMAT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* FORMATD resolve against each other in pass two.
*
* SA-C at any FORMAT prompt shows the COBOL the
* screen would export, on TEXT PAGE 2, laid out
* the way EDIT lays out a program:
*
*   row 0      the screen name at the left, the
*              space left in the buffer at the right
*   row 1      a rule carrying LINE and OF
*   rows 2-21  twenty lines of generated code
*   row 22     the Open-Apple commands
*   row 23     the Solid-Apple commands
*
* Line numbers on the rule are 1-based, as they are
* in EDIT: PVTOP counts from zero because it is an
* index, and one is added where it is shown.
*
* WHY PAGE 2
* TDSETPG picks a page for drawing AND display
* together, so we cannot build this behind the form
* and flip to it.  We do not need to.  TDSWAP
* remembers each page's cursor, so page 1 still
* holds the form exactly as it was - down to the
* half-typed answer on row 23 and the column the
* cursor was in - and coming back is one soft
* switch and no repaint at all.
*
* WHY IT REBUILDS EVERY TIME
* BLDCOB over fifteen fields is a few thousand
* stores, less than the repaint that follows it.
* Rebuilding means the preview renders the SAME
* bytes WRDCT would write, so it cannot drift from
* the exported file the way a second formatter
* eventually would.
*
* ON CLOBBERING STRPTR
* PVPUTS uses ZPT1, which IS STRPTR.  That is safe
* from inside LINEIN: LINEIN consumes STRPTR in its
* opening PUTS and never looks at it again, and
* every caller reloads it before the next prompt.

* PVPTR is in zone P for the same reason as SCREXP's
* TPTR: (ptr),Y needs zero page, known in pass 1.
PVPTR EQU ZPDRV+4

PVROW EQU 2
PVNP EQU 20

* ================= ENTRY =================
* ---- DOPREV: SA-C, show the code, come back -----
* a menu has no code to preview (FMTMNU.S)
DOPREV LDA FMENU
 BEQ DOPRV1
 RTS
DOPRV1 JSR BLDCOB
 JSR PVCNT
 LDA #0
 STA PVTOP
 JSR SWAPPAGE
 JSR CLRSCR
 JSR PVHDR
 JSR PVBARS
 JSR PVDRAW
PVKEY JSR GETCHORD
 LDA CHMOD
 BMI PVKOA
 AND #$40
 BNE PVKSA
 JMP PVKPL
PVKOA LDA CHKEY
 CMP #$0B
 BEQ PVPGU
 CMP #$0A
 BEQ PVPGD
 JMP PVKEY
PVKSA LDA CHKEY
 AND #$DF
 CMP #$43
 BEQ PVDONE
 JMP PVKEY
PVKPL LDA CHKEY
 CMP #$1B
 BEQ PVDONE
 CMP #$0B
 BEQ PVUP
 CMP #$0A
 BEQ PVDN
 JMP PVKEY
* The RTS of SWAPPAGE is our own: the form comes
* back, and the cursor it comes back with is the
* one page 1 was saved with.
PVDONE JMP SWAPPAGE

* ---- the scrolling keys ----
PVUP LDA PVTOP
 BEQ PVRED
 DEC PVTOP
PVRED JSR PVDRAW
 JMP PVKEY
PVDN JSR PVMAX
 CMP PVTOP
 BEQ PVRED
 BCC PVRED
 INC PVTOP
 JMP PVRED
PVPGU LDA PVTOP
 SEC
 SBC #PVNP
 BCS PVPU1
 LDA #0
PVPU1 STA PVTOP
 JMP PVRED
PVPGD JSR PVMAX
 STA PVMX
 LDA PVTOP
 CLC
 ADC #PVNP
 CMP PVMX
 BCC PVPD1
 LDA PVMX
PVPD1 STA PVTOP
 JMP PVRED

* ---- PVMAX: the largest legal PVTOP -> A --------
* Never negative: a program shorter than the window
* pins the top line at zero.
PVMAX SEC
 LDA PVNL
 SBC #PVNP
 BCS PVMXD
 LDA #0
PVMXD RTS

* ---- PVDRAW: what a scroll changes --------------
* The header and the bars do not move, so they are
* drawn once by DOPREV and not here.
PVDRAW JSR PVRULE
 JMP PVBODY

* ================= COUNTING =================
* ---- PVCNT: lines in EXPOUT -> PVNL -------------
* One byte is enough by construction: ADDENT caps
* the form at fifteen fields, and the worst field
* emits four lines, so no form can generate more
* than about seventy.
PVCNT LDA #0
 STA PVNL
 LDA #<EXPOUT
 STA PVPTR
 LDA #>EXPOUT
 STA PVPTR+1
 LDA EXLEN
 STA PVCL
 LDA EXLEN+1
 STA PVCL+1
PVC1 LDA PVCL
 ORA PVCL+1
 BEQ PVCD
 LDY #0
 LDA (PVPTR),Y
 CMP #$0D
 BNE PVC2
 INC PVNL
PVC2 JSR PVBUMP
 LDA PVCL
 BNE PVC3
 DEC PVCL+1
PVC3 DEC PVCL
 JMP PVC1
PVCD RTS

* ---- PVSEEK: PVPTR -> the first byte of PVTOP ---
PVSEEK LDA #<EXPOUT
 STA PVPTR
 LDA #>EXPOUT
 STA PVPTR+1
 LDA PVTOP
 STA PVSK
 BEQ PVKD
PVK1 LDY #0
 LDA (PVPTR),Y
 CMP #$0D
 BNE PVK2
 DEC PVSK
 BEQ PVK3
PVK2 JSR PVBUMP
 JMP PVK1
PVK3 JSR PVBUMP
PVKD RTS

* ---- PVBUMP: PVPTR = PVPTR + 1 ------------------
PVBUMP INC PVPTR
 BNE PVBD
 INC PVPTR+1
PVBD RTS

* ================= DRAWING =================
* ---- PVBODY: rows 2-21 from PVTOP ---------------
PVBODY JSR PVSEEK
 LDA #0
 STA PVROWN
PVB1 LDA PVROWN
 CMP #PVNP
 BCS PVBDN
 JSR PVLINE
 INC PVROWN
 JMP PVB1
PVBDN RTS

* ---- PVLINE: one line into ROWBUF, then blit ----
* A $00 is the unwritten tail of the buffer, past
* EXLEN.  We stop on it WITHOUT stepping over it,
* so every row after the last line of code comes
* out blank rather than walking off into whatever
* the previous export left behind.
PVLINE LDA #0
 STA PVCOL
PVL1 LDY #0
 LDA (PVPTR),Y
 BEQ PVL2
 CMP #$0D
 BEQ PVL2
 LDX PVCOL
 CPX #80
 BCS PVL1B
 AND #$7F
 JSR PVPUT
PVL1B JSR PVBUMP
 JMP PVL1
PVL2 CMP #$0D
 BNE PVL2A
 JSR PVBUMP
PVL2A LDA PVCOL
 CMP #80
 BCS PVL3
 LDA #$20
 JSR PVPUT
 JMP PVL2A
PVL3 CLC
 LDA PVROWN
 ADC #PVROW
 TAX
 JMP PUTROW

* ---- PVRULE: row 1 - where you are --------------
* $AD is '-' with the high bit already set, so the
* fill goes straight into ROWBUF without PVPUT.
PVRULE LDA #$AD
 LDX #79
PVR1 STA ROWBUF,X
 DEX
 BPL PVR1
 LDA #2
 STA PVCOL
 LDA #<PMLINE
 LDX #>PMLINE
 JSR PVPUTS
 LDA PVTOP
 CLC
 ADC #1
 JSR PVNUM
 LDA #<PMOF
 LDX #>PMOF
 JSR PVPUTS
 LDA PVNL
 JSR PVNUM
 LDA #$20
 JSR PVPUT
 LDX #1
 JMP PUTROW

* ---- PVHDR: row 0 - the name and the room left --
PVHDR LDX #0
 JSR CLRROW
 STZ SCRROW
 STZ SCRCOL
 STZ SCRATR
 LDA NAMEBUF
 BEQ PVHU
 LDA #<NAMEBUF
 LDX #>NAMEBUF
 JMP PVHN
PVHU LDA #<PMUNT
 LDX #>PMUNT
PVHN STA STRPTR
 STX STRPTR+1
 JSR PUTS
* The figure that matters here is not the machine's
* free memory - FORMAT holds its form in main and
* uses no auxiliary records at all - but the room
* left in the export buffer, which is the only
* thing a bigger screen can exhaust.
 SEC
 LDA #<EXMAX
 SBC EXLEN
 STA NFVAL
 LDA #>EXMAX
 SBC EXLEN+1
 STA NFVAL+1
 LDA #0
 STA NFVAL+2
 JSR NFCOMMA
 LDA #0
 STA PVHIX
 LDX #0
PVH1 INX
 LDA NFBUF,X
 LDY PVHIX
 STA PVHBUF+1,Y
 INC PVHIX
 CPX NFBUF
 BCC PVH1
 LDX #0
PVH2 LDA PMTAIL,X
 LDY PVHIX
 STA PVHBUF+1,Y
 INC PVHIX
 INX
 CPX #16
 BCC PVH2
 LDA PVHIX
 STA PVHBUF
 LDA #<PVHBUF
 STA STRPTR
 LDA #>PVHBUF
 STA STRPTR+1
 LDA #0
 STA SCRROW
 STA SCRATR
 JMP NFPUTR

* ---- PVBARS: rows 22 and 23 ---------------------
PVBARS LDX #0
PVBR1 LDA PVBTAB,X
 CMP #$FF
 BEQ PVBRD
 STA SCRROW
 LDA PVBTAB+1,X
 STA STRPTR
 LDA PVBTAB+2,X
 STA STRPTR+1
 LDA PVBTAB+3,X
 STA SCRCOL
 LDA #0
 STA SCRATR
 STX PVBSV
 JSR PUTSX
 LDX PVBSV
 TXA
 CLC
 ADC #4
 TAX
 JMP PVBR1
PVBRD RTS

* ================= ROW BUILDING =================
* ---- PVPUT: A = character, at column PVCOL ------
* ROWBUF is split, so the column's parity picks the
* half - exactly as it picks the memory bank on the
* screen itself.
PVPUT PHA
 LDA PVCOL
 LSR
 STA PVIX
 LDA PVCOL
 AND #1
 BEQ PVP1
 LDA PVIX
 CLC
 ADC #40
 STA PVIX
PVP1 PLA
 ORA #$80
 LDX PVIX
 STA ROWBUF,X
 INC PVCOL
 RTS

* ---- PVPUTS: A/X -> a length-prefixed string ----
PVPUTS STA ZPT1
 STX ZPT1+1
 LDY #0
 LDA (ZPT1),Y
 STA PVLEN
 BEQ PVSD
 LDA #1
 STA PVSAV
PVS1 LDY PVSAV
 LDA (ZPT1),Y
 JSR PVPUT
 INC PVSAV
 LDA PVLEN
 CMP PVSAV
 BCS PVS1
PVSD RTS

* ---- PVNUM: A = 0-255, decimal, no leading zero -
* Clobbers X, which is why the row builders keep
* their indices in memory.
PVNUM LDX #0
 STX PVD1
 STX PVD2
 STX PVANY
PVN1 CMP #100
 BCC PVN2
 SBC #100
 INC PVD1
 JMP PVN1
PVN2 CMP #10
 BCC PVN3
 SBC #10
 INC PVD2
 JMP PVN2
PVN3 STA PVD3
 LDA PVD1
 BEQ PVN4
 CLC
 ADC #$30
 JSR PVPUT
 LDA #1
 STA PVANY
PVN4 LDA PVD2
 BNE PVN5
 LDA PVANY
 BEQ PVN6
PVN5 LDA PVD2
 CLC
 ADC #$30
 JSR PVPUT
PVN6 LDA PVD3
 CLC
 ADC #$30
 JMP PVPUT

* ================= LITERALS =================
* row, string, column - and $FF at the end, the
* same table shape EDIT's bars use.
PVBTAB DFB 22
 DA PVB1S
 DFB 2
 DFB 22
 DA PVB2S
 DFB 24
 DFB 22
 DA PVB3S
 DFB 60
 DFB 23
 DA PVB4S
 DFB 2
 DFB $FF

* $00 says "the next byte is a raw screen code":
* $41 is the open apple, $40 the solid one.
PVB1S DFB 12
 ASC 'UP/DN Scroll'
PVB2S DFB 13
 DFB $00,$41
 ASC '-UP/DN Page'
PVB3S DFB 8
 ASC 'ESC Back'
PVB4S DFB 21
 DFB $00,$40
 ASC '-C Back to the form'

PMLINE DFB 6
 ASC ' LINE '
PMOF DFB 4
 ASC ' OF '
PMUNT DFB 8
 ASC 'UNTITLED'
PMTAIL ASC ' BYTES IN BUFFER'

* ================= VARIABLES =================
PVTOP DFB 0
PVNL DFB 0
PVMX DFB 0
PVSK DFB 0
PVCOL DFB 0
PVIX DFB 0
PVLEN DFB 0
PVSAV DFB 0
PVBSV DFB 0
PVROWN DFB 0
PVD1 DFB 0
PVD2 DFB 0
PVD3 DFB 0
PVANY DFB 0
PVHIX DFB 0
PVCL DS 2
PVHBUF DS 40
