modifying = false
local Music = {}
local vRP = Proxy.getInterface("vRP")
Tunnel.bindInterface("xradio_music",Music)
local datasoundinfo = {}
local nuiaberto = false
local interiorSoundState = {}
local rawSounity = exports.sounity
local sounitySounds = {}

local function safeSounityCall(methods, defaultValue, ...)
	if not rawSounity then
		return defaultValue
	end

	local methodList = type(methods) == "table" and methods or { methods }
	for i = 1, #methodList do
		local methodName = methodList[i]
		local ok, result = pcall(function(...)
			local fn = exports.sounity[methodName]
			if type(fn) ~= "function" then
				error(("missing export: %s"):format(methodName))
			end
			return fn(exports.sounity, ...)
		end, ...)
		if not ok then
			ok, result = pcall(function(...)
				local fn = exports.sounity[methodName]
				if type(fn) ~= "function" then
					error(("missing export: %s"):format(methodName))
				end
				return fn(...)
			end, ...)
		end
		if ok then
			return result
		end
	end

	return defaultValue
end

local function getSoundState(name)
	return sounitySounds[name]
end

local function buildSoundOptions(soundState)
	return json.encode({
		volume = math.max(0.0, soundState.volume or 0.0),
		outputType = "music",
		loop = soundState.loop == true,
		posX = soundState.pos.x,
		posY = soundState.pos.y,
		posZ = soundState.pos.z,
		panningModel = "HRTF",
		distanceModel = "inverse",
		maxDistance = Config.MaxAudioDistance or 130.0,
		refDistance = 1.9,
		rolloffFactor = 1.55,
		coneInnerAngle = 360.0,
		coneOuterAngle = 140.0,
		coneOuterGain = 0.38
	})
end

local function createSounitySound(name, url, volume, pos, loop, autoStart)
	local existing = getSoundState(name)
	if existing and existing.identifier then
			safeSounityCall({ "StopSound", "stopSound" }, nil, existing.identifier)
			safeSounityCall({ "DisposeSound", "disposeSound" }, nil, existing.identifier)
	end

	local soundState = {
		name = name,
		url = url,
		volume = math.max(0.0, volume or 0.0),
		pos = pos or vector3(0.0, 0.0, 0.0),
		loop = loop == true,
		playing = autoStart == true,
		paused = autoStart ~= true,
		dynamic = true,
		timestamp = 0.0,
		entityNet = nil
	}

	local identifier = safeSounityCall({ "CreateSound", "createSound" }, nil, url, buildSoundOptions(soundState))
	if not identifier then
		return nil
	end

	soundState.identifier = identifier
	sounitySounds[name] = soundState

	if autoStart then
		safeSounityCall({ "StartSound", "startSound" }, nil, identifier)
	end

	return soundState
end

Soundity = {
	soundExists = function(self, name)
		local soundState = getSoundState(name)
		return soundState ~= nil and soundState.identifier ~= nil
	end,
	isPaused = function(self, name) local s = getSoundState(name); return s and s.paused or false end,
	isPlaying = function(self, name) local s = getSoundState(name); return s and s.playing or false end,
	getMaxDuration = function(self, name) return 0.0 end,
	getTimeStamp = function(self, name) local s = getSoundState(name); return s and s.timestamp or 0.0 end,
	getVolume = function(self, name) local s = getSoundState(name); return s and s.volume or 0.0 end,
	Destroy = function(self, name)
		local s = getSoundState(name)
		if not s or not s.identifier then return false end
		safeSounityCall({ "StopSound", "stopSound" }, nil, s.identifier)
		safeSounityCall({ "DisposeSound", "disposeSound" }, nil, s.identifier)
		sounitySounds[name] = nil
		interiorSoundState[name] = nil
		return true
	end,
	isLooped = function(self, name) local s = getSoundState(name); return s and s.loop or false end,
	getLink = function(self, name) local s = getSoundState(name); return s and s.url or nil end,
	isDynamic = function(self, name) local s = getSoundState(name); return s and s.dynamic or false end,
	getPosition = function(self, name) local s = getSoundState(name); return s and s.pos or vector3(0.0, 0.0, 0.0) end,
	setTimeStamp = function(self, name, value) local s = getSoundState(name); if not s then return false end s.timestamp = math.max(0.0, value or 0.0) return true end,
	Distance = function(self, name, value) local s = getSoundState(name); if not s then return false end s.maxDistance = value return true end,
	setSoundDynamic = function(self, name, value)
		local s = getSoundState(name)
		if not s then return false end
		s.dynamic = value == true
		if s.dynamic and s.entityNet then
			safeSounityCall({ "DetachSound", "detachSound" }, nil, s.identifier)
		elseif not s.dynamic and s.entityNet then
			safeSounityCall({ "AttachSound", "attachSound" }, nil, s.identifier, s.entityNet)
		end
		return true
	end,
	setVolume = function(self, name, value)
		local s = getSoundState(name)
		if not s then return false end
		s.volume = math.max(0.0, value or 0.0)
		return true
	end,
	setVolumeMax = function(self, name, value)
		local s = getSoundState(name)
		if not s then return false end
		s.volume = math.max(0.0, value or 0.0)
		return true
	end,
	setSoundURL = function(self, name, url)
		local s = getSoundState(name)
		if not s then return false end
		local currentlyPlaying = s.playing and not s.paused
		local recreated = createSounitySound(name, url, s.volume, s.pos, s.loop, currentlyPlaying)
		if recreated then
			recreated.dynamic = s.dynamic
			recreated.timestamp = s.timestamp
			recreated.entityNet = s.entityNet
			if s.entityNet and not s.dynamic then
				safeSounityCall({ "AttachSound", "attachSound" }, nil, recreated.identifier, s.entityNet)
			end
			return true
		end
		return false
	end,
	Position = function(self, name, pos)
		local s = getSoundState(name)
		if not s or not s.identifier then return false end
		s.pos = pos
		if s.dynamic then
			safeSounityCall({ "MoveSound", "moveSound" }, nil, s.identifier, pos.x, pos.y, pos.z)
		end
		return true
	end,
	setSoundLoop = function(self, name, value)
		local s = getSoundState(name)
		if not s then return false end
		s.loop = value == true
		return true
	end,
	PlayUrlPos = function(self, name, url, vol, coords, loop, options)
		local state = createSounitySound(name, url, vol, coords, loop, true)
		if state and options and type(options.onPlayStart) == "function" then
			options.onPlayStart({})
		end
		return state ~= nil
	end,
	Resume = function(self, name)
		local s = getSoundState(name)
		if not s or not s.identifier then return false end
		s.paused = false
		s.playing = true
		safeSounityCall({ "StartSound", "startSound" }, nil, s.identifier)
		return true
	end,
	Pause = function(self, name)
		local s = getSoundState(name)
		if not s or not s.identifier then return false end
		s.paused = true
		s.playing = false
		safeSounityCall({ "StopSound", "stopSound" }, nil, s.identifier)
		return true
	end,
	setAttachedEntity = function(self, name, entityNet)
		local s = getSoundState(name)
		if not s or not s.identifier then return false end
		s.entityNet = entityNet
		if s.dynamic then
			safeSounityCall({ "DetachSound", "detachSound" }, nil, s.identifier)
		else
			safeSounityCall({ "AttachSound", "attachSound" }, nil, s.identifier, entityNet)
		end
		return true
	end
}
local myjob = nil
local nomidaberto
local SoundsPlaying = {}
local customSong = false

