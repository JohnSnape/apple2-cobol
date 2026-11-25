* VMLOOP.S  fetch/decode/dispatch, operand resolve
* PUT from VM.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* ================= THE LOOP =================
* One byte, one table lookup, one jump.  Handlers
* come back here with JMP VMLOOP, not RTS, so
* nothing accumulates on the 6502 stack: a COBOL
* PERFORM is thousands of instructions deep in its
* own terms and none of them touch the hardware
* stack.
VMLOOP LDA VMHLT
 BNE VMEND
 JSR VFETCH
 TAX
 LDA VTLO,X
 STA VMJP
 LDA VTHI,X
 STA VMJP+1
 JMP (VMJP)
* A program that ran to STOP RUN leaves its output
* on the screen, and the menu repaints the moment we
* return - so say it is over and wait for a key.
* Without this the result of every program vanished
* before it could be read (2026-11-07).  A fault has
* already waited in VMDIE (VMHLT = 1).
VMEND JSR VFCLALL
 LDA VMHLT
 CMP #2
 BNE VMEND9
 JSR CONCR
 LDA #<MEND
 STA STRPTR
 LDA #>MEND
 STA STRPTR+1
 JSR CONPUTS
 JSR WAITKEY
VMEND9 RTS

* ---- the two RECMAN file slots ------------------
* A slot whose ProDOS reference is not zero is OPEN
* to RECMAN, and nothing used to clear them - so
* the first OPEN of a run met whatever was left in
* $0E50 and said 41, already open, and every WRITE
* after it failed (2026-11-07).  VFINIT empties both
* at the start of a run; VFCLALL, on the way out by
* STOP RUN or by a fault, closes any file the
* program left open, so it cannot leak into the
* next one.
VFINIT LDX #31
VFI1 STZ RMFCB0,X
 DEX
 BPL VFI1
 RTS
VFCLALL LDX #0
VFC1 LDA RMFCB0,X
 BEQ VFC2
 TXA
 LSR
 LSR
 LSR
 LSR
 STA RMFNO
 PHX
 JSR FILCLOS
 PLX
VFC2 TXA
 CLC
 ADC #16
 TAX
 CPX #32
 BCC VFC1
 RTS

* ---- VFETCH: the byte at IP, then IP+1 ----------
VFETCH LDY #0
 LDA (VMIP),Y
 INC VMIP
 BNE VFT1
 INC VMIP+1
VFT1 RTS

* ---- VFETW: the two bytes at IP -> VMW ----------
VFETW JSR VFETCH
 STA VMW
 JSR VFETCH
 STA VMW+1
 RTS

* ================= OPERANDS =================
* ---- VDESC: VMW = item number -> VMPT, VMD ------
* A descriptor is eight bytes and the table is
* dense, so the address is the item number shifted
* three times.  This is the only multiplication in
* the interpreter and it is three shifts, which is
* what a power-of-two record size is for.
VDESC LDA VMW+1
 CMP #$FF
 BEQ VDSLT
VDSN LDA VMW
 STA VMT1
 LDA VMW+1
 STA VMT1+1
 ASL VMT1
 ROL VMT1+1
 ASL VMT1
 ROL VMT1+1
 ASL VMT1
 ROL VMT1+1
 CLC
 LDA VMT1
 ADC VMDT
 STA VMPT
 LDA VMT1+1
 ADC VMDT+1
 STA VMPT+1
 LDY #7
VDS1 LDA (VMPT),Y
 STA VMD,Y
 DEY
 BPL VDS1
 RTS
* $FFF0-$FFF3: a subscript slot, which SUBS filled
* with a table element's descriptor (FIXLIST A2).
* Anything else at $FFxx is an item number as before.
VDSLT LDA VMW
 CMP #$F0
 BCC VDSN
 CMP #$F4
 BCS VDSN
 AND #3
 ASL
 ASL
 ASL
 CLC
 ADC #<VMSUBD
 STA VMPT
 LDA #>VMSUBD
 ADC #0
 STA VMPT+1
 LDY #7
 BRA VDS1

