* CMPPROC2.S  PROCEDURE DIVISION, part 2 of 3
* PERFORM, GO TO, STOP; the QUERY verb; operands.
* PUT from COMPILE2.S straight after CMPPROC - no
* ORG, not assembled alone.  Split from CMPPROC.S
* (51K) on 2026-11-07: Merlin 8 cannot PUT a file
* over about 24K.  The bytes assembled are the same.

* ================= PERFORM, GO TO, STOP ========
* (moved here from the end of CMPPROC.S on
* 2026-11-07 to keep that file under Merlin 8's
* 24K PUT limit - same order, same bytes)

* ---- PERFORM para [THRU para] -------------------
* PERF carries its own return offset and needs no
* fixup for it: the instruction is five bytes, so
* the return is the offset of the opcode plus five,
* and that is known at the moment of emission.
* PERFORM para                    PERF
* PERFORM para THRU para          PERF  (THRU is
*    read and dropped: the range's last paragraph
*    ends in the RET either way)
* PERFORM para UNTIL cond         lowers to
*     L: <cond, false-branch to X>   ...no, to:
*     L: CMPx / B<inv> X
*        PERF para
*        BRA L
*     X:
*    which is a loop with the test at the top, as
*    the standard says - the paragraph runs zero
*    times if the condition starts true.
* PERFORM n TIMES                 is not in, and
*    says so - error 29 - because the only honest
*    lowering needs a hidden counter item, and the
*    compiler has no way to allocate one after the
*    DATA DIVISION has closed.
PDPERF JSR PDNEXT
 BCC PDPF2A
 RTS
* the first word decides: UNTIL, VARYING, a count, or
* a paragraph name (PDPF4, CMPPROC4.S)
PDPF2A JMP PDPF4
* PERFORM UNTIL cond ... END-PERFORM - the INLINE
* form, which all three sample programs use for their
* main loop.  The word after PERFORM is UNTIL and not
* a paragraph.  The loop top and the exit go on the
* IF stack, so END-PERFORM can find them the way
* END-IF finds its IF; the entry is marked with the
* high bit so END-IF and END-PERFORM cannot close
* each other's scope by mistake.
PDPF00
* the paragraph name is in TOKBUF.  Copy it aside:
* the UNTIL test, if there is one, is parsed FIRST
* so the loop top is above the PERF
 LDX #0
PDPF0 LDA TOKBUF,X
 STA PDPNAM,X
 INX
 CPX #31
 BCC PDPF0
 LDA TOKLEN
 STA PDPNLN
* THRU?  UNTIL?  neither?
* the range ends at the paragraph named here, not
* at the target: PDPEND records which.  The name used
* to be read and thrown away, so THRU did nothing.
 STZ PDPEND
 DEC PDPEND
 JSR PDQOPT
 BCS PDPF1
 CMP #24
 BEQ PDPFTH
 CMP #19
 BNE PDPF0A
PDPFTH JSR PDWORD
 BCS PDPF1
 JSR PDPIDX
 BCS PDPX
 JSR PDQOPT
 BCS PDPF1
PDPF0A CMP #20
 BEQ PDPF2
 CMP #25
 BNE PDPF0B
 STZ PDPINF
 JMP PDPVAR
PDPF0B LDA #1
 STA PDHELD
* ---- the plain PERF, or para n TIMES (PDPTO) ----
PDPF1 JMP PDPTO
* ---- PERFORM ... UNTIL ----
PDPF2 LDA CODLEN
 STA PDPTOP
 LDA CODLEN+1
 STA PDPTOP+1
 LDA #1
 STA PDCTRU
 JSR PDCOND
 BCS PDPX
 LDA PDT
 STA PDPXIT
 LDA PDT+1
 STA PDPXIT+1
 JSR PDPEMT
 LDA CMPERR
 BNE PDPX
* back to the top
 LDA PDPTOP
 STA EMWV
 LDA PDPTOP+1
 STA EMWV+1
 LDA #OBRA
 JSR EMOP1
 BCS PDPX
* and the false branch lands here
 LDA PDPXIT
 STA PDT
 LDA PDPXIT+1
 STA PDT+1
 JMP PDIHERE
