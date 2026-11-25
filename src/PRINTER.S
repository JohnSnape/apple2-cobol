* PRINTER.S  output to a printer card
* A library module (PUT it from LIB.S).
*
* The design is PRINTER.md.
*
* WE NEVER GAVE THE SCREEN TO THE FIRMWARE, SO THE
* PRINTER CANNOT TAKE IT.
* PR#n works by pointing CSW at the card and sending
* every COUT through it, which is why printing on
* this machine has always disturbed the display.
* TEXTDRV writes screen memory itself and never
* touches COUT or CSW after INIT80, so the card can
* be driven directly and there is nothing to save
* and restore.  That is a dividend from the page-2
* decision, which was made for a completely
* different reason.
*
* TWO PATHS, because the two kinds of card really
* are different and only one can be driven with
* certainty:
*   PRMODE 0  the Pascal 1.1 firmware entry.  Card
*             independent, and the default.  NOT YET
*             VERIFIED ON HARDWARE - see PRINTER.md
*   PRMODE 1  a Super Serial Card's 6551, polled and
*             written directly.  Serial only, and
*             the one we can be sure never reaches
*             the screen

* ================= THE THREE POINTERS ============
* PRROM, PRENT and PRACIA are read through as
* (pointer),Y - the card's ROM, its Pascal entry, its
* 6551 - and THERE IS NO (abs),Y ON THIS PROCESSOR.
* Declared with DS, as they were, every one of those
* five instructions is "Bad address mode": found on
* the first assembly of PRINTER.S, which had never
* been assembled into anything.
*   They belong in ZONE D, the service-private
* scratch, which MEMMAP.txt already lists the printer
* as a tenant of - and they take the TOP of it,
* $AA-$AF, so that the low end stays free for BCD and
* the record manager.  Zone D is not caller-saved and
* nothing else claims a byte of it in either tree, so
* a pointer set by PRTINI is still there when PRTPUT
* runs.
*   PRDMAX is up here for the same reason the record
* offsets are at the top of EQUATES: it is used in an
* immediate at PRTSEL below, and Merlin will not take
* a bare #SYMBOL it has not seen yet.
PRDMAX EQU 4
PRROM EQU ZPSVC+$1A
PRENT EQU ZPSVC+$1C
PRACIA EQU ZPSVC+$1E

* ---- PRTSEL: make device A the current one ------
* MORE THAN ONE PRINTER IS A TABLE, NOT A REWRITE.
* SPECIAL-NAMES gives each slot a mnemonic, the
* mnemonic is an index, and DISPP carries that index
* as a byte in the instruction - so a program with a
* report printer in slot 1 and a label printer in
* slot 2 costs one byte per DISPLAY and nothing
* else.  Four devices, which is three more than
* anybody has asked for.
PRTSEL CMP #PRDMAX
 BCC PRSL1
 RTS
PRSL1 STA PRDEV
 ASL
 ASL
 TAX
 LDA PRTAB,X
 STA PRSLOT
 LDA PRTAB+1,X
 STA PRMODE
 LDA PRTAB+2,X
 STA PRENT
 LDA PRTAB+3,X
 STA PRENT+1
 RTS

* ---- PRTSAV: write the current device back ------
PRTSAV LDA PRDEV
 ASL
 ASL
 TAX
 LDA PRSLOT
 STA PRTAB,X
 LDA PRMODE
 STA PRTAB+1,X
 LDA PRENT
 STA PRTAB+2,X
 LDA PRENT+1
 STA PRTAB+3,X
 RTS

* ---- PRTINI: PRSLOT -> the entry point ----------
* out: C=1 if there is no printer
* SLOT 0 means no printer and is not an error: a
* report printed to nowhere should run to the end,
* not hang, so that it can be tested on a machine
* with no card in it.
PRTINI LDA #0
 STA PRFOUND
 LDA PRSLOT
 BNE PRTI0
 SEC
 RTS
PRTI0 CMP #8
 BCC PRTI1
 SEC
 RTS
* $Cn00, where n is the slot
PRTI1 CLC
 ADC #$C0
 STA PRROM+1
 STZ PRROM
* the 6551 base for the direct path: $C088 + n0
 LDA PRSLOT
 ASL
 ASL
 ASL
 ASL
 CLC
 ADC #$88
 STA PRACIA
 LDA #$C0
 STA PRACIA+1
 LDA PRMODE
 BEQ PRI1
 LDA #1
 STA PRFOUND
 CLC
 RTS
