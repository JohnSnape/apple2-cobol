# Assembling the system — the checklist

The **do** to `BUILD.md`'s **why**. Follow it top to bottom; every step that can
silently ruin a later one says so. Written 2026-08-16 against the tree as it
stood that evening — the tree is still moving, so treat the size *estimates* as
advisory and the *ceilings* as law.

Environment: AppleWin set up as an enhanced //e with a RamWorks III at 8 MB (the
real machine this targets has the same), and the 32 MB ProDOS image
`COBOL32.po` on the hard-disk controller in slot 7. Merlin 8 lives on that image,
so no floppy is needed. Sources are in `/COBOL/SRC/`, objects go to
`/COBOL/OBJ/`.

---

## Phase 0 — already done on the PC

- All fifteen assemblies - the nine stubs and the six harnesses - now carry a
  `DSK /COBOL/OBJ/name` line, so each writes its object straight to the right
  directory.  The four older harnesses were given theirs on 2026-08-23; their
  objects used to land in `SRC/`. If your Merlin 8 rejects a
  pathname on `DSK`, change it to the bare name (object lands in `SRC/`, copy it
  over afterwards) — that is the one assembler-version unknown.
- The static checker passes all fifteen assemblies clean: no duplicate labels,
  no unresolved symbols, no branch out of range, and both dispatch-table halves
  exactly 256 entries. It really checks that last one as of 2026-08-23; the
  sentence was here before the check was.
- Three more passes also run clean: `strlen.js` (every length-prefixed string
  against the bytes after it), `datamap.js` (no two symbols on one data-region
  address), and `classify.js` (no file `PUT` by nothing).

## Phase 1 — build the disk image (CiderPress II)

**Done 2026-11-07:** `D:\AppleWin1.32.0.0\COBOL32.po` was built exactly this
way with the `cp2` command-line tool. Repeat these steps only to rebuild it, or
re-import `SRC/` after a source change.

1. Make a 65,535-block ProDOS image with volume name `COBOL`, which is what
   every `DSK /COBOL/OBJ/...` line expects. Create `SRC/` and `OBJ/` in its
   root, so the paths are `/COBOL/SRC/` and `/COBOL/OBJ/`.
2. Import all **102 `.S` files** from `P:\COBOL\src` into `SRC/`
   with **cp2's `merlin` importer**, the same one DeskWorks' `SYNC-DISK.ps1`
   uses:
   `cp2 import COBOL32.po merlin SRC` (run from a folder holding a `SRC`
   subfolder of the `.S` files). It converts line endings, stores Merlin's own
   format and sets type TXT. The 2026-11-07 import was checked by exporting
   `LIB.S`, `EQUATES.S` and `CMPPROC.S` back: all three match the tree line for
   line, spacing aside.
   - **Keep the `.S` in the names.** Merlin 8 under ProDOS adds `.S` itself, so
     `PUT EQUATES` opens `EQUATES.S`. A file renamed to plain `EQUATES` is
     **not** found. (Earlier versions of this file said the opposite; they were
     wrong. DeskWorks has always assembled with `.S` names.)
3. Import the **4 `.COB` files** into the volume root **raw, no conversion**
   (`cp2 add`). They are already CR-terminated, and converting them again is
   the classic way to double every line ending. Use bare names (`SKEL`,
   `MEDIA`, `LEADS`, `FINANCE`) and set type `$47`.
4. Copy `PRODOS`, `BASIC.SYSTEM`, and Merlin 8's `MERLIN.SYSTEM`, `PARMS` and
   `UTIL/` to the volume **root**, in that order after `PRODOS`. With
   `MERLIN.SYSTEM` the first `.SYSTEM` file, the image boots straight into
   Merlin and no slot 6 floppy is needed. Phase 3 changes the order.

## Phase 2 — the nine assemblies

Boot the image (slot 7). It comes up in Merlin. Set the prefix to `/COBOL/SRC/`.
`PUT` resolves against the prefix, and this is the step that makes all 70 `PUT`
files findable. Load each stub by its bare name (`LIB`); Merlin adds the `.S`.

For each row, in this order: **load the stub, `ASM`, read the symbol, compare.**

| # | Load | Writes | Read this symbol | Expect ≈ | Must be below |
|---|---|---|---|---|---|
| 1 | `LIB` | `COBOL.LIB` | `LIBEND` | `$5FE3` | `$6000` |
| 1a | `AUXLC` | `COBOL.AUX` | `AUXEND` | `$E324` (PREFIX.S puts the prefix table at `$F800`, above it) | `$FFFA` |
| 2 | `COBOLSYS` | `COBOL.SYSTEM` | (length ≈ `$0872`) | ends ≈ `$2872` | `$3000` |
| 2a | `UTIL` | **`UTILITIES`** (not UTIL - that is a directory) | (length ≈ `$0ADA`) | ends ≈ `$AADA` (loads at `$A000`) | `$B000` |
| 3 | `EDIT` | `EDIT` | `EDEND` | `$8775` (loads at `$6000`) | `$9800` |
| 4 | `FORMAT` | `FORMAT` | `FMTEND` | `$AE96` | `$B000` |
| 5 | `QUERY` | `QUERY` | `QRYEND` | `$9179` | `$B000` |
| 6 | `REPORT` | `REPORT` | `RPTEND` | `$7FC9` (loads at `$6000`) | `$97E0` |
| 7 | `VM` | `VM` | `VMSIZE` | `$7A03` (loads at `$6000`) | `$9200` |
| 8 | `COMPILE1` | `COMPILE1` | `CMPEND` | `$7985` (loads at `$6000`) | `$A500` |
| 9 | `COMPILE2` | `COMPILE2` | `CMPEND` | `$965D` (loads at `$6000`) | `$9C00` (ACCEPT FROM MENU reads a .MNU at `$9C00`) |

