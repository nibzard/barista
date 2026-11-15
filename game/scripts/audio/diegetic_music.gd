# ABOUTME: DiegeticMusic maps the places of the world to the music they play.
# ABOUTME: Section 21: music is diegetic first, never a score over the action.
class_name DiegeticMusic
extends RefCounted

enum Venue { SILENT, CAFE, BAND_STAGE, SLEEPVANA_CONCERT }

# The tracks of section 21: the cafe record, the endless song of the Sleep
# Jam band, and the hit of Sleepvana.
const CAFE_TRACK := "Vinyl Jazz"
const BAND_TRACK := "The Endless Song"
const SLEEPVANA_TRACK := "Smells Like Bean Spirit"
const SILENT_TRACK := ""


static func track_name(venue: Venue) -> String:
	match venue:
		Venue.CAFE:
			return CAFE_TRACK
		Venue.BAND_STAGE:
			return BAND_TRACK
		Venue.SLEEPVANA_CONCERT:
			return SLEEPVANA_TRACK
		_:
			return SILENT_TRACK


static func plays_with_tower_off(venue: Venue) -> bool:
	# The tower cut kills only the address. Diegetic music is the world's
	# own, so the record keeps spinning and the band keeps playing.
	return venue != Venue.SILENT
