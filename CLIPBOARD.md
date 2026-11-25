# The clipboard — an open format for passing data between programs

**This file is a shared specification.** An identical copy belongs in the tree of
every program that implements it, and where the copies differ, the oldest
unmodified one is right until somebody reconciles them deliberately and bumps the
version.

It is written as a **published format**, not as a private handshake between two
particular programs. That is deliberate and it is not a formality: any program on
this machine may read and write a clipboard, the format is complete as documented
here, and no implementation needs to know what wrote a clip in order to use it.

ProDOS type **$54, mnemonic `CLP`**.

---

## 1. Where this came from, and the one idea

It came from an accident. A word processor kept its cut lines in a buffer that was
cleared at startup and nowhere else — so cutting from one document and then
opening another left the lines still on the clipboard, and they could be pasted
into the new document. Nobody planned that, and it turned out to be the only way
to move text between two files.

The obvious generalisation is to make it survive a change of *program* as well as
a change of document. And the moment you try, you discover that the obvious
mechanism does not exist:

> **ProDOS 8 has no memory that survives a program launch, and the memory that
> looks as though it might, does not.**
>
> A `.SYS` file loads at `$2000` and runs as far up as it needs. The word
> processor keeps its clipboard at `$8600`; the database keeps a scrolling row
> cache at `$8000` and an overlay band from `$8000` to `$AFFF`. There is no region
> above `$2000` that two such programs both leave alone. Auxiliary memory is worse
> rather than better: it survives, but the two programs divide it up differently —
> 88-byte records in one, 512-byte blocks in the other, both filling from the
> bottom of bank 0 — so there is no address in it that is reliably nobody's. And
> on a stock 128K machine there is only bank 0, so there is nowhere to hide.

So the channel is **a file**, and the whole of the design follows from that. The
file is written without being asked and read without being asked, so the operator
never sees it and experiences it as a clipboard that follows them from program to
program.

**The one idea in the format itself:**

> **A clip is a table.** Rows and columns, the columns typed and named. Everything
> any of these programs cuts is a degenerate case of one:
>
> - a block of text — *N* rows × 1 column
> - a set of database records — *N* rows × *M* typed columns
> - one field — 1 × 1
> - a line of a report — 1 row × *M* columns
>
> One format therefore serves all of them, and each program reads it **at whatever
> fidelity it can use**: a word processor takes a table as lines with tabs between
> the columns, a database takes lines as one-column records, and a database
> pasting into a database matches columns to fields by name.

---

## 2. The payload is text, always

Row data is **text in display form**, never binary. Not the packed decimal cell,
not the four-byte date, not a length-prefixed record image.

Five reasons, and the fifth is the one that will matter most in practice:

1. Every program can paste it somewhere useful without knowing how the *source*
   stored it.
2. A word processor pasting a table gets exactly the characters it should show.
3. A database pasting text into a field just parses it — which it already does for
   every keystroke the operator types.
4. No storage convention leaks between programs. A sign byte, a nines-complement,
   a big-endian date and an implied decimal point are one program's private
   business, and a format that carried them would make every program that reads it
   a partial reimplementation of the one that wrote it.
5. **A clip file can be read in a text viewer.** When the feature misbehaves, the
   evidence is legible. A binary interchange format is a feature you debug by
   dumping hex and guessing.

### 2.1 One canonical spelling per type

| Type | In row data | Notes |
|---|---|---|
| text, ALPHA, ALNUM | the characters | trailing spaces trimmed |
| NUM | digits, no leading zeros, no separators | `1234`, not `0001234` and not `1,234` |
| DECIMAL | digits, one `.`, optional leading `-` | `1234.56`, `-0.07`, `0` |
| DATE | `YYYY-MM-DD` | unambiguous, sortable, readable. An empty date is an empty column |
| BOOL | `Y` or `N` | |
| empty | nothing between the separators | which is how an empty column and a column of spaces come out the same, and they should |

**No thousands separators, no currency signs, no `CR`/`DB`, no per-file date
style.** Those are display decisions belonging to whichever program is showing the
data, and a clip is not a display. A program pasting a `DECIMAL` applies its own
picture on the way in.

### 2.2 Columns are separated by TAB, rows by their length byte

Each row is a length byte followed by its text, with `$09` between columns. A row
with *M* columns therefore has *M−1* tabs, and an empty trailing column is a tab
with nothing after it.

