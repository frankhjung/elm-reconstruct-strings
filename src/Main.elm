module Main exposing
    ( Flags, FormState, Model, Msg(..)
    , init, update, main
    )

{-| Single-page interactive OLC sequence assembler and verification workbench.


# Types

@docs Flags, FormState, Model, Msg


# Lifecycle

@docs init, update, main

-}

import Alignment
    exposing
        ( AlignmentReport
        , alignContigsToSource
        , calculateFragmentCoverage
        )
import Array exposing (Array)
import Assembler
    exposing
        ( ReductionEvent(..)
        , RemovedFragment
        , traceAssembly
        )
import Browser
import Generator
    exposing
        ( RawParamsInput
        , ValidationError(..)
        , fragmentsGenerator
        , parseFragments
        , validateCustomPool
        , validateRawParams
        )
import Html exposing (Html, div, h1, header, main_, p, text)
import Html.Attributes exposing (class, id)
import Html.Lazy exposing (lazy, lazy2)
import Json.Decode as Decode exposing (Value)
import Presets exposing (getPreset, presets)
import Random
import Time
import View.Controls
    exposing
        ( viewControls
        , viewPlaybackBar
        , viewStatusBanner
        )
import View.Diff exposing (viewDiff)
import View.MergeTheatre exposing (viewMergeTheatre)
import View.Pool exposing (viewPool)
import View.StepView exposing (projectStepView)


{-| Startup flags passed from host index.html.
-}
type alias Flags =
    { preset : Maybe Int
    , step : Maybe Int
    }


{-| UI form inputs and modal toggle states.
-}
type alias FormState =
    { rawParams : RawParamsInput
    , selectedPresetIndex : Int
    , isCustomEditorOpen : Bool
    , customFragmentsText : String
    , validationErrors : List ValidationError
    }


{-| Root application state.
-}
type alias Model =
    { source : String
    , form : FormState
    , fragments : List String
    , events : Array ReductionEvent
    , currentStepIndex : Int
    , isPlaying : Bool
    , speedMs : Int
    , cumulativeRemoved : List RemovedFragment
    , alignmentReport : Maybe AlignmentReport
    }


{-| User interaction and timer progression messages.
-}
type Msg
    = UpdateSource String
    | SelectPreset Int
    | UpdateMinOverlap String
    | UpdateMinLength String
    | UpdateMaxLength String
    | UpdateFragmentCount String
    | GenerateFragments
    | GotRandomFragments (List String)
    | ToggleCustomEditor
    | UpdateCustomFragments String
    | ApplyCustomPool
    | TogglePlay
    | Tick
    | StepNext
    | StepPrev
    | Seek Int
    | UpdateSpeed Int
    | Reset


flagsDecoder : Decode.Decoder Flags
flagsDecoder =
    Decode.map2 Flags
        (Decode.maybe (Decode.field "preset" Decode.int))
        (Decode.maybe (Decode.field "step" Decode.int))


{-| Initialise application model from startup flags.
-}
init : Value -> ( Model, Cmd Msg )
init flagsValue =
    let
        flags =
            Decode.decodeValue flagsDecoder flagsValue
                |> Result.withDefault { preset = Nothing, step = Nothing }

        presetIndex =
            flags.preset |> Maybe.withDefault 0

        preset =
            getPreset presetIndex

        defaultFragments =
            preset.defaultFragments |> Maybe.withDefault []

        rawForm =
            { source = preset.source
            , minOverlap = String.fromInt preset.minOverlap
            , minLength = String.fromInt preset.minLength
            , maxLength = String.fromInt preset.maxLength
            , fragmentCount = String.fromInt preset.fragmentCount
            }

        ( initialEvents, initialRemoved, initialErrors ) =
            case computeEvents defaultFragments preset.minOverlap of
                Ok ( evts, rem ) ->
                    ( evts, rem, [] )

                Err err ->
                    ( Array.empty, [], [ err ] )

        formState =
            { rawParams = rawForm
            , selectedPresetIndex = presetIndex
            , isCustomEditorOpen = False
            , customFragmentsText = String.join "\n" defaultFragments
            , validationErrors = initialErrors
            }

        totalEvents =
            Array.length initialEvents

        targetStep =
            flags.step
                |> Maybe.withDefault 0
                |> Basics.max 0
                |> Basics.min (Basics.max 0 (totalEvents - 1))

        report =
            computeReport
                preset.source
                defaultFragments
                initialEvents
                targetStep
    in
    ( { source = preset.source
      , form = formState
      , fragments = defaultFragments
      , events = initialEvents
      , currentStepIndex = targetStep
      , isPlaying = False
      , speedMs = 600
      , cumulativeRemoved = initialRemoved
      , alignmentReport = report
      }
    , Cmd.none
    )


