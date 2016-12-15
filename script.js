var session;
var parsedFragment = parseFragment();
var loading;

setInterval(function() {
    updateProgress();
}, 1000);

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

function loadMedia(spec) {
    var url = spec.url;
    var title = spec.title;
    var subtitles = spec.subtitles;
    var subtitle = spec.subtitle;
    var poster = spec.poster;
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
    metadata.subtitle = (subtitle || url).substr(0, 100);
    mediaInfo.metadata = metadata;
    mediaInfo.tracks = tracks;
    mediaInfo.textTrackStyle = new chrome.cast.media.TextTrackStyle();
    var request = new chrome.cast.media.LoadRequest(mediaInfo);
    if (subtitles) {
        request.activeTrackIds = [1];
    }
    session.loadMedia(request, mediaLoaded, mediaLoadError);
    loading = spec;
    updateUI();
}

function mediaLoadError(e) {
    console.log('error loading media', e);
    loading = null;
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
    if (!activeMedia()) {
        loadProposedMedia();
    }
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
        return;
    }
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

function proposedContentURL() {
    return $('#new-url').val();
}

function proposedSubtitles() {
    return $('#subtitles').val();
}

function isProposedMedia(m) {
    if (!m) return false;
    var mi = m.media;
    if (mi.contentId != proposedContentURL()) return false;
    var ps = proposedSubtitles();
    return (mi.tracks[0] && mi.tracks[0].trackContentId || "") == (ps || "");
}

function updateUI() {
    var sessionConnected = session && session.status == chrome.cast.SessionStatus.CONNECTED;
    show('#request-session', !sessionConnected);
    show('#stop-session', sessionConnected);
    show('#leave-session', sessionConnected);
    show('#loaded', sessionConnected);
    displayControl('#leave-session', sessionConnected);
    var media = activeMedia();
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
    show('#load-button', sessionConnected && !isProposedMedia(media) && !loading);
    show('#loading-button', loading);
    show('#reload-button', sessionConnected && isProposedMedia(media));
    updateProgress();
}

function mediaLoaded(m) {
    console.log('media loaded', m);
    loading = null;
    m.addUpdateListener(mediaUpdated);
    updateUI();
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
    $('#new-url').val(parsedFragment.getLast('content') || 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4');
    $('#subtitles').val(parsedFragment.getLast('subtitles'));
    $('#load-button').on('click', function() {
        loadProposedMedia();
    });
    $('#reload-button').on('click', function() {
        loadProposedMedia();
    });
    $('#proposed textarea').on('click', function() {
        $(this).select();
    });
    updateUI();
});

function proposedMediaSpec() {
    return {
        url: $('#new-url').val(),
        subtitles: $('#subtitles').val(),
        title: parsedFragment.getLast('title'),
        poster: parsedFragment.getLast('poster'),
        subtitle: parsedFragment.getLast('subtitle')};
}

function loadProposedMedia() {
    loadMedia(proposedMediaSpec());
}

function parseFragment() {
    var ret = new MultiMap;
    window.location.hash.substr(1).split('&').forEach(function(field) {
        var tuple = field.split('=');
        ret.add(decodeURIComponent(tuple.shift()), decodeURIComponent(tuple.join('=')));
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
