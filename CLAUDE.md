# Personal News Feed

## Repo-structuur

Alles staat in één mono-repo. GitHub Actions workflows triggeren alleen op wijzigingen
in hun eigen subfolder.

```
personal-news-feed/
  frontend/    ← Flutter app
  backend/     ← Kotlin/Spring microservice
  gitops/      ← ArgoCD + OpenShift manifests
  .github/
    workflows/
      frontend.yml   ← triggert alleen op frontend/**
      backend.yml    ← triggert alleen op backend/**
  CLAUDE.md
```

---

## Tech stack

- **Frontend:** Flutter (Android + Web)
- **Backend:** Kotlin, Spring Boot 3, Spring AI (Anthropic API), WebSocket
- **Database:** PostgreSQL (draait in OpenShift, geen backup — bewust)
- **Auth:** Keycloak (draait in OpenShift, OpenID Connect)
- **Container registry:** GitHub Container Registry (ghcr.io)
- **CI/CD:** GitHub Actions
- **Deploy:** OpenShift single-node (thuis-pc), GitOps via ArgoCD
- **Externe toegang:** Cloudflare Tunnel (geen open poorten thuis)
- **Taal in de app:** Nederlands
- **Nieuwsitems taal:** Nederlands

---

## Categorieën

Configureerbaar per gebruiker, inclusief extra instructies per categorie.
Standaard categorieën:

- **AI** – Nieuws over kunstmatige intelligentie, nieuwe modellen, onderzoek, toepassingen
- **Crypto** – Niet over prijsnieuws, maar technische ontwikkelingen, adoptie door grote bedrijven of landen, regelgeving, nieuwe protocollen
- **Podcasts** – Tips voor nieuwe of interessante podcasts om te ontdekken
- **Software ontwikkeling** – Nieuws over programmeertalen, frameworks, tools, best practices
- **Overig** – Artikelen die niet in een van de bovenstaande categorieën passen

---

## Database (PostgreSQL)

Draait als container in OpenShift via de Crunchy PostgreSQL Operator.
Geen backup geconfigureerd — bewuste keuze voor dit project.

```sql
news_items
  id            UUID PRIMARY KEY
  title         TEXT
  summary       TEXT        -- Nederlandse samenvatting gegenereerd door Claude
  url           TEXT UNIQUE -- gebruikt voor deduplicatie
  category      TEXT        -- incl. 'overig' voor niet-passende artikelen
  published_at  TIMESTAMPTZ
  source        TEXT
  created_at    TIMESTAMPTZ DEFAULT now()

user_feedback
  id         UUID PRIMARY KEY
  user_id    TEXT
  item_id    UUID REFERENCES news_items(id)
  liked      BOOLEAN
  created_at TIMESTAMPTZ DEFAULT now()
  UNIQUE (user_id, item_id)

user_preferences
  id          UUID PRIMARY KEY
  user_id     TEXT UNIQUE
  updated_at  TIMESTAMPTZ DEFAULT now()

user_categories
  id                 UUID PRIMARY KEY
  user_preference_id UUID REFERENCES user_preferences(id)
  name               TEXT
  enabled            BOOLEAN DEFAULT true
  extra_instructions TEXT

news_requests
  id               UUID PRIMARY KEY
  user_id          TEXT
  subject          TEXT        -- onderwerp om nieuws over te zoeken
  source_item_id   UUID REFERENCES news_items(id) NULL  -- optioneel: vanuit artikel
  preferred_count  INT DEFAULT 2
  max_count        INT DEFAULT 5
  status           TEXT        -- pending / processing / done / failed
  created_at       TIMESTAMPTZ DEFAULT now()
  completed_at     TIMESTAMPTZ
```

## Auth (Keycloak)

Draait als container in OpenShift via de Keycloak Operator (OperatorHub).
Flutter gebruikt OpenID Connect (OIDC) om in te loggen.
De backend valideert JWT-tokens van Keycloak.

---

## Frontend (`frontend/`)

**Stack:** Flutter, Riverpod, WebSocket

### Schermen

1. **Login / registratie** – Keycloak OIDC
2. **News feed** – lijst van nieuwsitems als cards
   - Categorie-tabs bovenin (scrollbaar, inclusief "Overig")
   - Ongelezen-indicator per item (blauwe stip)
   - Badge bovenin met totaal aantal ongelezen items
   - "Gelezen / Verberg gelezen" toggle
   - Indicator dat er actieve requests in de queue zijn
