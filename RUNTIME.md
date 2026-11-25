# The COBOL runtime library — what's built, what's left

`COBOL.LIB`, loaded to **`$3000`** by every program that runs. Source is
`src/LIB.S`, which owns the jump table and `PUT`s every module. This file
tracks what the library must contain before a compiled COBOL program can run,
and what each piece costs.

The jump table is the system's ABI. Slots are **appended, never reordered,
never reused** — a compiled object calls the runtime by absolute address and
outlives any particular assembly of the library. Only the *base* is frozen;
the table grows off the end, where an already-compiled object cannot notice.

---

## 1. Built

| Module | Slots | Provides |
|---|---|---|
| `TEXTDRV.S` | 0–15 | Both text pages, output, line input, page swap |
| `FILEIO.S` | 16–18 | Suffix→type names, whole-file load and save |
| `CATALOG.S` | 19 | Directory listing, filtered by type |
| `BCD.S` | 20–39 | NUM8 decimal arithmetic, conversions, alphanumeric MOVE/compare |
| `BANKS.S` | 40–41 | Bank detection, the page mover |
| `CONSOLE.S` | 42–48 | Scrolling `DISPLAY`/`ACCEPT` with the shadow screen |
| `DSCREEN.S` | 50–53 | Positioned `DISPLAY`/`ACCEPT ... AT LINE n COLUMN n` |
| `AUXMEM.S` | 54–57, 60 | Records across auxiliary banks |
| `NUMFMT.S` | 58–59 | Readable numbers — `5,242,880`, right-justified |
| `TEXTDRV.S` | 64 | `PUTROW`, the whole-row blit (appended after the first 64) |
| `PICTURE.S` | 65–67 | The edit engine, both directions |
| `SELECT.S` | 68–70, 72–75 | The cursor, the predicate evaluator, the scan, field fetch |
| `SORT.S` | 71 | Shell sort over a cursor |
| `PRINTER.S` | 79–82 | Output to a printer card, without touching the screen |
| `TEXTDRV.S` | 76–78 | The Apple command keys — read the modifier, test for a chord, record a terminator |
| `RECMAN.S` | 92–99 | Relative files: the eight COBOL file verbs |

Slots 61–63 are reserved and currently `RTS`, so a call into an unbuilt
service returns rather than running off into whatever happens to be there.

**Slot 49 is retired.** It was `CONSCRD`, scroll down — removed because a
console with no scrollback has nothing to scroll back to, and nothing ever
called it. Its three bytes stay in the table as an `RTS`. A retired slot is
never reused: that is what stops an object compiled against an older library
from landing in whatever moved up into the gap.

**CATALOG stays in the library.** The menu uses it, but so does any COBOL
program that wants to let the operator pick a file to open or save — that is a
runtime service, not a tool feature.

**SELECT and SORT are services, not language.** `SORT` / `MERGE` are still out
of the COBOL subset and `SELECT` still means the FILE-CONTROL clause when a
compiled program says it. These two are the engines behind the `$D4`, `$D5`,
`$D7` and `$D8` service opcodes, called by `JSR` from an overlay and by opcode
from a program, exactly the way `CATALOG` is. The design is `QUERY.md`; the one
sentence of it that matters here is that a query result is a **list of record
numbers**, so neither routine ever moves a record.

**The door is the `QUERY` verb, added to the subset 2026-08-15** (`QUERY.md`
§15). That does not make these modules language — the verb hangs all four of
its forms off one new word precisely so that `SELECT` and `SORT` can stay out —
but it does mean these eight vectors finally have a caller that is not an
assembly harness. Until the verb existed, `SELECT.S` was 2,400 bytes, the second
largest module in the library, and unreachable from any COBOL program.

**None of it has been on the machine yet** as a library. Individual modules
were proven under the old architecture; `LIB.S` checks clean at
`A$3000 L$3902` - 14,594 bytes as of 2026-08-23, against the 5,231 that was
last actually assembled. See `STATUS.md` for what is verified and what is merely
assembling.

---

## 2. Still to build

**The list this section existed for is empty as of 2026-08-23.** All four
modules below were written or moved in; what is recorded here now is where each
went and what is still owed.

| Module | Where it is | What is still owed |
|---|---|---|
| `SCRSHOW.S` | **library, slot 100, vector `FRMSHOW`** | the compiler half — nothing emits a call to it |
| `SCRINP.S` | **library, slot 101, vector `FRMACC`** | the same, plus its `V` in `STATUS.md` no longer stands: it was earned before `GETFLD` was widened |
| `CLASS.S` | **library, slot 102, vector `CLASS`**, 382 bytes | the compiler half. Opcode `$62` is handled by `VCLASS` in `VMFLOW.S` and no longer traps |
| `ABORT.S` | **library, slots 103-104, vectors `ABSET` and `ABORT`** | a caller. The natural one is a compiled program's `ENTER` prologue |

**`SCRSHOW` and `SCRINP` were the blocking pair** and are not any more. The
argument for moving them is worth keeping, because it is the argument for the
jump table itself: a `PUT`-included module's entry point moves with every
program that includes it, and compiled p-code can only call an address that
does not move. Two things followed from actually doing it:

- **`SCRINP` would not have assembled anywhere.** It declared `FTYPE DFB 0`,
  and `EQUATES.S` has `FTYPE EQU $0CCB` — the file-type parameter — which every
  program `PUT`s first. Nothing `PUT` `SCRINP`, so nobody had ever met the
  collision. The local is `SIFTYP` now.
