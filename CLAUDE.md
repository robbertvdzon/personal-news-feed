# Personal News Feed

## Repo-structuur

```
personal-news-feed/
  frontend/    ← Flutter app
  backend/     ← Kotlin/Spring microservice
  gitops/      ← ArgoCD + OpenShift manifests
  CLAUDE.md
```

---

## Tech stack

- **Frontend:** Flutter (Android + Web)
- **Backend:** Kotlin, Spring Boot 3, Spring AI (Anthropic API)
- **Database:** Firebase Firestore
- **Auth:** Firebase Authentication
- **Deploy:** OpenShift (thuis-pc), GitOps via ArgoCD
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

## Firestore datamodel

```
news_items/
  {id}:
    title: string
    summary: string        ← Nederlandse samenvatting gegenereerd door Claude
    url: string
    category: string
    timestamp: timestamp
    source: string

user_feedback/
  {userId}_{itemId}:
    liked: boolean
    timestamp: timestamp

user_preferences/
  {userId}:
    categories: [
      {
        name: string
        enabled: boolean
        extra_instructions: string   ← bijv. "niet over prijs"
      }
    ]
```

---

## Frontend (`frontend/`)

**Stack:** Flutter, Riverpod

### Schermen

1. **Login scherm** – Firebase Auth (nog te implementeren)
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
      FirestoreService.kt      ← opslaan in Firestore
    scheduler/NewsFeedScheduler.kt
  src/main/resources/application.yml
  build.gradle.kts
  Dockerfile
```

---

## GitOps (`gitops/`)

**Flow:** push naar `main` → ArgoCD detecteert wijziging → deployed naar OpenShift

```
gitops/
  argocd/
    application.yaml           ← ArgoCD Application manifest
  manifests/
    namespace.yaml
    deployment.yaml
    service.yaml
    route.yaml                 ← OpenShift Route (i.p.v. Ingress)
    configmap.yaml             ← cron-expressie, RSS-urls, etc.
    secret.yaml                ← template (Anthropic API key, Firebase credentials)
```

### OpenShift namespace

`personal-news-feed`

### Secrets (niet in repo, template wel)

- `ANTHROPIC_API_KEY`
- Firebase service account JSON
