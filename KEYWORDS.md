# Every keyword, and what it costs

The whole subset, with what each word actually demands of us. Corrected for
every decision since the subset chapter was drafted: SCREEN SECTION dropped,
`AT LINE n COLUMN n` added, BASIC dropped, COMP-3 storage replaced by NUM8.

## How to read the "Needs" column

| Mark | Meaning |
|---|---|
| **C** | **Compile-time only.** Emits no code at all. The compiler learns something and moves on. |
| **G** | **Codegen only.** Emits opcodes that already exist. No new runtime, no new opcode. |
| **V** | **Needs a VM opcode** — a handler in the interpreter. |
| **L** | **Needs a library routine** in `COBOL.LIB` at `$3000`. |

Most `V` entries are also `L`: the opcode handler is five instructions that set
up parameters and `JSR` a library vector. That is the design working — the
interpreter is thin because the library is real.

A ✔ means the library side exists. `PCODE.md` says which opcodes are built.

---

## Source text — the library facility

Not a division, and not a verb. `COPY` is a **compiler-directive statement**:
the compiler reads the named file and substitutes its text at the point of the
statement, exactly the way Merlin's `PUT` builds our own overlays out of pieces.
It has no runtime existence whatsoever.

| Keyword | Needs | Module |
|---|---|---|
| `COPY text-name` | C | compiler — the lexer (CMPLEX.S LXCOPY). **Built 2026-11-11**: see QUICKREF.md for the rules |
| `COPY ... OF / IN library-name` | C | not built: error 44. A prefix or a path does the job (`COPY "*/PROCS/DATES".`) |
| `COPY ... REPLACING` | C | compiler. **Deferred**, see below |
| `REPLACE` (the COBOL-85 standalone statement) | — | **not in the subset** |

A copybook is not confined to one division: it may hold `SELECT` clauses, an
`FD`, a record layout, or **a block of paragraphs in the `PROCEDURE
DIVISION`**. That last is the one that matters here.

### Why it is on the list at all

`FORMAT` and `REPORT` both write `.SNP` snippets, and until now the only way
into a program was to paste one in — which `STATUS.md` records as the last
missing link in the FORMAT → EDIT → COMPILE chain, because EDIT has no
insert-file-at-cursor.

**`COPY` closes that link at the compiler instead of the editor, and closes it
better.** A pasted snippet is a *snapshot*: change the screen in `FORMAT`,
re-export, and the program silently holds the old layout with nothing to detect
it. `COPY LEDGER.` is a *live reference* — re-export, recompile, and the
program has the new layout with no editing at all. For a report, whose export
is four paragraphs and a pile of `FILLER` group items, nobody is going to
re-paste it by hand twice.

### What it costs

A source stack in the lexer: push the current file's position, open the
copybook, read to end of file, pop. No p-code, no library routine, no runtime,
no codegen. Perhaps 250 bytes.

**The nesting depth is set by the hardware, not by us.** There are three
ProDOS file buffers — `IOBUF`, `IOBUF2`, `IOBUF3` — and the main source plus one
copybook is two of them. So **`COPY` nests exactly one deep**: a copybook may
not itself contain a `COPY`. That is a limit to write in the manual rather than
leave for someone to discover, and it costs nothing to enforce — the lexer
already knows how deep it is.

### Two consequences

**Error reporting.** `FILETYPES.md` promises that COMPILE puts the editor *on*
the offending line rather than printing a number to hunt. An error inside a
copybook has to open the **copybook**, so the lexer's position record needs a
filename beside the line number, not just a line number. Cheap if it is built in
from the start and awkward to retrofit.

**`REPLACING` is deferred, deliberately.** Plain `COPY` is a source stack;
`REPLACING` with pseudo-text (`==...==`) is a real string-substitution pass over
every line, and it only earns its keep when one copybook is pulled into a
program twice under different names. A generated screen or report is used once.
Reserve the word, reject it with a clear message, and add it if a program ever
wants it.

---

## IDENTIFICATION DIVISION

| Keyword | Needs | Module |
|---|---|---|
| `IDENTIFICATION DIVISION` | C | compiler |
| `PROGRAM-ID` | C | compiler — name goes in the object header |

## ENVIRONMENT DIVISION

