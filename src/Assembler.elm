module Assembler exposing
    ( OverlapLength
    , AssemblyError(..), OverlapCandidate
    , RemovalReason(..), RemovedFragment, ReductionEvent(..), SessionStage
    , ReductionSession
    , errorToString
    , isProperSubstringOf, calculateOverlap, compareCandidates, findBestOverlap
    , filterContainedFragments, mergePair, sortCanonical
    , startSession, stepSession, traceAssembly, assembleStrings
    )

{-| Pure greedy Overlap-Layout-Consensus (OLC) sequence assembler.


# Types

@docs OverlapLength
@docs AssemblyError, OverlapCandidate
@docs RemovalReason, RemovedFragment, ReductionEvent, SessionStage
@docs ReductionSession


# Error Formatting

@docs errorToString


# Overlap Computations

@docs isProperSubstringOf, calculateOverlap, compareCandidates, findBestOverlap


# Reduction Stages

@docs filterContainedFragments, mergePair, sortCanonical


# Step Session & Batch Assembly

@docs startSession, stepSession, traceAssembly, assembleStrings

-}


{-| Overlap match length in characters.
-}
type alias OverlapLength =
    Int


{-| Explicit precondition failure during assembly initialisation.
-}
type AssemblyError
    = InvalidMinOverlap Int
    | EmptyFragmentEncountered


{-| Format an assembly error into human-readable text.
-}
errorToString : AssemblyError -> String
errorToString error =
    case error of
        InvalidMinOverlap n ->
            "Minimum overlap must be at least 1, but received "
                ++ String.fromInt n
                ++ "."

        EmptyFragmentEncountered ->
            "Input pool contains an empty fragment."


{-| Suffix-prefix match candidate between two distinct fragments.
-}
type alias OverlapCandidate =
    { prefix : String
    , suffix : String
    , matchLength : OverlapLength
    }


{-| Reason why a fragment was removed from the active pool.
-}
type RemovalReason
    = Contained
    | Duplicate Int


{-| Information about a fragment removed during deduplication or filtering.
-}
type alias RemovedFragment =
    { fragment : String
    , reason : RemovalReason
    }


{-| Stepwise reduction event emitted during greedy assembly.
-}
type ReductionEvent
    = InitialFiltered
        { pool : List String
        , removed : List RemovedFragment
        }
    | CandidateSelected
        { pool : List String
        , candidate : OverlapCandidate
        }
    | PairMerged
        { pool : List String
        , candidate : OverlapCandidate
        , mergedFragment : String
        }
    | DynamicFiltered
        { pool : List String
        , removed : List RemovedFragment
        , mergedFragment : String
        }
    | AssemblyCompleted
        { pool : List String
        , contigs : List String
        }


{-| Discrete reduction lifecycle stages.
-}
type SessionStage
    = StageInit
    | StageSelect
    | StageMerge OverlapCandidate
    | StageDynamicFilter
        { mergedFragment : String
        , removed : List RemovedFragment
        }
    | StageDone


{-| Immutable snapshot of an ongoing reduction session.
-}
type alias ReductionSession =
    { pool : List String
    , minOverlap : OverlapLength
    , stage : SessionStage
    , removed : List RemovedFragment
    }


{-| Test if s1 is a proper substring of s2.
-}
isProperSubstringOf : String -> String -> Bool
isProperSubstringOf s1 s2 =
    s1 /= s2 && String.contains s1 s2


{-| Calculate the longest exact suffix-prefix match length between fragments.
-}
calculateOverlap : String -> String -> OverlapLength -> Maybe OverlapLength
calculateOverlap prefix suffix minOverlap =
    let
        maxLen =
            max (String.length prefix) (String.length suffix)

        startLen =
            min (String.length prefix) (String.length suffix)

        checkLen len =
            if len < minOverlap then
                Nothing

            else if
                len
                    < maxLen
                    && String.right len prefix
                    == String.left len suffix
            then
                Just len

            else
                checkLen (len - 1)
    in
    checkLen startLen


