port module Cast exposing (..)

import Debug


type alias ApiAvailability =
    { loaded : Bool
    , error : Maybe String
    }


type alias JsContext =
    { session :
        Maybe
            { state : SessionState
            , media :
                Maybe
                    { duration : Maybe Float
                    , currentTime : Float
                    , playerState : String
                    , spec : Media
                    }
            , deviceName : String
            }
    , castState : String
    }


type alias Context =
    { session : Maybe Session
    , castState : CastState
    }


type alias Session =
    { state : SessionState
    , media : Maybe SessionMedia
    , deviceName : String
    }


type alias SessionState =
    String


type alias SessionMedia =
    { duration : Maybe Float
    , currentTime : Float
    , playerState : PlayerState
    , spec : Media
    }


fromJsContext : JsContext -> Context
fromJsContext c =
    { c
        | castState = castStateFromString c.castState
        , session =
            Maybe.map
                (\s ->
                    { s
                        | media =
                            Maybe.map
                                (\m -> { m | playerState = toPlayerState m.playerState })
                                s.media
                    }
                )
                c.session
    }


type CastState
    = NoDevicesAvailable
    | NotConnected
    | Connecting
    | Connected


castStateFromString : String -> CastState
castStateFromString s =
    case s of
        "NO_DEVICES_AVAILABLE" ->
            NoDevicesAvailable

        "NOT_CONNECTED" ->
            NotConnected

        "CONNECTING" ->
            Connecting

        "CONNECTED" ->
            Connected

        uff ->
            Debug.crash uff


toPlayerState : String -> PlayerState
toPlayerState s =
    case s of
        "IDLE" ->
            Idle

        "PLAYING" ->
            Playing

        "PAUSED" ->
            Paused

        "BUFFERING" ->
            Buffering

        uff ->
            Debug.crash uff


port onGCastApiAvailability : (ApiAvailability -> msg) -> Sub msg


port context : (JsContext -> msg) -> Sub msg


port setOptions : Options -> Cmd msg


port requestSession : () -> Cmd msg


port loadMedia : Media -> Cmd msg


port mediaLoaded : (Maybe String -> msg) -> Sub msg


port controlPlayer : JsPlayerAction -> Cmd msg


type alias JsPlayerAction =
    { playOrPause : Bool
    , seek : Maybe Float
    , stop : Bool
    }


type PlayerAction
    = PlayOrPause
    | Seek Float
    | Stop


type PlayerState
    = Idle
    | Playing
    | Paused
    | Buffering


emptyPlayerAction : JsPlayerAction
emptyPlayerAction =
    { playOrPause = False
    , seek = Nothing
    , stop = False
    }


toJsPlayerAction : PlayerAction -> JsPlayerAction
toJsPlayerAction pa =
    case pa of
        PlayOrPause ->
            { emptyPlayerAction | playOrPause = True }

        Seek time ->
            { emptyPlayerAction | seek = Just time }

        Stop ->
            { emptyPlayerAction | stop = True }


type alias AutoJoinPolicy =
    String


originScoped : AutoJoinPolicy
originScoped =
    "ORIGIN_SCOPED"


type alias Options =
    { autoJoinPolicy : AutoJoinPolicy
    , language : Maybe String
    , receiverApplicationId : Maybe String
    , resumeSavedSession : Bool
    }


defaultOptions : Options
defaultOptions =
    { autoJoinPolicy = originScoped
    , language = Nothing
    , receiverApplicationId = Nothing
    , resumeSavedSession = True
    }


onApiAvailability : (ApiAvailability -> msg) -> Sub msg
onApiAvailability =
    onGCastApiAvailability


apiNotLoaded : ApiAvailability
apiNotLoaded =
    { loaded = False, error = Nothing }


type alias Media =
    { url : String
    , title : String
    , subtitle : String
    , poster : String
    , subtitles : List String
    }


exampleMedia : Media
exampleMedia =
    { url = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    , subtitle = "1280x720 h264"
    , title = "Big Buck Bunny"
    , poster = "https://upload.wikimedia.org/wikipedia/commons/c/c5/Big_buck_bunny_poster_big.jpg"
    , subtitles = []
    }