| Keyword | Needs | Module |
|---|---|---|
| `ENVIRONMENT DIVISION` | C | compiler |
| `CONFIGURATION SECTION` | C | compiler |
| `SPECIAL-NAMES` | C | compiler |
| `CURRENCY SIGN IS` | C + L | sets `PICCUR`, one byte, in `PICTURE.S` ✔ |
| `DECIMAL-POINT IS COMMA` | C + L | swaps `PICDPT`/`PICCOM` in `PICTURE.S` ✔ |
| `CLASS ... IS` | C | compiler — builds the table `CLASS.S` tests against. That table is now a defined thing: a 32-byte membership bitmap in the literal pool, read by class code 10 |
| `CRT STATUS IS` | C | compiler — a pointer, and one store in the `ENTER` prologue to set `KEYCMD`. The runtime half exists: `KEYTERM`/`KEYCHAR` ✔ |
| `QUERY STATUS IS` | C | compiler — the same shape again, for `QSTAT`. See the query section below |
| `CONSOLE IS` | C | compiler |
| `INPUT-OUTPUT SECTION` | C | compiler |
| `FILE-CONTROL` | C | compiler |
| `SELECT ... ASSIGN TO` | C | compiler — builds a file control block in the object |
| `ORGANIZATION SEQUENTIAL / RELATIVE` | C | flag in the FCB |
| `ACCESS SEQUENTIAL / RANDOM / DYNAMIC` | C | flag in the FCB |
| `RELATIVE KEY IS` | C | pointer in the FCB |
| `FILE STATUS IS` | C | pointer in the FCB; `RECMAN.S` writes through it |

**Every word in both divisions above is compile-time.** Not one byte of runtime
comes out of them, apart from two `SPECIAL-NAMES` clauses that each set a single
byte. That is worth noticing before the table gets heavier.

## DATA DIVISION

| Keyword | Needs | Module |
|---|---|---|
| `DATA DIVISION` / `FILE SECTION` / `WORKING-STORAGE SECTION` | C | compiler |
| `FD` | C | compiler |
| Level numbers `01`–`49`, `77` | C | compiler — builds the record layout |
| `88` condition-name | C + G | compiler; the test compiles to a compare |
| `PICTURE` / `PIC` | C | compiler — the *edit* happens at MOVE time, in `PICTURE.S` |
| `USAGE DISPLAY` | C | compiler |
| `USAGE COMP` | C + L | 2-byte binary, for subscripts and keys; conversions via `BCDBIN`/`BINBCD` ✔ |
| `USAGE COMP-3` | C | **accepted, and it means NUM8.** See the note below |
| `VALUE` | C | compiler — initialises storage in the `ENTER` prologue |
| `OCCURS` | C + G | subscript = multiply and add, opcodes we have |
| `REDEFINES` | C | compiler — two names, one address |
| `SIGN ... SEPARATE` | C + L | sign handling in `PICTURE.S` ✔ |
| `JUSTIFIED RIGHT` | C + L | descriptor flag bit1; a right-justifying `MOVALP` |
| `BLANK WHEN ZERO` | C + L | descriptor flag bit2 → `PICFLG` in `PICTURE.S` ✔ |

> **`COMP-3` is a keyword we accept, not a storage format we use.** A program
> that says `PIC S9(6)V99 COMP-3` compiles, and the three sample programs are
> written that way, because that is how a COBOL programmer writes money. What
> the compiler *allocates* is a NUM8 cell — eight bytes, sign in a flag byte,
> fourteen digits — whatever the PICTURE says. `USAGE DISPLAY` on a numeric
> item gets the same cell. One size means one `ADD`, one `COMPARE`, one
> `MULTIPLY`, and no length parameter anywhere in the runtime.
>
> The visible consequence is that `COMP-3` is now a *hint about intent* rather
> than a layout request: it changes nothing about the bytes. The invisible
> consequence is that the arithmetic got simpler — with the sign out of the
> digits there is no masking anywhere. See `EQUATES.S` and `BCD.S`.

## PROCEDURE DIVISION — data movement