local function canControlCurrentVehicleRadio()
	local ped = PlayerPedId()
	if not IsPedInAnyVehicle(ped, false) then
		return false
	end

	local vehicle = GetVehiclePedIsIn(ped, false)
	if vehicle == 0 then
		return false
	end

	-- allow both front seats: driver (-1) and front passenger (0)
	return GetPedInVehicleSeat(vehicle, -1) == ped or GetPedInVehicleSeat(vehicle, 0) == ped
end

local function isControlAction(action)
	return action == "seturl"
		or action == "play"
		or action == "pause"
		or action == "volumeup"
		or action == "volumedown"
		or action == "loop"
		or action == "forward"
		or action == "back"
			or action == "faauzit"
end

local function isYouTubeUrl(url)
	if type(url) ~= "string" then
		return false
	end

	local normalized = url:lower()
	return normalized:find("youtube%.com", 1, false) ~= nil
		or normalized:find("youtu%.be", 1, false) ~= nil
		or normalized:find("music%.youtube%.com", 1, false) ~= nil
end

local function extractYouTubeVideoId(url)
	if type(url) ~= "string" then
		return nil
	end

	local fromWatch = url:match("[?&]v=([%w_-]+)")
	if fromWatch then
		return fromWatch
	end

	local fromShort = url:match("youtu%.be/([%w_-]+)")
	if fromShort then
		return fromShort
	end

	local fromEmbed = url:match("youtube%.com/embed/([%w_-]+)")
	if fromEmbed then
		return fromEmbed
	end

	return nil
end

local pendingYouTubeResolves = {}

RegisterNetEvent("carmusic:ResolveYouTubeUrlResult")
AddEventHandler("carmusic:ResolveYouTubeUrlResult", function(requestId, resolvedUrl)
	local callback = pendingYouTubeResolves[requestId]
	if callback then
		pendingYouTubeResolves[requestId] = nil
		callback(resolvedUrl)
	end
end)

local function resolveYouTubeToPlayableUrl(url, callback)
	local videoId = extractYouTubeVideoId(url)
	if not videoId then
		callback(nil)
		return
	end

	local requestId = ("%s:%s:%s"):format(GetPlayerServerId(PlayerId()), GetGameTimer(), math.random(1000, 9999))
	pendingYouTubeResolves[requestId] = callback
	TriggerServerEvent("carmusic:ResolveYouTubeUrl", requestId, ("https://youtu.be/%s"):format(videoId))

	SetTimeout(12000, function()
		if pendingYouTubeResolves[requestId] then
			local timeoutCb = pendingYouTubeResolves[requestId]
			pendingYouTubeResolves[requestId] = nil
			timeoutCb(nil)
		end
	end)
end

local function startSoundForLink(nameid, link)
	ApplySound(0.20,nameid,true)
	SetUrl(link,nameid)
	if Soundity:soundExists(nameid) and Soundity:isPaused(nameid) then
		TriggerServerEvent("carmusic:ChangeState", true, nameid)
	end
	customSong = true
end

local function isSoundLoopTracked(index)
	for i = 1, #SoundsPlaying do
		if SoundsPlaying[i] == index then
			return true
		end
	end

	return false
end

local function addSoundLoop(index)
	if index and not isSoundLoopTracked(index) then
		table.insert(SoundsPlaying, index)
		StartMusicLoop(index)
	end
end

