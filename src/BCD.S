* BCD.S  NUM8 decimal arithmetic + COBOL runtime
* A library module (PUT it from LIB.S).
*
* THE CELL
* Every COBOL numeric variable is one NUM8 cell -
* eight bytes, whatever its PICTURE says:
*   +0      flags: sign, uninitialised, overflow,
*           invalid
*   +1..+7  packed BCD, 14 digits, most
*           significant first
* Scale is not stored.  The compiler knows every
* PICTURE and emits BCDSHL/BCDSHR to line decimal
* points up before calling in here.
*
* WHY ONE SIZE
* One ADD routine, one COMPARE, one MULTIPLY.  No
* length parameter, no short-versus-long cases, no
* alignment inside the arithmetic.  A hundred
* numeric variables cost 800 bytes and buy back
* far more than that in runtime and interpreter
* that never has to exist.
*
* WHY THE SIGN MOVED OUT OF THE DIGITS
* COMP-3 puts the sign in the low nibble of the
* last byte, which means a field cannot be added
* as it stands - the sign would be treated as a
* digit, and every routine has to mask it away and
* put it back.  Give the sign its own byte and all
* of that disappears: the magnitude is nothing but
* digits, so ADD is seven bytes of ADC in decimal
* mode with no preparation at all.  The flag byte
* also has room for something COMP-3 could never
* hold - a bit saying this field was never
* assigned, which is the difference between a
* debugger that can say NUMERIC OVERFLOW IN
* CALCULATE-GROSS and one that can only shrug.
*
* WHY MULTIPLY AND DIVIDE LOOK DIFFERENT
* Decimal mode helps ADC and SBC and nothing else,
* and this processor has no multiply in any base.
* Both unpack to one digit per byte and do long
* multiplication and long division the way you
* would on paper.
*
* CALLING CONVENTION
*   ZPT1 -> operand A (source; never modified)
*   ZPT2 -> operand B (accumulator; the result)
* B = B op A, matching COBOL's ADD A TO B.
* No length: every cell is NCELL bytes.
*
* Zone S only, through ZPT1/ZPT2.  Never zone P -
* the interpreter keeps IP/SP/FP live across every
* one of these calls.

* ================= SIGN AND FLAGS ==============
* A sign is 0 or $80, so it tests with BMI and
* flips with EOR.

* ---- NGSA / NGSB: -> A = sign of an operand ----
NGSA LDY #0
 LDA (ZPT1),Y
 AND #FNEG
 RTS
NGSB LDY #0
 LDA (ZPT2),Y
 AND #FNEG
 RTS

* ---- NSSB: A = sign -> store into B ----
* Also clears UNINITIALISED: a cell that has just
* been computed into has, by definition, a value.
NSSB STA NTMP
 LDY #0
 LDA (ZPT2),Y
 AND #$3F
 ORA NTMP
 STA (ZPT2),Y
 RTS

* ---- NSOVFL: raise OVERFLOW on B ----
NSOVFL LDY #0
 LDA (ZPT2),Y
 ORA #FOVFL
 STA (ZPT2),Y
 RTS

* ---- NCKUN: was either operand ever set? ----
* Costs twenty cycles on every arithmetic call and
* is the whole reason the flag byte exists.  A
* COBOL program that adds a field it never
* initialised is a bug, and this is where it stops
* being invisible.
NCKUN LDY #0
 LDA (ZPT1),Y
 ORA (ZPT2),Y
 AND #FUNIN
 BEQ NCKD
 LDA #3
 STA BCDERR
NCKD RTS

* ================= MAGNITUDE OPS ===============
* The only three places SED appears.  No masking,
* no saved bytes, no preparation - byte 0 is flags
* and bytes 1-7 are digits, so the loop simply
* stops before it reaches the flags.

* ---- NMADD: |B| = |B| + |A|.  C=1 overflowed ----
NMADD CLC
 SED
 LDY #NLSB
NMA1 LDA (ZPT2),Y
 ADC (ZPT1),Y
 STA (ZPT2),Y
 DEY
 BNE NMA1
 CLD
 RTS

* ---- NMSUB: |B| = |B| - |A|  (needs |B|>=|A|) ---
NMSUB SEC
 SED
 LDY #NLSB
NMS1 LDA (ZPT2),Y
 SBC (ZPT1),Y
 STA (ZPT2),Y
 DEY
 BNE NMS1
 CLD
 RTS

