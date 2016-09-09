var session;

// https://syd1.anacrolix.link/preview?path=The.Last.Circus.2010.720p.BluRay.x264-LPD.mkv&ih=17e0d45e7b30bbba59f61ebad5896268cfa20603&at=MTQ3MzMyMjcyNXxlZnZKc04zVWt0R1Q0ek4xNlVXNDdfLXlLdFdsVjc5WjhKVXJCbU0zZXhtb0I0cTlhLWhQeVFYSGRmcThZdTktNURIZWZ6UGpHQkhKd1p0QXRqVHFKYXFVSkZaNUxJdGhvV0s0S0M3UGZWQVJjV0trOGxGVnMzNDlILURMMmw2dTQ3dUZhME5Kb1ROMlE5bmV8ESHJ7AW5-MwxFG3fT6h-v1xBTpfOzA3zOWiERur_5Rk%3d
// http://syd1.anacrolix.link:33849/out.vtt

setInterval(function() {
    updateProgress();
    updateUI();
}, 500);

window['__onGCastApiAvailable'] = function(loaded, errorInfo) {
    if (loaded) {
        apiAvailable();
    } else {
        $(document).ready(function() {
            $('#init-error-info').text(errorInfo+'.');
            $('#init-error-alert').show();
    });
    }
}

function apiAvailable() {
    $('#receivers').show();
    var sessionRequest = new chrome.cast.SessionRequest('911A4C88');
    var apiConfig = new chrome.cast.ApiConfig(
        sessionRequest,
        gotSession,
        gotReceiverAvailability,
        chrome.cast.AutoJoinPolicy.ORIGIN_SCOPED,
        chrome.cast.DefaultActionPolicy.CAST_THIS_TAB);
    chrome.cast.initialize(apiConfig, apiInitialized, onError);
};

function gotReceiverAvailability(availability) {
    if (availability == chrome.cast.ReceiverAvailability.AVAILABLE) {
        $('#available').show();
        $('#unavailable').hide();
        $('#session').show();
    } else {
        $('#available').hide();
        $('#unavailable').show();
        $('#session').hide();
    }
}

function loadMedia(url, subtitles, title, poster, subtitle) {
    for (var i = 0; i < session.media.length; i++) {
        var m = session.media[i];
        if (m.media.contentId != url) continue;
        if ((m.media.tracks[0] && m.media.tracks[0].trackContentId || "") != subtitles) continue;
        mediaLoaded(session.media[i]);
        return;
    }
    var tracks = [];
    if (subtitles) {
        var enSubs = new chrome.cast.media.Track(1, chrome.cast.media.TrackType.TEXT);
        enSubs.trackContentId = subtitles;
        enSubs.trackContentType = 'text/vtt';
        enSubs.subtype = chrome.cast.media.TextTrackType.SUBTITLES;
        enSubs.language = 'en-US';
        tracks.push(enSubs);
    }
    var mediaInfo = new chrome.cast.media.MediaInfo(url);
    mediaInfo.contentType = 'video/mp4';
    var metadata = new chrome.cast.media.GenericMediaMetadata();
    if (poster) {
        metadata.images = [new chrome.cast.Image(poster)];
    }
    metadata.metadataType = chrome.cast.media.MetadataType.GENERIC;
    if (title) {
        metadata.title = unescape(title).substr(0, 35);
    }
    metadata.subtitle = (subtitle || url).substr(0, 70);
    mediaInfo.metadata = metadata;
    mediaInfo.tracks = tracks;
    mediaInfo.textTrackStyle = new chrome.cast.media.TextTrackStyle();
    var request = new chrome.cast.media.LoadRequest(mediaInfo);
    if (subtitles) {
        request.activeTrackIds = [1];
    }
    // request.autoplay = false;
    session.loadMedia(request, mediaLoaded, onError);
}

function displayControl(sel, display) {
    var j = $(sel);
    if (!j.length) throw sel;
    if (display) j.show();
    else j.hide();
}