PDPX RTS

* ---- the inline PERFORM UNTIL -------------------
*     L: <cond, TRUE -> X>
*        ...statements...
*        BRA L
*     X:
PDPINL LDA CODLEN
 STA PDPTOP
 LDA CODLEN+1
 STA PDPTOP+1
 LDA #1
 STA PDCTRU
 JSR PDCOND
 BCS PDPIX
* push the TOP and the EXIT placeholder, in that
* order, with the top marked inline
 LDA PDT
 STA PDPXIT
 LDA PDT+1
 STA PDPXIT+1
 LDA PDPTOP
 STA PDT
 LDA PDPTOP+1
 ORA #$80
 STA PDT+1
 JSR PDIPUSH
 LDA PDPXIT
 STA PDT
 LDA PDPXIT+1
 STA PDT+1
 JMP PDIPUSH
PDPIX RTS

* ---- END-PERFORM --------------------------------
PDENDPF JSR PDIPOP
 LDA PDT
 STA PDPXIT
 LDA PDT+1
 STA PDPXIT+1
 JSR PDIPOP
 LDA PDT+1
 BMI PDEP1
 LDA #30
 STA CMPERR
 RTS
PDEP1 AND #$7F
 STA EMWV+1
 LDA PDT
 STA EMWV
 LDA #OBRA
 JSR EMOP1
 BCS PDEPX
 LDA PDPXIT
 STA PDT
 LDA PDPXIT+1
 STA PDT+1
 JMP PDIHERE
PDEPX RTS

* ---- PDPEMT: PERF <the name in PDPNAM> ----------
* The paragraph name goes into TOKBUF because that
* is where SYMFIND looks - which wiped the token
* PDQOPT had just HELD for the next statement.  So
*   PERFORM SHOW-MENU
*   PERFORM GET-CHOICE
* came back as the statement "SHOW-MENU": error 12
* (MEDIA, 2026-11-07).  The whole token - type,
* length, column, line, text - is put back after.
PDPEMT JSR TKSAVE
 JSR PDPEM0
 PHP
 JSR TKREST
 PLP
 RTS
* TOKTYP..TOKBUF are one 45-byte block in CMPVAR
TKSAVE LDX #44
TKS1 LDA TOKTYP,X
 STA TKSAV,X
 DEX
 BPL TKS1
 RTS
TKREST LDX #44
TKR1 LDA TKSAV,X
 STA TOKTYP,X
 DEX
 BPL TKR1
 RTS
PDPEM0 LDX #0
PDPE0 LDA PDPNAM,X
 STA TOKBUF,X
 INX
 CPX #31
 BCC PDPE0
 LDA PDPNLN
 STA TOKLEN
 LDA CODLEN
 STA PDT
 LDA CODLEN+1
 STA PDT+1
 LDA #OPERF
 JSR PDREF
 LDA CMPERR
 BNE PDPEX
 CLC
 LDA PDT
 ADC #6
 STA EMWV
 LDA PDT+1
 ADC #0
 STA EMWV+1
 JSR EMW
 BCS PDPEX
* the paragraph the range ENDS at - the target, or
* the THRU paragraph - so RET knows when to return.
* SYMIX is the target's, from PDREF.
 LDA PDPEND
 CMP #$FF
 BNE PDPE9
 LDA SYMIX
PDPE9 JMP EMB
PDPEX RTS
* PDPIDX: TOKBUF names a paragraph -> PDPEND, entered
* undefined if it has not been seen (as PDREF does)
PDPIDX JSR SYMFIND
 BCC PDPI9
 LDA #$FF
 STA SYMVAL
 STA SYMVAL+1
 LDA #KPARA
 JSR SYMADD
 BCS PDPIZ
PDPI9 LDA SYMIX
 STA PDPEND
 CLC
PDPIZ RTS

* ---- GO TO para ---------------------------------
PDGOTO JSR PDWORD
 BCS PDGX
 JSR PDWORD
 BCS PDGX
 LDA #OGOTO
 JMP PDREF
PDGX RTS

