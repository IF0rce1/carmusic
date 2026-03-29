
fx_version 'bodacious'
games { 'gta5' }
dependency 'sounity'

ui_page 'html/index.html'

client_scripts {
  "@vrp/client/Proxy.lua",
  "@vrp/client/Tunnel.lua",
  'config.lua',
  'client/main.lua',
}

files {
	'html/index.html',
	'html/script.js',
	'html/*.svg',
	'html/radio.png',
	'html/main.css',
}

server_scripts {
  "@vrp/lib/utils.lua",
  'config.lua',
  'server/main.lua',
  'utils/jest_setup.js'
}

supersede_radio "RADIO_17_FUNK" { url = "http://37.59.207.68:8000/;stream.mp3", volume = 1, name = "[Coxet]" }
supersede_radio "RADIO_09_HIPHOP_OLD" { url = "https://live.magicfm.ro:8443/magicfm.aacp#A", volume = 1, name ="Magic FM" }
supersede_radio "RADIO_05_TALK_01" { url = "https://live.kissfm.ro:8443/kissfm.aacp#A", volume = 1, name = "Kiss FM" }
supersede_radio "RADIO_06_COUNTRY" { url = "https://astreaming.edi.ro:8443/VirginRadio_aac#AW", volume = 0.10, name ="Virgin Radio" }
supersede_radio "RADIO_14_DANCE_02" { url = "http://167.114.207.234:8888/stream", volume = 1, name = "MUZICA POPULARA" }
supersede_radio "RADIO_01_CLASS_ROCK" { url = "https://edge126.rcs-rds.ro/profm/profm.mp3#W", volume = 0.10, name ="PRO FM" }
supersede_radio "RADIO_12_REGGAE" { url = "http://stream2.srr.ro:8002/;stream/1", volume = 1, name ="ROMANIA ACTUALITATI" }
supersede_radio "RADIO_16_SILVERLAKE" { url = "http://asculta.radiohitfm.net:8340/;", volume = 1, name ="RADIO HIT MANELE" }
supersede_radio "RADIO_08_MEXICAN" { url = "https://edge76.rcs-rds.ro/digifm/digifm.mp3#W", volume = 1, name = "DIGI FM" }
supersede_radio "RADIO_02_POP" { url = "http://a.fmradiomanele.ro:8054/stream?type=http&nocache=378", volume = 1, name ="Radio Manele FM" }
supersede_radio "RADIO_03_HIPHOP_NEW" { url = "https://astreaming.edi.ro:8443/EuropaFM_aac#AWwa", volume = 1, name ="Europa FM" }
supersede_radio "RADIO_18_90S_ROCK" { url = "https://ivm.antenaplay.ro/liveaudio/radiozu/playlist.m3u8", volume = 1, name ="RADIO ZU" }
supersede_radio "RADIO_04_PUNK" { url = "http://live.aquarelle.md:8000/aquarellefm.mp3", volume = 0.10, name = "Aquarelle FM MOLDOVA"}