TAB rather than comma because a comma occurs in ordinary text and in money, and
quoting rules are how a simple interchange format becomes a parser. A tab does not
occur in any of these programs' field data: a word processor's own TAB key advances
the cursor and stores spaces, and no field editor here stores a `$09`.

---

## 3. The file

### 3.1 Header — 32 bytes

The same shape as the other formats in this family — signature, version, counts,
offsets, `poolend`, a twelve-byte identity block at offset 20 — because formats
read by the same kind of code should not be laid out differently.

| Off | Len | Field | Meaning |
|---|---|---|---|
| 0 | 4 | signature | `"CLP1"` — `$43 $4C $50 $31` |
| 4 | 1 | version | 1 |
| 5 | 1 | kind | `0` text lines · `1` a table · `2` a single value |
| 6 | 2 | rowcount | rows in the clip |
| 8 | 1 | colcount | columns. 1 when `kind` is 0 or 2 |
| 9 | 1 | flags | bit 0: the column block is present |
| 10 | 2 | coloff | offset to the column descriptors, 0 = none |
| 12 | 2 | rowoff | offset to the row data |
| 14 | 2 | bytecount | bytes of row data |
| 16 | 2 | checksum | over the row data (§3.4) |
| 18 | 2 | poolend | offset to end of file — the file's own length |
| 20 | 4 | origin | which program wrote it (§3.3) |
| 24 | 2 | date | the ProDOS date word, as written |
| 26 | 2 | time | the ProDOS time word |
| 28 | 4 | — | reserved, zero |

`kind` is a **courtesy, not a contract**. A reader that only wants lines reads
`kind` 1 as lines with tabs in them and is right to. The distinction that matters
is `colcount`, and `kind` 2 exists only so that a program pasting into a single
field can tell "somebody copied one value" from "somebody copied a one-record
table" and skip a prompt.

### 3.2 Column descriptors — 16 bytes each

`colcount` of them at `coloff`, present when flags bit 0 is set. Absent for a
plain text clip, and a reader must cope with their absence rather than requiring
them.

| Off | Len | Field |
|---|---|---|
| 0 | 10 | name, upper case, space-padded |
| 10 | 1 | type — `0` ALPHA `1` ALNUM `2` NUM `3` BOOL `4` DECIMAL `5` DATE `6` TEXT |
| 11 | 1 | width, as the source displayed it |
| 12 | 1 | decimals |
| 13 | 1 | flags — bit 0 the source considered this a key |
| 14 | 2 | reserved, zero |

**The type codes are the same numbers the database uses for a field type**, with
`6 TEXT` added for a column that is simply characters. That is not a coincidence
to be tidied away later: it means a database can validate a pasted column against
the field it is going into with a byte comparison, and it means the clipboard
never needs a translation table.

**The names are what make a paste intelligent.** A database pasting into a
database matches columns to fields **by name**, exactly as a restructure matches
old fields to new — same rule, same routine, same ten-byte upper-case space-padded
comparison. A column with no matching field is offered to the operator, not
guessed at.

### 3.3 `origin`

Four characters naming the program that wrote the clip. `"WRTR"`, `"DBSY"`,
`"EDIT"`, and anything else a future program wants; a reader that does not
recognise a tag treats the clip as an ordinary clip.

**It is not there for compatibility switching** — the format is the format, and a
reader that behaves differently depending on who wrote a clip is a reader that
will be wrong about a clip written by somebody new. It is there for the operator:

> `Clipboard: 12 rows, 4 columns, from the database, 8/18/2026.  Paste? `

That single line is what makes a cross-program clipboard trustworthy instead of
alarming. An invisible clipboard that has followed the operator between two
programs is a thing they will not paste from unless they are told what is on it,
and **reading the header alone is one block read**, so the cost of telling them is
nothing.

### 3.4 The checksum

A running sum over the row data, rotated left one bit between bytes. It covers the
row data only, not the header and not the descriptors.

Two jobs: a truncated write — a disk that filled up halfway through a clip — is
caught rather than pasted, and a file that is not a clip but happens to start with
the right four bytes is rejected. A reader that finds a bad checksum says
*Clipboard is damaged* and treats the clipboard as empty. It does not paste part
of it.

### 3.5 The caps

| | Cap | Why |
|---|---|---|
| row data | 8,192 bytes | sixteen blocks; one read per block and no program needs a buffer |
| rows | 1,000 | |
| columns | 30 | a database record cannot have more fields than this |
| one row | 512 bytes | a length byte counts to 255, so a row longer than 255 is split across two length-prefixed segments with the continuation flag — **see the note below** |

