* VMFLOW.S  compare, branch, PERFORM/RET/GOTO
* PUT from VM.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* ================= COMPARE AND BRANCH ==========
* The cell does not carry its scale - the
* descriptor does - so two cells are comparable
* only at the same scale.  This compared them raw:
* a 9(5)V99 holding 50.00 is the digits 5000, and
* IF BAL > 100 was true (2026-11-08, FIXLIST A3).
* Now the one with FEWER decimals is copied to the
* scratch cell and shifted left to the other's
* scale.  Left, never right: a right shift drops
* digits, and 50.001 would equal 50.
* B is the first operand, A the second, as before.
VCMPN JSR VOPD
 JSR VOPS
 LDA VMD1+DDEC
 CMP VMD2+DDEC
 BEQ VCN0
 BCC VCN1
* the first operand has fewer: scale it up into
* the scratch, then compare scratch (B) with A
 SEC
 SBC VMD2+DDEC
 STA BCDDIG
 LDA VMO2
 STA ZPT1
 LDA VMO2+1
 STA ZPT1+1
 JSR VCNSC
 LDA #<VMSCR
 STA ZPT2
 LDA #>VMSCR
 STA ZPT2+1
 LDA VMO1
 STA ZPT1
 LDA VMO1+1
 STA ZPT1+1
 JMP VCN2
* the second has fewer: scratch is A
VCN1 LDA VMD2+DDEC
 SEC
 SBC VMD1+DDEC
 STA BCDDIG
 LDA VMO1
 STA ZPT1
 LDA VMO1+1
 STA ZPT1+1
 JSR VCNSC
 LDA #<VMSCR
 STA ZPT1
 LDA #>VMSCR
 STA ZPT1+1
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 JMP VCN2
VCN0 JSR VSETP
VCN2 JSR BCDCMP
 LDA BCMPR
 STA VMCC
 JMP VMLOOP
* VCNSC: the cell at ZPT1 -> VMSCR, times
* 10^BCDDIG.  Leaves ZPT2 at VMSCR.
VCNSC LDA #<VMSCR
 STA ZPT2
 LDA #>VMSCR
 STA ZPT2+1
 JSR BCDMOV
 LDA #<VMSCR
 STA ZPT2
 LDA #>VMSCR
 STA ZPT2+1
 JMP BCDSHL

VCMPA JSR VOPD
 JSR VOPS
 JSR VSETP
 LDA VMD1+DLEN
 STA ALEN
 LDA VMD2+DLEN
 STA BLEN
 JSR CMPALP
 LDA BCMPR
 STA VMCC
 JMP VMLOOP


* ---- VCLASS ($62): IF X IS NUMERIC and its kin --
* Six bytes: the item, one byte saying which test,
* and a literal-pool reference to a membership map.
*
* The map reference is fetched even when the test
* does not want one - only class 10, a user class
* declared by SPECIAL-NAMES, ever reads it.  Two
* bytes of object per class condition is cheaper
* than a variable-length instruction, which every
* other opcode in this interpreter has avoided
* being and which would make VBAD's promise - that
* any byte which is not an opcode faults - false
* for the byte after this one.
*
* CLASS answers 0 for true, which is what the
* condition register already means, so the branch
* the compiler emits after this is the same VBEQ
* an ordinary comparison gets.
VCLASS JSR VOPD
 JSR VFETCH
 STA CLCLS
 JSR VLIT
 LDA VMPT
 STA CLTAB
 LDA VMPT+1
 STA CLTAB+1
 LDA VMD2+DLEN
 STA CLLEN
 JSR VSETP
 JSR CLASS
 STA VMCC
 JMP VMLOOP

* A branch target is an offset from the code base,
* not from here: a relative branch would have to be
* fixed up by the compiler at a distance it does
* not know yet.
VBRAN JSR VFETW
 JMP VBRA2

VSKIP JSR VFETW
 JMP VMLOOP

VBRA JMP VBRAN
VBEQ LDA VMCC
 BEQ VBRA
 JMP VSKIP
VBNE LDA VMCC
 BNE VBRA
 JMP VSKIP
VBLT LDA VMCC
 CMP #$FF
 BEQ VBRA
 JMP VSKIP
VBGT LDA VMCC
 CMP #1
 BEQ VBRA
 JMP VSKIP
VBLE LDA VMCC
 BEQ VBRA
 CMP #$FF
 BEQ VBRA
 JMP VSKIP
VBGE LDA VMCC
 BEQ VBRA
 CMP #1
 BEQ VBRA
 JMP VSKIP
* BSIZ ends a checked arithmetic statement that has
* ON SIZE ERROR (VMMATH, SIZE ERRORS): checking off,
* and the clause runs if the statement failed.  Bit 3
* (it was a zero divisor) goes with bit 0.
VBSIZ STZ VMSZM
 LDA VMEXC
 AND #1
 BNE VBSZ1
 JMP VSKIP
VBSZ1 LDA VMEXC
 AND #$F6
 STA VMEXC
 JMP VBRAN
VBEXC LDA VMEXC
 AND #6
 BNE VBEX1
 JMP VSKIP
VBEX1 LDA VMEXC
 AND #$F9
 STA VMEXC
 JMP VBRAN

* ================= CONTROL FLOW ================
* PERFORM's return stack is the interpreter's, not
* the processor's.  A COBOL program can PERFORM
* THRU a range that PERFORMs another, and the depth
* has nothing to do with how deep the 6502 is.
VGOTO JMP VBRAN

* PERF target, return, END: the third operand is the
* paragraph the range ends at, kept on VMRMK beside
* the return offset so RET can tell its own PERFORM
* from a paragraph that is merely being fallen into.
VPERF JSR VFETW
 LDA VMW
 STA VMT2
 LDA VMW+1
 STA VMT2+1
 JSR VFETW
 JSR VFETCH
 LDX VMRSP
 STA VMRMK,X
 JSR VRPUSH
 LDA VMT2
 STA VMW
 LDA VMT2+1
 STA VMW+1
 JMP VBRA2

* VBRA2: branch to the offset already in VMW.
* Targets are offsets from the code base, not
* relative to here: the compiler fixes up a forward
* branch long before it knows how far away it
* landed, and an absolute offset is the only kind
* it can write down at that point.
VBRA2 CLC
 LDA VMCB
 ADC VMW
 STA VMIP
 LDA VMCB+1
 ADC VMW+1
 STA VMIP+1
 JMP VMLOOP

* VRPUSH: VMW = the return offset
VRPUSH LDA VMRSP
 CMP #VMRDEP
 BCS VRPOV
 LDA VMRSP
 ASL
 TAX
 LDA VMW
 STA VMRSTK,X
 LDA VMW+1
 STA VMRSTK+1,X
 INC VMRSP
 RTS
VRPOV LDA #<MRSTK
 LDX #>MRSTK
 JMP VMDIE

* RET n: return only if the innermost PERFORM ends at
* paragraph n.  Anything else - no PERFORM pending,
* or one that ends further on - falls through into
* the next paragraph, as COBOL says it must.
VRET JSR VFETCH
 LDX VMRSP
 BEQ VRTF
 CMP VMRMK-1,X
 BEQ VRT1
VRTF JMP VMLOOP
VRT1 LDA VMRSP
 BEQ VRTU
 DEC VMRSP
 LDA VMRSP
 ASL
 TAX
 LDA VMRSTK,X
 STA VMW
 LDA VMRSTK+1,X
 STA VMW+1
 JMP VBRA2
VRTU LDA #<MRSTK
 LDX #>MRSTK
 JMP VMDIE

