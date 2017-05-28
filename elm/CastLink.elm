module CastLink exposing (..)

import Debug exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Json.Encode
import List exposing (..)
import Cast exposing (..)
import Bootstrap exposing (..)
import Navigation exposing (..)
import Bootstrap.Alert as Alert
import Bootstrap.Grid as Grid
import Bootstrap.Navbar as Navbar
import Bootstrap.Card as Card
import Bootstrap.Button as Button
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Json.Decode as JD exposing (..)
import Bootstrap.Form.Textarea as Textarea
import Maybe exposing (..)
import String
import Http
import Query exposing(..)


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
    | RunCmd (Cmd Msg)
    | Update (Model -> ( Model, Cmd Msg ))
    | MouseoverProgress MouseoverEvent
    | MediaLoaded (Maybe String)


type alias Model =
    { api : Cast.ApiAvailability
    , setOptions : Bool
    , context : Maybe Cast.Context
    , navbarState : Navbar.State
    , proposedMedia : Cast.Media
    , progressHover : Maybe MouseoverEvent
    , loadingMedia : Bool
    }


type alias MouseoverEvent =
    { offsetX : Int
    }


init : Location -> ( Model, Cmd Msg )
init location =
    let
        _ =
            Debug.log "init location" location

        ( navbarState, navbarCmd ) =
            Navbar.initialState NavbarMsg
    in
        ( { api = Cast.apiNotLoaded
          , setOptions = False
          , context = Nothing
          , navbarState = navbarState
          , proposedMedia = locationMediaSpec location
          , progressHover = Nothing
          , loadingMedia = False
          }
        , navbarCmd
        )


locationMediaSpec : Location -> Cast.Media
locationMediaSpec loc =
    String.dropLeft 1 loc.hash |> parseQuerySpec



parseQuerySpec : String -> Cast.Media
parseQuerySpec query =
    let
        _ =
            Debug.log "query" query

        specQuery =
            parseQuery query

        decode =
            Http.decodeUri >> Maybe.withDefault ""

        first_ key =
            specQuery |> first key |> Maybe.andThen identity |> Maybe.map decode |> Maybe.withDefault ""

        all_ key =
            specQuery |> Query.all key |> justList |> List.map decode
    in
        Debug.log "query spec" <|
            Cast.Media
                (first_ "content")
                (first_ "title")
                (first_ "subtitle")
                (first_ "poster")
                (all_ "subtitles")


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Cast.onApiAvailability ApiAvailability
        , Cast.context CastContext
        , Cast.mediaLoaded MediaLoaded
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
                                let
                                    alert button =
                                        Alert.warning <| (p [] [ text "Not connected to a device." ]) :: [ button ]
                                in
                                    case model.context of
                                        Just context ->
                                            case context.castState of
                                                NotConnected ->
                                                    alert <| Bootstrap.button Primary (Just "sign-in") [ onClick RequestSession ] "Connect"

                                                Connecting ->
                                                    alert <| Button.button [ Button.info ] <| iconAndText [ "pulse", "spinner" ] "Connecting"

                                                Connected ->
                                                    Alert.success <|
                                                        [ p [] [ text "Connected to ", strong [] [ text <| withDefault "" <| Maybe.map .deviceName context.session ], text "." ]
                                                        , Button.button
                                                            [ Button.warning
                                                            , Button.onClick <| RunCmd <| Cast.endCurrentSession False
                                                            ]
                                                          <|
                                                            iconAndText [ "sign-out" ] "Leave"
                                                        , text " "
                                                        , Button.button
                                                            [ Button.danger
                                                            , Button.onClick <| RunCmd <| Cast.endCurrentSession True
                                                            ]
                                                          <|
                                                            iconAndText [ "trash" ] "Stop"
                                                        ]

                                                NoDevicesAvailable ->
                                                    Alert.danger <|
                                                        [ strong [] [ text "No receiver devices available." ]
                                                        , text "There appears to be no Chromecasts on your network. They may be switched off, or on a different network."
                                                        ]

                                        Nothing ->
                                            Alert.warning <| List.singleton <| p [] [ text "Context state unknown" ]

                            False ->
                                Alert.warning [ p [] [ text "Cast API not loaded." ] ]
                    ]
    in
        Card.config []
            |> cardHeader "Session"
            |> Card.block [] contents
            |> Card.view


