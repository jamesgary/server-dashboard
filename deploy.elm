module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Regex
import WebSocket


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { todo : List String
    , doing : List String
    , done : List String
    }


init : ( Model, Cmd Msg )
init =
    ( { todo = [ "filter0609p1mdw1.sendgrid.net", "filter1010p1mdw1.sendgrid.net" ]
      , doing = []
      , done = []
      }
    , Cmd.none
    )



-- UPDATE


type Msg
    = NewMessage String
    | Deploy


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NewMessage string ->
            ( model, Cmd.none )

        Deploy ->
            ( model, WebSocket.send "ws://127.0.0.1:9090/cmd" (payload model.todo) )


payload : List String -> String
payload servers =
    Encode.encode 0 <|
        Encode.object
            [ ( "cmd", Encode.string "deploy" )
            , ( "username", Encode.string "trothaus" )
            , ( "servers"
              , Encode.list
                    (encodeServers servers)
              )
            , ( "silence"
              , Encode.list []
              )
            , ( "concurrency", Encode.int 4 )
            ]


encodeServers : List String -> List Encode.Value
encodeServers servers =
    List.map Encode.string servers



-- VIEW


view : Model -> Html Msg
view model =
    div
        []
        [ button [ onClick Deploy ] [ text "Deploy" ]
        , lists model
        ]


list : String -> List String -> Html Msg
list title servers =
    div []
        [ h1 [] [ text title ]
        , ul [] (List.map (\s -> li [] [ text s ]) servers)
        ]


lists : Model -> Html Msg
lists model =
    div
        [ style [ ( "display", "flex" ) ] ]
        [ div []
            [ list "todo" model.todo
            , list "doing" model.doing
            , list "done" model.done
            ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    WebSocket.listen "ws://127.0.0.1:9090/cmd" NewMessage



-- OTHER


decodeListOfStrings : Decode.Decoder (List String)
decodeListOfStrings =
    Decode.list (Decode.at [ "name" ] Decode.string)
