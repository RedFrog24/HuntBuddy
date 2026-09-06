-- zones.lua
-- Created by: RedFrog
-- Original creation date: 03/23/2024
-- Version controlled by `zones.dataVersion` below (single source of truth - shown in the Help tab).
--
-- REBUILT FROM SCRATCH. The old hand-curated table is kept beside this one as zones2.lua, reference
-- only, not loaded. An audit found 240 of its 563 rows flagged hotzone against ~50 real ones, level
-- ranges contradicting the game (Velketor's Labyrinth 90-110 against an actual 45-55), and 79
-- invented zone ids. Nothing is copied from it.
--
-- WHERE EACH FIELD COMES FROM - every value here is sourced, none are guessed
--   short / name / expansion  MacroQuest's own resources/Zones.ini. Canonical and matched to the
--                             installed client, so a zone that is not real cannot appear here.
--   id                        PEQ (ProjectEQ) database, zone.zoneidnumber. Real ids.
--   zem                       PEQ zone.zone_exp_multiplier. AUTHORITATIVE FOR EMU - see "ZEM" below.
--   min / max                 DERIVED from the levels of the NPCs actually spawned in the zone
--                             (PEQ spawn2 -> spawnentry -> npc_types), 25th to 90th percentile so
--                             one high-level named cannot stretch the range, and ambient fauna
--                             cannot drag the floor down - Barren Coast is 53% level 5-25 fish and
--                             sea turtles, which made a level 50-65 zone derive as "11-64". The
--                             trailing comment
--                             gives the spawn count it came from. CITY zones use 10th-to-median
--                             instead, because guards otherwise push a starter city to level 60.
--                             Invisible script triggers are EXCLUDED (race 127 / bodytype 11,67):
--                             PEQ spawns them as level-1 NPCs named things like You_trip and
--                             Trap_control - 16% of Akheva Ruins' rows - which dragged that zone to
--                             "1-64" instead of its real 47-56. Filtering them fixes the broken
--                             zones and leaves correct ones untouched.
--   indoor                    PEQ zone.ztype.
--   hot                       Franklin Teek's hot zone brackets (published list, Aug 2024). The
--                             number IS the bracket, so hot=50 means "the level 50 hot zone".
--   emuOnly                   MEASURED: this client ships no .s3d/.eqg for the zone, so Live cannot
--                             load it - see "emuOnly" below.
--   city / cat                `cat` marks a zone that is real but not somewhere you go and hunt, so
--                             filters can hide it: instance, dev, arena, hub, housing, event,
--                             unused, city, nodata. `cat="instance"` is derived; the rest are
--                             curated. `nodata` means PEQ has no spawn rows - a gap in OUR source,
--                             not proof the zone is empty, which is why the review overrides it
--                             zone by zone.
--
-- cat="instance" - mission/adventure zones you cannot simply travel to. Detected, not hand-listed,
-- using Explore.mac (Denethor's zone-achievement route in the macros folder), which is a list of
-- places a player can actually GO. It visits chardok, chardokb AND chardoktwo - three genuinely
-- separate zones - but skips all six "Muramite Proving Grounds (A-F)" chambers, which are mission
-- instances of the one real `provinggrounds`. Two rules follow from that:
--   1. named "X (Y)" where a zone named exactly "X" exists and IS on the route, and this one is not
--   2. the whole of LDoN, which added no persistent open zones - only instanced adventure dungeons
--      (all 48 are skipped by the route)
-- Explore.mac also independently corroborates emuOnly: it skips 32 of 32 zones flagged that way.
--
-- emuOnly: when a zone was revamped the client stopped shipping the old files, so "no client file"
-- is a measurable test for "EMU-era only, not loadable on Live". Verified against the revamp pairs -
-- commons/ecommons vs commonlands, misty vs mistythicket, sro vs southro, oot vs oceanoftears,
-- tox vs toxxulia: in every case the classic short name has no client file and the revamp does.
-- Two genuine exceptions ship BOTH: freporte + freeporteast, and nro + northro. Those are the real
-- classic/live twins the `version` field and the duplicate-preference logic exist to handle.
--
-- ZEM: Daybreak has never published Live ZEM values. The EMU multiplier stands in so the column and
-- its filter stay useful. Treat it as a relative hint, not a measured Live figure. ZEMs stopped
-- rotating years ago and now only move for global events, so a static value is reasonable.
--
-- MQ's own Zones.ini lists six short names twice, and the DISPLAY NAME is what tells the two cases
-- apart, so the dedupe key is (short name, display name) - not (short name, expansion):
--   SAME name    -> one zone listed twice, collapsed, LAST placement kept. crafthalls
--                   "Ngreth's Den" (since dropped entirely - see below), dragoncrypt "Lair of the
--                   Fallen" and weddingchapel "Wedding
--                   Chapel" are all listed under both Base EverQuest and Underfoot; resplendent
--                   "Resplendent Temple" is listed twice under Veil of Alaris. The later placement
--                   is the one that matches the level data - Lair of the Fallen derives to 85-85,
--                   which is Underfoot's band, not Classic's.
--   DIFFERENT name -> genuinely different zones, both kept. neriakd is "Neriak Palace" in Classic
--                   and "Neriak - Fourth Gate" in CotF; guildhalllrg is "Palatial Guidhall" and
--                   "Grand Guild Hall".
-- Keying on (short, expansion) instead let the three Classic|Underfoot pairs through as two rows
-- each, and they surfaced in two different expansion reviews before it was caught (2026-09-04).
--
-- LDoN ADVENTURES SCALE. All 48 LDoN dungeons show 15-75, which is the adventure band from the
-- game's own adventure_template table (nine bands: 15-20, 21-26 ... 63-75, 66 templates each) - NOT
-- a spawn-derived range, which for scaling content only reflects whatever level PEQ happened to
-- populate a dungeon at. The zone gives you an adventure matched to your level, so any level in
-- that span is valid. Confirmed against Allakhazam's LDoN page: 48 dungeons, exact match.
--
-- PLAYER HOUSING IS AUTO-DROPPED. House interiors reappear every expansion (HoT 8, VoA 12, RoF 1)
-- and are never hunting zones, so the build tool removes any zone whose name contains "House
-- Interior" or whose short name starts plh*/phinterior*. Outdoor housing NEIGHBOURHOODS are not
-- dropped - Sunrise Hills is a real place you can walk around, so it stays, flagged `housing`.
--
-- A few zones are DROPPED rather than categorised - see DROP in the build tool. Identity normally
-- comes from Zones.ini, which is what makes a fake zone impossible, so removing a row is a
-- deliberate exception and each one carries a reason.
--
-- THIS FILE IS MEANT TO BE EDITED. If your server's owner changed a ZEM, or a level range is off,
-- edit the row - one line per zone, every field named. Nothing here is generated at runtime.

local zones = {}

zones.dataVersion = "3.16-SoR"
zones.expansionOrder = { ["Classic"] = 1, ["RoK"] = 2, ["Velious"] = 3, ["Luclin"] = 4, ["PoP"] = 5, ["LoY"] = 6, ["LDoN"] = 7, ["GoD"] = 8, ["OoW"] = 9, ["DoN"] = 10, ["DoDh"] = 11, ["PoR"] = 12, ["TSS"] = 13, ["TBS"] = 14, ["SoF"] = 15, ["SoD"] = 16, ["UF"] = 17, ["HoT"] = 18, ["VoA"] = 19, ["RoF"] = 20, ["CotF"] = 21, ["TDS"] = 22, ["TBM"] = 23, ["EoK"] = 24, ["RoS"] = 25, ["TBL"] = 26, ["ToV"] = 27, ["CoV"] = 28, ["ToL"] = 29, ["NoS"] = 30, ["LS"] = 31, ["TOB"] = 32, ["SoR"] = 33, ["Live"] = 999 }
zones.expansionList  = { "Classic", "RoK", "Velious", "Luclin", "PoP", "LoY", "LDoN", "GoD", "OoW", "DoN", "DoDh", "PoR", "TSS", "TBS", "SoF", "SoD", "UF", "HoT", "VoA", "RoF", "CotF", "TDS", "TBM", "EoK", "RoS", "TBL", "ToV", "CoV", "ToL", "NoS", "LS", "TOB", "SoR", "Live" }

zones.zones = {}

-- One row per zone. `exp` is set per section below so it is not repeated on every line.
local exp
local function add(t)
    zones.zones[#zones.zones + 1] = {
        fullName     = t.name,
        shortName    = t.short,
        id           = t.id or 0,
        expansion    = exp,
        levelmin     = t.min or 0,
        levelmax     = t.max or 0,
        zem          = { emu = t.zem or "--", live = t.zem or "--", lazarus = t.zem or "--" },
        hotzone      = t.hot ~= nil,
        hotzoneLevel = t.hot,
        city         = t.city or false,
        indoor       = t.indoor or false,
        category     = t.cat,
        emuOnly      = t.emuOnly or false,
        isFavorite   = false,
        isPlatinum   = false,
        version      = "classic",
    }
end

--===== Classic : 118 zones =====
exp = "Classic"

add{ short="akanon", name="Ak'Anon", id=55, min=22, max=34, zem=1.33, indoor=true, city=true }  -- 321 spawns, city median
add{ short="arttest", name="Art Testing Domain", id=996, zem=1.00, indoor=true, cat="dev", emuOnly=true }  -- no spawn data
add{ short="aviak", name="Aviak Village", id=53, zem=1.00, cat="nodata", emuOnly=true }  -- no spawn data
add{ short="befallen", name="Befallen (A)", id=36, min=7, max=16, zem=2.13 }  -- 350 spawns
add{ short="befallenb", name="Befallen (B)", id=411, zem=1.00, cat="nodata", emuOnly=true }  -- no spawn data
add{ short="blackburrow", name="BlackBurrow", id=17, min=5, max=12, zem=1.33, indoor=true }  -- 295 spawns
add{ short="butcher", name="Butcherblock Mountains", id=68, min=1, max=35, zem=1.00, indoor=true }  -- 574 spawns
add{ short="mistmoore", name="Castle Mistmoore", id=59, min=29, max=34, zem=1.20, indoor=true }  -- 368 spawns
add{ short="cazicthule", name="Cazic-Thule", id=48, min=53, max=58, zem=1.13 }  -- 748 spawns
add{ short="crushbone", name="Clan Crushbone", id=58, min=4, max=13, zem=2.13 }  -- 236 spawns
add{ short="runnyeye", name="Clan RunnyEye", id=11, min=15, max=23, zem=1.33, indoor=true }  -- 347 spawns
add{ short="commonlands", name="Commonlands", id=408, min=3, max=45, zem=1.00, indoor=true }  -- 391 spawns
add{ short="cauldron", name="Dagnor's Cauldron", id=70, min=12, max=39, zem=1.00 }  -- 121 spawns
add{ short="apprentice", name="Designer Apprentice", id=999, zem=1.00, cat="dev", emuOnly=true }  -- no spawn data
add{ short="ecommons", name="East Commonlands", id=22, min=2, max=40, zem=1.00, indoor=true, emuOnly=true }  -- 332 spawns
add{ short="freporte", name="East Freeport", id=10, min=2, max=25, zem=1.00, indoor=true, city=true }  -- 244 spawns, city median
add{ short="freeporteast", name="East Freeport", id=382, min=40, max=70, zem=1.00, indoor=true }  -- 279 spawns
add{ short="eastkarana", name="East Karana", id=15, min=11, max=35, zem=1.00 }  -- 350 spawns
add{ short="erudsxing", name="Erud's Crossing", id=98, min=10, max=33, zem=1.00 }  -- 93 spawns
add{ short="erudnext", name="Erudin", id=24, min=14, max=30, zem=1.33, indoor=true, city=true }  -- 122 spawns, city median
add{ short="erudnint", name="Erudin Palace", id=23, min=30, max=35, zem=1.33, city=true }  -- 79 spawns, city median
add{ short="unrest", name="Estate of Unrest", id=63, min=15, max=28, zem=1.73, indoor=true }  -- 304 spawns
add{ short="everfrost", name="Everfrost Peaks", id=30, min=2, max=45, zem=1.00, indoor=true }  -- 28 spawns
add{ short="felwithea", name="Felwithe (A)", id=61, min=40, max=40, zem=1.33, indoor=true, city=true }  -- 96 spawns, city median
add{ short="felwitheb", name="Felwithe (B)", id=62, min=40, max=40, zem=1.33, indoor=true, city=true, cat="city" }  -- 38 spawns, city median
add{ short="freeportsewers", name="Freeport Sewers", id=384, min=10, max=20, zem=1.00, indoor=true }  -- 104 spawns
add{ short="beholder", name="Gorge of King Xorbb", id=16, min=11, max=22, zem=1.00 }  -- 100 spawns
add{ short="grobb", name="Grobb", id=52, min=40, max=40, zem=1.33, city=true }  -- 119 spawns, city median
add{ short="halas", name="Halas", id=29, min=45, max=45, zem=1.33, indoor=true, city=true }  -- 91 spawns, city median
add{ short="highkeep", name="HighKeep", id=6, min=23, max=40, zem=2.00 }  -- 220 spawns
add{ short="highpasshold", name="Highpass Hold", id=407, min=15, max=34, zem=1.00 }  -- 369 spawns
add{ short="highpasskeep", name="Highpass Keep", id=412, zem=1.00, cat="nodata", emuOnly=true }  -- no spawn data
add{ short="paw", name="Infected Paw", id=18, min=64, max=64, zem=0.90, indoor=true }  -- 1255 spawns
add{ short="innothule", name="Innothule Swamp (A)", id=46, min=2, max=12, zem=1.00, indoor=true, emuOnly=true }  -- 245 spawns
add{ short="innothuleb", name="Innothule Swamp (B)", id=413, min=1, max=8, zem=1.00, indoor=true }  -- 329 spawns
add{ short="kaladima", name="Kaladim (A)", id=60, min=39, max=41, zem=1.33, indoor=true, city=true }  -- 68 spawns, city median
add{ short="kaladimb", name="Kaladim (B)", id=67, min=39, max=41, zem=1.33, indoor=true, city=true }  -- 81 spawns, city median
add{ short="kedge", name="Kedge Keep", id=64, min=38, max=49, zem=1.33 }  -- 261 spawns
add{ short="kerraridge", name="Kerra Isle", id=74, min=14, max=21, zem=1.20 }  -- 248 spawns
add{ short="kithicor", name="Kithicor Forest (A)", id=20, min=29, max=37, zem=1.00, indoor=true }  -- 1722 spawns
add{ short="kithforest", name="Kithicor Forest (B)", id=410, zem=1.00, cat="nodata", emuOnly=true }  -- no spawn data
add{ short="lakerathe", name="Lake Rathetear", id=51, min=11, max=35, zem=1.00, indoor=true }  -- 300 spawns
add{ short="lavastorm", name="Lavastorm Mountains", id=27, min=11, max=60, zem=0.75, indoor=true }  -- 398 spawns
add{ short="load", name="Loading (A)", id=184, zem=1.00, indoor=true, cat="dev" }  -- no spawn data
add{ short="load2", name="Loading (B)", id=185, zem=1.00, indoor=true, cat="dev" }  -- no spawn data
add{ short="clz", name="Loading (C)", id=190, zem=1.00, cat="dev" }  -- no spawn data
add{ short="gukbottom", name="Lower Guk", id=66, min=31, max=42, zem=1.06, indoor=true }  -- 465 spawns
add{ short="erudsxing2", name="Marauder's Mire", id=130, zem=1.00, cat="nodata", emuOnly=true }  -- no spawn data
add{ short="misty", name="Misty Thicket (A)", id=33, min=3, max=11, zem=1.00, indoor=true, emuOnly=true }  -- 480 spawns
add{ short="mistythicket", name="Misty Thicket (B)", id=415, min=2, max=11, zem=1.00, indoor=true }  -- 461 spawns
add{ short="rathemtn", name="Mountains of Rathe", id=50, min=6, max=40, zem=1.00, indoor=true }  -- 535 spawns
add{ short="soldungb", name="Nagafen's Lair", id=32, min=35, max=49, zem=1.06, indoor=true }  -- 270 spawns
add{ short="najena", name="Najena", id=44, min=12, max=23, zem=1.73, indoor=true }  -- 256 spawns
add{ short="nedaria", name="Nedaria's Landing", id=182, min=21, max=65, zem=1.00, hot=25 }  -- 431 spawns
add{ short="nektropos", name="Nektropos", id=28, zem=1.00, cat="nodata", emuOnly=true }  -- no spawn data
add{ short="nektulos", name="Nektulos Forest", id=25, min=1, max=9, zem=1.00, indoor=true }  -- 3278 spawns
add{ short="neriakb", name="Neriak Commons", id=41, min=40, max=40, zem=1.33, indoor=true, city=true }  -- 151 spawns, city median
add{ short="neriaka", name="Neriak Foreign Quarter", id=40, min=37, max=40, zem=1.33, indoor=true, city=true }  -- 85 spawns, city median
add{ short="neriakd", name="Neriak Palace", id=43, min=100, max=101, zem=1.00, city=true }  -- Alla: 221 NPCs
add{ short="neriakc", name="Neriak Third Gate", id=42, min=38, max=40, zem=1.33, indoor=true, city=true }  -- 126 spawns, city median
add{ short="freportn", name="North Freeport", id=8, min=30, max=45, zem=1.33, indoor=true, city=true }  -- 118 spawns, city median
add{ short="northkarana", name="North Karana", id=13, min=10, max=36, zem=1.00 }  -- 232 spawns
add{ short="qeynos2", name="North Qeynos", id=2, min=1, max=5, zem=1.00, city=true }  -- 216 spawns, city median
add{ short="nro", name="North Ro (A)", id=34, min=5, max=30, zem=1.00, indoor=true, emuOnly=true }  -- 236 spawns
add{ short="northro", name="North Ro (B)", id=392, min=1, max=40, zem=1.00 }  -- 308 spawns
add{ short="oasis", name="Oasis of Marr", id=37, min=11, max=36, zem=1.00, indoor=true, emuOnly=true }  -- 288 spawns
add{ short="oot", name="Ocean of Tears", id=69, min=13, max=46, zem=1.13, emuOnly=true }  -- 320 spawns
add{ short="oceanoftears", name="Ocean Of Tears", id=409, min=15, max=45, zem=1.00 }  -- 598 spawns
add{ short="oggok", name="Oggok", id=49, min=36, max=40, zem=1.33, city=true }  -- 132 spawns, city median
add{ short="paineel", name="Paineel", id=75, min=15, max=34, zem=1.00, city=true }  -- 180 spawns, city median
add{ short="permafrost", name="Permafrost Keep", id=73, min=17, max=44, zem=1.20, indoor=true }  -- 454 spawns
add{ short="fearplane", name="Plane of Fear", id=72, min=49, max=52, zem=1.13, indoor=true }  -- 248 spawns
add{ short="poknowledge", name="Plane of Knowledge", id=202, min=60, max=99, zem=1.00, cat="hub" }  -- 520 spawns
add{ short="airplane", name="Plane of Sky", id=71, min=53, max=58, zem=1.13, indoor=true }  -- 125 spawns
add{ short="qcat", name="Qeynos Catacombs", id=45, min=1, max=60, zem=1.00, indoor=true }  -- 194 spawns
add{ short="qeytoqrg", name="Qeynos Hills", id=4, min=3, max=25, zem=1.00 }  -- 366 spawns
add{ short="rivervale", name="Rivervale", id=19, min=6, max=30, zem=1.33, indoor=true, city=true }  -- 184 spawns, city median
add{ short="takishruins", name="Ruins of Takish-Hiz", id=376, min=55, max=67, zem=1.00 }  -- 175 spawns
add{ short="shadowrest", name="Shadowrest", id=187, min=20, max=50, zem=1.00, cat="hub" }  -- 14 spawns
add{ short="soldunga", name="Solusek's Eye", id=31, min=24, max=32, zem=1.73, indoor=true, hot=30 }  -- 476 spawns
add{ short="southkarana", name="South Karana", id=14, min=10, max=31, zem=1.00, hot=20 }  -- 1240 spawns
add{ short="qeynos", name="South Qeynos", id=1, min=10, max=27, zem=1.00, city=true }  -- 207 spawns, city median
add{ short="sro", name="South Ro (A)", id=35, min=6, max=35, zem=1.00, indoor=true, emuOnly=true }  -- 370 spawns
add{ short="southro", name="South Ro (B)", id=393, min=10, max=49, zem=1.00 }  -- 378 spawns
add{ short="steamfont", name="Steamfont Mountains", id=56, min=2, max=26, zem=1.00, indoor=true }  -- 370 spawns
add{ short="steamfontmts", name="Steamfont Mountains", id=448, min=1, max=26, zem=1.00, indoor=true }  -- 378 spawns
add{ short="stonebrunt", name="Stonebrunt Mountains", id=100, min=17, max=30, zem=1.00, indoor=true, hot=25 }  -- 619 spawns
add{ short="cshome", name="Sunset Home", id=26, min=50, max=65, zem=1.00, indoor=true, cat="housing", emuOnly=true }  -- 40 spawns
add{ short="qrg", name="Surefall Glade", id=3, min=2, max=24, zem=1.33, indoor=true, city=true }  -- 72 spawns, city median
add{ short="soltemple", name="Temple of Solusek Ro", id=80, min=34, max=40, zem=1.33, indoor=true }  -- 49 spawns
add{ short="arena", name="The Arena (A)", id=77, min=75, max=80, zem=1.00, indoor=true, cat="arena" }  -- 5 spawns
add{ short="arena2", name="The Arena (B)", id=180, zem=1.00, indoor=true, cat="arena" }  -- no spawn data
add{ short="barter", name="The Barter Hall", id=346, zem=1.00, cat="hub", emuOnly=true }  -- no spawn data
add{ short="bazaar", name="The Bazaar", id=151, min=35, max=60, zem=1.00, cat="hub" }  -- 116 spawns
add{ short="bazaar2", name="The Bazaar (2)", cat="instance", emuOnly=true }  -- no spawn data
add{ short="soldungc", name="The Caverns of Exile", id=278, min=54, max=60, zem=2.00, indoor=true }  -- 282 spawns
add{ short="feerrott", name="The Feerrott(A)", id=47, min=3, max=32, zem=1.00, indoor=true }  -- 563 spawns
add{ short="fhalls", name="The Forgotten Halls", id=998, min=2, max=4, zem=1.00 }  -- 57 spawns
add{ short="gfaydark", name="The Greater Faydark", id=54, min=2, max=45, zem=1.00, indoor=true }  -- 632 spawns
add{ short="guildlobby", name="The Guild Lobby", id=344, min=50, max=70, zem=1.00, cat="hub" }  -- 49 spawns
add{ short="jaggedpine", name="The Jaggedpine Forest", id=181, min=34, max=44, zem=1.00, indoor=true }  -- 599 spawns
add{ short="lfaydark", name="The Lesser Faydark", id=57, min=6, max=30, zem=1.00, indoor=true }  -- 301 spawns
add{ short="tutoriala", name="The Mines of Gloomingdeep (A)", id=188, min=5, max=5, zem=1.00, cat="unused" }  -- 1 spawns
add{ short="tutorialb", name="The Mines of Gloomingdeep (B)", id=189, min=2, max=9, zem=1.00 }  -- 361 spawns
add{ short="hateplane", name="The Plane of Hate", id=76, min=50, max=56, zem=1.00, indoor=true }  -- 175 spawns
add{ short="hateplaneb", name="The Plane of Hate", id=186, min=54, max=64, zem=1.13 }  -- 728 spawns
add{ short="hole", name="The Ruins of Old Paineel", id=39, min=45, max=56, zem=1.33, indoor=true }  -- 1171 spawns
add{ short="warrens", name="The Warrens", id=101, min=5, max=8, zem=2.00, indoor=true, city=true }  -- 584 spawns, city median
add{ short="dragonscalea", name="Tinmizer's Wunderwerks", cat="hub" }  -- no spawn data
add{ short="tox", name="Toxxulia Forest", id=38, min=1, max=35, zem=1.00, indoor=true, emuOnly=true }  -- 495 spawns
add{ short="toxxulia", name="Toxxulia Forest", id=414, min=2, max=20, zem=1.00, indoor=true }  -- 538 spawns
add{ short="tutorial", name="Tutorial Zone", id=183, zem=1.00, indoor=true, cat="nodata" }  -- no spawn data
add{ short="guktop", name="Upper Guk", id=65, min=13, max=25, zem=2.00, indoor=true, hot=20 }  -- 579 spawns
add{ short="weddingchapeldark", name="Wedding Chapel", id=494, min=1, max=1, cat="event" }  -- 33 spawns
add{ short="commons", name="West Commonlands", id=21, min=7, max=32, zem=1.00, indoor=true, emuOnly=true }  -- 191 spawns
add{ short="freportw", name="West Freeport", id=9, min=1, max=26, zem=1.00, indoor=true, city=true }  -- 220 spawns, city median
add{ short="freeportwest", name="West Freeport", id=383, min=25, max=70, zem=1.00 }  -- 314 spawns
add{ short="qey2hh1", name="West Karana", id=12, min=4, max=30, zem=1.00 }  -- 394 spawns

--===== RoK : 28 zones =====
exp = "RoK"

add{ short="burningwood", name="Burning Woods", id=87, min=37, max=45, zem=1.00, indoor=true }  -- 471 spawns
add{ short="chardok", name="Chardok", id=103, min=49, max=56, zem=1.50, indoor=true }  -- 713 spawns
add{ short="citymist", name="City of Mist", id=90, min=36, max=45, zem=0.85, indoor=true, hot=40 }  -- 968 spawns
add{ short="dalnir", name="Dalnir", id=104, min=26, max=30, zem=1.13, indoor=true, hot=30 }  -- 227 spawns
add{ short="dreadlands", name="Dreadlands", id=86, min=34, max=40, zem=1.00, indoor=true, hot=35 }  -- 477 spawns
add{ short="cabeast", name="East Cabilis", id=106, min=1, max=30, zem=1.33, indoor=true, city=true }  -- 203 spawns, city median
add{ short="firiona", name="Firiona Vie", id=84, min=28, max=45, zem=1.00, indoor=true }  -- 567 spawns
add{ short="frontiermtns", name="Frontier Mountains", id=92, min=28, max=35, zem=1.00, indoor=true }  -- 489 spawns
add{ short="charasis", name="Howling Stones", id=105, min=45, max=52, zem=1.13, indoor=true }  -- 654 spawns
add{ short="kaesora", name="Kaesora", id=88, min=31, max=35, zem=1.46, indoor=true }  -- 297 spawns
add{ short="karnor", name="Karnor's Castle", id=102, min=42, max=50, zem=1.13, indoor=true }  -- 564 spawns
add{ short="kurn", name="Kurn's Tower", id=97, min=12, max=17, zem=2.00, indoor=true }  -- 628 spawns
add{ short="lakeofillomen", name="Lake of Ill Omen", id=85, min=12, max=35, zem=0.80, indoor=true, hot=25 }  -- 647 spawns
add{ short="nurga", name="Mines of Nurga", id=107, min=31, max=49, zem=0.95 }  -- 1244 spawns
add{ short="sebilis", name="Old Sebilis", id=89, min=47, max=55, zem=2.50, indoor=true, hot=50 }  -- 1098 spawns
add{ short="skyfire", name="Skyfire Mountains", id=91, min=43, max=51, zem=1.06, indoor=true, hot=50 }  -- 312 spawns
add{ short="swampofnohope", name="Swamp of No Hope", id=83, min=11, max=25, zem=1.00, indoor=true }  -- 750 spawns
add{ short="droga", name="Temple of Droga", id=81, min=29, max=53, zem=0.95 }  -- 4666 spawns
add{ short="emeraldjungle", name="The Emerald Jungle", id=94, min=35, max=40, zem=1.00, indoor=true, hot=40 }  -- 332 spawns
add{ short="fieldofbone", name="The Field of Bone", id=78, min=2, max=27, zem=1.00, indoor=true }  -- 607 spawns
add{ short="chardokb", name="The Halls of Betrayal", id=277, min=56, max=63, zem=2.00, indoor=true }  -- 507 spawns
add{ short="overthere", name="The Overthere", id=93, min=30, max=33, zem=1.00, indoor=true, city=true }  -- 539 spawns, city median
add{ short="timorous", name="Timorous Deep", id=96, min=14, max=50, zem=1.00, indoor=true }  -- 350 spawns
add{ short="trakanon", name="Trakanon's Teeth", id=95, min=36, max=50, zem=1.00, indoor=true }  -- 553 spawns
add{ short="veeshan", name="Veeshan's Peak", id=108, min=62, max=69, zem=1.00, indoor=true }  -- 712 spawns
add{ short="veksar", name="Veksar", id=109, min=51, max=60, zem=1.33, indoor=true, hot=60 }  -- 285 spawns
add{ short="warslikswood", name="Warsliks Wood", id=79, min=3, max=26, zem=1.00, indoor=true }  -- 435 spawns
add{ short="cabwest", name="West Cabilis", id=82, min=30, max=50, zem=1.33, indoor=true, city=true }  -- 68 spawns, city median

--===== Velious : 19 zones =====
exp = "Velious"

add{ short="cobaltscar", name="Cobalt Scar", id=117, min=38, max=50, zem=1.00, indoor=true }  -- 310 spawns
add{ short="crystal", name="Crystal Caverns", id=121, min=29, max=37, zem=1.13 }  -- 260 spawns
add{ short="necropolis", name="Dragon Necropolis", id=123, min=48, max=58, zem=1.50, indoor=true }  -- 469 spawns
add{ short="eastwastes", name="Eastern Wastes", id=116, min=32, max=55, zem=1.00, indoor=true }  -- 591 spawns
add{ short="greatdivide", name="Great Divide", id=118, min=29, max=53, zem=1.00, indoor=true, hot=35 }  -- 970 spawns
add{ short="iceclad", name="Iceclad Ocean", id=110, min=29, max=35, zem=1.00, indoor=true }  -- 300 spawns
add{ short="thurgadinb", name="Icewell Keep", id=129, min=48, max=57, zem=1.13, indoor=true }  -- 140 spawns
add{ short="kael", name="Kael Drakkal", id=113, min=35, max=56, zem=1.13, indoor=true }  -- 953 spawns
add{ short="growthplane", name="Plane of Growth", id=127, min=52, max=60, zem=1.13, indoor=true }  -- 347 spawns
add{ short="mischiefplane", name="Plane of Mischief", id=126, min=52, max=63, zem=1.13, indoor=true }  -- 1055 spawns
add{ short="sirens", name="Siren's Grotto", id=125, min=50, max=56, zem=0.85 }  -- 1002 spawns
add{ short="skyshrine", name="Skyshrine", id=114, min=38, max=62, zem=1.13, indoor=true }  -- 1000 spawns
add{ short="sleeper", name="Sleeper's Tomb", id=128, min=66, max=66, zem=1.20, indoor=true }  -- 295 spawns
add{ short="templeveeshan", name="Temple of Veeshan", id=124, min=60, max=65, zem=1.33, indoor=true }  -- 402 spawns
add{ short="wakening", name="The Wakening Land", id=119, min=37, max=48, zem=1.00, indoor=true }  -- 619 spawns
add{ short="thurgadina", name="Thurgadin", id=115, min=31, max=42, zem=1.13, indoor=true }  -- 239 spawns
add{ short="frozenshadow", name="Tower of Frozen Shadow", id=111, min=30, max=40, zem=1.13, indoor=true }  -- 405 spawns
add{ short="velketor", name="Velketor's Labyrinth", id=112, min=46, max=55, zem=1.50, indoor=true, hot=50 }  -- 782 spawns
add{ short="westwastes", name="Western Wastes", id=120, min=48, max=66, zem=1.06, indoor=true }  -- 405 spawns

--===== Luclin : 27 zones =====
exp = "Luclin"

add{ short="acrylia", name="Acrylia Caverns", id=154, min=44, max=54, zem=2.00, indoor=true }  -- 691 spawns
add{ short="akheva", name="Akheva Ruins", id=179, min=49, max=56, zem=1.75, indoor=true }  -- 475 spawns
add{ short="dawnshroud", name="Dawnshroud Peaks", id=174, min=28, max=41, zem=1.75 }  -- 909 spawns
add{ short="echo", name="Echo Caverns", id=153, min=27, max=48, zem=1.06, indoor=true }  -- 277 spawns
add{ short="fungusgrove", name="Fungus Grove", id=157, min=47, max=53, zem=2.00, indoor=true }  -- 565 spawns
add{ short="griegsend", name="Grieg's End", id=163, min=53, max=58, zem=0.90 }  -- 880 spawns
add{ short="grimling", name="Grimling Forest", id=167, min=34, max=42, zem=1.06 }  -- 1139 spawns
add{ short="hollowshade", name="Hollowshade Moor", id=166, min=16, max=27, zem=1.00, indoor=true }  -- 2067 spawns
add{ short="katta", name="Katta Castellum", id=160, min=37, max=43, zem=1.13, indoor=true, city=true }  -- 463 spawns, city median
add{ short="mseru", name="Marus Seru", id=168, min=21, max=29, zem=1.00, indoor=true }  -- 460 spawns
add{ short="letalis", name="Mons Letalis", id=169, min=36, max=41, zem=1.75, indoor=true, hot=40 }  -- 341 spawns
add{ short="netherbian", name="Netherbian Lair", id=161, min=20, max=29, zem=1.06, indoor=true }  -- 502 spawns
add{ short="paludal", name="Paludal Caverns", id=156, min=15, max=20, zem=1.75, indoor=true, hot=20 }  -- 2851 spawns
add{ short="sseru", name="Sanctus Seru", id=159, min=44, max=60, zem=1.13, indoor=true }  -- 1474 spawns
add{ short="shadeweaver", name="Shadeweaver's Thicket", id=165, min=7, max=26, zem=1.00, indoor=true }  -- 1336 spawns
add{ short="shadowhaven", name="Shadow Haven", id=150, min=30, max=55, zem=1.33, indoor=true, city=true }  -- 316 spawns, city median
add{ short="sharvahl", name="Shar Vahl", id=155, min=2, max=4, zem=1.00, indoor=true, city=true }  -- 674 spawns, city median
add{ short="ssratemple", name="Ssraeshza Temple", id=162, min=52, max=58, zem=1.33, indoor=true }  -- 1723 spawns
add{ short="thedeep", name="The Deep", id=164, min=50, max=54, zem=2.00, indoor=true, hot=55 }  -- 788 spawns
add{ short="thegrey", name="The Grey", id=171, min=44, max=50, zem=2.00, indoor=true }  -- 984 spawns
add{ short="maiden", name="The Maiden's Eye", id=173, min=48, max=55, zem=1.00, indoor=true }  -- 754 spawns
add{ short="nexus", name="The Nexus", id=152, min=50, max=50, zem=1.00, indoor=true, cat="hub" }  -- 18 spawns
add{ short="scarlet", name="The Scarlet Desert", id=175, min=36, max=43, zem=1.00, indoor=true, hot=45 }  -- 1337 spawns
add{ short="tenebrous", name="The Tenebrous Mountains", id=172, min=34, max=41, zem=1.75, indoor=true }  -- 495 spawns
add{ short="twilight", name="The Twilight Sea", id=170, min=26, max=39, zem=1.00, indoor=true }  -- 1513 spawns
add{ short="umbral", name="The Umbral Plains", id=176, min=55, max=58, zem=1.20, indoor=true }  -- 851 spawns
add{ short="vexthal", name="Vex Thal", id=158, min=58, max=66, zem=1.33, indoor=true }  -- 990 spawns

--===== PoP : 23 zones =====
exp = "PoP"

add{ short="pofire", name="Doomfire, The Burning Lands", id=217, min=65, max=68, zem=3.00, indoor=true }  -- 1037 spawns
add{ short="potactics", name="Drunder, Fortress of Zek", id=214, min=60, max=69, zem=2.75, indoor=true, hot=65 }  -- 769 spawns
add{ short="poair", name="Eryslai, the Kingdom of Wind", id=215, min=65, max=68, zem=2.75, indoor=true }  -- 489 spawns
add{ short="hohonora", name="Halls of Honor", id=211, min=61, max=66, zem=2.75, indoor=true }  -- 495 spawns
add{ short="nightmareb", name="Lair of Terris Thule", id=221, min=61, max=64, zem=2.35, indoor=true }  -- 37 spawns
add{ short="podisease", name="Plane of Disease", id=205, min=51, max=58, zem=1.58, indoor=true }  -- 697 spawns
add{ short="poinnovation", name="Plane of Innovation", id=206, min=50, max=57, zem=1.58, indoor=true, hot=55 }  -- 561 spawns
add{ short="pojustice", name="Plane of Justice", id=201, min=47, max=55, zem=1.58, indoor=true }  -- 800 spawns
add{ short="ponightmare", name="Plane of Nightmare", id=204, min=54, max=60, zem=1.58, indoor=true }  -- 645 spawns
add{ short="postorms", name="Plane of Storms", id=210, min=58, max=63, zem=2.35, indoor=true }  -- 1120 spawns
add{ short="potimea", name="Plane of Time (A)", id=219, min=62, max=62, zem=0.40, indoor=true }  -- 251 spawns
add{ short="potimeb", name="Plane of Time (B)", id=223, min=67, max=70, zem=2.75, indoor=true }  -- 380 spawns
add{ short="potorment", name="Plane of Torment", id=207, min=59, max=65, zem=2.75, indoor=true }  -- 379 spawns
add{ short="potranquility", name="Plane of Tranquility", id=203, min=46, max=60, zem=1.00, indoor=true, cat="hub" }  -- 76 spawns
add{ short="povalor", name="Plane of Valor", id=208, min=61, max=66, zem=2.35, indoor=true }  -- 377 spawns
add{ short="powar", name="Plane of War", id=213, zem=1.00, indoor=true }  -- no spawn data
add{ short="powater", name="Reef of Coirnav", id=216, min=65, max=68, zem=3.00 }  -- 299 spawns
add{ short="codecay", name="Ruins of Lxanvom", id=200, min=61, max=62, zem=2.35, indoor=true }  -- 1025 spawns
add{ short="solrotower", name="Solusek Ro's Tower", id=212, min=61, max=70, zem=2.75, indoor=true }  -- 561 spawns
add{ short="poearthb", name="Stronghold of the Twelve", id=222, min=65, max=68, zem=3.00, indoor=true }  -- 92 spawns
add{ short="hohonorb", name="Temple of Marr (A)", id=220, min=61, max=68, zem=2.75, indoor=true }  -- 58 spawns
add{ short="bothunder", name="Torden, The Bastion of Thunder", id=209, min=61, max=64, zem=2.75, indoor=true, hot=65 }  -- 790 spawns
add{ short="poeartha", name="Vegarlson, The Earthen Badlands", id=218, min=63, max=66, zem=3.00, indoor=true }  -- 316 spawns

--===== LoY : 5 zones =====
exp = "LoY"

add{ short="nadox", name="Crypt of Nadox", id=227, min=47, max=57, zem=1.50, indoor=true }  -- 666 spawns
add{ short="dulak", name="Dulak's Harbor", id=225, min=38, max=48, zem=2.00, indoor=true, hot=45 }  -- 764 spawns
add{ short="gunthak", name="Gulf of Gunthak", id=224, min=33, max=43, zem=1.50, indoor=true }  -- 847 spawns
add{ short="hatesfury", name="Hate's Fury, The Scorned Maiden", id=228, min=53, max=56, zem=2.00 }  -- 365 spawns
add{ short="torgiran", name="Torgiran Mines", id=226, min=46, max=54, zem=1.13, indoor=true }  -- 491 spawns

--===== LDoN : 48 zones =====
exp = "LDoN"

add{ short="gukh", name="The Accursed Sanctuary", id=264, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mmch", name="The Aisles of Blood", id=268, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="gukc", name="The Ancient Aqueducts", id=239, min=15, max=75, zem=1.50 }  -- scales; adventure band
add{ short="taki", name="The Antiquated Palace", id=270, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="ruji", name="The Arena of Chance", id=269, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mmcc", name="The Asylum of Invoked Stone", id=243, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="takg", name="The Balancing Chamber", id=261, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="rujj", name="The Barracks of War", id=273, min=15, max=75, zem=1.50 }  -- scales; adventure band
add{ short="rujh", name="The Blazing Forge", id=265, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="ruja", name="The Bloodied Quarries", id=230, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="guka", name="The Cauldron of Lost Souls", id=229, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mmcg", name="The Cesspits of Putrescence", id=263, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mmcd", name="The Chambers of Eternal Affliction", id=248, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="gukf", name="The Chapel of the Witnesses", id=254, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mmcb", name="The Dreary Grotto", id=238, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="gukb", name="The Drowning Crypt", id=234, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="ruje", name="The Drudge Hollows", id=250, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="takc", name="The Fading Temple", id=241, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="guke", name="The Foreboding Prison", id=249, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mirf", name="The Forgotten Wastes", id=257, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mmca", name="The Forlorn Caverns", id=233, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="rujf", name="The Fortified Lair of the Taskmasters", id=255, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mire", name="The Frosted Halls", id=252, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="rujd", name="The Gladiator Pits", id=245, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mirj", name="The Grand Library", id=275, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mmci", name="The Halls of Sanguinary Rites", id=272, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="rujb", name="The Halls of War", id=235, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mirg", name="The Heart of the Menagerie", id=262, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="rujg", name="The Hidden Vale", id=260, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mird", name="The Hushed Banquet", id=247, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mmcj", name="The Infernal Sanctuary", id=276, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mirb", name="The Maw of the Menagerie", id=237, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mirh", name="The Morbid Laboratory", id=267, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="gukd", name="The Mushroom Grove", id=244, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="takj", name="The Prismatic Corridors", id=274, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mmcf", name="The Ritualistic Summoning Grounds", id=258, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="take", name="The River of Recollection", id=251, min=15, max=75, zem=1.50 }  -- scales; adventure band
add{ short="gukg", name="The Root Garden", id=259, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="takd", name="The Royal Observatory", id=246, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="takf", name="The Sandfall Corridors", id=256, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mmce", name="The Sepulcher of the Damned", id=253, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="takb", name="The Shifting Tower", id=236, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mira", name="The Silent Gallery", id=232, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="mirc", name="The Spider Den", id=242, min=15, max=75, zem=1.50 }  -- scales; adventure band
add{ short="taka", name="The Sunken Library", id=231, min=15, max=75, zem=1.50 }  -- scales; adventure band
add{ short="takh", name="The Sweeping Tides", id=266, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="miri", name="The Theater of Imprisoned Horrors", id=271, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band
add{ short="rujc", name="The Wind Bridges", id=240, min=15, max=75, zem=1.50, indoor=true }  -- scales; adventure band

--===== GoD : 21 zones =====
exp = "GoD"

add{ short="abysmal", name="Abysmal Sea", id=279, min=70, max=70, zem=1.00 }  -- 265 spawns
add{ short="barindu", name="Barindu, Hanging Gardens", id=283, min=47, max=62, zem=2.00, hot=60 }  -- 623 spawns
add{ short="ferubi", name="Ferubi, Forgotten Temple of Taelosia", id=284, min=61, max=66, zem=2.00, indoor=true }  -- 1331 spawns
add{ short="ikkinz", name="Ikkinz, Chambers of Destruction", id=294, min=62, max=67, zem=1.50 }  -- 503 spawns
add{ short="inktuta", name="Inktu`Ta, The Unmasked Chapel", id=296, min=66, max=70, zem=1.75 }  -- 98 spawns
add{ short="kodtaz", name="Kod'Taz, Broken Trial Grounds", id=293, min=64, max=68, zem=2.50, indoor=true }  -- 693 spawns
add{ short="natimbi", name="Natimbi, The Broken Shores", id=280, min=44, max=51, zem=1.50 }  -- 762 spawns
add{ short="qinimi", name="Qinimi, Court of Nihilia", id=281, min=50, max=55, zem=2.00 }  -- 639 spawns
add{ short="qvic", name="Qvic, Prayer Grounds of Calling", id=295, min=66, max=69, zem=2.00, indoor=true }  -- 1155 spawns
add{ short="qvicb", name="Qvic, the Hidden Vault", id=299, zem=1.00, emuOnly=true }  -- no spawn data
add{ short="riwwi", name="Riwwi, Coliseum of Games", id=282, min=47, max=60, zem=2.00, hot=55 }  -- 298 spawns
add{ short="snlair", name="Sewers of Nihilia, Lair of Trapped Ones", id=286, min=61, max=64, zem=1.50, indoor=true }  -- 209 spawns
add{ short="snpool", name="Sewers of Nihilia, Pool of Sludge", id=285, min=59, max=62, zem=1.50, indoor=true }  -- 178 spawns
add{ short="snplant", name="Sewers of Nihilia, Purifying Plant", id=287, min=61, max=65, zem=1.50, indoor=true }  -- 383 spawns
add{ short="sncrematory", name="Sewers of Nihilia, the Crematory", id=288, min=59, max=62, zem=1.50, indoor=true }  -- 156 spawns
add{ short="tacvi", name="Tacvi, Seat of the Slaver", id=298, min=1, max=1, zem=1.00 }  -- 1 spawns
add{ short="tipt", name="Tipt, Treacherous Crags", id=289, min=64, max=66, zem=2.00 }  -- 61 spawns
add{ short="txevu", name="Txevu, Lair of the Elite", id=297, min=67, max=70, zem=1.75 }  -- 1088 spawns
add{ short="uqua", name="Uqua, The Ocean God Chantry", id=292, min=67, max=69, zem=2.00 }  -- 62 spawns
add{ short="vxed", name="Vxed, The Crumbling Caverns", id=290, min=64, max=66, zem=2.00 }  -- 426 spawns
add{ short="yxtta", name="Yxtta, Pulpit of Exiles", id=291, min=65, max=68, zem=2.00 }  -- 356 spawns

--===== OoW : 31 zones =====
exp = "OoW"

add{ short="anguish", name="Asylum of Anguish", id=317, min=72, max=74, zem=1.00 }  -- 1773 spawns
add{ short="dranikcatacombsa", name="Catacombs of Dranik (A)", id=328, min=67, max=67, zem=1.75, indoor=true }  -- 368 spawns
add{ short="dranikcatacombsb", name="Catacombs of Dranik (B)", id=329, min=67, max=67, zem=1.75, indoor=true }  -- 109 spawns
add{ short="dranikcatacombsc", name="Catacombs of Dranik (C)", id=330, min=67, max=67, zem=1.75, indoor=true }  -- 179 spawns
add{ short="dranikhollowsa", name="Dranik's Hollows (A)", id=318, min=66, max=66, zem=1.75 }  -- 94 spawns
add{ short="dranikhollowsb", name="Dranik's Hollows (B)", id=319, min=66, max=66, zem=1.75 }  -- 92 spawns
add{ short="dranikhollowsc", name="Dranik's Hollows (C)", id=320, min=66, max=66, zem=1.75 }  -- 100 spawns
add{ short="draniksscar", name="Dranik's Scar", id=302, min=40, max=50, zem=1.75, indoor=true, hot=45 }  -- 807 spawns
add{ short="harbingers", name="Harbingers' Spire", id=335, min=53, max=63, zem=2.00 }  -- 247 spawns
add{ short="provinggrounds", name="Muramite Proving Grounds", id=316, min=70, max=70, zem=2.75, indoor=true, cat="instance" }  -- 814 spawns
add{ short="chambersa", name="Muramite Proving Grounds (A)", id=304, min=65, max=75, zem=1.00, indoor=true, cat="instance" }  -- 23 spawns
add{ short="chambersb", name="Muramite Proving Grounds (B)", id=305, min=70, max=80, zem=1.00, indoor=true, cat="instance" }  -- 10 spawns
add{ short="chambersc", name="Muramite Proving Grounds (C)", id=306, min=55, max=64, zem=1.00, indoor=true, cat="instance" }  -- 47 spawns
add{ short="chambersd", name="Muramite Proving Grounds (D)", id=307, min=64, max=72, zem=1.00, indoor=true, cat="instance" }  -- 18 spawns
add{ short="chamberse", name="Muramite Proving Grounds (E)", id=308, min=65, max=72, zem=1.00, indoor=true, cat="instance" }  -- 15 spawns
add{ short="chambersf", name="Muramite Proving Grounds (F)", id=309, min=70, max=70, zem=1.00, indoor=true, cat="instance" }  -- 70 spawns
add{ short="causeway", name="Nobles' Causeway", id=303, min=61, max=66, zem=2.25, indoor=true }  -- 661 spawns
add{ short="riftseekers", name="Riftseekers' Sanctum", id=334, min=71, max=72, zem=3.00 }  -- 697 spawns
add{ short="draniksewersa", name="Sewers of Dranik (A)", id=331, min=67, max=68, zem=1.75, indoor=true }  -- 130 spawns
add{ short="draniksewersb", name="Sewers of Dranik (B)", id=332, min=67, max=68, zem=1.75, indoor=true }  -- 161 spawns
add{ short="draniksewersc", name="Sewers of Dranik (C)", id=333, min=67, max=68, zem=1.75, indoor=true }  -- 162 spawns
add{ short="bloodfields", name="The Bloodfields", id=301, min=53, max=58, zem=2.00, indoor=true }  -- 485 spawns
add{ short="dranik", name="The Ruined City of Dranik", id=336, min=64, max=68, zem=1.75, indoor=true }  -- 892 spawns
add{ short="wallofslaughter", name="Wall of Slaughter", id=300, min=64, max=68, zem=2.50, indoor=true }  -- 715 spawns

--===== DoN : 8 zones =====
exp = "DoN"

add{ short="guildhall", name="Guild Hall", id=345, min=50, max=60, zem=1.00, cat="hub" }  -- 7 spawns
add{ short="delvea", name="Lavaspinner's Lair", id=341, min=55, max=66, zem=2.95 }  -- 940 spawns
add{ short="stillmoona", name="Stillmoon Temple", id=338, min=55, max=67, zem=3.00 }  -- 1205 spawns
add{ short="thenest", name="The Accursed Nest", id=343, min=71, max=73, zem=3.10 }  -- 2882 spawns
add{ short="stillmoonb", name="The Ascent", id=339, min=62, max=67, zem=3.00 }  -- 868 spawns
add{ short="broodlands", name="The Broodlands", id=337, min=45, max=55, zem=1.75, indoor=true }  -- 672 spawns
add{ short="thundercrest", name="Thundercrest Isles", id=340, min=67, max=68, zem=3.05 }  -- 2454 spawns
add{ short="delveb", name="Tirranun's Delve", id=342, min=55, max=66, zem=2.95 }  -- 776 spawns

--===== DoDh : 20 zones =====
exp = "DoDh"

add{ short="westkorlachb", name="Caverns of the Lost", id=360, min=66, max=68, zem=1.00 }  -- 166 spawns
add{ short="westkorlacha", name="Chambers of Xill", id=359, min=67, max=70, zem=1.00 }  -- 123 spawns
add{ short="corathus", name="Corathus Creep", id=365, min=61, max=65, zem=1.00, indoor=true }  -- 1412 spawns
add{ short="corathusb", name="Corathus Lair", id=367, min=66, max=69, zem=1.00 }  -- 394 spawns
add{ short="drachnidhiveb", name="Coven of the Skinwalkers", id=356, min=60, max=71, zem=1.00 }  -- 168 spawns
add{ short="dreadspire", name="Dreadspire Keep", id=351, min=72, max=74, zem=1.00 }  -- 731 spawns
add{ short="illsalina", name="Imperial Bazaar", id=348, min=71, max=75, zem=1.00, cat="hub" }  -- 8 spawns
add{ short="westkorlachc", name="Lair of the Korlach", id=361, min=67, max=74, zem=1.00 }  -- 472 spawns
add{ short="drachnidhivea", name="Living Larder", id=355, min=60, max=71, zem=1.00 }  -- 473 spawns
add{ short="drachnidhivec", name="Queen Sendaii's Lair", id=357, min=1, max=70, zem=1.00 }  -- 28 spawns
add{ short="illsalin", name="Ruins of Illsalin", id=347, min=70, max=72, zem=1.00, indoor=true }  -- 298 spawns
add{ short="nektulosa", name="Shadowed Grove", id=368, min=20, max=27, zem=1.00 }  -- 30 spawns
add{ short="shadowspine", name="Shadowspine", id=364, min=70, max=74, zem=1.00 }  -- 78 spawns
add{ short="eastkorlacha", name="Snarlstone Dens", id=363, min=66, max=68, zem=1.00 }  -- 355 spawns
add{ short="corathusa", name="Sporali Caverns", id=366, min=69, max=71, zem=1.00 }  -- 213 spawns
add{ short="westkorlach", name="Stoneroot Falls", id=358, min=64, max=70, zem=1.00, hot=70 }  -- 943 spawns
add{ short="illsalinb", name="Temple of the Korlach", id=349, min=69, max=72, zem=1.00 }  -- 209 spawns
add{ short="drachnidhive", name="The Hive", id=354, min=66, max=71, zem=1.00, hot=70 }  -- 1476 spawns
add{ short="illsalinc", name="The Nargilor Pits", id=350, min=70, max=75, zem=1.00 }  -- 252 spawns
add{ short="eastkorlach", name="Undershore", id=362, min=56, max=67, zem=1.00 }  -- 907 spawns

--===== PoR : 19 zones =====
exp = "PoR"

add{ short="freeportacademy", name="Academy of Arcane Sciences", id=385, min=67, max=67, zem=1.00, indoor=true }  -- 1 spawns
add{ short="arcstone", name="Arcstone", id=369, min=65, max=69, zem=1.00, hot=70 }  -- 259 spawns
add{ short="freeportarena", name="Arena", id=388, min=80, max=80, zem=1.00, cat="arena" }  -- 1 spawns
add{ short="freeportcityhall", name="City Hall", id=389, min=69, max=72, zem=1.00 }  -- 70 spawns
add{ short="theatera", name="Deathknell, Tower of Dissonance", id=381, min=80, max=80, zem=1.00, indoor=true }  -- 10 spawns
add{ short="freeportmilitia", name="Freeport Militia House", id=387, min=69, max=71, zem=1.00, indoor=true, cat="hub" }  -- 22 spawns
add{ short="freeporthall", name="Hall of Truth", id=391, min=69, max=71, zem=1.00, indoor=true }  -- 74 spawns
add{ short="ragea", name="Razorthorn, Tower of Sullon Zek", id=375, min=70, max=72, zem=1.00, indoor=true }  -- 95 spawns
add{ short="relic", name="Relic", id=370, min=70, max=72, zem=1.00 }  -- 213 spawns
add{ short="skylance", name="Skylance", id=371, min=65, max=72, zem=1.00, indoor=true }  -- 126 spawns
add{ short="rage", name="Sverag, Stronghold of Rage", id=374, min=72, max=74, zem=1.00 }  -- 206 spawns
add{ short="freeporttemple", name="Temple of Marr (B)", id=386, zem=1.00, emuOnly=true }  -- no spawn data
add{ short="devastation", name="The Devastation", id=372, min=49, max=72, zem=1.00, indoor=true }  -- 1138 spawns
add{ short="elddar", name="The Elddar Forest", id=378, min=69, max=73, zem=1.00 }  -- 381 spawns
add{ short="takishruinsa", name="The Root of Ro", id=377, min=68, max=70, zem=1.00, indoor=true }  -- 28 spawns
add{ short="devastationa", name="The Seething Wall", id=373, min=70, max=73, zem=1.00, indoor=true }  -- 69 spawns
add{ short="freeporttheater", name="Theater", id=390, min=67, max=69, zem=1.00 }  -- 42 spawns
add{ short="theater", name="Theater of Blood", id=380, min=73, max=75, zem=1.00, indoor=true }  -- 332 spawns
add{ short="elddara", name="Tunare's Shrine", id=379, min=70, max=71, zem=1.00, indoor=true }  -- 61 spawns

--===== TSS : 13 zones =====
exp = "TSS"

add{ short="ashengate", name="Ashengate, Reliquary of the Scale", id=406, min=75, max=78, zem=1.00, indoor=true }  -- 314 spawns
add{ short="roost", name="Blackfeather Roost", id=398, min=55, max=60, zem=1.00, indoor=true, hot=60 }  -- 296 spawns
add{ short="moors", name="Blightfire Moors", id=395, min=22, max=35, zem=1.00, indoor=true, hot=30 }  -- 675 spawns
add{ short="crescent", name="Crescent Reach", id=394, min=4, max=70, zem=1.00, indoor=true }  -- 725 spawns
add{ short="direwind", name="Direwind Cliffs", id=405, min=70, max=76, zem=1.00, indoor=true, hot=75 }  -- 553 spawns
add{ short="frostcrypt", name="Frostcrypt, Throne of the Shade King", id=402, min=75, max=78, zem=1.00, indoor=true }  -- 400 spawns
add{ short="mesa", name="Goru`kar Mesa", id=397, min=41, max=53, zem=1.00, indoor=true }  -- 617 spawns
add{ short="icefall", name="Icefall Glacier", id=400, min=69, max=76, zem=1.00, indoor=true }  -- 560 spawns
add{ short="stonehive", name="Stone Hive", id=396, min=31, max=40, zem=1.00, indoor=true, hot=35 }  -- 300 spawns
add{ short="sunderock", name="Sunderock Springs", id=403, min=64, max=71, zem=1.00, indoor=true }  -- 562 spawns
add{ short="steppes", name="The Steppes", id=399, min=62, max=67, zem=1.00, indoor=true }  -- 388 spawns
add{ short="valdeholm", name="Valdeholm", id=401, min=72, max=77, zem=1.00, indoor=true, hot=80 }  -- 657 spawns
add{ short="vergalid", name="Vergalid Mines", id=404, min=70, max=77, zem=1.00, indoor=true }  -- 416 spawns

--===== TBS : 20 zones =====
exp = "TBS"

add{ short="barren", name="Barren Coast", id=422, min=53, max=64, zem=1.00, indoor=true, hot=65 }  -- 462 spawns
add{ short="blacksail", name="Blacksail Folly", id=428, min=74, max=76, zem=1.00, indoor=true }  -- 113 spawns
add{ short="deadbone", name="Deadbone Reef", id=427, min=72, max=75, zem=1.00, indoor=true }  -- 148 spawns
add{ short="jardelshook", name="Jardel's Hook", id=424, min=74, max=77, zem=1.00, indoor=true }  -- 124 spawns
add{ short="atiiki", name="Jewel of Atiiki", id=418, min=73, max=75, zem=1.00, indoor=true, hot=75 }  -- 491 spawns
add{ short="kattacastrum", name="Katta Castrum", id=416, min=73, max=75, zem=1.00, indoor=true }  -- 839 spawns
add{ short="maidensgrave", name="Maiden's Grave", id=429, min=70, max=72, zem=1.00, indoor=true }  -- 138 spawns
add{ short="monkeyrock", name="Monkey Rock", id=425, min=64, max=66, zem=1.00, indoor=true }  -- 103 spawns
add{ short="redfeather", name="Redfeather Isle", id=430, min=68, max=72, zem=1.00, indoor=true }  -- 118 spawns
add{ short="silyssar", name="Silyssar, New Chelsith", id=420, min=76, max=79, zem=1.00, indoor=true, hot=80 }  -- 487 spawns
add{ short="solteris", name="Solteris, the Throne of Ro", id=421, min=75, max=76, zem=1.00, indoor=true }  -- 48 spawns
add{ short="suncrest", name="Suncrest Isle", id=426, min=74, max=76, zem=1.00, indoor=true }  -- 128 spawns
add{ short="thalassius", name="Thalassius, the Coral Keep", id=417, min=73, max=76, zem=1.00, indoor=true }  -- 287 spawns
add{ short="buriedsea", name="The Buried Sea", id=423, min=68, max=76, zem=1.00, indoor=true, hot=75 }  -- 876 spawns
add{ short="shipmvp", name="The Open Sea (A)", id=431, min=73, max=76, zem=1.00, indoor=true }  -- 62 spawns
add{ short="zhisza", name="Zhisza, the Shissar Sanctuary", id=419, min=75, max=78, zem=1.00, indoor=true }  -- 194 spawns

--===== SoF : 14 zones =====
exp = "SoF"

add{ short="bloodmoon", name="Bloodmoon Keep", id=445, min=80, max=81, zem=1.00, indoor=true }  -- 276 spawns
add{ short="cryptofshade", name="Crypt of Shade", id=449, zem=1.00 }  -- no spawn data
add{ short="crystallos", name="Crystallos, Lair of the Awakened", id=446, min=82, max=82, zem=1.00 }  -- 253 spawns
add{ short="dragonscaleb", name="Deepscar's Den", id=451, min=83, max=83, zem=1.50, indoor=true }  -- 1 spawns
add{ short="dragonscale", name="Dragonscale Hills", id=442, min=68, max=80, zem=1.00, indoor=true }  -- 698 spawns
add{ short="mechanotus", name="Fortress Mechanotus", id=436, min=78, max=80, zem=1.00, indoor=true, hot=80 }  -- 949 spawns
add{ short="gyrospireb", name="Gyrospire Beza", id=440, min=79, max=82, zem=1.00, indoor=true }  -- 193 spawns
add{ short="gyrospirez", name="Gyrospire Zeka", id=441, min=80, max=83, zem=1.00, indoor=true, hot=85 }  -- 204 spawns
add{ short="hillsofshade", name="Hills of Shade", id=444, min=79, max=83, zem=1.00, indoor=true }  -- 629 spawns
add{ short="lopingplains", name="Loping Plains", id=443, min=75, max=79, zem=1.00, indoor=true }  -- 575 spawns
add{ short="mansion", name="Meldrath's Majestic Mansion", id=437, min=81, max=83, zem=1.00, indoor=true, hot=85 }  -- 389 spawns
add{ short="shipworkshop", name="S.H.I.P. Workshop", id=439, min=80, max=83, zem=1.00, indoor=true }  -- 429 spawns
add{ short="guardian", name="The Mechamatic Guardian", id=447, min=78, max=82, zem=1.00 }  -- 310 spawns
add{ short="steamfactory", name="The Steam Factory", id=438, min=81, max=83, zem=1.00, indoor=true }  -- 707 spawns

--===== SoD : 27 zones =====
exp = "SoD"

add{ short="oldkithicor", name="Bloody Kithicor", id=456, min=75, max=80, zem=1.50, indoor=true }  -- 513 spawns
add{ short="discordtower", name="Citadel of the Worldslayer", id=471, min=90, max=90, zem=1.50, indoor=true }  -- 1 spawns
add{ short="olddranik", name="City of Dranik", id=474, min=84, max=87, zem=1.50, indoor=true }  -- 228 spawns
add{ short="oldfieldofboneb", name="Field of Scale" }  -- no spawn data
add{ short="oldkaesorab", name="Hatchery Wing", id=454, min=83, max=85, zem=1.50, indoor=true }  -- 84 spawns
add{ short="oldkaesoraa", name="Kaesora Library", id=453, min=84, max=85, zem=1.50, indoor=true }  -- 344 spawns
add{ short="discord", name="Korafax, Home of the Riders", id=470, min=84, max=87, zem=1.50, indoor=true }  -- 220 spawns
add{ short="korascian", name="Korascian Warrens", id=476, min=84, max=86, zem=1.50, indoor=true }  -- 339 spawns
add{ short="oceangreenhills", name="Oceangreen Hills", id=466, min=73, max=76, zem=1.50, indoor=true }  -- 379 spawns
add{ short="oceangreenvillage", name="Oceangreen Village", id=467, min=72, max=75, zem=1.50, indoor=true }  -- 212 spawns
add{ short="oldblackburrow", name="Old Blackburrow", id=468, min=75, max=76, zem=1.50, indoor=true }  -- 182 spawns
add{ short="oldbloodfield", name="Old Bloodfields", id=472, min=85, max=86, zem=1.50, indoor=true }  -- 248 spawns
add{ short="oldcommons", name="Old Commonlands", id=457, min=9, max=79, zem=1.50, indoor=true }  -- 568 spawns
add{ short="oldfieldofbone", name="Old Field of Scale", id=452, min=80, max=82, zem=1.50, indoor=true }  -- 579 spawns
add{ short="oldhighpass", name="Old Highpass Hold", id=458, zem=1.50, emuOnly=true }  -- no spawn data
add{ short="oldkurn", name="Old Kurn's Tower", id=455, min=81, max=85, zem=1.50, indoor=true }  -- 195 spawns
add{ short="rathechamber", name="Rathe Council Chambers", id=477, min=84, max=86, zem=1.50, indoor=true }  -- 262 spawns
add{ short="bertoxtemple", name="Temple of Bertoxxulous", id=469, min=75, max=77, zem=1.50, indoor=true }  -- 82 spawns
add{ short="precipiceofwar", name="The Precipice of War", id=473, min=84, max=86, zem=1.50 }  -- 44 spawns
add{ short="thevoida", name="The Void (A)", id=459, min=90, max=90, zem=1.50, indoor=true, cat="hub" }  -- 1 spawns
add{ short="toskirakk", name="Toskirakk", id=475, min=80, max=85, zem=1.50, indoor=true }  -- 303 spawns

--===== UF : 16 zones =====
exp = "UF"

add{ short="arthicrex", name="Arthicrex", id=485, min=84, max=86, zem=1.00, indoor=true, hot=90 }  -- 487 spawns
add{ short="brellsarena", name="Brell's Arena", id=492, min=84, max=89, zem=1.00, indoor=true, cat="arena" }  -- 13 spawns
add{ short="brellsrest", name="Brell's Rest", id=480, min=83, max=86, zem=1.00, indoor=true }  -- 247 spawns
add{ short="brellstemple", name="Brell's Temple", id=490, min=83, max=85, indoor=true }  -- 97 spawns
add{ short="fungalforest", name="Fungal Forest", id=481, min=85, max=86, indoor=true }  -- 474 spawns
add{ short="shiningcity", name="Kernagir, The Shining City", id=484, min=83, max=86 }  -- 564 spawns
add{ short="dragoncrypt", name="Lair of the Fallen", id=495, min=85, max=85, indoor=true, cat="instance" }  -- 11 spawns
add{ short="lichencreep", name="Lichen Creep", id=487, min=85, max=85, indoor=true }  -- 584 spawns
add{ short="pellucid", name="Pellucid Grotto", id=488, min=83, max=85, zem=1.00, indoor=true }  -- 458 spawns
add{ short="convorteum", name="The Convorteum", id=491, min=85, max=86, indoor=true }  -- 708 spawns
add{ short="coolingchamber", name="The Cooling Chamber", id=483, min=83, max=87, zem=1.00, indoor=true }  -- 603 spawns
add{ short="foundation", name="The Foundation", id=486, min=84, max=86, zem=1.00, indoor=true, hot=85 }  -- 449 spawns
add{ short="underquarry", name="The Underquarry", id=482, min=83, max=85, zem=1.00, indoor=true }  -- 632 spawns
add{ short="stonesnake", name="Volska's Husk", id=489, min=85, max=86, zem=1.00, indoor=true }  -- 218 spawns
add{ short="weddingchapel", name="Wedding Chapel", id=493, min=1, max=1, cat="event" }  -- 33 spawns

--===== HoT : 23 zones =====
exp = "HoT"

add{ short="alkabormare", name="Al`Kabor's Nightmare", id=709, min=88, max=90, indoor=true }  -- 262 spawns
add{ short="fallen", name="Erudin Burning", id=706, min=85, max=88, indoor=true }  -- 348 spawns
add{ short="thuledream", name="Fear Itself", id=711, min=88, max=91, indoor=true, hot=90 }  -- 379 spawns
add{ short="thulehouse1", name="House of Thule", id=701, min=83, max=85, indoor=true }  -- 181 spawns
add{ short="thulehouse2", name="House of Thule, Upper Floors", id=702, min=88, max=90, indoor=true }  -- 274 spawns
add{ short="miragulmare", name="Miragul's Nightmare", id=710, min=88, max=90, indoor=true }  -- 206 spawns
add{ short="phylactery", name="Miragul's Phylactery" }  -- no spawn data
add{ short="morellcastle", name="Morell's Castle", id=707, min=89, max=93 }  -- 334 spawns
add{ short="morelltower", name="Morell's Tower", emuOnly=true }  -- no spawn data
add{ short="somnium", name="Sanctum Somnium", id=708, min=89, max=91 }  -- 283 spawns
add{ short="neighborhood", name="Sunrise Hills", id=712, min=50, max=85, indoor=true, cat="housing" }  -- 31 spawns
add{ short="feerrott2", name="The Feerrott (B)", id=700, min=84, max=86, indoor=true }  -- 473 spawns
add{ short="housegarden", name="The Grounds", id=703, min=85, max=87, indoor=true }  -- 386 spawns
add{ short="thulelibrary", name="The Library", id=704, min=87, max=90, zem=1.00 }  -- 111 spawns
add{ short="well", name="The Well", id=705, min=87, max=90, indoor=true }  -- 72 spawns

--===== VoA : 29 zones =====
exp = "VoA"

add{ short="argath", name="Argath", id=724, min=88, max=91, indoor=true, hot=90 }  -- 659 spawns
add{ short="beastdomain", name="Beast's Domain", id=728, min=93, max=96, indoor=true }  -- 550 spawns
add{ short="cityofbronze", name="City of Bronze", id=732, min=94, max=96, indoor=true }  -- 939 spawns
add{ short="eastsepulcher", name="East Sepulcher", id=734, min=96, max=98 }  -- 295 spawns
add{ short="pillarsalra", name="Pillars of Alra", id=730, min=95, max=97, indoor=true, hot=95 }  -- 815 spawns
add{ short="resplendent", name="Resplendent Temple", id=729, min=94, max=95, indoor=true, hot=95 }  -- 480 spawns
add{ short="rubak", name="Rubak Oseka", id=727, min=93, max=95 }  -- 156 spawns
add{ short="sarithcity", name="Sarith, City of Tides", id=726, min=91, max=93, indoor=true, hot=95 }  -- 361 spawns
add{ short="sepulcher", name="Sepulcher of Order", id=733, min=95, max=97 }  -- 556 spawns
add{ short="shadowedmount", name="Shadowed Mount" }  -- no spawn data
add{ short="arelis", name="Valley of Lunanyn", id=725, min=90, max=95, indoor=true }  -- 641 spawns
add{ short="westsepulcher", name="West Sepulcher", id=735, min=95, max=98 }  -- 381 spawns
add{ short="windsong", name="Windsong", id=731, min=94, max=96, indoor=true }  -- 434 spawns

--===== RoF : 17 zones =====
exp = "RoF"

add{ short="chapterhouse", name="Chapterhouse of the Fallen", id=760, min=98, max=100, indoor=true }  -- 455 spawns
add{ short="chelsithreborn", name="Chelsith Reborn", cat="nodata" }  -- no spawn data
add{ short="eastwastesshard", name="East Wastes: Zeixshi-Kar's Awakening", id=755, min=96, max=98, indoor=true }  -- 527 spawns
add{ short="eviltree", name="Evantil, the Vile Oak", id=758, min=98, max=100, indoor=true }  -- 472 spawns
add{ short="grelleth", name="Grelleth's Palace, the Chateau of Filth", id=759, min=99, max=102, indoor=true }  -- 313 spawns
add{ short="heartoffearc", name="Heart of Fear: The Epicenter", cat="nodata" }  -- no spawn data
add{ short="heartoffearb", name="Heart of Fear: The Rebirth", cat="nodata" }  -- no spawn data
add{ short="heartoffear", name="Heart of Fear: The Threshold", cat="nodata" }  -- no spawn data
add{ short="kaelshard", name="Kael Drakkel: The King's Madness", id=754, min=97, max=99, indoor=true }  -- 420 spawns
add{ short="poshadow", name="Plane of Shadow", cat="nodata" }  -- no spawn data
add{ short="shardslanding", name="Shard's Landing", id=752, min=95, max=99, indoor=true, hot=100 }  -- 838 spawns
add{ short="breedinggrounds", name="The Breeding Grounds", id=757, min=99, max=102 }  -- 260 spawns
add{ short="burnedwoods", name="The Burned Woods", emuOnly=true }  -- no spawn data
add{ short="crystalshard", name="The Crystal Caverns: Fragment of Fear", id=756, min=96, max=99 }  -- 238 spawns
add{ short="pomischief", name="The Plane of Mischief" }  -- no spawn data
add{ short="xorbb", name="Valley of King Xorbb", id=753, min=99, max=101, indoor=true }  -- 777 spawns

--===== CotF : 7 zones =====
exp = "CotF"

add{ short="arginhiz", name="Argin-Hiz", min=99, max=101 }  -- Alla: 37 NPCs
add{ short="bixiewarfront", name="Bixie Warfront", min=99, max=99 }  -- Alla: 14 NPCs
add{ short="ethernere", name="Ethernere Tainted West Karana", min=99, max=100 }  -- Alla: 149 NPCs
add{ short="neriakd", name="Neriak - Fourth Gate", id=43, min=100, max=101, zem=1.00, city=true, hot=105 }  -- Alla: 221 NPCs
add{ short="deadhills", name="The Dead Hills", min=100, max=101 }  -- Alla: 38 NPCs
add{ short="towerofrot", name="Tower of Rot", min=100, max=102, hot=105 }  -- Alla: 72 NPCs

--===== TDS : 8 zones =====
exp = "TDS"

add{ short="arxmentis", name="Arx Mentis", min=104, max=106 }  -- Alla: 47 NPCs
add{ short="brotherisland", name="Brother Island", min=101, max=103 }  -- Alla: 64 NPCs
add{ short="endlesscaverns", name="Caverns of Endless Song", min=104, max=108 }  -- Alla: 64 NPCs
add{ short="dredge", name="Combine Dredge", min=106, max=108 }  -- Alla: 89 NPCs
add{ short="degmar", name="Degmar, the Lost Castle", min=105, max=106 }  -- Alla: 36 NPCs
add{ short="kattacastrumb", name="Katta Castrum, The Deluge", min=98, max=100 }  -- Alla: 21 NPCs
add{ short="tempesttemple", name="Tempest Temple", min=99, max=100, hot=100 }  -- Alla: 40 NPCs
add{ short="thuliasaur", name="Thuliasaur Island", min=105, max=107 }  -- Alla: 92 NPCs

--===== TBM : 5 zones =====
exp = "TBM"

add{ short="cosul", name="Crypt of Sul", min=105, max=107 }  -- Alla: 26 NPCs
add{ short="codecayb", name="Ruins of Lxanvom", min=106, max=108 }  -- Alla: 47 NPCs
add{ short="exaltedb", name="Sul Vius: Demiplane of Decay", min=105, max=107 }  -- Alla: 93 NPCs
add{ short="exalted", name="Sul Vius: Demiplane of Life", min=105, max=106 }  -- Alla: 47 NPCs
add{ short="pohealth", name="The Plane of Health", min=105, max=106 }  -- Alla: 28 NPCs

--===== EoK : 7 zones =====
exp = "EoK"

add{ short="chardoktwo", name="Chardok", min=106, max=108 }  -- Alla: 90 NPCs
add{ short="frontiermtnsb", name="Frontier Mountains", min=103, max=106 }  -- Alla: 105 NPCs
add{ short="korshaext", name="Gates of Kor-Sha", min=99, max=106 }  -- Alla: 28 NPCs
add{ short="korshaint", name="Kor-Sha Laboratory", min=106, max=108 }  -- Alla: 39 NPCs
add{ short="lceanium", name="Lceanium", min=105, max=107 }  -- Alla: 35 NPCs
add{ short="scorchedwoods", name="Scorched Woods", min=103, max=106 }  -- Alla: 78 NPCs
add{ short="drogab", name="Temple of Droga", min=106, max=108 }  -- Alla: 106 NPCs

--===== RoS : 6 zones =====
exp = "RoS"

add{ short="gorowyn", name="Gorowyn", min=110, max=113 }  -- Alla: 56 NPCs
add{ short="charasistwo", name="Howling Stones", min=110, max=113 }  -- Alla: 24 NPCs
add{ short="charasisb", name="Sathir's Tomb", min=110, max=113 }  -- Alla: 46 NPCs
add{ short="skyfiretwo", name="Skyfire Mountains", min=110, max=113 }  -- Alla: 75 NPCs
add{ short="overtheretwo", name="The Overthere", min=109, max=111 }  -- Alla: 52 NPCs
add{ short="veeshantwo", name="Veeshan's Peak", min=110, max=113 }  -- Alla: 26 NPCs

--===== TBL : 8 zones =====
exp = "TBL"

add{ short="aalishai", name="AAlishai: Palace of Embers", min=109, max=112 }  -- Alla: 56 NPCs
add{ short="empyr", name="Empyr: Realms of Ash", min=108, max=112 }  -- Alla: 50 NPCs
add{ short="esianti", name="Esianti: Palace of the Winds", min=109, max=112 }  -- Alla: 44 NPCs
add{ short="gnomemtn", name="Gnome Memorial Mountain", min=107, max=109 }  -- Alla: 57 NPCs
add{ short="mearatas", name="Mearatas: The Stone Demesne", min=110, max=112 }  -- Alla: 36 NPCs
add{ short="trialsofsmoke", name="Plane of Smoke", min=108, max=112 }  -- Alla: 20 NPCs
add{ short="stratos", name="Stratos: Zephyr's Flight", min=108, max=111 }  -- Alla: 59 NPCs
add{ short="chamberoftears", name="The Chamber of Tears", min=95, max=112 }  -- Alla: 8 NPCs

--===== ToV : 7 zones =====
exp = "ToV"

add{ short="crystaltwob", name="Crystal Caverns", min=112, max=115 }  -- Alla: 21 NPCs
add{ short="kaeltwo", name="Kael Drakkel", min=114, max=116 }  -- Alla: 312 NPCs
add{ short="eastwastestwo", name="The Eastern Wastes", min=113, max=115 }  -- Alla: 34 NPCs
add{ short="greatdividetwo", name="The Great Divide", min=113, max=116 }  -- Alla: 36 NPCs
add{ short="crystaltwoa", name="The Ry`Gorr Mines", min=113, max=115 }  -- Alla: 17 NPCs
add{ short="frozenshadowtwo", name="The Tower of Frozen Shadow", min=113, max=115 }  -- Alla: 51 NPCs
add{ short="velketortwo", name="Velketor's Labyrinth", min=113, max=115 }  -- Alla: 25 NPCs

--===== CoV : 6 zones =====
exp = "CoV"

add{ short="cobaltscartwo", name="Cobalt Scar", min=112, max=115 }  -- Alla: 36 NPCs
add{ short="necropolistwo", name="Dragon Necropolis", min=112, max=115 }  -- Alla: 33 NPCs
add{ short="skyshrinetwo", name="Skyshrine", min=112, max=118 }  -- Alla: 22 NPCs
add{ short="sleepertwo", name="The Sleeper's Tomb", min=113, max=116 }  -- Alla: 28 NPCs
add{ short="templeveeshantwo", name="The Temple of Veeshan", min=112, max=116 }  -- Alla: 27 NPCs
add{ short="westwastestwo", name="The Western Wastes", min=112, max=113 }  -- Alla: 16 NPCs

--===== ToL : 8 zones =====
exp = "ToL"

add{ short="basilica", name="Basilica of Adumbration", min=118, max=118 }  -- Alla: 34 NPCs
add{ short="bloodfalls", name="Bloodfalls", min=118, max=123 }  -- Alla: 36 NPCs
add{ short="akhevatwo", name="Ka Vethan", min=118, max=119 }  -- Alla: 24 NPCs
add{ short="maidentwo", name="Maiden's Eye", min=115, max=117 }  -- Alla: 44 NPCs
add{ short="shadowvalley", name="Shadow Valley", min=118, max=120 }  -- Alla: 48 NPCs
add{ short="umbraltwo", name="Umbral Plains", min=116, max=119 }  -- Alla: 44 NPCs
add{ short="vexthaltwo", name="Vex Thal", min=118, max=120 }  -- Alla: 74 NPCs

--===== NoS : 8 zones =====
exp = "NoS"

add{ short="darklightcaverns", name="Darklight Caverns", min=118, max=120 }  -- Alla: 21 NPCs
add{ short="deepshade", name="Deepshade", min=118, max=121 }  -- Alla: 26 NPCs
add{ short="firefallpass", name="Firefall Pass", min=117, max=118 }  -- Alla: 34 NPCs
add{ short="paludaltwo", name="Paludal Depths", min=119, max=121 }  -- Alla: 37 NPCs
add{ short="shadowhaventwo", name="Ruins of Shadow Haven", min=119, max=121 }  -- Alla: 25 NPCs
add{ short="shadeweavertwo", name="Shadeweaver's Tangle", min=117, max=120 }  -- Alla: 76 NPCs
add{ short="sharvahltwo", name="Shar Vahl, Divided", min=118, max=121 }  -- Alla: 30 NPCs

--===== LS : 9 zones =====
exp = "LS"

add{ short="ankexfen", name="Ankexfen Keep", min=122, max=125 }  -- Alla: 33 NPCs
add{ short="guildhallsng", name="Boldven's Hideout", min=123, max=126 }  -- Alla: 6 NPCs
add{ short="laurioninn", name="Laurion's Inn", min=122, max=124 }  -- Alla: 39 NPCs
add{ short="moorsofnokk", name="Moors of Nokk", min=124, max=126 }  -- Alla: 41 NPCs
add{ short="pallomen", name="Pal'Lomen", min=123, max=125 }  -- Alla: 33 NPCs
add{ short="herosforge", name="The Hero's Forge", min=124, max=126 }  -- Alla: 18 NPCs
add{ short="anniversarytower", name="Tides of Time", cat="hub" }  -- no spawn data
add{ short="timorousfalls", name="Timorous Falls", min=122, max=125 }  -- Alla: 32 NPCs
add{ short="unkemptwoods", name="Unkempt Woods", min=123, max=126 }  -- Alla: 49 NPCs

--===== TOB : 6 zones =====
exp = "TOB"

add{ short="aureatecovert", name="Aureate Covert", min=123, max=124 }  -- Alla: 12 NPCs
add{ short="hodstock", name="Hodstock Hills", min=122, max=125 }  -- Alla: 43 NPCs
add{ short="puissance", name="The Chambers of Puissance", min=124, max=126 }  -- Alla: 17 NPCs
add{ short="gildedspire", name="The Gilded Spire", min=124, max=126 }  -- Alla: 22 NPCs
add{ short="harbingerscradle", name="The Harbinger's Cradle", min=124, max=125 }  -- Alla: 15 NPCs
add{ short="toe", name="The Theater of Eternity", min=123, max=125 }  -- Alla: 26 NPCs

--===== SoR : 6 zones =====
exp = "SoR"

add{ short="arcstoneruins", name="Arcstone, Shattered Isles", min=128, max=130 }  -- Alla: 31 NPCs
add{ short="candlemakers", name="Candlemaker's Workshop", min=128, max=130 }  -- Alla: 43 NPCs
add{ short="spite", name="Labyrinth of Spite", min=128, max=131 }  -- Alla: 49 NPCs
add{ short="ruinedrelic", name="Ruined Relic", min=128, max=130 }  -- Alla: 64 NPCs
add{ short="embattledpogrowth", name="Scarred Grove", min=128, max=129 }  -- Alla: 31 NPCs
add{ short="vortex", name="The Vortex", min=128, max=131 }  -- Alla: 24 NPCs

zones.hotPoolVerified = "2026-09-05"
zones.hotPool = {
    { level = 20, active = 1, { name = "Upper Guk", short = "guktop" }, { name = "South Karana", short = "southkarana" }, { name = "Paludal Caverns", short = "paludal" } },
    { level = 25, active = 1, { name = "Stonebrunt Mountains", short = "stonebrunt" }, { name = "Lake of Ill Omen", short = "lakeofillomen" }, { name = "Nedaria's Landing", short = "nedaria" } },
    { level = 30, active = 1, { name = "Blightfire Moors", short = "moors" }, { name = "Solusek's Eye", short = "soldunga" }, { name = "Dalnir", short = "dalnir" } },
    { level = 35, active = 1, { name = "Great Divide", short = "greatdivide" }, { name = "Stone Hive", short = "stonehive" }, { name = "Dreadlands", short = "dreadlands" } },
    { level = 40, active = 1, { name = "Mons Letalis", short = "letalis" }, { name = "City of Mist", short = "citymist" }, { name = "The Emerald Jungle", short = "emeraldjungle" } },
    { level = 45, active = 1, { name = "Dulak's Harbor", short = "dulak" }, { name = "Dranik's Scar", short = "draniksscar" }, { name = "The Scarlet Desert", short = "scarlet" } },
    { level = 50, active = 3, { name = "Velketor's Labyrinth", short = "velketor" }, { name = "Old Sebilis", short = "sebilis" }, { name = "Skyfire Mountains", short = "skyfire" } },
    { level = 55, active = 3, { name = "The Deep", short = "thedeep" }, { name = "Plane of Innovation", short = "poinnovation" }, { name = "Riwwi, Coliseum of Games", short = "riwwi" } },
    { level = 60, active = 3, { name = "Veksar", short = "veksar" }, { name = "Blackfeather Roost", short = "roost" }, { name = "Barindu, Hanging Gardens", short = "barindu" } },
    { level = 65, active = 3, { name = "Barren Coast", short = "barren" }, { name = "Drunder, Fortress of Zek", short = "potactics" }, { name = "Torden, The Bastion of Thunder", short = "bothunder" } },
    { level = 70, active = 3, { name = "Arcstone", short = "arcstone" }, { name = "The Hive", short = "drachnidhive" }, { name = "Stoneroot Falls", short = "westkorlach" } },
    { level = 75, active = 3, { name = "Direwind Cliffs", short = "direwind" }, { name = "Jewel of Atiiki", short = "atiiki" }, { name = "The Buried Sea", short = "buriedsea" } },
    { level = 80, active = 3, { name = "Valdeholm", short = "valdeholm" }, { name = "Fortress Mechanotus", short = "mechanotus" }, { name = "Silyssar, New Chelsith", short = "silyssar" } },
    { level = 85, active = 3, { name = "Meldrath's Majestic Mansion", short = "mansion" }, { name = "The Foundation", short = "foundation" }, { name = "Gyrospire Zeka", short = "gyrospirez" } },
    { level = 90, active = nil, { name = "Fear Itself", short = "thuledream" }, { name = "Arthicrex", short = "arthicrex" }, { name = "Argath", short = "argath" } },
    { level = 95, active = nil, { name = "Pillars of Alra", short = "pillarsalra" }, { name = "Sarith, City of Tides", short = "sarithcity" }, { name = "Resplendent Temple", short = "resplendent" } },
    { level = 100, active = nil, { name = "Shard's Landing", short = "shardslanding" }, { name = "Tempest Temple", short = "tempesttemple" } },
    { level = 105, active = nil, { name = "Neriak - Fourth Gate", short = "neriakd" }, { name = "Tower of Rot", short = "towerofrot" } },
}

return zones
