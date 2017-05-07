var gCastApiAvailable = new Promise((resolve, reject) => {
	window['__onGCastApiAvailable'] =
		(loaded, error) => {
			console.log('resolving __onGCastApiAvailable', loaded, error)
			if (!error) error = null
			resolve({loaded, error})
		}
});
function context() {
	return cast.framework.CastContext.getInstance()
}
function session() {
		return context() && context().getCurrentSession();
}
function ifTrue(value, onTrue) {
	if (!value) return value;
	return onTrue(value);
}
var app = Elm.CastLink.fullscreen()
function elmCastContext(c) {
	return {
		castState: c.getCastState(),
		session: (s => {
			if (!s) return null;
			return {
				state: s.getSessionState(),
				media: ifTrue(s.getMediaSession(), m => {
					return {
						duration: m.media.duration,
						currentTime: m.getEstimatedTime(),
						playerState: m.playerState,
						spec: (() => {
							const mi = m.media;
							const md = mi.metadata;
							return {
								url: m.media.contentId,
								subtitles: mi.tracks.map(t => t.trackContentId),
								poster: md.images[0].url,
								title: md.title,
								subtitle: md.subtitle,
							};
						})(),
					};
				}),
			}
		})(c.getCurrentSession())
	}
}
function sendContext() {
	const c = elmCastContext(context())
	console.log('sending context', c)
	app.ports.context.send(c)
}
function initRemotePlayer() {
	rp = new cast.framework.RemotePlayer();
	rpc = new cast.framework.RemotePlayerController(rp);
	rpc.addEventListener(cast.framework.RemotePlayerEventType.ANY_CHANGE, remotePlayerChanged);
}
function remotePlayerChanged(event) {
    console.log('remote player changed', event);
    sendContext()
}
gCastApiAvailable.then(value => {
	console.log('sending api availability', value)
	app.ports.onGCastApiAvailability.send(value)
	context().addEventListener(cast.framework.CastContextEventType.CAST_STATE_CHANGED, sendContext);
	context().addEventListener(cast.framework.CastContextEventType.SESSION_STATE_CHANGED, sendContext);
	initRemotePlayer()
	sendContext()
})
app.ports.setOptions.subscribe(options => {
	console.log('setting options', options)
	cast.framework.CastContext.getInstance().setOptions(options)
})
app.ports.requestSession.subscribe(() => {
	context().requestSession()
})
app.ports.loadMedia.subscribe(spec => {
	var url = spec.url;
	var title = spec.title;
	var subtitle = spec.subtitle;
	var poster = spec.poster;
	var mediaInfo = new chrome.cast.media.MediaInfo(url, 'video/mp4');
	mediaInfo.tracks = spec.subtitles.map((val, i) => {
		var subs = new chrome.cast.media.Track(i+1, chrome.cast.media.TrackType.TEXT);
		subs.trackContentId = val;
		subs.trackContentType = 'text/vtt';
		subs.subtype = chrome.cast.media.TextTrackType.SUBTITLES;
		subs.language = 'en-US';
		return subs;
	});
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
	mediaInfo.textTrackStyle = new chrome.cast.media.TextTrackStyle();
	var request = new chrome.cast.media.LoadRequest(mediaInfo);
	if (mediaInfo.tracks.length) {
			request.activeTrackIds = [1];
	}
	request.autoplay = true;
	loading = true;
	session().loadMedia(request).then(mediaLoaded, errorLoadingMedia);
})
app.ports.controlPlayer.subscribe(action => {
	const rp = new cast.framework.RemotePlayer();
	const rpc = new cast.framework.RemotePlayerController(rp);
	if (action.playOrPause) {
		rpc.playOrPause();
	}
	if (action.seek !== null) {
		rp.currentTime = action.seek;
		rpc.seek();
	}
	if (action.stop) {
		rpc.stop();
	}
});
function mediaLoaded() {
	sendMediaLoaded(null)
}
function errorLoadingMedia(e) {
	console.log('error loading media', e)
	sendMediaLoaded(e)
}
function sendMediaLoaded(e) {
	app.ports.mediaLoaded.send(e)
}
// app.ports.gCastApiAvailable.subscribe(function() {
//   console.log('subscribing')
//   if (cast.framework) {
//     app.ports.onGCastApiAvailable.send({
//       loaded: true,
//       error: null,
//     })
//     return
//   }
// })
