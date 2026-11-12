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

## Planned: machine profiles

Space Invaders is the only game so far, and its specifics are spread over several modules:
the video layout (`Graphics`), the interrupt schedule (`Config`), the button-to-port-bit map
(`IO`) and the keyboard map (`UI.KeyDecoder`). They will be gathered in one value:

```elm
type alias Cabinet =
    { name : String
    , video : { start : Int, width : Int, height : Int, rotation : Rotation }
    , interrupts : Int -> Int                 -- which vector is due in frame slice n
    , buttons : Button -> List ( Port, Int )  -- port and bit driven by each button
    , keys : String -> Maybe Button
    }
```

Space Invaders becomes one value of this type. Another 8080 cabinet would be another value.
The CPU core does not change. The test ROMs use a plain profile without video or buttons.

## Planned: smaller clean-ups

- One implementation per opcode family (the generated ones); no duplicate per-opcode functions.
- `Register` and flag accessors instead of one function per register.
- A flat effect type (`WriteRegister`, `WriteFlag`, `WriteMemory`, `AddCycles`).
- `Result` for errors, instead of two error channels.
- `Main.Model` split into `Machine` (emulator), `Clock` (timing) and `Ui` (controls, screen).
- Views are functions of the model; the rendered screen is cached with `Html.Lazy`, not stored
  in the model.
