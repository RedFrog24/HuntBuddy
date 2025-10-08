-- huntbuddy.lua
-- Created by: RedFrog
-- Original creation date: 03/23/2024
-- Version: 2.3.87
-- Changelog:
-- Version 2.3.87: Fixed Platinum button Push/PopStyleColor mismatch on toggle (always push Text color, conditional value)
-- 2.3.86: Fixed EMU/Lazarus expansion caps & duplicate version logic:
--         - EMU shows up to DoN, Lazarus up to OoW, Live shows all.
--         - For dupes: EMU/Lazarus prefer classic; Live prefers live.
-- 2.3.85: Rewrote sorting to use precomputed string keys + key inversion for DESC. Fixes rare "invalid order function" on ZEM.
-- 2.3.84: Added ZEM sorting (numbers for current server mode; "--" always sinks).
-- 2.3.83: Precomputed level sort key; fixed level sort crash.
-- 2.3.82: Level Range sorting (min → max, alpha tie-break).
-- 2.3.81: Rock-solid alpha sort for Zone Name (articles/punct stripped, case-insensitive).
-- 2.3.74–.80: UI centering, platinum tint, ImVec constructors, guards & fallbacks.

local mq = require("mq")
local ImGui = require("ImGui")
local Icons = require('mq.ICONS')
local Themes = require('huntbuddy.theme_loader')
local ThemeData = require('huntbuddy.themes')
local zones = require('huntbuddy.zones')

--========================
-- Header icon centering
--========================
local function centerIconInCell(icon, tooltipText)
    local cellWidth = ImGui.GetContentRegionAvailVec().x
    local textWidth = ImGui.CalcTextSize(icon)
    local cursorX = ImGui.GetCursorPosX()
    ImGui.SetCursorPosX(cursorX + (cellWidth - textWidth) * 0.5)
    ImGui.Text(icon)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.Text(tooltipText)
        ImGui.EndTooltip()
    end
end

--========================
-- Body cell helpers
--========================
local function centerNextItemInCell(itemWidth)
    local avail = ImGui.GetContentRegionAvailVec().x
    local curX = ImGui.GetCursorPosX()
    local padX = (avail - itemWidth) * 0.5
    if padX > 0 then ImGui.SetCursorPosX(curX + padX) end
end

local function drawCenteredIconInCell(icon, color)
    local textW = ImGui.CalcTextSize(icon)
    centerNextItemInCell(textW)
    if color then ImGui.PushStyleColor(ImGuiCol.Text, color) end
    ImGui.Text(icon)
    if color then ImGui.PopStyleColor() end
end

--========================
-- State
--========================
local filterName, filterZemMin, filterZemMax = "", 0.0, 5.0
local filterLevelMin, filterLevelMax = 1, 125
local openGUI, useShortNames = true, false
local selectedExpansion, currentTheme, serverMode = "DoN", "Grape", "EMU"
local showHotzonesOnly, removeCities = false, false
local showPlatinumOnly, showFavoritesOnly = false, false
local showExpansionOnly, showOutdoorOnly = false, false

local ColumnID_Name       = 0
local ColumnID_LevelRange = 1
local ColumnID_ZEM        = 2
local ColumnID_Hotzone    = 3
local ColumnID_Favorites  = 4
local ColumnID_Platinum   = 5

local settingsFile = mq.configDir .. "\\HuntBuddySettings.ini"