| Keyword | Needs | Module |
|---|---|---|
| `MOVE` numeric → numeric | V + L | `BCDMOV` ✔; the VM aligns the scales itself |
| `MOVE` numeric → edited | V + L | `PICEDIT` in `PICTURE.S` ✔ |
| `MOVE` alphanumeric | V + L | `MOVALP` ✔ |
| `MOVE` figurative (`SPACE`, `ZERO`, `ALL "x"`) | V + L | `FILLCH` ✔ |
| `INITIALIZE` | V + L | `FILLCH` + `BCDZRO` ✔ |
| `SET ... TO TRUE` | G | compiles to a `MOVE` of the 88's value |

> **Alignment moved into the VM.** The compiler used to emit `BCDSHL`/`BCDSHR`
> before every arithmetic instruction to line the decimal points up. The scale
> now lives in the data descriptor, so the interpreter can read both operands'
> scales and align them itself. `BCDSHL`/`BCDSHR` are still in the library and
> still needed — the VM is what calls them now.

## PROCEDURE DIVISION — arithmetic

| Keyword | Needs | Module |
|---|---|---|
| `ADD` | V + L | `BCDADD` ✔ |
| `SUBTRACT` | V + L | `BCDSUB` ✔ |
| `MULTIPLY` | V + L | `BCDMUL` ✔ |
| `DIVIDE` | V + L | `BCDDIV` ✔ |
| `DIVIDE ... REMAINDER` | V + L | `BCDDIV` + `BCDREM` ✔ |
| `COMPUTE` | V + L | compiler emits reverse-Polish onto the VM expression stack ✔ |
| `ROUNDED` | V + L | `BCDRND` ✔ |
| `ON SIZE ERROR` | G | tests `BCDERR`, branches ✔ |

**All of arithmetic is built** — in the library and, since the expression stack
opcodes `$50–$57` went in, in the interpreter too. `COMPUTE` still needs an
expression evaluator in the *compiler*, but no new runtime and no new opcode.

`BMUL` and `BDIV` are the least-exercised code in the tree. See `STATUS.md`.

## PROCEDURE DIVISION — logic and flow

| Keyword | Needs | Module |
|---|---|---|
| `IF` / `ELSE` / `END-IF` | G | compare + branch opcodes ✔ |
| Relations `=` `>` `<` `>=` `<=` `NOT` | G + L | `BCDCMP` / `CMPALP` ✔ |
| `AND` / `OR` / `NOT` | G | branch restructuring only |
| `IS NUMERIC` / `IS ALPHABETIC` | V + L | **`CLASS.S` built 2026-08-23**, slot 102, and `$62` no longer traps. The COMPILER half is what is missing: nothing emits the opcode |
| `EVALUATE` / `WHEN` / `END-EVALUATE` | G | lowers to compares and branches |
| `PERFORM ... TIMES` | V | **VM** — counted loop; traps today |
| `PERFORM ... UNTIL` | V | **VM** — traps today |
| `PERFORM ... VARYING` | V + L | **VM** + `BCDADD` for the increment; traps today |
| `PERFORM ... THRU` | V | **VM** — the PERFORM stack ✔ |
| `PERFORM` (inline) | V | **VM** ✔ |
| `GO TO` | V | **VM** — one jump opcode ✔ |
| `EXIT` | C | a no-op paragraph |
| `CONTINUE` | C | a no-op |
| `STOP RUN` | V + L | **VM** halt ✔, then a return to the menu |
| `GOBACK` | V | **VM** — same as `STOP RUN` in a one-program system |

## PROCEDURE DIVISION — screen

| Keyword | Needs | Module |
|---|---|---|
| `DISPLAY` literal / field | V + L | `CONPUTS` ✔ (edited fields go via `PICTURE.S`) |
| `DISPLAY ... AT LINE n COLUMN n` | V + L | `DSAT` + `DSPUTS` ✔ |
| `DISPLAY ... UPON PRINTER` | V + L | `PRINTER.S` ✔ — needs opcodes `$88`/`$89`. See `PRINTER.md` |
| `ACCEPT` field | V + L | `CONGETLN` ✔ / `DSACC` ✔; whole-form `ACCEPT` needs `SCRINP.S` moved in |
| `ACCEPT ... AT LINE n COLUMN n` | V + L | `DSACC` ✔ |
| `ACCEPT ... FROM DATE / DAY / TIME` | V + L | **`DATIME.S`** — opcode `$85` traps today |
| `ACCEPT ... FROM KEY` | V + L | one keystroke, no field, for menu loops. Needs opcode **`$87`**, free at the top of the screen block |
| `ACCEPT ... ON EXCEPTION` / `END-ACCEPT` | G | tests `KEYTERM`, branches |

