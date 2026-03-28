let customRadios;

$('#volumeUp').click(function () {
  $.post('https://carmusic/action', JSON.stringify({ action: 'volumeup' }))
})

$('#volumeDown').click(function () {
  $.post('https://carmusic/action', JSON.stringify({ action: 'volumedown' }))
})

$('#loopButton').click(function () {
  $.post('https://carmusic/action', JSON.stringify({ action: 'loop' }))
})

$('#stopButton').click(function () {
  $.post('https://carmusic/action', JSON.stringify({ action: 'pause' }))
})

$('#prevButton').click(function () {
  $.post('https://carmusic/action', JSON.stringify({ action: 'back' }))
})

$('#nextButton').click(function () {
  $.post('https://carmusic/action', JSON.stringify({ action: 'forward' }))
})

var vidname = 'Name not Found'
$('#playButton').click(function () {
  if (customRadios && typeof customRadios.stop === 'function') customRadios.stop();
  var link = document.getElementById('youtubeLink').value
  $.post('https://carmusic/action', JSON.stringify({ action: 'seturl', link: link }))
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
      $.post('https://carmusic/action', JSON.stringify({ action: 'exit' }))
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
  fetch('https://carmusic/radio:ready', { method: 'POST', body: '{}' })

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
            $.post('https://carmusic/action', JSON.stringify({ action: 'pause' }))
            customRadios.play(index)
          }
        } else {
          fetch('https://carmusic/radio:ready', { method: 'POST', body: '{}' })
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
    data.howl.volume(Math.max(0, Math.min(1, data.currentVolume)))
    if (typeof data.howl.stereo === 'function') {
      data.howl.stereo(computePan(carplayEngine.listener, data.position))
    }
  })
}

setInterval(engineTick, 60)

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
      const howl = new Howl({
        src: [data.url],
        html5: true,
        loop: !!data.loop,
        volume: 0.0,
      })
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
    return
  }

  const snd = carplayEngine.sounds[data.name]
  if (!snd || !snd.howl) return
  if (data.cmd === 'pause') snd.howl.pause()
  if (data.cmd === 'resume' && !snd.howl.playing()) snd.howl.play()
  if (data.cmd === 'setUrl') {
    snd.howl.unload()
    snd.howl = new Howl({ src: [data.url], html5: true, loop: !!snd.loop, volume: 0.0 })
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
  if (data.cmd === 'seek' && typeof snd.howl.seek === 'function') snd.howl.seek(data.value || 0)
})