* ---- STOP RUN / GOBACK --------------------------
* STOP takes its RUN first, through PDWORD, the way
* GO takes its TO.  It used not to, and RUN was
* left behind as the next statement - error 12, an
* unknown verb, on the last line of every program
* (2026-11-07).  GOBACK is one word and comes
* straight to PDSTOP.
PDSTRUN JSR PDWORD
 BCC PDSTOP
 LDA #12
 STA CMPERR
 RTS
PDSTOP LDA #OHALT
 JMP EMOP

* ================= THE QUERY VERB ==============
* Four forms off one keyword, told apart by the word
* after it.  A quoted name means the long form; NEXT,
* SORT and FIELD are the other three.
*
*   QUERY q USING d {FOR n | OF f}
*         [GIVING c] [ON ERROR stmt]
*   QUERY NEXT [GIVING r] [AT END stmt]
*   QUERY SORT [ON ERROR stmt]
*   QUERY FIELD n INTO x
*
* TWO STATED LIMITS, both cheaper to write down than
* to discover.  The clause takes exactly ONE
* statement - there is no END-QUERY, so there is
* nothing to say where a second would stop.  And
* that statement may not itself be a QUERY, which
* PDQDEP enforces, because this parser keeps its
* working values in variables and not on a stack.
PDQUERY LDA PDQDEP
 BEQ PDQ0
 JMP PDQBAD
PDQ0 JSR PDNEXT
 BCS PDQBAD
 LDA TOKTYP
 CMP #TKSTR
 BNE PDQ1
* a quoted name: the long form.  PDOSTR is PDOPND's
* string arm and puts the text in the literal pool
* exactly as an operand would be.
 JSR PDOSTR
 BCS PDQX
 JMP PDQOPEN
PDQ1 CMP #TKWORD
 BNE PDQBAD
 JSR PDQKW
 BCS PDQBAD
 CMP #0
 BNE PDQ2
 JMP PDQNXT
PDQ2 CMP #1
 BNE PDQ3
 JMP PDQSRT
PDQ3 CMP #2
 BEQ PDQ4
PDQBAD LDA #16
 STA CMPERR
PDQX RTS
PDQ4 JMP PDQFLD

* ---- QUERY q USING d {FOR n|OF f} ---------------
PDQOPEN LDA PDVAL
 STA PDQQ
 LDA PDVAL+1
 STA PDQQ+1
 JSR PDQNEED
 BCS PDQBAD
 CMP #3
 BNE PDQBAD
 JSR PDNEXT
 BCS PDQBAD
 LDA TOKTYP
 CMP #TKSTR
 BNE PDQBAD
 JSR PDOSTR
 BCS PDQX
 LDA PDVAL
 STA PDQD
 LDA PDVAL+1
 STA PDQD+1
 JSR PDQNEED
 BCS PDQBAD
 CMP #4
 BEQ PDQFOR
 CMP #5
 BEQ PDQOF
 JMP PDQBAD
* FOR n: a literal count rides in the instruction
* (src 2), a data name is read at run time (src 0).
PDQFOR JSR PDNEXT
 BCS PDQBAD
 LDA TOKTYP
 CMP #TKNUM
 BEQ PDQFN
 CMP #TKWORD
 BNE PDQBAD
 JSR PDOW3
 BCS PDQX
 LDA #0
 STA PDQSRC
 JMP PDQF9
PDQFN JSR PDQNUM
 BCS PDQBAD
 LDA #2
 STA PDQSRC
 JMP PDQF9
* ---- the far half's exits ----------------------
* PDQBAD and PDQX are at the head of this block and
* everything from PDQOF down is further away than a
* branch reaches.  Same answer CATALOG's CTLIST
* uses - branch to a JMP - and it is placed in the
* MIDDLE so the code above reaches it forwards and
* the code below reaches it backwards.
PDQBADF JMP PDQBAD
PDQXF RTS

* OF file-name: src 1, and the operand is the
* file's number, 0 or 1 - the name must be one a
* SELECT declared, the same lookup OPEN and READ
* make.
PDQOF JSR PDNEXT
 BCS PDQBADF
 LDA TOKTYP
 CMP #TKWORD
 BNE PDQBADF
 JSR PFBYNAM
 BCS PDQBADF
 LDA PFNO
 STA PDVAL
 STZ PDVAL+1
 LDA #1
 STA PDQSRC
