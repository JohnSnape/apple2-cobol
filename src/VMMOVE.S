* VMMOVE.S  control and move opcodes
* PUT from VM.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* ================= CONTROL =================
VNOP JMP VMLOOP

* 2, not 1: VMEND tells a program that finished
* (STOP RUN, which should wait so its output can be
* read) from one that faulted (VMDIE has already
* waited, and leaves 1).
VHALT LDA #2
 STA VMHLT
 JMP VMLOOP

* LINE: the compiler drops one of these at the head
* of each statement.  It costs three bytes and a
* store, and it is the difference between "SIZE
* ERROR" and "SIZE ERROR AT LINE 47".
VLINE JSR VFETW
 LDA VMW
 STA VMLINE
 LDA VMW+1
 STA VMLINE+1
 JMP VMLOOP

* ENTER: clear working storage.  VALUE clauses are
* instructions that follow, not an image in the
* file - which is why an object file has no data
* segment in it at all.
VENTER JSR VFETW
 LDA VMDP
 STA VMPT
 LDA VMDP+1
 STA VMPT+1
VEN1 LDA VMW
 ORA VMW+1
 BEQ VEN3
 LDY #0
 LDA #0
 STA (VMPT),Y
 INC VMPT
 BNE VEN2
 INC VMPT+1
VEN2 LDA VMW
 BNE VEN2A
 DEC VMW+1
VEN2A DEC VMW
 JMP VEN1
VEN3 JMP VMLOOP

* ================= MOVES =================
* MOVA: alphanumeric, space filled and truncated
VMOVA JSR VOPD
 JSR VOPS
 JSR VSETP
 LDA VMD1+DLEN
 STA ALEN
 LDA VMD2+DLEN
 STA BLEN
 JSR MOVALP
 JMP VMLOOP

* MOVN: numeric to numeric, aligned by scale.
* The compiler used to have to emit a shift here.
* It does not any more: both scales are in the
* descriptors and this is the only place that needs
* to know.
VMOVN JSR VOPD
 JSR VOPS
 JSR VSETP
 JSR BCDMOV
 JSR VALIGN
 JMP VMLOOP

* MOVE: the edited move - a number becoming
* something a person reads
VMOVE JSR VOPD
 JSR VOPS
 JSR VEDIT
 JMP VMLOOP

* VEDIT: source VMO1 (numeric) -> dest VMO2, using
* the destination's edit picture
VEDIT LDA VMO1
 STA ZPT1
 LDA VMO1+1
 STA ZPT1+1
 LDA VMD2+DEDT
 ORA VMD2+DEDT+1
 BNE VED1
 JSR VDEFP
 JMP VED2
VED1 CLC
 LDA VMD2+DEDT
 ADC VMLP
 STA ZPT2
 LDA VMD2+DEDT+1
 ADC VMLP+1
 STA ZPT2+1
VED2 LDA VMD1+DDEC
 STA PICSCL
 LDA VMD2+DFLG
 LSR
 LSR
 AND #1
 STA PICFLG
 JSR PICEDIT
* PICBUF now holds the characters; the destination
* takes as many as it has room for, space filled
 LDA #<PICBUF
 STA ZPT1
 LDA #>PICBUF
 STA ZPT1+1
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDA PICLEN
 STA ALEN
 LDA VMD2+DLEN
 STA BLEN
 JMP MOVALP

* VDEFP: a picture for a numeric item that has
* none.  DISPLAY of a raw number still has to print
* something sensible, so we build one: nines to the
* left of the point, nines to the right, as many as
* the item's scale says.
* How many nines go left of the point: the integer
* digit count the compiler left in the top four bits
* of the flags (PIC 9(6) -> six), or, if none was
* recorded, everything the scale leaves of NDIG.
VDEFP LDA #0
 STA VMT2
 LDA VMD1+DFLG
 LSR
 LSR
 LSR
 LSR
 BNE VDP0
 SEC
 LDA #NDIG
 SBC VMD1+DDEC
VDP0 STA VMT2+1
VDP1 LDA VMT2
 CMP VMT2+1
 BCS VDP2
 LDX VMT2
 LDA #$39
 STA PICWRK+1,X
 INC VMT2
 JMP VDP1
VDP2 LDA VMD1+DDEC
 BEQ VDP4
 LDX VMT2
 LDA #$2E
 STA PICWRK+1,X
 INC VMT2
 LDA #0
 STA VMT2+1
