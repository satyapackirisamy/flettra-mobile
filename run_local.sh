#!/bin/bash
# Run Flutter app pointed at your local backend
# Usage: ./run_local.sh
# Optional: ./run_local.sh --emulator  (uses Android emulator IP)

HOST_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)

if [[ "$1" == "--emulator" ]]; then
  API_URL="http://10.0.2.2:3000"
else
  API_URL="http://${HOST_IP}:3000"
fi

echo "Connecting to: $API_URL"
flutter run --dart-define=API_URL=$API_URL
