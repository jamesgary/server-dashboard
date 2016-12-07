module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode
import Regex


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { serverSearchBox : String
    , servers : ServerList
    , stashes : StashList
    }


type StashList
    = Success (List String)
    | Loading
    | Error String


type ServerList
    = Success (List Server)
    | Loading
    | Error String


type alias Server =
    { name : String
    , isStashed : Bool
    }


initServer name =
    { name = name
    , isStashed = False
    }


type Msg
    = SearchForServer String
    | FetchServers (Result Http.Error (List String))
    | FetchStashes (Result Http.Error (List String))


init : ( Model, Cmd Msg )
init =
    ( { servers = Loading
      , serverSearchBox = ""
      }
    , Cmd.batch
        [ Http.send FetchServers (Http.get "http://sensu-mdw1.sendgrid.net:4567/clients" decodeListOfServers)
        , Http.send FetchStashes (Http.get "http://sensu-mdw1.sendgrid.net:4567/stashes" decodeListOfStashes)
        ]
    )


decodeListOfServers : Decode.Decoder (List String)
decodeListOfServers =
    Decode.list (Decode.at [ "name" ] Decode.string)


decodeListOfStashes : Decode.Decoder (List String)
decodeListOfStashes =
    {--|> (fancy logic here) --}
    Decode.list (Decode.at [ "path" ] Decode.string)



-- VIEW


view : Model -> Html Msg
view model =
    div
        [ class "container" ]
        [ input
            [ onInput SearchForServer ]
            []
        , viewServers model.serverSearchBox model.servers
        ]


isServerMatch : String -> Server -> Bool
isServerMatch search server =
    let
        regex =
            Regex.regex search
    in
        Regex.contains regex server.name


viewServers : String -> ServerList -> Html Msg
viewServers searchTerm serverList =
    case serverList of
        Loading ->
            div
                []
                [ text "Loading..." ]

        Success servers ->
            ul
                [ class "servers" ]
                (List.map viewServer (List.filter (isServerMatch searchTerm) servers))

        Error errorMsg ->
            div
                [ style [ ( "color", "red" ) ] ]
                [ text errorMsg ]


viewServer : Server -> Html Msg
viewServer server =
    li
        [ class "server" ]
        [ text server.name ]



-- UPDATE


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        newModel =
            case msg of
                SearchForServer serverName ->
                    { model | serverSearchBox = serverName }

                FetchServers serverList ->
                    case serverList of
                        Err _ ->
                            { model | servers = Error "something went wrong fetching servers" }

                        Ok serverList ->
                            { model | servers = Success (List.map initServer serverList) }

                FetchStashes stashList ->
                    case stashList of
                        Err _ ->
                            { model | servers = Error "something went wrong fetching stashes" }

                        Ok serverList ->
                            { model | stashes = Success serverList }
    in
        ( newModel, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        []
