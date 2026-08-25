# Interplanetary Fuel Calculator

[![CI](https://github.com/sergei-krylov/elixir_challenge/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/sergei-krylov/elixir_challenge/actions/workflows/ci.yml)

Calculates the fuel a spacecraft needs to fly a path of launches and landings
across the Solar System. Built with Elixir, Phoenix and LiveView: the flight
path is assembled in the browser and the total updates as you edit it.

## Running

```bash
mix setup
mix phx.server
```

Then visit [localhost:4000](http://localhost:4000). Run the tests with `mix test`.

## The formulas

A step costs `mass * gravity * coefficient - constant`, rounded down:

| Action | Coefficient | Constant |
| ------ | ----------- | -------- |
| Launch | 0.042       | 33       |
| Land   | 0.033       | 42       |

Surface gravity in m/s²: Earth 9.807, Moon 1.62, Mars 3.711.

Fuel is itself mass that needs fuel, so each result is fed back through the same
formula until the increment stops being positive. Landing 28,801 kg on Earth
needs 9278 + 2960 + 915 + 254 + 40 = 13,447 kg.

## Why the path is costed backwards

The brief gives the formula for a single step but not how steps combine. A
spacecraft has to carry the fuel for every step still ahead of it, so that fuel
is payload for the earlier steps. The path is therefore costed from the last
step to the first, each step against the spacecraft plus the fuel already
committed to the steps after it.

Summing forwards instead gives 51,951 kg for Apollo 11 rather than 51,898 —
close enough to look correct, which is why the test suite asserts that
reversing a path changes its total.

## Decisions

Points the brief leaves open:

- **A step needing no fuel contributes 0**, never a negative. This is reachable
  for light craft: launching from the Moon needs no fuel below 485 kg.
- **Mass is a positive integer**, capped at 1,000,000,000 kg. A larger integer
  overflows float conversion inside the formula and
  raises `ArithmeticError`.
- **Unfinished steps are skipped and counted**, not treated as errors, so the
  total stays live while a path is being edited.
- **Flight path coherence is advisory.** The brief never fixes where a mission
  starts, so the first step decides it and a single step such as *Launch -
  Mars* is a valid path. Later steps that contradict the path so far are
  flagged inline but still costed, since the arithmetic is well defined either
  way.
- **A path is capped at 20 steps**, which bounds both the form and the socket
  state.
- **No database.** A mission is an embedded schema validated by changesets and
  held in the LiveView socket.
