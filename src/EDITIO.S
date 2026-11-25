* EDITIO.S  EDIT's Open and Save
* PUT from EDIT.S - not assembled on its own, and
* it has no ORG: PUT drops it in at the point of
* the PUT line, so every address is exactly what it
* would be inline.  The split is a source
* convenience, nothing more - EDIT.S had grown too
* large for Merlin's editor to hold at once.
*
* ONE SYMBOL TABLE SPANS THE PUT.  This file freely
* references labels defined in EDIT.S - the ring's
* SHFGET / SHFPUT / SHFBLK / CSETRC, EDFULL,
* EDSTAL, the messages (MSAVE / MOPEN / MSAVED /
* MFULL / MERR) and the file variables (SLINE,
* SGP, OLINE, NAMBUF and the rest) - and EDIT.S
* reaches DOPEN and DSAVE here.  Merlin resolves it
* all in its second pass, exactly as if the two
* files were one.
*
* ================= OPEN AND SAVE ===============
* THE FILE BUFFER IS PRODOS'S, NOT OURS
* The 1024 bytes at IOBUF handed to OPEN are
* ProDOS's own working space - the current data
* block and the index block - and it rewrites them
* on every call.  Our data never goes there.  READ
* and WRITE take a SEPARATE data address and count,
* and STAGE is what we pass.
*
* WHY THIS STREAMS INSTEAD OF CALLING FLOAD/FSAVE
* Those move one contiguous buffer.  A 500-line
* program is 40,000 bytes and it exists nowhere in
* main memory - it is records scattered across
* auxiliary banks.  So we go a line at a time
* through a 512-byte staging buffer, which makes
* one MLI call a block instead of one a line.
* 512 is a batching choice and nothing more:
* ProDOS blocks any byte count itself.
*
* WHY RECORD BY RECORD AND NOT A BULK MOVE
* A 512-byte window into the auxiliary image can
* straddle a bank boundary - records 511 and 512
* live in different banks - and AUXMOVE has no idea.
* AMGET and AMPUT go through AMMAP, which does.
*
* ORDER IS INHERENT.  Line N is record N, so
* nothing is sorted, indexed or seeked at either
* end: SAVE counts up and stops, OPEN counts up and
* stops.
*
* ON DISK: low ASCII, every line ended with $0D,
* trailing spaces trimmed.  That is what the sample
* programs already are.  Reading masks to seven
* bits, so a file written in high ASCII by another
* program imports correctly as well.
STAGE EQU OVLWORK
STGSZ EQU 512
* The flush threshold, 432, as its two bytes.  A
* line contributes at most 81 - eighty columns and
* the carriage return - so 512-81 = 431 is the last
* safe length, and we flush at 432 and above.
STGFLH EQU 1
STGFLL EQU $B0

* ---- EPROMP: ask for a file name ----------------
* STRPTR -> the question.  C=1 if the operator
* pressed ESC or typed nothing.
EPROMP JSR PRMPT
 JSR PUTS
 LDA #<NAMBUF+1
 STA ZPT2
 LDA #>NAMBUF+1
 STA ZPT2+1
 LDA #15
 JSR GETLN80
 BCS EPR9
 STY NAMBUF
 CPY #0
 BEQ EPR9
 CLC
 RTS
EPR9 SEC
 RTS

* ---- ENAME: NAMBUF -> FNBUF1 and FTYPE ----------
* SPLITNM does all of it: upper-cases the name,
* recognises a three-character suffix, and turns
* that suffix into a ProDOS type.  A name it does
* not recognise comes back as BIN, which is wrong
* here - EDIT edits COBOL source, so a bare name
* is COB.
* NO PATH IS BUILT.  ProDOS prepends the current
* prefix to any pathname that does not begin with a
* slash, so the bare name is enough - and the
* prefix is on row 0 where the operator can see
* which one it is.
ENAME LDA #<NAMBUF
 STA FNAMP
 LDA #>NAMBUF
 STA FNAMP+1
