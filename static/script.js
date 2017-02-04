var parsedFragment = parseFragment();
var receiverApplicationId = '911A4C88';
var cf;
var rp;
var rpc;
var loading = false;

window['__onGCastApiAvailable'] = function(loaded, errorInfo) {
    console.log('__onGCastApiAvailable', loaded, errorInfo);
    $(document).ready(function() {
        $1('#api-not-available').hide();
    });
    if (loaded) {
        onAPIAvailable();
    } else {
        $(document).ready(function() {
            $1('#api-init-error-info').text(errorInfo+'.');
            $1('#api-init-error').show();
        });
    }
    $(document).ready(updateUI());
}

function apiReady() {
    return cf;
}

function context() {
    return cf && cast.framework.CastContext.getInstance();
}

function session() {
    return context() && context().getCurrentSession();
}

function media() {
    var s = session();
    return s && s.getMediaSession();
}

function onAPIAvailable() {
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
    var tracks = [];
    if (spec.subtitles) {
        var enSubs = new chrome.cast.media.Track(1, chrome.cast.media.TrackType.TEXT);
        enSubs.trackContentId = spec.subtitles;
        enSubs.trackContentType = 'text/vtt';
        enSubs.subtype = chrome.cast.media.TextTrackType.SUBTITLES;
        enSubs.language = 'en-US';
        tracks.push(enSubs);
    }
    var mediaInfo = new chrome.cast.media.MediaInfo(url, 'video/mp4');
    var metadata = new chrome.cast.media.GenericMediaMetadata();
    if (poster) {
        metadata.images = [new chrome.cast.Image(poster)];
    }
    metadata.metadataType = chrome.cast.media.MetadataType.GENERIC;
    if (title) {
        metadata.title = title;
    }
    metadata.subtitle = subtitle || url;
    mediaInfo.metadata = metadata;
    mediaInfo.tracks = tracks;
    mediaInfo.textTrackStyle = new chrome.cast.media.TextTrackStyle();
    var request = new chrome.cast.media.LoadRequest(mediaInfo);
    if (spec.subtitles) {
        request.activeTrackIds = [1];
    }
    request.autoplay = true;
    console.log(session(), request);
    loading = true;
    session().loadMedia(request).then(mediaLoaded, mediaLoadError);
    updateUI();
}

function mediaLoaded() {
    console.log('media loaded');
    loading = false;
    updateUI();
}

