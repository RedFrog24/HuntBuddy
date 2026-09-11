-- huntbuddy.lua
-- Created by: RedFrog
-- Original creation date: 03/23/2024
-- Version controlled by `version` below (single source of truth - drives window title).
-- Changelog:
-- 2.34:   Settings text rewritten. It named the nine zones that exist in two generations; there are
--         24, and any list of them goes stale the moment one is added. It now explains the naming
--         convention instead - 1.0 is the classic zone, 2.0 the one that replaced it - which is
--         what the user needs and cannot go out of date.
-- 2.33:   Hunting Only gets a tooltip. It is the one filter whose name does not explain it: the
--         others say what they do, this one hides zones by a judgement about whether you go there
--         to kill things. The tooltip also says what it does NOT hide - a zone with no level data
--         is kept, because that is a gap in the zone data, not an empty zone.
-- 2.32:   Settings gains "Show all zone versions". Nine zones exist in two generations - the
--         classic one and the version that replaced it (Freeport x3, Steamfont, Plane of Hate,
--         Innothule, Misty Thicket, North/South Ro, Toxxulia) - and on Live the classic half is a
--         zone you cannot enter, so it is hidden. EMU servers vary over which generation they run,
--         and a mis-flagged zone would otherwise be invisible with no way to reach it, so the hide
--         is now overridable. Off by default: correct for almost everyone, escapable by anyone.
-- 2.17:   Help tab explains why LDoN zones show 15-75 (adventures scale to your level).
-- 2.16:   Hunting Only toggle - hides zones that are real but are not places you hunt (mission
--         instances, loading zones, guild halls, housing, arenas). `nodata` is NOT hidden by it:
--         that marks a gap in the zone-data source, not an empty zone. Live mode also now hides
--         zones this client ships no files for, automatically.
-- 2.15:   Pause/Resume Nav beside Stop (/nav pause keeps the route, /nav pause off resumes). State
--         is read from Navigation.Paused/.Active, not tracked locally, and the button is inert when
--         no route is running because /nav pause without one does nothing. Help tab reformatted -
--         indented sections, legend glyphs in their real table colours, measured columns.
-- 2.14:   Travel. A Go button per row runs MQ2EasyFind's /travelto, with a Group Travel toggle and
--         a Stop button above the table. The button is dead (and says why) when EasyFind is not
--         loaded or you are already in that zone.
-- 2.13:   Tabs: Zones / Settings / Help. Theme picker moved to Settings; the Zones tab keeps the
--         filter block exactly as it was. Help follows the fleet pattern and carries the version
--         footer, including zones.dataVersion so users can report which zone data they have.
--         Toggle glyphs now line up - labels padded to the widest MEASURED label.
-- 2.12:   The visible-zone list and its sort were rebuilt every frame even when nothing changed
--         (~1.6 ms and ~1,100 table allocations per frame). Both are now gated on a signature of
--         everything that can affect the result, so the work happens on interaction instead.
--         Window is also resizable now (was locked at 600x800), with a 500x400 floor.
-- 2.11:   Dropped four accidental globals (`filterZemMin, _ = ...` - the `_` was never declared
--         local, and Lua discards surplus returns anyway). With the new shared .luacheckrc at the
--         Scripts root, luacheck on this file goes 75 warnings -> 0.
-- 2.10:   Seven near-identical toggle blocks collapsed into a drawToggle() helper. Layout geometry
--         deliberately unchanged - de-duplication only.
-- 2.09:   Split the 315-line DrawZoneSelector into section functions. It held 50 upvalues against
--         LuaJIT's cap of 60, and every queued feature lands in it. Worst function is now 19.
--         Pure restructure - no behaviour change, no code rewritten.
-- 2.08:   TWO REAL BUGS found while cleaning up: (1) in Live mode 272 of 563 zones were invisible -
--         their live ZEM is stored as a numeric STRING ("0.90") and the filter accepted only a
--         number or "--"; (2) typing "(" or "%" in the zone name box crashed the render callback,
--         because user input was passed to string.find as a Lua PATTERN. Both fixed.
--         Also: Reset Filters no longer changes server mode (a preference, like the theme - and it
--         was never persisted, so the ini disagreed); render loop's goto chain replaced by a
--         zonePassesFilters() predicate; stopped mutating zone.id every frame; descending name/level
--         sorts run table.sort once instead of twice; per-frame ImVec4 colours hoisted to constants;
--         level column uses string.format like the rest of the fleet.
-- 2.07:   ZEM lookup no longer falls through to EMU data when the active mode has no value (a Live
--         row could display "--" while sorting by its hidden EMU number). Loader and render loop now
--         share ONE definition of a usable zone; optional flags are defaulted instead of
--         disqualifying a zone and skipping its ZEM normalization.
-- 2.06:   Fixed the classic/live duplicate filter, which had never worked: it keyed on shortName,
--         but twins share a fullName and differ in shortName, so East/West Freeport both showed
--         twice in every mode. Now keyed on fullName AND precomputed once at startup instead of
--         rescanning all zones for every zone, every frame (~317k comparisons/frame -> 1 lookup).
-- 2.05:   Server dropdown is Live-first and Live-default (was EMU), listing only Live + EMU until
--         Lazarus / EQ Might are built out. Server mode now persists to the ini. Default expansion
--         filter moved DoN -> Live so a Live user is not silently capped at DoN.
-- 2.04:   VERSION SCHEME CHANGED to two-part xx.xx - 2.3.90 moves permanently forward to 2.04, and
--         increments .05, .06 from here. Also restored all 7 original themes (Default, Halloween,
--         Lime, Grape, Burnt, Red, MonoChrome) alongside the four map palettes - 11 total.
-- 2.3.90: Dropped the external themes.lua + theme_loader.lua (Grimmier's) for an inline THEMES table,
--         matching the fleet standard (croakwatch / postmaster). Four map-themed palettes:
--         Meridian (default), Wayfarer, Lodestone, Dead Reckoning. Theme picker and INI persistence
--         are unchanged; a saved theme that no longer exists now falls back instead of sticking.
-- 2.3.89: Added 9 zones missing from zones.lua - Plane of Knowledge, Plane of Tranquility,
--         The Bazaar, Plane of Hate, Misty Thicket, The Jaggedpine Forest, Nedaria's Landing,
--         The Rathe Mountains, Solusek's Eye. Zone ids cross-checked against an external list
--         AND in-file adjacency; levels/ZEM still need in-game verification.
-- 2.3.88: Version number moved to a single `version` local (was duplicated in the header
--         comment and hardcoded in the window title, which would drift on a bump).
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

local mq = require('mq')
local ImGui = require('ImGui')
local Icons = require('mq.ICONS')
local zones = require('huntbuddy.zones')

local version = "2.34"

--========================
-- Header icon centering
--========================
-- Every tooltip in this file was the same four lines: hover test, Begin, one Text, End. Ten copies,
-- each one a chance to leave Begin/End unbalanced - which corrupts ImGui's stack rather than failing
-- visibly. `sub` renders a dimmed second line for the two that need one.
-- NOT ImGui.SetTooltip: it printf-formats its argument, so a literal % in a zone name would throw
-- (CroakWatch v1.07 hit exactly that). Text() does not reformat.
local function hoverTip(text, sub)
    if not ImGui.IsItemHovered() then return end
    ImGui.BeginTooltip()
    ImGui.Text(text)
    if sub and sub ~= "" then ImGui.TextDisabled(sub) end
    ImGui.EndTooltip()
end

local function centerIconInCell(icon, tooltipText)
    local cellWidth = ImGui.GetContentRegionAvailVec().x
    local textWidth = ImGui.CalcTextSize(icon)
    local cursorX = ImGui.GetCursorPosX()
    ImGui.SetCursorPosX(cursorX + (cellWidth - textWidth) * 0.5)
    ImGui.Text(icon)
    hoverTip(tooltipText)
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

-- The level filter's ceiling comes from the DATA, not a constant. It was hardcoded to 125, and
-- Shattering of Ro ships zones at 128-131 - so all six were filtered out before the user ever saw
-- them and the zone count read 540 instead of 546. AL caught it by comparing the in-game count
-- against the file. Deriving it means the next expansion cannot repeat this.
-- +10 of headroom so a zone whose named sit above its band is still reachable by dragging the
-- slider, and so the default never sits exactly on the highest value.
local function highestZoneLevel()
    local hi = 0
    for _, z in ipairs(zones.zones) do
        if (z.levelmax or 0) > hi then hi = z.levelmax end
    end
    return hi + 10
end

local filterLevelMin, filterLevelMax = 1, highestZoneLevel()
local openGUI, useShortNames = true, false
local selectedExpansion, currentTheme, serverMode = "Live", "Meridian", "Live"
local showHotzonesOnly, removeCities = false, false
local showPlatinumOnly, showFavoritesOnly = false, false
local showExpansionOnly, showOutdoorOnly = false, false
local showHuntableOnly = false
-- Overrides the Live-only hide of `emuOnly` zones (Settings, not the Zones tab: it is a preference
-- about your server, not a filter you flip while browsing). See the filter in zonePassesFilters.
local showAllVersions = false
-- Clicked-row highlight. Keyed on shortName+expansion, not shortName alone: the file's invariant is
-- unique (shortName + expansion), so a bare short name can collide. Purely visual - it marks your
-- place while scanning and drives nothing else.
local selectedZoneKey = nil
local groupTravel = false

local ColumnID_Name       = 0
local ColumnID_LevelRange = 1
local ColumnID_ZEM        = 2
local ColumnID_Hotzone    = 3
local ColumnID_Favorites  = 4
local ColumnID_Platinum   = 5
local ColumnID_Travel     = 6

-- Exact fullNames that have BOTH a classic and a live row. Built once at startup by
-- buildClassicLivePairs(); see the note there for why this is keyed on fullName.
local classicLivePairs = {}

-- Semantic colours, built once. These were being allocated inside the render loop, so the
-- toggle row alone churned ~14 ImVec4 objects per frame. They never change per theme by design.
local COLOR_ON  = ImVec4(0.0, 1.0, 0.0, 1.0)   -- lit toggle, and the live server name
local COLOR_OFF = ImVec4(1.0, 0.0, 0.0, 1.0)
local COLOR_TRANSPARENT = ImVec4(0.0, 0.0, 0.0, 0.0)
local COLOR_FAVORITE   = ImVec4(1.0, 1.0, 0.0, 1.0)
local COLOR_HOTZONE    = ImVec4(1.0, 0.5, 0.0, 1.0)
local COLOR_PLATINUM   = ImVec4(1.0, 0.84, 0.0, 1.0)
local COLOR_HEADING    = ImVec4(0.90, 0.76, 0.36, 1.0)  -- gold section heading (fleet standard)
local COLOR_DISABLED   = ImVec4(0.35, 0.38, 0.42, 1.0)

-- EQ's own map icon, drawn beside the ZEM/Level filters - a parchment map, which is exactly
-- HuntBuddy's map/atlas direction. It ships with the GAME, not with us, so there is no asset to
-- distribute and no licence question.
--
-- The path MUST be resolved at runtime: `mq.TLO.EverQuest.Path()` is the user's own EQ install
-- (MQ's own EZInventory uses it for the same purpose). Hardcoding AL's `C:\Games\Everquest` would
-- work on exactly one machine - the standing rule that nothing shipped may read AL's paths.
--
-- `default/` is EQ's stock UI folder and is present even when the user runs a custom UI, so this
-- resolves for everyone. Loaded once, croakwatch's pattern: `false` means tried-and-missing, so a
-- missing file costs one attempt and then simply renders nothing. Never a crash.
--
-- 64x64 and already power-of-2, so `CreateTexture` does not pad it and the default UVs show the
-- whole image. A non-power-of-2 PNG gets silently padded to the next POT size and the
-- default UVs then sample blank padding, so the icon renders tiny in a corner.
local filterIconTex = nil
local function getMapIcon()
    if filterIconTex == nil then
        local eqPath = (mq.TLO.EverQuest.Path() or ""):gsub("\\", "/")
        -- pcall, unlike croakwatch's version of this: croakwatch's PNGs ship WITH the script, so a
        -- missing one is a packaging bug. This file belongs to the game and may genuinely be absent
        -- (custom install, trimmed UI folder), and whether CreateTexture returns nil or throws on a
        -- missing path is not something we have verified. Guard it rather than assume.
        local ok, tex = false, nil
        if eqPath ~= "" and mq.CreateTexture then
            ok, tex = pcall(mq.CreateTexture, eqPath .. "/uiresources/default/assets/images/map_icon.png")
        end
        filterIconTex = (ok and tex and tex.GetTextureID and tex:GetTextureID()) and tex or false
    end
    return filterIconTex or nil
end

-- Bumped whenever a Favorite/Platinum flag is toggled. Part of the rebuild signature below, so a
-- toggle that changes what "Favorites Only" should show is not missed by the cache.
local zoneEditCount = 0

local settingsFile = mq.configDir .. "\\HuntBuddySettings.ini"

--========================
-- Themes (inline, fleet standard - see croakwatch / postmaster)
--========================
-- Map-themed set. Replaced Grimmier's external themes.lua + theme_loader.lua in 2.3.90 - the palette
-- now lives here where it can be read and edited, instead of behind a generic Lua-eval loader.
-- SEMANTIC COLORS ARE NEVER THEMED: the gold Favorite star, silver Platinum coin and orange hotzone
-- flame keep their meaning in every theme. Only window chrome changes.
-- Map set first (2.3.90), then the original Grimmier-derived set carried forward in 2.04 so
-- long-time users keep the look they chose. Both live in the same table; only the palettes differ.
local SERVER_MODES = { "Live", "EMU" }

local THEME_NAMES = {
    'Meridian', 'Wayfarer', 'Lodestone', 'Dead Reckoning',
    'Default', 'Halloween', 'Lime', 'Grape', 'Burnt', 'Red', 'MonoChrome',
}
local THEMES = {
    -- Meridian: deep navy with steel-blue accents - the default. Reads as reference material and
    -- stays legible against EQ's mostly-warm UI, so the window never blends into the game behind it.
    ['Meridian'] = { colors = {
        { 'WindowBg',              0.055, 0.075, 0.098, 1.000 },
        { 'ChildBg',               0.070, 0.092, 0.118, 1.000 },
        { 'PopupBg',               0.065, 0.086, 0.110, 0.970 },
        { 'TitleBg',               0.080, 0.108, 0.140, 1.000 },
        { 'TitleBgActive',         0.118, 0.160, 0.205, 1.000 },
        { 'Border',                0.290, 0.420, 0.540, 0.650 },
        { 'Text',                  0.820, 0.870, 0.920, 1.000 },
        { 'TextDisabled',          0.450, 0.510, 0.570, 1.000 },
        { 'Button',                0.130, 0.200, 0.275, 0.900 },
        { 'ButtonHovered',         0.200, 0.310, 0.420, 1.000 },
        { 'ButtonActive',          0.270, 0.400, 0.530, 1.000 },
        { 'FrameBg',               0.100, 0.135, 0.175, 1.000 },
        { 'FrameBgHovered',        0.150, 0.200, 0.260, 1.000 },
        { 'FrameBgActive',         0.195, 0.260, 0.335, 1.000 },
        { 'CheckMark',             0.420, 0.720, 0.950, 1.000 },
        { 'Separator',             0.230, 0.330, 0.430, 0.550 },
        { 'ScrollbarBg',           0.065, 0.088, 0.115, 0.600 },
        { 'ScrollbarGrab',         0.150, 0.220, 0.295, 1.000 },
        { 'ScrollbarGrabHovered',  0.215, 0.310, 0.410, 1.000 },
        { 'ScrollbarGrabActive',   0.280, 0.400, 0.520, 1.000 },
        { 'Header',                0.140, 0.215, 0.290, 0.750 },
        { 'HeaderHovered',         0.205, 0.310, 0.410, 0.900 },
        { 'HeaderActive',          0.265, 0.390, 0.510, 1.000 },
        { 'TableHeaderBg',         0.170, 0.240, 0.320, 1.000 },
        { 'TableBorderStrong',     0.250, 0.350, 0.450, 0.800 },
        { 'TableBorderLight',      0.160, 0.220, 0.290, 0.600 },
        { 'TableRowBg',            0.000, 0.000, 0.000, 0.000 },
        { 'TableRowBgAlt',         1.000, 1.000, 1.000, 0.030 },
    } },
    -- Wayfarer: moss and sage over dark bark - the field-guide look, for when HuntBuddy is a hunting
    -- almanac rather than an atlas.
    ['Wayfarer'] = { colors = {
        { 'WindowBg',              0.062, 0.075, 0.055, 1.000 },
        { 'ChildBg',               0.078, 0.094, 0.068, 1.000 },
        { 'PopupBg',               0.072, 0.088, 0.064, 0.970 },
        { 'TitleBg',               0.090, 0.110, 0.078, 1.000 },
        { 'TitleBgActive',         0.130, 0.160, 0.110, 1.000 },
        { 'Border',                0.360, 0.460, 0.280, 0.650 },
        { 'Text',                  0.850, 0.875, 0.810, 1.000 },
        { 'TextDisabled',          0.480, 0.520, 0.440, 1.000 },
        { 'Button',                0.150, 0.200, 0.115, 0.900 },
        { 'ButtonHovered',         0.230, 0.310, 0.170, 1.000 },
        { 'ButtonActive',          0.300, 0.400, 0.220, 1.000 },
        { 'FrameBg',               0.110, 0.135, 0.090, 1.000 },
        { 'FrameBgHovered',        0.160, 0.200, 0.130, 1.000 },
        { 'FrameBgActive',         0.210, 0.265, 0.170, 1.000 },
        { 'CheckMark',             0.620, 0.850, 0.380, 1.000 },
        { 'Separator',             0.280, 0.360, 0.210, 0.550 },
        { 'ScrollbarBg',           0.072, 0.088, 0.062, 0.600 },
        { 'ScrollbarGrab',         0.170, 0.220, 0.125, 1.000 },
        { 'ScrollbarGrabHovered',  0.240, 0.310, 0.175, 1.000 },
        { 'ScrollbarGrabActive',   0.310, 0.400, 0.225, 1.000 },
        { 'Header',                0.160, 0.215, 0.120, 0.750 },
        { 'HeaderHovered',         0.235, 0.310, 0.175, 0.900 },
        { 'HeaderActive',          0.300, 0.390, 0.220, 1.000 },
        { 'TableHeaderBg',         0.190, 0.240, 0.140, 1.000 },
        { 'TableBorderStrong',     0.290, 0.370, 0.220, 0.800 },
        { 'TableBorderLight',      0.180, 0.230, 0.135, 0.600 },
        { 'TableRowBg',            0.000, 0.000, 0.000, 0.000 },
        { 'TableRowBgAlt',         1.000, 1.000, 1.000, 0.030 },
    } },
    -- Lodestone: cold iron and slate with a single ember accent on the CheckMark - colour appears only
    -- where it carries meaning. The quiet, data-tool option.
    ['Lodestone'] = { colors = {
        { 'WindowBg',              0.078, 0.080, 0.086, 1.000 },
        { 'ChildBg',               0.095, 0.098, 0.105, 1.000 },
        { 'PopupBg',               0.088, 0.091, 0.098, 0.970 },
        { 'TitleBg',               0.105, 0.108, 0.116, 1.000 },
        { 'TitleBgActive',         0.150, 0.155, 0.166, 1.000 },
        { 'Border',                0.360, 0.370, 0.395, 0.650 },
        { 'Text',                  0.855, 0.860, 0.875, 1.000 },
        { 'TextDisabled',          0.480, 0.490, 0.510, 1.000 },
        { 'Button',                0.170, 0.175, 0.190, 0.900 },
        { 'ButtonHovered',         0.250, 0.258, 0.278, 1.000 },
        { 'ButtonActive',          0.325, 0.335, 0.360, 1.000 },
        { 'FrameBg',               0.128, 0.132, 0.142, 1.000 },
        { 'FrameBgHovered',        0.180, 0.186, 0.200, 1.000 },
        { 'FrameBgActive',         0.235, 0.242, 0.260, 1.000 },
        { 'CheckMark',             0.950, 0.520, 0.250, 1.000 },
        { 'Separator',             0.290, 0.298, 0.320, 0.550 },
        { 'ScrollbarBg',           0.088, 0.091, 0.098, 0.600 },
        { 'ScrollbarGrab',         0.190, 0.196, 0.212, 1.000 },
        { 'ScrollbarGrabHovered',  0.265, 0.273, 0.294, 1.000 },
        { 'ScrollbarGrabActive',   0.340, 0.350, 0.375, 1.000 },
        { 'Header',                0.185, 0.190, 0.205, 0.750 },
        { 'HeaderHovered',         0.260, 0.268, 0.288, 0.900 },
        { 'HeaderActive',          0.330, 0.340, 0.365, 1.000 },
        { 'TableHeaderBg',         0.220, 0.228, 0.246, 1.000 },
        { 'TableBorderStrong',     0.320, 0.330, 0.355, 0.800 },
        { 'TableBorderLight',      0.205, 0.212, 0.228, 0.600 },
        { 'TableRowBg',            0.000, 0.000, 0.000, 0.000 },
        { 'TableRowBgAlt',         1.000, 1.000, 1.000, 0.030 },
    } },
    -- Dead Reckoning: near-black with pale cyan - navigating by instrument at night. The darkest of the
    -- four, and deliberately unlike postmaster's warm brass, which an antique-map palette would echo.
    ['Dead Reckoning'] = { colors = {
        { 'WindowBg',              0.030, 0.038, 0.042, 1.000 },
        { 'ChildBg',               0.042, 0.052, 0.057, 1.000 },
        { 'PopupBg',               0.038, 0.047, 0.052, 0.970 },
        { 'TitleBg',               0.048, 0.060, 0.066, 1.000 },
        { 'TitleBgActive',         0.075, 0.098, 0.108, 1.000 },
        { 'Border',                0.240, 0.430, 0.460, 0.650 },
        { 'Text',                  0.800, 0.860, 0.870, 1.000 },
        { 'TextDisabled',          0.400, 0.470, 0.485, 1.000 },
        { 'Button',                0.070, 0.130, 0.140, 0.900 },
        { 'ButtonHovered',         0.110, 0.210, 0.225, 1.000 },
        { 'ButtonActive',          0.155, 0.290, 0.310, 1.000 },
        { 'FrameBg',               0.058, 0.078, 0.085, 1.000 },
        { 'FrameBgHovered',        0.088, 0.125, 0.135, 1.000 },
        { 'FrameBgActive',         0.120, 0.175, 0.190, 1.000 },
        { 'CheckMark',             0.350, 0.900, 0.900, 1.000 },
        { 'Separator',             0.170, 0.310, 0.330, 0.550 },
        { 'ScrollbarBg',           0.038, 0.048, 0.053, 0.600 },
        { 'ScrollbarGrab',         0.085, 0.150, 0.162, 1.000 },
        { 'ScrollbarGrabHovered',  0.125, 0.225, 0.242, 1.000 },
        { 'ScrollbarGrabActive',   0.170, 0.300, 0.320, 1.000 },
        { 'Header',                0.080, 0.145, 0.158, 0.750 },
        { 'HeaderHovered',         0.120, 0.215, 0.232, 0.900 },
        { 'HeaderActive',          0.160, 0.285, 0.305, 1.000 },
        { 'TableHeaderBg',         0.110, 0.158, 0.172, 1.000 },
        { 'TableBorderStrong',     0.200, 0.340, 0.360, 0.800 },
        { 'TableBorderLight',      0.110, 0.175, 0.188, 0.600 },
        { 'TableRowBg',            0.000, 0.000, 0.000, 0.000 },
        { 'TableRowBgAlt',         1.000, 1.000, 1.000, 0.030 },
    } },

    -- ---- Original set (pre-2.04, converted verbatim from Grimmier's themes.lua) ----
    -- Carried over exactly as they were, all 54 ImGuiCol keys each. Note these never set
    -- base `Text`, so it stays ImGui's default - that is original behaviour, not an omission.
    -- Keys ImGui 1.92 renamed (NavHighlight, Docking*) are skipped by pushTheme, not fatal.
    -- Default: bare ImGui defaults - sets no colors at all, only the shared style vars.
    ["Default"] = { colors = {} },
    ["Halloween"] = { colors = {
        { 'TextDisabled',          0.498, 0.393, 0.283, 1.000 },
        { 'WindowBg',              0.000, 0.000, 0.000, 1.000 },
        { 'ChildBg',               0.000, 0.000, 0.000, 0.000 },
        { 'PopupBg',               0.080, 0.080, 0.080, 0.940 },
        { 'Border',                0.962, 0.470, 0.059, 1.000 },
        { 'BorderShadow',          0.000, 0.000, 0.000, 0.000 },
        { 'FrameBg',               0.249, 0.240, 0.230, 0.540 },
        { 'FrameBgHovered',        0.980, 0.690, 0.260, 0.400 },
        { 'FrameBgActive',         0.980, 0.588, 0.260, 0.670 },
        { 'TitleBg',               0.000, 0.000, 0.000, 1.000 },
        { 'TitleBgActive',         0.055, 0.054, 0.053, 1.000 },
        { 'TitleBgCollapsed',      0.000, 0.000, 0.000, 0.510 },
        { 'MenuBarBg',             0.140, 0.140, 0.140, 1.000 },
        { 'ScrollbarBg',           0.020, 0.020, 0.020, 0.530 },
        { 'ScrollbarGrab',         0.310, 0.310, 0.310, 1.000 },
        { 'ScrollbarGrabHovered',  0.410, 0.410, 0.410, 1.000 },
        { 'ScrollbarGrabActive',   0.510, 0.510, 0.510, 1.000 },
        { 'CheckMark',             0.533, 0.980, 0.260, 1.000 },
        { 'SliderGrab',            0.880, 0.458, 0.240, 1.000 },
        { 'SliderGrabActive',      0.980, 0.547, 0.260, 1.000 },
        { 'Button',                0.801, 0.320, 0.084, 0.787 },
        { 'ButtonHovered',         0.853, 0.315, 0.000, 1.000 },
        { 'ButtonActive',          0.980, 0.400, 0.060, 1.000 },
        { 'Header',                0.118, 0.066, 0.016, 0.310 },
        { 'HeaderHovered',         0.980, 0.690, 0.260, 0.800 },
        { 'HeaderActive',          0.980, 0.731, 0.260, 1.000 },
        { 'Separator',             1.000, 0.284, 0.000, 0.500 },
        { 'SeparatorHovered',      0.750, 0.359, 0.100, 0.780 },
        { 'SeparatorActive',       0.750, 0.303, 0.100, 1.000 },
        { 'ResizeGrip',            0.948, 0.553, 0.090, 0.200 },
        { 'ResizeGripHovered',     0.980, 0.547, 0.260, 0.670 },
        { 'ResizeGripActive',      0.980, 0.608, 0.260, 0.950 },
        { 'Tab',                   0.000, 0.000, 0.000, 0.860 },
        { 'TabHovered',            0.696, 0.282, 0.000, 0.687 },
        { 'TabActive',             0.616, 0.272, 0.094, 1.000 },
        { 'TabUnfocused',          0.033, 0.029, 0.022, 0.970 },
        { 'TabUnfocusedActive',    0.941, 0.631, 0.449, 1.000 },
        { 'DockingPreview',        0.980, 0.588, 0.260, 0.700 },
        { 'DockingEmptyBg',        0.200, 0.200, 0.200, 1.000 },
        { 'PlotLines',             0.610, 0.610, 0.610, 1.000 },
        { 'PlotLinesHovered',      1.000, 0.430, 0.350, 1.000 },
        { 'PlotHistogram',         0.900, 0.700, 0.000, 1.000 },
        { 'PlotHistogramHovered',  1.000, 0.600, 0.000, 1.000 },
        { 'TableHeaderBg',         0.076, 0.075, 0.074, 1.000 },
        { 'TableBorderStrong',     1.000, 0.456, 0.000, 1.000 },
        { 'TableBorderLight',      1.000, 0.456, 0.000, 1.000 },
        { 'TableRowBg',            0.000, 0.000, 0.000, 0.000 },
        { 'TableRowBgAlt',         1.000, 1.000, 1.000, 0.060 },
        { 'TextSelectedBg',        0.980, 0.731, 0.260, 0.350 },
        { 'DragDropTarget',        1.000, 1.000, 0.000, 0.900 },
        { 'NavHighlight',          0.980, 0.588, 0.260, 1.000 },
        { 'NavWindowingHighlight', 1.000, 1.000, 1.000, 0.700 },
        { 'NavWindowingDimBg',     0.800, 0.800, 0.800, 0.200 },
        { 'ModalWindowDimBg',      0.800, 0.800, 0.800, 0.350 },
    } },
    ["Lime"] = { colors = {
        { 'TextDisabled',          0.363, 0.361, 0.360, 1.000 },
        { 'WindowBg',              0.017, 0.133, 0.026, 1.000 },
        { 'ChildBg',               0.000, 0.000, 0.000, 0.000 },
        { 'PopupBg',               0.080, 0.080, 0.080, 0.940 },
        { 'Border',                0.376, 0.962, 0.059, 0.500 },
        { 'BorderShadow',          0.000, 0.000, 0.000, 0.000 },
        { 'FrameBg',               0.338, 0.621, 0.327, 0.540 },
        { 'FrameBgHovered',        0.697, 0.980, 0.260, 0.400 },
        { 'FrameBgActive',         0.676, 0.980, 0.260, 0.670 },
        { 'TitleBg',               0.040, 0.040, 0.040, 1.000 },
        { 'TitleBgActive',         0.000, 0.000, 0.000, 1.000 },
        { 'TitleBgCollapsed',      0.000, 0.000, 0.000, 0.510 },
        { 'MenuBarBg',             0.140, 0.140, 0.140, 1.000 },
        { 'ScrollbarBg',           0.020, 0.020, 0.020, 0.530 },
        { 'ScrollbarGrab',         0.070, 0.512, 0.039, 1.000 },
        { 'ScrollbarGrabHovered',  0.204, 0.588, 0.150, 1.000 },
        { 'ScrollbarGrabActive',   0.356, 0.720, 0.133, 1.000 },
        { 'CheckMark',             0.260, 0.980, 0.356, 1.000 },
        { 'SliderGrab',            0.264, 0.880, 0.240, 1.000 },
        { 'SliderGrabActive',      0.260, 0.980, 0.335, 1.000 },
        { 'Button',                0.176, 0.521, 0.052, 0.400 },
        { 'ButtonHovered',         0.103, 0.204, 0.071, 1.000 },
        { 'ButtonActive',          0.618, 0.980, 0.060, 1.000 },
        { 'Header',                0.472, 0.980, 0.260, 0.310 },
        { 'HeaderHovered',         0.369, 0.980, 0.260, 0.800 },
        { 'HeaderActive',          0.533, 0.980, 0.260, 1.000 },
        { 'Separator',             0.154, 0.905, 0.211, 0.500 },
        { 'SeparatorHovered',      0.217, 0.750, 0.100, 0.780 },
        { 'SeparatorActive',       0.199, 0.750, 0.100, 1.000 },
        { 'ResizeGrip',            0.098, 0.948, 0.090, 0.200 },
        { 'ResizeGripHovered',     0.267, 0.980, 0.260, 0.670 },
        { 'ResizeGripActive',      0.080, 0.896, 0.072, 0.950 },
        { 'Tab',                   0.057, 0.142, 0.051, 0.860 },
        { 'TabHovered',            0.244, 0.696, 0.000, 0.687 },
        { 'TabActive',             0.044, 0.071, 0.006, 1.000 },
        { 'TabUnfocused',          0.022, 0.033, 0.022, 0.970 },
        { 'TabUnfocusedActive',    0.055, 0.076, 0.054, 1.000 },
        { 'DockingPreview',        0.451, 0.980, 0.260, 0.700 },
        { 'DockingEmptyBg',        0.200, 0.200, 0.200, 1.000 },
        { 'PlotLines',             0.610, 0.610, 0.610, 1.000 },
        { 'PlotLinesHovered',      1.000, 0.430, 0.350, 1.000 },
        { 'PlotHistogram',         0.900, 0.700, 0.000, 1.000 },
        { 'PlotHistogramHovered',  1.000, 0.600, 0.000, 1.000 },
        { 'TableHeaderBg',         0.190, 0.190, 0.200, 1.000 },
        { 'TableBorderStrong',     0.310, 0.310, 0.350, 1.000 },
        { 'TableBorderLight',      0.230, 0.230, 0.250, 1.000 },
        { 'TableRowBg',            0.000, 0.000, 0.000, 0.000 },
        { 'TableRowBgAlt',         1.000, 1.000, 1.000, 0.060 },
        { 'TextSelectedBg',        0.676, 0.980, 0.260, 0.350 },
        { 'DragDropTarget',        0.408, 1.000, 0.000, 0.900 },
        { 'NavHighlight',          0.980, 0.588, 0.260, 1.000 },
        { 'NavWindowingHighlight', 1.000, 1.000, 1.000, 0.700 },
        { 'NavWindowingDimBg',     0.800, 0.800, 0.800, 0.200 },
        { 'ModalWindowDimBg',      0.800, 0.800, 0.800, 0.350 },
    } },
    ["Grape"] = { colors = {
        { 'TextDisabled',          0.500, 0.500, 0.500, 1.000 },
        { 'WindowBg',              0.017, 0.002, 0.047, 0.940 },
        { 'ChildBg',               0.063, 0.006, 0.156, 0.000 },
        { 'PopupBg',               0.054, 0.012, 0.156, 0.940 },
        { 'Border',                0.295, 0.153, 0.398, 0.500 },
        { 'BorderShadow',          0.000, 0.000, 0.000, 0.000 },
        { 'FrameBg',               0.263, 0.160, 0.480, 0.540 },
        { 'FrameBgHovered',        0.431, 0.260, 0.980, 0.400 },
        { 'FrameBgActive',         0.533, 0.260, 0.980, 0.670 },
        { 'TitleBg',               0.103, 0.004, 0.194, 1.000 },
        { 'TitleBgActive',         0.354, 0.160, 0.480, 1.000 },
        { 'TitleBgCollapsed',      0.079, 0.013, 0.186, 0.510 },
        { 'MenuBarBg',             0.140, 0.140, 0.140, 1.000 },
        { 'ScrollbarBg',           0.020, 0.020, 0.020, 0.530 },
        { 'ScrollbarGrab',         0.458, 0.138, 0.621, 1.000 },
        { 'ScrollbarGrabHovered',  0.414, 0.261, 0.664, 1.000 },
        { 'ScrollbarGrabActive',   0.616, 0.115, 0.839, 1.000 },
        { 'CheckMark',             0.699, 0.576, 0.928, 1.000 },
        { 'SliderGrab',            0.596, 0.240, 0.880, 1.000 },
        { 'SliderGrabActive',      0.552, 0.260, 0.980, 1.000 },
        { 'Button',                0.231, 0.102, 0.720, 0.400 },
        { 'ButtonHovered',         0.574, 0.260, 0.980, 1.000 },
        { 'ButtonActive',          0.479, 0.060, 0.980, 1.000 },
        { 'Header',                0.570, 0.260, 0.980, 0.310 },
        { 'HeaderHovered',         0.643, 0.260, 0.980, 0.800 },
        { 'HeaderActive',          0.574, 0.260, 0.980, 1.000 },
        { 'Separator',             0.322, 0.000, 1.000, 0.825 },
        { 'SeparatorHovered',      0.380, 0.100, 0.750, 0.780 },
        { 'SeparatorActive',       0.365, 0.100, 0.750, 1.000 },
        { 'ResizeGrip',            0.574, 0.260, 0.980, 0.200 },
        { 'ResizeGripHovered',     0.497, 0.260, 0.980, 0.670 },
        { 'ResizeGripActive',      0.570, 0.260, 0.980, 0.950 },
        { 'Tab',                   0.287, 0.147, 0.493, 0.860 },
        { 'TabHovered',            0.533, 0.260, 0.980, 0.800 },
        { 'TabActive',             0.237, 0.237, 0.840, 1.000 },
        { 'TabUnfocused',          0.098, 0.070, 0.150, 0.970 },
        { 'TabUnfocusedActive',    0.351, 0.185, 0.521, 1.000 },
        { 'DockingPreview',        0.203, 0.044, 0.464, 0.700 },
        { 'DockingEmptyBg',        0.200, 0.200, 0.200, 1.000 },
        { 'PlotLines',             0.610, 0.610, 0.610, 1.000 },
        { 'PlotLinesHovered',      1.000, 0.430, 0.350, 1.000 },
        { 'PlotHistogram',         0.900, 0.700, 0.000, 1.000 },
        { 'PlotHistogramHovered',  1.000, 0.600, 0.000, 1.000 },
        { 'TableHeaderBg',         0.226, 0.180, 0.256, 1.000 },
        { 'TableBorderStrong',     0.212, 0.095, 0.280, 1.000 },
        { 'TableBorderLight',      0.206, 0.129, 0.318, 1.000 },
        { 'TableRowBg',            0.102, 0.019, 0.270, 1.000 },
        { 'TableRowBgAlt',         0.090, 0.043, 0.251, 1.000 },
        { 'TextSelectedBg',        0.552, 0.260, 0.980, 0.350 },
        { 'DragDropTarget',        0.190, 0.043, 0.209, 0.858 },
        { 'NavHighlight',          0.265, 0.212, 0.299, 1.000 },
        { 'NavWindowingHighlight', 1.000, 1.000, 1.000, 0.700 },
        { 'NavWindowingDimBg',     0.800, 0.800, 0.800, 0.200 },
        { 'ModalWindowDimBg',      0.800, 0.800, 0.800, 0.350 },
    } },
    ["Burnt"] = { colors = {
        { 'TextDisabled',          0.498, 0.393, 0.283, 1.000 },
        { 'WindowBg',              0.000, 0.000, 0.000, 1.000 },
        { 'ChildBg',               0.000, 0.000, 0.000, 0.000 },
        { 'PopupBg',               0.080, 0.080, 0.080, 0.940 },
        { 'Border',                0.962, 0.470, 0.059, 0.500 },
        { 'BorderShadow',          0.000, 0.000, 0.000, 0.000 },
        { 'FrameBg',               0.249, 0.240, 0.230, 0.540 },
        { 'FrameBgHovered',        0.980, 0.690, 0.260, 0.400 },
        { 'FrameBgActive',         0.980, 0.588, 0.260, 0.670 },
        { 'TitleBg',               0.000, 0.000, 0.000, 1.000 },
        { 'TitleBgActive',         0.055, 0.054, 0.053, 1.000 },
        { 'TitleBgCollapsed',      0.000, 0.000, 0.000, 0.510 },
        { 'MenuBarBg',             0.140, 0.140, 0.140, 1.000 },
        { 'ScrollbarBg',           0.020, 0.020, 0.020, 0.530 },
        { 'ScrollbarGrab',         0.310, 0.310, 0.310, 1.000 },
        { 'ScrollbarGrabHovered',  0.410, 0.410, 0.410, 1.000 },
        { 'ScrollbarGrabActive',   0.510, 0.510, 0.510, 1.000 },
        { 'CheckMark',             0.980, 0.526, 0.260, 1.000 },
        { 'SliderGrab',            0.880, 0.458, 0.240, 1.000 },
        { 'SliderGrabActive',      0.980, 0.547, 0.260, 1.000 },
        { 'Button',                0.671, 0.348, 0.190, 0.400 },
        { 'ButtonHovered',         1.000, 0.582, 0.000, 1.000 },
        { 'ButtonActive',          0.980, 0.400, 0.060, 1.000 },
        { 'Header',                0.980, 0.547, 0.260, 0.310 },
        { 'HeaderHovered',         0.980, 0.690, 0.260, 0.800 },
        { 'HeaderActive',          0.980, 0.731, 0.260, 1.000 },
        { 'Separator',             1.000, 0.284, 0.000, 0.500 },
        { 'SeparatorHovered',      0.750, 0.359, 0.100, 0.780 },
        { 'SeparatorActive',       0.750, 0.303, 0.100, 1.000 },
        { 'ResizeGrip',            0.948, 0.553, 0.090, 0.200 },
        { 'ResizeGripHovered',     0.980, 0.547, 0.260, 0.670 },
        { 'ResizeGripActive',      0.980, 0.608, 0.260, 0.950 },
        { 'Tab',                   0.000, 0.000, 0.000, 0.860 },
        { 'TabHovered',            0.696, 0.282, 0.000, 0.687 },
        { 'TabActive',             0.616, 0.272, 0.094, 1.000 },
        { 'TabUnfocused',          0.033, 0.029, 0.022, 0.970 },
        { 'TabUnfocusedActive',    0.360, 0.163, 0.048, 1.000 },
        { 'DockingPreview',        0.980, 0.588, 0.260, 0.700 },
        { 'DockingEmptyBg',        0.200, 0.200, 0.200, 1.000 },
        { 'PlotLines',             0.610, 0.610, 0.610, 1.000 },
        { 'PlotLinesHovered',      1.000, 0.430, 0.350, 1.000 },
        { 'PlotHistogram',         0.900, 0.700, 0.000, 1.000 },
        { 'PlotHistogramHovered',  1.000, 0.600, 0.000, 1.000 },
        { 'TableHeaderBg',         0.076, 0.075, 0.074, 1.000 },
        { 'TableBorderStrong',     1.000, 0.456, 0.000, 1.000 },
        { 'TableBorderLight',      1.000, 0.456, 0.000, 1.000 },
        { 'TableRowBg',            0.000, 0.000, 0.000, 0.000 },
        { 'TableRowBgAlt',         1.000, 1.000, 1.000, 0.060 },
        { 'TextSelectedBg',        0.980, 0.731, 0.260, 0.350 },
        { 'DragDropTarget',        1.000, 1.000, 0.000, 0.900 },
        { 'NavHighlight',          0.980, 0.588, 0.260, 1.000 },
        { 'NavWindowingHighlight', 1.000, 1.000, 1.000, 0.700 },
        { 'NavWindowingDimBg',     0.800, 0.800, 0.800, 0.200 },
        { 'ModalWindowDimBg',      0.800, 0.800, 0.800, 0.350 },
    } },
    ["Red"] = { colors = {
        { 'TextDisabled',          0.498, 0.393, 0.283, 1.000 },
        { 'WindowBg',              0.000, 0.000, 0.000, 1.000 },
        { 'ChildBg',               0.000, 0.000, 0.000, 0.000 },
        { 'PopupBg',               0.080, 0.080, 0.080, 0.940 },
        { 'Border',                0.962, 0.059, 0.059, 0.500 },
        { 'BorderShadow',          0.000, 0.000, 0.000, 0.000 },
        { 'FrameBg',               0.249, 0.240, 0.230, 0.540 },
        { 'FrameBgHovered',        0.980, 0.690, 0.260, 0.400 },
        { 'FrameBgActive',         0.980, 0.260, 0.260, 0.670 },
        { 'TitleBg',               0.000, 0.000, 0.000, 1.000 },
        { 'TitleBgActive',         0.055, 0.054, 0.053, 1.000 },
        { 'TitleBgCollapsed',      0.000, 0.000, 0.000, 0.510 },
        { 'MenuBarBg',             0.140, 0.140, 0.140, 1.000 },
        { 'ScrollbarBg',           0.020, 0.020, 0.020, 0.530 },
        { 'ScrollbarGrab',         0.310, 0.310, 0.310, 1.000 },
        { 'ScrollbarGrabHovered',  0.410, 0.410, 0.410, 1.000 },
        { 'ScrollbarGrabActive',   0.510, 0.510, 0.510, 1.000 },
        { 'CheckMark',             0.980, 0.526, 0.260, 1.000 },
        { 'SliderGrab',            0.880, 0.458, 0.240, 1.000 },
        { 'SliderGrabActive',      0.980, 0.547, 0.260, 1.000 },
        { 'Button',                0.671, 0.190, 0.245, 0.400 },
        { 'ButtonHovered',         1.000, 0.582, 0.000, 1.000 },
        { 'ButtonActive',          0.980, 0.400, 0.060, 1.000 },
        { 'Header',                0.943, 0.246, 0.103, 0.957 },
        { 'HeaderHovered',         0.980, 0.342, 0.260, 1.000 },
        { 'HeaderActive',          0.980, 0.321, 0.260, 1.000 },
        { 'Separator',             1.000, 0.000, 0.125, 0.500 },
        { 'SeparatorHovered',      0.750, 0.359, 0.100, 0.780 },
        { 'SeparatorActive',       0.750, 0.303, 0.100, 1.000 },
        { 'ResizeGrip',            0.948, 0.553, 0.090, 0.200 },
        { 'ResizeGripHovered',     0.980, 0.547, 0.260, 0.670 },
        { 'ResizeGripActive',      0.980, 0.608, 0.260, 0.950 },
        { 'Tab',                   0.000, 0.000, 0.000, 0.860 },
        { 'TabHovered',            0.803, 0.070, 0.140, 0.630 },
        { 'TabActive',             0.616, 0.094, 0.177, 1.000 },
        { 'TabUnfocused',          0.033, 0.029, 0.022, 0.970 },
        { 'TabUnfocusedActive',    0.360, 0.163, 0.048, 1.000 },
        { 'DockingPreview',        0.980, 0.588, 0.260, 0.700 },
        { 'DockingEmptyBg',        0.200, 0.200, 0.200, 1.000 },
        { 'PlotLines',             0.610, 0.610, 0.610, 1.000 },
        { 'PlotLinesHovered',      1.000, 0.430, 0.350, 1.000 },
        { 'PlotHistogram',         0.900, 0.700, 0.000, 1.000 },
        { 'PlotHistogramHovered',  1.000, 0.600, 0.000, 1.000 },
        { 'TableHeaderBg',         0.616, 0.090, 0.041, 1.000 },
        { 'TableBorderStrong',     1.000, 0.000, 0.000, 1.000 },
        { 'TableBorderLight',      1.000, 0.000, 0.000, 1.000 },
        { 'TableRowBg',            0.673, 0.115, 0.115, 0.986 },
        { 'TableRowBgAlt',         0.649, 0.052, 0.052, 0.910 },
        { 'TextSelectedBg',        0.980, 0.731, 0.260, 0.350 },
        { 'DragDropTarget',        1.000, 1.000, 0.000, 0.900 },
        { 'NavHighlight',          0.915, 0.092, 0.213, 1.000 },
        { 'NavWindowingHighlight', 1.000, 1.000, 1.000, 0.700 },
        { 'NavWindowingDimBg',     0.800, 0.800, 0.800, 0.200 },
        { 'ModalWindowDimBg',      0.800, 0.800, 0.800, 0.350 },
    } },
    ["MonoChrome"] = { colors = {
        { 'TextDisabled',          0.500, 0.500, 0.500, 1.000 },
        { 'WindowBg',              0.060, 0.060, 0.060, 0.848 },
        { 'ChildBg',               0.000, 0.000, 0.000, 0.000 },
        { 'PopupBg',               0.080, 0.080, 0.080, 0.940 },
        { 'Border',                0.430, 0.430, 0.500, 0.500 },
        { 'BorderShadow',          0.000, 0.000, 0.000, 0.000 },
        { 'FrameBg',               0.364, 0.368, 0.374, 0.540 },
        { 'FrameBgHovered',        0.636, 0.655, 0.678, 0.400 },
        { 'FrameBgActive',         0.554, 0.587, 0.626, 0.670 },
        { 'TitleBg',               0.040, 0.040, 0.040, 1.000 },
        { 'TitleBgActive',         0.248, 0.253, 0.261, 1.000 },
        { 'TitleBgCollapsed',      0.000, 0.000, 0.000, 0.510 },
        { 'MenuBarBg',             0.294, 0.284, 0.284, 1.000 },
        { 'ScrollbarBg',           0.020, 0.020, 0.020, 0.530 },
        { 'ScrollbarGrab',         0.310, 0.310, 0.310, 1.000 },
        { 'ScrollbarGrabHovered',  0.410, 0.410, 0.410, 1.000 },
        { 'ScrollbarGrabActive',   0.510, 0.510, 0.510, 1.000 },
        { 'CheckMark',             0.962, 0.975, 0.991, 1.000 },
        { 'SliderGrab',            0.640, 0.648, 0.659, 1.000 },
        { 'SliderGrabActive',      0.744, 0.759, 0.777, 1.000 },
        { 'Button',                0.376, 0.382, 0.389, 0.400 },
        { 'ButtonHovered',         0.036, 0.039, 0.043, 1.000 },
        { 'ButtonActive',          0.485, 0.499, 0.512, 1.000 },
        { 'Header',                0.437, 0.444, 0.521, 0.310 },
        { 'HeaderHovered',         0.659, 0.674, 0.692, 0.800 },
        { 'HeaderActive',          0.456, 0.523, 0.602, 1.000 },
        { 'Separator',             0.581, 0.581, 0.626, 0.500 },
        { 'SeparatorHovered',      0.286, 0.307, 0.332, 0.780 },
        { 'SeparatorActive',       0.603, 0.629, 0.659, 1.000 },
        { 'ResizeGrip',            0.517, 0.530, 0.545, 0.200 },
        { 'ResizeGripHovered',     0.536, 0.557, 0.583, 0.670 },
        { 'ResizeGripActive',      0.400, 0.410, 0.422, 0.950 },
        { 'Tab',                   0.492, 0.511, 0.536, 0.860 },
        { 'TabHovered',            0.630, 0.678, 0.735, 0.800 },
        { 'TabActive',             0.523, 0.528, 0.536, 1.000 },
        { 'TabUnfocused',          0.070, 0.100, 0.150, 0.970 },
        { 'TabUnfocusedActive',    0.336, 0.348, 0.365, 1.000 },
        { 'DockingPreview',        0.406, 0.416, 0.427, 0.700 },
        { 'DockingEmptyBg',        0.200, 0.200, 0.200, 1.000 },
        { 'PlotLines',             0.891, 0.811, 0.545, 1.000 },
        { 'PlotLinesHovered',      1.000, 0.430, 0.350, 1.000 },
        { 'PlotHistogram',         0.900, 0.700, 0.000, 1.000 },
        { 'PlotHistogramHovered',  1.000, 0.600, 0.000, 1.000 },
        { 'TableHeaderBg',         0.190, 0.190, 0.200, 1.000 },
        { 'TableBorderStrong',     0.310, 0.310, 0.350, 1.000 },
        { 'TableBorderLight',      0.230, 0.230, 0.250, 1.000 },
        { 'TableRowBg',            0.000, 0.000, 0.000, 0.000 },
        { 'TableRowBgAlt',         1.000, 1.000, 1.000, 0.060 },
        { 'TextSelectedBg',        0.559, 0.568, 0.578, 0.350 },
        { 'DragDropTarget',        0.204, 0.204, 0.188, 0.900 },
        { 'NavHighlight',          0.707, 0.737, 0.773, 1.000 },
        { 'NavWindowingHighlight', 1.000, 1.000, 1.000, 0.700 },
        { 'NavWindowingDimBg',     0.800, 0.800, 0.800, 0.200 },
        { 'ModalWindowDimBg',      0.800, 0.800, 0.800, 0.350 },
    } },
}

-- Pushes the active theme's colors + shared style vars; returns the two counts the caller must pop.
-- An ImGuiCol key this MQ build does not have is skipped rather than crashing.
local function pushTheme()
    local cols = (THEMES[currentTheme] or THEMES['Meridian']).colors
    local n = 0
    for _, c in ipairs(cols) do
        local idx = ImGuiCol[c[1]]
        if idx then
            ImGui.PushStyleColor(idx, c[2], c[3], c[4], c[5])
            n = n + 1
        end
    end
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding,    6)
    ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding,     5)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding,     4)
    ImGui.PushStyleVar(ImGuiStyleVar.GrabRounding,      3)
    ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarRounding, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize,   1)
    return n, 6
