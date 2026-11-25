* CMPEMIT.S  the p-code emitter
* PUT from COMPILE.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* The design is COMPILE.md.  This file is the half
* of the compiler that knows what the interpreter
* eats, and it is deliberately the FIRST half
* written: PCODE.md 5 says the way to test the VM
* is a hand-assembled object of a dozen
* instructions, and this is that object without the
* hand-assembly.  The same routines that will one
* day emit every program are what prove the format.
*
* THREE AREAS, ALL IN MAIN MEMORY
* An object plus its data segment can never exceed
* 8K, because that is all the band the interpreter
* gives them.  So there is no case for putting the
* build areas in auxiliary memory, no allocator to
* write, and no bank to claim:
*   $9800 OBDESC  128 descriptors
*   $9C00 OBLIT   1024 bytes of pool
*   $A000 OBCODE  4096 bytes of code
* CMPEND must stay below OBDESC.  See BUILD.md 5.
* (That was the first layout.  Today: OBDESC $0800,
* 64 descriptors on text page 2; OBLIT $B400, 2,048
* bytes in the second and third file buffers; OBCODE
* $A500, 2,816 bytes.  CMPCON.S has the history.)
*
* EVERY OPERAND IS AN ITEM NUMBER, NEVER AN ADDRESS
* VDESC shifts the item number three times and adds
* the descriptor base; VADDR adds the data segment
* base.  So this file never computes an address for
* anything.  It hands out indices and offsets and
* lets the interpreter do the arithmetic - which is
* also why an object file can be loaded anywhere.

* ---- EMINIT: start a new object ----------------
* The pool starts ONE BYTE IN.  A descriptor's edit
* reference of zero means "no picture", so a picture
* that was the first literal - offset zero - was
* read as none, and MOVE to a $$,$9.99 item printed
* plain digits (2026-11-07).  Byte 0 is a pad.
EMINIT LDA #0
 STA CODLEN
 STA CODLEN+1
 STA OBLIT
 STA LITLEN+1
 LDA #1
 STA LITLEN
 LDA #0
 STA NLITS
 STA NITEMS
 STA NITEMS+1
 STA DSEG
 STA DSEG+1
 STA CMPERR
 RTS

* ---- EMB: emit the byte in A -------------------
* out: C=1 if the code area is full
EMB STA EMSAV
 LDA CODLEN+1
 CMP #>CODMAX
 BCC EMB1
 LDA CODLEN
 CMP #<CODMAX
 BCC EMB1
 LDA #1
 STA CMPERR
 SEC
 RTS
EMB1 LDA CODLEN
 STA EMXO
 LDA CODLEN+1
 STA EMXO+1
 LDA #<EMSAV
 STA EMXB
 LDA #>EMSAV
 STA EMXB+1
 LDA #1
 STA EMXN
 STZ EMXN+1
 SEC
 JSR EMXMOV
 INC CODLEN
 BNE EMB2
 INC CODLEN+1
EMB2 CLC
 RTS

* ---- EMW: emit the word in EMWV ----------------
* Low byte first, as everything on this machine is
* except a cursor key - see QUERY.md for the one
* place the system is big-endian and why.
EMW LDA EMWV
 JSR EMB
 BCS EMWX
 LDA EMWV+1
 JMP EMB
EMWX RTS

* ---- EMSETW: patch the word at offset EMWO ------
* The fixup primitive.  A forward branch's operand
* is written twice: once as a link in a chain, and
* once, later, as the answer.
EMSETW JSR EMXW
 SEC
 JMP EMXMOV

* ---- EMGETW: read the word at offset EMWO ------
EMGETW JSR EMXW
 CLC
 JMP EMXMOV

* EMXW: EMWV <-> the code at EMWO, two bytes
EMXW LDA EMWO
 STA EMXO
 LDA EMWO+1
 STA EMXO+1
 LDA #<EMWV
 STA EMXB
 LDA #>EMWV
 STA EMXB+1
 LDA #2
 STA EMXN
 STZ EMXN+1
 RTS

* ================= THE CODE, IN AUX ============
* ---- EMXMOV: bytes between main and the code ---
* in:  EMXO  offset in the code (0 = its first byte)
*      EMXB  the main-memory end of the move
*      EMXN  how many bytes, never 0 - AUXMOVE takes
*            an inclusive end, and 0 would be 64K
*      C=1   main -> the code (a write)
*      C=0   the code -> main (a read)
* The code lives at CODAUX in aux bank 0 (CMPCON.S
* says why).  The library's AXPUT and AXGET do the
* move, through the firmware's AUXMOVE; they take
* AXBANK, AXADDR, AXBUF and AXLEN, which are the
* LEXER'S too - it reads every source line through
* them.  It sets them all before each read, but this
* puts them back anyway, so no caller can ever be
* surprised.  They are seven bytes in a row at
* $0CF1, AXBANK to AXLEN+1 (EQUATES2.S).
*   A byte costs one AUXMOVE, about two hundred
* cycles with the saving and restoring: five
* thousand bytes of code is about a second.
EMXMOV PHP
 LDX #6
