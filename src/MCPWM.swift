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

@_exported import ESP_MCPWM
import Platform

private let log = Logger(tag: "MCPWM")

/// `~Copyable` — stops, disables, and deletes the timer in `deinit`.
///
/// Declare `McpwmTimer` before operators/comparators/generators so Swift
/// destroys them in reverse order (leaves first, timer last).
public struct McpwmTimer: ~Copyable {
    private let handle: mcpwm_timer_handle_t
    private let groupId: Int32

    /// Aborts on failure — intended for boot-time static allocation.
    public init(
        group: Int32 = 0,
        resolutionHz: UInt32,
        periodTicks: UInt32,
        countMode: mcpwm_timer_count_mode_t = MCPWM_TIMER_COUNT_MODE_UP
    ) {
        var cfg = mcpwm_timer_config_t(
            group_id: group,
            clk_src: MCPWM_TIMER_CLK_SRC_DEFAULT,
            resolution_hz: resolutionHz,
            count_mode: countMode,
            period_ticks: periodTicks,
            intr_priority: 0,
            flags: .init(update_period_on_empty: 0, update_period_on_sync: 0, allow_pd: 0))
        var h: mcpwm_timer_handle_t? = nil
        mcpwm_new_timer(&cfg, &h)
            .abortOnError { log.e("Failed to create MCPWM timer: \($0.name)") }
        guard let h else {
            log.e("MCPWM timer handle is nil")
            fatalError()
        }
        self.handle = h
        self.groupId = group
    }

    deinit {
        _ = mcpwm_timer_start_stop(handle, MCPWM_TIMER_STOP_EMPTY)
        _ = mcpwm_timer_disable(handle)
        _ = mcpwm_del_timer(handle)
    }

    public func enable() throws(Error) {
        try mcpwm_timer_enable(handle)
            .throwEspError { log.e("Failed to enable MCPWM timer: \($0.name)") }
    }

    public func disable() throws(Error) {
        try mcpwm_timer_disable(handle)
            .throwEspError { log.e("Failed to disable MCPWM timer: \($0.name)") }
    }

    public func startStop(_ cmd: mcpwm_timer_start_stop_cmd_t) throws(Error) {
        try mcpwm_timer_start_stop(handle, cmd)
            .throwEspError { log.e("Failed to start/stop MCPWM timer: \($0.name)") }
    }

    public func setPeriod(_ periodTicks: UInt32) throws(Error) {
        try mcpwm_timer_set_period(handle, periodTicks)
            .throwEspError { log.e("Failed to set MCPWM timer period: \($0.name)") }
    }

    public func newOperator() throws(Error) -> McpwmOperator {
        var cfg = mcpwm_operator_config_t(
            group_id: groupId,
            intr_priority: 0,
            flags: .init(
                update_gen_action_on_tez: 1, update_gen_action_on_tep: 0,
                update_gen_action_on_sync: 0, update_dead_time_on_tez: 0,
                update_dead_time_on_tep: 0, update_dead_time_on_sync: 0))
        var h: mcpwm_oper_handle_t? = nil
        try mcpwm_new_operator(&cfg, &h)
            .throwEspError { log.e("Failed to create MCPWM operator: \($0.name)") }
        guard let h else {
            log.e("MCPWM operator handle is nil")
            throw Error.espError(ESP_FAIL)
        }
        let connectErr = mcpwm_operator_connect_timer(h, handle)
        if connectErr != ESP_OK {
            log.e("Failed to connect MCPWM operator to timer: \(connectErr.name)")
            // The operator handle was still allocated by mcpwm_new_operator above and would
            // otherwise leak since it's never wrapped in a McpwmOperator on this failure path.
            _ = mcpwm_del_operator(h)
            throw Error.espError(connectErr)
        }
        return McpwmOperator(handle: h)
    }
}

/// `~Copyable` — deletes the operator in `deinit`.
public struct McpwmOperator: ~Copyable {
    private let handle: mcpwm_oper_handle_t

