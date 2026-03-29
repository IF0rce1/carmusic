Config = {}

Config.DistanceToVolume = 10.5
Config.DistanceToVolumeAuzit = 14.0
Config.PlayToEveryone = true
Config.ItemInVehicle = true
Config.CommandVehicle = "carradio"
Config.YouTubeResolverInstances = {
	"https://piped.video",
	"https://pipedapi.kavin.rocks",
	"https://inv.nadeko.net",
	"https://invidious.privacyredirect.com"
}

-- ── Acoustic / distance settings ─────────────────────────────────────────────

-- Base hearing range (metres) when ALL doors+windows are CLOSED.
-- La aceasta distanta volumul e 0 in afara unei masini inchise.
Config.BaseRangeClosed = 18.0

-- Extra metres adaugate per fiecare usa/geam deschis (0-4 openings).
-- ex: 4 deschise → 18 + 4*16 = 82 m range maxim
Config.RangePerOpening = 16.0

-- Distanta absoluta dupa care sistemul audio 3D nu mai calculeaza nimic (guard perf).
-- Trebuie sa fie >= BaseRangeClosed + 4*RangePerOpening + slack.
Config.MaxAudioDistance = 130.0

-- Volumul care "scurge" afara cand masina e complet inchisa (0.0 - 1.0).
-- 0.07 = abia auzi un thump de bass, 0.18 = evident dar muffled.
Config.ClosedLeakVolume = 0.07

-- Cat de "infundat" suna muzica cand masina e inchisa (simuleaza bass-only).
-- 1.0 = deloc infundat, 0.45 = doar frecvente joase trec prin caroserie.
Config.MuffleFloor = 0.45

-- Secundele de crossfade cand iesi din masina (fara taiere brusca).
Config.ExitFadeDuration = 2.8

-- ─────────────────────────────────────────────────────────────────────────────

Config.Zones = {
}
