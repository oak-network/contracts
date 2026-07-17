#!/usr/bin/env bash
# Builds the deterministic ABI release bundle consumed by the oak-network/sdk
# sync pipeline (see .github/workflows/release.yml).
#
# Usage: .github/scripts/build-abi-bundle.sh <tag>
# Requires: `forge build --ast` already run (artifacts/ populated WITH AST -
# contractKind is read from it), jq, tar, sha256sum.
#
# Output:
#   dist/abis-<tag>.tar.gz  - reproducible tarball:
#     abis/{ContractName}.json   { contractName, sourcePath, abi }
#     sources/DataRegistryKeys.sol
#     metadata.json              { tag, sha, solcVersion, foundryVersion,
#                                  contracts[], deployableContracts[] }
#   dist/SHA256SUMS
set -euo pipefail

TAG="${1:?usage: build-abi-bundle.sh <tag>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACTS_DIR="$REPO_ROOT/artifacts"
BUNDLE_DIR="$REPO_ROOT/.abi-bundle"
DIST_DIR="$REPO_ROOT/dist"

if [[ ! -d "$ARTIFACTS_DIR" ]]; then
  echo "error: $ARTIFACTS_DIR not found - run 'forge build' first" >&2
  exit 1
fi

rm -rf "$BUNDLE_DIR" "$DIST_DIR"
mkdir -p "$BUNDLE_DIR/abis" "$BUNDLE_DIR/sources" "$DIST_DIR"

contracts=()
deployable=()
solc_version=""

# Every artifact whose compilation target lives under src/ (excludes test/, lib/, script/).
while IFS= read -r artifact; do
  target="$(jq -r '.metadata.settings.compilationTarget | to_entries[0] | "\(.key):\(.value)"' "$artifact" 2>/dev/null || true)"
  [[ "$target" == src/* ]] || continue

  source_path="${target%%:*}"
  contract_name="${target##*:}"

  # Skip duplicate artifacts for the same source (same contract compiled under
  # multiple solc versions); error on two different sources sharing one name,
  # since abis/{name}.json could then hold the wrong contract.
  if printf '%s\n' "${contracts[@]:-}" | grep -qx "$contract_name"; then
    existing_source="$(jq -r .sourcePath "$BUNDLE_DIR/abis/$contract_name.json")"
    if [[ "$existing_source" != "$source_path" ]]; then
      echo "error: contract name $contract_name is defined in both $existing_source and $source_path" >&2
      exit 1
    fi
    echo "warning: duplicate artifact for $contract_name, keeping first, skipping $artifact" >&2
    continue
  fi

  # contractKind comes from the AST (requires forge build --ast). Only concrete,
  # non-abstract contracts count as deployable - libraries and interfaces are
  # bundled for their ABIs but excluded from new-contract detection.
  kind_info="$(jq -r --arg n "$contract_name" \
    '[.ast.nodes[]? | select(.nodeType == "ContractDefinition" and .name == $n)][0]
     | if . == null then "missing" else "\(.contractKind):\(.abstract)" end' "$artifact")"
  if [[ "$kind_info" == "missing" ]]; then
    echo "error: no AST in artifact for $contract_name - run 'forge build --ast'" >&2
    exit 1
  fi

  jq --arg name "$contract_name" --arg src "$source_path" -S \
    '{ contractName: $name, sourcePath: $src, abi: .abi }' \
    "$artifact" > "$BUNDLE_DIR/abis/$contract_name.json"

  contracts+=("$contract_name")
  if [[ "$kind_info" == "contract:false" && "$(jq -r '.bytecode.object' "$artifact")" != "0x" ]]; then
    deployable+=("$contract_name")
  fi
  if [[ -z "$solc_version" ]]; then
    solc_version="$(jq -r '.metadata.compiler.version' "$artifact")"
  fi
done < <(find "$ARTIFACTS_DIR" -name '*.json' -path '*.sol/*' | LC_ALL=C sort)

if [[ ${#contracts[@]} -eq 0 ]]; then
  echo "error: no src/ contracts found in $ARTIFACTS_DIR" >&2
  exit 1
fi

cp "$REPO_ROOT/src/constants/DataRegistryKeys.sol" "$BUNDLE_DIR/sources/DataRegistryKeys.sol"

GIT_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
FOUNDRY_VERSION="$(forge --version | head -n1)"

# jq --args builds proper JSON arrays; guard the empty case explicitly (a bare
# printf-into-jq pipeline would turn an empty array into [""]).
contracts_json="$(jq -cn '$ARGS.positional | sort' --args "${contracts[@]}")"
if [[ ${#deployable[@]} -gt 0 ]]; then
  deployable_json="$(jq -cn '$ARGS.positional | sort' --args "${deployable[@]}")"
else
  deployable_json="[]"
fi

jq -n -S \
  --arg tag "$TAG" \
  --arg sha "$GIT_SHA" \
  --arg solc "$solc_version" \
  --arg foundry "$FOUNDRY_VERSION" \
  --argjson contracts "$contracts_json" \
  --argjson deployable "$deployable_json" \
  '{ tag: $tag, sha: $sha, solcVersion: $solc, foundryVersion: $foundry,
     contracts: $contracts, deployableContracts: $deployable }' \
  > "$BUNDLE_DIR/metadata.json"

# Reproducible tarball: fixed order, ownership, and mtime.
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='UTC 2020-01-01' \
  -czf "$DIST_DIR/abis-$TAG.tar.gz" -C "$BUNDLE_DIR" .
(cd "$DIST_DIR" && sha256sum "abis-$TAG.tar.gz" > SHA256SUMS)

echo "Bundle: $DIST_DIR/abis-$TAG.tar.gz"
echo "Contracts (${#contracts[@]}): ${contracts[*]}"
echo "Deployable (${#deployable[@]}): ${deployable[*]}"
