* SCRSHOW.S  draw a form from a dictionary
* LIBRARY MODULE - slot 100, vector FRMSHOW.
* It used to be a PUT file, which meant its entry
* point moved with every program that included it,
* and compiled p-code can only call an address that
* does not move.  Moved in 2026-08-23 with SCRINP.
* Calls the screen through the jump table.
* Draws labels + field blanks in rows 0-21 only.
* Rows 22 (commands) and 23 (line entry) are left
* alone for other modules.
* Set ZPDICT -> dictionary, then JSR FRMSHOW.

* zero page now in EQUATES.S - PUT it first

* CLRDATA used to live here.  It is now a library
* vector - the driver owns the soft switches, and
* this module has no business knowing which bank a
* column lands in.

* ---- SCRSHOW: ZPDICT = dictionary base ----
SCRSHOW JSR CLRDATA
 JSR SHLBLS
 JSR SHFLDS
 RTS

* ---- SHLBLS: draw labels ----
* WPTR = base + labeloff (header 14,15)
SHLBLS LDY #14
 LDA (ZPDICT),Y
 CLC
 ADC ZPDICT
 STA WPTR
 LDY #15
 LDA (ZPDICT),Y
 ADC ZPDICT+1
 STA WPTR+1
 LDY #9
 LDA (ZPDICT),Y
 STA SHCNT
 BEQ SHLD
SHLL LDY #0
 LDA (WPTR),Y
 STA SCRROW
 LDY #1
 LDA (WPTR),Y
 STA SCRCOL
 LDY #2
 LDA (WPTR),Y
 STA SCRATR
 LDY #3
 LDA (WPTR),Y
 STA SHLEN
 LDA SCRROW
 CMP #22
 BCS SHLNX
 CLC
 LDA WPTR
 ADC #3
 STA STRPTR
 LDA WPTR+1
 ADC #0
 STA STRPTR+1
 JSR PUTS
SHLNX LDA SHLEN
 CLC
 ADC #4
 STA SHTMP
 CLC
 LDA WPTR
 ADC SHTMP
 STA WPTR
 LDA WPTR+1
 ADC #0
 STA WPTR+1
 DEC SHCNT
 BNE SHLL
SHLD RTS

* ---- SHFLDS: draw field blanks ----
* WPTR = base + fieldoff (header 12,13)
SHFLDS LDY #12
 LDA (ZPDICT),Y
 CLC
 ADC ZPDICT
 STA WPTR
 LDY #13
 LDA (ZPDICT),Y
 ADC ZPDICT+1
 STA WPTR+1
 LDY #8
 LDA (ZPDICT),Y
 STA SHCNT
 BEQ SHFD
SHFL LDY #16
 LDA (WPTR),Y
 STA SCRROW
 LDY #17
 LDA (WPTR),Y
 STA SCRCOL
 LDY #18
 LDA (WPTR),Y
 STA SCRATR
 LDY #11
 LDA (WPTR),Y
 STA SHWID
 LDA SCRROW
 CMP #22
 BCS SHFNX
 LDA SCRATR
 BEQ SHFNM
 LDA #$20
 BNE SHFST
SHFNM LDA #$A0
SHFST STA SHFILL
 LDX SCRROW
 JSR SCRADDR
 LDX SHWID
 BEQ SHFNX
SHFBL LDA SHFILL
 JSR PUTC
 DEX
 BNE SHFBL
SHFNX CLC
 LDA WPTR
 ADC #24
 STA WPTR
 LDA WPTR+1
 ADC #0
 STA WPTR+1
 DEC SHCNT
 BNE SHFL
SHFD RTS

* ---- variables ----
SHCNT DFB 0
SHLEN DFB 0
SHTMP DFB 0
SHWID DFB 0
SHFILL DFB 0
