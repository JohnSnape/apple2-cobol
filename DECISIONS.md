# Decisions, trade-offs and compromises

Started 2026-11-11, at the user's request, for the build guide. Every entry
says what was decided, why, what it cost, what was turned down, and where to
look in the source. Students should see that almost nothing here is "the
right answer" in general. Each one is the answer that fit a 128K Apple IIe
with two floppies and ProDOS 8.

Entries marked **(user)** were the user's call; the others were engineering
decisions made while building. Dates are when the decision was made or last
changed. `MEMMAP.txt` is the authority on addresses; this file is about the
reasons.

---

## 1. The machine

### 1.1 The target is a 128K enhanced IIe, 65C02, ProDOS 8, 80 columns
- **Why.** The enhanced IIe is the most common serious Apple II. 128K gives
  a second 64K bank for the source and the data; 80 columns are what a
  business program needs. The 65C02 adds `STZ`, `BRA`, `PHX`, `(zp)` and
  `JMP (abs,X)`, which the whole system leans on.
- **Cost.** A 64K II+, an unenhanced IIe and a 6502 are refused at boot
  (CHK128, CHK65 in SYSBOOT.S).
- **Turned down.** The IIGS (a separate 16-bit port, `COBOL16`, is a
  different project) and the IIc as stated targets.

### 1.2 No graphics anywhere
- **Why.** With no hi-res, everything above the two text pages is ours. That
  single choice is where most of the room in this system comes from.
- **Cost.** No charts, no graphic screens. Menus and forms are text.

### 1.3 /RAM is disconnected at boot
- **Why.** ProDOS's /RAM disk lives in the auxiliary 64K, which this system
  needs for the source, data records, and the cards' code.
- **Cost.** The student loses the RAM disk while the system runs; the book
  says not to keep files on it.

---

## 2. Memory

### 2.1 COBOL.SYSTEM stays at $2000; the tools are overlays called by `JSR`
- **Why.** ProDOS 8 has no "quit back to the caller", so there is no clean
  way to chain programs. One resident dispatcher that loads a tool into the
  overlay band and calls it as a subroutine is simple and fast.
- **Cost.** Only one tool is in memory at a time; switching tools reads a
  file from disk.
- **Turned down.** Chaining SYS programs through QUIT with a parameter file
  (the early design).

### 2.2 The shared runtime is a file, COBOL.LIB, with a frozen jump table
- **Why.** Every tool and every compiled program uses the same screen, file,
  number and record code. One copy at `$3000`, reached through a jump table
  whose base never moves, means a compiled program keeps working when the
  library is rebuilt. New services go on the end of the table.
- **Cost.** The table can never be reordered, and the library is now nearly
  full (18 bytes left), so new runtime code goes on the aux card instead.

### 2.3 The auxiliary language card holds code, behind a gate
- **Why.** The aux card's 16K at `$D000-$FFFF` was unused. BCD arithmetic,
  PICTURE editing, the error messages, the prefix table and (since
  2026-11-11) the compiler's symbol table moved there, giving main memory
  back to the programs.
- **Cost.** Every call crosses a gate (GATE.S) that swaps zero page, the
  stack and the card in and out: about 200 cycles a call. Code up there may
  not call ProDOS or the ROM, and anything a caller reads afterwards has to
  be left in main memory. The symbol table's code must also sit above
  `$E000`, because it switches the card's `$D000` bank to reach the names.
- **Turned down.** Running code from the 48K auxiliary bank through the
  firmware's XFER; that bank holds data only.

### 2.4 The source lives in auxiliary memory as fixed 80-byte records
- **Why.** EDIT and the compiler share it with no disk in between: compiling
  needs no disk once the source is loaded, and a syntax error costs nothing
  to run again. Fixed records make line *n* a multiply, not a search.
- **Cost.** A short line still costs 80 bytes. EDIT puts 512 records in a
  64K bank, so a program is capped at 512 lines on a plain 128K machine
  (each RamWorks bank adds 512 more).
- **Turned down.** Compressed or variable-length lines (slower to edit and
  to address).

### 2.5 Compile-time tables borrow memory nothing is using at that moment
- **Why.** While the compiler runs, nothing displays text page 2, opens a
  second file, or catalogues a disk. So:
  - the descriptors (128 x 8 bytes) are built on text page 2, `$0800-$0BFF`;
  - the literal pool (2,048 bytes) is in the second and third ProDOS file
    buffers, `$B400-$BBFF`;
  - a COPY book's lines go into the aux records after the program's.
- **Cost.** Each borrow is an invariant someone must not break later. They
  are written down in CMPCON.S and MEMMAP.txt for that reason.

---

## 3. The compiler

### 3.1 Compile to p-code, run it on an interpreter
- **Why.** On a machine this size the deciding argument is object size: a
  compiled program has to fit beside its own data, and p-code is far
  smaller than 65C02 code for the same statements. A much simpler code
  generator is the second prize. Prior art: UCSD Pascal, Abacus COBOL 64.
- **Cost.** Programs run slower than native code would. The interpreter
  spends most of its time on the screen and the disk, so for business
  programs it rarely shows.

### 3.2 Two passes, which are really one read split in two
- **Why.** The whole compiler does not fit in memory at once. Pass one reads
  everything up to `PROCEDURE DIVISION` (the data); pass two carries on from
  that line and writes the object. Each pass is an overlay; what pass two
  needs from pass one survives in memory the menu does not touch.
