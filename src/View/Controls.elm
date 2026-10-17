module View.Controls exposing
    ( ControlsConfig, PlaybackConfig, sliderToDelay, delayToSlider
    , viewControls, viewPlaybackBar, viewStatusBanner
    )

{-| Controls panel, parameters form, and playback bar views.

@docs ControlsConfig, PlaybackConfig, sliderToDelay, delayToSlider
@docs viewControls, viewPlaybackBar, viewStatusBanner

-}

import Generator
    exposing
        ( RawParamsInput
        , ValidationError
        , errorToString
        )
import Html
    exposing
        ( Html
        , button
        , div
        , h2
        , input
        , label
        , option
        , select
        , span
        , text
        , textarea
        )
import Html.Attributes as Attr
    exposing
        ( attribute
        , class
        , disabled
        , id
        , step
        , type_
        , value
        )
import Html.Events exposing (onClick, onInput)
import Presets exposing (Preset)


{-| Form configuration data passed to the controls view.
-}
type alias ControlsConfig msg =
    { rawParams : RawParamsInput
    , presets : List Preset
    , selectedPresetIndex : Int
    , isCustomEditorOpen : Bool
    , customFragmentsText : String
    , validationErrors : List ValidationError
    , onSourceChange : String -> msg
    , onPresetSelect : Int -> msg
    , onMinOverlapChange : String -> msg
    , onMinLengthChange : String -> msg
    , onMaxLengthChange : String -> msg
    , onFragmentCountChange : String -> msg
    , onGenerate : msg
    , onToggleCustomEditor : msg
    , onCustomFragmentsChange : String -> msg
    , onApplyCustomPool : msg
    , onReset : msg
    }


{-| Playback bar configuration state and dispatch actions.
-}
type alias PlaybackConfig msg =
    { isPlaying : Bool
    , currentStep : Int
    , totalSteps : Int
    , speedMs : Int
    , stageName : String
    , onTogglePlay : msg
    , onStepNext : msg
    , onStepPrev : msg
    , onSeek : Int -> msg
    , onSpeedChange : Int -> msg
    }


{-| Convert slider integer value (1-10) to step delay milliseconds (200-2000).
-}
sliderToDelay : Int -> Int
sliderToDelay sliderVal =
    let
        clamped =
            Basics.max 1 (Basics.min 10 sliderVal)
    in
    2200 - (clamped * 200)


{-| Convert step delay milliseconds (200-2000) to slider integer value (1-10).
-}
delayToSlider : Int -> Int
delayToSlider delayMs =
    let
        clamped =
            Basics.max 200 (Basics.min 2000 delayMs)
    in
    (2200 - clamped) // 200


{-| Render the control sidebar with generator inputs and custom pool editor.
-}
viewControls : ControlsConfig msg -> Html msg
viewControls config =
    div [ id "controls-panel", class "panel" ]
        [ h2 [] [ text "Sequence & Fragment Generator" ]
        , viewValidationErrors config.validationErrors
        , div [ class "form-group" ]
            [ label [] [ text "Curated Preset" ]
            , select
                [ id "preset-select"
                , onInput
                    (\str ->
                        config.onPresetSelect
                            (String.toInt str |> Maybe.withDefault 0)
                    )
                ]
                (List.indexedMap
                    (\idx p ->
                        option
                            [ value (String.fromInt idx)
                            , Attr.selected
                                (idx == config.selectedPresetIndex)
                            ]
                            [ text p.name ]
                    )
                    config.presets
                )
            ]
        , div [ class "form-group" ]
            [ label [] [ text "Source Sequence" ]
            , textarea
                [ id "param-source"
                , value config.rawParams.source
                , onInput config.onSourceChange
                , attribute "rows" "3"
                ]
                []
            ]
        , div [ class "form-row" ]
            [ div [ class "form-group" ]
                [ label [] [ text "Min Overlap (n)" ]
                , input
                    [ id "param-n"
                    , type_ "number"
                    , value config.rawParams.minOverlap
                    , onInput config.onMinOverlapChange
                    ]
                    []
                ]
            , div [ class "form-group" ]
                [ label [] [ text "Fragment Count (m)" ]
                , input
                    [ id "param-m"
                    , type_ "number"
                    , value config.rawParams.fragmentCount
                    , onInput config.onFragmentCountChange
                    ]
                    []
                ]
            ]
        , div [ class "form-row" ]
            [ div [ class "form-group" ]
                [ label [] [ text "Min Length (a)" ]
                , input
                    [ id "param-a"
                    , type_ "number"
                    , value config.rawParams.minLength
                    , onInput config.onMinLengthChange
                    ]
                    []
                ]
            , div [ class "form-group" ]
                [ label [] [ text "Max Length (b)" ]
                , input
                    [ id "param-b"
                    , type_ "number"
                    , value config.rawParams.maxLength
                    , onInput config.onMaxLengthChange
                    ]
                    []
                ]
            ]
        , div [ class "button-group" ]
            [ button
                [ id "btn-generate"
                , class "btn btn-primary"
                , onClick config.onGenerate
                ]
                [ text "Generate Fragments" ]
            , button
                [ id "btn-toggle-custom"
                , class "btn btn-secondary"
                , onClick config.onToggleCustomEditor
                ]
                [ text
                    (if config.isCustomEditorOpen then
                        "Close Custom Pool"

                     else
                        "Manual Pool Editor"
                    )
                ]
            , button
                [ id "btn-reset"
                , class "btn btn-outline"
                , onClick config.onReset
                ]
                [ text "Reset" ]
            ]
        , if config.isCustomEditorOpen then
            div [ id "custom-editor", class "custom-editor-box" ]
                [ label []
                    [ text "Manual Fragments (newline/comma separated)" ]
                , textarea
                    [ id "custom-fragments"
                    , value config.customFragmentsText
                    , onInput config.onCustomFragmentsChange
                    , attribute "rows" "5"
                    ]
                    []
                , button
                    [ id "btn-apply-custom"
                    , class "btn btn-accent"
                    , onClick config.onApplyCustomPool
                    ]
                    [ text "Apply Custom Pool" ]
                ]

          else
            text ""
        ]


