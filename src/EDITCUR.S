* EDITCUR.S  EDIT cursor and key input
* PUT from EDIT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* EDIT resolve against each other in pass two.
*
* ================= THE CURSOR =================
CURPOS SEC
 LDA CURLIN
 SBC TOPLIN
 CLC
 ADC #TOPROW
 STA SCRROW
 LDX SCRROW
 JSR SCRADDR
 LDA CURCOL
 STA CCOL
 RTS

* Insert mode is an underline, overwrite an inverse
* block.  The shape IS the mode indicator - there
* is no word on the screen saying which one you are
* in, because the cursor is already saying it.
SHOWCUR JSR CURPOS
 STZ SCRATR
 LDA MODE
 BEQ SCINS
 LDY CURCOL
 LDA (EDPTR),Y
 LDX #1
 STX SCRATR
 JSR CONV
 JMP PUTAT
SCINS LDA #$5F
 JSR CONV
 JMP PUTAT

HIDECUR JSR CURPOS
 LDA #0
 STA SCRATR
 LDY CURCOL
 LDA (EDPTR),Y
 JSR CONV
 JMP PUTAT

* ---- EKEY: blink, wait, read the modifiers ------
* The blink loop carries RNDSEED, as the monitor's
* KEYIN carried RNDL/RNDH.
EKEY LDA #0
 STA BLINK
EK1 LDA BLINK
 AND #1
 BEQ EKON
 JSR HIDECUR
 JMP EK2
EKON JSR SHOWCUR
EK2 LDX #$40
EK2A LDY #0
EK3 LDA KBD
 BMI EKSAW
 INC RNDSEED
 BNE EK4
 INC RNDSEED+1
 BNE EK4
 INC RNDSEED+2
 BNE EK4
 INC RNDSEED+3
EK4 INY
 BNE EK3
 DEX
 BNE EK2A
 INC BLINK
 JMP EK1
* Straight off the BMI, before anything else at
* all: this is the only moment at which the Apple
* keys are still certain to be down.
EKSAW JSR READMOD
 JMP EKGOT
* The key is saved BEFORE the cursor is hidden:
* HIDECUR returns the character underneath it, and
* taking that as the keystroke is a bug this
* editor has already had once.
* The Apple keys are read by READMOD, in the
* library, which the blink loop above has already
* called at the instant it saw the key.  Reading
* them here - after HIDECUR - was a window: the key
* waits in the latch but the Apple keys are paddle
* buttons and report only what is held NOW.
EKGOT AND #$7F
 STA CHKEY
 JSR HIDECUR
 LDA KEYMOD
 STA CHMOD
 BIT KBDSTRB
 RTS

