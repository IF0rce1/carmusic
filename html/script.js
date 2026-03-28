let customRadios;
const RESOURCE_NAME = (typeof GetParentResourceName === 'function' && GetParentResourceName()) || 'carmusic'
const NUI_URL = `https://${RESOURCE_NAME}`
const nuiPost = (route, payload = {}) => {
  return fetch(`${NUI_URL}/${route}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload),
  }).catch(() => null)
}

const showStatus = (message, isError = false) => {
  const el = document.getElementById('statusMessage')
  if (!el) return
  el.innerText = message
  el.style.color = isError ? '#ff9f9f' : '#c8fff6'
  el.classList.remove('hidden')
  clearTimeout(showStatus._timer)
  showStatus._timer = setTimeout(() => el.classList.add('hidden'), 3000)
}

const normalizeUrl = (input) => {
  let value = (input || '').trim()
  if (!value) return ''
  if (!/^https?:\/\//i.test(value)) value = `https://${value}`
  return value
}

$('#volumeUp').click(function () {
  nuiPost('action', { action: 'volumeup' })
})

$('#volumeDown').click(function () {
  nuiPost('action', { action: 'volumedown' })
})

$('#loopButton').click(function () {
  nuiPost('action', { action: 'loop' })
})

$('#stopButton').click(function () {
  nuiPost('action', { action: 'pause' })
})

$('#prevButton').click(function () {
  nuiPost('action', { action: 'back' })
})

$('#nextButton').click(function () {
  nuiPost('action', { action: 'forward' })
})

var vidname = 'Name not Found'
$('#playButton').click(function () {
  if (customRadios && typeof customRadios.stop === 'function') customRadios.stop();
  const raw = document.getElementById('youtubeLink').value
  const link = normalizeUrl(raw)
  if (!link || !/^https?:\/\//i.test(link)) {
    showStatus('URL invalid. Folosește link direct http/https.', true)
    return
  }

  nuiPost('action', { action: 'seturl', link: link })
  nuiPost('action', { action: 'play' })
  showStatus('Se încarcă stream-ul...')
  getNameFile(link)
  document.getElementById('youtubeLink').value = ''
})

window.addEventListener('message', function (e) {
  switch (e.data.action) {
    case 'showRadio':
      $('#carmusic').show(), showTime()
      break
    case 'hideRadio':
      $('#carmusic').hide()
      break
    case 'changevidname':
      getNameFile(e.data.text)
      break
    case 'changetextv':
      document.getElementById('volumeButton').innerHTML = e.data.text
      break
  }
})

function getNameFile(url) {
  url == undefined
    ? ((vidname = 'Nimic'),
      (document.getElementById('testrec').innerHTML = `Car Radio<p>` + vidname + `</p>`))
    : $.getJSON(
        'https://noembed.com/embed?url=',
        {
          format: 'json',
          url: url,
        },
        function (data) {
          vidname = data.title
          whenDone(url)
        }
      )
}

const capitalize = (text) => {
  if (typeof text !== 'string') return ''
  return text.charAt(0).toUpperCase() + text.slice(1)
}

function whenDone(url) {
  vidname == undefined &&
    ((vidname = capitalize(GetFilename(url))),
    vidname == '' && (vidname = 'Name not Found'))
  document.getElementById('testrec').innerHTML = `Car Radio<p>` + vidname + `</p>`
  $('#carmusicNowListen').fadeIn(500, function () {
    setTimeout(() => {
      $('#carmusicNowListen').fadeOut(500)
    }, 2000)
  })
}

function GetFilename(url) {
  if (url) {
    var data = url.toString().match(/.*\/(.+?)\./)
    if (data && data.length > 1) return data[1]
  }
  return ''
}

var doispontos = false
function showTime() {
  var now = new Date(),
    hour = now.getHours(),
    minute = now.getMinutes(),
    suffix = ' AM'

  if (hour == 0) hour = 12
  if (hour > 12) {
    hour = hour - 12
    suffix = ' PM'
  }

  hour = hour < 10 ? '0' + hour : hour
  minute = minute < 10 ? '0' + minute : minute

  var txt = hour + ':' + minute + suffix
  if (!doispontos) {
    doispontos = true
    txt = hour + ' ' + minute + suffix
  } else {
    doispontos = false
  }

  const clockEl = document.getElementById('MyClockDisplay')
  if (clockEl) {
    clockEl.innerText = txt
    clockEl.textContent = txt
  }

  $('#carmusic').is(':visible') && setTimeout(showTime, 1000)
}

$(document).ready(function () {
  $('#carmusic').hide()
  document.onkeyup = function (ev) {
    if (ev.which == 27) {
      nuiPost('action', { action: 'exit' })
    }
  }
})

const Radio = function (stations, volume) {
  let self = this
  self.stations = stations
  self.volume = volume
  self.index = 0
}

Radio.prototype = {
  play: function (index) {
    let self = this
    let sound
    index = index !== -1 ? index : self.index
    let station = self.stations[index]

    if (station.howl) {
      sound = station.howl
    } else {
      sound =
        station.howl = new Howl({
          src: station.data.url,
          html5: true,
          format: ['opus', 'ogg'],
          volume: (station.data.volume || 1.0) * self.volume || 0.1,
        })
    }

    sound.play()
    self.index = index
  },

  stop: function () {
    let self = this
    let sound = self.stations[self.index] && self.stations[self.index].howl
    if (sound && sound.state() !== 'unloaded') {
      sound.unload()
    } else if (sound) {
      sound.stop()
    }
  },

  setVolume: function (volume) {
    let self = this
    self.volume = volume
    for (let i = 0, length = self.stations.length; i < length; i++) {
      if (self.stations[i].howl) {
        self.stations[i].howl.volume((self.stations[i].data.volume || 1.0) * volume)
      }
    }
  },
}

document.addEventListener('DOMContentLoaded', () => {
  nuiPost('radio:ready', {})

  window.addEventListener('message', (event) => {
    let item = event.data
    switch (item.type) {
      case '_createRadio':
        customRadios = new Radio(item.radios, item.volume)
        break
      case '_volumeRadio':
        if (customRadios) customRadios.setVolume(item.volume)
        break
      case '_playRadio':
        if (typeof customRadios !== 'undefined') {
          let index = item.radio
          let isNotPlaying =
            customRadios.stations[index].howl && !customRadios.stations[index].howl.playing()
          if (isNotPlaying || !customRadios.stations[index].howl) {
            $('#testrec').html('Radio<p>Acum asculti radio: ' + item.name + '</p>')
            $('#carmusicNowListen').fadeIn(500, function () {
              setTimeout(() => {
                $('#carmusicNowListen').fadeOut(500)
              }, 2000)
            })
            nuiPost('action', { action: 'pause' })
            customRadios.play(index)
          }
        } else {
          nuiPost('radio:ready', {})
        }
        break
      case '_stopRadio':
        if (customRadios) customRadios.stop()
        break
    }
  })
})

const carplayEngine = {
  sounds: {},
  listener: { x: 0, y: 0, z: 0, heading: 0 },
  audioContext: null,
}

function getAudioContext() {
  if (carplayEngine.audioContext) return carplayEngine.audioContext
  const Ctx = window.AudioContext || window.webkitAudioContext
  if (!Ctx) return null
  carplayEngine.audioContext = new Ctx()
  return carplayEngine.audioContext
}

function ensureFxChain(entry) {
  if (entry.fxChainReady || !entry.howl) return
  const sound = entry.howl._sounds && entry.howl._sounds[0]
  if (!sound || !sound._node) return
  const ctx = getAudioContext()
  if (!ctx || !ctx.createMediaElementSource) return
  try {
    const source = ctx.createMediaElementSource(sound._node)
    const low = ctx.createBiquadFilter()
    low.type = 'lowshelf'
    low.frequency.value = 180
    low.gain.value = 0
    const mid = ctx.createBiquadFilter()
    mid.type = 'peaking'
    mid.frequency.value = 1400
    mid.Q.value = 0.9
    mid.gain.value = 0
    const high = ctx.createBiquadFilter()
    high.type = 'highshelf'
    high.frequency.value = 3800
    high.gain.value = 0
    const compressor = ctx.createDynamicsCompressor()
    compressor.threshold.value = -20
    compressor.ratio.value = 3
    source.connect(low)
    low.connect(mid)
    mid.connect(high)
    high.connect(compressor)
    compressor.connect(ctx.destination)
    entry.fx = { low, mid, high, compressor }
    entry.fxChainReady = true
  } catch (_) {
    entry.fxChainReady = false
  }
}

function applyFx(entry) {
  ensureFxChain(entry)
  if (!entry.fx) return
  const fx = entry.fxPreset || {}
  entry.fx.low.gain.value = fx.lowGain || 0
  entry.fx.mid.gain.value = fx.midGain || 0
  entry.fx.high.gain.value = fx.highGain || 0
  entry.fx.compressor.threshold.value = fx.threshold || -20
  entry.fx.compressor.ratio.value = fx.ratio || 3
}

function distance3(a, b) {
  const dx = a.x - b.x
  const dy = a.y - b.y
  const dz = a.z - b.z
  return Math.sqrt(dx * dx + dy * dy + dz * dz)
}

function computePan(listener, source) {
  const dx = source.x - listener.x
  const dy = source.y - listener.y
  const angleToSource = Math.atan2(dy, dx) * 180 / Math.PI
  let relative = (angleToSource - listener.heading) % 360
  if (relative > 180) relative -= 360
  if (relative < -180) relative += 360
  return Math.max(-1, Math.min(1, relative / 90))
}

function engineTick() {
  Object.keys(carplayEngine.sounds).forEach((name) => {
    const data = carplayEngine.sounds[name]
    if (!data || !data.howl) return
    const dist = distance3(carplayEngine.listener, data.position)
    const range = Math.max(1, data.range || 35)
    let attenuation = Math.max(0, 1 - (dist / range))
    attenuation = attenuation * attenuation
    const target = (data.maxVolume || data.volume || 0) * attenuation
    const current = data.currentVolume || 0
    data.currentVolume = current + ((target - current) * 0.35)
    const safeVol = Math.max(0, Math.min(1, data.currentVolume))
    if (Math.abs((data.lastAppliedVolume || 0) - safeVol) > 0.008) {
      data.howl.volume(safeVol)
      data.lastAppliedVolume = safeVol
    }
    if (typeof data.howl.stereo === 'function') {
      data.howl.stereo(computePan(carplayEngine.listener, data.position))
    }
  })
}

setInterval(engineTick, 60)

function createHowlWithRetry(entry, url, loop) {
  const retries = entry.retryCount || 0
  const howl = new Howl({
    src: [url],
    html5: true,
    loop: !!loop,
    volume: 0.0,
    onload: () => {
      entry.retryCount = 0
      showStatus('Stream conectat.')
    },
    onloaderror: () => {
      if (retries < 3) {
        entry.retryCount = retries + 1
        showStatus(`Retry stream ${entry.retryCount}/3...`, true)
        setTimeout(() => {
          if (entry.howl) entry.howl.unload()
          entry.howl = createHowlWithRetry(entry, url, loop)
          entry.howl.play()
        }, 350 * (retries + 1))
      } else {
        showStatus('Nu s-a putut încărca stream-ul (URL/CORS).', true)
      }
    },
    onplayerror: () => {
      showStatus('Play error, reîncerc...', true)
      howl.once('unlock', () => howl.play())
    },
  })
  return howl
}

window.addEventListener('message', function (event) {
  const data = event.data
  if (data.action !== 'carplayAudio') return

  if (data.cmd === 'listener') {
    carplayEngine.listener = {
      x: data.position.x,
      y: data.position.y,
      z: data.position.z,
      heading: data.heading || 0,
    }
    return
  }

  if (data.cmd === 'destroy') {
    const existing = carplayEngine.sounds[data.name]
    if (existing && existing.howl) existing.howl.unload()
    delete carplayEngine.sounds[data.name]
    return
  }

  if (data.cmd === 'upsert') {
    let entry = carplayEngine.sounds[data.name]
    if (!entry || !entry.howl || entry.url !== data.url) {
      if (entry && entry.howl) entry.howl.unload()
      const howl = createHowlWithRetry(entry || {}, data.url, data.loop)
      howl.play()
      entry = { howl: howl, currentVolume: 0.0 }
      carplayEngine.sounds[data.name] = entry
    }
    entry.url = data.url
    entry.position = data.position
    entry.volume = data.volume || 0
    entry.maxVolume = data.maxVolume || data.volume || 0
    entry.range = data.range || 35
    entry.loop = !!data.loop
    entry.howl.loop(entry.loop)
    if (data.paused) entry.howl.pause()
    else if (!entry.howl.playing()) entry.howl.play()
    applyFx(entry)
    return
  }

  const snd = carplayEngine.sounds[data.name]
  if (!snd || !snd.howl) return
  if (data.cmd === 'pause') snd.howl.pause()
  if (data.cmd === 'resume' && !snd.howl.playing()) snd.howl.play()
  if (data.cmd === 'setUrl') {
    snd.howl.unload()
    snd.howl = createHowlWithRetry(snd, data.url, snd.loop)
    snd.howl.play()
    snd.url = data.url
  }
  if (data.cmd === 'setPosition') snd.position = data.position
  if (data.cmd === 'setVolume') {
    snd.volume = data.value
    snd.maxVolume = data.value
  }
  if (data.cmd === 'setVolumeMax') snd.maxVolume = data.value
  if (data.cmd === 'setLoop') {
    snd.loop = !!data.value
    snd.howl.loop(snd.loop)
  }
  if (data.cmd === 'setFx') {
    snd.fxPreset = data.value || {}
    applyFx(snd)
  }
  if (data.cmd === 'seek' && typeof snd.howl.seek === 'function') snd.howl.seek(data.value || 0)
})