3. **Item detail** – volledige samenvatting + link naar bron + prev/next navigatie
   - Knop "Meer hierover" → maakt een news request aan
4. **Queue** – overzicht van alle news requests
   - Live statusupdates via WebSocket (wachtend / bezig / klaar)
   - Nieuw request handmatig aanmaken (vrij onderwerp invullen)
   - Bij aanmaken: gewenst aantal (bij voorkeur X, max Y)
5. **Instellingen**
   - Categorieën aan/uit + extra instructies per categorie
   - Eigen categorieën toevoegen en verwijderen

### Per nieuwsitem tonen

- Categoriebadge (kleurgecodeerd, ook voor "Overig")
- Titel
- Samenvatting (Nederlands, ~250 woorden)
- Tijdstip
- 👍 / 👎 knoppen
- Link naar origineel artikel
- Knop "Meer hierover"

### Huidige staat (mock)

- Werkt met hardcoded mockdata (13 items, alle 4 categorieën)
- Scrollbare categorie-tabs bovenin
- Ongelezen-indicator (blauwe stip), items worden gelezen gemarkeerd bij openen
- "Gelezen / Verberg gelezen" toggle knop
- Prev/next navigatie in detail screen (swipe + knoppen)
- Nog geen koppeling met backend API

### Coding conventies

- Gebruik Riverpod voor state management
- Dart package naam: `personal_news_feed`
- Widgets klein en gesplitst in losse bestanden
- Nederlandstalige comments zijn prima

### CI/CD

GitHub Actions workflow (`frontend.yml`) triggert alleen bij wijzigingen in `frontend/**`:
- Bouwt Flutter web app
- Bouwt Docker image en pusht naar `ghcr.io`
- Werkt image tag bij in `gitops/manifests/frontend-deployment.yaml`

---

## Backend (`backend/`)

**Stack:** Kotlin, Spring Boot 3, Spring AI (Anthropic), WebSocket

### Verantwoordelijkheden

1. **Geplande nieuwsrun** – haalt meerdere keren per dag nieuws op, filtert en verwerkt
2. **News request queue** – verwerkt door gebruikers ingediende zoekopdrachten
3. **REST API** – levert nieuws en queue-data aan de frontend
4. **WebSocket** – pusht live statusupdates van queue-items naar verbonden clients

### REST API endpoints

```
GET    /api/news                  ← gefilterd op categorie, gelezen-status, paginering
GET    /api/news/{id}             ← enkel artikel
POST   /api/news/{id}/feedback    ← 👍/👎 opslaan

GET    /api/requests              ← queue van de ingelogde gebruiker
POST   /api/requests              ← nieuw news request aanmaken
GET    /api/requests/{id}         ← status van één request

GET    /api/preferences           ← gebruikersvoorkeuren en categorieën
PUT    /api/preferences           ← voorkeuren opslaan

POST   /api/refresh               ← handmatig nieuwsrun triggeren (admin)
```

### WebSocket

- Endpoint: `ws://api.jouwdomein.nl/ws`
- De backend pusht een bericht naar de client zodra een news request van status wisselt
- Berichtformaat: `{ requestId, status, newItemCount }` (JSON)
- De frontend herlaadt de bijbehorende items na ontvangst

### Nieuws-bronnen

Alle bronnen zijn configureerbaar via `application.yml` — geen limiet op aantal.

#### RSS (gratis, geen API-key)
Voorbeelden — volledig uitbreidbaar:
- The Verge, Ars Technica, TechCrunch
- Hacker News, CoinDesk
- Elke site met een RSS-feed

#### NewsAPI.org (gratis tier: 100 calls/dag)
- Doorzoekt honderden nieuwsbronnen tegelijk
- Vereist `NEWS_API_KEY`

#### Reddit (gratis, ruime limieten)
- Subreddits configureerbaar, bijv: `r/MachineLearning`, `r/rust`, `r/Bitcoin`, `r/programming`

### Verwerking in twee stappen (kostenbesparing)

