* CMPDATA2.S  DATA DIVISION, part two
* PUT from COMPILE1.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* Started 2026-11-08 for FIXLIST list A, because
* CMPDATA.S is within two K of Merlin 8's 24K
* PUT-file limit.  New DATA DIVISION code goes here.

* ================= REDEFINES ===================
* A REDEFINES item is a second description of
* storage that already exists, so it gets the
* REDEFINED item's offset instead of new bytes.
* It was skipped as a clause word and the item got
* storage of its own: a MOVE to one name never
* showed through the other (FIXLIST A11).
*
* How the allocation goes:
*   DDREDF  the clause: find the item, keep its
*           offset in RDOFF, set REDF
*   DDRDA   just before EMALLOC: remember where
*           storage had got to (RDHIW) and hand out
*           from RDOFF instead
*   DDRDB   just after the descriptor: an
*           elementary item is done at once; a
*           group waits for its close
*   DDRDC   from DDMEAS, when that group closes
* and both ends put DSEG back to the HIGHER of the
* two - the redefining description may be longer
* than the one it redefines, and nothing after it
* may land on top of either.
*
* One REDEFINES group at a time: a REDEFINES inside
* a REDEFINES group is refused with error 13.

* ---- DDREDF: REDEFINES <name> -------------------
DDREDF JSR LEXNEXT
 BCS DDRBAD
 LDA TOKTYP
 CMP #TKWORD
 BNE DDRBAD
 LDA RDPEND
 BNE DDRNST
 JSR SYMFIND
 BCS DDRUNK
 JSR SYMGET
 LDA SYKIND
 CMP #KDATA
 BNE DDRUNK
* the offset is bytes 4-5 of descriptor SYMVAL
 LDA SYMVAL
 STA RDT
 LDA SYMVAL+1
 STA RDT+1
 ASL RDT
 ROL RDT+1
 ASL RDT
 ROL RDT+1
 ASL RDT
 ROL RDT+1
 CLC
 LDA #<OBDESC
 ADC RDT
 STA ZPT1
 LDA #>OBDESC
 ADC RDT+1
 STA ZPT1+1
 LDY #4
 LDA (ZPT1),Y
 STA RDOFF
 INY
 LDA (ZPT1),Y
 STA RDOFF+1
 LDA #1
 STA REDF
 RTS
DDRBAD LDA #8
 STA CMPERR
 RTS
DDRUNK LDA #15
 STA CMPERR
 RTS
DDRNST LDA #13
 STA CMPERR
 RTS

* ---- DDRDA: before EMALLOC ----------------------
DDRDA LDA REDF
 BEQ DDRAX
 LDA DSEG
 STA RDHIW
 LDA DSEG+1
 STA RDHIW+1
 LDA RDOFF
 STA DSEG
 LDA RDOFF+1
 STA DSEG+1
DDRAX RTS

* ---- DDRDB: after the descriptor ----------------
* CURIT is the item just described
DDRDB LDA REDF
 BEQ DDRBX
 STZ REDF
 LDA HASPIC
 BNE DDRMAX
* a group: finish when DDMEAS closes it
 LDA CURIT
 STA RDITEM
 LDA CURIT+1
 STA RDITEM+1
 LDA #1
 STA RDPEND
DDRBX RTS

* ---- DDRDC: a group closed - was it ours? -------
* EMIT is the group DDMEAS just measured
DDRDC LDA RDPEND
 BEQ DDRCX
 LDA EMIT
 CMP RDITEM
 BNE DDRCX
 LDA EMIT+1
 CMP RDITEM+1
 BNE DDRCX
 STZ RDPEND
 JMP DDRMAX
DDRCX RTS

* ---- DDRMAX: DSEG = the higher of DSEG, RDHIW ----
DDRMAX LDA DSEG+1
 CMP RDHIW+1
 BCC DDRM1
 BNE DDRMX
 LDA DSEG
 CMP RDHIW
 BCS DDRMX
DDRM1 LDA RDHIW
 STA DSEG
 LDA RDHIW+1
 STA DSEG+1
DDRMX RTS

