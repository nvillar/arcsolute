-- absolute-position midi controller for monome arc
-- based on cycles.lua by tehn
-- long press: toggle between play and config modes
-- short press: play mode resets values; config mode (cc/channel) toggles option

DEFAULT_LED_LEVEL_LOW = 5
DEFAULT_LED_LEVEL_HIGH = 15

LED_LEVEL_LOW = DEFAULT_LED_LEVEL_LOW
LED_LEVEL_HIGH = DEFAULT_LED_LEVEL_HIGH

LED_COUNT = 64
SCRIPT_ID = "arcsolute"
TICKS_PER_CC = 8

MODE_PLAY = 1
MODE_CC = 2
MODE_CH = 3
MODE_BRIGHTNESS = 4

mode_names = {
    [MODE_PLAY] = "play",
    [MODE_CC] = "cc",
    [MODE_CH] = "channel",
    [MODE_BRIGHTNESS] = "brightness"
}

local CONFIG_MODES = {MODE_CC, MODE_CH, MODE_BRIGHTNESS}

local function next_config_mode(current)
    for index, value in ipairs(CONFIG_MODES) do
        if value == current then
            local next_index = (index % #CONFIG_MODES) + 1
            return CONFIG_MODES[next_index]
        end
    end
    return CONFIG_MODES[1]
end

DEFAULT_CCS = {10, 11, 12, 13}
DEFAULT_CH = 1

-- LED positions for CC mode digit display
TENS_POSITIONS = {51, 52, 53, 54, 55, 56, 57, 58, 59, 60}
ONES_POSITIONS = {40, 41, 42, 43, 44, 45, 46, 47, 48, 49}
HUNDREDS_POSITION = 63

-- default to play mode
mode = MODE_PLAY

-- used to track long vs short button press
key_metro = nil 

-- state for each ring
c = {{}, {}, {}, {}}

-- pending ticks for each ring
pending_ticks = {0, 0, 0, 0}

local display_cache = {
    {value_full = 0, value_partial_led = nil, cc_hundreds = nil, cc_tens = nil, cc_ones = nil, ch_index = nil},
    {value_full = 0, value_partial_led = nil, cc_hundreds = nil, cc_tens = nil, cc_ones = nil, ch_index = nil},
    {value_full = 0, value_partial_led = nil, cc_hundreds = nil, cc_tens = nil, cc_ones = nil, ch_index = nil},
    {value_full = 0, value_partial_led = nil, cc_hundreds = nil, cc_tens = nil, cc_ones = nil, ch_index = nil}
}

local function reset_ring_cache(ring)
    pending_ticks[ring] = 0
    local cache = display_cache[ring]
    cache.value_full = 0
    cache.value_partial_led = nil
    cache.cc_hundreds = nil
    cache.cc_tens = nil
    cache.cc_ones = nil
    cache.ch_index = nil
end

local function status(fmt, ...)
    if ps then
        ps(fmt, ...)
    else
        print(string.format(fmt, ...))
    end
end

local function clamp(v, min_v, max_v)
    if v < min_v then return min_v end
    if v > max_v then return max_v end
    return v
end

local function clamp_brightness(low, high)
    low = clamp(low or DEFAULT_LED_LEVEL_LOW, 1, 10)
    high = clamp(high or DEFAULT_LED_LEVEL_HIGH, 2, 15)

    if high <= low then
        high = clamp(low + 1, 2, 15)
        if high <= low then
            low = clamp(high - 1, 1, 10)
        end
    end

    return low, high
end

local function set_brightness(low, high)
    LED_LEVEL_LOW = low
    LED_LEVEL_HIGH = high

    if not c.brightness then
        c.brightness = {}
    end

    c.brightness.low = low
    c.brightness.high = high
end

local function wrap_led(index)
    return ((index - 1) % LED_COUNT) + 1
end

local function value_leds(value)
    if value <= 0 then
        return 0, nil
    end

    local scaled = (value + 1) / 2
    local full = math.floor(scaled)
    local fractional = scaled - full

    if full >= LED_COUNT then
        return LED_COUNT, nil
    end

    if fractional > 0 then
        return full, wrap_led(full + 1)
    end

    return full, nil
end

local function set_value(ring, new_value)
    local state = c[ring]
    local current = state.value or 0
    local clamped = clamp(new_value, 0, 127)
    if clamped == current then return false end
    state.value = clamped
    midi_cc(state.cc, clamped, state.ch)
    return true
end

local function accumulate_steps(ring, delta)
    pending_ticks[ring] = pending_ticks[ring] + delta

    local steps = 0
    while pending_ticks[ring] >= TICKS_PER_CC do
        pending_ticks[ring] = pending_ticks[ring] - TICKS_PER_CC
        steps = steps + 1
    end
    while pending_ticks[ring] <= -TICKS_PER_CC do
        pending_ticks[ring] = pending_ticks[ring] + TICKS_PER_CC
        steps = steps - 1
    end

    return steps
end

local function apply_steps(ring, delta, current, min_value, max_value, transform)
    local steps = accumulate_steps(ring, delta)
    if steps == 0 then return nil end

    local target = transform(current, steps)
    if target < min_value or target > max_value then
        pending_ticks[ring] = 0
        target = clamp(target, min_value, max_value)
    end

    if target == current then
        return nil
    end

    return target
end

local function draw_value(ring, force)
    local value = c[ring].value or 0
    local cache = display_cache[ring]

    if force then
        cache.value_full = 0
        cache.value_partial_led = nil
    end

    local prev_full = cache.value_full or 0
    local prev_partial = cache.value_partial_led

    local full_leds, partial_led = value_leds(value)

    if prev_partial and prev_partial ~= partial_led then
        arc_led(ring, prev_partial, 0)
    end

    if prev_full > full_leds then
        for i = full_leds + 1, prev_full do
            arc_led(ring, wrap_led(i), 0)
        end
    elseif full_leds > prev_full then
        for i = prev_full + 1, full_leds do
            arc_led(ring, wrap_led(i), LED_LEVEL_HIGH)
        end
    end

    if partial_led then
        arc_led(ring, partial_led, LED_LEVEL_LOW)
    end

    cache.value_full = full_leds
    cache.value_partial_led = partial_led
end

local function draw_cc(ring, force)
    local value = c[ring].cc or 0
    local hundreds = math.floor(value / 100)
    local tens = math.floor((value % 100) / 10)
    local ones = value % 10
    local cache = display_cache[ring]

    if force then
        arc_led(ring, HUNDREDS_POSITION, LED_LEVEL_LOW)
        for digit = 0, 9 do
            arc_led(ring, TENS_POSITIONS[digit + 1], LED_LEVEL_LOW)
            arc_led(ring, ONES_POSITIONS[digit + 1], LED_LEVEL_LOW)
        end
        cache.cc_hundreds = nil
        cache.cc_tens = nil
        cache.cc_ones = nil
    end

    if cache.cc_hundreds ~= hundreds then
        arc_led(ring, HUNDREDS_POSITION, hundreds == 1 and LED_LEVEL_HIGH or LED_LEVEL_LOW)
        cache.cc_hundreds = hundreds
    end

    if cache.cc_tens and cache.cc_tens > 0 and cache.cc_tens ~= tens then
        arc_led(ring, TENS_POSITIONS[cache.cc_tens + 1], LED_LEVEL_LOW)
    end
    if tens > 0 and cache.cc_tens ~= tens then
        arc_led(ring, TENS_POSITIONS[tens + 1], LED_LEVEL_HIGH)
    end
    cache.cc_tens = tens

    if cache.cc_ones and cache.cc_ones > 0 and cache.cc_ones ~= ones then
        arc_led(ring, ONES_POSITIONS[cache.cc_ones + 1], LED_LEVEL_LOW)
    end
    if ones > 0 and cache.cc_ones ~= ones then
        arc_led(ring, ONES_POSITIONS[ones + 1], LED_LEVEL_HIGH)
    end
    cache.cc_ones = ones
end

local function draw_ch(ring, force)
    local channel = c[ring].ch or 1
    local cache = display_cache[ring]

    if force then
        for i = 1, 16 do
            arc_led(ring, 24 - i, LED_LEVEL_LOW)
        end
        cache.ch_index = nil
    end

    if cache.ch_index and cache.ch_index ~= channel then
        arc_led(ring, 24 - cache.ch_index, LED_LEVEL_LOW)
    end

    if cache.ch_index ~= channel then
        arc_led(ring, 24 - channel, LED_LEVEL_HIGH)
        cache.ch_index = channel
    end
end

local function redraw_play_mode()
    for ring = 1, 4 do
        draw_value(ring, true)
    end
end

local function redraw_cc_mode()
    for ring = 1, 4 do
        draw_cc(ring, true)
    end
end

local function redraw_ch_mode()
    for ring = 1, 4 do
        draw_ch(ring, true)
    end
end

local function preview_brightness()
    arc_led_all(1, LED_LEVEL_LOW)
    arc_led_all(2, LED_LEVEL_LOW)
    arc_led_all(3, LED_LEVEL_HIGH)
    arc_led_all(4, LED_LEVEL_HIGH)
end

local function redraw_brightness_mode()
    preview_brightness()
end

function redraw()
    for ring = 1, 4 do
        arc_led_all(ring, 0)
    end

    if mode == MODE_PLAY then
        redraw_play_mode()
    elseif mode == MODE_CC then
        redraw_cc_mode()
    elseif mode == MODE_CH then
        redraw_ch_mode()
    elseif mode == MODE_BRIGHTNESS then
        redraw_brightness_mode()
    end

    arc_refresh()
end

local function save_state()
    local persist = {
        script = SCRIPT_ID,
        brightness = {
            low = LED_LEVEL_LOW,
            high = LED_LEVEL_HIGH
        }
    }

    for ring = 1, 4 do
        persist[ring] = {
            cc = c[ring].cc or (DEFAULT_CCS[ring] or DEFAULT_CCS[1]),
            ch = c[ring].ch or DEFAULT_CH
        }
    end

    pset_write(1, persist)
end

local function reset_values()
    for ring = 1, 4 do
        c[ring].value = 0
        midi_cc(c[ring].cc, 0, c[ring].ch)
        reset_ring_cache(ring)
    end
end

local function handle_short_press()
    if mode == MODE_PLAY then
        reset_values()
        save_state()
        status("values reset")
        redraw()
        return
    end

    mode = next_config_mode(mode)

    for ring = 1, 4 do
        reset_ring_cache(ring)
    end

    status("mode: %s", mode_names[mode])
    redraw()
end

local function handle_long_press()
    if mode == MODE_PLAY then
        mode = MODE_CC
        status("mode: %s", mode_names[mode])
    else
        mode = MODE_PLAY
        save_state()
        status("mode: %s", mode_names[mode])
    end

    for ring = 1, 4 do
        reset_ring_cache(ring)
    end

    redraw()
end

function init()
    print("\narcsolute starting\n")
    local stored = pset_read(1)
    local has_stored = stored and stored.script == SCRIPT_ID

    for ring = 1, 4 do
        c[ring] = c[ring] or {}
        c[ring].value = 0

        local default_cc = DEFAULT_CCS[ring] or DEFAULT_CCS[1]
        if has_stored and stored[ring] then
            c[ring].cc = clamp(stored[ring].cc or default_cc, 0, 127)
            c[ring].ch = clamp(stored[ring].ch or DEFAULT_CH, 1, 16)
        else
            c[ring].cc = default_cc
            c[ring].ch = DEFAULT_CH
        end
    end

    if has_stored then
        local stored_low, stored_high = clamp_brightness(
            stored.brightness and stored.brightness.low,
            stored.brightness and stored.brightness.high
        )
        set_brightness(stored_low, stored_high)
    else
        local low, high = clamp_brightness(DEFAULT_LED_LEVEL_LOW, DEFAULT_LED_LEVEL_HIGH)
        set_brightness(low, high)
        save_state()
    end

    mode = MODE_PLAY

    for ring = 1, 4 do
        arc_res(ring, 1)
        reset_ring_cache(ring)
    end

    redraw()
end

function arc(ring, delta)
    if delta == 0 then return end

    if mode == MODE_PLAY then
        local current = c[ring].value or 0
        local target = apply_steps(ring, delta, current, 0, 127, function(value, steps)
            return value + steps
        end)

        if target and set_value(ring, target) then
            draw_value(ring, false)
            arc_refresh()
        end
    elseif mode == MODE_CC then
        local current = c[ring].cc or 0
        local target = apply_steps(ring, delta, current, 0, 127, function(value, steps)
            return value + steps
        end)

        if target then
            c[ring].cc = target
            status("ring %d cc: %d", ring, target)
            draw_cc(ring, false)
            arc_refresh()
        end
    elseif mode == MODE_CH then
        local current = c[ring].ch or DEFAULT_CH
        local target = apply_steps(ring, delta, current, 1, 16, function(value, steps)
            return value - steps
        end)

        if target then
            c[ring].ch = target
            status("ring %d ch: %d", ring, target)
            draw_ch(ring, false)
            arc_refresh()
        end
    elseif mode == MODE_BRIGHTNESS then
        if ring <= 2 then
            local current = LED_LEVEL_LOW
            local max_value = math.max(1, math.min(10, LED_LEVEL_HIGH - 1))
            local target = apply_steps(ring, delta, current, 1, max_value, function(value, steps)
                return value + steps
            end)

            if target then
                set_brightness(target, LED_LEVEL_HIGH)
                status("brightness low: %d", target)
                preview_brightness()
                arc_refresh()
            end
        else
            local current = LED_LEVEL_HIGH
            local min_value = clamp(LED_LEVEL_LOW + 1, 2, 15)
            local target = apply_steps(ring, delta, current, min_value, 15, function(value, steps)
                return value + steps
            end)

            if target then
                set_brightness(LED_LEVEL_LOW, target)
                status("brightness high: %d", target)
                preview_brightness()
                arc_refresh()
            end
        end
    end
end

function arc_key(z)
    if z == 1 then
        key_metro = metro.new(key_timer, 500, 1)
    elseif key_metro then
        metro.stop(key_metro)
        key_metro = nil
        handle_short_press()
    end
end

function key_timer()
    metro.stop(key_metro)
    key_metro = nil
    handle_long_press()
end

init()
