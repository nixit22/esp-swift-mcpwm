// Copyright (c) 2026 Nicolas Christe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import GPIO
import MCPWM
import Platform

func testMCPWM(logger: Logger) {
    do {
        // 20 kHz PWM, 1 MHz resolution → 50 duty ticks
        let timer = McpwmTimer(group: 0, resolutionHz: 1_000_000, periodTicks: 50)
        let oper = try timer.newOperator()
        let cmprA = try oper.newComparator()
        let cmprB = try oper.newComparator()
        let genA = try oper.newGenerator(gpioNum: GPIO_NUM_10)
        let genB = try oper.newGenerator(gpioNum: GPIO_NUM_11)

        // Standard H-bridge PWM actions: HIGH at timer empty, LOW at comparator threshold
        try genA.setActionOnTimerEvent(direction: MCPWM_TIMER_DIRECTION_UP, event: MCPWM_TIMER_EVENT_EMPTY, action: MCPWM_GEN_ACTION_HIGH)
        try genA.setActionOnCompareEvent(direction: MCPWM_TIMER_DIRECTION_UP, comparator: cmprA, action: MCPWM_GEN_ACTION_LOW)
        try genB.setActionOnTimerEvent(direction: MCPWM_TIMER_DIRECTION_UP, event: MCPWM_TIMER_EVENT_EMPTY, action: MCPWM_GEN_ACTION_HIGH)
        try genB.setActionOnCompareEvent(direction: MCPWM_TIMER_DIRECTION_UP, comparator: cmprB, action: MCPWM_GEN_ACTION_LOW)

        // Coast: hold both pins low before starting timer
        try genA.setForceLevel(0)
        try genB.setForceLevel(0)

        try timer.enable()
        try timer.startStop(MCPWM_TIMER_START_NO_STOP)

        // Forward at ~75%: cmprA = 37/50, genB forced low, genA released to PWM
        try cmprA.setCompareValue(37)
        try genB.setForceLevel(0)
        try genA.setForceLevel(-1)
        logger.i("MCPWM: genA 75% duty (forward)")

        // Coast
        try genA.setForceLevel(0)

        logger.i("MCPWM: APIs compiled and linked successfully")
        // genB, genA, cmprB, cmprA, oper, timer freed by deinit (reverse declaration order)
    } catch {
        logger.e("MCPWM: failed: \(error.name)")
    }
}
