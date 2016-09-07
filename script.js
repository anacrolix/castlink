var media;
var session;
var url = window.location.hash.substr(1) || 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';

setInterval(function() {
    updateProgress();
}, 1000);

window['__onGCastApiAvailable'] = function(loaded, errorInfo) {
    if (loaded) {
        apiAvailable();
    } else {
        console.log(errorInfo);
    }
}

function apiAvailable() {
    var sessionRequest = new chrome.cast.SessionRequest('911A4C88');
    var apiConfig = new chrome.cast.ApiConfig(sessionRequest, gotSession, gotReceiverAvailability, chrome.cast.AutoJoinPolicy.ORIGIN_SCOPED);
    chrome.cast.initialize(apiConfig, apiInitialized, onError);
};

function gotReceiverAvailability(availability) {
    if (availability == chrome.cast.ReceiverAvailability.AVAILABLE) {
        showJoin();
    } else {
        hideJoin();
    }
}

function loadMedia(url) {
    for (var i = 0; i < session.media.length; i++) {
        if (session.media[i].media.contentId == url) {
            mediaLoaded(session.media[i]);
            return
        }
    }
    var mediaInfo = new chrome.cast.media.MediaInfo(url);
    mediaInfo.contentType = 'video/mp4';
    mediaInfo.metadata = new chrome.cast.media.GenericMediaMetadata();
    mediaInfo.metadata.metadataType = chrome.cast.media.MetadataType.GENERIC;
    var request = new chrome.cast.media.LoadRequest(mediaInfo);
    session.loadMedia(request, mediaLoaded, onError);
}

function showLeave() {
    $('.leave').show();
}

function hideLeave() {
    $('.leave').hide();
}

function showJoin() {
    $('.join').show();
}

function hideJoin() {
    $('.join').hide();
}

function showPlay() {
    $('.play').show();
}

function hidePlay() {
    $('.play').hide();
}

function showPause() {
    $('.pause').show();
}

function hidePause() {
    $('.pause').hide();
}

function showStop() {
    $('.stop').show();
}

function hideStop() {
    $('.stop').hide();
}

function showProgress() {
    $('.progress').show();
}

function hideProgress() {
    $('.progress').hide();
}

function updateMediaControls() {
    if (!media) {
        hidePlay();
        hidePause();
        hideStop();
        hideProgress();
    }
}

function gotSession(s) {
    console.log('got session', s);
    session = s;
    session.addUpdateListener(sessionUpdated);
    applySession(session);
    loadMedia(url);
}

function sessionUpdated(isAlive) {
    console.log('session updated', isAlive);
    applySession();
}

function applySession() {
    console.log('applying session', session);
    if (session.status == chrome.cast.SessionStatus.CONNECTED) {
        showLeave();
        hideJoin();
    } else {
        showJoin();
        hideLeave();
        media = null;
        updateMediaControls();
    }
}

function apiInitialized() {
    console.log('cast api initialized');
}

function onError(e) {
    console.log('onError', e);
}

function updateProgress() {
    if (!media) {
        hideProgress();
        return;
    }
    showProgress();
    $('.progress-bar').attr({
        value: media.getEstimatedTime(),
        max: media.media.duration
    });
    $('.current-time').text(media.getEstimatedTime());
    $('.duration').text(media.media.duration);
}

function mediaUpdated(alive) {
    console.log('media updated', alive);
    applyMedia();
}

function applyMedia() {
    updateProgress();
    switch (media.playerState) {
    case chrome.cast.media.PlayerState.PLAYING:
    case chrome.cast.media.PlayerState.BUFFERING:
        showPause();
        showStop();
        hidePlay();
        break;
    case chrome.cast.media.PlayerState.PAUSED:
        showPlay();
        showStop();
        hidePause();
        break;
    default:
        showPlay();
        hideStop();
        hidePause();
    }
}

function mediaLoaded(m) {
    console.log('media loaded', m);
    media = m;
    media.addUpdateListener(mediaUpdated);
}

$(document).ready(function() {
    $('.current-url').text(url);
    $('.progress-bar').on('click', function(e) {
        var sr = new chrome.cast.media.SeekRequest();
        sr.currentTime = e.offsetX/e.target.clientWidth*media.media.duration;
        media.seek(sr, null, onError);
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
    $('.leave').on('click', function() {
        session.leave(null, onError);
    });
    $('.join').on('click', function() {
        chrome.cast.requestSession(gotSession, onError);
    });
})
