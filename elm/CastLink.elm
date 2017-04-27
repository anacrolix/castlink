module CastLink exposing (..)

import Debug exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Cast exposing (defaultOptions)
import Json.Encode
import List
import Bootstrap exposing (..)
import Navigation exposing (..)
import Bootstrap.Grid as Grid
import Bootstrap.Navbar as Navbar
import Bootstrap.Card as Card
import Bootstrap.Button as Button
import Bootstrap.Alert as Alert


main : Program Never Model Msg
main =
    Navigation.program UrlChange
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type Msg
    = ApiAvailability Cast.ApiAvailability
    | CastContext Cast.JsContext
    | RequestSession
    | UrlChange Navigation.Location
    | Navigate String
    | NavbarMsg Navbar.State


type alias Model =
    { api : Cast.ApiAvailability
    , setOptions : Bool
    , context : Maybe Cast.Context
    , navbarState : Navbar.State
    }


init : Location -> ( Model, Cmd Msg )
init location =
    let
        ( navbarState, navbarCmd ) =
            Navbar.initialState NavbarMsg
    in
        ( { api = Cast.apiNotLoaded
          , setOptions = False
          , context = Nothing
          , navbarState = navbarState
          }
        , navbarCmd
        )


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
    Grid.container [] <|
        [ Navbar.config NavbarMsg
            |> Navbar.brand [ href "#" ] [ text "chromecast.link" ]
            |> Navbar.inverse
            |> Navbar.items
                [ Navbar.itemLinkActive [ href "#" ] [ text "Link caster" ]
                , Navbar.itemLink [ href "#about" ] [ text "About" ]
                , Navbar.itemLink [ href "#dev" ] [ text "Use on your website" ]
                ]
            |> Navbar.view model.navbarState
        ]
            ++ viewContents model
            ++ viewFooter model


cardHeader s =
    Card.headerH4 [] [ text s ]


viewContents : Model -> List (Html Msg)
viewContents model =
    List.map (\f -> f model) [ sessionCard, playerCard, mediaCard ]


sessionCard : Model -> Html Msg
sessionCard model =
    let
        contents =
            List.map Card.custom <|
                List.concat
                    [ maybeToList <| contextAlerts model
                    , List.singleton <|
                        case model.api.loaded of
                            True ->
                                Bootstrap.button Primary (Just "sign-in") [ onClick RequestSession ] "Connect"

                            False ->
                                p [] [ text "not loaded" ]
                    ]
    in
        Card.config []
            |> cardHeader "Session"
            |> Card.block [] contents
            |> Card.view


mediaCard : Model -> Html Msg
mediaCard model =
    Card.config []
        |> cardHeader "Media"
        |> Card.block []
            [ Card.custom <|
                Button.button [ Button.primary ] [ text "Load into Player" ]
            ]
        |> Card.view


playerCard : Model -> Html Msg
playerCard model =
    Card.config []
        |> cardHeader "Player"
        |> Card.block []
            [ Card.custom <|
                Button.button [ Button.primary ] [ text "Play" ]
            ]
        |> Card.view


viewFooter model =
    [ p [] []
    , p [ class "text-muted small text-center" ]
        [ a
            [ class "text-muted"
            , href "mailto:anacrolix@gmail.com"
            ]
            [ text "Questions, suggestions, support: "
            , span [ class "small glyphicon glyphicon-envelope" ] []
            , text "anacrolix@gmail.com"
            ]
        ]
    , ad
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


type alias UpdateFn msg model =
    msg -> model -> ( model, Cmd msg )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        _ =
            Debug.log "update" msg
    in
        chainUpdates msg model [ mainUpdate, setOptions ]


chainUpdates : msg -> model -> List (UpdateFn msg model) -> ( model, Cmd msg )
chainUpdates msg model updates =
    let
        merge =
            \update ( lastModel, lastCmd ) ->
                let
                    ( nextModel, nextCmd ) =
                        update msg lastModel
                in
                    ( nextModel, Cmd.batch [ lastCmd, nextCmd ] )
    in
        List.foldr merge ( model, Cmd.none ) updates


type alias Update model msg =
    msg -> model -> ( model, Cmd msg )


type alias Updater model msg =
    { model : model
    , cmd : Cmd msg
    , msg : msg
    }


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
                ( { model | context = Just <| Cast.jsToElmContext context }, Cmd.none )

        RequestSession ->
            ( model, Cast.requestSession () )

        UrlChange loc ->
            let
                _ =
                    log "UrlChange" loc
            in
                ( model, Cmd.none )

        Navigate url ->
            let
                _ =
                    log "Navigate" url
            in
                ( model, newUrl url )

        NavbarMsg state ->
            ( { model | navbarState = state }, Cmd.none )


setOptions : Msg -> Model -> ( Model, Cmd msg )
setOptions _ model =
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
<ins class="adsbygoogle"
 style="display:block"
 data-ad-client="ca-pub-5195063250458873"
 data-ad-slot="4804343597"
 data-ad-format="auto"></ins>
<script>
(adsbygoogle = window.adsbygoogle || []).push({});
</script>
"""


ad : Html msg
ad =
    div [ property "innerHTML" <| Json.Encode.string adBlob ] []
