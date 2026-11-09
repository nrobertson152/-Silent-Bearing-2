extends RefCounted
## Munitions and weapon mounts. Figures are rounded from published data
## (NavWeaps, Jane's, manufacturer sheets) and occasionally adjusted for play.

## kind: shell, missile, torpedo, rocket, cannon.
## Shells: cal (mm), mass (kg), v0 (m/s), range (m, max at best elevation),
##   pen (mm of armour at the muzzle, for AP/SAP), he (kg of explosive).
## Missiles: role (ship, air, sub, land), speed (m/s), range (m), alt (cruise m),
##   term (terminal: skim, popup, dive, weave), he (kg), pen (mm), seeker (m),
##   agile (0..1 how hard to intercept), nuke (kilotons, optional).
## Torpedoes: speed (m/s), range (m), he, guidance (active, wake, wire).
const MUNITIONS := {
	# --- US guns
	"76_he": {"name": "76 mm HE", "kind": "shell", "cal": 76, "mass": 6.3, "v0": 925, "range": 16300, "pen": 12, "he": 0.75},
	"127_he": {"name": "5-inch/54 HE-CVT", "kind": "shell", "cal": 127, "mass": 31.8, "v0": 808, "range": 23100, "pen": 25, "he": 3.6},
	"127_38": {"name": "5-inch/38 AAC", "kind": "shell", "cal": 127, "mass": 25.0, "v0": 792, "range": 16600, "pen": 22, "he": 3.3},
	"203_ap": {"name": "8-inch Mk 21 AP", "kind": "shell", "cal": 203, "mass": 152.0, "v0": 762, "range": 27480, "pen": 330, "he": 2.3, "ap": true},
	"203_he": {"name": "8-inch Mk 25 HC", "kind": "shell", "cal": 203, "mass": 118.0, "v0": 823, "range": 28000, "pen": 45, "he": 9.7},
	"406_ap": {"name": "16-inch Mk 8 APC", "kind": "shell", "cal": 406, "mass": 1225.0, "v0": 762, "range": 38720, "pen": 829, "he": 18.5, "ap": true},
	"406_he": {"name": "16-inch Mk 13 HC", "kind": "shell", "cal": 406, "mass": 862.0, "v0": 820, "range": 38060, "pen": 110, "he": 69.8},
	"w23": {"name": "16-inch Mk 23 'Katie' (W23 nuclear)", "kind": "shell", "cal": 406, "mass": 862.0, "v0": 820, "range": 38060, "pen": 110, "he": 0, "nuke": 15.0},
	# --- Soviet guns
	"76_ak": {"name": "76.2 mm OF-62", "kind": "shell", "cal": 76, "mass": 5.9, "v0": 980, "range": 15700, "pen": 12, "he": 0.4},
	"100_he": {"name": "100 mm OF-58", "kind": "shell", "cal": 100, "mass": 15.6, "v0": 880, "range": 21500, "pen": 18, "he": 1.4},
	"100_sm5": {"name": "100 mm F-56", "kind": "shell", "cal": 100, "mass": 15.6, "v0": 900, "range": 24000, "pen": 18, "he": 1.5},
	"130_he": {"name": "130 mm F-44", "kind": "shell", "cal": 130, "mass": 33.4, "v0": 850, "range": 23000, "pen": 26, "he": 3.6},
	"152_ap": {"name": "152 mm PB-35 AP", "kind": "shell", "cal": 152, "mass": 55.0, "v0": 950, "range": 30200, "pen": 220, "he": 1.5, "ap": true},
	"152_he": {"name": "152 mm OF-35 HE", "kind": "shell", "cal": 152, "mass": 55.0, "v0": 950, "range": 30200, "pen": 30, "he": 6.0},
	"406_su_ap": {"name": "406 mm B-37 AP", "kind": "shell", "cal": 406, "mass": 1108.0, "v0": 830, "range": 45600, "pen": 870, "he": 16.0, "ap": true},
	"406_su_he": {"name": "406 mm B-37 HE", "kind": "shell", "cal": 406, "mass": 1108.0, "v0": 830, "range": 45600, "pen": 120, "he": 60.0},
	# --- anti-ship and strike missiles
	"harpoon": {"name": "RGM-84 Harpoon", "kind": "missile", "role": "ship", "speed": 265, "range": 124000, "alt": 6, "term": "popup", "he": 221, "pen": 60, "seeker": 18000, "agile": 0.25, "len": 4.6, "dia": 0.34},
	"tasm": {"name": "BGM-109B Tomahawk (anti-ship)", "kind": "missile", "role": "ship", "speed": 245, "range": 450000, "alt": 8, "term": "skim", "he": 454, "pen": 90, "seeker": 30000, "agile": 0.2, "len": 6.2, "dia": 0.52},
	"tlam": {"name": "BGM-109C Tomahawk (land attack)", "kind": "missile", "role": "land", "speed": 245, "range": 1250000, "alt": 30, "term": "dive", "he": 454, "pen": 90, "seeker": 0, "agile": 0.2, "len": 6.2, "dia": 0.52},
	"tlam_n": {"name": "BGM-109A TLAM-N (W80 nuclear)", "kind": "missile", "role": "ship", "speed": 245, "range": 2500000, "alt": 30, "term": "skim", "he": 0, "pen": 0, "seeker": 40000, "agile": 0.2, "len": 6.2, "dia": 0.52, "nuke": 150.0},
	"moskit": {"name": "P-270 Moskit (SS-N-22)", "kind": "missile", "role": "ship", "speed": 800, "range": 120000, "alt": 15, "term": "weave", "he": 320, "pen": 150, "seeker": 20000, "agile": 0.75, "len": 9.7, "dia": 0.76},
	"granit": {"name": "P-700 Granit (SS-N-19)", "kind": "missile", "role": "ship", "speed": 700, "range": 550000, "alt": 20, "term": "skim", "he": 750, "pen": 400, "seeker": 40000, "agile": 0.55, "len": 10.0, "dia": 0.85},
	"granit_n": {"name": "P-700 Granit (500 kt nuclear)", "kind": "missile", "role": "ship", "speed": 700, "range": 550000, "alt": 20, "term": "skim", "he": 0, "pen": 0, "seeker": 40000, "agile": 0.55, "len": 10.0, "dia": 0.85, "nuke": 500.0},
	"metel": {"name": "URPK-4 Metel (SS-N-14)", "kind": "missile", "role": "sub", "speed": 280, "range": 50000, "alt": 400, "term": "drop", "he": 0, "pen": 0, "seeker": 0, "agile": 0.1, "len": 7.2, "dia": 0.57, "payload": "at2"},
	"kh22": {"name": "Kh-22 (AS-4 Kitchen)", "kind": "missile", "role": "ship", "speed": 1000, "range": 400000, "alt": 12000, "term": "dive", "he": 960, "pen": 300, "seeker": 60000, "agile": 0.5, "len": 11.7, "dia": 0.92},
	"harpoon_air": {"name": "AGM-84 Harpoon", "kind": "missile", "role": "ship", "speed": 265, "range": 120000, "alt": 6, "term": "popup", "he": 221, "pen": 60, "seeker": 18000, "agile": 0.25, "len": 3.8, "dia": 0.34},
	"asroc": {"name": "RUR-5 ASROC", "kind": "missile", "role": "sub", "speed": 300, "range": 9000, "alt": 800, "term": "drop", "he": 0, "pen": 0, "seeker": 0, "agile": 0.0, "len": 4.5, "dia": 0.33, "payload": "mk46"},
	# --- surface-to-air
	"sm1": {"name": "RIM-66 SM-1MR", "kind": "missile", "role": "air", "speed": 650, "range": 46000, "he": 62, "agile": 0.6, "pk": 0.7, "len": 4.5, "dia": 0.34},
	"sm2": {"name": "RIM-66 SM-2MR", "kind": "missile", "role": "air", "speed": 1000, "range": 120000, "he": 62, "agile": 0.7, "pk": 0.75, "len": 4.7, "dia": 0.34},
	"nssm": {"name": "RIM-7 Sea Sparrow", "kind": "missile", "role": "air", "speed": 850, "range": 19000, "he": 39, "agile": 0.7, "pk": 0.65, "len": 3.7, "dia": 0.2},
	"osa": {"name": "9M33 Osa-M (SA-N-4)", "kind": "missile", "role": "air", "speed": 800, "range": 15000, "he": 15, "agile": 0.6, "pk": 0.55, "len": 3.2, "dia": 0.21},
	"uragan": {"name": "9M38 Uragan (SA-N-7)", "kind": "missile", "role": "air", "speed": 1000, "range": 25000, "he": 70, "agile": 0.7, "pk": 0.7, "len": 5.5, "dia": 0.4},
	"s300f": {"name": "5V55RM Fort (SA-N-6)", "kind": "missile", "role": "air", "speed": 1700, "range": 90000, "he": 133, "agile": 0.8, "pk": 0.8, "len": 7.0, "dia": 0.5},
	# --- torpedoes and ASW rockets
	"mk46": {"name": "Mk 46 Mod 5", "kind": "torpedo", "speed": 23.0, "range": 11000, "he": 44, "guidance": "active", "seeker": 1500, "len": 2.6, "dia": 0.32},
	"at2": {"name": "AT-2U", "kind": "torpedo", "speed": 20.0, "range": 8000, "he": 100, "guidance": "active", "seeker": 1500, "len": 3.5, "dia": 0.53},
	"mk48": {"name": "Mk 48 ADCAP", "kind": "torpedo", "speed": 28.3, "range": 38000, "he": 295, "guidance": "wire", "seeker": 2500, "len": 5.8, "dia": 0.53},
	"t53": {"name": "53-65K (wake homing)", "kind": "torpedo", "speed": 23.0, "range": 19000, "he": 307, "guidance": "wake", "seeker": 2000, "len": 7.2, "dia": 0.53},
	"t65": {"name": "65-76A 'Kit' (650 mm)", "kind": "torpedo", "speed": 25.7, "range": 50000, "he": 450, "guidance": "wake", "seeker": 2500, "len": 11.0, "dia": 0.65},
	"set65": {"name": "SET-65 (anti-submarine)", "kind": "torpedo", "speed": 20.5, "range": 15000, "he": 205, "guidance": "wire", "seeker": 1800, "len": 7.8, "dia": 0.53},
	"rgb60": {"name": "RGB-60 depth rocket", "kind": "rocket", "speed": 240, "range": 5800, "he": 23, "sink": 11.5},
	"rgb10": {"name": "RGB-10 depth rocket", "kind": "rocket", "speed": 160, "range": 1000, "he": 100, "sink": 11.5},
}

