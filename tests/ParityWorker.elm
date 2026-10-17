port module ParityWorker exposing (main)

{-| Headless Platform.worker for differential parity testing.
-}

import Assembler exposing (assembleStrings)
import Json.Decode as Decode


port outputResult : List String -> Cmd msg


type alias Flags =
    { fragments : List String
    , minOverlap : Int
    }


flagsDecoder : Decode.Decoder Flags
flagsDecoder =
    Decode.map2 Flags
        (Decode.field "fragments" (Decode.list Decode.string))
        (Decode.field "minOverlap" Decode.int)


init : Decode.Value -> ( (), Cmd msg )
init flagsVal =
    case Decode.decodeValue flagsDecoder flagsVal of
        Ok flags ->
            case assembleStrings flags.fragments flags.minOverlap of
                Ok contigs ->
                    ( (), outputResult contigs )

                Err _ ->
                    ( (), outputResult [] )

        Err _ ->
            ( (), outputResult [] )


main : Program Decode.Value () msg
main =
    Platform.worker
        { init = init
        , update = \_ model -> ( model, Cmd.none )
        , subscriptions = \_ -> Sub.none
        }
