module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { servers : List String
    , serverSearchBox : String
    }


type Msg
    = SearchForServer String
    | FetchServers (Result Http.Error (List String))


init : ( Model, Cmd Msg )
init =
    ( { servers = [ "apid1", "apid2", "apid3" ]
      , serverSearchBox = ""
      }
    , Http.send FetchServers (Http.get "http://sensu-mdw1.sendgrid.net:4567/clients" decodeListOfStrings)
    )


decodeListOfStrings : Decode.Decoder (List String)
decodeListOfStrings =
    Decode.list (Decode.at [ "name" ] Decode.string)


view : Model -> Html Msg
view model =
    div
        [ class "container" ]
        [ input
            [ onInput SearchForServer ]
            []
        , ul
            [ class "servers" ]
            (List.map viewServer (List.filter (isServerMatch model.serverSearchBox) model.servers))
        ]


isServerMatch : String -> String -> Bool
isServerMatch search server =
    String.contains search server


viewServer : String -> Html Msg
viewServer serverName =
    li
        [ class "server" ]
        [ text serverName ]


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
                            { model | servers = [ "something went wrong" ] }

                        Ok serverList ->
                            { model | servers = serverList }
    in
        ( newModel, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        []