{-| Three-tier deterministic candidate tie-breaking.
-}
compareCandidates : OverlapCandidate -> OverlapCandidate -> Order
compareCandidates a b =
    case compare b.matchLength a.matchLength of
        EQ ->
            case compare a.prefix b.prefix of
                EQ ->
                    compare a.suffix b.suffix

                ord ->
                    ord

        ord ->
            ord


{-| Find the best valid overlap candidate among all pairs of fragments.
-}
findBestOverlap : List String -> OverlapLength -> Maybe OverlapCandidate
findBestOverlap pool minOverlap =
    let
        allCandidates =
            pool
                |> List.concatMap
                    (\p ->
                        pool
                            |> List.filterMap
                                (\s ->
                                    if p /= s then
                                        calculateOverlap p s minOverlap
                                            |> Maybe.map
                                                (\len ->
                                                    { prefix = p
                                                    , suffix = s
                                                    , matchLength = len
                                                    }
                                                )

                                    else
                                        Nothing
                                )
                    )
    in
    case allCandidates of
        [] ->
            Nothing

        c :: cs ->
            Just (List.foldl pickBest c cs)


pickBest : OverlapCandidate -> OverlapCandidate -> OverlapCandidate
pickBest cand acc =
    case compareCandidates cand acc of
        LT ->
            cand

        _ ->
            acc


{-| Filter contained proper substrings and duplicate fragments.
-}
filterContainedFragments :
    List String
    -> { kept : List String, removed : List RemovedFragment }
filterContainedFragments fragments =
    let
        stepCount str ( uniqueAcc, countsAcc ) =
            case List.filter (\( s, _ ) -> s == str) countsAcc of
                [] ->
                    ( uniqueAcc ++ [ str ], countsAcc ++ [ ( str, 1 ) ] )

                _ ->
                    ( uniqueAcc
                    , countsAcc
                        |> List.map
                            (\( s, c ) ->
                                if s == str then
                                    ( s, c + 1 )

                                else
                                    ( s, c )
                            )
                    )

        ( uniqueFragments, counts ) =
            List.foldl stepCount ( [], [] ) fragments

        getCount str =
            counts
                |> List.filter (\( s, _ ) -> s == str)
                |> List.head
                |> Maybe.map Tuple.second
                |> Maybe.withDefault 1

        isContained str =
            List.any (\other -> isProperSubstringOf str other) uniqueFragments

        partitionStep str acc =
            let
                count =
                    getCount str
            in
            if isContained str then
                { acc
                    | removed =
                        acc.removed
                            ++ [ { fragment = str, reason = Contained } ]
                }

            else
                let
                    dupRemoved =
                        if count > 1 then
                            [ { fragment = str
                              , reason = Duplicate (count - 1)
                              }
                            ]

                        else
                            []
                in
                { kept = acc.kept ++ [ str ]
                , removed = acc.removed ++ dupRemoved
                }
    in
    List.foldl partitionStep { kept = [], removed = [] } uniqueFragments


{-| Merge winning overlap candidate into a single contig.
-}
mergePair : OverlapCandidate -> String
mergePair candidate =
    candidate.prefix ++ String.dropLeft candidate.matchLength candidate.suffix


{-| Sort contigs descending by length, then ascending by code unit order.
-}
sortCanonical : List String -> List String
sortCanonical contigs =
    List.sortWith
        (\a b ->
            case compare (String.length b) (String.length a) of
                EQ ->
                    compare a b

                ord ->
                    ord
        )
        contigs


{-| Initialise a new reduction session with precondition checks.
-}
startSession :
    List String
    -> OverlapLength
    -> Result AssemblyError ReductionSession
startSession fragments minOverlap =
    if minOverlap < 1 then
        Err (InvalidMinOverlap minOverlap)

    else if List.any (\f -> f == "") fragments then
        Err EmptyFragmentEncountered

    else
        Ok
            { pool = fragments
            , minOverlap = minOverlap
            , stage = StageInit
            , removed = []
            }


