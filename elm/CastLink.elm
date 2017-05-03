module CastLink exposing (..)

import Debug exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Json.Encode
import List
import Cast exposing (..)
import Bootstrap exposing (..)
import Navigation exposing (..)
import Bootstrap.Grid as Grid
import Bootstrap.Navbar as Navbar
import Bootstrap.Card as Card
import Bootstrap.Button as Button
import Bootstrap.Progress as Progress
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Json.Decode as JD exposing (..)
import Bootstrap.Form.Textarea as Textarea
import Maybe exposing (..)
import String


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
    | LoadMedia
    | ProposedMediaInput (Cast.Media -> String -> Cast.Media) String
    | ClickedPlayerControl Cast.PlayerAction
    | ProgressClicked Float


type alias Model =
    { api : Cast.ApiAvailability
    , setOptions : Bool
    , context : Maybe Cast.Context
    , navbarState : Navbar.State
    , proposedMedia : Cast.Media
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
          , proposedMedia = Cast.exampleMedia
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
                  --, Navbar.itemLink [ href "#about" ] [ text "About" ]
                  --, Navbar.itemLink [ href "#dev" ] [ text "Use on your website" ]
                ]
            |> Navbar.view model.navbarState
        ]
            ++ viewContents model
            ++ viewFooter model


cardHeader : String -> Card.Config Msg -> Card.Config Msg
cardHeader s =
    Card.headerH5 [] [ text s ]


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
                Button.button
                    [ Button.primary
                    , Button.onClick LoadMedia
                    ]
                    [ text "Load into Player" ]
            , Card.custom <|
                Form.form []
                    (let
                        pm =
                            model.proposedMedia
                     in
                        [ Form.group []
                            [ Form.label [] [ text "Title" ]
                            , Input.text
                                [ Input.onInput <| ProposedMediaInput <| \m s -> { m | title = s }
                                , Input.value pm.title
                                ]
                            ]
                        , Form.group []
                            [ Form.label [] [ text "Subtitle" ]
                            , Input.text
                                [ Input.onInput <| ProposedMediaInput <| \m s -> { m | subtitle = s }
                                , Input.value pm.subtitle
                                ]
                            ]
                        , Form.group []
                            [ Form.label [] [ text "Content URL" ]
                            , Textarea.textarea
                                [ Textarea.onInput <| ProposedMediaInput <| \m s -> { m | url = s }
                                , Textarea.value pm.url
                                ]
                            ]
                        , Form.group []
                            [ Form.label [] [ text "Subtitles URL" ]
                            , Textarea.textarea
                                [ Textarea.onInput <| ProposedMediaInput <| \m s -> { m | subtitles = [ s ] }
                                , Textarea.value <| Maybe.withDefault "" <| List.head pm.subtitles
                                ]
                            ]
                        , Form.group []
                            [ Form.label [] [ text "Poster URL" ]
                            , Textarea.textarea
                                [ Textarea.onInput <| ProposedMediaInput <| \m s -> { m | poster = s }
                                , Textarea.value pm.poster
                                ]
                            ]
                        ]
                    )
            ]
        |> Card.view


justList : List (Maybe a) -> List a
justList =
    let
        f m l =
            case m of
                Just value ->
                    value :: l

                Nothing ->
                    l
    in
        List.foldr f []


playerButtons : Model -> List (Html Msg)
playerButtons model =
    case model.context |> Maybe.andThen .session |> Maybe.andThen .media of
        Just { playerState } ->
            let
                pause =
                    ( [ Button.warning, Button.onClick <| ClickedPlayerControl Cast.PlayOrPause ], [ text "Pause" ] )

                play =
                    ( [ Button.primary, Button.onClick <| ClickedPlayerControl Cast.PlayOrPause ], [ text "Play" ] )
            in
                List.map (uncurry Button.button) <|
                    case playerState of
                        Idle ->
                            [ play ]

                        Playing ->
                            [ pause ]

                        Paused ->
                            [ play ]

                        Buffering ->
                            []

        Nothing ->
            []


progress : Model -> Maybe (Html Msg)
progress model =
    let
        andThen =
            Maybe.andThen

        media : Maybe Cast.SessionMedia
        media =
            model.context |> andThen .session |> andThen .media

        duration : Maybe Float
        duration =
            andThen .duration media

        elem : Cast.SessionMedia -> Float -> Html Msg
        elem media duration =
            Progress.progressWithAttrs [ Html.Events.on "click" decodeProgressClick ] <|
                [ Progress.attr <|
                    Html.Attributes.style
                        [ ( "width", (toString <| 100 * media.currentTime / duration) ++ "%" )
                        ]
                ]

        card media duration =
            Card.config []
                |> Card.block []
                    (List.map Card.custom
                        [ div []
                            [ span [] [ text <| secsToHhmmss << floor <| media.currentTime ]
                            , span [ style [ ( "float", "right" ) ] ] [ text <| secsToHhmmss << floor <| duration ]
                            ]
                        , elem media duration
                        ]
                    )
                |> Card.view
    in
        Maybe.map2 card media duration


secsToHhmmss : Int -> String
secsToHhmmss s =
    let
        extract ( q, mm ) =
            case mm of
                Just m ->
                    s // q % m

                Nothing ->
                    s // q

        format =
            String.padLeft 2 '0' << toString << extract
    in
        String.join ":" <|
            List.map format
                [ ( 3600, Nothing )
                , ( 60, Just 60 )
                , ( 1, Just 60 )
                ]


traceDecoder : JD.Decoder msg -> JD.Decoder msg
traceDecoder decoder =
    JD.value
        |> JD.andThen
            (\value ->
                case JD.decodeValue decoder value of
                    Ok decoded ->
                        JD.succeed <| Debug.log "herp" decoded

                    Err err ->
                        JD.fail <| Debug.log "error" <| err
            )


decodeProgressClick : Decoder Msg
decodeProgressClick =
    let
        f x w =
            ProgressClicked <| toFloat x / toFloat w
    in
        JD.map2 f
            (field "offsetX" int)
            (at [ "currentTarget", "clientWidth" ] int)


playerCard : Model -> Html Msg
playerCard model =
    Card.config []
        |> cardHeader "Player"
        |> Card.block []
            (List.map Card.custom <|
                (playerButtons model)
                    ++ let
                        card node =
                            Card.config [] |> Card.block [] [ Card.custom <| node ] |> Card.view
                       in
                        justList [ Maybe.map card <| progress model ]
            )
        |> Card.view


viewFooter : Model -> List (Html Msg)
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
                ( { model | context = Just <| Cast.fromJsContext context }, Cmd.none )

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

        LoadMedia ->
            ( model, Cast.loadMedia model.proposedMedia )

        ProposedMediaInput mediaUpdater s ->
            ( { model | proposedMedia = mediaUpdater model.proposedMedia s }, Cmd.none )

        ClickedPlayerControl action ->
            ( model, Cast.controlPlayer <| Cast.toJsPlayerAction action )

        ProgressClicked x ->
            ( model
            , case model.context |> Maybe.andThen .session |> Maybe.andThen .media |> Maybe.andThen .duration of
                Just d ->
                    Cast.controlPlayer <| Cast.toJsPlayerAction <| Cast.Seek <| x * d

                Nothing ->
                    Cmd.none
            )


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
    String.trim <| """
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
