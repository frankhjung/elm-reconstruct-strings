module View.MergeTheatre exposing (viewMergeTheatre)

{-| Aligned character theatre displaying suffix-prefix overlap and merge.

@docs viewMergeTheatre

-}

import Assembler exposing (OverlapCandidate)
import Html exposing (Html, div, h3, span, text)
import Html.Attributes exposing (class, id)
import View.StepView exposing (StepViewModel)


{-| Render the sliding character alignment theatre.
-}
viewMergeTheatre : StepViewModel -> Html msg
viewMergeTheatre model =
    div [ id "theatre-container", class "panel" ]
        [ h3 [] [ text "Overlap & Merge Theatre" ]
        , case model.candidate of
            Just candidate ->
                renderActiveTheatre candidate model.mergedFragment

            Nothing ->
                if model.isCompleted then
                    div [ class "theatre-idle" ]
                        [ text "Reduction complete. Final contigs assembled." ]

                else
                    div [ class "theatre-idle" ]
                        [ text "Scanning pool for candidate overlaps..." ]
        ]


renderActiveTheatre : OverlapCandidate -> Maybe String -> Html msg
renderActiveTheatre candidate maybeMerged =
    let
        prefixChars =
            String.toList candidate.prefix

        suffixChars =
            String.toList candidate.suffix

        prefixLen =
            List.length prefixChars

        suffixLen =
            List.length suffixChars

        matchLen =
            candidate.matchLength

        prefixNonOverlapLen =
            prefixLen - matchLen

        suffixNonOverlapLen =
            suffixLen - matchLen

        prefixRow =
            List.indexedMap
                (\idx ch ->
                    if idx >= prefixNonOverlapLen then
                        span
                            [ class "char-cell char-overlap" ]
                            [ text (String.fromChar ch) ]

                    else
                        span
                            [ class "char-cell char-prefix" ]
                            [ text (String.fromChar ch) ]
                )
                prefixChars
                ++ List.repeat suffixNonOverlapLen
                    (span [ class "char-cell char-gap" ] [ text "·" ])

        suffixLeadingGaps =
            List.repeat prefixNonOverlapLen
                (span [ class "char-cell char-gap" ] [ text "·" ])

        suffixRow =
            suffixLeadingGaps
                ++ List.indexedMap
                    (\idx ch ->
                        if idx < matchLen then
                            span
                                [ class "char-cell char-overlap" ]
                                [ text (String.fromChar ch) ]

                        else
                            span
                                [ class "char-cell char-suffix" ]
                                [ text (String.fromChar ch) ]
                    )
                    suffixChars

        mergedRow =
            case maybeMerged of
                Just mergedStr ->
                    let
                        chars =
                            String.toList mergedStr
                    in
                    List.indexedMap
                        (\idx ch ->
                            if idx < prefixNonOverlapLen then
                                span
                                    [ class "char-cell char-prefix" ]
                                    [ text (String.fromChar ch) ]

                            else if idx < prefixNonOverlapLen + matchLen then
                                span
                                    [ class "char-cell char-overlap" ]
                                    [ text (String.fromChar ch) ]

                            else
                                span
                                    [ class "char-cell char-suffix" ]
                                    [ text (String.fromChar ch) ]
                        )
                        chars

                Nothing ->
                    let
                        totalLen =
                            prefixNonOverlapLen + matchLen + suffixNonOverlapLen
                    in
                    List.repeat totalLen
                        (span [ class "char-cell char-placeholder" ]
                            [ text "—" ]
                        )
    in
    div [ class "theatre-content" ]
        [ div [ class "theatre-row" ]
            [ span [ class "row-label" ] [ text "Prefix" ]
            , div [ class "cell-row" ] prefixRow
            ]
        , div [ class "theatre-row" ]
            [ span [ class "row-label" ] [ text "Suffix" ]
            , div [ class "cell-row" ] suffixRow
            ]
        , div [ class "theatre-row row-merged" ]
            [ span [ class "row-label" ] [ text "Merged" ]
            , div [ class "cell-row" ] mergedRow
            ]
        ]
