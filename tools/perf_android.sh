#!/usr/bin/env bash
# Benchmark sul telefono collegato via USB (debug USB attivo).
# Uso: tools/perf_android.sh [--export] [argomenti del test]
#   --export  riesporta prima l'APK (preset "Android Perf")
#   gli altri argomenti vanno a tests/perf_test.gd, es. --profile --levels=8,4 --seconds=6
# Risultati: righe PERF nel terminale e build/perf/results_<data>.json
set -euo pipefail
cd "$(dirname "$0")/.."
# Git Bash non deve convertire i percorsi del telefono (/data/...) in percorsi Windows.
export MSYS_NO_PATHCONV=1

ADB="${ADB:-/d/AndroidADB/platform-tools/adb}"
GODOT="${GODOT:-/d/Godot/Godot_v4.7.2-stable_win64_console.exe}"
PKG="com.bulbandshade.game.perf"
APK="build/perf/BulbPerf.apk"

export_apk=false
test_args=()
for arg in "$@"; do
	if [[ "$arg" == "--export" ]]; then export_apk=true; else test_args+=("$arg"); fi
done

if [[ "$export_apk" == true || ! -f "$APK" ]]; then
	mkdir -p build/perf
	rm -f "$APK"
	# L'export a volte non termina dopo la build Gradle: quando l'APK è pronto
	# (dimensione stabile) il processo viene chiuso.
	"$GODOT" --headless --path . --export-debug "Android Perf" "$APK" > build/perf/export.log 2>&1 &
	pid=$!
	size=-1
	while kill -0 "$pid" 2>/dev/null; do
		sleep 5
		[[ -f "$APK" ]] || continue
		new_size=$(stat -c %s "$APK")
		if [[ "$new_size" == "$size" ]]; then
			kill "$pid" 2>/dev/null || true
			break
		fi
		size=$new_size
	done
	[[ -f "$APK" ]] || { echo "Export fallito, vedi build/perf/export.log"; exit 1; }
fi

"$ADB" get-state >/dev/null
"$ADB" install -r "$APK"
# Gli argomenti arrivano al test tramite user://perf/args.txt.
"$ADB" shell "run-as $PKG sh -c 'mkdir -p files/perf && echo \"${test_args[*]:-}\" > files/perf/args.txt'"
# Schermo acceso durante il test (finché è collegato all'USB).
"$ADB" shell svc power stayon usb
"$ADB" shell input keyevent KEYCODE_WAKEUP
"$ADB" shell am force-stop "$PKG"
"$ADB" logcat -c
"$ADB" shell am start -n "$PKG/com.godot.game.GodotAppLauncher"

saved=""
done=false
declare -A seen=()
# Se adb perde il telefono per un attimo, logcat si chiude: si riaggancia e
# si salta quello che è già stato mostrato.
while [[ "$done" == false ]]; do
	while IFS= read -r line; do
		line="${line%$'\r'}"
		[[ "$line" == *"PERF "* || "$line" == *"SCRIPT ERROR"* || "$line" == *"ERROR:"* ]] || continue
		[[ -n "${seen[$line]:-}" ]] && continue
		seen[$line]=1
		echo "${line#*PERF }"
		[[ "$line" == *"PERF SAVED "* ]] && saved="${line#*PERF SAVED }"
		if [[ "$line" == *"PERF DONE"* ]]; then
			done=true
			break
		fi
	done < <("$ADB" logcat -v raw -s godot:V || true)
	[[ "$done" == true ]] || { sleep 2; "$ADB" wait-for-device; }
done

"$ADB" shell svc power stayon false
if [[ -n "$saved" ]]; then
	out="build/perf/results_$(date +%Y%m%d_%H%M%S).json"
	"$ADB" exec-out run-as "$PKG" cat "$saved" > "$out"
	echo "Risultati salvati in $out"
fi