computeEvents :
    List String
    -> Int
    -> Result ValidationError ( Array ReductionEvent, List RemovedFragment )
computeEvents fragments minOverlap =
    case traceAssembly fragments minOverlap of
        Ok evts ->
            let
                arr =
                    Array.fromList evts

                gatherRemoved event =
                    case event of
                        InitialFiltered data ->
                            data.removed

                        DynamicFiltered data ->
                            data.removed

                        _ ->
                            []

                allRemoved =
                    List.concatMap gatherRemoved evts
            in
            Ok ( arr, allRemoved )

        Err err ->
            Err (AssemblyPrecondition err)


computeReport :
    String
    -> List String
    -> Array ReductionEvent
    -> Int
    -> Maybe AlignmentReport
computeReport source fragments events stepIdx =
    let
        total =
            Array.length events
    in
    if total == 0 then
        Nothing

    else if stepIdx >= total - 1 then
        case Array.get stepIdx events of
            Just (AssemblyCompleted data) ->
                Just (alignContigsToSource source data.contigs)

            _ ->
                Just (calculateFragmentCoverage source fragments)

    else
        Just (calculateFragmentCoverage source fragments)


{-| The Elm Architecture update reducer.
-}
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UpdateSource newSrc ->
            let
                oldForm =
                    model.form

                oldRaw =
                    oldForm.rawParams

                newRaw =
                    { oldRaw | source = newSrc }

                newReport =
                    computeReport
                        newSrc
                        model.fragments
                        model.events
                        model.currentStepIndex
            in
            ( { model
                | source = newSrc
                , form = { oldForm | rawParams = newRaw }
                , alignmentReport = newReport
              }
            , Cmd.none
            )

        SelectPreset idx ->
            let
                preset =
                    getPreset idx

                defaultFrags =
                    preset.defaultFragments |> Maybe.withDefault []

                newRaw =
                    { source = preset.source
                    , minOverlap = String.fromInt preset.minOverlap
                    , minLength = String.fromInt preset.minLength
                    , maxLength = String.fromInt preset.maxLength
                    , fragmentCount = String.fromInt preset.fragmentCount
                    }

                ( evts, rem, errs ) =
                    case computeEvents defaultFrags preset.minOverlap of
                        Ok ( e, r ) ->
                            ( e, r, [] )

                        Err err ->
                            ( Array.empty, [], [ err ] )

                oldForm =
                    model.form

                newForm =
                    { oldForm
                        | selectedPresetIndex = idx
                        , rawParams = newRaw
                        , customFragmentsText = String.join "\n" defaultFrags
                        , validationErrors = errs
                    }

                report =
                    computeReport preset.source defaultFrags evts 0
            in
            ( { model
                | source = preset.source
                , form = newForm
                , fragments = defaultFrags
                , events = evts
                , currentStepIndex = 0
                , isPlaying = False
                , cumulativeRemoved = rem
                , alignmentReport = report
              }
            , Cmd.none
            )

        UpdateMinOverlap str ->
            updateRawField (\raw -> { raw | minOverlap = str }) model

        UpdateMinLength str ->
            updateRawField (\raw -> { raw | minLength = str }) model

        UpdateMaxLength str ->
            updateRawField (\raw -> { raw | maxLength = str }) model

        UpdateFragmentCount str ->
            updateRawField (\raw -> { raw | fragmentCount = str }) model

        GenerateFragments ->
            case validateRawParams model.form.rawParams of
                Ok params ->
                    ( { model
                        | isPlaying = False
                        , form = setErrors [] model.form
                      }
                    , Random.generate GotRandomFragments
                        (fragmentsGenerator params)
                    )

                Err errs ->
                    ( { model
                        | isPlaying = False
                        , fragments = []
                        , events = Array.empty
                        , currentStepIndex = 0
                        , alignmentReport = Nothing
                        , form = setErrors errs model.form
                      }
                    , Cmd.none
                    )

        GotRandomFragments fragments ->
            let
                n =
                    String.toInt model.form.rawParams.minOverlap
                        |> Maybe.withDefault 2

                ( evts, rem, errs ) =
                    case computeEvents fragments n of
                        Ok ( e, r ) ->
                            ( e, r, [] )

                        Err err ->
                            ( Array.empty, [], [ err ] )

                form =
                    model.form

                newForm =
                    { form
                        | customFragmentsText = String.join "\n" fragments
                        , validationErrors = errs
                    }

                report =
                    computeReport model.source fragments evts 0
            in
            ( { model
                | fragments = fragments
                , events = evts
                , currentStepIndex = 0
                , isPlaying = False
                , cumulativeRemoved = rem
                , alignmentReport = report
                , form = newForm
              }
            , Cmd.none
            )

        ToggleCustomEditor ->
            let
                form =
                    model.form

                newForm =
                    { form | isCustomEditorOpen = not form.isCustomEditorOpen }
            in
            ( { model | form = newForm }, Cmd.none )

        UpdateCustomFragments str ->
            let
                form =
                    model.form

                newForm =
                    { form | customFragmentsText = str }
            in
            ( { model | form = newForm }, Cmd.none )

        ApplyCustomPool ->
            case validateCustomPool model.form.customFragmentsText of
                Ok fragments ->
                    let
                        n =
                            String.toInt model.form.rawParams.minOverlap
                                |> Maybe.withDefault 2
                    in
                    case computeEvents fragments n of
                        Ok ( evts, rem ) ->
                            let
                                report =
                                    computeReport
                                        model.source
                                        fragments
                                        evts
                                        0
                            in
                            ( { model
                                | fragments = fragments
                                , events = evts
                                , currentStepIndex = 0
                                , isPlaying = False
                                , cumulativeRemoved = rem
                                , alignmentReport = report
                                , form = setErrors [] model.form
                              }
                            , Cmd.none
                            )

                        Err err ->
                            ( { model
                                | isPlaying = False
                                , form = setErrors [ err ] model.form
                              }
                            , Cmd.none
                            )

                Err errs ->
                    ( { model
                        | isPlaying = False
                        , form = setErrors errs model.form
                      }
                    , Cmd.none
                    )

        TogglePlay ->
            let
                total =
                    Array.length model.events

                startingAtEnd =
                    model.currentStepIndex >= total - 1 && total > 0

                newIndex =
                    if startingAtEnd then
                        0

                    else
                        model.currentStepIndex

                newPlaying =
                    not model.isPlaying

                report =
                    computeReport
                        model.source
                        model.fragments
                        model.events
                        newIndex
            in
            ( { model
                | isPlaying = newPlaying
                , currentStepIndex = newIndex
                , alignmentReport = report
              }
            , Cmd.none
            )

        Tick ->
            let
                total =
                    Array.length model.events

                nextIndex =
                    model.currentStepIndex + 1
            in
            if nextIndex >= total - 1 then
                let
                    finalIndex =
                        Basics.max 0 (total - 1)

                    report =
                        computeReport
                            model.source
                            model.fragments
                            model.events
                            finalIndex
                in
                ( { model
                    | currentStepIndex = finalIndex
                    , isPlaying = False
                    , alignmentReport = report
                  }
                , Cmd.none
                )

            else
                ( { model | currentStepIndex = nextIndex }
                , Cmd.none
                )

        StepNext ->
            let
                total =
                    Array.length model.events

                nextIndex =
                    Basics.min (total - 1) (model.currentStepIndex + 1)

                report =
                    computeReport
                        model.source
                        model.fragments
                        model.events
                        nextIndex
            in
            ( { model
                | currentStepIndex = nextIndex
                , isPlaying = False
                , alignmentReport = report
              }
            , Cmd.none
            )

        StepPrev ->
            let
                prevIndex =
                    Basics.max 0 (model.currentStepIndex - 1)

                report =
                    computeReport
                        model.source
                        model.fragments
                        model.events
                        prevIndex
            in
            ( { model
                | currentStepIndex = prevIndex
                , isPlaying = False
                , alignmentReport = report
              }
            , Cmd.none
            )

        Seek idx ->
            let
                total =
                    Array.length model.events

                clampedIdx =
                    Basics.max 0 (Basics.min (total - 1) idx)

                report =
                    computeReport
                        model.source
                        model.fragments
                        model.events
                        clampedIdx
            in
            ( { model
                | currentStepIndex = clampedIdx
                , isPlaying = False
                , alignmentReport = report
              }
            , Cmd.none
            )

        UpdateSpeed ms ->
            ( { model | speedMs = ms }, Cmd.none )

        Reset ->
            let
                preset =
                    getPreset model.form.selectedPresetIndex

                defaultFrags =
                    parseFragments model.form.customFragmentsText

                ( evts, rem ) =
                    case computeEvents defaultFrags preset.minOverlap of
                        Ok ( e, r ) ->
                            ( e, r )

                        Err _ ->
                            ( model.events, model.cumulativeRemoved )

                report =
                    computeReport model.source defaultFrags evts 0
            in
            ( { model
                | fragments = defaultFrags
                , events = evts
                , currentStepIndex = 0
                , isPlaying = False
                , cumulativeRemoved = rem
                , alignmentReport = report
              }
            , Cmd.none
            )


