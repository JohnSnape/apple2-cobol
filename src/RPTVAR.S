* RPTVAR.S  REPORT variables (holds RPTEND)
* PUT from REPORT.S - no ORG, not assembled alone.
* One symbol table spans every PUT: this file and
* REPORT resolve against each other in pass two.
*
* ================= VARIABLES ===================
* The report itself is NOT here.  It lives at
* RPTHDR/RPTENT up at $97E0, an address and not
* a DS, so its four kilobytes never travel in
* the file.  What is here is only the working
* of the drawing.
PTOP DFB 0
QUIT DFB 0
WROW DFB 0
PLINE DFB 0
ENTIX DFB 0
PMX DFB 0
GTMP DFB 0
* ---- painting one entry ----
PKIND DFB 0
PCNT DFB 0
PIX DFB 0
PCH DFB 0
* ---- building one row ----
RCOL DFB 0
RIX DFB 0
RLEN DFB 0
RSAV DFB 0
PD1 DFB 0
PD2 DFB 0
PD3 DFB 0
PANY DFB 0
* ---- the rule's band lookup ----
BTMP DFB 0
BIX DFB 0
BNHI DFB 0
BSAV DFB 0
* ---- the trimmed dictionary name for row 0 ----
DNBUF DS 16

* ---- slice 2: the entry being staged ----
* Built here and copied into the table whole, so a
* rejected entry never half-lands in the report.
AKRES DFB 0
NKIND DFB 0
NLINE DFB 0
NCOL DFB 0
NWID DFB 0
NLLEN DFB 0
NHI DFB 0
NPICT DS 14
NTEXT DS 32
* F and T: the field's name, decimals and type
NNAME DS 10
NDECS DFB 0
NFTYP DFB 0
* ---- walking the table ----
* OIX belongs to OVERLAP and FIDX to everything
* that finds or places a slot; they are separate
* from ENTIX, which belongs to the drawing, so a
* redraw can never disturb a search.
OIX DFB 0
OLO DFB 0
OHI DFB 0
FIDX DFB 0
DIX DFB 0

* If RPTEND ever reaches $97E0 the code has grown
* into the report header, and the first symptom
* will be a corrupted layout rather than a crash.
* Check it after every assembly, as LIB checks
* LIBEND, EDIT checks EDEND and FORMAT checks
* FMTEND.
RPTEND EQU *