RegisterNUICallback("action", function(data)
	local _source = source
	local nameid = nomidaberto

	if isControlAction(data.action) and not canControlCurrentVehicleRadio() then
		vRP.notify({"Doar soferul sau pasagerul din dreapta fata poate controla carradio-ul.","error"})
		return
	end
	if IsPedInAnyVehicle(PlayerPedId(), false) then
		local veh = GetVehiclePedIsIn(PlayerPedId(),false)
		local plate = GetVehicleNumberPlateText(veh)
		nameid = plate
	end
	if data.action == "seturl" then
		if isYouTubeUrl(data.link) then
			vRP.notify({"Detectat link YouTube, convertesc catre stream audio...","info"})
				resolveYouTubeToPlayableUrl(data.link, function(resolvedUrl)
					if not resolvedUrl then
						vRP.notify({"Nu am putut extrage stream audio din YouTube. Incearca alt link sau adauga alte instante resolver in config.","error"})
						return
					end
				startSoundForLink(nameid, resolvedUrl)
			end)
			return
		end
		startSoundForLink(nameid, data.link)
	elseif data.action == "numemelodie" then
		vRP.notify({"Se reda acum: "..data.nume,"info"})
	elseif data.action == "faauzit" then
		ApplySound(0.9,nameid)
	elseif data.action == "play" then
		if Soundity:soundExists(nameid) and Soundity:isPaused(nameid) then
			TriggerServerEvent("carmusic:ChangeState", true, nameid)
		end
	elseif data.action == "pause" then
		if Soundity:soundExists(nameid) and Soundity:isPlaying(nameid) then
			TriggerServerEvent("carmusic:ChangeState", false, nameid)
		end
		customSong = false
	elseif data.action == "exit" then
		show()
	elseif data.action == "volumeup" then
		ApplySound(0.05,nameid)
	elseif data.action == "volumedown" then
		ApplySound(-0.05,nameid)
	elseif data.action == "loop" then
		if Soundity:soundExists(nameid) then
			datasoundinfo.loop = not Soundity:isLooped(nameid)
			TriggerServerEvent("carmusic:ChangeLoop",nameid,datasoundinfo.loop)
		else
			datasoundinfo.loop = not datasoundinfo.loop
		end
		if type(datasoundinfo.loop) ~= "table" then
			local loop = ('Looping: '.. firstToUpper(tostring(datasoundinfo.loop)))
			vRP.notify({"Mod repeat: On"})
		end
	elseif data.action == "forward" then
		if Soundity:soundExists(nameid) then
			vRP.notify({"Seek momentan indisponibil pe Sounity (stream live-safe).","warning"})
		end
	elseif data.action == "back" then
		if Soundity:soundExists(nameid) then
			vRP.notify({"Seek momentan indisponibil pe Sounity (stream live-safe).","warning"})
		end
	end
end)

function ApplySound(quanti,plate,set)
	local exis = false
	local som = datasoundinfo.volume
	if Soundity:soundExists(plate) and Soundity:isPlaying(plate) then
		exis = true
		som = Soundity:getVolume(plate)
		datasoundinfo.volume = som
	end
	local vadi = math.max(-0.001, math.min(0.99, (set and quanti or som + quanti)))
	if vadi <= 1.01 and vadi >= -0.001 and exis then
		if vadi < 0.005 then
			vadi = 0.0
		end
		datasoundinfo.volume = vadi
		local volume = (('Volume: '.. math.floor((vadi*100) - 0.1+1).."%"))
		SendNUIMessage({
            action = "changetextv",
            text = volume,
        })
		TriggerServerEvent("carmusic:ChangeVolume", quanti, plate, set)
	end
end

function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

function SetUrl(url,nid,sync)
	local nome = nid
	if url then
		local encontrad = false
		for i = 1, #Zones do
			local v = Zones[i]
			if v.name == nome then
				encontrad = true
			end
		end
		if encontrad then
			local vehdata = {}
			vehdata.name = nome
			vehdata.link = url
			vehdata.loop = datasoundinfo.loop
			if IsPedInAnyVehicle(PlayerPedId(), false) then
				vehdata.popo = NetworkGetNetworkIdFromEntity(GetVehiclePedIsIn(PlayerPedId(),false))
			end
			modifying = true
			TriggerServerEvent("carmusic:ModifyURL",vehdata)
		else
			if IsPedInAnyVehicle(PlayerPedId(), false) then
				local veh = GetVehiclePedIsIn(PlayerPedId(),false)
				local cordsveh = GetEntityCoords(veh)
				local netid = NetworkGetNetworkIdFromEntity(veh)
				local vehdata = {}
				vehdata.plate = nome
				vehdata.coords = cordsveh
				vehdata.link = url
				vehdata.popo = netid
				vehdata.volume = datasoundinfo.volume
				vehdata.loop = datasoundinfo.loop
				modifying = true
				TriggerServerEvent("carmusic:AddVehicle",vehdata,sync)
			end
		end
	else

	end
	SendNUIMessage({
		action = "TimeVid",
	})
	if Soundity:soundExists(nome) then
		SendNUIMessage({
			action = "TimeVid",
			total = Soundity:getMaxDuration(nome),
			played = Soundity:getTimeStamp(nome),
		})
	end
	local esperar = 0
	while nuiaberto do
		Wait(1000)
		if Soundity:soundExists(nome) then
			if Soundity:isPlaying(nome) then
				SendNUIMessage({
					action = "TimeVid",
					total = Soundity:getMaxDuration(nome),
					played = Soundity:getTimeStamp(nome),
				})
			else
				esperar = esperar +1
			end
		else
			esperar = esperar +1
		end
		if esperar >= 4 then
			break
		end
	end
end

if Config.ItemInVehicle then
	RegisterCommand(Config.CommandVehicle, function(source, args, rawCommand)
		if not canControlCurrentVehicleRadio() then
			vRP.notify({"Doar soferul sau pasagerul din dreapta fata poate deschide carradio-ul.","error"})
			return
		end
		show()
	end, false)
end

if Config.ItemInVehicle then
	RegisterNetEvent("carmusic:ShowNui")
	AddEventHandler("carmusic:ShowNui", function()
		if not canControlCurrentVehicleRadio() then
			vRP.notify({"Doar soferul sau pasagerul din dreapta fata poate deschide carradio-ul.","error"})
			return
		end
		show()
	end)
end

local shown = false

