var parsedFragment = parseFragment();
var receiverApplicationId = '911A4C88';
var cf;
var rp;
var rpc;

setInterval(function() {
    updateProgress();
}, 1000);

window['__onGCastApiAvailable'] = function(loaded, errorInfo) {
    show('#api-not-available', false);
    if (loaded) {
        apiAvailable();
    } else {
        $(document).ready(function() {
            $('#init-error-info').text(errorInfo+'.');
            $('#init-error-alert').show();
        });
    }
}

function context() {
    return cast.framework.CastContext.getInstance();
}

function session() {
    return context().getCurrentSession();
}

function media() {
    var s = session();
    return s && s.getMediaSession();
}

function apiAvailable() {
    cf = cast.framework;
    context().setOptions({
        receiverApplicationId: receiverApplicationId,
        autoJoinPolicy: chrome.cast.AutoJoinPolicy.ORIGIN_SCOPED,
        resumeSavedSession: true
    });
    context().addEventListener(cast.framework.CastContextEventType.CAST_STATE_CHANGED, castStateChanged);
    context().addEventListener(cast.framework.CastContextEventType.SESSION_STATE_CHANGED, sessionStateChanged);
    initRemotePlayer();
    updateUI();
};

function initRemotePlayer() {
    rp = new cf.RemotePlayer();
    rpc = new cf.RemotePlayerController(rp);
    rpc.addEventListener(cf.RemotePlayerEventType.ANY_CHANGE, remotePlayerChanged);
}

function remotePlayerChanged(event) {
    console.log('remote player changed', event);
    media() && media().addUpdateListener(mediaUpdated);
    updateUI();
}

function castStateChanged(castState) {
    console.log('cast state changed: ', castState);
    updateUI();
}

function sessionStateChanged(s) {
    console.log('session state changed: ', s);
    updateUI();
    // Might be starting or ended, and so there's no session.
    if (!s.session) return;
    s.session.addEventListener(cast.framework.SessionEventType.MEDIA_SESSION, mediaSessionChanged);
}

function mediaSessionChanged(m) {
    console.log('media session changed', m);
    m.mediaSession.addUpdateListener(mediaUpdated)
}

function mediaUpdated(alive) {
    console.log('media status changed', alive);
    updateUI();
}

function receiversAvailable(available) {
    show('#available', available);
    show('#unavailable', !available);
    show('#session', available);
}

function loadMedia(spec) {
    var url = spec.url;
    var title = spec.title;
    var subtitle = spec.subtitle;
    var poster = spec.poster;
    // var tracks = [];
    // if (subtitles) {
    //     var enSubs = new chrome.cast.media.Track(1, chrome.cast.media.TrackType.TEXT);
    //     enSubs.trackContentId = subtitles;
    //     enSubs.trackContentType = 'text/vtt';
    //     enSubs.subtype = chrome.cast.media.TextTrackType.SUBTITLES;
    //     enSubs.language = 'en-US';
    //     tracks.push(enSubs);
    // }
    var mediaInfo = new chrome.cast.media.MediaInfo(url, 'video/mp4');
    // mediaInfo.contentType = 'video/mp4';
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
    // mediaInfo.tracks = tracks;
    // mediaInfo.textTrackStyle = new chrome.cast.media.TextTrackStyle();
    var request = new chrome.cast.media.LoadRequest(mediaInfo);
    // if (subtitles) {
    //     request.activeTrackIds = [1];
    // }
    request.autoplay = true;
    console.log(session(), request);
    session().loadMedia(request).then(mediaLoaded, mediaLoadError);
    updateUI();
}

function mediaLoaded() {
    console.log('media loaded');
}

function mediaLoadError(e) {
    console.log('error loading media', e);
    loading = null;
}

function displayControl(sel, display) {
    var j = $(sel);
    if (!j.length) console.log('control not found', sel);
    if (display) j.show();
    else j.hide();
}

var show = displayControl;

function gotSession() {
    var s = session();
    console.log('got session', s);
    // s.addEventListener(sessionUpdated);
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
    var width = 100*media.getEstimatedTime()/media.media.duration + '%';
    $('#progress-bar').css('width', width);
    // $('#progress-bar').attr({
    //     value: media.getEstimatedTime(),
    //     max: media.media.duration
    // });
    $('.current-time').text(toHHMMSS(media.getEstimatedTime()));
    $('.duration').text(toHHMMSS(media.media.duration));
}

