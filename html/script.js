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
  customRadios.stop();
  var _0x38601b = document.getElementById('youtubeLink').value
  $.post(
    'https://carmusic/action',
    JSON.stringify({
      action: 'seturl',
      link: _0x38601b,
    })
  )
  getNameFile(_0x38601b)
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

function getNameFile(_0x3d9b10) {
  _0x3d9b10 == undefined
    ? ((vidname = 'Nimic'),
      (document.getElementById('testrec').innerHTML = `Car Radio<p>`+vidname+`</p>`))
    : $.getJSON(
        'https://noembed.com/embed?url=',
        {
          format: 'json',
          url: _0x3d9b10,
        },
        function (_0x25a269) {
          vidname = _0x25a269.title
          // $.post(
          //   'https://carmusic/action',
          //   JSON.stringify({
          //     action: 'numemelodie',
          //     nume: vidname,
          //   })
          // )
          whenDone(_0x3d9b10)
        }
      )
}
const capitalize = (_0x5dc8a6) => {
  if (typeof _0x5dc8a6 !== 'string') {
    return ''
  }
  return _0x5dc8a6.charAt(0).toUpperCase() + _0x5dc8a6.slice(1)
}
function whenDone(_0x3eed52) {
  vidname == undefined &&
    ((vidname = capitalize(GetFilename(_0x3eed52))),
    vidname == '' && (vidname = 'Name not Found'))
  document.getElementById('testrec').innerHTML = `Car Radio<p>`+vidname+`</p>`
  $("#carmusicNowListen").fadeIn(500,function(){
    setTimeout(() => {
      $("#carmusicNowListen").fadeOut(500);
    }, 2000);
  });
}
function GetFilename(_0x29904f) {
  if (_0x29904f) {
    var _0x3a78d0 = _0x29904f.toString().match(/.*\/(.+?)\./)
    if (_0x3a78d0 && _0x3a78d0.length > 1) {
      return _0x3a78d0[1]
    }
  }
  return ''
}
var doispontos = false
function showTime() {
  var _0x3cc400 = new Date(),
    _0x21397c = _0x3cc400.getHours(),
    _0x3c0eb1 = _0x3cc400.getMinutes(),
    _0x41e3eb = ' AM'
  _0x21397c == 0 && (_0x21397c = 12)
  _0x21397c > 12 && ((_0x21397c = _0x21397c - 12), (_0x41e3eb = ' PM'))
  _0x21397c = _0x21397c < 10 ? '0' + _0x21397c : _0x21397c
  _0x3c0eb1 = _0x3c0eb1 < 10 ? '0' + _0x3c0eb1 : _0x3c0eb1
  var _0x1b161c = _0x21397c + ':' + _0x3c0eb1 + _0x41e3eb
  !doispontos
    ? ((doispontos = true),
      (_0x1b161c = _0x21397c + ' ' + _0x3c0eb1 + _0x41e3eb))
    : (doispontos = false)
  document.getElementById('MyClockDisplay').innerText = _0x1b161c
  document.getElementById('MyClockDisplay').textContent = _0x1b161c
  $('#carmusic').is(':visible') && setTimeout(showTime, 1000)
}
$(document).ready(function () {
  $('#carmusic').hide()
  document.onkeyup = function (_0x54f936) {
    _0x54f936.which == 27 &&
      $.post('https://carmusic/action', JSON.stringify({ action: 'exit' }))
  }
})


/**
 * Radio class containing the state of our stations.
 * Includes all methods for playing, stopping, etc.
 * @param {Array} stations Array of objects with station details.
 * @param {number} volume Number from 0.0 to 1.0
 */
const Radio = function (stations, volume) {
    let self = this;
    self.stations = stations;
    self.volume = volume;
    self.index = 0;
};
Radio.prototype = {
    /**
     * Play a station with a specific index.
     * @param  {Number} index Index in the array of stations.
     */
    play: function (index) {
        let self = this;
        let sound;
        index = index !== -1 ? index : self.index;
        let station = self.stations[index];
        // If we already loaded this track, use the current one.
        // Otherwise, setup and load a new Howl.
        if (station.howl) {
            sound = station.howl;
        } else {
            sound = station.howl = new Howl({
                src: station.data.url,
                html5: true, // A live stream can only be played through HTML5 Audio.
                format: ['opus', 'ogg'],
                volume: (station.data.volume || 1.0) * self.volume || 0.1
            });
        }
        // Begin playing the sound.
        sound.play();
        // Keep track of the index we are currently playing.
        self.index = index;
    },
    /**
     * Stop a station's live stream.
     */
    stop: function () {
        let self = this;
        // Get the Howl we want to manipulate.
        let sound = self.stations[self.index].howl;
        // Stop and unload the sound.
        if (sound && sound.state() !== "unloaded") {
            sound.unload();
        } else if (sound) {
            sound.stop();
        }
    },
    /**
     * Change stations volume.
     * @param {number} volume Number from 0.0 to 1.0
     */
    setVolume: function(volume) {
        let self = this;
        self.volume = volume;
        for (let i = 0, length = self.stations.length; i < length; i++) {
            if (self.stations[i].howl) {
                self.stations[i].howl.volume((self.stations[i].data.volume || 1.0) * volume);
            }
        }
    }
};
document.addEventListener("DOMContentLoaded", () => {
    fetch("https://carmusic/radio:ready", { "method": "POST", "body": "{}" });
    window.addEventListener("message", (event) => {
        let item = event.data;
        switch (item.type) {
            case "_createRadio":
                customRadios = new Radio(item.radios, item.volume);
                break;
            case "_volumeRadio":
                if (customRadios) {
                    customRadios.setVolume(item.volume);
                }
                break;
            case "_playRadio":
                if (typeof customRadios !== "undefined") {
                    let index = item.radio
                    let isNotPlaying = (customRadios.stations[index].howl && !customRadios.stations[index].howl.playing());
                    // If the station isn't already playing or it doesn't exist, play it.
                    if (isNotPlaying || !customRadios.stations[index].howl) {
                        // console.log(item.name);
                        $("#testrec").html("Radio<p>Acum asculti radio: "+item.name+"</p>");
                        $("#carmusicNowListen").fadeIn(500,function(){
                          setTimeout(() => {
                            $("#carmusicNowListen").fadeOut(500);
                          }, 2000);
                        });
                        $.post('https://carmusic/action', JSON.stringify({ action: 'pause' }))
                        customRadios.play(index);
                    }
                } else {
                    fetch("https://carmusic/radio:ready", { "method": "POST", "body": "{}" });
                }
                break;
            case "_stopRadio":
                customRadios.stop();
                break;
        }
    });
});