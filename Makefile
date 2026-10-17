PROJECT  := SilverRainMini.xcodeproj
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
SCHEME   := SilverRainMini
APP_NAME := Silver Rain Mini
DERIVED  := build/DerivedData
PRODUCT  := $(DERIVED)/Build/Products/Release/$(APP_NAME).app
APP      := build/$(APP_NAME).app

.PHONY: app run test install clean project

project:
	xcodegen generate --quiet

app: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-derivedDataPath $(DERIVED) -destination 'generic/platform=macOS' build -quiet
	rm -rf "$(APP)"
	ditto "$(PRODUCT)" "$(APP)"

test: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED) \
		-destination 'platform=macOS,arch=$(shell uname -m)' test -quiet

run: app
	-pkill -x "$(APP_NAME)"
	open "$(APP)"

install: app
	-pkill -x "$(APP_NAME)"
	rm -rf "/Applications/$(APP_NAME).app"
	ditto "$(APP)" "/Applications/$(APP_NAME).app"
	# The build copies carry the same identifier; forget them so that the login
	# item and LaunchServices find the installed app, not a build folder.
	-$(LSREGISTER) -u "$(APP)"
	-$(LSREGISTER) -u "$(PRODUCT)"

clean:
	rm -rf build $(PROJECT)
