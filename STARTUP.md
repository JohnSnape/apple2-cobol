# The startup document — being launched with a file to open

**This file is a shared specification.** An identical copy belongs in the tree of
every program that implements it. Like `CLIPBOARD.md`, it is written as a
published convention rather than as a private arrangement — the mechanism is not
ours, it is ProDOS 8's, and we are implementing it rather than inventing it.

---

## 1. What it is

A ProDOS 8 `.SYS` file is loaded at `$2000` and jumped to. There is a
long-established convention by which whoever does that launching can also hand
the program **a document to open**:

```
 $2000   4C xx xx    JMP to the real entry point
 $2003   EE          signature
 $2004   EE          signature
 $2005   nn          THE SIZE OF THE BUFFER AT $2006, INCLUDING the
                     length byte.  65 - not 64
 $2006   ll          length byte of the pathname
 $2007+              the pathname itself, ll characters
```

The launcher — a selector such as ProSel-8 or Bird's Better Bye, the ProDOS 8
quit-code dispatcher, or the IIGS Finder launching a P8 application — loads the
`.SYS` file, **then** looks at `$2003`. If it finds `$EE $EE` it copies the
document's full pathname into `$2006` before jumping to `$2000`. The program
reads its own `$2006` at startup: a non-zero length byte means *open this*.

`BASIC.SYSTEM` is the canonical implementer, and that is why double-clicking an
Applesoft `BAS` file gets you ProDOS 8, `BASIC.SYSTEM`, and that program `RUN`
rather than `STARTUP`.

### Verified against BASIC.SYSTEM, 2026-08-18

This is not from memory. The first sixteen bytes of a real `BASIC.SYSTEM`:

```
4c 47 20 ee ee 41 07 53 54 41 52 54 55 50 00 00     LG .. A . S T A R T U P
```

- `4C 47 20` — `JMP $2047`
- `EE EE` — the signature, exactly where expected
- **`41` — 65, and it is the buffer size *including* the length byte**
- `07` then `STARTUP` — a length byte and seven characters

**Two independent facts fix the meaning of `$2005`, and they agree.** A ProDOS
pathname cannot exceed 64 characters, so 65 can only be 64 + the length byte. And
the `JMP` target is `$2047`, which is exactly `$2006 + 65` — BASIC.SYSTEM's entry
point sits immediately after its buffer. Either alone would be suggestive; together
they are conclusive.

**The off-by-one here is not cosmetic.** A program declaring 64 tells the launcher
it can hold 64 bytes *including* the length, so a launcher that respects the
declaration would refuse or truncate a full-length 64-character pathname — and a
truncated pathname is a pathname to a different file. Declare 65.

### And a second thing the dump shows: the buffer has a default in it

`BASIC.SYSTEM` does not ship with an empty buffer. It ships with `STARTUP` already
in it, and **that is how it runs `STARTUP` when nobody hands it a document** — the
launcher simply overwrites the default when there is one.

So the field is better understood as *the startup file pathname*, not *the document
to open, if any*. Reading a zero length as "no document" is a legitimate use of the
same mechanism and is what all three of our programs do — but it is our choice, not
the convention's requirement. Any of them could ship a default the same way.

**The order matters and is the whole trick**: the launcher writes into memory
*after* loading the file, so the buffer must be **part of the program image** —
reserved space inside the `.SYS` file at a fixed offset. It cannot be a variable
somewhere convenient.

---

## 2. What each program declares

Sixty-seven bytes at the top of the file, and nothing else:

```
 ORG $2000
 PUT EQUATES        no bytes - it is all EQU - so the JMP still lands at $2000
 JMP <entry>
 DFB $EE,$EE
 DFB SDBUFSZ        65 - the length byte AND the characters
SDPATH DS SDBUFSZ
```

**Two names, so that neither use is a "+1 somewhere":**

```
SDMAX   EQU 64          the longest pathname - what the length check compares
SDBUFSZ EQU SDMAX+1     the buffer size - what goes at $2005 and what DS reserves
```

`SDMAX` is 64 because a ProDOS pathname cannot exceed 64 characters: more would be
room that cannot be used, less would be a legal pathname we could not accept.
`SDBUFSZ` is 65 because `$2005` counts the length byte, which is what
`BASIC.SYSTEM` declares and what its own entry address confirms.

**The buffer is `DS`, so it is zeros in the file on disk.** A program launched
*without* a document — from a menu, or by being the boot `.SYSTEM` file — reads a
length byte of zero and goes to its own opening screen. That is the normal case
and it needs no test of its own.

---

## 3. What a program does with it

Four rules, in order, and each exists because the alternative fails quietly:

1. **Check the length before anything else.** Zero means no document. A length
   greater than `SDMAX` means the launcher wrote more than we said we could hold,
   and the answer is to **refuse and say so**, not to truncate — a truncated
   pathname is a pathname to a different file, or to nothing, and either way the
   error message will be about the wrong thing.