function activeMedia() {
    return media();
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
    console.log('updating ui');
    show('#no-devices-available', context().getCastState() == cf.CastState.NO_DEVICES_AVAILABLE);
    show('#connected', context().getCastState() == cf.CastState.CONNECTED);
    $('#connected-receiver-name').text(session() && session().getCastDevice().friendlyName);
    show('#request-session-button', _in(context().getSessionState(), cf.SessionState.NO_SESSION, cf.SessionState.SESSION_ENDED));
    show('#leave-session-button', _in(context().getSessionState(), cf.SessionState.SESSION_STARTED, cf.SessionState.SESSION_RESUMED));
    show('#stop-session-button', _in(context().getSessionState(), cf.SessionState.SESSION_STARTED, cf.SessionState.SESSION_RESUMED));
    var m = media();
    var ss = session() && session().getSessionState();
    var ps = m && m.playerState;
    console.log(ps);
    show('#pause-button', ps && _in(ps, 'PLAYING', 'BUFFERING'));
    show('#play-button', ps && !_in(ps, 'PLAYING', 'IDLE'));
    show('#stop-button', ps && ps != 'IDLE');
    // show('#loading-button', loading);
    show('#player', rp.isMediaLoaded);
    show('#loaded-button', rp.isMediaLoaded);
    $1('#media-form .load').prop('disabled', !session());
    updateProgress();
}

function setClickHandlers() {
    $1('#progress-bar').on('click', function(e) {
        var sr = new chrome.cast.media.SeekRequest();
        sr.currentTime = e.offsetX/e.target.clientWidth*activeMedia().media.duration;
        activeMedia().seek(sr, null, onError);
    });
    $1('#pause-button').on('click', function() {
        // rpc.playOrPause();
        activeMedia().pause(null, null, onError);
    });
    $1('#play-button').on('click', function() {
        // rpc.playOrPause();
        activeMedia().play(null, null, onError);
    });
    $1('#stop-button').on('click', function() {
        // activeMedia().stop(null, null, onError);
        // media().stop();
        rpc.stop();
    });
    $1('#leave-session-button').on('click', function() {
        context().endCurrentSession(false);
    });
    $1('#stop-session-button').on('click', function() {
        context().endCurrentSession(true);
    });
    $1('#request-session-button').on('click', function() {
        context().requestSession().then(gotSession, onError);
    });
    $1('#new-url').val();
    $1('#subtitles').val(parsedFragment.getLast('subtitles'));
    $1('#proposed textarea').on('click', function() {
        $(this).select();
    });
    $1('#media-form .load').on('click', function() {
        loadMedia(getMediaSpecFromForm());
    });
}

$(document).ready(function() {
    setClickHandlers();
    $('#media-form').on('show.bs.modal', function(event) {
        var id = event.relatedTarget.id;
        console.log(id);
        switch (id) {
        case 'proposed-button':
            setMediaFormFromSpec(proposedMediaSpec());
            break;
        case 'loaded-button':
            setMediaFormFromSpec(loadedMediaSpec());
            break
        default:
            throw(id);
        }
    });
});

function setMediaFormFromSpec(spec) {
    console.log(spec);
    $1('#media-form .content.url').val(spec.url);
    $1('#media-form .subtitles.url').val(spec.subtitles);
    $1('#media-form .title').val(spec.title);
    $1('#media-form .poster').val(spec.poster);
    $1('#media-form .subtitle').val(spec.subtitle);
}

function getMediaSpecFromForm() {
    return {
        url: $('#media-form .content').val(),
        subtitles: $('#media-form .subtitles').val(),
        title: $('#media-form .title').val(),
        poster: $('#media-form .poster').val(),
        subtitle: $('#media-form .subtitle').val()
    };
}

function proposedMediaSpec() {
    return {
        url: parsedFragment.getLast('content') || 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        subtitles: parsedFragment.getLast('subtitles'),
        title: parsedFragment.getLast('title'),
        poster: parsedFragment.getLast('poster'),
        subtitle: parsedFragment.getLast('subtitle')};
}

function loadProposedMedia() {
    loadMedia(proposedMediaSpec());
}

function urlDecode(str) {
    return decodeURIComponent(str.replace(/\+/g, ' '));
}

function parseFragment() {
    var ret = new MultiMap;
    window.location.hash.substr(1).split('&').forEach(function(field) {
        var tuple = field.split('=');
        ret.add(urlDecode(tuple.shift()), urlDecode(tuple.join('=')));
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

function _in(a) {
    for (var i = 1; i < arguments.length; i++) {
        if (arguments[i] == a) return true;
    }
    return false;
}

function $1(sel) {
    var j = $(sel);
    if (!j.length) console.log('selection matched nothing', sel);
    return j;
}

var $plus = $1;

function loadedMediaSpec() {
    var m = media();
    var mi = m.media;
    var md = mi.metadata;
    return {
        url: mi.contentId,
        subtitles: mi.tracks && mi.tracks[0].trackContentId,
        poster: md.images && md.images[0].url,
        title: md.title,
        subtitle: md.subtitle
    };
}
