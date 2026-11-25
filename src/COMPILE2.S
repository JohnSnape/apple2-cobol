* COMPILE2.S  the compiler, pass two
* Menu option 5, second of two overlays.
*
* COMPILE1.S's header explains the split and why the
* handover works.  The short version: the four build
* areas live above $9C00, the overlay band ends at
* $9BFF, so this overlay loads over pass one's code
* and finds pass one's descriptors, literal pool,
* symbol table and p-code exactly as they were left.
* CMPXFR at $1F00 carries the ten values that would
* otherwise have moved with the code.
*
* ================= WHAT PASS TWO DOES ==========
* The PROCEDURE DIVISION - paragraph names, the
* verbs, the fixup chains - and then the object
* writer, which is here and not in pass one because
* it runs last and needs numbers only this pass
* knows.
*
* IT RESUMES, IT DOES NOT RESTART.  Pass one stopped
* on the word PROCEDURE and left LEXLN on the line
* after it, so this pass carries straight on.  The
* one limit that follows: the PROCEDURE DIVISION
* header must be the last thing on its line.  It is
* in SKEL.COB and in all three sample programs, and
* it is cheaper to say so than to make pass two scan
* the whole source again looking for a word it has
* already been told the position of.
 XC
 PUT EQUATES
 PUT EQUATES2
 PUT CMPCON

 ORG LOWBASE
* the object goes straight to disk as it assembles,
* which also keeps it out of memory - BUILD.md 3.
* If your Merlin rejects the pathname, use the bare
* name and copy from SRC to OBJ afterwards.
 DSK /COBOL/OBJ/COMPILE2
 JMP C2START

* The PUT order is the ORIGINAL code order with the
* pass-one files left out - CMPEMIT, CMPOBJ,
* CMPLEX, CMPSYM, then CMPPROC.  Keeping the
* relative order is not fussiness: PUT concatenates
* at the line, so two files that fell through into
* one another still do.
 PUT CMPEMIT
 PUT CMPCOM
 PUT CMPOBJ
 PUT CMPLEX
 PUT CMPSYM
 PUT CMPPROC
 PUT CMPPROC2
 PUT CMPPROC3
 PUT CMPPROC4
 PUT CMPARITH
 PUT CMPSET
 PUT CMPCOND

* ---- C2START: the pass two driver ---------------
* NO EMINIT HERE.  EMINIT zeroes CODLEN, LITLEN,
* NITEMS, DSEG and CMPERR - which is exactly the
* work pass one did, and calling it would throw away
* the whole DATA DIVISION while leaving the
* descriptors sitting at $9C00 to be overwritten by
* nothing.  Pass two initialises only what is its
* own: the literal entry table, which starts empty
* because this pass never refers to a VALUE literal.
C2START LDA CMPPHS
 CMP #1
 BEQ C2GO
 JMP C2NOP1
* LEXCOL is per-pass scratch, so this pass loads
* with it at zero, and LEXNEXT would rescan
* whatever is in LEXBUF from one byte before it.
* 81 means "past the end of this line": the next
* token comes from line LEXLN, which pass one left
* pointing just past PROCEDURE DIVISION.
C2GO LDA #81
 STA LEXCOL
 STZ NLITS
 STZ PDHELD
 STZ PDQDEP
 JSR PROCDIV
 LDA CMPERR
 BNE C2BAD
* PROCDIV stops quietly on a lexer error (PDX) with
* CMPERR still zero - which wrote a half-compiled
* object and said "Compiled".  31 or 32 now.
 LDA LEXERR
 BEQ C2LEXOK
 CLC
 ADC #30
 STA CMPERR
 JMP C2BAD
C2LEXOK
* WILL IT FIT TO RUN?  The menu loads the object at
* RUNBASE ($8000 since 2026-11-22, was $9200) and
* the VM lays WORKING-STORAGE straight after the
* code, so object and data together must end at
* $B000, where the first file buffer starts -
* RUNMAX, 12,288 bytes (was 7,680).  Nothing
* checked this until 2026-11-12: a big enough
* program ran with its data on top of ProDOS's
* buffers and said nothing.  Refused here, where
* the student can still do something about it.
 JSR C2SIZE
 BCC C2SZOK
 LDA #49
 STA CMPERR
 JMP C2BAD
C2SZOK
* the object: header, descriptors, pool, code.  It
* is written from CODLEN, LITLEN, NITEMS and DSEG,
* three of which pass one set and this pass added
* to.
* THE OBJECT'S NAME COMES FROM THE EDITOR, and until
* now nothing set it at all.  CMPWRT opens FNBUF1,
* and neither pass had ever put anything there - so
* the object went to whatever name the last FISPLT
* happened to leave behind.  That is EDIT's source
* name if you saved before compiling, and something
* else entirely if you did not: the library, most
* likely, overwritten with p-code.
*
* SRCNAM is the program name EDIT published in
* SRCXFR on its way out, so it is the right answer
* and it is already there.  FISPLT folds it to upper
* case into FNBUF1 - through SPLITNM, the jump-table
* vector, because FISPLT is FILEIO's own label and
* the compiler is a different assembly.  The TYPE is
* not taken from the
* suffix - COCR hardcodes $4A OBJ - so FIRST.COB
* compiles to FIRST.OBJ and the two sit side by side.
 LDA #<SRCNAM
 STA FNAMP
 LDA #>SRCNAM
 STA FNAMP+1
* TEST.COB compiles to TEST.OBJ: the suffix is
* REPLACED (X=1).  With the suffix part of the name,
* keeping the source's would write the object over
* the source.
 LDA #$4A
 LDX #1
 JSR SETSFX
 JSR CMPWRT
 BCS C2WERR
 JMP C2DONE
