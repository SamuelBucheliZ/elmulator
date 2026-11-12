# Elm-ulator [![CI](https://github.com/SamuelBucheliZ/elmulator/actions/workflows/ci.yml/badge.svg)](https://github.com/SamuelBucheliZ/elmulator/actions/workflows/ci.yml)

_by [Samuel Bucheli](https://github.com/SamuelBucheliZ), [Stefan Friedli](https://github.com/sfriedli) and [Lukas Akermann](https://github.com/lakermann), October 2019_

An Intel 8080 emulator written in Elm 0.19.1.

* Running version (published from this repository's `main` branch by the CI deploy job): <https://samuelbucheliz.github.io/elmulator>
* Forked from [lakermann/elmulator](https://github.com/lakermann/elmulator), whose version is published at <https://lakermann.github.io/elmulator>

## Requirements

* Node.js 24 (the version is pinned in [`.nvmrc`](./.nvmrc); with [nvm](https://github.com/nvm-sh/nvm) run `nvm use`)

Elm itself is installed through npm (`elm@0.19.1-6`), so no separate Elm installation is needed.

## Developer Onboarding

1. Install Node.js 24 (or `nvm install && nvm use` in the project folder).
2. Run `npm ci` to install the exact dependency versions from `package-lock.json`.
3. Optional: install the [Elm language extension](https://marketplace.visualstudio.com/items?itemName=elmtooling.elm-ls-vscode) for your editor and point it at the bundled tools:

    ```json
    "elm.compiler": "./node_modules/.bin/elm",
    "elm.formatCommand": "./node_modules/.bin/elm-format",
    "[elm]": {
        "editor.formatOnSave": true
    }
    ```

## Scripts

| Command | What it does |
| --- | --- |
| `npm test` | Run the Elm test suite (`elm-test`), including the quick CPU test ROMs |
| `npm run test:slow` | Run the long CPU test ROMs `CPUTEST.COM` and `8080EXM.COM` (takes many minutes) |
| `npm run gen:roms` | Regenerate `tests/RomData.elm` after changing the ROM files in `tests/roms` |
| `npm run test:watch` | Re-run the tests on every change |
| `npm run format` / `npm run format:check` | Format the Elm sources with `elm-format` / verify they are formatted |
| `npm run analyse` | Static analysis with `elm-analyse` |
| `npm run build:dev` | Compile to `src/js/elmulator.js` |
| `npm run build:prod` | Compile an optimised build to `src/js/elmulator.js` |
| `npm run run:watch` | Dev server with live reload (`elm-live`) |

## Controls

| Button | Key | What it does |
| --- | --- | --- |
| (l)oad rom | `l` | Pick a ROM file and start it |
| (p)ause / (p)lay | `p` | Stop or continue the emulation |
| (r)eset | `r` | Start the loaded program again (speed and the start setting are kept) |
| start paused | | When ticked, a loaded ROM starts paused |
| (n)ext step | `n` | Run one instruction and pause |
| (e)xecute steps | `e` | Run the number of instructions in the box and pause |
| (i)nterrupt | `i` | Force an RST 2 interrupt now, even if the CPU has interrupts disabled |
| 0.25x ... 4x | | Speed relative to the 2 MHz clock of a real 8080 |

Game buttons (Space Invaders; hold a key while the button is pressed):

| Button | Key |
| --- | --- |
| left | `a` |
| right | `d` |
| fire | `s` |
| coin | `c` (insert a coin before starting) |
| 1P start | `1` |
| 2P start | `2` |

Keys typed into the step box are not treated as shortcuts.

## Test ROMs

The emulator runs the Intel 8080 CPU test programs from `tests/roms/` (provenance in its README)
through a small CP/M shim (`tests/CpmShim.elm`). The results match the reference runner exactly, including
instruction and cycle counts:

| ROM | Checked by | Result |
| --- | --- | --- |
| `TST8080.COM` | `npm test` | `CPU IS OPERATIONAL`, 651 instructions, 4924 cycles |
| `8080PRE.COM` | `npm test` | preliminary tests complete, 1061 instructions, 7817 cycles |
| `CPUTEST.COM` | `npm run test:slow` | `CPU TESTS OK`, 33971311 instructions, 255653383 cycles |
| `8080EXM.COM` | `npm run test:slow` | CRC based exerciser over all instruction groups |

Space Invaders (`roms/invaders.rom`) is not in the repository because it is copyrighted. The `/roms/` folder is git-ignored; put your own copy there to play it locally.

## Continuous integration

[`.github/workflows/ci.yml`](./.github/workflows/ci.yml) runs the tests, the format check and a production build on every push and pull request. Pushes to `main` also deploy `src/` to GitHub Pages.

## Documentation

* [8080 By Opcode](./docu/opcodes.md)
* [Design note](./docs/DESIGN.md)
* Slides for software engineers: emulation, the 8080, functional programming and modelling, Elm and a walk-through of this code: <https://samuelbucheliz.github.io/elmulator/slides/> (source in [`slides/`](./slides); to present locally, `cd slides && npm install && npm run dev`)

## Links

* <https://elm-lang.org>
* <https://github.com/Malax/elmboy>
* <http://emulator101.com>
