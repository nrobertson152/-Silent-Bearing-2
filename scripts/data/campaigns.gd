extends RefCounted
## The two campaigns: story, missions, situation reports and the strategic map.
## Mission positions are [km east, km north] of the mission origin (lat/lon).
## "front" sets who holds each map region during the mission; "sitrep" is the
## news from the Army, the Air Force and the fleet after the mission is won.

const MAP_CENTER := Vector2(62.0, -12.0)

## Places on the map: [name, lon, lat, optional label offset in pixels].
const LABELS := [
	["Norfolk", -76.3, 36.9, [-60, 4]], ["New York", -74.0, 40.7, [-70, 4]], ["Boston", -71.06, 42.36], ["Halifax", -63.57, 44.65],
	["Bermuda", -64.75, 32.3, [12, 20]], ["Reykjavik", -21.9, 64.15, [8, -9]], ["Tórshavn", -6.8, 62.0], ["Bergen", 5.3, 60.4],
	["Bodø", 14.4, 67.3, [-42, 4]], ["Tromsø", 18.95, 69.65, [-58, -2]], ["Kirkenes", 30.05, 69.73, [-66, -6]],
	["Murmansk", 33.1, 68.97, [6, 13]], ["Arkhangelsk", 40.5, 64.55], ["Leningrad", 30.3, 59.94], ["London", -0.13, 51.5, [-52, 4]],
	["Berlin", 13.4, 52.5], ["Moscow", 37.6, 55.75], ["Thule", -68.7, 76.5], ["Sondrestrom", -50.7, 67.0],
	["Goose Bay", -60.4, 53.3], ["Loring AFB", -67.9, 46.9, [-80, -4]], ["Scapa Flow", -3.1, 58.9, [-76, 4]],
]

## Contested regions drawn over the map, as [lon, lat] outlines.
const REGIONS := {
	"iceland": [[-24.6, 65.6], [-23.8, 66.3], [-22.4, 66.5], [-18.0, 66.3], [-14.5, 66.4], [-13.4, 65.2], [-14.4, 64.4],
		[-17.0, 63.7], [-20.0, 63.4], [-22.8, 63.8], [-22.6, 64.6], [-24.2, 65.0]],
	"norway_n": [[11.0, 65.2], [13.6, 64.6], [14.8, 66.0], [16.2, 67.4], [18.4, 68.5], [21.0, 69.1], [25.0, 68.6],
		[28.3, 69.0], [31.0, 69.7], [31.2, 70.3], [28.0, 71.1], [25.5, 71.2], [20.0, 70.4], [16.0, 69.4], [12.6, 67.9]],
	"pechenga": [[28.6, 69.0], [31.1, 69.7], [32.4, 69.8], [33.4, 69.4], [33.3, 68.9], [31.5, 68.5], [29.0, 68.5]],
	"faroes": [[-7.8, 61.4], [-6.0, 61.4], [-6.0, 62.5], [-7.8, 62.5]],
	"bermuda": [[-65.1, 32.1], [-64.4, 32.1], [-64.4, 32.6], [-65.1, 32.6]],
}

## Land front lines in Europe.
const FRONTS := {
	"rhine": [[4.3, 52.0], [6.1, 51.8], [7.0, 50.9], [7.6, 50.1], [8.3, 49.2], [7.6, 47.6]],
	"igb": [[10.9, 54.1], [10.8, 53.2], [11.4, 52.6], [10.6, 51.7], [10.1, 51.0], [11.7, 50.5], [12.3, 50.2]],
	"elbe": [[11.6, 54.0], [12.2, 53.2], [12.9, 52.5], [12.3, 51.6], [13.1, 51.0], [14.4, 50.8]],
}

