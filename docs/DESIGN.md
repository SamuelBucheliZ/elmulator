# Design

This note describes how Elmulator is structured and why. It is meant for anyone reading
the code, including people new to functional programming.

## Layers

The code is split into a pure core, device models, and a thin shell:

| Layer | Modules | Nature |
| --- | --- | --- |
| CPU core | `Cpu`, `MachineInstructions`, `OpCodeTable`, `OpCode`, `Memory`, `Psw` | Pure functions of the machine state |
| Devices | `IO` (ports and buttons), `Graphics` (video RAM to drawing commands) | Pure functions of the machine state |
| Timing | `Config`, `Cpu.runCycles` | Pure: cycles in, state out |
| Shell | `Main`, `UI.*` | Elm runtime: messages, subscriptions, views |

The core and the devices know nothing about the browser. Everything that happens in the
browser (timers, keys, file input, canvas) goes through `Main`.

## The machine state is a value

`MachineState` is an ordinary record: CPU registers and flags, memory, the shift register,
the ports and a step counter. Nothing is mutated. Each instruction takes a state and returns
a new one, so every earlier state is still there. This is what makes step back and forward
possible later: it is a list of states.

## Instructions describe their effects

An instruction does not change the state directly. It returns a `MachineStateDiff`: a list of
events ("set register A to 5", "set flag Z", "write memory", "add 4 cycles"). `Cpu.apply` folds
the events into the next state. Tests can check what an instruction does, or check the state
after it.

## Opcodes are data

`OpCodeTable` maps each opcode byte to its name, cycle count and implementation.
Instruction families (MOV, ALU, Jcc, RST, ...) are generated from the opcode bits, so the table
has one source of truth.

## Time

The 8080 runs at 2 MHz. The emulator counts cycles, not instructions:

- `Config.baseCyclesPerSecond` is the clock; the speed factor scales it.
- The video interrupt is raised every `interruptPeriodCycles` (1/120 s): RST 1 at mid-frame and
  RST 2 at the end of the frame, alternating. The game re-enables interrupts in its RST 1
  handler, so both are needed.
- `Cpu.runCycles target due state` runs instructions until the cycle count reaches `target`,
  raising interrupts when they fall due. It is pure: the caller keeps the due cycle.
- The shell runs a slice every 16 ms, converting elapsed time into cycles.

## Testing

- **Behaviour tests** (`CpuBehaviourTest`, `GraphicsTest`, `ControlsTest`, `EmulationSpeedTest`):
  they check what an instruction does, or what the emulator does over time.
- **ROM tests** (`CpmRomTest`, `tests/roms`): the Intel 8080 CPU diagnostics, run through a
  small CP/M shim, check output, instruction counts and cycle counts against the reference.
  `tests-slow` holds the two long ones (CPUTEST, 8080 exerciser).
- **Coverage**: a test checks that every documented opcode is implemented.

## Machine profiles: started

Space Invaders is the only game so far. Its specifics were spread over several modules, and the
first step has been taken: `Cabinet` (`src/elm/Cabinet.elm`) is a record with the name, the
keyboard map and the initial port values, and `Space Invaders` is its one value. `UI.KeyDecoder`
gets its keys from the cabinet through `Cabinet.gameKey`.

Still outside the cabinet, to be moved in later:

- the video layout (`Graphics`: start, width, height, rotation),
- the interrupt schedule (`Config`, `Cpu`: which vector is due in each slice of the frame),
- the button-to-port-bit map (`IO`).

The aim is a cabinet value with these fields as well, so that another 8080 machine would be another
value. The CPU core should not change. The test ROMs use a plain profile without video or buttons.

## Clean-ups: done and open

Done:

- One implementation per opcode family: the families are generated from the opcode bits, not
  written out per opcode.
- Typed registers and register pairs (`Registers`), so that operands are not raw strings.
- `Main`'s model is split into `Machine` (emulator), `Clock` (timing) and `Ui` (controls, screen).
- Dead code is removed: the old event-search helpers and commented-out validators in `Cpu`.

Done in a different shape than planned: effects are events in two levels (`SetCpu`, `SetMemory`,
`SetFlag`, `AddCycles`, ...) inside `MachineStateDiffEvent`, rather than one flat type.

Open:

- `Result` for errors: memory access still uses its own `MemoryAccessResult`, and a failed step is
  `Invalid` in `EmulatorState`. The standard `Result` would give `map` and `andThen` for free.
- Views as functions of the model, with the rendered screen cached by `Html.Lazy`. The screen is
  not cached yet.

## Documentation

- `docs/DESIGN.md`: this note.
- `docs/opcodes.md`: the 8080 opcode reference.
- `docs/slides/`: the slide deck for software engineers (Slidev), published with the Pages site under
  `/elmulator/slides/`. It has its own `package.json`, so the Elm build does not depend on it.