* ---- variables: pass one only, and the overlay is
* loaded fresh for every compile ----
REDF DFB 0
RDPEND DFB 0
RDOFF DS 2
RDHIW DS 2
RDITEM DS 2
RDT DS 2

* ================= VALUE =======================
* FIXLIST A12.  VALUE -5 lost its sign, VALUE +5
* and VALUE IS 5 gave no value at all - the first
* token after VALUE was taken as the value whatever
* it was - and 88 X VALUE SPACES compared with the
* six letters S P A C E S.

* ---- DDVPRE: the token after VALUE --------------
* Skips IS, takes a + or - in front.  out: the value
* token in TOKBUF, VALNEG = 1 if it was negative;
* C=1 at the end of the source, as LEXNEXT.
DDVPRE STZ VALNEG
DDVP1 JSR LEXNEXT
 BCS DDVPX
 LDA TOKTYP
 CMP #TKPUNC
 BNE DDVP2
 LDA TOKBUF
 CMP #$2B
 BEQ DDVP1
 CMP #$2D
 BNE DDVPOK
 LDA #1
 STA VALNEG
 BNE DDVP1
DDVP2 CMP #TKWORD
 BNE DDVPOK
 LDA TOKLEN
 CMP #2
 BNE DDVP3
 LDA TOKBUF
 CMP #$49
 BNE DDVPOK
 LDA TOKBUF+1
 CMP #$53
 BEQ DDVP1
 BRA DDVPOK
* VALUES ARE "Y": ARE is passed over as IS is
DDVP3 CMP #3
 BNE DDVPOK
 LDA TOKBUF
 CMP #$41
 BNE DDVPOK
 LDA TOKBUF+1
 CMP #$52
 BNE DDVPOK
 LDA TOKBUF+2
 CMP #$45
 BEQ DDVP1
DDVPOK CLC
DDVPX RTS

* ---- DDVNEG: the cell in LITBUF gets the sign ----
* Called straight after BCDPACK.  Byte 0 of a cell
* is its flags and FNEG is the sign.
DDVNEG LDA VALNEG
 BEQ DDVNX
 LDA LITBUF
 ORA #FNEG
 STA LITBUF
DDVNX RTS

* ---- DDXVAL: a second value, or THRU ------------
* An 88 tests ONE value.  VALUE 1 2 3 and VALUE 1
* THRU 5 used to test only the 1, silently; now
* they are error 34 until lists are built.  DDCLAU
* calls this for every token that is not a word or
* the full stop, and the THRU words come here from
* the clause table.
* A NUMBER ON A LATER LINE than the level number is
* the next entry's level number: this entry's full
* stop is missing.  It used to merge the two
* entries into one (FIXLIST A18) - error 35 now,
* reported at the line the next entry starts on.
DDXVAL LDA TOKTYP
 CMP #TKNUM
 BNE DDXV0
 LDA TOKLIN
 CMP ENTLIN
 BNE DDXFS
 LDA TOKLIN+1
 CMP ENTLIN+1
 BEQ DDXV1
DDXFS LDA #35
 STA CMPERR
 RTS
DDXV0 CMP #TKNUM
 BEQ DDXV1
 CMP #TKSTR
 BNE DDXVX
DDXV1 LDA VALKND
 BEQ DDXVX
DDXTHR LDA #34
 STA CMPERR
DDXVX RTS

* ---- DD88F: a figurative as an 88's value -------
* SPACE(S) becomes the text " ", ZERO(S)/ZEROES the
* digit 0 - as a number if the parent is numeric,
* as text if not, because the compare is made by
* the parent's type.  Any other word is error 34.
* in: VALKND, VALBUF/VALLEN.  out: C=1 on error.
DD88F LDA VALKND
 CMP #3
 BEQ DD8F0
 CLC
 RTS
DD8F0 LDX #0
DD8F1 LDA FIGW,X
 BEQ DD8FB
 CMP VALLEN
 BNE DD8F4
 STX RDT
 LDY #0
DD8F2 INX
 LDA FIGW,X
 CMP VALBUF,Y
 BNE DD8F3
 INY
 CPY VALLEN
 BCC DD8F2
* matched: the byte after the text says which
 INX
 LDA FIGW,X
 BEQ DD8FS
