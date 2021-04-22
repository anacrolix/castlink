module CastLink exposing (..)

import Bootstrap exposing (..)
import Bootstrap.Alert as Alert
import Bootstrap.Button as Button
import Bootstrap.Card as Card
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Grid as Grid
import Bootstrap.Navbar as Navbar
import Cast exposing (..)
import Debug exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http
import Json.Decode as JD exposing (..)
import Json.Encode
import List exposing (..)
import Markdown
import Maybe exposing (..)
import Navigation exposing (..)
import Query exposing (..)
import String
import Unicode


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
    | SetPage Page


type alias Model =
    { api : Cast.ApiAvailability
    , setOptions : Bool
    , context : Maybe Cast.Context
    , navbarState : Navbar.State
    , proposedMedia : Cast.Media
    , progressHover : Maybe MouseoverEvent
    , loadingMedia : Bool
    , page : Page
    }


type alias MouseoverEvent =
    { offsetX : Float
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
      , page = Caster
      }
    , navbarCmd
    )


locationMediaSpec : Location -> Cast.Media
locationMediaSpec loc =
    String.dropLeft 1 loc.hash |> parseQuerySpec


type Page
    = Caster
    | About
    | Dev


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


voidHref : Html.Attribute msg
voidHref =
    href "javascript:void(0)"


view : Model -> Html Msg
view model =
    let
        navItem page text =
            let
                maker =
                    if model.page == page then
                        Navbar.itemLinkActive

                    else
                        Navbar.itemLink
            in
            maker [ voidHref, onClick <| SetPage page ] [ Html.text text ]
    in
    Grid.container [] <|
        [ Navbar.config NavbarMsg
            |> Navbar.brand [ voidHref, onClick <| SetPage Caster ] [ text "chromecast.link" ]
            |> Navbar.inverse
            |> Navbar.items
                --[ navItem Caster "Link caster"
                [ navItem About "About"
                , navItem Dev "Use on your website"
                , Navbar.itemLink [ href "https://www.patreon.com/bePatron?u=6126463" ] [ Html.text "Become a Patron!" ]
                ]
            --|> Navbar.customItems [ Navbar.customItem <| div [ innerHtml """<a href="https://www.patreon.com/bePatron?u=6126463" data-patreon-widget-type="become-patron-button">Become a Patron!</a><script async src="https://c6.patreon.com/becomePatronButton.bundle.js"></script>""" ] [] ]
            |> Navbar.view model.navbarState
        ]
            ++ viewContents model
            ++ viewFooter model


cardHeader : String -> Card.Config Msg -> Card.Config Msg
cardHeader s =
    Card.headerH5 [] [ text s ]


viewContents : Model -> List (Html Msg)
viewContents model =
    case model.page of
        Caster ->
            List.map (\f -> f model) [ sessionCard, playerCard, mediaCard ]

        About ->
            List.singleton <| Markdown.toHtml [] """
## About

This page makes use of the Chromecast sender API to control Chromecasts on your local network. It provides a web interface rather than requiring you to install a native app on your devices. Links you load are accessed directly by the Chromecast.

I made this page because I was annoyed at how invasive Chromecast support can be. It currently requires integrating Chromecast libraries into every application that wants to interoperate. Screen mirroring is a partial solution that doesn't require individual app support, by including the integration at the device-level, but comes with security and privacy issues, and is very inefficient. Data is first streamed to your device, and then streamed on to the Chromecast, requiring double the bandwidth or more than just streaming directly to the Chromecast.

This site only serves code to control your Chromecasts. There is no communication of what you are watching required to any server, other than the one your Chromecast accesses to retrieve the content. Links directly to content, from other websites, encode the content in the fragment part of the URL, which is not sent in requests to this site.
"""

        Dev ->
            List.singleton <| Markdown.toHtml [] """
## Developers

You can link to this site and automatically fill the proposed media URLs by including a fragment in the link. A fragment is the part after a <code>#</code> in URL. For example <code>https://chromecast.link#title=Title&subtitle=Subtitle&poster=http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg&content=http://download.blender.org/peach/bigbuckbunny_movies/BigBuckBunny_320x180.mp4</code>

The valid fragment parameters are:
<dl>
  <dt>content</dt>
  <dd>URL of content to send to the Chromecast. Must be a supported format like MP4, WebM, Ogg etc.</dd>
  <dt>title</dt>
  <dd>This is the title to show on the loading and pause screens.</dd>
  <dt>poster</dt>
  <dd>A thumbnail image to show that represents the content.</dd>
  <dt>subtitle</dt>
  <dd>Smaller text that appears below the title.</dd>
  <dt>subtitles</dt>
  <dd>URL for subtitles for the content. I think it must be WebVTT format.</dd>
</dl>
"""


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
                                        Alert.warning <| p [] [ text "Not connected to a device." ] :: [ button ]
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
                                                    [ p []
                                                        [ text "Connected to "
                                                        , strong [] [ text <| withDefault "" <| Maybe.map (.deviceName >> Unicode.unEsc) context.session ]
                                                        , text "."
                                                        ]
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
                                                    , text " There appears to be no Chromecasts on your network. They may be switched off, or on a different network."
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
            ( [ Button.info, Button.onClick <| ClickedPlayerControl Cast.PlayOrPause ], iconAndText [ "pulse", "spinner" ] "Buffering" )

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

                -- , Html.Events.on "touchdown" decodeProgressClick
                , Html.Events.on "pointermove" <| JD.map MouseoverProgress decodeMouseoverEvent
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
            ProgressClicked <| x / toFloat w
    in
    JD.map2 f
        (field "offsetX" JD.float)
        (at [ "currentTarget", "clientWidth" ] JD.int)


decodeMouseoverEvent : JD.Decoder MouseoverEvent
decodeMouseoverEvent =
    traceDecoder <|
        JD.map
            MouseoverEvent
            (field "offsetX" float)


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
                                :: (let
                                        card node =
                                            Card.config [] |> Card.block [] [ Card.custom <| node ] |> Card.view
                                    in
                                    justList [ progress model ]
                                   )

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
            , href <| "mailto:" ++ email
            ]
            [ text "Questions, suggestions, support: "
            , span [ class "small glyphicon glyphicon-envelope" ] []
            , text email
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
            ( { model | progressHover = Just e }, Cmd.none )

        MediaLoaded _ ->
            ( { model | loadingMedia = False }, Cmd.none )

        SetPage page ->
            ( { model | page = page }, Cmd.none )


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
    div [ innerHtml adBlob ] []


innerHtml : String -> Html.Attribute msg
innerHtml =
    property "innerHTML" << Json.Encode.string


email =
    "anacrolix+chromecast.link@gmail.com"
