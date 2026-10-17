# Glossary

## Assembly Error

An explicit failure condition returned when input preconditions are violated,
such as a minimum overlap below one or an empty fragment. It is distinct from a
valid terminal state where the pool is simply unable to merge further.

_Avoid_: invalid input, bad state

## Candidate

An ordered pair of distinct fragments that shares a valid suffix-prefix match
at or above the minimum overlap threshold. A candidate is a reducer decision
point, not a final assembled output.

_Avoid_: match

## Chimeric Join

An erroneous merge in which fragments from separate regions are connected by an
inexact or coincidental overlap. A chimeric join is a defect in the assembled
output, not a valid reduction step.

_Avoid_: misassembly, chimera

## Containment

The condition where one fragment is a proper substring of another and therefore
adds no new information to the pool. Containment is removed before overlap
selection so that redundant fragments do not skew the reduction.

_Avoid_: overlap

## Contig

A terminal assembled sequence produced by repeatedly merging overlapping
fragments until no valid merge remains. A contig is the output of reduction, not
necessarily the complete source sequence.

_Avoid_: assembly, sequence fragment when referring to a final merged object

## Coverage

The extent to which the source sequence is represented by the sampled
fragments. Coverage is used to reason about which regions are assembled,
missing, or incorrectly joined.

_Avoid_: complete assembly

## Diagnostic Status

An explicit domain classification of the assembly outcome evaluated
against the ground-truth source sequence. It categorises the result into
Perfect Reconstruction, Partial Assembly, Fragmented Assembly, or
Misassembly Detected based on contig counts, sequence coverage, and chimeric
joins.

_Avoid_: assembly result, assembly health

## Fragment

A contiguous substring sampled from the source sequence and treated as the unit
of overlap and merge during assembly. A fragment is defined by its content and
its position within the source sequence, not by its arrangement in the UI.

_Avoid_: chunk, segment, contig

## Overlap

A deterministic suffix-prefix match between two fragments, measured by an exact
character count. Overlap determines which pair is merged next and is distinct
from fuzzy or approximate alignment.

_Avoid_: similarity, approximate match, alignment when describing exact
suffix-prefix matching

## Overlap Length

A positive integer representing the number of characters shared in an exact
suffix-prefix match between two fragments. The absence of a qualifying overlap
is represented by `Nothing`, not by a zero-length match.

_Avoid_: similarity

## Reduction

The ordered process of selecting the best valid overlap, merging the winning
pair, and removing any fragments that are now contained by the merged result.
Reduction is a domain operation, while playback controls are a UI concern.

_Avoid_: simplification, minimisation, compression

## Reduction Event

An immutable description of a discrete state transition during greedy reduction,
including the active pool, selected candidate, removed fragments, or merged
result. It captures domain state rather than narration or UI timing.

_Avoid_: log entry, step description

## Reduction Session

An immutable snapshot of an ongoing reduction run, including the active pool,
minimum overlap threshold, and current stage. It represents the progression of a
single assembly attempt.

_Avoid_: assembler state

## Reference Alignment

The exact comparison of a reconstructed contig against the original source
sequence to identify matches, uncovered gaps, and chimeric joins. It is distinct
from the fragment-to-fragment overlap used to drive greedy reduction.

_Avoid_: fuzzy match

## Source Sequence

The canonical input string from which fragments are generated and against which
assembled contigs are checked. It is the ground truth reference for the
reconstruction task.

_Avoid_: original, target, result

## Span

A half-open interval `[start, end)` representing a contiguous sequence of
either covered or uncovered character indices within the source sequence
during reference alignment.

_Avoid_: range, chunk

## Strand

An independent randomly sampled substring from a contiguous block of text.
Within this project, a strand is synonymous with a simulated fragment used in
random sequence generation.

_Avoid_: partition

## Window Match

The optimal sub-alignment of a contig against the source sequence produced
by sliding the contig across candidate offsets, reporting the start position
and matching character count.

_Avoid_: fuzzy match, approximate alignment
