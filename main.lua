--------------------------------------------------------------------------------
-- Street Fighter III: 3rd Strike - Combo Memory Delta Monitor
--
-- What this does:
--   - Toggle recording ON/OFF with F1 (fallback: hold P1 Start + P1 Coin/Select)
--   - Detect combos via combo counters
--   - Record memory changes per hit inside each combo
--   - Treat single hits as 1-hit combos
--   - Save a structured report to a text file when recording is stopped
--
-- Notes:
--   - Position X/Y addresses are intentionally excluded.
--   - Most gameplay-relevant and niche combat addresses are included.
--------------------------------------------------------------------------------

local OUTPUT_FOLDER = "Combo Monitor Logs"
local OUTPUT_PREFIX = "sf3_combo_monitor_"

local CHAR_NAMES = {
    [1]  = "Alex",
    [2]  = "Ryu",
    [3]  = "Yun",
    [4]  = "Dudley",
    [5]  = "Necro",
    [6]  = "Hugo",
    [7]  = "Ibuki",
    [8]  = "Elena",
    [9]  = "Oro",
    [10] = "Yang",
    [11] = "Ken",
    [12] = "Sean",
    [13] = "Urien",
    [14] = "Gouki",
    [16] = "Chun-Li",
    [17] = "Makoto",
    [18] = "Q",
    [19] = "Twelve",
    [20] = "Remy",
}

local P1_CHAR_ID = 0x02011387
local P2_CHAR_ID = 0x02011388

local COMBO_COUNTERS = {
    { name = "P1_to_P2", addr = 0x0206961D, attacker = "P1", defender = "P2" },
    { name = "P2_to_P1", addr = 0x020696C5, attacker = "P2", defender = "P1" },
}