EMXM1 LDA AXBANK,X
 STA EMXSV,X
 DEX
 BPL EMXM1
 STZ AXBANK
 CLC
 LDA #<CODAUX
 ADC EMXO
 STA AXADDR
 LDA #>CODAUX
 ADC EMXO+1
 STA AXADDR+1
 LDA EMXB
 STA AXBUF
 LDA EMXB+1
 STA AXBUF+1
 LDA EMXN
 STA AXLEN
 LDA EMXN+1
 STA AXLEN+1
 PLP
 BCC EMXM2
 JSR AXPUT
 JMP EMXM3
EMXM2 JSR AXGET
EMXM3 LDX #6
EMXM4 LDA EMXSV,X
 STA AXBANK,X
 DEX
 BPL EMXM4
 RTS
EMXO DS 2
EMXB DS 2
EMXN DS 2
EMXSV DS 7

* ================= DESCRIPTORS =================
* ---- EMDESC: add one, return its item number ----
* in:  DTYP DLENV DDECV DFLGV DOFFV DEDTV
* out: EMIT = the item number, C=1 if full
* The eight bytes are exactly what VDESC copies out
* and VADDR reads - type, length, decimals, flags,
* offset into the data segment, editref into the
* pool.
EMDESC LDA NITEMS+1
 BNE EMDF
 LDA NITEMS
 CMP #DESCMX
 BCS EMDF
* address = OBDESC + item * 8
 LDA NITEMS
 STA EMT
 LDA #0
 STA EMT+1
 ASL EMT
 ROL EMT+1
 ASL EMT
 ROL EMT+1
 ASL EMT
 ROL EMT+1
 CLC
 LDA #<OBDESC
 ADC EMT
 STA ZPT1
 LDA #>OBDESC
 ADC EMT+1
 STA ZPT1+1
 LDY #0
 LDA DTYP
 STA (ZPT1),Y
 INY
 LDA DLENV
 STA (ZPT1),Y
 INY
 LDA DDECV
 STA (ZPT1),Y
 INY
 LDA DFLGV
 STA (ZPT1),Y
 INY
 LDA DOFFV
 STA (ZPT1),Y
 INY
 LDA DOFFV+1
 STA (ZPT1),Y
 INY
 LDA DEDTV
 STA (ZPT1),Y
 INY
 LDA DEDTV+1
 STA (ZPT1),Y
 LDA NITEMS
 STA EMIT
 LDA NITEMS+1
 STA EMIT+1
 INC NITEMS
 BNE EMD1
 INC NITEMS+1
EMD1 CLC
 RTS
EMDF LDA #2
 STA CMPERR
 SEC
 RTS

* ---- EMDLEN: patch item EMIT's length to A ------
* A group's length is not known when its descriptor
* is written - it is the sum of everything
* subordinate, and none of that has been read yet.
* So the descriptor goes out with a length of zero
* and this puts the measurement in afterwards.
EMDLEN STA EMSAV
 LDA EMIT
 STA EMT
 LDA EMIT+1
 STA EMT+1
 ASL EMT
 ROL EMT+1
 ASL EMT
 ROL EMT+1
 ASL EMT
 ROL EMT+1
 CLC
 LDA #<OBDESC
 ADC EMT
 STA ZPT1
 LDA #>OBDESC
 ADC EMT+1
 STA ZPT1+1
 LDY #1
 LDA EMSAV
 STA (ZPT1),Y
 RTS

* ---- EMALLOC: give an item DLENV bytes ----------
* Storage is handed out in declaration order and
* nothing is ever aligned: a NUM8 cell is eight
* bytes wherever it lands, and the interpreter
* reaches it through an offset, not a pointer.
EMALLOC LDA DSEG
 STA DOFFV
 LDA DSEG+1
 STA DOFFV+1
 CLC
 LDA DSEG
 ADC DLENV
 STA DSEG
 LDA DSEG+1
 ADC #0
 STA DSEG+1
 RTS

