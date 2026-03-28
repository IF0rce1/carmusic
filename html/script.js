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
