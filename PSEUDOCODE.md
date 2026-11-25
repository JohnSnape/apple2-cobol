# The tricks, in pseudocode

Flowchart-ready descriptions of the parts of this system that are hard to see
from the listing. Each entry has the same four parts:

- **The problem** — what the machine refuses to do
- **The pseudocode** — numbered steps, explicit loops and decisions
- **Why it works** — the mechanism, stated once
- **Reuse it when** — the general shape, so the reader can lift the idea

Conventions in the pseudocode: `←` is assignment, `[i]` is indexing, `LOOP …
END LOOP` brackets a loop, `IF … END IF` a decision, and a comment sits after
`--`. Byte values are shown as `$xx`. Where a step maps to one 6502
instruction the instruction is named, because that is usually the point.

> **A caveat to carry through the whole file.** Most of this code has been
> assembled but not run, and three of the largest pieces — `BMUL`/`BDIV`,
> `PICTURE`, `VM` — have never been executed at all. The techniques are sound
> and the reasoning is checked, but pseudocode is not a test. See `STATUS.md`.

---

# A. The screen

## A1. The console scroll — never read the screen

**The problem.** Scrolling normally means reading the line below and writing it
one line up. On this machine the even columns live in auxiliary memory, and
reading auxiliary memory means turning **RAMRD** on — which redirects
*instruction fetch* as well as data. The routine doing the scroll would fetch
its own next instruction from the bank it just switched to, and vanish.

The firmware escapes this by running with 80STORE on. We cannot: 80STORE is
exactly what makes text page 2 unreachable, and page 2 is the whole reason the
driver exists.

**The answer.** Never read the screen at all. Keep a shadow copy of the 24
visible rows in main memory, write every character to both, and scroll the
shadow.

### A1.1 The write path — every character goes two places

```
CONPUTC (ch)
 1  code ← CONV(ch)              -- ASCII to screen code, once
 2  write code into SHADOW at (row, col)
 3  write code onto the SCREEN at (row, col)
 4  col ← col + 1
 5  IF col = 80 THEN
 6      CONCR                    -- end of line: wrap, and scroll if needed
 7  END IF
```

Converting once and storing twice is what makes the repaint in A1.3 free of
thought: the shadow already holds screen codes, so a repaint copies and does
not convert.

### A1.2 The scroll — one block move

The shadow is a flat 1,920-byte array, row-major, every row exactly 80 bytes.
So moving 23 rows up by one row is moving 1,840 bytes down by 80 — **one
straight copy that has no idea rows exist.**

```
CONSCRU
 1  src   ← SHADOW + 80          -- the first byte of row 1
 2  dst   ← SHADOW               -- the first byte of row 0
 3  pages ← 7                    -- 1840 = 7*256 + 48
 4  y     ← 0
 5  LOOP                         -- the whole pages
 6      LOOP
 7          dst[y] ← src[y]
 8          y ← y + 1            -- INY, wraps 255 → 0
 9      UNTIL y = 0              -- BNE: the wrap IS the loop test
10      src ← src + 256          -- INC of the high byte only
11      dst ← dst + 256
12      pages ← pages - 1
13  UNTIL pages = 0
14  LOOP                         -- the 48-byte tail; y is already 0
15      dst[y] ← src[y]
16      y ← y + 1
17  UNTIL y = 48
18  blank row 23 in the shadow
19  CONBLIT                      -- repaint (A1.3)
```

**Why it works.** Three separate things:

- **The destination is below the source**, so a forward copy can never overtake
  itself. Copying *up* by one row would need a backward loop.
- **Y wrapping to zero is the page loop's own test.** `INY` / `BNE` copies
  exactly 256 bytes and leaves Y at 0, ready for the next page — and ready for
  the tail loop with no reset.
- **The aux/main split inside a row never enters into it.** Each row is 40 aux
  bytes then 40 main bytes, but that split is identical in *every* row, so it
  travels with the bytes. There is no aux pass and no main pass.

The routine this replaced walked row by row and called a multiply-by-80
subroutine twice per row — **46 multiplies per scroll**, now zero.

### A1.3 The repaint — two copies a row

