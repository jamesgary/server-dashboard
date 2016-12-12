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
    | Clients (Result Http.Error (List String))


init : ( Model, Cmd Msg )
init =
    ( { servers = [ "loading..." ]
      , serverSearchBox = ""
      }
    , getClients
    )


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

                Clients (Err e) ->
                    case e of
                        Http.BadUrl e ->
                            { model | servers = [ "bad url" ] }

                        Http.Timeout ->
                            { model | servers = [ "timeout" ] }

                        Http.NetworkError ->
                            { model | servers = [ "network error" ] }

                        Http.BadStatus resp ->
                            { model | servers = [ "bad status" ] }

                        Http.BadPayload p resp ->
                            { model | servers = [ "error getting clients" ] }

                Clients (Ok clients) ->
                    { model | servers = clients }
    in
        ( newModel, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        []



-- HTTP


getClients : Cmd Msg
getClients =
    let
        url =
            "http://sensu-mdw1.sendgrid.net:4567/clients"

        headers =
            [ Http.header "Accept" "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
            ]

        request =
            Http.request
                ({ method = "GET"
                 , headers = headers
                 , url = url
                 , body = Http.emptyBody
                 , expect = Http.expectJson decodeClients
                 , timeout = Nothing
                 , withCredentials = False
                 }
                )
    in
        Http.send Clients request


decodeClients : Decode.Decoder (List String)
decodeClients =
    Decode.list (Decode.at [ "name" ] Decode.string)
