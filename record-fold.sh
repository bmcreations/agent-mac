#!/bin/bash
# One command for a fold check in the guest VM: installs Handset.app there,
# runs it against the host's loupe on one device, sets the first posture,
# then for each later step clicks that posture in Handset's posture pill with
# agent-desktop while recording the guest screen. Each transition lands in
# <out> as <n>-<step>.mov with its measured fps (.fps.json); manifest.json
# says what ran where. Handset is quit at the end.
#
#   scripts/vm/record-fold.sh -a <Handset.app> -t <target> -o <out> [-b label] [-s secs] step...
#
#   step   a posture-pill label as Handset names it (Closed, Open, ...), or
#          loupe:<posture> to set it through loupe (closed, halfOpened, opened)
#          without a click. The first step is always set through loupe.
#   -b     build label for the manifest (default: app name + build time)
#   -s     seconds recorded per transition (default 5)
#
# The target is claimed first with X-Loupe-Session LOUPE_SESSION (default
# vm-record-fold-<pid>); a 409 stops the run. Released at the end.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
vm=$here/vm
LOUPE=${LOUPE:-https://localhost:18456}
TOKEN=${LOUPE_TOKEN:-$(cat ~/Library/Caches/loupe/token)}
SESSION=${LOUPE_SESSION:-vm-record-fold-$$}
secs=5 app= target= out= label=
while getopts a:t:o:b:s: opt; do
  case $opt in
    a) app=$OPTARG ;; t) target=$OPTARG ;; o) out=$OPTARG ;;
    b) label=$OPTARG ;; s) secs=$OPTARG ;;
    *) sed -n 2,19p "$0"; exit 2 ;;
  esac
done
shift $((OPTIND - 1))
if [ -z "$app" ] || [ -z "$target" ] || [ -z "$out" ] || [ $# -lt 2 ]; then sed -n 2,19p "$0"; exit 2; fi
mkdir -p "$out"; out=$(cd "$out" && pwd)

api() { # METHOD PATH [BODY]; body to $out/.body, status echoed
  local a=(-sk -o "$out/.body" -w '%{http_code}' -X "$1" -H "Authorization: Bearer $TOKEN"
    -H "X-Loupe-Agent: claude" -H "X-Loupe-Session: $SESSION")
  [ $# -ge 3 ] && a+=(-H "Content-Type: application/json" -d "$3")
  curl "${a[@]}" "$LOUPE$2"
}
posture() {
  local s; s=$(api PUT "/api/settings?target=$target" "{\"changes\":{\"posture\":\"$1\"}}")
  [ "$s" = 200 ] || { echo "posture $1 refused ($s): $(cat "$out/.body")" >&2; exit 1; }
}

s=$(api POST "/api/claims?target=$target")
[ "$s" = 200 ] || { echo "claim refused ($s): $(cat "$out/.body")" >&2; exit 1; }
trap 'api DELETE "/api/claims?target=$target" >/dev/null; "$vm" quit >/dev/null 2>&1 || true' EXIT

locked() { ioreg -n Root -d1 -a | grep -A1 CGSSessionScreenIsLocked | grep -q '<true/>' && echo yes || echo no; }
locked_start=$(locked)

"$vm" status | grep -q "running at" || "$vm" up
[ -n "$label" ] || label="$(basename "$app") built $(stat -f '%Sm' -t '%Y-%m-%dT%H:%M' "$app/Contents/MacOS")"
"$vm" install "$app" "$label"
"$vm" run "$target"

# The ref of Handset's button named exactly $1, or nothing.
ref_of() {
  "$vm" ad find --app Handset --role button --name "$1" | python3 -c '
import json, sys
d = json.load(sys.stdin).get("data") or {}
m = d.get("matches", []) if isinstance(d, dict) else d
m = [e for e in m if e.get("name") == sys.argv[1] and e.get("ref_id")]
print(m[0]["ref_id"] if m else "")' "$1"
}

first=${1#loupe:}; shift
posture "$first"

# Handset reads the posture once on open; a read made while the device was
# still booting leaves the pill without postures until Handset reopens it.
pill=${PILL_PROBE:-Open}
for try in 1 2; do
  for i in $(seq 20); do [ -n "$(ref_of "$pill")" ] && break 2; sleep 1; done
  [ $try = 1 ] && { echo "no \"$pill\" in the posture pill; reopening Handset" >&2; "$vm" run "$target"; }
done
[ -n "$(ref_of "$pill")" ] || { echo "no \"$pill\" in Handset's posture pill" >&2; exit 1; }
sleep 2

n=0
for step in "$@"; do
  n=$((n + 1)); name=$(printf '%02d-%s' $n "${step#loupe:}" | tr ' ' '_')
  ref=
  if [ "${step#loupe:}" = "$step" ]; then
    ref=$(ref_of "$step")
    [ -n "$ref" ] || { echo "no \"$step\" control in Handset" >&2; exit 1; }
  fi
  "$vm" record start $((secs + 5))
  sleep 1
  t0=$(python3 -c 'import time; print(f"{time.time():.3f}")')
  if [ -n "$ref" ]; then "$vm" ad click "$ref" >/dev/null; else posture "${step#loupe:}"; fi
  sleep "$secs"
  "$vm" record stop "$out" "$name" >/dev/null
  echo "{\"step\":\"$step\",\"clicked_at\":$t0,\"recording_started_before_s\":1}" > "$out/$name.step.json"
  cat "$out/$name.fps.json"
done

python3 -c '
import json, sys
keys = ["target", "build", "host_locked_at_start", "host_locked_at_end", "finished"]
print(json.dumps(dict(zip(keys, sys.argv[1:])), indent=1))' \
  "$target" "$label" "$locked_start" "$(locked)" "$(date -u +%FT%TZ)" > "$out/manifest.json"
echo "wrote $out" >&2