- **Cost.** The `PROCEDURE DIVISION` header has to be the last thing on its
  line, because pass two resumes at the *next* line.
- **Turned down.** Two reads of the PROCEDURE DIVISION (two parsers that
  must agree). Forward references are handled the way one-pass assemblers
  do it: a chain of fix-ups through the code, patched when the paragraph is
  found.

### 3.3 No third pass; stream the menu file instead (user, 2026-11-11)
- **The problem.** Pass two had 608 bytes left, and every remaining COBOL
  feature lands in pass two.
- **Options weighed.**
  - A third pass that only writes the object file: about 400 bytes freed,
    one more overlay load per compile.
  - A lexing pass that turns the source into tokens first: about 1.4K freed
    from both passes, but the tokens would need aux memory that the source
    already uses, roughly halving the longest program on a 128K machine.
  - Loading statement parsers on demand: too slow from a floppy.
- **Chosen.** `ACCEPT ... FROM MENU` used to load the whole `.MNU` into a 2K
  buffer at `$9C00`, and that buffer was what capped pass two. It now reads
  the file 81 bytes at a time and emits as it goes. Pass two can grow to
  `$A500`: 2,867 bytes free, with no extra pass and no slower compiles.

### 3.4 The first error stops the compile
- **Why.** Recovering from an error and carrying on means guessing what the
  programmer meant, and that guessing costs code the compiler cannot spare.
- **Cost.** One error at a time. Each message names the line, and an error
  inside a COPY book names the book's line as well.

### 3.5 Names: from 10 characters and 64, to 30 and 128 (user, 2026-11-11)
- **The principle.** A name exists only while compiling. The finished
  program refers to every item by number; no name is in the object. So a
  long name costs the running program nothing, and the limit is purely
  where the compiler can keep its table.
- **Before.** 64 names of 10 characters, 16 bytes an entry, in the 1K at
  `$1000` that both passes could reach. Names were compared on their first
  10 characters, and two that agreed there were reported as a duplicate,
  never silently merged.
- **Now.** 30 characters (the COBOL standard's maximum; the user chose 30
  over 32), all significant, and 128 names. The table moved to the aux
  card: the names in the card's spare `$D000` bank, the rest in arrays
  beside the code. A name longer than 30 is refused (error 48), never cut
  short. Lookup stays linear: 128 names is still nothing.
- **Bonus.** The lookup code left both passes, which gave pass two back 112
  bytes.

### 3.6 128 data items
- **Why.** Each item needs an 8-byte descriptor in the object, which the
  interpreter uses at run time. The descriptors took 512 bytes of text page
  2; once the literal pool left that page they could have all of it.
- **Cost.** Unlike names, items do cost the running program: 128 items is
  1K of the roughly 8K a program and its data share.

### 3.7 Numbers are 14-digit BCD
- **Why.** Business arithmetic must be exact to the cent. BCD avoids the
  binary fractions that make 0.10 inexact.
- **Cost.** Every numeric item and every numeric literal is a 9-byte NUM8
  cell, so 2,048 bytes of literal pool hold about 220 numeric literals.

### 3.8 A full stop closes every open IF (COBOL-74 style)
- **Why.** It matches how most older COBOL is written, and it costs nothing
  to support beside `END-IF`.
- **Cost.** A stray full stop inside an IF ends it early, which is standard
  but surprises newcomers. An IF, inline PERFORM or EVALUATE still open at a
  paragraph or the end is an error.

### 3.9 ON SIZE ERROR with no clause stops the run (user)
- **Why.** A result that does not fit its PICTURE is wrong money. Stopping
  is safer than printing a truncated figure.
- **Cost.** Stricter than the standard, which leaves the result undefined.

---

### 3.10 A program and its data must fit in 7,680 bytes, checked twice (2026-11-12)
- **The problem.** A compiled program is loaded at `$9200` and the VM puts
  WORKING-STORAGE straight after the code. The first ProDOS file buffer
  starts at `$B000`. Nothing checked that the two stayed apart, so a large
  enough program ran with its data on top of the buffers and gave no error.
  The 2,048-byte literal pool and 128 items made this more likely.