C2BAD JMP C2SHOW
* A write that fails has a ProDOS error in A, not a
* CMPERR, so it gets its own message rather than
* being reported as a compile error it is not.
C2WERR PHA
 JSR CMCR
 LDA #<MC2WRT
 STA STRPTR
 LDA #>MC2WRT
 STA STRPTR+1
 JSR CONPUTS
 PLA
 STA NFVAL
 STZ NFVAL+1
 STZ NFVAL+2
 JSR NFCOMMA
 LDA #<NFBUF
 STA STRPTR
 LDA #>NFBUF
 STA STRPTR+1
 JSR CONPUTS
 JSR CMCR
 JMP WAITKEY

* ---- pass two on its own ------------------------
* Only reachable if something loaded this overlay
* without running pass one.  It refuses, because a
* PROCEDURE DIVISION compiled against an empty
* symbol table does not fail - every data name is
* simply unknown, which is error 15 on the first
* statement, and that is a confusing way to be told
* the compiler was driven wrongly.
C2NOP1 JSR CMCR
 LDA #<MC2SEQ
 STA STRPTR
 LDA #>MC2SEQ
 STA STRPTR+1
 JSR CONPUTS
 JSR CMCR
 JMP WAITKEY

* ---- C2DONE: the sizes, so the operator can see -
C2DONE JSR CMCR
 LDA #<MC2OK
 STA STRPTR
 LDA #>MC2OK
 STA STRPTR+1
 JSR CONPUTS
 LDA CODLEN
 STA NFVAL
 LDA CODLEN+1
 STA NFVAL+1
 STZ NFVAL+2
 JSR NFCOMMA
 LDA #<NFBUF
 STA STRPTR
 LDA #>NFBUF
 STA STRPTR+1
 JSR CONPUTS
 JSR CMCR
 JMP WAITKEY

* ---- C2SHOW: the error and the line -------------
C2SHOW JSR CMCR
 LDA #<MC2ERR
 STA STRPTR
 LDA #>MC2ERR
 STA STRPTR+1
 JSR CONPUTS
 LDA CMPERR
 STA NFVAL
 STZ NFVAL+1
 STZ NFVAL+2
 JSR NFCOMMA
 LDA #<NFBUF
 STA STRPTR
 LDA #>NFBUF
 STA STRPTR+1
 JSR CONPUTS
* and what it means, from the library (CMPMSG, slot
* 105, ERRMSG.S) - added 2026-11-07
 LDA #$20
 JSR CONPUTC
 LDA CMPERR
 JSR CMPMSG
 JSR CONPUTS
 JSR CMCR
 LDA #<MC2LIN
 STA STRPTR
 LDA #>MC2LIN
 STA STRPTR+1
 JSR CONPUTS
 LDA TOKLIN
 STA NFVAL
 LDA TOKLIN+1
 STA NFVAL+1
 STZ NFVAL+2
 JSR NFCOMMA
 LDA #<NFBUF
 STA STRPTR
 LDA #>NFBUF
 STA STRPTR+1
 JSR CONPUTS
* and the line in a COPY book, if it was in one
 JSR LXSHCP
 JSR CMCR
 JMP WAITKEY

* ---- C2SIZE: object + data over RUNMAX? --------
* The object is the header, eight bytes for each
* item, the literal pool and the code - the same
* sum CMPHDR makes for the offsets - and the data
* segment is DSEG.  Sixteen bits throughout; a
* carry out of any add is too big already.
* out: C=1 too big.  EMT is borrowed: CMPHDR sets
* it again when the object is written.
C2SIZE LDA NITEMS
 STA EMT
 LDA NITEMS+1
 STA EMT+1
 ASL EMT
 ROL EMT+1
 ASL EMT
 ROL EMT+1
 ASL EMT
 ROL EMT+1
 CLC
 LDA EMT
 ADC #HDRLEN
 STA EMT
 LDA EMT+1
 ADC #0
 STA EMT+1
 CLC
 LDA EMT
 ADC LITLEN
 STA EMT
 LDA EMT+1
 ADC LITLEN+1
 STA EMT+1
 BCS C2SZB
 CLC
 LDA EMT
 ADC CODLEN
 STA EMT
 LDA EMT+1
 ADC CODLEN+1
 STA EMT+1
 BCS C2SZB
 CLC
 LDA EMT
 ADC DSEG
 STA EMT
 LDA EMT+1
 ADC DSEG+1
 STA EMT+1
 BCS C2SZB
* RUNMAX < EMT is too big; equal just fits
 LDA #<RUNMAX
 CMP EMT
 LDA #>RUNMAX
 SBC EMT+1
 BCC C2SZB
 CLC
 RTS
C2SZB SEC
 RTS

* ---- CMCR: a new line at the menu's column ------
* The compiler talks under the menu it was started
* from, so every line it prints starts where the
* menu's lines do (MENUCOL) rather than at the left
* edge.  The longest - PROCEDURE DIVISION error,
* the number and the longest text in ERRMSG.S -
* still ends inside column 80.
CMCR JSR CONCR
 LDA #MENUCOL
 STA SCRCOL
 RTS

MC2ERR DFB 25
 ASC 'PROCEDURE DIVISION error '
MC2LIN DFB 9
 ASC 'at line  '

MC2OK DFB 18
 ASC 'Compiled.  bytes: '
MC2SEQ DFB 28
 ASC 'Pass one has not run - stop '
MC2WRT DFB 21
 ASC 'Cannot write object  '

 PUT CMPVAR
