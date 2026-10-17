module AssemblerPropertyTest exposing (suite)

{-| Property-based fuzz tests verifying OLC greedy assembly invariants.

@docs suite

-}

import Assembler
    exposing
        ( ReductionEvent(..)
        , assembleStrings
        , isProperSubstringOf
        , sortCanonical
        , traceAssembly
        )
import Expect
import Fuzz exposing (Fuzzer, intRange, list)
import Test exposing (Test, describe, fuzz2)


dnaFuzzer : Fuzzer String
dnaFuzzer =
    Fuzz.map
        (\chars ->
            if List.isEmpty chars then
                "ACGT"

            else
                String.fromList chars
        )
        (list
            (Fuzz.oneOf
                [ Fuzz.constant 'A'
                , Fuzz.constant 'C'
                , Fuzz.constant 'G'
                , Fuzz.constant 'T'
                ]
            )
        )


fragmentPoolFuzzer : Fuzzer (List String)
fragmentPoolFuzzer =
    Fuzz.map
        (\frags ->
            frags
                |> List.filter (\s -> String.length s >= 2)
                |> (\clean ->
                        if List.isEmpty clean then
                            [ "ACGT", "CGTA" ]

                        else
                            clean
                   )
        )
        (list dnaFuzzer)


{-| Suite of fuzz property tests for Assembler invariants.
-}
suite : Test
suite =
    describe "Assembler Properties"
        [ fuzz2
            fragmentPoolFuzzer
            (intRange 1 5)
            "idempotence: assembling contigs produces same contigs"
          <|
            \pool minOverlap ->
                case assembleStrings pool minOverlap of
                    Ok contigs ->
                        case assembleStrings contigs minOverlap of
                            Ok reassembled ->
                                reassembled
                                    |> Expect.equal contigs

                            Err _ ->
                                Expect.fail "Reassembly should not fail"

                    Err _ ->
                        Expect.pass
        , fuzz2
            fragmentPoolFuzzer
            (intRange 1 5)
            "containment-free: no output contig is proper substring of another"
          <|
            \pool minOverlap ->
                case assembleStrings pool minOverlap of
                    Ok contigs ->
                        let
                            hasContainment =
                                contigs
                                    |> List.any
                                        (\c1 ->
                                            contigs
                                                |> List.any
                                                    (\c2 ->
                                                        isProperSubstringOf
                                                            c1
                                                            c2
                                                    )
                                        )
                        in
                        hasContainment
                            |> Expect.equal False

                    Err _ ->
                        Expect.pass
        , fuzz2
            fragmentPoolFuzzer
            (intRange 1 5)
            "preservation: all input fragments are substrings of output contigs"
          <|
            \pool minOverlap ->
                case assembleStrings pool minOverlap of
                    Ok contigs ->
                        let
                            allPreserved =
                                pool
                                    |> List.all
                                        (\frag ->
                                            contigs
                                                |> List.any
                                                    (\contig ->
                                                        String.contains
                                                            frag
                                                            contig
                                                    )
                                        )
                        in
                        allPreserved
                            |> Expect.equal True

                    Err _ ->
                        Expect.pass
        , fuzz2
            fragmentPoolFuzzer
            (intRange 1 5)
            "canonical order: contigs are sorted by length desc then ASCII asc"
          <|
            \pool minOverlap ->
                case assembleStrings pool minOverlap of
                    Ok contigs ->
                        let
                            sorted =
                                sortCanonical contigs
                        in
                        contigs
                            |> Expect.equal sorted

                    Err _ ->
                        Expect.pass
        , fuzz2
            fragmentPoolFuzzer
            (intRange 1 5)
            "trace equivalence: trace contigs match assembleStrings"
          <|
            \pool minOverlap ->
                case
                    ( assembleStrings pool minOverlap
                    , traceAssembly pool minOverlap
                    )
                of
                    ( Ok batchContigs, Ok evts ) ->
                        let
                            lastEvt =
                                List.reverse evts |> List.head
                        in
                        case lastEvt of
                            Just (AssemblyCompleted d) ->
                                d.contigs
                                    |> Expect.equal batchContigs

                            _ ->
                                Expect.fail "Expected AssemblyCompleted"

                    ( Err e1, Err e2 ) ->
                        e1
                            |> Expect.equal e2

                    _ ->
                        Expect.fail "Mismatched Ok/Err results"
        ]