end

local function popTheme(colorCount, styleCount)
    if colorCount > 0 then ImGui.PopStyleColor(colorCount) end
    if styleCount > 0 then ImGui.PopStyleVar(styleCount) end
end

--========================
-- Zone validity (one definition, shared)
--========================
-- These fields must exist or the zone cannot be rendered at all. Everything else (hotzone, city,
-- indoor, isFavorite, isPlatinum) is OPTIONAL and gets defaulted below.
--
-- The loader and the render loop used to disagree: the loader demanded all 11 fields and skipped its
-- ZEM normalization whenever any were missing, while the render loop asked for only these 6. A zone
-- missing just `indoor` therefore rendered WITHOUT normalized ZEM - which is exactly what made the
-- sort-key fallthrough below reachable. Both now call this.
local ZONE_REQUIRED = { "shortName", "fullName", "expansion", "zem", "levelmin", "levelmax" }

-- Returns a list of missing required fields, or nil when the zone is usable.
-- nil (not an empty table) in the common case, so the render loop allocates nothing per row.
local function missingRequiredFields(zone)
    local missing = nil
    for _, field in ipairs(ZONE_REQUIRED) do
        if zone[field] == nil then
            missing = missing or {}
            missing[#missing + 1] = field
        end
    end
    return missing
end

--========================
-- Settings
--========================
-- Favorites and Platinum persist to the ini keyed on shortName - but a short name is NOT unique.
-- `neriakd` is both Classic "Neriak Palace" and CotF "Neriak - Fourth Gate", so starring one of them
-- starred the other on the next load: same key, same value. The file's real uniqueness invariant is
-- (shortName + expansion), which is why validate_zones.lua enforces that pair.
--
-- Only the genuinely colliding short names get the compound key. Keying EVERYTHING on
-- shortName|expansion would be cleaner in the abstract and would silently wipe every existing
-- user's saved favourites, since none of their keys would match any more.
local duplicateShorts = nil
local function buildDuplicateShorts()
    local seen = {}
    duplicateShorts = {}
    for _, z in ipairs(zones.zones) do
        if z.shortName then
            if seen[z.shortName] then duplicateShorts[z.shortName] = true end
            seen[z.shortName] = true
        end
    end
end

local function zoneIniKey(zone)
    if duplicateShorts and duplicateShorts[zone.shortName] then
        return zone.shortName .. "|" .. (zone.expansion or "")
    end
    return zone.shortName
end

local function LoadSettings()
    buildDuplicateShorts()
    -- A saved theme that no longer exists (renamed, or left over from the pre-2.3.90 Grimmier set)
    -- falls back to the default rather than leaving the combo showing a name nothing matches.
    local savedTheme = mq.TLO.Ini(settingsFile, "Settings", "Theme")()
    if savedTheme and THEMES[savedTheme] then currentTheme = savedTheme end

    -- Server mode persists too, so an EMU user is not re-picking it every launch now that Live is
    -- the default. A stored mode no longer offered (Lazarus, from before 2.05) falls back to Live.
    local savedMode = mq.TLO.Ini(settingsFile, "Settings", "ServerMode")()
    if savedMode then
        for _, mode in ipairs(SERVER_MODES) do
            if mode == savedMode then serverMode = savedMode break end
        end
    end

    groupTravel = mq.TLO.Ini(settingsFile, "Settings", "GroupTravel")() == "1"
    showAllVersions = mq.TLO.Ini(settingsFile, "Settings", "ShowAllVersions")() == "1"
    for i, zone in ipairs(zones.zones) do
        local missing = missingRequiredFields(zone)
        if missing then
            mq.cmdf("/echo Warning: Invalid zone at index %d (shortName: %s, missing: %s)", i, tostring(zone.shortName), table.concat(missing, ", "))
        else
            -- Optional flags get defaulted rather than disqualifying the zone. Previously a nil here
            -- skipped everything below, including the ZEM normalization.
            if zone.hotzone == nil then zone.hotzone = false end
            if zone.city == nil then zone.city = false end
            if zone.indoor == nil then zone.indoor = false end

            local key = zoneIniKey(zone)
            local fav = mq.TLO.Ini(settingsFile, "Favorites", key)()
            local plat = mq.TLO.Ini(settingsFile, "Platinum", key)()
            zone.isFavorite = (fav == "1") or zone.isFavorite or false
            zone.isPlatinum = (plat == "1") or zone.isPlatinum or false

            zone.zem.emu = zone.zem.emu or "--"
            zone.zem.live = zone.zem.live or "--"
            zone.zem.lazarus = zone.zem.lazarus or "--"
        end
    end
end

local function SaveZoneSettings(zone)
    local key = zoneIniKey(zone)
    mq.cmdf('/ini "%s" "Favorites" "%s" "%d"', settingsFile, key, zone.isFavorite and 1 or 0)
    mq.cmdf('/ini "%s" "Platinum" "%s" "%d"',  settingsFile, key, zone.isPlatinum and 1 or 0)
    zoneEditCount = zoneEditCount + 1
end

local function SaveThemeSetting()
    mq.cmdf('/ini "%s" "Settings" "Theme" "%s"', settingsFile, currentTheme)
end

local function SaveServerSetting()
    mq.cmdf('/ini "%s" "Settings" "ServerMode" "%s"', settingsFile, serverMode)
end

local function SaveTravelSetting()
    mq.cmdf('/ini "%s" "Settings" "GroupTravel" "%d"', settingsFile, groupTravel and 1 or 0)
end

local function SaveShowAllVersionsSetting()
    mq.cmdf('/ini "%s" "Settings" "ShowAllVersions" "%d"', settingsFile, showAllVersions and 1 or 0)
end

local function ResetFilters()
    filterName, filterZemMin, filterZemMax = "", 0.0, 5.0
    filterLevelMin, filterLevelMax = 1, highestZoneLevel()
    selectedExpansion = "Live"
    showHotzonesOnly, removeCities = false, false
    useShortNames = false
    -- serverMode is deliberately NOT reset: it is a preference (like the theme and Show All Zone
    -- Versions, which Reset also leaves alone), not a filter. It used to be reset here without
    -- persisting, so the ini kept the old value and the next launch silently reverted.
    showPlatinumOnly, showFavoritesOnly = false, false
    showExpansionOnly, showOutdoorOnly = false, false
    showHuntableOnly = false
end

--========================
-- Sorting helpers (string-only keys)
--========================
local function to_numid(id)
    return tonumber(id) or 0
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

-- Raw ZEM for one server mode: the stored value, or "--" when this zone has none for that mode.
--
-- Deliberately an if/elseif, NOT an `and`/`or` chain. The old chain read
--     (mode == "Live") and zone.zem.live or (mode == "Lazarus") and zone.zem.lazarus or zone.zem.emu
-- which falls through to the EMU value whenever the requested mode's entry is nil - so a Live row
-- with no live ZEM displayed "--" but SORTED by its hidden EMU number. Asking for one mode must
-- never silently answer with another mode's data.
local function get_zem_for_mode(zone, mode)
    local zem = zone.zem
    if not zem then return "--" end
    local v
    if mode == "Live" then
        v = zem.live
    elseif mode == "Lazarus" then
        v = zem.lazarus
    else
        v = zem.emu
    end
    if v == nil then return "--" end
    return v
end

-- Numeric ZEM for sorting and filtering, or nil when this mode has no number for the zone.
local function get_zem_number_for_mode(zone, mode)
    local v = get_zem_for_mode(zone, mode)
    if type(v) == "number" then return v end
    if type(v) == "string" then return tonumber(v) end
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

-- Which zones have BOTH a classic and a live row? Computed ONCE at startup (2.06).
--
-- Keyed on EXACT fullName. It used to key on shortName, which never matched anything: the twins in
-- the data share a NAME but not a short name - East Freeport is `freporte`/classic AND
-- `freeporteast`/live. So the lookup returned false for every row, both twins rendered, and the
-- whole classic/live preference was dead code from 2.3.86 until 2.06.
--
-- NOT normalized (no article/punctuation stripping): that would merge genuinely different zones,
-- e.g. Velious "Eastern Wastes" with ToV "The Eastern Wastes". Exact match finds both real pairs
-- and nothing else.
--
-- Also no longer a per-frame scan. The old version was O(n) called once per zone per frame -
-- ~317,000 string comparisons every frame on a table that never changes after load.
-- A zone whose version is nil/unknown counts as classic, as before.
local function buildClassicLivePairs()
    local seen = {}
    for _, z in ipairs(zones.zones) do
        if z.fullName then
            local entry = seen[z.fullName]
            if not entry then
                entry = { classic = false, live = false }
                seen[z.fullName] = entry
            end
            if z.version == "live" then entry.live = true else entry.classic = true end
        end
    end
    classicLivePairs = {}
    for name, entry in pairs(seen) do
        if entry.classic and entry.live then classicLivePairs[name] = true end
    end
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
    if not classicLivePairs[zone.fullName] then
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

-- Every filter for one zone, as guard clauses instead of a goto chain.
-- `zone.id` used to be normalised here (`zone.id = to_numid(zone.id)`), which mutated the shared
-- zone table from inside the render loop on every frame. build_alpha_key already calls to_numid on
-- it, so the write was redundant as well as a side effect.
local function zonePassesFilters(zone, maxExpansionLevel)
    if missingRequiredFields(zone) then return false end

    local zoneExpansionLevel = zones.expansionOrder[zone.expansion]
    if not zoneExpansionLevel then return false end
    if zoneExpansionLevel > maxExpansionLevel then return false end
    if showExpansionOnly and zone.expansion ~= selectedExpansion then return false end

    if showHotzonesOnly and not zone.hotzone then return false end
    if removeCities and zone.city then return false end
    if showFavoritesOnly and not zone.isFavorite then return false end
    if showPlatinumOnly and not zone.isPlatinum then return false end
    if showOutdoorOnly and zone.indoor ~= false then return false end

    -- Hunting Only hides zones that are real but are not places you go to kill things - the
    -- Muramite Proving Grounds, loading zones, guild halls, player housing, arenas.
    -- `nodata` is deliberately NOT hidden: it means PEQ had no spawn rows for the zone, which is a
    -- gap in the SOURCE, not a statement that the zone is empty. Every zone past Rain of Fear will
    -- carry it, and hiding them would erase the modern game.
    if showHuntableOnly and zone.category and zone.category ~= "nodata" then return false end

    -- `emuOnly` marks a zone you cannot enter on Live. It covers two cases: the client ships no
    -- files for it, and - the larger group - it is the classic half of a pair whose replacement is
    -- what Live actually runs (freporte vs freeporteast). The second kind still ships its old .s3d,
    -- so only the zone data knows, and the zone data can be wrong.
    -- Hence the override: default off, because hiding is right for almost everyone, but a user on a
    -- server we guessed wrong about would otherwise have no way to reach the zone at all.
    if serverMode == "Live" and zone.emuOnly and not showAllVersions then return false end

    -- A zone with no derived range has levelmax = 0, which is NOT "level 0" - it means PEQ had no
    -- spawn rows for it. Comparing it against the slider hides it in every mode with no way to turn
    -- that off: `0 < filterLevelMin` is always true, since filterLevelMin is clamped to >= 1.
    -- That silently ate 18 zones on Live, 7 of them ones AL reviewed and forced huntable, and would
    -- have hidden all 91 zones of the expansions past Rain of Fear the moment they were added.
    -- Same principle as `nodata` and the Hunting Only filter: absent data is not a verdict.
    if zone.levelmax > 0 and (zone.levelmin > filterLevelMax or zone.levelmax < filterLevelMin) then
        return false
    end

    if filterName ~= "" then
        local displayName = useShortNames and zone.shortName or zone.fullName
        if not string.find(string.lower(displayName), string.lower(filterName), 1, true) then
            return false
        end
    end

    -- Parse through get_zem_number_for_mode so numeric STRINGS count. 272 of 563 zones store their
    -- live ZEM as "0.90" rather than 0.90, and the old check accepted only a real number or exactly
    -- "--" - so in Live mode those 272 zones failed the ZEM test and vanished from the list entirely.
    local zemNumber = get_zem_number_for_mode(zone, serverMode)
    if zemNumber then
        if zemNumber < filterZemMin or zemNumber > filterZemMax then return false end
    elseif filterZemMin > 0 then
        return false          -- no ZEM for this mode at all, and the filter demands one
    end

    return FilterZonesByServerAndExpansion(zone)
end

--========================
-- Travel (MQ2EasyFind)
--========================
-- /travelto comes from the MQ2EasyFind plugin - verified by inspecting the dll, which registers
-- both /easyfind and /travelto. Nothing else in the Live install provides it, so if EasyFind is not
-- loaded the command silently does nothing. Hence the gate: the Go button is never live without it,
-- and says why.

local function easyFindLoaded()
    local name = mq.TLO.Plugin("MQ2EasyFind").Name()
    return name ~= nil and name ~= ""
end

-- True only when we are actually in a group with a leader. The checkbox alone is not trusted -
-- "/travelto group" with no group misfires. Magellan guards the same way.
local function travellingAsGroup()
    return groupTravel and (mq.TLO.Group.Leader.ID() or 0) > 0
end

local function travelTo(shortName)
    if travellingAsGroup() then
        mq.cmdf('/travelto group %s', shortName)
    else
        mq.cmdf('/travelto %s', shortName)
    end
end

-- Always stop ourselves first, then the group. Magellan sends only the group form, which relies on
-- DanNet being loaded - if it is not, the Stop button does nothing at all. This way our own
-- character always halts even when the group half cannot be delivered.
-- MQ2Nav state, read live rather than tracked in a flag of our own - nav can stop on its own and a
-- local flag would drift. Note Active can be false while Paused is true (pppoker's finding).
local function navIsPaused()
    return mq.TLO.Navigation.Paused() == true
end

local function navIsActive()
    return mq.TLO.Navigation.Active() == true
end

-- /nav pause keeps the path; /nav pause off resumes it. Confirmed in TRAVEL_REFERENCE and pppoker.
-- Pausing with no active route just prints "[Nav] Navigation must be active to pause" and does
-- nothing, which is why the button is only live while a route exists.
local function travelPauseToggle()
    if navIsPaused() then
        mq.cmd('/squelch /nav pause off')
        if travellingAsGroup() then mq.cmd('/dgae /squelch /nav pause off') end
    else
        mq.cmd('/squelch /nav pause')
        if travellingAsGroup() then mq.cmd('/dgae /squelch /nav pause') end
    end
end

local function travelStop()
    mq.cmd('/travelto stop')
    if travellingAsGroup() then
        mq.cmd('/dgae /travelto stop')
    end
end

--========================
-- UI - sections
--========================
-- DrawZoneSelector was one 315-line function holding 50 upvalues against LuaJIT's cap of 60. Every
-- queued feature (travel button, Help tab, version readout) lands in this area and would have pushed
-- it over. The cap is PER FUNCTION, so splitting by section gives each one its own budget.
-- Every ImGui Begin/End pair stays in DrawZoneSelector below, where it can be checked at a glance;
-- these helpers only draw inside an already-open child.

-- One toggle: a label plus a clickable on/off glyph. Lua cannot pass the state by reference, so the
-- caller assigns the return value back:
--     showHotzonesOnly = drawToggle("Hotzones Only:", showHotzonesOnly, "showHotzonesOnly", labelWidth)
-- Replaces seven near-identical five-line blocks.
-- labelWidth pads the label column so the glyphs line up. Omit it and the toggle sits directly
-- after the label, which is what the inline "Expansion Only:" beside the expansion combo wants.
-- The toggle grid's right-hand column. drawFilterInputs lines Reset Filters up with it and
-- drawToggles starts every right-column toggle at it, so it lives in one place rather than being
-- spelled out in both and drifting.
local function toggleColumnX()
    return ImGui.GetWindowWidth() / 2 + 50
end

-- Every label in the toggle grid. The labels differ in length, so butting each toggle up against its
-- own label leaves them ragged down the column - the width is MEASURED from the longest and every
-- label padded to it. 2.3.36-2.3.46 was eleven versions of nudging a hardcoded number instead.
-- Shared rather than local to drawToggles because the map icon aligns to the grid's right edge, so
-- there are two readers and one list.
local TOGGLE_LABELS = { "Hotzones Only:", "Platinum Only:", "Remove Cities:", "Outdoor Only:",
                        "Favorites Only:", "Short Names:", "Hunting Only:", "Expansion Only:" }

local function toggleLabelWidth()
    local widest = 0
    for _, text in ipairs(TOGGLE_LABELS) do
        local w = ImGui.CalcTextSize(text)
        if w > widest then widest = w end
    end
    return widest + 8
end

-- Right edge of the grid's right-hand column: the column x, plus the padded label, plus the toggle
-- glyph that sits after it.
local function toggleColumnRightX()
    return toggleColumnX() + toggleLabelWidth() + ImGui.CalcTextSize(Icons.FA_TOGGLE_ON or "[ ]")
end

local function drawToggle(label, value, id, labelWidth, tip, tipSub)
    local startX = ImGui.GetCursorPosX()
    ImGui.Text(label)
    -- Tip on the LABEL too, not just the glyph: the label is the wider target and the part a user
    -- reads, so it is where the pointer already is when they wonder what the filter does.
    if tip then hoverTip(tip, tipSub) end
    if labelWidth then ImGui.SameLine(startX + labelWidth) else ImGui.SameLine() end
    ImGui.PushID(id)
    ImGui.TextColored(value and COLOR_ON or COLOR_OFF, value and Icons.FA_TOGGLE_ON or Icons.FA_TOGGLE_OFF)
    -- Read the click BEFORE drawing the tooltip. hoverTip submits a tooltip window, after which
    -- IsItemHovered() no longer refers to the glyph - the toggle would stop responding.
    if ImGui.IsItemHovered() and ImGui.IsMouseClicked(0) then value = not value end
    if tip then hoverTip(tip, tipSub) end
    ImGui.PopID()
    return value
end

local function drawThemePicker()
    ImGui.Text("Theme:")
    ImGui.SameLine()
    ImGui.SetNextItemWidth(150)
    if ImGui.BeginCombo("##Theme", currentTheme) then
        for _, name in ipairs(THEME_NAMES) do
            local isSelected = (name == currentTheme)
            if ImGui.Selectable(name, isSelected) then
                currentTheme = name
                SaveThemeSetting()
            end
            if isSelected then ImGui.SetItemDefaultFocus() end
        end
        ImGui.EndCombo()
    end
end

local function drawServerPicker()
    ImGui.Text("Server:")
    ImGui.SameLine()
    ImGui.TextColored(COLOR_ON, mq.TLO.EverQuest.Server() or "Unknown")
    ImGui.SameLine()
    ImGui.SetNextItemWidth(100)
    if ImGui.BeginCombo("##ServerMode", serverMode) then
        -- Live first and default. Lazarus + EQ Might are planned; their code paths (maxExpForMode,
        -- the zem.lazarus column, duplicate preference) are already in place, so re-enabling a mode
        -- is just adding its name to SERVER_MODES.
        for _, mode in ipairs(SERVER_MODES) do
            local isSelected = (mode == serverMode)
            if ImGui.Selectable(mode, isSelected) then
                serverMode = mode
                SaveServerSetting()
            end
            if isSelected then ImGui.SetItemDefaultFocus() end
        end
        ImGui.EndCombo()
    end
end

local function drawFilterInputs()
    local filterLabelWidth = 85
    local filterTopY = ImGui.GetCursorPosY()   -- top of the Zone Name row; the icon spans from here

    ImGui.Text("Zone Name:") ImGui.SameLine(filterLabelWidth)
    ImGui.SetNextItemWidth(250)
    filterName = ImGui.InputText("##ZoneName", filterName)

    ImGui.Text("ZEM:") ImGui.SameLine(filterLabelWidth)
    hoverTip("Zone Experience Modifier")
    ImGui.Text("Min") ImGui.SameLine()
    ImGui.SetNextItemWidth(90)
    filterZemMin = ImGui.InputFloat("##ZemMin", filterZemMin, 0.1, 1.0, "%.2f")
    ImGui.SameLine(0, 8)
    ImGui.Text("Max") ImGui.SameLine()
    ImGui.SetNextItemWidth(90)
    filterZemMax = ImGui.InputFloat("##ZemMax", filterZemMax, 0.1, 1.0, "%.2f")

    ImGui.Text("Level:") ImGui.SameLine(filterLabelWidth)
    ImGui.Text("Min") ImGui.SameLine()
    ImGui.SetNextItemWidth(90)
    filterLevelMin = ImGui.InputInt("##LevelMin", filterLevelMin, 1, 10)
    ImGui.SameLine(0, 8)
    ImGui.Text("Max") ImGui.SameLine()
    ImGui.SetNextItemWidth(90)
    filterLevelMax = ImGui.InputInt("##LevelMax", filterLevelMax, 1, 10)

    -- One icon spanning ALL THREE filter rows (Zone Name, ZEM, Level), sitting in the toggle grid's
    -- right-hand column so it lines up with Reset Filters and the toggles below it. Drawn LAST and
    -- positioned back up at the first row, so it cannot change any row's height - an image taller
    -- than a text line placed inline would push every row below it down. Size comes from the rows
    -- themselves, so it tracks the font rather than being a magic number.
    local rowsEndY = ImGui.GetCursorPosY()
    local style = ImGui.GetStyle()
    local mapIcon = getMapIcon()
    if mapIcon then
        local iconSize = rowsEndY - filterTopY - style.ItemSpacing.y
        -- RIGHT-aligned to the toggle grid's right edge, so the icon finishes where the toggle
        -- glyphs below it finish. max() keeps it clear of the Zone Name input (the widest thing in
        -- this block: starts at filterLabelWidth, 250 wide) at narrow window widths, where the
        -- computed x can fall behind it - same guard as Reset Filters.
        local iconX = math.max(toggleColumnRightX() - iconSize,
                               filterLabelWidth + 250 + style.ItemSpacing.x)
        ImGui.SetCursorPos(ImVec2(iconX, filterTopY))
        ImGui.Image(mapIcon:GetTextureID(), ImVec2(iconSize, iconSize))
        ImGui.SetCursorPosY(rowsEndY)   -- put the cursor back so the Expansion row lands normally
    end

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
    -- Reset Filters sits on this line at the toggle grid's right-hand column, so it lines up with
    -- the labels below it rather than floating against the window edge. Expansion Only moved down
    -- into the grid, which is what freed this spot.
    -- max() so a narrow window degrades instead of overlapping: the combo ends at ~285px, and
    -- toggleColumnX() drops below that under ~486px of window, which would draw the button on top
    -- of it. Below that width the button just follows the combo.
    ImGui.SameLine()
    ImGui.SetCursorPosX(math.max(toggleColumnX(), ImGui.GetCursorPosX()))
    if ImGui.Button("Reset Filters") then ResetFilters() end
    hoverTip("Reset All Filters")
end

local function drawToggles()
    local leftOffset = 50
    local midOffset = toggleColumnX()

    local labelWidth = toggleLabelWidth()

    ImGui.SetCursorPosX(leftOffset)
    showHotzonesOnly  = drawToggle("Hotzones Only:",  showHotzonesOnly,  "showHotzonesOnly", labelWidth)
    ImGui.SameLine(midOffset)
    showExpansionOnly = drawToggle("Expansion Only:", showExpansionOnly, "showExpansionOnly", labelWidth)

    ImGui.SetCursorPosX(leftOffset)
    removeCities      = drawToggle("Remove Cities:",  removeCities,      "removeCities", labelWidth)
    ImGui.SameLine(midOffset)
    showPlatinumOnly  = drawToggle("Platinum Only:",  showPlatinumOnly,  "showPlatinumOnly", labelWidth)

    ImGui.SetCursorPosX(leftOffset)
    showFavoritesOnly = drawToggle("Favorites Only:", showFavoritesOnly, "showFavoritesOnly", labelWidth)
    ImGui.SameLine(midOffset)
    showOutdoorOnly   = drawToggle("Outdoor Only:",   showOutdoorOnly,   "showOutdoorOnly", labelWidth)

    ImGui.SetCursorPosX(leftOffset)
    showHuntableOnly  = drawToggle("Hunting Only:",   showHuntableOnly,  "showHuntableOnly", labelWidth,
        "Hide zones that are not places you go to kill things.",
        "Mission hubs, arenas, guild halls, cities, housing\nand loading zones are hidden.\n" ..
        "Zones with no level data are KEPT - that is a gap\nin the zone data, not an empty zone.")
    ImGui.SameLine(midOffset)
    useShortNames     = drawToggle("Short Names:",    useShortNames,     "useShortNames", labelWidth)
end

-- Rebuild gating.
--
-- The visible set and its three sort keys per row were rebuilt EVERY FRAME, whether or not anything
-- had changed: ~1.6 ms and ~1,100 table allocations per frame for 563 zones, 60 times a second, to
-- produce an identical answer. Everything that can change the result is folded into one string; if
-- it matches last frame's, the cached list is returned untouched.
--
-- A signature beats dirty-flagging every mutation site because there is no way to forget one - a new
-- filter that is not added here shows up immediately as "the list does not update", which is obvious,
-- rather than as a subtle staleness nobody notices.
local lastBuildSignature = nil
local cachedVisibleZones, cachedVisibleCount = {}, 0

local function buildSignature()
    return table.concat({
        filterName, filterZemMin, filterZemMax, filterLevelMin, filterLevelMax,
        selectedExpansion, serverMode, zoneEditCount,
        tostring(useShortNames), tostring(showHotzonesOnly), tostring(removeCities),
        tostring(showPlatinumOnly), tostring(showFavoritesOnly),
        tostring(showExpansionOnly), tostring(showOutdoorOnly), tostring(showHuntableOnly),
        tostring(showAllVersions),
    }, "")
end

-- Pure compute, no drawing: which zones survive the filters, with their sort keys built.
local function buildVisibleZones()
    local signature = buildSignature()
    if signature == lastBuildSignature then
        return cachedVisibleZones, cachedVisibleCount
    end
    lastBuildSignature = signature

    -- Visible zones
    local visibleZones, visibleZoneCount = {}, 0
    local maxExpansionLevel = zones.expansionOrder[selectedExpansion] or 999
    if not zones.expansionOrder[selectedExpansion] then
        mq.cmdf("/echo Warning: Selected expansion %s not found in expansionOrder", selectedExpansion)
        selectedExpansion = "Live"
        maxExpansionLevel = zones.expansionOrder[selectedExpansion] or 999
    end
    for _, zone in ipairs(zones.zones) do
        if zonePassesFilters(zone, maxExpansionLevel) then
            zone._alphaKey = build_alpha_key(zone, useShortNames)
            zone._levelKey = build_level_key(zone)
            build_zem_keys(zone, serverMode)
            table.insert(visibleZones, zone)
            visibleZoneCount = visibleZoneCount + 1
        end
    end
    cachedVisibleZones, cachedVisibleCount = visibleZones, visibleZoneCount
    return visibleZones, visibleZoneCount
end

local lastSortSignature = nil
local cachedSortedZones = nil

local function drawZoneTable(visibleZones)
    -- Table
    ImGui.BeginChild("ZoneTableChild", ImVec2(0, -1), true)

    if ImGui.BeginTable("ZoneTable",
        8,
        ImGuiTableFlags.Sortable + ImGuiTableFlags.Resizable + ImGuiTableFlags.Borders + ImGuiTableFlags.ScrollY) then

        -- Name, Level, ZEM sortable; others locked.
        ImGui.TableSetupColumn("Zone Name",
            ImGuiTableColumnFlags.WidthStretch + ImGuiTableColumnFlags.DefaultSort, 1.0, ColumnID_Name)
        -- Widths are set by the HEADER text plus its sort arrow, not by the content: the level cell
        -- only ever holds "38-49" or "--". "Level Range" needed ~100px for the header alone, so the
        -- header is now "Level" and the column fits in 74. ZEM needs ~51 and had 100.
        -- Freed 78px total, which the stretching Zone Name column absorbs.
        ImGui.TableSetupColumn("Level",
            ImGuiTableColumnFlags.WidthFixed, 74.0, ColumnID_LevelRange)
        ImGui.TableSetupColumn("ZEM",
            ImGuiTableColumnFlags.WidthFixed, 52.0, ColumnID_ZEM)
        ImGui.TableSetupColumn("##Hotzone",
            ImGuiTableColumnFlags.WidthFixed + ImGuiTableColumnFlags.NoSort + ImGuiTableColumnFlags.NoSortAscending + ImGuiTableColumnFlags.NoSortDescending,
            26.0, ColumnID_Hotzone)
        ImGui.TableSetupColumn("##Favorites",
            ImGuiTableColumnFlags.WidthFixed + ImGuiTableColumnFlags.NoSort + ImGuiTableColumnFlags.NoSortAscending + ImGuiTableColumnFlags.NoSortDescending,
            26.0, ColumnID_Favorites)
        ImGui.TableSetupColumn("##Platinum",
            ImGuiTableColumnFlags.WidthFixed + ImGuiTableColumnFlags.NoSort + ImGuiTableColumnFlags.NoSortAscending + ImGuiTableColumnFlags.NoSortDescending,
            26.0, ColumnID_Platinum)
        ImGui.TableSetupColumn("##Travel",
            ImGuiTableColumnFlags.WidthFixed + ImGuiTableColumnFlags.NoSort + ImGuiTableColumnFlags.NoSortAscending + ImGuiTableColumnFlags.NoSortDescending,
            30.0, ColumnID_Travel)
        ImGui.TableSetupColumn("##Pad",
            ImGuiTableColumnFlags.WidthFixed + ImGuiTableColumnFlags.NoSort + ImGuiTableColumnFlags.NoSortAscending + ImGuiTableColumnFlags.NoSortDescending,
            8.0)

        -- ScrollY alone does NOT pin the header - TableSetupScrollFreeze is the only thing that
        -- does, and it must come after every TableSetupColumn and before the header row.
        -- (0 columns frozen, 1 row.)
        ImGui.TableSetupScrollFreeze(0, 1)

        ImGui.TableNextRow(ImGuiTableRowFlags.Headers)
        ImGui.TableSetColumnIndex(ColumnID_Name)       ImGui.TableHeader("Zone Name")
        ImGui.TableSetColumnIndex(ColumnID_LevelRange) ImGui.TableHeader("Level")
        ImGui.TableSetColumnIndex(ColumnID_ZEM)        ImGui.TableHeader("ZEM")
        ImGui.TableSetColumnIndex(ColumnID_Hotzone)    centerIconInCell(Icons.FA_FIRE, "Hotzones")
        ImGui.TableSetColumnIndex(ColumnID_Favorites)  centerIconInCell(Icons.FA_STAR, "Favorites")
        ImGui.TableSetColumnIndex(ColumnID_Platinum)   centerIconInCell(Icons.FA_DATABASE, "Platinum")
        ImGui.TableSetColumnIndex(ColumnID_Travel)     centerIconInCell(Icons.FA_PLAY or ">", "Travel to zone")
        ImGui.TableSetColumnIndex(7)                   ImGui.Text("")

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

        -- The sort is gated on the same signature plus the chosen column and direction, so it runs
        -- on interaction rather than on every frame.
        local sortSignature = (lastBuildSignature or "") .. "|" .. sortTarget .. "|" .. tostring(asc)
        if sortSignature ~= lastSortSignature then
            lastSortSignature = sortSignature
            cachedSortedZones = nil
        end

        if cachedSortedZones then
            visibleZones = cachedSortedZones
        elseif #visibleZones > 1 then
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
            -- ZEM keys already encode direction (_zemKeyAsc / _zemKeyDesc), so they always sort
            -- ascending; name/level let build_sorted_by_key invert. This used to sort ascending and
            -- then, for a descending name/level, invert the keys and sort a SECOND time.
            build_sorted_by_key(rows, (sortTarget == "zem") or asc)

            local sorted = {}
            for _, r in ipairs(rows) do sorted[#sorted+1] = visibleZones[r.idx] end
            visibleZones = sorted
            cachedSortedZones = sorted
        end

        -- Both gates are TLO reads, so they are evaluated once per frame here rather than once per
        -- row - 563 plugin/zone lookups a frame would be pure waste.
        local canTravel = easyFindLoaded()
        local currentZone = (mq.TLO.Zone.ShortName() or ""):lower()

        -- Body rows
        for _, zone in ipairs(visibleZones) do
            ImGui.TableNextRow()

            local zoneKey = (zone.shortName or "") .. "|" .. (zone.expansion or "")
            if selectedZoneKey == zoneKey then
                -- A white wash rather than a themed colour: it reads on all 11 palettes and needs no
                -- per-theme key. Same trick TableRowBgAlt already uses at 0.03.
                ImGui.TableSetBgColor(ImGuiTableBgTarget.RowBg0, ImGui.GetColorU32(1.0, 1.0, 1.0, 0.13))
            end

            ImGui.TableNextColumn()
            -- Selectable rather than Text so the name cell is the click target. Deliberately NOT
            -- SpanAllColumns: that would cover the star, coin and Go buttons and swallow their
            -- clicks. The name column is the widest by far, so clicking "the line" lands here.
            -- `selected` is always false - ImGui's own highlight would double up with the row tint
            -- above; this only wants the hover affordance.
            local label = (useShortNames and zone.shortName or zone.fullName) or "Unknown"
            if ImGui.Selectable(label .. "##row" .. zoneKey, false) then
                -- NOT `(selectedZoneKey == zoneKey) and nil or zoneKey` - that is
                -- the ternary that can never return nil: `true and nil` is
                -- nil, which is falsy, so `or` always takes the right branch and the row could
                -- only ever be set, never cleared. AL spotted the symptom in game.
                if selectedZoneKey == zoneKey then
                    selectedZoneKey = nil
                else
                    selectedZoneKey = zoneKey
                end
            end
            -- Always show whichever name is NOT on screen, so the two directions cannot drift -
            -- one expression, not a branch per mode. Sorting follows the DISPLAYED name, so
            -- toggling short names legitimately reorders the table; this makes any single row
            -- self-identifying without a second column eating the width we just freed.
            -- TextDisabled (not COLOR_DISABLED) so the expansion line follows the active theme.
            hoverTip((useShortNames and zone.fullName or zone.shortName) or "Unknown", zone.expansion or "")

            ImGui.TableNextColumn()
            if (zone.levelmax or 0) > 0 then
                ImGui.Text(string.format("%d-%d", zone.levelmin or 0, zone.levelmax or 0))
            else
                ImGui.TextColored(COLOR_DISABLED, "--")   -- no level data, not level zero
            end

            ImGui.TableNextColumn()
            local disp = zone._zemDisp
            if type(disp) == "number" then
                ImGui.Text(string.format("%.2f", disp))
            else
                ImGui.Text(tostring(disp or "--"))
            end

            ImGui.TableNextColumn()
            if zone.hotzone then
                drawCenteredIconInCell(Icons.FA_FIRE, COLOR_HOTZONE)
            else
                drawCenteredIconInCell(" ", nil)
            end

            ImGui.TableNextColumn()
            ImGui.PushStyleColor(ImGuiCol.Button,        COLOR_TRANSPARENT)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, COLOR_TRANSPARENT)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive,  COLOR_TRANSPARENT)
            ImGui.PushStyleColor(ImGuiCol.Text,          COLOR_FAVORITE)
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
            ImGui.PushStyleColor(ImGuiCol.Button,        COLOR_TRANSPARENT)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, COLOR_TRANSPARENT)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive,  COLOR_TRANSPARENT)
            local wasPlatinum = zone.isPlatinum  -- Capture state before potential toggle
            if wasPlatinum then ImGui.PushStyleColor(ImGuiCol.Text, COLOR_PLATINUM) end
            centerNextItemInCell(30)
            if ImGui.Button(wasPlatinum and Icons.FA_DATABASE or " ", ImVec2(30, 20)) then
                zone.isPlatinum = not zone.isPlatinum
                SaveZoneSettings(zone)
            end
            if wasPlatinum then ImGui.PopStyleColor() end
            ImGui.PopStyleColor(3)
            ImGui.PopID()

            ImGui.TableNextColumn()
            local isHere = (zone.shortName or ""):lower() == currentZone
            if canTravel and not isHere then
                ImGui.PushID("Go_" .. (zone.shortName or "unknown"))
                ImGui.PushStyleColor(ImGuiCol.Button,        COLOR_TRANSPARENT)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, COLOR_TRANSPARENT)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive,  COLOR_TRANSPARENT)
                centerNextItemInCell(30)
                if ImGui.Button(Icons.FA_PLAY or ">", ImVec2(30, 20)) then
                    travelTo(zone.shortName)
                end
                ImGui.PopStyleColor(3)
                ImGui.PopID()
                hoverTip("Travel to " .. (zone.fullName or zone.shortName))
            else
                drawCenteredIconInCell(Icons.FA_PLAY or ">", COLOR_DISABLED)
                hoverTip(isHere and "You are already here" or "MQ2EasyFind is not loaded")
            end
        end

        ImGui.EndTable()
    end
    ImGui.EndChild()