relatedButtons : List (Html Msg) -> List (Html Msg)
relatedButtons =
    List.intersperse (text "")


loadedMedia : Maybe Cast.Context -> Maybe Cast.Media
loadedMedia context =
    context
        |> Maybe.andThen .session
        |> Maybe.andThen .media
        |> Maybe.andThen
            (\sm ->
                case sm.playerState of
                    Idle ->
                        Nothing

                    _ ->
                        Just sm
            )
        |> Maybe.map .spec


mediaCard : Model -> Html Msg
mediaCard model =
    let
        session =
            model.context |> Maybe.andThen .session

        proposedMedia =
            model.proposedMedia

        haveSession =
            case session of
                Just _ ->
                    True

                Nothing ->
                    False

        loadButton =
            Button.button
                [ Button.primary
                , Button.onClick LoadMedia
                , Button.attrs [ disabled <| not haveSession || Just proposedMedia == loadedMedia model.context || model.loadingMedia ]
                ]
            <|
                if model.loadingMedia then
                    iconAndText [ "pulse", "spinner" ] "Loading"
                else
                    iconAndText [ "external-link" ] "Load into Player"

        setExample =
            Button.button
                [ Button.secondary
                , Button.onClick <| Update <| \model -> ( { model | proposedMedia = Cast.exampleMedia }, Cmd.none )
                , Button.attrs [ disabled <| proposedMedia == Cast.exampleMedia ]
                ]
            <|
                iconAndText [ "question" ] "Set example"

        copyLoaded =
            Button.button
                [ Button.secondary
                , Button.onClick <|
                    Update <|
                        \model ->
                            ( withDefault model <| Maybe.map (\media -> { model | proposedMedia = media }) <| loadedMedia model.context
                            , Cmd.none
                            )
                , Button.attrs [ disabled <| Just model.proposedMedia == loadedMedia model.context ]
                ]
            <|
                iconAndText [ "copy" ] "Copy loaded"

        specForm =
            Form.form [] <|
                let
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
    in
        Card.config []
            |> cardHeader "Media"
            |> Card.block []
                (List.map
                    Card.custom
                    [ p [] <|
                        List.intersperse
                            (text " ")
                            [ loadButton, setExample, copyLoaded ]
                    , specForm
                    ]
                )
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


iconAndText : List String -> String -> List (Html msg)
iconAndText classes text =
    [ i (class "fa" :: List.map (\c -> class <| "fa-" ++ c) classes) []
    , Html.text " "
    , Html.text text
    ]


