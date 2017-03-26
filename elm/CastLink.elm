module CastLink exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Cast
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
    = CastApiAvailable Cast.ApiAvailability


type alias Model =
    Cast.ApiAvailability


init =
    ( Cast.apiNotLoaded, Cmd.none )


subscriptions model =
    Cast.onApiAvailability CastApiAvailable


maybeToList : Maybe a -> List a
maybeToList maybe =
    case maybe of
        Just value ->
            List.singleton value

        Nothing ->
            []


view : Model -> Html msg
view model =
    fluidContainer <|
        List.concat <|
            [ [ navbar "chromecast.link" [ { href = "/about", title = "About" } ]
              , p [] []
              ]
            , maybeToList <| contextAlerts model
            , [ case model.loaded of
                    True ->
                        p [] [ text "loaded" ]

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
            model
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


update msg model =
    case msg of
        CastApiAvailable api ->
            ( api, Cmd.none )


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
