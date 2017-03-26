module Bootstrap exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Json.Encode exposing (string)


fluidContainer : List (Html msg) -> Html msg
fluidContainer contents =
    div [ class "container-fluid" ] contents


navbarToggler : Html msg
navbarToggler =
    button
        [ class "navbar-toggler navbar-toggler-right"
        , type_ "button"
        , property "data-toggle" <| string "collapse"
        , property "data-target" <| string "#navbarNavDropdown"
        ]
        [ span [ class "navbar-toggler-icon" ] [] ]


navbar : String -> List NavItem -> Html msg
navbar brand items =
    nav [ class "navbar navbar-inverse bg-inverse navbar-toggleable-sm" ]
        [ navbarToggler
        , a [ class "navbar-brand", href "/" ] [ text brand ]
        , div [ id "navbarNavDropdown", class "collapse navbar-collapse" ]
            [ ul [ class "navbar-nav mr-auto" ]
                (List.map view items)
            ]
        ]


view : NavItem -> Html msg
view navItem =
    li [ class "nav-item" ] [ a [ class "nav-link", href navItem.href ] [ text navItem.title ] ]


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


contextString : Context -> String
contextString context =
    case context of
        Warning ->
            "warning"

        Danger ->
            "danger"


alert : Context -> List (Html msg) -> Html msg
alert context =
    div [ class "alert", class <| "alert-" ++ contextString context ]


simpleAlert : Context -> String -> String -> Html msg
simpleAlert context title msg =
    alert context
        [ strong [] [ text title ]
        , text <| " " ++ msg
        ]



--<div id="api-not-available" class="alert alert-warning">
--  <strong>API not loaded.</strong> Session and player functions not yet available.
--</div>
--<div id="api-init-error" class="alert alert-danger initially-hidden" role="alert">
--  <strong id="api-init-error-info"></strong> You may need to use Chrome, or an Android device.
--</div>
