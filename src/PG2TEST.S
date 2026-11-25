* XC turns on the 65C02 opcodes.  SYSBOOT already
* REFUSES to boot without a 65C02 - CHK65 - so the
* machine is guaranteed to have one, and until now
* we were paying that compatibility cost and taking
* none of the benefit.  STZ is the one that earns
* its keep: LDA #0 followed by a run of STA becomes
* a run of STZ, two bytes shorter every time.
 XC
* PG2TEST.S  does 80-column text page 2 work?
* Standalone throwaway - run this BEFORE we commit
* the new memory map.  Assemble, BSAVE, BRUN it.
* Writes one banner to page 1 ($0400) and another
* to page 2 ($0800), then flips between them each
* time you press a key.  ESC quits.
* If both banners read correctly in 80 columns,
* hardware page 2 is real and TEXTDRV is sound.
* NOTE: the firmware never supported this, so the
* text screen may look odd after you quit.  PR#3
* or a reboot puts it right.

 ORG $2000

* ---- soft switches ----
* $C000 reads as KBD, writes as 80STORE OFF.
KBD EQU $C000
CLR80S EQU $C000
MAINWR EQU $C004
AUXWR EQU $C005
KBDSTRB EQU $C010
SET80V EQU $C00D
ALTCHR EQU $C00F
TXTSET EQU $C051
MIXCLR EQU $C052
* with 80STORE OFF these are the DISPLAY page
* select again - which is the whole point.
PG1 EQU $C054
PG2 EQU $C055

* ---- zero page ----
PTR EQU $06
SRC EQU $08

* === START ===
START STA SET80V
 STA CLR80S
 STA ALTCHR
 STA TXTSET
 STA MIXCLR
 STA MAINWR
 LDA #$04
 JSR CLRPG
 LDA #$08
 JSR CLRPG

* --- banner on page 1, row 0 ---
 STZ PTR
 LDA #$04
 STA PTR+1
 LDA #<M1
 STA SRC
 LDA #>M1
 STA SRC+1
 LDA #M1E-M1
 STA LEN
 JSR PRSTR

* --- banner on page 2, row 0 ---
 STZ PTR
 LDA #$08
 STA PTR+1
 LDA #<M2
 STA SRC
 LDA #>M2
 STA SRC+1
 LDA #M2E-M2
 STA LEN
 JSR PRSTR

* --- flip on every key ---
 STA PG1
LOOP JSR KEY
 STA PG2
 JSR KEY
 STA PG1
 JMP LOOP

* --- KEY: wait a key; ESC exits ---
KEY LDA KBD
 BPL KEY
 BIT KBDSTRB
 AND #$7F
 CMP #$1B
 BEQ QUIT
 RTS
QUIT STA PG1
 STA $C001
 JMP $3D0

* --- CLRPG: A = page high byte ($04 or $08) ---
* blanks 1K in main and the same 1K in aux.
CLRPG STA PTR+1
 LDA #0
 STA PTR
 LDX #4
CP1 LDY #0
CP2 LDA #$A0
 STA (PTR),Y
 STA AUXWR
 STA (PTR),Y
 STA MAINWR
 INY
 BNE CP2
 INC PTR+1
 DEX
 BNE CP1
 RTS

* --- PRSTR: SRC -> text, LEN bytes, at PTR ---
* PTR = row base.  Even columns land in aux,
* odd columns in main; byte offset = column/2.
PRSTR LDA #0
 STA IDX
PS1 LDA IDX
 CMP LEN
 BCS PSD
 LDY IDX
 LDA (SRC),Y
 ORA #$80
 STA CH
 LDA IDX
 LSR
 TAY
 LDA CH
 BCS PSM
 STA AUXWR
 STA (PTR),Y
 STA MAINWR
 JMP PSN
PSM STA (PTR),Y
PSN INC IDX
 JMP PS1
PSD RTS

* --- variables ---
LEN DFB 0
IDX DFB 0
CH DFB 0

* --- banners ---
M1 ASC 'PAGE ONE - 80 COLUMNS - PRESS A KEY'
M1E EQU *
M2 ASC 'PAGE TWO - IF YOU CAN READ THIS IT WORKS'
M2E EQU *