--========================
-- Settings
--========================
local function LoadSettings()
    local savedTheme = mq.TLO.Ini(settingsFile, "Settings", "Theme")
    if savedTheme() and savedTheme ~= "" then
        for _, theme in ipairs(ThemeData.Theme) do
            if theme.Name == savedTheme() then
                currentTheme = savedTheme()
                break
            end
        end
    end
    for i, zone in ipairs(zones.zones) do
        local missing = {}
        if zone.shortName == nil then table.insert(missing, "shortName") end
        if zone.fullName == nil then table.insert(missing, "fullName") end
        if zone.expansion == nil then table.insert(missing, "expansion") end
        if zone.zem == nil then table.insert(missing, "zem") end
        if zone.levelmin == nil then table.insert(missing, "levelmin") end
        if zone.levelmax == nil then table.insert(missing, "levelmax") end
        if zone.hotzone == nil then table.insert(missing, "hotzone") end
        if zone.city == nil then table.insert(missing, "city") end
        if zone.indoor == nil then table.insert(missing, "indoor") end
        if zone.isFavorite == nil then table.insert(missing, "isFavorite") end
        if zone.isPlatinum == nil then table.insert(missing, "isPlatinum") end
        if #missing > 0 then
            mq.cmdf("/echo Warning: Invalid zone at index %d (shortName: %s, missing: %s)", i, tostring(zone.shortName), table.concat(missing, ", "))
            goto continue
        end
        local fav = mq.TLO.Ini(settingsFile, "Favorites", zone.shortName)()
        local plat = mq.TLO.Ini(settingsFile, "Platinum", zone.shortName)()
        zone.isFavorite  = (fav == "1") or zone.isFavorite or false
        zone.isPlatinum = (plat == "1") or zone.isPlatinum or false
        zone.zem = zone.zem or { emu = "--", live = "--", lazarus = "--" }
        zone.zem.emu = zone.zem.emu or "--"
        zone.zem.live = zone.zem.live or "--"
        zone.zem.lazarus = zone.zem.lazarus or "--"
        ::continue::
    end
end

local function SaveZoneSettings(zone)
    mq.cmdf('/ini "%s" "Favorites" "%s" "%d"', settingsFile, zone.shortName, zone.isFavorite and 1 or 0)
    mq.cmdf('/ini "%s" "Platinum" "%s" "%d"',  settingsFile, zone.shortName, zone.isPlatinum and 1 or 0)
end

local function SaveThemeSetting()
    mq.cmdf('/ini "%s" "Settings" "Theme" "%s"', settingsFile, currentTheme)
end

local function ResetFilters()
    filterName, filterZemMin, filterZemMax = "", 0.0, 5.0
    filterLevelMin, filterLevelMax = 1, 125
    selectedExpansion = "DoN"
    showHotzonesOnly, removeCities = false, false
    serverMode, useShortNames = "EMU", false
    showPlatinumOnly, showFavoritesOnly = false, false
    showExpansionOnly, showOutdoorOnly = false, false
end

--========================
-- Sorting helpers (string-only keys)
--========================
local function to_numid(id)
    local n = tonumber(id)
    return n and n or 0
end

local function normalize_full_name(name)
    name = tostring(name or "")
    name = name:gsub("^%s+", "")
    local lower = name:lower()
    lower = lower:gsub("^the%s+", ""):gsub("^an%s+", ""):gsub("^a%s+", "")
    lower = lower:gsub("[%p%s]+", "")
    return lower
end

local function normalize_short_name(name)
    name = tostring(name or "")
    local lower = name:lower()
    lower = lower:gsub("[%p%s]+", "")
    return lower
end

-- Build alpha sort key (primary + tie breakers)
local function build_alpha_key(zone, usingShort)
    local full  = tostring(zone.fullName or "")
    local short = tostring(zone.shortName or "")
    local idnum = to_numid(zone.id)
    local idpad = string.format("%08d", idnum % 100000000)
    if usingShort then
        local primary = normalize_short_name(short)
        return table.concat({primary, short:lower(), full:lower(), idpad}, "|")
    else
        local primary = normalize_full_name(full)
        return table.concat({primary, full:lower(), short:lower(), idpad}, "|")
    end
end

-- Build level sort key "min|max|alpha"
local function build_level_key(zone)
    local amin = tonumber(zone.levelmin) or 0
    local amax = tonumber(zone.levelmax) or 0
    local minpad = string.format("%05d", amin % 100000)
    local maxpad = string.format("%05d", amax % 100000)
    return table.concat({minpad, maxpad, zone._alphaKey or ""}, "|")
end

-- Get ZEM number for active server mode
local function get_zem_number_for_mode(zone, mode)
    local v = (mode == "Live") and zone.zem.live
          or (mode == "Lazarus") and zone.zem.lazarus
          or zone.zem.emu
    if type(v) == "number" then return v end
    if type(v) == "string" then
        local n = tonumber(v)
        if n then return n end
    end
    return nil
end