PDQF9 LDA PDVAL
 STA PDQA
 LDA PDVAL+1
 STA PDQA+1
* [GIVING c] [ON ERROR stmt]
 JSR PDQGIV
 BCS PDQXF
 LDA #7
 JSR PDQPAIR
 BCS PDQXF
PDQE9 JMP PDQEMIT

* ---- QUERY NEXT [GIVING r] [AT END stmt] --------
PDQNXT JSR PDQGIV
 BCS PDQXF
 LDA #9
 JSR PDQPAIR
 BCS PDQXF
PDQN9 LDA #OQNEXT
 JSR EMB
 BCS PDQXF
 LDX #6
 JSR PDQEW
 BCS PDQXF
 JMP PDQCLS

* ---- QUERY SORT [ON ERROR stmt] -----------------
PDQSRT LDA #$FF
 STA PDQCLA
 JSR PDQOPT
 BCS PDQSR1
 STA PDQCLA
PDQSR1 LDA #7
 JSR PDQPAIR
 BCS PDQXF
PDQS9 LDA #OQSORT
 JSR EMB
 BCS PDQXF
 JMP PDQCLS

* ---- QUERY FIELD n INTO x -----------------------
* The field number is a literal byte in the
* instruction, as DISPA's line and column are: it is
* constant in the source, so it is constant in the
* code.  Whether it is a field the DICTIONARY has is
* not the compiler's business - the dictionary is
* not read until run time, and status 8 is the
* answer when it is not.
* Its own exits, at its own foot: the pair in the
* middle of the block is out of reach from down
* here, and a routine this self-contained is better
* with local ones than with a third trampoline.
PDQFLD JSR PDNEXT
 BCS PDQFB
 LDA TOKTYP
 CMP #TKNUM
 BNE PDQFB
 JSR PDQNUM
 BCS PDQFB
 LDA PDVAL+1
 BNE PDQFB
 LDA PDVAL
 STA PDQA
 JSR PDWORD
 BCS PDQFB
 JSR PDNEXT
 BCS PDQFB
 LDA TOKTYP
 CMP #TKWORD
 BNE PDQFB
 JSR PDOW3
 BCS PDQFX
 LDA #OQFLD
 JSR EMB
 BCS PDQFX
 LDA PDQA
 JSR EMB
 BCS PDQFX
 LDA PDVAL
 STA EMWV
 LDA PDVAL+1
 STA EMWV+1
 JMP EMW
PDQFB LDA #16
 STA CMPERR
PDQFX RTS

* ---- PDQEMIT: the QOPEN instruction -------------
* Seven operands, in the order VQOPEN fetches them.
* Emitted here and not as they were parsed, because
* GIVING and ON ERROR come last in the source and
* are not last in the instruction.
PDQEMIT LDA #OQOPEN
 JSR EMB
 BCS PDQX2
 LDX #0
 JSR PDQEW
 BCS PDQX2
 LDX #2
 JSR PDQEW
 BCS PDQX2
 LDA PDQSRC
 JSR EMB
 BCS PDQX2
 LDX #4
 JSR PDQEW
 BCS PDQX2
 LDX #6
 JSR PDQEW
 BCS PDQX2
 LDA QSTITM
 STA EMWV
 LDA QSTITM+1
 STA EMWV+1
 JSR EMW
 BCS PDQX2
 JMP PDQCLS
PDQX2 RTS

* ---- PDQEW: emit the word at PDQQ,X -------------
* PDQQ PDQD PDQA PDQC PDQE PDQP are declared
* contiguously on purpose.  QOPEN is five words out
* of that block, and one indexed helper is a good
* deal smaller than five copies of the same four
* instructions - which is the whole reason the
* variables are in that order.
PDQEW LDA PDQQ,X
 STA EMWV
 LDA PDQQ+1,X
 STA EMWV+1
 JMP EMW

* ---- PDQPAT: the placeholder at PDQQ,X gets here
PDQPAT LDA PDQQ,X
 STA EMWO
 LDA PDQQ+1,X
 STA EMWO+1
 LDA CODLEN
 STA EMWV
 LDA CODLEN+1
 STA EMWV+1
 JMP EMSETW

