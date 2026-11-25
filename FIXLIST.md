# What is unfinished or wrong — 2026-11-08

Found by reading the compiler, interpreter and library line by line (three
passes, one per area) while preparing the reference manual. **Not yet confirmed
by running each case** — every item gets a test program before it is fixed.
Source citations are in the three reports; the file:line references below are
the starting points.

**Space was the constraint behind most of this — solved 2026-11-08.** BCD,
PICTURE and ERRMSG moved to the auxiliary language card and VM and the
compiler now load at $7000: VM has 4,217 bytes free, COMPILE2 4,225, COMPILE1
8,221, the library 4,187, the card 8,124 (HANDOFF.md).

## A. Wrong results with no error — fix first

**Started 2026-11-08. All nineteen fixed the same day** (A2, A14, A15 in the second pass).
The tests are `at.cob`, `lista.cob`, `listd.cob`, `listm.cob`, `listv.cob` and the
`e33`/`e14`/`e34`/`e35` compile errors in `tools/emu/progs`; `errtest.ps1`
runs the error set and then the regressions; `listall.ps1` runs everything. The second
pass added `a2.cob`, `a14.cob`, `a15.cob` and the `e36`/`e38` compile errors.

| # | Problem | Status |
|---|---|---|
| A1 | `DISPLAY`/`ACCEPT ... AT LINE n COLUMN n` never compiled. | **Fixed.** `AT` after a DISPLAY's operands puts a new `$82 AT` (cursor move) in front of them; `ACCEPT x AT` is the new `$87 ACCA`, an inverse form field (DSACC) the width of the item. `COL` and `NUMBER` accepted. CMPPROC4.S, VMSCRN.S |
| A2 | No subscripting. `X(2)` compiles as `X`; `X(I)` is error 12. OCCURS only reserves space — and DDSIZE stores n × length as the *descriptor's* length. | **Fixed.** One dimension, on an elementary item or a group (and every item under it); `X(2)` or `X(I)`. A table's descriptor is one occurrence; pass one hands pass two a table list at `$1F60`; a table item needs a subscript, and the new `$18 SUBS` builds the element's descriptor in one of four slots (`$FFF0`–`$FFF3`) that every other instruction reads as an item. Out of range stops the run. New errors 36 OCCURS NOT ALLOWED HERE (nested, at 01/77, a ninth table), 37 NO VALUE IN A TABLE, 38 SUBSCRIPT MISSING OR WRONG (also a subscripted EVALUATE subject or condition name), 39 OVER 4 SUBSCRIPTS IN STATEMENT. CMPDATA2.S DDTAB, CMPPROC4.S PDOSUB, VMLOOP.S VSUBS |
| A3 | Numeric comparisons ignored decimal places. | **Fixed.** CMPN scales the operand with fewer decimals up. Literals in conditions get a temp of their own scale (0–4 decimals), so `IF X < 1.5` works — it used to be error 29. VMFLOW.S, CMPPROC3.S PDTNUM |
| A4 | An `IF` with no `END-IF` jumped to the program start. | **Fixed.** A full stop closes every open IF (COBOL-74 style); an IF, inline PERFORM or EVALUATE still open at a paragraph or the end is error 14 / 28. CMPPROC4.S PDDOT/PDOPEN |
| A5 | `IF NOT A = B` compiled as `IF A = B`. | **Fixed.** CMPPROC.S |
| A6 | `COMPUTE` without punctuation swallowed the next statement. | **Fixed.** CEOP now holds the token its comment always said it held. CMPPROC3.S |
| A7 | `COMPUTE`: `1 + 0.5` = 1, `10 / 2.50` = 0, divide by zero gave the dividend. | **Fixed.** Add/subtract scale the operand with fewer decimals up; divide pre-scales the dividend for at least 4 decimals (capped by its leading zeros); divide by zero stops the run, `DIVIDE` too. `ADD 1.5 TO X` allowed (was error 29). VMMATH.S |
| A8 | `DIVIDE A BY B GIVING C` computed B / A. | **Fixed**, and a literal second operand works with GIVING (`DIVIDE X BY 2 GIVING C`, `SUBTRACT X FROM 100 GIVING C`). CMPPROC.S |
| A9 | A `77` after an FD record joined the record; headers did not close groups. | **Fixed.** CMPDATA.S |
| A10 | Lengths over 255 wrapped (300 → 44). | **Refused**: new error 33, ITEM OR RECORD OVER 255 BYTES, for a group, an OCCURS total or a PICTURE. Real 16-bit lengths moved to list B. CMPDATA.S, CMPPIC.S |
| A11 | `REDEFINES` was ignored. | **Fixed**, for elementary items and groups; one REDEFINES group open at a time. CMPDATA2.S |
| A12 | `VALUE -5`, `+5`, `IS x` gave no value; `88 VALUE SPACES` compared with the text; 88 lists and THRU tested only the first value. | **Fixed** for the first three; an 88 list or THRU is now error 34, ONE VALUE ONLY — the lists themselves moved to list B. CMPDATA2.S |
| A13 | No negative literals outside COMPUTE; numeric DISPLAY never showed a sign. | **Fixed.** `MOVE -5`, `IF X < -1`, `ADD +3`; DISPLAY writes a `-` in front of a negative number only, so positive output is unchanged. CMPPROC2.S, VMSCRN.S |
| A14 | A clause body (`AT END`, `INVALID KEY`, `ON ERROR`) holding IF/EVALUATE/inline PERFORM runs on success too; a file verb with its own clause inside a clause jumps to the program start. | **Fixed.** A clause that opens an IF, EVALUATE or inline PERFORM runs to the statement that closes it (or the full stop); each clause level keeps its own end, four deep. CMPPROC2.S PDQCLS |
| A15 | `ROUNDED` is accepted and does nothing. Size errors are silent. | **Fixed** for ROUNDED: any `ROUNDED`, `GIVING` or literal-operand arithmetic goes through the expression stack and stores with the new `$58 POPDR`; `COMPUTE X ROUNDED =` is accepted (was error 24). GIVING also no longer cuts the second operand to the result's decimals first. Size errors stay silent — `ON SIZE ERROR` is list B. CMPPROC4.S PDARTL, VMMATH.S |
| A16 | Figuratives matched on four letters (`HIGH-SCORE`, `ZERO-FLAG`, `QUOTA`); a figurative as a DISPLAY or arithmetic operand was used as an item number. | **Fixed.** Whole words, every spelling; DISPLAY SPACE goes through a temp; `ADD ZERO TO X` is error 13. CMPCOM.S, CMPPROC.S |
| A17 | Mismatched MOVEs produced garbage; group MOVE did not space-fill. | **Fixed.** Number → text/group goes through the edit (MOVE); text/group → number is the new `$17 MOVD`, de-edited like ACCEPT; group MOVE space-fills; a quoted literal or SPACE into a number, or a numeric literal into text, is error 13. CMPPROC4.S PDMVTY, VMMOVE.S |
| A18 | A missing full stop in a data entry merged it with the next. | **Fixed** where the next entry starts with a level number on a later line: error 35, FULL STOP MISSING ABOVE THIS. CMPDATA2.S DDXVAL |
| A19 | Run-time stops said "at line 0". | **Fixed.** A LINE marker (3 bytes) before each statement that starts a new source line. CMPPROC4.S PDLMK |
| A20 | `REWRITE` or `DELETE` of a deleted record says `"00"` and takes no `INVALID KEY`. A REWRITE writes the new record over the deleted one, first byte included, so the record comes back. Found 2026-11-20 by `fchk2.cob` (D1 00 / R2 00 / D2 00). Past the end both say `"23"` and take `INVALID KEY` correctly. Also: a `READ` that fails on a deleted record leaves that record's bytes, `$FF` first, in the record area. | **Fixed 2026-11-20.** RECMAN.S `RMGONE` reads the record's first byte into `RMDBYT` before `RMREWR` or `RMDEL` writes anything; `$FF` is SNOREC, `"23"`, and the INVALID KEY runs. `RM1BYT` is the one-byte MLI block, shared with DELETE to stay inside LIB's `$5FFF` ceiling (22 bytes left). `fchk2` now gives R2 INV 23 / D2 INV 23, and the deleted record keeps its old bytes. The failed-READ record area is left as it is: the standard says it is undefined after a failed READ. |
| A21 | A 17th group level open at once gets no error. `DDPUSH` (CMPDATA.S) returns without a word when `NLVL` reaches `LVLMAX` (16), so that level is never pushed and its length is never patched. Found 2026-11-22 by reading, while `tools/refpage.js` built the limits table, and confirmed by `lvl17.cob`: `G17 []` and `MOVE G17` gave spaces, where G1 and G16 held `HELLO`. | **Fixed 2026-11-22.** `DDPUSH` raises **error 51, OVER 16 GROUP LEVELS NESTED**, at the 17th group's line (ERRMSG.S, `ERMAX` 51). The stack is not deepened: it has 80 bytes of OVLWORK with PDPNAM straight after. `lvl17.cob` now stops with error 51 at line 23; `lvl16.cob` (sixteen deep, the most) gives `G1 [HELLO] / G16 [HELLO] / W [HELLO]`. COMPILE1 +6 bytes, COBOL.AUX +29. |
| A22 | `DISPLAY a " " b UPON PRINTER` sent only `b` to the printer; `a` and the space went to the SCREEN. The compiler learns about `UPON` after the operands, and only the last was emitted in the printer form. Under `SET PRINTER TO SCREEN` the line came out split around a held blank line. REPORT's generated code prints one item per DISPLAY, which is why its tests never showed it. Found 2026-11-22 by `SALESDB.cob` option 5. | **Fixed 2026-11-22.** New opcodes `$97 DISPPN` / `$98 DISPPLN` (an item or literal to the printer, no line end). PDDREC (CMPPROC.S) keeps where each screen-form operand went; PDDPAT patches them to the printer forms when `UPON PRINTER` arrives; more than sixteen is error 13. In screen mode the first operand begins the line (VPLBEG, VPLIN) and the last ends it; a multi-operand line is never held back as blank. SALESDB prints whole lines to `print-test.txt` and previews them correctly. |
| A23 | A quoted literal of exactly 40 characters (the most allowed) lost its last character: `LITBUF` was `DS 40`, but a text literal is a length byte plus 40, so the 40th went into `TMPX`, which the pool search changed. SALESDB's 40-character prompt showed `?*`. Found 2026-11-22. | **Fixed 2026-11-22.** `LITBUF DS 41` (CMPVAR.S). |
| A24 | `ASSIGN TO WS-NAME` (a data name) compiled with no error and stored no path: the word after `TO` was skipped as if it were `TO`. Every `OPEN` used pool + $FFFF and said `"42"`. A `SELECT` with no `ASSIGN` did the same. Found 2026-11-22 (`asn.cob`: E1 42 / W1 42 / ...). | **Fixed 2026-11-22** by building `ASSIGN TO` a data name (DECISIONS §8.6): FCASN parks the name, FCRES resolves it (error 15 if unknown), and a file with no `ASSIGN` is error 18. |
| A25 | Every `PERFORM ... UNTIL` and every `NOT` ran backwards after the p-code moved to aux memory (DECISIONS §8.8): `PERFORM UNTIL WS-EOF = "Y"` left the loop before its first pass. CXFLIP (CMPCOND.S) turns a branch round by reading its opcode with EMGETW, then wrote the new one with `STA (ZPT1),Y` - into the old main-memory code buffer, which no longer holds the code. Found 2026-11-22 (`fchk`: T1 00 00; `qfile`, `qsort`: no rows). | **Fixed 2026-11-22**: CXFLIP writes the opcode back through EMSETW. Every other `(ZPT1)` store in the compiler was checked: they point at descriptors and literals, still in main memory. `fchk`, `qfile`, `qsort`, `conds` right again. |
| A26 | A pathname over 64 characters was cut to 64 and opened - possibly another file: PXBLD (PREFIX.S) stopped copying without a word, and VFNAM (VMFILE.S) cut an `ASSIGN TO` item to 64 before trimming its spaces. A name breaking ProDOS's rules came back as `"30"` or a wrong `"35"`. Found 2026-11-22 reading for DECISIONS §8.10. | **Fixed 2026-11-22** (§8.10): both refuse; every bad name is FILE STATUS `"31"` and "Bad file name" in the tools. `badnm.cob`, `badnames.ps1`. |