**Open-Apple and Solid-Apple are `CRT STATUS`, not new syntax.** The library
half is built — `READMOD` reads the two switches inside every key wait, and
`CONGETLN` / `DSACC` / `EDITFLD` all record how the accept ended in two ASCII
characters. Dispatching on them is `EVALUATE`, which the subset already has,
so **acting on a command key costs no new keyword at all**. `KEYS.md` is the
contract.

**The screen is two halves and a program picks one.** `CONSOLE` scrolls and
wraps and has a cursor that advances; `DSCREEN` has coordinates and never
scrolls. Mixing them gives a screen that half-scrolls. The three sample
programs use plain `DISPLAY`/`ACCEPT`, so they are CONSOLE programs;
FORMAT-generated code is all `AT LINE n COLUMN n`, so it is DSCREEN.

## PROCEDURE DIVISION — files

**All three halves are built as of 2026-08-16**: `RECMAN.S` in the library, the
`$90–$96` opcodes as one handler in `VMFILE.S`, and the seven verbs plus
`FILE-CONTROL` in the compiler. A file statement now compiles and runs.

| Keyword | Needs | Module |
|---|---|---|
| `OPEN INPUT / OUTPUT / I-O / EXTEND` | V + L | `RECMAN.S` |
| `CLOSE` | V + L | `RECMAN.S` |
| `READ` | V + L | `RECMAN.S` |
| `READ ... NEXT RECORD` | V + L | `RECMAN.S` |
| `WRITE` | V + L | `RECMAN.S` |
| `REWRITE` | V + L | `RECMAN.S` |
| `DELETE` | V + L | `RECMAN.S` |
| `START ... KEY IS` | V + L | `RECMAN.S` |
| `AT END` / `INVALID KEY` | G | tests `FILE STATUS`, branches |

## PROCEDURE DIVISION — the query engine

**New 2026-08-15.** One verb, `QUERY`, in four forms. `QUERY.md` §15 is the
design and the authority; this table is what it costs.

| Keyword | Needs | Module |
|---|---|---|
| `QUERY name USING dict FOR n` | V + L | `SELECT.S` ✔ + `SORT.S` ✔ — opcode **`$D4`** ✔ |
| `QUERY name USING dict OF file` | V + L | the same, plus **`RECMAN.S`** — the file must be open; works since 2026-11-08 |
| `QUERY NEXT ... AT END` | V + L | `SLNEXT` ✔ — opcode **`$D5`** ✔ |
| `QUERY SORT` | V + L | `SRSORT` ✔ — opcode **`$D7`** ✔ |
| `QUERY FIELD n INTO identifier` | V + L | `SLFLD` ✔ — opcode **`$D8`** ✔ |
| `QUERY STATUS IS identifier` | C | compiler — a pointer, carried on `$D4` |
| `ON ERROR` (on a `QUERY` statement) | G | tests the status, branches |

**Every library routine behind this verb was already written, and as of
2026-08-15 so is every opcode**: `src/VMQRY.S`, 719 bytes, wired into the
dispatch table. What is left is only the statement parser in `CMPPROC`. That is
the whole reason the verb was worth adding — the engine had been unreachable
from COBOL since the day it was written, and it was the only major module in
the tree with no path to a program.

**`QUERY STATUS IS` is modelled on `CRT STATUS IS`, deliberately** — a pointer
resolved at compile time and one store, after which every `QUERY` statement
writes `QSTAT` through it. It differs in one detail the implementation forced:
the pointer rides as an operand of `$D4` rather than being set in the `ENTER`
prologue, because `$D4` necessarily runs before any other query statement and
that saved an opcode number. A program that declares no status item still runs;
it just cannot tell status 3 from status 8, which is what `ON ERROR` is for.

**`QUERY` adds two reserved words, not one.** `QUERY` and `FIELD`. `NEXT`,
`SORT`, `USING`, `GIVING`, `OF`, `FOR`, `INTO` and `STATUS` are all COBOL
reserved words already. `FIELD` is not a COBOL-74 reserved word, so taking it
costs a data name somebody might have wanted — the alternative was to make a
numeric literal after `QUERY` mean something different from an alphanumeric
one, and a rule that subtle is worse than a word.