* ---- PDQCLS: the target operand and its clause --
* in: PDQCLA 0 = there was no clause
* The layout is IF/ELSE's, and for the same reason:
*
*     <the query opcode> ... target -> E
*     BRA P                 reached when nothing
*   E <the one statement>   went wrong
*   P <the next statement>
*
* The handler branches to the target on the bad
* outcome and falls through on the good one, so the
* fall-through has to jump the clause.
PDQCLS LDA PDQHAS
 BNE PDQC1
 LDA #$FF
 STA EMWV
 STA EMWV+1
 JMP EMW
PDQC1 STZ EMWV
 STZ EMWV+1
 LDA CODLEN
 STA PDQE
 LDA CODLEN+1
 STA PDQE+1
 JSR EMW
 BCS PDQX2
 STZ EMWV
 STZ EMWV+1
 LDA #OBRA
 JSR EMB
 BCS PDQX2
 LDA CODLEN
 STA PDQP
 LDA CODLEN+1
 STA PDQP+1
 JSR EMW
 BCS PDQX2
* the clause starts here
 LDX #8
 JSR PDQPAT
* ONE statement, compiled where it stands - and when
* that statement opens an IF, an EVALUATE or an
* inline PERFORM, every statement after it until the
* one that closes it (FIXLIST A14).  An IF compiles
* as its test and nothing more; the old code patched
* the clause's end straight after the test, so the
* IF's body ran on success too.
* The end is patched through PDQP, and a file verb
* inside the clause has a clause of its own that
* sets PDQP again - the outer end was never patched
* and jumped to the program start.  So each level
* keeps its PDQP, and the IF and EVALUATE depths it
* started at, in the PDCL tables, indexed by PDQDEP.
* PDQDEP is also what keeps a QUERY out of a clause.
 LDX PDQDEP
 CPX #4
 BCS PDQBAD2
 LDA PDQP
 STA PDCLP,X
 LDA PDQP+1
 STA PDCLPH,X
 LDA NIFS
 STA PDCLI,X
 LDA NEVS
 STA PDCLE,X
 INC PDQDEP
 JSR PDNEXT
 BCS PDQBAD2
 LDA TOKTYP
 CMP #TKWORD
 BNE PDQBAD2
 JSR PDLMK
 JSR PDDISP
 BRA PDQC3
* here, between the two halves, so that both are
* in a branch's reach
PDQBAD2 LDA #16
 STA CMPERR
 RTS
* is anything the clause opened still open?
PDQC3 LDA CMPERR
 BNE PDQCX
 LDX PDQDEP
 LDA PDCLI-1,X
 CMP NIFS
 BCC PDQC4
 LDA PDCLE-1,X
 CMP NEVS
 BCS PDQC9
* yes: the next statement, the way PROCDIV reads
* one - the held token first
PDQC4 LDA PDHELD
 BEQ PDQC5
 STZ PDHELD
 BRA PDQC6
PDQC5 JSR PDNEXT
 BCS PDQEOF
PDQC6 LDA LEXERR
 BNE PDQCX
 LDA TOKTYP
 CMP #TKPUNC
 BNE PDQC7
* a full stop ends the sentence, and every IF in it
* - the clause's and any it is inside, since none
* of them emits code at its end
 LDA TOKBUF
 CMP #$2E
 BNE PDQC4
 JSR PDDOT
 BRA PDQC3
PDQC7 CMP #TKWORD
 BNE PDQC4
* a paragraph name with the clause's IF still open
 LDA TOKCOL
 CMP #6
 BCC PDQEOF
 JSR PDLMK
 JSR PDDISP
 BRA PDQC3
* and ends here
PDQC9 DEC PDQDEP
 LDX PDQDEP
 LDA PDCLP,X
 STA PDQP
 LDA PDCLPH,X
 STA PDQP+1
 LDX #10
 JMP PDQPAT
PDQEOF LDA #14
 STA CMPERR
PDQCX RTS