* A bare name gets .COB on the end (SETSFX, X=0); a
* name with a suffix - TEST.SNP - is kept as typed.
* The suffix is part of the ProDOS name since
* 2026-11-07, so source and object never collide.
 LDA #$47
 LDX #0
 JMP SETSFX

* ---- ESETNM: the name goes into the header ------
* EDNAME holds sixteen, and it is also the name the
* compiler gives the object (SRCNAM, EDITENT).  A
* name that will not fit - a prefix makes a long one
* easily: 1/PAYROLL can be /HD/WORK/DATA/PAYROLL.COB
* - keeps only its last part, so the header shows
* the file's name and the object goes to 0/, the
* program prefix, which is where RUN looks for it.
* It used to keep the first sixteen characters,
* which named neither (2026-11-11).
ESETNM LDX #0
 LDA FNBUF1
 CMP #17
 BCC ESN0
* X = just after the last slash
 TAY
ESN4 LDA FNBUF1,Y
 CMP #$2F
 BEQ ESN5
 DEY
 BNE ESN4
ESN5 TYA
 TAX
ESN0 STX ESNX
 LDA FNBUF1
 SEC
 SBC ESNX
 CMP #17
 BCC ESN1
 LDA #16
ESN1 STA EDNAME
 TAY
ESN2 CPY #0
 BEQ ESN3
 TYA
 CLC
 ADC ESNX
 TAX
 LDA FNBUF1,X
 STA EDNAME,Y
 DEY
 JMP ESN2
ESN3 LDA RFLAG
 ORA #4
 STA RFLAG
 RTS
ESNX DFB 0

* ---- EMSG: A/X -> message, then wait for a key --
EMSG STA STRPTR
 STX STRPTR+1
 JSR PRMPT
 JSR PUTS
 JMP WAITKEY

* ---- EDERR: A = MLI error code ------------------
* The code is shown in hex because that is how the
* ProDOS manual lists them, and a number the
* operator can look up beats a word we invented.
*   Except $40, bad pathname: that one is the name
* the operator typed, and the prefix service makes
* every name that breaks ProDOS's rules into one
* (PREFIX.S, DECISIONS 8.10) - so it says so.
EDERR CMP #$40
 BNE EDE1
 LDA #<MBADN
 LDX #>MBADN
 JMP EMSG
EDE1 PHA
 LSR
 LSR
 LSR
 LSR
 JSR EHEXD
 STA MERR+13
 PLA
 AND #$0F
 JSR EHEXD
 STA MERR+14
 LDA #<MERR
 LDX #>MERR
 JMP EMSG

EHEXD CMP #10
 BCC EHX1
 CLC
 ADC #$37
 RTS
EHX1 CLC
 ADC #$30
 RTS

* ---- SGRST: the staging buffer is empty ---------
SGRST LDA #<STAGE
 STA SGP
 LDA #>STAGE
 STA SGP+1
 LDA #0
 STA SGLEN
 STA SGLEN+1
 RTS

* ---- SGFLSH: write what is staged, then reset ---
* C=1 + A = MLI error on failure.
SGFLSH LDA SGLEN
 ORA SGLEN+1
 BEQ SGF1
 LDA #<STAGE
 STA EPRWPM+2
 LDA #>STAGE
 STA EPRWPM+3
 LDA SGLEN
 STA EPRWPM+4
 LDA SGLEN+1
 STA EPRWPM+5
 JSR EPWRIT
 BCS SGF9
SGF1 JSR SGRST
 CLC
SGF9 RTS

* ---- SGTRIM: SLEN = SHFBUF less trailing spaces -
* A line of nothing but spaces gives zero, which
* writes as a bare carriage return - a blank line,
* which is what it is.
SGTRIM LDY #RECSZ-1
SGT1 LDA SHFBUF,Y
 CMP #$20
 BNE SGT2
 DEY
 BPL SGT1
 LDY #$FF