-- Precompute ZEM keys (asc/desc) and display
local function build_zem_keys(zone, mode)
    local v = get_zem_number_for_mode(zone, mode)
    if v then
        local val = math.floor(v * 1000 + 0.5)               -- 3 decimals precision
        local pad = string.format("%05d", val)                -- 0..5000 typical
        local inv = string.format("%05d", 99999 - val)       -- inverted for DESC
        zone._zemKeyAsc  = "0|"..pad.."|"..(zone._alphaKey or "")
        zone._zemKeyDesc = "0|"..inv.."|"..(zone._alphaKey or "")
        zone._zemDisp    = v
    else
        -- Missing -> always bottom
        zone._zemKeyAsc  = "1|99999|"..(zone._alphaKey or "")
        zone._zemKeyDesc = "1|99999|"..(zone._alphaKey or "")
        zone._zemDisp    = "--"
    end
end

-- Invert a string's bytes so sorting ascending on the inverted key == descending on original
local function invert_key_bytes(s)
    local t = {}
    for i = 1, #s do t[i] = string.char(255 - string.byte(s, i)) end
    return table.concat(t)
end

-- Build a sortable rows array to avoid tricky comparators
local function build_sorted_by_key(t, asc)
    -- t: array of {key=..., idx=...}
    if not asc then
        for i = 1, #t do t[i].key = invert_key_bytes(t[i].key or "") end
    end
    table.sort(t, function(a, b)
        local ak = a.key or ""
        local bk = b.key or ""
        return ak < bk
    end)
end

--========================
-- Expansion caps & duplicates (NEW in 2.3.86)
--========================
local function expIndex(label)
    if not label then return nil end
    return zones.expansionOrder[label]
        or zones.expansionOrder[(label == "Dragons of Norrath") and "DoN" or label]
        or zones.expansionOrder[(label == "Omens of War") and "OoW" or label]
end

-- Max expansion per server mode (inclusive).
local function maxExpForMode(mode)
    if mode == "EMU" then
        -- EMU shows up to DoN
        return expIndex("DoN") or expIndex("Dragons of Norrath") or 10
    elseif mode == "Lazarus" then
        -- Lazarus shows up to OoW
        return expIndex("OoW") or expIndex("Omens of War") or 9
    end
    return 999 -- Live: no cap
end

-- Does this shortName have BOTH a classic and live entry?
-- Treat nil/unknown version as "classic" for our purposes.
local function hasClassicLivePair(shortName)
    if not shortName then return false end
    local hasClassic, hasLive = false, false
    for _, z in ipairs(zones.zones) do
        if z.shortName == shortName then
            if z.version == "live" then
                hasLive = true
            else
                hasClassic = true
            end
            if hasClassic and hasLive then return true end
        end
    end
    return false
end

-- Server/Expansion filtering with duplicate-aware version preference.
local function FilterZonesByServerAndExpansion(zone)
    if not zone or not zone.expansion then return false end

    local zoneExpansionLevel = zones.expansionOrder[zone.expansion] or 999
    local modeMax = maxExpForMode(serverMode)

    -- Apply per-mode expansion cap (Live has no cap here)
    if serverMode ~= "Live" and zoneExpansionLevel > modeMax then
        return false
    end

    -- If no classic/live twin exists, keep the zone regardless of version.
    local dupPair = hasClassicLivePair(zone.shortName)
    if not dupPair then
        return true
    end

    -- Duplicate exists: prefer one by mode.
    if serverMode == "Live" then
        -- Live prefers 'live'
        return zone.version == "live"
    else
        -- EMU & Lazarus prefer classic (anything not flagged 'live')
        return zone.version ~= "live"
    end
end