2. **Ask the file what it is; do not trust the suffix.** `GET_FILE_INFO` gives
   the type byte and the aux field, and those are the truth. Dispatch on them.

3. **A type we do not handle is not an error to hide.** Say what the file is and
   go to the opening screen. *That is a REPORT file — open it from the menu* is
   a sentence somebody can act on; a program that silently ignores the document it
   was double-clicked with looks broken.

4. **Consume it once.** Clear the length byte after acting on it, so that nothing
   later in the session re-opens the document behind the operator's back.

---

## 4. Which program claims which type

The type block is `FILETYPES.md` in each tree. What matters here is that **no
type is claimed by two programs**, because the association is what a launcher
dispatches on.

| Type | Owner | Double-clicking it means |
|---|---|---|
| `$04` TXT, aux `$0000` | the word processor | open that document |
| `$04` TXT, aux ≠ 0 | the database | a data file — §5 |
| `$50` DBF | the database | open that definition |
| `$51` DBQ | the database | run that query |
| `$52` DBR | the database | print through that report |
| `$54` CLP | **nobody** | a clipboard is pasted, never opened. Every program refuses it by name |
| `$55` SSH *(proposed)* | the spreadsheet | open that sheet |
| `$56` SSF *(proposed, reserved)* | the spreadsheet | a sheet template or format |

**`$04` is claimed twice and that is deliberate**, because the aux field
separates the two: our convention has always been that a data file is an ordinary
`TXT` with its record length in aux, and aux `$0000` means sequential. So a
launcher that dispatches on type alone will get it wrong, and one that reads the
aux field will get it right. Programs must therefore check the aux field
themselves rather than assuming the launcher did — which is rule 2 again, from a
different direction.

`$54 CLP` being claimed by nobody is worth stating rather than leaving implied.
The clipboard is a channel, not a document; a program handed one should say so.

**The spreadsheet's two are a proposal, not a decision.** `$47-$4D` and
`$50-$54` are already allocated and contiguous, so `$55-$56` is the obvious
continuation and costs nothing to reserve now. It is written here so that the
spreadsheet has something to agree or disagree with rather than a blank, and
the tree that owns those types is the one that confirms them.

---

## 5. The database's complication, and it is a real one

Every other program in the suite opens **one file** and is finished. A database
does not: a definition and its data are two files, and neither is usable without
the other.

That makes "what does double-clicking a database file open?" a question the
launch convention cannot answer on its own, and it is **not** a question this
document settles. It is settled in `DICTIONARY.md` and `STORAGE.md`, by whatever
rule pairs a definition with its data. Until that rule is fixed, the database
implements the mechanism and handles the definition case; the data-file case
depends on the pairing.

The three candidate rules and what each does to a double-click:

- **Same name, different directories** (the current convention, because ProDOS
  will not hold two files of one name in a directory whatever their types). A
  double-clicked data file cannot find its definition without guessing at a
  sibling directory, so only the *definition* is usefully double-clickable.
- **Same directory, the definition naming its data file.** Both are
  double-clickable; the cost is a field in the header and a naming rule to
  explain.
- **One file, the definition living inside the data file.** There is nothing to
  pair, nothing to double-click but the one thing, and the fingerprint check
  becomes unnecessary because a definition cannot be separated from its data.

---

## 6. Launching a sibling program with a document

The natural companion, and it is a *different* mechanism — worth saying, because
they get conflated.

The `$EE $EE` header lets a program **be launched with** a document. It does not
let a program **launch** one: the launcher does the loading, and a program cannot
load a `.SYS` file to `$2000` while it is itself running there.

Doing it properly means being a small selector: copy a loader stub somewhere safe
— `$0300` is taken, but the ProDOS file buffers and `$BD00-$BEFF` are not —
`CLOSE` everything, `BLOAD` the target to `$2000`, write the pathname into its
`$2006`, and jump. About 250 bytes, and identical in all three programs.

**It is not in version 1 of anything**, and the reason is that the payoff is
smaller than it looks: the clipboard already moves *data* between the three
programs without leaving either of them, and that is what an operator actually
wants most of the time. Handing off the whole machine is the rarer case. When it
is built it goes in this document, as one shared routine.

---

## 7. What each program has to do

| | Change | Cost |
|---|---|---|
| word processor | the header; at startup, a non-zero length means open that document instead of showing an empty one. Its Open path already exists | ~70 bytes + ~40 |
| database | the header; the dispatch table in §4; §5 decides the data-file case | ~70 bytes + ~150 |
| spreadsheet | the header, **from the first assembly** — it is 67 bytes and retrofitting a fixed offset into a program that has grown around `$2003` is the kind of change that moves everything | ~70 bytes + ~40 |

The spreadsheet gets the best deal here for the same reason the source editor got
the best deal on the clipboard: it has not been written yet, so the convention
costs it nothing but the decision to follow it.