- **Chosen.** Pass two adds up the header, descriptors, literal pool, code and
  data, and refuses anything over 7,680 bytes: error 49, PROGRAM AND DATA OVER
  7,680 BYTES. The VM checks again before it runs anything ("Program too big
  to run"), for objects built before the check existed.
- **Cost.** About 80 bytes in pass two and 30 in the VM.
- **Turned down.** Moving the file buffers or the object. Every address there
  is already spoken for; the limit is real, and the fix is to report it.

### 3.11 A word pass one does not know is an error, not skipped (2026-11-12)
- **The problem.** Pass one used to skip any word it did not recognise. That
  kept the sample programs compiling, but it also let `LINKAGE SECTION`,
  `ORGANIZATION INDEXED`, `RECORD KEY`, `COMP-1`, `JUSTIFIED RIGHT`,
  `BLANK WHEN ZERO`, `CURRENCY SIGN` and level 66 compile. The program then
  did something other than what it said, and nothing told the student.
- **Chosen.** Every place pass one reads words now has a list of the words it
  takes. Anything else is error 50, NOT PART OF THIS COBOL, at its line. The
  lists are in `CMPENV.S`, with a comment saying why each word is taken or
  left out.
- **Kept, because they change nothing here.** `COMP-3`, `BINARY`, `COMP-4` and
  the rest of the COMP family (every number is a NUM8 cell anyway); `USAGE`,
  `DISPLAY`, `SIGN ... SEPARATE`, `SYNC`; FD clauses such as `LABEL RECORDS`
  and `RECORD CONTAINS`; `SOURCE-COMPUTER` and `OBJECT-COMPUTER`.
- **Refused for now, wanted later.** `CURRENCY SIGN` and `DECIMAL-POINT IS
  COMMA`. Accepting them before they work would print dollars and points in a
  program that asked for pounds and commas.
- **The IDENTIFICATION DIVISION stays free text.** Everything in it is skipped,
  numbers included, until `ENVIRONMENT DIVISION` or `DATA DIVISION`.
- **Bugs this found.** A date in the IDENTIFICATION DIVISION was read as a
  level number: `DATE-WRITTEN. 11 NOV 2026.` made an item called NOV at
  level 11. The count in `RECORD CONTAINS 40 CHARACTERS` became a level 40.
  SELECT knew its words by first letter and length, so `ACCESS` was read as
  `ASSIGN` and `RECORD KEY` as the relative key. Key and status names were
  still cut to 10 characters after names went to 30.

### 3.12 UPPERCASE ONLY is the default; ANYCASE is asked for (user, 2026-11-12)
- **What it controls.** What ACCEPT does with a letter the operator types. It
  does not affect the source: keywords and names are folded to capitals as
  they always were, and text in quotes is kept as written.
- **Written.** In the ENVIRONMENT DIVISION, normally under `SPECIAL-NAMES`:
  `UPPERCASE ONLY.` or `ANYCASE.`, with `INPUT`, `CASE` and `IS` allowed
  as noise words (`INPUT CASE IS ANYCASE.`).
- **The default is UPPERCASE ONLY (user).** This matches the feel of classic
  Apple II programs, and `IF ANSWER = "Y"` works whatever the operator types.
  ANYCASE keeps input exactly as typed.
- **How.** A new p-code instruction, `$8F CASE`, sets a flag in the VM. The
  VM starts every run at UPPERCASE ONLY, so only ANYCASE has to be compiled
  in; writing UPPERCASE ONLY emits it anyway, so the object matches the
  source. All three ACCEPT forms follow the flag: the console line, the field
  at `AT LINE / COLUMN`, and `FROM KEY`. `FROM MENU` always matches keys
  without regard to case.
- **Cost.** The library had 18 bytes free and this took 17. CONGETLN uses bit 7
  of its length byte to mean "fold". Every existing caller passes 80 or less,
  so none of them changes, but a console `ACCEPT` now reads at most 127
  characters. To save two bytes, the fold also turns `{|}~` into `[]^`, as
  on an Apple II with no lower case.

## 4. COPY (2026-11-11)

### 4.1 The lexer carries COPY out; neither pass knows it exists
- **Why.** Done in the lexer, both passes get it with no parser changes at
  all.
- **Cost.** About 790 bytes in each pass's lexer, against the 250 first
  estimated: the open, staging the book into aux memory, the `.SNP` pieces,
  the library search and five error messages.

### 4.2 The book is copied into aux memory and the file closed at once
- **Why.** Nothing stays open while the parser works, so a statement inside
  a book that needs a file of its own (a menu) still has the file buffer.
- **Cost.** A book uses aux records after the program's; a very large
  program plus a large book can run out (error 46).

### 4.3 One deep, and COPY ends its line
- **Why.** Nesting would need another place to keep a position, and the
  books FORMAT and REPORT write never contain COPY.
- **Cost.** A copybook may not contain COPY (error 45), and anything after
  the full stop on a COPY line is ignored.

### 4.4 A `.SNP` is copied by division (user)
- **Why.** FORMAT, REPORT and the procedure library write one `.SNP` in
  pieces (notes, then data, then paragraphs), the same pieces the editor's
  PLACE uses. Taking the data in the DATA DIVISION and the paragraphs in
  the PROCEDURE DIVISION lets the same file serve both.
- **Cost.** It is not standard COBOL: the same `COPY CUSTSCR.` is written
  twice and does different things in each place. A file with no lone `*`
  line is copied whole, as the standard does.
- **Turned down.** Copying the whole file always, which would have needed
  FORMAT and REPORT to export two files each.

### 4.5 A bare name looks in `0/`, then `*/PROCS/` (user)
- **Why.** `COPY DATES.` should find the procedure library without a path.
- **Cost.** A program's own `DATES.SNP` hides the library's.

### 4.6 `OF` / `IN` library and `REPLACING` are refused
- **Why.** A prefix name or a path does the job of `OF`, and `REPLACING`
  only pays when one book is copied twice under different names, which a
  generated screen or report never is.
- **Cost.** Error 44 for either. They can be added if a real program needs
  them.

---

## 5. Menus (2026-11-11)

### 5.1 FORMAT designs them and saves a `.MNU` (user)
- **Why.** The user wanted menus drawn the way forms are, saved as their own
  file type so the compiler knows one when it sees it, and optionally
  centred on the screen.
- **Cost.** Room in FORMAT, which now has 251 bytes left.

### 5.2 The menu is compiled into the program (user)
- **Why.** `ACCEPT x FROM MENU "MAIN"` reads `MAIN.MNU` at compile time, so
  the finished program needs no file to show it and a turnkey disk carries
  nothing extra.
- **Cost.** Changing a menu means recompiling.

### 5.3 The keys come from the text (user)
- **Why.** A line written `1) Add a contact` answers to `1`; `Q) Quit`
  answers to `Q`. Nothing to set up separately.
- **Cost.** Two lines with the same key can't be told apart, so FORMAT
  refuses the second (`Key already used`), and the compiler refuses a menu
  file that has one (error 42), since a `.MNU` can come from anywhere.

---

## 6. Files, prefixes and settings

### 6.1 The suffix stays in the ProDOS name (2026-11-07)
- **Why.** The type was first carried only in ProDOS's type byte, so
  `LEADS.COB`, `LEADS.OBJ` and `LEADS.DAT` were all the file `LEADS`, and
  running a sample overwrote its own source. ProDOS cannot hold two files
  of one name in a directory.
- **Cost.** Names lose four of ProDOS's fifteen characters to the suffix.

### 6.2 Relative files only, searched in order
- **Why.** Fixed-length records addressed by number are simple and fast on a
  floppy. Indexed files (ISAM, B-trees) were deferred to an advanced
  chapter.
- **Cost.** No `INDEXED` files; a search reads records in order.

### 6.3 Two files open at once
- **Why.** Each open ProDOS file needs a 1K buffer in main memory, and the
  system keeps three: two for a program's own files (RECMAN), and one for
  the system, so a program with two files open can still list a directory
  or load a query.
- **Cost.** A program that needs three files must close one first.

### 6.4 Prefixes in the ProDOS 16 style (user)
- **Why.** `*/` the boot directory, `0/` the program's directory, `1/`-`9/`
  the program's data directories, so a program never hard-codes a disk
  name.
- **Cost.** ProDOS 8 knows only one prefix, so the other ten are kept by
  this system (in the aux card) and expanded in every file name it handles.
  Prefixes a program sets last for the session; Utilities saves them.

### 6.5 `*/` cannot be changed (user)
- **Why.** The system loads its own overlays from `*/`; moving it would leave
  it unable to find itself.

### 6.6 The Utilities overlay is a file called UTILITIES
- **Why.** It moved out of COBOL.SYSTEM to make room, and the obvious name,
  `UTIL`, was already a directory on the disk.

---

## 7. The screen and the printer

### 7.1 The screen can stand in for the printer (user)
- **Why.** `SET PRINTER TO SCREEN` lets a program show a report a page at a
  time with the same code that prints it, switched at run time.
- **Cost.** Blank lines are held back and dropped at a new page, so a report
  laid out for paper looks right on the screen.

---

## 8. The toolchain and how it was tested

### 8.1 Merlin 8 is the assembler of record; Merlin32 stands in
- **Why.** The book's readers will use Merlin 8 on the machine. Merlin32 on
  the PC builds the same source in seconds, and its objects have matched
  Merlin 8's byte for byte every time they were compared.
- **Cost.** The source obeys Merlin 8's limits, which shape the code:
  - lines kept to 60 columns (Merlin 8 rejects long operands);
  - every PUT file under 24K, which is why several modules are split into
    numbered pieces (CMPPROC, CMPPROC2, CMPPROC3, CMPPROC4);
  - no forward-referenced EQUs (they assemble to garbage silently);
  - no `#'a'` constants (the editor upper-cases them), so hex is used;
  - no label as a `DS` fill value.
- **Decided (user, 2026-11-11).** The Merlin 8 builds for the book wait
  until the system is complete; Merlin32 plus the emulator verify it
  meanwhile.

### 8.2 Testing by driving the emulator
- **Why.** Every change is assembled, copied onto the disk image, and run in
  AppleWin by script, with screenshots compared against expected results
  (`tools/emu/`). Most bugs since 2026-11-07 were found this way.
- **Static checks** run on every build: sizes against ceilings, branch range,
  undefined names, registers used after a library call that does not keep
  them, branches into subroutines, and Merlin 8's forward-reference rules.

### 8.3 Documentation waits for the system (user, 2026-11-11)
- No more reference-manual chapters until the system is complete; the user
  will write the tutorial.
- **Gather, don't write (user, 2026-11-20).** `MANUALS-MAP.md` maps every
  planned chapter of the tutorial, the user's manual and the reference manual
  to the files that feed it, and lists the material that exists only in the
  source (the error list in `ERRMSG.S`, the run-time stops in `VMTAIL.S`).
  It writes no chapter text, so §8.3 stands.
- **Cost.** The map goes stale as the system grows; its line numbers are a
  snapshot. The split of `MANUAL/` into a user's manual (Ch 1, 2, 7, 8) and a
  reference manual (Ch 3–6, appendices) is shown, not decided.
- **A generated reference page (user, 2026-11-22).** `REFERENCE.html` is one
  long page in the shape of the GnuCOBOL Programmer's Guide, built by
  `node tools/refpage.js`. It holds only what can be generated: QUICKREF as
  the language chapters, and appendices read out of the source — the limits
  (each from its EQU, with file:line), compiler errors 1–51 (`ERRMSG.S`, with
  the test that raises each), the run-time messages (`VMTAIL.S`, with every
  place that raises them) and the ProDOS error codes. The statement entries
  (general format, rules, a tested example per verb) are a placeholder that
  cites this section. **Why:** these were MANUALS-MAP §4 gaps 1–3, and a
  table read from the source cannot drift from it. **Cost:** a missing
  symbol shows as a red "?" and a warning, not a failed build; the "when"
  line for each run-time message is written in `refpage.js` and must follow
  the interpreter by hand. **Turned down:** writing the statement entries
  now (§8.3), and copying the GnuCOBOL guide's text (theirs; only the shape
  is borrowed).

