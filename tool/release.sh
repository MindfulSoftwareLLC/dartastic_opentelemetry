#!/usr/bin/env bash
# tool/release.sh — Flutter/Dart team -wip release pattern.
#
# Reads the version from pubspec.yaml, which MUST end in `-wip`. Then:
#   1. Strips `-wip` from pubspec.yaml.
#   2. Replaces the `## [X.Y.Z-wip]` CHANGELOG header with
#      `## [X.Y.Z] - YYYY-MM-DD`.
#   3. Runs `dart pub get`, `dart analyze`, and `dart test`.
#   4. Commits as `Release X.Y.Z` and tags `vX.Y.Z`.
#   5. Bumps pubspec to next `-wip` version (rightmost numeric component
#      + 1 by default, or `--next` to override).
#   6. Inserts a fresh `## [next-wip]` section above the just-released
#      one in CHANGELOG.md.
#   7. Commits as `Bump to <next-wip>`.
#
# After success, push and publish manually:
#     git push origin HEAD vX.Y.Z
#     dart pub publish
#
# Usage:
#     tool/release.sh                       # auto-bump trailing number
#     tool/release.sh --next 1.2.0-beta     # override the next version
#     tool/release.sh --yes                 # skip confirmation prompt
#
# Aborts if the working tree isn't clean. If anything fails after
# pubspec/CHANGELOG have been edited but before the commit, recover
# with:
#     git checkout pubspec.yaml CHANGELOG.md
#     git tag -d vX.Y.Z   # only if the tag was created

set -euo pipefail

NEXT_OVERRIDE=""
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
  case $1 in
    --next) NEXT_OVERRIDE="$2"; shift 2;;
    --yes|-y) ASSUME_YES=1; shift;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done

# require clean working tree
if ! git diff-index --quiet HEAD --; then
  echo "error: working tree is dirty. commit or stash first." >&2
  exit 1
fi

# read current version
CURRENT=$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')
if [[ -z $CURRENT ]]; then
  echo "error: could not read version from pubspec.yaml" >&2
  exit 1
fi

if [[ $CURRENT != *-wip ]]; then
  echo "error: pubspec.yaml version is '$CURRENT' — expected to end in -wip." >&2
  echo "       did you already release? bump to the next -wip version." >&2
  exit 1
fi

RELEASE=${CURRENT%-wip}
TODAY=$(date +%Y-%m-%d)

# verify CHANGELOG has a section for the wip version
if ! grep -qE "^##[[:space:]]*\\[?${CURRENT//./\\.}\\]?" CHANGELOG.md; then
  echo "error: CHANGELOG.md has no section header for $CURRENT" >&2
  echo "       expected '## [$CURRENT]' or '## $CURRENT'." >&2
  exit 1
fi

# compute next-wip
if [[ -n $NEXT_OVERRIDE ]]; then
  NEXT_WIP="${NEXT_OVERRIDE%-wip}-wip"
else
  if [[ $RELEASE =~ ([0-9]+)$ ]]; then
    NUM=${BASH_REMATCH[1]}
    PREFIX=${RELEASE%$NUM}
    NEXT_WIP="${PREFIX}$((NUM+1))-wip"
  else
    echo "error: cannot auto-bump '$RELEASE' (no trailing number)." >&2
    echo "       use --next <version> to specify it explicitly." >&2
    exit 1
  fi
fi

cat <<EOM

  Releasing: $RELEASE   (was: $CURRENT)
  Next dev:  $NEXT_WIP

EOM

if [[ $ASSUME_YES -ne 1 ]]; then
  printf 'Continue? [y/N] '
  read -r reply
  [[ $reply == y || $reply == Y ]] || { echo "aborted."; exit 1; }
fi

cleanup_msg() {
  cat >&2 <<EOM

error: failed mid-release. To recover:
  git checkout pubspec.yaml CHANGELOG.md
  git tag -d v$RELEASE 2>/dev/null || true

EOM
}
trap cleanup_msg ERR

# 1) strip -wip from pubspec
perl -i -pe "s|^(version:\\s*)\\Q$CURRENT\\E\\s*\$|\${1}$RELEASE|" pubspec.yaml

# 2) date the CHANGELOG section header
perl -i -pe "s|^(##[[:space:]]*)\\[?\\Q$CURRENT\\E\\]?.*\$|\${1}[$RELEASE] - $TODAY|" CHANGELOG.md

# 3) sanity check
dart pub get >/dev/null
dart analyze
dart test

# 4) commit + tag
git add pubspec.yaml CHANGELOG.md
git commit -m "Release $RELEASE"
git tag "v$RELEASE"
echo "✓ tagged v$RELEASE"

# 5) bump pubspec to next -wip
perl -i -pe "s|^(version:\\s*)\\Q$RELEASE\\E\\s*\$|\${1}$NEXT_WIP|" pubspec.yaml

# 6) inject a fresh wip section above the just-released one
perl -i -pe "
  if (!\$done && /^##[[:space:]]*\\[\\Q$RELEASE\\E\\]/) {
    print \"## [$NEXT_WIP]\n\n\";
    \$done = 1;
  }
" CHANGELOG.md

# 7) commit
git add pubspec.yaml CHANGELOG.md
git commit -m "Bump to $NEXT_WIP"

trap - ERR

cat <<EOM

✓ done.

Next steps:
  git push origin HEAD v$RELEASE
  dart pub publish

If publish fails or you need to roll back the tag:
  git tag -d v$RELEASE
  git push origin :refs/tags/v$RELEASE   # only if already pushed
  git reset --hard HEAD~2

EOM