- The estimates are a static pass, good to ±1–2%. **A disagreement bigger than
  that means the wrong thing was assembled** — usually a stale file on the
  image.
- A ceiling failure is a stop: nothing downstream behaves, and no amount of
  testing will say why. `BUILD.md` §5 names what each overrun corrupts.
- The nine do not depend on each other's objects — a failure in one does not
  block trying the others, so collect all the errors in one sitting.
- **Expect the first pass to throw Merlin errors the PC-side checker cannot
  predict.** It reproduces Merlin's arithmetic to half a per cent but it is not
  Merlin. Fix, note, re-`ASM` — the stubs reassemble in seconds because `PUT`
  streams from disk.

## Phase 3 — file type and the boot order

1. `COBOL.SYSTEM` in `/COBOL/OBJ/` is BIN. **Change it to SYS (`$FF`)** with
   CiderPress or Copy II Plus. (If your Merlin has `TYP $FF`, add it beside the
   `DSK` line instead and reassemble once to confirm.)
2. Copy to the image **root**, in this order — ProDOS launches the *first* SYS
   file whose name ends `.SYSTEM`, in directory-entry order:
   - `PRODOS` (already there)
   - `COBOL.SYSTEM` — **before** `BASIC.SYSTEM`
   - `BASIC.SYSTEM` (kept: it is how the harnesses and, for now, compiled
     programs run)
   - `COBOL.LIB`, `COBOL.AUX`, `EDIT`, `FORMAT`, `QUERY`, `REPORT`, `VM`, `COMPILE1`,
     `COMPILE2`, `SKEL`
3. If `BASIC.SYSTEM` was on the image first, delete it and re-add it after
   `COBOL.SYSTEM`, or the machine boots to an Applesoft prompt forever.
4. **`MERLIN.SYSTEM` is also ahead of it on `COBOL32.po`.** Do the same with
   it: delete it and re-add it after `COBOL.SYSTEM`, or the disk keeps booting
   into Merlin. Once it is behind, start Merlin from `BASIC.SYSTEM` with
   `-MERLIN.SYSTEM`.

## Phase 4 — the harnesses, and two of them are not optional

> **Since 2026-11-08 the harnesses that do arithmetic or editing cannot run
> from BASIC.SYSTEM as described below.** BCD, PICTURE and ERRMSG moved out of
> `COBOL.LIB` into `COBOL.AUX`, which only `COBOL.SYSTEM` copies into the
> auxiliary language card at boot (`GATE.S`). `BCDTEST`, `PICTEST` and
> `QRYTEST` need a small loader of their own before they run again; until then
> the system itself, through the menu, is the test.

Six more assemblies, same recipe, no ceiling worries: `BCDTEST`, `PICTEST`,
`QRYTEST`, `KEYTEST`, `OBJTEST`, `LEXTEST`. Each runs from BASIC.SYSTEM in
**two steps** — they call the library, which nothing has loaded yet:

```
BLOAD COBOL.LIB,A$3000
BRUN BCDTEST
```

**`BCDTEST` and `PICTEST` come before anything else runs.** `PCODE.md` §5 asks
for them in that order and gives the reason: `BMUL` and `BDIV` are the
least-exercised code in the tree, a product index is either exactly right or
off by one with nothing in between, and PICTURE's back-fill is the part most
likely to be off by one place. Both take two minutes, both need only
`COBOL.LIB`, and every figure this system will ever print for money goes
through what they exercise. Running them after the compiler works means a
wrong answer arrives with four other things to blame it on.

Neither reports PASS, and that is deliberate: each case prints what it got
beside what it should have got, and you read the screen. `BCDTEST` stops twice
on the way down the arithmetic table; `PICTEST` brackets every edited result,
because trailing spaces are half of what a PICTURE does and an unbracketed
line cannot show them.

`AXTEST` and `PG2TEST` are older `ORG $2000` spikes, standalone, already proven.

## Phase 5 — the smoke ladder

Each rung proves the ones below it. Stop at the first failure; `BUILD.md` §8
maps symptoms to causes.

0. **`BCDTEST` and `PICTEST`, from BASIC.SYSTEM, before you boot the system at
   all.** They need only `COBOL.LIB`, so they are the one rung that does not
   depend on any of the others, and they are the rung everything above them
   quietly assumes. Rung zero because arithmetic that is wrong here is wrong
   in every report the machine ever prints, and finding that out at rung seven
   means finding it out with the compiler and the interpreter also in the
   frame.
