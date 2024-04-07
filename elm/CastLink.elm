module CastLink exposing (..)

import Array exposing (Array)
import Array.Extra as Array
import Basics018 exposing (..)
import Bootstrap exposing (..)
import Bootstrap.Alert as Alert
import Bootstrap.Button as Button
import Bootstrap.CDN
import Bootstrap.Card as Card
import Bootstrap.Card.Block
import Bootstrap.Form as Form
import Bootstrap.Form.Checkbox as Checkbox
import Bootstrap.Form.Input as Input
import Bootstrap.Form.Radio as Radio
import Bootstrap.Form.Textarea as Textarea exposing (textarea)
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Grid.Row as Grid
import Bootstrap.Navbar as Navbar
import Bootstrap.Utilities.Flex
import Browser exposing (..)
import Browser.Navigation
import Cast exposing (..)
import Dict exposing (Dict)
import ElmEscapeHtml
import Filesize
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http
import Json.Decode as JD
import Json.Encode
import List exposing (..)
import List.Extra as List
import Markdown
import Maybe exposing (..)
import Maybe.Extra
import Process
import Query exposing (..)
import Set exposing (Set)
import String
import Task
import Url
import Url.Parser
import Url.Parser.Query


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlChange = UrlChange
        , onUrlRequest = Navigate
        }


type Msg
    = ApiAvailability Cast.ApiAvailability
    | CastContext Cast.JsContext
    | RequestSession
    | UrlChange Url.Url
    | Navigate UrlRequest
    | NavbarMsg Navbar.State
    | LoadMedia
    | ChangeTitle String
    | ChangeSubtitle String
    | ChangeContentUrl String
    | ChangePosterUrl String
    | ClickedPlayerControl Cast.PlayerAction
    | ProgressClicked Float
    | OnTimeRangeInput Float
    | RunCmd (Cmd Msg)
    | SetProposedMedia ProposedMedia
    | MouseoverProgress MouseoverEvent
    | MediaLoaded (Maybe String)
    | SetPage Page
    | Noop
    | CheckedSubtitleTrack TrackId Bool
    | UnlockPlayerLoadingButton
    | TrashSubtitleTrack Int
    | ChangeSubtitlesUrl Int String
    | GotSubtitlesSize SubtitleUrlString (Result String Int)


type alias SubtitleUrlString =
    String


type SubtitlesSize
    = NotRequested
    | Requesting
    | Size Int


type alias ProposedSubtitles =
    { raw : Cast.Subtitles
    }


type alias ProposedMedia =
    { title : String
    , subtitle : String
    , url : String
    , poster : String
    , subtitles : List ProposedSubtitles
    }


type alias Model =
    { api : Cast.ApiAvailability
    , setOptions : Bool
    , context : Maybe Cast.Context
    , navbarState : Navbar.State
    , proposedMedia : ProposedMedia
    , progressHover : Maybe MouseoverEvent
    , loadingMedia : Bool
    , lockLoadingButton : Bool
    , page : Page
    , navKey : Browser.Navigation.Key
    , activeTrackIds : Set Int
    , errors : List JD.Error
    , subtitlesSizes : Dict String (Maybe (Result String Int))
    }


type alias MouseoverEvent =
    { offsetX : Float
    }


init : () -> Url.Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        ( navbarState, navbarCmd ) =
            Navbar.initialState NavbarMsg
    in
    ( { api = Cast.apiNotLoaded
      , setOptions = False
      , context = Nothing
      , navbarState = navbarState
      , proposedMedia = exampleMedia
      , progressHover = Nothing
      , loadingMedia = False
      , page = Caster
      , navKey = key
      , activeTrackIds = Set.empty
      , lockLoadingButton = False
      , errors = []
      , subtitlesSizes = Dict.empty
      }
        |> updateUrl url
    , navbarCmd
    )


proposedSubtitleUrls : Model -> List String
proposedSubtitleUrls model =
    model.proposedMedia.subtitles |> List.map .raw |> List.map .trackContentId


unrequestedSubtitleUrls : Model -> List String
unrequestedSubtitleUrls model =
    let
        hasRequest url =
            Dict.member url <| model.subtitlesSizes
    in
    proposedSubtitleUrls model |> List.filterNot hasRequest