VDP3 LDA VMT2+1
 CMP VMD1+DDEC
 BCS VDP4
 LDX VMT2
 LDA #$39
 STA PICWRK+1,X
 INC VMT2
 INC VMT2+1
 JMP VDP3
VDP4 LDA VMT2
 STA PICWRK
 LDA #<PICWRK
 STA ZPT2
 LDA #>PICWRK
 STA ZPT2+1
 RTS

* MOVG: a group move is bytes, nothing else - no
* editing, no padding, no opinion about what is in
* them
* A group move is an alphanumeric move: what is
* left over is SPACE FILLED.  It copied the shorter
* length and left the rest as it was (FIXLIST A17).
VMOVG JMP VMOVA

* MOVD: text into a number - de-edited, the way
* ACCEPT reads what was typed: digits, a point, a
* minus.  MOVE of a PIC X item to a numeric item
* copied the letters into the cell (FIXLIST A17).
* At most 20 characters, trailing spaces dropped.
VMOVD JSR VOPD
 JSR VOPS
 LDA VMO1
 STA ZPT1
 LDA VMO1+1
 STA ZPT1+1
 LDY #0
VMDD1 CPY VMD1+DLEN
 BCS VMDD2
 CPY #20
 BCS VMDD2
 LDA (ZPT1),Y
 STA VMTXT,Y
 INY
 BNE VMDD1
VMDD2 TYA
 BEQ VMDD3
 LDA VMTXT-1,Y
 CMP #$20
 BNE VMDD3
 DEY
 JMP VMDD2
VMDD3 STY VMTLEN
 LDA #<VMTLEN
 STA ZPT1
 LDA #>VMTLEN
 STA ZPT1+1
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDA VMD2+DDEC
 STA PICSCL
 JSR PICDEED
 JMP VMLOOP

* MOVL: a literal into an item.  The destination's
* type decides how to read the pool - a numeric
* literal was turned into a cell by the compiler,
* so it is eight raw bytes; anything else is
* length-prefixed text.
VMOVL JSR VOPD
 JSR VLIT
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDA VMD2+DTYPE
 CMP #TNUM
 BEQ VML0
 CMP #TEDIT
 BNE VML2
* A NUMBER into an edited item is edited, exactly as
* MOVE of a numeric item is.  It went in as text, so
* MOVE 42 TO a ZZZ9 field left it blank.
 JSR VMLSC
 LDA VMPT
 STA VMO1
 LDA VMPT+1
 STA VMO1+1
 JSR VEDIT
 JMP VMLOOP
* A number into a number: the cell, then shifted
* from the LITERAL'S scale - the byte after the cell
* - to the item's.  It was copied raw, so MOVE 250.75
* TO a V99 item held 2.50 (2026-11-07).
VML0 LDY #NCELL-1
VML1 LDA (VMPT),Y
 STA (ZPT2),Y
 DEY
 BPL VML1
 JSR VMLSC
 JSR VALIGN
 JMP VMLOOP
* VMLSC: VMD1+DDEC = the literal's own scale
VMLSC LDY #NCELL
 LDA (VMPT),Y
 STA VMD1+DDEC
 RTS
VML2 LDA VMPT
 STA ZPT1
 LDA VMPT+1
 STA ZPT1+1
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDY #0
 LDA (ZPT1),Y
 STA ALEN
 INC ZPT1
 BNE VML3
 INC ZPT1+1
VML3 LDA VMD2+DLEN
 STA BLEN
 JSR MOVALP
 JMP VMLOOP

* MOVF: a figurative constant
* 0 SPACE  1 ZERO  2 HIGH-VALUE  3 LOW-VALUE
* 4 QUOTE
VMOVF JSR VOPD
 JSR VFETCH
 STA VMT2
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDA VMD2+DTYPE
 CMP #TNUM
 BNE VMF1
 LDA VMT2
 CMP #1
 BNE VMF1
 JSR BCDZRO
 JMP VMLOOP
VMF1 LDX VMT2
 LDA VFIGT,X
 STA FILLC
 LDA VMD2+DLEN
 STA BLEN
 JSR FILLCH
 JMP VMLOOP

* INIT: numerics to zero, everything else to spaces
VINIT JSR VOPD
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDA VMD2+DTYPE
 CMP #TNUM
 BNE VIN1
 JSR BCDZRO
 JMP VMLOOP
VIN1 LDA #$20
 STA FILLC
 LDA VMD2+DLEN
 STA BLEN
 JSR FILLCH
 JMP VMLOOP