1. **Boot.** Menu appears; date at top right (the clock prompt takes an empty
   line to mean "leave it"). A failure before the menu names its check.
2. **Option 1, EDIT.** Correct screen (prefix / `UNTITLED` / byte count; the
   rule; twenty blank rows; two bars). Type a line, `OA-S` as `TEST`, `OA-N`,
   `OA-O` `TEST` — the line comes back. This proves aux memory, the ring,
   `PUTROW`, and file save/load in one pass.
3. **Option 4, FORMAT.** New → place two fields → Save → Delete → Open: the
   `.DCT` round-trips. `SA-C` shows the generated COBOL on page 2.
4. **Option 6, QUERY.** Build two conditions and a sort key, save, reopen —
   the decompile is the fragile half.
5. **Option 7, REPORT.** Scroll the 66-line page, `OA-A` a literal and a rule,
   `OA-D` one away.
6. **The rest of the harnesses.** `QRYTEST` (eight printed steps — read them,
   nothing says PASS on purpose), `KEYTEST` (stage 2 is the compatibility
   promise), `LEXTEST`, then `OBJTEST` — which writes `HELLO.OBJ`.
7. **The interpreter, before the compiler.** From BASIC.SYSTEM:
   `BLOAD COBOL.LIB,A$3000` · `BLOAD HELLO.OBJ,A$9200` · `BRUN VM`. This runs a
   known-good dozen-instruction object and proves the VM against the object
   format with the compiler out of the loop.

## Phase 6 — the first compiled program

In EDIT (option 1), type `BETA1` — written to our line shape: Area A names at
column 2, statements at column 9 (two TABs):

```
 IDENTIFICATION DIVISION.
 PROGRAM-ID. BETA1.
 DATA DIVISION.
 WORKING-STORAGE SECTION.
 01 WS-COUNT PIC 9(4).
 01 WS-TOTAL PIC 9(6).
 PROCEDURE DIVISION.
 MAIN.
     MOVE 1 TO WS-COUNT
     MOVE 0 TO WS-TOTAL.
 LOOP.
     ADD WS-COUNT TO WS-TOTAL
     ADD 1 TO WS-COUNT
     IF WS-COUNT < 11
         GO TO LOOP
     END-IF
     DISPLAY WS-TOTAL
     STOP RUN.
```

`OA-S` it, ESC to the menu, **option 5 immediately** — the compiler takes the
source from auxiliary memory, where EDIT just left it. Pass one reports, pass
two reports `Compiled.  bytes:`. Then catalog `/COBOL` to find the object the
writer produced (its naming comes from the editor's program name — confirming
that is itself a test), and run it the Phase-5-step-7 way. **It should print
55.**

If all of that works, the tool chain is a system, end to end, for the first
time.

Then graduate deliberately: a program with a file (`OPEN OUTPUT` → `WRITE` →
`CLOSE` → `OPEN INPUT` → `READ` → `DISPLAY`), then one with `EVALUATE`, then
`PERFORM UNTIL`, then a `QUERY`. One new feature per program — a failure then
names its own cause.

## What you will have — and what you will not

**Have:** a bootable development system — menu, full-screen editor, screen
designer (exports `.DCT` + COBOL), query designer (`.QRY`), report designer
(layout slices), a two-pass compiler (data division, `MOVE`, `DISPLAY`,
`ACCEPT`, arithmetic, `IF`, `EVALUATE`, `PERFORM`/`UNTIL`, `GO TO`, `COMPUTE`,
the seven file verbs, `QUERY`), the p-code interpreter, and a **twenty-module**
runtime library including relative files, the query engine, the forms engine,
the class conditions, the runtime error stop, printer and clock.

**Not have:** a way to run a compiled program without BASIC.SYSTEM (the launch
stub, slice 8, is the single biggest gap); `GIVING`; `COPY` (so FORMAT/REPORT
exports cannot be included in a program yet); `PERFORM TIMES`/`VARYING`;
REPORT slices 3–7; EDIT clipboard/undo; menu options 2 and 3;
VIEW; the `HELP/` files.

**Two of those moved out of this list on 2026-08-23 and are worth naming.**
Whole-form `ACCEPT` used to be here because `SCRSHOW`/`SCRINP` sat outside the
library; they are slots 100–101 now and `SCRINP`'s two blockers — the `FTYPE`
collision and the eight-bit descriptor offset — are fixed. `CLASS.S` and
`ABORT.S` used to be here because they did not exist; they are slots 102–104,
and opcode `$62` no longer traps. **What is still missing in both cases is the
COMPILER half**: the runtime can be called and nothing emits the call. That is
a smaller gap than the one it replaced, but it is not nothing, and a program
that says `IF X IS NUMERIC` still will not compile.

**And the honest framing:** the shell, the editor and the screen designer have
been assembled and run before — Phases 1–3 are known ground with changed
sources. `REPORT`, `QUERY`, `VM` and the two compiler passes have never been
assembled at all, and that is where the unknowns are. The ladder in Phase 5 is
ordered so each rung rests on one already proven — except rung zero, which
rests on nothing and is the reason it is rung zero.
