* UTIL.S  the Utilities overlay
* A STUB, the same shape as FORMAT and REPORT: it
* sets the origin and the output file and PUTs the
* body, UTILD.S, which says why Utilities is an
* overlay now (2026-11-11).
*
* It loads at UTLBASE, $A000, and must end below
* $B000, where the file buffers are.  check.js tests
* that; read it after every assembly as well.
*
* Save the object as UTILITIES, type BIN.  NOT
* UTIL: the system disk has a directory of that
* name already, Merlin's own utilities.
 ORG $A000
 DSK /COBOL/OBJ/UTILITIES
 XC
 PUT EQUATES
 PUT EQUATES2
 PUT UTILD
