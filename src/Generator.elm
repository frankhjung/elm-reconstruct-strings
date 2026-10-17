module Generator exposing
    ( GeneratorParams, RawParamsInput, ValidationError(..)
    , errorToString, validateParams, validateRawParams, parseFragments
    , validateCustomPool, fragmentsGenerator, generateWithSeed
    )

{-| Random fragment generator, bounds validation, and pool parsing.

@docs GeneratorParams, RawParamsInput, ValidationError
@docs errorToString, validateParams, validateRawParams, parseFragments
@docs validateCustomPool, fragmentsGenerator, generateWithSeed

-}

import Assembler exposing (AssemblyError)
import Random
import Validation exposing (Validation, andMap, fail, succeed)


{-| Maximum permitted ground-truth source sequence length.
-}
maxSourceLength : Int
maxSourceLength =
    10000


{-| Maximum permitted number of synthetic fragments to generate.
-}
maxFragmentCount : Int
maxFragmentCount =
    500


{-| Minimum overlap threshold allowed in the generator UI.
-}
minOverlapThreshold : Int
minOverlapThreshold =
    2


{-| Validated generator parameters.
-}
type alias GeneratorParams =
    { source : String
    , minOverlap : Int
    , minLength : Int
    , maxLength : Int
    , fragmentCount : Int
    }


{-| Raw form string inputs for generator parameters.
-}
type alias RawParamsInput =
    { source : String
    , minOverlap : String
    , minLength : String
    , maxLength : String
    , fragmentCount : String
    }


{-| Validation error variants for parameter and pool constraints.
-}
type ValidationError
    = EmptySource
    | SourceTooLong Int
    | InvalidMinOverlapParam Int
    | InvalidMinLength Int
    | MaxLengthBelowMinLength { minLength : Int, maxLength : Int }
    | MinLengthExceedsSource { minLength : Int, sourceLength : Int }
    | InvalidFragmentCount Int
    | FragmentCountTooLarge Int
    | EmptyFragmentPool
    | EmptyFragmentInPool
    | InvalidNumberField String String
    | AssemblyPrecondition AssemblyError


{-| Format validation errors into user-facing Australian English strings.
-}
errorToString : ValidationError -> String
errorToString err =
    case err of
        AssemblyPrecondition asmErr ->
            Assembler.errorToString asmErr

        EmptySource ->
            "Source sequence cannot be empty."

        SourceTooLong len ->
            "Source length ("
                ++ String.fromInt len
                ++ ") exceeds maximum permitted length ("
                ++ String.fromInt maxSourceLength
                ++ ")."

        InvalidMinOverlapParam n ->
            "Minimum overlap ("
                ++ String.fromInt n
                ++ ") must be at least "
                ++ String.fromInt minOverlapThreshold
                ++ "."

        InvalidMinLength a ->
            "Minimum fragment length ("
                ++ String.fromInt a
                ++ ") must be at least 2."

        MaxLengthBelowMinLength { minLength, maxLength } ->
            "Maximum fragment length ("
                ++ String.fromInt maxLength
                ++ ") cannot be smaller than minimum length ("
                ++ String.fromInt minLength
                ++ ")."

        MinLengthExceedsSource { minLength, sourceLength } ->
            "Minimum fragment length ("
                ++ String.fromInt minLength
                ++ ") exceeds source sequence length ("
                ++ String.fromInt sourceLength
                ++ ")."

        InvalidFragmentCount m ->
            "Fragment count ("
                ++ String.fromInt m
                ++ ") must be at least 2."

        FragmentCountTooLarge m ->
            "Fragment count ("
                ++ String.fromInt m
                ++ ") exceeds maximum permitted limit ("
                ++ String.fromInt maxFragmentCount
                ++ ")."

        EmptyFragmentPool ->
            "Fragment pool contains no valid fragments."

        EmptyFragmentInPool ->
            "Fragment pool contains an empty fragment."

        InvalidNumberField name val ->
            "Field '" ++ name ++ "' contains invalid number '" ++ val ++ "'."


{-| Validate pre-parsed GeneratorParams.
-}
validateParams :
    GeneratorParams
    -> Validation ValidationError GeneratorParams
validateParams params =
    let
        sourceLen =
            String.length params.source

        vSource =
            if String.isEmpty params.source then
                fail EmptySource

            else if sourceLen > maxSourceLength then
                fail (SourceTooLong sourceLen)

            else
                succeed params.source

        vOverlap =
            if params.minOverlap < minOverlapThreshold then
                fail (InvalidMinOverlapParam params.minOverlap)

            else
                succeed params.minOverlap

        vMinLen =
            if params.minLength < 2 then
                fail (InvalidMinLength params.minLength)

            else if params.minLength > sourceLen && sourceLen > 0 then
                fail
                    (MinLengthExceedsSource
                        { minLength = params.minLength
                        , sourceLength = sourceLen
                        }
                    )

            else
                succeed params.minLength

        vMaxLen =
            if params.maxLength < params.minLength then
                fail
                    (MaxLengthBelowMinLength
                        { minLength = params.minLength
                        , maxLength = params.maxLength
                        }
                    )

            else
                succeed params.maxLength

        vCount =
            if params.fragmentCount < 2 then
                fail (InvalidFragmentCount params.fragmentCount)

            else if params.fragmentCount > maxFragmentCount then
                fail (FragmentCountTooLarge params.fragmentCount)

            else
                succeed params.fragmentCount
    in
    succeed GeneratorParams
        |> andMap vSource
        |> andMap vOverlap
        |> andMap vMinLen
        |> andMap vMaxLen
        |> andMap vCount