SGT2 INY
 STY SLEN
 RTS

* ---- SGLINE: SHFBUF, trimmed, + $0D -> STAGE ----
* ZPT1 is zone S - caller-saved - so it is only
* safe to hold a pointer in it across code that
* calls nothing.  Nothing between the reload here
* and the last store does.
SGLINE LDA SGP
 STA ZPT1
 LDA SGP+1
 STA ZPT1+1
 LDY #0
SGL1 CPY SLEN
 BCS SGL2
 LDA SHFBUF,Y
 AND #$7F
 STA (ZPT1),Y
 INY
 JMP SGL1
SGL2 LDA #$0D
 STA (ZPT1),Y
 INY
 TYA
 CLC
 ADC SGP
 STA SGP
 LDA SGP+1
 ADC #0
 STA SGP+1
 TYA
 CLC
 ADC SGLEN
 STA SGLEN
 LDA SGLEN+1
 ADC #0
 STA SGLEN+1
 RTS

* ---- DSAVE: OA-S --------------------------------
DSAVE JSR EDFLSH
 LDA #<MSAVE
 STA STRPTR
 LDA #>MSAVE
 STA STRPTR+1
 JSR EPROMP
* DSV9 is a whole routine away - too far for a
* relative branch - so invert the test and jump.
 BCC DSV0
 JMP DSV9
* THE SAFE SAVE.  The old shape here was DESTROY
* then CREATE - ProDOS has no truncate, so a
* shorter program written into a longer file would
* keep the old tail, and the DESTROY was the cure.
* But from that DESTROY until the last WRITE and
* the CLOSE, the disk held no complete copy of the
* program: power lost there, or a drive door
* opened, lost the file.  So the lines now stream
* into a TEMPORARY file - the target's name plus
* .T - and only when it is safely closed is the
* old file DESTROYed and the temporary RENAMEd
* onto its name.  At no instant does the disk lack
* a complete copy, and the fresh temporary keeps
* the no-truncate cure for free.
* The name needs two spare characters for the .T -
* 13 of ProDOS's 15.  A longer one fails the
* CREATE cleanly with $40, nothing touched, and
* the operator picks a shorter name.
DSV0 JSR ENAME
 JSR ETMPBD
* a stray temporary from an interrupted save is
* deleted without comment; the result is ignored
 JSR EDTIDY
 LDA #<ETMPNB
 STA EPCPRM+1
 LDA #>ETMPNB
 STA EPCPRM+2
 LDA FTYPE
 STA EPCPRM+4
 LDA #0
 STA EPCPRM+5
 STA EPCPRM+6
 JSR EPCREA
 BCC DSV0A
 JMP DSVER
DSV0A JSR EOPENT
 BCC DSV0B
 JMP DSVDE
DSV0B JSR SGRST
 LDA #0
 STA SLINE
 STA SLINE+1
DSV1 LDA SLINE
 STA C1
 LDA SLINE+1
 STA C1+1
 LDA NLINES
 STA C2
 LDA NLINES+1
 STA C2+1
 JSR CMP16
 BCS DSV5
 LDA SLINE
 STA CLINE
 LDA SLINE+1
 STA CLINE+1
 JSR SHFGET
 JSR SGTRIM
* Flush now if fewer than 81 bytes are free - the
* most one line can add.  512 - 81 = 431, so the
* test is SGLEN >= 432, and 432 is $01B0.  Written
* as two explicit bytes because an immediate
* operand is one byte and 432 is not: CMP #432
* would not have meant what it looked like.
 LDA SGLEN+1
 CMP #STGFLH
 BCC DSV3
 BNE DSV2
 LDA SGLEN
 CMP #STGFLL
 BCC DSV3
DSV2 JSR SGFLSH
 BCS DSVCE
