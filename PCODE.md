# The p-code machine — the specification as built

The authority on what `src/VM.S` does. The opcode **numbers** live in
*Chapter — The P-Code Instruction Set*, are unchanged, and remain
authoritative; this file is where the registers, the descriptor, the object
format and the implementation status are recorded.

The corrections in §6 have been applied to that chapter — see
`chapters/REVISIONS.md`.

---

## 1. The three corrections that shaped it

**1. The registers moved to Zone P.** An earlier draft put `IP` at `$18–$19`
and `CCND` at `$20`. `$18–$1F` is Zone S — caller-saved scratch that every
library routine is free to destroy — and `$20` upward belongs to the monitor.
Both would have been overwritten by the first `PUTS` an opcode called.

They live at `$60–$7F`, Zone P, which the Golden Rule keeps every service out
of. That rule was written for exactly this: `IP`, `DP` and the stack pointers
stay live across the dozen library calls a single instruction makes.

```
$60 IP    instruction pointer      $6C O1    source item address
$62 DP    data segment base        $6E O2    destination item address
$64 LP    literal pool base        $70 PT    working pointer
$66 DT    descriptor table base    $72 JP    dispatch vector
$68 RSP   PERFORM stack pointer    $73 ESP   expression stack pointer
$74 CC    last compare result      $75 EXC   exception flags
$76 HLT   halt flag
```

**2. NUM8 replaced COMP-3, so the types collapsed.** Eight descriptor types
became six: `num-display`, `packed` and `signed` are now one thing — an 8-byte
cell:

| Code | Type | Storage |
|---|---|---|
| 0 | alphanumeric | `length` bytes, space filled |
| 1 | numeric | one NUM8 cell, always 8 bytes |
| 2 | binary (`COMP`) | 2 bytes, for subscripts and keys |
| 3 | boolean | 1 byte, `$01` / `$00` |
| 4 | group | raw bytes, no interpretation |
| 5 | edited | alphanumeric, with `editref` pointing at its PICTURE |

**Scale did not disappear — it moved into the descriptor**, where the
interpreter can read it. That is why **alignment happens in the VM, not the
compiler**: `VALIGN` can see both operands' scales, so the compiler no longer
emits `BCDSHL`/`BCDSHR` before each arithmetic instruction. One fewer
instruction emitted per statement, and one fewer thing for a code generator to
get wrong.

**3. The interpreter is an overlay.** Not a `$6000` resident. The overlay band
is the only 12K free in both worlds, so:

```
$8000-$91FF   VM.S, the interpreter (4,129 bytes; a page is the table)
$9200-$AFFF   the object, then the data segment (7.5K for both)
```

A program run from the menu returns to the menu with an `RTS`. The identical
object run from a launch stub returns to ProDOS. Nothing in an object file
holds an address, so the same bytes run either way — and if 8K ever binds, the
interpreter moves to `$2000` in the standalone world and the band is all the
program's.

---

## 2. The object file

```
0   4  "PCB1"        11  2  litoff     offset to the literal pool
4   1  version = 1   13  2  codeoff    offset to the p-code
5   2  dataseg       15  2  entry      first instruction, from codeoff
7   2  itemcount     17  2  codelen    length of the p-code
9   2  descoff       19  1  language   0 = COBOL
```

**There is no data-segment offset field**: the data segment starts at
`codeoff + codelen`. Two numbers we already have say where it begins, and a
third could disagree with them.

`VMRUN` checks the signature, the version **and** the language byte before it
executes a single instruction. An object built for a front end this interpreter
does not implement stops with a message rather than being run as if it were
ours.

**Descriptor, 8 bytes:** `type`, `length`, `decimals`, `flags` (bit0 signed,
bit1 justified, bit2 blank-when-zero), `offset` into the data segment,
`editref` into the literal pool (0 = none).

**The literal pool** holds two kinds of thing, and the destination's type says
which is being read: text literals are length-prefixed, and a numeric literal
is a NUM8 cell **followed by one byte giving its scale**. That trailing byte is
what lets `PUSHL` put a literal on the expression stack with its scale intact.