### 8.4 A deleted record cannot be rewritten or deleted (2026-11-20)
- **Decided.** `REWRITE` or `DELETE` of a record whose first byte is the
  `$FF` deletion mark is FILE STATUS `"23"` and takes `INVALID KEY`, as the
  standard says and as `READ` already did (FIXLIST A20). RECMAN reads one
  byte (`RMGONE`) before it writes.
- **Why.** Before, REWRITE wrote straight over the mark and so un-deleted the
  record with a `"00"`; a program that tested INVALID KEY to mean "not on
  file" was told the opposite.
- **Cost.** One extra ProDOS READ (one byte) and SET_MARK per REWRITE and
  DELETE. 36 bytes of COBOL.LIB, paid for by sharing the one-byte MLI block
  with DELETE (`RM1BYT`); 22 bytes remain below `$5FFF`.
- **Turned down.** Letting REWRITE revive a deleted record, as a cheap
  "undelete": it is not standard, and WRITE to that key already does it.

### 8.5 Groups nest sixteen deep; a seventeenth is error 51 (2026-11-22)
- **Decided.** A 17th group open at once is compile error 51, OVER 16
  GROUP LEVELS NESTED, at its own line (`DDPUSH`, CMPDATA.S; FIXLIST A21).
  It is a new number rather than error 8 or 33, whose texts would point the
  programmer at the wrong thing.