## Figurative constants

| Keyword | Needs | Module |
|---|---|---|
| `ZERO` `SPACE` `HIGH-VALUE` `LOW-VALUE` `QUOTE` | C | compile to literals |
| `ALL "x"` | C + L | `FILLCH` ✔ |

## Explicitly not in the subset

`SCREEN SECTION` (FORMAT generates `DISPLAY`/`ACCEPT` instead) · `CALL` /
`CANCEL` / `LINKAGE` · `STRING` / `UNSTRING` / `INSPECT` (phase 2) · **`SORT` /
`MERGE` — the COBOL verbs, with their `SD`, `RELEASE` and `RETURN`; the
*service* of the same name is in the library and is reached by opcode, not by
statement. See the note below** · Report Writer · Communications · `ALTER` · `GO TO ... DEPENDING` ·
`EXAMINE` / `TRANSFORM` / `ENTER` · `66 RENAMES` · `OCCURS DEPENDING ON` ·
`SYNCHRONIZED` · `COMP-1` / `COMP-2` (no floating point — and with BASIC
dropped, none is coming) · `INDEX` / `POINTER` · `ORGANIZATION INDEXED` ·
`I-O-CONTROL` · segmentation · DEBUG declaratives · `REPLACE` and
`COPY ... REPLACING` (the library facility itself **is** in — see the top of
this file; only the text-substitution half is deferred).

### The two words that now mean two things

`SELECT.S` and `SORT.S` are in the library, and **neither adds a keyword**.
That has not changed, and it is easy to misread now that `QUERY` is a verb.

`SORT` the COBOL verb wants a sort file (`SD`), a `RELEASE`/`RETURN` protocol
and an input and output procedure — a fair amount of grammar for something a
program can do with three `JSR`s. `SELECT` the COBOL clause names a file and is
compile-time only; it has nothing to do with selecting records.

The engines behind them are runtime **services**, reached through the `$D0–$DF`
opcode block that `PCODE.md` §3 reserves, and they are neutral in the
front-end sense: a second language would call the same ones. So the row above
stays exactly as it was — the verbs are out.

**What changed on 2026-08-15 is the door, not the room.** `QUERY` is a verb;
`SELECT` and `SORT` are still not. `QUERY SORT` is the sort, spelled as a
*form of the query verb* rather than as the COBOL `SORT` — which keeps the
excluded verb excluded and means a program can never write a bare `SORT`
statement and get something that is not COBOL's `SORT`. That was the deciding
argument for hanging all four forms off one new word instead of two.

Both things they were owed are paid: `PRINTER.S` is written, so a selected and
sorted set can go somewhere, and `QUERY ... OF file-name` reads the program's
open relative file through `RECMAN.S` (2026-11-08) — which needed the dictionary
to describe NUM fields as the NUM8 cells a program actually writes
(`DICTIONARY.md` §3).

---

# The roll-up

## Library — `$30C0–$7FFF`, 20800 bytes

| Module | Est. | Status |
|---|---|---|
| `TEXTDRV.S` | ~700 | ✔ built |
| `FILEIO.S` | ~450 | ✔ built |
| `CATALOG.S` | ~700 + 512 buf | ✔ built |
| `BCD.S` | ~1500 + 144 data | ✔ built |
| `BANKS.S` | ~350 | ✔ built |
| `CONSOLE.S` | ~500 + 1920 buf | ✔ built |
| `DSCREEN.S` | ~350 | ✔ built |
| `AUXMEM.S` | ~400 | ✔ built |
| `NUMFMT.S` | ~200 | ✔ built |
| `PICTURE.S` | ~1160 | ✔ built |
| `SELECT.S` | ~2400 | ✔ written, never assembled |
| `SORT.S` | ~320 | ✔ written, never assembled |
| `RECMAN.S` | 1229 | ✔ built 2026-08-16, slots 92-99 |
| `SCRINP.S` | ~600 | ✔ **in the library 2026-08-23**, slot 101, vector `FRMACC` |
| `SCRSHOW.S` | ~250 | ✔ **in the library 2026-08-23**, slot 100, vector `FRMSHOW` |
| `CLASS.S` | 382 | **built 2026-08-23** — eleven class codes, slot 102 |
| `DATIME.S` | ~100 | ✔ written, slots 84-87 and 91 |
| `ABORT.S` | 329 | **built 2026-08-23** — setjmp/longjmp, slots 103-104 |
| `PRINTER.S` | ~330 | ✔ written, never assembled |
| **Total** | **14594** | **of 20480, checked. 5886 spare** |

