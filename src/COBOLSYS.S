* COBOLSYS.S  the COBOL.SYSTEM dispatcher.
* ProDOS loads it at $2000 and it STAYS at $2000
* for as long as you are in the menu.  There is no
* relocation and no two-phase boot: with no
* graphics anywhere in this system, low memory is
* ours, and the shared runtime lives in COBOL.LIB
* at $3000 rather than inside this program.
*
* STARTUP ORDER IS LOAD-BEARING.
* Everything before INIT80 talks to the screen
* through the monitor at 40 columns, because that
* is all that exists before the driver does.
* Everything after it goes through the library.
* There is no middle ground - once the driver is
* running, 80STORE is off and COUT writes into
* every other column.
*
* COBOL.LIB loads at $3000 and stays for the life
* of the session.  Overlays load at $8000, are
* entered with JSR, and RTS back into this program,
* which is still sitting at $2000 - so a menu
* choice is a subroutine call, and nothing has to
* be reloaded when the overlay returns.
* Every address here comes from EQUATES (LIBBASE,
* OVLBASE, OVLMAX): this file names no memory of
* its own, so the map can move without editing it.
*
* We do not set the date and time.  Without a
* clock ProDOS stamps new files with no date,
* which is what an unclocked IIe always did.
*
* Save the object as COBOL.SYSTEM, type SYS ($FF).

 ORG $2000
* the object goes straight to disk as it assembles,
* which also keeps it out of memory - BUILD.md 3.
* If your Merlin rejects the pathname, use the bare
* name and copy from SRC to OBJ afterwards.
 DSK /COBOL/OBJ/COBOL.SYSTEM
* XC turns on the 65C02 opcodes.  SYSBOOT already
* REFUSES to boot without a 65C02 - CHK65 - so the
* machine is guaranteed to have one, and until now
* we were paying that compatibility cost and taking
* none of the benefit.  STZ is the one that earns
* its keep: LDA #0 followed by a run of STA becomes
* a run of STZ, two bytes shorter every time.
 XC
 PUT EQUATES
 PUT EQUATES2

* ================= THE SHELL, IN PIECES ==========
* COBOL.SYSTEM is a STUB.  Its three parts are PUT
* below in the original order, so the bytes are
* identical to the former single file.  ProDOS
* enters a SYS file at $2000.
*
* $2000 IS A JMP since 2026-11-08, because $2003 is
* the TURNKEY NAME: empty on the system disk, and on
* a turnkey disk the program to run, which the
* Utilities copier writes there as it copies this
* file (UTURN, SYSUTIL.S).  Length, then up to
* fifteen characters - a ProDOS name.  ITS OFFSET IN
* THE FILE IS FIXED AT 3: do not put anything
* between the ORG and this.
 JMP COLD
TKNAME DFB 0
 DS 15
* $2013: the entries the UTIL overlay calls, at
* addresses it knows from EQUATES2 (XTOSYS, XTOWRK)
* because it is assembled apart from this file.
* FIXED, like TKNAME: add on the end.
 JMP TOSYS
 JMP TOWRK
 PUT SYSBOOT
 PUT SYSLOAD
 PUT SYSMENU
 PUT SYSUTIL
