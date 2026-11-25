* EDITVAR.S  EDIT variables (holds EDEND)
* PUT from EDIT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* EDIT resolve against each other in pass two.
*
* ================= VARIABLES ===================
NLINES DS 2
CURLIN DS 2
TOPLIN DS 2
CURCOL DFB 0
MODE DFB 0
BARDRT DFB 0
RWID DFB 0
QUIT DFB 0
CHKEY DFB 0
CHMOD DFB 0
BLINK DFB 0
LDIRTY DFB 0
RFLAG DFB 0
DROW DFB 0
BSAV DFB 0
HIX DFB 0
CNT DFB 0
CMA DFB 0
DREM DFB 0
RCOL DFB 0
RIX DFB 0
RLEN DFB 0
RSAV DFB 0
GLEN DFB 0
CLINE DS 2
CLOW DS 2
CHIGH DS 2
CVALID DFB 0
DLO DS 2
DHI DS 2
C1 DS 2
C2 DS 2
CPTR DS 2
CT DS 2
SVAL DS 2
VT DS 2
SRCL DS 2
INSP DS 2
NBUF DS 5
GBUF DS 8
* HDRBUF PFXBUF SHFBUF are addresses above the
* ring now - see EDHIGH in EDIT.S
* ---- Open and Save ----
SLINE DS 2
SLEN DFB 0
SGP DS 2
SGLEN DS 2
OLINE DS 2
OCOL DFB 0
OFULL DFB 0
OPP DS 2
OREM DS 2
* NAMBUF and ETMPNB too - EDHIGH in EDIT.S

* If EDEND ever passes $9800 the code has grown
* into the ring.  Check it after every assembly.
EDEND EQU *