* ---- NMRSUB: |B| = |A| - |B|  (needs |A|>=|B|) --
* The same loop with the operands read the other
* way round, which saves swapping them.
NMRSUB SEC
 SED
 LDY #NLSB
NMR1 LDA (ZPT1),Y
 SBC (ZPT2),Y
 STA (ZPT2),Y
 DEY
 BNE NMR1
 CLD
 RTS

* ---- NMCMP: compare |B| with |A| ----
* out: BCMPR = 0 equal, 1 if |B|>|A|, $FF if less.
* Most significant byte first, so the first
* difference decides it.
NMCMP LDY #NMSB
NMC1 LDA (ZPT2),Y
 CMP (ZPT1),Y
 BNE NMC2
 INY
 CPY #NCELL
 BCC NMC1
 LDA #0
 STA BCMPR
 RTS
NMC2 BCS NMC3
 LDA #$FF
 STA BCMPR
 RTS
NMC3 LDA #1
 STA BCMPR
 RTS

* ================= ADD AND SUBTRACT ============

* ---- BADD: B = B + A  (vector BCDADD) ----
BADD JSR NGSA
 STA NSA
 JSR NGSB
 STA NSB
 JMP NADD2

* ---- BSUB: B = B - A  (vector BCDSUB) ----
* Subtracting is adding with A's sign flipped, and
* we flip the sign we READ - A belongs to the
* caller and is never touched.
BSUB JSR NGSA
 EOR #FNEG
 STA NSA
 JSR NGSB
 STA NSB

* --- the common core ---
* Like signs: add the magnitudes, keep the sign.
* Unlike: subtract the smaller from the larger and
* take the sign of the larger.  Exactly the rules
* you were taught for doing it on paper.
NADD2 LDA #0
 STA BCDERR
 JSR NCKUN
 LDA NSA
 CMP NSB
 BNE NADIF
 JSR NMADD
 BCC NAD1
 LDA #1
 STA BCDERR
 JSR NSOVFL
NAD1 LDA NSB
 JMP NSSB
NADIF JSR NMCMP
 LDA BCMPR
 BEQ NAZERO
 BMI NALT
 JSR NMSUB
 LDA NSB
 JMP NSSB
NALT JSR NMRSUB
 LDA NSA
 JMP NSSB
* Equal magnitudes, opposite signs.  The answer is
* zero, and COBOL wants a positive zero rather than
* minus nothing.
NAZERO JMP BZERO

* ================= COMPARE AND TEST ============

* ---- BCMP: compare B with A  (vector BCDCMP) ----
* out: BCMPR = 0 equal, 1 if B>A, $FF if B<A
BCMP JSR NGSA
 STA NSA
 JSR NGSB
 STA NSB
 LDA NSA
 CMP NSB
 BEQ NCSAME
* different signs: the positive one is the greater
 LDA NSB
 BNE NCNEG
 LDA #1
 STA BCMPR
 RTS
NCNEG LDA #$FF
 STA BCMPR
 RTS
* same sign: magnitude decides, but if both are
* negative the answer is the other way about
NCSAME JSR NMCMP
 LDA NSB
 BEQ NCD
 LDA BCMPR
 BEQ NCD
 EOR #$FE
 STA BCMPR
NCD RTS

* ---- BTEST: test B  (vector BCDTST) ----
* out: BCMPR = 0 zero, 1 positive, $FF negative
BTEST LDA #0
 STA NTMP
 LDY #NMSB
BT1 LDA (ZPT2),Y
 ORA NTMP
 STA NTMP
 INY
 CPY #NCELL
 BCC BT1
 LDA NTMP
 BNE BT2
 LDA #0
 STA BCMPR
 RTS
BT2 JSR NGSB
 BEQ BT3
 LDA #$FF
 STA BCMPR
 RTS
BT3 LDA #1
 STA BCMPR
 RTS

* ================= MOVE, ZERO, NEGATE ==========

* ---- BZERO: B = 0  (vector BCDZRO) ----
* Clears the flags too, so the result is a positive,
* initialised, unflagged zero.
BZERO LDY #NCELL-1
 LDA #0
BZ1 STA (ZPT2),Y
 DEY
 BPL BZ1
 RTS

