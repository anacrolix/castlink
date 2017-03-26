port module Cast exposing (..)


type alias ApiAvailability =
    { loaded : Bool
    , error : Maybe String
    }


port onGCastApiAvailability : (ApiAvailability -> msg) -> Sub msg


onApiAvailability =
    onGCastApiAvailability


apiNotLoaded : ApiAvailability
apiNotLoaded =
    { loaded = False, error = Nothing }
