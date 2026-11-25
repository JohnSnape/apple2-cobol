* CMPVAR.S  COMPILE's variables (holds CMPEND)
* PUT from COMPILE.S - no ORG, not assembled alone.
* PUT LAST, so CMPEND is the real end of the code.
*
* CMPEND must stay below OBCODE ($A400), or the
* compiler has grown into the p-code it is building
* - and the first symptom is an object whose tail
* is 6502 code.  BUILD.md 5.

* ---- constants ----
* The build areas, opcode numbers, type codes and
* LITSMX are in CMPCON.S, PUT before any code - see
* the note at its top.


* ================ THE HANDOVER SET =============
* CODLEN LITLEN NITEMS DSEG CMPERR NSYMS NSRC LEXLN
* QSTITM CMPPHS are NOT declared here.  They must
* survive the overlay swap between pass one and pass
* two, and both passes PUT this file at different
* sizes, so a DS here would put them at a different
* address in each - harmless for scratch, fatal for
* a handover.  They are EQUated in EQUATES.S into
* CMPXFR at $1F00, which is also where SYSMENU finds
* CMPERR when it decides whether to load pass two.
*
* Everything below IS per-pass scratch.  The rule
* for deciding is one question: does pass two need
* to know what pass one made of it?

* ---- emitter state -----------------------------
EMSAV DFB 0
EMT DS 2
EMT2 DS 2
EMWV DS 2
EMWV2 DS 2
EMWO DS 2
EMIT DS 2
EMLO DS 2
EMTGT DS 2
EMMODE DFB 0
FIXHD DS 2

* ---- the descriptor being built ----------------
DTYP DFB 0
DLENV DFB 0
DDECV DFB 0
DFLGV DFB 0
DOFFV DS 2
DEDTV DS 2

* ---- the literal being added -------------------
LITN DFB 0
LITSCL DFB 0
* 41: a text literal is a length byte and up to
* TOKMAX (40) characters.  It was DS 40, so the 40th
* character of a 40-character literal went into
* TMPX, which the pool search then changed - that
* character came out as garbage ("?*", SALESDB's
* filter prompt) and TMPX was trampled (FIXLIST A23,
* 2026-11-22)
LITBUF DS 41

* ---- the literal entry table -------------------
* Offset and length for every distinct literal, so
* the pool can be searched by ENTRY rather than by
* byte.  The pool itself is not self-describing - a
* text literal has a length byte and a NUM8 cell is
* nine anonymous bytes - so searching it directly
* can match halfway through something and return an
* offset that points at nothing.
* (LITSMX, the table size, is in CMPCON.S)
TMPX DFB 0
NLITS DFB 0
* LTAB and TKSAV live in OVLWORK, not here: per-pass
* scratch with no starting value, and 237 bytes the
* overlay needs more (COMPILE2 was 150 short of its
* $A400 ceiling, 2026-11-07).  OVLWORK+0 is LEXBUF
* and +80 LEXNAME, 80 each; these follow at +160.
LTAB EQU OVLWORK+160
* Also in OVLWORK since 2026-11-07, for room in
* COMPILE2: LVLST +400, PDPNAM +480, EVSTK +512,
* VSBUF +540, IFSTK +564 - all scratch with no
* starting value.  OVLWORK is 640 bytes; +580 is the
* last byte used.

* ---- the object header -------------------------
OBHDR DS 20

* ---- the lexer ---------------------------------
* LEXBUF is the current source line and it lives in
* OVLWORK - which is exactly what OVLWORK is for,
* work space for whichever overlay is resident, and
* COMPILE is an overlay.  Eighty bytes that cost
* nothing on the floppy.
LEXBUF EQU OVLWORK
LEXNAME EQU OVLWORK+80
* the source: line count, and where the lexer is
LEXCOL DFB 0
LEXQ DFB 0
LEXERR DFB 0
LEXHDL DFB 0
* the token just read.  TOKCOL is not decoration:
* in fixed-form COBOL a word beginning in Area A is
* a division, a section, a paragraph or an 01, and
* the same word in Area B is a statement.
TOKTYP DFB 0
TOKLEN DFB 0
TOKCOL DFB 0
TOKLIN DS 2
TOKBUF DS 40
* TKSAV: room for all five above (45 bytes), used by
* PDPEMT to keep a held token alive.  The five must
* stay together and in this order.
TKSAV EQU OVLWORK+352

* ---- the symbol table --------------------------
SYMIX DFB 0
SYMVAL DS 2
SYKIND DFB 0
* SYXS: the caller's X, kept across the aux call
SYXS DFB 0

* ---- the DATA DIVISION parser ------------------
* LVLST is the open-level stack: level, item number
* and the data-segment offset the group started at,
* five bytes an entry.  A group is MEASURED when it
* closes, never declared.
NLVL DFB 0
LVLST EQU OVLWORK+400
THISLV DFB 0
DDONE DFB 0
CURIT DS 2
HASPIC DFB 0
ISFILL DFB 0
OCCN DFB 0
* the OCCURS group being declared: its table entry
* + 1 (0 = none) and its level-stack index
TBOPEN DFB 0
TBNLVL DFB 0
DDTW DFB 0
DDTN DFB 0
DDTT DS 2
ENTOFF DS 2
DDT DS 2
DDT2 DFB 0
DDWS DFB 0
CLWN DFB 0
FIGN DFB 0
VALKND DFB 0
VALLEN DFB 0
VALFIG DFB 0
VALBUF DS 40

* ---- PICTURE parsing ---------------------------
PCNT DFB 0
PDEC DFB 0
PSEENV DFB 0
PISNUM DFB 0
PISALF DFB 0
PISEDT DFB 0
PSIGN DFB 0
PIX DFB 0
PLAST DFB 0
PREPN DFB 0
PRT DFB 0