mapResponseBody : (a -> b) -> Http.Response a -> Http.Response b
mapResponseBody f resp =
    case resp of
        Http.BadStatus_ metadata body ->
            Http.BadStatus_ metadata <| f body

        Http.GoodStatus_ metadata body ->
            Http.GoodStatus_ metadata <| f body

        Http.NetworkError_ ->
            Http.NetworkError_

        Http.BadUrl_ url ->
            Http.BadUrl_ url

        Http.Timeout_ ->
            Http.Timeout_


expectHeadResponse : (Result x a -> msg) -> (Http.Response () -> Result x a) -> Http.Expect msg
expectHeadResponse toMsg decoder =
    Http.expectBytesResponse toMsg <| mapResponseBody (always ()) >> decoder


getSubtitlesSize : String -> Cmd Msg
getSubtitlesSize url =
    let
        decoder response =
            case response of
                Http.GoodStatus_ metadata () ->
                    metadata.headers
                        --|> Debug.log "subtitles size response headers"
                        |> Dict.get "content-length"
                        |> Result.fromMaybe "missing Content-Length"
                        |> Result.andThen (String.toInt >> Result.fromMaybe "bad Content-Length")

                _ ->
                    Err "response error"

        toMsg =
            GotSubtitlesSize url

        expect =
            expectHeadResponse toMsg decoder
    in
    Http.get
        { url = url
        , expect = expect
        }


requestSubtitlesSizes : ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
requestSubtitlesSizes ( model, cmd ) =
    let
        newRequests =
            unrequestedSubtitleUrls model |> List.map (\url -> ( url, getSubtitlesSize url ))

        addRequest ( url, reqCmd ) ( model_, cmd_ ) =
            ( { model_ | subtitlesSizes = Dict.insert url Nothing model_.subtitlesSizes }
            , Cmd.batch [ reqCmd, cmd_ ]
            )
    in
    List.foldr addRequest ( model, cmd ) newRequests


updateUrl : Url.Url -> Model -> Model
updateUrl url model =
    let
        ( errors, proposedMedia ) =
            locationMediaSpec url
    in
    { model
        | proposedMedia =
            case proposedMedia of
                Just pm ->
                    pm

                Nothing ->
                    if List.isEmpty errors then
                        exampleMedia

                    else
                        emptyProposedMedia
        , page = internalPageForUrl url
        , errors = errors
    }


locationMediaSpec : Url.Url -> ( List JD.Error, Maybe ProposedMedia )
locationMediaSpec loc =
    loc.fragment
        |> Maybe.map (parseQuerySpec >> Tuple.mapSecond Just)
        |> Maybe.withDefault ( [], Nothing )


internalPageForUrl : Url.Url -> Page
internalPageForUrl url =
    case url.fragment |> Maybe.map parseQuery |> Maybe.andThen (first "page") |> Maybe.Extra.join |> Maybe.withDefault "" of
        "dev" ->
            Dev

        "about" ->
            About

        _ ->
            Caster


type Page
    = Caster
    | About
    | Dev


aboutPath =
    "#page=about"


devPath =
    "#page=dev"


rootCasterPath =
    ""


internalPageLink page =
    case page of
        Caster ->
            rootCasterPath

        About ->
            aboutPath

        Dev ->
            devPath


type alias SubtitlesWithoutTrackId =
    { language : String
    , trackContentId : String
    , name : Maybe String
    }