{-| Render the playback transport and timeline scrubber bar.
-}
viewPlaybackBar : PlaybackConfig msg -> Html msg
viewPlaybackBar config =
    div [ id "playback-bar", class "playback-container" ]
        [ div [ class "playback-controls" ]
            [ button
                [ id "btn-step-prev"
                , class "btn btn-icon"
                , onClick config.onStepPrev
                , disabled (config.currentStep <= 0)
                ]
                [ text "⏮" ]
            , button
                [ id "btn-play-pause"
                , class "btn btn-icon btn-play"
                , onClick config.onTogglePlay
                ]
                [ text
                    (if config.isPlaying then
                        "⏸ Pause"

                     else
                        "▶ Play"
                    )
                ]
            , button
                [ id "btn-step-next"
                , class "btn btn-icon"
                , onClick config.onStepNext
                , disabled
                    (config.totalSteps
                        == 0
                        || config.currentStep
                        >= config.totalSteps
                        - 1
                    )
                ]
                [ text "⏭" ]
            ]
        , div [ class "scrubber-container" ]
            [ input
                [ id "scrubber"
                , type_ "range"
                , Attr.min "0"
                , Attr.max
                    (String.fromInt (Basics.max 0 (config.totalSteps - 1)))
                , value (String.fromInt config.currentStep)
                , onInput
                    (\str ->
                        config.onSeek (String.toInt str |> Maybe.withDefault 0)
                    )
                ]
                []
            , span [ id "step-label", class "step-indicator" ]
                [ text
                    ("Step "
                        ++ String.fromInt (config.currentStep + 1)
                        ++ " / "
                        ++ String.fromInt (Basics.max 1 config.totalSteps)
                        ++ " ("
                        ++ config.stageName
                        ++ ")"
                    )
                ]
            ]
        , div [ class "speed-container" ]
            [ label [] [ text "Speed" ]
            , input
                [ id "speed-slider"
                , type_ "range"
                , Attr.min "1"
                , Attr.max "10"
                , step "1"
                , value (String.fromInt (delayToSlider config.speedMs))
                , onInput
                    (\str ->
                        let
                            sVal =
                                String.toInt str |> Maybe.withDefault 5
                        in
                        config.onSpeedChange (sliderToDelay sVal)
                    )
                ]
                []
            , span [ class "speed-label" ]
                [ text (String.fromInt config.speedMs ++ " ms") ]
            ]
        ]


{-| Render human-readable narration explanation banner.
-}
viewStatusBanner : String -> Html msg
viewStatusBanner narration =
    div [ id "status-explanation", class "status-banner" ]
        [ span [ class "narration-text" ] [ text narration ] ]


{-| Render validation error alert messages.
-}
viewValidationErrors : List ValidationError -> Html msg
viewValidationErrors errors =
    if List.isEmpty errors then
        text ""

    else
        div [ class "alert alert-error" ]
            (List.map (\err -> div [] [ text (errorToString err) ]) errors)
