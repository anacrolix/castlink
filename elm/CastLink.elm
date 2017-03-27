module CastLink exposing (..)

import Debug exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Cast exposing (defaultOptions)
import Json.Encode
import Bootstrap exposing (..)


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type Msg
    = ApiAvailability Cast.ApiAvailability
    | CastContext Cast.Context
    | RequestSession


type alias Model =
    { api : Cast.ApiAvailability
    , setOptions : Bool
    , context : Maybe Cast.Context
    }


init : ( Model, Cmd msg )
init =
    ( initialModel, Cmd.none )


initialModel : Model
initialModel =
    { api = Cast.apiNotLoaded
    , setOptions = False
    , context = Nothing
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Cast.onApiAvailability ApiAvailability
        , Cast.context CastContext
        ]


maybeToList : Maybe a -> List a
maybeToList maybe =
    case maybe of
        Just value ->
            List.singleton value

        Nothing ->
            []


view : Model -> Html Msg
view model =
    fluidContainer <|
        List.concat <|
            [ [ navbar "chromecast.link" [ { href = "/about", title = "About" } ]
              , p [] []
              ]
            , maybeToList <| contextAlerts model
            , [ case model.api.loaded of
                    True ->
                        Bootstrap.button Primary (Just "sign-in") [ onClick RequestSession ] "Connect"

                    False ->
                        p [] [ text "not loaded" ]
              , Bootstrap.footer
              , ad
              ]
            ]


contextAlerts : Model -> Maybe (Html msg)
contextAlerts model =
    let
        api =
            model.api
    in
        case api.loaded of
            True ->
                case api.error of
                    Just msg ->
                        Just <| simpleAlert Danger msg "You may need to use Chrome, or an Android device."

                    Nothing ->
                        Nothing

            False ->
                Just <| simpleAlert Warning "API not loaded." "Session and player functions not yet available."


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    let
        ( model2, cmd1 ) =
            mainUpdate msg model

        ( model3, cmd2 ) =
            setOptions model2
    in
        ( model3, Cmd.batch [ cmd1, cmd2 ] )


mainUpdate : Msg -> Model -> ( Model, Cmd msg )
mainUpdate msg model =
    case msg of
        ApiAvailability api ->
            ( { model | api = api }, Cmd.none )

        CastContext context ->
            let
                _ =
                    log "cast context" context
            in
                ( { model | context = Just context }, Cmd.none )

        RequestSession ->
            ( model, Cast.requestSession () )


setOptions : Model -> ( Model, Cmd msg )
setOptions model =
    if model.api.loaded && not model.setOptions then
        ( { model | setOptions = True }
        , Cast.setOptions
            { defaultOptions
                | resumeSavedSession = True
                , receiverApplicationId = Just "911A4C88"
            }
        )
    else
        ( model, Cmd.none )


adBlob : String
adBlob =
    """
<script async src="//pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<!-- castlink responsive -->
<ins class="adsbygoogle"
 style="display:block"
 data-ad-client="ca-pub-5195063250458873"
 data-ad-slot="4804343597"
 data-ad-format="auto"></ins>
<script>
(adsbygoogle = window.adsbygoogle || []).push({});
</script>"""


ad : Html msg
ad =
    div [ property "innerHTML" <| Json.Encode.string adBlob ] []