```
CONBLIT
 1  FOR row ← 0 TO 23
 2      scr ← SCRADDR(row)       -- table lookup, rows are scrambled
 3      sh  ← SHADOW + row*80
 4      switch writes to AUX
 5      copy 40 bytes  sh[0..39]  → scr[0..39]      -- even columns
 6      switch writes to MAIN
 7      copy 40 bytes  sh[40..79] → scr[0..39]      -- odd columns
 8  END FOR
```

Both halves are written to the *same* screen addresses; only the target bank
differs. That is what 80-column memory is.

> **A variation that does not pay, and why.** It is tempting to do all 24 aux
> halves in one pass and all 24 main halves in another, cutting 48 bank
> switches down to 2. A bank switch is one `STA` to a soft switch — 4 cycles —
> so that saves about 184 cycles. But the screen rows are scrambled, so each
> pass must walk the row table separately: 48 `SCRADDR` calls instead of 24, at
> about 32 cycles each, costing about 480. **Net loss of ~300 cycles and one
> extra loop.** Worth showing the reader the arithmetic rather than the
> conclusion — this is how you decide such things, and the intuitive answer is
> wrong.

### A1.4 What the shadow is not

It is **not scrollback**. It is exactly 24 rows — a mirror of what is on the
glass this instant. A line that scrolls off the top is overwritten in the
shadow at the same moment it leaves the display, and it is gone, exactly as on
an unmodified Apple II. The editor keeps its lines because keeping lines is
what an editor is for, and it does that somewhere else entirely (D1).

**Reuse it when** a device is write-only in practice — you can put data there
but reading it back is expensive, dangerous, or impossible. Keep the authority
in memory you own, treat the device as a projection of it, and never ask the
device what it holds.

---

## A2. One shift, two answers

**The problem.** In 80-column mode, even columns live in auxiliary memory and
odd columns in main. Given a column number you need *two* facts: which byte of
the 40-byte row to write, and which bank to write it to. That looks like a
divide and a test.

```
TDPUTC (code)
 1  A ← col
 2  A ← A >> 1        -- LSR: quotient in A, low bit into CARRY
 3  Y ← A             -- the byte offset within the row
 4  IF carry = 1 THEN            -- odd column
 5      screen[Y] ← code         -- main memory, no switching
 6  ELSE                         -- even column
 7      switch writes to AUX
 8      screen[Y] ← code
 9      switch writes to MAIN    -- restore immediately, always
10  END IF
11  col ← col + 1
```

**Why it works.** One `LSR` produces both answers at once: the quotient is
`col / 2`, the byte offset, and the bit shifted out into carry is `col AND 1`,
the parity. A divide and a mask, in one instruction, with the second result
already sitting in the flag the next branch tests.

Note step 9. Writing to aux is safe — `RAMWRT` does not affect instruction
fetch, because fetches are *reads* — but the switch is restored immediately
anyway. Every routine in the driver leaves the machine in the same state it
found it, which is what lets any of them be called from anywhere.

**Reuse it when** you need a quotient and a remainder by a power of two.
Shifting gives you both, and the remainder arrives in a flag rather than a
register.

---

## A3. The branchless page switch

**The problem.** Text page 1 rows begin at `$0400`; page 2 rows at `$0800`. The
row-address lookup should not have to know which page is showing, and should
certainly not branch on it inside the innermost routine in the system.

```
SETPAGE (n)
 1  IF n = 1 THEN pghi ← $04 ELSE pghi ← $00   -- decided ONCE, here

SCRADDR (row)
 1  ptr.low  ← SCRTBL[row]           -- page 1 base, low byte
 2  ptr.high ← SCRTBH[row] + pghi    -- page 1 base, high byte, plus the offset
 3  RETURN ptr
```

**Why it works.** Page 2 is exactly `$0400` above page 1 for every row, so the
difference between the pages is one addend. The table is stored for page 1
only; `pghi` holds `$00` or `$04`, and `SCRADDR` **never branches** — it adds a
number that is usually zero.

**Reuse it when** two variants of a structure differ by a constant offset.
Store one table, keep the offset in a variable, and let the addition be the
switch. A variable added is cheaper than a branch taken, and much cheaper than
two tables that can drift apart.

---

## A4. The inverse-uppercase trap

**The problem.** A character's attribute is carried in the *value* written to
screen memory, so converting ASCII to a screen code is where normal and inverse
are decided. Inverse looks like "clear the high bit". It is not.