local WATCH_LIST = {
    -- Match/global
    { key = "game_phase", addr = 0x020154A7, size = 1 },
    { key = "timer", addr = 0x02011377, size = 1 },
    { key = "timer2", addr = 0x02028679, size = 1 },
    { key = "hitboxes_active", addr = 0x02009EFC, size = 1 },
    { key = "p1_damage_done", addr = 0x02010D61, size = 1 },
    { key = "selected_super_p1", addr = 0x0201138B, size = 1 },
    { key = "selected_super_p2", addr = 0x0201138C, size = 1 },
    { key = "p1_char_id", addr = 0x02011387, size = 1 },
    { key = "p2_char_id", addr = 0x02011388, size = 1 },

    -- Round life/stun/SA
    { key = "p1_life_round", addr = 0x02028655, size = 1 },
    { key = "p2_life_round", addr = 0x0202866D, size = 1 },
    { key = "p1_stun_round", addr = 0x02028805, size = 1 },
    { key = "p2_stun_round", addr = 0x02028829, size = 1 },
    { key = "p1_sa_bar_content", addr = 0x020286A5, size = 1 },
    { key = "p1_sa_bar_count", addr = 0x020286AB, size = 1 },
    { key = "p1_sa_bar_max", addr = 0x020286AD, size = 1 },
    { key = "p2_sa_bar_content", addr = 0x020286D9, size = 1 },

    -- Hit type flags
    { key = "p1_hit_by_n", addr = 0x0202884D, size = 1 },
    { key = "p1_hit_by_s", addr = 0x0202884F, size = 1 },
    { key = "p1_hit_by_sa_other", addr = 0x02028855, size = 1 },
    { key = "p1_hit_by_sa", addr = 0x02028859, size = 1 },
    { key = "p2_hit_by_n", addr = 0x02028861, size = 1 },
    { key = "p2_hit_by_s", addr = 0x02028863, size = 1 },
    { key = "p2_hit_by_sa_other", addr = 0x02028869, size = 1 },
    { key = "p2_hit_by_sa", addr = 0x0202886D, size = 1 },
    { key = "hurt_a", addr = 0x020288A8, size = 1 },
    { key = "hurt_b", addr = 0x020288A9, size = 1 },

    -- Core object/hitbox roots
    { key = "objects_base_address", addr = 0x02028990, size = 4 },
    { key = "superfreeze_decount2", addr = 0x02028A2B, size = 1 },
    { key = "superfreeze_decount", addr = 0x0202922B, size = 1 },
    { key = "hb_objects", addr = 0x02068A96, size = 2 },
    { key = "hb_third_obj", addr = 0x02068A9C, size = 2 },

    -- P1 structure
    { key = "p1_hb_base_address", addr = 0x02068C6C, size = 4 },
    { key = "p1_facing_dir", addr = 0x02068C76, size = 1 },
    { key = "p1_opponent_dir", addr = 0x02068C77, size = 1 },
    { key = "p1_attack", addr = 0x02068C93, size = 1 },
    { key = "p1_jump_recovery_1", addr = 0x02068CA7, size = 1 },
    { key = "p1_stop", addr = 0x02068CB1, size = 1 },
    { key = "p1_zero_hit_stop", addr = 0x02068CB3, size = 1 },
    { key = "p1_life_char", addr = 0x02068D0B, size = 1 },
    { key = "p1_next_hit_damage", addr = 0x02068D0F, size = 1 },
    { key = "p1_denjin2", addr = 0x02068D27, size = 1 },
    { key = "p1_denjin", addr = 0x02068D2D, size = 1 },
    { key = "p1_state", addr = 0x02068E75, size = 1 },
    { key = "p1_sprite_decount", addr = 0x02068E80, size = 1 },
    { key = "p1_jump_recovery_2", addr = 0x02068E81, size = 1 },
    { key = "p1_anim_frame", addr = 0x02068E86, size = 1 },
    { key = "p1_universal_cancel", addr = 0x02068E8D, size = 1 },
    { key = "p1_active_throw", addr = 0x02068F01, size = 1 },
    { key = "p1_hb_active_presence", addr = 0x02068F05, size = 1 },
    { key = "p1_hb_vulnerability_presence", addr = 0x02068F07, size = 1 },
    { key = "p1_hb_passive_base", addr = 0x02068F0C, size = 4 },
    { key = "p1_hb_vulnerability_ptr", addr = 0x02068F14, size = 4 },
    { key = "p1_hb_throw_base", addr = 0x02068F24, size = 4 },
    { key = "p1_hb_throwable_base", addr = 0x02068F2C, size = 4 },
    { key = "p1_hb_active_base", addr = 0x02068F34, size = 4 },
    { key = "p1_hb_push_base", addr = 0x02068F40, size = 4 },
    { key = "p1_next_hit_stun", addr = 0x02068F9F, size = 1 },
    { key = "p1_inf_fireball", addr = 0x02068FB8, size = 1 },
    { key = "p1_true_inf_juggle", addr = 0x0206902E, size = 1 },
    { key = "p1_semi_inf_juggle", addr = 0x02069031, size = 1 },
    { key = "p1_no_combo_reduction", addr = 0x0206903E, size = 1 },
    { key = "p1_superfreeze_2", addr = 0x02069088, size = 1 },
    { key = "p1_bonus_damage", addr = 0x020690A7, size = 1 },
    { key = "p1_bonus_stun", addr = 0x020690AB, size = 1 },
    { key = "p1_bonus_resistance", addr = 0x020690AD, size = 1 },

    -- P2 structure
    { key = "p2_hb_base_address", addr = 0x02069104, size = 4 },
    { key = "p2_facing_dir", addr = 0x0206910E, size = 1 },
    { key = "p2_opponent_dir", addr = 0x0206910F, size = 1 },
    { key = "p2_attack", addr = 0x0206912B, size = 1 },
    { key = "p2_hit_stop2", addr = 0x02069149, size = 1 },
    { key = "p2_hit_stop", addr = 0x0206914B, size = 1 },
    { key = "p2_life_char", addr = 0x020691A3, size = 1 },
    { key = "p2_next_hit_damage", addr = 0x020691A7, size = 1 },
    { key = "p2_state", addr = 0x020691B3, size = 1 },
    { key = "p2_anim_frame", addr = 0x0206931E, size = 1 },
    { key = "p2_universal_cancel", addr = 0x02069325, size = 1 },
    { key = "p2_active_throw", addr = 0x02069399, size = 1 },
    { key = "p2_hb_active_presence", addr = 0x0206939D, size = 1 },
    { key = "p2_hb_vulnerability_presence", addr = 0x0206939F, size = 1 },
    { key = "p2_hb_passive_base", addr = 0x020693A4, size = 4 },
    { key = "p2_hb_vulnerability_ptr", addr = 0x020693AC, size = 4 },
    { key = "p2_hb_throw_base", addr = 0x020693BC, size = 4 },
    { key = "p2_hb_throwable_base", addr = 0x020693C4, size = 4 },
    { key = "p2_hb_active_base", addr = 0x020693CC, size = 4 },
    { key = "p2_hb_push_base", addr = 0x020693D8, size = 4 },
    { key = "p2_next_hit_stun", addr = 0x02069437, size = 1 },
    { key = "p2_inf_fireball", addr = 0x02069450, size = 1 },
    { key = "p2_true_inf_juggle", addr = 0x020694C6, size = 1 },
    { key = "p2_air_combo_inf", addr = 0x020694C7, size = 1 },
    { key = "p2_air_timer", addr = 0x020694C9, size = 1 },
    { key = "p2_no_combo_reduction", addr = 0x020694D6, size = 1 },
    { key = "p2_superfreeze", addr = 0x02069520, size = 1 },
    { key = "p2_bonus_damage", addr = 0x0206953F, size = 1 },
    { key = "p2_bonus_stun", addr = 0x02069543, size = 1 },
    { key = "p2_bonus_resistance", addr = 0x02069545, size = 1 },

    -- Meter and stun subsystem
    { key = "p1_ex_available", addr = 0x020695A8, size = 1 },
    { key = "p1_bar", addr = 0x020695B5, size = 1 },
    { key = "p1_max_super_bar", addr = 0x020695BD, size = 1 },
    { key = "p2_ex_available", addr = 0x020695D4, size = 1 },
    { key = "p2_bar", addr = 0x020695E1, size = 1 },
    { key = "p1_stun_bar_length", addr = 0x020695F7, size = 1 },
    { key = "p1_stun_status", addr = 0x020695FD, size = 1 },
    { key = "p1_stun_recovery_rate", addr = 0x02069602, size = 1 },
    { key = "p2_stun_bar_length", addr = 0x0206960B, size = 1 },
    { key = "p2_stun_status", addr = 0x02069611, size = 1 },
    { key = "p2_stun_recovery_rate", addr = 0x02069616, size = 1 },
    { key = "p1_combo_counter", addr = 0x0206961D, size = 1 },
    { key = "p2_combo_counter", addr = 0x020696C5, size = 1 },

    -- Input and charge data
    { key = "p1_inputs_kicks", addr = 0x0202563C, size = 1 },
    { key = "p1_inputs_dir_punches", addr = 0x0202563D, size = 1 },
    { key = "p1_hayate_charge", addr = 0x02025665, size = 1 },
    { key = "p2_inputs_kicks", addr = 0x02025680, size = 1 },
    { key = "p2_inputs_dir_punches", addr = 0x02025681, size = 1 },
    { key = "p1_rotation_resetter_1", addr = 0x020258F7, size = 1 },
    { key = "p1_rotation_1", addr = 0x0202590F, size = 1 },
    { key = "p1_charge_resetter_5", addr = 0x020259D7, size = 1 },
    { key = "p1_charge_5", addr = 0x020259D9, size = 1 },
    { key = "p1_rotation_2", addr = 0x020259EF, size = 1 },
    { key = "p1_charge_resetter_4", addr = 0x020259F3, size = 1 },
    { key = "p1_charge_4", addr = 0x020259F5, size = 1 },
    { key = "p1_hyakuretsu_1", addr = 0x02025A03, size = 1 },
    { key = "p1_hyakuretsu_2", addr = 0x02025A05, size = 1 },
    { key = "p1_hyakuretsu_3", addr = 0x02025A07, size = 1 },
    { key = "p1_rotation_3", addr = 0x02025A0B, size = 1 },
    { key = "p1_charge_resetter_3", addr = 0x02025A0F, size = 1 },
    { key = "p1_charge_3", addr = 0x02025A11, size = 1 },
    { key = "p1_charge_resetter_2", addr = 0x02025A2B, size = 1 },
    { key = "p1_charge_2", addr = 0x02025A2D, size = 1 },
    { key = "p1_charge_resetter_1", addr = 0x02025A47, size = 1 },
    { key = "p1_charge_1", addr = 0x02025A49, size = 1 },
    { key = "p2_charge_resetter_1", addr = 0x02025FF7, size = 1 },
    { key = "p2_charge_1", addr = 0x02025FF9, size = 1 },
    { key = "p2_charge_resetter_3", addr = 0x02026013, size = 1 },
    { key = "p2_charge_3", addr = 0x02026015, size = 1 },
    { key = "p2_charge_resetter_2", addr = 0x0202602F, size = 1 },
    { key = "p2_charge_2", addr = 0x02026031, size = 1 },
    { key = "p2_charge_resetter_4", addr = 0x0202604B, size = 1 },
    { key = "p2_charge_4", addr = 0x0202604D, size = 1 },
    { key = "p2_charge_resetter_5", addr = 0x02026067, size = 1 },
    { key = "p2_charge_5", addr = 0x02026069, size = 1 },
}