playerButtons : Cast.SessionMedia -> Html Msg
playerButtons media =
    let
        playerState =
            media.playerState

        buffering =
            ( [ Button.info, Button.disabled True ], iconAndText [ "pulse", "spinner" ] "Buffering" )

        pause =
            ( [ Button.warning, Button.onClick <| ClickedPlayerControl Cast.PlayOrPause ], iconAndText [ "pause" ] "Pause" )

        play =
            ( [ Button.primary, Button.onClick <| ClickedPlayerControl Cast.PlayOrPause ], iconAndText [ "play" ] "Play" )

        stop =
            ( [ Button.danger, Button.onClick <| ClickedPlayerControl Cast.Stop ], iconAndText [ "stop" ] "Stop" )

        seek time icon text =
            ( [ Button.secondary, Button.onClick <| ClickedPlayerControl <| Cast.Seek time ], iconAndText [ icon ] text )

        makeSeekButtons =
            List.map <|
                \( delta, icon, text ) ->
                    seek (media.currentTime + delta) icon text

        seekBackButtons =
            makeSeekButtons
                [ ( -120, "fast-backward", "-2m" )
                , ( -30, "backward", "-30s" )
                ]

        seekForwardButtons =
            makeSeekButtons
                [ ( 30, "forward", "+30s" )
                , ( 120, "fast-forward", "+2m" )
                ]
    in
        p [] <|
            List.intersperse (text " ") <|
                List.map (uncurry Button.button) <|
                    seekBackButtons
                        ++ (case playerState of
                                Idle ->
                                    [ play ]

                                Playing ->
                                    [ pause, stop ]

                                Paused ->
                                    [ play, stop ]

                                Buffering ->
                                    [ buffering, stop ]
                           )
                        ++ seekForwardButtons


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
            div
                [ class "progress"
                , Html.Events.on "click" decodeProgressClick
                , let
                    defaultOptions =
                        Html.Events.defaultOptions
                  in
                    Html.Events.on "mousemove" <| JD.map MouseoverProgress decodeMouseoverEvent
                , style [ ( "position", "relative" ) ]
                ]
            <|
                justList
                    [ {- Maybe.map progressHoverPopup model.progressHover
                         ,
                      -}
                      Just <|
                        div
                            [ class "progress-bar"
                            , Html.Attributes.style
                                [ ( "width", (toString <| 100 * media.currentTime / duration) ++ "%" )
                                ]
                            ]
                            []
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
            (field "offsetX" JD.int)
            (at [ "currentTarget", "clientWidth" ] JD.int)


decodeMouseoverEvent : JD.Decoder MouseoverEvent
decodeMouseoverEvent =
    traceDecoder <|
        JD.map
            MouseoverEvent
            (field "offsetX" int)


playerCard : Model -> Html Msg
playerCard model =
    let
        noMedia =
            List.singleton <|
                Card.custom <|
                    Alert.warning
                        [ strong [] [ text "No media loaded." ]
                        , text " Configure media below, and load it into the player."
                        ]

        contents =
            case model.context |> Maybe.andThen .session |> Maybe.andThen .media of
                Just media ->
                    if media.playerState == Idle then
                        noMedia
                    else
                        List.map Card.custom <|
                            playerButtons media
                                :: let
                                    card node =
                                        Card.config [] |> Card.block [] [ Card.custom <| node ] |> Card.view
                                   in
                                    justList [ progress model ]

                Nothing ->
                    noMedia
    in
        Card.config []
            |> cardHeader "Player"
            |> Card.block [] contents
            |> Card.view


progressHoverPopup : MouseoverEvent -> Html Msg
progressHoverPopup e =
    p
        [ style
            [ ( "position", "absolute" )
            , ( "left", toString e.offsetX )
            ]
        ]
        [ text "herp" ]


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


mainUpdate : Msg -> Model -> ( Model, Cmd Msg )
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
                ( { model | proposedMedia = locationMediaSpec loc }, Cmd.none )

        Navigate url ->
            let
                _ =
                    log "Navigate" url
            in
                ( model, newUrl url )

        NavbarMsg state ->
            ( { model | navbarState = state }, Cmd.none )

        LoadMedia ->
            ( { model | loadingMedia = True }, Cast.loadMedia model.proposedMedia )

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

        RunCmd cmd ->
            ( model, cmd )

        Update run ->
            run model

        MouseoverProgress e ->
            let
                _ =
                    Debug.log "mouseover target" target
            in
                ( { model | progressHover = Just e }, Cmd.none )

        MediaLoaded _ ->
            ( { model | loadingMedia = False }, Cmd.none )


setOptions : Msg -> Model -> ( Model, Cmd msg )
setOptions _ model =
    if model.api.loaded && not model.setOptions then
        ( { model | setOptions = True }
        , Cast.setOptions
            { defaultOptions
                | resumeSavedSession = True
                , receiverApplicationId = Just "911A4C88"
                , autoJoinPolicy = Cast.originScoped
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
