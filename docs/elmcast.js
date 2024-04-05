var gCastApiAvailable = new Promise((resolve, reject) => {
	window['__onGCastApiAvailable'] =
		(loaded, error) => {
			console.log('resolving __onGCastApiAvailable', loaded, error)
			if (!error) error = null;
			resolve({loaded, error});
		};
});
function getContext() {
	return cast.framework.CastContext.getInstance();
}
function getSession() {
		return getContext()?.getCurrentSession();
}
function ifTrue(value, onTrue) {
	if (!value) return value;
	return onTrue(value);
}
function undefinedToNull(value) {
	if (value === undefined) return null;
	return value;
}
var app = Elm.CastLink.init({});
function elmCastContext(c) {
	return {
		castState: c.getCastState(),
		session: (s => {
			if (!s) return null;
			return {
				state: s.getSessionState(),
				media: ifTrue(s.getMediaSession(), m => {
					return {
						activeTrackIds: m.activeTrackIds ?? [],
						duration: m.media?.duration ?? null,
						currentTime: m.getEstimatedTime(),
						playerState: m.playerState,
						spec: (() => {
							const mi = m.media;
							const md = mi.metadata;
							return {
								url: m.media.contentId,
								subtitles: ifTrue(mi.tracks, ts => ts
									.filter(t => typeof t.trackContentId == 'string')
									.map(t => ({
										trackContentId: t.trackContentId,
										language: t.language,
										name: t.name ?? null,
										trackId: t.trackId,
									}))),
								poster: md.images?.[0].url ?? '',
								title: md.title ?? '',
								subtitle: md.subtitle,
							};
						})(),
					};
				}),
				deviceName: s.getCastDevice().friendlyName,
			}
		})(c.getCurrentSession())
	};
}
function sendContext() {
	const context = getContext();
	const elm = elmCastContext(context);
	console.log('sending context, elm', elm, 'js', context);
	app.ports.context.send(elm);
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
	const context = getContext();
	context.addEventListener(
		cast.framework.CastContextEventType.CAST_STATE_CHANGED,
		(event) => {
			console.log('cast state changed', event);
			initRemotePlayer();
			sendContext();
		});
	context.addEventListener(
		cast.framework.CastContextEventType.SESSION_STATE_CHANGED,
		logEventAndSendContext('session state changed'));
	sendContext();
})
app.ports.setOptions.subscribe(options => {
	console.log('setting options', options);
	cast.framework.CastContext.getInstance().setOptions(options);
})
app.ports.requestSession.subscribe(() => {
	getContext().requestSession().then(result => {
		console.log('request session fullfilled:', result);
		getSession().addEventListener(cast.framework.SessionEventType.MEDIA_SESSION, (event) => {
			console.log('cast session media session changed');
			sendContext();
		});
		getSession().addEventListener(cast.framework.SessionEventType.APPLICATION_STATUS_CHANGED, (event) => {
			console.log('session application status changed', event.status);
			sendContext();
		});
		sendContext();
	}, err => {
		console.log('request session rejected:', err);
		sendContext();
	});
})
app.ports.loadMedia.subscribe(elmRequest => {
	const spec = elmRequest.media;
	const url = spec.url;
	const title = spec.title;
	const subtitle = spec.subtitle;
	const poster = spec.poster;
	const mediaInfo = new chrome.cast.media.MediaInfo(url, 'video/mp4');
	mediaInfo.tracks = spec.subtitles.map((val) => {
		const track = new chrome.cast.media.Track(val.trackId, chrome.cast.media.TrackType.TEXT);
		track.trackContentId = val.trackContentId;
		track.trackContentType = 'text/vtt';
		track.subtype = chrome.cast.media.TextTrackType.SUBTITLES;
		track.language = val.language ?? 'en-US';
		track.name = val.name;
		return track;
	});
	const metadata = new chrome.cast.media.GenericMediaMetadata();
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
	const request = new chrome.cast.media.LoadRequest(mediaInfo);
	request.activeTrackIds = elmRequest.activeTrackIds;
	request.autoplay = false;
	getSession().loadMedia(request).then(() => {
		sendMediaLoaded(null);
	}, (e) => {
		console.log('error loading media', e);
		sendMediaLoaded(e);
	});
});
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
app.ports.endCurrentSession.subscribe(stopCasting => {
	getContext().endCurrentSession(stopCasting);
});

app.ports.editTracks.subscribe(activeTrackIds => {
	const request = new chrome.cast.media.EditTracksInfoRequest(activeTrackIds);
	const ms = getSession()?.getMediaSession();
	if (!ms) {
		console.log('error editing tracks, no media session');
		return;
	}
	ms.editTracksInfo(request, function() {
		console.log('success editing tracks', activeTrackIds);
	}, function(e) {
		console.log('error editing tracks', e);
	})
})

function sendMediaLoaded(e) {
	app.ports.mediaLoaded.send(e);
}

const logEventAndSendContext = (msg) => (event) => {
	console.log(msg, event);
	sendContext();
}