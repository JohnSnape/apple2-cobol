* CMPFILE.S  FILE-CONTROL: SELECT, FD and the names
* they park
* PUT from COMPILE1.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* Split out of CMPDATA.S on 2026-11-22, when ASSIGN
* TO a data name (and the A21 notes) took CMPDATA.S
* past Merlin 8's 24K PUT-file limit.  Nothing in
* it changed in the move; CMPDATA.S still calls
* FCSEL, FCFD, FCREC and FCRES, and one symbol table
* spans every PUT, so where they sit does not matter.

* ---- FCSEL: SELECT name ASSIGN TO "path" ... ----
* The clauses are read to the full stop.  Three of
* them are kept and the rest are skipped by name
* rather than by grammar: ORGANIZATION and ACCESS
* can only say what this system already does, so
* reading them would be a way of rejecting programs
* rather than of learning anything.
FCSEL LDA NFILES
 CMP #2
 BCC FCS0
 LDA #17
 STA CMPERR
 RTS
FCS0 JSR LEXNEXT
 BCS FCSBAD
 LDA TOKTYP
 CMP #TKWORD
 BNE FCSBAD
* SELECT OPTIONAL name: OPTIONAL is not the name
 LDA #<OPTW
 LDX #>OPTW
 JSR WDLKAX
 BCS FCS0
 LDA NFILES
 STA SYMVAL
 STZ SYMVAL+1
 LDA #KFILE
 JSR SYMADD
 BCC FCS1
 RTS
* clear the entry, so a clause left out reads as
* absent rather than as whatever was there
FCS1 JSR FCX
 LDY #0
FCS2 LDA #$FF
 STA CMPFIL,X
 INX
 INY
 CPY #8
 BCC FCS2
 JSR FCX
 LDA #1
 STA CMPFIL+FLFLG,X
* the two names we cannot resolve yet - WORKING-
* STORAGE has not been read - are parked as TEXT and
* looked up by FCRES at the end of the pass.  FCNX
* and FCNCL index by FCI, so FCI is THIS file - it
* was never set here, and a second SELECT parked its
* names on top of the first's.
 LDA NFILES
 STA FCI
 JSR FCNCL
FCS3 JSR LEXNEXT
 BCS FCSDN
 LDA TOKTYP
 CMP #TKPUNC
 BEQ FCSDN
 CMP #TKWORD
 BNE FCS3
 JSR FCCLA
 JMP FCS3
FCSDN INC NFILES
 RTS
FCSBAD LDA #18
 STA CMPERR
 RTS

* ---- FCCLA: one SELECT clause ------------------
* ASSIGN, KEY and STATUS are the three words that
* carry something; the rest of SELTAB (CMPENV.S) is
* taken and passed over, and a word not in it is
* error 50.  Until 2026-11-12 a word was known by
* its first letter and length - ACCESS was ASSIGN,
* RECORD KEY was the relative key, and INDEXED was
* nothing at all.
FCCLA LDA #<SELTAB
 LDX #>SELTAB
 JSR WDLKAX
 BCS FCC1
 JMP ENBAD
FCC1 CMP #1
 BCS FCC2
 JMP FCASN
FCC2 BNE FCC3
 LDA #0
 JMP FCNAM
FCC3 CMP #2
 BNE FCCX
 LDA #1
 JMP FCNAM
FCCX RTS

