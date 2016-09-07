var media;

setInterval(function() {
    updateProgress();
}, 1000);

window['__onGCastApiAvailable'] = function(loaded, errorInfo) {
    if (loaded) {
        initializeCastApi();
    } else {
        console.log(errorInfo);
    }
}

initializeCastApi = function() {
  var sessionRequest = new chrome.cast.SessionRequest(chrome.cast.media.DEFAULT_MEDIA_RECEIVER_APP_ID);
  var apiConfig = new chrome.cast.ApiConfig(sessionRequest, onSession, onReceiver);
  chrome.cast.initialize(apiConfig, initSuccess, onError);
};

function onReceiver(e) {
    console.log('onReceiver', e);
    if (e == chrome.cast.ReceiverAvailability.AVAILABLE) {
        chrome.cast.requestSession(onSession, onError);
    }
}

function loadMedia(url) {
    for (var i = 0; i < session.media.length; i++) {
        if (session.media[i].media.contentId == url) {
            onMedia(session.media[i]);
            return
        }
    }
    var mediaInfo = new chrome.cast.media.MediaInfo(url);
    var request = new chrome.cast.media.LoadRequest(mediaInfo);
    session.loadMedia(request, onMedia, onError);
}

function onSession(s) {
    session = s;
    session.addUpdateListener(onSessionChanged);
    console.log('onSession', session);
    loadMedia(url);
}

function onSessionChanged(isAlive) {
    console.log('onSessionChanged', isAlive, session);
}

function initSuccess() {
    console.log("init succeeded");
}

function onError(e) {
    console.log('onError', e);
}

function updateProgress() {
    if (!media) {
        return;
    }
    $('.current-url').text(media.media.contentId);
    $('.progress-bar').attr({
        value: media.getEstimatedTime(),
        max: media.media.duration
    });
    $('.current-time').text(media.getEstimatedTime());
    $('.duration').text(media.media.duration);
}

function onMediaChanged(alive) {
    console.log('onMediaChanged', alive);
    updateProgress();
}

function onMedia(m) {
    console.log('onMedia', m);
    media = m;
    media.addUpdateListener(onMediaChanged);
}

$(document).ready(function() {
    $('.cast-icon-error').on('click', function() {
        chrome.cast.requestSession(onSession, onError);
    });
    $('.pause').on('click', function() {
        media.pause(null, null, onError);
    });
    $('.play').on('click', function() {
        loadMedia(url);
        media.play(null, null, onError);
    });
    $('.stop').on('click', function() {
        media.stop(null, null, onError);
    });
});

var url = 'http://syd1.anacrolix.link/preview?path=The.Last.Circus.2010.720p.BluRay.x264-LPD.mkv&ih=17e0d45e7b30bbba59f61ebad5896268cfa20603&at=MTQ3MzIyODAzMnx0SFo3b0lieGRYM2haZUNieklHSjJ0dFk5SHBza2RLOU9FSXpTcUNhdVBVeWNrU3VaTG9NNkZ3Xy1UR28tOXQxZU1Oa0VpbTljVUpFSkt2bzBudk1KXzQ1UEVYWHIySE1pZUpLQ3B5bFVTcF9DVUdIR29yaVZMYWtIZVV0dnNCSUE2NlJmRjN1MkVvVnFINHZ8TekeZcV78ONqQT7KBsIFk9Cn7kI_AjhXsR_dI6sivfY%3d';
url = "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";
