#!/bin/zsh
# Build suparpad.app from the SPM release binary.
#   scripts/make-app.sh            → builds .build/suparpad.app
#   scripts/make-app.sh --install  → also installs to /Applications and
#                                    (re)loads the launch-at-login agent
set -e
cd "$(dirname "$0")/.."

swift build -c release 2>&1 | tail -2

APP=.build/suparpad.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp resources/Info.plist "$APP/Contents/Info.plist"
cp resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp .build/release/suparpad "$APP/Contents/MacOS/suparpad"
codesign --force --sign - "$APP"
echo "built $PWD/$APP"

if [[ "$1" == "--install" ]]; then
  # Quit a running instance before replacing the binary under it.
  pkill -x suparpad 2>/dev/null || true
  sleep 1
  rm -rf /Applications/suparpad.app
  cp -R "$APP" /Applications/
  echo "installed /Applications/suparpad.app"

  AGENT=~/Library/LaunchAgents/com.arthur.suparpad.plist
  mkdir -p ~/Library/LaunchAgents ~/Library/Logs
  cat > "$AGENT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.arthur.suparpad</string>
	<key>ProgramArguments</key>
	<array>
		<string>/Applications/suparpad.app/Contents/MacOS/suparpad</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StandardOutPath</key>
	<string>$HOME/Library/Logs/suparpad.log</string>
	<key>StandardErrorPath</key>
	<string>$HOME/Library/Logs/suparpad.log</string>
</dict>
</plist>
EOF
  launchctl bootout "gui/$UID/com.arthur.suparpad" 2>/dev/null || true
  launchctl bootstrap "gui/$UID" "$AGENT"
  echo "launch agent loaded — suparpad starts at login; logs at ~/Library/Logs/suparpad.log"
fi
