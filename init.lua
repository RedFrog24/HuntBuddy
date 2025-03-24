-- huntbuddy.lua
-- Created by: RedFrog
-- Original creation date: 03/23/2024
-- Thank you to Grimmier for assistance and his themes
-- ToDo List: add zones by server, EMU server, and TLP for Live
-- Tooltips
-- Add Keyed filter, add 'key' Column
-- reset filter button
-- select row?
-- favorite?

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
local currentTheme = "Grape"
local showHotzonesOnly = false
local removeCities = false
local isLiveMode = false -- Default to EMU

local ColumnID_Name = 0
local ColumnID_LevelRange = 1
local ColumnID_ZEM = 2
local ColumnID_Hotzone = 3

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

        openGUI = ImGui.Begin("HuntBuddy", true)
        if not openGUI then ImGui.End() return end

        ImGui.Text("Theme:")
        ImGui.SameLine()
        ImGui.SetNextItemWidth(150)
        if ImGui.BeginCombo("##Theme", currentTheme) then
            for _, themeName in ipairs(themeNames) do
                local isSelected = (themeName == currentTheme)
                if ImGui.Selectable(themeName, isSelected) then
                    currentTheme = themeName
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
            ImGui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), "EMU") -- Green EMU
            ImGui.SameLine()
            ImGui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), Icons.FA_TOGGLE_OFF) -- Green toggle, dot left
            if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then
                isLiveMode = not isLiveMode
            end
            ImGui.SameLine()
            ImGui.Text("LIVE") -- Default color
        else
            ImGui.Text("EMU") -- Default color
            ImGui.SameLine()
            ImGui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), Icons.FA_TOGGLE_ON) -- Green toggle, dot right
            if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then
                isLiveMode = not isLiveMode
            end
            ImGui.SameLine()
            ImGui.TextColored(ImVec4(0.0, 1.0, 0.0, 1.0), "LIVE") -- Green LIVE
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

        ImGui.Text("Zones:")
        ImGui.BeginChild("ZoneTableChild", ImVec2(0, 300), true)
        if ImGui.BeginTable("ZoneTable", 4, ImGuiTableFlags.Sortable + ImGuiTableFlags.Resizable + ImGuiTableFlags.Borders) then
            ImGui.TableSetupColumn("Zone Name", ImGuiTableColumnFlags.DefaultSort, 0.0, ColumnID_Name)
            ImGui.TableSetupColumn("Level Range", ImGuiTableColumnFlags.DefaultSort, 0.0, ColumnID_LevelRange)
            ImGui.TableSetupColumn("ZEM", ImGuiTableColumnFlags.DefaultSort, 0.0, ColumnID_ZEM)
            ImGui.TableSetupColumn("Hotzone", ImGuiTableColumnFlags.DefaultSort, 0.0, ColumnID_Hotzone)
            ImGui.TableHeadersRow()

            local sortSpecs = ImGui.TableGetSortSpecs()
            if sortSpecs and sortSpecs.SpecsDirty then
                currentSortSpecs = sortSpecs
                table.sort(zones.zones, CompareWithSortSpecs)
                currentSortSpecs = nil
                sortSpecs.SpecsDirty = false
            end

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
                        ImGui.TableNextRow()
                        ImGui.TableNextColumn()
                        if ImGui.Selectable(displayName, false, ImGuiSelectableFlags.SpanAllColumns) then
                            mq.cmdf("/echo Selected zone: %s", zone.shortName)
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
    mq.imgui.init("HuntBuddy", DrawZoneSelector)
    while openGUI do
        mq.delay(100)
    end
    mq.cmdf("/echo HuntBuddy script terminated")
end

main()