end

local function sectionHeading(text)
    ImGui.TextColored(COLOR_HEADING, text)
end

local function drawSettingsTab()
    ImGui.Spacing()
    sectionHeading("Appearance")
    drawThemePicker()
    ImGui.TextDisabled("Applies instantly and is saved to HuntBuddySettings.ini.")
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    sectionHeading("Zone list")
    local wasAll = showAllVersions
    showAllVersions = drawToggle("Show all zone versions:", showAllVersions, "showAllVersions")
    if showAllVersions ~= wasAll then SaveShowAllVersionsSetting() end
    hoverTip("Show zones that were replaced by a newer version.",
             "Only affects Live - EMU already shows both.")
    -- Deliberately NOT a list of the zones. It was one, written when there were nine; there are 24,
    -- and the count moved three times in a day. Explaining the naming instead cannot go stale.
    ImGui.TextWrapped("Zones that exist in two generations are named 1.0 and 2.0 - 1.0 is the " ..
        "classic zone, 2.0 the version that replaced it. On Live the 1.0 half is usually a zone " ..
        "you cannot enter, so it is hidden.")
    ImGui.TextWrapped("Turn this on if your server runs the other generation, or if a zone you " ..
        "know exists is missing from the list.")
    ImGui.Spacing()
end

local function drawHelpTab()
    -- Two-column rows with a MEASURED label column, indented under their heading. The glyphs use the
    -- same colours they have in the table, so the legend reads as the thing it describes rather than
    -- as a wall of identical grey text.
    local function twoColumn(rows)
        local widest = 0
        for _, row in ipairs(rows) do
            local w = ImGui.CalcTextSize(row[1])
            if w > widest then widest = w end
        end
        for _, row in ipairs(rows) do
            local startX = ImGui.GetCursorPosX()
            if row[2] then ImGui.TextColored(row[2], row[1]) else ImGui.Text(row[1]) end
            ImGui.SameLine(startX + widest + 18)
            ImGui.TextDisabled(row[3])
        end
    end

    local function section(title, draw)
        sectionHeading(title)
        ImGui.Indent()
        draw()
        ImGui.Unindent()
        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()
    end

    ImGui.Spacing()

    section("Getting started", function()
        twoColumn({
            { "/lua run huntbuddy", nil, "start HuntBuddy" },
        })
    end)

    section("The columns", function()
        twoColumn({
            { "ZEM",                    nil,             "Zone Experience Modifier - higher is faster XP" },
            { Icons.FA_FIRE,            COLOR_HOTZONE,   "Hotzone" },
            { Icons.FA_STAR,            COLOR_FAVORITE,  "Favourite - click to mark, saved between sessions" },
            { Icons.FA_DATABASE,        COLOR_PLATINUM,  "Platinum - your own 'good money here' mark" },
            { Icons.FA_PLAY or ">",     COLOR_ON,        "Travel to that zone (needs the MQ2EasyFind plugin)" },
        })
    end)

    section("Travelling", function()
        twoColumn({
            { "Go",           COLOR_ON,       "Travel to that row's zone" },
            { "Group Travel", nil,            "Send the whole group. Ignored when you are not in one." },
            { "Pause",        nil,            "Stop moving but keep the route - Resume picks it up" },
            { "Stop",         nil,            "Abandon the route entirely" },
        })
        ImGui.Spacing()
        ImGui.TextWrapped("Go is greyed out for the zone you are already in, and for every zone when MQ2EasyFind is not loaded.")
    end)

    section("Tips", function()
        -- Bullet + SameLine(0,0) + TextWrapped: BulletText does not wrap and these are sentences.
        local function tip(text)
            ImGui.Bullet() ImGui.SameLine(0, 0) ImGui.TextWrapped(text)
            ImGui.Spacing()
        end
        tip("Server mode changes both the expansion cap and which ZEM column is shown. It is saved, so you only pick it once.")
        tip("The Expansion dropdown is a cap - it shows everything up to that expansion. Turn on Expansion Only to see just that one.")
        tip("Favourites and Platinum marks are stored per zone and survive updates.")
        tip("Hunting Only hides zones that exist but are not places you go to kill things - mission instances, loading zones, guild halls, housing and arenas.")
        tip("On Live, zones your client has no files for are hidden automatically. Switch to EMU to see them - that is where they still exist.")
        tip("LDoN dungeons all show 15-75 because their adventures SCALE to your level. The zone gives you an adventure matched to you, so any level in that span is valid - it is not a normal narrow range.")
        tip("Sort by clicking Zone Name, Level Range or ZEM. Zones with no ZEM for the current server always sort to the bottom.")
    end)

    sectionHeading("Version")
    ImGui.Indent()
    twoColumn({
        { "HuntBuddy", nil, "v" .. version },
        { "Zone data", nil, "v" .. (zones.dataVersion or "unknown") },
    })
    ImGui.Spacing()
    -- 91 of the 580 zones show "--" for level, and without this line that reads as a bug rather
    -- than a known gap. Our level data comes from PEQ, whose content stops at Rain of Fear (2012).
    ImGui.TextWrapped('A level range of "--" means we have no level data for that zone - not that '
        .. 'it is empty. Zones from Call of the Forsaken onward are listed by name only.')
    ImGui.Spacing()
    ImGui.TextDisabled("Created by RedFrog")
    ImGui.Unindent()
    ImGui.Spacing()