* ================= THE LITERAL POOL ============
* ---- EMLIT: append LITBUF (LITN bytes) ---------
* out: EMLO = the offset, C=1 if the pool is full
* Pooled by value, so MOVE ZERO a hundred times
* costs nine bytes once.
EMLIT JSR EMFIND
 BCC EMLX
 CLC
 LDA LITLEN
 ADC LITN
 STA EMT
 LDA LITLEN+1
 ADC #0
 STA EMT+1
 LDA EMT+1
 CMP #>LITMAX
 BCC EMLA
 BNE EMLF
 LDA EMT
 CMP #<LITMAX
 BCS EMLF
EMLA LDA LITLEN
 STA EMLO
 LDA LITLEN+1
 STA EMLO+1
 CLC
 LDA #<OBLIT
 ADC LITLEN
 STA ZPT1
 LDA #>OBLIT
 ADC LITLEN+1
 STA ZPT1+1
 LDY #0
EML1 CPY LITN
 BCS EML2
 LDA LITBUF,Y
 STA (ZPT1),Y
 INY
 JMP EML1
EML2 LDA EMT
 STA LITLEN
 LDA EMT+1
 STA LITLEN+1
 JSR EMFADD
EMLX CLC
 RTS
EMLF LDA #3
 STA CMPERR
 SEC
 RTS

* ---- EMFIND: is LITBUF already in the pool? -----
* out: C=0 and EMLO set if it is, C=1 if not
*
* IT WALKS THE ENTRY TABLE, NOT THE POOL.  Searching
* the pool byte by byte is the obvious way and it is
* wrong: the pool is not self-describing - a text
* literal carries a length byte but a NUM8 cell is
* nine anonymous bytes - so a nine-byte cell can
* match starting halfway through a piece of text and
* hand back an offset that points at nothing.  The
* interpreter would then read a literal that was
* never written.
*
* So each entry's start AND length are recorded as
* they are added, three bytes apiece, and a match
* has to agree on both.  Sixty-four distinct
* literals is more than an eight-kilobyte program
* will ever hold.
EMFIND LDX #0
EMF1 CPX NLITS
 BCS EMFNO
 STX TMPX
 TXA
 ASL
 CLC
 ADC TMPX
 TAY
 LDA LTAB+2,Y
 CMP LITN
 BNE EMF3
 LDA LTAB,Y
 STA EMT
 LDA LTAB+1,Y
 STA EMT+1
 CLC
 LDA #<OBLIT
 ADC EMT
 STA ZPT1
 LDA #>OBLIT
 ADC EMT+1
 STA ZPT1+1
 LDY #0
EMF2 CPY LITN
 BCS EMFYES
 LDA (ZPT1),Y
 CMP LITBUF,Y
 BNE EMF3
 INY
 JMP EMF2
EMF3 INX
 JMP EMF1
EMFYES LDA EMT
 STA EMLO
 LDA EMT+1
 STA EMLO+1
 CLC
 RTS
EMFNO SEC
 RTS

* ---- EMFADD: record the entry just added --------
* in: EMLO = its offset, LITN = its length
EMFADD LDA NLITS
 CMP #LITSMX
 BCS EMFA9
 STA TMPX
 ASL
 CLC
 ADC TMPX
 TAY
 LDA EMLO
 STA LTAB,Y
 LDA EMLO+1
 STA LTAB+1,Y
 LDA LITN
 STA LTAB+2,Y
 INC NLITS
EMFA9 RTS

* ---- EMLTXT: a text literal from LITBUF+1 -------
* in: LITN = the text length.  Builds the length
* byte in front of it, which is the form MOVL and
* DISPL both read.
*
* No shifting: every caller already leaves LITBUF+0
* free for the length.  There used to be a loop here
* moving the text up one byte, as if it started at
* LITBUF+0 - so each literal got a stray byte in
* front and lost its last letter: "MEDIA.DAT" was
* stored as ?MEDIA.DA, ZZZ9 as ?ZZZ, and every
* DISPLAY "..." printed one character off
* (2026-11-07).
EMLTXT LDA LITN
 STA LITBUF
 INC LITN
 JMP EMLIT

* ---- EMLNUM: a numeric literal ------------------
* in: LITBUF = an eight-byte NUM8 cell,
*     LITSCL = its scale
* Nine bytes: the cell, then ONE BYTE OF SCALE.
* That trailing byte is what lets PUSHL put a
* literal on the expression stack with its scale
* intact - the cell itself does not carry one.
EMLNUM LDA LITSCL
 STA LITBUF+NCELL
 LDA #NCELL+1
 STA LITN
 JMP EMLIT

* ================= INSTRUCTIONS ================
* Helpers, not a code generator.  The parser knows
* which instruction it wants; these know how many
* bytes it takes and in what order.

* ---- EMOP: opcode only --------------------------
EMOP JMP EMB