## B. Standard features missing (error 12 or similar)

**Started 2026-11-08.** Tests: `conds2.cob`, `perf2.cob` (in `listall.ps1`; `suite.ps1` runs everything).


- ~~Relations: `>=`, `<=`, `NOT =`, `GREATER THAN`, `EQUAL TO`, parentheses, mixing AND with OR, `A = 1 OR 2`~~ — **done 2026-11-08.** CMPCOND.S is a real grammar now (OR over AND over NOT over parentheses), jumping code with the exit lists chained through the placeholders; also `GREATER THAN OR EQUAL TO`, `A > 1 AND < 10`. And a bug: `NOT LESS` was compiled as LE.
- ~~Class and sign conditions~~ — **done 2026-11-08**: `IS [NOT] NUMERIC`, `ALPHABETIC`, `-UPPER`, `-LOWER`, `POSITIVE`, `NEGATIVE`, `ZERO`, through `$62 CLASS`.
- ~~`PERFORM ... TIMES`, `PERFORM ... VARYING`, `THROUGH`~~ — **done 2026-11-08**, in line and out of line. Not done: `VARYING ... AFTER`, `WITH TEST AFTER`.
- ~~`IF ... THEN`, `DISPLAY ... UPON CONSOLE`~~ — **fixed 2026-11-11**, found by trying IBM's COBCALC samples. `THEN` was read as an unknown verb (error 12); `UPON CONSOLE` went to the printer, because any word after `UPON` meant the printer. PDTHEN (CMPCOND.S), PDUPON (CMPPROC4.S); test `then.cob`.
- ~~`ON SIZE ERROR`, `REMAINDER`~~ — **done 2026-11-11**: a result with more integer digits than the receiver's PICTURE, over 14 digits, or a zero divisor leaves the receiver unchanged and runs the clause; **with no clause the run stops** (the user's choice), "Size error at line n". `SZON`/`SZCHK`/`SZSKP` ($59-$5B), VMMATH SIZE ERRORS, CMPARITH.S; `END-ADD` … `END-COMPUTE` accepted. Test `size.cob`. Not done: `NOT ON SIZE ERROR`, several receiving fields (`ADD A TO B C`).
- ~~`ADD X 20 GIVING Y`~~ — **fixed 2026-11-11**: a literal second operand with no TO was read as the TO and thrown away (PDARITH took the next token through PDWORD, which refuses a number).
- ~~Edited pictures with a repeat count~~ — **fixed 2026-11-11**: `PIC -(7)9.99` printed "(7)1.00"; the mask was pooled as written and the edit engine knows no brackets. PPEDT (CMPPIC.S, pass one) now pools it expanded.
- ~~`ACCEPT ... FROM DATE / TIME`, `DISPLAY ... UPON PRINTER`~~ — done 2026-11-08 ($85, $88/$89). `FROM DAY` is not, and DISPLAY's device byte is read and ignored (one printer).
- `INITIALIZE`, `SET ... TO TRUE`, `MOVE ALL "x"`, `GO TO ... DEPENDING`.
- `NOT AT END`, `NOT INVALID KEY`, and `ACCEPT ... ON EXCEPTION` / `END-ACCEPT`
  — all error 12 (checked 2026-11-20, `notat.cob`, `exc.cob`). QUICKREF had
  ON EXCEPTION as half built; nothing in the compiler knows the word.
