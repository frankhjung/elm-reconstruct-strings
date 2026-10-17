module Alignment exposing
    ( DiagnosticStatus(..), Span, WindowMatch, ContigAlignment, AlignmentReport
    , findAllOccurrences, findBestWindow, calculateSpans, alignContigsToSource
    , calculateFragmentCoverage
    )

{-| Pure reference alignment, interval mathematics, and coverage diagnostics.

@docs DiagnosticStatus, Span, WindowMatch, ContigAlignment, AlignmentReport
@docs findAllOccurrences, findBestWindow, calculateSpans, alignContigsToSource
@docs calculateFragmentCoverage

-}

import Set


{-| Domain classification of the assembly reconstruction outcome.
-}
type DiagnosticStatus
    = InProgress
    | PerfectReconstruction
    | PartialAssembly
    | FragmentedAssembly
    | MisassemblyDetected


{-| Half-open interval [start, end) representing a continuous index span.
-}
type alias Span =
    { start : Int
    , end : Int
    }


{-| Best matching window position and character match count.
-}
type alias WindowMatch =
    { startIndex : Int
    , matchCount : Int
    }


{-| Detailed alignment mapping for an individual contig against source.
-}
type alias ContigAlignment =
    { contig : String
    , startIndex : Int
    , matchCount : Int
    , isExact : Bool
    }


{-| Complete reference alignment report across all contigs.
-}
type alias AlignmentReport =
    { alignments : List ContigAlignment
    , unalignedContigs : List String
    , coveredPositions : List Int
    , coveragePercent : Float
    , coveredSpans : List Span
    , uncoveredSpans : List Span
    , diagnosticStatus : DiagnosticStatus
    }


{-| Find all occurrence indices of needle in haystack safely.
-}
findAllOccurrences : String -> String -> List Int
findAllOccurrences needle haystack =
    if String.isEmpty needle then
        []

    else
        String.indexes needle haystack


{-| Find optimal alignment window for a contig across candidate offsets.
-}
findBestWindow : String -> String -> WindowMatch
findBestWindow contig source =
    let
        contigLen =
            String.length contig

        sourceLen =
            String.length source

        exactMatches =
            findAllOccurrences contig source
    in
    case exactMatches of
        firstIdx :: _ ->
            { startIndex = firstIdx, matchCount = contigLen }

        [] ->
            if contigLen == 0 || sourceLen == 0 then
                { startIndex = 0, matchCount = 0 }

            else
                let
                    maxOffset =
                        max 0 (sourceLen - contigLen)

                    offsets =
                        List.range 0 maxOffset

                    scoreOffset offset =
                        let
                            sourceSlice =
                                String.slice offset (offset + contigLen) source

                            matches =
                                List.map2 (==)
                                    (String.toList contig)
                                    (String.toList sourceSlice)
                                    |> List.filter (\b -> b)
                                    |> List.length
                        in
                        { startIndex = offset, matchCount = matches }

                    allMatches =
                        List.map scoreOffset offsets
                in
                case allMatches of
                    [] ->
                        { startIndex = 0, matchCount = 0 }

                    first :: rest ->
                        List.foldl
                            (\m acc ->
                                if m.matchCount > acc.matchCount then
                                    m

                                else
                                    acc
                            )
                            first
                            rest


{-| Fold boolean coverage flags into contiguous half-open interval spans.
-}
calculateSpans :
    List Bool
    -> { coveredSpans : List Span, uncoveredSpans : List Span }
calculateSpans flags =
    let
        step ( idx, isCovered ) state =
            case state.current of
                Nothing ->
                    { state
                        | current =
                            Just
                                { isCovered = isCovered
                                , start = idx
                                , end = idx + 1
                                }
                    }

                Just cur ->
                    if cur.isCovered == isCovered then
                        { state | current = Just { cur | end = idx + 1 } }

                    else
                        let
                            finishedSpan =
                                { start = cur.start, end = cur.end }
                        in
                        if cur.isCovered then
                            { covered = state.covered ++ [ finishedSpan ]
                            , uncovered = state.uncovered
                            , current =
                                Just
                                    { isCovered = isCovered
                                    , start = idx
                                    , end = idx + 1
                                    }
                            }

                        else
                            { covered = state.covered
                            , uncovered = state.uncovered ++ [ finishedSpan ]
                            , current =
                                Just
                                    { isCovered = isCovered
                                    , start = idx
                                    , end = idx + 1
                                    }
                            }

        indexedFlags =
            List.indexedMap (\idx b -> ( idx, b )) flags

        initialState =
            { covered = []
            , uncovered = []
            , current = Nothing
            }

        finalState =
            List.foldl step initialState indexedFlags

        ( finalCovered, finalUncovered ) =
            case finalState.current of
                Nothing ->
                    ( finalState.covered, finalState.uncovered )

                Just cur ->
                    let
                        lastSpan =
                            { start = cur.start, end = cur.end }
                    in
                    if cur.isCovered then
                        ( finalState.covered ++ [ lastSpan ]
                        , finalState.uncovered
                        )

                    else
                        ( finalState.covered
                        , finalState.uncovered ++ [ lastSpan ]
                        )
    in
    { coveredSpans = finalCovered
    , uncoveredSpans = finalUncovered
    }