end

-- The rotation pool laid out as it appears on Allakhazam - three slots per level bracket - with the
-- slots AL has confirmed in game highlighted. Presented as a table rather than folded into the Zones
-- tab because the pattern only shows up in columns: brackets 20-45 run slot 1 and 50-85 run slot 3,
-- which is invisible in a flat "is it hot" flag. AL wants it to watch whether that pattern holds
-- across future rotations, and it doubles as a quick reference.
local function drawHotZoneTab()
    ImGui.Spacing()
    ImGui.TextWrapped("Each level bracket rotates between three possible hot zones. Orange marks the "
        .. "one confirmed active in game; the others are in the pool but not currently offered.")
    ImGui.Spacing()
    ImGui.TextDisabled("Verified against Franklin Teek, Plane of Knowledge - "
        .. (zones.hotPoolVerified or "date unknown")
        .. ". He only serves your own bracket and below, so 90+ is unconfirmed.")
    ImGui.Spacing()

    if not zones.hotPool then
        ImGui.TextColored(COLOR_OFF, "No hot zone pool in this zones.lua - update the data file.")
        return
    end

    ImGui.BeginChild("HotZoneChild", ImVec2(0, -1), true)
    if ImGui.BeginTable("HotZoneTable", 4,
        ImGuiTableFlags.Borders + ImGuiTableFlags.RowBg + ImGuiTableFlags.ScrollY) then
        ImGui.TableSetupColumn("Lvl", ImGuiTableColumnFlags.WidthFixed, 40.0)
        ImGui.TableSetupColumn("Slot 1", ImGuiTableColumnFlags.WidthStretch, 1.0)
        ImGui.TableSetupColumn("Slot 2", ImGuiTableColumnFlags.WidthStretch, 1.0)
        ImGui.TableSetupColumn("Slot 3", ImGuiTableColumnFlags.WidthStretch, 1.0)
        ImGui.TableSetupScrollFreeze(0, 1)
        ImGui.TableHeadersRow()

        for _, bracket in ipairs(zones.hotPool) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text(tostring(bracket.level))
            for slot = 1, 3 do
                ImGui.TableNextColumn()
                local entry = bracket[slot]
                if not entry then
                    ImGui.TextDisabled("-")            -- 100 and 105 have only two pool entries
                elseif bracket.active == slot then
                    -- COLOR_HOTZONE, the same orange as the flame in the Zones tab, so "hot" reads
                    -- the same way in both places.
                    ImGui.TextColored(COLOR_HOTZONE, entry.name)
                elseif bracket.active == nil then
                    -- Whole bracket unverified: nothing here is known to be active, so do not imply
                    -- the plain ones are known NOT to be.
                    ImGui.TextDisabled(entry.name)
                else
                    ImGui.Text(entry.name)
                end
            end
        end
        ImGui.EndTable()
    end
    ImGui.EndChild()
