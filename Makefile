APP_NAME=LudoPrince
DISPLAY_NAME="Ludo Prince - Fair Ludo"

.PHONY: help clean deps version build android-build ios-build android-internal android-production ios-internal ios-production internal production

help:
	@echo "Release commands for $(DISPLAY_NAME)"
	@echo ""
	@echo " make build              -> build Android & iOS"
	@echo " make android-build      -> build Android using Fastlane"
	@echo " make internal           -> deploy internal testing build"
	@echo " make production         -> deploy production build"
	@echo " make android-internal   -> Android internal testing"
	@echo " make android-production -> Android production"
	@echo " make ios-internal       -> iOS TestFlight (future)"
	@echo " make ios-production     -> iOS App Store (future)"
	@echo " make clean              -> flutter clean"
	@echo " make deps               -> flutter pub get"
	@echo " make version            -> increment pubspec version"

clean:
	flutter clean

deps:
	flutter pub get

version:
	./scripts/increment_version.sh

# ---------- Build ----------

build: android-build ios-build
	@echo ""
	@echo "✅ Build completed for $(DISPLAY_NAME)"

android-build:
	cd android && bundle exec fastlane build

ios-build:
	@echo "iOS build lane not added yet"


# ---------- Android Deploy ----------

android-internal:
	cd android && bundle exec fastlane internal

android-production:
	cd android && bundle exec fastlane production


# ---------- iOS Deploy ----------

ios-internal:
	@echo "iOS internal lane not added yet"

ios-production:
	@echo "iOS production lane not added yet"


# ---------- Platform pipelines ----------

internal: version build android-internal ios-internal
	@echo ""
	@echo "🚀 Internal release completed for $(DISPLAY_NAME)"

production: version build android-production ios-production
	@echo ""
	@echo "🚀 Production release completed for $(DISPLAY_NAME)"