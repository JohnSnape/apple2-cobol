* VMCORE.S  interpreter entry, header check, VMDIE
* PUT from VM.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* ================= START =================
* The header is checked before anything else runs.
* An object that is not ours, or is a build for a
* language this interpreter does not implement,
* stops here rather than being executed as if it
* were code.
VMRUN TSX
 STX VMSTK
 STZ VMHLT
 STZ VMEXC
 STZ VMSZM
 STZ VMCC
 STZ VMRSP
 STZ VMESP
 LDA #$40
 STA VMCASE
 LDA #<OBJBASE
 STA VMPT
 LDA #>OBJBASE
 STA VMPT+1
 LDY #0
 LDA (VMPT),Y
 CMP #$50
 BNE VMSIG
 INY
 LDA (VMPT),Y
 CMP #$43
 BNE VMSIG
 INY
 LDA (VMPT),Y
 CMP #$42
 BNE VMSIG
 INY
 LDA (VMPT),Y
 CMP #$31
 BNE VMSIG
 LDY #4
 LDA (VMPT),Y
 CMP #1
 BNE VMSIG
 LDY #19
 LDA (VMPT),Y
 BNE VMLANG
 JSR VMSETU
* A program starts on a clear screen, top left - not
* wherever the menu's prompt left the cursor (BETA1
* printed its answer at column 56 of the "Program to
* run?" line, 2026-11-07).
 JSR CONCLR
 JSR VFINIT
* The edit engine keeps its currency sign, decimal
* point and comma in three bytes that PICINIT sets.
* Nothing in the VM called it, so every edited
* number printed $ as D and the point and comma as
* @, and ACCEPT 250.75 - not seeing a point - stored
* 25075 (LEADS, 2026-11-07).
 JSR PICINIT
 JMP VMLOOP
VMSIG LDA #<MSIG
 LDX #>MSIG
 JMP VMDIE
VMBIG LDA #<MBIG
 LDX #>MBIG
 JMP VMDIE
VMLANG LDA #<MLANG
 LDX #>MLANG
 JMP VMDIE

* ---- VMSETU: the register file from the header --
VMSETU LDY #9
 JSR VMHDRW
 JSR VMADDB
 LDA VMPT
 STA VMDT
 LDA VMPT+1
 STA VMDT+1
 LDY #11
 JSR VMHDRW
 JSR VMADDB
 LDA VMPT
 STA VMLP
 LDA VMPT+1
 STA VMLP+1
 LDY #13
 JSR VMHDRW
 JSR VMADDB
 LDA VMPT
 STA VMIP
 STA VMCB
 LDA VMPT+1
 STA VMIP+1
 STA VMCB+1
* The data segment sits immediately after the code,
* so its base is codeoff + codelen.  No header
* field for it: two numbers we already have say
* where it starts, and a third could disagree with
* them.
 LDY #13
 JSR VMHDRW
 LDA VMW
 STA VMT1
 LDA VMW+1
 STA VMT1+1
 LDY #17
 JSR VMHDRW
 CLC
 LDA VMW
 ADC VMT1
 STA VMW
 LDA VMW+1
 ADC VMT1+1
 STA VMW+1
 JSR VMADDB
 LDA VMPT
 STA VMDP
 LDA VMPT+1
 STA VMDP+1
* THE BACKSTOP.  Code and data must end at IOBUF,
* $B000, or WORKING-STORAGE lies on top of the file
* buffers.  The compiler refuses such a program
* (error 49) - this is for an object built before
* that check, or by anything else.  Header bytes
* 5-6 are the data segment's size.
 LDY #5
 JSR VMHDRW
 CLC
 LDA VMDP
 ADC VMW
 TAX
 LDA VMDP+1
 ADC VMW+1
 BCS VMBG2
 CMP #>IOBUF
 BCC VMFITS
 BNE VMBG2
 CPX #1
 BCC VMFITS
VMBG2 JMP VMBIG
VMFITS
* entry is a p-code offset from the code base, so
* it is added to IP after IP was set to the code
 LDY #15
 JSR VMHDRW
 CLC
 LDA VMIP
 ADC VMW
 STA VMIP
 LDA VMIP+1
 ADC VMW+1
 STA VMIP+1
 RTS

* VMHDRW: Y = header offset -> VMW
VMHDRW LDA #<OBJBASE
 STA VMPT
 LDA #>OBJBASE
 STA VMPT+1
 LDA (VMPT),Y
 STA VMW
 INY
 LDA (VMPT),Y
 STA VMW+1
 RTS

* VMADDB: VMPT = OBJBASE + VMW
VMADDB CLC
 LDA VMW
 ADC #<OBJBASE
 STA VMPT
 LDA VMW+1
 ADC #>OBJBASE
 STA VMPT+1
 RTS

