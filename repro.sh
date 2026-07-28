#!/usr/bin/env bash
set -euo pipefail

ST2_REV=a77776ac553af9b9b04149f2bc9f6c269a008b83
ST2=(nix run "github:compoundingtech/st2/$ST2_REV" --)

repro_root="$(mktemp -d)"
catalog="$repro_root/catalog"
workspace="$repro_root/workspace"
agent_dir="$catalog/agents/example-host/worker"
spec="$agent_dir/agent.kdl"

mkdir -p "$agent_dir/resources/context" "$workspace"

write_spec() {
  local generation="$1"
  local retired="$2"
  {
    printf 'agent "worker" {\n'
    printf '  host "example-host"\n'
    printf '  workspace "%s"\n' "$workspace"
    printf '  retired #%s\n' "$retired"
    printf '  command #"printf %s > generation.txt; exec sleep 300"#\n' "$generation"
    printf '}\n'
  } >"$spec"
}

cleanup() {
  if [[ -f "$spec" ]]; then
    write_spec g2 true
    PTY_ROOT="$repro_root/pty" "${ST2[@]}" up \
      --catalog "$catalog" --host example-host --once >/dev/null 2>&1 || true
  fi
  rm -rf "$repro_root"
}
trap cleanup EXIT

write_spec g1 false

echo "== Reproduction 1: a resource JSON becomes a phantom agent =="
printf '%s\n' \
  '{"identity":"phantom","host":"example-host","command":"true"}' \
  >"$agent_dir/resources/context/checkpoint.json"

roster="$("${ST2[@]}" agents --catalog "$catalog" --host example-host --json)"
printf '%s\n' "$roster"
count="$(printf '%s\n' "$roster" | grep -o '"identity"' | wc -l | tr -d ' ')"
if [[ "$count" != 2 ]]; then
  echo "Expected 2 discovered agents (worker + phantom), got $count" >&2
  exit 1
fi
echo "Observed: one canonical agent.kdl plus one resource JSON yields 2 agents."

rm "$agent_dir/resources/context/checkpoint.json"

echo
echo "== Reproduction 2: a changed live declaration adopts the old process =="
PTY_ROOT="$repro_root/pty" "${ST2[@]}" up \
  --catalog "$catalog" --host example-host --once

for _ in {1..50}; do
  [[ -f "$workspace/generation.txt" ]] && break
  sleep 0.1
done

first="$(<"$workspace/generation.txt")"
write_spec g2 false
PTY_ROOT="$repro_root/pty" "${ST2[@]}" up \
  --catalog "$catalog" --host example-host --once
second="$(<"$workspace/generation.txt")"

printf 'Before declaration update: running generation = %s\n' "$first"
printf 'After declaration update:  running generation = %s\n' "$second"

if [[ "$first" != g1 || "$second" != g1 ]]; then
  echo "Expected the updated g2 declaration to keep adopting the running g1 task." >&2
  exit 1
fi

echo "Observed: agent.kdl says g2, but the still-running task remains g1."
echo
echo "Both current behaviors reproduced with st2 $ST2_REV."
