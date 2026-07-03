# SwiftMCPWM

Swift MCPWM driver wrapping ESP-IDF's `esp_driver_mcpwm`. Exposes the MCPWM peripheral primitives — `McpwmTimer`, `McpwmOperator`, `McpwmComparator`, `McpwmGenerator` — for PWM motor control over an H-bridge; higher-level motor logic lives in the client app. Swift module name: **`MCPWM`**.

Depends on: `SwiftPlatform`, `SwiftSupport`, `esp_driver_mcpwm`.

## Usage

```swift
import MCPWM

let timer = McpwmTimer(group: 0, resolutionHz: 1_000_000, periodTicks: 50)
let oper = try timer.newOperator()
let cmpr = try oper.newComparator()
let gen = try oper.newGenerator(gpioNum: GPIO_NUM_10)
try timer.enable()
try timer.startStop(MCPWM_TIMER_START_NO_STOP)
try cmpr.setCompareValue(37) // ~74% duty
```

See [`CLAUDE.md`](CLAUDE.md) for full API details, the resource hierarchy, and non-obvious patterns (deletion order, force-level semantics).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
