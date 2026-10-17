module AlignmentTest exposing (suite)

{-| Unit tests for reference alignment, window search, and coverage diagnostics.

@docs suite

-}

import Alignment
    exposing
        ( DiagnosticStatus(..)
        , alignContigsToSource
        , calculateSpans
        , findAllOccurrences
        , findBestWindow
        )
import Expect
import Test exposing (Test, describe, test)


{-| Test suite for Alignment module.
-}
suite : Test
suite =
    describe "Alignment"
        [ describe "findAllOccurrences"
            [ test "returns empty list for empty needle" <|
                \_ ->
                    findAllOccurrences "" "ATGGCGTGCA"
                        |> Expect.equal []
            , test "finds multiple start indices of needle" <|
                \_ ->
                    findAllOccurrences "GC" "ATGGCGTGCA"
                        |> Expect.equal [ 3, 7 ]
            , test "returns empty list when needle is absent" <|
                \_ ->
                    findAllOccurrences "ZZZ" "ATGGCGTGCA"
                        |> Expect.equal []
            ]
        , describe "findBestWindow"
            [ test "identifies exact window occurrence" <|
                \_ ->
                    let
                        match =
                            findBestWindow "GCGT" "ATGGCGTGCA"
                    in
                    Expect.all
                        [ \_ -> match.startIndex |> Expect.equal 3
                        , \_ -> match.matchCount |> Expect.equal 4
                        ]
                        ()
            , test "finds optimal sliding window with maximum matches" <|
                \_ ->
                    let
                        match =
                            findBestWindow "GCGZ" "ATGGCGTGCA"
                    in
                    Expect.all
                        [ \_ -> match.startIndex |> Expect.equal 3
                        , \_ -> match.matchCount |> Expect.equal 3
                        ]
                        ()
            ]
        , describe "calculateSpans"
            [ test "partitions boolean flags into contiguous intervals" <|
                \_ ->
                    let
                        flags =
                            [ True, True, False, False, True ]

                        spans =
                            calculateSpans flags
                    in
                    Expect.all
                        [ \_ ->
                            spans.coveredSpans
                                |> Expect.equal
                                    [ { start = 0, end = 2 }
                                    , { start = 4, end = 5 }
                                    ]
                        , \_ ->
                            spans.uncoveredSpans
                                |> Expect.equal [ { start = 2, end = 4 } ]
                        ]
                        ()
            ]
        , describe "alignContigsToSource diagnostics"
            [ test "classifies PerfectReconstruction on 100% exact match" <|
                \_ ->
                    let
                        report =
                            alignContigsToSource "ATGGCGTGCA" [ "ATGGCGTGCA" ]
                    in
                    Expect.all
                        [ \_ ->
                            report.diagnosticStatus
                                |> Expect.equal PerfectReconstruction
                        , \_ ->
                            report.coveragePercent
                                |> Expect.within (Expect.Absolute 0.01) 100.0
                        , \_ ->
                            report.uncoveredSpans
                                |> Expect.equal []
                        ]
                        ()
            , test "classifies PartialAssembly when coverage < 100%" <|
                \_ ->
                    let
                        report =
                            alignContigsToSource "ATGGCGTGCA" [ "ATGGC" ]
                    in
                    Expect.all
                        [ \_ ->
                            report.diagnosticStatus
                                |> Expect.equal PartialAssembly
                        , \_ ->
                            report.coveragePercent
                                |> Expect.within (Expect.Absolute 0.01) 50.0
                        ]
                        ()
            , test "classifies FragmentedAssembly for multiple exact contigs" <|
                \_ ->
                    let
                        report =
                            alignContigsToSource
                                "ATGGCGTGCA"
                                [ "ATGGC", "GTGCA" ]
                    in
                    report.diagnosticStatus
                        |> Expect.equal FragmentedAssembly
            , test "flags MisassemblyDetected when contig has mismatches" <|
                \_ ->
                    let
                        report =
                            alignContigsToSource "ATGGCGTGCA" [ "ATGAC" ]
                    in
                    report.diagnosticStatus
                        |> Expect.equal MisassemblyDetected
            ]
        ]
