* VMMATH.S  arithmetic and the expression stack
* PUT from VM.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* ================= ARITHMETIC =================
* VALIGN: bring operand B to the destination's
* scale.  The two descriptors are in VMD1 and VMD2
* and the difference decides which way to shift.
VALIGN LDA VMD2+DDEC
 CMP VMD1+DDEC
 BEQ VALD
 BCC VALR
 SEC
 SBC VMD1+DDEC
 STA BCDDIG
 JMP BCDSHL
VALR LDA VMD1+DDEC
 SEC
 SBC VMD2+DDEC
 STA BCDDIG
* POPDR asks for the digits dropped here to round
 LDA VMRND
 BEQ VALR1
 JMP BCDRND
VALR1 JMP BCDSHR
VALD RTS

* VPREP: source -> the scratch cell, shifted to the
* destination's scale, with ZPT1 left pointing at
* the scratch.  Every two-operand arithmetic
* instruction starts here, and it is why the
* compiler emits no alignment of its own.
VPREP LDA VMO1
 STA ZPT1
 LDA VMO1+1
 STA ZPT1+1
 LDA #<VMSCR
 STA ZPT2
 LDA #>VMSCR
 STA ZPT2+1
 JSR BCDMOV
 JSR VALIGN
 LDA #<VMSCR
 STA ZPT1
 LDA #>VMSCR
 STA ZPT1+1
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 RTS

* VMODE: the mode byte.  Bit 0 is ROUNDED - but the
* compiler no longer sets it: VMARE rounded nothing
* (BCDDIG 0), and ADDP had already truncated its
* source.  ROUNDED goes the expression-stack way and
* ends in POPDR (FIXLIST A15).
VADDP JSR VOPD
 JSR VOPS
 JSR VFETCH
 STA VMMODE
 JSR VSZSV
 JSR VPREP
 JSR BCDADD
 JMP VMARE
VSUBP JSR VOPD
 JSR VOPS
 JSR VFETCH
 STA VMMODE
 JSR VSZSV
 JSR VPREP
 JSR BCDSUB
 JMP VMARE

* Multiply and divide carry scale through the
* operation rather than into it: a product's scale
* is the sum of the two, a quotient's the
* difference, and only then is it brought to the
* destination's.
VMULP JSR VOPD
 JSR VOPS
 JSR VFETCH
 STA VMMODE
 JSR VSZSV
 JSR VSETP
 JSR BCDMUL
 CLC
 LDA VMD1+DDEC
 ADC VMD2+DDEC
 STA VMT2
 LDA VMD2+DDEC
 JSR VSCALE
 JMP VMARE
VDIVP JSR VOPD
 JSR VOPS
 JSR VFETCH
 STA VMMODE
* saved before the dividend is shifted: the shift
* is done in the receiver itself
 JSR VSZSV
* pre-scale the dividend so the quotient lands with
* the digits the destination wants
 CLC
 LDA VMD2+DDEC
 ADC VMD1+DDEC
 SEC
 SBC VMD2+DDEC
 STA BCDDIG
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDA BCDDIG
 BEQ VDV1
 JSR BCDSHL
VDV1 JSR VSETP
 JSR BCDDIV
 JSR VDIV0
 JMP VMARE

* VSCALE: A = wanted scale, VMT2 = the scale the
* value actually has
VSCALE STA VMT1
 LDA VMT2
 CMP VMT1
 BEQ VSCD
 BCC VSCL
 SEC
 SBC VMT1
 STA BCDDIG
 JMP BCDSHR
VSCL LDA VMT1
 SEC
 SBC VMT2
 STA BCDDIG
 JMP BCDSHL
VSCD RTS

* VMARE: what every arithmetic instruction does on
* the way out - round if asked, then the size check
* (VSZFIN, below).
VMARE LDA VMMODE
 AND #1
 BEQ VMAR1
 LDA #0
 STA BCDDIG
 JSR BCDRND
VMAR1 JSR VSZFIN
 JMP VMLOOP

