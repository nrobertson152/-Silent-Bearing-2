extends RefCounted
## Aircraft types. speed in m/s (cruise), alt in m, launch = missile release range.

const AIRCRAFT := {
	"tu22m": {"name": "Tu-22M3 Backfire", "side": "su", "role": "bomber", "speed": 260.0, "alt": 11000.0, "weapon": "kh22", "n": 2, "launch": 260000.0, "turn": 2.5, "span": 34.3, "len": 42.5, "model": "backfire"},
	"tu95": {"name": "Tu-95RTs Bear D", "side": "su", "role": "recon", "speed": 210.0, "alt": 9000.0, "weapon": "", "n": 0, "launch": 0.0, "turn": 2.0, "span": 50.0, "len": 46.0, "model": "bear"},
	"tu142": {"name": "Tu-142 Bear F", "side": "su", "role": "patrol", "speed": 180.0, "alt": 400.0, "weapon": "at2", "n": 4, "launch": 1500.0, "turn": 2.5, "span": 50.0, "len": 49.5, "model": "bear"},
	"mig31": {"name": "MiG-31 Foxhound", "side": "su", "role": "fighter", "speed": 480.0, "alt": 11000.0, "aam": 4, "turn": 5.0, "span": 13.5, "len": 22.7, "model": "fighter"},
	"su24": {"name": "Su-24M Fencer", "side": "su", "role": "bomber", "speed": 250.0, "alt": 150.0, "weapon": "kh22", "n": 1, "launch": 90000.0, "turn": 4.0, "span": 17.6, "len": 22.7, "model": "fighter"},
	"ka27": {"name": "Ka-27 Helix", "side": "su", "role": "helo", "speed": 65.0, "alt": 120.0, "weapon": "at2", "n": 1, "launch": 1200.0, "turn": 10.0, "span": 15.9, "len": 11.3, "model": "helix"},
	"a6": {"name": "A-6E Intruder", "side": "us", "role": "bomber", "speed": 230.0, "alt": 120.0, "weapon": "harpoon_air", "n": 2, "launch": 90000.0, "turn": 4.0, "span": 16.2, "len": 16.6, "model": "fighter"},
	"b52": {"name": "B-52G Stratofortress", "side": "us", "role": "bomber", "speed": 240.0, "alt": 9000.0, "weapon": "harpoon_air", "n": 6, "launch": 110000.0, "turn": 2.0, "span": 56.4, "len": 48.5, "model": "bomber"},
	"p3": {"name": "P-3C Orion", "side": "us", "role": "patrol", "speed": 170.0, "alt": 300.0, "weapon": "mk46", "n": 4, "launch": 1500.0, "turn": 3.0, "span": 30.4, "len": 35.6, "model": "orion"},
	"f15": {"name": "F-15C Eagle", "side": "us", "role": "fighter", "speed": 450.0, "alt": 9000.0, "aam": 4, "turn": 5.0, "span": 13.0, "len": 19.4, "model": "fighter"},
	"f14": {"name": "F-14A Tomcat", "side": "us", "role": "fighter", "speed": 450.0, "alt": 9000.0, "aam": 6, "turn": 5.0, "span": 19.5, "len": 19.1, "model": "fighter"},
	"sh60": {"name": "SH-60B Seahawk", "side": "us", "role": "helo", "speed": 70.0, "alt": 120.0, "weapon": "mk46", "n": 2, "launch": 1200.0, "turn": 10.0, "span": 16.4, "len": 19.8, "model": "seahawk"},
}


static func spec(id: String) -> Dictionary:
	return AIRCRAFT.get(id, {})
