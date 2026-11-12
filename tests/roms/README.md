# Test ROMs

CP/M programs from the Intel 8080 CPU test suite, used by `tests/CpmRomTest.elm`.
The `.COM` files are loaded at 0x0100 by a small CP/M shim (`CALL 5` = BDOS, `JMP 0` = exit).

| File | What it tests | Source |
| --- | --- | --- |
| `TST8080.COM` (+ `TST8080.ASM`) | Microcosm Associates 8080/8085 CPU diagnostic, version 1.0 | <https://github.com/superzazu/8080/tree/master/cpu_tests> (copied from <http://altairclone.com/downloads/cpu_tests/>) |
| `8080PRE.COM` | Preliminary 8080 tests, modified by Ian Bartholomew from Frank Cringle's Z80 test | <https://github.com/superzazu/8080/tree/master/cpu_tests> |

Both are distributed through the MIT-licensed `superzazu/8080` project, which runs them as its test suite.
The ROM files themselves are historical public-domain test programs; please check before redistributing them elsewhere.

Expected results (from the reference runner in `superzazu/8080`):

* `TST8080.COM`: prints `CPU IS OPERATIONAL`, 651 instructions
* `8080PRE.COM`: prints `8080 Preliminary tests complete`, 1061 instructions

The larger `CPUTEST.COM` and `8080EXM.COM` (the CRC based instruction exerciser) are not included yet: they execute tens of millions of instructions, which is too slow for `elm-test`.