parseQuerySpec : String -> ( List JD.Error, ProposedMedia )
parseQuerySpec query =
    let
        specQuery =
            parseQuery query

        decode =
            Url.percentDecode >> Maybe.withDefault ""

        first_ key =
            specQuery |> first key |> Maybe.andThen identity |> Maybe.map decode |> Maybe.withDefault ""

        all_ key =
            specQuery |> Query.all key |> justList |> List.map decode

        trackDecoder =
            JD.map3
                (\src lang name ->
                    { language = withDefault "" lang
                    , trackContentId = src
                    , name = name
                    }
                )
                (JD.field "src" JD.string)
                (JD.maybe <| JD.field "lang" JD.string)
                (JD.maybe <| JD.field "name" JD.string)

        oldStyleSubtitles =
            all_ "subtitles"
                |> List.map
                    (\id ->
                        { trackContentId = id
                        , language = defaultSubtitlesLanguage
                        , name = Nothing
                        }
                    )

        --newStyleSubtitles : ( List JD.Error, List Cast.Subtitles )
        ( errors, newStyleSubtitles ) =
            all_ "track"
                |> List.map (JD.decodeString trackDecoder)
                |> List.foldr
                    (\result ( errors_, subs ) ->
                        case result of
                            Ok value ->
                                ( errors_, value :: subs )

                            Err error ->
                                ( error :: errors_, subs )
                    )
                    ( [], [] )

        addTrackIds =
            List.indexedMap <|
                \index track ->
                    { trackId = index + 1
                    , name = track.name
                    , trackContentId = track.trackContentId
                    , language = track.language
                    }

        -- Chromecast seems to barf on loading more than about 50 tracks at once. Old versions of
        -- webtorrent will serve up all SRTs in an entire torrent, which has been 342 in once
        -- instance. Loading this into Chromecast gives "invalid_parameter".
        limitTracks proposedMedia =
            { proposedMedia | subtitles = List.take 50 proposedMedia.subtitles }

        media =
            Cast.Media
                (first_ "content")
                (first_ "title")
                (first_ "subtitle")
                (first_ "poster")
                (addTrackIds <| oldStyleSubtitles ++ newStyleSubtitles)
    in
    ( errors
    , media
        |> proposedMediaFromCastMedia
        |> limitTracks
    )


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


view : Model -> Document Msg
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
            maker [ href <| internalPageLink page ] [ Html.text text ]

        navbar =
            Navbar.config NavbarMsg
                -- Span is an option for brand in Bootstrap 4, but it doesn't seem to be exposed?
                --|> Navbar.brand [ href <| internalPageLink Caster ] [ text "chromecast.link" ]
                |> Navbar.dark
                |> Navbar.items
                    [ navItem Caster
                        "Chromecast.Link"
                    , navItem About "About"
                    , navItem Dev "API"
                    , Navbar.itemLink [ href "https://github.com/sponsors/anacrolix" ] [ Html.text "Sponsor" ]
                    ]
                |> Navbar.view model.navbarState
    in
    { title = ""
    , body =
        [ Bootstrap.CDN.fontAwesome
        , Grid.container [] <|
            [ navbar
            ]
                ++ viewContents model
                ++ viewFooter model
        ]
    }


cardHeader : String -> Card.Config Msg -> Card.Config Msg
cardHeader s =
    Card.headerH5 [] [ text s ]


markdownContent : String -> List (Html Msg)
markdownContent s =
    let
        defaultOptions =
            Markdown.defaultOptions

        options =
            { defaultOptions | sanitize = False }
    in
    [ Grid.containerFluid []
        [ Grid.row []
            [ Grid.col []
                [ Markdown.toHtmlWith options [] s
                ]
            ]
        ]
    ]