```
CONV (ch)
 1  ch ← ch AND $7F
 2  IF attribute = NORMAL THEN
 3      RETURN ch OR $80
 4  END IF
 5  -- inverse:
 6  IF ch < $40 THEN RETURN ch              -- space, digits, punctuation
 7  IF ch >= $60 THEN RETURN ch             -- lowercase
 8  RETURN ch AND $3F                       -- $40-$5F folds down to $00-$1F
```

**Why it works.** In the alternate character set the inverse forms of space,
digits and punctuation already sit at `$20–$3F`, and inverse lowercase at
`$60–$7E`, so those pass through untouched. But `$40–$5F` — `@`, `A`–`Z` and
five symbols — is where **MouseText** lives. Echo a typed `A` (`$41`) into an
inverse field by merely clearing the high bit and you store `$41`, which is a
MouseText glyph, not an inverse A. Inverse uppercase lives at `$00–$1F`, so
that one range must be folded down by `$40`.

This is why the conversion is a range test rather than a single mask, and it is
the reason the whole system's attribute rule reads *furniture is normal, data
entry is inverse*: MouseText has no inverse form at all, so anything drawn with
it must be normal.

**Reuse it when** an encoding is *almost* uniform. The exception is where the
bugs live, and one range test written once is cheaper than the same bug found
twice.

---

# B. Arithmetic on a machine with no multiply and no divide

## B1. The seven-byte decimal add

**The problem.** Money is decimal. Standard COBOL packs the sign into the low
nibble of the last byte, which means a field cannot be added as it stands — the
sign would be treated as a digit — so every routine masks it out, adds, and puts
it back.

**The answer.** Move the sign out of the digits. A NUM8 cell is:

```
offset 0     flags   -- bit7 negative, bit6 uninitialised, bit5 overflow
offset 1..7  14 packed decimal digits, most significant first
```

```
NMADD (a, b)  -- |b| ← |b| + |a|
 1  CLEAR carry
 2  SET DECIMAL MODE            -- SED
 3  y ← 7                       -- the least significant byte
 4  LOOP
 5      b[y] ← b[y] + a[y] + carry     -- one ADC, two digits at a time
 6      y ← y - 1
 7  UNTIL y = 0                 -- byte 0 is the FLAGS byte: stop before it
 8  CLEAR DECIMAL MODE          -- CLD
 9  RETURN carry                -- carry out = overflow
```

**Why it works.** Two things, and the second is nearly a joke:

- **There is no masking anywhere.** The magnitude bytes are nothing but digits,
  so the loop body is a single `ADC` and the whole routine is seven of them.
  One byte of overhead per value bought the removal of every mask in the system.
- **The flags byte doubles as the loop terminator.** Digits occupy offsets 1
  through 7, so counting down and stopping at zero stops exactly where the
  digits stop. `DEY` / `BNE` needs no separate counter and no comparison.

The flag byte also has room for a bit that says *this field was never
assigned*, which packed decimal has nowhere to put. That is the difference
between a debugger that can say NUMERIC OVERFLOW IN CALCULATE-GROSS and one
that can only shrug.

**Reuse it when** a format forces you to fight it on every operation. Adding a
byte of overhead to make the hot path trivial is nearly always the right trade —
count the instructions you delete, not the bytes you add.

## B2. Multiplying by a constant with shifts and adds

**The problem.** `EDIT` needs `line × 80` to find a cache slot; `AUXMEM` needs
`index × record-size` to find an address. There is no multiply instruction.

Two techniques, and the choice between them is the lesson.

### B2.1 When the constant is known at assembly time

`80 = 64 + 16`, and both are shifts:

```
CROWAD (row)  -- row * 80
 1  t ← row
 2  t ← t << 4          -- row * 16   (four ASL/ROL pairs, 16-bit)
 3  u ← t               -- keep it
 4  t ← t << 2          -- row * 64
 5  RETURN t + u        -- 64r + 16r = 80r
```

Two shifts and one add, no loop, no test.

### B2.2 When the constant is only known at run time

The record size is a variable, so the general form is long multiplication in
binary — the same algorithm as B3, eight steps deep instead of fourteen:

```
MULTIPLY (multiplicand, multiplier)
 1  product ← 0
 2  LOOP WHILE multiplier ≠ 0
 3      IF multiplier is odd THEN         -- LSR put the low bit in carry
 4          product ← product + multiplicand
 5      END IF
 6      multiplier   ← multiplier >> 1
 7      multiplicand ← multiplicand << 1
 8  END LOOP
 9  RETURN product
```

**Why it works.** Every number is a sum of powers of two, and shifting the
multiplicand left is multiplying it by the next power. Step 3 asks whether this
power is present.

**Reuse it when** — and this is the point of showing both — you have a choice.
If the constant is fixed, decompose it by hand and pay two shifts. If it is not,
pay the loop. Writing the general routine and then calling it with a constant is
the mistake, and it is easy to make when the general routine already exists.

## B3. Long multiplication, one digit per byte

**The problem.** Decimal mode helps `ADC` and `SBC` and **nothing else**. There
is no decimal multiply, and packed digits — two per byte — are the wrong shape
for one anyway.

**The answer.** Change the representation for the duration. Unpack to one digit
per byte, do it exactly as you would on paper, and pack the answer back.

```
BMUL (a, b)  -- b ← b * a
 1  unpack a into DA[0..13]       -- one decimal digit per byte
 2  unpack b into DB[0..13]
 3  clear DP[0..27]               -- the product, twice as many digits
 4  FOR i ← 13 DOWN TO 0                 -- each digit of b
 5      carry ← 0
 6      FOR j ← 13 DOWN TO 0             -- each digit of a
 7          k ← i + j + 1                -- where this partial product lands
 8          p ← DA[j] * DB[i]            -- see step 8a
 9          p ← p + DP[k] + carry        -- add in what is already there
10          carry ← 0
11          LOOP WHILE p >= 10           -- normalise to one digit
12              p ← p - 10
13              carry ← carry + 1
14          END LOOP
15          DP[k] ← p
16      END FOR
17      DP[i] ← DP[i] + carry            -- the final carry of the row
18  END FOR
19  pack DP back into b, checking for overflow
20  sign of b ← sign of a XOR sign of b
```

Step 8a — the digit-by-digit multiply itself, with no multiply instruction:

```
 8a  p ← 0
     LOOP DA[j] TIMES              -- at most 9 iterations
         p ← p + DB[i]
     END LOOP
```

**Why it works.** This is the paper method, and that is its whole
justification. Carry the digit, bring the next one down. It is far slower than
packed arithmetic and enormously easier to read, and the contrast with B1 is
the teaching point: **a representation that is ideal for one operation can be
the wrong one for another.** Packed decimal makes addition nearly free and
multiplication awkward, so multiplication changes representation, does its
work, and changes back.

Note steps 11–14: normalising by repeated subtraction of ten, because there is
no divide either. A single-digit product is at most 81, so the loop runs at
most eight times.

**Reuse it when** the fast representation fights the operation. Converting to a
clumsy-but-workable form and back can beat forcing the clever form to do
something it was not shaped for — and it will always be easier to debug.

## B4. Printing a number with no divide

**The problem.** Every number that reaches a screen has to become digits.
Extracting digits is repeated division by ten, and there is no divide.

```
DEC16 (n)  -- print a 16-bit number, leading zeros suppressed
 1  POWERS ← [10000, 1000, 100, 10, 1]
 2  suppressing ← TRUE
 3  FOR x ← 0 TO 4
 4      digit ← 0
 5      LOOP WHILE n >= POWERS[x]        -- 16-bit subtract, test the carry
 6          n ← n - POWERS[x]
 7          digit ← digit + 1
 8      END LOOP
 9      IF digit ≠ 0 THEN suppressing ← FALSE
10      IF x = 4 THEN suppressing ← FALSE   -- always print the units digit
11      IF suppressing THEN
12          print " "
13      ELSE
14          print digit + "0"
15      END IF
16  END FOR
```

**Why it works.** Division is repeated subtraction, and the count of
subtractions *is* the digit. The loop runs at most nine times per digit, so the
whole thing is bounded and small.

Step 10 is the detail worth pointing at: without it, zero prints as five
spaces. The units digit is never suppressed, in any number-formatting routine
ever written, and forgetting it is the classic bug.

**Reuse it when** you need division by a small set of known constants. A table
of those constants plus repeated subtraction beats a general divide routine and
is much easier to get right.

