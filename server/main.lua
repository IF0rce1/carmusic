
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

local function resolveYouTubeToAudioUrl(url, callback)
	local videoId = extractYouTubeVideoId(url)
	if not videoId then
		callback(nil)
		return
	end

	local endpoints = Config.YouTubeResolverInstances or {
		"https://piped.video",
		"https://pipedapi.kavin.rocks"
	}
	local index = 1

	local function tryNextEndpoint()
		if index > #endpoints then
			callback(nil)
			return
		end

		local endpoint = endpoints[index]
		index = index + 1
		local requestUrl = ("%s/api/v1/streams/%s"):format(endpoint, videoId)

		PerformHttpRequest(requestUrl, function(statusCode, body)
			if statusCode >= 200 and statusCode < 300 and body then
				local payload = json.decode(body)
				if payload and payload.audioStreams then
					local bestUrl = nil
					local bestBitrate = -1
					for _, stream in pairs(payload.audioStreams) do
						if stream and stream.url then
							local bitrate = tonumber(stream.bitrate) or 0
							if bitrate > bestBitrate then
								bestBitrate = bitrate
								bestUrl = stream.url
							end
						end
					end
					if bestUrl then
						callback(bestUrl)
						return
					end
				end
			end

			tryNextEndpoint()
		end, "GET", "", { ["Accept"] = "application/json" })
	end

	tryNextEndpoint()
end

RegisterNetEvent("carmusic:ResolveYouTubeUrl")
AddEventHandler("carmusic:ResolveYouTubeUrl", function(requestId, url)
	local src = source
	if type(requestId) ~= "string" then
		return
	end

	if not isYouTubeUrl(url) then
		TriggerClientEvent("carmusic:ResolveYouTubeUrlResult", src, requestId, url)
		return
	end

	resolveYouTubeToAudioUrl(url, function(resolvedUrl)
		TriggerClientEvent("carmusic:ResolveYouTubeUrlResult", src, requestId, resolvedUrl)
	end)
end)

RegisterNetEvent("carmusic:ChangeVolume")
AddEventHandler("carmusic:ChangeVolume", function(vol, nome)
    local somafter = false
    local rangeafter = false
    for i = 1, #Config.Zones do
        local v = Config.Zones[i]
        if nome == v.name then
            local vadi = v.volume + vol
            if vadi <= 1.01 and vadi >= -0.001 then
				if vadi < 0.005 then
					vadi = 0.0
				end
                if v.popo then
                    v.range = (v.volume*Config.DistanceToVolume)
                else
					if vadi >= 0.05 then
						v.range = (vadi*v.range)/v.volume
					end
                end
                v.volume = vadi
                somafter = v.volume
                rangeafter = v.range
            end
        end
    end
    if somafter and rangeafter then
        TriggerClientEvent("carmusic:ChangeVolume",-1,somafter,rangeafter, nome)
    end
end)

RegisterNetEvent("carmusic:ChangeLoop")
AddEventHandler("carmusic:ChangeLoop", function(nome,tip)
	local loopstate
	for i = 1, #Config.Zones do
		local v = Config.Zones[i]
		if nome == v.name then
			v.loop = tip
			loopstate = v.loop
		end
	end
	if loopstate ~= nil then
		TriggerClientEvent("carmusic:ChangeLoop",-1,loopstate, nome)
	end
end)

RegisterNetEvent("carmusic:ChangeState")
AddEventHandler("carmusic:ChangeState", function(type, nome)
	for i = 1, #Config.Zones do
		local v = Config.Zones[i]
		if nome == v.name then
			v.isplaying = type
		end
	end
	TriggerClientEvent("carmusic:ChangeState",-1,type, nome)
end)

RegisterNetEvent("carmusic:ChangePosition")
AddEventHandler("carmusic:ChangePosition", function(quanti, nome)
	for i = 1, #Config.Zones do
		local v = Config.Zones[i]
		if nome == v.name then
			v.deftime = v.deftime+quanti
			if v.deftime < 0 then
				v.deftime = 0
			end
		end
	end
	TriggerClientEvent("carmusic:ChangePosition",-1,quanti, nome)
end)

RegisterNetEvent("carmusic:ModifyURL")
AddEventHandler("carmusic:ModifyURL", function(data)
	local _data = data
	local zena = false
	for i = 1, #Config.Zones do
		local v = Config.Zones[i]
		if _data.name == v.name then
			v.deflink = _data.link
			if _data.popo then
				v.popo = _data.popo
			end
			v.deftime = 0
			v.isplaying = true
			v.loop = _data.loop
			zena = v
		end
	end
	if zena then
		TriggerClientEvent("carmusic:ModifyURL",-1,zena)
	end
end)

function countTime()
    SetTimeout(1000, countTime)
    for i = 1, #Config.Zones do
		local v = Config.Zones[i]
        if v.isplaying then
            v.deftime = v.deftime + 1
        end
    end
end

SetTimeout(1000, countTime)

RegisterNetEvent('carmusic:AddVehicle')
AddEventHandler("carmusic:AddVehicle", function(vehdata)
    local Data = {}
    Data.name = vehdata.plate
    Data.coords = vehdata.coords
    Data.range = vehdata.volume * Config.DistanceToVolume
    Data.volume = vehdata.volume
    Data.deflink = vehdata.link
    Data.isplaying = true
    Data.loop = vehdata.loop
    Data.deftime = 0
    Data.popo = vehdata.popo
    table.insert(Config.Zones, Data)
    TriggerClientEvent('carmusic:AddVehicle', math.floor(-1), Config.Zones[#Config.Zones])
end)

RegisterNetEvent('carmusic:GetDate')
AddEventHandler('carmusic:GetDate', function()
    TriggerClientEvent('carmusic:SendData', math.floor(-1), Config.Zones)
end)
