* VM.S  the p-code interpreter
* An overlay at $8000, like every other one: the
* menu BLOADs it, JSRs $8000, and gets an RTS back
* when the program stops.  A compiled program is
* the object file at $9200; the interpreter walks
* it.  PCODE.md is the specification this file
* implements, and the one to read first.
*
* ================= THE SHAPE OF IT ==============
* Fetch a byte, look it up in a table, jump.  Each
* handler sets up two pointers and calls a library
* vector.  That is the whole machine, and it is
* small for one reason: the runtime is real.  An
* ADD opcode is nine instructions and a JSR into
* code that was written, tested and understood two
* chapters ago.
*
* THREE THINGS CHANGED SINCE THE INSTRUCTION-SET
* CHAPTER WAS WRITTEN, and the chapter is the one
* that is wrong:
*
* 1. THE REGISTERS MOVED TO ZONE P.  The chapter
*    puts IP at $18 and CCND at $20.  $18-$1F is
*    zone S, which every service is free to destroy,
*    and $20 upward belongs to the monitor.  The
*    registers live at $60-$7F now - zone P, which
*    the Golden Rule keeps every service out of.
*    That rule exists precisely so IP, SP and DP can
*    stay live across the dozen library calls one
*    opcode makes.
*
* 2. NUM8 REPLACED COMP-3.  The chapter's eight
*    descriptor types collapse to six, because
*    num-display, packed and signed are now the same
*    thing: one 8-byte cell.  Scale did not go away
*    - it moved out of the data and into the
*    descriptor, where the interpreter can read it.
*    That is why alignment happens HERE and not in
*    the compiler: we can see both scales, so the
*    compiler no longer has to emit a shift before
*    every arithmetic instruction.
*
* 3. THE INTERPRETER IS AN OVERLAY, NOT A $6000
*    RESIDENT.  The overlay band is the only 12K
*    that is free in both worlds, so the interpreter
*    takes the bottom 2K of it and the program takes
*    the rest.  A compiled program run from the menu
*    returns to the menu; the same object run from a
*    launch stub returns to ProDOS.  Same addresses
*    either way.
*
* ================= MEMORY =================
*   $6000-$7FFF  this interpreter (7,051 bytes on
*                2026-11-22; a page of it is the
*                dispatch table)
*   $8000        the object: header, descriptors,
*                literal pool, p-code
*   after it     the data segment - working storage,
*                never in the file, because VALUE
*                clauses compile to instructions in
*                the prologue
*
* That leaves a program 12K for code and data
* together ($8000-$AFFF; it was 7.5K from $9200 until
* 2026-11-22).  If it ever binds, the answer is not to
* shrink the interpreter: in the standalone world
* there is no menu at $2000, so the interpreter
* moves down there and the whole band becomes the
* program's.  Same object file either way - nothing
* in it holds an address of its own.
*
* ================= WHAT IS NOT HERE =============
* The forms engine ($D0-$D3) traps: SCRSHOW and
* SCRINP are still overlay files with floating entry
* points, so compiled p-code cannot call them.  The
* BASIC block ($C0-$CF) traps and always will in
* this build.  A trap is not a crash - it names the
* opcode and the source line and returns to the
* menu.
*
* THE FILE OPCODES ARE HERE, since 2026-08-16:
* $90-$96, in VMFILE, over RECMAN in the library.
* SEVEN OPCODES AND ONE HANDLER - the interpreter
* had 217 bytes left and seven handlers of the usual
* shape would have been three times that.  VMLOOP
* leaves the opcode in X, so one handler can tell
* which of the seven it is.
*
* THE QUERY VERB IS HERE, since 2026-08-15: $D4,
* $D5, $D7 and $D8, in VMQRY.  It is the first of
* the $D0-$DF services to be wired up, and it could
* be first precisely because every library routine
* underneath it was already written - the engine
* was finished months before there was a way to say
* it in COBOL.

