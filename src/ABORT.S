* ABORT.S  the runtime error stop
* LIBRARY MODULE - slots 103-104, vectors ABSET and
* ABORT.
* Subscript out of range, divide by zero, a file
* error nothing can recover from.  Says what
* happened, waits, and puts the machine back where
* it was - which is the difference between a system
* you can develop on and one you reboot.
*
* WHY THIS IS TWO ROUTINES AND NOT ONE
* A fault is raised deep inside something.  By the
* time DIVIDE finds a zero divisor there are return
* addresses on the 6502 stack leading back into an
* arithmetic statement that is being abandoned, and
* there is no sensible way to walk back out of it
* one RTS at a time.  So we do not walk out: we
* write the stack pointer down BEFORE the program
* starts, and a fault restores it.
*
*   JSR ABSET     mark the recovery point
*   BCS FAULTED   ABSET returns C=0.  A fault comes
*                 back to this same instruction
*                 with C=1
*   ...the program...
*
* That is setjmp and longjmp, and on a processor
* with a 256-byte stack it costs six bytes of
* storage.  VMDIE does the same thing by hand for
* the interpreter; this is the version anything can
* use, and a compiled program's ENTER prologue is
* the natural caller.
*
* ABCODE keeps the number after the jump, because
* the carry says only that something failed and a
* program that wants to say which needs somewhere
* to read it from.
*
* ABSET's saved return address is COPIED, not left
* on the stack.  The two bytes JSR pushed are still
* at that address when the fault comes, but they
* have been written over a hundred times by then -
* everything the program did used that region.

* ---- the codes ----
* Nine, and the numbering is not going to change:
* an object compiled a year ago may still call
* ABORT with a 5 in it, and 5 has to keep meaning
* what it meant.  Append, the way the jump table
* does.
*   0  unknown - what an out-of-range code becomes
*   1  subscript out of range
*   2  divide by zero
*   3  numeric overflow
*   4  value was never set - the UNINITIALISED bit
*      in a NUM8 flag byte, which is the whole
*      reason that bit exists
*   5  file error - one RECMAN could not recover
*   6  out of memory
*   7  bad screen layout - a .DCT that will not
*      parse
*   8  PERFORM nested too deep
ABNMSG EQU 9

* ---- ABSET: mark the recovery point ----
ABMARK TSX
 STX ABSP
 LDA $0101,X
 STA ABRET
 LDA $0102,X
 STA ABRET+1
 CLC
 RTS

* ---- ABORT: A = code.  Does not return here ----
ABFAIL STA ABCODE
 CMP #ABNMSG
 BCC ABF1
 LDA #0
 STA ABCODE
ABF1 JSR TDBELL
 JSR CNCR
 LDA #<ABMHDR
 STA STRPTR
 LDA #>ABMHDR
 STA STRPTR+1
 JSR CNPUTS
 LDA ABCODE
 ASL
 TAX
 LDA ABTAB,X
 STA STRPTR
 LDA ABTAB+1,X
 STA STRPTR+1
 JSR CNPUTS
 JSR CNCR
 LDA #<ABMKEY
 STA STRPTR
 LDA #>ABMKEY
 STA STRPTR+1
 JSR CNPUTS
 JSR TDWAITK
 JSR CNCR
* Back to the mark.  ABSET was ENTERED with the
* pointer at ABSP and RETURNED with it two higher,
* because its own RTS popped the address JSR had
* pushed - so the level to restore is ABSP+2, not
* ABSP.  Get that wrong and every fault leaks two
* bytes of stack, which on a processor with 256 of
* them is a program that dies on the hundred and
* twenty-eighth recovered error and nowhere near
* the code that caused it.
 LDX ABSP
 INX
 INX
 TXS
* Then put the return address back where ABSET's
* JSR left it - the bytes themselves are long gone,
* written over by everything the program did - and
* RTS through it.
 LDA ABRET+1
 PHA
 LDA ABRET
 PHA
 SEC
 RTS

* ---- the messages ----
* A table of pointers, not a table of fixed-width
* strings: nine messages of thirty characters would
* be 270 bytes and half of them padding.
ABTAB DA ABM0,ABM1,ABM2,ABM3,ABM4
 DA ABM5,ABM6,ABM7,ABM8

ABMHDR DFB 12
 ASC 'Run stopped:'
ABMKEY DFB 22
 ASC 'Press any key to go on'
ABM0 DFB 14
 ASC ' unknown fault'
ABM1 DFB 23
 ASC ' subscript out of range'
ABM2 DFB 15
 ASC ' divide by zero'
ABM3 DFB 17
 ASC ' numeric overflow'
ABM4 DFB 20
 ASC ' value was never set'
ABM5 DFB 11
 ASC ' file error'
ABM6 DFB 14
 ASC ' out of memory'
ABM7 DFB 18
 ASC ' bad screen layout'
ABM8 DFB 24
 ASC ' PERFORM nested too deep'

* ---- variables ----
ABSP DFB 0
ABRET DS 2
