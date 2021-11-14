module Bootstrap exposing (..)

import Bootstrap.Card.Block
import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Encode exposing (string)
import List exposing (..)


fluidContainer : List (Html msg) -> Html msg
fluidContainer contents =
    div [ class "container-fluid" ] contents


navbarToggler : Html msg
navbarToggler =
    Html.button
        [ class "navbar-toggler navbar-toggler-right"
        , type_ "button"
        , property "data-toggle" <| string "collapse"
        , property "data-target" <| string "#navbarNavDropdown"
        ]
        [ span [ class "navbar-toggler-icon" ] [] ]


type alias HtmlNodeMaker msg =
    List (Html.Attribute msg) -> List (Html msg) -> Html msg



--navbar : List (Html msg) -> List ( HtmlNodeMaker msg, List (Html.Attribute msg), List (Html msg) ) -> Html msg
--navbar brand items =
--    let lis =
--        List.map
--    nav
--        [ class "navbar navbar-inverse bg-inverse navbar-toggleable-sm" ]
--        [ navbarToggler
--        , a [ class "navbar-brand", href "/" ] brand
--        , div [ id "navbarNavDropdown", class "collapse navbar-collapse" ]
--            [ ul [ class "navbar-nav mr-auto" ] (List.map (\( nm, as_, es ) -> i as_ es) items) ]
--        ]


navItem : { href : String, title : String } -> Html msg
navItem { href, title } =
    li [ class "nav-item" ] [ a [ class "nav-link", Html.Attributes.href href ] [ text title ] ]


type alias NavItem =
    { href : String
    , title : String
    }


container : List (Attribute msg) -> List (Html msg) -> Html msg
container facts =
    div (class "container" :: facts)


glyphicon : String -> List (Attribute msg) -> Html msg
glyphicon icon facts =
    span ([ class "glyphicon", class <| "glyphicon-" ++ icon ] ++ facts) []


footer : Html msg
footer =
    div [ id "footer" ]
        [ container [ class "text-center" ]
            [ p [ class "text-muted small" ]
                [ a [ class "text-muted", href "mailto:anacrolix@gmail.com" ]
                    [ text "Questions, suggestions, support: "
                    , glyphicon "envelope" [ class "small" ]
                    , text " anacrolix@gmail.com"
                    ]
                ]
            ]
        ]


type Context
    = Warning
    | Danger
    | Primary


contextString : Context -> String
contextString context =
    case context of
        Warning ->
            "warning"

        Danger ->
            "danger"

        Primary ->
            "primary"


alert : Context -> List (Html msg) -> Html msg
alert context =
    div [ class "alert", class <| "alert-" ++ contextString context ]


simpleAlert : Context -> String -> String -> Html msg
simpleAlert context title msg =
    alert context
        [ strong [] [ text title ]
        , text <| " " ++ msg
        ]


type alias ButtonOptions =
    { context : Context
    , icon : FontAwesome
    }


type alias FontAwesome =
    { symbol : String
    , animation : Maybe ()
    }


fontAwesomeHtml : String -> Html msg
fontAwesomeHtml fa =
    span [ class <| "fa fa-" ++ fa ] []


buttonContext : Context -> Attribute msg
buttonContext ctx =
    class <| "btn btn-" ++ contextString ctx


button : Context -> Maybe String -> List (Attribute msg) -> String -> Html msg
button ctx maybeIcon attrs text =
    let
        iconNodes =
            case maybeIcon of
                Just icon ->
                    [ fontAwesomeHtml icon, Html.text " " ]

                Nothing ->
                    []
    in
    Html.button
        (List.concat [ [ buttonContext ctx ], attrs ])
        (iconNodes ++ [ Html.text text ])


inlineForm attrs controls =
    Html.form (class "form-inline" :: attrs) controls


textInput attrs placeHolder =
    Html.input (attrs ++ [ class "form-control", type_ "text", placeholder placeHolder ]) []



--<div id="api-not-available" class="alert alert-warning">
--  <strong>API not loaded.</strong> Session and player functions not yet available.
--</div>
--<div id="api-init-error" class="alert alert-danger initially-hidden" role="alert">
--  <strong id="api-init-error-info"></strong> You may need to use Chrome, or an Android device.
--</div>


customCard =
    Bootstrap.Card.Block.custom