* ZERO: number or text by the parent's type
 LDA #$30
 STA VALBUF
 LDA #1
 STA VALLEN
 STZ VALNEG
 JSR DD8PTY
 CMP #TNUMB
 BEQ DD8FN
 LDA #1
 STA VALKND
 CLC
 RTS
DD8FN LDA #2
 STA VALKND
 STZ DDECV
 CLC
 RTS
DD8FS LDA #$20
 STA VALBUF
 LDA #1
 STA VALLEN
 STA VALKND
 CLC
 RTS
DD8F3 LDX RDT
DD8F4 TXA
 CLC
 ADC FIGW,X
 TAX
 INX
 INX
 JMP DD8F1
DD8FB LDA #34
 STA CMPERR
 SEC
 RTS
* the parent's type: byte 0 of descriptor CURIT
DD8PTY LDA CURIT
 STA RDT
 LDA CURIT+1
 STA RDT+1
 ASL RDT
 ROL RDT+1
 ASL RDT
 ROL RDT+1
 ASL RDT
 ROL RDT+1
 CLC
 LDA #<OBDESC
 ADC RDT
 STA ZPT1
 LDA #>OBDESC
 ADC RDT+1
 STA ZPT1+1
 LDA (ZPT1)
 RTS
* length, text, then 0 = space or 1 = zero
FIGW DFB 5
 ASC 'SPACE'
 DFB 0
 DFB 6
 ASC 'SPACES'
 DFB 0
 DFB 4
 ASC 'ZERO'
 DFB 1
 DFB 5
 ASC 'ZEROS'
 DFB 1
 DFB 6
 ASC 'ZEROES'
 DFB 1
 DFB 0

VALNEG DFB 0
ENTLIN DS 2

* ================= 88 LEVELS ===================
* A condition name compiles to nothing here.  Its
* value is pooled and its parent remembered, and
* slice 5 turns IF IS-ACTIVE into a compare against
* that literal.
* An 88 is a NAME for a comparison: its parent item
* against its literal.  So the symbol records BOTH -
* the literal's pool offset as the value and the
* parent's item number in the chain slot, which is
* what CMPSYM's header has always said a KCOND
* holds and what the code did not do until
* 2026-08-16.  The comparison is emitted wherever
* the name is used: IF IS-ACTIVE, PERFORM UNTIL
* ALL-DONE, WHEN STAT-OK.
DD88 JSR LEXNEXT
 BCS DD88E
 LDA TOKTYP
 CMP #TKWORD
 BEQ DD88N
DD88E LDA #8
 STA CMPERR
 RTS
* the name goes in now with a placeholder, because
* the clause loop is about to destroy TOKBUF and the
* literal is not read yet
DD88N STZ SYMVAL
 STZ SYMVAL+1
 LDA #KCOND
 JSR SYMADD
 BCC DD88A
 RTS
DD88A LDA SYMIX
 STA DD88I
 STZ VALKND
 JSR DDCLAU
 LDA CMPERR
 BNE DD88R
 LDA VALKND
 BEQ DD88E
 JSR DD88F
 BCS DD88R
* pool the literal exactly as DDVAL would, but do
* NOT emit a MOVL - an 88 allocates nothing and
* initialises nothing
 JSR DD88P
 LDA DD88I
 STA SYMIX
 LDA EMLO
 STA SYMVAL
 LDA EMLO+1
 STA SYMVAL+1
 JSR SYMPUT
 LDA CURIT
 STA FIXHD
 LDA CURIT+1
 STA FIXHD+1
 JMP SYMCHS
DD88R RTS

* ---- DD88P: VALBUF into the pool, no MOVL -------
* The text and numeric arms of DDVAL, without the
* emit at the end.  DDVAL itself cannot be called
* because it ends in EMOP2; this is the part before.
DD88P LDX #0
DD8P1 CPX VALLEN
 BCS DD8P2
 LDA VALBUF,X
 STA LITBUF+1,X
 INX
 JMP DD8P1
DD8P2 LDA VALLEN
 STA LITN
 LDA VALKND
 CMP #2
 BEQ DD8PN
 JMP EMLTXT
