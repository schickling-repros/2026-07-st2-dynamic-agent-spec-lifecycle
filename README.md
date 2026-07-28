# st2 — dynamic Agent Spec lifecycle gaps

This reproduces two deterministic behaviors that make policy-mediated dynamic
Agent Specs difficult to publish safely:

1. a spec-shaped JSON resource inside the catalog is discovered as a phantom
   agent; and
2. changing an active declaration under the same task ID leaves the old process
   adopted, so the declaration and running generation disagree.

The reproduction uses only synthetic identities, paths, and commands.

## Reproduction

Requires Nix with flakes enabled:

```bash
./repro.sh
```

The script pins st2 by full source commit, creates an isolated temporary catalog,
and retires the synthetic agent during cleanup.

## Expected

- Only canonical `agent.kdl` declarations are discovered in a folder catalog.
- After a declaration changes, st2 exposes that the running task realizes an
  older generation, or requires an explicit replacement protocol. Merely
  observing a live task with the same stable ID must not imply that it realizes
  the current declaration.

## Actual

```text
one canonical agent.kdl + one resources/context/checkpoint.json
  -> 2 discovered agents

running task g1 + active agent.kdl update to g2
  -> task is adopted
  -> catalog says g2 while process remains g1
```

These are separate behaviors, but together they expose the missing boundary for
an external policy-aware publisher: safe declaration discovery plus an
observable desired-versus-running generation.

## Versions

- st2: `0.1.0+a77776a`
- source: `a77776ac553af9b9b04149f2bc9f6c269a008b83`
- runtime: Bash and Nix
- verified on Linux

## Related issues

- [compoundingtech/st2#39 — Folder catalogs discover spec-shaped resource JSON as phantom agents](https://github.com/compoundingtech/st2/issues/39)
- [compoundingtech/st2#40 — Expose desired versus observed launch generation for adopted tasks](https://github.com/compoundingtech/st2/issues/40)
- [compoundingtech/st2#41 — Proposal: exact-byte CAS publication for canonical Agent Specs](https://github.com/compoundingtech/st2/issues/41)
- [compoundingtech/st2#42 — Proposal: safely unpublish an Agent Spec only after retirement completes](https://github.com/compoundingtech/st2/issues/42)
- [compoundingtech/evals#37 — Specify and evaluate transactional publication of canonical Agent Specs](https://github.com/compoundingtech/evals/issues/37)