* ---- BMOVE: B = A  (vector BCDMOV) ----
* Flags travel with the value, which is what you
* want: moving an uninitialised field does not
* quietly make it initialised.
BMOVE LDY #NCELL-1
BM1 LDA (ZPT1),Y
 STA (ZPT2),Y
 DEY
 BPL BM1
 RTS

* ---- BNEG: B = -B  (vector BCDNEG) ----
* Zero stays positive.  COBOL has no negative zero.
BNEG JSR BTEST
 LDA BCMPR
 BEQ BNGD
 JSR NGSB
 EOR #FNEG
 JMP NSSB
BNGD RTS

* ================= DIGIT ACCESS ================
* Digits are numbered 0 to 13 from the most
* significant.  Digit i is in byte 1 + i/2 - the
* high nibble when i is even, the low when odd.
* Slower than twiddling nibbles in place, and much
* easier to read, which for the shifts is the
* right trade.

* ---- NGETD: X = digit index -> A = digit ----
NGETD STX NDX
 TXA
 LSR
 CLC
 ADC #NMSB
 TAY
 LDA (ZPT2),Y
 STA NDT
 LDA NDX
 AND #1
 BNE NGD1
 LDA NDT
 LSR
 LSR
 LSR
 LSR
 RTS
NGD1 LDA NDT
 AND #$0F
 RTS

* ---- NPUTD: X = digit index, A = digit ----
NPUTD STA NDV
 STX NDX
 TXA
 LSR
 CLC
 ADC #NMSB
 TAY
 LDA NDX
 AND #1
 BNE NPD1
 LDA (ZPT2),Y
 AND #$0F
 STA NDT
 LDA NDV
 ASL
 ASL
 ASL
 ASL
 ORA NDT
 STA (ZPT2),Y
 RTS
NPD1 LDA (ZPT2),Y
 AND #$F0
 ORA NDV
 STA (ZPT2),Y
 RTS

* ================= DIGIT SHIFTS ================
* BCDDIG says how many digits to move.  These are
* how the compiler aligns decimal points: a field
* with two decimal places added to one with three
* is shifted first, then added.

* ---- BSHR: B = B / 10^BCDDIG  (vector BCDSHR) ---
* Each digit moves BCDDIG places toward the least
* significant end - toward the HIGHER index - so
* the loop runs backwards.  Truncating; BROUND is
* the version that rounds.
BSHR LDA BCDDIG
 BEQ BSRD
 CMP #NDIG
 BCS BSRZ
 LDA #NDIG-1
 STA NSI
BSR1 LDA NSI
 CMP BCDDIG
 BCC BSR2
 SEC
 SBC BCDDIG
 TAX
 JSR NGETD
 STA NDSAV
 LDX NSI
 LDA NDSAV
 JSR NPUTD
 DEC NSI
 JMP BSR1
BSR2 LDA NSI
 BMI BSRD
 LDX NSI
 LDA #0
 JSR NPUTD
 DEC NSI
 JMP BSR2
BSRD RTS
BSRZ JMP BZERO

* ---- BSHL: B = B * 10^BCDDIG  (vector BCDSHL) ---
* Digits pushed off the top are an overflow, so we
* look before we shift.
BSHL LDA BCDDIG
 BEQ BSLD
 CMP #NDIG
 BCS BSLZ
 LDA #0
 STA NSI
BSLC LDA NSI
 CMP BCDDIG
 BCS BSLG
 LDX NSI
 JSR NGETD
 BEQ BSLCN
 JSR NSOVFL
 LDA #1
 STA BCDERR
BSLCN INC NSI
 JMP BSLC
BSLG LDA #0
 STA NSI
BSL1 CLC
 LDA NSI
 ADC BCDDIG
 CMP #NDIG
 BCS BSL2
 TAX
 JSR NGETD
 STA NDSAV
 LDX NSI
 LDA NDSAV
 JSR NPUTD
 INC NSI
 JMP BSL1
BSL2 LDA NSI
 CMP #NDIG
 BCS BSLD
 LDX NSI
 LDA #0
 JSR NPUTD
 INC NSI
 JMP BSL2
BSLD RTS
BSLZ JMP BZERO

* ---- BROUND: drop BCDDIG digits, rounded --------
* COBOL ROUNDED: look at the most significant digit
* about to be thrown away, and if it is five or
* more add one to what survives.  Half-up, away
* from zero - which is what a ledger expects, and
* what the standard says.  Adding to the MAGNITUDE
* is what makes it away from zero for both signs.
BROUND LDA BCDDIG
 BEQ BRDD
 LDA #NDIG
 SEC
 SBC BCDDIG
 TAX
 JSR NGETD
 CMP #5
 PHP
 JSR BSHR
 PLP
 BCC BRDD
 LDA #<NONEC
 STA ZPT1
 LDA #>NONEC
 STA ZPT1+1
 JSR NMADD