---

# C. Memory that moves under you

## C1. Two tests, opposite constraints

**The problem.** Two routines both test banked memory. Both are in danger from
the switch they throw. **The danger is opposite in each**, and so is the fix.

```
CHK128 -- is there a second 64K bank?
 1  copy this routine to $0100          -- and JMP there
 2  switch reads AND writes to AUX
 3  write $EE to LOW  ($0C00)
 4  write $EE to HIGH ($7C00)           -- 28K away, same bank
 5  -- test 1: does it store?
 6  IF LOW ≠ $EE THEN answer NO
 7  -- test 2: does it CHANGE when told to?
 8  shift LOW left in memory             -- $EE becomes $DC
 9  shift the same value left in A       -- A becomes $DC too
10  IF LOW ≠ A THEN answer NO
11  -- test 3: are LOW and HIGH really different memory?
12  IF HIGH = A THEN answer NO           -- changing LOW changed HIGH: aliased
13  answer YES
14  restore MAIN reads and writes        -- on every path, including failure
```

`CHK128` **must** run from `$0100`, because `RAMRD`/`RAMWRT` switch
`$0200–$BFFF`. Code anywhere in that range would bank *itself* out mid-test.
The stack page is outside the switched range, so it is safe ground.

```
FINDBNK -- how many auxiliary banks exist?
 1  count ← 0
 2  FOR bank ← 0 TO 127
 3      select bank                      -- write the number to $C073
 4      write bank AND its complement into that bank's memory
 5      read both back
 6      IF both match THEN
 7          TABLE[count] ← bank ; count ← count + 1
 8      END IF
 9  END FOR
10  select bank 0                        -- always leave bank 0 selected
11  RETURN count
```

`FINDBNK` must **not** run from `$0100`, because it switches **ALTZP**, which
moves `$0000–$01FF` — including the stack. The one page that saved `CHK128` is
the one page that would destroy this.

**Why `CHK128` needs three tests.** Each one catches a different lie:

- **Test 1** catches nothing there at all — no memory, no store.
- **Test 2** catches a floating bus or a latch echoing the last value written.
  Something that echoes `$EE` will hand back `$EE` when asked; it will not
  correctly hold `$DC` after being shifted. *Read back what you wrote* is a
  weak test; *change it and read back the change* is a strong one.
- **Test 3** catches **address aliasing** — a card that decodes too few address
  lines and mirrors the same physical memory at many addresses. Two locations
  28K apart are written, one is modified, and the other must not move. If it
  does, the "memory" is one small block wearing many addresses.

**Why `FINDBNK` writes a complement.** Same principle, one test instead of
three: writing a value *and its complement* into each bank and requiring both
back is very hard to satisfy by accident. On a plain IIe every bank select is
ignored, bank 0 verifies, bank 1 does not, and the count comes out as 1 — so
nothing above has to know whether a card is fitted.

Note step 14. The main/aux switches are restored on **every** path out,
including the failures. A test that leaves the machine in a strange state when
it fails is worse than no test, because the failure message will not reach the
screen.

**Reuse it when** the code doing a test lives in the thing being tested. Ask
first *what does this switch move?*, and put the routine where the answer
cannot reach it. The two cases here have the same hazard and opposite
addresses, which is why they belong side by side in the book.

## C2. Code that must exist at the same address in every bank

**The problem.** `RAMRD` redirects **instruction fetch** as well as data. The
instruction after you throw the switch is fetched from the bank you just
selected. If your routine is not sitting at that same address in that bank, the
processor executes whatever is.

**The answer.** Put an identical copy in every bank, so the switch becomes
invisible: execution simply carries on in a copy of the same code.

```
BMINIT -- install the mover everywhere
 1  copy the mover template to $0300 in MAIN
 2  FOR each bank in TABLE
 3      select bank
 4      switch WRITES to aux                    -- reads stay on main
 5      copy $0300..$033F to $0300              -- source main, dest aux
 6      switch writes back to MAIN
 7  END FOR
 8  select bank 0
```

Step 5 is worth staring at. Source and destination are the *same address*, and
the loop reads main and writes aux, so it copies the page onto itself in
another bank. Only `RAMWRT` is on, and writes do not affect instruction fetch,
so this loop is never in danger.

