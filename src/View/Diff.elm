module View.Diff exposing (viewDiff)

{-| Reference alignment diff view and assembly diagnostic metrics.

@docs viewDiff

-}

import Alignment
    exposing
        ( AlignmentReport
        , ContigAlignment
        , DiagnosticStatus(..)
        )
import Html exposing (Html, div, h3, h4, span, text)
import Html.Attributes exposing (class, id)


{-| Format a float percentage to deterministic one-decimal string.
-}
formatPercent : Float -> String
formatPercent pct =
    let
        roundedTimesTen =
            round (pct * 10)

        whole =
            roundedTimesTen // 10

        fraction =
            modBy 10 (abs roundedTimesTen)
    in
    String.fromInt whole ++ "." ++ String.fromInt fraction ++ "%"


{-| Render the reference alignment diff view and diagnostic metrics cards.
-}
viewDiff : Maybe AlignmentReport -> String -> Html msg
viewDiff maybeReport source =
    div [ id "diff-container", class "panel" ]
        [ h3 [] [ text "Reference Alignment & Diagnostics" ]
        , case maybeReport of
            Just report ->
                renderCompletedDiff report source

            Nothing ->
                div [ class "diff-placeholder" ]
                    [ span [ class "placeholder-text" ]
                        [ text
                            ("Assembly in progress. Reference alignment will"
                                ++ " display when reduction completes."
                            )
                        ]
                    ]
        ]


renderCompletedDiff : AlignmentReport -> String -> Html msg
renderCompletedDiff report source =
    let
        ( statusText, statusClass, statusDesc ) =
            case report.diagnosticStatus of
                PerfectReconstruction ->
                    ( "PERFECT RECONSTRUCTION"
                    , "status-perfect"
                    , "Ground truth sequence reconstructed with 100% coverage."
                    )

                PartialAssembly ->
                    ( "PARTIAL ASSEMBLY"
                    , "status-partial"
                    , "Single exact contig assembled with incomplete coverage."
                    )

                FragmentedAssembly ->
                    ( "FRAGMENTED ASSEMBLY"
                    , "status-fragmented"
                    , "Multiple exact contigs; sequence coverage is disjoint."
                    )

                MisassemblyDetected ->
                    ( "MISASSEMBLY DETECTED"
                    , "status-misassembly"
                    , "Chimeric join or sequence mismatch detected in contigs."
                    )

        totalContigs =
            List.length report.alignments + List.length report.unalignedContigs
    in
    div [ class "diff-content" ]
        [ div [ class ("diagnostic-banner " ++ statusClass) ]
            [ h4 [ class "diagnostic-title" ] [ text statusText ]
            , span [ class "diagnostic-desc" ] [ text statusDesc ]
            ]
        , div [ class "metrics-grid" ]
            [ div [ class "metric-card" ]
                [ span [ class "metric-label" ] [ text "Diagnostic Status" ]
                , span [ class "metric-value" ] [ text statusText ]
                ]
            , div [ class "metric-card" ]
                [ span [ class "metric-label" ] [ text "Sequence Coverage" ]
                , span [ class "metric-value" ]
                    [ text (formatPercent report.coveragePercent) ]
                ]
            , div [ class "metric-card" ]
                [ span [ class "metric-label" ] [ text "Contigs Reconstructed" ]
                , span [ class "metric-value" ]
                    [ text (String.fromInt totalContigs) ]
                ]
            ]
        , div [ class "alignment-theatre" ]
            [ renderSourceRow source report
            , div [ class "contigs-rows" ]
                (List.indexedMap
                    (renderContigRow source)
                    report.alignments
                )
            , renderUnalignedSection report.unalignedContigs
            ]
        , renderLegend
        ]


renderSourceRow : String -> AlignmentReport -> Html msg
renderSourceRow source report =
    let
        sourceChars =
            String.toList source

        isCovered idx =
            List.member idx report.coveredPositions

        cells =
            List.indexedMap
                (\idx ch ->
                    let
                        cellClass =
                            if isCovered idx then
                                "diff-char-covered"

                            else
                                "diff-char-uncovered"
                    in
                    span [ class ("diff-cell " ++ cellClass) ]
                        [ text (String.fromChar ch) ]
                )
                sourceChars
    in
    div [ class "diff-row" ]
        [ span [ class "diff-row-label" ] [ text "Reference" ]
        , div [ class "diff-cells" ] cells
        ]


renderContigRow : String -> Int -> ContigAlignment -> Html msg
renderContigRow source index alignment =
    let
        leadingGaps =
            List.repeat alignment.startIndex
                (span [ class "diff-cell diff-cell-gap" ] [ text "·" ])

        sourceLen =
            String.length source

        contigChars =
            String.toList alignment.contig

        contigLen =
            List.length contigChars

        trailingGapsCount =
            Basics.max 0 (sourceLen - (alignment.startIndex + contigLen))

        trailingGaps =
            List.repeat trailingGapsCount
                (span [ class "diff-cell diff-cell-gap" ] [ text "·" ])

        sourceSlice =
            String.slice
                alignment.startIndex
                (alignment.startIndex + contigLen)
                source

        contigCells =
            List.map2
                (\cChar sChar ->
                    let
                        cellClass =
                            if cChar == sChar then
                                "diff-char-match"

                            else
                                "diff-char-mismatch"
                    in
                    span [ class ("diff-cell " ++ cellClass) ]
                        [ text (String.fromChar cChar) ]
                )
                contigChars
                (String.toList sourceSlice)

        rowLabel =
            if alignment.isExact then
                "Contig " ++ String.fromInt (index + 1)

            else
                "Chimera " ++ String.fromInt (index + 1)
    in
    div [ class "diff-row" ]
        [ span [ class "diff-row-label" ] [ text rowLabel ]
        , div [ class "diff-cells" ]
            (leadingGaps ++ contigCells ++ trailingGaps)
        ]


renderUnalignedSection : List String -> Html msg
renderUnalignedSection unaligned =
    if List.isEmpty unaligned then
        text ""

    else
        div [ class "unaligned-section" ]
            [ span [ class "unaligned-title" ] [ text "Unaligned Contigs:" ]
            , div [ class "unaligned-list" ]
                (List.map
                    (\c -> span [ class "badge badge-error" ] [ text c ])
                    unaligned
                )
            ]


renderLegend : Html msg
renderLegend =
    div [ class "diff-legend" ]
        [ div [ class "legend-item" ]
            [ span [ class "legend-swatch swatch-match" ] []
            , span [] [ text "Exact Match" ]
            ]
        , div [ class "legend-item" ]
            [ span [ class "legend-swatch swatch-mismatch" ] []
            , span [] [ text "Mismatch / Error" ]
            ]
        , div [ class "legend-item" ]
            [ span [ class "legend-swatch swatch-uncovered" ] []
            , span [] [ text "Uncovered Gap" ]
            ]
        ]
