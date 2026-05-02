LOCAL_API  = http://localhost:8080
LOCAL_WS   = ws://localhost:8080
EXT_API    = http://217.120.100.76:19283
EXT_WS     = ws://217.120.100.76:19283
PROD_API   = https://pnf.vdzon.com
PROD_WS    = wss://pnf.vdzon.com

DEFINES_LOCAL = --dart-define=API_BASE_URL=$(LOCAL_API) --dart-define=WS_BASE_URL=$(LOCAL_WS)
DEFINES_EXT   = --dart-define=API_BASE_URL=$(EXT_API)   --dart-define=WS_BASE_URL=$(EXT_WS)
DEFINES_PROD  = --dart-define=API_BASE_URL=$(PROD_API)  --dart-define=WS_BASE_URL=$(PROD_WS)

.PHONY: run run-ext run-prod run-android run-android-ext run-android-local build build-local clean

# Web tegen extern IP (tijdelijk port-forwarded), bereikbaar van buiten via poort 19285
run:
	flutter run -d chrome --web-port=3000 --web-hostname=0.0.0.0 $(DEFINES_EXT)

# Web tegen lokale backend
run-local:
	flutter run -d chrome --web-port=3000 $(DEFINES_LOCAL)

# Web tegen extern IP (tijdelijk port-forwarded), bereikbaar van buiten via poort 19285
run-ext:
	flutter run -d chrome --web-port=3000 --web-hostname=0.0.0.0 $(DEFINES_EXT)

# Web tegen productie backend
run-prod:
	flutter run -d chrome --web-port=3000 $(DEFINES_PROD)

# Android tegen extern IP (tijdelijk port-forwarded)
run-android-ext:
	flutter run -d android $(DEFINES_EXT)

# Android tegen lokale backend (vervang IP met jouw machine IP, bv 192.168.1.10)
run-android-local:
	flutter run -d android \
	  --dart-define=API_BASE_URL=http://$(LOCAL_IP):8080 \
	  --dart-define=WS_BASE_URL=ws://$(LOCAL_IP):8080

# Android tegen productie
run-android:
	flutter run -d android $(DEFINES_PROD)

# APK tegen extern IP (tijdelijk port-forwarded)
build-apk-ext:
	flutter build apk --release $(DEFINES_EXT)

# APK productie
build-apk:
	flutter build apk --release $(DEFINES_PROD)

# Productie web build
build:
	flutter build web $(DEFINES_PROD)

# Lokale web build (voor testen)
build-local:
	flutter build web $(DEFINES_LOCAL)

clean:
	flutter clean