BRDD RTS

* the constant 1, as a NUM8 cell
NONEC DFB 0,0,0,0,0,0,0,$01

* ================= UNPACK AND PACK =============
* One digit per byte, no sign.  Multiply and divide
* live in this world, because decimal mode is no
* help to either of them.

* ---- NUNPA: operand A -> DA ----
NUNPA LDA #0
 STA NSI
NUA1 LDA NSI
 CMP #NDIG
 BCS NUAD
 LSR
 CLC
 ADC #NMSB
 TAY
 LDA (ZPT1),Y
 STA NDT
 LDA NSI
 AND #1
 BNE NUA2
 LDA NDT
 LSR
 LSR
 LSR
 LSR
 JMP NUA3
NUA2 LDA NDT
 AND #$0F
NUA3 LDY NSI
 STA DA,Y
 INC NSI
 JMP NUA1
NUAD RTS

* ---- NUNPB: operand B -> DB ----
NUNPB LDA #0
 STA NSI
NUB1 LDA NSI
 CMP #NDIG
 BCS NUBD
 LSR
 CLC
 ADC #NMSB
 TAY
 LDA (ZPT2),Y
 STA NDT
 LDA NSI
 AND #1
 BNE NUB2
 LDA NDT
 LSR
 LSR
 LSR
 LSR
 JMP NUB3
NUB2 LDA NDT
 AND #$0F
NUB3 LDY NSI
 STA DB,Y
 INC NSI
 JMP NUB1
NUBD RTS

* ---- NPKP: the low NDIG digits of DP -> B ----
* DP holds up to 28 digits; only the least
* significant 14 fit.  Anything above them is
* COBOL's ON SIZE ERROR.
NPKP LDA #0
 STA NSI
NPK1 LDA NSI
 CMP #NDIG
 BCS NPK2
 LDY NSI
 LDA DP,Y
 BEQ NPKN
 LDA #1
 STA BCDERR
 JSR NSOVFL
NPKN INC NSI
 JMP NPK1
NPK2 LDA #0
 STA NSI
NPK3 LDA NSI
 CMP #NDIG
 BCS NPKD
 CLC
 LDA NSI
 ADC #NDIG
 TAY
 LDA DP,Y
 STA NDSAV
 LDX NSI
 LDA NDSAV
 JSR NPUTD
 INC NSI
 JMP NPK3
NPKD RTS

* ================= MULTIPLY ====================
* Long multiplication: every digit of one number
* against every digit of the other, carrying as we
* go.  A digit product never exceeds 9*9+9+9 = 99,
* so the carry is a single digit and folding it out
* is a divide by ten done by counting.

* ---- BMUL: B = B * A  (vector BCDMUL) ----
BMUL LDA #0
 STA BCDERR
 JSR NCKUN
 JSR NGSA
 STA NSA
 JSR NGSB
 STA NSB
 JSR NUNPA
 JSR NUNPB
 LDY #0
 LDA #0
NMU0 STA DP,Y
 INY
 CPY #NDIG*2
 BCC NMU0
 LDA #NDIG-1
 STA NMI
NMU1 LDA NMI
* The whole inner loop sits between here and the
* exit, which is far beyond a branch's reach, so
* the test is inverted and the exit is a jump.
 BPL NMU1A
 JMP NMU9
NMU1A LDA #NDIG-1
 STA NMJ
 LDA #0
 STA NMCY
NMU2 LDA NMJ
 BMI NMU8
 CLC
 LDA NMI
 ADC NMJ
 ADC #1
 TAX
 LDA DP,X
 STA NMACC
 LDY NMJ
 LDA DA,Y
 STA NMK
 LDY NMI
 LDA DB,Y
 STA NMD
 LDA #0
 STA NMPRD
NMU3 LDA NMK
 BEQ NMU4
 CLC
 LDA NMPRD
 ADC NMD
 STA NMPRD
 DEC NMK
 JMP NMU3
NMU4 CLC
 LDA NMPRD
 ADC NMACC
 ADC NMCY
 STA NMPRD
 LDA #0
 STA NMCY
