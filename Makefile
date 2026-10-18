PROJECT  := SilverRainMini.xcodeproj
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
SCHEME   := SilverRainMini
APP_NAME := Silver Rain Mini
DERIVED  := build/DerivedData
PRODUCT  := $(DERIVED)/Build/Products/Release/$(APP_NAME).app
APP      := build/$(APP_NAME).app

# The stable identity from tools/setup-signing.sh when it exists, ad-hoc otherwise.
# The same identity on every build keeps what macOS has granted the app.
SIGN_ID  := SilverRainMini Self-Signed
SIGN_KC  := $(HOME)/Library/Keychains/silverrainmini.keychain-db
SIGNED   := $(shell security find-identity "$(SIGN_KC)" 2>/dev/null | grep -qF "$(SIGN_ID)" && echo yes)
SIGNING  := $(if $(SIGNED),CODE_SIGN_IDENTITY="$(SIGN_ID)" OTHER_CODE_SIGN_FLAGS="--keychain $(SIGN_KC)")
# `make dmg VERSION=1.2.0` stamps the version; without it, project.yml's stands.
VERSIONING := $(if $(VERSION),MARKETING_VERSION=$(VERSION))

.PHONY: app run test install dmg clean project

project:
	xcodegen generate --quiet

app: project
	$(if $(SIGNED),security unlock-keychain -p silverrainmini "$(SIGN_KC)")
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-derivedDataPath $(DERIVED) -destination 'generic/platform=macOS' \
		$(SIGNING) $(VERSIONING) build -quiet
	rm -rf "$(APP)"
	ditto "$(PRODUCT)" "$(APP)"
	@codesign -dv "$(APP)" 2>&1 | grep -E '^(Authority|Signature)=' || true

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

# A drag-to-Applications .dmg and a .zip in build/, for a release or by hand.
dmg: app
	tools/make-dmg.sh "$(APP)"

clean:
	rm -rf build $(PROJECT)