> **The row length byte is one byte and a row can be longer than 255.** A
> paragraph in a word processor routinely is. A row whose length byte is `$FF` is
> **continued** in the row that follows it, and a reader concatenates until it
> meets a length under `$FF`. That is one comparison in the reader and it avoids a
> two-byte length on every row of every clip for the sake of the rare long one.
> A row of exactly 255 bytes is therefore written as `$FF` + 255 bytes + `$00`,
> and the empty continuation is what says it ended.

**A reader takes what it can hold and says what it left.** A word processor with
room for sixty-four lines, handed a clip of two hundred rows, pastes sixty-four
and says *64 of 200 rows pasted*. It does not truncate silently and it does not
refuse the whole thing.

### 3.6 Where the file lives

`CLIPBOARD`, type `$54`, in the **root of the boot volume** — found through the
boot device rather than through the current prefix, because a prefix changes and a
clip copied while pointed at one disk must still be found from another.

Two consequences to handle rather than hope about:

- **A write-protected boot disk.** The write fails, and the program says so
  **once** — *Clipboard cannot be saved: disk is write-protected* — and carries on
  with an in-memory clipboard only. It does not ask again every time.
- **A settable location.** Every implementing program has one Utilities entry,
  *Clipboard volume*, so the operator with a protected system disk can point it
  at a data disk. The setting shows its current value on the menu line, like every
  other setting that holds a value rather than doing something.

---

## 4. The two tiers, and why each program gets to choose differently

There are only two: **memory within a program**, and **the file between them.**

There is deliberately **no third tier in auxiliary memory**, and it is worth
writing down why, because it is the first idea anybody has and it looks free.
Every implementing program would have to reserve an extent that none of the others
ever touches — forever, in a memory where nobody has room to spare — plus a
signature and a checksum to tell a live clip from whatever the last program left
behind, plus a fall-back to the file for when the test fails. All of that to avoid
one disk write when a program exits and one block read when the operator pastes.
It is several hundred bytes and a permanent constraint in three programs, buying
under a second. The file is enough.

### The rule

- **Cut and copy write the clip to memory if the program keeps one, and mark it
  dirty.**
- **The file is written when the program is about to leave the machine**, if the
  clip is dirty — the same discipline as flushing a dirty disk buffer, and for the
  same reason: the cost is paid once, at a moment the operator is already waiting.
- **Paste uses the in-memory clip if there is one. If there is not, it reads the
  file.** So the first paste after a program change picks up what the last program
  left, and every paste after that is free.
- **A clip is streamed, never buffered whole.** Row data is at most 8K and a
  program has nowhere to put 8K; so a paste reads a block, parses the rows in it,
  and consumes them. A row straddling a block boundary needs no special case — the
  row under construction simply continues into the next block, which is the same
  argument every streaming reader in this family already makes.

### What each program does with that

| | keeps a clip in memory | writes the file |
|---|---|---|
| a word processor | **yes** — it already commits 5.6K of main memory to sixty-four lines, and cut and copy are constant | at Quit, if dirty |
| a database | **no** — copying records is rare, and there is no main memory to spare | on every cut and copy |
| a source editor | **yes**, for the same reason as the word processor | at Quit, if dirty |

**A program with no in-memory tier is not a degraded implementation.** It reads
and writes the same file, and the only difference the operator can detect is that
its own copy-and-paste costs a disk access. Saying which programs cache and which
do not is part of the specification precisely so that neither is mistaken for a
bug.

---

## 5. What a paste actually does

The matrix, stated once so that no implementation has to invent an entry.

| From | Into | Result |
|---|---|---|
| text lines | a document | the lines, inserted. What already worked |
| text lines | one field | the **first** row, parsed and validated. `kind` 2 skips the "which row" question |
| text lines | a record list | each row becomes a record, into a field the operator names once |
| a table | a document | one line a row, tabs between columns. Or aligned to the column widths, which is a setting |
| a table | records, matching definition | columns to fields **by name**; anything unmatched is named to the operator |
| a table | records, different definition | the same, and a column whose type will not convert into its matched field is **refused** rather than converted badly |
| a table | one field | the first column of the first row |
| one value | anywhere | 1 × 1, and it fits everywhere |

Three rules that apply to every row of that table:

1. **Nothing is written until everything validates.** A paste of forty records
   that fails on the thirty-first must leave nothing behind, or the operator has to
   work out which thirty went in.
2. **A conversion that loses information is named before it runs**, not after. A
   narrowed column truncates, a `DECIMAL` into a `NUM` drops the decimals, an
   unparseable date becomes empty — and the operator confirms the list.
3. **A paste that cannot be done at all says which column and why.** *Column
   BALANCE will not fit field QTY* is a sentence somebody can act on. *Paste
   failed* is not.

---

## 6. Opening another program's files directly

A separate question from the clipboard, asked at the same time, and the answer is
deliberately narrower.

**We do know the exact layout of each others' files, and that is not sufficient
reason to read them.** Every direct reader is a copy of another program's format
specification living inside a program that has to be able to ship, be documented
and be revised on its own. Two copies of a spec in two products is two places to
keep in sync, and the failure when they drift is a file read at the wrong offsets
— which does not announce itself, it produces plausible rubbish.

So the rule is:

> **Plain text and the clipboard are the interchange. A direct reader of another
> program's format is justified only where it costs almost nothing and cannot
> drift.**

Three cases qualify, and they are the only three:

### 6.1 An older version of a program's own format

A database that reads version 1 of its own definition file reads a definition
written by anything that wrote version 1 — which is not interoperability code at
all, it is backward compatibility, and it is justified on its own terms. Roughly
thirty bytes.

**And the other direction, which is the case people forget: save down when it
fits.** A definition that uses no version 2 feature — no `DECIMAL`, no `DATE`, no
more fields than version 1 allowed, one screen page, no keys — is **written as
version 1**, so it stays readable by everything that reads version 1. A format
that only ever writes its newest version strands every older reader on the first
day it ships.

### 6.2 Plain text, in both directions

One program's native document form is one paragraph to a line of `TXT`. Another's
export is one record to a line of `TXT`. **These are the same file.** So an export
opens as a document and a document imports as records, with no code on either side
beyond what each program already has.

This is the case that makes the whole question mostly go away, and it was free
before anybody thought about it.

### 6.3 A data file as a read-only table — *optional, and here is what it costs*

A word processor could open a database's data file and show it as a table, if the
definition file is beside it: read the header and the descriptors, then render each
record as a row of formatted columns. It is a genuinely nice thing to be able to
do — write a document with the data in front of you.

**It costs about 650 bytes** in the word processor, read-only, and it puts a copy
of the definition format inside a program that otherwise knows nothing about it.
That is the coupling §6 is about, and the honest position is:

- It is **not** in version 1 of anything.
- If it is ever built, it is built as an **import through the clipboard format** —
  the word processor asks the operator to have the database write a clip, or it
  reads a `.TXT` export — before it is built as a direct reader.
- If it is built as a direct reader anyway, the definition reader is **one routine
  in one file**, so that when the format gains a version there is one place to fix
  and it is obvious where.

---

## 7. What is not in version 1

- **No pictures, no styles, no attributes.** A clip is characters. Bold text
  pasted from a word processor that has bold arrives as text.
- **No append.** A copy replaces the clipboard. A multi-clip clipboard is a
  different feature with a different interface and it should not be smuggled in as
  a flag.
- **No cut across programs.** The clipboard is a copy; deleting the source is the
  source program's business and happens before the clip is written.
- **No clipboard history and no named clipboards.** One file, one clip. A second
  clip is a saved export with a name the operator chose, which is a better answer
  to that need anyway.
- **No locking.** One machine, one operator, one program at a time. A clip written
  by a program that is no longer running is exactly the case this exists for.

---

## 8. What each program has to do, and what it costs

| | Change | Cost |
|---|---|---|
| a word processor | keep the accidental survival, and make it deliberate: the clip is dirty from cut/copy, written at Quit; a paste with an empty in-memory clip reads the file; the paste prompt reports the header | ~500 bytes and one Utilities entry |
| a database | the clipboard is the file: cut and copy write it, paste streams it, columns match fields by name | ~700 bytes |
| a source editor | its clipboard is **not yet written at all**, so it can be built to this specification from the start rather than retrofitted — which is the one piece of luck in this whole design | it was going to cost this anyway |

The word processor's change is the smallest and the most important, because **the
accident is already the feature**. What it is missing is only the part that
crosses a program boundary, and one file write at Quit is the whole of it.