NMU5 LDA NMPRD
 CMP #10
 BCC NMU6
 SEC
 SBC #10
 STA NMPRD
 INC NMCY
 JMP NMU5
NMU6 CLC
 LDA NMI
 ADC NMJ
 ADC #1
 TAX
 LDA NMPRD
 STA DP,X
 DEC NMJ
 JMP NMU2
* the last carry lands one place further left
NMU8 LDA NMCY
 BEQ NMU8B
 LDX NMI
 CLC
 LDA DP,X
 ADC NMCY
 STA DP,X
NMU8B DEC NMI
 JMP NMU1
NMU9 JSR NPKP
* signs multiply: like signs positive, unlike
* negative, which EOR says exactly
 LDA NSA
 EOR NSB
 PHA
 JSR BTEST
 LDA BCMPR
 BNE NMU10
 PLA
 LDA #0
 JMP NSSB
NMU10 PLA
 JMP NSSB

* ================= DIVIDE ======================
* Long division, also as on paper: bring a digit
* down, see how many times the divisor goes in by
* subtracting until it will not, write the count.

* ---- BDIV: B = B / A  (vector BCDDIV) ----
* Remainder in BCDREM.  Division by zero leaves B
* alone and sets BCDERR = 2; ON SIZE ERROR covers
* it in the source.
BDIV LDA #0
 STA BCDERR
 JSR NCKUN
 JSR NGSA
 STA NSA
 JSR NGSB
 STA NSB
 JSR NDVZ
 BCC NDV0
 LDA #2
 STA BCDERR
 RTS
NDV0 JSR NUNPA
 JSR NUNPB
 LDY #0
 LDA #0
NDV1 STA DP,Y
 STA DR,Y
 INY
 CPY #NDIG*2
 BCC NDV1
 LDA #0
 STA NMI
NDV2 LDA NMI
 CMP #NDIG
 BCS NDV9
 JSR NDRSHL
 LDY NMI
 LDA DB,Y
 LDX #NDIG
 STA DR,X
 LDA #0
 STA NMK
NDV3 JSR NDRCMP
 BCC NDV4
 JSR NDRSUB
 INC NMK
 JMP NDV3
NDV4 LDY NMI
 LDA NMK
 STA DP,Y
 INC NMI
 JMP NDV2
* the quotient is already the right width, so it
* packs from digit 0 rather than from the middle
NDV9 JSR NDQPK
 JSR NDRPK
 LDA NSA
 EOR NSB
 PHA
 JSR BTEST
 LDA BCMPR
 BNE NDV10
 PLA
 LDA #0
 JMP NSSB
NDV10 PLA
 JMP NSSB

* NDVZ: C=1 if operand A is zero
NDVZ LDA #0
 STA NTMP
 LDY #NMSB
NDZ1 LDA (ZPT1),Y
 ORA NTMP
 STA NTMP
 INY
 CPY #NCELL
 BCC NDZ1
 LDA NTMP
 BNE NDZ2
 SEC
 RTS
NDZ2 CLC
 RTS

* THE REMAINDER IS ONE DIGIT WIDER THAN EVERYTHING
* ELSE.  After each step the remainder is smaller
* than the divisor, so with a 14-digit divisor it
* can itself be 14 digits - and then multiplying by
* ten to bring the next digit down needs a
* fifteenth.  Keep DR at NDIG+1 digits, indices 0
* through 14, and treat the divisor as though it
* had a leading zero at DR's index 0.  Without the
* extra digit, dividing by a full-width number
* silently loses the top of the remainder, which is
* the kind of bug that only shows up in the one
* case nobody tests.

* NDRSHL: remainder = remainder * 10
NDRSHL LDY #0
NDRS1 INY
 CPY #NDIG+1
 BCS NDRS2
 LDA DR,Y
 DEY
 STA DR,Y
 INY
 JMP NDRS1
NDRS2 LDY #NDIG
 LDA #0
 STA DR,Y
 RTS

* NDRCMP: C=1 if remainder >= divisor
* DR[0] is the extra digit; if it is set at all the
* remainder is bigger and no comparison is needed.
NDRCMP LDA DR
 BNE NDRCY
 LDY #0
NDRC1 LDA DR+1,Y
 CMP DA,Y
 BNE NDRC2
 INY
 CPY #NDIG
 BCC NDRC1
 SEC
 RTS