## The interpreter — `$8000–$91FF`, 4608 bytes

| Piece | Actual |
|---|---|
| `VM.S` as written, including a page of dispatch table | 4204 |

Which leaves `$9200–$AFFF`, 7.5K, for the object file and its data segment
together.  The interpreter grew past `$8FFF` when the dispatch table became a
full page; `PCODE.md` §1 has the current map, and 404 bytes are left under the
ceiling.

## The compiler — an `$8000–$AFFF` overlay, 12288 bytes

| Piece | Est. |
|---|---|
| Lexer over fixed-form source | ~600 |
| `COPY` — the lexer's source stack | ~250 (built: about 790 — the open, the staging into aux, the .SNP pieces, the `*/PROCS/` fallback, five errors) |
| Keyword tables | ~800 |
| Symbol table (in aux) | ~800 |
| DATA DIVISION parser, incl. PICTURE parsing | ~1200 |
| PROCEDURE DIVISION parser + codegen | ~2000 |
| Expression evaluator for `COMPUTE` | ~600 |
| The `QUERY` statement — four forms, one keyword | **1,401 (written)** |
| Object writer + fixups | ~400 |
| **Total** | **~6850 of 12288** |

`QUERY` was going to be the cheapest verb in the subset per unit of capability,
because all four forms are **fixed-shape statements with no expression anywhere
in them**: a literal, a literal, a number, an item, a branch target. Nothing to
parse recursively.

**It came to 1,401 bytes, and the estimate of 200 was not close.** Fixed shapes
are cheap to *parse* and the parsing is a small part of a statement: what costs
is one keyword table, a decimal-to-binary conversion the compiler had no other
use for, seven operands emitted in an order that is not the order they were
read, and the branch-and-clause machinery that `ON ERROR` and `AT END` share.
**That overran `COMPILE`'s ceiling by 210 bytes** — see `STATUS.md`, which has
the three ways out and recommends splitting the compiler into two overlays.

The *interpreter* side turned out to be **719 bytes, not the 250 estimated** —
`VMQRY.S`, written 2026-08-15. The engine calls are nine bytes of it; the rest
is operand plumbing and the four helpers that read a count out of a COBOL item
and write one back, in both the `COMP` and the NUM8 flavour. `QUERY.md` §15.6
has the account. It leaves `VM` with 241 bytes below `$9000`.

---

# What this tells us

**1. Most of COBOL is free.** Two entire divisions and nearly all of the DATA
DIVISION are compile-time only. The runtime cost is concentrated in about
fifteen verbs.

**2. Everything fits, and the old crisis is over.** The earlier version of this
document ended with the library 2700 bytes over a 4608-byte budget and called
for a structural answer — moving buffers out, claiming `$0800–$0BFF`, splitting
into `COBOL.LIB` + `COBOL.LI2`. All three are now unnecessary. Separating code
from data and moving the code to `$3000` gave the library 20K and the buffers
cost nothing at all, because they became addresses in a region that is never
loaded.

**3. What is actually left is a short list.** `RECMAN`, the two forms modules
moved in, four small services, and the compiler. Nothing on it is architectural.

## Suggested order of work

1. **Prove `BCD` on the machine**, on its own. `BMUL` and `BDIV` are the
   least-exercised code in the tree, and a product index is the sort of thing
   that is either exactly right or off by one with nothing between.
2. **Prove `PICTURE`**, from a small test harness rather than the VM.
3. **Then the VM**, with a hand-assembled object of a dozen instructions.
   Hand-assembling it is not a chore to avoid: it is the only way to test the
   interpreter before there is a compiler, and it proves the object format at
   the same time.
4. `RECMAN.S` — after which the three sample programs have everything they need
   except a compiler.
5. Move `SCRSHOW`/`SCRINP` in; write the four small services.
6. The compiler — the largest single piece, and the last one that can be
   written, because it emits calls to all of the above.