DSV3 JSR SGLINE
 INC SLINE
 BNE DSV4
 INC SLINE+1
DSV4 JMP DSV1
DSV5 JSR SGFLSH
 BCS DSVCE
 JSR EPCLOS
 BCS DSVDE
* the program is safe under the temporary name;
* now the two directory steps, both of them
* directory-only, no data moving.  A missing old
* file ($46) is the normal first save.  Any other
* refusal - locked, say - keeps BOTH files: the
* old one under its name, the new one as .T, and
* the error says which call balked.
 LDA #<FNBUF1
 STA EPDPRM+1
 LDA #>FNBUF1
 STA EPDPRM+2
 JSR EPDEST
 BCC DSV6
 CMP #$46
 BEQ DSV6
 JMP DSVER
* a RENAME failure also leaves the temporary
* alone: it is the only complete copy of the new
* text
DSV6 LDA #<ETMPNB
 STA EPRNPM+1
 LDA #>ETMPNB
 STA EPRNPM+2
 LDA #<FNBUF1
 STA EPRNPM+3
 LDA #>FNBUF1
 STA EPRNPM+4
 JSR EPRENA
 BCS DSVER
 JSR ESETNM
 LDA #<MSAVED
 LDX #>MSAVED
 JSR EMSG
DSV9 JMP EDFULL
* The CLOSE failed with every write clean: the
* temporary may be incomplete.  Drop it and
* report; the old file is exactly as it was.
DSVDE PHA
 JSR EDTIDY
 PLA
 JMP DSVER
* An error partway through leaves a file open, and
* an open file with no CLOSE loses the blocks it
* was holding.  Close it, drop the temporary - the
* old file is still whole - then report.
DSVCE PHA
 JSR EPCLOS
 JSR EDTIDY
 PLA
DSVER JSR EDERR
 JMP EDFULL

* ---- DOPEN: OA-O --------------------------------
DOPEN LDA #<MOPEN
 STA STRPTR
 LDA #>MOPEN
 STA STRPTR+1
 JSR EPROMP
* DOP9 and DOPER are both a routine away - too far
* for a relative branch - so invert and jump.
 BCC DOP0
 JMP DOP9
DOP0 JSR ENAME
 JSR EOPENF
 BCC DOP0B
 JMP DOPER
DOP0B LDA #0
 STA OLINE
 STA OLINE+1
 STA OCOL
 STA OFULL
 JSR SHFBLK
* ProDOS signals the end of a file by failing a
* READ with $4C once there is nothing left to give;
* a short count is not an error and not the end.
* So $4C is the ordinary way out of this loop, and
* any OTHER error is a real one and has to be said
* out loud - a disk fault that silently truncated
* the program would be indistinguishable from a
* file that simply ended.
DOP1 JSR EPRDST
 BCC DOP1A
 CMP #$4C
 BEQ DOP4
 PHA
 JSR EPCLOS
 PLA
 JMP DOPER
DOP1A LDA EPRWPM+6
 ORA EPRWPM+7
 BEQ DOP4
 LDA #<STAGE
 STA OPP
 LDA #>STAGE
 STA OPP+1
 LDA EPRWPM+6
 STA OREM
 LDA EPRWPM+7
 STA OREM+1
DOP2 LDA OREM
 ORA OREM+1
 BEQ DOP1
 JSR OGETB
 JSR OCHAR
 LDA OFULL
 BEQ DOP2
DOP4 JSR EPCLOS
* A last line with no carriage return after it is
* still a line.  Anything accumulated when the file
* ran out has to be stored, or the program loses
* its final statement to a missing byte.
 LDA OFULL
 BNE DOP5
 LDA OCOL
 BEQ DOP5
 JSR OSTORE
DOP5 LDA OLINE
 ORA OLINE+1
 BNE DOP6
