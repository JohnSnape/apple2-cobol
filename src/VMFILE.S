* VMFILE.S  the file opcodes - $90 to $96
* PUT from VM.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* ================= ONE HANDLER, SEVEN OPCODES ===
* Every other group in the interpreter has a handler
* per opcode.  This one cannot afford to: VM had 217
* bytes left below $9000 when RECMAN made these
* reachable, and seven handlers of the ordinary
* shape would have been three times that.
*
* THE OPCODE IS STILL IN X.  VMLOOP does TAX before
* it indexes the dispatch table, so a handler is
* entered with its own opcode in X and can tell
* which of seven it is - which is what lets all
* seven table slots point here.  That is not a trick
* invented for this file; it is a property of the
* loop that was there all along and had not been
* used.
*
* ================= ONE OPERAND SHAPE ============
* The seven verbs want different things, and giving
* them different instruction layouts would put the
* difference in the interpreter.  They share one
* layout instead, ten bytes, and the differences are
* in what the fields MEAN:
*
*   ctl  b   bits 0-1  which file, 0 or 1
*            bits 4-7  OPEN: the mode
*                      READ: non-zero means NEXT
*   op1  w   OPEN: the pathname, an offset into the
*                  literal pool
*            else: the item holding the RELATIVE KEY
*   op2  w   the record area item - the 01 under the
*            FD.  $FFFF if the verb has no record
*   st   w   the FILE STATUS item, or $FFFF
*   tgt  w   AT END / INVALID KEY, or $FFFF
*
* $FFFF means absent, the same convention the query
* verb uses and for the same reason: it is not a
* valid item number and not a valid code offset.
*
* ================= WHAT IS NOT HERE =============
* No file control block, no mode checking, no status
* codes.  All of that is RECMAN's, in the library,
* where a second front end could reach it too.  This
* file is nine instructions of plumbing and a table.

* ---- $90-$96: every file verb -------------------
VFILE TXA
 AND #7
 STA VFIX
 JSR VFETCH
 STA VFCTL
 PHA
 AND #3
 STA RMFNO
 PLA
 LSR
 LSR
 LSR
 LSR
 STA RMMODE
* the four words, in order, into one block - which
* is why they are declared adjacent
 LDX #0
VFL1 JSR VFETW
 LDA VMW
 STA VFO1,X
 LDA VMW+1
 STA VFO1+1,X
 INX
 INX
 CPX #8
 BCC VFL1

* ---- op1: a pathname for OPEN, a key otherwise --
 LDA VFIX
 BNE VFL2
 LDA VFCTL
 AND #4
 BNE VFNAM
 CLC
 LDA VFO1
 ADC VMLP
 STA RMNAMP
 LDA VFO1+1
 ADC VMLP+1
 STA RMNAMP+1
 JMP VFL3

* ---- ASSIGN TO a data name (2026-11-22) ---------
* ctl bit 2: op1 is the ITEM that holds the name,
* read now, at this OPEN - so one SELECT can open
* EAST.DAT and later WEST.DAT.  RECMAN wants a
* length-prefixed name, which a PIC X item is not:
* it is a fixed width, space filled.  So the name is
* copied into VFNBUF with the trailing spaces off
* and its letters upper cased (ProDOS names are
* capitals, and a name MOVEd from a literal keeps
* the case it was typed in).  Sixty-four characters
* at most, ProDOS's limit for a whole pathname; a
* prefix such as 1/ is expanded later by RECMAN as
* it is for a quoted name.  An empty name opens
* nothing and RECMAN says so in FILE STATUS.
VFNAM LDA VFO1
 STA VMW
 LDA VFO1+1
 STA VMW+1
 JSR VOPD2
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
* The WHOLE item is trimmed, then measured.  It was
* cut to 64 first, and a longer name in a wide item
* opened its first 64 characters - another file,
* perhaps (DECISIONS 8.10).  Over 64 now goes on as
* "!", a name ProDOS can only refuse: FILE STATUS
* "31", as for any other bad name (PREFIX.S).
 LDY VMD2+DLEN
* back over the trailing spaces
VFN2 CPY #0
 BEQ VFN4
 DEY
 LDA (ZPT2),Y
 CMP #$20
 BEQ VFN2
 INY
VFN4 CPY #65
 BCC VFN4A
 LDA #$21
 STA VFNBUF+1
 LDA #1
 STA VFNBUF
 BRA VFN6
VFN4A STY VFNBUF
* then copy what is left, last byte first; $61-$7A
* are the lower-case letters (hex, not 'a': Merlin's
* editor upper-cases a quoted constant)
VFN5 DEY
 BMI VFN6
 LDA (ZPT2),Y
 CMP #$61
 BCC VFN7
 CMP #$7B
 BCS VFN7
 AND #$DF
VFN7 STA VFNBUF+1,Y
 JMP VFN5
VFN6 LDA #<VFNBUF
 STA RMNAMP
 LDA #>VFNBUF
 STA RMNAMP+1
 JMP VFL3

