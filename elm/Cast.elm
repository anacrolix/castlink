port module Cast exposing (..)


type alias ApiAvailability =
    { loaded : Bool
    , error : Maybe String
    }


type alias Context =
    { session : Maybe Session
    , castState : CastState
    }


type alias CastState =
    String


type alias Session =
    { state : SessionState }


type alias SessionState =
    String


port onGCastApiAvailability : (ApiAvailability -> msg) -> Sub msg


port context : (Context -> msg) -> Sub msg


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