* ---- PDQPAIR: the two-word trailing clause ------
* in:  A = the first word wanted - ON (7) or AT (9)
*      PDQCLA = what PDQGIV actually found, or $FF
* out: PDQHAS 1 if the clause is there
* $FF and not 0 means "nothing found", because
* keyword 0 is NEXT and a real index of zero would
* otherwise read as absence - and the token would be
* dropped instead of handed back.
PDQPAIR STA PDQWNT
 STZ PDQHAS
 LDA PDQCLA
 CMP #$FF
 BNE PDQP1
 CLC
 RTS
PDQP1 CMP PDQWNT
 BEQ PDQP2
* a keyword, but not this statement's: it belongs to
* whatever comes next
 LDA #1
 STA PDHELD
 CLC
 RTS
* ON must be followed by ERROR, AT by END - the
* second word of each pair is one past the first in
* QKWTAB, so there is nothing to look up
PDQP2 JSR PDQNEED
 BCS PDQPB
 SEC
 SBC PDQWNT
 CMP #1
 BNE PDQPB
 LDA #1
 STA PDQHAS
 CLC
 RTS
PDQPB LDA #16
 STA CMPERR
 SEC
 RTS

* ---- PDQGIV: an optional GIVING item ------------
* out: PDQC = the item or $FFFF, PDQCLA = the next
*      clause keyword, or $FF if there is none
PDQGIV LDA #$FF
 STA PDQC
 STA PDQC+1
 STA PDQCLA
 JSR PDQOPT
 BCS PDQG9
 CMP #6
 BEQ PDQG1
 STA PDQCLA
 CLC
 RTS
PDQG1 JSR PDNEXT
 BCS PDQGB
 LDA TOKTYP
 CMP #TKWORD
 BNE PDQGB
 JSR PDOW3
 BCS PDQGX
 LDA PDVAL
 STA PDQC
 LDA PDVAL+1
 STA PDQC+1
 JSR PDQOPT
 BCS PDQG9
 STA PDQCLA
PDQG9 CLC
 RTS
PDQGB LDA #16
 STA CMPERR
PDQGX SEC
 RTS

* ---- PDQOPT: an optional clause keyword ---------
* out: A = its index, C=0
*      C=1 = there was none, and anything read has
*      been handed back through PDHELD
PDQOPT JSR PDNEXT
 BCS PDQO9
 LDA TOKTYP
 CMP #TKWORD
 BNE PDQOH
 JSR PDQKW
 BCC PDQOY
PDQOH LDA #1
 STA PDHELD
PDQO9 SEC
 RTS
PDQOY CLC
 RTS

* ---- PDQNEED: a keyword that must be there ------
PDQNEED JSR PDNEXT
 BCS PDQNN
 LDA TOKTYP
 CMP #TKWORD
 BNE PDQNN
 JMP PDQKW
PDQNN SEC
 RTS

* ---- PDQKW: TOKBUF against QKWTAB ---------------
* out: A = index, C=0;  C=1 = no match
* Full comparisons, not first letters: these words
* sit where a data name could, and NEXT matching
* NAME would compile something else entirely.
PDQKW LDA #0
 STA PDQN
 LDX #0
PDQK1 LDA QKWTAB,X
 BEQ PDQKN
 STX PDWS
 LDY #0
PDQK2 CPY TOKLEN
 BCS PDQK5
 INX
 LDA QKWTAB,X
 CMP TOKBUF,Y
 BNE PDQK3
 INY
 JMP PDQK2
PDQK3 LDX PDWS
 TXA
 CLC
 ADC QKWTAB,X
 TAX
 INX
 INC PDQN
 JMP PDQK1
PDQK5 LDX PDWS
 LDA QKWTAB,X
 CMP TOKLEN
 BNE PDQK3
 LDA PDQN
 CLC
 RTS
PDQKN SEC
 RTS