- **Why.** The push used to be skipped without a word: the group was never
  measured, kept a length of 0, and showed as nothing - a wrong result with
  no error, the class this system exists to not have.
- **Cost.** 6 bytes of COMPILE1 and a 28-byte message in COBOL.AUX (4,113
  spare). Every error list that said 1–50 is now 1–51.
- **Turned down.** A deeper stack, to the 49 levels the standard allows: it
  lives in 80 bytes of OVLWORK with PDPNAM straight after it, and sixteen
  nested groups is far past any record a program here will describe.

### 8.6 ASSIGN TO a data name (user, 2026-11-22)
- **Decided (user).** `SELECT f ASSIGN TO WS-NAME` names the file by a data
  item, read at every `OPEN`, so one program can keep one database for the
  east coast and one for the west (the user's example). The quoted form
  stays; `TO` is optional.
- **How.** The compiler parks the name as text beside the key and status
  (a third slot, CMPFILE.S) and FCRES makes it an item number; FLFLG bit 2
  becomes bit 2 of OPEN's ctl byte, which was unused. VMFILE then copies the
  item into a 65-byte buffer with the trailing spaces off and the letters
  upper-cased, and hands RECMAN that as the length-prefixed name a literal
  would have been. Prefixes (`1/EAST.DAT`) work as before.
- **Also refused now.** An undeclared ASSIGN name is error 15; a `SELECT`
  with no `ASSIGN` is error 18. Both used to compile and fail at run time
  with `"42"` (FIXLIST A24).
- **Cost.** VM +158 bytes, COMPILE1 +169 (60 of them the third name slot),
  COMPILE2 +11. No new opcode. A numeric item as the name is not refused;
  it would open whatever its eight bytes spell.
- **Turned down.** Choosing the folder only (`SET PREFIX` with a fixed
  name): it works today, but every database needs a folder made outside
  COBOL. And `ASSIGN USING`, a vendor spelling of the same thing.
- **CMPDATA.S was split** the same day: FILE-CONTROL went to CMPFILE.S,
  because this and the A21 notes took CMPDATA.S past Merlin 8's 24K
  PUT-file limit (check.js warned). Nothing in the moved code changed.

### 8.7 Every operand of DISPLAY ... UPON PRINTER goes to the printer (2026-11-22)
- **Decided.** Two opcodes, `$97 DISPPN` and `$98 DISPPLN`: an item or a
  literal to the printer without ending the line. The compiler still emits
  the screen forms first, because it meets `UPON` only after the operands,
  and patches them in place when it does - they are the same three bytes
  (FIXLIST A22).
- **Why.** Before, only the last operand reached the printer and the rest
  went to the screen. `SALESDB` option 5 showed it; REPORT's code prints one
  item per DISPLAY and never did.
- **Cost.** COMPILE2 +142 bytes, VM +148; at most sixteen operands before
  the last, and more is error 13 rather than a line split between screen and
  paper. Under `SET PRINTER TO SCREEN` a line of several operands is never
  held back as blank, even if every operand is spaces; the hold is for the
  one-item blank lines REPORT pads its pages with.
- **Turned down.** Reading ahead for `UPON` before emitting anything: the
  lexer hands back one token, not a statement.

### 8.8 Room for bigger programs (user, 2026-11-22)
- **Decided (user: "we need space for our users").** Two changes, both
  invisible to a program:
  1. **Programs load at `$8000`, not `$9200`.** The interpreter is 7,051
     bytes and ends at `$7B8A`; the 5.7K above it was unused. Object and
     WORKING-STORAGE together may now be **12,288 bytes** (was 7,680);
     error 49's text says so. Objects already on a disk run unchanged:
     nothing in one holds an address (PCODE.md 2).
  2. **The compiler builds the p-code in auxiliary memory**, at `$AC00-$BEFF`
     in bank 0: **4,864 bytes** of code (was 2,816 at `$A500` in main). The
     source's 512 records of 80 bytes end at `$AC00`, and QUERY's cursor
     uses the top of the bank only while a program runs. Every write, patch
     and read goes through EMXMOV (CMPEMIT.S) and the library's AXPUT/AXGET;
     the object writer and the DISPLAY ... AT shift copy through `$A500`,
     which is now a staging area and room for COMPILE2 to grow.
- **Why.** SALESDB, a seven-item menu program, filled the old code buffer
  four lines from the end. The limits came from where things sat in main
  memory, not from the machine.
- **Cost.** The interpreter has 1,141 bytes left to grow below `$8000`
  (it had 5.7K, most of it never going to be used). Each byte the compiler
  emits is one AUXMOVE, about two hundred cycles: a 4K program costs about a
  second more to compile. The literal pool (2,048) and the descriptors (128
  items) are unchanged and are now the next limits a big program meets,
  with the source itself: 512 lines on a 128K machine.
- **Not broken.** MEMMAP's "aux holds data, never code": the code in aux is
  data while it is being compiled; nothing ever runs from aux.
- **Turned down.** Paging p-code from aux at run time (MEMMAP, decision 7).
  Chaining programs is the answer past 12K, and is not decided.

### 8.9 The missing keywords, in three batches (user, 2026-11-22)
- **Decided (user).** Build the keywords QUICKREF marks ✘ that are not
  excluded on purpose - **all three batches, one batch at a time**, "so we
  don't break something then have to figure out how to fix it". Each batch
  is built, tested in AppleWin with its own programs, regression-run and
  baselined before the next one starts.
  1. `JUSTIFIED RIGHT`, `BLANK WHEN ZERO`, `CURRENCY SIGN IS`,
     `DECIMAL-POINT IS COMMA`, `MOVE ALL`, `INITIALIZE`, `SET ... TO TRUE`,
     `NOT AT END` / `NOT INVALID KEY` / `NOT ON SIZE ERROR`, `ACCEPT ...
     FROM DAY`, `GO TO ... DEPENDING ON`, `PERFORM VARYING ... AFTER`,
     `EVALUATE` `THRU` / `ALSO`, 88s with several values or `THRU`.
  2. `STRING`, `UNSTRING`, `INSPECT` (built second: the biggest gain).
  3. `CRT STATUS`, `ACCEPT ... ON EXCEPTION`, continuation lines and
     literals over 40, `CLASS`, `COPY ... REPLACING`, `START`'s relation.
- **Stays out, on purpose:** `ALTER`, debug declaratives, segmentation,
  `COMP-1`/`COMP-2`, `LINKAGE`/`CALL`, the `SORT`/`MERGE` verbs,
  `SCREEN SECTION`, Report Writer, `ORGANIZATION INDEXED`.
- **Where the code goes.** New run-time code on the aux card (about 4K
  free) through the gate, as BCD and PICTURE are; VM has 1,141 bytes and
  COBOL.LIB 22. If batch 2 does not fit, RUNBASE moves up a page or two.
- **Order.** After the size work (§8.8) is tested and the customer/ledger
  example is built.

### 8.10 Bad file names are refused, not converted (user, 2026-11-22)
- **Decided (user: "Check and refuse").** A name that breaks ProDOS's rules -
  each part 1-15 characters, starting with a letter, then letters, digits
  and periods; 64 characters in all - is refused with a clear answer:
  FILE STATUS **"31"** ("bad file name", GnuCOBOL's code for an
  inconsistent file name) in a program, and **"Bad file name"** in the tools.
  Until now ProDOS's own `$40` came back as "30" on OPEN OUTPUT, as a wrong
  "35" (not on the disk) on OPEN INPUT and I-O, and as "ProDOS error $40" in
  the tools.
- **Turned down: converting the name** (`MY DATABASE!.DAT` to
  `MY.DATABASE..DAT`). Two names can become one file (`EAST COAST` and
  `EAST!COAST`), and a leading digit or a sixteenth character cannot be
  fixed by swapping characters. A program that wants to convert does it
  where the user can see it - `INSPECT ... REPLACING` once keyword batch 2
  is built.
- **Also:** a pathname over 64 characters is cut short today (PREFIX.S
  PXBLD) and could open a different file; it becomes a bad name too.
- **Order.** Built and tested on its own, after the size work (§8.8) passes
  and before the customer/ledger example.
- **Built 2026-11-22.** The check is in ONE place, the prefix service's
  EXPAND (PREFIX.S PXCHK), which every load, save and OPEN already goes
  through. A bad name goes on to ProDOS as `!`, which it can only refuse
  (`$40`), and the public byte NAMBAD (`$0E7C`) is set. RECMAN turns `$40`
  into "31"; EDIT, Utilities and RUN turn it into "Bad file name"; FORMAT,
  QUERY and REPORT, whose messages are fixed text, read NAMBAD. Chosen over
  a check at every prompt because the suffix (.DCT, .OBJ) is added after
  the prompt, and over following ProDOS's error code through each tool
  because several of them no longer hold it when they report.
- **Over 64 is refused in three places:** PXBLD (an expanded name),
  VMFILE's VFNAM (an `ASSIGN TO` item, which was cut to 64 BEFORE its
  spaces were trimmed) and SET PREFIX (Utilities says "Bad file name"; a
  program's `SET PREFIX` is left unchanged, as before - it has no status).
- **A prefix that is not set** (`2/X.DAT` with 2/ empty) is a bad name
  too, as ProDOS's `$40` already made it.
- **Not changed:** FISFX still shortens a name to make room for its
  suffix (FORMAT's `ABCDEFGHIJKLMN` saves as `ABCDEFGHIJK.DCT`) - that is
  the tools choosing the file's name, not a mend of a bad one.
- Tests: `progs/badnm.cob` (B1-B10) and `badnames.ps1` (every tool).

### 8.12 An offshoot on an OS of our own (user, 2026-11-22)

(8.11 is reserved for the file-name ACCEPT, written when it is tested.)

The user wants a COBOL offshoot running on our own OS in the language
card, the way ProDOS sits there. The user chose a new small kernel
(not SWA), ProDOS-format volumes, a fork in `P:\COBOLOS`, and to
design it now. The kernel supplies the 16 ProDOS calls this system
makes, with ProDOS's numbers, parameter blocks and error codes, so
these binaries run on it unchanged. This tree stays the ProDOS build.
The plan is `P:\COBOLOS\DESIGN.md`; its decisions are logged in
`P:\COBOLOS\DECISIONS.md`.

### 8.13 This build refuses to start under COBOL.OS (user, 2026-11-24)

The user decided on two builds of COBOL: this one for ProDOS, and the
one in `P:\COBOLOS\cobol` for COBOL.OS. Each refuses to run on the
other system. The user's reason: once COBOL ships with its own OS,
someone will start it under the wrong one, and a build that expects
the other system overwrites part of it. This build keeps ERRBUF and
the prefixes at `$BD00`, and that is COBOL.OS's block buffer.

- **The test:** COLD's first instruction reads `$BFFF`, the kernel
  version byte. It is small under ProDOS (`$24` for 2.4.x) and `$C0`
  or more under COBOL.OS. If it is `$C0` or more, MERRQ prints two
  lines, waits for a key and QUITs:
  - "This COBOL needs ProDOS, not COBOL.OS."
  - "Start it from ProDOS - press a key"
- **What changed:** SYSBOOT.S and EQUATES2.S (`KVERS EQU $BFFF`).
  Only COBOL.SYSTEM changed, from 2,201 to 2,293 bytes.
- **The COBOL.OS build** has the mirror-image test (its DECISIONS
  6.1, 6.7).
- **Not yet deployed to `COBOL32.po`.** The disk is waiting on 8.11's
  test anyway. `deploy.ps1 -Obj COBOLSYS` puts it there.
- **Not yet run.** It is to be tested in AppleWin on a COBOL.OS disk
  carrying this build.


### 8.14 DELETE erases in every one-line input (user, 2026-11-24)

EDIT always took DELETE (`$7F`) as erase-left. The five routines
that read one typed line threw it away:
- `TDGETLN` (`GETLN80`);
- `CONGETLN`;
- `DSACC`;
- SCRINP's `EDITFLD`;
- PROMPT's `LINEIN`.

The //e's DELETE key is where a typist reaches to fix a slip. The
user asked for it to erase there too, the same as the left arrow, in
both builds.

- **The change costs no bytes.** Each routine has the key at seven
  bits before it tests, so its `CMP #$7F / BCS ignore` was only ever
  true for DELETE. That `BCS ignore` is now `BEQ erase`.
  - Two bytes change at each of seven places: four in COBOL.LIB,
    and PROMPT's copy in FORMAT, QUERY and REPORT.
  - Every object keeps its size, and LIB still ends below `$6000`.
- **Why not a separate test for `$7F`.** Adding `CMP #$7F / BEQ` to
  each routine was tried first, in the COBOL.OS build. It put LIB 15
  bytes into `LOWBASE`.
- **The COBOL.OS build** made the same change first (its DECISIONS
  6.12). These five source files are now identical in both trees.
- **Deployed and taken back the same day.** `deploy.ps1 -Src TEXTDRV,
  CONSOLE,DSCREEN,SCRINP,PROMPT -Obj LIB,FORMAT,QUERY,REPORT` put it on
  `COBOL32.po`. FORMAT, QUERY and REPORT differed from the disk only by
  the DELETE bytes. COBOL.LIB did not: it also carried 8.11's CGWARN
  beep in CONGETLN, whose VM half was not on the disk. Nothing zeroes
  `$0E7D` at start-up, so a plain ACCEPT could have beeped at random.
  - At the user's word the disk was restored from
    `COBOL32.before-delete.po`, and it is byte-identical to the disk
    before the deploy.
  - **DELETE goes onto the disk with 8.11**, once `progs/fnacc.cob`
    has tested it. That deploy is 8.11's list plus
    `-Src TEXTDRV,DSCREEN,SCRINP,PROMPT -Obj FORMAT,QUERY,REPORT`.
  - The lesson: before deploying LIB, compare the disk's COBOL.LIB
    with the build from before the change. If they differ, the build
    is carrying something else.
- **Not yet run under ProDOS.** The COBOL.OS side's
  `tools/suite/deltest.ps1` tests the same routines.

### 8.15 Command letters are folded everywhere (user, 2026-11-24)

KEYS.md §9 was rewritten from the code. That showed five places that
tested a command letter without folding it to a capital, so with Caps
Lock up they did nothing:
- PROMPT's `LINEIN` command walk: all of FORMAT's Open-Apple commands.
- `LINEIN`'s SA-D and SA-C.
- FORMAT's field-type answer, A/X/N/B, and its SA-D.
- REPORT's OA-G, OA-A and OA-D. Its other letters were already folded.

Most dispatchers already folded with `AND #$DF`. The user said fix them.

- **The change:**
  - **`LINEIN`** folds the letter into `CMDCH` and walks `CMDLIST` against
    that. The old `LDA CHKEY / STA CMDCH` at `LICK` goes, so the
    overlays read the capital.
  - **`LISA`** and FORMAT's **`GETTYPE`** get an `AND #$DF`. ESC is `$1B`,
    which survives it.
  - **`RPTENT`** folds once at `RPKOA`. The fold that used to sit at
    `RPKO3` is gone, so it is the same size.
- **Sizes:** FORMAT +8, QUERY +4, REPORT +4. `check.js` says they all fit;
  FORMAT has 331 bytes to spare below `$B000`. LIB and EDIT are
  unchanged.
- **The COBOL.OS build:** the same change, made there first (its
  DECISIONS 6.13). PROMPT.S, FORMATD.S and RPTENT.S are identical in
  both trees.
- **The test** is the COBOL.OS suite's `deltest.ps1` step 2b: a pasted
  lowercase `a` at FORMAT's type question must add the field.
  - **Not tested:** the lowercase Open-Apple commands. AppleWin sends
    Alt-letter as a capital while its Caps Lock is down, which is how
    the tests run.
- **Not yet deployed.** It goes on with 8.11 and 8.14 (HANDOFF).

### 8.16 The system on 800K disks **(user)**

COBOLOS DECISIONS 6.14 has the detail.
- **The disk:** `COBOL800PD.po` is this build on a fresh 800K volume named
  COBOL, made by `P:\COBOLOS\tools\emu\mk800.ps1`. It has 1,329 blocks
  free. The source stays on `COBOL32.po`.
- **The test:** in AppleWin on 2026-11-24 it booted, catalogued, and ran
  FORMAT. DELETE erased in FORMAT and in an ACCEPT, and FINANCE compiled,
  ran and wrote its file.
- **8.11 is on it untested.** This build's LIB and COMPILE2 include 8.11,
  so the disk carries code that is not yet on `COBOL32.po`.

### 8.17 ESC cancels a typed name **(user)**

COBOLOS DECISIONS 6.15 and 6.16 have the detail.
- **The bug:** `UNAME`, in both `SYSUTIL.S` and `UTILD.S`, tested only
  whether anything was typed. It ignored GETLN80's C=1 for ESC, so ESC
  after a typed name acted as RETURN:
  - DELETE a file destroyed the file;
  - RENAME and COPY went on to the second name;
  - the turnkey copier went on;
  - RUN ran the program.

  It has been on `COBOL32.po` all along.
- **The fix (the user said yes, 2026-11-25):** `BCS UNX` after
  `JSR UPROMPT` in both copies. COBOL.SYSTEM is now 2,295 bytes and
  UTILITIES 2,778, both +2 and both under their ceilings.
- **The test:** on `COBOL800PD.po`, ESC kept the file in DELETE, left
  RENAME and RUN without going on, and RETURN still deleted.
- **Not on `COBOL32.po`.** It goes on with 8.11, 8.14 and 8.15.

### 8.18 On GitHub as JohnSnape/apple2-cobol **(user)**

The user asked on 2026-11-25 for this tree to go on GitHub, as SP COBOL
had, and made these four calls:
- **Only this tree.** COBOL.OS was to stay private for now. **Changed
  the same day:** the user asked for the kernel to have a repository of
  its own, so that others can use it in their own projects. It is
  `JohnSnape/cobol-os`, kernel only (COBOLOS DECISIONS 6.17). The
  COBOL.OS build of this system is still not published.
- **Code and manuals only.** The source, the tools, `MANUAL/` and the
  design documents are public. These stay private through `.gitignore`:
  - the book: `chapters/`, `GETTING-STARTED/`, the InDesign files,
    `OUTLINE`, `CHAPTER-NOTES` and `MANUALS-MAP`;
  - the working notes `HANDOFF` and `STATUS`;
  - `BBASIC`;
  - the internal `README`.
- **No disk images.** There is no release. Anyone who wants it builds it
  and supplies ProDOS 8 themselves.
- **The licence is MIT.**

How it is set up:
- **The public README is `.github/README.md`.** GitHub shows it in place
  of the internal one, which is left alone.
- **`.gitattributes` sets `* -text`**, so every byte is kept, including
  the sample programs' CR endings.
- **These are left out too:** `build/`, the test screenshots and the
  stage folders, the root `.txt` copies (except `MEMMAP.txt`), and every
  disk image.
- **Commits are by "John Snape"**, through the GitHub noreply address,
  as for SP COBOL.
- **The folder is now a git repo**, with `main` tracking `origin`.
- **New work is not public until it is committed and pushed.** Neither
  is `COBOL32.po`.