* ---- where the object goes ----------------------
* MOVED $9000 -> $9200 on 2026-08-16, when the file
* opcodes went in and the interpreter came out 33
* bytes over.
*
* IT IS ONE LINE AND IT COSTS ALMOST NOTHING,
* which is worth understanding rather than just
* doing.  Nothing in an object file holds an address
* - PCODE.md 2 - so the base is free to move; and
* the COMPILER cannot build an object bigger than
* 4,096 bytes anyway, because its three build areas
* are OBDESC 512 + OBLIT 512 + OBCODE 3072.  The 8K
* that object and data segment shared was already
* over-provisioned by the other end of the tool
* chain.  512 of it buys the interpreter room for
* everything it still owes: the three counted
* PERFORMs, CLASS, ACCEPT FROM DATE, the two printer
* opcodes and ACCEPT FROM KEY, about 290 bytes
* between them.
*
* What it costs is 512 bytes of WORKING-STORAGE in
* the largest possible program.  What it buys is
* every remaining opcode.
*
* MOVED $9200 -> $8000 on 2026-11-22 (the user:
* "we need space for our users").  The interpreter
* had grown to 7,051 bytes and ended at $7B8A, so
* $7B8B-$91FF was 5.7K that nothing used.  $8000
* leaves it 1,141 bytes to grow and gives programs
* 12,288 bytes instead of 7,680.  Objects already
* compiled run unchanged - they hold no address.
* RUNBASE in EQUATES2.S must say the same.
OBJBASE EQU $8000

* The equates come first: every register below is
* ZPDRV plus something, and an EQU cannot use a
* symbol Merlin has not met yet.  (They used to be
* PUT further down, after ORG - an illegal forward
* reference on all thirteen lines.)
 PUT EQUATES
 PUT EQUATES2

* ---- zone P: the register file ----
* Nothing else may touch $60-$7F WHILE VM RUNS.  The
* FORMAT and QUERY overlays borrow the bottom of it
* for their own pointers, which is safe because an
* overlay and the VM are never in memory together.
VMIP EQU ZPDRV
VMDP EQU ZPDRV+2
VMLP EQU ZPDRV+4
VMDT EQU ZPDRV+6
VMO1 EQU ZPDRV+8
VMO2 EQU ZPDRV+10
VMPT EQU ZPDRV+12
VMJP EQU ZPDRV+14
VMRSP EQU ZPDRV+16
VMESP EQU ZPDRV+17
VMCC EQU ZPDRV+18
VMEXC EQU ZPDRV+19
VMHLT EQU ZPDRV+20
* VMT1 is the general address temp, and VMMATH reads
* through (VMT1),Y - so it must be zero page.  It was
* a DS 2 in VMTAIL.
VMT1 EQU ZPDRV+21

* ---- stack depths ----
* Here, not in VMTAIL with the stacks themselves:
* VMMATH and VMFLOW test against them first, and a
* small EQU met after its use is an ILLEGAL FORWARD
* REFERENCE to Merlin 8.
VMEDEP EQU 8
VMRDEP EQU 16

* ---- descriptor layout (8 bytes) ----
DTYPE EQU 0
DLEN EQU 1
DDEC EQU 2
DFLG EQU 3
DOFF EQU 4
DEDT EQU 6

* ---- item types ----
TALPHA EQU 0
TNUM EQU 1
TBIN EQU 2
TBOOL EQU 3
TGROUP EQU 4
TEDIT EQU 5

 ORG LOWBASE
* the object goes straight to disk as it assembles,
* which also keeps it out of memory - BUILD.md 3.
* If your Merlin rejects the pathname, use the bare
* name and copy from SRC to OBJ afterwards.
 DSK /COBOL/OBJ/VM
 JMP VMRUN
* XC turns on the 65C02 opcodes.  SYSBOOT already
* REFUSES to boot without a 65C02 - CHK65 - so the
* machine is guaranteed to have one, and until now
* we were paying that compatibility cost and taking
* none of the benefit.  STZ is the one that earns
* its keep: LDA #0 followed by a run of STA becomes
* a run of STZ, two bytes shorter every time.
 XC

* ================= THE VM, IN PIECES =============
* VM is a STUB.  Each part of the interpreter is its
* own source file, PUT in below in the original
* order - so the assembled bytes are identical to
* the former single file.  Merlin holds only this
* file in the editor and streams the rest from disk,
* which is what keeps it inside the editor's limits;
* the whole interpreter is larger than Merlin can
* hold at once.
* JMP VMRUN above lands on the first byte of VMCORE.
 PUT VMCORE
 PUT VMLOOP
 PUT VMMOVE
 PUT VMMATH
 PUT VMFLOW
 PUT VMSCRN
 PUT VMQRY
 PUT VMFILE
 PUT VMTAIL