```
BMENTRY (page, bank, direction)   -- resident at $0300 in every bank
 1  IF direction = WRITE THEN GOTO 10
 2  -- READ: bank → main $0200
 3  IF bank ≠ MAIN THEN
 4      select bank
 5      switch READS to aux            -- from here on, instructions come
 6  END IF                             --   from the aux copy of this code
 7  copy 256 bytes  (page) → $0200
 8  GOTO 17
10  -- WRITE: main $0200 → bank
11  IF bank ≠ MAIN THEN
12      select bank
13      switch WRITES to aux           -- reads, and so fetches, stay on main
14  END IF
15  copy 256 bytes  $0200 → (page)
17  select bank 0 ; restore MAIN reads and writes
```

**Why it works, and the asymmetry that proves it.** Only the **read** path
needs the duplicated copies. The write path sets `RAMWRT` alone and never
leaves main memory for its instructions — which is exactly why the installer in
`BMINIT` can safely be an ordinary loop. When you see that only half the
routine needed the trick, you have understood the trick.

Two details carried in the code and worth carrying into the prose: zero page
follows **ALTZP**, not `RAMRD`, so pointers in zero page survive the switch and
the loop can use them throughout. And step 17 always restores bank 0, because
bank 0 is the one the 80-column firmware paints the screen from — leave any
other selected and the display turns to confetti.

**Reuse it when** you switch anything that affects instruction fetch. Either
the code must not be in the switched region (C1), or it must be identical on
both sides of the switch (C2). There is no third option.

## C3. Choose the geometry so the division is a shift

**The problem.** Auxiliary memory is not one flat space — it is N separate 64K
banks with one visible at a time. Turning a record number into a bank and an
offset means dividing. There is no divide.

**The answer.** Do not divide. *Choose* the number of records per bank to be a
power of two, and declare it.

```
AMMAP (record)
 1  bank  ← record >> SHIFT             -- SHIFT LSRs, no division
 2  index ← record - (bank << SHIFT)    -- shift back and subtract
 3  addr  ← BASE + index * RECSIZE      -- shift-and-add (B2.2)
 4  RETURN (bank, addr)
```

**Why it works.** Step 1 is the division, and it is free. Step 2 is the
remainder: shifting the bank number back left and subtracting costs less than
building and applying a mask, and it works for any shift without a table of
masks.

The geometry was then chosen so two limits meet exactly. At 80 bytes a record,
512 records fill 40,960 bytes of a bank's 45,824 usable — and a 16-bit record
number at 512 records a bank reaches **exactly 128 banks**, which is exactly
what the hardware allows. Neither limit wastes the other.

One more decision worth stating: every bank's usable space starts at `$0C00`,
bank 0 included. Banks above 0 have nothing below that address, so the system
gives up 2,560 bytes per bank to keep **one mapping with no special case**. On
a machine this size that is usually the wrong trade; here, buying uniformity
with memory is what keeps this routine four steps long.

**Reuse it when** you get to pick the constants. Powers of two turn division
into shifts and modulo into masks. The freedom to choose the layout is worth
more than any amount of cleverness applied afterwards to a layout you did not
choose.

---

# D. Structures that make the hard case cheap

## D1. The ring — the low byte of the line number *is* the slot

**The problem.** The editor holds each source line as a record in auxiliary
memory. Repainting a twenty-line window would mean twenty cross-bank reads, and
scrolling one line would mean twenty more. Every keystroke would touch
auxiliary memory.

**The answer.** Cache 52 consecutive lines in main memory — sixteen above the
window, the twenty on screen, sixteen below — in a ring of 64 slots.

```
CADDR (line)
 1  slot ← line AND 63              -- ONE instruction
 2  RETURN CACHE + slot * 80        -- shift-and-add (B2.2)
```

```
SCROLL DOWN ONE LINE
 1  top ← top + 1
 2  fetch the one line entering the far margin from aux into its slot
 3  repaint the window from the cache
```

**Why it works.** The ring is 64 slots and **64 divides 256**, so `line AND 63`
is the slot with no head pointer, no wrap arithmetic, and no bookkeeping. A
line that leaves the ring simply has its slot taken by the line arriving 52
lines away — the eviction is automatic and costs nothing, because it is the
same store that brings the new line in.