- ~~`COPY`~~ — **done 2026-11-11**: `COPY name.` / `COPY "1/name".`, carried out by the lexer (CMPLEX.S LXCOPY), so both passes have it with no parser change. A `.SNP` is copied by division (the data piece in the DATA DIVISION, the paragraphs in the PROCEDURE DIVISION); a bare name is looked for in `0/` then `*/PROCS/`; one deep; errors 43–47. `OF` and `REPLACING` are refused (44). Test `copytest.ps1`.
- `SPECIAL-NAMES`: `CURRENCY SIGN`, `DECIMAL-POINT IS COMMA`, `CRT STATUS`, `CLASS`.
- Continuation lines; literals over 40 characters. ~~Names significant only to 10 characters; 64 names, 64 items~~ — **done 2026-11-11**: names to 30 characters, all significant (error 48 over 30), 128 names (the symbol table moved to the aux card, SYMAUX.S, LIB slot 108) and 128 items (descriptors on all of text page 2). Test `limtest.ps1`. ~~~380 bytes of literals~~ — **2,048 since 2026-11-11** (OBLIT moved to `$B400`, IOBUF2/3, which nothing uses during a compile); a full pool now says error 3 and not error 23. A numeric literal costs 9 bytes. The procedure library groups cost 14-27 of the 128 names each.
- ~~No run-time check that the object plus WORKING-STORAGE stays below the file buffers at `$B000`~~ — **done 2026-11-12**: pass two refuses it (error 49, PROGRAM AND DATA OVER 7,680 BYTES, COMPILE2 C2SIZE) and the VM checks again before running ("Program too big to run", VMCORE). Test `safetytest.ps1` (sz49).
- 16-bit item lengths (records over 255 bytes) — list A10 only refuses them.
- 88 with several values or THRU — list A12 refuses them with error 34.
- `PROGRAM-ID` is not stored; `EVALUATE`'s `WHEN` takes one value (no THRU, ALSO, OR); `START` ignores its relation.
- ~~Things outside the subset (`INDEXED`, `COMP-1`, `LINKAGE SECTION` …) are silently skipped rather than refused~~ — **done 2026-11-12**: every word pass one reads is checked against a list (CMPENV.S) and anything else is error 50, NOT PART OF THIS COBOL. Refused now: LINKAGE/SCREEN/REPORT/LOCAL-STORAGE SECTION, I-O-CONTROL, INDEXED, RECORD KEY, ALTERNATE, LINE SEQUENTIAL, COMP-1/2, INDEX, POINTER, JUSTIFIED, BLANK WHEN ZERO, INDEXED BY, DEPENDING ON, level 66, CURRENCY SIGN, DECIMAL-POINT, CLASS, CRT STATUS. Found on the way and fixed: a number in the IDENTIFICATION DIVISION (`DATE-WRITTEN. 11 NOV 2026.`) and the count in `RECORD CONTAINS 40 CHARACTERS` were read as level numbers; SELECT took ACCESS for ASSIGN and RECORD KEY for the relative key; key and status names were still cut to 10 characters. `SELECT OPTIONAL` and `VALUES ARE` now work. Tests `safetytest.ps1` (e50a-d, envok).
- ~~UPPERCASE ONLY / ANYCASE~~ — **done 2026-11-12** (the user's request): an ENVIRONMENT DIVISION clause saying what ACCEPT does with typed letters; UPPERCASE ONLY is the default. `$8F CASE`; CONGETLN folds when bit 7 of its length is set. Tests `caseup`, `caseany`.
- `JUSTIFIED RIGHT` and `BLANK WHEN ZERO` were refused rather than built: the library has the pieces (KEYWORDS.md) but the compiler never set the descriptor flags. Wanted.
- FORMAT's dictionary keeps field names to 10 characters (`ENAME DS 10`, FORMATD.S) while the compiler now takes 30 — a FORMAT-made screen cannot use a name like `RR-CATEGORY` (11). Found writing `SAMPLE-FIELDS.md`.

## C. The tools

- ~~REPORT slices 3–7~~ — **done 2026-11-08**: dictionary, bands, save/open, export, code view, and PLACE R in the editor. Control breaks are still REPORT.md §10's first open question.
- ~~Utilities COPY and VIEW are stubs~~ — COPY works and VIEW left the menu (2026-11-08).
- FORMAT cannot give a numeric field decimal places (the dictionary has the byte).
- Printers and the clock have never been tried on the machine.

## D. Documentation

- A complete list of every COBOL keyword and every p-code (VM opcode), and
  how they correlate: which statement or clause compiles to which opcodes,
  each opcode's operands, and the opcodes no keyword produces yet (`VCLASS`,
  `$88`/`$89`). Build it from VERBTAB and the VM's dispatch table, not from
  KEYWORDS.md, and check it against the compiler's output. It becomes a
  manual appendix.
- The reference manual (MANUAL/): chapters 3–7, front matter and appendices
  once list A is fixed. ~~CH01 must not claim the IIc or IIGS~~ — **done
  2026-11-25**, and the GitHub README no longer claims them either.