local function read_u8(addr)
    return memory.readbyte(addr) or 0
end

local function read_u16(addr)
    local b0 = read_u8(addr)
    local b1 = read_u8(addr + 1)
    return b0 + b1 * 0x100
end

local function read_u32(addr)
    local b0 = read_u8(addr)
    local b1 = read_u8(addr + 1)
    local b2 = read_u8(addr + 2)
    local b3 = read_u8(addr + 3)
    return b0 + b1 * 0x100 + b2 * 0x10000 + b3 * 0x1000000
end

local function read_value(spec)
    if spec.size == 1 then
        return read_u8(spec.addr)
    elseif spec.size == 2 then
        return read_u16(spec.addr)
    end
    return read_u32(spec.addr)
end

local function capture_snapshot()
    local snap = {}
    for i = 1, #WATCH_LIST do
        local spec = WATCH_LIST[i]
        snap[spec.key] = read_value(spec)
    end
    return snap
end

local function get_combo_counters()
    local result = {}
    for i = 1, #COMBO_COUNTERS do
        result[i] = read_u8(COMBO_COUNTERS[i].addr)
    end
    return result
end

local function to_hex(value, byteCount)
    local width = byteCount * 2
    return string.format("0x%0" .. tostring(width) .. "X", value)
end

local function format_value(value, byteCount)
    return string.format("%d (%s)", value, to_hex(value, byteCount))