* An empty file becomes one blank line, because a
* program is never empty - the same rule DDEL obeys
* when the last line is deleted.
 JSR SHFBLK
 LDA #0
 STA CLINE
 STA CLINE+1
 JSR SHFPUT
 LDA #1
 STA OLINE
 LDA #0
 STA OLINE+1
DOP6 LDA OLINE
 STA NLINES
 LDA OLINE+1
 STA NLINES+1
 LDA #0
 STA CURLIN
 STA CURLIN+1
 STA TOPLIN
 STA TOPLIN+1
 STA CURCOL
 STA LDIRTY
 JSR EDSTAL
 JSR ESETNM
 LDA OFULL
 BEQ DOP7
 LDA #<MFULL
 LDX #>MFULL
 JSR EMSG
DOP7 JMP EDFULL
DOPER JSR EDERR
DOP9 JMP EDFULL

* ---- OGETB: the next staged byte -> A -----------
* Masked to seven bits, so a file written in high
* ASCII by another program reads correctly.  The
* pointer is reloaded from memory on every byte
* rather than kept in zero page, because the loop
* that calls this also calls AXPUT at the end of
* every line and zone S does not survive that.  It
* costs about eight cycles a byte and it is the
* difference between a routine that is obviously
* right and one that has to be argued about.
OGETB LDA OPP
 STA ZPT1
 LDA OPP+1
 STA ZPT1+1
 LDY #0
 LDA (ZPT1),Y
 PHA
 INC OPP
 BNE OGB1
 INC OPP+1
OGB1 SEC
 LDA OREM
 SBC #1
 STA OREM
 LDA OREM+1
 SBC #0
 STA OREM+1
 PLA
 AND #$7F
 RTS

* ---- OCHAR: one imported character --------------
* $0D ends a line.  A tab moves four columns, which
* is exactly what TAB does when it is typed - the
* Area A to Area B step.  A tab in an imported file
* came from somebody else's editor and meant
* whatever their stops were, so this is a guess;
* it is at least the same guess the editor makes
* everywhere else.
* Any other control character is DROPPED rather
* than stored.  They are another program's
* convention and none of them mean anything here.
* A line longer than eighty columns is TRUNCATED,
* not refused.  Refusing would let one long line
* lock the operator out of an entire file, and this
* editor's line IS eighty columns - there is
* nowhere to put the rest.
OCHAR CMP #$0D
 BEQ OCEOL
 CMP #$09
 BEQ OCTAB
 CMP #$20
 BCC OCR
 LDY OCOL
 CPY #RECSZ
 BCS OCR
 STA SHFBUF,Y
 INC OCOL
OCR RTS
OCEOL JMP OSTORE
* Same grid as the editor's own TAB (columns 1, 5,
* 9, 13 ...): snap to the next multiple of four, not
* just add four, so an imported tab lands where a
* typed one would.
OCTAB LDA OCOL
 AND #$FC
 CLC
 ADC #4
 CMP #RECSZ
 BCC OCT1
 LDA #RECSZ
OCT1 STA OCOL
 RTS

* ---- OSTORE: SHFBUF -> record OLINE -------------
* Then a fresh blank line and back to column zero.
* If auxiliary memory has filled, OFULL stops the
* import and the operator keeps everything read so
* far - which is more useful than an error and an
* empty editor.
OSTORE LDA OLINE
 STA C1
 LDA OLINE+1
 STA C1+1
 LDA AXCAPV
 STA C2
 LDA AXCAPV+1
 STA C2+1
 JSR CMP16
 BCC OST1
 LDA #1
 STA OFULL
 RTS
OST1 LDA OLINE
 STA CLINE
 LDA OLINE+1
 STA CLINE+1
 JSR SHFPUT
 INC OLINE
 BNE OST2
 INC OLINE+1
OST2 LDA #0
 STA OCOL
 JMP SHFBLK