function show(nomecenas)
	shown = not shown
	local nome = nomecenas
	if IsPedInAnyVehicle(PlayerPedId(), false) then
		local veh = GetVehiclePedIsIn(PlayerPedId(),false)
		local plate = GetVehicleNumberPlateText(veh)
		nome = plate
	end
    if shown and nome then
		nuiaberto = true
		datasoundinfo = {volume = 0.2, loop = false}
		local linkurl
		if Soundity:soundExists(nome) then
			datasoundinfo.volume = Soundity:getVolume(nome)
			datasoundinfo.loop = Soundity:isLooped(nome)
			if Soundity:isPlaying(nome) then
				linkurl = Soundity:getLink(nome)
			end
		end
        SetNuiFocus(true, true)
		local volume = ('Volume: '.. math.floor((datasoundinfo.volume*100) - 0.1+1).."%")
		if type(datasoundinfo.loop) ~= "table" then
			local loop = ('Looping: '.. firstToUpper(tostring(datasoundinfo.loop)))
			vRP.notify({"Mod repeat: Off"})
		end
		SendNUIMessage({
            action = "changetextv",
            text = volume,
        })
		SendNUIMessage({
            action = "changevidname",
            text = linkurl,
        })
		SendNUIMessage({
            action = "showRadio",
        })
		SendNUIMessage({
			action = "TimeVid",
		})
		if Soundity:soundExists(nome) then
			SendNUIMessage({
				action = "TimeVid",
				total = Soundity:getMaxDuration(nome),
				played = Soundity:getTimeStamp(nome),
			})
		end
		local esperar = 0
		while nuiaberto do
			Wait(1000)
			if Soundity:soundExists(nome) then
				if Soundity:isPlaying(nome) then
					SendNUIMessage({
						action = "TimeVid",
						total = Soundity:getMaxDuration(nome),
						played = Soundity:getTimeStamp(nome),
					})
				else
					esperar = esperar +1
				end
			else
				esperar = esperar +1
			end
			if esperar >= 4 then
				break
			end
		end
    elseif nuiaberto then
		nuiaberto = false
        SetNuiFocus(false, false)
        SendNUIMessage({
            action = "hideRadio",
			data = datasoundinfo
        })
	end
end

Zones = {}