## Mount types. kind: gun, ciws, launcher, vls, tubes, rocket.
## Guns: barrels, rof (rounds/min per barrel), train/elev (deg/s), emin/emax (deg),
##   disp (dispersion, fraction of range), ammo (list of munitions), crew.
## Launchers: cycle (s between launches), salvo (missiles per launch event).
## CIWS: range, rof, pk (kill chance per second vs a missile in its envelope).
const MOUNTS := {
	"mk45": {"name": "5-inch/54 Mk 45", "kind": "gun", "model": "mk45", "barrels": 1, "rof": 20, "train": 30, "elev": 20, "emin": -15, "emax": 65, "disp": 0.0025, "ammo": ["127_he"], "hp": 40},
	"mk75": {"name": "76 mm/62 Mk 75", "kind": "gun", "model": "mk75", "barrels": 1, "rof": 80, "train": 60, "elev": 35, "emin": -15, "emax": 85, "disp": 0.003, "ammo": ["76_he"], "hp": 25},
	"mk38": {"name": "5-inch/38 twin Mk 38", "kind": "gun", "model": "mk38", "barrels": 2, "rof": 15, "train": 25, "elev": 15, "emin": -15, "emax": 85, "disp": 0.004, "ammo": ["127_38"], "hp": 50},
	"mk16": {"name": "8-inch/55 RF triple Mk 16", "kind": "gun", "model": "mk16", "barrels": 3, "rof": 9, "train": 5, "elev": 10, "emin": -5, "emax": 41, "disp": 0.004, "ammo": ["203_ap", "203_he"], "hp": 260, "armor": 203},
	"mk7": {"name": "16-inch/50 triple Mk 7", "kind": "gun", "model": "mk7", "barrels": 3, "rof": 2, "train": 4, "elev": 12, "emin": -2, "emax": 45, "disp": 0.0045, "ammo": ["406_ap", "406_he", "w23"], "hp": 900, "armor": 432},
	"ak726": {"name": "76.2 mm twin AK-726", "kind": "gun", "model": "ak726", "barrels": 2, "rof": 45, "train": 30, "elev": 30, "emin": -10, "emax": 85, "disp": 0.004, "ammo": ["76_ak"], "hp": 30},
	"ak100": {"name": "100 mm AK-100", "kind": "gun", "model": "ak100", "barrels": 1, "rof": 60, "train": 35, "elev": 30, "emin": -15, "emax": 80, "disp": 0.003, "ammo": ["100_he"], "hp": 35},
	"ak130": {"name": "130 mm twin AK-130", "kind": "gun", "model": "ak130", "barrels": 2, "rof": 40, "train": 25, "elev": 20, "emin": -12, "emax": 80, "disp": 0.003, "ammo": ["130_he"], "hp": 60},
	"b38": {"name": "152 mm/57 triple MK-5bis", "kind": "gun", "model": "b38", "barrels": 3, "rof": 6, "train": 5, "elev": 13, "emin": -5, "emax": 45, "disp": 0.0045, "ammo": ["152_ap", "152_he"], "hp": 200, "armor": 175},
	"sm5": {"name": "100 mm twin SM-5-1", "kind": "gun", "model": "sm5", "barrels": 2, "rof": 15, "train": 20, "elev": 20, "emin": -8, "emax": 85, "disp": 0.004, "ammo": ["100_sm5"], "hp": 45},
	"mk4_152": {"name": "152 mm twin MK-4", "kind": "gun", "model": "mk4_152", "barrels": 2, "rof": 6, "train": 6, "elev": 12, "emin": -5, "emax": 45, "disp": 0.0045, "ammo": ["152_ap", "152_he"], "hp": 160, "armor": 100},
	"b37": {"name": "406 mm/50 triple MK-1", "kind": "gun", "model": "b37", "barrels": 3, "rof": 2, "train": 4.5, "elev": 6, "emin": -2, "emax": 45, "disp": 0.0045, "ammo": ["406_su_ap", "406_su_he"], "hp": 950, "armor": 495},
	"phalanx": {"name": "Phalanx CIWS", "kind": "ciws", "model": "phalanx", "range": 1800, "rof": 4500, "pk": 0.55, "rounds": 1550, "train": 115, "elev": 90, "emin": -20, "emax": 80, "hp": 15},
	"ak630": {"name": "AK-630M", "kind": "ciws", "model": "ak630", "range": 2500, "rof": 5000, "pk": 0.5, "rounds": 2000, "train": 70, "elev": 50, "emin": -12, "emax": 88, "hp": 18},
	"mk13": {"name": "Mk 13 launcher", "kind": "launcher", "model": "mk13", "cycle": 8.0, "salvo": 1, "hp": 40, "train": 90, "elev": 45},
	"mk41": {"name": "Mk 41 VLS", "kind": "vls", "model": "mk41", "cycle": 1.0, "salvo": 1, "hp": 80},
	"mk143": {"name": "Mk 143 armored box launcher", "kind": "launcher", "model": "mk143", "cycle": 6.0, "salvo": 1, "hp": 60, "fixed": true},
	"mk141": {"name": "Mk 141 Harpoon quad", "kind": "launcher", "model": "mk141", "cycle": 3.0, "salvo": 1, "hp": 20, "fixed": true},
	"mk29": {"name": "Mk 29 Sea Sparrow", "kind": "launcher", "model": "mk29", "cycle": 2.5, "salvo": 1, "hp": 25, "train": 60, "elev": 45},
	"kt106": {"name": "KT-106 (Metel)", "kind": "launcher", "model": "kt106", "cycle": 5.0, "salvo": 1, "hp": 35, "fixed": true},
	"zif122": {"name": "ZIF-122 Osa-M", "kind": "launcher", "model": "zif122", "cycle": 8.0, "salvo": 2, "hp": 30, "train": 60, "elev": 45},
	"kt190": {"name": "KT-190 (Moskit)", "kind": "launcher", "model": "kt190", "cycle": 5.0, "salvo": 1, "hp": 35, "fixed": true},
	"3s90": {"name": "3S90 Uragan", "kind": "launcher", "model": "3s90", "cycle": 12.0, "salvo": 1, "hp": 30, "train": 60, "elev": 45},
	"b203": {"name": "B-203A Fort VLS", "kind": "vls", "model": "b203", "cycle": 3.0, "salvo": 1, "hp": 40},
	"sm233": {"name": "SM-233 Granit VLS", "kind": "vls", "model": "sm233", "cycle": 3.0, "salvo": 1, "hp": 60},
	"rbu6000": {"name": "RBU-6000", "kind": "rocket", "model": "rbu6000", "cycle": 180.0, "salvo": 12, "hp": 20, "train": 30, "elev": 30, "ammo": ["rgb60"]},
	"rbu1000": {"name": "RBU-1000", "kind": "rocket", "model": "rbu1000", "cycle": 120.0, "salvo": 6, "hp": 20, "train": 30, "elev": 30, "ammo": ["rgb10"]},
	"mk32": {"name": "Mk 32 triple tubes", "kind": "tubes", "model": "mk32", "cycle": 20.0, "salvo": 1, "hp": 15, "train": 20},
	"pta53": {"name": "PTA-53 quad tubes", "kind": "tubes", "model": "pta53", "cycle": 15.0, "salvo": 1, "hp": 20, "train": 15},
	"dta53": {"name": "DTA-53 twin tubes", "kind": "tubes", "model": "dta53", "cycle": 15.0, "salvo": 1, "hp": 20, "train": 15},
	"sub_tubes": {"name": "Torpedo tubes", "kind": "tubes", "model": "", "cycle": 12.0, "salvo": 1, "hp": 50},
}


static func mun(id: String) -> Dictionary:
	return MUNITIONS.get(id, {})


static func mount(id: String) -> Dictionary:
	return MOUNTS.get(id, {})
