module GeneratorTest exposing (suite)

{-| Unit and property tests for generator parameters, validation, and sampling.

@docs suite

-}

import Expect
import Fuzz exposing (intRange)
import Generator
    exposing
        ( GeneratorParams
        , ValidationError(..)
        , generateWithSeed
        , parseFragments
        , validateCustomPool
        , validateParams
        , validateRawParams
        )
import Random
import Test exposing (Test, describe, fuzz, test)
import View.Controls exposing (delayToSlider, sliderToDelay)


validParams : GeneratorParams
validParams =
    { source = "ATGGCGTGCA"
    , minOverlap = 2
    , minLength = 3
    , maxLength = 6
    , fragmentCount = 5
    }


{-| Test suite for Generator module.
-}
suite : Test
suite =
    describe "Generator"
        [ describe "validateParams"
            [ test "succeeds for valid parameters" <|
                \_ ->
                    validateParams validParams
                        |> Expect.equal (Ok validParams)
            , test "rejects empty source" <|
                \_ ->
                    validateParams { validParams | source = "" }
                        |> Expect.equal (Err [ EmptySource ])
            , test "rejects minOverlap < 2" <|
                \_ ->
                    validateParams { validParams | minOverlap = 1 }
                        |> Expect.equal (Err [ InvalidMinOverlapParam 1 ])
            , test "rejects minLength < 2" <|
                \_ ->
                    validateParams { validParams | minLength = 1 }
                        |> Expect.equal (Err [ InvalidMinLength 1 ])
            , test "rejects maxLength < minLength" <|
                \_ ->
                    validateParams
                        { validParams | minLength = 5, maxLength = 4 }
                        |> Expect.equal
                            (Err
                                [ MaxLengthBelowMinLength
                                    { minLength = 5, maxLength = 4 }
                                ]
                            )
            , test "rejects minLength exceeding source length" <|
                \_ ->
                    validateParams
                        { validParams
                            | source = "ABCD"
                            , minLength = 5
                            , maxLength = 6
                        }
                        |> Expect.equal
                            (Err
                                [ MinLengthExceedsSource
                                    { minLength = 5, sourceLength = 4 }
                                ]
                            )
            ]
        , describe "validateRawParams"
            [ test "parses valid raw form inputs" <|
                \_ ->
                    let
                        raw =
                            { source = "ATGGCGTGCA"
                            , minOverlap = "2"
                            , minLength = "3"
                            , maxLength = "6"
                            , fragmentCount = "5"
                            }
                    in
                    validateRawParams raw
                        |> Expect.equal (Ok validParams)
            , test "reports invalid numeric field errors" <|
                \_ ->
                    let
                        raw =
                            { source = "ATGGCGTGCA"
                            , minOverlap = "abc"
                            , minLength = "3"
                            , maxLength = "6"
                            , fragmentCount = "5"
                            }
                    in
                    case validateRawParams raw of
                        Err errs ->
                            List.member
                                (InvalidNumberField
                                    "Minimum Overlap (n)"
                                    "abc"
                                )
                                errs
                                |> Expect.equal True

                        Ok _ ->
                            Expect.fail "Expected validation failure"
            ]
        , describe "parseFragments and validateCustomPool"
            [ test "parseFragments handles commas and newlines" <|
                \_ ->
                    parseFragments "ABC, BCD\nCDE,  "
                        |> Expect.equal [ "ABC", "BCD", "CDE" ]
            , test "validateCustomPool rejects empty pool" <|
                \_ ->
                    validateCustomPool "   \n , "
                        |> Expect.equal (Err [ EmptyFragmentPool ])
            ]
        , describe "Slider and Delay roundtrip"
            [ fuzz (intRange 1 10) "delayToSlider inverses sliderToDelay" <|
                \sliderVal ->
                    delayToSlider (sliderToDelay sliderVal)
                        |> Expect.equal sliderVal
            ]
        , describe "Deterministic sampling"
            [ test "sampled fragments are valid substrings of source" <|
                \_ ->
                    let
                        seed =
                            Random.initialSeed 42

                        ( frags, _ ) =
                            generateWithSeed validParams seed
                    in
                    Expect.all
                        [ \_ ->
                            List.length frags
                                |> Expect.equal validParams.fragmentCount
                        , \_ ->
                            List.all
                                (\f ->
                                    String.length f
                                        >= validParams.minLength
                                        && String.length f
                                        <= validParams.maxLength
                                        && String.contains f validParams.source
                                )
                                frags
                                |> Expect.equal True
                        ]
                        ()
            ]
        ]
