module AssemblerTest exposing (suite)

{-| Unit tests for the pure greedy OLC assembler and reduction state machine.

@docs suite

-}

import Assembler
    exposing
        ( AssemblyError(..)
        , ReductionEvent(..)
        , RemovalReason(..)
        , assembleStrings
        , calculateOverlap
        , compareCandidates
        , filterContainedFragments
        , findBestOverlap
        , isProperSubstringOf
        , mergePair
        , sortCanonical
        , startSession
        , stepSession
        , traceAssembly
        )
import Expect
import Test exposing (Test, describe, test)


{-| Test suite for Assembler module.
-}
suite : Test
suite =
    describe "Assembler"
        [ describe "Preconditions"
            [ test "rejects minOverlap < 1" <|
                \_ ->
                    assembleStrings [ "ABC", "BCD" ] 0
                        |> Expect.equal (Err (InvalidMinOverlap 0))
            , test "rejects empty fragment in pool" <|
                \_ ->
                    assembleStrings [ "ABC", "", "BCD" ] 2
                        |> Expect.equal (Err EmptyFragmentEncountered)
            ]
        , describe "Overlap calculation and tie-breaking"
            [ test "calculates exact suffix-prefix overlap" <|
                \_ ->
                    calculateOverlap "ABCDE" "CDEFG" 2
                        |> Expect.equal (Just 3)
            , test "returns Nothing when overlap is below threshold" <|
                \_ ->
                    calculateOverlap "ABCDE" "EFGHI" 3
                        |> Expect.equal Nothing
            , test "rejects full containment inside calculateOverlap" <|
                \_ ->
                    calculateOverlap "ABC" "ABC" 2
                        |> Expect.equal Nothing
            , test "tie-breaking prioritises longer matchLength" <|
                \_ ->
                    let
                        c1 =
                            { prefix = "AAA", suffix = "AAB", matchLength = 3 }

                        c2 =
                            { prefix = "AAA", suffix = "AAC", matchLength = 2 }
                    in
                    compareCandidates c1 c2
                        |> Expect.equal LT
            , test "tie-breaking prioritises smaller prefix" <|
                \_ ->
                    let
                        c1 =
                            { prefix = "ABC", suffix = "CDE", matchLength = 2 }

                        c2 =
                            { prefix = "BBC", suffix = "CDE", matchLength = 2 }
                    in
                    compareCandidates c1 c2
                        |> Expect.equal LT
            , test "findBestOverlap selects optimal candidate" <|
                \_ ->
                    findBestOverlap [ "ATGGC", "GGCGT", "CGTGCA" ] 2
                        |> Expect.equal
                            (Just
                                { prefix = "ATGGC"
                                , suffix = "GGCGT"
                                , matchLength = 3
                                }
                            )
            ]
        , describe "Containment and duplicate filtering"
            [ test "isProperSubstringOf tests strict containment" <|
                \_ ->
                    Expect.all
                        [ \_ ->
                            isProperSubstringOf "BCD" "ABCDE"
                                |> Expect.equal True
                        , \_ ->
                            isProperSubstringOf "ABC" "ABC"
                                |> Expect.equal False
                        , \_ ->
                            isProperSubstringOf "XYZ" "ABC"
                                |> Expect.equal False
                        ]
                        ()
            , test "filterContainedFragments purges substrings" <|
                \_ ->
                    let
                        input =
                            [ "ABCDE", "BCD", "ABCDE", "XYZ" ]

                        filtered =
                            filterContainedFragments input
                    in
                    Expect.all
                        [ \_ ->
                            filtered.kept
                                |> Expect.equal [ "ABCDE", "XYZ" ]
                        , \_ ->
                            filtered.removed
                                |> Expect.equal
                                    [ { fragment = "ABCDE"
                                      , reason = Duplicate 1
                                      }
                                    , { fragment = "BCD"
                                      , reason = Contained
                                      }
                                    ]
                        ]
                        ()
            ]
        , describe "Reduction and Assembly Examples"
            [ test "Example A: simple linear overlaps" <|
                \_ ->
                    assembleStrings [ "ABC", "BCD", "CDE" ] 2
                        |> Expect.equal (Ok [ "ABCDE" ])
            , test "Example B: toy DNA sequence" <|
                \_ ->
                    assembleStrings [ "ATGGC", "GGCGT", "CGTGCA" ] 2
                        |> Expect.equal (Ok [ "ATGGCGTGCA" ])
            , test "Example C: disjoint fragments" <|
                \_ ->
                    assembleStrings [ "ABC", "XYZ" ] 2
                        |> Expect.equal (Ok [ "ABC", "XYZ" ])
            , test "Example D: alphabet sequence" <|
                \_ ->
                    assembleStrings
                        [ "ABCDE", "CDEFG", "EFGHI", "GHIJK" ]
                        2
                        |> Expect.equal (Ok [ "ABCDEFGHIJK" ])
            , test "Example E: duplicates and contained fragments" <|
                \_ ->
                    assembleStrings
                        [ "ABCDE", "BCD", "ABCDE", "CDEFG" ]
                        2
                        |> Expect.equal (Ok [ "ABCDEFG" ])
            , test "mergePair merges prefix and suffix at matchLength" <|
                \_ ->
                    mergePair
                        { prefix = "ATGGC"
                        , suffix = "GGCGT"
                        , matchLength = 3
                        }
                        |> Expect.equal "ATGGCGT"
            , test "sortCanonical orders by length then ASCII" <|
                \_ ->
                    sortCanonical [ "A", "BB", "AA", "CCC" ]
                        |> Expect.equal [ "CCC", "AA", "BB", "A" ]
            ]
        , describe "Stepwise Session Transitions"
            [ test "session advances across all discrete stages" <|
                \_ ->
                    case startSession [ "ABC", "BCD" ] 2 of
                        Err _ ->
                            Expect.fail "Expected startSession to succeed"

                        Ok s0 ->
                            let
                                ( s1, e1 ) =
                                    stepSession s0

                                ( s2, e2 ) =
                                    stepSession s1

                                ( s3, e3 ) =
                                    stepSession s2

                                ( _, e4 ) =
                                    stepSession s3
                            in
                            Expect.all
                                [ \_ ->
                                    case e1 of
                                        InitialFiltered d ->
                                            d.pool
                                                |> Expect.equal [ "ABC", "BCD" ]

                                        _ ->
                                            Expect.fail "Not InitialFiltered"
                                , \_ ->
                                    case e2 of
                                        CandidateSelected d ->
                                            d.candidate.matchLength
                                                |> Expect.equal 2

                                        _ ->
                                            Expect.fail "Not CandidateSelected"
                                , \_ ->
                                    case e3 of
                                        PairMerged d ->
                                            d.mergedFragment
                                                |> Expect.equal "ABCD"

                                        _ ->
                                            Expect.fail "Not PairMerged"
                                , \_ ->
                                    case e4 of
                                        AssemblyCompleted d ->
                                            d.contigs
                                                |> Expect.equal [ "ABCD" ]

                                        _ ->
                                            Expect.fail "Not AssemblyCompleted"
                                ]
                                ()
            , test "traceAssembly contigs match assembleStrings" <|
                \_ ->
                    case traceAssembly [ "ATGGC", "GGCGT", "CGTGCA" ] 2 of
                        Ok evts ->
                            let
                                lastEvt =
                                    List.reverse evts |> List.head
                            in
                            case lastEvt of
                                Just (AssemblyCompleted d) ->
                                    d.contigs
                                        |> Expect.equal [ "ATGGCGTGCA" ]

                                _ ->
                                    Expect.fail "Not AssemblyCompleted"

                        Err _ ->
                            Expect.fail "Expected traceAssembly to succeed"
            ]
        ]