function mediaLoadError(e) {
    console.log('error loading media', e);
    loading = false;
    updateUI();
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

function updateUI() {
    console.log('updating ui');
    show('#connecting', context() && context().getCastState() == cf.CastState.CONNECTING);
    show('#session', apiReady());
    show('#player', apiReady());
    show('#no-devices-available', context() && context().getCastState() == cf.CastState.NO_DEVICES_AVAILABLE);
    show('#connected', context() && context().getCastState() == cf.CastState.CONNECTED);
    show('#not-connected', !context() || context().getCastState() == cf.CastState.NOT_CONNECTED);
    $('#connected-receiver-name').text(session() && session().getCastDevice().friendlyName);
    $1('#request-session-button').prop('disabled', !(context() && _in(context().getSessionState(),
        cf.SessionState.NO_SESSION,
        cf.SessionState.SESSION_ENDED,
        cf.SessionState.SESSION_START_FAILED
    )));
    show('#leave-session-button', apiReady() && _in(context().getSessionState(), cf.SessionState.SESSION_STARTED, cf.SessionState.SESSION_RESUMED));
    show('#stop-session-button', apiReady() && _in(context().getSessionState(), cf.SessionState.SESSION_STARTED, cf.SessionState.SESSION_RESUMED));
    var m = media();
    var ss = session() && session().getSessionState();
    var ps = m && m.playerState;
    show('#pause-button', ps && _in(ps, 'PLAYING', 'BUFFERING'));
    show('#play-button', ps && _in(ps, 'PAUSED'));
    show('#stop-button', ps && ps != 'IDLE');
    $1('#load-button').prop('disabled', !(session() && !mediaSpecsEqual(loadedMediaSpec(), getMediaSpecFromForm()) && getMediaSpecFromForm().url));
    show('#load-button', !loading);
    $1('#copy-button').prop('disabled', !(apiReady() && rp.isMediaLoaded && !mediaSpecsEqual(loadedMediaSpec(), getMediaSpecFromForm())));
    show('#progress', apiReady() && rp.isMediaLoaded);
    updateProgress();
    show('#no-media-loaded', !apiReady() || !rp.isMediaLoaded);
    show('#loading-button', loading);
    show('#player-controls', apiReady() && rp.isMediaLoaded && rp.isConnected);
    $('textarea').each(function() {
        $(this).height(1);
        $(this).height(this.scrollHeight-($(this).innerHeight()-$(this).height()));
    });
}

function setClickHandlers() {
    $1('#progress div.progress').on('click', function(e) {
        rp.currentTime = e.offsetX/e.currentTarget.clientWidth*rp.duration;
        rpc.seek();
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
        // session().getSessionObj().leave(function() {}, onError);
    });
    $1('#stop-session-button').on('click', function() {
        context().endCurrentSession(true);
        // session().getSessionObj().stop(function() {}, onError);
    });
    $1('#request-session-button').on('click', function() {
        context().requestSession().then(gotSession, onError);
    });
    $1('#load-button').on('click', function() {
        loadMedia(getMediaSpecFromForm());
    });
    $1('#copy-button').on('click', function() {
        setMediaFormFromSpec(loadedMediaSpec());
        updateUI();
    });
    $('#example-button').click(function() {
        setMediaFormFromSpec(exampleMediaSpec());
    });
    $('button.seek-backward').click(function(event) {
        rp.currentTime -= $(event.target).data('seconds');
        rpc.seek();
    })
    $('button.seek-forward').click(function(event) {
        rp.currentTime += $(event.target).data('seconds');
        rpc.seek();
    })
    $1('#set-link').click(function() {
        window.history.pushState(null, "", linkFromMediaSpec(getMediaSpecFromForm()));
    });
}

$(document).ready(function() {
    setClickHandlers();
    $('#media-forms').on("input",function() {
        updateUI();
    });
    setMediaFormFromSpec(mediaSpecFromFragment());
});

function setMediaFormFromSpec(spec) {
    console.log('setting media form from spec', spec);
    $1('#media-content').val(spec.url);
    $1('#media-subtitles').val(spec.subtitles);
    $1('#media-title').val(spec.title);
    $1('#media-poster').val(spec.poster);
    $1('#media-subtitle').val(spec.subtitle);
    updateUI();
}

function getMediaSpecFromForm() {
    return {
        url: $1('#media-content').val() || null,
        subtitles: $1('#media-subtitles').val() || null,
        title: $1('#media-title').val() || null,
        poster: $1('#media-poster').val() || null,
        subtitle: $1('#media-subtitle').val() || null
    };
}

function mediaSpecFromFragment() {
    return {
        url: parsedFragment.getLast('content'),
        subtitles: parsedFragment.getLast('subtitles'),
        title: parsedFragment.getLast('title'),
        poster: parsedFragment.getLast('poster'),
        subtitle: parsedFragment.getLast('subtitle')
    };
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
    var mi = m && m.media;
    var md = mi && mi.metadata;
    return {
        url: mi && mi.contentId,
        subtitles: mi && mi.tracks && mi.tracks.length && mi.tracks[0].trackContentId,
        poster: md && md.images && md.images[0].url,
        title: md && md.title,
        subtitle: md && md.subtitle
    };
}

function mediaSpecsEqual(a, b) {
    return (
        a.url       == b.url &&
        a.subtitles == b.subtitles &&
        a.poster    == b.poster &&
        a.title     == b.title &&
        a.subtitle  == b.subtitle);
}

function linkFromMediaSpec(spec) {
    var pairs = [];
    for (var k in spec) {
        if (!spec.hasOwnProperty(k)) continue;
        var v = spec[k];
        if (!v) continue;
        pairs.push(encodeURIComponent(k)+'='+encodeURIComponent(v));
    }
    var f = pairs.join('&');
    var ret = '/';
    if (f) ret += '#' + f;
    return ret;
}

function exampleMediaSpec() {
    return {
        url: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        subtitle: '1280x720 h264',
        title: 'Big Buck Bunny',
        poster: 'https://upload.wikimedia.org/wikipedia/commons/c/c5/Big_buck_bunny_poster_big.jpg'
    };
}