end

local function diff_snapshots(oldSnap, newSnap)
    local changes = {}
    for i = 1, #WATCH_LIST do
        local spec = WATCH_LIST[i]
        local oldVal = oldSnap[spec.key]
        local newVal = newSnap[spec.key]
        if oldVal ~= newVal then
            changes[#changes + 1] = {
                key = spec.key,
                addr = spec.addr,
                size = spec.size,
                oldValue = oldVal,
                newValue = newVal,
            }
        end
    end
    return changes
end

local function get_char_name(charId)
    return CHAR_NAMES[charId] or ("ID_" .. tostring(charId))
end

local function now_frame(lastFrame)
    if emu.framecount then
        return emu.framecount()
    end
    return lastFrame + 1
end

local recording = false
local prevSnapshot = nil
local prevCounters = { 0, 0 }
local currentCombo = nil
local combos = {}
local lastFrameNumber = 0
local prevTogglePressed = false

local function safe_gui_text(x, y, text)
    if gui and gui.text then
        pcall(gui.text, x, y, text)
    end
end

local function start_recording(frameNumber)
    recording = true
    combos = {}
    currentCombo = nil
    prevSnapshot = capture_snapshot()
    prevCounters = get_combo_counters()
    print(string.format("[ComboMonitor] Recording ON at frame %d", frameNumber))
end

