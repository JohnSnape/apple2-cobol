* VMTAIL.S  faults, the dispatch table, variables
* PUT from VM.S - no ORG, not assembled alone.
* One symbol table spans every PUT.
*
* ================= FAULTS =================
* A trap is not a crash.  It says which opcode, and
* which line of the program, and comes back to the
* menu - which is the difference between a system
* you can develop on and one you reboot.
VBAD LDA #<MOPC
 LDX #>MOPC
 JMP VMDIE

* THE STACK IS RESET, NOT UNWOUND.  A fault can be
* raised from inside a helper that was reached by
* JSR - VRPUSH is one - so there may be return
* addresses on the 6502 stack that lead back into
* an instruction we are abandoning.  The stack
* pointer saved at entry is the only thing that
* gets us out cleanly.
VMDIE STA STRPTR
 STX STRPTR+1
 LDX VMSTK
 TXS
 JSR CONCR
 JSR CONPUTS
 JSR CONCR
 LDA #<MLINE
 STA STRPTR
 LDA #>MLINE
 STA STRPTR+1
 JSR CONPUTS
 LDA VMLINE
 STA NFVAL
 LDA VMLINE+1
 STA NFVAL+1
 LDA #0
 STA NFVAL+2
 JSR NFCOMMA
 LDA #<NFBUF
 STA STRPTR
 LDA #>NFBUF
 STA STRPTR+1
 JSR CONPUTS
 JSR CONCR
 JSR WAITKEY
 LDA #1
 STA VMHLT
 RTS

* ================= THE DISPATCH TABLE ==========
* Two tables of 256 bytes, low byte and high byte.
* Everything not an instruction points at VBAD, so
* a byte that was never an opcode faults instead of
* being executed - which matters most when a jump
* has gone wrong and the machine is walking through
* data.
VTLO DFB <VNOP,<VHALT,<VLINE,<VENTER
* Runs of VBAD are written out one DFB at a time.
* They were DS n,<VBAD - Merlin 8 cannot take a label
* as a DS fill byte: Unknown label, and 2 bytes, not
* n.  One short run shifts every opcode above it.
* Each run keeps its count as a comment.
* 12 x <VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD
 DFB <VMOVA,<VMOVN,<VMOVE,<VMOVG
 DFB <VMOVL,<VMOVF,<VINIT,<VMOVD
* $18 SUBS, then 23 x <VBAD
 DFB <VSUBS,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VADDP,<VBAD,<VSUBP,<VBAD
 DFB <VMULP,<VBAD,<VDIVP,<VBAD
* 24 x <VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VPUSHD,<VPUSHL,<VPOPD,<VEADD
 DFB <VESUB,<VEMUL,<VEDIV,<VENEG
* $58 POPDR, $59 SZON, $5A SZCHK, $5B SZSKP,
* then 4 x <VBAD
 DFB <VPOPDR,<VSZON,<VSZCK,<VSZSK,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VCMPN,<VCMPA,<VCLASS,<VBRA
 DFB <VBEQ,<VBNE,<VBLT,<VBGT
 DFB <VBLE,<VBGE,<VBSIZ,<VBEXC
* 4 x <VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD
 DFB <VPERF,<VBAD,<VBAD,<VBAD
 DFB <VRET,<VGOTO
* 10 x <VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD
 DFB <VDISP,<VDISPL,<VAT,<VACC
 DFB <VDISPN,<VACCF,<VNL,<VACCA
 DFB <VDISPP,<VDISPPL,<VDISPLN
* $8B ERASE, $8C SETPR, $8D SETPX, $8E MENU
* (2026-11-11), $8F CASE (2026-11-12)
 DFB <VERASE,<VSETPR,<VSETPX,<VMENU,<VCASE
 DFB <VFILE,<VFILE,<VFILE,<VFILE
 DFB <VFILE,<VFILE,<VFILE
* $97 DISPPN, $98 DISPPLN (2026-11-22)
 DFB <VDISPPN,<VDISPPLN
* $99 FNAME (2026-11-22, DECISIONS 8.11)
 DFB <VFNAMA
* 6 x <VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
* $A0-$D2: tables, strings, BASIC, and the forms
* half of the services.  All still traps.
* 51 x <VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD
* $D3-$D8: the query block.  QBE stays trapping on
* purpose - the thing that WRITES a .QRY is the
* QUERY overlay an operator runs from the menu, and
* a running program has no business building one.
 DFB <VBAD,<VQOPEN,<VQNEXT
 DFB <VBAD,<VQSORT,<VQFLD
* 39 x <VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD
 DFB <VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD,<VBAD

VTHI DFB >VNOP,>VHALT,>VLINE,>VENTER
* 12 x >VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD
 DFB >VMOVA,>VMOVN,>VMOVE,>VMOVG
 DFB >VMOVL,>VMOVF,>VINIT,>VMOVD
* $18 SUBS, then 23 x >VBAD
 DFB >VSUBS,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VADDP,>VBAD,>VSUBP,>VBAD
 DFB >VMULP,>VBAD,>VDIVP,>VBAD
* 24 x >VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VPUSHD,>VPUSHL,>VPOPD,>VEADD
 DFB >VESUB,>VEMUL,>VEDIV,>VENEG