* ---- VSUBS: $18, a table element into a slot ----
*   slot(b) item(w) subscript(w) count(b) stride(b)
* Bit 7 of the slot byte says the subscript is a
* number; otherwise it is the item that holds it.
* The slot gets the table item's descriptor - one
* occurrence - with (subscript - 1) * stride added
* to its offset.  A subscript of 0, over the count,
* negative or not a number stops the run: reading
* past a table would read whatever is next to it.
VSUBS JSR VFETCH
 STA VMSS
 JSR VFETW
 JSR VDESC
 LDA VMSS
 AND #3
 ASL
 ASL
 ASL
 STA VMSO
 TAX
 LDY #0
VSB1 LDA VMD,Y
 STA VMSUBD,X
 INX
 INY
 CPY #8
 BCC VSB1
 JSR VFETW
 LDA VMSS
 BMI VSB3
* the item holding it: a NUM8 cell, read as binary
 JSR VQGETN
 LDY #0
 LDA (VMO2),Y
 AND #FNEG
 BNE VSBBAD
VSB3 JSR VFETCH
 STA VMSN
 JSR VFETCH
 STA VMSW
 LDA VMW+1
 BNE VSBBAD
 LDA VMW
 BEQ VSBBAD
 CMP VMSN
 BEQ VSB4
 BCS VSBBAD
* (subscript - 1) * stride, added to the offset
VSB4 STZ VMT2
 STZ VMT2+1
 LDX VMW
VSB5 DEX
 BEQ VSB6
 CLC
 LDA VMT2
 ADC VMSW
 STA VMT2
 BCC VSB5
 INC VMT2+1
 BRA VSB5
VSB6 LDX VMSO
 CLC
 LDA VMSUBD+DOFF,X
 ADC VMT2
 STA VMSUBD+DOFF,X
 LDA VMSUBD+DOFF+1,X
 ADC VMT2+1
 STA VMSUBD+DOFF+1,X
 JMP VMLOOP
VSBBAD LDA #<MSUBR
 LDX #>MSUBR
 JMP VMDIE

* ---- VADDR: VMD -> VMT1 = the item's address ----
VADDR CLC
 LDA VMD+DOFF
 ADC VMDP
 STA VMT1
 LDA VMD+DOFF+1
 ADC VMDP+1
 STA VMT1+1
 RTS

* ---- VOPS: fetch an item -> VMO1, VMD1 (source) -
VOPS JSR VFETW
 JSR VDESC
 JSR VADDR
 LDA VMT1
 STA VMO1
 LDA VMT1+1
 STA VMO1+1
 LDY #7
VOS1 LDA VMD,Y
 STA VMD1,Y
 DEY
 BPL VOS1
 RTS

* ---- VOPD: fetch an item -> VMO2, VMD2 (dest) ---
* VOPD2 is the same thing for an item number ALREADY
* in VMW.  The query opcodes need it: they pull
* every operand out of the stream first, in order,
* and resolve the item numbers afterwards - so the
* fetch and the resolve had to come apart.  One
* label, no duplicated code.
VOPD JSR VFETW
VOPD2 JSR VDESC
 JSR VADDR
 LDA VMT1
 STA VMO2
 LDA VMT1+1
 STA VMO2+1
 LDY #7
VOD1 LDA VMD,Y
 STA VMD2,Y
 DEY
 BPL VOD1
 RTS

* ---- VSETP: the library's two pointers ----------
* Zone S is caller-saved, so these are set fresh
* before every call rather than kept.  Zone P holds
* the real addresses and survives.
VSETP LDA VMO1
 STA ZPT1
 LDA VMO1+1
 STA ZPT1+1
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 RTS

* ---- VLIT: fetch a literal reference -> VMPT ----
VLIT JSR VFETW
 CLC
 LDA VMW
 ADC VMLP
 STA VMPT
 LDA VMW+1
 ADC VMLP+1
 STA VMPT+1
 RTS

