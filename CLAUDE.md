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
- **Backend:** Kotlin, Spring Boot 3, Spring AI (Anthropic API)
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
  category      TEXT
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
```

## Auth (Keycloak)

Draait als container in OpenShift via de Keycloak Operator (OperatorHub).
Flutter gebruikt OpenID Connect (OIDC) om in te loggen.
De backend valideert JWT-tokens van Keycloak.

---

## Frontend (`frontend/`)

**Stack:** Flutter, Riverpod

### Schermen

1. **Login scherm** – Keycloak OIDC (nog te implementeren)
2. **News feed** – lijst van nieuwsitems als cards
3. **Item detail** – volledige samenvatting + link naar bron + prev/next navigatie
4. **Instellingen** – categorieën aan/uit + extra instructies per categorie

### Per nieuwsitem tonen

- Categoriebadge (kleurgecodeerd)
- Titel
- Korte samenvatting (Nederlands, ~250 woorden)
- Tijdstip
- 👍 / 👎 knoppen
- Link naar origineel artikel

### Huidige staat

- Werkt met hardcoded mockdata (13 items, alle 4 categorieën)
- Scrollbare categorie-tabs bovenin
- Ongelezen-indicator (blauwe stip), items worden gelezen gemarkeerd bij openen
- "Gelezen / Verberg gelezen" toggle knop
- Prev/next navigatie in detail screen (swipe + knoppen)
- Nog geen Firebase-koppeling

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

**Stack:** Kotlin, Spring Boot 3, Spring AI (Anthropic)

### Wat het doet

1. Haalt meerdere keren per dag nieuws op via meerdere bron-types
2. Filtert irrelevante items goedkoop weg (stap 1: past item bij een categorie?)
3. Laat Claude per relevant item een Nederlandse samenvatting maken (~250 woorden) en categorie toewijzen (stap 2)
4. Slaat nieuwe items op in Firestore (duplicaten overslaan op basis van URL)
5. Draait als `@Scheduled` cron-job, configureerbaar via `application.yml`
6. Exposeert `POST /api/refresh` om handmatig een run te triggeren

### Nieuws-bronnen

Alle bronnen zijn configureerbaar via `application.yml` — geen limiet op aantal.

#### RSS (gratis, geen API-key)
Voorbeelden — volledig uitbreidbaar:
- The Verge, Ars Technica, TechCrunch
- Hacker News, CoinDesk
- Elke site met een RSS-feed

#### NewsAPI.org (gratis tier: 100 calls/dag)
- Doorzoekt honderden nieuwsbronnen tegelijk
- Handig voor brede dekking zonder per-site RSS-urls te beheren
- Vereist `NEWS_API_KEY`

#### Reddit (gratis, ruime limieten)
- Subreddits configureerbaar, bijv: `r/MachineLearning`, `r/rust`, `r/Bitcoin`, `r/programming`
- Levert actuele discussies en links die traditionele nieuwssites missen

### Verwerking in twee stappen (kostenbesparing)

1. **Filter** (goedkoop, klein model): is dit item relevant voor een van de ingestelde categorieën?
2. **Samenvatting** (uitgebreider, groter model): alleen voor items die de filter halen — Nederlandse samenvatting ~250 woorden + categorie toewijzen

### Projectstructuur

```
backend/
  src/main/kotlin/com/vdzon/newsfeed/
    NewsFeedApplication.kt
    config/AppConfig.kt
    model/NewsItem.kt
    service/
      RssFetchService.kt       ← RSS ophalen en parsen
      NewsApiService.kt        ← NewsAPI.org integratie
      RedditService.kt         ← Reddit API integratie
      FilterService.kt         ← stap 1: relevantiecheck via Spring AI
      SummaryService.kt        ← stap 2: samenvatting + categorie via Spring AI
      PostgresService.kt       ← opslaan in PostgreSQL
    scheduler/NewsFeedScheduler.kt
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
  - `api.jouwdomein.nl` → backend API
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
    application-backend.yaml     ← ArgoCD Application voor backend
    application-frontend.yaml    ← ArgoCD Application voor frontend
    application-infra.yaml       ← ArgoCD Application voor infra (tunnel, etc.)
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
      secret-template.yaml       ← structuur zonder waarden
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

Elke workflow triggert alleen op zijn eigen subfolder:

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