Scrolling therefore costs **one** record read instead of twenty. Typing costs
none at all: edits change the cache in place and mark the line dirty, and the
record goes back to auxiliary memory only when the cursor leaves the line.

**Reuse it when** a window slides over data too large to hold. Size the ring to
a power of two larger than the window, index it by the low bits of the absolute
position, and let eviction be a side effect of arrival. The cost of the trick
is the gap between 52 and 64 — twelve slots of slack bought the entire
arithmetic.

## D2. Streaming a file that exists nowhere in memory

**The problem.** The editor holds a program as records scattered across
auxiliary banks. A 500-line program is 40,000 bytes and there is no point at
which it is a contiguous block anywhere — so the library's whole-file
`FLOAD`/`FSAVE`, which move one buffer, have nothing to be handed.

Two more constraints sharpen it:

- **The ProDOS file buffer is not yours.** The 1024 bytes passed to `OPEN` are
  ProDOS's private working space — the current data block and the index block —
  and it rewrites them on every call. `READ` and `WRITE` take a **separate**
  data address and count. Staging data in the file buffer corrupts it.
- **You cannot bulk-copy from aux either.** A 512-byte window into the record
  image can straddle a bank boundary, and `AUXMOVE` has no idea banks exist.
  Only the record mapper (C3) does.

**The answer.** A 512-byte staging buffer in main memory, filled and drained a
record at a time.

```
SAVE
 1  flush the line being typed back to its record
 2  open the file
 3  staged ← 0
 4  FOR line ← 0 TO lastline
 5      fetch record `line` from aux into LINEBUF   -- via the mapper
 6      len ← LINEBUF without its trailing spaces
 7      IF 512 - staged < 81 THEN                   -- 80 columns + the CR
 8          WRITE `staged` bytes from STAGE
 9          staged ← 0
10      END IF
11      append LINEBUF[0..len-1] to STAGE
12      append $0D to STAGE
13  END FOR
14  IF staged > 0 THEN WRITE `staged` bytes
15  close the file
```

```
OPEN
 1  open the file
 2  line ← 0 ; col ← 0 ; LINEBUF ← 80 spaces
 3  LOOP
 4      READ up to 512 bytes into STAGE, giving `count`
 5      IF error OR count = 0 THEN EXIT          -- end of file
 6      FOR i ← 0 TO count-1
 7          ch ← STAGE[i] AND $7F                -- accept high ASCII too
 8          IF ch = $0D THEN
 9              store LINEBUF as record `line`
10              line ← line + 1 ; col ← 0 ; LINEBUF ← 80 spaces
11          ELSE IF ch = $09 THEN col ← min(col + 4, 80)
12          ELSE IF ch >= $20 AND col < 80 THEN
13              LINEBUF[col] ← ch ; col ← col + 1
14          END IF                               -- else: dropped
15      END FOR
16  END LOOP
17  IF col > 0 THEN store LINEBUF as record `line` ; line ← line + 1
18  IF line = 0 THEN store one blank line ; line ← 1
19  linecount ← line ; cursor ← top ; invalidate the cache
20  close the file
```

**Why it works.**

- **Order is inherent.** Line N is record N, so neither direction sorts,
  indexes or seeks. Save counts up and stops; open counts up and stops.
- **512 is a batching choice, not a requirement.** ProDOS blocks any byte count
  itself. Chunking makes one MLI call a *block* instead of one a *line*, and
  that is the whole of the speed argument.
- **A line straddling a chunk boundary needs no special case.** The record
  under construction simply continues into the next chunk — `col` does not
  care that the source ran out. This is the single nicest property of the
  design, and it is a consequence of keeping the partial line in a buffer of
  its own rather than trying to find line ends inside the chunk.
- **Step 17 exists because a last line with no terminator is still a line.**
  Forgetting it silently drops the final statement of any file that does not
  end in a newline, which is most files written by most editors.

Two things the code needs that the sketch above does not show, both learned the
hard way by everyone who has written this:

- **DESTROY before CREATE.** ProDOS has no truncate. Writing a shorter program
  into an existing longer file leaves the old tail in place, and that tail is
  read straight back as source next time.
- **CLOSE on the error path.** A file left open loses the blocks it was
  holding. Every early exit closes first and reports second.

