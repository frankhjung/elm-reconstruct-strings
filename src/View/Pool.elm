module View.Pool exposing (viewPool)

{-| Fragment pool grid view with contextual role and status badges.

@docs viewPool

-}

import Assembler exposing (RemovalReason(..), RemovedFragment)
import Html exposing (Html, div, h3, span, text)
import Html.Attributes exposing (class, id)
import View.StepView exposing (StepViewModel)


{-| Render the active fragment pool grid and filtered fragments drawer.
-}
viewPool : StepViewModel -> Html msg
viewPool model =
    div [ id "pool-container", class "panel" ]
        [ div [ class "pool-header" ]
            [ h3 []
                [ text
                    ("Active Fragment Pool ("
                        ++ String.fromInt (List.length model.pool)
                        ++ ")"
                    )
                ]
            ]
        , div [ id "pool-grid", class "pool-grid" ]
            (List.indexedMap (renderActiveCard model) model.pool)
        , if not (List.isEmpty model.cumulativeRemoved) then
            div [ id "removed-pool-section", class "removed-section" ]
                [ h3 []
                    [ text
                        ("Filtered Fragments ("
                            ++ String.fromInt
                                (List.length model.cumulativeRemoved)
                            ++ ")"
                        )
                    ]
                , div [ class "pool-grid pool-grid-removed" ]
                    (List.map renderRemovedCard model.cumulativeRemoved)
                ]

          else
            text ""
        ]


renderActiveCard : StepViewModel -> Int -> String -> Html msg
renderActiveCard model index fragmentStr =
    let
        candidate =
            model.candidate

        isPrefix =
            case candidate of
                Just c ->
                    c.prefix == fragmentStr

                Nothing ->
                    False

        isSuffix =
            case candidate of
                Just c ->
                    c.suffix == fragmentStr

                Nothing ->
                    False

        isMerged =
            case model.mergedFragment of
                Just m ->
                    m == fragmentStr

                Nothing ->
                    False

        cardClasses =
            [ ( "fragment-card", True )
            , ( "card-prefix", isPrefix )
            , ( "card-suffix", isSuffix )
            , ( "card-merged", isMerged )
            ]
                |> List.filter Tuple.second
                |> List.map Tuple.first
                |> String.join " "

        badge =
            if isPrefix then
                span [ class "badge badge-prefix" ] [ text "Prefix" ]

            else if isSuffix then
                span [ class "badge badge-suffix" ] [ text "Suffix" ]

            else if isMerged then
                span [ class "badge badge-merged" ] [ text "Merged" ]

            else
                span [ class "badge badge-index" ]
                    [ text ("#" ++ String.fromInt (index + 1)) ]
    in
    div [ class cardClasses ]
        [ div [ class "card-header" ] [ badge ]
        , div [ class "card-body" ]
            [ span [ class "fragment-string" ] [ text fragmentStr ] ]
        , div [ class "card-footer" ]
            [ span [ class "fragment-length" ]
                [ text (String.fromInt (String.length fragmentStr) ++ " bp") ]
            ]
        ]


renderRemovedCard : RemovedFragment -> Html msg
renderRemovedCard removed =
    let
        ( badgeClass, badgeLabel ) =
            case removed.reason of
                Contained ->
                    ( "badge-contained", "Contained" )

                Duplicate copies ->
                    ( "badge-duplicate"
                    , "Duplicate ×" ++ String.fromInt copies
                    )
    in
    div [ class "fragment-card card-removed" ]
        [ div [ class "card-header" ]
            [ span [ class ("badge " ++ badgeClass) ] [ text badgeLabel ] ]
        , div [ class "card-body" ]
            [ span [ class "fragment-string" ] [ text removed.fragment ] ]
        , div [ class "card-footer" ]
            [ span [ class "fragment-length" ]
                [ text
                    (String.fromInt (String.length removed.fragment) ++ " bp")
                ]
            ]
        ]
