Objective:
Design and define the Preflight Layer that catches predictable reverts and developer mistakes before RPC calls.

Deliverables:

Preflight architecture:

Validation → warnings → normalization → simulation

Rule taxonomy:

Structural (types, formats)

Semantic (array lengths, sums, duplicates)

Contract-specific invariants

Warning model:

Error vs warn classification

Issue codes & messaging style

Mode behavior:

strict, warn, normalize

MVP rule set:

Which contract methods get preflight in v1

Which checks are mandatory vs nice-to-have

Outcome:
A developer-first safety layer that meaningfully reduces revert-driven debugging.