module MainTest exposing (suite)

{-| Unit tests for Main TEA application lifecycle and state transitions.
-}

import Array
import Expect
import Json.Encode as Encode
import Main exposing (Model, Msg(..), init, update)
import Test exposing (Test, describe, test)


initModel : Model
initModel =
    let
        ( m, _ ) =
            init Encode.null
    in
    m


suite : Test
suite =
    describe "Main TEA Lifecycle"
        [ describe "init"
            [ test "initialises with default preset 0 when flags are null" <|
                \_ ->
                    let
                        ( m, _ ) =
                            init Encode.null
                    in
                    Expect.all
                        [ \mod ->
                            Expect.equal 0 mod.form.selectedPresetIndex
                        , \mod -> Expect.equal 0 mod.currentStepIndex
                        , \mod -> Expect.equal False mod.isPlaying
                        , \mod -> Expect.equal 600 mod.speedMs
                        , \mod ->
                            Expect.greaterThan 0 (Array.length mod.events)
                        ]
                        m
            , test "respects preset and step passed via flags" <|
                \_ ->
                    let
                        flags =
                            Encode.object
                                [ ( "preset", Encode.int 1 )
                                , ( "step", Encode.int 1 )
                                ]

                        ( m, _ ) =
                            init flags
                    in
                    Expect.all
                        [ \mod ->
                            Expect.equal 1 mod.form.selectedPresetIndex
                        , \mod -> Expect.equal 1 mod.currentStepIndex
                        ]
                        m
            ]
        , describe "update"
            [ test "SelectPreset updates preset index and resets step" <|
                \_ ->
                    let
                        ( m, _ ) =
                            update (SelectPreset 2) initModel
                    in
                    Expect.all
                        [ \mod ->
                            Expect.equal 2 mod.form.selectedPresetIndex
                        , \mod -> Expect.equal 0 mod.currentStepIndex
                        , \mod -> Expect.equal False mod.isPlaying
                        ]
                        m
            , test "StepNext increments step index and pauses playback" <|
                \_ ->
                    let
                        playingModel =
                            { initModel | isPlaying = True }

                        ( m, _ ) =
                            update StepNext playingModel
                    in
                    Expect.all
                        [ \mod -> Expect.equal 1 mod.currentStepIndex
                        , \mod -> Expect.equal False mod.isPlaying
                        ]
                        m
            , test "StepPrev decrements step index clamped at zero" <|
                \_ ->
                    let
                        ( m1, _ ) =
                            update StepNext initModel

                        ( m2, _ ) =
                            update StepPrev m1

                        ( m3, _ ) =
                            update StepPrev m2
                    in
                    Expect.all
                        [ \_ -> Expect.equal 1 m1.currentStepIndex
                        , \_ -> Expect.equal 0 m2.currentStepIndex
                        , \_ -> Expect.equal 0 m3.currentStepIndex
                        ]
                        ()
            , test "Seek jumps to clamped index" <|
                \_ ->
                    let
                        total =
                            Array.length initModel.events

                        ( mClampHigh, _ ) =
                            update (Seek 9999) initModel

                        ( mClampLow, _ ) =
                            update (Seek -5) initModel
                    in
                    Expect.all
                        [ \_ ->
                            Expect.equal (total - 1)
                                mClampHigh.currentStepIndex
                        , \_ -> Expect.equal 0 mClampLow.currentStepIndex
                        ]
                        ()
            , test "TogglePlay flips playing flag" <|
                \_ ->
                    let
                        ( mPlay, _ ) =
                            update TogglePlay initModel

                        ( mPause, _ ) =
                            update TogglePlay mPlay
                    in
                    Expect.all
                        [ \_ -> Expect.equal True mPlay.isPlaying
                        , \_ -> Expect.equal False mPause.isPlaying
                        ]
                        ()
            , test "Tick advances step and concludes at final step" <|
                \_ ->
                    let
                        total =
                            Array.length initModel.events

                        lastIdx =
                            total - 1

                        almostDoneModel =
                            { initModel
                                | currentStepIndex = lastIdx - 1
                                , isPlaying = True
                            }

                        ( m, _ ) =
                            update Tick almostDoneModel
                    in
                    Expect.all
                        [ \mod -> Expect.equal lastIdx mod.currentStepIndex
                        , \mod -> Expect.equal False mod.isPlaying
                        , \mod -> Expect.notEqual Nothing mod.alignmentReport
                        ]
                        m
            , test "UpdateSpeed sets timer interval" <|
                \_ ->
                    let
                        ( m, _ ) =
                            update (UpdateSpeed 300) initModel
                    in
                    Expect.equal 300 m.speedMs
            , test "Reset rewinds to step 0 and pauses" <|
                \_ ->
                    let
                        advancedModel =
                            { initModel
                                | currentStepIndex = 3
                                , isPlaying = True
                            }

                        ( m, _ ) =
                            update Reset advancedModel
                    in
                    Expect.all
                        [ \mod -> Expect.equal 0 mod.currentStepIndex
                        , \mod -> Expect.equal False mod.isPlaying
                        ]
                        m
            ]
        ]