* ---- the Pascal 1.1 signature -------------------
* Four bytes in the card's ROM.  When they are all
* there, $Cn0F holds the OFFSET of the card's
* character-output routine inside its own page - so
* the entry is $Cn00 plus that byte.
PRI1 LDY #5
 LDA (PRROM),Y
 CMP #$38
 BNE PRIOLD
 LDY #7
 LDA (PRROM),Y
 CMP #$18
 BNE PRIOLD
 LDY #11
 LDA (PRROM),Y
 CMP #$01
 BNE PRIOLD
 LDY #12
 LDA (PRROM),Y
 CMP #$31
 BNE PRIOLD
 LDY #15
 LDA (PRROM),Y
 CLC
 ADC PRROM
 STA PRENT
 LDA PRROM+1
 ADC #0
 STA PRENT+1
 LDA #1
 STA PRFOUND
 JSR PRTSAV
 CLC
 RTS
* ---- no signature: a parallel card, driven direct
* It called $Cn00 here, the old CSW-style entry -
* and that firmware ECHOES to the screen and turns
* the 80-column display off: printed text on row 0
* and every other column gone (AppleWin, 2026-11-08).
* A card without the Pascal signature is a parallel
* card, and a parallel card takes the byte at its
* data register, $C080 + slot*16 - so PRFOUND 2 now
* writes there, as PRPSER writes a 6551, and the
* firmware never runs.
PRIOLD LDA PRROM
 STA PRENT
 LDA PRROM+1
 STA PRENT+1
 LDA #2
 STA PRFOUND
 JSR PRTSAV
 CLC
 RTS

* ---- PRTPUT: one byte to the printer ------------
* THE HIGH BIT GOES ON.  Apple II printer interfaces
* expect ASCII with bit 7 set, the same as the
* screen, and a byte sent with it clear prints as
* nothing at all on most cards - a silent failure,
* and worth one ORA.
PRTPUT ORA #$80
 STA PRCH
 LDA PRFOUND
 BNE PRP1
 RTS
PRP1 CMP #2
 BEQ PRPPAR
 LDA PRMODE
 BNE PRPSER
* the firmware path.  X and Y carry the slot, which
* is the convention the protocol documents and the
* part most likely to need adjusting for a
* particular card - see PRINTER.md 8.
 LDA PRROM+1
 TAX
 LDA PRSLOT
 ASL
 ASL
 ASL
 ASL
 TAY
 LDA PRCH
 JMP (PRENT)
* ---- the 6551, polled -------------------------
* Bit 4 of the status register is "transmit register
* empty".  Wait for it, then write the data
* register.  No firmware, no CSW, and no way for
* this to reach the display.
PRPSER LDY #1
PRPS1 LDA (PRACIA),Y
 AND #$10
 BEQ PRPS1
 LDY #0
 LDA PRCH
 STA (PRACIA),Y
 RTS

* ---- the parallel data register --------------
* Seven-bit ASCII: there is no firmware to strip
* the high bit on the way out.
PRPPAR LDA PRSLOT
 ASL
 ASL
 ASL
 ASL
 TAX
 LDA PRCH
 AND #$7F
 STA $C080,X
 RTS

* ---- PRTSTR: a length-prefixed string -----------
PRTSTR LDY #0
 LDA (STRPTR),Y
 STA PRLEN
 BEQ PRSD
 LDA #1
 STA PRIX2
PRS1 LDY PRIX2
 LDA (STRPTR),Y
 JSR PRTPUT
 INC PRIX2
 LDA PRLEN
 CMP PRIX2
 BCS PRS1
PRSD RTS

* ---- PRTCR: end the line -------------------------
* $0D ONLY, and no line feed.  Every Apple II
* printer interface has a setting for whether it
* adds one, and sending a second is the classic
* double-spaced-report bug.  If a report comes out
* double spaced the card is adding line feeds and
* the card is where to turn them off.
PRTCR LDA #$0D
 JSR PRTPUT
* the direct parallel path has no firmware to add
* the line feed a card normally adds, so it is sent
 LDA PRFOUND
 CMP #2
 BNE PRTC1
 LDA #$0A
 JSR PRTPUT
PRTC1
 INC PRLINE
 BNE PRCRX
 INC PRLINE+1
PRCRX RTS

* ================= VARIABLES ===================
* PRDMAX, PRROM, PRENT and PRACIA are NOT here any
* more - see the note at the head of the file.
PRDEV DFB 0
PRTAB DS 16
PRCH DFB 0
PRLEN DFB 0
PRIX2 DFB 0
