modifying = false
local Music = {}
local vRP = Proxy.getInterface("vRP")
Tunnel.bindInterface("xradio_music",Music)
local datasoundinfo = {}
local nuiaberto = false
local standaloneAudioState = {}
local function nowMs()
	return GetGameTimer()
end

local function syncStandaloneSound(name)
	local state = standaloneAudioState[name]
	if not state then return end
	SendNUIMessage({
		action = "carplayAudio",
		cmd = "upsert",
		name = name,
		url = state.url,
		position = { x = state.pos.x, y = state.pos.y, z = state.pos.z },
		volume = state.baseVolume,
		maxVolume = state.maxVolume,
		range = state.range,
		loop = state.loop,
		paused = state.paused,
		dynamic = state.dynamic
	})
end

xSound = {
	soundExists = function(self, name) return standaloneAudioState[name] ~= nil end,
	isPaused = function(self, name) return standaloneAudioState[name] and standaloneAudioState[name].paused or false end,
	isPlaying = function(self, name) return standaloneAudioState[name] and not standaloneAudioState[name].paused or false end,
	getMaxDuration = function(self, name) return 0.0 end,
	getTimeStamp = function(self, name)
		local state = standaloneAudioState[name]
		if not state then return 0.0 end
		if state.paused then return state.timestamp end
		return state.timestamp + ((nowMs() - state.lastResumeMs) / 1000.0)
	end,
	getVolume = function(self, name) return standaloneAudioState[name] and standaloneAudioState[name].maxVolume or 0.0 end,
	Destroy = function(self, name)
		standaloneAudioState[name] = nil
		SendNUIMessage({ action = "carplayAudio", cmd = "destroy", name = name })
		return true
	end,
	isLooped = function(self, name) return standaloneAudioState[name] and standaloneAudioState[name].loop or false end,
	getLink = function(self, name) return standaloneAudioState[name] and standaloneAudioState[name].url or nil end,
	isDynamic = function(self, name) return standaloneAudioState[name] and standaloneAudioState[name].dynamic or false end,
	getPosition = function(self, name) return standaloneAudioState[name] and standaloneAudioState[name].pos or vector3(0.0, 0.0, 0.0) end,
	setTimeStamp = function(self, name, value)
		local state = standaloneAudioState[name]
		if not state then return false end
		state.timestamp = value or 0.0
		state.lastResumeMs = nowMs()
		SendNUIMessage({ action = "carplayAudio", cmd = "seek", name = name, value = state.timestamp })
		return true
	end,
	Distance = function(self, name, value)
		local state = standaloneAudioState[name]
		if not state then return false end
		state.range = value
		syncStandaloneSound(name)
		return true
	end,
	setSoundDynamic = function(self, name, value)
		local state = standaloneAudioState[name]
		if not state then return false end
		state.dynamic = value and true or false
		syncStandaloneSound(name)
		return true
	end,
	setVolume = function(self, name, value)
		local state = standaloneAudioState[name]
		if not state then return false end
		state.baseVolume = value
		state.maxVolume = value
		SendNUIMessage({ action = "carplayAudio", cmd = "setVolume", name = name, value = value })
		return true
	end,
	setVolumeMax = function(self, name, value)
		local state = standaloneAudioState[name]
		if not state then return false end
		state.maxVolume = value
		SendNUIMessage({ action = "carplayAudio", cmd = "setVolumeMax", name = name, value = value })
		return true
	end,
	setSoundURL = function(self, name, url)
		local state = standaloneAudioState[name]
		if not state then return false end
		state.url = url
		state.timestamp = 0.0
		state.lastResumeMs = nowMs()
		SendNUIMessage({ action = "carplayAudio", cmd = "setUrl", name = name, url = url })
		return true
	end,
	Position = function(self, name, pos)
		local state = standaloneAudioState[name]
		if not state then return false end
		state.pos = pos
		SendNUIMessage({ action = "carplayAudio", cmd = "setPosition", name = name, position = { x = pos.x, y = pos.y, z = pos.z } })
		return true
	end,
	setSoundLoop = function(self, name, value)
		local state = standaloneAudioState[name]
		if not state then return false end
		state.loop = value and true or false
		SendNUIMessage({ action = "carplayAudio", cmd = "setLoop", name = name, value = state.loop })
		return true
	end,
	setFx = function(self, name, fxData)
		local state = standaloneAudioState[name]
		if not state then return false end
		SendNUIMessage({ action = "carplayAudio", cmd = "setFx", name = name, value = fxData or {} })
		return true
	end,
	setSubmixPreset = function(self, name, preset)
		local presets = {
			inside = { lowGain = 2.5, midGain = -1.2, highGain = -2.8, threshold = -22, ratio = 2.6 },
			outside = { lowGain = -1.0, midGain = -2.0, highGain = -4.0, threshold = -24, ratio = 3.2 },
			flat = { lowGain = 0.0, midGain = 0.0, highGain = 0.0, threshold = -20, ratio = 3.0 }
		}
		return self:setFx(name, presets[preset] or presets.flat)
	end,
	PlayUrlPos = function(self, name, url, vol, coords, loop, options)
		standaloneAudioState[name] = {
			url = url,
			pos = coords,
			baseVolume = vol or 0.2,
			maxVolume = vol or 0.2,
			range = 35.0,
			loop = loop and true or false,
			paused = false,
			dynamic = true,
			timestamp = 0.0,
			lastResumeMs = nowMs()
		}
		syncStandaloneSound(name)
		if options and options.onPlayStart then
			CreateThread(function()
				Wait(25)
				options.onPlayStart({})
			end)
		end
		return true
	end,
	Resume = function(self, name)
		local state = standaloneAudioState[name]
		if not state then return false end
		state.paused = false
		state.lastResumeMs = nowMs()
		SendNUIMessage({ action = "carplayAudio", cmd = "resume", name = name })
		return true
	end,
	Pause = function(self, name)
		local state = standaloneAudioState[name]
		if not state then return false end
		state.timestamp = state.timestamp + ((nowMs() - state.lastResumeMs) / 1000.0)
		state.paused = true
		SendNUIMessage({ action = "carplayAudio", cmd = "pause", name = name })
		return true
	end,
}
local myjob = nil
local nomidaberto
local SoundsPlaying = {}
local customSong = false
local interiorSoundState = {}

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
--[[RegisterCommand("mota",function()
	TriggerServerEvent("carmusic:ModifyURL",{})
	TriggerServerEvent("carmusic:AddVehicle",{})
end)]]

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
		ApplySound(0.20,nameid,true)
		SetUrl(data.link,nameid)
		if xSound:soundExists(nameid) and xSound:isPaused(nameid) then
			TriggerServerEvent("carmusic:ChangeState", true, nameid)
		end
		customSong = true
	elseif data.action == "numemelodie" then
		vRP.notify({"Se reda acum: "..data.nume,"info"})
	elseif data.action == "faauzit" then
		ApplySound(0.9,nameid)
	elseif data.action == "play" then
		if xSound:soundExists(nameid) and xSound:isPaused(nameid) then
			TriggerServerEvent("carmusic:ChangeState", true, nameid)
		end
	elseif data.action == "pause" then
		if xSound:soundExists(nameid) and xSound:isPlaying(nameid) then
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
		if xSound:soundExists(nameid) then
			datasoundinfo.loop = not xSound:isLooped(nameid)
			TriggerServerEvent("carmusic:ChangeLoop",nameid,datasoundinfo.loop)
		else
			datasoundinfo.loop = not datasoundinfo.loop
		end
		if type(datasoundinfo.loop) ~= "table" then
			local loop = ('Looping: '.. firstToUpper(tostring(datasoundinfo.loop)))
			-- SendNUIMessage({
			-- 	action = "changetextl",
			-- 	text = loop,
			-- })
			vRP.notify({"Mod repeat: On"})
			--TriggerEvent("nzv:notify", loop)
		end
	elseif data.action == "forward" then
		if xSound:soundExists(nameid) then
			TriggerServerEvent("carmusic:ChangePosition", 10, nameid)
		end
	elseif data.action == "back" then
		if xSound:soundExists(nameid) then
			TriggerServerEvent("carmusic:ChangePosition", -10, nameid)
		end
	end
