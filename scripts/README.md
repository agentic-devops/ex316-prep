# scripts/ (grader additions)

`verify-qNN.sh` — best-effort automated checks against a subset of each
objective's acceptance criteria, for use after `questions/*.md` or
`mock-exam-1.md`.

```bash
./scripts/verify-qNN.sh <objective-number 01-16> <namespace>
```

It prints PASS/FAIL/SKIP per check and exits non-zero if any check fails.
`SKIP` means the check needs a human (reading console output, timing a
ping, confirming a file's content) rather than something scriptable, or
needs a resource name that varies by attempt (pass it as extra arguments,
documented per-objective at the top of the case block in the script).

This is a supplement, not a replacement, for grading yourself against the
full acceptance-criteria list in each `questions/*.md` file.