* ---- FCASN: ASSIGN [TO] "path" or a data name --
* A QUOTED NAME goes into the literal pool exactly as
* any other text literal does, and the file table
* keeps its offset.  VMFILE adds the pool base at
* run time, so nothing here has to know where the
* pool will land.
*
* A DATA NAME (2026-11-22, the user's call) is the
* file's name AT EACH OPEN: one SELECT can open
* EAST.DAT, close it, and open WEST.DAT.  It is
* parked as text in the third name slot, beside the
* key and the status, because WORKING-STORAGE has
* not been read yet; FCRES turns it into an item
* number and sets bit 2 of FLFLG to say "the path
* is an item, not a pool offset".
*
* Until then the word after TO was skipped as if it
* were TO itself, nothing was stored, and OPEN used
* a path of $FFFF - every OPEN said "42" and no
* error was given at compile time (test asn.cob).
* TO is optional, as the standard has it.  Anything
* that is neither a quoted name nor a word is error
* 18, SELECT STATEMENT ERROR.
FCASN JSR LEXNEXT
 BCS FCAX
 LDA TOKTYP
 CMP #TKWORD
 BNE FCA1
 LDA TOKLEN
 CMP #2
 BNE FCA2
 LDA TOKBUF
 CMP #$54
 BNE FCA2
 LDA TOKBUF+1
 CMP #$4F
 BNE FCA2
* it was TO: the name is the next token
 JSR LEXNEXT
 BCS FCAX
 LDA TOKTYP
 CMP #TKWORD
 BEQ FCA2
FCA1 CMP #TKSTR
 BNE FCABAD
 JSR FCSTXT
 BCS FCAX
 JSR FCX
 LDA EMLO
 STA CMPFIL+FLPATH,X
 LDA EMLO+1
 STA CMPFIL+FLPATH+1,X
FCAX RTS
* a data name: slot 2, copied by FCNAM's own loop
FCA2 LDA #2
 STA FCWH
 JMP FCN1
FCABAD LDA #18
 STA CMPERR
 RTS

* ---- FCNAM: KEY IS x / STATUS IS x -------------
* in: A = 0 for the key, 1 for the status
* The name is COPIED, not resolved.  RELATIVE KEY IS
* LEAD-KEY names an item in WORKING-STORAGE, which
* is two sections further down the source - so there
* is nothing to look it up in yet.  FCRES does it
* when there is.
FCNAM STA FCWH
 JSR LEXNEXT
 BCS FCNX9
 LDA TOKTYP
 CMP #TKWORD
 BNE FCNX9
* skip IS
 LDA TOKLEN
 CMP #2
 BNE FCN1
 LDA TOKBUF
 CMP #$49
 BNE FCN1
 JSR LEXNEXT
 BCS FCNX9
 LDA TOKTYP
 CMP #TKWORD
 BNE FCNX9
FCN1 JSR FCNX
 LDY #0
FCN2 CPY TOKLEN
 BCS FCN3
 CPY #30
 BCS FCN3
 LDA TOKBUF,Y
 STA FLNAMS,X
 INX
 INY
 JMP FCN2
* FLNLEN has ONE byte per slot, so it is indexed by
* the slot (FCT, which FCNX leaves behind) and not by
* X, which is ten times that.  Indexed by X, the
* status name's length landed on the 7th letter of
* the key name - MEDIA-KEY became MEDIA-?EY and the
* sample programs died with error 20 (2026-11-07).
FCN3 JSR FCNX
 LDX FCT
 LDA TOKLEN
 CMP #31
 BCC FCN4
 LDA #30
FCN4 STA FLNLEN,X
FCNX9 RTS

* ---- FCNCL: no key, status or ASSIGN name yet --
* the three slots of file FCI: 3*FCI to 3*FCI+2
FCNCL LDA FCI
 ASL
 CLC
 ADC FCI
 TAX
 LDA #0
 STA FLNLEN,X
 STA FLNLEN+1,X
 STA FLNLEN+2,X
 RTS

* ---- FCFD: FD name ------------------------------
* The record area is not named here - it is the very
* next 01, which is how COBOL says it.  So this only
* remembers WHICH file is waiting for one, and DDLVL
* fills it in when the 01 arrives.
FCFD JSR LEXNEXT
 BCS FCFDX
 LDA TOKTYP
 CMP #TKWORD
 BNE FCFDX
 JSR SYMFIND
 BCS FCFDB
 JSR SYMGET
 LDA SYKIND
 CMP #KFILE
 BNE FCFDB
 LDA SYMVAL
 STA FCFDIX
* and its clauses, to the full stop (CMPENV.S)
 JMP FDCLA
FCFDB LDA #19
 STA CMPERR
FCFDX RTS

* ---- FCREC: this 01 is the waiting FD's record --
* Called from DDLVL for every level 01.  FCFDIX is
* $FF unless an FD is waiting, so the ordinary
* WORKING-STORAGE 01 costs one compare.
FCREC LDA FCFDIX
 CMP #$FF
 BEQ FCRX
 PHA
 ASL
 ASL
 ASL
 ASL
 TAX
 LDA NITEMS
 STA CMPFIL+FLREC,X
 LDA NITEMS+1
 STA CMPFIL+FLREC+1,X
 PLA
 LDA #$FF
 STA FCFDIX
FCRX RTS

* ---- FCRES: resolve the parked names -----------
* End of pass one, when every data name is known.
* The name is copied back into TOKBUF because that
* is what SYMFIND reads - which is cheaper than a
* second lookup routine that reads somewhere else.
* Three names a file since 2026-11-22: the key, the
* status and the ASSIGN data name.  A file with no
* ASSIGN at all still has the $FFFF FCSEL put in
* its path, and is error 18 here - it used to reach
* OPEN, which used whatever lay at pool + $FFFF.
FCRES STZ FCI
FCR1 LDA FCI
 CMP NFILES
 BCS FCRX2
 STZ FCWH
FCR1A JSR FCR2
 INC FCWH
 LDA FCWH
 CMP #3
 BCC FCR1A
* an earlier error stands: an ASSIGN name that was
* not found also leaves the path $FFFF, and its 15
* is the true one (test asne15 said 18 first)
 LDA CMPERR
 BNE FCR1B
 LDA FCI
 ASL
 ASL
 ASL
 ASL
 TAX
 LDA CMPFIL+FLPATH,X
 AND CMPFIL+FLPATH+1,X
 CMP #$FF
 BNE FCR1B
 LDA #18
 STA CMPERR
FCR1B INC FCI
 JMP FCR1
FCRX2 RTS
FCR2 JSR FCNX
 LDX FCT
 LDA FLNLEN,X
 BEQ FCR9
 STA TOKLEN
 JSR FCNX
 LDY #0
FCR3 CPY TOKLEN
 BCS FCR4
 LDA FLNAMS,X
 STA TOKBUF,Y
 INX
 INY
 JMP FCR3
FCR4 JSR SYMFIND
 BCS FCR8
 JSR SYMGET
 LDA SYKIND
 CMP #KDATA
 BNE FCR8
 LDA FCI
 ASL
 ASL
 ASL
 ASL
 TAX
 LDA FCWH
 BNE FCR5
 LDA SYMVAL
 STA CMPFIL+FLKEY,X
 LDA SYMVAL+1
 STA CMPFIL+FLKEY+1,X
 RTS
FCR5 CMP #2
 BEQ FCR6
 LDA SYMVAL
 STA CMPFIL+FLSTAT,X
 LDA SYMVAL+1
 STA CMPFIL+FLSTAT+1,X
FCR9 RTS
* the ASSIGN name: its item number is the path, and
* FLFLG bit 2 tells PDFILE to set bit 2 of OPEN's
* ctl byte, which is what VMFILE tests
FCR6 LDA SYMVAL
 STA CMPFIL+FLPATH,X
 LDA SYMVAL+1
 STA CMPFIL+FLPATH+1,X
 LDA CMPFIL+FLFLG,X
 ORA #4
 STA CMPFIL+FLFLG,X
 RTS
* a key or status name that is not a data item is
* 20; an ASSIGN name is an ordinary unknown name, 15
FCR8 LDA #20
 LDX FCWH
 CPX #2
 BNE FCR8B
 LDA #15
FCR8B STA CMPERR
 RTS

* ---- FCX: X = 16 * the file being declared -----
FCX LDA NFILES
 ASL
 ASL
 ASL
 ASL
 TAX
 RTS

* ---- FCNX: X = the name slot for FCWH ---------
* Three names a file, thirty bytes each (ten until
* names went to thirty, 2026-11-11), in declaration
* order: file 0 key, status, ASSIGN name, then file
* 1's three.  The third came 2026-11-22.
FCNX LDA FCI
 ASL
 CLC
 ADC FCI
 CLC
 ADC FCWH
 STA FCT
* 30 x FCT = 32 x FCT - 2 x FCT; at most 150
 ASL
 STA FCTW
 ASL
 ASL
 ASL
 ASL
 SEC
 SBC FCTW
 TAX
 RTS

* ---- FILE-CONTROL working storage --------------
* Pass one only, so it sits in this file rather than
* in CMPVAR - pass two PUTs CMPVAR too and has no
* use for 186 bytes of parked file names.
FCFDIX DFB $FF
FCI DFB 0
FCWH DFB 0
FCT DFB 0
FCTW DFB 0
DD88I DFB 0
FLNLEN DFB 0,0,0,0,0,0
FLNAMS DS 180

* ---- FCSTXT: TOKBUF -> the literal pool --------
* out: EMLO = its offset, C=1 if the pool is full
* PDOPND's string arm does this too, and is in
* CMPPROC - which pass one does not have.  Fifteen
* lines here beat moving a routine that the other
* pass uses in a different way.
FCSTXT LDX #0
FCSX1 CPX TOKLEN
 BCS FCSX2
 LDA TOKBUF,X
 STA LITBUF+1,X
 INX
 JMP FCSX1
FCSX2 LDA TOKLEN
 STA LITN
 JMP EMLTXT


