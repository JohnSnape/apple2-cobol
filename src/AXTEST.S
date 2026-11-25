* XC turns on the 65C02 opcodes.  SYSBOOT already
* REFUSES to boot without a 65C02 - CHK65 - so the
* machine is guaranteed to have one, and until now
* we were paying that compatibility cost and taking
* none of the benefit.  STZ is the one that earns
* its keep: LDA #0 followed by a run of STA becomes
* a run of STZ, two bytes shorter every time.
 XC
* AXTEST.S  how many auxiliary banks are real, and
* does select-then-AUXMOVE reach them?
* Standalone throwaway.  Assemble, BSAVE, BRUN.
*
* AUXMEM moves records by writing the bank number
* to $C073 and then calling the firmware's AUXMOVE.
* Harvey Brown's 1986 article says AUXMOVE "does
* not work with the extra banks of RAM available in
* cards such as the RAMWORKS" - plainly true of
* AUXMOVE by itself, which has no bank parameter,
* but not necessarily true once a bank is already
* selected.  Everything in AUXMEM rests on that
* distinction.
*
* Writes a bank's own number and its complement
* into the same address in all 128 possible banks,
* then reads them all back.  A bank that returns
* both bytes is real and reachable; anything else
* is aliasing or absent.
*
* WHY THE WRITE LOOP COUNTS DOWN
* On a machine with fewer than 128 banks the extra
* numbers alias onto real ones.  Writing upwards
* would leave every physical bank holding whatever
* the highest logical number that reached it wrote,
* and nothing would verify.  Counting down means
* the LAST write to each physical bank is the
* lowest number that maps to it - which, for the
* banks that really exist, is their own.  The
* published FindBanks routine counts down for
* exactly this reason.
*
* CAUTION: this scribbles on auxiliary memory at
* $2000 in every bank.  If /RAM is connected it
* lives there, so anything on the RAM disk is
* forfeit.  Delete /RAM first, or accept the loss.

 ORG $2000

* Every equate first.  An assembler reads forwards,
* so an equate placed where it reads best - beside
* the buffer it points at - cannot be assembled.
SPTR EQU $06
BANKSEL EQU $C073
AUXMOVE EQU $C311
CLR80S EQU $C000
COUT EQU $FDED
CROUT EQU $FD8E
HOME EQU $FC58
RDKEY EQU $FD0C
TARGET EQU $2000
MAXB EQU 128

START JSR HOME
 LDA #<MHDR
 STA SPTR
 LDA #>MHDR
 STA SPTR+1
 JSR PRSTR

* --- write, counting DOWN, to every bank ---
 LDA #MAXB-1
 STA BK
WR1 LDA BK
 STA BUF
 EOR #$FF
 STA BUF+1
 LDX #2
WR2 LDA BK
 STA BUF,X
 INX
 CPX #16
 BCC WR2
 JSR PUTBK
 DEC BK
 BPL WR1

* --- read every bank back and judge it ---
 LDA #0
 STA BK
RD1 LDX #0
 LDA #0
RD2 STA BUF,X
 INX
 CPX #16
 BCC RD2
 JSR GETBK
 LDA BUF
 CMP BK
 BNE RDBAD
 LDA BK
 EOR #$FF
 CMP BUF+1
 BNE RDBAD
 LDA #$AE
 JMP RDST
RDBAD LDA #$D8
RDST LDX BK
 STA RESULT,X
 INC BK
 LDA BK
 CMP #MAXB
 BCC RD1

* --- the grid: 32 banks to a row ---
 LDX #0
GR1 LDA RESULT,X
 JSR COUT
 INX
 TXA
 AND #31
 BNE GR2
 JSR CROUT
GR2 CPX #MAXB
 BCC GR1

* --- the count ---
 LDA #0
 STA CNT
 LDX #0
CN1 LDA RESULT,X
 CMP #$AE
 BNE CN2
 INC CNT
CN2 INX
 CPX #MAXB
 BCC CN1
 LDA #<MCNT
 STA SPTR
 LDA #>MCNT
 STA SPTR+1
 JSR PRSTR
 JSR PRDEC
 JSR CROUT
 LDA #<MFTR
 STA SPTR
 LDA #>MFTR
 STA SPTR+1
 JSR PRSTR
 JSR RDKEY
 RTS

* --- PUTBK: BUF -> bank BK at TARGET ---
* Carry SET is main to auxiliary.  It reads the
* wrong way round, and getting it backwards moves
* the right bytes the wrong way: a write silently
* destroys the destination instead of filling it.
PUTBK LDA BK
 STA BANKSEL
 LDA #<BUF
 STA $3C
 LDA #>BUF
 STA $3D
 LDA #<BUF+15
 STA $3E
 LDA #>BUF+15
 STA $3F
 LDA #<TARGET
 STA $42
 LDA #>TARGET
 STA $43
 STA CLR80S
 SEC
 JSR AUXMOVE
 LDA #0
 STA BANKSEL
 RTS

* --- GETBK: bank BK at TARGET -> BUF ---
* Carry CLEAR is auxiliary to main.
GETBK LDA BK
 STA BANKSEL
 LDA #<TARGET
 STA $3C
 LDA #>TARGET
 STA $3D
 LDA #<TARGET+15
 STA $3E
 LDA #>TARGET+15
 STA $3F
 LDA #<BUF
 STA $42
 LDA #>BUF
 STA $43
 STA CLR80S
 CLC
 JSR AUXMOVE
 LDA #0
 STA BANKSEL
 RTS

* --- PRDEC: CNT (0-128) in decimal ---
PRDEC LDA #0
 STA DH
 STA DT
 STA DANY
 LDA CNT
PD1 CMP #100
 BCC PD2
 SBC #100
 INC DH
 JMP PD1
PD2 CMP #10
 BCC PD3
 SBC #10
 INC DT
 JMP PD2
PD3 STA DU
 LDA DH
 BEQ PD5
 CLC
 ADC #$B0
 JSR COUT
 LDA #1
 STA DANY
PD5 LDA DT
 BNE PD6
 LDA DANY
 BEQ PD7
PD6 LDA DT
 CLC
 ADC #$B0
 JSR COUT
PD7 LDA DU
 CLC
 ADC #$B0
 JMP COUT

* --- PRSTR: SPTR -> $00-terminated ---
PRSTR LDY #0
PS1 LDA (SPTR),Y
 BEQ PSD
 ORA #$80
 JSR COUT
 INY
 BNE PS1
PSD RTS

BK DFB 0
CNT DFB 0
DH DFB 0
DT DFB 0
DU DFB 0
DANY DFB 0
BUF DS 16
RESULT DS MAXB

MHDR ASC 'AUXILIARY BANKS - . REAL, X NOT'
 DFB $8D,$8D,0
MCNT ASC 'BANKS REACHABLE: '
 DFB 0
MFTR DFB $8D
 ASC 'EACH BANK IS 64K.'
 DFB $8D,0