    init(handle: mcpwm_oper_handle_t) {
        self.handle = handle
    }

    deinit {
        _ = mcpwm_del_operator(handle)
    }

    public func newComparator() throws(Error) -> McpwmComparator {
        var cfg = mcpwm_comparator_config_t(
            intr_priority: 0,
            flags: .init(update_cmp_on_tez: 1, update_cmp_on_tep: 0, update_cmp_on_sync: 0))
        var h: mcpwm_cmpr_handle_t? = nil
        try mcpwm_new_comparator(handle, &cfg, &h)
            .throwEspError { log.e("Failed to create MCPWM comparator: \($0.name)") }
        guard let h else {
            log.e("MCPWM comparator handle is nil")
            throw Error.espError(ESP_FAIL)
        }
        return McpwmComparator(handle: h)
    }

    public func newGenerator(gpioNum: gpio_num_t, invertPwm: Bool = false) throws(Error) -> McpwmGenerator {
        var cfg = mcpwm_generator_config_t(
            gen_gpio_num: Int32(gpioNum.rawValue),
            flags: .init(
                invert_pwm: invertPwm ? 1 : 0,
                io_loop_back: 0, io_od_mode: 0, pull_up: 0, pull_down: 0))
        var h: mcpwm_gen_handle_t? = nil
        try mcpwm_new_generator(handle, &cfg, &h)
            .throwEspError { log.e("Failed to create MCPWM generator: \($0.name)") }
        guard let h else {
            log.e("MCPWM generator handle is nil")
            throw Error.espError(ESP_FAIL)
        }
        return McpwmGenerator(handle: h)
    }
}

/// `~Copyable` — deletes the comparator in `deinit`.
public struct McpwmComparator: ~Copyable {
    internal let handle: mcpwm_cmpr_handle_t

    init(handle: mcpwm_cmpr_handle_t) {
        self.handle = handle
    }

    deinit {
        _ = mcpwm_del_comparator(handle)
    }

    public func setCompareValue(_ ticks: UInt32) throws(Error) {
        try mcpwm_comparator_set_compare_value(handle, ticks)
            .throwEspError { log.e("Failed to set MCPWM compare value: \($0.name)") }
    }
}

/// `~Copyable` — deletes the generator in `deinit`.
public struct McpwmGenerator: ~Copyable {
    private let handle: mcpwm_gen_handle_t

    init(handle: mcpwm_gen_handle_t) {
        self.handle = handle
    }

    deinit {
        _ = mcpwm_del_generator(handle)
    }

    public func setActionOnTimerEvent(
        direction: mcpwm_timer_direction_t,
        event: mcpwm_timer_event_t,
        action: mcpwm_generator_action_t
    ) throws(Error) {
        try mcpwm_generator_set_action_on_timer_event(
            handle,
            mcpwm_gen_timer_event_action_t(direction: direction, event: event, action: action)
        ).throwEspError { log.e("Failed to set MCPWM generator timer action: \($0.name)") }
    }

    public func setActionOnCompareEvent(
        direction: mcpwm_timer_direction_t,
        comparator: borrowing McpwmComparator,
        action: mcpwm_generator_action_t
    ) throws(Error) {
        try mcpwm_generator_set_action_on_compare_event(
            handle,
            mcpwm_gen_compare_event_action_t(
                direction: direction, comparator: comparator.handle, action: action)
        ).throwEspError { log.e("Failed to set MCPWM generator compare action: \($0.name)") }
    }

    /// Set or release a forced output level.
    /// - Parameter level: 0 = force low, 1 = force high, -1 = release (resume PWM action).
    public func setForceLevel(_ level: Int32, holdOn: Bool = true) throws(Error) {
        try mcpwm_generator_set_force_level(handle, level, holdOn)
            .throwEspError { log.e("Failed to set MCPWM generator force level: \($0.name)") }
    }
}
