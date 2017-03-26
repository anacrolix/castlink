module CastLink exposing (..)

import Html exposing (..)
import Maybe
import Cast


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type Msg
    = CastApiAvailable Cast.ApiAvailability


type alias Model =
    Cast.ApiAvailability



--port onGCastApiAvailability :    Cast.onApiAvailability


init =
    ( Cast.apiNotLoaded, Cmd.none )


subscriptions model =
    Cast.onApiAvailability CastApiAvailable


view model =
    case model.loaded of
        True ->
            p [] [ text "loaded" ]

        False ->
            p [] [ text "not loaded" ]


update msg model =
    case msg of
        CastApiAvailable api ->
            ( api, Cmd.none )