{-| Align contigs against reference ground truth and compute diagnostic metrics.
-}
alignContigsToSource : String -> List String -> AlignmentReport
alignContigsToSource source contigs =
    let
        sourceLen =
            String.length source

        alignContig contig ( accAlignments, accUnaligned, accCoveredSet ) =
            let
                contigLen =
                    String.length contig

                exactIndices =
                    findAllOccurrences contig source
            in
            if not (List.isEmpty exactIndices) then
                let
                    scoreIdx idx =
                        let
                            newPositions =
                                List.range idx (idx + contigLen - 1)
                                    |> List.filter
                                        (\p -> not (Set.member p accCoveredSet))
                                    |> List.length
                        in
                        ( idx, newPositions )

                    bestIdx =
                        exactIndices
                            |> List.map scoreIdx
                            |> List.sortWith
                                (\( _, s1 ) ( _, s2 ) -> compare s2 s1)
                            |> List.head
                            |> Maybe.map Tuple.first
                            |> Maybe.withDefault 0

                    coveredIndices =
                        List.range bestIdx (bestIdx + contigLen - 1)

                    newSet =
                        List.foldl Set.insert accCoveredSet coveredIndices

                    alignment =
                        { contig = contig
                        , startIndex = bestIdx
                        , matchCount = contigLen
                        , isExact = True
                        }
                in
                ( accAlignments ++ [ alignment ]
                , accUnaligned
                , newSet
                )

            else
                let
                    bestWindow =
                        findBestWindow contig source

                    minThreshold =
                        contigLen // 2
                in
                if bestWindow.matchCount >= minThreshold && contigLen > 0 then
                    let
                        sourceSlice =
                            String.slice
                                bestWindow.startIndex
                                (bestWindow.startIndex + contigLen)
                                source

                        matchingPositions =
                            List.map2
                                (\charContig ( charSource, pos ) ->
                                    if charContig == charSource then
                                        Just pos

                                    else
                                        Nothing
                                )
                                (String.toList contig)
                                (List.map2 Tuple.pair
                                    (String.toList sourceSlice)
                                    (List.range
                                        bestWindow.startIndex
                                        (bestWindow.startIndex + contigLen - 1)
                                    )
                                )
                                |> List.filterMap identity

                        newSet =
                            List.foldl
                                Set.insert
                                accCoveredSet
                                matchingPositions

                        alignment =
                            { contig = contig
                            , startIndex = bestWindow.startIndex
                            , matchCount = bestWindow.matchCount
                            , isExact = False
                            }
                    in
                    ( accAlignments ++ [ alignment ]
                    , accUnaligned
                    , newSet
                    )

                else
                    ( accAlignments
                    , accUnaligned ++ [ contig ]
                    , accCoveredSet
                    )

        ( alignments, unaligned, coveredSet ) =
            List.foldl alignContig ( [], [], Set.empty ) contigs

        coveredPositions =
            Set.toList coveredSet |> List.sort

        coveragePercent =
            if sourceLen == 0 then
                0.0

            else
                (toFloat (List.length coveredPositions) / toFloat sourceLen)
                    * 100.0

        flags =
            List.range 0 (sourceLen - 1)
                |> List.map (\idx -> Set.member idx coveredSet)

        spans =
            calculateSpans flags

        diagnostic =
            if not (List.isEmpty unaligned) then
                MisassemblyDetected

            else if List.any (\a -> not a.isExact) alignments then
                MisassemblyDetected

            else if List.length alignments > 1 then
                FragmentedAssembly

            else if List.length alignments == 1 then
                if
                    (List.length coveredPositions == sourceLen)
                        && (sourceLen > 0)
                then
                    PerfectReconstruction

                else
                    PartialAssembly

            else
                PartialAssembly
    in
    { alignments = alignments
    , unalignedContigs = unaligned
    , coveredPositions = coveredPositions
    , coveragePercent = coveragePercent
    , coveredSpans = spans.coveredSpans
    , uncoveredSpans = spans.uncoveredSpans
    , diagnosticStatus = diagnostic
    }


{-| Calculate reference sequence coverage provided by a pool of fragments.
-}
calculateFragmentCoverage : String -> List String -> AlignmentReport
calculateFragmentCoverage source fragments =
    let
        sourceLen =
            String.length source

        coverFragment fragment accSet =
            let
                fragLen =
                    String.length fragment

                exactIndices =
                    findAllOccurrences fragment source
            in
            if not (List.isEmpty exactIndices) then
                List.foldl
                    (\idx s ->
                        List.range idx (idx + fragLen - 1)
                            |> List.foldl Set.insert s
                    )
                    accSet
                    exactIndices

            else
                let
                    bestWindow =
                        findBestWindow fragment source

                    minThreshold =
                        fragLen // 2
                in
                if bestWindow.matchCount >= minThreshold && fragLen > 0 then
                    let
                        sourceSlice =
                            String.slice
                                bestWindow.startIndex
                                (bestWindow.startIndex + fragLen)
                                source

                        matchingPositions =
                            List.map2
                                (\charFrag ( charSource, pos ) ->
                                    if charFrag == charSource then
                                        Just pos

                                    else
                                        Nothing
                                )
                                (String.toList fragment)
                                (List.map2 Tuple.pair
                                    (String.toList sourceSlice)
                                    (List.range
                                        bestWindow.startIndex
                                        (bestWindow.startIndex + fragLen - 1)
                                    )
                                )
                                |> List.filterMap identity
                    in
                    List.foldl Set.insert accSet matchingPositions

                else
                    accSet

        coveredSet =
            List.foldl coverFragment Set.empty fragments

        coveredPositions =
            Set.toList coveredSet |> List.sort

        coveragePercent =
            if sourceLen == 0 then
                0.0

            else
                (toFloat (List.length coveredPositions) / toFloat sourceLen)
                    * 100.0

        flags =
            List.range 0 (sourceLen - 1)
                |> List.map (\idx -> Set.member idx coveredSet)

        spans =
            calculateSpans flags
    in
    { alignments = []
    , unalignedContigs = []
    , coveredPositions = coveredPositions
    , coveragePercent = coveragePercent
    , coveredSpans = spans.coveredSpans
    , uncoveredSpans = spans.uncoveredSpans
    , diagnosticStatus = InProgress
    }
