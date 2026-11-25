* COMPILE1.S  the compiler, pass one
* Menu option 5, first of two overlays.
*
* ================= WHY TWO =====================
* One overlay did not fit.  With the QUERY statement
* in, CMPEND landed about 210 bytes above OBDESC at
* $9C00 - which is the descriptor table the compiler
* is building, so the first symptom would have been
* an object whose descriptors were p-code.
*
* Splitting it costs a second copy of the emitter,
* the lexer and the symbol table in each pass -
* about 1.8K - and buys about 3K of head room in
* each.  The reason it works AT ALL is that the four
* build areas are OUTSIDE the overlay band:
*
*   $9C00 OBDESC   the descriptors
*   $9E00 OBLIT    the literal pool
*   $A000 SYMTAB   64 names of 16 bytes
*   $A400 OBCODE   the p-code
* (the first layout; they have all moved since -
* CMPCON.S says where and why)
*
* Every one of them is above $9C00 and the band ends
* at $9BFF, so pass two loads over pass one's code
* and finds the whole of pass one's WORK untouched.
* Nothing is written to disk between the passes and
* nothing is copied.  That is not luck - it is what
* separating code from data was for, one level up.
*
* WHAT DOES NOT SURVIVE is anything CMPVAR declares
* with DS, because the two passes are different
* sizes and DS space lands at different addresses in
* each.  The handover set is EQUated into CMPXFR at
* $1F00 instead; CMPVAR's header says which values
* those are and why each one is in the list.
*
* ================= WHAT PASS ONE DOES ==========
* IDENTIFICATION and ENVIRONMENT (skipped, for now,
* except that this is where SPECIAL-NAMES will be
* read), then the DATA DIVISION: levels, PICTURE,
* VALUE, OCCURS, 88s, the group measure, and the
* ENTER whose size is patched when the division
* closes.  It stops on the word PROCEDURE and leaves
* LEXLN pointing at the line after it.
 XC
 PUT EQUATES
 PUT EQUATES2
 PUT CMPCON

 ORG LOWBASE
* the object goes straight to disk as it assembles,
* which also keeps it out of memory - BUILD.md 3.
* If your Merlin rejects the pathname, use the bare
* name and copy from SRC to OBJ afterwards.
 DSK /COBOL/OBJ/COMPILE1
 JMP C1START

 PUT CMPEMIT
 PUT CMPCOM
 PUT CMPLEX
 PUT CMPSYM
 PUT CMPPIC
 PUT CMPDATA
 PUT CMPDATA2
 PUT CMPFILE
 PUT CMPENV

* ---- C1START: the pass one driver ---------------
* The source is already in auxiliary memory: EDIT
* put it there and published SRCXFR on its way out.
* Nothing is read from disk to compile - which is
* what COMPILE.md 5 means by compiling needing no
* disk once the source is loaded.
C1START JSR C1SRC
 BCC C1S1
 JMP C1NOSRC
C1S1 JSR EMINIT
 STZ CMPPHS
 STZ NOCC
 STZ TBOPEN
 LDA #$FF
 STA QSTITM
 STA QSTITM+1
 JSR LEXINIT
 JSR DATDIV
 BCS C1BAD
* PROCEDURE DIVISION found inside a COPY book would
* leave pass two to start in the middle of the book,
* which it cannot (the book is read again only by a
* COPY): error 47 (CMPLEX.S)
 LDA CPYON
 BEQ C1S2
 LDA #47
 STA CMPERR
 BRA C1BAD
C1S2
* DATDIV stopped on PROCEDURE and LEXLN is already
* pointing past that line, so pass two has only to
* carry on from where it stands.  LEXLN is in the
* handover set for exactly this.
 LDA #1
 STA CMPPHS
 RTS
* An error in pass one is reported here and pass two
* is never loaded - SYSMENU tests CMPERR between the
* two RUNOVLs.  Compiling a PROCEDURE DIVISION
* against a symbol table that was never finished
* would produce an object file rather than a
* message, which is the worst of the two failures.
C1BAD JSR C1SHOW
 RTS

* ---- C1SRC: take the source from SRCXFR ---------
* out: C=1 there is nothing in aux to compile
*
* THE GEOMETRY IS RESTORED, NOT ASSUMED.  AXSHIFT
* and AXRSZ are global and the query engine sets its
* own record size, so between EDIT and here they may
* be anything at all.  The editor wrote down what it
* used; this puts it back.  AXCAP recomputes the
* capacity from them, which is what AMMAP divides
* by.
C1SRC LDA SRCSIG
 CMP #$53
 BNE C1SRNO
 LDA SRCSIG+1
 CMP #$52
 BNE C1SRNO
 LDA SRCLIN
 ORA SRCLIN+1
 BEQ C1SRNO
 LDA SRCLIN
 STA NSRC
 LDA SRCLIN+1
 STA NSRC+1
 LDA SRCSHF
 STA AXSHIFT
 LDA SRCRSZ
 STA AXRSZ
 STA AXLEN
 STZ AXLEN+1
 LDA NBANKS
 BNE C1SR1
 JSR FINDBNK
C1SR1 JSR AXCAP
 CLC
 RTS
C1SRNO SEC
 RTS

* ---- nothing to compile -------------------------
* An empty aux is not an error in the compiler, it
* is an operator who pressed 5 before 1.  Saying so
* beats error 6 out of DATDIV, which would be true
* and unhelpful.
C1NOSRC JSR CMCR
 LDA #<MC1NOS
 STA STRPTR
 LDA #>MC1NOS
 STA STRPTR+1
 JSR CONPUTS
 JSR CMCR
 JSR WAITKEY
* CMPERR is what SYSMENU tests to decide whether to
* load pass two, so it has to be non-zero here even
* though no compiling was attempted.
 LDA #7
 STA CMPERR
 RTS

* ---- C1SHOW: say what went wrong ----------------
* A lexer error leaves CMPERR at zero - and SYSMENU
* would then load pass two over a half-read DATA
* DIVISION.  It becomes 31 or 32 here, which both
* stops the compile and gets it a message.
C1SHOW LDA CMPERR
 BNE C1SH1
 LDA LEXERR
 CLC
 ADC #30
 STA CMPERR
C1SH1 JSR CMCR
 LDA #<MC1ERR
 STA STRPTR
 LDA #>MC1ERR
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
 LDA #<MC1LIN
 STA STRPTR
 LDA #>MC1LIN
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

MC1ERR DFB 20
 ASC 'DATA DIVISION error '
MC1LIN DFB 9
 ASC 'at line  '
MC1NOS DFB 31
 ASC 'Nothing to compile - EDIT first'

 PUT CMPVAR