--========================
-- UI
--========================
local function DrawZoneSelector()
    if not openGUI then return end

    local ColorCount, StyleCount = Themes.StartTheme(currentTheme, ThemeData)
    ImGui.SetNextWindowSize(ImVec2(600, 800), ImGuiCond.FirstUseEver)
    local isOpen, shouldDraw = ImGui.Begin("HuntBuddy 2.3.87", true, ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoScrollbar)
    openGUI = isOpen

    if not shouldDraw then
        ImGui.End()
        Themes.EndTheme(ColorCount, StyleCount)
        return
    end

    -- Header
    ImGui.BeginChild("HeaderSection", ImVec2(0, 270), true)

    ImGui.Text("Theme:")
    ImGui.SameLine()
    ImGui.SetNextItemWidth(150)
    if ImGui.BeginCombo("##Theme", currentTheme) then
        for _, theme in ipairs(ThemeData.Theme) do
            local isSelected = (theme.Name == currentTheme)
            if ImGui.Selectable(theme.Name, isSelected) then
                currentTheme = theme.Name
                SaveThemeSetting()
            end
            if isSelected then ImGui.SetItemDefaultFocus() end
        end
        ImGui.EndCombo()
    end

    ImGui.Separator()

    ImGui.Text("Server:")
    ImGui.SameLine()
    ImGui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), mq.TLO.EverQuest.Server() or "Unknown")
    ImGui.SameLine()
    ImGui.SetNextItemWidth(100)
    if ImGui.BeginCombo("##ServerMode", serverMode) then
        for _, mode in ipairs({"EMU", "Live", "Lazarus"}) do
            local isSelected = (mode == serverMode)
            if ImGui.Selectable(mode, isSelected) then serverMode = mode end
            if isSelected then ImGui.SetItemDefaultFocus() end
        end
        ImGui.EndCombo()
    end

    ImGui.Separator()

    local filterLabelWidth = 85
    ImGui.Text("Zone Name:") ImGui.SameLine(filterLabelWidth)
    ImGui.SetNextItemWidth(250)
    filterName = ImGui.InputText("##ZoneName", filterName)

    ImGui.Text("ZEM:") ImGui.SameLine(filterLabelWidth)
    if ImGui.IsItemHovered() then ImGui.BeginTooltip(); ImGui.Text("Zone Experience Modifier"); ImGui.EndTooltip() end
    ImGui.Text("Min") ImGui.SameLine()
    ImGui.SetNextItemWidth(90)
    filterZemMin, _ = ImGui.InputFloat("##ZemMin", filterZemMin, 0.1, 1.0, "%.2f")
    ImGui.SameLine(0, 8)
    ImGui.Text("Max") ImGui.SameLine()
    ImGui.SetNextItemWidth(90)
    filterZemMax, _ = ImGui.InputFloat("##ZemMax", filterZemMax, 0.1, 1.0, "%.2f")

    ImGui.Text("Level:") ImGui.SameLine(filterLabelWidth)
    ImGui.Text("Min") ImGui.SameLine()
    ImGui.SetNextItemWidth(90)
    filterLevelMin, _ = ImGui.InputInt("##LevelMin", filterLevelMin, 1, 10)
    ImGui.SameLine(0, 8)
    ImGui.Text("Max") ImGui.SameLine()
    ImGui.SetNextItemWidth(90)
    filterLevelMax, _ = ImGui.InputInt("##LevelMax", filterLevelMax, 1, 10)

    ImGui.Text("Expansion:") ImGui.SameLine(filterLabelWidth)
    ImGui.SetNextItemWidth(200)
    if ImGui.BeginCombo("##Expansion", selectedExpansion) then
        for _, exp in ipairs(zones.expansionList) do
            local isSelected = (exp == selectedExpansion)
            if ImGui.Selectable(exp, isSelected) then selectedExpansion = exp end
            if isSelected then ImGui.SetItemDefaultFocus() end
        end
        ImGui.EndCombo()
    end
    ImGui.SameLine()
    ImGui.Text("Expansion Only:") ImGui.SameLine()
    ImGui.PushID("showExpansionOnly")
    ImGui.TextColored(showExpansionOnly and ImVec4(0,1,0,1) or ImVec4(1,0,0,1), showExpansionOnly and Icons.FA_TOGGLE_ON or Icons.FA_TOGGLE_OFF)
    if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then showExpansionOnly = not showExpansionOnly end
    ImGui.PopID()

    local windowWidth = ImGui.GetWindowWidth()
    local leftOffset = 50
    local midOffset = windowWidth / 2 + 50

    ImGui.SetCursorPosX(leftOffset)
    ImGui.Text("Hotzones Only:") ImGui.SameLine()
    ImGui.PushID("showHotzonesOnly")
    ImGui.TextColored(showHotzonesOnly and ImVec4(0,1,0,1) or ImVec4(1,0,0,1), showHotzonesOnly and Icons.FA_TOGGLE_ON or Icons.FA_TOGGLE_OFF)
    if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then showHotzonesOnly = not showHotzonesOnly end
    ImGui.PopID()

    ImGui.SameLine(midOffset)
    ImGui.Text("Platinum Only:") ImGui.SameLine()
    ImGui.PushID("showPlatinumOnly")
    ImGui.TextColored(showPlatinumOnly and ImVec4(0,1,0,1) or ImVec4(1,0,0,1), showPlatinumOnly and Icons.FA_TOGGLE_ON or Icons.FA_TOGGLE_OFF)
    if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then showPlatinumOnly = not showPlatinumOnly end
    ImGui.PopID()

    ImGui.SetCursorPosX(leftOffset)
    ImGui.Text("Remove Cities:") ImGui.SameLine()
    ImGui.PushID("removeCities")
    ImGui.TextColored(removeCities and ImVec4(0,1,0,1) or ImVec4(1,0,0,1), removeCities and Icons.FA_TOGGLE_ON or Icons.FA_TOGGLE_OFF)
    if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then removeCities = not removeCities end
    ImGui.PopID()

    ImGui.SameLine(midOffset)
    ImGui.Text("Outdoor Only:") ImGui.SameLine()
    ImGui.PushID("showOutdoorOnly")
    ImGui.TextColored(showOutdoorOnly and ImVec4(0,1,0,1) or ImVec4(1,0,0,1), showOutdoorOnly and Icons.FA_TOGGLE_ON or Icons.FA_TOGGLE_OFF)
    if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then showOutdoorOnly = not showOutdoorOnly end
    ImGui.PopID()

    ImGui.SetCursorPosX(leftOffset)
    ImGui.Text("Favorites Only:") ImGui.SameLine()
    ImGui.PushID("showFavoritesOnly")
    ImGui.TextColored(showFavoritesOnly and ImVec4(0,1,0,1) or ImVec4(1,0,0,1), showFavoritesOnly and Icons.FA_TOGGLE_ON or Icons.FA_TOGGLE_OFF)
    if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then showFavoritesOnly = not showFavoritesOnly end
    ImGui.PopID()

    ImGui.SameLine(midOffset)
    ImGui.Text("Short Names:") ImGui.SameLine()
    ImGui.PushID("useShortNames")
    ImGui.TextColored(useShortNames and ImVec4(0,1,0,1) or ImVec4(1,0,0,1), useShortNames and Icons.FA_TOGGLE_ON or Icons.FA_TOGGLE_OFF)
    if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then useShortNames = not useShortNames end
    ImGui.PopID()

    if filterZemMin < 0 then filterZemMin = 0 end
    if filterZemMax < filterZemMin then filterZemMax = filterZemMin end
    if filterLevelMin < 1 then filterLevelMin = 1 end
    if filterLevelMax < filterLevelMin then filterLevelMax = filterLevelMin end

    -- Visible zones
    local visibleZones, visibleZoneCount = {}, 0
    local maxExpansionLevel = zones.expansionOrder[selectedExpansion] or 999
    if not zones.expansionOrder[selectedExpansion] then
        mq.cmdf("/echo Warning: Selected expansion %s not found in expansionOrder", selectedExpansion)
        selectedExpansion = "DoN"
        maxExpansionLevel = zones.expansionOrder[selectedExpansion] or 999
    end
    for _, zone in ipairs(zones.zones) do
        if not (zone.shortName and zone.fullName and zone.expansion and zone.zem and zone.levelmin and zone.levelmax) then goto continue end
        local zoneExpansionLevel = zones.expansionOrder[zone.expansion]
        if not zoneExpansionLevel then goto continue end
        if showExpansionOnly and zone.expansion ~= selectedExpansion then goto continue end
        if zoneExpansionLevel > maxExpansionLevel then goto continue end

        local displayName = useShortNames and zone.shortName or zone.fullName
        local zemValue = (serverMode == "Live") and (zone.zem.live or "--")
            or ((serverMode == "Lazarus") and (zone.zem.lazarus or "--") or (zone.zem.emu or "--"))
        local nameMatch = (filterName == "") or string.find(string.lower(displayName), string.lower(filterName))
        local zemMatch  = (zemValue == "--" and filterZemMin <= 0) or (type(zemValue) == "number" and zemValue >= filterZemMin and zemValue <= filterZemMax)
        local levelMatch = (zone.levelmin <= filterLevelMax) and (zone.levelmax >= filterLevelMin)
        local hotzoneMatch = (not showHotzonesOnly) or (zone.hotzone or false)
        local cityMatch = (not removeCities) or not (zone.city or false)
        local favoritesMatch = (not showFavoritesOnly) or (zone.isFavorite or false)
        local platinumMatch  = (not showPlatinumOnly) or (zone.isPlatinum or false)
        local outdoorMatch   = (not showOutdoorOnly) or (zone.indoor == false)

        if nameMatch and zemMatch and levelMatch and hotzoneMatch and cityMatch and favoritesMatch and platinumMatch and outdoorMatch and FilterZonesByServerAndExpansion(zone) then
            zone.id = to_numid(zone.id)
            zone._alphaKey = build_alpha_key(zone, useShortNames)
            zone._levelKey = build_level_key(zone)
            build_zem_keys(zone, serverMode)
            table.insert(visibleZones, zone)
            visibleZoneCount = visibleZoneCount + 1
        end
        ::continue::
    end

    ImGui.Text("Zones: " .. visibleZoneCount)
    ImGui.SameLine()
    ImGui.SetCursorPosX(ImGui.GetWindowWidth() - 120)
    if ImGui.Button("Reset Filters") then ResetFilters() end
    if ImGui.IsItemHovered() then ImGui.BeginTooltip(); ImGui.Text("Reset All Filters"); ImGui.EndTooltip() end

    ImGui.EndChild()

    -- Table
    ImGui.BeginChild("ZoneTableChild", ImVec2(0, -1), true)

    if ImGui.BeginTable("ZoneTable",
        7,
        ImGuiTableFlags.Sortable + ImGuiTableFlags.Resizable + ImGuiTableFlags.Borders + ImGuiTableFlags.ScrollY) then

        -- Name, Level, ZEM sortable; others locked.
        ImGui.TableSetupColumn("Zone Name",
            ImGuiTableColumnFlags.WidthStretch + ImGuiTableColumnFlags.DefaultSort, 1.0, ColumnID_Name)
        ImGui.TableSetupColumn("Level Range",
            ImGuiTableColumnFlags.WidthFixed, 100.0, ColumnID_LevelRange)
        ImGui.TableSetupColumn("ZEM",
            ImGuiTableColumnFlags.WidthFixed, 100.0, ColumnID_ZEM)
        ImGui.TableSetupColumn("##Hotzone",
            ImGuiTableColumnFlags.WidthFixed + ImGuiTableColumnFlags.NoSort + ImGuiTableColumnFlags.NoSortAscending + ImGuiTableColumnFlags.NoSortDescending,
            30.0, ColumnID_Hotzone)
        ImGui.TableSetupColumn("##Favorites",
            ImGuiTableColumnFlags.WidthFixed + ImGuiTableColumnFlags.NoSort + ImGuiTableColumnFlags.NoSortAscending + ImGuiTableColumnFlags.NoSortDescending,
            30.0, ColumnID_Favorites)
        ImGui.TableSetupColumn("##Platinum",
            ImGuiTableColumnFlags.WidthFixed + ImGuiTableColumnFlags.NoSort + ImGuiTableColumnFlags.NoSortAscending + ImGuiTableColumnFlags.NoSortDescending,
            30.0, ColumnID_Platinum)
        ImGui.TableSetupColumn("##Pad",
            ImGuiTableColumnFlags.WidthFixed + ImGuiTableColumnFlags.NoSort + ImGuiTableColumnFlags.NoSortAscending + ImGuiTableColumnFlags.NoSortDescending,
            15.0)

        ImGui.TableNextRow(ImGuiTableRowFlags.Headers)
        ImGui.TableSetColumnIndex(ColumnID_Name)       ImGui.TableHeader("Zone Name")
        ImGui.TableSetColumnIndex(ColumnID_LevelRange) ImGui.TableHeader("Level Range")
        ImGui.TableSetColumnIndex(ColumnID_ZEM)        ImGui.TableHeader("ZEM")
        ImGui.TableSetColumnIndex(ColumnID_Hotzone)    centerIconInCell(Icons.FA_FIRE, "Hotzones")
        ImGui.TableSetColumnIndex(ColumnID_Favorites)  centerIconInCell(Icons.FA_STAR, "Favorites")
        ImGui.TableSetColumnIndex(ColumnID_Platinum)   centerIconInCell(Icons.FA_DATABASE, "Platinum")
        ImGui.TableSetColumnIndex(6)                   ImGui.Text("")

        -- Sort target & direction
        local sortSpecs = ImGui.TableGetSortSpecs()
        local sortTarget = "name"  -- "name" | "level" | "zem"
        local asc = true
        if sortSpecs and sortSpecs.SpecsCount and sortSpecs.SpecsCount > 0 then
            local primary = sortSpecs:Specs(1)
            if primary then
                if primary.ColumnUserID == ColumnID_LevelRange then
                    sortTarget = "level"
                elseif primary.ColumnUserID == ColumnID_ZEM then
                    sortTarget = "zem"
                else
                    sortTarget = "name"
                end
                asc = (primary.SortDirection == ImGuiSortDirection.Ascending)
            end
            if sortSpecs.SpecsDirty ~= nil then sortSpecs.SpecsDirty = false end
        end

        -- Build rows of (key, idx) then sort them with a simple comparator
        if #visibleZones > 1 then
            local rows = {}
            if sortTarget == "name" then
                for i, z in ipairs(visibleZones) do rows[#rows+1] = {key = z._alphaKey or "", idx = i} end
            elseif sortTarget == "level" then
                for i, z in ipairs(visibleZones) do rows[#rows+1] = {key = z._levelKey or "", idx = i} end
            else -- zem
                for i, z in ipairs(visibleZones) do
                    local key = asc and (z._zemKeyAsc or "") or (z._zemKeyDesc or "")
                    rows[#rows+1] = {key = key, idx = i}
                end
            end
            build_sorted_by_key(rows, true)                    -- always ascending on (possibly inverted) key
            if not asc and sortTarget ~= "zem" then            -- for name/level invert rows (desc) after building using raw keys
                for i = 1, #rows do rows[i].key = invert_key_bytes(rows[i].key or "") end
                table.sort(rows, function(a,b) return (a.key or "") < (b.key or "") end)
            end

            local sorted = {}
            for _, r in ipairs(rows) do sorted[#sorted+1] = visibleZones[r.idx] end
            visibleZones = sorted
        end

        -- Body rows
        for _, zone in ipairs(visibleZones) do
            ImGui.TableNextRow()

            ImGui.TableNextColumn()
            ImGui.Text((useShortNames and zone.shortName or zone.fullName) or "Unknown")

            ImGui.TableNextColumn()
            ImGui.Text("%d-%d", zone.levelmin or 0, zone.levelmax or 0)

            ImGui.TableNextColumn()
            local disp = zone._zemDisp
            if type(disp) == "number" then
                ImGui.Text(string.format("%.2f", disp))
            else
                ImGui.Text(tostring(disp or "--"))
            end

            ImGui.TableNextColumn()
            if zone.hotzone then
                drawCenteredIconInCell(Icons.FA_FIRE, ImVec4(1.0, 0.5, 0.0, 1.0))
            else
                drawCenteredIconInCell(" ", nil)
            end

            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Button,        ImVec4(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive,  ImVec4(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.Text,          ImVec4(1.0, 1.0, 0.0, 1.0))
            ImGui.PushID("Fav_" .. (zone.shortName or "unknown"))
            centerNextItemInCell(30)
            if ImGui.Button(zone.isFavorite and Icons.FA_STAR or " ", ImVec2(30, 20)) then
                zone.isFavorite = not zone.isFavorite
                SaveZoneSettings(zone)
            end
            ImGui.PopID()
            ImGui.PopStyleColor(4)

            ImGui.TableNextColumn()
            ImGui.PushID("Plat_" .. (zone.shortName or "unknown"))
            ImGui.PushStyleColor(ImGuiCol.Button,        ImVec4(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, ImVec4(0, 0, 0, 0))
            ImGui.PushStyleColor(ImGuiCol.ButtonActive,  ImVec4(0, 0, 0, 0))
            local wasPlatinum = zone.isPlatinum  -- Capture state before potential toggle
            if wasPlatinum then ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(1.0, 0.84, 0.0, 1.0)) end
            centerNextItemInCell(30)
            if ImGui.Button(wasPlatinum and Icons.FA_DATABASE or " ", ImVec2(30, 20)) then
                zone.isPlatinum = not zone.isPlatinum
                SaveZoneSettings(zone)
            end
            if wasPlatinum then ImGui.PopStyleColor() end
            ImGui.PopStyleColor(3)
            ImGui.PopID()
        end

        ImGui.EndTable()
    end
    ImGui.EndChild()

    ImGui.End()
    Themes.EndTheme(ColorCount, StyleCount)
end

--========================
-- Main
--========================
local function main()
    LoadSettings()
    mq.imgui.init("HuntBuddy", DrawZoneSelector)
    while openGUI do mq.delay(100) end
end

main()