---

## 3. What is implemented

| Range | Group | State |
|---|---|---|
| `$00–$03` | NOP, HALT, LINE, ENTER | **built** |
| `$10–$16` | the moves, including the edited move | **built**; `SETX` (`$17`) traps |
| `$30–$37` | ADD/SUB/MUL/DIV | **two-operand only.** `ADDP`, `SUBP`, `MULP`, `DIVP` built; the three-operand GIVING forms `ADDG`/`SUBG`/`MULG`/`DIVG` (`$31`/`$33`/`$35`/`$37`) all **trap** — there is no handler for any of them |
| `$50–$57` | the expression stack | **built** |
| `$60–$6B` | compare and branch | **all built.** `CLASS` (`$62`) landed 2026-08-23 - `VCLASS` in `VMFLOW.S` over the library's `CLASS` vector. Six bytes: opcode, item, class code, literal reference to a membership map. Nothing EMITS it yet |
| `$70–$75` | PERFORM, RET, GOTO | `PERF`, `RET`, `GOTO` built; the TIMES / UNTIL / VARYING forms trap |
| `$80–$8F` | DISPLAY, ACCEPT, ERASE, SET PRINTER/PREFIX, MENU, CASE | built except `ACCS` and `ACCDT`. `$88 DISPP` / `$89 DISPPL` send the LAST operand of a `DISPLAY ... UPON PRINTER` and end the line. Both are now blocked on a HANDLER rather than on a library: the forms engine is slots 100-101 and `DATIME` is slots 84-87 |
| `$90–$96` | files | **built 2026-08-16** — one handler, `VMFILE`, over `RECMAN`. ctl byte: bits 0-1 the file, 4-7 the OPEN mode or READ NEXT, and **bit 2 (2026-11-22): OPEN's op1 is the item holding the name** (`ASSIGN TO` a data name) rather than a literal-pool offset |
| `$97`, `$98` | `DISPPN`, `DISPPLN` | **built 2026-11-22** — an item or a literal to the printer WITHOUT ending the line: every operand of `DISPLAY a b c UPON PRINTER` but the last. Three bytes, the same as `DISPN`/`DISPLN`, which the compiler emits first and patches once it meets `UPON PRINTER` (FIXLIST A22) |
| `$99` | `FNAME` | **built 2026-11-22** (DECISIONS 8.11) — one byte, no operand: the `ACCEPT` or `ACCA` after it reads a FILE NAME. The compiler emits it when a `SELECT` names the item in `ASSIGN TO`. The line is cut to 64 characters, and a plain `ACCEPT` beeps on each of the last seven (CONGETLN's `CGWARN`, `$0E7D`). Both ACCEPT handlers take the mark and clear it, so it never lasts past one |
| `$A0–$B2` | tables and strings | **all trap** |
| `$C0–$CA` | BASIC | **all trap**, and always will in this build |
| `$D0–$D6` | the runtime services | **all trap.** The forms engine exists now - `FRMSHOW` and `FRMACC`, slots 100-101 - so what is missing is the handlers and the code generation, not the runtime |
| `$D7`, `$D8` | the query verb's other two | **trap** — new 2026-08-15, see below |

**The query block is now spoken for, and four of its five have a COBOL
statement behind them.** `QUERY.md` §15 added the `QUERY` verb to the subset, so
`$D4` `QOPEN`, `$D5` `QNEXT`, `$D7` `QSORT` and `$D8` `QFLD` are no longer
opcodes with no way to emit them. Every library routine underneath them is
written. The handlers are five instructions each plus one shared
status-and-branch helper, and `QUERY.md` §15.5 gives the exact `VMTAIL.S`
dispatch-table edit — the last line of the table currently absorbs everything
from `$A0` upward and has to be split into three.

`$D3` `QBE` stays trapping deliberately: the thing that writes a `.QRY` is the
`QUERY` overlay an operator runs from the menu, not something a program builds.

**A trap is not a crash.** `VBAD` names the instruction and the source line
(`LINE` opcodes are what make that possible) and returns to the menu. Every
byte that is not an opcode points at it, so a jump that has gone wrong faults
on the first bad byte instead of walking through data executing it.

---

## 4. Two things worth knowing before writing the compiler

**Branch targets are offsets from the code base, never relative.** A forward
branch is fixed up long before the compiler knows how far away it landed, and
an absolute offset is the only thing it can write down at that point.

**The PERFORM stack is the interpreter's, not the processor's.** A COBOL
program can `PERFORM THRU` a range that performs another; the depth has nothing
to do with how deep the 6502 is. Handlers return to the fetch loop with `JMP`,
never `RTS`, so nothing accumulates on the hardware stack — which is also why
`VMDIE` **resets** the stack pointer from the value saved at entry rather than
trying to unwind it. A fault can be raised inside a helper that was reached by
`JSR`, and the return addresses above it lead back into an instruction being
abandoned.

---

## 5. Untested, and the order to test in

None of this has been on the machine. **The first two harnesses now exist** —
`BCDTEST.S` and `PICTEST.S`, written 2026-08-23 to the pattern `QRYTEST.S`
set. Neither has been assembled either, but the reason for the order below has
not changed and each one is now a `BRUN` rather than a project.

1. **BCD first, and on its own.** `BMUL` and `BDIV` are the least-exercised
   code in the tree and the product index is the sort of thing that is either
   exactly right or off by one with nothing in between. A test that multiplies
   known values is worth more than any amount of reading.
   **`BCDTEST`** does it: 17 arithmetic cases — carries that run the length of
   the cell, both opposite-sign adds, a product that will not fit and must
   raise OVERFLOW, an exact divide, one with a remainder, one by zero — then 6
   compares across every combination of signs, then 6 shift and ROUNDED cases
   including the negative half-up that has to round *away from zero*.
2. **PICTURE next**, driven from a small test harness rather than the VM:
   `$$,$$9.99CR` against a positive value, a negative one, and zero;
   `ZZZ,ZZ9.99` with a value that suppresses into the commas; `9(5)` with a
   value too wide for it. The back-fill is the part most likely to be off by
   one place.
   **`PICTEST`** does exactly those, plus `*` protection, BLANK WHEN ZERO, DB,
   the fixed/floating/trailing forms of `+` and `-`, and 8 de-edit cases —
   which are the only test that says the two halves of the engine agree with
   each other. It brackets every result, because trailing spaces are half of
   what a PICTURE does and an unbracketed line cannot show them.
3. **Then the VM**, with a hand-assembled object of a dozen instructions —
   `ENTER`, a couple of `MOVL`s, an `ADDP`, a `DISP`, `HALT`. Hand-assembling
   it is not a chore to avoid: it is the only way to test the interpreter
   before there is a compiler, and it proves the object format at the same
   time.

Neither harness reports PASS. Every case prints what it got beside what it
should have got and the operator reads the screen, for the reason `QRYTEST`
gives: a test that reports PASS is a test that can lie.

## 6. The chapter edits this forced — applied 2026-08-14

All six are done. Recorded here so the reasoning survives, and detailed in
`chapters/REVISIONS.md`.

- **§2 VM registers** — the whole table was wrong; replaced with §1 above, with
  the explanation of why Zone P exists.
- **§1.1 Data descriptor** — eight types became six; added the sentence about
  scale moving into the descriptor and alignment moving into the VM.
- **§1 object file** — no data-segment offset; the `codeoff + codelen` rule
  stated.
- **§3.2 arithmetic** — the operands are NUM8 cells, not COMP-3 fields, and the
  interpreter aligns them.
- **§3.9 BASIC extensions** — the range stays reserved, but the section says
  plainly that this build traps it; it is an argument now, not a plan.
- **Everywhere** — "the interpreter at `$6000`" became the overlay band.
