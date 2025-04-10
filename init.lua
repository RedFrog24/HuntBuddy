-- huntbuddy.lua
-- Created by: RedFrog
-- Original creation date: 03/23/2024
-- Version: 2.2.1
-- Thank you to Grimmier for assistance and his themes
-- ToDo List: add zones by server, EMU server, and TLP for Live
-- Add Keyed filter, add 'key' Column
-- select row?

local mq = require("mq")
local ImGui = require("ImGui")
local Icons = require('mq.ICONS')
local Themes = require('huntbuddy.theme_loader')
local ThemeData = require('huntbuddy.themes')
local zones = require('huntbuddy.zones') -- Zones, expansionOrder, and expansionList from here

-- State variables
local filterName = ""
local filterZemMin = 0.0
local filterZemMax = 5.0
local filterLevelMin = 1
local filterLevelMax = 100
local openGUI = true
local currentSortSpecs = nil
local useShortNames = false
local selectedExpansion = "DoN"
local currentTheme = "Grape" -- Default, will be overridden by saved value
local showHotzonesOnly = false
local removeCities = false
local isLiveMode = false -- Default to EMU

local ColumnID_Name = 0
local ColumnID_LevelRange = 1
local ColumnID_ZEM = 2
local ColumnID_Hotzone = 3
local ColumnID_Favorites = 4

-- Settings file path
local settingsFile = mq.TLO.MacroQuest.Path() .. "\\HuntBuddySettings.ini"

-- Load saved settings
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
    -- Load favorites
    for _, zone in ipairs(zones.zones) do
        local isFavorite = mq.TLO.Ini(settingsFile, "Favorites", zone.shortName)
        zone.isFavorite = (isFavorite() == "1")
    end
end

-- Save settings
local function SaveSettings()
    mq.cmdf('/ini "%s" "Settings" "Theme" "%s"', settingsFile, currentTheme)
    -- Save favorites
    for _, zone in ipairs(zones.zones) do
        mq.cmdf('/ini "%s" "Favorites" "%s" "%d"', settingsFile, zone.shortName, zone.isFavorite and 1 or 0)
    end
end

-- Reset filters function
local function ResetFilters()
    filterName = ""
    filterZemMin = 0.0
    filterZemMax = 5.0
    filterLevelMin = 1
    filterLevelMax = 100
    selectedExpansion = "DoN"
    showHotzonesOnly = false
    removeCities = false
    isLiveMode = false
    useShortNames = false
end

-- Sorting function
local function CompareWithSortSpecs(a, b)
    for n = 1, currentSortSpecs.SpecsCount, 1 do
        local sortSpec = currentSortSpecs:Specs(n)
        local delta = 0
        if sortSpec.ColumnUserID == ColumnID_Name then
            local aName = useShortNames and a.shortName or a.fullName
            local bName = useShortNames and b.shortName or b.fullName
            if aName < bName then delta = -1 elseif bName < aName then delta = 1 else delta = 0 end
        elseif sortSpec.ColumnUserID == ColumnID_LevelRange then
            delta = a.levelMin - b.levelMin
        elseif sortSpec.ColumnUserID == ColumnID_ZEM then
            local aZem = isLiveMode and a.zem.live or a.zem.emu
            local bZem = isLiveMode and b.zem.live or b.zem.emu
            if aZem == "--" and bZem == "--" then delta = 0
            elseif aZem == "--" then delta = 1
            elseif bZem == "--" then delta = -1
            else delta = aZem - bZem end
        elseif sortSpec.ColumnUserID == ColumnID_Hotzone then
            delta = (a.isHotzone and 1 or 0) - (b.isHotzone and 1 or 0)
        elseif sortSpec.ColumnUserID == ColumnID_Favorites then
            delta = (a.isFavorite and 1 or 0) - (b.isFavorite and 1 or 0)
        end
        if delta ~= 0 then
            if sortSpec.SortDirection == ImGuiSortDirection.Ascending then return delta < 0 end
            return delta > 0
        end
    end
    return false