const CAMPAIGNS := {
	"us": {
		"title": "LONG WAY BACK",
		"subtitle": "United States Navy, 1988",
		"intro": [
			"August 1988. A border incident during the Warsaw Pact's autumn exercises in East Germany spiraled out of control in seventy-two hours. On 4 August, Soviet tank armies crossed the inner-German border.",
			"Three weeks later NATO's northern flank is gone. Norway has fallen. Soviet airborne troops took Iceland in a single night, and Backfire bombers now fly from Keflavik. Two American carrier battle groups were lost in the Norwegian Sea trying to stop the Northern Fleet's breakout.",
			"In Germany the Army is holding at the Rhine, but nothing is getting across the Atlantic to reinforce it. What is left of the Atlantic Fleet has been pushed back to home waters, and Soviet submarines are already off the Virginia Capes.",
			"You have a frigate, two hundred sailors, and orders to sail.",
		],
		"missions": [
			{
				"id": "us1", "title": "Capes Patrol", "ship": "ffg7", "side": "us", "date": [1988, 9, 21], "time": 6.2,
				"lat": 36.95, "lon": -75.6, "geo": "us1", "land_h": 15.0, "location": "Off Cape Henry, Virginia",
				"weather": {"sea": 3.0, "wind": 40.0, "vis": 18.0, "clouds": 0.6},
				"briefing": "Convoy C-2, three ammunition ships bound for the first reinforcement convoy to Europe, sails from Hampton Roads at dawn. A Soviet nuclear attack submarine was detected yesterday off Cape Henry, and Soviet Naval Aviation has been staging Backfire bombers through Cuba.\n\nEscort the convoy north until the destroyers from Norfolk relieve you in about 25 minutes. Your SH-60B Seahawk is airborne on anti-submarine screen.",
				"intel": "One Akula-class nuclear attack submarine, suspected. Four Tu-22M3 Backfires with Kh-22 missiles possible after 0630.",
				"support": "Air Force F-15C Eagles from Langley AFB on strip alert. Your SH-60B LAMPS III helicopter.",
				"tip": "Air defence is automatic: the Mk 13 fires SM-1s and the Phalanx guards the stern. The Seahawk attacks submarines it finds near the convoy; once sonar holds the boat, select group 5 and fire Mk 46s with Space.",
				"player": {"pos": [0, 0], "hdg": 50.0, "speed": 15.0},
				"units": [
					{"cls": "merchant", "side": "us", "pos": [-4, -3], "hdg": 45.0, "speed": 12.0, "n": 3, "cols": 1, "spacing": 1.0, "tag": "convoy", "ai": "convoy", "waypoints": [[60, 60]], "names": ["SS Cape Ann", "SS Cape Alexander", "SS Pride of Texas"]},
					{"cls": "akula", "side": "su", "pos": [20, 26], "hdg": 225.0, "speed": 5.0, "depth": 90.0, "tag": "sub", "ai": "patrol", "waypoints": [[8, 10], [25, 30]], "name": "K-480"},
				],
				"air": [
					{"type": "sh60", "side": "us", "pos": [-1, 1], "hdg": 45.0, "orbit": [4, 6], "callsign": "Proud Warrior 51"},
					{"type": "f15", "side": "us", "at": 400.0, "pos": [-80, 20], "hdg": 160.0, "n": 2, "orbit": [-30, -90], "callsign": "Eagle 21", "radio": ["Eagle 21", "Eagle two-one, flight of two out of Langley. We'll take the Backfires we can reach."]},
					{"type": "tu22m", "side": "su", "at": 420.0, "pos": [-40, -300], "hdg": 15.0, "n": 4, "tag": "raid", "radio": ["Darkstar", "Bandits, bandits. Four Backfires bearing one-niner-five, one-six-zero miles, heading north for the convoy."]},
				],
				"objectives": [
					{"id": "o1", "text": "Escort the ammunition convoy until relieved", "type": "protect", "tag": "convoy", "min": 2, "until": 1500.0},
					{"id": "o2", "text": "Find and sink the Soviet submarine", "type": "destroy", "tag": "sub", "optional": true},
				],
				"events": [
					{"at": 4.0, "radio": ["Commodore", "Roberts, Commodore. Charlie-Two is formed up, steaming zero-four-five at twelve knots. Keep that submarine off them until Norfolk relieves you."]},
					{"at": 95.0, "radio": ["Sonar", "Conn, sonar. Faint broadband noise, bearing roughly zero-three-five. Could be a submarine."]},
					{"at": 1490.0, "radio": ["Commodore", "Roberts, the destroyers have the convoy. You are relieved. Well done."]},
				],
				"front": {"iceland": "su", "norway_n": "su", "faroes": "su", "pechenga": "su", "bermuda": "us", "europe": "rhine"},
				"sitrep": {
					"army": "The 82nd Airborne and the 1st Cavalry Division finish loading at Norfolk and Wilmington. Every shell your convoy delivered is going with them to the Rhine.",
					"air": "Langley's Eagles claim two Backfires over the Gulf Stream. B-52s strike the Soviet staging fields in Cuba, and the raids from the south stop.",
					"navy": "With the Capes clear, the first reinforcement convoy can form. But a Soviet amphibious group is heading for Bermuda, the last NATO anchor in the western Atlantic.",
				},
			},
			{
				"id": "us2", "title": "Hunter at Bermuda", "ship": "ssn688", "side": "us", "date": [1988, 9, 30], "time": 21.5,
				"lat": 32.0, "lon": -64.75, "geo": "us2", "land_h": 50.0, "location": "South of Bermuda",
				"weather": {"sea": 3.0, "wind": 200.0, "vis": 14.0, "clouds": 0.5},
				"briefing": "A Soviet amphibious group, two troop transports with a Sovremenny-class destroyer and a Krivak-class frigate, is making fourteen knots for Bermuda. If they land, Backfires will fly from Kindley Field within the week and the western Atlantic will be closed.\n\nYou are the only unit in range. Get inside the screen and sink both transports before they reach the island.",
				"intel": "Sovremenny-class destroyer (no towed array, weak sonar), Krivak-class frigate (good hull and variable-depth sonar), Ka-27 Helix anti-submarine helicopter. Two transports with a naval infantry regiment embarked.",
				"support": "Air Force B-52Gs from Loring AFB with Harpoons will strike the escorts at about 2150.",
				"tip": "You start in the control room: the sonar waterfall shows what you can hear, so slow down to hear more. Stay deep and slow until you are inside 15 km. T picks a contact, Space fires; Mk 48 ADCAPs are wire-guided and home on their own once close. P raises the periscope at 18 m. The Krivak's sonar is dangerous: go deep (PgDn), drop a decoy (N) if a torpedo comes for you.",
				"player": {"pos": [3, 30], "hdg": 10.0, "speed": 6.0, "depth": 90.0},
				"units": [
					{"cls": "merchant", "side": "su", "pos": [12, 64], "hdg": 190.0, "speed": 14.0, "n": 2, "cols": 2, "spacing": 1.4, "tag": "transports", "ai": "convoy", "waypoints": [[5, 38]], "names": ["Aleksandr Nikolaev", "Mitrofan Moskalenko"]},
					{"cls": "sovremenny", "side": "su", "pos": [12, 60], "hdg": 190.0, "speed": 14.0, "tag": "escorts", "ai": "escort", "lead": "transports", "offset": [2.5, 3.0], "name": "Bezuprechny"},
					{"cls": "krivak", "side": "su", "pos": [10, 60], "hdg": 190.0, "speed": 14.0, "tag": "escorts", "ai": "escort", "lead": "transports", "offset": [-2.0, 2.0], "name": "Druzhny"},
				],
				"air": [
					{"type": "ka27", "side": "su", "pos": [10, 58], "hdg": 190.0, "orbit": [8, 50]},
					{"type": "b52", "side": "us", "at": 1200.0, "pos": [-80, 300], "hdg": 160.0, "n": 3, "callsign": "Jaws 31", "target_tag": "escorts", "radio": ["Jaws 31", "Jaws three-one, three BUFFs out of Loring with Harpoons, inbound on the Soviet escorts."]},
				],
				"objectives": [
					{"id": "o1", "text": "Sink both troop transports before they reach Bermuda", "type": "deny", "tag": "transports", "pos": [5, 37], "r": 6.0},
					{"id": "o2", "text": "Sink the escorts", "type": "destroy", "tag": "escorts", "optional": true},
				],
				"events": [
					{"at": 4.0, "radio": ["SUBLANT", "Dallas, SUBLANT. Soviet amphibious group bearing zero-one-five, thirty-four kilometres, speed fourteen, heading for Bermuda. Sink the transports. Weapons free."]},
					{"at": 60.0, "radio": ["Sonar", "Conn, sonar. Two sets of screws, merchant type, bearing zero-two-five. Warship turbines too."]},
				],
				"front": {"iceland": "su", "norway_n": "su", "faroes": "su", "pechenga": "su", "bermuda": "contested", "europe": "rhine"},
				"sitrep": {
					"army": "The Marine detachment and the Bermuda Regiment hold the island. A Marine battalion flies in to reinforce them.",
					"air": "B-52s from Loring sink the Krivak Druzhny with Harpoons. Kindley Field reopens for Navy P-3 Orions.",
					"navy": "The sea lanes to Europe are open again. But a Soviet surface action group has slipped through to raid the convoy route off New England.",
				},
			},
			{
				"id": "us3", "title": "Georges Bank", "ship": "dd963", "side": "us", "date": [1988, 10, 9], "time": 14.0,
				"lat": 41.5, "lon": -67.5, "location": "Georges Bank, off Cape Cod",
				"weather": {"sea": 4.0, "wind": 280.0, "vis": 22.0, "clouds": 0.55},
				"briefing": "Three fast sealift ships, USNS Algol, Capella and Denebola, are carrying the 24th Infantry Division's armour from Boston to Europe at eighteen knots. A Soviet surface action group of two Sovremenny-class destroyers and a Krivak is closing from the north-east to intercept.\n\nDestroy the surface action group. Keep at least two of the sealift ships afloat.",
				"intel": "Two Sovremenny-class destroyers (8 SS-N-22 Sunburn missiles each, Mach 2.5, very hard to intercept) and a Krivak frigate. A Backfire raid is expected later in the afternoon.",
				"support": "USS Nicholas (FFG-47) is escorting the convoy. Massachusetts Air National Guard F-15s from Otis will cover against the Backfires.",
				"tip": "Your Harpoons and Tomahawk anti-ship missiles outrange their guns. Designate (T), select group 3 or 6, and launch salvos with Space. Sunburns arrive fast and low: your Sea Sparrow and Phalanx engage automatically.",
				"player": {"pos": [0, 0], "hdg": 70.0, "speed": 20.0},
				"units": [
					{"cls": "merchant", "side": "us", "pos": [-8, -6], "hdg": 60.0, "speed": 18.0, "n": 3, "cols": 1, "spacing": 1.4, "tag": "convoy", "ai": "convoy", "waypoints": [[90, 50]], "names": ["USNS Algol", "USNS Capella", "USNS Denebola"]},
					{"cls": "ffg7", "side": "us", "pos": [-6, -4], "hdg": 60.0, "speed": 18.0, "tag": "friends", "ai": "escort", "lead": "convoy", "offset": [2.5, 1.0], "name": "USS Nicholas"},
					{"cls": "sovremenny", "side": "su", "pos": [72, 34], "hdg": 245.0, "speed": 24.0, "n": 2, "cols": 2, "spacing": 2.0, "tag": "sag", "ai": "patrol", "waypoints": [[10, 5]], "names": ["Osmotritelny", "Bezboyaznenny"]},
					{"cls": "krivak", "side": "su", "pos": [76, 30], "hdg": 245.0, "speed": 24.0, "tag": "sag", "ai": "patrol", "waypoints": [[14, 3]], "name": "Ladny"},
				],
				"air": [
					{"type": "f15", "side": "us", "at": 590.0, "pos": [-60, 60], "hdg": 60.0, "n": 2, "orbit": [40, 60], "callsign": "Saber 11", "radio": ["Saber 11", "Saber one-one, Otis Eagles on station. We have the northern sector."]},
					{"type": "tu22m", "side": "su", "at": 600.0, "pos": [200, 300], "hdg": 215.0, "n": 6, "tag": "raid", "radio": ["Crown", "Vampire raid: six Backfires bearing zero-three-five, two hundred miles, inbound."]},
				],
				"objectives": [
					{"id": "o1", "text": "Destroy the Soviet surface action group", "type": "destroy", "tag": "sag"},
					{"id": "o2", "text": "Protect the fast sealift ships (two must survive)", "type": "protect", "tag": "convoy", "min": 2, "until_flag": "o1_done"},
				],
				"events": [
					{"at": 4.0, "radio": ["Commodore", "Spruance, surface group bearing zero-six-five, eighty kilometres, closing at twenty-four knots. Engage before they reach Harpoon range of the convoy."]},
				],
				"front": {"iceland": "su", "norway_n": "su", "faroes": "su", "pechenga": "su", "bermuda": "us", "europe": "rhine"},
				"sitrep": {
					"army": "The 24th Infantry Division's armour unloads at Le Havre and moves up to the Rhine. For the first time since August, NATO has fresh tanks in the line.",
					"air": "Otis's Eagles splash four Backfires. The Air Force begins nightly B-52 raids on the Soviet air base at Keflavik.",
					"navy": "The Navy can go on the offensive at last. An invasion force is assembling to retake Iceland, and it will need an Aegis cruiser over it.",
				},
			},
			{
				"id": "us4", "title": "Iceland Convoy", "ship": "cg47", "side": "us", "date": [1988, 10, 24], "time": 10.0,
				"lat": 61.0, "lon": -22.0, "location": "South of Iceland",
				"weather": {"sea": 5.0, "wind": 220.0, "vis": 20.0, "clouds": 0.7},
				"briefing": "The invasion force for Iceland, the amphibious assault ships Guam and Inchon with the Marines, the dock landing ship Raleigh and the oiler Neosho, is three hundred kilometres south of Keflavik. Soviet Naval Aviation will throw everything it has at it.\n\nYou are the air defence commander. Keep three of the four ships afloat through the raids.",
				"intel": "Three raids of six to eight Tu-22M3 Backfires each, carrying Kh-22 missiles that dive at Mach 3. A Soviet submarine is probably shadowing the force.",
				"support": "USS Caron (DD-970) and USS Simpson (FFG-56) in the screen. An E-3 Sentry gives early warning. F-15Cs from Sondrestrom, Greenland, will hit the second raid.",
				"tip": "Aegis can guide many SM-2s at once. Leave air defence on AUTO (Q). Keep the cruiser between the raids and the convoy: missiles that leak through dive on the biggest ships.",
				"player": {"pos": [0, 0], "hdg": 15.0, "speed": 16.0},
				"awacs": true,
				"units": [
					{"cls": "tanker", "side": "us", "pos": [-3, -5], "hdg": 15.0, "speed": 14.0, "n": 4, "cols": 2, "spacing": 1.6, "tag": "convoy", "ai": "convoy", "waypoints": [[40, 160]], "names": ["USS Guam", "USS Inchon", "USS Raleigh", "USNS Neosho"]},
					{"cls": "dd963", "side": "us", "pos": [2, -2], "hdg": 15.0, "speed": 14.0, "tag": "friends", "ai": "escort", "lead": "convoy", "offset": [4.0, 1.0], "name": "USS Caron"},
					{"cls": "ffg7", "side": "us", "pos": [-6, -6], "hdg": 15.0, "speed": 14.0, "tag": "friends", "ai": "escort", "lead": "convoy", "offset": [-4.0, -2.5], "name": "USS Simpson"},
					{"cls": "akula", "side": "su", "pos": [25, 45], "hdg": 200.0, "speed": 6.0, "depth": 120.0, "tag": "sub", "ai": "patrol", "waypoints": [[5, 25], [25, 45]], "name": "K-317"},
				],
				"air": [
					{"type": "tu22m", "side": "su", "at": 240.0, "pos": [-60, 380], "hdg": 175.0, "n": 6, "tag": "raid1", "radio": ["Sentry", "Raid one: six Backfires over Iceland, heading south. Range three-eight-zero kilometres."]},
					{"type": "f15", "side": "us", "at": 820.0, "pos": [-220, 60], "hdg": 60.0, "n": 4, "orbit": [20, 140], "callsign": "Viper 41", "radio": ["Viper 41", "Viper four-one, four Eagles out of Sondrestrom. Committing on raid two."]},
					{"type": "tu22m", "side": "su", "at": 840.0, "pos": [150, 330], "hdg": 205.0, "n": 8, "tag": "raid2", "radio": ["Sentry", "Raid two: eight Backfires, bearing zero-two-five, fast."]},
					{"type": "tu22m", "side": "su", "at": 1440.0, "pos": [-160, 300], "hdg": 150.0, "n": 6, "tag": "raid3", "radio": ["Sentry", "Raid three from the north-west. Six bombers. This looks like their last throw."]},
				],
				"objectives": [
					{"id": "o1", "text": "Protect the invasion force (three of four must survive)", "type": "protect", "tag": "convoy", "min": 3, "until": 2000.0},
					{"id": "o2", "text": "Sink the shadowing submarine", "type": "destroy", "tag": "sub", "optional": true},
				],
				"events": [
					{"at": 4.0, "radio": ["Commodore", "Bunker Hill, you have the air. The Marines are counting on you."]},
					{"at": 1990.0, "radio": ["Sentry", "Last raid is turning for home. No more bandits on the scope."]},
				],
				"front": {"iceland": "su", "norway_n": "su", "faroes": "us", "pechenga": "su", "bermuda": "us", "europe": "rhine"},
				"sitrep": {
					"army": "The 2nd Marine Division is embarked off Iceland. At Goose Bay, Labrador, the 82nd Airborne waits for the word to jump on Keflavik.",
					"air": "E-3 Sentries and Greenland-based F-15s have broken Soviet Naval Aviation: more than forty Backfires lost in two weeks.",
					"navy": "Now the guns. The Navy has brought the heavy cruiser USS Salem back into service to silence the coastal batteries before the landings.",
				},
			},
			{
				"id": "us5", "title": "Reykjanes Guns", "ship": "ca139", "side": "us", "date": [1988, 11, 2], "time": 9.8,
				"lat": 63.70, "lon": -22.60, "geo": "us5", "land_h": 250.0, "location": "Reykjanes Peninsula, Iceland",
				"weather": {"sea": 3.0, "wind": 60.0, "vis": 16.0, "clouds": 0.65},
				"briefing": "The landings on Iceland begin today. Soviet coastal batteries on the south shore of the Reykjanes Peninsula cover the landing beaches, and two SA-10 missile sites around Keflavik will slaughter the 82nd Airborne's transports unless they are destroyed.\n\nSilence the batteries and the SAM sites with your 8-inch guns. Protect the landing ships waiting offshore.",
				"intel": "Three 152 mm coastal batteries (range 22 km), two SA-10 sites near Keflavik, a P-35 search radar. Two Krivak-class frigates patrol offshore. A Backfire raid is possible.",
				"support": "Forward observer team Whiskey Two on Reykjanes Point will spot your fall of shot. Eagle 52 flight provides combat air patrol.",
				"tip": "Switch the main battery to HC (high-capacity) shells with Z: they are far better against shore targets. Use the gun director sight (B) and the tactical plot (M) to find targets. The batteries shoot back: keep moving.",
				"player": {"pos": [0, -12], "hdg": 0.0, "speed": 14.0},
				"units": [
					{"cls": "merchant", "side": "us", "pos": [-8, -22], "hdg": 15.0, "speed": 8.0, "n": 2, "cols": 2, "spacing": 1.5, "tag": "landing", "ai": "convoy", "waypoints": [[-6, -8]], "names": ["USS Newport", "USS Fairfax County"]},
					{"cls": "krivak", "side": "su", "pos": [22, 6], "hdg": 250.0, "speed": 18.0, "n": 2, "cols": 2, "spacing": 2.0, "tag": "defenders", "ai": "patrol", "waypoints": [[-12, 6], [26, 8]], "names": ["Pytlivy", "Razitelny"]},
				],
				"ground": [
					{"name": "Battery Hafnir", "pos": [-3, 19], "kind": "battery", "tag": "batteries"},
					{"name": "Battery Grindavik", "pos": [16, 18.5], "kind": "battery", "tag": "batteries"},
					{"name": "Battery Krysuvik", "pos": [28, 18], "kind": "battery", "tag": "batteries"},
					{"name": "SA-10 site Keflavik North", "pos": [2, 30], "kind": "sam", "tag": "sams", "hp": 0.8},
					{"name": "SA-10 site Keflavik East", "pos": [12, 31], "kind": "sam", "tag": "sams", "hp": 0.8},
					{"name": "P-35 radar", "pos": [10, 24], "kind": "radar", "tag": "radar", "hp": 0.6, "h": 60},
				],
				"air": [
					{"type": "f15", "side": "us", "at": 880.0, "pos": [-80, -60], "hdg": 40.0, "n": 2, "orbit": [10, 40], "callsign": "Eagle 52"},
					{"type": "tu22m", "side": "su", "at": 900.0, "pos": [100, 260], "hdg": 200.0, "n": 4, "tag": "raid", "radio": ["Crown", "Four Backfires out of Akureyri heading for the landing ships."]},
				],
				"objectives": [
					{"id": "o1", "text": "Silence the coastal batteries", "type": "bombard", "tag": "batteries"},
					{"id": "o2", "text": "Destroy the SA-10 sites around Keflavik", "type": "bombard", "tag": "sams"},
					{"id": "o3", "text": "Protect the landing ships", "type": "protect", "tag": "landing", "min": 1, "until_flag": "o2_done"},
				],
				"events": [
					{"at": 25.0, "radio": ["Whiskey Two", "Salem, Whiskey Two, forward observer on Reykjanes Point. Batteries are dug in along the south shore. Ready to adjust your fire."]},
					{"when": "o1_done", "radio": ["Beachmaster", "Batteries silenced. First wave is going in."]},
					{"when": "o2_done", "radio": ["Hammer 6", "SAMs are down! The 82nd is jumping on Keflavik. Thanks, Salem."]},
				],
				"front": {"iceland": "contested", "norway_n": "su", "faroes": "us", "pechenga": "su", "bermuda": "us", "europe": "rhine"},
				"sitrep": {
					"army": "The 82nd Airborne seizes Keflavik airfield; the 2nd Marine Division takes Reykjavik after two days of street fighting. The Soviet garrison surrenders on 6 November.",
					"air": "Keflavik is an American base again. Within a week F-15s and P-3 Orions are flying from it.",
					"navy": "With Iceland back, the GIUK gap closes behind the Northern Fleet. Now the battleships go north to support the landings in Norway.",
				},
			},
			{
				"id": "us6", "title": "Lofoten", "ship": "bb61", "side": "us", "date": [1988, 11, 16], "time": 11.6,
				"lat": 68.2, "lon": 12.0, "geo": "us6", "land_h": 700.0, "location": "West of the Lofoten Islands, Norway",
				"weather": {"sea": 4.0, "wind": 230.0, "vis": 20.0, "clouds": 0.5},
				"briefing": "Norwegian Brigade North and the Army's 10th Mountain Division are going ashore at Narvik. The Soviet Kirov battle group, the nuclear battlecruiser Frunze with two Sovremenny-class destroyers and a Krivak, has sortied to break up the landings.\n\nIntercept and sink Frunze. The Iowa's armour will shrug off what her escorts carry; her twenty Granit missiles are another matter.",
				"intel": "Frunze (Kirov class): 20 SS-N-19 Shipwreck missiles (750 kg warheads), S-300 air defence, 76 mm of armour at most. Two Sovremenny destroyers and a Krivak frigate.",
				"support": "USS Yorktown (CG-48) and USS Stark (FFG-31) escort you. B-52s from Loring will strike the escorts with Harpoons. An E-3 Sentry is on station.",
				"tip": "Use 16-inch AP (Z to cycle) against Frunze: at under 25 km your shells go through anything she has. Close the range fast: her Granits are her main threat.",
				"player": {"pos": [0, 0], "hdg": 40.0, "speed": 20.0},
				"awacs": true,
				"units": [
					{"cls": "cg47", "side": "us", "pos": [3, -2], "hdg": 40.0, "speed": 20.0, "tag": "friends", "ai": "escort", "lead": "player", "offset": [3.0, -1.5], "name": "USS Yorktown"},
					{"cls": "ffg7", "side": "us", "pos": [-3, -2], "hdg": 40.0, "speed": 20.0, "tag": "friends", "ai": "escort", "lead": "player", "offset": [-3.0, -2.5], "name": "USS Stark"},
					{"cls": "kirov", "side": "su", "pos": [55, 70], "hdg": 220.0, "speed": 22.0, "tag": "kirov", "ai": "patrol", "waypoints": [[0, 0]], "name": "Frunze"},
					{"cls": "sovremenny", "side": "su", "pos": [58, 66], "hdg": 220.0, "speed": 22.0, "n": 2, "cols": 2, "spacing": 3.0, "tag": "escorts", "ai": "escort", "lead": "kirov", "offset": [3.5, 1.0], "names": ["Gremyashchy", "Bystry"]},
					{"cls": "krivak", "side": "su", "pos": [52, 74], "hdg": 220.0, "speed": 22.0, "tag": "escorts", "ai": "escort", "lead": "kirov", "offset": [0.0, -3.0], "name": "Zharky"},
				],
				"air": [
					{"type": "b52", "side": "us", "at": 470.0, "pos": [-150, -200], "hdg": 40.0, "n": 2, "callsign": "Jaws 51", "target_tag": "escorts", "radio": ["Jaws 51", "Jaws five-one, two BUFFs with Harpoons, inbound on the escorts."]},
					{"type": "tu22m", "side": "su", "at": 480.0, "pos": [180, 300], "hdg": 225.0, "n": 4, "tag": "raid", "radio": ["Sentry", "Four Backfires out of Olenya, heading for you."]},
				],
				"objectives": [
					{"id": "o1", "text": "Sink the battlecruiser Frunze", "type": "destroy", "tag": "kirov"},
					{"id": "o2", "text": "Destroy her escorts", "type": "destroy", "tag": "escorts", "optional": true},
				],
				"events": [
					{"at": 4.0, "radio": ["COMSTRIKFLT", "Missouri, the Frunze group is bearing zero-four-zero, ninety kilometres. Engage. The landings at Narvik depend on you."]},
				],
				"front": {"iceland": "us", "norway_n": "su", "faroes": "us", "pechenga": "su", "bermuda": "us", "europe": "rhine"},
				"sitrep": {
					"army": "Narvik and Bodø are retaken. Soviet forces in northern Norway fall back toward Finnmark. On the Rhine, V Corps crosses at Remagen and drives east.",
					"air": "The Air Force flies its first strikes from Bodø against the airfields on the Kola Peninsula.",
					"navy": "One task remains. The Northern Fleet's last capital ship, the battleship Sovetsky Soyuz, waits in the Barents Sea to defend the submarine bastion.",
				},
			},
			{
				"id": "us7", "title": "Barents Gate", "ship": "bb61", "side": "us", "date": [1988, 11, 29], "time": 12.0,
				"lat": 71.6, "lon": 26.0, "geo": "us7", "land_h": 300.0, "location": "Off North Cape, entering the Barents Sea",
				"weather": {"sea": 5.0, "wind": 60.0, "vis": 14.0, "clouds": 0.4, "aurora": 1.0},
				"nuclear_release": true,
				"briefing": "The polar night has fallen over North Cape. The battleship Sovetsky Soyuz, completed in secret in the 1950s and rebuilt with missiles in the 1980s, is steaming west with her escorts to meet you. Behind her lie the Kola bases and the Soviet ballistic-missile submarines.\n\nSink Sovetsky Soyuz. The President has delegated release authority for nuclear weapons against naval targets at sea. Your W23 shells and nuclear Tomahawks are armed. Whether to use them is your decision.",
				"intel": "Sovetsky Soyuz: nine 406 mm guns, 420 mm belt armour, Granit and Moskit missiles. A Sovremenny destroyer and a Krivak frigate escort her. An Akula-class submarine is in the area.",
				"support": "USS Leyte Gulf (CG-55) and USS Peterson (DD-969). The Air Force will strike the Kola airfields to keep the Backfires grounded, but expect at least one raid.",
				"tip": "Her belt is thicker than yours. At long range your shells plunge onto her deck; inside 18 km they strike her belt. To use special weapons: turn both keys on the bridge release panel, select the W23 or TLAM-N with Z, and fire.",
				"player": {"pos": [0, 0], "hdg": 70.0, "speed": 22.0},
				"awacs": true,
				"units": [
					{"cls": "cg47", "side": "us", "pos": [3, -2], "hdg": 70.0, "speed": 22.0, "tag": "friends", "ai": "escort", "lead": "player", "offset": [3.0, -2.0], "name": "USS Leyte Gulf"},
					{"cls": "dd963", "side": "us", "pos": [-3, -2], "hdg": 70.0, "speed": 22.0, "tag": "friends", "ai": "escort", "lead": "player", "offset": [-3.0, -2.0], "name": "USS Peterson"},
					{"cls": "sovsoyuz", "side": "su", "pos": [62, 28], "hdg": 250.0, "speed": 24.0, "tag": "bb", "ai": "patrol", "waypoints": [[0, 0]], "name": "Sovetsky Soyuz", "aggression": 1.3},
					{"cls": "sovremenny", "side": "su", "pos": [64, 31], "hdg": 250.0, "speed": 24.0, "tag": "escorts", "ai": "escort", "lead": "bb", "offset": [3.0, 1.0], "name": "Okrylenny"},
					{"cls": "krivak", "side": "su", "pos": [60, 25], "hdg": 250.0, "speed": 24.0, "tag": "escorts", "ai": "escort", "lead": "bb", "offset": [-3.0, -1.0], "name": "Neukrotimy"},
					{"cls": "akula", "side": "su", "pos": [26, 6], "hdg": 250.0, "speed": 6.0, "depth": 120.0, "tag": "sub", "ai": "patrol", "waypoints": [[10, 0], [26, 6]], "name": "K-263"},
				],
				"air": [
					{"type": "tu22m", "side": "su", "at": 360.0, "pos": [220, 120], "hdg": 260.0, "n": 6, "tag": "raid", "radio": ["Sentry", "Six Backfires got off the ground at Olenya. Inbound from the east."]},
				],
				"objectives": [
					{"id": "o1", "text": "Sink the battleship Sovetsky Soyuz", "type": "destroy", "tag": "bb"},
					{"id": "o2", "text": "Destroy the escort group", "type": "destroy", "tag": "escorts", "optional": true},
				],
				"events": [
					{"at": 4.0, "radio": ["CINCLANTFLT", "Missouri, release authority for special weapons against naval targets at sea is delegated to you. The decision is yours. Good hunting."]},
					{"at": 30.0, "radio": ["Sentry", "Surface group bearing zero-seven-zero, seventy kilometres. Sovetsky Soyuz is leading."]},
				],
				"front": {"iceland": "us", "norway_n": "us", "faroes": "us", "pechenga": "su", "bermuda": "us", "europe": "igb"},
			},
		],
		"endings": {
			"won": [
				"Missouri's guns ended the Northern Fleet as a fighting force in the dark off North Cape. Three weeks later, with NATO armies back on the inner-German border and the Kola airfields in ruins, Moscow accepted a ceasefire in Geneva.",
				"The war at sea had been won with steel, gunpowder and nerve. No one crossed the nuclear threshold, and in the years that followed, that would be remembered as the most important victory of all.",
				"USS Missouri came home to Norfolk on 23 December 1988. Every ship in Hampton Roads sounded her whistle.",
			],
			"won_nuclear": [
				"The flash lit the polar night for a hundred miles, and the Sovetsky Soyuz group was simply gone. The ceasefire came eleven days later.",
				"But the world had changed. For the first time since Nagasaki a nuclear weapon had been used in anger, and it had been an American one. The talks in Geneva were held under a cloud that would not lift for a generation.",
				"You were decorated. You never wore the medal.",
			],
		},
	},
	"su": {
		"title": "NORTHERN BASTION",
		"subtitle": "Soviet Navy (VMF SSSR), 1988",
		"intro": [
			"August 1988. The Warsaw Pact offensive broke against the Weser. Within a month NATO's counteroffensive, fed by American divisions flown across the Atlantic, had thrown our armies back across the inner-German border and into the German Democratic Republic.",
			"At sea it is worse. Three American carrier groups have pushed into the Norwegian Sea, and their aircraft strike the Kola Peninsula every day. American Marines and Norwegian troops have crossed the border at Pechenga. The Northern Fleet's surface ships were battered at their moorings in Severomorsk.",
			"The Motherland itself is under attack. The fleet's orders are simple: hold the bastion, then drive the Americans back into the Atlantic.",
			"You command a patrol ship at the mouth of the Kola Bay.",
		],
		"missions": [
			{
				"id": "su1", "title": "Kola Inlet", "ship": "krivak", "side": "su", "date": [1988, 9, 18], "time": 2.5,
				"lat": 69.40, "lon": 33.75, "geo": "su1", "land_h": 250.0, "location": "Mouth of the Kola Bay",
				"weather": {"sea": 2.0, "wind": 200.0, "vis": 15.0, "clouds": 0.25, "aurora": 1.0},
				"briefing": "Two ammunition transports are leaving the Kola Bay tonight for the army at the Titovka River. An American submarine has been laying mines and attacking shipping off the inlet, and carrier aircraft raid the coast at dawn.\n\nEscort the transports clear of the inlet. Find the American submarine if you can.",
				"intel": "One Los Angeles-class nuclear submarine (very quiet at low speed). Carrier-based A-6E Intruders with Harpoon missiles expected after 0330.",
				"support": "PVO MiG-31 interceptors from Monchegorsk. A Ka-27 helicopter from Severomorsk is searching for the submarine.",
				"tip": "Your Osa missiles and twin 76 mm guns defend against air attack automatically. The URPK-4 Metel (group 5) carries a homing torpedo to a submarine 50 km away; the RBU-6000 rockets are for close range. Stop or slow down to hear the submarine.",
				"player": {"pos": [-2, 6], "hdg": 80.0, "speed": 14.0},
				"units": [
					{"cls": "tanker", "side": "su", "pos": [-5, 3], "hdg": 60.0, "speed": 11.0, "tag": "convoy", "ai": "convoy", "waypoints": [[40, 30]], "name": "Dubna"},
					{"cls": "merchant", "side": "su", "pos": [-7, 1], "hdg": 60.0, "speed": 11.0, "tag": "convoy", "ai": "convoy", "waypoints": [[38, 28]], "name": "Kapitan Kadetsky"},
					{"cls": "ssn688", "side": "us", "pos": [18, 18], "hdg": 230.0, "speed": 5.0, "depth": 100.0, "tag": "sub", "ai": "patrol", "waypoints": [[5, 12], [20, 20]], "name": "USS Augusta"},
				],
				"air": [
					{"type": "ka27", "side": "su", "pos": [2, 8], "hdg": 60.0, "orbit": [8, 12], "callsign": "Kasatka 12"},
					{"type": "mig31", "side": "su", "at": 470.0, "pos": [0, -60], "hdg": 330.0, "n": 2, "orbit": [-40, 40], "callsign": "Sokol 1", "radio": ["Sokol 1", "Sokol-1, pair of MiG-31s airborne from Monchegorsk. We will meet them."]},
					{"type": "a6", "side": "us", "at": 480.0, "pos": [-200, 200], "hdg": 120.0, "n": 4, "tag": "raid", "radio": ["Coastal radar", "Low-flying aircraft, four, bearing three-one-five, two hundred kilometres. Intruders."]},
				],
				"objectives": [
					{"id": "o1", "text": "Escort the transports clear of the inlet", "type": "protect", "tag": "convoy", "min": 1, "until": 1500.0},
					{"id": "o2", "text": "Sink the American submarine", "type": "destroy", "tag": "sub", "optional": true},
				],
				"events": [
					{"at": 4.0, "radio": ["Operational duty officer", "Bezzavetny, the transports are clear of the boom. Escort them east of Kildin. Keep the American submarine off them."]},
					{"at": 1490.0, "radio": ["Operational duty officer", "Transports are clear. Well done, Bezzavetny. Return to base."]},
				],
				"front": {"iceland": "us", "norway_n": "us", "faroes": "us", "pechenga": "us", "bermuda": "us", "europe": "elbe"},
				"sitrep": {
					"army": "The 131st Motor Rifle Division halts the NATO advance at the Titovka River, forty kilometres from Murmansk. The shells your transports carried are already falling on the American Marines.",
					"air": "PVO MiG-31s claim six Intruders over the Kola Peninsula. The American carriers pull back to the south-west.",
					"navy": "The bastion holds. Our submarines sail to strike the reinforcements bound for northern Norway.",
				},
			},
			{
				"id": "su2", "title": "Bear Island", "ship": "akula", "side": "su", "date": [1988, 9, 29], "time": 15.5,
				"lat": 74.0, "lon": 19.0, "location": "Near Bear Island, Barents Sea",
				"weather": {"sea": 4.0, "wind": 250.0, "vis": 12.0, "clouds": 0.8},
				"briefing": "Two American fast transports with the Marines' heavy equipment are running for Tromsø, escorted by a Spruance-class destroyer and a Perry-class frigate. Without that equipment the Marines at Pechenga cannot hold.\n\nGet past the escorts and sink both transports.",
				"intel": "USS Caron (Spruance class, excellent SQS-53 sonar and SQR-19 towed array), USS Stark (Perry class) with an SH-60B helicopter. Two transports.",
				"support": "Naval aviation Tu-22M3 Backfires will strike the escorts after your attack.",
				"tip": "The American escorts hear well. Approach deep and slow, below the layer (80 m), and watch the sonar waterfall in the control room. T picks a contact, Space fires. The 65-76 'fat' torpedoes home on a ship's wake and cannot be decoyed. P raises the periscope at 18 m; N drops a decoy.",
				"player": {"pos": [0, -4], "hdg": 340.0, "speed": 6.0, "depth": 100.0},
				"units": [
					{"cls": "merchant", "side": "us", "pos": [-10, 32], "hdg": 160.0, "speed": 15.0, "n": 2, "cols": 2, "spacing": 1.5, "tag": "transports", "ai": "convoy", "waypoints": [[30, -80]], "names": ["USNS Bellatrix", "USNS Pollux"]},
					{"cls": "dd963", "side": "us", "pos": [-9, 28], "hdg": 160.0, "speed": 15.0, "tag": "escorts", "ai": "escort", "lead": "transports", "offset": [2.0, 3.0], "name": "USS Caron"},
					{"cls": "ffg7", "side": "us", "pos": [-11, 28], "hdg": 160.0, "speed": 15.0, "tag": "escorts", "ai": "escort", "lead": "transports", "offset": [-2.5, -1.0], "name": "USS Stark"},
				],
				"air": [
					{"type": "sh60", "side": "us", "pos": [-9, 26], "hdg": 160.0, "orbit": [-6, 22]},
					{"type": "tu22m", "side": "su", "at": 1200.0, "pos": [100, -300], "hdg": 330.0, "n": 4, "callsign": "Strela 2", "target_tag": "escorts", "radio": ["Strela 2", "Strela-2, four Backfires inbound on the American escorts."]},
				],
				"objectives": [
					{"id": "o1", "text": "Sink both American transports", "type": "destroy", "tag": "transports"},
					{"id": "o2", "text": "Sink the escorts", "type": "destroy", "tag": "escorts", "optional": true},
				],
				"events": [
					{"at": 4.0, "radio": ["Northern Fleet", "K-284, convoy bearing three-four-zero, thirty-seven kilometres, speed fifteen, heading south-south-east. Attack."]},
				],
				"front": {"iceland": "us", "norway_n": "us", "faroes": "us", "pechenga": "us", "bermuda": "us", "europe": "elbe"},
				"sitrep": {
					"army": "Without their heavy equipment the American Marines at Pechenga are cut off. The 131st Motor Rifle Division retakes Luostari.",
					"air": "Naval aviation Backfires press home their attack on the convoy's escorts with Kh-22s.",
					"navy": "But an American surface group is shelling our army's positions from the Varangerfjord.",
				},
			},
			{
				"id": "su3", "title": "Varangerfjord", "ship": "sovremenny", "side": "su", "date": [1988, 10, 12], "time": 12.5,
				"lat": 70.05, "lon": 30.6, "geo": "su3", "land_h": 200.0, "location": "Varangerfjord, off the Norwegian border",
				"weather": {"sea": 3.0, "wind": 240.0, "vis": 25.0, "clouds": 0.5},
				"briefing": "An American surface group, a Spruance-class destroyer and two Perry-class frigates, has been shelling the 131st Motor Rifle Division from the Varangerfjord for two days. The army's counter-attack on Pechenga cannot begin until they are gone.\n\nDestroy the American group.",
				"intel": "USS Peterson (Spruance class: Harpoon, Tomahawk, two 5-inch guns), USS Nicholas and USS Simpson (Perry class). Carrier aircraft may raid later.",
				"support": "The frigate Druzhny joins you. Su-24 Fencers of the Northern Fleet air arm will strike the American group.",
				"tip": "Your P-270 Moskits fly at Mach 2.5 and weave in the last kilometres: four on a target will overwhelm a Perry. Keep the ship moving and let the AK-630s and Uragans handle Harpoons.",
				"player": {"pos": [20, 5], "hdg": 270.0, "speed": 22.0},
				"units": [
					{"cls": "krivak", "side": "su", "pos": [22, 7], "hdg": 270.0, "speed": 22.0, "tag": "friends", "ai": "escort", "lead": "player", "offset": [2.5, -1.0], "name": "Druzhny"},
					{"cls": "dd963", "side": "us", "pos": [-15, 2], "hdg": 90.0, "speed": 15.0, "tag": "usgroup", "ai": "patrol", "waypoints": [[-25, 0], [-5, 4]], "name": "USS Peterson"},
					{"cls": "ffg7", "side": "us", "pos": [-18, 5], "hdg": 90.0, "speed": 15.0, "n": 2, "cols": 2, "spacing": 2.0, "tag": "usgroup", "ai": "patrol", "waypoints": [[-28, 4], [-8, 7]], "names": ["USS Nicholas", "USS Simpson"]},
				],
				"air": [
					{"type": "su24", "side": "su", "at": 300.0, "pos": [60, -150], "hdg": 320.0, "n": 2, "callsign": "Grach 3", "target_tag": "usgroup", "radio": ["Grach 3", "Grach-3, pair of Fencers inbound on the American ships."]},
					{"type": "a6", "side": "us", "at": 600.0, "pos": [-250, 100], "hdg": 100.0, "n": 4, "tag": "raid", "radio": ["Coastal radar", "Four Intruders low over Finnmark, heading for you."]},
				],
				"objectives": [
					{"id": "o1", "text": "Destroy the American surface group", "type": "destroy", "tag": "usgroup"},
				],
				"events": [
					{"at": 4.0, "radio": ["Northern Fleet", "Otlichny, American group bearing two-seven-zero, thirty-five kilometres. The army is waiting. Attack."]},
				],
				"front": {"iceland": "us", "norway_n": "us", "faroes": "us", "pechenga": "contested", "bermuda": "us", "europe": "elbe"},
				"sitrep": {
					"army": "The 131st Motor Rifle Division and the 61st Naval Infantry Brigade retake Pechenga. The Americans fall back on Kirkenes.",
					"air": "Su-24 Fencers strike NATO artillery positions around Kirkenes. Two are lost to Hawk missiles.",
					"navy": "To break the Kirkenes line the army needs heavy guns. The old cruiser Murmansk has been recommissioned for the task.",
				},
			},
			{
				"id": "su4", "title": "Guns for Kirkenes", "ship": "sverdlov", "side": "su", "date": [1988, 10, 22], "time": 9.5,
				"lat": 69.80, "lon": 30.2, "geo": "su4", "land_h": 250.0, "location": "Off Kirkenes, Norway",
				"weather": {"sea": 2.0, "wind": 180.0, "vis": 18.0, "clouds": 0.6},
				"briefing": "The army attacks Kirkenes at dawn. NATO artillery batteries dug in along the shore and two Hawk missile sites stand in the way. Naval infantry landing ships are waiting to put a brigade ashore behind the line.\n\nSilence the batteries and the Hawk sites with your 152 mm guns, and protect the landing ships.",
				"intel": "Three NATO artillery batteries (155 mm and 152 mm captured guns), two Hawk SAM sites, the frigate USS Simpson. Carrier aircraft may attack with Harpoons.",
				"support": "PVO MiG-31s will cover against air attack. Army spotters are with the forward battalions.",
				"tip": "Load HE (Z) for shore targets. Use the tactical plot (M) to see the target positions and the director sight (B) to aim. The batteries will fire back.",
				"player": {"pos": [10, 20], "hdg": 230.0, "speed": 14.0},
				"units": [
					{"cls": "merchant", "side": "su", "pos": [25, 30], "hdg": 220.0, "speed": 9.0, "n": 2, "cols": 2, "spacing": 1.5, "tag": "landing", "ai": "convoy", "waypoints": [[16, 10]], "names": ["BDK-91", "BDK-182"]},
					{"cls": "ffg7", "side": "us", "pos": [35, 15], "hdg": 270.0, "speed": 16.0, "tag": "defenders", "ai": "patrol", "waypoints": [[0, 15], [35, 15]], "name": "USS Simpson"},
				],
				"ground": [
					{"name": "NATO battery Hessa", "pos": [5, -6], "kind": "battery", "tag": "batteries", "side": "us"},
					{"name": "Battery Kirkenes", "pos": [18, -3], "kind": "battery", "tag": "batteries", "side": "us"},
					{"name": "Battery Bøkfjord", "pos": [30, -2], "kind": "battery", "tag": "batteries", "side": "us"},
					{"name": "Hawk site Elvenes", "pos": [12, -12], "kind": "sam", "tag": "sams", "side": "us", "hp": 0.8},
					{"name": "Hawk site Pasvik", "pos": [25, -10], "kind": "sam", "tag": "sams", "side": "us", "hp": 0.8},
				],
				"air": [
					{"type": "mig31", "side": "su", "at": 690.0, "pos": [40, -80], "hdg": 330.0, "n": 2, "orbit": [-30, 30], "callsign": "Sokol 4"},
					{"type": "a6", "side": "us", "at": 700.0, "pos": [-220, 120], "hdg": 110.0, "n": 4, "tag": "raid", "radio": ["Coastal radar", "Intruders inbound from the west, low."]},
				],
				"objectives": [
					{"id": "o1", "text": "Silence the NATO artillery batteries", "type": "bombard", "tag": "batteries"},
					{"id": "o2", "text": "Destroy the Hawk missile sites", "type": "bombard", "tag": "sams"},
					{"id": "o3", "text": "Protect the landing ships", "type": "protect", "tag": "landing", "min": 1, "until_flag": "o1_done"},
				],
				"events": [
					{"at": 20.0, "radio": ["Army spotter", "Murmansk, forward observer with the 2nd Battalion. The batteries are along the shore east and west of Kirkenes. Ready to correct your fire."]},
					{"when": "o1_done", "radio": ["Naval infantry", "The batteries are silent! The brigade is landing."]},
				],
				"front": {"iceland": "us", "norway_n": "us", "faroes": "us", "pechenga": "su", "bermuda": "us", "europe": "elbe"},
				"sitrep": {
					"army": "Kirkenes falls on 24 October. Soviet tanks cross into Norway and roll west along the coast road toward Tromsø.",
					"air": "With the Hawk batteries gone, our aircraft own the sky over Finnmark.",
					"navy": "The Northern Fleet sails. Kirov leads the breakout into the Norwegian Sea.",
				},
			},
			{
				"id": "su5", "title": "Breakout", "ship": "kirov", "side": "su", "date": [1988, 11, 5], "time": 13.0,
				"lat": 67.0, "lon": 4.0, "location": "Norwegian Sea",
				"weather": {"sea": 4.0, "wind": 230.0, "vis": 25.0, "clouds": 0.5},
				"briefing": "Kirov leads the Northern Fleet into the Norwegian Sea. An American group built around the Aegis cruiser Yorktown stands in the way, with carrier aircraft behind it.\n\nDestroy the American group. Your twenty P-700 Granits can saturate any defence: use them well.",
				"intel": "USS Yorktown (Ticonderoga class, Aegis, about 80 SM-2 missiles), USS Moosbrugger (Spruance class), USS Kauffman (Perry class). A-6E Intruder strike expected.",
				"support": "The destroyer Bezuprechny and the frigate Ladny escort you. Naval aviation Backfires will strike the Americans.",
				"tip": "Aegis can shoot down a few missiles at a time but not twenty. Fire Granits in large salvos (Space repeatedly) at the cruiser first. S-300F is automatic against the Intruders.",
				"player": {"pos": [0, 0], "hdg": 230.0, "speed": 24.0},
				"units": [
					{"cls": "sovremenny", "side": "su", "pos": [3, 2], "hdg": 230.0, "speed": 24.0, "tag": "friends", "ai": "escort", "lead": "player", "offset": [3.0, -1.5], "name": "Bezuprechny"},
					{"cls": "krivak", "side": "su", "pos": [-3, 2], "hdg": 230.0, "speed": 24.0, "tag": "friends", "ai": "escort", "lead": "player", "offset": [-3.0, -2.0], "name": "Ladny"},
					{"cls": "cg47", "side": "us", "pos": [-85, -65], "hdg": 45.0, "speed": 20.0, "tag": "usgroup", "ai": "patrol", "waypoints": [[0, 0]], "name": "USS Yorktown"},
					{"cls": "dd963", "side": "us", "pos": [-82, -68], "hdg": 45.0, "speed": 20.0, "tag": "usgroup", "ai": "escort", "lead": "usgroup", "offset": [3.0, 1.0], "name": "USS Moosbrugger"},
					{"cls": "ffg7", "side": "us", "pos": [-88, -62], "hdg": 45.0, "speed": 20.0, "tag": "usgroup", "ai": "escort", "lead": "usgroup", "offset": [-3.0, -1.0], "name": "USS Kauffman"},
				],
				"air": [
					{"type": "tu22m", "side": "su", "at": 300.0, "pos": [150, 250], "hdg": 220.0, "n": 4, "callsign": "Strela 5", "target_tag": "usgroup", "radio": ["Strela 5", "Strela-5, four Backfires, attacking the American group."]},
					{"type": "a6", "side": "us", "at": 400.0, "pos": [-250, -100], "hdg": 70.0, "n": 6, "tag": "raid", "radio": ["Kirov radar", "Six aircraft low from the south-west. Intruders with Harpoons."]},
				],
				"objectives": [
					{"id": "o1", "text": "Destroy the American surface group", "type": "destroy", "tag": "usgroup"},
				],
				"events": [
					{"at": 4.0, "radio": ["Northern Fleet", "Kirov, American group bearing two-two-five, one hundred and ten kilometres. The fleet goes south through you. Attack."]},
				],
				"front": {"iceland": "us", "norway_n": "contested", "faroes": "us", "pechenga": "su", "bermuda": "us", "europe": "elbe"},
				"sitrep": {
					"army": "Tromsø falls. In Germany the front stabilises on the Elbe; the American advance has run out of fuel.",
					"air": "Naval aviation strikes the American air base at Keflavik. The 76th Guards Air Assault Division prepares to retake Iceland.",
					"navy": "Sovetsky Soyuz, the battleship finished in secret and rebuilt with missiles, will lead the assault on Iceland.",
				},
			},
			{
				"id": "su6", "title": "Keflavik", "ship": "sovsoyuz", "side": "su", "date": [1988, 11, 15], "time": 10.5,
				"lat": 63.70, "lon": -22.60, "geo": "su6", "land_h": 250.0, "location": "Reykjanes Peninsula, Iceland",
				"weather": {"sea": 4.0, "wind": 50.0, "vis": 15.0, "clouds": 0.7},
				"briefing": "The 76th Guards Air Assault Division will drop on Keflavik when the American Hawk sites are gone. Coastal batteries on the Reykjanes shore cover the landing beaches for the naval infantry, and the heavy cruiser USS Salem defends the approaches.\n\nSilence the batteries and the Hawk sites. Protect the landing ships.",
				"intel": "Three coastal batteries, two Hawk sites and an AN/FPS-117 radar. USS Salem (Des Moines class: nine fast-firing 8-inch guns, 152 mm belt) and the frigate USS Kauffman.",
				"support": "Naval aviation will hit any American aircraft carrier strike. Landing ships BDK-10 and Ivan Rogov wait offshore.",
				"tip": "Salem's 8-inch guns cannot pierce your belt except at very close range, but they will wreck your superstructure and radars. Sink her with 406 mm AP, then switch to HE for the shore.",
				"player": {"pos": [0, -14], "hdg": 0.0, "speed": 16.0},
				"units": [
					{"cls": "merchant", "side": "su", "pos": [-8, -24], "hdg": 15.0, "speed": 8.0, "n": 2, "cols": 2, "spacing": 1.5, "tag": "landing", "ai": "convoy", "waypoints": [[-6, -8]], "names": ["BDK-10", "Ivan Rogov"]},
					{"cls": "ca139", "side": "us", "pos": [20, 6], "hdg": 250.0, "speed": 18.0, "tag": "defenders", "ai": "patrol", "waypoints": [[-12, 6], [24, 8]], "name": "USS Salem"},
					{"cls": "ffg7", "side": "us", "pos": [24, 9], "hdg": 250.0, "speed": 18.0, "tag": "defenders", "ai": "escort", "lead": "defenders", "offset": [2.0, -1.0], "name": "USS Kauffman"},
				],
				"ground": [
					{"name": "Coastal battery Hafnir", "pos": [-3, 19], "kind": "battery", "tag": "batteries", "side": "us"},
					{"name": "Coastal battery Grindavik", "pos": [16, 18.5], "kind": "battery", "tag": "batteries", "side": "us"},
					{"name": "Coastal battery Krysuvik", "pos": [28, 18], "kind": "battery", "tag": "batteries", "side": "us"},
					{"name": "Hawk site Keflavik North", "pos": [2, 30], "kind": "sam", "tag": "sams", "side": "us", "hp": 0.8},
					{"name": "Hawk site Keflavik East", "pos": [12, 31], "kind": "sam", "tag": "sams", "side": "us", "hp": 0.8},
					{"name": "AN/FPS-117 radar", "pos": [10, 24], "kind": "radar", "tag": "radar", "side": "us", "hp": 0.6, "h": 60},
				],
				"air": [
					{"type": "a6", "side": "us", "at": 800.0, "pos": [-200, 150], "hdg": 120.0, "n": 4, "tag": "raid", "radio": ["Radar", "Intruders from the west, low, heading for the landing ships."]},
				],
				"objectives": [
					{"id": "o1", "text": "Silence the coastal batteries", "type": "bombard", "tag": "batteries"},
					{"id": "o2", "text": "Destroy the Hawk missile sites", "type": "bombard", "tag": "sams"},
					{"id": "o3", "text": "Protect the landing ships", "type": "protect", "tag": "landing", "min": 1, "until_flag": "o2_done"},
					{"id": "o4", "text": "Sink USS Salem", "type": "destroy", "tag": "defenders", "count": 1, "optional": true},
				],
				"events": [
					{"at": 20.0, "radio": ["Spotter", "Sovetsky Soyuz, spotter group ashore near Reykjanes lighthouse. Batteries along the south shore. Ready."]},
					{"when": "o2_done", "radio": ["76th Guards", "Hawks are silent. The division is jumping. For the Motherland!"]},
				],
				"front": {"iceland": "contested", "norway_n": "su", "faroes": "us", "pechenga": "su", "bermuda": "us", "europe": "elbe"},
				"sitrep": {
					"army": "The 76th Guards Air Assault Division takes Keflavik; naval infantry land at Grindavik. Iceland is ours by 18 November.",
					"air": "Our fighters fly from Keflavik. The GIUK gap is open and the convoy routes to Europe lie under our bombers.",
					"navy": "The Americans gather everything they have left, the battleship Missouri among them, in the Denmark Strait.",
				},
			},
			{
				"id": "su7", "title": "Denmark Strait", "ship": "sovsoyuz", "side": "su", "date": [1988, 11, 28], "time": 13.0,
				"lat": 66.0, "lon": -27.0, "location": "Denmark Strait",
				"weather": {"sea": 6.0, "wind": 40.0, "vis": 10.0, "clouds": 0.85, "dark": 0.5},
				"nuclear_release": true,
				"briefing": "A winter gale is blowing down the Denmark Strait. Out there is USS Missouri with an Aegis cruiser and a Spruance-class destroyer, the last American battle group able to contest the North Atlantic.\n\nSink Missouri. The General Staff has authorised the use of special warheads against naval targets at sea. Your Granits with nuclear warheads are ready. The decision is yours, Comrade Captain.",
				"intel": "USS Missouri (Iowa class: nine 16-inch guns, 307 mm belt, Tomahawk and Harpoon), USS Leyte Gulf (Aegis cruiser), USS Peterson (Spruance class). An American submarine may be present.",
				"support": "The battlecruiser Kalinin and the destroyer Okrylenny sail with you.",
				"tip": "Her 16-inch shells can pierce your belt inside about 20 km. Use your heavier armour and longer range. To use special weapons: turn both keys on the bridge release panel, select Granit (500 kt) with Z, and fire.",
				"player": {"pos": [0, 0], "hdg": 230.0, "speed": 22.0},
				"units": [
					{"cls": "kirov", "side": "su", "pos": [3, 2], "hdg": 230.0, "speed": 22.0, "tag": "friends", "ai": "escort", "lead": "player", "offset": [3.5, -2.0], "name": "Kalinin"},
					{"cls": "sovremenny", "side": "su", "pos": [-3, 2], "hdg": 230.0, "speed": 22.0, "tag": "friends", "ai": "escort", "lead": "player", "offset": [-3.0, -2.0], "name": "Okrylenny"},
					{"cls": "bb61", "side": "us", "pos": [-70, -40], "hdg": 50.0, "speed": 24.0, "tag": "bb", "ai": "patrol", "waypoints": [[0, 0]], "name": "USS Missouri", "aggression": 1.3},
					{"cls": "cg47", "side": "us", "pos": [-67, -43], "hdg": 50.0, "speed": 24.0, "tag": "escorts", "ai": "escort", "lead": "bb", "offset": [3.0, 1.0], "name": "USS Leyte Gulf"},
					{"cls": "dd963", "side": "us", "pos": [-73, -37], "hdg": 50.0, "speed": 24.0, "tag": "escorts", "ai": "escort", "lead": "bb", "offset": [-3.0, -1.0], "name": "USS Peterson"},
					{"cls": "ssn688", "side": "us", "pos": [-30, -12], "hdg": 50.0, "speed": 6.0, "depth": 120.0, "tag": "sub", "ai": "patrol", "waypoints": [[-10, -5], [-30, -12]], "name": "USS Philadelphia"},
				],
				"air": [
					{"type": "a6", "side": "us", "at": 400.0, "pos": [-250, -60], "hdg": 70.0, "n": 4, "tag": "raid", "radio": ["Radar", "Four aircraft low from the south-west. Intruders."]},
				],
				"objectives": [
					{"id": "o1", "text": "Sink the battleship USS Missouri", "type": "destroy", "tag": "bb"},
					{"id": "o2", "text": "Destroy the escort group", "type": "destroy", "tag": "escorts", "optional": true},
				],
				"events": [
					{"at": 4.0, "radio": ["Commander-in-Chief of the Navy", "Sovetsky Soyuz, the General Staff authorises special warheads against naval targets at sea. The decision is yours."]},
					{"at": 30.0, "radio": ["Kalinin", "Large surface contact bearing two-three-zero, eighty kilometres. It is Missouri."]},
				],
				"front": {"iceland": "su", "norway_n": "su", "faroes": "contested", "pechenga": "su", "bermuda": "us", "europe": "igb"},
			},
		],
		"endings": {
			"won": [
				"Missouri went down in the gale with her guns still firing. With the last American battle group gone and the North Atlantic under Soviet bombers, Washington agreed to a ceasefire in Geneva on 19 December.",
				"The armies stopped where they stood, roughly on the old inner-German border. The war had settled nothing, but it had not ended the world, and no Soviet captain had been the one to cross the threshold.",
				"Sovetsky Soyuz returned to Severomorsk on New Year's Eve. The crews of the fleet lined the shore of the Kola Bay in the dark to see her in.",
			],
			"won_nuclear": [
				"The Granit's warhead turned the Denmark Strait into a column of fire and steam. The American battle group vanished. Eleven days later Washington agreed to a ceasefire.",
				"But a line had been crossed that the world had held since 1945, and the Soviet Union had crossed it. The ceasefire held, barely, under a shadow that would never quite lift.",
				"You were made a Hero of the Soviet Union. You never spoke of the decision again.",
			],
		},
	},
}


static func campaign(side: String) -> Dictionary:
	return CAMPAIGNS.get(side, {})


static func mission(side: String, idx: int) -> Dictionary:
	var ms: Array = CAMPAIGNS[side]["missions"]
	return ms[clampi(idx, 0, ms.size() - 1)]


static func count(side: String) -> int:
	return (CAMPAIGNS[side]["missions"] as Array).size()