* ---- EMOP1: opcode + one word -------------------
* in: A = opcode, EMWV = the word
EMOP1 JSR EMB
 BCS EMO1X
 JMP EMW
EMO1X RTS

* ---- EMOP2: opcode + two words ------------------
* in: A = opcode, EMWV = first, EMWV2 = second
* THE DESTINATION IS THE FIRST WORD.  VMOVN calls
* VOPD before VOPS, so MOVE X TO Y emits Y then X -
* the opposite order to the way COBOL writes it,
* and the easiest thing in the machine to get
* backwards.  Backwards it still runs, and moves
* the wrong way.
EMOP2 JSR EMB
 BCS EMO2X
 JSR EMW
 BCS EMO2X
 LDA EMWV2
 STA EMWV
 LDA EMWV2+1
 STA EMWV+1
 JMP EMW
EMO2X RTS

* ---- EMARI: an arithmetic instruction -----------
* in: A = opcode, EMWV = dest, EMWV2 = source,
*     EMMODE = the ROUNDED byte
EMARI JSR EMOP2
 BCS EMARX
 LDA EMMODE
 JMP EMB
EMARX RTS

* ---- EMLINE: the LINE marker --------------------
* in: EMWV = the source line number
* Three bytes and a store, and it is the difference
* between SIZE ERROR and SIZE ERROR AT LINE 47.
EMLINE LDA #OLINE
 JMP EMOP1

* ================= FIXUPS ======================
* A forward branch's operand is written twice: once
* as a link in a chain, and once, later, as the
* answer.  The chain lives IN THE CODE STREAM, so
* it costs no memory at all - the placeholder word
* holds the offset of the previous placeholder, and
* the symbol holds the head.
*
* ---- EMREF: emit a reference to FIXHD -----------
* in:  A = opcode, FIXHD = the symbol's chain head
*      ($FFFF if there are no references yet)
* out: FIXHD updated to point at the word just
*      emitted
EMREF JSR EMB
 BCS EMRX
 LDA CODLEN
 STA EMT
 LDA CODLEN+1
 STA EMT+1
 LDA FIXHD
 STA EMWV
 LDA FIXHD+1
 STA EMWV+1
 JSR EMW
 BCS EMRX
 LDA EMT
 STA FIXHD
 LDA EMT+1
 STA FIXHD+1
 CLC
EMRX RTS

* ---- EMFIX: resolve the chain at FIXHD ----------
* in: FIXHD = the head, EMTGT = the real offset
* Each link is read out BEFORE it is overwritten,
* which is the whole trick: the placeholder is the
* list.
EMFIX LDA FIXHD
 CMP #$FF
 BNE EMFX1
 LDA FIXHD+1
 CMP #$FF
 BEQ EMFXD
EMFX1 LDA FIXHD
 STA EMWO
 LDA FIXHD+1
 STA EMWO+1
 JSR EMGETW
 LDA EMWV
 STA EMT
 LDA EMWV+1
 STA EMT+1
 LDA EMTGT
 STA EMWV
 LDA EMTGT+1
 STA EMWV+1
 JSR EMSETW
 LDA EMT
 STA FIXHD
 LDA EMT+1
 STA FIXHD+1
 JMP EMFIX
EMFXD LDA #$FF
 STA FIXHD
 STA FIXHD+1
 RTS

* ---- EMDGET: read descriptor EMIT back ----------
* The compiler has to know what it already said an
* item was, because which MOVE to emit is decided
* from the two descriptors' types and nothing else.
* Reading them back is cheaper than a second table
* saying the same thing twice.
EMDGET LDA EMIT
 STA EMT
 LDA EMIT+1
 STA EMT+1
* $FFF0-$FFF3 is a subscript slot: describe the
* table item it holds (FIXLIST A2).  $FFFF, which
* means "none" to EVALUATE TRUE, is left alone.
 CMP #$FF
 BNE EMDG1
 LDA EMIT
 CMP #$F4
 BCS EMDG1
 CMP #$F0
 BCC EMDG1
 AND #3
 TAY
 LDA PDSLL,Y
 STA EMT
 LDA PDSLH,Y
 STA EMT+1
EMDG1 ASL EMT
 ROL EMT+1
 ASL EMT
 ROL EMT+1
 ASL EMT
 ROL EMT+1
 CLC
 LDA #<OBDESC
 ADC EMT
 STA ZPT1
 LDA #>OBDESC
 ADC EMT+1
 STA ZPT1+1
 LDY #0
 LDA (ZPT1),Y
 STA DTYP
 INY
 LDA (ZPT1),Y
 STA DLENV
 INY
 LDA (ZPT1),Y
 STA DDECV
 INY
 LDA (ZPT1),Y
 STA DFLGV
 RTS