end)

function ApplySound(quanti,plate,set)
	local exis = false
	local som = datasoundinfo.volume
	if xSound:soundExists(plate) and xSound:isPlaying(plate) then
		exis = true
		som = xSound:getVolume(plate)
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
	if xSound:soundExists(nome) then
		SendNUIMessage({
			action = "TimeVid",
			total = xSound:getMaxDuration(nome),
			played = xSound:getTimeStamp(nome),
		})
	end
	local esperar = 0
	while nuiaberto do
		Wait(1000)
		if xSound:soundExists(nome) then
			if xSound:isPlaying(nome) then
				SendNUIMessage({
					action = "TimeVid",
					total = xSound:getMaxDuration(nome),
					played = xSound:getTimeStamp(nome),
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
		if xSound:soundExists(nome) then
			datasoundinfo.volume = xSound:getVolume(nome)
			datasoundinfo.loop = xSound:isLooped(nome)
			if xSound:isPlaying(nome) then
				linkurl = xSound:getLink(nome)
			end
		end
        SetNuiFocus(true, true)
		local volume = ('Volume: '.. math.floor((datasoundinfo.volume*100) - 0.1+1).."%")
		if type(datasoundinfo.loop) ~= "table" then
			local loop = ('Looping: '.. firstToUpper(tostring(datasoundinfo.loop)))
			-- SendNUIMessage({
			-- 	action = "changetextl",
			-- 	text = loop,
			-- })
			vRP.notify({"Mod repeat: Off"})
			--TriggerEvent("nzv:notify", loop)
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
		if xSound:soundExists(nome) then
			SendNUIMessage({
				action = "TimeVid",
				total = xSound:getMaxDuration(nome),
				played = xSound:getTimeStamp(nome),
			})
		end
		local esperar = 0
		while nuiaberto do
			Wait(1000)
			if xSound:soundExists(nome) then
				if xSound:isPlaying(nome) then
					SendNUIMessage({
						action = "TimeVid",
						total = xSound:getMaxDuration(nome),
						played = xSound:getTimeStamp(nome),
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
		-- nomidaberto = nil
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
	if xSound:soundExists(v.name) then
		xSound:Destroy(v.name)
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
			while (xSound:soundExists(v.name) and DoesEntityExist(networked_veh)) do Wait(512)
				local ped = PlayerPedId()
				local coords = GetEntityCoords(ped)
				local veh_coords = GetEntityCoords(networked_veh)
				if #(coords - veh_coords) >= 30 then
					if xSound:soundExists(v.name) then
						xSound:Destroy(v.name)
					end
				end
			end
		end)
	end
	xSound:PlayUrlPos(v.name, v.deflink, avancartodos, v.coords, v.loop,{
		onPlayStart = function(event)
			xSound:setTimeStamp(v.name, v.deftime)
			xSound:Distance(v.name,v.range)
		end,
	})
	addSoundLoop(#Zones)
end)

-- RegisterCommand("testSong",function()
-- 	TriggerEvent("carmusic:AddVehicle",{
-- 		name = "testMasa",
-- 		volume = 10.0,
-- 		deflink = "https://www.youtube.com/watch?v=tiUb_Gwvt60",
-- 		coords = GetEntityCoords(PlayerPedId()),
-- 		loop = true,
-- 		deftime = 0,
-- 		range = 10000.0,
-- 		popo = false,
-- 		isplaying = true
-- 	})
-- end)

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
	if xSound:soundExists(v.name) then
		if not xSound:isDynamic(v.name) then
			xSound:setSoundDynamic(v.name,true)
		end
		Wait(100)
		xSound:setVolumeMax(v.name,0.0)
		xSound:setSoundURL(v.name, v.deflink)
		Wait(100)
		xSound:Position(v.name, v.coords)
		xSound:setSoundLoop(v.name,v.loop)
		Wait(200)
		xSound:setTimeStamp(v.name,0)
		xSound:setVolumeMax(v.name,avancartodos)
									 
	else
		xSound:PlayUrlPos(v.name, v.deflink, avancartodos, v.coords, v.loop, {
			onPlayStart = function(event)
				xSound:setTimeStamp(v.name, v.deftime)
				xSound:Distance(v.name,v.range)
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
		if xSound:soundExists(v.name) then
			local pped = PlayerPedId()
			local coordss = GetEntityCoords(pped)
			local geraldist = #(coordss-xSound:getPosition(v.name))
			if xSound:isPlaying(v.name) and (geraldist <= 3 or not v.popo) then
				SendNUIMessage({
					action = "TimeVid",
					total = xSound:getMaxDuration(v.name),
					played = xSound:getTimeStamp(v.name),
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
	if tipo and xSound:soundExists(nome) then
		xSound:Resume(nome)
	elseif xSound:soundExists(nome) then
		xSound:Pause(nome)
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
	if xSound:soundExists(nome) then
		xSound:setTimeStamp(nome,tempapply)
	end
end)

RegisterNetEvent("carmusic:ChangeLoop")
AddEventHandler("carmusic:ChangeLoop", function(tipo, nome)
	if xSound:soundExists(nome) then
		xSound:setSoundLoop(nome,tipo)
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
	if xSound:soundExists(nome) then
		xSound:Distance(nome,range)
		if not carroe and crds then
			xSound:setVolumeMax(nome,som)
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
			if xSound:soundExists(v.name) then
				xSound:Destroy(v.name)
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
			xSound:PlayUrlPos(v.name, v.deflink, avancartodos, v.coords, v.loop,
			{
				onPlayStart = function(event)
					xSound:setTimeStamp(v.name, v.deftime)
					xSound:Distance(v.name,v.range)
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
	while not xSound:soundExists(Zones[i].name) do
		Wait(10)
	end
	Citizen.CreateThread(function()
		local poschanged = true
		while true do
			local sleep = 100
			local v = Zones[i]
			if v == nil then
				return
			end
			if v.isplaying and xSound:soundExists(v.name) then
				local carrofound = false
				if NetworkDoesEntityExistWithNetworkId(v.popo)then
					local carro = NetworkGetEntityFromNetworkId(v.popo)
					if DoesEntityExist(carro) then
						if GetEntityType(carro) == 2 then
							if GetVehicleNumberPlateText(carro) == v.name then
									carrofound = true
									local cordsveh = GetEntityCoords(carro)
									local geraldist = #(cordsveh-coordsped)
									local speedcar = GetEntitySpeed(carro)*3.6
									local cabinIsolation, totalLeak, openings = getVehicleAcousticData(carro)
									if geraldist <= v.range+50 then
									local avolume = xSound:getVolume(v.name)
									local dina = xSound:isDynamic(v.name)
									local getpos = v.coords
									local getposdif = #(getpos-cordsveh)
									if avolume <= 0.001 then
										sleep = 1000
									end
									if pploop == carro then
										if dina then
											xSound:setSoundDynamic(v.name,false)
										end
											applyInteriorAudioProfile(v.name, v.volume, geraldist, true, cabinIsolation, totalLeak, openings, speedcar, v.range)
										if getposdif >= 5.0 or poschanged then
											poschanged = false
											v.coords = cordsveh
											xSound:Position(v.name, cordsveh)
										else
											sleep = sleep+150
										end
									else	
										if not dina then
											xSound:setSoundDynamic(v.name,true)
										end
											applyInteriorAudioProfile(v.name, v.volume, geraldist, false, cabinIsolation, totalLeak, openings, speedcar, v.range)
											if geraldist >= v.range+20 then
												sleep = math.max(sleep, (geraldist*25)/3)
											end
											if sleep <= 1500 then
												if speedcar <= 2.0 then
													sleep = sleep+260
												elseif speedcar <= 5.0 then
													sleep = sleep+170
												elseif speedcar <= 10.0 then
													sleep = sleep+90
												end
											end
										if getposdif >= 1.0 or poschanged then
											poschanged = false
											v.coords = cordsveh
											xSound:Position(v.name, cordsveh)
										else
												sleep = sleep+90
											end
										end
									else
									if not xSound:isDynamic(v.name) then
										xSound:setSoundDynamic(v.name,true)
									end
									xSound:setVolumeMax(v.name,0.0)
									if not poschanged then
										xSound:Position(v.name, vector3(350.0,0.0,-150.0))
										poschanged = true
									end
										sleep = math.max(120, (geraldist*20)/2)
								end
							end
						end
					end
					else
						if xSound:soundExists(v.name) then
							-- avoid interrupting playback on short network entity desync
							xSound:setVolumeMax(v.name,0.0)
								Wait(150)
						end
					end
				if not carrofound and xSound:soundExists(v.name) then
					if not xSound:isDynamic(v.name) then
						xSound:setSoundDynamic(v.name,true)
					end
					--xSound:setVolumeMax(v.name,0.0)
					if not poschanged then
						xSound:Position(v.name, vector3(350.0,0.0,-150.0))
						poschanged = true
					end
						Wait(450)
				end
			else
				if xSound:soundExists(v.name) then
					if not xSound:isDynamic(v.name) then
						xSound:setSoundDynamic(v.name,true)
					end
					xSound:setVolumeMax(v.name,0.0)
					if not poschanged then
						xSound:Position(v.name, vector3(350.0,0.0,-150.0))
						poschanged = true
					end
				end
				v.isplaying = false
				for j = 1, #SoundsPlaying do
					local k = SoundsPlaying[j]
					if k == i then
						table.remove(SoundsPlaying, j)
					end
				end
				break
			end
				if sleep > 1500 then
					sleep = 1500
				elseif sleep < 80 then
					sleep = 80
				end
			Wait(sleep)
		end
	end)
end


function getVehicleAcousticData(vehicle)
	if vehicle == 0 or not DoesEntityExist(vehicle) then
		return 0.0, 0.0, 0
	end

	local model = GetEntityModel(vehicle)
	local seats = GetVehicleModelNumberOfSeats(model)
	local maxWindowIndex = seats <= 2 and 1 or 3

	local checkedDoors = 0
	local openedDoors = 0
	for door = 0, 5 do
		if not IsVehicleDoorDamaged(vehicle, door) then
			checkedDoors = checkedDoors + 1
			if GetVehicleDoorAngleRatio(vehicle, door) > 0.05 then
				openedDoors = openedDoors + 1
			end
		end
	end

	local doorLeak = checkedDoors > 0 and (openedDoors / checkedDoors) or 0.0

	local checkedWindows = 0
	local openWindows = 0
	for window = 0, maxWindowIndex do
		checkedWindows = checkedWindows + 1
		if not IsVehicleWindowIntact(vehicle, window) then
			openWindows = openWindows + 1
		end
	end

	local openings = openedDoors + openWindows
	local windowLeak = checkedWindows > 0 and (openWindows / checkedWindows) or 0.0
	local totalLeak = math.max(0.0, math.min(1.0, (doorLeak * 0.75) + (windowLeak * 0.45)))
	local cabinIsolation = math.max(0.0, math.min(1.0, (1.0 - doorLeak) * (1.0 - (windowLeak * 0.60))))

	return cabinIsolation, totalLeak, openings
end

function applyInteriorAudioProfile(soundName, baseVolume, distanceToVehicle, inSameVehicle, cabinIsolation, totalLeak, openings, vehicleSpeed, hearingRange)
	if not xSound:soundExists(soundName) then
		return
	end

	local profile = interiorSoundState[soundName] or {}
	local targetVolume = baseVolume
	local currentMs = GetGameTimer()
	local insideBaseVolume = math.min(baseVolume, baseVolume * 0.99)

	if inSameVehicle then
		local insidePresence = 0.97 + (0.03 * cabinIsolation)
		targetVolume = math.min(baseVolume, baseVolume * insidePresence)
	else
		local openingFactor = 0.12
		if openings == 1 then
			openingFactor = 0.25
		elseif openings == 2 then
			openingFactor = 0.50
		elseif openings == 3 then
			openingFactor = 0.75
		elseif openings >= 4 then
			openingFactor = 1.0
		end

		local maxRange = math.max(15.0, (hearingRange or 30.0) + 30.0)
		local distanceFactor = math.max(0.0, 1.0 - (distanceToVehicle / maxRange))
		distanceFactor = math.pow(distanceFactor, 1.35)

		local shellFactor = math.max(0.08, 1.0 - (cabinIsolation * 0.85))
		local leakPresence = 0.70 + (totalLeak * 0.50)
		local highCutEmulation = 1.0 - math.min(0.55, ((distanceToVehicle / maxRange) * 0.45) + (cabinIsolation * 0.15))
		local motionPulse = 1.0 + (math.min(0.06, (vehicleSpeed or 0.0) / 320.0) * math.abs(math.sin(GetGameTimer() / 280.0)))
		targetVolume = baseVolume * openingFactor * distanceFactor * shellFactor * leakPresence * highCutEmulation * motionPulse
		targetVolume = math.min(baseVolume, targetVolume)
	end

	if profile.wasInside == nil then
		profile.wasInside = inSameVehicle
	end

	if profile.wasInside and not inSameVehicle then
		profile.exitTransitionUntil = currentMs + 1800
	elseif (not profile.wasInside) and inSameVehicle then
		profile.enterTransitionUntil = currentMs + 800
	end
	profile.wasInside = inSameVehicle

	if profile.exitTransitionUntil and currentMs < profile.exitTransitionUntil then
		local progress = 1.0 - ((profile.exitTransitionUntil - currentMs) / 1800.0)
		targetVolume = insideBaseVolume + ((targetVolume - insideBaseVolume) * progress)
	elseif profile.enterTransitionUntil and currentMs < profile.enterTransitionUntil then
		local progress = 1.0 - ((profile.enterTransitionUntil - currentMs) / 800.0)
		targetVolume = targetVolume + ((insideBaseVolume - targetVolume) * progress)
	end

	local smoothedVolume = profile.smoothedVolume or targetVolume
	local alpha = inSameVehicle and 0.30 or 0.22
	smoothedVolume = smoothedVolume + ((targetVolume - smoothedVolume) * alpha)
	profile.smoothedVolume = smoothedVolume

	if not profile.lastVolume or math.abs(profile.lastVolume - smoothedVolume) > 0.007 then
		if inSameVehicle then
			xSound:setVolume(soundName, smoothedVolume)
			xSound:setSubmixPreset(soundName, "inside")
		else
			xSound:setVolumeMax(soundName, smoothedVolume)
			xSound:setSubmixPreset(soundName, "outside")
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
    ["RADIO_01_CLASS_ROCK"] = true,              -- Los Santos Rock Radio
    ["RADIO_02_POP"] = true,                     -- Non-Stop-Pop FM
    ["RADIO_03_HIPHOP_NEW"] = true,              -- Radio Los Santos
    ["RADIO_04_PUNK"] = true,                    -- Channel X
    ["RADIO_05_TALK_01"] = true,                 -- West Coast Talk Radio
    ["RADIO_06_COUNTRY"] = true,                 -- Rebel Radio
    ["RADIO_07_DANCE_01"] = true,                -- Soulwax FM
    ["RADIO_08_MEXICAN"] = true,                 -- East Los FM
    ["RADIO_09_HIPHOP_OLD"] = true,              -- West Coast Classics
    ["RADIO_12_REGGAE"] = true,                  -- Blue Ark
    ["RADIO_13_JAZZ"] = true,                    -- Worldwide FM
    ["RADIO_14_DANCE_02"] = true,                -- FlyLo FM
    ["RADIO_15_MOTOWN"] = true,                  -- The Lowdown 91.1
    ["RADIO_16_SILVERLAKE"] = true,              -- Radio Mirror Park
    ["RADIO_17_FUNK"] = true,                    -- Space 103.2
    ["RADIO_18_90S_ROCK"] = true,                -- Vinewood Boulevard Radio
    ["RADIO_19_USER"] = true,                    -- Self Radio
    ["RADIO_20_THELAB"] = true,                  -- The Lab
    ["RADIO_11_TALK_02"] = true,                 -- Blaine County Radio
    ["RADIO_21_DLC_XM17"] = true,                -- Blonded Los Santos 97.8 FM
    ["RADIO_22_DLC_BATTLE_MIX1_RADIO"] = true    -- Los Santos Underground Radio
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
			local hasCarRadio = xSound:soundExists(plate)
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

Citizen.CreateThread(function()
	while true do
		Wait(80)
		local ped = PlayerPedId()
		local coords = GetEntityCoords(ped)
		local heading = GetEntityHeading(ped)
		SendNUIMessage({
			action = "carplayAudio",
			cmd = "listener",
			position = { x = coords.x, y = coords.y, z = coords.z },
			heading = heading
		})
	end
end)
