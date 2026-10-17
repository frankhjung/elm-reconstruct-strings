module StepViewTest exposing (suite)

{-| Unit tests for StepViewModel projection and narration.
-}

import Assembler
    exposing
        ( ReductionEvent(..)
        , RemovalReason(..)
        )
import Expect
import Test exposing (Test, describe, test)
import View.StepView exposing (describeRemoved, projectStepView)


suite : Test
suite =
    describe "View.StepView"
        [ describe "describeRemoved"
            [ test "formats Contained reason" <|
                \_ ->
                    let
                        item =
                            { fragment = "AA", reason = Contained }
                    in
                    describeRemoved item
                        |> Expect.equal "contained proper substring"
            , test "formats Duplicate reason" <|
                \_ ->
                    let
                        item =
                            { fragment = "AA", reason = Duplicate 2 }
                    in
                    describeRemoved item
                        |> Expect.equal "duplicate (2 removed)"
            ]
        , describe "projectStepView"
            [ test "projects InitialFiltered with no removed items" <|
                \_ ->
                    let
                        event =
                            InitialFiltered
                                { pool = [ "AAA", "BBB" ]
                                , removed = []
                                }

                        vm =
                            projectStepView [] event
                    in
                    Expect.all
                        [ \v -> Expect.equal "Initial Filtering" v.stageName
                        , \v -> Expect.equal False v.isCompleted
                        , \v -> Expect.equal Nothing v.candidate
                        , \v -> Expect.equal [] v.contigs
                        ]
                        vm
            , test "projects InitialFiltered with removed items" <|
                \_ ->
                    let
                        rem =
                            [ { fragment = "A", reason = Contained } ]

                        event =
                            InitialFiltered
                                { pool = [ "AAA" ], removed = rem }

                        vm =
                            projectStepView rem event
                    in
                    Expect.all
                        [ \v -> Expect.equal 1 (List.length v.removed)
                        , \v ->
                            Expect.equal
                                "Filtered 1 duplicate or contained fragment(s)."
                                v.narration
                        ]
                        vm
            , test "projects CandidateSelected correctly" <|
                \_ ->
                    let
                        cand =
                            { prefix = "ABC"
                            , suffix = "BCD"
                            , matchLength = 2
                            }

                        event =
                            CandidateSelected
                                { pool = [ "ABC", "BCD" ]
                                , candidate = cand
                                }

                        vm =
                            projectStepView [] event
                    in
                    Expect.all
                        [ \v -> Expect.equal "Candidate Selection" v.stageName
                        , \v -> Expect.equal (Just cand) v.candidate
                        , \v -> Expect.equal Nothing v.mergedFragment
                        ]
                        vm
            , test "projects PairMerged correctly" <|
                \_ ->
                    let
                        cand =
                            { prefix = "ABC"
                            , suffix = "BCD"
                            , matchLength = 2
                            }

                        event =
                            PairMerged
                                { pool = [ "ABCD" ]
                                , candidate = cand
                                , mergedFragment = "ABCD"
                                }

                        vm =
                            projectStepView [] event
                    in
                    Expect.all
                        [ \v -> Expect.equal "Pair Merging" v.stageName
                        , \v -> Expect.equal (Just "ABCD") v.mergedFragment
                        ]
                        vm
            , test "projects DynamicFiltered correctly" <|
                \_ ->
                    let
                        rem =
                            [ { fragment = "BC", reason = Contained } ]

                        event =
                            DynamicFiltered
                                { pool = [ "ABCD" ]
                                , mergedFragment = "ABCD"
                                , removed = rem
                                }

                        vm =
                            projectStepView rem event
                    in
                    Expect.all
                        [ \v -> Expect.equal "Dynamic Filtering" v.stageName
                        , \v -> Expect.equal (Just "ABCD") v.mergedFragment
                        , \v -> Expect.equal 1 (List.length v.removed)
                        ]
                        vm
            , test "projects AssemblyCompleted single contig" <|
                \_ ->
                    let
                        event =
                            AssemblyCompleted
                                { pool = [ "ABCD" ]
                                , contigs = [ "ABCD" ]
                                }

                        vm =
                            projectStepView [] event
                    in
                    Expect.all
                        [ \v -> Expect.equal "Assembly Completed" v.stageName
                        , \v -> Expect.equal True v.isCompleted
                        , \v -> Expect.equal [ "ABCD" ] v.contigs
                        ]
                        vm
            , test "projects AssemblyCompleted multiple contigs" <|
                \_ ->
                    let
                        event =
                            AssemblyCompleted
                                { pool = [ "ABC", "XYZ" ]
                                , contigs = [ "ABC", "XYZ" ]
                                }

                        vm =
                            projectStepView [] event
                    in
                    Expect.all
                        [ \v -> Expect.equal True v.isCompleted
                        , \v -> Expect.equal [ "ABC", "XYZ" ] v.contigs
                        ]
                        vm
            ]
        ]