1. **Filter** (goedkoop, klein model): is dit item relevant voor een van de ingestelde categorieën? Zo nee → categorie "overig"
2. **Samenvatting** (groter model): Nederlandse samenvatting ~250 woorden + categorie toewijzen

### News request verwerking

- Backend pikt `pending` requests op en zet ze op `processing`
- Zoekt nieuws op basis van het opgegeven onderwerp
- Genereert samenvattingen voor gevonden items
- Respecteert `preferred_count` en `max_count` — alleen echt interessante items boven het voorkeur-aantal worden toegevoegd
- Zet request op `done` en notificeert frontend via WebSocket

### Projectstructuur

```
backend/
  src/main/kotlin/com/vdzon/newsfeed/
    NewsFeedApplication.kt
    config/AppConfig.kt
    model/
      NewsItem.kt
      NewsRequest.kt
    api/
      NewsController.kt
      RequestController.kt
      PreferencesController.kt
    websocket/
      NewsWebSocketHandler.kt
    service/
      RssFetchService.kt
      NewsApiService.kt
      RedditService.kt
      FilterService.kt
      SummaryService.kt
      RequestProcessorService.kt  ← verwerkt news requests uit de queue
      PostgresService.kt
    scheduler/
      NewsFeedScheduler.kt        ← geplande nieuwsrun
      RequestQueueScheduler.kt    ← pikt pending requests op
  src/main/resources/application.yml
  build.gradle.kts
  Dockerfile
```

### CI/CD

GitHub Actions workflow (`backend.yml`) triggert alleen bij wijzigingen in `backend/**`:
- Bouwt Kotlin/Spring Boot jar
- Bouwt Docker image en pusht naar `ghcr.io`
- Werkt image tag bij in `gitops/manifests/backend-deployment.yaml`

---

## Infra & GitOps (`gitops/`)

### Infrastructuur

- **Hardware:** mini-pc thuis, single-node OpenShift, SSD storage
- **Externe toegang:** Cloudflare Tunnel als container in OpenShift — geen open poorten thuis
  - `api.jouwdomein.nl` → backend API + WebSocket
  - `app.jouwdomein.nl` → frontend
- **Beheer:** kubeconfig en admin access alleen lokaal; geen externe toegang tot het cluster zelf

### GitOps-flow

```
code push naar main
  └── GitHub Actions bouwt image → pusht naar ghcr.io
        └── pipeline commit: update image tag in gitops/manifests/
              └── ArgoCD detecteert wijziging → rolt uit naar OpenShift
```

ArgoCD wordt geïnstalleerd via OperatorHub. Één bootstrap Application wordt handmatig
aangemaakt om ArgoCD aan de repo te koppelen. Daarna beheert ArgoCD zichzelf en alle
andere applicaties via Git.

### Secrets

Secrets worden handmatig aangemaakt in OpenShift (niet in Git).
Toekomstige migratie naar Sealed Secrets zodat ook secrets via GitOps beheerd kunnen worden.

Benodigde secrets:
- `ANTHROPIC_API_KEY`
- `NEWS_API_KEY`
- PostgreSQL wachtwoord
- Keycloak admin wachtwoord
- Cloudflare Tunnel token

### Repo-structuur

```
gitops/
  argocd/
    application-backend.yaml
    application-frontend.yaml
    application-infra.yaml
  manifests/
    infra/
      namespace.yaml
      cloudflare-tunnel.yaml
      postgres.yaml              ← Crunchy PostgreSQL Operator CR
      keycloak.yaml              ← Keycloak Operator CR
    backend/
      deployment.yaml
      service.yaml
      route.yaml
      configmap.yaml             ← cron-expressie, RSS-urls, subreddits, etc.
      secret-template.yaml
    frontend/
      deployment.yaml
      service.yaml
      route.yaml
```

### Database & Auth

PostgreSQL en Keycloak draaien beide als containers in OpenShift:
- **PostgreSQL** via Crunchy PostgreSQL Operator
- **Keycloak** via Keycloak Operator (OperatorHub)

Beide worden via GitOps beheerd (manifests in `gitops/manifests/infra/`).

### GitHub Actions — path filters

```yaml
# backend.yml
on:
  push:
    paths:
      - 'backend/**'

# frontend.yml
on:
  push:
    paths:
      - 'frontend/**'

# ArgoCD reageert automatisch alleen op wijzigingen in gitops/**
```