QKWTAB DFB 4
 ASC 'NEXT'
 DFB 4
 ASC 'SORT'
 DFB 5
 ASC 'FIELD'
 DFB 5
 ASC 'USING'
 DFB 3
 ASC 'FOR'
 DFB 2
 ASC 'OF'
 DFB 6
 ASC 'GIVING'
 DFB 2
 ASC 'ON'
 DFB 5
 ASC 'ERROR'
 DFB 2
 ASC 'AT'
 DFB 3
 ASC 'END'
 DFB 7
 ASC 'INVALID'
 DFB 3
 ASC 'KEY'
 DFB 6
 ASC 'RECORD'
 DFB 5
 ASC 'INPUT'
 DFB 6
 ASC 'OUTPUT'
 DFB 3
 ASC 'I-O'
 DFB 6
 ASC 'EXTEND'
 DFB 5
 ASC 'OTHER'
 DFB 4
 ASC 'THRU'
 DFB 5
 ASC 'UNTIL'
 DFB 5
 ASC 'TIMES'
 DFB 4
 ASC 'TRUE'
 DFB 7
 ASC 'ROUNDED'
* 24 THROUGH (THRU spelled out), 25 VARYING
 DFB 7
 ASC 'THROUGH'
 DFB 7
 ASC 'VARYING'
* 26 SIZE, 27 REMAINDER (2026-11-11)
 DFB 4
 ASC 'SIZE'
 DFB 9
 ASC 'REMAINDER'
 DFB 0

* ---- PDQNUM: TOKBUF digits -> PDVAL, 16 bits ----
* Not a NUM8 cell and not a pool literal: a count
* and a field number are plain binary numbers that
* go in the instruction, so the eight-byte machinery
* would have to be undone again at the other end.
* Times ten is two shifts, an add and a shift.
PDQNUM STZ PDVAL
 STZ PDVAL+1
 LDX #0
PDQM1 CPX TOKLEN
 BCS PDQM9
 LDA TOKBUF,X
 CMP #$30
 BCC PDQMB
 CMP #$3A
 BCS PDQMB
 LDA PDVAL
 STA PDQT2
 LDA PDVAL+1
 STA PDQT2+1
 ASL PDVAL
 ROL PDVAL+1
 ASL PDVAL
 ROL PDVAL+1
 CLC
 LDA PDVAL
 ADC PDQT2
 STA PDVAL
 LDA PDVAL+1
 ADC PDQT2+1
 STA PDVAL+1
 ASL PDVAL
 ROL PDVAL+1
 LDA TOKBUF,X
 AND #$0F
 CLC
 ADC PDVAL
 STA PDVAL
 LDA PDVAL+1
 ADC #0
 STA PDVAL+1
 INX
 JMP PDQM1
PDQM9 CLC
 RTS
PDQMB SEC
 RTS

* ================= OPERANDS ====================
* ---- PDOPND: the next token as an operand -------
* out: PDKIND 0 item, 1 literal, 2 figurative
*      PDVAL  the item number, pool offset, or
*             figurative index
*      C=1 if there is nothing there
* A sign in front of a number makes a signed
* literal: MOVE -5 TO X, IF X < -1.  It was error 12
* everywhere but COMPUTE (FIXLIST A13).  COMPUTE
* never gets here with a sign - CEFACT takes a
* unary minus itself - so nothing else changes.
PDOPND JSR PDOPN0
 BCS PDOPN9
* a table item takes its subscript (CMPPROC4.S)
 JMP PDOSUB
PDOPN9 RTS
PDOPN0 STZ PDCKND
 STZ PDONEG
 JSR PDNEXT
 BCS PDOX
 LDA TOKTYP
 CMP #TKPUNC
 BNE PDOQ1
 LDA TOKBUF
 CMP #$2B
 BEQ PDOSG
 CMP #$2D
 BNE PDOX
 INC PDONEG
PDOSG JSR PDNEXT
 BCS PDOX
 LDA TOKTYP
 CMP #TKNUM
 BEQ PDOQ2
 SEC
 RTS
PDOQ1 CMP #TKSTR
 BEQ PDOSTR
 CMP #TKNUM
 BNE PDOX0
PDOQ2 JMP PDONUM
PDOX0 CMP #TKWORD
 BEQ PDOWRD
PDOX SEC
 RTS
* a name: a data item, or a figurative constant
PDOWRD LDX #0
PDOW1 CPX TOKLEN
 BCS PDOW2
 LDA TOKBUF,X
 STA VALBUF,X
 INX
 JMP PDOW1