updateRawField :
    (RawParamsInput -> RawParamsInput)
    -> Model
    -> ( Model, Cmd Msg )
updateRawField updater model =
    let
        oldForm =
            model.form

        newRaw =
            updater oldForm.rawParams
    in
    ( { model | form = { oldForm | rawParams = newRaw } }, Cmd.none )


setErrors : List ValidationError -> FormState -> FormState
setErrors errs form =
    { form | validationErrors = errs }


{-| Declarative subscription for playback animation timer.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    if model.isPlaying then
        Time.every (toFloat model.speedMs) (\_ -> Tick)

    else
        Sub.none


{-| Root application view.
-}
view : Model -> Html Msg
view model =
    let
        currentEvent =
            Array.get model.currentStepIndex model.events
                |> Maybe.withDefault
                    (InitialFiltered { pool = [], removed = [] })

        stepView =
            projectStepView model.cumulativeRemoved currentEvent

        controlsConfig =
            { rawParams = model.form.rawParams
            , presets = presets
            , selectedPresetIndex = model.form.selectedPresetIndex
            , isCustomEditorOpen = model.form.isCustomEditorOpen
            , customFragmentsText = model.form.customFragmentsText
            , validationErrors = model.form.validationErrors
            , onSourceChange = UpdateSource
            , onPresetSelect = SelectPreset
            , onMinOverlapChange = UpdateMinOverlap
            , onMinLengthChange = UpdateMinLength
            , onMaxLengthChange = UpdateMaxLength
            , onFragmentCountChange = UpdateFragmentCount
            , onGenerate = GenerateFragments
            , onToggleCustomEditor = ToggleCustomEditor
            , onCustomFragmentsChange = UpdateCustomFragments
            , onApplyCustomPool = ApplyCustomPool
            , onReset = Reset
            }

        playbackConfig =
            { isPlaying = model.isPlaying
            , currentStep = model.currentStepIndex
            , totalSteps = Array.length model.events
            , speedMs = model.speedMs
            , stageName = stepView.stageName
            , onTogglePlay = TogglePlay
            , onStepNext = StepNext
            , onStepPrev = StepPrev
            , onSeek = Seek
            , onSpeedChange = UpdateSpeed
            }
    in
    div [ id "app-root", class "app-layout" ]
        [ header [ class "app-header" ]
            [ h1 [] [ text "Interactive OLC Sequence Assembler" ]
            , p [ class "app-subtitle" ]
                [ text
                    ("Greedy Overlap-Layout-Consensus reduction workbench"
                        ++ " and reference sequence alignment verifier in Elm."
                    )
                ]
            ]
        , main_ [ class "main-container" ]
            [ div [ class "sidebar-col" ]
                [ viewControls controlsConfig ]
            , div [ class "workspace-col" ]
                [ viewStatusBanner stepView.narration
                , viewPlaybackBar playbackConfig
                , lazy viewMergeTheatre stepView
                , lazy viewPool stepView
                , lazy2 viewDiff model.alignmentReport model.source
                ]
            ]
        ]


{-| Browser.element application entry point.
-}
main : Program Value Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
