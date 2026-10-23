#!/bin/sh
# strip-comments.sh SRC DST — submission artifact generator.
#
# Canonical Koru sources stay annotated (per-driver disclosure headers are
# load-bearing honesty). But every benchmark suite scores raw source lines,
# and the rest of the field ships zero comments — so the artifact we submit
# is generated: this copies every .k/.kz under SRC to DST minus full-line
# `//` comments, collapsing blank runs to one and dropping leading blanks.
#
# Trailing comments (`code // note`) are kept: `//` legitimately appears
# inside string literals ("http://"), so only ^\s*// is safe to remove
# without a real lexer. Two such lines exist in the whole corpus.
#
# Verify the artifact before submitting — rebuild and output-diff it.

set -eu
src=${1:?usage: strip-comments.sh SRC DST}
dst=${2:?usage: strip-comments.sh SRC DST}
[ -d "$src" ] || { echo "strip-comments: no such dir: $src" >&2; exit 1; }

rm -rf "$dst"
mkdir -p "$dst"

find "$src" -type f \( -name '*.k' -o -name '*.kz' \) | sort | while read -r f; do
  rel=${f#"$src"/}
  mkdir -p "$dst/$(dirname "$rel")"
  awk '
    /^[[:space:]]*\/\// { next }
    /^[[:space:]]*$/    { blank++; next }
    { if (blank > 0 && out > 0) print ""; blank = 0; out++; print }
  ' "$f" > "$dst/$rel"
done

n_src=$(find "$src" -type f \( -name '*.k' -o -name '*.kz' \) | wc -l | tr -d ' ')
n_dst=$(find "$dst" -type f | wc -l | tr -d ' ')
echo "strip-comments: $n_src source files -> $dst ($n_dst written)"