{-| Validate raw string form inputs into GeneratorParams.
-}
validateRawParams :
    RawParamsInput
    -> Validation ValidationError GeneratorParams
validateRawParams raw =
    let
        sourceTrimmed =
            String.trim raw.source

        sourceLen =
            String.length sourceTrimmed

        vSource =
            if String.isEmpty sourceTrimmed then
                fail EmptySource

            else if sourceLen > maxSourceLength then
                fail (SourceTooLong sourceLen)

            else
                succeed sourceTrimmed

        parseInt fieldName rawVal =
            case String.toInt (String.trim rawVal) of
                Just n ->
                    succeed n

                Nothing ->
                    fail (InvalidNumberField fieldName rawVal)

        vOverlap =
            parseInt "Minimum Overlap (n)" raw.minOverlap
                |> Result.andThen
                    (\n ->
                        if n < minOverlapThreshold then
                            fail (InvalidMinOverlapParam n)

                        else
                            succeed n
                    )

        vMinLen =
            parseInt "Minimum Length (a)" raw.minLength
                |> Result.andThen
                    (\a ->
                        if a < 2 then
                            fail (InvalidMinLength a)

                        else if a > sourceLen && sourceLen > 0 then
                            fail
                                (MinLengthExceedsSource
                                    { minLength = a
                                    , sourceLength = sourceLen
                                    }
                                )

                        else
                            succeed a
                    )

        vMaxLen =
            parseInt "Maximum Length (b)" raw.maxLength

        vCount =
            parseInt "Fragment Count (m)" raw.fragmentCount
                |> Result.andThen
                    (\m ->
                        if m < 2 then
                            fail (InvalidFragmentCount m)

                        else if m > maxFragmentCount then
                            fail (FragmentCountTooLarge m)

                        else
                            succeed m
                    )

        checkMaxAgainstMin parsedMin parsedMax =
            if parsedMax < parsedMin then
                fail
                    (MaxLengthBelowMinLength
                        { minLength = parsedMin
                        , maxLength = parsedMax
                        }
                    )

            else
                succeed parsedMax

        combinedLengths =
            case ( vMinLen, vMaxLen ) of
                ( Ok minL, Ok maxL ) ->
                    checkMaxAgainstMin minL maxL
                        |> Result.map (\_ -> ( minL, maxL ))

                ( Err e1, Err e2 ) ->
                    Err (e1 ++ e2)

                ( Err e, Ok _ ) ->
                    Err e

                ( Ok _, Err e ) ->
                    Err e
    in
    case combinedLengths of
        Ok ( minL, maxL ) ->
            succeed (\src ovl cnt -> GeneratorParams src ovl minL maxL cnt)
                |> andMap vSource
                |> andMap vOverlap
                |> andMap vCount

        Err lenErrors ->
            let
                otherErrors =
                    case ( vSource, vOverlap, vCount ) of
                        ( Ok _, Ok _, Ok _ ) ->
                            []

                        ( Err e1, Ok _, Ok _ ) ->
                            e1

                        ( Ok _, Err e2, Ok _ ) ->
                            e2

                        ( Ok _, Ok _, Err e3 ) ->
                            e3

                        ( Err e1, Err e2, Ok _ ) ->
                            e1 ++ e2

                        ( Err e1, Ok _, Err e3 ) ->
                            e1 ++ e3

                        ( Ok _, Err e2, Err e3 ) ->
                            e2 ++ e3

                        ( Err e1, Err e2, Err e3 ) ->
                            e1 ++ e2 ++ e3
            in
            Err (otherErrors ++ lenErrors)


{-| Split newline and comma delimited fragment inputs.
-}
parseFragments : String -> List String
parseFragments raw =
    raw
        |> String.replace "," "\n"
        |> String.lines
        |> List.map String.trim
        |> List.filter (\s -> not (String.isEmpty s))


{-| Validate parsed custom fragment pool.
-}
validateCustomPool :
    String
    -> Validation ValidationError (List String)
validateCustomPool raw =
    let
        fragments =
            parseFragments raw
    in
    if List.isEmpty fragments then
        fail EmptyFragmentPool

    else if List.any (\f -> f == "") fragments then
        fail EmptyFragmentInPool

    else
        succeed fragments


{-| Pure generator for a single fragment from source sequence.
-}
singleFragmentGenerator : GeneratorParams -> Random.Generator String
singleFragmentGenerator params =
    let
        sourceLen =
            String.length params.source

        effectiveMax =
            min params.maxLength sourceLen
    in
    Random.int params.minLength effectiveMax
        |> Random.andThen
            (\len ->
                Random.int 0 (sourceLen - len)
                    |> Random.map
                        (\offset ->
                            String.slice offset (offset + len) params.source
                        )
            )


{-| Generator for a list of synthetic random fragments.
-}
fragmentsGenerator : GeneratorParams -> Random.Generator (List String)
fragmentsGenerator params =
    Random.list params.fragmentCount (singleFragmentGenerator params)


{-| Sample fragments with a deterministic pseudo-random seed.
-}
generateWithSeed :
    GeneratorParams
    -> Random.Seed
    -> ( List String, Random.Seed )
generateWithSeed params seed =
    Random.step (fragmentsGenerator params) seed