viewContents : Model -> List (Html Msg)
viewContents model =
    case model.page of
        Caster ->
            List.map (\f -> f model) [ sessionCard, playerCard, mediaCard ]

        About ->
            markdownContent """
## About

This page makes use of the Chromecast sender API to control Chromecasts on your local network. It provides a web interface rather than requiring you to install a native app on your devices. Links you load are accessed directly by the Chromecast.

I made this page because I was annoyed at how invasive Chromecast support can be. It currently requires integrating Chromecast libraries into every application that wants to interoperate. Screen mirroring is a partial solution that doesn't require individual app support, by including the integration at the device-level, but comes with security and privacy issues, and is very inefficient. Data is first streamed to your device, and then streamed on to the Chromecast, requiring double the bandwidth or more than just streaming directly to the Chromecast.

This site only serves code to control your Chromecasts. There is no communication of what you are watching required to any server, other than the one your Chromecast accesses to retrieve the content. Links directly to content, from other websites, encode the content in the fragment part of the URL, which is not sent in requests to this site.
"""

        Dev ->
            markdownContent """
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
            List.map Bootstrap.Card.Block.custom <|
                List.concat
                    [ maybeToList <| contextAlerts model
                    , List.singleton <|
                        case model.api.loaded of
                            True ->
                                let
                                    alert button =
                                        Alert.simpleWarning [] <| p [] [ text "Not connected to a device." ] :: [ button ]
                                in
                                case model.context of
                                    Just context ->
                                        case context.castState of
                                            NotConnected ->
                                                alert <| Bootstrap.button Primary (Just "sign-in") [ onClick RequestSession ] "Connect"

                                            Connecting ->
                                                alert <| Button.button [ Button.info ] <| iconAndText [ "pulse", "spinner" ] "Connecting"

                                            Connected ->
                                                Alert.simpleSuccess [] <|
                                                    [ p []
                                                        [ text "Connected to "
                                                        , strong [] [ text <| withDefault "" <| Maybe.map (.deviceName >> ElmEscapeHtml.unescape) context.session ]
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
                                                Alert.simpleDanger [] <|
                                                    [ strong [] [ text "No receiver devices available." ]
                                                    , text " There appears to be no Chromecasts on your network. They may be switched off, or on a different network."
                                                    ]

                                    Nothing ->
                                        Alert.simpleWarning [] <| List.singleton <| p [] [ text "Context state unknown" ]

                            False ->
                                Alert.simpleWarning [] [ p [] [ text "Cast API not loaded." ] ]
                    ]
    in
    Card.config []
        |> cardHeader "Session"
        |> Card.block [] contents
        |> Card.view


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

        loadingButton =
            if model.loadingMedia then
                Just <|
                    Button.button
                        [ Button.info
                        , Button.attrs [ disabled <| not haveSession || proposedMediaMatchesLoaded model || model.lockLoadingButton ]
                        ]
                    <|
                        iconAndText
                            [ "pulse", "spinner" ]
                            "Loading"

            else
                Nothing

        loadButton =
            if model.loadingMedia || model.lockLoadingButton then
                Nothing

            else
                Just <|
                    Button.button
                        [ if model.loadingMedia then
                            Button.warning

                          else
                            Button.primary
                        , Button.onClick LoadMedia
                        , Button.attrs [ disabled <| not haveSession || proposedMediaMatchesLoaded model || model.lockLoadingButton || model.proposedMedia.url == "" ]
                        ]
                    <|
                        iconAndText [ "external-link" ] "Load into Player"

        setExample =
            Button.button
                [ Button.secondary
                , Button.onClick <| SetProposedMedia exampleMedia
                , Button.attrs [ disabled <| proposedMedia == exampleMedia ]
                ]
            <|
                iconAndText [ "question" ] "Set example"

        copyLoaded =
            Button.button
                [ Button.secondary
                , Button.onClick <|
                    Maybe.withDefault Noop <|
                        Maybe.map (SetProposedMedia << proposedMediaFromCastMedia) <|
                            loadedMedia model.context
                , Button.attrs [ disabled <| proposedMediaMatchesLoaded model ]
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
                        [ Input.onInput ChangeTitle
                        , Input.value pm.title
                        ]
                    ]
                , Form.group []
                    [ Form.label [] [ text "Subtitle" ]
                    , Input.text
                        [ Input.onInput ChangeSubtitle
                        , Input.value pm.subtitle
                        ]
                    ]
                , Form.group []
                    [ Form.label [] [ text "Content URL" ]
                    , Textarea.textarea <|
                        List.concat
                            [ [ Textarea.onInput ChangeContentUrl
                              , Textarea.value pm.url
                              ]
                            , urlTextareaAttrsOptions
                            ]
                    ]
                , Form.group []
                    ([ div
                        -- This ensures there's a similar space between the header for the subtitles
                        -- label, and the individual rows of subtitles.
                        [ class "form-group" ]
                        [ Form.label [] [ text "Subtitles URL" ] ]
                     ]
                        ++ playerSubtitlesHtml model
                    )
                , Form.group []
                    [ Form.label [] [ text "Poster URL" ]
                    , Textarea.textarea
                        ([ Textarea.onInput ChangePosterUrl
                         , Textarea.value pm.poster
                         ]
                            ++ urlTextareaAttrsOptions
                        )
                    ]
                ]
    in
    Card.config []
        |> cardHeader "Media"
        |> Card.block []
            (List.map
                Bootstrap.Card.Block.custom
                [ p [] <|
                    List.intersperse
                        (text " ")
                        (Maybe.Extra.values [ loadingButton, loadButton, Just setExample, Just copyLoaded ])
                , specForm
                ]
            )
        |> Card.view


formCheckboxWithoutLabel ariaLabel_ checked indeterminate id attrs checkMsg =
    Html.div
        [ class "form-group"
        , class "custom-control"
        , class "custom-switch"
        , onClick <| checkMsg <| not checked
        ]
        [ Html.input
            ([ class "custom-control-input"
             , type_ "checkbox"
             , Html.Attributes.checked checked
             , Html.Attributes.property "indeterminate" <| Json.Encode.bool indeterminate
             , attribute "ariaLabel" ariaLabel_
             , Html.Attributes.id id
             ]
                ++ attrs
            )
            []
        , label [ class "custom-control-label" ] [ text "Active" ]
        ]


playerSubtitlesHtml model =
    let
        indeterminate =
            Maybe.Extra.isJust
                (loadedMedia model.context)
                && not (proposedMediaMatchesLoaded model)

        checkbox checked trackId ariaLabel =
            formCheckboxWithoutLabel
                ariaLabel
                checked
                indeterminate
                (String.fromInt trackId)
                [ Html.Events.onCheck <| CheckedSubtitleTrack trackId
                , Html.Attributes.style "margin-top" "0"
                ]
                (CheckedSubtitleTrack trackId)

        listGroup items =
            ul
                [ class "list-group"
                , class "list-group-flush"
                ]
            <|
                List.map (li [ class "list-group-item" ]) items

        sizeText url =
            Dict.get url model.subtitlesSizes
                |> (\value ->
                        case value of
                            Nothing ->
                                "not requested"

                            Just Nothing ->
                                "requested"

                            Just (Just (Ok size)) ->
                                Filesize.format size

                            Just (Just (Err err)) ->
                                err
                   )
    in
    List.singleton <|
        listGroup <|
            List.indexedMap
                (\index s ->
                    let
                        trackId =
                            s.raw.trackId

                        name =
                            Maybe.withDefault "" s.raw.name

                        col =
                            div
                    in
                    [ div [ class "form-row" ]
                        [ col
                            [ class "col-auto"
                            , Bootstrap.Utilities.Flex.alignSelfCenter
                            ]
                            [ checkbox (Set.member trackId model.activeTrackIds) trackId name ]
                        , col
                            [ class "col-auto", class "form-group", style "display" "flex" ]
                            [ small
                                [ class "form-text"
                                , class "text-muted"
                                , style "align-self" "center"
                                , style "margin-top" "0"
                                ]
                                [ text <| sizeText s.raw.trackContentId ]
                            ]
                        , col [ class "col-auto", class "form-group" ]
                            [ Button.button
                                [ Button.secondary
                                , Button.light
                                , Button.onClick <| TrashSubtitleTrack index
                                ]
                              <|
                                iconAndTextExtraAttrs [ "trash" ] [] "Remove"
                            ]
                        , col [ class "col-md-9", class "form-group" ]
                            [ Input.text
                                [ Input.value <| name
                                , Input.placeholder "Name"
                                ]
                            ]
                        , col [ class "col-md-3 d-none d-md-block", class "form-group" ]
                            [ Input.text
                                [ Input.value s.raw.language
                                , Input.placeholder "Language"
                                , Input.attrs [ Html.Attributes.size 10 ]
                                ]
                            ]
                        , col [ class "col-12", class "form-group" ]
                            [ Textarea.textarea <|
                                List.concat
                                    [ [ Textarea.value s.raw.trackContentId
                                      , Textarea.onInput <| ChangeSubtitlesUrl index
                                      ]
                                    , urlTextareaAttrsOptions
                                    ]
                            ]
                        ]
                    ]
                )
                model.proposedMedia.subtitles


urlTextareaAttrsOptions =
    [ Textarea.attrs
        [ Html.Attributes.placeholder "URL"
        , Html.Attributes.class "text-monospace"
        , Html.Attributes.style "word-break" "break-all"

        -- Can't use the small class since it gets clobbered by
        -- form-control class.
        , Html.Attributes.style "font-size" "80%"
        ]

    --, Textarea.rows 2
    ]


activeTrackIdsFromContext : Cast.Context -> Maybe (List Int)
activeTrackIdsFromContext =
    .session
        >> Maybe.andThen .media
        >> Maybe.map .activeTrackIds


trackIdIsActive : Int -> Model -> Bool
trackIdIsActive id =
    .context
        >> Maybe.andThen activeTrackIdsFromContext
        >> Maybe.withDefault []
        >> member id


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
    iconAndTextExtraAttrs classes [] text


iconAndTextExtraAttrs : List String -> List (Html.Attribute msg) -> String -> List (Html msg)
iconAndTextExtraAttrs classes attrs text =
    [ i
        (class "fa"
            :: List.map (\c -> class <| "fa-" ++ c) classes
            ++ attrs
        )
        []
    ]
        ++ (if text == "" then
                []

            else
                [ Html.text " "
                , Html.text text
                ]
           )


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

        maybeMedia : Maybe Cast.SessionMedia
        maybeMedia =
            model.context |> andThen .session |> andThen .media

        maybeDuration : Maybe Float
        maybeDuration =
            andThen .duration maybeMedia

        elemProgressBar : Cast.SessionMedia -> Float -> Html Msg
        elemProgressBar media duration =
            -- TODO: Use a Bootstrap range input, with ticks for regular intervals of the media.
            div
                [ class "progress"
                , Html.Events.on "click" decodeProgressClick

                -- , Html.Events.on "touchdown" decodeProgressClick
                , Html.Events.on "pointermove" <| JD.map MouseoverProgress decodeMouseoverEvent
                , style "position" "relative"
                ]
            <|
                justList
                    [ {- Maybe.map progressHoverPopup model.progressHover
                         ,
                      -}
                      Just <|
                        div
                            [ class "progress-bar"
                            , style
                                "width"
                                ((String.fromFloat <| 100 * media.currentTime / duration) ++ "%")
                            ]
                            []
                    ]

        elemRangeInput media duration =
            input
                [ type_ "range"
                , class "form-control-range"
                , Html.Attributes.max <| String.fromFloat duration
                , step "1"
                , Html.Events.onInput <|
                    String.toFloat
                        >> Maybe.map OnTimeRangeInput
                        >> Maybe.withDefault Noop
                , value <| String.fromFloat media.currentTime
                ]
                []

        elem : Cast.SessionMedia -> Float -> Html Msg
        elem =
            elemRangeInput

        card media duration =
            Card.config []
                |> Card.block []
                    (List.map Bootstrap.Card.Block.custom
                        [ div []
                            [ span [] [ text <| secsToHhmmss << floor <| media.currentTime ]
                            , span [ style "float" "right" ] [ text <| secsToHhmmss << floor <| duration ]
                            ]
                        , elem media duration
                        ]
                    )
                |> Card.view
    in
    Maybe.map2 card maybeMedia maybeDuration


secsToHhmmss : Int -> String
secsToHhmmss s =
    let
        extract ( q, mm ) =
            case mm of
                Just m ->
                    modBy m <| s // q

                Nothing ->
                    s // q

        format =
            String.padLeft 2 '0' << String.fromInt << extract
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
                        JD.succeed <| decoded

                    Err err ->
                        JD.fail <| JD.errorToString err
            )


decodeProgressClick : JD.Decoder Msg
decodeProgressClick =
    let
        f x w =
            ProgressClicked <| x / toFloat w
    in
    JD.map2 f
        (JD.field "offsetX" JD.float)
        (JD.at [ "currentTarget", "clientWidth" ] JD.int)


decodeMouseoverEvent : JD.Decoder MouseoverEvent
decodeMouseoverEvent =
    traceDecoder <|
        JD.map
            MouseoverEvent
            (JD.field "offsetX" JD.float)


playerCard : Model -> Html Msg
playerCard model =
    let
        noMedia =
            List.singleton <|
                customCard <|
                    Alert.simpleWarning []
                        [ strong [] [ text "No media loaded." ]
                        , text " Configure media below, and load it into the player."
                        ]

        contents =
            case model.context |> Maybe.andThen .session |> Maybe.andThen .media of
                Just media ->
                    if media.playerState == Idle then
                        noMedia

                    else
                        List.map customCard <|
                            playerButtons media
                                :: (let
                                        card node =
                                            Card.config [] |> Card.block [] [ customCard <| node ] |> Card.view
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
            "position"
            "absolute"
        , style "left" <| String.fromFloat e.offsetX
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
    chainUpdates msg model [ mainUpdate, setOptions ]


chainUpdates : msg -> model -> List (UpdateFn msg model) -> ( model, Cmd msg )
chainUpdates msg model updates =
    let
        merge =
            \u ( lastModel, lastCmd ) ->
                let
                    ( nextModel, nextCmd ) =
                        u msg lastModel
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
    let
        updateProposedMedia : (ProposedMedia -> ProposedMedia) -> ( Model, Cmd Msg )
        updateProposedMedia mediaUpdater =
            ( { model | proposedMedia = mediaUpdater model.proposedMedia }, Cmd.none )

        handleMsg =
            case msg of
                ApiAvailability api ->
                    ( { model | api = api }, Cmd.none )

                CastContext jsContext ->
                    let
                        elmContext =
                            Cast.fromJsContext jsContext

                        newModel =
                            { model
                                | context = Just elmContext
                                , loadingMedia =
                                    model.loadingMedia
                                        -- Unset when a media session appears.
                                        && (elmContext.session |> Maybe.andThen .media |> Maybe.Extra.isNothing)
                            }
                    in
                    ( { newModel
                        | activeTrackIds =
                            -- If the proposed media matches what is loaded, clobber the local with what's
                            -- active on the receiver.
                            if proposedMediaMatchesLoaded newModel then
                                activeTrackIdsFromContext elmContext
                                    |> Maybe.withDefault []
                                    |> Set.fromList

                            else
                                newModel.activeTrackIds

                        --, activeTrackIds = activeTrackIdsFromContext context |> Maybe.withDefault [] |> Set.fromList
                      }
                    , Cmd.none
                    )

                RequestSession ->
                    ( model, Cast.requestSession () )

                UrlChange loc ->
                    ( updateUrl loc model, Cmd.none )

                Navigate request ->
                    case request of
                        Internal url ->
                            ( model, Browser.Navigation.replaceUrl model.navKey <| Url.toString url )

                        External s ->
                            ( model, Browser.Navigation.load s )

                NavbarMsg state ->
                    ( { model | navbarState = state }, Cmd.none )

                LoadMedia ->
                    ( { model | loadingMedia = True }
                    , Cmd.batch
                        [ Cast.loadMedia <|
                            { media = castMediaFromProposedMedia model.proposedMedia
                            , activeTrackIds = Set.toList model.activeTrackIds
                            }
                        , Process.sleep 3000 |> Task.perform (always UnlockPlayerLoadingButton)
                        ]
                    )

                ChangeTitle s ->
                    updateProposedMedia <| \pm -> { pm | title = s }

                ChangeSubtitle s ->
                    updateProposedMedia <| \pm -> { pm | subtitle = s }

                ChangeContentUrl s ->
                    updateProposedMedia <| \pm -> { pm | url = s }

                ChangePosterUrl s ->
                    updateProposedMedia <| \pm -> { pm | poster = s }

                SetProposedMedia pm ->
                    updateProposedMedia <| always pm

                Noop ->
                    ( model, Cmd.none )

                ClickedPlayerControl action ->
                    ( model, Cast.controlPlayer <| Cast.toJsPlayerAction action )

                ProgressClicked x ->
                    ( model
                    , case
                        model.context
                            |> Maybe.andThen .session
                            |> Maybe.andThen .media
                            |> Maybe.andThen .duration
                      of
                        Just d ->
                            Cast.controlPlayer <| Cast.toJsPlayerAction <| Cast.Seek <| x * d

                        Nothing ->
                            Cmd.none
                    )

                -- We could do the seek only on change, and pause and update the time on input.
                OnTimeRangeInput value ->
                    ( model, Cast.controlPlayer <| Cast.toJsPlayerAction <| Cast.Seek value )

                RunCmd cmd ->
                    ( model, cmd )

                MouseoverProgress e ->
                    ( { model | progressHover = Just e }, Cmd.none )

                MediaLoaded _ ->
                    ( { model | loadingMedia = False }, Cmd.none )

                SetPage page ->
                    ( { model | page = page }, Cmd.none )

                CheckedSubtitleTrack id checked ->
                    let
                        f =
                            if checked then
                                Set.insert

                            else
                                Set.remove

                        newActiveTrackIds =
                            f id model.activeTrackIds
                    in
                    ( { model
                        | activeTrackIds = newActiveTrackIds
                      }
                    , Cast.editTracks <| Set.toList newActiveTrackIds
                    )

                UnlockPlayerLoadingButton ->
                    ( { model | lockLoadingButton = False }, Cmd.none )

                TrashSubtitleTrack index ->
                    let
                        proposedMedia =
                            model.proposedMedia
                    in
                    ( { model
                        | proposedMedia =
                            { proposedMedia
                                | subtitles =
                                    List.removeAt index proposedMedia.subtitles
                            }
                      }
                    , Cmd.none
                    )

                ChangeSubtitlesUrl index url ->
                    updateProposedMedia (updateSubtitlesIndex index (updateRawSubtitles <| \s -> { s | trackContentId = url }))

                GotSubtitlesSize url result ->
                    ( { model
                        | subtitlesSizes = Dict.insert url (Just result) model.subtitlesSizes
                      }
                    , Cmd.none
                    )
    in
    handleMsg |> requestSubtitlesSizes



--updateProposedMedia : (ProposedMedia -> ProposedMedia) -> Model -> Model
--updateProposedMedia f model = { model | proposedMedia = f model.proposedMedia }


updateRawSubtitles : (Subtitles -> Subtitles) -> ProposedSubtitles -> ProposedSubtitles
updateRawSubtitles f proposedSubtitles =
    { proposedSubtitles | raw = f proposedSubtitles.raw }


updateSubtitlesIndex : Int -> (ProposedSubtitles -> ProposedSubtitles) -> ProposedMedia -> ProposedMedia
updateSubtitlesIndex index f proposedMedia =
    { proposedMedia
        | subtitles =
            case List.getAt index proposedMedia.subtitles of
                Just track ->
                    List.setAt index (f track) proposedMedia.subtitles

                Nothing ->
                    proposedMedia.subtitles
    }


setOptions : Msg -> Model -> ( Model, Cmd msg )
setOptions _ model =
    if model.api.loaded && not model.setOptions then
        ( { model | setOptions = True }
        , Cast.setOptions
            { defaultOptions
                | resumeSavedSession = True
                , receiverApplicationId = Just "911A4C88"
                , autoJoinPolicy = Cast.pageScoped
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


exampleMedia : ProposedMedia
exampleMedia =
    { url = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    , subtitle = "1280x720 h264"
    , title = "Big Buck Bunny"
    , poster = "https://upload.wikimedia.org/wikipedia/commons/c/c5/Big_buck_bunny_poster_big.jpg"
    , subtitles =
        [ { raw = { trackId = 1, name = Just "acid", trackContentId = "/acid.vtt", language = "acid" }
          }
        , { raw = { trackId = 2, name = Just "de", trackContentId = "https://webtorrent.io/torrents/Sintel/Sintel.de.srt", language = "de" }
          }
        ]
    }


emptyProposedMedia : ProposedMedia
emptyProposedMedia =
    { url = ""
    , subtitle = ""
    , title = "Title goes here"
    , poster = ""
    , subtitles = []
    }


proposedMediaFromCastMedia : Cast.Media -> ProposedMedia
proposedMediaFromCastMedia cast =
    { title = cast.title
    , subtitle = cast.subtitle
    , url = cast.url
    , poster = cast.poster
    , subtitles = List.map (\s -> { raw = s }) cast.subtitles
    }


castMediaFromProposedMedia : ProposedMedia -> Cast.Media
castMediaFromProposedMedia proposed =
    { url = proposed.url
    , title = proposed.title
    , subtitle = proposed.subtitle
    , poster = proposed.poster
    , subtitles = List.map .raw proposed.subtitles
    }


proposedMediaMatchesLoaded : Model -> Bool
proposedMediaMatchesLoaded model =
    Just (castMediaFromProposedMedia model.proposedMedia) == loadedMedia model.context
