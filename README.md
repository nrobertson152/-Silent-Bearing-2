# Silent Bearing 2

**1988. The Cold War has gone hot, and the enemy has pushed you back to your home waters.**

Silent Bearing 2 is a naval warfare game made with [Godot 4.7](https://godotengine.org). You command
American or Soviet warships through a campaign, working up from a frigate to a submarine, a destroyer,
two kinds of cruiser and finally a modernised battleship carrying nuclear weapons. Between missions,
situation reports describe what the Army, the Air Force and the rest of the fleet are doing.

Everything is generated in code: ship models, textures, the ocean, the sky, terrain, sound, music and
the campaign map. The repository contains no binary assets.

## Download

Linux and Windows builds are attached to each [release](../../releases). Every pull request also
produces builds, which you can download from that run's Actions artifacts.

- **Linux:** `SilentBearing2-x86_64.AppImage` runs on most distributions with nothing to install. Make it
  executable (`chmod +x SilentBearing2-x86_64.AppImage`, or tick "Allow executing" in its file properties)
  and run it. On systems without FUSE, run it with `--appimage-extract-and-run`. The plain
  `SilentBearing2-linux-x86_64.tar.gz` build is there too.
- **Windows:** unzip `SilentBearing2-windows-x86_64.zip` and run `SilentBearing2.exe`.

You need a GPU that supports Vulkan for the full Forward+ renderer. Without Vulkan the game falls back
to OpenGL 3 automatically.

## The campaigns

**Long Way Back** (United States Navy). Norway and Iceland have fallen, and Soviet submarines are off
the Virginia Capes. You fight from American waters back across the Atlantic to the Barents Sea.

| # | Mission | Ship | Where |
|---|---------|------|-------|
| 1 | Capes Patrol | USS *Samuel B. Roberts* (FFG-58), *Perry*-class frigate | Off Cape Henry, Virginia |
| 2 | Hunter at Bermuda | USS *Dallas* (SSN-700), *Los Angeles*-class submarine | South of Bermuda |
| 3 | Georges Bank | USS *Spruance* (DD-963), destroyer | Off Cape Cod |
| 4 | Iceland Convoy | USS *Bunker Hill* (CG-52), *Ticonderoga*-class Aegis cruiser | South of Iceland |
| 5 | Reykjanes Guns | USS *Salem* (CA-139), *Des Moines*-class heavy cruiser | Reykjanes Peninsula, Iceland |
| 6 | Lofoten | USS *Missouri* (BB-63), *Iowa*-class battleship | West of the Lofoten Islands |
| 7 | Barents Gate | USS *Missouri* | Off North Cape |

**Northern Bastion** (Soviet Navy). NATO has thrown the Warsaw Pact back across the inner-German border,
and American carriers strike the Kola Peninsula every day. You hold the bastion, then drive the
Americans back into the Atlantic.

| # | Mission | Ship | Where |
|---|---------|------|-------|
| 1 | Kola Inlet | *Bezzavetny*, Krivak I-class frigate | Mouth of the Kola Bay |
| 2 | Bear Island | K-284, Akula-class submarine | Barents Sea |
| 3 | Varangerfjord | *Otlichny*, Sovremenny-class destroyer | Off the Norwegian border |
| 4 | Guns for Kirkenes | *Murmansk*, Sverdlov-class light cruiser | Off Kirkenes |
| 5 | Breakout | *Kirov*, nuclear battlecruiser | Norwegian Sea |
| 6 | Keflavik | *Sovetsky Soyuz*, battleship | Reykjanes Peninsula, Iceland |
| 7 | Denmark Strait | *Sovetsky Soyuz* | Denmark Strait |

The campaign map shows real coastlines and who holds Iceland, northern Norway, the Faroes, Pechenga
and Bermuda as the war moves, along with the land front in Germany. Coastal missions take place along
real coastlines, with shore batteries, SAM sites and radars to bombard. In the last mission of each
campaign you are authorised to use nuclear weapons, and the ending changes if you do.

**Free battle** lets you take any of the twelve ships into five kinds of fight (surface action, duel,
convoy defence, convoy attack, air raid) in five different waters, at any time of day and in any sea
state. For the battleships you can also authorise nuclear release.

The game takes some liberties with history. *Sovetsky Soyuz* was never finished; here she was
completed in the 1950s and modernised with missiles. *Salem* is back in commission, just as the *Iowa*s were.
Ship, weapon and aircraft figures otherwise follow published 1988 data.

## What is simulated

- **Engines.** Steam, gas-turbine, nuclear and diesel plants. On telegraph ships you ring a bell and
  wait for the engine room to answer, and you must pass through STOP before going astern. A steam
  ship loses pressure if you ring up more speed than its lit boilers can supply. Gas turbines take
  about 90 seconds to start. The US gas-turbine ships use controllable-pitch propeller levers instead
  of bells.
- **Ship handling.** Rudder rate limits, Nomoto steering dynamics, speed lost and heel taken in a turn,
  and turning circles close to the real ships'.
- **Gunnery.** Shells fly ballistic paths with drag fitted to each gun's published maximum range. Every
  shot has a time of flight and dispersion. Firing tables and a director give you a lead solution.
- **Armour.** Penetration is scaled with the de Marre formula against belt, deck and turret armour at
  the striking angle. The result can be a ricochet, a non-penetration, a penetration or an
  overpenetration.
- **Damage.** Compartments flood and burn, damage-control teams fight both, magazines can explode,
  and ships list, settle and sink. Radar, fire control, steering, the engines and individual weapon
  mounts can all be knocked out.
- **Missiles and air defence.** Sea-skimming, pop-up, diving and weaving anti-ship missiles. SAMs and
  CIWS are limited by fire-control channels and reaction time. Bombers come in raids and fighters fly
  combat air patrols.
- **Submarines and torpedoes.** A passive sonar model where target speed is heard, own speed deafens
  and the thermal layer hides you. Torpedoes are wire-guided, active-homing or wake-homing. You also
  get decoys, a crush depth, and a periscope that only works at periscope depth.
- **Sensors.** Radar horizon, visibility, night and weather all decide what you can see.
- **The world.** Gerstner ocean waves set by the sea state, the real sun and moon for the date, place
  and time, clouds, aurora, fog, and the curvature of the Earth.

## Controls

| Key | Action |
|-----|--------|
| W / S, Up / Down | Engine orders (telegraph bells or throttle lever) |
| A / D, Left / Right | Rudder (Shift for hard over), X amidships |
| C | Steady: the helmsman holds the current heading |
| V | Bridge or outside view (submarines: control room or outside) |
| B | Gun director sight |
| M or Tab | Tactical plot: click a contact to target it |
| Mouse | Look and aim. On the bridge, right-drag to look and click the controls |
| Left click | Fire the selected weapon |
| 1 to 6 | Weapon group: main, secondary, anti-ship missiles, SAM, ASW / torpedoes, strike |
| Z | Ammunition or missile type |
| T | Designate the target nearest the crosshair (control room: next sonar contact) |
| F | Director on or off |
| Space | Launch a missile or torpedo at the target |
| Q | Air defence AUTO / HOLD |
| R | Radar on or off (EMCON) |
| G | General quarters |
| H | Ship's whistle |
| PgUp / PgDn | Submarine depth |
| P | Periscope (submarines) |
| N | Decoy (submarines) |
| . and , | Time compression |
| F1 | Controls overlay |
| Esc | Pause |

On the bridge almost everything has a working control. You can turn the wheel, ring the telegraph,
start turbines and light boilers on the machinery panel, switch radars, sound alarms and the whistle,
and use the special-weapons panel. Nuclear release takes two keys and a guarded button.

In a submarine you start in the control room. It has the broadband sonar waterfall, the contact
tracker, the tubes, the depth gauge and clickable orders.

## Building from source

1. Install [Godot 4.7.2](https://godotengine.org/download).
2. Open `project.godot` in the editor and press Play, or run `godot --path .` from this folder.

To export, install the export templates and run
`godot --headless --path . --export-release "Linux" build/SilentBearing2.x86_64`. Use `"Windows"`
for a Windows build.

### Command line

Arguments after `--`, used by CI and for screenshots:

| Flag | Effect |
|------|--------|
| `--mission us5` | Start a campaign mission directly |
| `--sandbox bb61` | Start a test battle in any ship class |
| `--screen map:us` | Open a screen: `menu`, `free`, `map:<side>`, `brief:<id>`, `intro:<side>`, `sitrep:<id>`, `ending:<side>`, `debrief:<id>` |
| `--warp 8` | Time compression |
| `--smoke 120` | Quit after this many seconds of battle time |
| `--shot out.png 10 [view]` | Save a screenshot after 10 seconds (`view`: bridge, external, scope) |
| `--at X Y`, `--depth M`, `--hour H`, `--vis KM` | Place the ship, set submarine depth, time of day, visibility |

### Tests

```
godot --headless --path . -s tools/check_scripts.gd   # every script compiles
godot --headless --path . -s tests/run_tests.gd       # ballistics, propulsion, ship handling, combat
godot --headless --path . -s tests/flow_test.gd       # menus, campaign flow, submarines, effects, all 14 missions
```

CI runs all three on every push and pull request, plus headless battles in six ships and six coastal
missions. It then builds Linux and Windows releases.

### Coastline data

The campaign map and mission coastlines come from [Natural Earth](https://www.naturalearthdata.com)
(public domain). `tools/make_geo.py` turns the Natural Earth land GeoJSON into the files in
`data/geo/`.

## License

GPL-3.0. See [LICENSE](LICENSE).