VFL2 LDX #0
 JSR VFARG
 BEQ VFL3
 JSR VQGETN
 LDA VMW
 STA RMREC
 LDA VMW+1
 STA RMREC+1

* ---- op2: the record area, and its LENGTH -------
* THE RECORD LENGTH COMES OUT OF THE DESCRIPTOR.
* An FD whose 01 is sixty bytes opens a sixty-byte
* file, and nobody has to say so twice - which is
* the whole reason RMLEN is an input to OPEN OUTPUT
* rather than something the programmer declares.
VFL3 LDX #2
 JSR VFARG
 BEQ VFL4
 JSR VOPD2
 LDA VMO2
 STA RMBUF
 LDA VMO2+1
 STA RMBUF+1
 LDA VMD2+DLEN
 STA RMLEN
 STZ RMLEN+1

* ---- READ NEXT is READ with the nibble set ------
* The mode nibble means something only to OPEN, so
* it is free on every other verb.  Spending a whole
* opcode on the difference between READ and READ
* NEXT would have been the eighth of seven.
VFL4 LDA VFIX
 CMP #2
 BNE VFL5
 LDA RMMODE
 BEQ VFL5
 LDA #7
 STA VFIX

* ---- call RECMAN --------------------------------
VFL5 LDA VFIX
 ASL
 TAX
 LDA VFTAB,X
 STA VMJP
 LDA VFTAB+1,X
 STA VMJP+1
 JSR VFGO
 PHP

* ---- READ NEXT tells the program WHERE it is ----
* COBOL puts the number of the record a READ NEXT
* delivered into the RELATIVE KEY.  RECMAN hands it
* back in RMREC and nothing stored it, so a listing
* showed every record as 1 and MEDIA, counting its
* records that way, wrote its next item over record
* 2 (2026-11-07).
 BCS VFNK
 LDA VFIX
 CMP #7
 BNE VFNK
 LDX #0
 JSR VFARG
 BEQ VFNK
 LDA RMREC
 STA BINVAL
 LDA RMREC+1
 STA BINVAL+1
 JSR VQPUTN
VFNK

* ---- the two FILE STATUS characters -------------
 LDX #4
 JSR VFARG
 BEQ VFL6
 JSR VOPD2
 LDA VMO2
 STA ZPT2
 LDA VMO2+1
 STA ZPT2+1
 LDY #0
 LDA RMSTAT
 STA (ZPT2),Y
 INY
 LDA RMSTAT+1
 STA (ZPT2),Y

* ---- AT END / INVALID KEY -----------------------
* One branch for both, taken on RECMAN's carry.
* Which of them it was is in the FILE STATUS item -
* "10" is at end and "23" is an invalid key - and a
* program that needs to tell them apart has
* EVALUATE, exactly as it does for CRT STATUS.
VFL6 PLP
 BCC VFL7
 LDX #6
 JSR VFARG
 BEQ VFL7
 JMP VBRA2
VFL7 JMP VMLOOP

* ---- VFGO: JSR through VMJP ---------------------
* The 6502 has no indirect JSR and the 65C02 does
* not add one.  A JSR to a JMP indirect is the whole
* of the workaround, and it costs three bytes once
* instead of a compare chain seven deep.
VFGO JMP (VMJP)

* ---- VFARG: VMW = the word at VFO1,X ------------
* out: Z=1 if it is $FFFF - the clause was absent
* Fetching an operand and testing whether it is
* there were two routines and four pairs of calls.
* They are one routine and four calls, which is
* twenty bytes in a file that had none to spare.
VFARG LDA VFO1,X
 STA VMW
 LDA VFO1+1,X
 STA VMW+1
 AND VMW
 CMP #$FF
 RTS

* ---- the RECMAN vectors, in opcode order --------
* Seven opcodes and eight entries: READ NEXT is the
* eighth and has no opcode of its own.
*
* THESE ARE JUMP-TABLE ADDRESSES, not RECMAN's
* labels.  The interpreter is one assembly and the
* library is another; RMOPEN means nothing here, and
* writing it would have assembled to zero and jumped
* into the bottom of the data region.  Everything
* that crosses that line goes through $3000.
VFTAB DA FILOPEN
 DA FILCLOS
 DA FILREAD
 DA FILWRIT
 DA FILREWR
 DA FILDEL
 DA FILSTRT
 DA FILNEXT

* ---- variables ----------------------------------
* VFO1 VFO2 VFST VFTG are adjacent ON PURPOSE: the
* fetch loop and both helpers index them as one
* eight-byte block.
VFIX DFB 0
* the ctl byte, kept for its bit 2 (ASSIGN TO a data
* name), and the name built from that item
VFCTL DFB 0
VFNBUF DS 65
VFO1 DFB $FF,$FF
VFO2 DFB $FF,$FF
VFST DFB $FF,$FF
VFTG DFB $FF,$FF