RegisterNetEvent("carmusic:AddVehicle")
AddEventHandler("carmusic:AddVehicle", function(data)
	table.insert(Zones, data)
	local v = data
	if Soundity:soundExists(v.name) then
		Soundity:Destroy(v.name)
	end
	local avancartodos = v.volume
	if not Config.PlayToEveryone and v.popo then
		avancartodos = 0.0
		local popodentro = GetVehiclePedIsIn(PlayerPedId(),false)
		local plate = GetVehicleNumberPlateText(popodentro)
		if plate == v.name then
			avancartodos = v.volume
		end
	end
	local networked_veh = NetworkGetEntityFromNetworkId(v.popo)
	local ped_veh = GetVehiclePedIsIn(PlayerPedId())
	if networked_veh ~= 0 and ped_veh == networked_veh then
		CreateThread(function()
			while (Soundity:soundExists(v.name) and DoesEntityExist(networked_veh)) do Wait(512)
				local ped = PlayerPedId()
				local coords = GetEntityCoords(ped)
				local veh_coords = GetEntityCoords(networked_veh)
				if #(coords - veh_coords) >= 30 then
					if Soundity:soundExists(v.name) then
						Soundity:Destroy(v.name)
					end
				end
			end
		end)
	end
	Soundity:PlayUrlPos(v.name, v.deflink, avancartodos, v.coords, v.loop,{
		onPlayStart = function(event)
			Soundity:setTimeStamp(v.name, v.deftime)
			Soundity:Distance(v.name, Config.MaxAudioDistance or 130.0)
		end,
	})
	addSoundLoop(#Zones)
end)

RegisterNetEvent("carmusic:ModifyURL")
AddEventHandler("carmusic:ModifyURL", function(data)
	local v = data
	local avancartodos = v.volume
	if not Config.PlayToEveryone and v.popo then
		avancartodos = 0.0
		local popodentro = GetVehiclePedIsIn(PlayerPedId(),false)
		local plate = GetVehicleNumberPlateText(popodentro)
		if plate == v.name then
			avancartodos = v.volume
		end
	end
	if Soundity:soundExists(v.name) then
		if not Soundity:isDynamic(v.name) then
			Soundity:setSoundDynamic(v.name,true)
		end
		Wait(100)
		Soundity:setVolumeMax(v.name,0.0)
		Soundity:setSoundURL(v.name, v.deflink)
		Wait(100)
		Soundity:Position(v.name, v.coords)
		Soundity:setSoundLoop(v.name,v.loop)
		Wait(200)
		Soundity:setTimeStamp(v.name,0)
		Soundity:setVolumeMax(v.name,avancartodos)

	else
		Soundity:PlayUrlPos(v.name, v.deflink, avancartodos, v.coords, v.loop, {
			onPlayStart = function(event)
				Soundity:setTimeStamp(v.name, v.deftime)
				Soundity:Distance(v.name, Config.MaxAudioDistance or 130.0)
			end,
		})
	end
	local iss = nil
	for i = 1, #Zones do
		local b = Zones[i]
		if v.name == b.name then
			if b.popo then
				iss = i
			end
			b.deflink = v.deflink
			b.deftime = 0
			b.isplaying = v.isplaying
			b.loop = v.loop
			if v.popo then
				b.popo = v.popo
			end
		end
	end
	local encontrads = false
	for i = 1, #SoundsPlaying do
		local v = SoundsPlaying[i]
		if v == iss then
			encontrads = true
		end
	end
	local esperar = 0
	while nuiaberto do
		Wait(1000)
		if Soundity:soundExists(v.name) then
			local pped = PlayerPedId()
			local coordss = GetEntityCoords(pped)
			local geraldist = #(coordss-Soundity:getPosition(v.name))
			if Soundity:isPlaying(v.name) and (geraldist <= 3 or not v.popo) then
				SendNUIMessage({
					action = "TimeVid",
					total = Soundity:getMaxDuration(v.name),
					played = Soundity:getTimeStamp(v.name),
				})
			else
				esperar = esperar +1
			end
		else
			esperar = esperar +1
		end
		if esperar >= 4 then
			break
		end
	end
	if not encontrads and iss then
		addSoundLoop(iss)
	end
end)

RegisterNetEvent("carmusic:ChangeState")
AddEventHandler("carmusic:ChangeState", function(tipo, nome)
	if tipo and Soundity:soundExists(nome) then
		Soundity:Resume(nome)
	elseif Soundity:soundExists(nome) then
		Soundity:Pause(nome)
	end
	local iss = nil
	for i = 1, #Zones do
		local v = Zones[i]
		if v.name == nome then
			if v.popo then
				iss = i
			end
			v.isplaying = tipo
		end
	end
	if tipo and iss then
		addSoundLoop(iss)
	elseif iss then
		for i = 1, #SoundsPlaying do
			local v = SoundsPlaying[i]
			if v == iss then
				table.remove(SoundsPlaying, i)
			end
		end
	end
end)

RegisterNetEvent("carmusic:ChangePosition")
AddEventHandler("carmusic:ChangePosition", function(quanti, nome)
	local tempapply
	for i = 1, #Zones do
		local v = Zones[i]
		if v.name == nome then
			v.deftime = v.deftime + quanti
			if v.deftime < 0 then
				v.deftime = 0
			end
			tempapply = v.deftime
		end
	end
	if Soundity:soundExists(nome) then
		Soundity:setTimeStamp(nome,tempapply)
	end
end)

RegisterNetEvent("carmusic:ChangeLoop")
AddEventHandler("carmusic:ChangeLoop", function(tipo, nome)
	if Soundity:soundExists(nome) then
		Soundity:setSoundLoop(nome,tipo)
	end
	for i = 1, #Zones do
		local v = Zones[i]
		if v.name == nome then
			v.loop = tipo
		end
	end
end)

RegisterNetEvent("carmusic:ChangeVolume")
AddEventHandler("carmusic:ChangeVolume", function(som, range, nome)
	local carroe
	local crds
    for i = 1, #Zones do
        local v = Zones[i]
        if nome == v.name then
            v.volume = som
            v.range = range
			carroe = v.popo
			crds = v.coords
        end
    end
	if Soundity:soundExists(nome) then
		-- Do NOT call Soundity:Distance here — the loop pins it to MaxAudioDistance.
		-- We just let applyInteriorAudioProfile handle volume on next tick.
		if not carroe and crds then
			Soundity:setVolumeMax(nome,som)
		end
	end
end)

function countTime()
    SetTimeout(2000, countTime)
    for i = 1, #Zones do
		local v = Zones[i]
		if v.isplaying then
			v.deftime = v.deftime + 2
		end
    end
end

SetTimeout(2000, countTime)

RegisterNetEvent("carmusic:SendData")
AddEventHandler("carmusic:SendData", function(data)
    Zones = data
    for i = 1, #Zones do
		local v = Zones[i]
		if v.isplaying then
			if Soundity:soundExists(v.name) then
				Soundity:Destroy(v.name)
			end
			local avancartodos = v.volume
			if not Config.PlayToEveryone and v.popo then
				avancartodos = 0.0
				local popodentro = GetVehiclePedIsIn(PlayerPedId(),false)
				local plate = GetVehicleNumberPlateText(popodentro)
				if plate == v.name then
					avancartodos = v.volume
				end
			end
			Soundity:PlayUrlPos(v.name, v.deflink, avancartodos, v.coords, v.loop,
			{
				onPlayStart = function(event)
					Soundity:setTimeStamp(v.name, v.deftime)
					Soundity:Distance(v.name, Config.MaxAudioDistance or 130.0)
				end,
				})
				if v.popo then
					addSoundLoop(i)
				end
			end
    end
end)

local plpedloop
local pploop
local coordsped

Citizen.CreateThread(function()
	local poschanged = true
	while true do
		Wait(750)
		plpedloop = PlayerPedId()
		pploop = GetVehiclePedIsIn(plpedloop,false)
		coordsped = GetEntityCoords(plpedloop)
	end
end)

function StartMusicLoop(i)
	while not Soundity:soundExists(Zones[i].name) do
		Wait(10)
	end

	-- Immediately pin Soundity's own distance cutoff to MaxAudioDistance so it
	-- NEVER fires its built-in hard-stop. We do all attenuation ourselves.
	local initName = Zones[i].name
	local maxDist = (Config.MaxAudioDistance or 130.0)
	Soundity:Distance(initName, maxDist)

	Citizen.CreateThread(function()
		local poschanged = true
		while true do
			local sleep = 90
			local v = Zones[i]
			if v == nil then return end

			if v.isplaying and Soundity:soundExists(v.name) then
				local carrofound = false

				if NetworkDoesEntityExistWithNetworkId(v.popo) then
					local carro = NetworkGetEntityFromNetworkId(v.popo)
					if DoesEntityExist(carro) and GetEntityType(carro) == 2
					   and GetVehicleNumberPlateText(carro) == v.name then

						carrofound = true
						Soundity:setAttachedEntity(v.name, v.popo)
						local cordsveh  = GetEntityCoords(carro)
						local geraldist = #(cordsveh - coordsped)
						local speedcar  = GetEntitySpeed(carro) * 3.6
						local openFactor, numOpenings = getVehicleOpenFactor(carro)

						-- Keep Soundity's own distance fence well beyond our soft range
						-- so it never interferes. Update it dynamically too.
						local softMax = (Config.BaseRangeClosed or 18.0)
						              + ((numOpenings or 0) * (Config.RangePerOpening or 16.0))
						local soundityFence = math.min(maxDist, softMax + 40.0)
						Soundity:Distance(v.name, soundityFence)

						local dina = Soundity:isDynamic(v.name)

						if pploop == carro then
							-- ── Inside this vehicle ──────────────────────────────────
							if dina then Soundity:setSoundDynamic(v.name, false) end
							applyInteriorAudioProfile(v.name, v.volume, geraldist, true, openFactor, numOpenings, speedcar)

							local getposdif = #(v.coords - cordsveh)
							if getposdif >= 5.0 or poschanged then
								poschanged = false
								v.coords = cordsveh
								Soundity:Position(v.name, cordsveh)
							else
								sleep = sleep + 150
							end

						elseif geraldist <= maxDist then
							-- ── Outside, within absolute max distance ────────────────
							if not dina then Soundity:setSoundDynamic(v.name, true) end
							applyInteriorAudioProfile(v.name, v.volume, geraldist, false, openFactor, numOpenings, speedcar)

							-- Position update — less frequent when far away and slow
							local getposdif = #(v.coords - cordsveh)
							if getposdif >= 1.0 or poschanged then
								poschanged = false
								v.coords = cordsveh
								Soundity:Position(v.name, cordsveh)
							else
								sleep = sleep + 90
							end

							-- Stretch sleep when far and moving slowly (saves CPU)
							if geraldist > softMax + 10 then
								sleep = math.max(sleep, math.min(1200, geraldist * 12))
							end
							if sleep <= 1400 then
								if speedcar <= 2.0 then sleep = sleep + 240
								elseif speedcar <= 5.0 then sleep = sleep + 150
								elseif speedcar <= 10.0 then sleep = sleep + 80
								end
							end

						else
							-- ── Beyond absolute max — silence without cutting position ──
							-- We soft-zero volume here; applyInteriorAudioProfile will
							-- smoothly bring it to 0 rather than snapping.
							if not dina then Soundity:setSoundDynamic(v.name, true) end
							applyInteriorAudioProfile(v.name, v.volume, geraldist, false, openFactor, numOpenings, speedcar)
							sleep = math.min(1400, math.max(200, geraldist * 10))
						end
					end
				else
					-- Network entity missing — soft-zero, don't destroy
					if Soundity:soundExists(v.name) then
						Soundity:setVolumeMax(v.name, 0.0)
						Wait(150)
					end
				end

				if not carrofound and Soundity:soundExists(v.name) then
					if not Soundity:isDynamic(v.name) then
						Soundity:setSoundDynamic(v.name, true)
					end
					if not poschanged then
						Soundity:Position(v.name, vector3(350.0, 0.0, -150.0))
						poschanged = true
					end
					Wait(400)
				end

			else
				-- Sound stopped / paused — clean up this loop
				if Soundity:soundExists(v.name) then
					if not Soundity:isDynamic(v.name) then
						Soundity:setSoundDynamic(v.name, true)
					end
					Soundity:setVolumeMax(v.name, 0.0)
					if not poschanged then
						Soundity:Position(v.name, vector3(350.0, 0.0, -150.0))
						poschanged = true
					end
				end
				v.isplaying = false
				for j = 1, #SoundsPlaying do
					if SoundsPlaying[j] == i then
						table.remove(SoundsPlaying, j)
						break
					end
				end
				break
			end

			sleep = math.max(80, math.min(1400, sleep))
			Wait(sleep)
		end
	end)
end

-- ============================================================
-- ACOUSTIC ENGINE v3
--
-- Design goals:
--   1. ZERO hard cuts — volume always fades to 0 smoothly via
--      exponential smoothing, never a snap.
--   2. Soundity's own Distance() is kept at MaxAudioDistance so
--      Soundity never fires its built-in cutoff. WE own attenuation.
--   3. openFactor (0.0–1.0) is smoothed frame-to-frame so a
--      door swinging open/closed sounds continuous.
--   4. Range = BaseRangeClosed + numOpenings * RangePerOpening
--      (fully configurable in config.lua).
--   5. Muffle simulation: closed car → low volFactor AND
--      an additional muffleFactor that pulls volume toward
--      Config.MuffleFloor, giving a "bass thump through metal" feel.
--      As car opens, muffle fades out → bright full sound.
--   6. Exit fade uses cubic ease-in-out over Config.ExitFadeDuration.
-- ============================================================

-- ----------------------------------------------------------------
-- getVehicleOpenFactor(vehicle)
-- Returns:
--   openFactor  (float 0.0–1.0)  — how acoustically open the car is
--   numOpenings (int)             — discrete count for range calc
-- ----------------------------------------------------------------
function getVehicleOpenFactor(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return 0.0, 0
	end

	local model  = GetEntityModel(vehicle)
	local seats  = GetVehicleModelNumberOfSeats(model)
	local maxWin = seats <= 2 and 1 or 3

	local totalWeight = 0.0
	local totalLeak   = 0.0
	local numOpenings = 0

	-- Windows: weight 1.0, broken/missing = full leak
	for w = 0, maxWin do
		totalWeight = totalWeight + 1.0
		if not IsVehicleWindowIntact(vehicle, w) then
			totalLeak   = totalLeak + 1.0
			numOpenings = numOpenings + 1
		end
	end

	-- Doors: weight 2.0, use actual angle ratio for continuous response
	-- curve: angle^0.72 so a door at 30% feels like ~25%, 50% feels ~44%
	for d = 0, 5 do
		if not IsVehicleDoorDamaged(vehicle, d) then
			local angle = GetVehicleDoorAngleRatio(vehicle, d) -- 0→1
			totalWeight = totalWeight + 2.0
			if angle > 0.02 then
				local doorLeak = math.pow(angle, 0.72)
				totalLeak   = totalLeak + (doorLeak * 2.0)
				-- Count as a discrete opening once it's meaningfully ajar
				if angle > 0.08 then
					numOpenings = numOpenings + 1
				end
			end
		end
	end

	local openFactor = totalWeight > 0
	                   and math.min(1.0, totalLeak / totalWeight)
	                   or 0.0
	return openFactor, math.min(4, numOpenings)
end

-- ----------------------------------------------------------------
-- applyInteriorAudioProfile
--
-- soundName     : Soundity sound id
-- baseVolume    : the user-set volume (0-1)
-- distToVehicle : metres between listener and car
-- inSameVehicle : bool
-- openFactor    : raw 0-1 from getVehicleOpenFactor
-- numOpenings   : 0-4 discrete count for range calculation
-- vehicleSpeed  : km/h
-- ----------------------------------------------------------------
function applyInteriorAudioProfile(soundName, baseVolume, distToVehicle, inSameVehicle, openFactor, numOpenings, vehicleSpeed)
	if not Soundity:soundExists(soundName) then return end

	local profile   = interiorSoundState[soundName] or {}
	local currentMs = GetGameTimer()

	-- ── 1. Smooth openFactor (door swing feels analog, not stepped) ──
	local prevOpen  = profile.smoothedOpenFactor or openFactor
	-- Opening is faster (door flies open), closing is slower (damped swing)
	local oAlpha    = openFactor > prevOpen and 0.16 or 0.09
	local smoothOpen = prevOpen + ((openFactor - prevOpen) * oAlpha)
	profile.smoothedOpenFactor = smoothOpen

	-- ── 2. Effective hearing range ────────────────────────────────────
	local baseClosed  = Config.BaseRangeClosed  or 18.0
	local perOpening  = Config.RangePerOpening  or 16.0
	-- Range scales with discrete openings (so 1 door = more range than 0)
	-- but we also interpolate within that via smoothOpen for sub-step smoothness
	local discreteRange  = baseClosed + (numOpenings * perOpening)
	local continuousRange = baseClosed + (smoothOpen * 4.0 * perOpening)
	-- Blend: 70% discrete (snappy per door), 30% continuous (smooth within)
	local effectiveRange = (discreteRange * 0.70) + (continuousRange * 0.30)
	effectiveRange = math.max(8.0, effectiveRange)

	-- ── 3. Compute target volume ──────────────────────────────────────
	local targetVolume

	if inSameVehicle then
		-- Inside: always full volume from the speakers.
		-- Tiny +warmth when windows closed (cabin resonance).
		local warmth = 1.0 - (smoothOpen * 0.035)
		targetVolume = baseVolume * warmth

	else
		local closedLeak = Config.ClosedLeakVolume or 0.07
		local muffleFloor = Config.MuffleFloor     or 0.45

		-- volFactor: from closedLeak when sealed → 1.0 when fully open
		-- power curve so even a small opening causes a noticeable jump
		-- (cracking a door lets sound escape immediately)
		local volFactor = closedLeak + (smoothOpen * (1.0 - closedLeak))
		volFactor = math.pow(volFactor, 0.60)   -- compress: opening matters early

		-- Distance attenuation within effective range
		-- Use a softer curve (exponent < 1) so attenuation starts gentle
		-- and only becomes aggressive near the edge → no sudden cutoff feel
		local distRatio = math.max(0.0, 1.0 - (distToVehicle / effectiveRange))
		-- Blend two curves: linear falloff (harsh) vs sqrt (gentle)
		-- → sqrt at close range, linear at far range
		local distFactor = (math.pow(distRatio, 0.80) * 0.55)
		                 + (distRatio * 0.45)
		distFactor = math.max(0.0, distFactor)

		-- Muffle simulation: low smoothOpen → pull volume toward muffleFloor
		-- This simulates that only bass frequencies escape a closed car.
		-- At smoothOpen 0.0 → muffleFactor = muffleFloor (heavy bass-only feel)
		-- By smoothOpen 0.4 → muffleFactor = 1.0 (fully bright)
		local muffleBlend  = math.max(0.0, 1.0 - (smoothOpen / 0.38))  -- linear 0→0.38
		local muffleFactor = 1.0 - (muffleBlend * (1.0 - muffleFloor))

		-- Speed shimmer: engine + exhaust carry sound in micro-pulses
		local shimmer = 1.0 + (math.min(0.035, (vehicleSpeed or 0.0) / 450.0)
		               * math.abs(math.sin(currentMs / 310.0)))

		targetVolume = baseVolume * volFactor * distFactor * muffleFactor * shimmer
		targetVolume = math.min(baseVolume, targetVolume)
	end

	-- ── 4. Entry / exit crossfade ─────────────────────────────────────
	if profile.wasInside == nil then
		profile.wasInside = inSameVehicle
	end

	if profile.wasInside and not inSameVehicle then
		-- Stepped out: record exact volume at exit moment, crossfade out
		profile.exitStartVol         = profile.smoothedVolume or baseVolume
		profile.exitTransitionUntil  = currentMs + math.floor((Config.ExitFadeDuration or 2.8) * 1000)
	elseif (not profile.wasInside) and inSameVehicle then
		-- Got in: quick snap to inside volume
		profile.enterTransitionUntil = currentMs + 850
	end
	profile.wasInside = inSameVehicle

	if profile.exitTransitionUntil and currentMs < profile.exitTransitionUntil then
		local fadeDur = (Config.ExitFadeDuration or 2.8) * 1000
		local t = 1.0 - ((profile.exitTransitionUntil - currentMs) / fadeDur)
		-- Cubic ease-in-out: slow start, fast middle, slow end
		t = t * t * (3.0 - 2.0 * t)
		local fromVol = profile.exitStartVol or baseVolume
		targetVolume  = fromVol + ((targetVolume - fromVol) * t)
	elseif profile.enterTransitionUntil and currentMs < profile.enterTransitionUntil then
		local t = 1.0 - ((profile.enterTransitionUntil - currentMs) / 850.0)
		t = t * t * (3.0 - 2.0 * t)
		local insideVol = baseVolume * 0.995
		targetVolume = targetVolume + ((insideVol - targetVolume) * t)
	end

	-- ── 5. Exponential smoothing — eliminates ALL twitching ──────────
	local smoothedVolume = profile.smoothedVolume or targetVolume
	-- Inside: slightly faster (speakers are right there)
	-- Outside: slower (acoustic space has natural inertia)
	local alpha = inSameVehicle and 0.22 or 0.11
	smoothedVolume = smoothedVolume + ((targetVolume - smoothedVolume) * alpha)
	profile.smoothedVolume = smoothedVolume

	-- ── 6. Push update only when audibly different (>0.4%) ───────────
	if not profile.lastVolume or math.abs(profile.lastVolume - smoothedVolume) > 0.004 then
		if inSameVehicle then
			Soundity:setVolume(soundName, smoothedVolume)
		else
			Soundity:setVolumeMax(soundName, smoothedVolume)
		end
		profile.lastVolume = smoothedVolume
	end

	interiorSoundState[soundName] = profile
end

function DrawText3D(x, y, z, text,r,g,b,a)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
	if r and g and b and a then
		SetTextColour(r, g, b, a)
	else
		SetTextColour(255, 255, 255, 215)
	end
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local availableRadios = {
    ["RADIO_01_CLASS_ROCK"] = true,
    ["RADIO_02_POP"] = true,
    ["RADIO_03_HIPHOP_NEW"] = true,
    ["RADIO_04_PUNK"] = true,
    ["RADIO_05_TALK_01"] = true,
    ["RADIO_06_COUNTRY"] = true,
    ["RADIO_07_DANCE_01"] = true,
    ["RADIO_08_MEXICAN"] = true,
    ["RADIO_09_HIPHOP_OLD"] = true,
    ["RADIO_12_REGGAE"] = true,
    ["RADIO_13_JAZZ"] = true,
    ["RADIO_14_DANCE_02"] = true,
    ["RADIO_15_MOTOWN"] = true,
    ["RADIO_16_SILVERLAKE"] = true,
    ["RADIO_17_FUNK"] = true,
    ["RADIO_18_90S_ROCK"] = true,
    ["RADIO_19_USER"] = true,
    ["RADIO_20_THELAB"] = true,
    ["RADIO_11_TALK_02"] = true,
    ["RADIO_21_DLC_XM17"] = true,
    ["RADIO_22_DLC_BATTLE_MIX1_RADIO"] = true
}

local customRadios = {}
local isPlaying = false;
local index = -1;
local volume = GetProfileSetting(306) / 10
local previousVolume = volume;

for k = 0, GetNumResourceMetadata("carmusic", "supersede_radio") do
    if k < GetNumResourceMetadata("carmusic", "supersede_radio") then
        local radio = GetResourceMetadata("carmusic", "supersede_radio", k)
        if not availableRadios[radio] then
            print("radio: "..radio.." este invalid!")
        else
            local data = json.decode(GetResourceMetadata("carmusic", "supersede_radio_extra", k))
            if data ~= nil then
                customRadios[k] = {isPlaying = false, name = radio, data = data}
            end
            if data.name then
                AddTextEntry(radio, data.name)
            else
                print("radio: nu s-au gasit datele pentru "..radio)
            end
        end
    end
end

RegisterNuiCallbackType("radio:ready")
AddEventHandler("__cfx_nui:radio:ready", function(data,cb)
    SendNuiMessage(json.encode({
        type = "_createRadio",
        radios = customRadios,
        volume = volume
    }))
    previousVolume = -1
    print("radio - nui Ready")
end)

SendNuiMessage(json.encode({
     type = "_createRadio",
    radios = customRadios,
    volume = volume
}))
print("radio - nui Ready 2")

function ToggleCustomRadioBehavior()
    SetFrontendRadioActive(not isPlaying)
    if isPlaying then
        StartAudioScene("DLC_MPHEIST_TRANSITION_TO_APT_FADE_IN_RADIO_SCENE")
    else
        StopAudioScene("DLC_MPHEIST_TRANSITION_TO_APT_FADE_IN_RADIO_SCENE")
    end
end

function PlayCustomRadio(radio)
    isPlaying = true
    for k,v in pairs(customRadios) do
       if v == radio then
            index = k
            ToggleCustomRadioBehavior()
            SendNuiMessage(json.encode({
                type = "_playRadio",
                radio = tostring(k),
				name = v.data.name
            }))
            print("radio - nui Play")
       end
    end
end

function StopCustomRadios()
    isPlaying = false
    ToggleCustomRadioBehavior()
    SendNuiMessage(json.encode({
        type = "_stopRadio"
    }))
    print("radio - nui Stop")
end

local function findRadio(Radio)
    for k,v in pairs(customRadios) do
        if v.name == Radio then
            return v,k
        end
    end
    return nil,nil
end

RegisterCommand("removeQ",function()
	if GetVehiclePedIsIn(PlayerPedId()) ~= 0 then
		customSong = false
	end
end)

RegisterKeyMapping("removeQ","Nu umbla","keyboard","Q")

Citizen.CreateThread(function()
    while true do
        Wait(350)
        if not customSong then
            local playerRadioEnabled = IsPlayerVehicleRadioEnabled()
            local playerRadioStationName = playerRadioEnabled and GetPlayerRadioStationName() or ""
            local customRadio, customRadioIndex = findRadio(playerRadioStationName)

            if (not isPlaying and customRadio ~= nil) or (isPlaying and customRadio ~= nil and customRadioIndex ~= index) then
                StopCustomRadios()
                PlayCustomRadio(customRadio)
            elseif isPlaying and customRadio == nil then
                StopCustomRadios()
            end

            local currentVolume = GetProfileSetting(306) / 10
            if previousVolume ~= currentVolume then
                SendNuiMessage(json.encode({
                    type = "_volumeRadio",
                    volume = currentVolume
                }))
                print("radio - nui Volume")
                previousVolume = currentVolume
            end
        elseif isPlaying then
            StopCustomRadios()
        end
    end
end)

Citizen.CreateThread(function()
	while true do
		Wait(200)
		local ped = PlayerPedId()
		if IsPedInAnyVehicle(ped, false) then
			local veh = GetVehiclePedIsIn(ped, false)
			local plate = GetVehicleNumberPlateText(veh)
			local hasCarRadio = Soundity:soundExists(plate)
			if customSong or hasCarRadio then
				SetVehRadioStation(veh, "OFF")
				SetVehicleRadioEnabled(veh, false)
				SetUserRadioControlEnabled(false)
			else
				SetVehicleRadioEnabled(veh, true)
				SetUserRadioControlEnabled(true)
			end
		else
			SetUserRadioControlEnabled(true)
		end
	end
end)