* $58 POPDR, $59 SZON, $5A SZCHK, $5B SZSKP,
* then 4 x >VBAD
 DFB >VPOPDR,>VSZON,>VSZCK,>VSZSK,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VCMPN,>VCMPA,>VCLASS,>VBRA
 DFB >VBEQ,>VBNE,>VBLT,>VBGT
 DFB >VBLE,>VBGE,>VBSIZ,>VBEXC
* 4 x >VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD
 DFB >VPERF,>VBAD,>VBAD,>VBAD
 DFB >VRET,>VGOTO
* 10 x >VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD
 DFB >VDISP,>VDISPL,>VAT,>VACC
 DFB >VDISPN,>VACCF,>VNL,>VACCA
 DFB >VDISPP,>VDISPPL,>VDISPLN
* $8B ERASE, $8C SETPR, $8D SETPX, $8E MENU
* (2026-11-11), then 1 x >VBAD
 DFB >VERASE,>VSETPR,>VSETPX,>VMENU,>VCASE
 DFB >VFILE,>VFILE,>VFILE,>VFILE
 DFB >VFILE,>VFILE,>VFILE
* $97 DISPPN, $98 DISPPLN (2026-11-22)
 DFB >VDISPPN,>VDISPPLN
* $99 FNAME (2026-11-22, DECISIONS 8.11)
 DFB >VFNAMA
* 6 x >VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
* 51 x >VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD
 DFB >VBAD,>VQOPEN,>VQNEXT
 DFB >VBAD,>VQSORT,>VQFLD
* 39 x >VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD
 DFB >VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD,>VBAD

* ---- figurative constants ----
VFIGT DFB $20,$30,$FF,$00,$22

* ---- messages ----
MEND DFB 24
 ASC 'STOP RUN. (Press a Key) '
MSIG DFB 26
 ASC 'Not a p-code object file  '
MLANG DFB 26
 ASC 'Wrong interpreter for this'
MOPC DFB 22
 ASC 'Unknown instruction   '
MESTK DFB 22
 ASC 'Expression stack fault'
MRSTK DFB 22
 ASC 'PERFORM stack fault   '
MLINE DFB 9
 ASC 'at line  '
MDIV0 DFB 14
 ASC 'Divide by zero'
MSIZE DFB 10
 ASC 'Size error'
MSUBR DFB 23
 ASC 'Subscript out of range '
MPAUSE DFB 20
 ASC 'Press a key to go on'
MBIG DFB 22
 ASC 'Program too big to run'

* ================= VARIABLES ===================
* VMEDEP and VMRDEP, the two stack depths, are in
* VM.S: VMMATH and VMFLOW compare against them first,
* and Merlin 8 must meet a small EQU before its use.
VMW DS 2
* VMT1 is zero page now - VMHLT+1 in VM.S - because
* VMMATH reads through (VMT1),Y.
VMT2 DS 2
VMD DS 8
VMD1 DS 8
VMD2 DS 8
VMLINE DS 2
VMMODE DFB 0
* 1 while POPDR is storing: VALIGN rounds
VMRND DFB 0
* SUBS: four slot descriptors, and its scratch
VMSUBD DS 32
VMSS DFB 0
VMSO DFB 0
VMSN DFB 0
VMSW DFB 0
VMSTK DFB 0
* $40 UPPERCASE ONLY, 0 ANYCASE - what ACCEPT does
* with a typed letter.  VMRUN sets $40, the default;
* only a program that says ANYCASE emits $8F 0.
VMCASE DFB $40
VMCB DS 2
VMSCR DS 8
* VEDIV's shift and its cap
VMEK DFB 0
VMELZ DFB 0
* size errors (VMMATH): checking on, what one store
* collected, VFIT's count, the receiver as it was
VMSZM DFB 0
VMSZP DFB 0
VMSZT DFB 0
VMSAV DS 8
VMESTK DS 64
VMESCL DS 8
VMRSTK DS 32
* VMRMK: the paragraph each pending PERFORM ends at,
* one byte per VMRSTK entry (plus one, because VPERF
* writes it before VRPUSH checks for overflow)
VMRMK DS 17
PICWRK DS 20
* VMTLEN and VMTXT are one length-prefixed string
* in two pieces, so ACCEPT can hand what was typed
* straight to PICDEED without copying it.
VMNONL DFB 0
* the printer: VPRMOD 1 while a DISPLAY goes to it,
* VPRON 1 once PRINIT has run in this program
VPRMOD DFB 0
VPRON DFB 0
VMTLEN DFB 0
VMTXT DS 24
* SET PRINTER TO SCREEN (VMSCRN): VPRSCR 1 while it
* is in force, VPGN lines on the screen since it was
* cleared, VPGB blank lines held back
VPRSCR DFB 0
VPGN DFB 0
VPGB DFB 0
* 1 while a multi-operand printer line is open on
* the screen (VPLBEG, 2026-11-22)
VPLIN DFB 0
* SET PREFIX and FROM PREFIX: the number, the text
VPXN DFB 0
VPXBUF DS 66
* the menu: flags, line count, keys found, the
* centring offsets, where the lines start, the box,
* and the keys themselves
VMNF DFB 0
VMNC DFB 0
VMNK DFB 0
VMNDR DFB 0
VMNDC DFB 0
VMNIP DS 2
VMNR0 DFB 0
VMNR1 DFB 0
VMNC0 DFB 0
VMNC1 DFB 0
VMNN DFB 0
VMNT1 DFB 0
VMNL DFB 0
VMNI DFB 0
VMNKEY DS 24
VMSIZE EQU *