end

-- Extract theme names from ThemeData
local function GetThemeNames()
    local names = {}
    for _, theme in ipairs(ThemeData.Theme) do
        table.insert(names, theme.Name)
    end
    return names
end
local themeNames = GetThemeNames()

-- Draw function
local function DrawZoneSelector()
    if not openGUI then return end
    
    local success, err = pcall(function()
        local ColorCount, StyleCount = Themes.StartTheme(currentTheme, ThemeData)

        local isOpen = ImGui.Begin("HuntBuddy 2.2.1", true)
        if not isOpen then 
            ImGui.End()
            Themes.EndTheme(ColorCount, StyleCount)
            openGUI = false
            return 
        end

        ImGui.Text("Theme:")
        ImGui.SameLine()
        ImGui.SetNextItemWidth(150)
        if ImGui.BeginCombo("##Theme", currentTheme) then
            for _, themeName in ipairs(themeNames) do
                local isSelected = (themeName == currentTheme)
                if ImGui.Selectable(themeName, isSelected) then
                    currentTheme = themeName
                    SaveSettings()
                end
                if isSelected then ImGui.SetItemDefaultFocus() end
            end
            ImGui.EndCombo()
        end

        ImGui.Separator()

        ImGui.Text("Filters:")
        local labelWidth = 85
        ImGui.Text("Zone Name:") ImGui.SameLine(labelWidth)
        ImGui.SetNextItemWidth(250)
        filterName = ImGui.InputText("##ZoneName", filterName)

        ImGui.Text("ZEM:") ImGui.SameLine(labelWidth)
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text("Zone Experience Modifier")
            ImGui.EndTooltip()
        end
        ImGui.Text("Min") ImGui.SameLine()
        ImGui.SetNextItemWidth(90)
        filterZemMin, _ = ImGui.InputFloat("##ZemMin", filterZemMin, 0.1, 1.0, "%.2f")
        ImGui.SameLine(0, 8)
        ImGui.Text("Max") ImGui.SameLine()
        ImGui.SetNextItemWidth(90)
        filterZemMax, _ = ImGui.InputFloat("##ZemMax", filterZemMax, 0.1, 1.0, "%.2f")

        ImGui.Text("Level:") ImGui.SameLine(labelWidth)
        ImGui.Text("Min") ImGui.SameLine()
        ImGui.SetNextItemWidth(90)
        filterLevelMin, _ = ImGui.InputInt("##LevelMin", filterLevelMin, 1, 10)
        ImGui.SameLine(0, 8)
        ImGui.Text("Max") ImGui.SameLine()
        ImGui.SetNextItemWidth(90)
        filterLevelMax, _ = ImGui.InputInt("##LevelMax", filterLevelMax, 1, 10)

        ImGui.Text("Expansion:") ImGui.SameLine(labelWidth)
        ImGui.SetNextItemWidth(250)
        if ImGui.BeginCombo("##Expansion", selectedExpansion) then
            for _, exp in ipairs(zones.expansionList) do
                local isSelected = (exp == selectedExpansion)
                if ImGui.Selectable(exp, isSelected) then selectedExpansion = exp end
                if isSelected then ImGui.SetItemDefaultFocus() end
            end
            ImGui.EndCombo()
        end

        if filterZemMin < 0 then filterZemMin = 0 end
        if filterZemMax < filterZemMin then filterZemMax = filterZemMin end
        if filterLevelMin < 1 then filterLevelMin = 1 end
        if filterLevelMax < filterLevelMin then filterLevelMax = filterLevelMin end

        ImGui.Text("Display Mode:")
        ImGui.SameLine()
        ImGui.PushID("isLiveMode")
        if not isLiveMode then
            ImGui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), "EMU")
            ImGui.SameLine()
            ImGui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), Icons.FA_TOGGLE_OFF)
            if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then
                isLiveMode = not isLiveMode
            end
            ImGui.SameLine()
            ImGui.Text("LIVE")
        else
            ImGui.Text("EMU")
            ImGui.SameLine()
            ImGui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), Icons.FA_TOGGLE_ON)
            if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then
                isLiveMode = not isLiveMode
            end
            ImGui.SameLine()
            ImGui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), "LIVE")
        end
        ImGui.PopID()

        ImGui.Text("Short Names:") ImGui.SameLine()
        ImGui.PushID("useShortNames")
        if useShortNames then
            ImGui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), Icons.FA_TOGGLE_ON)
        else
            ImGui.TextColored(ImVec4(1.0, 0.0, 0.0, 1.0), Icons.FA_TOGGLE_OFF)
        end
        if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then
            useShortNames = not useShortNames
        end
        ImGui.PopID()

        ImGui.Text("Hotzones Only:") ImGui.SameLine()
        ImGui.PushID("showHotzonesOnly")
        if showHotzonesOnly then
            ImGui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), Icons.FA_TOGGLE_ON)
        else
            ImGui.TextColored(ImVec4(1.0, 0.0, 0.0, 1.0), Icons.FA_TOGGLE_OFF)
        end
        if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then
            showHotzonesOnly = not showHotzonesOnly
        end
        ImGui.PopID()

        ImGui.Text("Remove Cities:") ImGui.SameLine()
        ImGui.PushID("removeCities")
        if removeCities then
            ImGui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), Icons.FA_TOGGLE_ON)
        else
            ImGui.TextColored(ImVec4(1.0, 0.0, 0.0, 1.0), Icons.FA_TOGGLE_OFF)
        end
        if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then
            removeCities = not removeCities
        end
        ImGui.PopID()

        ImGui.Separator()

        -- Count visible zones
        local visibleZoneCount = 0
        local maxExpansionLevel = isLiveMode and zones.expansionOrder["Live"] or zones.expansionOrder["DoN"]
        for _, zone in ipairs(zones.zones) do
            local zoneExpansionLevel = zones.expansionOrder[zone.expansion]
            if zoneExpansionLevel <= maxExpansionLevel then
                local displayName = useShortNames and zone.shortName or zone.fullName
                local zemValue = isLiveMode and zone.zem.live or zone.zem.emu
                local nameMatch = filterName == "" or string.find(string.lower(displayName), string.lower(filterName))
                local zemMatch = (zemValue == "--" and filterZemMin <= 0) or (zemValue ~= "--" and zemValue >= filterZemMin and zemValue <= filterZemMax)
                local levelMatch = (zone.levelMin <= filterLevelMax) and (zone.levelMax >= filterLevelMin)
                local hotzoneMatch = not showHotzonesOnly or zone.isHotzone
                local cityMatch = not removeCities or not zone.isCity
                if nameMatch and zemMatch and levelMatch and hotzoneMatch and cityMatch then
                    visibleZoneCount = visibleZoneCount + 1
                end
            end
        end

        ImGui.Text("Zones: " .. visibleZoneCount)
        ImGui.SameLine()
        ImGui.SetCursorPosX(ImGui.GetWindowWidth() - 120)
        if ImGui.Button("Reset Filters") then
            ResetFilters()
        end
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text("Reset All Filters")
            ImGui.EndTooltip()
        end

        ImGui.BeginChild("ZoneTableChild", ImVec2(0, 300), true)
        if ImGui.BeginTable("ZoneTable", 5, ImGuiTableFlags.Sortable + ImGuiTableFlags.Resizable + ImGuiTableFlags.Borders) then
            ImGui.TableSetupColumn("Zone Name", ImGuiTableColumnFlags.DefaultSort, 300.0, ColumnID_Name) -- Even wider
            ImGui.TableSetupColumn("Level Range", ImGuiTableColumnFlags.DefaultSort, 0.0, ColumnID_LevelRange)
            ImGui.TableSetupColumn("ZEM", ImGuiTableColumnFlags.DefaultSort, 0.0, ColumnID_ZEM)
            ImGui.TableSetupColumn(Icons.FA_FIRE, ImGuiTableColumnFlags.DefaultSort, 20.0, ColumnID_Hotzone) -- Even smaller
            ImGui.TableSetupColumn(Icons.FA_STAR, ImGuiTableColumnFlags.DefaultSort, 20.0, ColumnID_Favorites) -- Even smaller
            ImGui.TableHeadersRow()

            -- Hotzone column tooltip
            ImGui.TableSetColumnIndex(ColumnID_Hotzone)
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.Text("Hotzone")
                ImGui.EndTooltip()
            end

            -- Favorites column tooltip
            ImGui.TableSetColumnIndex(ColumnID_Favorites)
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.Text("Favorites")
                ImGui.EndTooltip()
            end

            local sortSpecs = ImGui.TableGetSortSpecs()
            if sortSpecs and sortSpecs.SpecsDirty then
                currentSortSpecs = sortSpecs
                table.sort(zones.zones, CompareWithSortSpecs)
                currentSortSpecs = nil
                sortSpecs.SpecsDirty = false
            end

            for _, zone in ipairs(zones.zones) do
                local zoneExpansionLevel = zones.expansionOrder[zone.expansion]
                if zoneExpansionLevel <= maxExpansionLevel then
                    local displayName = useShortNames and zone.shortName or zone.fullName
                    local zemValue = isLiveMode and zone.zem.live or zone.zem.emu
                    local nameMatch = filterName == "" or string.find(string.lower(displayName), string.lower(filterName))
                    local zemMatch = (zemValue == "--" and filterZemMin <= 0) or (zemValue ~= "--" and zemValue >= filterZemMin and zemValue <= filterZemMax)
                    local levelMatch = (zone.levelMin <= filterLevelMax) and (zone.levelMax >= filterLevelMin)
                    local hotzoneMatch = not showHotzonesOnly or zone.isHotzone
                    local cityMatch = not removeCities or not zone.isCity

                    if nameMatch and zemMatch and levelMatch and hotzoneMatch and cityMatch then
                        ImGui.TableNextRow()
                        ImGui.TableNextColumn()
                        if ImGui.Selectable(displayName, false, ImGuiSelectableFlags.SpanAllColumns) then
                            zone.isFavorite = not zone.isFavorite
                            SaveSettings()
                            mq.cmdf("/echo %s %s as favorite", zone.shortName, zone.isFavorite and "marked" or "unmarked")
                        end
                        ImGui.TableNextColumn()
                        ImGui.Text("%d-%d", zone.levelMin, zone.levelMax)
                        ImGui.TableNextColumn()
                        ImGui.Text(tostring(zemValue))
                        ImGui.TableNextColumn()
                        if zone.isHotzone then
                            ImGui.TextColored(ImVec4(1.0, 0.5, 0.0, 1.0), Icons.FA_FIRE)
                        else
                            ImGui.Text(" ")
                        end
                        ImGui.TableNextColumn()
                        if zone.isFavorite then
                            ImGui.TextColored(ImVec4(1.0, 1.0, 0.0, 1.0), Icons.FA_STAR)
                        else
                            ImGui.Text(" ")
                        end
                    end
                end
            end
            ImGui.EndTable()
        end
        ImGui.EndChild()

        ImGui.End()
        Themes.EndTheme(ColorCount, StyleCount)
    end)
    if not success then
        mq.cmdf("/echo ImGui Error: %s", tostring(err))
    end
end

-- Main loop
local function main()
    LoadSettings()
    mq.imgui.init("HuntBuddy", DrawZoneSelector)
    while openGUI do
        mq.delay(100)
    end
    mq.cmdf("/echo HuntBuddy script terminated")
end

main()