end

local function drawTravelBar(visibleZoneCount)
    local hasEasyFind = easyFindLoaded()

    -- The bar sits BETWEEN two bordered children, which inset their contents by WindowPadding, so
    -- at window level it starts a few px left of everything above and below it. Read the real
    -- padding rather than hardcoding 8 - the value is ImGui's, not ours.
    local style = ImGui.GetStyle()
    local pad = style.WindowPadding.x
    ImGui.Indent(pad)

    ImGui.Text("Zones: " .. visibleZoneCount)
    if not hasEasyFind then
        -- Sits on the LEFT with the count, not after Stop: the travel controls are right-aligned to
        -- a measured width, and appending a long warning to them would push it off the edge.
        ImGui.SameLine()
        ImGui.TextColored(COLOR_OFF, "MQ2EasyFind not loaded - travel unavailable")
    end

    -- Right-align the travel controls so they sit under the table's Go column. Width is measured,
    -- and the Pause slot is measured at its WIDEST label ("Resume") so the bar does not jump when
    -- a route starts or stops.
    local toggleW = ImGui.CalcTextSize("Group Travel:") + style.ItemSpacing.x
                    + ImGui.CalcTextSize(Icons.FA_TOGGLE_ON or "[ ]")
    local pauseW  = ImGui.CalcTextSize("Resume") + style.FramePadding.x * 2
    local stopW   = ImGui.CalcTextSize("Stop")   + style.FramePadding.x * 2
    local barW    = toggleW + pauseW + stopW + style.ItemSpacing.x * 2
    ImGui.SameLine()
    ImGui.SetCursorPosX(ImGui.GetWindowWidth() - barW - pad * 2)

    local wasGroup = groupTravel
    groupTravel = drawToggle("Group Travel:", groupTravel, "groupTravel")
    if groupTravel ~= wasGroup then SaveTravelSetting() end
    hoverTip("Send the whole group. Ignored when you are not in a group.")

    -- Pause is inert with no route: /nav pause without one just prints "Navigation must be active
    -- to pause" and does nothing. State comes from the Navigation TLO, never a local flag.
    ImGui.SameLine()
    local paused = navIsPaused()
    if paused or navIsActive() then
        if ImGui.Button(paused and "Resume" or "Pause") then travelPauseToggle() end
        hoverTip(paused and "Resume the paused route." or "Stop moving but keep the route.")
    else
        ImGui.TextColored(COLOR_DISABLED, "Pause")
        hoverTip("Nothing to pause - no route is running.")
    end

    ImGui.SameLine()
    if ImGui.Button("Stop") then travelStop() end
    hoverTip("Abandon the route. Always stops you; also stops the group when Group Travel is on.")

    ImGui.Unindent(pad)   -- must match the Indent above or it leaks into the table below
