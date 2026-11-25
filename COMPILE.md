# The compiler — how COBOL becomes p-code

The authority on the `COMPILE` overlay: its passes, its memory, and — the part
that matters most — **the exact bytes each COBOL construct turns into**.

`PCODE.md` owns the VM: registers, object format, which opcodes are built.
This file owns the other side of the same contract. Where they touch,
`PCODE.md` wins on what the interpreter does and this file wins on what the
compiler emits.

§3 is transcribed from `VMLOOP.S`, `VMMOVE.S`, `VMFLOW.S`, `VMMATH.S` and
`VMSCRN.S` — the code that actually executes these bytes — and not from the
instruction-set chapter, which predates some of it.

---

## 1. Three facts that shape everything

**A compiled object can never exceed 8K.** `PCODE.md` gives the object *and*
its data segment `$9000–$AFFF` together. That is not a limitation the compiler
adds; it is the ceiling the compiler is building against, and it is why the
build areas below can live in main memory without anybody feeling it.

**Every operand is a two-byte item number**, an index into the descriptor
table. Not an address — `VDESC` shifts the item number three times and adds the
descriptor base, and `VADDR` adds the data-segment base. The compiler therefore
never computes an address for anything. It allocates *offsets* and hands out
*indices*.

**Branch targets are offsets from the code base, never relative.** A forward
branch has to be written down before the compiler knows how far away it landed,
and an absolute offset is the only thing it can write at that point. That makes
a fixup chain unavoidable — §4.

## 2. The passes

**One and a half.** The DATA DIVISION is read in full first, because nothing in
the PROCEDURE DIVISION can be compiled without knowing what the names mean. The
PROCEDURE DIVISION is then read once, emitting as it goes, with forward
references to paragraphs threaded onto fixup chains.

| Pass | Reads | Produces |
|---|---|---|
| 1 | IDENTIFICATION, ENVIRONMENT, DATA | the symbol table, the descriptor table, the data segment's size |
| 2 | PROCEDURE | p-code, the literal pool, and the fixups resolved as it goes |

**Why not two passes over the PROCEDURE DIVISION.** It would cost a second walk
of the source — which is cheap, the source is in memory — but it would also
mean two parsers that must agree, or one parser with a mode flag threaded
through every statement. The fixup chain is about forty instructions and it is
the same technique every one-pass assembler on this machine already uses.
Merlin does it; so do we.

**Errors stop the compile at the first one.** `FILETYPES.md` promises COMPILE
puts the editor *on* the offending line rather than printing a number to hunt.
That means the lexer carries a line number and a filename — a filename because
an error inside a `COPY` book has to open the copybook — and the overlay
returns them to the menu, which passes them to EDIT. Cheap built in from the
start, awkward to retrofit.

## 3. What each construct becomes

Operands are listed **in the order the bytes appear**, which for the moves is
*not* the order COBOL writes them.

> **The destination is emitted first.** `VMOVN` calls `VOPD` before `VOPS`, so
> `MOVE X TO Y` compiles to `$11` then *Y* then *X*. Every two-operand
> instruction in the machine is destination-first. It is the single easiest
> thing to get backwards, and getting it backwards produces a program that runs
> and quietly moves the wrong way.

### Control

| Op | Mnem | Operand bytes | Emitted for |
|---|---|---|---|
| `$00` | NOP | — | nothing; padding |
| `$01` | HALT | — | `STOP RUN`, `GOBACK` |
| `$02` | LINE | word — source line | the head of each statement |
| `$03` | ENTER | word — bytes of working storage | the program prologue |

`ENTER` clears the data segment. **`VALUE` clauses are instructions that
follow it, not an image in the file** — which is why an object file contains no
data segment at all.

`LINE` costs three bytes and a store, and it is the difference between
`SIZE ERROR` and `SIZE ERROR AT LINE 47`. Emit one per statement.

### Moves

