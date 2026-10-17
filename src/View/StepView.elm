module View.StepView exposing (StepViewModel, describeRemoved, projectStepView)

{-| Pure view projection from ReductionEvent to presentation view models.

@docs StepViewModel, describeRemoved, projectStepView

-}

import Assembler
    exposing
        ( OverlapCandidate
        , ReductionEvent(..)
        , RemovalReason(..)
        , RemovedFragment
        )


{-| Formatted presentation view model projected from a reduction event.
-}
type alias StepViewModel =
    { stageName : String
    , pool : List String
    , candidate : Maybe OverlapCandidate
    , mergedFragment : Maybe String
    , removed : List RemovedFragment
    , cumulativeRemoved : List RemovedFragment
    , contigs : List String
    , isCompleted : Bool
    , narration : String
    }


{-| Format reason for fragment removal into human-readable text.
-}
describeRemoved : RemovedFragment -> String
describeRemoved item =
    case item.reason of
        Contained ->
            "contained proper substring"

        Duplicate count ->
            "duplicate (" ++ String.fromInt count ++ " removed)"


{-| Project a domain ReductionEvent into a stateless StepViewModel.
-}
projectStepView :
    List RemovedFragment
    -> ReductionEvent
    -> StepViewModel
projectStepView cumulativeRemoved event =
    case event of
        InitialFiltered data ->
            let
                remCount =
                    List.length data.removed

                narr =
                    if remCount == 0 then
                        "Initial pool has no duplicates or proper substrings."

                    else
                        "Filtered "
                            ++ String.fromInt remCount
                            ++ " duplicate or contained fragment(s)."
            in
            { stageName = "Initial Filtering"
            , pool = data.pool
            , candidate = Nothing
            , mergedFragment = Nothing
            , removed = data.removed
            , cumulativeRemoved = cumulativeRemoved
            , contigs = []
            , isCompleted = False
            , narration = narr
            }

        CandidateSelected data ->
            { stageName = "Candidate Selection"
            , pool = data.pool
            , candidate = Just data.candidate
            , mergedFragment = Nothing
            , removed = []
            , cumulativeRemoved = cumulativeRemoved
            , contigs = []
            , isCompleted = False
            , narration =
                "Selected prefix '"
                    ++ data.candidate.prefix
                    ++ "' and suffix '"
                    ++ data.candidate.suffix
                    ++ "' with "
                    ++ String.fromInt data.candidate.matchLength
                    ++ "-character overlap."
            }

        PairMerged data ->
            { stageName = "Pair Merging"
            , pool = data.pool
            , candidate = Just data.candidate
            , mergedFragment = Just data.mergedFragment
            , removed = []
            , cumulativeRemoved = cumulativeRemoved
            , contigs = []
            , isCompleted = False
            , narration =
                "Merged winning overlap pair into '"
                    ++ data.mergedFragment
                    ++ "'."
            }

        DynamicFiltered data ->
            { stageName = "Dynamic Filtering"
            , pool = data.pool
            , candidate = Nothing
            , mergedFragment = Just data.mergedFragment
            , removed = data.removed
            , cumulativeRemoved = cumulativeRemoved
            , contigs = []
            , isCompleted = False
            , narration =
                "Removed "
                    ++ String.fromInt (List.length data.removed)
                    ++ " fragment(s) newly engulfed by '"
                    ++ data.mergedFragment
                    ++ "'."
            }

        AssemblyCompleted data ->
            let
                contigCount =
                    List.length data.contigs

                narr =
                    if contigCount <= 1 then
                        "Reduction complete: pool assembled into single contig."

                    else
                        "Reduction complete: no further legal overlaps; "
                            ++ String.fromInt contigCount
                            ++ " contigs remain."
            in
            { stageName = "Assembly Completed"
            , pool = data.pool
            , candidate = Nothing
            , mergedFragment = Nothing
            , removed = []
            , cumulativeRemoved = cumulativeRemoved
            , contigs = data.contigs
            , isCompleted = True
            , narration = narr
            }