end

local function drawZonesTab()
    -- 270 -> 240: the theme row and its separator moved to the Settings tab, and the tab bar takes
    -- roughly that much back at the top of the window.
    ImGui.BeginChild("HeaderSection", ImVec2(0, 240), true)
    drawServerPicker()
    ImGui.Separator()
    drawFilterInputs()
    drawToggles()

    -- Clamp after the inputs are read, before anything filters on them.
    if filterZemMin < 0 then filterZemMin = 0 end
    if filterZemMax < filterZemMin then filterZemMax = filterZemMin end
    if filterLevelMin < 1 then filterLevelMin = 1 end
    if filterLevelMax < filterLevelMin then filterLevelMax = filterLevelMin end

    local visibleZones, visibleZoneCount = buildVisibleZones()
    ImGui.EndChild()

    drawTravelBar(visibleZoneCount)
    drawZoneTable(visibleZones)
end

--========================
-- UI
--========================
local function DrawZoneSelector()
    if not openGUI then return end

    local ColorCount, StyleCount = pushTheme()
    -- The window was NoResize at a fixed 600x800, so a user whose content did not fit had no way to
    -- do anything about it. It is now resizable with a floor that keeps the two-column toggle row
    -- from collapsing. The layout was already width-responsive (ImVec2(0, -1), GetWindowWidth()).
    -- NOTE: the header child's height (see drawZonesTab) and the toggle row's left/mid column
    -- offsets are still fixed values; the toggle LABEL width is measured as of 2.13.
    ImGui.SetNextWindowSize(ImVec2(600, 800), ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowSizeConstraints(ImVec2(500, 400), ImVec2(4000, 4000))
    local isOpen, shouldDraw = ImGui.Begin("HuntBuddy " .. version, true, ImGuiWindowFlags.NoScrollbar)
    openGUI = isOpen

    if not shouldDraw then
        ImGui.End()
        popTheme(ColorCount, StyleCount)
        return
    end

    -- Icon names are guarded: one MQ's bundled subset lacks degrades to no icon, never a crash.
    if ImGui.BeginTabBar("##HuntBuddyTabs") then
        if ImGui.BeginTabItem((Icons.FA_MAP_O or "") .. "  Zones") then
            drawZonesTab()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem((Icons.FA_FIRE or "") .. "  HotZone") then
            drawHotZoneTab()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem((Icons.FA_COG or "") .. "  Settings") then
            drawSettingsTab()
            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem((Icons.FA_QUESTION_CIRCLE or "") .. "  Help") then
            drawHelpTab()
            ImGui.EndTabItem()
        end
        ImGui.EndTabBar()
    end

    ImGui.End()
    popTheme(ColorCount, StyleCount)
end

--========================
-- Main
--========================
local function main()
    LoadSettings()
    buildClassicLivePairs()
    mq.imgui.init("HuntBuddy", DrawZoneSelector)
    while openGUI do mq.delay(100) end
end

main()