DD8PN JSR DDVSCL
 LDA #<VALBUF
 STA ZPT1
 LDA #>VALBUF
 STA ZPT1+1
 LDA #<LITBUF
 STA ZPT2
 LDA #>LITBUF
 STA ZPT2+1
 LDA VALLEN
 STA ALEN
 JSR BCDPACK
 JSR DDVNEG
 LDA DDECV
 STA LITSCL
 JMP EMLNUM
DD88X LDA #8
 STA CMPERR
 RTS

* ================= TABLES (OCCURS) ==============
* FIXLIST A2, 2026-11-08.  An OCCURS item used to be
* one descriptor n times as long, so X(2) was X and
* there was no way to reach the second element.  Now
* the descriptor is ONE occurrence and the storage
* is n of them; the table list at $1F60 tells pass
* two which items are tables, how many occurrences
* and how far apart, and a SUBS instruction finds
* the element at run time.
* The subset: one dimension - no OCCURS inside an
* OCCURS - not at level 01 or 77, eight tables, and
* no VALUE anywhere in a table.  Each is an error
* rather than a table quietly built wrong.

* ---- DDTAB: after an item is described ----------
* in: CURIT the item, OCCN its OCCURS (0 = none),
*     HASPIC 0 for a group, DLENV one occurrence
DDTAB LDA VALKND
 BEQ DDTB1
 LDA OCCN
 ORA TBOPEN
 BEQ DDTB1
 LDA #37
 BNE DDTER
DDTB1 LDA OCCN
 BEQ DDTBX
 LDA TBOPEN
 BNE DDTB36
 LDA THISLV
 CMP #1
 BEQ DDTB36
 CMP #77
 BEQ DDTB36
 LDA NOCC
 CMP #8
 BCS DDTB36
 LDA CURIT+1
 BNE DDTB36
* first, last, count, stride
 LDA NOCC
 ASL
 ASL
 TAX
 LDA CURIT
 STA OCCTAB,X
 STA OCCTAB+1,X
 LDA OCCN
 STA OCCTAB+2,X
 LDA DLENV
 STA OCCTAB+3,X
 INC NOCC
 LDA HASPIC
 BNE DDTB2
* a group: its length, its last item and the rest
* of its storage wait for DDTCLS
 LDA NOCC
 STA TBOPEN
 LDA NLVL
 STA TBNLVL
 RTS
* an elementary item: the other n-1 now
DDTB2 LDA OCCN
 STA DDTN
 LDA DLENV
 JMP DDTGRW
DDTB36 LDA #36
DDTER STA CMPERR
DDTBX RTS

* ---- DDTCLS: a group closing (DDMEAS) -----------
* in: DDT its length, NLVL its level-stack index
* If it is the open OCCURS group, that length is the
* stride, the last item described is the table's
* last, and the other n-1 occurrences go on the end.
DDTCLS LDA TBOPEN
 BEQ DDTCX
 LDA NLVL
 CMP TBNLVL
 BNE DDTCX
 LDA TBOPEN
 SEC
 SBC #1
 ASL
 ASL
 TAX
 LDA NITEMS
 SEC
 SBC #1
 STA OCCTAB+1,X
 LDA DDT
 STA OCCTAB+3,X
 LDA OCCTAB+2,X
 STA DDTN
 STZ TBOPEN
* over 255 for one occurrence: DDMEAS says so next
 LDA DDT+1
 BNE DDTCX
 LDA DDT
 JMP DDTGRW
DDTCX RTS

* ---- DDTGRW: DDTN copies of A bytes, one there --
* The whole table must fit in 255 bytes, as a group
* must (FIXLIST A10): error 33 if it does not.
DDTGRW STA DDTW
 STZ DDTT
 STZ DDTT+1
 LDX DDTN
DDTG1 CLC
 LDA DDTT
 ADC DDTW
 STA DDTT
 BCC DDTG2
 INC DDTT+1
DDTG2 DEX
 BNE DDTG1
 LDA DDTT+1
 BNE DDTG33
* DSEG += n copies - the one already there
 SEC
 LDA DDTT
 SBC DDTW
 CLC
 ADC DSEG
 STA DSEG
 BCC DDTG3
 INC DSEG+1
DDTG3 RTS
DDTG33 LDA #33
 STA CMPERR
 RTS