- **`GETFLD` computed the descriptor offset in eight bits.** A descriptor is
  24 bytes, so field 11 sits at offset 264, and `264 AND $FF` is 8 — a
  perfectly plausible offset pointing at the wrong field. Any form with more
  than ten fields was reading the wrong descriptor for every field past the
  tenth, silently. `SCRSHOW` never had the bug because it walks the array with
  a running pointer and adds 24 each time round, which carries by itself.

**`FRMACC` returns its terminator in A**, not in a shared variable. A compiled
program is a separate assembly and cannot name `TERM`, which is a label inside
the library; the same reasoning that put these two behind vectors says the
answer has to come back in a register or a documented address, and a register
is cheaper.

**`ABORT` is setjmp and longjmp.** A fault is raised deep inside something —
by the time `DIVIDE` finds a zero divisor there are return addresses on the
6502 stack leading back into an arithmetic statement being abandoned — so
there is no walking back out one `RTS` at a time. `ABSET` writes the stack
pointer down before the program starts and returns `C=0`; `ABORT` prints the
fault, waits, restores the pointer and returns to that same instruction with
`C=1`. `VMDIE` does this by hand for the interpreter; this is the version
anything can use.

**`RECMAN.S` was built on 2026-08-16** — 1,229 bytes, slots 92-99, and the
estimate had said 600. What the estimate missed was the arithmetic: a 16-by-16
multiply into 24 bits, because a ProDOS mark is three bytes and a thousand
records of eighty is past what two hold. **The library half is done and the
language half is not**: opcodes `$90-$96` are still `VBAD`, so every COBOL file
statement still traps. Seven handlers, and each is the same shape as the query
ones — fill the parameter block at `$0E70`, `JSR` one vector, copy `RMSTAT`
into the program's `FILE STATUS` item.

**What blocks the forms engine now is the compiler, not the library.** That is
a different and smaller problem: the runtime is callable, at addresses that do
not move, and what is missing is code that emits the call.

### Not library modules

These belong to the VM or the compiler, not here:

- **The PERFORM stack.** `PERFORM ... THRU`, `TIMES`, `UNTIL`, `VARYING` need a
  return stack independent of the 6502's. That is interpreter state, in Zone P.
- **Subscript arithmetic for `OCCURS`.** The compiler emits `BCDBIN` plus a
  multiply; no new runtime.
- **`REDEFINES`, `VALUE`, level structure.** All resolved at compile time.
- **Decimal alignment.** This moved. The compiler used to emit `BCDSHL`/`BCDSHR`
  to line scales up before each arithmetic instruction; now the scale lives in
  the data descriptor, the interpreter can see both operands' scales, and
  `VALIGN` does it. One fewer instruction emitted per statement, and one fewer
  thing for a code generator to get wrong. The BCD pack still does arithmetic
  and not alignment — it is the VM that aligns, not the library.

---

## 3. Memory: the two worlds

The data region and the library are identical in both, and never move. Only
`$2000` and `$8000` upward differ.

```
AT THE MENU                       RUNNING A COMPILED PROGRAM
$0C00-$1FFF  data region          $0C00-$1FFF  data region
$2000-$2FFF  COBOL.SYSTEM         $2000-$2FFF  the launch stub
$3000-$7FFF  COBOL.LIB            $3000-$7FFF  COBOL.LIB
$8000-$AFFF  FORMAT/EDIT/COMPILE  $8000-$8FFF  the interpreter
                                  $9000-$AFFF  object + data segment
```

**Code and data are separated.** `$0C00–$1FFF` holds every variable and buffer
the library owns and is *never loaded* — it is addresses, not a file.
`COBOL.LIB` is pure code with its jump table at the front, which is what lets
it be one contiguous file with a single load address.

A standalone compiled program is **one SYS file** — a small stub followed by
its p-code — plus two shared files: `COBOL.LIB` and the interpreter. The stub
loads the library to `$3000`, the interpreter to `$8000`, and JSRs in with the
object still sitting where ProDOS put it. Nothing relocates, nothing is
overwritten, because the interpreter deliberately does not live at `$2000`.

Full detail in `MEMMAP.txt`.

---

## 4. The budget — resolved

The first assembly measured **5045 bytes for five modules** in the old
4608-byte region at `$0C00`: 437 over, with seven modules still to write. That
number is what forced the current layout.

Moving the code to `$3000` and leaving the data at `$0C00–$1FFF` settles it:

```
built     TEXTDRV ~700  FILEIO ~450  CATALOG ~700  BCD ~1500
          BANKS ~350  CONSOLE ~500  DSCREEN ~350  AUXMEM ~400
          NUMFMT ~200  PICTURE ~1160                       = ~6310
          SELECT ~2400  SORT ~320                          = ~2720
          RECMAN 1229  DATIME  PRINTER  CLOCK             = ~2570
built     SCRSHOW  SCRINP  CLASS 382  ABORT 329           = ~1717
2026-08-23                                                  ------
     LIBEND now reads 14594 of 20480, 5886 spare
```

`SELECT` is the largest module in the library after `BCD`, and larger than it
looks like it should be. Roughly half of it is the predicate evaluator, which
is a small interpreter in its own right — dispatch, a stack, three comparison
forms and the normalising that makes a typed literal comparable with a stored
field. The other half is arithmetic on 16-bit indices, because a cursor can
hold more entries than a byte can count.

Comfortable with every planned module in. **The two-file split is dropped** —
`COBOL.LI2` is no longer needed, and neither is leaving CATALOG out.

The buffers stopped counting entirely. `CATBLK`'s 512 bytes, BCD's 144 bytes of
digit arrays, `CSHADOW`'s 1920, `PICTURE`'s buffers — all addresses in the data
region now, costing nothing on disk and nothing in the code budget.

`LIBEND` at the foot of `LIB.S` is the real number, and the only one that
matters. Read it after every assembly.
