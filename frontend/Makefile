LOCAL_API  = http://localhost:8080
LOCAL_WS   = ws://localhost:8080
PROD_API   = https://pnf.vdzon.com
PROD_WS    = wss://pnf.vdzon.com

DEFINES_LOCAL = --dart-define=API_BASE_URL=$(LOCAL_API) --dart-define=WS_BASE_URL=$(LOCAL_WS)
DEFINES_PROD  = --dart-define=API_BASE_URL=$(PROD_API)  --dart-define=WS_BASE_URL=$(PROD_WS)

.PHONY: run run-prod run-android run-android-local build build-local clean

# Web tegen lokale backend
run:
	flutter run -d chrome $(DEFINES_LOCAL)

# Web tegen productie backend
run-prod:
	flutter run -d chrome $(DEFINES_PROD)

# Android tegen lokale backend (vervang IP met jouw machine IP, bv 192.168.1.10)
run-android-local:
	flutter run -d android \
	  --dart-define=API_BASE_URL=http://$(LOCAL_IP):8080 \
	  --dart-define=WS_BASE_URL=ws://$(LOCAL_IP):8080

# Android tegen productie
run-android:
	flutter run -d android $(DEFINES_PROD)

# Productie web build
build:
	flutter build web $(DEFINES_PROD)

# Lokale web build (voor testen)
build-local:
	flutter build web $(DEFINES_LOCAL)

clean:
	flutter clean