local function finalize_combo(frameNumber, endSnapshot)
    if not currentCombo then
        return
    end

    local tailChanges = diff_snapshots(currentCombo.lastSnapshot, endSnapshot)
    if #tailChanges > 0 then
        currentCombo.postComboChanges = tailChanges
    end

    currentCombo.endFrame = frameNumber
    combos[#combos + 1] = currentCombo

    print(string.format(
        "[ComboMonitor] Combo %d ended (%s -> %s), hits: %d",
        currentCombo.id,
        currentCombo.attacker,
        currentCombo.defender,
        currentCombo.totalHits
    ))

    currentCombo = nil
end

local function register_hit(comboRef, hitCount, frameNumber, hitSnapshot)
    local changes = diff_snapshots(comboRef.lastSnapshot, hitSnapshot)
    comboRef.lastSnapshot = hitSnapshot
    comboRef.lastCounter = hitCount
    comboRef.totalHits = hitCount

    comboRef.hits[#comboRef.hits + 1] = {
        hitNumber = hitCount,
        frame = frameNumber,
        changes = changes,
    }

    print(string.format(
        "[ComboMonitor] Combo %d hit %d (%s -> %s), changed addresses: %d",
        comboRef.id,
        hitCount,
        comboRef.attacker,
        comboRef.defender,
        #changes
    ))
end

local function create_combo(counterIndex, frameNumber, baselineSnapshot)
    local comboMeta = COMBO_COUNTERS[counterIndex]
    return {
        id = #combos + 1,
        counterIndex = counterIndex,
        attacker = comboMeta.attacker,
        defender = comboMeta.defender,
        startFrame = frameNumber,
        endFrame = frameNumber,
        totalHits = 0,
        lastCounter = 0,
        lastSnapshot = baselineSnapshot,
        hits = {},
        postComboChanges = {},
    }
end

local function write_report_to_file(stopFrame)
    local p1Name = get_char_name(read_u8(P1_CHAR_ID))
    local p2Name = get_char_name(read_u8(P2_CHAR_ID))
    local stamp = os.date("%Y%m%d_%H%M%S")
    local outputPath = OUTPUT_FOLDER .. "/" .. OUTPUT_PREFIX .. stamp .. ".txt"

    pcall(function()
        os.execute('mkdir "' .. OUTPUT_FOLDER .. '"')
    end)

    local file = io.open(outputPath, "w")
    if not file then
        print("[ComboMonitor] Could not open output file: " .. outputPath)
        return
    end

    file:write("Street Fighter III: 3rd Strike - Combo Memory Delta Monitor\n")
    file:write(string.format("Matchup: %s (P1) vs %s (P2)\n", p1Name, p2Name))
    file:write(string.format("Stop frame: %d\n", stopFrame))
    file:write(string.format("Recorded combos: %d\n\n", #combos))

    if #combos == 0 then
        file:write("No combos were captured during this recording window.\n")
    end

    for c = 1, #combos do
        local combo = combos[c]
        file:write(string.format(
            "Combo %d | %s -> %s | Frames %d to %d | Hits %d\n",
            combo.id,
            combo.attacker,
            combo.defender,
            combo.startFrame,
            combo.endFrame,
            combo.totalHits
        ))

        if #combo.hits == 0 then
            file:write("  (No hit snapshots stored)\n")
        end

        for h = 1, #combo.hits do
            local hit = combo.hits[h]
            file:write(string.format(
                "  Hit %d at frame %d | Changed locations: %d\n",
                hit.hitNumber,
                hit.frame,
                #hit.changes
            ))

            if #hit.changes == 0 then
                file:write("    - (no monitored value changed at this hit sample)\n")
            end

            for i = 1, #hit.changes do
                local ch = hit.changes[i]
                file:write(string.format(
                    "    - [%s] %s: %s -> %s\n",
                    to_hex(ch.addr, 4),
                    ch.key,
                    format_value(ch.oldValue, ch.size),
                    format_value(ch.newValue, ch.size)
                ))
            end
        end

        if combo.postComboChanges and #combo.postComboChanges > 0 then
            file:write(string.format(
                "  Post-combo cleanup changes: %d\n",
                #combo.postComboChanges
            ))
            for i = 1, #combo.postComboChanges do
                local ch = combo.postComboChanges[i]
                file:write(string.format(
                    "    - [%s] %s: %s -> %s\n",
                    to_hex(ch.addr, 4),
                    ch.key,
                    format_value(ch.oldValue, ch.size),
                    format_value(ch.newValue, ch.size)
                ))
            end
        end

        file:write("\n")
    end

    file:close()
    print("[ComboMonitor] Report saved to: " .. outputPath)
end

local function stop_recording(frameNumber)
    if currentCombo and prevSnapshot then
        finalize_combo(frameNumber, prevSnapshot)
    end

    recording = false
    write_report_to_file(frameNumber)
    print(string.format("[ComboMonitor] Recording OFF at frame %d", frameNumber))
end

local function read_toggle_pressed()
    local hotkey = false
    if input and input.get then
        local keys = input.get()
        if keys and (keys["F1"] or keys["f1"]) then
            hotkey = true
        end
    end

    local pad = nil
    if joypad and joypad.get then
        pad = joypad.get(1)
        if not pad then
            pad = joypad.get()
        end
    end

    local padToggle = false
    if pad then
        local coinPressed = pad["P1 Coin"] or pad["P1 Select"]
        padToggle = pad["P1 Start"] and coinPressed
    end

    return hotkey or padToggle
end

local function process_recording_frame(frameNumber)
    local currentSnapshot = capture_snapshot()
    local currentCounters = get_combo_counters()

    if not prevSnapshot then
        prevSnapshot = currentSnapshot
    end

    local activeIndex = nil
    if currentCombo then
        activeIndex = currentCombo.counterIndex
    else
        for i = 1, #currentCounters do
            if prevCounters[i] == 0 and currentCounters[i] > 0 then
                activeIndex = i
                break
            end
        end
        if not activeIndex then
            for i = 1, #currentCounters do
                if currentCounters[i] > prevCounters[i] and currentCounters[i] > 0 then
                    activeIndex = i
                    break
                end
            end
        end

        if activeIndex then
            currentCombo = create_combo(activeIndex, frameNumber, prevSnapshot)
            register_hit(currentCombo, currentCounters[activeIndex], frameNumber, currentSnapshot)
        end
    end

    if currentCombo then
        local idx = currentCombo.counterIndex
        local comboCount = currentCounters[idx]

        if comboCount > currentCombo.lastCounter then
            register_hit(currentCombo, comboCount, frameNumber, currentSnapshot)
        end

        if comboCount == 0 and prevCounters[idx] > 0 then
            finalize_combo(frameNumber, currentSnapshot)
        end
    end

    prevSnapshot = currentSnapshot
    prevCounters = currentCounters
end

local function draw_status(frameNumber)
    local p1Name = get_char_name(read_u8(P1_CHAR_ID))
    local p2Name = get_char_name(read_u8(P2_CHAR_ID))
    local state = recording and "REC" or "IDLE"
    local comboText = "none"

    if currentCombo then
        comboText = string.format(
            "Combo %d (%s -> %s) hits:%d",
            currentCombo.id,
            currentCombo.attacker,
            currentCombo.defender,
            currentCombo.totalHits
        )
    end

    safe_gui_text(8, 8, string.format("SF3 Combo Monitor [%s]", state))
    safe_gui_text(8, 18, "Toggle: F1 or P1 Start+Coin")
    safe_gui_text(8, 28, string.format("Match: %s vs %s", p1Name, p2Name))
    safe_gui_text(8, 38, string.format("Combos logged: %d", #combos))
    safe_gui_text(8, 48, string.format("Active: %s", comboText))
    safe_gui_text(8, 58, string.format("Frame: %d", frameNumber))
end

print("[ComboMonitor] Loaded.")
print("[ComboMonitor] Toggle recording: F1 (fallback: P1 Start + P1 Coin/Select)")

while true do
    local frameNumber = now_frame(lastFrameNumber)
    lastFrameNumber = frameNumber

    local togglePressed = read_toggle_pressed()
    if togglePressed and not prevTogglePressed then
        if recording then
            stop_recording(frameNumber)
        else
            start_recording(frameNumber)
        end
    end
    prevTogglePressed = togglePressed

    if recording then
        process_recording_frame(frameNumber)
    end

    draw_status(frameNumber)
    emu.frameadvance()
end