**Reuse it when** the thing you are writing out has no single address. The
shape is general: an outer loop over logical units, a staging buffer sized to
the largest unit plus a margin, a flush test *before* appending rather than
after, and a final flush outside the loop. It is the same shape whether the
units are lines, records, or packets.

## D3. A dispatch table where every wrong byte faults

**The problem.** The interpreter fetches a byte and jumps through a table. Most
byte values are not opcodes. If the table only covers the values you defined, a
jump that has gone wrong walks through data *executing it*, and the machine
does something inexplicable a long way from the mistake.

```
BUILD THE TABLE
 1  fill all 256 entries with the address of VBAD
 2  overwrite the entries that are real opcodes

FETCH / DECODE / DISPATCH
 1  op ← code[IP] ; IP ← IP + 1
 2  jump to TABLE[op]

VBAD
 1  report the opcode and the current source line
 2  reset the hardware stack pointer to its value at entry
 3  return to the menu
```

**Why it works.** The table is 256 entries because the byte is eight bits;
covering all of it costs nothing but the space you already paid for. Every byte
that is not an opcode points at the fault handler, so **the machine stops on
the first bad byte** rather than at some unrelated place later.

Step 2 of `VBAD` is the subtle one. A fault can be raised inside a helper
reached by `JSR`, so the return addresses stacked above it lead back into an
instruction that is being abandoned. Unwinding them is meaningless; the handler
*resets* the stack pointer to the value saved when the interpreter started.
This is also why opcode handlers return to the fetch loop with a jump and never
`RTS` — nothing is allowed to accumulate on the hardware stack in the first
place.

The `LINE` opcode is what makes the message useful: the compiler emits one per
source statement, so the interpreter always knows which line it is executing.
A fault that names a line is a bug report; one that names an address is a
puzzle.

**Reuse it when** you dispatch on untrusted or computed values. Make the table
total, point everything undefined at one handler, and you convert a class of
silent corruption into a single clear stop.

## D4. The frozen jump table

**The problem.** Compiled programs call the runtime by absolute address, and an
object file outlives any particular assembly of the library it was compiled
against.

```
THE RULES
 1  the table sits at a fixed base, at the FRONT of the library's own code
 2  new entries are APPENDED to the end, never inserted
 3  entries are never reordered
 4  a retired entry keeps its three bytes and becomes an RTS
 5  a retired slot is NEVER reused
```

**Why it works.** Rule 1 keeps the library one contiguous file with one load
address; put the table anywhere else and it becomes two files, or one file with
a twenty-kilobyte hole through the middle of it. Rule 2 is safe because an
already-compiled object cannot notice entries past the ones it knows about.
Rules 4 and 5 are what make deletion possible at all — an object compiled
against the old library returns harmlessly instead of landing in whatever moved
up into the gap.

Only the *base* is frozen, not the count. This system's table grew past its
original 64 entries and the additions cost nothing.

There is a matching move on the other side, worth the same paragraph: when two
soft-switch names changed meaning, the equates were **deleted rather than
redefined**, so any code still using them fails to assemble instead of quietly
writing to the wrong bank. Retiring a name loudly is the same discipline as
retiring a slot loudly.

**Reuse it when** anything you compile outlives the thing it calls. The rule is
append-only, and the cost of obeying it is three bytes per mistake.

---

# E. Suggested figures

For the book, the entries that most repay a drawn figure — and what the figure
should show:

| Entry | Figure |
|---|---|
| A1 | Three panels: write path (one char → two places), scroll (one arrow, whole block, down by 80), repaint (two 40-byte arrows a row). The point is that only the middle panel moves anything |
| A2 | A column number in binary, with the `LSR` splitting it into offset and carry |
| C1 | Memory map with the switched region shaded, `$0100` marked safe for one test and fatal for the other. **The strongest single figure in the book.** A second panel showing the three lies test 1, 2 and 3 each catch |
| C2 | Main and one aux bank side by side, the identical `$0300` page in both, and the fetch arrow crossing at the switch |
| C3 | A record number in binary, cut by the shift into bank and index |
| D1 | 64 slots around a circle, the 20-line window as an arc, and the one arrow that moves when the window slides |
| B3 | A paper long-multiplication worked in the same layout as the `DP` array |