* ================= SIZE ERRORS =================
* ON SIZE ERROR, and the stop when there is none
* (FIXLIST B, 2026-11-11).
*
* WHAT A SIZE ERROR IS.  A NUM8 cell holds fourteen
* digits whatever the PICTURE says, so ADD 50 TO X
* with X PIC 99 at 60 used to leave 110 in the cell:
* DISPLAY showed 10, IF X > 99 was true, and nothing
* said a word.  Now the result is held against the
* integer digits the PICTURE allows - the count the
* compiler keeps in the top four bits of the flags
* byte (CMPPIC PPD3) - and a digit above them is a
* size error.  So is a result over fourteen digits
* (the library's BCDERR 1) and a zero divisor
* (BCDERR 2).
*
* WHAT HAPPENS THEN.  The receiver is put back as it
* was - COBOL's rule for ON SIZE ERROR - and the
* statement's last instruction decides:
*   BSIZ   (there is a clause) runs it
*   SZCHK  (there is none) stops the run:
*          "Size error at line n", or "Divide by
*          zero at line n" as before
* so a program never goes on with a wrong number.
*
* ONLY THE PROGRAMMER'S STATEMENTS ARE CHECKED.  The
* compiler's own arithmetic - PERFORM VARYING's step,
* the TIMES counter - uses POPD too, and must not
* stop a run or leave a flag behind for some later
* statement.  So every ADD, SUBTRACT, MULTIPLY,
* DIVIDE and COMPUTE starts with SZON, which turns
* the checking on, and ends with SZCHK or BSIZ,
* which turn it off.  Two bytes a statement.
*
* THE FLAGS.  VMSZM is 1 between SZON and the end.
* VMSZP collects what went wrong on the way to ONE
* store - an expression's middle steps can fail
* before POPD is reached - and is emptied by that
* store.  VMEXC keeps the answer for the end of the
* statement: bit 0 a size error, bit 3 that it was a
* zero divisor.  Bits 1 and 2 are BEXC's.

* ---- VSZSV: keep the receiver, VMO2, in VMSAV ---
* Before every checked store.  Eight bytes whatever
* the receiver is: a cell is eight, and nothing is
* written back unless the store failed.
VSZSV LDA VMSZM
 BEQ VSZSX
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDY #7
VSZS1 LDA (ZPT2),Y
 STA VMSAV,Y
 DEY
 BPL VSZS1
VSZSX RTS

* ---- VSZER: the library's error byte -> VMSZP ---
* 1 (over fourteen digits) is a size error, 2 (zero
* divisor) is one with bit 3 as well.  3 is an
* operand that was never given a value: not a size
* error, and dropped here as it always was.
VSZER LDA VMSZM
 BEQ VSZEX
 LDA BCDERR
 BEQ VSZEX
 CMP #3
 BEQ VSZE3
 CMP #2
 BNE VSZE1
 LDA #9
 BRA VSZE2
VSZE1 LDA #1
VSZE2 ORA VMSZP
 STA VMSZP
VSZE3 STZ BCDERR
VSZEX RTS

* ---- VSZFIN: after a store to VMO2 / VMD2 -------
* Unchecked (the compiler's own arithmetic) the
* library's byte is simply dropped, as it always
* was.  Checked, the result is held against the
* PICTURE and a failure puts the receiver back.
VSZFIN JSR VSZER
 STZ BCDERR
 LDA VMSZM
 BEQ VSZFX
 LDA VMD2+DTYPE
 CMP #TNUM
 BNE VSZF1
 JSR VFIT
 BCC VSZF1
 LDA VMSZP
 ORA #1
 STA VMSZP
VSZF1 LDA VMSZP
 BEQ VSZFX
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDY #7
VSZF2 LDA VMSAV,Y
 STA (ZPT2),Y
 DEY
 BPL VSZF2
 LDA VMEXC
 ORA VMSZP
 STA VMEXC
 STZ VMSZP
VSZFX RTS

* ---- VFIT: does the cell at VMO2 fit VMD2? ------
* out: C=1 if not.  N = the PICTURE's integer
* digits (0 = not recorded: anything fits), D = its
* decimals.  The cell is fourteen digits at the
* item's own scale, most significant first, so the
* top 14 - N - D of them must all be zero.  Digit
* 0 is the high nibble of byte NMSB.
VFIT LDA VMD2+DFLG
 LSR
 LSR
 LSR
 LSR
 BEQ VFOK
 CLC
 ADC VMD2+DDEC
 CMP #NDIG
 BCS VFOK
 STA VMSZT
 LDA #NDIG
 SEC
 SBC VMSZT
 STA VMSZT
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDY #NMSB
VFIT1 LDA (ZPT2),Y
 AND #$F0
 BNE VFBAD
 DEC VMSZT
 BEQ VFOK
 LDA (ZPT2),Y
 AND #$0F
 BNE VFBAD
 DEC VMSZT
 BEQ VFOK
 INY
 BRA VFIT1
VFOK CLC
 RTS
VFBAD SEC
 RTS

* ---- $59 SZON: a checked statement starts -------
VSZON LDA #1
 STA VMSZM
 STZ VMSZP
 LDA VMEXC
 AND #$F6
 STA VMEXC
 JMP VMLOOP

* ---- $5A SZCHK: it ends with no clause ----------
* A size error stops the run here, at the line the
* statement is on.
VSZCK STZ VMSZM
 LDA VMEXC
 AND #1
 BNE VSZC1
 JMP VMLOOP
VSZC1 LDA VMEXC
 AND #8
 BEQ VSZC2
 LDA #<MDIV0
 LDX #>MDIV0
 JMP VMDIE
VSZC2 LDA #<MSIZE
 LDX #>MSIZE
 JMP VMDIE

* ---- $5B SZSKP target: branch if failed so far --
* DIVIDE ... REMAINDER: the remainder is worked out
* from the quotient as stored, so when the quotient
* failed there is nothing to work it from and the
* remainder is left alone too.  The flag is not
* cleared - SZCHK or BSIZ still needs it.
VSZSK LDA VMEXC
 AND #1
 BEQ VSZK1
 JMP VBRAN
VSZK1 JMP VSKIP

* ================= EXPRESSION STACK ============
* COMPUTE compiles to reverse Polish.  The stack is
* NUM8 cells in main memory, not on the 6502's
* stack: an operand is eight bytes and the hardware
* stack is 256 of them.
VESADR LDA #0
 STA VMT1+1
 LDA VMESP
 ASL
 ASL
 ASL
 STA VMT1
 ROL VMT1+1
 CLC
 LDA VMT1
 ADC #<VMESTK
 STA VMT1
 LDA VMT1+1
 ADC #>VMESTK
 STA VMT1+1
 RTS

VPUSHD JSR VOPS
 LDA VMESP
 CMP #VMEDEP
 BCS VPSOV
 JSR VESADR
 LDA VMO1
 STA ZPT1
 LDA VMO1+1
 STA ZPT1+1
 LDA VMT1
 STA ZPT2
 LDA VMT1+1
 STA ZPT2+1
 JSR BCDMOV
 LDA VMD1+DDEC
 LDX VMESP
 STA VMESCL,X
 INC VMESP
 JMP VMLOOP
VPSOV LDA #<MESTK
 LDX #>MESTK
 JMP VMDIE

VPUSHL JSR VLIT
 LDA VMESP
 CMP #VMEDEP
 BCS VPSOV
 JSR VESADR
 LDY #NCELL-1
VPL1 LDA (VMPT),Y
 STA (VMT1),Y
 DEY
 BPL VPL1
* a literal's scale rides with it in the pool: the
* byte after the cell
 LDY #NCELL
 LDA (VMPT),Y
 LDX VMESP
 STA VMESCL,X
 INC VMESP
 JMP VMLOOP

* POPDR: POPD, ROUNDED (FIXLIST A15).  The stack
* holds the whole result at its own scale, so this is
* the one place where the digits to drop are all
* still there: VALIGN rounds them off instead of
* cutting them.
VPOPDR LDA #1
 STA VMRND
VPOPD JSR VOPD
 JSR VSZSV
 JSR VEPOP
 LDA VMT1
 STA ZPT1
 LDA VMT1+1
 STA ZPT1+1
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 JSR BCDMOV
* the stacked value's scale is in VMD1's place so
* VALIGN can do its usual work
 LDX VMESP
 LDA VMESCL,X
 STA VMD1+DDEC
 JSR VALIGN
 STZ VMRND
 JSR VSZFIN
 JMP VMLOOP

* VEPOP: drop the top -> VMT1 = its address
VEPOP LDA VMESP
 BEQ VEPU
 DEC VMESP
 JMP VESADR
VEPU LDA #<MESTK
 LDX #>MESTK
 JMP VMDIE

* The binary operators all have the same shape:
* pop b, leave a on top, compute a = a op b.
VEBIN JSR VEPOP
 LDA VMT1
 STA ZPT1
 LDA VMT1+1
 STA ZPT1+1
 LDX VMESP
 LDA VMESCL,X
 STA VMD1+DDEC
 LDA VMESP
 BEQ VEBU
 DEC VMESP
 JSR VESADR
 INC VMESP
 LDA VMT1
 STA ZPT2
 LDA VMT1+1
 STA ZPT2+1
 LDX VMESP
 DEX
 LDA VMESCL,X
 STA VMD2+DDEC
 RTS
VEBU LDA #<MESTK
 LDX #>MESTK
 JMP VMDIE

VEADD JSR VEBIN
 JSR VALGE
 JSR BCDADD
 JSR VSZER
 JMP VMLOOP
VESUB JSR VEBIN
 JSR VALGE
 JSR BCDSUB
 JSR VSZER
 JMP VMLOOP
VEMUL JSR VEBIN
 JSR BCDMUL
 CLC
 LDX VMESP
 DEX
 LDA VMESCL,X
 ADC VMD1+DDEC
 STA VMESCL,X
 JSR VSZER
 JMP VMLOOP
* a / b.  BCDDIV divides the digits as integers, so
* the quotient's scale is a's minus b's - and 10 /
* 2.50 was 10 / 250 = 0 (FIXLIST A7).  So a is
* shifted left first, by k digits, to give the
* quotient Q = MAX(a's, b's, 5) decimals - five, so
* that a ROUNDED result of four decimals still has a
* digit to round on:
*     k = Q - a's + b's
* but never by more than a's leading zero digits,
* which would push digits off the top.  If that cap
* leaves Q below zero - a dividend of thirteen or
* fourteen digits over a decimal divisor - b loses
* its low digits instead and Q is 0.
VEDIV JSR VEBIN
 LDA #5
 CMP VMD2+DDEC
 BCS VDQ1
 LDA VMD2+DDEC
VDQ1 CMP VMD1+DDEC
 BCS VDQ2
 LDA VMD1+DDEC
VDQ2 SEC
 SBC VMD2+DDEC
 CLC
 ADC VMD1+DDEC
 STA VMEK
* a's leading zero digits, counted straight off the
* packed cell: digit 0 is the high nibble of byte
* NMSB.  (NGETD would do it, but it lives in the
* language card and is not in the library's table.)
 STZ VMELZ
 LDY #NMSB
VDQ3 LDA (ZPT2),Y
 AND #$F0
 BNE VDQ4
 INC VMELZ
 LDA (ZPT2),Y
 AND #$0F
 BNE VDQ4
 INC VMELZ
 INY
 CPY #NMSB+7
 BCC VDQ3
VDQ4 LDA VMEK
 CMP VMELZ
 BCC VDQ5
 LDA VMELZ
 STA VMEK
* Q = a's + k - b's
VDQ5 CLC
 LDA VMD2+DDEC
 ADC VMEK
 SEC
 SBC VMD1+DDEC
 BCS VDQ6
* below zero: b drops -Q digits, Q = 0
 EOR #$FF
 ADC #1
 STA BCDDIG
 JSR VBSHR
 LDA #0
VDQ6 LDX VMESP
 DEX
 STA VMESCL,X
 LDA VMEK
 STA BCDDIG
 JSR BCDSHL
 JSR BCDDIV
 JSR VDIV0
 JMP VMLOOP
* VDIV0: stop the run on a zero divisor.  BDIV
* leaves the dividend alone and says 2; the result
* used to be the dividend, silently.  The manual
* has always said a program that divides by zero
* stops, and now it does.
* In a checked statement it is a size error instead
* (VSZER): ON SIZE ERROR catches it, and SZCHK stops
* the run with the same message when there is no
* clause.
VDIV0 LDA VMSZM
 BEQ VDV01
 JMP VSZER
VDV01 LDA BCDERR
 CMP #2
 BEQ VDV0D
 RTS
VDV0D LDA #<MDIV0
 LDX #>MDIV0
 JMP VMDIE
* VBSHR: operand A (ZPT1) / 10^BCDDIG.  BCDSHR works
* on B, so the pointers trade places around it.
VBSHR LDA ZPT2
 STA VMT2
 LDA ZPT2+1
 STA VMT2+1
 LDA ZPT1
 STA ZPT2
 LDA ZPT1+1
 STA ZPT2+1
 JSR BCDSHR
 LDA ZPT2
 STA ZPT1
 LDA ZPT2+1
 STA ZPT1+1
 LDA VMT2
 STA ZPT2
 LDA VMT2+1
 STA ZPT2+1
 RTS
VENEG JSR VEPOP
 INC VMESP
 LDA VMT1
 STA ZPT2
 LDA VMT1+1
 STA ZPT2+1
 JSR BCDNEG
 JMP VMLOOP

* VALGE: bring the popped operand to the scale of
* the one it is being added to.  Add and subtract
* need it; multiply does not, because a product
* carries the sum of the two scales and EMUL
* records that instead.
*
* The popped cell is shifted rather than the
* accumulator, and it can be shifted freely because
* it has already left the stack - nothing will read
* it again.  BCDSHL works on operand B, so the two
* pointers trade places for the duration.
* THE ONE WITH FEWER DECIMALS IS SHIFTED UP, never
* the other one down.  It used to shift the popped
* operand to the accumulator's scale either way, so
* in 1 + 0.5 the 0.5 went right one place and was
* lost: 1 (FIXLIST A7).  When the popped one has
* more, the accumulator - B, on the stack - goes up
* to its scale and takes that scale with it.
VALGE LDA VMD1+DDEC
 CMP VMD2+DDEC
 BNE VLG0
 RTS
VLG0 BCC VLG1
 SEC
 SBC VMD2+DDEC
 STA BCDDIG
 JSR BCDSHL
 LDX VMESP
 DEX
 LDA VMD1+DDEC
 STA VMESCL,X
 STA VMD2+DDEC
 RTS
VLG1 LDA ZPT2
 STA VMT2
 LDA ZPT2+1
 STA VMT2+1
 LDA ZPT1
 STA ZPT2
 LDA ZPT1+1
 STA ZPT2+1
 LDA VMD1+DDEC
 CMP VMD2+DDEC
 BCS VLG2
 LDA VMD2+DDEC
 SEC
 SBC VMD1+DDEC
 STA BCDDIG
 JSR BCDSHL
 JMP VLG3
VLG2 LDA VMD1+DDEC
 SEC
 SBC VMD2+DDEC
 STA BCDDIG
 JSR BCDSHR
VLG3 LDA ZPT2
 STA ZPT1
 LDA ZPT2+1
 STA ZPT1+1
 LDA VMT2
 STA ZPT2
 LDA VMT2+1
 STA ZPT2+1
 RTS

