# SwiftMCPWM

Swift MCPWM driver wrapping `esp_driver_mcpwm`. Exposes the MCPWM peripheral primitives (timer, operator, comparator, generator); motor control logic lives in the client app. Swift module name: **`MCPWM`**.

Depends on: `SwiftPlatform`, `SwiftSupport`, `esp_driver_mcpwm`

## Files

| File | Role |
|---|---|
| `src/MCPWM.swift` | `McpwmTimer`, `McpwmOperator`, `McpwmComparator`, `McpwmGenerator` — public Swift API |
| `src/mcpwm.c` / `src/mcpwm.h` | Thin C wrapper — only `#include <driver/mcpwm_prelude.h>` |
| `module.modulemap` | Clang module `ESP_MCPWM` — umbrella over `src/mcpwm.h` |

## Public API

```swift
// Timer: controls the PWM period and clock — aborts on failure
let timer = McpwmTimer(group: 0, resolutionHz: 1_000_000, periodTicks: 50)

// Operator: created from the timer (same group, auto-connected)
let oper = try timer.newOperator()

// Comparators: set the duty-cycle threshold
let cmprA = try oper.newComparator()
let cmprB = try oper.newComparator()
try cmprA.setCompareValue(37)     // 37/50 = 74% duty at 20 kHz

// Generators: drive GPIO pins
let genA = try oper.newGenerator(gpioNum: GPIO_NUM_10)
let genB = try oper.newGenerator(gpioNum: GPIO_NUM_11, invertPwm: true)

// Configure actions (what the pin does on timer/compare events)
try genA.setActionOnTimerEvent(direction: MCPWM_TIMER_DIRECTION_UP, event: MCPWM_TIMER_EVENT_EMPTY, action: MCPWM_GEN_ACTION_HIGH)
try genA.setActionOnCompareEvent(direction: MCPWM_TIMER_DIRECTION_UP, comparator: cmprA, action: MCPWM_GEN_ACTION_LOW)

// Force a pin to a fixed level, bypassing the PWM action
try genA.setForceLevel(0)    // force low (coast / brake)
try genA.setForceLevel(1)    // force high
try genA.setForceLevel(-1)   // release — resume normal PWM action

// Timer lifecycle
try timer.enable()
try timer.startStop(MCPWM_TIMER_START_NO_STOP)
try timer.startStop(MCPWM_TIMER_STOP_EMPTY)
try timer.disable()
try timer.setPeriod(100)     // change period on the fly

// No explicit cleanup — deinit handles it, in reverse declaration order:
// genA, genB, cmprA, cmprB destroyed first, then oper, then timer.
```

## MCPWM resource hierarchy

```
Group (Int32)
└── McpwmTimer   (mcpwm_new_timer)
    └── McpwmOperator  (mcpwm_new_operator + connect_timer)
        ├── McpwmComparator A  (mcpwm_new_comparator)
        ├── McpwmComparator B
        ├── McpwmGenerator A   (mcpwm_new_generator)
        └── McpwmGenerator B
```

`McpwmOperator` is created via `timer.newOperator()`, which handles both allocation and `mcpwm_operator_connect_timer` automatically. `McpwmComparator` and `McpwmGenerator` are created via `oper.newComparator()` / `oper.newGenerator(gpioNum:)`.

## Non-obvious patterns

**No C glue needed** — `mcpwm_generator_set_action_on_timer_event` and `_on_compare_event` are real functions (not macros). All config structs have no SoC-conditional fields.

**`@_exported import ESP_MCPWM`** — re-exports the C module. Callers get all `MCPWM_*` enums (`MCPWM_TIMER_DIRECTION_UP`, `MCPWM_TIMER_EVENT_EMPTY`, `MCPWM_GEN_ACTION_HIGH`, `MCPWM_TIMER_START_NO_STOP`, etc.) and `gpio_num_t` without a separate import.

**`setForceLevel(-1)` releases PWM** — `-1` removes the forced level; the generator resumes its configured timer/compare actions. `0` / `1` force the pin low/high regardless of PWM state. `holdOn: true` (default) keeps the forced level until explicitly removed.

**`gen_gpio_num` is `Int32`** — `mcpwm_generator_config_t.gen_gpio_num` is `int`, not `gpio_num_t`. Converted via `Int32(gpioNum.rawValue)` inside `newGenerator`.

**`McpwmComparator.handle` is `internal`** — exposed at the module level (not `private`) so `McpwmGenerator.setActionOnCompareEvent` can pass the raw handle to `mcpwm_generator_set_action_on_compare_event`.

**Duty resolution** — `resolutionHz = 1_000_000` gives `periodTicks = 1_000_000 / pwmHz` duty steps. At 20 kHz: 50 steps. The prescaler is an exact integer on both C6 (80 MHz PLL ÷ 80) and H2 (96 MHz PLL ÷ 96).

**Deletion order** — all four types are `~Copyable` with `deinit`-based cleanup; generators and comparators must be destroyed before their operator, and the operator before its timer (deleting out of order returns `ESP_ERR_INVALID_STATE`). Declare `timer` first and leaf values (generators/comparators) last so Swift's reverse-declaration-order destruction matches this requirement automatically.

**Operator flags** — `update_gen_action_on_tez: 1` makes generator action changes (via `setForceLevel`) take effect at the next timer-zero event, preventing mid-period glitches.

**Dead-time not included (v1)** — suitable for bridge ICs (DRV8833, TB6612) that handle shoot-through protection internally. Discrete FET bridges need `mcpwm_generator_set_dead_time()` — add in v2.
