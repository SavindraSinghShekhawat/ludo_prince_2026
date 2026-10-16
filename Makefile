APP_NAME=LudoPrince
DISPLAY_NAME="Ludo Prince - Fair Ludo"

.PHONY: help clean deps version build android-build ios-build android-internal android-production ios-internal ios-production internal production test test-flutter test-functions test-verbose

help:
	@echo "Release commands for $(DISPLAY_NAME)"
	@echo ""
	@echo " make test               -> run all tests (clean/concise summary)"
	@echo " make test-verbose       -> run all tests with full details & logs"
	@echo " make test-flutter       -> run Flutter tests only"
	@echo " make test-functions     -> run Firebase Functions E2E tests only"
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

# ---------- Testing ----------

test: test-flutter test-functions
	@echo ""
	@echo "🎉 All Flutter and Firebase Cloud Functions tests passed!"

test-flutter:
	@echo "🧪 Running Flutter Tests..."
	@flutter test

test-functions:
	@echo "🔥 Running Firebase Functions E2E Tests..."
	@cd functions && npm run build > /dev/null && npm run test:e2e

test-verbose:
	@echo "🧪 Running Flutter Tests (verbose)..."
	@flutter test -v
	@echo "🔥 Running Firebase Functions E2E Tests (verbose)..."
	@cd functions && npm run build && npm run test:verbose


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
	cd ios && bundle exec fastlane build


# ---------- Android Deploy ----------

android-internal:
	cd android && bundle exec fastlane internal

android-production:
	cd android && bundle exec fastlane production


# ---------- iOS Deploy ----------

ios-internal:
	cd ios && bundle exec fastlane internal

ios-production:
	cd ios && bundle exec fastlane production


# ---------- Platform pipelines ----------

internal: version android-internal ios-internal
	@echo ""
	@echo "🚀 Internal release completed for $(DISPLAY_NAME)"

production: android-production ios-production
	@echo ""
	@echo "🚀 Production release completed for $(DISPLAY_NAME)"