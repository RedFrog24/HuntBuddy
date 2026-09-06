# HuntBuddy

> Lua to help you find new places to hunt. Boredom Begone!

![image](https://github.com/user-attachments/assets/bfa698e7-3cf0-4dc8-8f8f-d33ff16a9469)

HuntBuddy is a zone reference for Live and EMU. Every zone in the game in one sortable list — level
range, experience modifier, hot zone status — with filters to narrow it to somewhere worth your time,
and a Go button to take you there.

- **All 33 expansions**, Classic through Shattering of Ro — 571 zones
- **Sort by name, level or ZEM**, filter by level band, expansion, indoor/outdoor and more
- **Hot Zone tab** showing all three possible hot zones for every bracket from 20 to 105
- **Travel to any zone** with one click (needs MQ2EasyFind), including group travel
- **Mark favourites and your own "good money here" zones** — saved between sessions
- **Live and EMU aware** — EMU caps at Dragons of Norrath, and zones your client can't load are hidden
  on Live
- **Eleven themes**, including four map-and-atlas palettes

## The zone data

The whole table was rebuilt from scratch, and **every value in it comes from a named source** rather
than being typed in by hand:

| What | Where it comes from |
|---|---|
| Zone names, short names, expansion | MacroQuest's own zone list |
| Zone IDs and experience modifiers | The ProjectEQ database |
| Level ranges | The monsters actually spawned in each zone |
| Which zones your client can load | The `.eqg` / `.s3d` files in your EverQuest folder |
| Hot zones | The published rotation pool, verified in game against Franklin Teek |

**Level ranges are worked out from the monsters that are really there**, and deliberately exclude the
things that would skew them — decorative wildlife, merchants, bankers, guards, quest NPCs and porters.
A newbie zone with two level-50 guards standing at the entrance is still a newbie zone.

**A level range of `--` means we have no data for that zone, not that it is empty.** A handful of
zones have no published monster list anywhere; they are listed by name so you can still find and
travel to them.

Zones that exist but are not places you hunt — mission hubs, arenas, guild halls, loading zones — are
flagged, and the **Hunting Only** filter hides them.

## Using it

```
/lua run huntbuddy
```

Closing the window with the X stops the script. Your theme, server mode, group-travel setting,
favourites and platinum marks are saved to `config/HuntBuddySettings.ini` and survive updates.

Four tabs: **Zones** for the list, **HotZone** for the rotation pool, **Settings**, and **Help** —
which shows your zone-data version, the fastest way to tell me what you are running if something
looks wrong.

## About the version number

HuntBuddy used to use three-part version numbers like 2.3.90. It now uses two-part numbers.
**2.31 looks like a smaller number than 2.3.90, but it is the newer build** — same script, renumbered.
Everything from here is 2.32, 2.33 and so on.

## Notes on ZEM

Daybreak has never published experience modifiers for Live, and the client is never told them — they
live on the server. The numbers shown come from the ProjectEQ database, where a value of **1.00 is the
normal outdoor rate**, not "no data". They are a good guide to which zones are better than others, and
should be treated as a relative hint rather than an exact Live figure. On EMU your server's owner can
change them, so they may differ there too.

## Feedback

Bug reports and zone corrections are very welcome — especially level ranges that look wrong for a zone
you know well. Include the zone-data version from the Help tab.