PDOW2 LDA TOKLEN
 STA VALLEN
 JSR DDFIGN
 BCS PDOW3
 STA PDVAL
 STZ PDVAL+1
 LDA #2
 STA PDKIND
 CLC
 RTS
PDOW3 JSR SYMFIND
 BCC PDOW4
 JMP PDOBAD
PDOW4 JSR SYMGET
 LDA SYKIND
 STA PDCKND
 CMP #KDATA
 BEQ PDOW5
 CMP #KCOND
 BEQ PDOW6
 JMP PDOBAD
* a condition name.  PDVAL gets the LITERAL's pool
* offset and PDCPAR the parent's item number, which
* is what the symbol holds since pass one learned to
* store both; the caller decides what to do with it
PDOW6 JSR SYMCHG
 LDA FIXHD
 STA PDCPAR
 LDA FIXHD+1
 STA PDCPAR+1
PDOW5 LDA SYMVAL
 STA PDVAL
 LDA SYMVAL+1
 STA PDVAL+1
 LDA #0
 STA PDKIND
 CLC
 RTS
* a quoted literal: into the pool as text
PDOSTR LDX #0
PDOS1 CPX TOKLEN
 BCS PDOS2
 LDA TOKBUF,X
 STA LITBUF+1,X
 INX
 JMP PDOS1
PDOS2 LDA TOKLEN
 STA LITN
 JSR EMLTXT
 BCC PDOS3
 SEC
 RTS
PDOS3 STZ PDLTYP
 JMP PDOLIT
* a numeric literal: into the pool as a NUM8 cell.
* Its scale is its own, because there is no
* destination to borrow one from at this point -
* PUSHL reads the trailing byte and MOVL of a
* literal into a scaled item is the one case the
* DATA DIVISION handles instead.
PDONUM LDX #0
PDON1 CPX TOKLEN
 BCS PDON2
 LDA TOKBUF,X
 STA VALBUF,X
 INX
 JMP PDON1
* The literal keeps its OWN scale: as many decimals
* as it was written with.  DDECV was set to zero
* first, so DDVSCL cut 250.75 down to 250 and the
* fraction was gone before anything could see it.
PDON2 LDA TOKLEN
 STA VALLEN
 STZ DDECV
 LDX #0
PDNS1 CPX TOKLEN
 BCS PDNS3
 LDA TOKBUF,X
 INX
 CMP #$2E
 BNE PDNS1
 STX ALEN
 LDA TOKLEN
 SEC
 SBC ALEN
 STA DDECV
PDNS3 JSR DDVSCL
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
* the sign, if there was one: FNEG in the flags
 LDA PDONEG
 BEQ PDONP
 LDA LITBUF
 ORA #FNEG
 STA LITBUF
PDONP LDA DDECV
 STA LITSCL
 JSR EMLNUM
 BCC PDON3
 SEC
 RTS
PDON3 LDA #1
 STA PDLTYP
 JMP PDOLIT
PDOLIT LDA EMLO
 STA PDVAL
 LDA EMLO+1
 STA PDVAL+1
 LDA #1
 STA PDKIND
 CLC
 RTS
PDOBAD LDA #15
 STA CMPERR
 SEC
 RTS

* ---- PDSAVE: park the operand just read ---------
PDSAVE LDA PDVAL
 STA PDSVAL
 LDA PDVAL+1
 STA PDSVAL+1
 LDA PDKIND
 STA PDSKND
 RTS

* ---- PDWORD: read a word and throw it away ------
* TO, FROM, BY, INTO, THEN, RUN - the connecting
* words.  Which verb this is has already been
* decided, and in the subset they cannot be swapped
* for one another, so nothing is learned by reading
* them and nothing is lost by not.
PDWORD JSR PDNEXT
 BCS PDWX
 LDA TOKTYP
 CMP #TKWORD
 BEQ PDWOK
PDWX SEC
 RTS
PDWOK CLC
 RTS

* (PDRELOP, the relation, is in CMPCOND.S since
* 2026-11-08.)
* (continued in CMPPROC3.S - Merlin 8 cannot PUT a
* file over about 24K, so the PROCEDURE parser is
* three files.  COMPILE2 PUTs all three, in order.)
