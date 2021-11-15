module Query exposing (..)

import Dict exposing (..)
import List exposing (..)


type alias Query =
    Dict String (List (Maybe String))


first : String -> Query -> Maybe (Maybe String)
first key query =
    Dict.get key query |> Maybe.andThen head


all : String -> Query -> List (Maybe String)
all key query =
    Dict.get key query |> Maybe.withDefault []


parseQuery : String -> Query
parseQuery query =
    let
        params : List String
        params =
            String.split "&" query

        pairs : List ( String, Maybe String )
        pairs =
            List.map
                (\param ->
                    case String.split "=" param of
                        key :: [] ->
                            ( key, Nothing )

                        key :: rest ->
                            ( key, Just <| String.join "=" rest )

                        [] ->
                            ( "", Nothing )
                )
                params

        update : Maybe String -> Maybe (List (Maybe String)) -> Maybe (List (Maybe String))
        update new old =
            Just <|
                case old of
                    Nothing ->
                        [ new ]

                    Just list ->
                        new :: list
    in
    pairs
        |> List.foldr
            (\( key, value ) ->
                Dict.update key <| update value
            )
            Dict.empty