{-| Advance a reduction session by a single discrete transition.
-}
stepSession : ReductionSession -> ( ReductionSession, ReductionEvent )
stepSession session =
    case session.stage of
        StageInit ->
            let
                filtered =
                    filterContainedFragments session.pool

                nextSession =
                    { session
                        | pool = filtered.kept
                        , stage = StageSelect
                        , removed = session.removed ++ filtered.removed
                    }
            in
            ( nextSession
            , InitialFiltered
                { pool = filtered.kept
                , removed = filtered.removed
                }
            )

        StageSelect ->
            if List.length session.pool <= 1 then
                let
                    contigs =
                        sortCanonical session.pool
                in
                ( { session | stage = StageDone }
                , AssemblyCompleted
                    { pool = session.pool
                    , contigs = contigs
                    }
                )

            else
                case findBestOverlap session.pool session.minOverlap of
                    Just candidate ->
                        ( { session | stage = StageMerge candidate }
                        , CandidateSelected
                            { pool = session.pool
                            , candidate = candidate
                            }
                        )

                    Nothing ->
                        let
                            contigs =
                                sortCanonical session.pool
                        in
                        ( { session | stage = StageDone }
                        , AssemblyCompleted
                            { pool = session.pool
                            , contigs = contigs
                            }
                        )

        StageMerge candidate ->
            let
                merged =
                    mergePair candidate

                poolWithoutPair =
                    session.pool
                        |> List.filter
                            (\f ->
                                f /= candidate.prefix && f /= candidate.suffix
                            )

                candidatePool =
                    merged :: poolWithoutPair

                filtered =
                    filterContainedFragments candidatePool
            in
            if List.isEmpty filtered.removed then
                ( { session
                    | pool = filtered.kept
                    , stage = StageSelect
                  }
                , PairMerged
                    { pool = filtered.kept
                    , candidate = candidate
                    , mergedFragment = merged
                    }
                )

            else
                ( { session
                    | pool = candidatePool
                    , stage =
                        StageDynamicFilter
                            { mergedFragment = merged
                            , removed = filtered.removed
                            }
                  }
                , PairMerged
                    { pool = candidatePool
                    , candidate = candidate
                    , mergedFragment = merged
                    }
                )

        StageDynamicFilter data ->
            let
                filtered =
                    filterContainedFragments session.pool

                nextSession =
                    { session
                        | pool = filtered.kept
                        , stage = StageSelect
                        , removed = session.removed ++ data.removed
                    }
            in
            ( nextSession
            , DynamicFiltered
                { pool = filtered.kept
                , removed = data.removed
                , mergedFragment = data.mergedFragment
                }
            )

        StageDone ->
            let
                contigs =
                    sortCanonical session.pool
            in
            ( session
            , AssemblyCompleted
                { pool = session.pool
                , contigs = contigs
                }
            )


{-| Trace greedy reduction steps from input fragments to completion.
-}
traceAssembly :
    List String
    -> OverlapLength
    -> Result AssemblyError (List ReductionEvent)
traceAssembly fragments minOverlap =
    startSession fragments minOverlap
        |> Result.map (loopSession [])


loopSession : List ReductionEvent -> ReductionSession -> List ReductionEvent
loopSession acc session =
    let
        ( nextSession, event ) =
            stepSession session

        newAcc =
            acc ++ [ event ]
    in
    case event of
        AssemblyCompleted _ ->
            newAcc

        _ ->
            loopSession newAcc nextSession


{-| Batch assemble raw string fragments into canonical contig strings.
-}
assembleStrings :
    List String
    -> OverlapLength
    -> Result AssemblyError (List String)
assembleStrings fragments minOverlap =
    traceAssembly fragments minOverlap
        |> Result.map
            (\events ->
                events
                    |> List.reverse
                    |> List.head
                    |> Maybe.andThen
                        (\evt ->
                            case evt of
                                AssemblyCompleted data ->
                                    Just data.contigs

                                _ ->
                                    Nothing
                        )
                    |> Maybe.withDefault []
            )