| Op | Mnem | Operand bytes | Emitted for |
|---|---|---|---|
| `$10` | MOVA | dest word, src word | `MOVE` alphanumeric → alphanumeric |
| `$11` | MOVN | dest word, src word | `MOVE` numeric → numeric. **The VM aligns the scales** |
| `$12` | MOVE | dest word, src word | `MOVE` numeric → edited, text or group (edited by the default picture) |
| `$13` | MOVG | dest word, src word | a group move — the same as MOVA, space filled (2026-11-08) |
| `$14` | MOVL | dest word, literal-offset word | `MOVE "TEXT" TO X`, `MOVE 100 TO X` |
| `$15` | MOVF | dest word, figurative byte | `MOVE SPACE`, `MOVE ZERO` … |
| `$16` | INIT | dest word | `INITIALIZE` |
| `$17` | MOVD | dest word, src word | a text or group item into a number, de-edited (2026-11-08) |
| `$18` | SUBS | slot byte, item word, subscript word, count byte, stride byte | a table element: fills subscript slot 0-3 (2026-11-08) |

**Tables (`OCCURS`), since 2026-11-08.** A table item's descriptor describes ONE
occurrence; pass one allocates the rest and writes a table list at `$1F60` (first
item, last item, count, stride — a group's entry covers every item under it). In
pass two `PDOSUB` looks every data name up in it: a table item must be followed by
`( n )` or `( name )`, and `SUBS` goes out in front of the statement. Bit 7 of the
slot byte says the subscript word is a number rather than an item. At run time
`SUBS` copies the table item's descriptor into slot 0-3, checks 1 ≤ subscript ≤
count, and adds (subscript − 1) × stride to the offset. The operand the statement
gets is the slot, `$FFF0`–`$FFF3`; `VDESC` reads a slot's descriptor instead of the
table's, and the compiler's `EMDGET` describes the table item, so no other
instruction or emitter changed. Four slots per statement, each used once.

Figurative byte: `0` SPACE, `1` ZERO, `2` HIGH-VALUE, `3` LOW-VALUE, `4` QUOTE.

Which move to emit is decided from the two descriptors' types, and it is the
compiler's decision alone — the VM does what it is told:

```
dest edited                  -> MOVE
dest numeric, src numeric    -> MOVN
dest group  or src group     -> MOVG
otherwise                    -> MOVA
source is a literal          -> MOVL, whatever the types
```

### Arithmetic

| Op | Mnem | Operand bytes |
|---|---|---|
| `$30` | ADDP | dest word, src word, mode byte |
| `$32` | SUBP | dest word, src word, mode byte |
| `$34` | MULP | dest word, src word, mode byte |
| `$36` | DIVP | dest word, src word, mode byte |

`dest = dest op src`, so `ADD B TO A` is `ADDP A, B`. **Only the plain form is
emitted this way** — two items, no `GIVING`, no `ROUNDED`. The mode byte is
always 0: `ADDP` cuts its source to the destination's scale *before* it adds, so
there is nothing left to round. **The `GIVING` forms — `$31`, `$33`, `$35`, `$37`
— have no handler and trap.**

Everything else — a literal first operand, `GIVING`, `ROUNDED` — goes through the
expression stack (since 2026-11-08, FIXLIST A15): `ADD A TO B GIVING C ROUNDED` is
`PUSHD B`, `PUSHD A`, `EADD`, `POPDR C`. The stack keeps every digit at its own
scale until the store. The old lowering, `MOVN C, B` then `ADDP C, A`, cut `B` to
`C`'s decimals before adding: `ADD .05 TO 1.06 GIVING C`, `PIC 9V9`, gave 1.0.

The expression stack, for `COMPUTE`:

| Op | Mnem | Operand bytes |
|---|---|---|
| `$50` | PUSHD | src word |
| `$51` | PUSHL | literal-offset word |
| `$52` | POPD | dest word |
| `$53`–`$57` | EADD ESUB EMUL EDIV ENEG | — |
| `$58` | POPDR | dest word — `POPD`, `ROUNDED`: the digits dropped are rounded, half away from zero (2026-11-08) |

`EDIV` gives its quotient at least five decimals (`MAX(a's, b's, 5)`), so a
`ROUNDED` result with four still has a digit to round on.

`COMPUTE X = (A + B) * C` is reverse Polish: `PUSHD A`, `PUSHD B`, `EADD`,
`PUSHD C`, `EMUL`, `POPD X`. The stack is eight deep, which is deeper than any
expression a person writes on one line.

### Compare and branch

| Op | Mnem | Operand bytes |
|---|---|---|
| `$60` | CMPN | left word, right word |
| `$61` | CMPA | left word, right word |
| `$62` | CLASS | item word, test byte, map word — `IS NUMERIC` … `ZERO`; 0 = true (2026-11-08) |
| `$63` | BRA | target-offset word |
| `$64`–`$69` | BEQ BNE BLT BGT BLE BGE | target-offset word |
| `$6A` | BSIZ | target-offset word — and clears the flag |
| `$6B` | BEXC | target-offset word — and clears the flag |

The compare leaves its answer in the condition register and the branch reads
it, so they are always emitted as a pair. **The first operand is the left-hand
side of the COBOL relation**: `IF A > B` is `CMPN A, B` then `BGT`.

`IF … ELSE … END-IF` inverts: emit the compare, then a branch on the *opposite*
relation to the else-part, which is a forward reference and therefore a fixup.

**Compound conditions are jumping code** (CMPCOND.S, 2026-11-08). The grammar is
`cond := and {OR and}`, `and := not {AND not}`, `not := NOT not | ( cond ) | simple`.
Every condition falls through when true and ends with a branch taken when its
last test fails; its other exits are two lists, T and F, chained through the
placeholder words themselves (each holds the offset of the next, 0 at the end).
`AND` aims the left side's T list at the right side; `OR` turns the left side's
last branch round onto T and aims the rest of its F list at the right side;
`NOT` turns the last branch round and swaps the lists. At the end a single F
entry is the caller's placeholder; several are gathered by `BRA OK / L: BRA` so
the caller still gets one. Abbreviated terms (`A = 1 OR 2`, `A > 1 AND < 10`)
borrow the last subject and relation.

### Flow

| Op | Mnem | Operand bytes |
|---|---|---|
| `$70` | PERF | target-offset word, **return-offset word** |
| `$74` | RET | — |
| `$75` | GOTO | target-offset word |

**`PERFORM` carries its own return address and it needs no fixup.** `PERF` is
five bytes, so the return offset is the current code offset plus five —
computable at the moment of emission. The target is the one that may need
fixing up.

`PERFORM … THRU` is the same instruction: the range's exit paragraph ends with
the `RET`. The counted and conditional forms — `$71` `$72` `$73` — trap, so
the compiler lowers every loop itself, each with its stepping **at the top** so
that `END-PERFORM` only ever emits `BRA top`:

```
UNTIL     T: <cond, true -> X>  body  BRA T  X:
n TIMES      PUSH n  POPD c
          T: CLASS c,POSITIVE  BNE X  PUSHD c PUSHL 1 ESUB POPD c  body  BRA T  X:
VARYING      PUSH a  POPD i  BRA C
          T: PUSHD i  PUSH b  EADD  POPD i
          C: <cond, true -> X>  body  BRA T  X:
```

`body` is `PERF p` out of line, or the statements up to `END-PERFORM` in line.
The `TIMES` counter is a hidden item made for the statement.

### Screen

| Op | Mnem | Operand bytes |
|---|---|---|
| `$80` | DISP | src word |
| `$81` | DISPL | literal-offset word |
| `$82` | AT | line byte, column byte — move the cursor |
| `$83` | ACC | dest word |
| `$84` | DISPN | src word — DISP without the newline |
| `$85` | ACCF | dest word, code byte — `ACCEPT ... FROM DATE` (0, YYMMDD) or `TIME` (1, HHMMSSss) |
| `$88` | DISPP | device byte, src word — `DISPLAY ... UPON PRINTER`; the line always ends |
| `$89` | DISPPL | device byte, literal-offset word — the same for a literal |
| `$86` | NL | — |
| `$87` | ACCA | line byte, column byte, dest word — a form field |
| `$8A` | DISPLN | literal-offset word — DISPL without the newline |

`AT` and `ACCA` take their coordinates as **two literal bytes in the instruction**,
not as items — `AT LINE n COLUMN n` is constant in the source, so it is constant
in the code. `DISPLAY a b AT LINE 3 COLUMN 6` compiles to `AT 3 6` and then a
`DISPN`/`DISPLN` for each operand: the `AT` is inserted in front once the
compiler reaches it, and the last operand keeps its no-newline form. (`$82` was
`DISPA`, one item's raw bytes at a position, which nothing ever emitted; it was
replaced on 2026-11-08.)

### Everything else

`$90–$9F` files, `$A0–$BF` tables and strings, `$C0–$CF` BASIC, `$D0–$DF`
services: **every one of them traps.** The dispatch table is a full 256 entries
with `VBAD` in every slot that is not an instruction, so a compiler bug that
emits a wrong byte faults on that byte and names it, rather than walking off
into data.

### The `QUERY` statement — the one service block with a verb

Added to the subset 2026-08-15. `QUERY.md` §15 is the design; the lowering is
four fixed-shape statements with no expression anywhere in them, which is why
the whole thing is about 200 bytes of parser.

| Source | Emits |
|---|---|
| `QUERY q USING d FOR n [GIVING c] [ON ERROR]` | `$D4` q-litoff **w**, d-litoff **w**, `$00` **b**, n-item **w**, c-item **w**, status-item **w**, err **w** |
| `QUERY q USING d OF f [GIVING c] [ON ERROR]` | `$D4` q-litoff **w**, d-litoff **w**, `$01` **b**, f-item **w**, c-item **w**, status-item **w**, err **w** |
| `QUERY NEXT [GIVING r] [AT END]` | `$D5` r-item **w**, end **w** |
| `QUERY SORT [ON ERROR]` | `$D7` err **w** |
| `QUERY FIELD n INTO x` | `$D8` n **b**, x-item **w** |

### The file verbs

Added 2026-08-16. Seven verbs, one parser, one emitter — because `VMFILE` gave
all seven opcodes the **same ten-byte shape**, so the differences between them
are entirely in where the operands come *from*.

| Source | Emits |
|---|---|
| `OPEN mode f` | `$90` ctl **b**, path-litoff **w**, rec-item **w**, status **w**, `$FFFF` |
| `CLOSE f` | `$91` ctl **b**, key **w**, rec **w**, status **w**, `$FFFF` |
| `READ f [NEXT] [AT END]` | `$92` ctl **b**, key **w**, rec **w**, status **w**, target **w** |
| `WRITE r [INVALID KEY]` | `$93` … |
| `REWRITE r` / `DELETE f` / `START f` | `$94` / `$95` / `$96` … |

`ctl` carries the file number in bits 0–1 and, for `OPEN`, the mode in bits
4–7; `READ` reuses that nibble to mean `NEXT`. **Every operand but the control
byte comes out of the file table** at `$1F40`, which `FILE-CONTROL` filled in
during pass one — the parser reads a name, looks the file up, and copies four
words.

**`WRITE` and `REWRITE` name a record, not a file.** That is COBOL's rule, and
it is why the file table keeps the record's item number: `PFBYREC` searches the
two entries for the one whose `FD` declared it.

**The trailing-clause machinery is `QUERY`'s, reused whole.** `PDQPAIR` reads
`AT END` and `INVALID KEY`; `PDQCLS` emits the target, the skip branch and the
one statement. Neither needed a change — the return on having made them
separate routines rather than part of the query statement.

Two stated limits: **one file per ** (COBOL allows a list; the samples
never use one), and the clause is **one statement**, as it is for ,
because there is no  to say where a second would stop.

The status-item word is the `QUERY STATUS IS` item from `SPECIAL-NAMES`, or
`$FFFF` if the program declared none. It rides on `$D4` rather than on a
prologue instruction of its own, and `VMQRY.S` explains why: `$D4` is
necessarily the first query statement to execute, so it is the same one store in
a slightly later place, for three bytes instead of an opcode number.

Three things the emitter does here that are worth copying elsewhere:

- **An absent clause emits `$FFFF`**, not a separate opcode and not a flag byte.
  It is not a valid item number and not a valid code offset, so the handler's
  test is unambiguous and every form is one fixed length.
- **`AT END` and `ON ERROR` are ordinary forward branches** and go on the fixup
  chain of §4 exactly as `IF`'s do. There is nothing special about them beyond
  which condition the handler tests.
- **The field number is an immediate byte**, following `DISPA`'s precedent: it
  is constant in the source, so it is constant in the code.

`QUERY STATUS IS` in `SPECIAL-NAMES` is compile-time — a pointer resolved to an
item and one store in the `ENTER` prologue, the same shape as `CRT STATUS IS`.

## 4. Fixups

A forward reference is a word in the code stream that is not known yet.
The chain lives **in the code stream itself**, which costs no memory at all:

- The symbol for an undefined paragraph holds the offset of the *most recent*
  reference to it, or `$FFFF` for none.
- Emitting a reference writes the symbol's current head into the operand word,
  then makes the symbol point at this new word. The operand word is both a
  placeholder and the link to the previous placeholder.
- Defining the paragraph walks the chain from the head, and at each link reads
  the next offset out before overwriting the word with the real target.

At end of pass 2 any symbol whose head is not `$FFFF` is an undefined
paragraph, and the compiler can name every reference to it because they are
still threaded together.

### COMPUTE and EVALUATE — slice 6

Written 2026-08-16.

**COMPUTE is recursive descent, and it emits postfix for nothing.** Parse the
left operand — which emits it — then the right, then the operator. That *is*
reverse Polish, and there is no operator stack in the compiler because the
6502's own stack holds the half-finished expressions. The shunting yard is the
algorithm you need when you are not allowed to recurse.

```
expr   := term { (+|-) term }
term   := factor { (*|/) factor }
factor := [-] primary
primary:= identifier | literal | ( expr )
```

Precedence falls out of which routine calls which — `CEEXPR` calls `CETERM`, so
multiply binds tighter — and nothing tests a priority number anywhere. Depth is
bounded at eight parentheses, because the hardware stack is 256 bytes and a
runaway bracket would walk off it in silence.

**`COMPUTE X ROUNDED = ...` stores through `POPDR`** (2026-11-08). Until there was
an instruction to put it in, `ROUNDED` was refused with error 24 rather than
accepted and ignored. Error 24 now means `ROUNDED` with no `=` after it.

**EVALUATE has two kinds of forward reference and they are not the same shape.**

```
    CMPx subj, "1"
    BNE  W2
    <stmt>
    BRA  END
W2  CMPx subj, "2"
    ...
```

The `BNE` goes to the *next* `WHEN` — one outstanding at a time, one variable.
The `BRA`s all go to the *same* place and there may be any number of them, so
they are a **chain** — and the chain is `EMREF` and `EMFIX`, the paragraph
fixup machinery, used on something that is not a paragraph. `FIXHD` is a plain
variable, so nothing had to change to lend it out.

Four deep, which is three more than the samples use. **`EVALUATE TRUE` with
condition names is not here**: it needs an 88 to compile to a test, which `IF`
cannot do either, so it is one piece of work that fixes both and it is not this
one. Error 26 names it rather than mis-compiling it.

## 5. Memory

The compiler is an overlay like any other, and its build areas sit **above it
in the same band, in main memory**. There is no aux and no allocator, because
§1 already caps the object at 8K and the band has room for that.

```
$8000-$9FFF   the compiler overlay         8,192 bytes
$A000-$A1FF   OBDESC  descriptor table       512 = 64 items
$A200-$A3FF   OBLIT   literal pool           512
$A400-$AFFF   OBCODE  p-code               3,072
$1000-$13FF   SYMTAB  64 names of 16       1,024  (borrowed)
```

(The August layout. Since 2026-11-11 the descriptors are 128 on text page 2,
`$0800-$0BFF`, and the symbol table is 128 names of up to 30 characters in the
aux language card — `SYMAUX.S`, names in the card's `$D000` bank 1. `CMPCON.S`
and `MEMMAP.txt` have the current map.)

**The symbol table left the band on 2026-08-16**, when `COMPUTE` and `EVALUATE`
needed room the band did not have. It is 1,024 bytes that exist only while a
compile is running, and `$1000-$13FF` is `CATBLK` plus the front of `DCTBUF` —
the directory block and the loaded dictionary. **Nothing is cataloguing and no
dictionary is loaded while the compiler runs**, so the borrow costs nothing; it
is the same argument `QRYLOAD` already makes for staging a `.QRY` there. The
code band grew by a kilobyte and `OBCODE` did *not* have to shrink — which was
the other way of finding the room, and would have capped a compiled program at
2K of p-code.

`CMPEND` must stay below `$A000`, and it joins `LIBEND`, `EDEND`, `FMTEND`,
`QRYEND` and `RPTEND` in `BUILD.md` §5. The four boundaries are `EQU`s and can
move; the sum cannot.

### It is TWO overlays, since 2026-08-16

The `QUERY` statement put `CMPEND` 210 bytes above `OBDESC` and the answer was
to split the compiler in half: `COMPILE1` is the lexer and the DATA DIVISION,
`COMPILE2` is the PROCEDURE DIVISION and the object writer. 4,343 and 6,149
bytes, against 7,168 each.

**The split works because every one of the four build areas above is outside
the overlay band.** The band's code ends at `$9BFF`; `OBDESC` starts at
`$9C00`. So pass two loads over pass one's *code* and finds pass one's
descriptors, literal pool, symbol table and p-code exactly as they were left.
Nothing is written to disk between the passes and nothing is copied. The
layout above was not designed for this and it is what made it free.

**What could not stay in the band.** Both passes `PUT CMPVAR`, and they are
different sizes, so anything `CMPVAR` declares with `DS` lands at a *different
address in each*. Ten values have to survive the swap, so they are EQUated into
`CMPXFR` at **`$1F00`** — the last page of `OVLWORK`, which nothing else uses:

| | |
|---|---|
| `CODLEN` `LITLEN` `NITEMS` `DSEG` | how much of each build area is used |
| `CMPERR` | also read by `SYSMENU`, which decides on it whether to load pass two |
| `NSYMS` | how many names are in `SYMTAB` |
| `NSRC` `LEXLN` | the source length, and where pass one stopped reading |
| `QSTITM` | the `QUERY STATUS IS` item, read in pass one and emitted in pass two |
| `CMPPHS` | which pass has run; pass two refuses to run alone |

The layout lives in `EQUATES.S`, not in `CMPVAR.S`, because `SYSMENU` needs
`CMPERR` and does not `PUT` the compiler's variables. Two files needing the same
address is exactly what `EQUATES` is for.

**Pass two resumes; it does not restart.** Pass one stops on the word
`PROCEDURE` and leaves `LEXLN` on the line after it. The limit that follows is
worth stating rather than discovering: **the `PROCEDURE DIVISION` header must be
the last thing on its line.** It is, in `SKEL.COB` and all three samples.

**`CMPCOM.S` is the file the split created.** `DDFIGN` was in `CMPDATA` and
`DDVSCL` in `CMPPIC` — both pass-one files — and the PROCEDURE parser calls
both, because a literal is a literal wherever it appears and the two divisions
were never as separate as their names suggest. Pulling 200 bytes into a shared
file beat carrying 1,836 bytes of PICTURE and DATA parsing into a pass that
parses neither.

**The source is read from auxiliary memory**, one record a line, exactly as
EDIT holds it — `AXMAP` then `AXGET`. Compiling is therefore the one operation
in the system that needs no disk at all once the source is loaded, and a syntax
error costs nothing to re-run.

## 6. The object file

Twenty bytes of header, then three blocks concatenated in the order the header
declares:

```
0   4  "PCB1"        11  2  litoff
4   1  version = 1   13  2  codeoff
5   2  dataseg       15  2  entry
7   2  itemcount     17  2  codelen
9   2  descoff       19  1  language = 0
```

`descoff` is always 20. `litoff` = `20 + itemcount × 8`. `codeoff` =
`litoff + litlen`. **There is no data-segment offset field** — the data segment
starts at `codeoff + codelen`, and a third number could only disagree with the
two we already have.

`VMRUN` checks the signature, the version *and* the language byte before it
executes an instruction.

### The literal pool holds two kinds of thing

The destination's type says which is being read, so the pool needs no tags:

- **Text**: a length byte, then the characters.
- **Numeric**: an eight-byte NUM8 cell, then **one byte giving its scale**.
  That trailing byte is what lets `PUSHL` put a literal on the expression stack
  with its scale intact.

The compiler pools literals by value, so `MOVE ZERO` a hundred times costs nine
bytes once. Text and numeric literals of the same appearance are different
entries, because they are different bytes.

## 7. The slices

Each one leaves something that runs.

1. **The emitter and the object writer.** No lexer, no parser: a driver calls
   `EMB`/`EMW`/`EMLIT`/`EMDESC` directly and a real `.OBJ` comes out. **This is
   slice 1 and it is written** — see §8. It is deliberately first because
   `PCODE.md` §5 says the way to test the VM is a hand-assembled object of a
   dozen instructions, and this is that, without the hand-assembly.
2. ~~**The lexer.**~~ **Written 2026-08-15.** Fixed-column source out of aux,
   tokens out the other end, with `LEXTEST` dumping them. See §9.
3. **The keyword table and the statement skeleton.** Recognise the four
   divisions and the section headers; walk to the PROCEDURE DIVISION and stop.
4. ~~**The DATA DIVISION.**~~ **Written 2026-08-15.** Level numbers, `PIC` parsing, `VALUE`, the symbol
   table, the descriptor table, data-segment offsets. After this a program's
   *data* compiles.
5. **The PROCEDURE DIVISION, statement by statement.** `MOVE`, `DISPLAY`,
   `ACCEPT`, `STOP RUN` first — the four the sample programs open with — then
   arithmetic, then `IF`, then `PERFORM` and `GO TO` with the fixup chain.
6. **`COMPUTE`** and its expression evaluator.
7. **`COPY`** — built 2026-11-11 in the lexer (CMPLEX.S LXCOPY), one deep; QUICKREF.md has the rules.
8. **The launch stub**, which makes a compiled program a standalone SYS file:
   stub, library, interpreter, object.

## 8. What is built

**Slice 1, written 2026-08-15, never assembled.**

| File | Pass | |
|---|---|---|
| `COMPILE1.S` | 1 | the stub and the pass-one driver |
| `COMPILE2.S` | 2 | the stub and the pass-two driver |
| `CMPEMIT.S` | both | the emitter: bytes, words, literals, descriptors, fixups, and the instruction helpers |
| `CMPCOM.S` | both | `DDFIGN` and `DDVSCL` — the two routines that cross the division boundary |
| `CMPVAR.S` | both | per-pass variables — **holds `CMPEND`**. The handover set is in `EQUATES.S` |
| `CMPLEX.S` | both | **the lexer** — slice 2, see §9 |
| `CMPSYM.S` | both | the compiler's side of the symbol table: wrappers over SYMAUX.S in the aux card (128 names of up to 30, since 2026-11-11) |
| `CMPPIC.S` | 1 | PICTURE parsing |
| `CMPDATA.S` | 1 | **the DATA DIVISION** — slice 4 |
| `CMPOBJ.S` | 2 | the header and the object writer, through the MLI |
| `CMPPROC.S` | 2 | **the PROCEDURE DIVISION** — slice 5, and the `QUERY` statement |
| `OBJTEST.S` | the harness — builds `PCODE.md` §5's dozen-instruction object and writes it out |
| `LEXTEST.S` | the token dump |

Menu option 5 still answers *Not built yet*, and should, until slice 5.

**What slice 1 unblocks immediately**: `PCODE.md` §5's test order ends with
"then the VM, with a hand-assembled object of a dozen instructions". Nobody has
to hand-assemble it now. `OBJTEST` emits it, and the same emitter that will
eventually emit every program is what proves the object format.

## 9. The lexer, as built

`CMPLEX.S`, slice 2, written 2026-08-15. Never assembled; the algorithm was
transliterated and run against `LEXTEST`'s own source on the host, and the
token dump below is what came out.

### The column is part of the token

Every other lexer hands back a type and some text. This one also hands back
`TOKCOL`, **the column the token started in**, because in fixed-form COBOL that
is not decoration — it is grammar. A word beginning in Area A is a division, a
section, a paragraph or an `01`; the same word beginning in Area B is a
statement. A parser without the column cannot tell them apart and would need a
mode flag threaded through every rule.

`TOKLIN` is **1-based**, because it is the number that goes in an error
message. The aux record number, which is what positions EDIT's cursor, is one
less.

### Five token types

`TKEOF` `TKWORD` `TKNUM` `TKSTR` `TKPUNC`. Punctuation is one character per
token; which characters are legal is the parser's business.

A **level number comes back as `TKNUM`**, because lexically that is what `01`
is. The parser knows it is a level from its column and its context, which is
the same knowledge it needs anyway.

### The three things that are not obvious

**A full stop is part of a number only if a digit follows it.** `123.45` is one
token; the `.` that ends `MOVE 123.45 TO N.` is its own. Without the lookahead
the lexer would swallow the end of every statement that finishes with a
numeric literal — and the parser would then see a program with no sentences in
it.

**A PICTURE string is not a COBOL word.** `S9(4)V99` has parentheses in it and
would come back as five tokens with the meaning spread between them. Every real
COBOL compiler special-cases this and so do we: the parser sees `PIC`, then
calls **`LEXPIC`**, which takes the next run of non-blanks whatever is in it.
Thirty bytes here that save a mess in the DATA DIVISION parser.

**A token too long is an error, not a truncation.** A silently shortened data
name would match the wrong symbol, and that is a bug nobody finds by reading
the source. `LEXERR` = 1 unterminated literal, 2 token too long.

### What the dump looks like

```
LN CL TYPE TEXT
 1  2 WORD IDENTIFICATION      6  2 NUM  01
 1 17 WORD DIVISION            6  6 WORD MSG
 1 25 PUNC .                   6 12 WORD PIC
 2  2 WORD PROGRAM-ID          6 16 WORD X(13)
 2 12 PUNC .                   6 21 PUNC .
 2 14 WORD HELLO               7 16 WORD S9(4)V99
 4  2 WORD DATA                7 25 WORD COMP-3
 5  2 WORD WORKING-STORAGE    10 11 NUM  123.45
 5 18 WORD SECTION            10 22 PUNC .
 9  2 WORD MAIN               11 14 STR  HELLO, WORLD.
 9  6 PUNC .                  11 29 PUNC .
```

Line 3 is a comment and does not appear at all. `MAIN` at column 2 is a
paragraph; `MOVE` at column 6 is a statement; that difference is the whole of
the grammar and it is visible in the dump.

### Two limits, stated

A **literal may not span lines** — the continuation indicator is recognised and
recorded in `LEXHDL`, but joining two lines into one literal is not done. A
literal that runs off column 80 is `LEXERR` = 1.

**`LEXPIC` does not cross a line boundary usefully**: if it has to fetch a new
line it will read from column 1, the indicator. A PICTURE is always on the same
line as its `PIC` in practice, so this has been left rather than guarded.
