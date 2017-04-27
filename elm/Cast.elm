port module Cast exposing (..)

import Debug


type alias ApiAvailability =
    { loaded : Bool
    , error : Maybe String
    }


type alias JsContext =
    { session : Maybe Session
    , castState : String
    }


type alias Context =
    { session : Maybe Session
    , castState : CastState
    }


jsToElmContext : JsContext -> Context
jsToElmContext js =
    { js | castState = castStateFromString js.castState }


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



--type alias CastState =
--    String


type alias Session =
    { state : SessionState }


type alias SessionState =
    String


port onGCastApiAvailability : (ApiAvailability -> msg) -> Sub msg


port context : (JsContext -> msg) -> Sub msg


port setOptions : Options -> Cmd msg


port requestSession : () -> Cmd msg


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


onApiAvailability =
    onGCastApiAvailability


apiNotLoaded : ApiAvailability
apiNotLoaded =
    { loaded = False, error = Nothing }
