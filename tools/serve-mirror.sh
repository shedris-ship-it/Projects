#!/usr/bin/env bash
# Serve the project to Studio through a mirror folder (run from Git Bash).
#
# Rojo 7.7.1 panics when a watched file disappears between "created" and
# "read" (src/change_processor.rs, handle_vfs_event). Editors that save through
# a temporary file and a rename, like Claude's file tools, trigger that, and
# every crash forces a manual Okay -> Connect in Studio. This script copies
# changed files from src/ into .rojo-mirror/ in place (no temporary files) and
# serves the mirror, restarting Rojo if it ever exits. Ctrl+C to stop.
#
# Plain `rojo serve` is fine when files are saved in place (VS Code, Notepad).

set -u
cd "$(dirname "$0")/.." || exit 1
MIRROR=.rojo-mirror

sync_once() {
	for dir in src assets; do
		[ -d "$dir" ] || continue
		# New or changed files: copy in place.
		(cd "$dir" && find . -type f \( -name "*.luau" -o -name "*.json" -o -name "*.rbxm" -o -name "*.rbxmx" \)) 2>/dev/null |
			while read -r f; do
				if [ ! -e "$MIRROR/$dir/$f" ] || [ "$dir/$f" -nt "$MIRROR/$dir/$f" ]; then
					mkdir -p "$MIRROR/$dir/$(dirname "$f")"
					cp "$dir/$f" "$MIRROR/$dir/$f" 2>/dev/null
				fi
			done
		# Files deleted from the source folder: delete from the mirror.
		if [ -d "$MIRROR/$dir" ]; then
			(cd "$MIRROR/$dir" && find . -type f) | while read -r f; do
				[ -e "$dir/$f" ] || rm -f "$MIRROR/$dir/$f"
			done
		fi
	done
	if [ ! -e "$MIRROR/default.project.json" ] || [ default.project.json -nt "$MIRROR/default.project.json" ]; then
		cp default.project.json "$MIRROR/default.project.json"
	fi
}

mkdir -p "$MIRROR"
sync_once
(while true; do
	sleep 0.5
	sync_once
done) &
MIRROR_PID=$!
trap 'kill $MIRROR_PID 2>/dev/null' EXIT

while true; do
	rojo serve "$MIRROR/default.project.json"
	echo "[rojo exited $(date +%T), restarting]"
	sleep 1
done
