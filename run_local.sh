#!/bin/bash
# Run the Flutter app against your local backend.
#
#   ./run_local.sh              auto-detect the target
#   ./run_local.sh --chrome     Chrome (web)
#   ./run_local.sh --macos      macOS desktop
#   ./run_local.sh --emulator   Android emulator
#   ./run_local.sh --device     physical device on the same Wi-Fi
#
# Port comes from backend/.env (PORT=3011). Override with: PORT=1234 ./run_local.sh
set -euo pipefail

PORT="${PORT:-3011}"
HOST_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")

TARGET="${1:-}"
DEVICE_ARGS=()

case "$TARGET" in
  --emulator)
    # The Android emulator reaches the host machine at 10.0.2.2, never localhost.
    API_URL="http://10.0.2.2:${PORT}"
    ;;
  --chrome)
    API_URL="http://localhost:${PORT}"
    DEVICE_ARGS=(-d chrome)
    ;;
  --macos)
    API_URL="http://localhost:${PORT}"
    DEVICE_ARGS=(-d macos)
    ;;
  --device)
    if [[ -z "$HOST_IP" ]]; then
      echo "Could not determine this Mac's LAN IP. Connect to Wi-Fi, or pass API_URL yourself." >&2
      exit 1
    fi
    # A phone cannot resolve the Mac's localhost — it needs the LAN address.
    API_URL="http://${HOST_IP}:${PORT}"
    ;;
  "")
    DEVICES=$(flutter devices 2>/dev/null || true)
    if echo "$DEVICES" | grep -qiE "ios|android" ; then
      API_URL="http://${HOST_IP:-localhost}:${PORT}"
    else
      API_URL="http://localhost:${PORT}"
    fi
    ;;
  *)
    echo "Unknown option: $TARGET" >&2
    exit 1
    ;;
esac

if ! lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Warning: nothing is listening on port ${PORT}."
  echo "         Start the backend first:  cd ../backend && npm run start:dev"
  echo
fi

echo "Connecting to: $API_URL"
flutter run --dart-define=API_URL="$API_URL" "${DEVICE_ARGS[@]}"
