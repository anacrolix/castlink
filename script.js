var session;
var url = window.location.hash.substr(1) || 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
var subtitles;
// var subtitle = 'http://syd1.anacrolix.link:33849/out.vtt';
// var subtitle = 'https://syd1.anacrolix.link/data?ih=17e0d45e7b30bbba59f61ebad5896268cfa20603&path=The.Last.Circus.2010.720p.BluRay.x264-LPD.srt&at=MTQ3MzI2NTMwMHxJN2dmRGlDbl82ZlIySmR1UFVxWmZHTG1GUjFNZWI1TENTVGlNSzI0UkFNaTNnbGk3T05Vd3pabHVFMEdpVHJpb3lwZlV6V3NnSlZiNEpHS2hSNGpLcllkSEM2V3dvdFU3SmNkdU5YQ3pOa0NodTlHOFJ0TDBxemQ4M1RkZWVZdVVPWUw1VGVyQ3VmeHlhZGR8pZbuIgf6HhxmJ8LoD8VQDmQz5QM9bNsg8dgJPA9KpXs%3d';

setInterval(function() {
    updateProgress();
}, 500);

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
    var tracks = [];
    if (subtitles) {
        var enSubs = new chrome.cast.media.Track(1, chrome.cast.media.TrackType.TEXT);
        enSubs.trackContentId = subtitle;
        enSubs.trackContentType = 'text/vtt';
        enSubs.subtype = chrome.cast.media.TextTrackType.SUBTITLES;
        enSubs.language = 'en-US';
        tracks.push(enSubs);
    }
    var mediaInfo = new chrome.cast.media.MediaInfo(url);
    mediaInfo.contentType = 'video/mp4';
    mediaInfo.metadata = new chrome.cast.media.GenericMediaMetadata();
    mediaInfo.metadata.metadataType = chrome.cast.media.MetadataType.GENERIC;
    mediaInfo.tracks = tracks;
    mediaInfo.textTrackStyle = new chrome.cast.media.TextTrackStyle();
    var request = new chrome.cast.media.LoadRequest(mediaInfo);
    if (subtitles) {
        request.activeTrackIds = [1];
    }
    // request.autoplay = false;
    session.loadMedia(request, mediaLoaded, onError);
}

function displayControl(name, display) {
    var j = $('.'+name);
    if (!j.length) throw name;
    if (display) j.show();
    else j.hide();
}

function showLeave() {
    $('.leave').show();
}

function hideLeave() {
    $('.leave').hide();
}

function displayJoin(display) {
    if (display) showJoin();
    else hideJoin();
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
    session.media.forEach(mediaLoaded);
    applySession(session);
}

function sessionUpdated(isAlive) {
    console.log('session updated', isAlive);
    applySession();
}

function applySession() {
    console.log('applying session', session);
    updateUI();
}

function apiInitialized() {
    console.log('cast api initialized');
}

function onError(e) {
    console.log('onError', e);
}

function updateProgress() {
    var media = activeMedia();
    if (!media) {
        hideProgress();
        return;
    }
    showProgress();
    $('.progress-bar').attr({
        value: media.getEstimatedTime(),
        max: media.media.duration
    });
    $('.current-time').text(toHHMMSS(media.getEstimatedTime()));
    $('.duration').text(toHHMMSS(media.media.duration));
}

function mediaUpdated(alive) {
    console.log('media updated', alive);
    updateUI();
}

function activeMedia() {
    return session && session.status == chrome.cast.SessionStatus.CONNECTED && session.media[0];
}

function updateUI() {
    var sessionConnected = session && session.status == chrome.cast.SessionStatus.CONNECTED;
    displayJoin(!sessionConnected);
    displayControl('leave', sessionConnected);
    var media = activeMedia();
    $('.current-url').text(media && media.media.contentId || 'none');
    displayControl('play', function() {
        if (!media) return false;
        switch (media.playerState) {
        case chrome.cast.media.PlayerState.PLAYING:
        case chrome.cast.media.PlayerState.BUFFERING:
            return false;
        }
        return true;
    }());
    displayControl('pause', function() {
        if (!media) return false;
        switch (media.playerState) {
        case chrome.cast.media.PlayerState.PLAYING:
        case chrome.cast.media.PlayerState.BUFFERING:
            break;
        default:
            return false;
        }
        return true;
    }());
    displayControl('stop', function() {
        return media;
    }());
}

function mediaLoaded(m) {
    console.log('media loaded', m);
    m.addUpdateListener(mediaUpdated);
    // var activeTrackIds = [1];
    // var tracksInfoRequest = new chrome.cast.media.EditTracksInfoRequest(activeTrackIds);
    // media.editTracksInfo(tracksInfoRequest, null, onError);
}

$(document).ready(function() {
    $('.progress-bar').on('click', function(e) {
        var sr = new chrome.cast.media.SeekRequest();
        sr.currentTime = e.offsetX/e.target.clientWidth*activeMedia().media.duration;
        activeMedia().seek(sr, null, onError);
    });
    $('.pause').on('click', function() {
        activeMedia().pause(null, null, onError);
    });
    $('.play').on('click', function() {
        activeMedia().play(null, null, onError);
    });
    $('.stop').on('click', function() {
        activeMedia().stop(null, null, onError);
    });
    $('.leave').on('click', function() {
        session.leave(null, onError);
    });
    $('.join').on('click', function() {
        chrome.cast.requestSession(gotSession, onError);
    });
    $('#new-url').attr('value', url);
    $('.load').on('click', function() {
        loadMedia($('#new-url').val());
    });
})

function toHHMMSS(i) {
    var sec_num = parseInt(i, 10); // don't forget the second param
    var hours   = Math.floor(sec_num / 3600);
    var minutes = Math.floor((sec_num - (hours * 3600)) / 60);
    var seconds = sec_num - (hours * 3600) - (minutes * 60);

    if (hours   < 10) {hours   = "0"+hours;}
    if (minutes < 10) {minutes = "0"+minutes;}
    if (seconds < 10) {seconds = "0"+seconds;}
    return hours+':'+minutes+':'+seconds;
}