var show = displayControl;

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
    $('#progress').show();
}

function hideProgress() {
    $('#progress').hide();
}

function gotSession(s) {
    console.log('got session', s);
    session = s;
    session.addUpdateListener(sessionUpdated);
    session.media.forEach(function(m) {
        m.addUpdateListener(mediaUpdated);
    });
    updateUI();
}

function sessionUpdated(isAlive) {
    console.log('session updated', isAlive, session);
    session.media.forEach(function(m) {
        m.addUpdateListener(mediaUpdated);
    });
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
    $('#progress-bar').attr({
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
    if (!session) return;
    if (session.status != chrome.cast.SessionStatus.CONNECTED) return;
    var media = session.media[0];
    if (!media) return;
    if (media.playerState == chrome.cast.media.PlayerState.IDLE) return;
    return media;
}

function updateUI() {
    var sessionConnected = session && session.status == chrome.cast.SessionStatus.CONNECTED;
    show('#request-session', !sessionConnected);
    show('#stop-session', sessionConnected);
    show('#leave-session', sessionConnected);
    show('#loaded', sessionConnected);
    displayControl('#leave-session', sessionConnected);
    var media = activeMedia();
    console.log('update ui media', session, media);
    show('#loaded', media);
    if (media) {
        $('#current-url').text(media && media.media.contentId || 'none');
        displayControl('#play-button', function() {
            return media.playerState == chrome.cast.media.PlayerState.PAUSED;
        }());
        displayControl('#pause-button', function() {
            return media.playerState != chrome.cast.media.PlayerState.PAUSED;
        }());
        displayControl('#stop-button', function() {
            return true;
        }());
    }
    show('#load-button', sessionConnected);
}

function mediaLoaded(m) {
    console.log('media loaded', m);
    m.addUpdateListener(mediaUpdated);
    updateUI();
    // var activeTrackIds = [1];
    // var tracksInfoRequest = new chrome.cast.media.EditTracksInfoRequest(activeTrackIds);
    // media.editTracksInfo(tracksInfoRequest, null, onError);
}

$(document).ready(function() {
    $('#progress-bar').on('click', function(e) {
        var sr = new chrome.cast.media.SeekRequest();
        sr.currentTime = e.offsetX/e.target.clientWidth*activeMedia().media.duration;
        activeMedia().seek(sr, null, onError);
    });
    $('#pause-button').on('click', function() {
        activeMedia().pause(null, null, onError);
    });
    $('#play-button').on('click', function() {
        activeMedia().play(null, null, onError);
    });
    $('#stop-button').on('click', function() {
        activeMedia().stop(null, null, onError);
    });
    $('#leave-session').on('click', function() {
        session.leave(null, onError);
    });
    $('#stop-session').on('click', function() {
        session.stop(null, onError);
    });
    $('#request-session').on('click', function() {
        chrome.cast.requestSession(gotSession, onError);
    });
    var f = parseFragment();
    $('#new-url').val(f.getLast('content') || 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4');
    $('#subtitles').val(f.getLast('subtitles'));
    $('#load-button').on('click', function() {
        loadMedia(
            $('#new-url').val(),
            $('#subtitles').val(),
            f.getLast('title'),
            f.getLast('poster'),
            f.getLast('subtitle'));
    });
    $('#proposed textarea').on('click', function() {
        $(this).select();
    });
    updateUI();
})

function parseFragment() {
    var ret = new MultiMap;
    window.location.hash.substr(1).split(',').forEach(function(field) {
        var tuple = field.split('=');
        ret.add(tuple.shift(), tuple.join('='));
    });
    return ret;
}

function MultiMap() {
    this.map = {};
    this.getLast = function(key) {
        var value = this.map[key];
        if (!value) return;
        return value.slice(-1)[0];
    };
    this.add = function(key, value) {
        if (!this.map.hasOwnProperty(key)) {
            this.map[key] = [];
        }
        this.map[key].push(value);
    };
}

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
