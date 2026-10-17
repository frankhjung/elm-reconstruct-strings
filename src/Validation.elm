module Validation exposing (Validation, succeed, fail, andMap)

{-| Applicative error accumulation for form and parameter validation.

@docs Validation, succeed, fail, andMap

-}


{-| An accumulated validation result returning either all errors or the value.
-}
type alias Validation err a =
    Result (List err) a


{-| Lift a pure value into a successful validation.
-}
succeed : a -> Validation err a
succeed value =
    Ok value


{-| Construct a validation failure from a single error.
-}
fail : err -> Validation err a
fail err =
    Err [ err ]


{-| Combine validation results, accumulating errors if any occur.
-}
andMap : Validation err a -> Validation err (a -> b) -> Validation err b
andMap valA valFn =
    case ( valFn, valA ) of
        ( Ok fn, Ok a ) ->
            Ok (fn a)

        ( Err errs1, Err errs2 ) ->
            Err (errs1 ++ errs2)

        ( Err errs, Ok _ ) ->
            Err errs

        ( Ok _, Err errs ) ->
            Err errs
