* BANKS.S  RamWorks bank detection and page moves
* A library module (PUT it from LIB.S).
*
* A 128K IIe has one auxiliary bank.  A RamWorks or
* compatible card in the aux slot has up to 128 of
* them, selected by writing the bank number to
* $C073.  Bank $00 is the ordinary auxiliary 64K -
* the one the 80-column firmware paints from - so
* a plain IIe simply reports one bank and nothing
* above needs to know the difference.
*
* TWO MEMORY TESTS, OPPOSITE CONSTRAINTS
* CHK128 in COBOL.SYSTEM must run from $0100,
* because RAMRD/RAMWRT switch $0200-$BFFF and code
* anywhere in that range would bank itself out
* mid-test.  FINDBNK below must NOT run from
* $0100, because it switches ALTZP, which moves
* $0000-$01FF - including the stack.  Same hazard,
* opposite address.  FINDBNK runs from the library
* at $3000 and is safe there.
*
* Adapted from two published routines: the bank
* count from the FindBanks listing, and the page
* mover from Harvey Brown's RAMWORKS MOVE (1986).
* What changed and why is at the foot of the file.

* ================= BANK DETECTION ==============
* FINDBNK: how many 64K banks does the aux card
* have?
* out: NBANKS = count, BANKTBL = their numbers
*
* Write a bank number and its complement into each
* bank's zero page, then read them all back.  Only
* a bank that really exists gives both bytes back.
* The complement is the second check: without it a
* floating bus that happened to return the right
* byte would look like memory.
*
* This works because ALTZP moves ONLY $0000-$01FF.
* $00 and $01 become per-bank while everything
* else - this code, BANKTBL - stays in main memory
* untouched.
BKFIND STA ALTZPON
 LDY #$7F
FB1 STY BANKSEL
 STY $00
 TYA
 EOR #$FF
 STA $01
 DEY
 BPL FB1
* read them back
 LDX #0
 LDY #0
FB2 STY BANKSEL
 CPY $00
 BNE FB3
 TYA
 EOR #$FF
 CMP $01
 BNE FB3
 TYA
 STA BANKTBL,X
 INX
 CPX #MAXBNK
 BCS FB4
FB3 INY
 BPL FB2
FB4 LDA #0
 STA BANKSEL
 STA ALTZPOFF
 STX NBANKS
 RTS

* ================= PAGE MOVER =================
* The template comes FIRST in this file, before the
* routine that installs it.  BMLEN is its length,
* measured with EQU *-BMPAGE, and an assembler
* cannot use a location-counter equate it has not
* reached yet - so the installer has to come after
* the thing it measures.  The alternative is a
* hand-guessed constant that goes quietly wrong the
* first time the template grows.

* ---- the page-resident routine ----
* Copied to $0300, so it must use relative
* branches only - no absolute JMP to itself, or the
* copies would all jump back into this template.
*
* in:  A = page (high byte of the aux address)
*      X = bank number, or $FF for main memory
*      C=1 write $0200 -> bank
*      C=0 read  bank  -> $0200
* Always 256 bytes, always through $0200.  A fixed
* size and a fixed staging buffer are what keep
* this small enough to duplicate into every bank.
BMPAGE STX ZPT2
 STA ZPT1+1
 LDY #0
 STY ZPT1
 BCS BMPW
* --- read: bank -> main $0200 ---
* RAMRD goes to aux, RAMWRT stays on main, so one
* loop reads aux and writes main with no switching
* per byte.  Execution continues in the aux copy.
 LDA ZPT2
 CMP #$FF
 BEQ BMPR2
 STA BANKSEL
 STA AUXRD
BMPR2 LDY #0
BMPR3 LDA (ZPT1),Y
 STA BMBUF,Y
 INY
 BNE BMPR3
 BEQ BMPX
* --- write: main $0200 -> bank ---
* The mirror image: RAMWRT to aux, RAMRD left on
* main.  Note this path never leaves main memory
* for its instructions - only the read path
* actually needs the duplicated copies.
BMPW LDA ZPT2
 CMP #$FF
 BEQ BMPW2
 STA BANKSEL
 STA AUXWR
BMPW2 LDY #0
BMPW3 LDA BMBUF,Y
 STA (ZPT1),Y
 INY
 BNE BMPW3
* Bank 0 last, always: it is the bank the 80-column
* firmware paints the screen from, and leaving any
* other one selected turns the display to confetti.
BMPX LDA #0
 STA BANKSEL
 STA MAINRD
 STA MAINWR
 RTS
BMLEN EQU *-BMPAGE

* ---- BMINIT: install the mover at $0300 ---------
* In main memory and in every auxiliary bank.
*
* WHY IT HAS TO BE IN EVERY BANK
* Reading from an aux bank means turning RAMRD on,
* and RAMRD redirects instruction fetch as well as
* data.  The instruction after the switch is
* fetched from the bank we just selected.  If the
* routine is not sitting at the same address in
* that bank, the processor runs whatever is.
* So we put an identical copy in all of them, and
* the switch becomes invisible: execution carries
* on in a copy of the same code.
*
* Call FINDBNK first; this walks the table it
* built.
BKINIT LDY #0
BMI1 LDA BMPAGE,Y
 STA BMENTRY,Y
 INY
 CPY #BMLEN
 BCC BMI1
 LDX NBANKS
BMI2 DEX
 BMI BMI4
 LDA BANKTBL,X
 STA BANKSEL
 STA AUXWR
 LDY #0
BMI3 LDA BMENTRY,Y
 STA BMENTRY,Y
 INY
 CPY #BMLEN
 BCC BMI3
 STA MAINWR
 JMP BMI2
BMI4 LDA #0
 STA BANKSEL
 STA MAINWR
 RTS

* ================= WHAT CHANGED =================
* From the FindBanks listing:
*   - Dropped the TABLE/BANKTBL bit-packing.  It
*     computed AND #7 and then threw it away with
*     the next LDA, and its self-modifying INC of
*     the ORA operand had nothing to reset it.  The
*     two commented-out lines in that listing - one
*     TYA, one STA - are the version that works,
*     and are what is above.
*   - Capped at MAXBNK entries rather than 128.  A
*     COBOL system has no use for 8MB, and the
*     table has to live somewhere.
*
* From Harvey Brown's RAMWORKS MOVE:
*   - Removed SEL16K and both upper-16K paths.  We
*     never touch aux $D000-$FFFF, and EXIT's
*     LDA $C082 to restore the ROM would have
*     banked out the ProDOS MLI - fatal here, where
*     Brown's caller was running under Applesoft.
*   - Moved off $C00, which is our library.
*   - PTR moved from $00/$01, which belong to
*     ProDOS, to ZPT1 in zone S.  Zero page follows
*     ALTZP, not RAMRD, so it stays in main memory
*     throughout and the pointer survives the bank
*     switch.
*   - The bank list is built by FINDBNK at run time
*     instead of being assembled in.
*   - Absolute JMPs inside the page became branches
*     so the template can be copied without fixups.