NDRC2 RTS
NDRCY SEC
 RTS

* NDRSUB: remainder = remainder - divisor
* The borrow out of the top digit lands in DR[0].
NDRSUB LDY #NDIG-1
 LDA #0
 STA NMCY
NDRU1 SEC
 LDA DR+1,Y
 SBC DA,Y
 SEC
 SBC NMCY
 STA NMPRD
 STZ NMCY
 LDA NMPRD
 BPL NDRU2
 CLC
 ADC #10
 STA NMPRD
 LDA #1
 STA NMCY
NDRU2 LDA NMPRD
 STA DR+1,Y
 DEY
 BPL NDRU1
 LDA DR
 SEC
 SBC NMCY
 STA DR
 RTS

* NDQPK: quotient digits DP -> B
NDQPK LDA #0
 STA NSI
NDQ1 LDA NSI
 CMP #NDIG
 BCS NDQD
 LDY NSI
 LDA DP,Y
 STA NDSAV
 LDX NSI
 LDA NDSAV
 JSR NPUTD
 INC NSI
 JMP NDQ1
NDQD RTS

* NDRPK: remainder digits DR -> BCDREM
NDRPK LDY #NCELL-1
 LDA #0
NDR1 STA BCDREM,Y
 DEY
 BPL NDR1
 LDA #0
 STA NSI
NDR2 LDA NSI
 CMP #NDIG
 BCS NDRD
 LSR
 CLC
 ADC #NMSB
 TAX
 LDY NSI
 LDA DR+1,Y
 STA NDSAV
 LDA NSI
 AND #1
 BNE NDR3
 LDA BCDREM,X
 AND #$0F
 STA NDT
 LDA NDSAV
 ASL
 ASL
 ASL
 ASL
 ORA NDT
 STA BCDREM,X
 JMP NDR4
NDR3 LDA BCDREM,X
 AND #$F0
 ORA NDSAV
 STA BCDREM,X
NDR4 INC NSI
 JMP NDR2
NDRD RTS

* ================= CONVERSIONS =================

* ---- BPACK: DISPLAY digits -> NUM8 -------------
* in:  ZPT1 -> ASCII digits, ALEN of them
*      ZPT2 -> the cell
* Right justified: a short source is zero filled on
* the left, which is how COBOL moves a smaller
* numeric field into a larger one.
BPACK JSR BZERO
 LDA #NDIG
 SEC
 SBC ALEN
 BCC BPKX
 STA NPH
 LDA #0
 STA NSI
BPK1 LDA NSI
 CMP ALEN
 BCS BPKD
 LDY NSI
 LDA (ZPT1),Y
 AND #$0F
 STA NDSAV
 CLC
 LDA NSI
 ADC NPH
 TAX
 LDA NDSAV
 JSR NPUTD
 INC NSI
 JMP BPK1
BPKD RTS
BPKX LDA #1
 STA BCDERR
 JMP NSOVFL

* ---- BUNPK: NUM8 -> DISPLAY digits -------------
* in:  ZPT2 -> the cell, ZPT1 -> ALEN ASCII digits
* The sign is dropped here.  Putting it back where
* a reader expects it - a leading minus, a trailing
* CR - is the PICTURE engine's job, not this one's.
BUNPK LDA #0
 STA NSI
BU1 LDA NSI
 CMP ALEN
 BCS BUD
 LDA ALEN
 SEC
 SBC NSI
 SEC
 SBC #1
 STA NDJ
 LDA #NDIG
 SEC
 SBC NSI
 SEC
 SBC #1
 BMI BUZ
 TAX
 JSR NGETD
 JMP BUS
BUZ LDA #0
BUS ORA #$30
 LDY NDJ
 STA (ZPT1),Y
 INC NSI
 JMP BU1
BUD RTS

* ---- BTOBIN: NUM8 -> 16-bit BINVAL -------------
* For subscripts, COMP fields and anything that has
* to index memory.  Horner's method: what we have
* so far, times ten, plus the next digit.  A value
* past 65535 simply wraps - the compiler is
* expected not to ask.
BTOBIN LDA #0
 STA BINVAL
 STA BINVAL+1
 STA NSI
