module Presets exposing (Preset, presets, getPreset)

{-| Curated preset sequences and fragment configurations.

@docs Preset, presets, getPreset

-}


{-| Configuration for a curated assembly demonstration preset.
-}
type alias Preset =
    { name : String
    , source : String
    , minOverlap : Int
    , minLength : Int
    , maxLength : Int
    , fragmentCount : Int
    , defaultFragments : Maybe (List String)
    }


{-| All four curated presets available in the workbench.
-}
presets : List Preset
presets =
    [ { name = "DNA Sequence"
      , source = "ATGGCGTGCA"
      , minOverlap = 2
      , minLength = 4
      , maxLength = 6
      , fragmentCount = 6
      , defaultFragments = Just [ "ATGGC", "GGCGT", "CGTGCA" ]
      }
    , { name = "Alphabet Sequence"
      , source = "ABCDEFGHIJK"
      , minOverlap = 2
      , minLength = 3
      , maxLength = 5
      , fragmentCount = 6
      , defaultFragments =
            Just [ "ABCDE", "CDEFG", "EFGHI", "GHIJK" ]
      }
    , { name = "English Pangram"
      , source = "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG"
      , minOverlap = 3
      , minLength = 8
      , maxLength = 15
      , fragmentCount = 12
      , defaultFragments =
            Just
                [ "THE QUICK BROWN"
                , "BROWN FOX JUMPS"
                , "JUMPS OVER THE"
                , "OVER THE LAZY DOG"
                ]
      }
    , { name = "Simple Test"
      , source = "ABCDE"
      , minOverlap = 2
      , minLength = 3
      , maxLength = 3
      , fragmentCount = 3
      , defaultFragments = Just [ "ABC", "BCD", "CDE" ]
      }
    ]


{-| Retrieve a preset by 0-based index safely, defaulting to Preset 0.
-}
getPreset : Int -> Preset
getPreset index =
    presets
        |> List.drop index
        |> List.head
        |> Maybe.withDefault
            (case presets of
                first :: _ ->
                    first

                [] ->
                    { name = "Default"
                    , source = "ABCDE"
                    , minOverlap = 2
                    , minLength = 3
                    , maxLength = 3
                    , fragmentCount = 3
                    , defaultFragments = Just [ "ABC", "BCD", "CDE" ]
                    }
            )