* ---- EOPENF: open FNBUF1, keep the reference ----
* ---- EOPENT: the same for the save's temporary --
* The reference number goes into both the read/
* write block and the close block at once, so no
* later call can be made against a stale one.
* Close everything first.  ProDOS error $56 on OPEN
* means the io_buffer overlaps one already in use -
* a file left open somewhere frees no buffer.  A
* CLOSE with reference 0 closes ALL open files and
* releases their buffers, so IOBUF is certainly free
* before we ask for it.  The editor never keeps a
* file open between operations, so this closes
* nothing it needs.  The result is ignored: with no
* files open it is a no-op.
EOPENF LDA #<FNBUF1
 STA EPOPRM+1
 LDA #>FNBUF1
 STA EPOPRM+2
 JMP EOPGO
EOPENT LDA #<ETMPNB
 STA EPOPRM+1
 LDA #>ETMPNB
 STA EPOPRM+2
EOPGO LDA #0
 STA EPCLPM+1
 JSR EPCLOS
 LDA #<IOBUF
 STA EPOPRM+3
 LDA #>IOBUF
 STA EPOPRM+4
 JSR EPOPEN
 BCS EOF9
 LDA EPOPRM+5
 STA EPRWPM+1
 STA EPCLPM+1
 CLC
EOF9 RTS

* ---- ETMPBD: ETMPNB = FNBUF1 + .T ---------------
* The names are absolute buffers, so plain indexed
* stores do it - no zero page borrowed.
ETMPBD LDX #0
ETB1 CPX FNBUF1
 BCS ETB2
 LDA FNBUF1+1,X
 STA ETMPNB+1,X
 INX
 JMP ETB1
ETB2 LDA #$2E
 STA ETMPNB+1,X
 INX
 LDA #$54
 STA ETMPNB+1,X
 INX
 STX ETMPNB
 RTS

* ---- EDTIDY: best-effort delete of the temp -----
EDTIDY LDA #<ETMPNB
 STA EPDPRM+1
 LDA #>ETMPNB
 STA EPDPRM+2
 JMP EPDEST

* ---- EPRDST: read one chunk into STAGE ----------
EPRDST LDA #<STAGE
 STA EPRWPM+2
 LDA #>STAGE
 STA EPRWPM+3
 LDA #<STGSZ
 STA EPRWPM+4
 LDA #>STGSZ
 STA EPRWPM+5
 JMP EPREAD

* ---- the MLI calls EDIT makes for itself --------
* FILEIO's wrappers are private to that module, and
* FLOAD/FSAVE move one contiguous buffer, which is
* exactly what a streamed file is not.  These are
* three lines each and the shape is identical every
* time, which is the whole point of the convention.
EPCREA JSR MLI
 DFB $C0
 DA EPCPRM
 RTS
EPDEST JSR MLI
 DFB $C1
 DA EPDPRM
 RTS
EPRENA JSR MLI
 DFB $C2
 DA EPRNPM
 RTS
EPOPEN JSR MLI
 DFB $C8
 DA EPOPRM
 RTS
EPREAD JSR MLI
 DFB $CA
 DA EPRWPM
 RTS
EPWRIT JSR MLI
 DFB $CB
 DA EPRWPM
 RTS
EPCLOS JSR MLI
 DFB $CC
 DA EPCLPM
 RTS

* ---- MLI parameter blocks -----------------------
* Access $C3 is destroy/rename/write/read.  Storage
* type 1 is a standard file.  Date and time are
* left at zero: with no clock ProDOS stamps a file
* with no date, which is what an unclocked IIe
* always did.
EPCPRM DFB 7
 DA 0
 DFB $C3
 DFB $47
 DA 0
 DFB 1
 DA 0
 DA 0
EPDPRM DFB 1
 DA 0
EPRNPM DFB 2
 DA 0
 DA 0
EPOPRM DFB 3
 DA 0
 DA 0
 DFB 0
EPRWPM DFB 4
 DFB 0
 DA 0
 DA 0
 DA 0
EPCLPM DFB 1
 DFB 0