* ---- VALUE scaling -----------------------------
VSNEG DFB 0
VSI DFB 0
VSN DFB 0
VSFRAC DFB 0
VSSEEN DFB 0
VSBUF EQU OVLWORK+540


* ---- the PROCEDURE DIVISION parser -------------
PDONE DFB 0
PDVN DFB 0
PDAVN DFB 0
PDAR2V DS 2
PDAR2K DFB 0
PDARBY DFB 0
* PDARTL: where the result goes, and GIVING seen
PDARDV DS 2
PDARGV DFB 0
PDWS DFB 0
PDOP DFB 0
PDT DS 2
PDKIND DFB 0
PDVAL DS 2
PDSKND DFB 0
PDSVAL DS 2
PDDEV DFB 0
PDDLOP DS 2
PDDST DS 2
* PDMV went with the AT shift's byte loop (2026-11-22)
PDATL DFB 0
* ACCEPT FROM PREFIX n: the n
PDAPX DFB 0
PDATC DFB 0
PDREL DFB 0
PDRNOT DFB 0
NIFS DFB 0
IFSTK EQU OVLWORK+564

* ---- the one-token pushback --------------------
* The lexer cannot un-read a token, and an OPTIONAL
* clause cannot be recognised without reading the
* word that might not be it.  PDHELD says the token
* in TOKBUF has already been read and belongs to
* the NEXT statement; PD1 honours it before calling
* LEXNEXT.  One flag, no buffer: nothing between
* setting it and PD1 touches TOKBUF.
PDHELD DFB 0

* ---- the QUERY statement -----------------------
PDQQ DS 2
PDQD DS 2
PDQA DS 2
PDQC DS 2
PDQE DS 2
PDQP DS 2
PDQSRC DFB 0
PDQCLA DFB 0
PDQWNT DFB 0
PDQHAS DFB 0
PDQN DFB 0
PDQT2 DS 2
PDQDEP DFB 0
* a row per clause level (PDQCLS, 4 deep): its PDQP
* and the IF and EVALUATE depths when it started
PDCLP DS 4
PDCLPH DS 4
PDCLI DS 4
PDCLE DS 4

* ---- literal operands --------------------------
* PDLTYP: what kind of literal PDOPND last read -
* 0 text, 1 numeric.  PDTNI/PDTAI: the two hidden
* temp items PDMAT creates on first use, $FFFF
* until then.  The overlay is reloaded from disk
* for every compile, so the $FF initialisers are
* re-initialised the only way that never forgets.
PDLTYP DFB 0
PDONEG DFB 0
PDIFL DFB 0
PDTNI DFB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
 DFB $FF,$FF
PDTNX DFB 0
PDTAI DFB $FF,$FF

* ---- the file verbs ----------------------------
* PFO1 PFO2 PFST are adjacent: the emitter walks
* them as one six-byte block, the way the query
* statement walks its own.
PFIX DFB 0
PFCTL DFB 0
PFNO DFB 0
PFO1 DFB $FF,$FF
PFO2 DFB $FF,$FF
PFST DFB $FF,$FF

* ---- COMPUTE ----------------------------------
PDCKND DFB 0
PDCNOT DFB 0
PDCPAR DS 2
* ---- subscripts (PDOSUB) ----
* PDSUBN the next free slot in this statement;
* PDSLL/PDSLH the table item each slot holds, which
* is what EMDGET describes when asked for a slot
PDSUBN DFB 0
PDSLL DS 4
PDSLH DS 4
PDSIT DS 2
PDSIX DS 2
PDSFLG DFB 0
PDSTX DFB 0
PDSTW DFB 0
PDSTD DFB 0
PDPNAM EQU OVLWORK+480
PDPNLN DFB 0
* PDPEND: the paragraph a PERFORM range ends at ($FF
* = the target itself).  PDCUR: the paragraph being
* compiled now ($FF = none yet) - its RET goes out
* when the next one starts.
PDPEND DFB $FF
PDCUR DFB $FF
* PDCTRU: ask PDCOND for the branch-when-TRUE
PDCTRU DFB 0
* compound conditions (PDCOND): the sense wanted, how
* many terms, the joiner (1 AND, 2 OR), each term's
* branch placeholder, and a spare word plus a count
PDCWNT DFB 0
* the condition's two exit lists - T then F, in that
* order: CXHERE and CXCAT index them with X = 0 / 2
PDCT DS 2
PDCF DS 2
PDCQ DS 2
PDCP DS 2
PDCOK DS 2
* ---- PERFORM TIMES / VARYING (CMPPROC4) ----
PDPINF DFB 0
PDPCK DFB 0
PDPCNT DS 2
PDPCTR DS 2
PDPVI DS 2
PDPVA DS 2
PDPVAK DFB 0
PDPVB2 DS 2
PDPVBK DFB 0
PDPVC DS 2
PDPVT DFB 0
PDCDP DFB 0
* the abbreviated forms: the last subject, relation
PDCSV DFB 0
PDCSUB DS 2
PDCRL DFB 0
PDRCLS DFB 0
PDRCON DFB 0
PDCLC DFB 0
PDRKI DFB 0
PDPTOP DS 2
PDPXIT DS 2
CETGT DS 2
CEDEP DFB 0

* ---- EVALUATE ---------------------------------
* EVSUBJ EVCHN EVNEXT EVOPEN are contiguous and in
* that order: the stack push and pop copy them as
* one seven-byte block.
NEVS DFB 0
EVSUBJ DS 2
EVCHN DS 2
EVNEXT DS 2
EVOPEN DFB 0
EVSTK EQU OVLWORK+512

CMPEND EQU *