BB1 LDX NSI
 JSR NGETD
 STA NDSAV
 LDA BINVAL
 ASL
 STA NTMP
 LDA BINVAL+1
 ROL
 STA NTMP2
 LDA NTMP
 ASL
 STA NXW
 LDA NTMP2
 ROL
 STA NXW+1
 LDA NXW
 ASL
 STA NXW
 LDA NXW+1
 ROL
 STA NXW+1
 CLC
 LDA NXW
 ADC NTMP
 STA BINVAL
 LDA NXW+1
 ADC NTMP2
 STA BINVAL+1
 CLC
 LDA BINVAL
 ADC NDSAV
 STA BINVAL
 LDA BINVAL+1
 ADC #0
 STA BINVAL+1
 INC NSI
 LDA NSI
 CMP #NDIG
 BCS BTBD
 JMP BB1
BTBD RTS

* ---- BFRBIN: 16-bit BINVAL -> NUM8 -------------
* Repeated subtraction again, since there is still
* no divide anywhere on this machine.
* THE QUOTIENT MUST BE SIXTEEN BITS.  65535 / 10 is
* 6553, which does not fit in a byte - an 8-bit
* count wraps to 153 and every value above 2559
* quietly converts wrong.
BFRBIN JSR BZERO
 LDA #NDIG-1
 STA NSI
BI1 LDA NSI
 BMI BID
 LDA #0
 STA NXW
 STA NXW+1
BI2 SEC
 LDA BINVAL
 SBC #10
 TAY
 LDA BINVAL+1
 SBC #0
 BCC BI3
 STY BINVAL
 STA BINVAL+1
 INC NXW
 BNE BI2
 INC NXW+1
 JMP BI2
BI3 LDA BINVAL
 LDX NSI
 JSR NPUTD
 LDA NXW
 STA BINVAL
 LDA NXW+1
 STA BINVAL+1
 DEC NSI
 JMP BI1
BID RTS

* ================= ALPHANUMERIC ================
* COBOL's other MOVE.  Left justified, space
* filled, truncated on the right - the opposite of
* everything numeric above, and the source of most
* of the surprises a new COBOL programmer meets.

* ---- BMOVA: A (ALEN) -> B (BLEN)  (vector MOVALP)
BMOVA LDY #0
MVA1 CPY BLEN
 BCS MVAD
 CPY ALEN
 BCS MVA2
 LDA (ZPT1),Y
 JMP MVA3
MVA2 LDA #$20
MVA3 STA (ZPT2),Y
 INY
 JMP MVA1
MVAD RTS

* ---- BCMPA: compare A with B  (vector CMPALP) ---
* out: BCMPR = 0 equal, 1 if B>A, $FF if B<A
* The shorter operand is treated as though padded
* with spaces, which is what the standard says and
* what makes "AB" equal to "AB   ".
BCMPA LDY #0
CMA1 CPY ALEN
 BCC CMA2
 CPY BLEN
 BCS CMAEQ
CMA2 CPY ALEN
 BCS CMA3
 LDA (ZPT1),Y
 JMP CMA4
CMA3 LDA #$20
CMA4 STA NTMP
 CPY BLEN
 BCS CMA5
 LDA (ZPT2),Y
 JMP CMA6
CMA5 LDA #$20
CMA6 CMP NTMP
 BNE CMA7
 INY
 JMP CMA1
CMA7 BCS CMAGT
 LDA #$FF
 STA BCMPR
 RTS
CMAGT LDA #1
 STA BCMPR
 RTS
CMAEQ LDA #0
 STA BCMPR
 RTS

* ---- BFILL: fill B (BLEN) with FILLC ------------
* INITIALIZE, MOVE SPACE, MOVE ZERO, MOVE ALL "x".
BFILL LDY #0
 LDA FILLC
FC1 STA (ZPT2),Y
 INY
 CPY BLEN
 BCC FC1
 RTS

* ================= VARIABLES ===================
* Scalars only.  The unpacked digit arrays DA, DB,
* DP and DR are addresses in the data region - see
* EQUATES - because they are bulk storage and have
* no business inside a file that gets loaded from
* a floppy every time a program starts.
NTMP DFB 0
NTMP2 DFB 0
NSA DFB 0
NSB DFB 0
NDX DFB 0
NDT DFB 0
NDV DFB 0
NDSAV DFB 0
NSI DFB 0
NDJ DFB 0
NPH DFB 0
NMI DFB 0
NMJ DFB 0
NMK DFB 0
NMD DFB 0
NMCY DFB 0
NMACC DFB 0
NMPRD DFB 0
NXW DS 2
