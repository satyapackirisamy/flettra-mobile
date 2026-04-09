#!/bin/bash
# Run Flutter app pointed at your local backend
# Usage: ./run_local.sh              (auto-detects device)
# Optional: ./run_local.sh --chrome  (Chrome web, uses localhost)
# Optional: ./run_local.sh --emulator (Android emulator)

HOST_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)

if [[ "$1" == "--emulator" ]]; then
  API_URL="http://10.0.2.2:3000"
elif [[ "$1" == "--chrome" ]]; then
  API_URL="http://localhost:3000"
else
  # Check if only Chrome/web devices are available
  DEVICES=$(flutter devices 2>/dev/null)
  if echo "$DEVICES" | grep -q "chrome" && ! echo "$DEVICES" | grep -q "ios\|android"; then
    API_URL="http://localhost:3000"
  else
    API_URL="http://${HOST_IP}:3000"
  fi
fi

echo "Connecting to: $API_URL"
flutter run --dart-define=API_URL=$API_URL
