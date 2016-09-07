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
    mediaInfo.contentType = 'video/mp4';
    mediaInfo.metadata = new chrome.cast.media.GenericMediaMetadata();
    mediaInfo.metadata.metadataType = chrome.cast.media.MetadataType.GENERIC;
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

var url = window.location.hash.substr(1) || 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

$(document).ready(function() {
    $('.current-url').text(url);
    $('.progress-bar').on('click', function(e) {
        var sr = new chrome.cast.media.SeekRequest();
        sr.currentTime = e.offsetX/e.target.clientWidth*media.media.duration;
        media.seek(sr, null, onError);
    });
})
