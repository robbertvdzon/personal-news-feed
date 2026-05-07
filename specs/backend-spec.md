# Personal News Feed — Backend Specificatie

> **Doel van dit document:** Een volledige black-box beschrijving van de backend, zodat een AI-model de backend volledig opnieuw kan bouwen zonder de originele broncode te zien. Geen implementatiedetails, wel volledig gedrag.

---

## 1. Overzicht

De backend is een **persoonlijke nieuwsfeed-service** die:
- RSS-feeds ophaalt en met AI samenvat en categoriseert
- Artikelen selecteert voor een persoonlijke feed op basis van gebruikersinteresses
- Ad-hoc zoekverzoeken verwerkt op basis van een opgegeven onderwerp
- Dagelijks een AI-samenvatting genereert van alle nieuwsitems
- Podcasts genereert (script + audio) op basis van recente nieuwsartikelen
- Multi-user: elke gebruiker heeft volledig eigen data en instellingen

**Stack:** REST API + WebSocket, JSON opslag op schijf (geen database), JWT authenticatie, asynchrone achtergrondverwerking.

**Taal/platform:** Spring Boot (Kotlin), poort 8080.

---

## 2. Architectuur & Dataopslag

### Persistentie
Alle data wordt opgeslagen als JSON-bestanden op het lokale bestandssysteem. Er is geen externe database. De rootmap is configureerbaar via `app.data-dir` (standaard `./data`).

Structuur:
```
data/
  users.json                          # alle gebruikersaccounts
  users/{username}/
    rss_items.json                    # ruwe RSS-artikelen
    feed_items.json                   # gecureerde feed-items
    news_requests.json                # verzoeken (ad-hoc + dagelijkse updates)
    settings.json                     # categorie-instellingen
    rss_feeds.json                    # geconfigureerde RSS-feed URLs
    podcasts.json                     # podcast metadata
    topic_history.json                # onderwerp-geschiedenis per gebruiker
    audio/
      {podcastId}.mp3                 # gegenereerde podcast audio
```

### Concurrency
- Alle achtergrondtaken zijn asynchroon (`@Async`).
- Per-gebruiker vergrendeling voorkomt dat dezelfde gebruiker meerdere RSS-verwerkingen tegelijk uitvoert.
- Maximaal 3 gelijktijdige Claude API-aanroepen (semaphore).

---

## 3. Authenticatie

**Mechanisme:** JWT Bearer token (HS256), geldig 30 dagen. Alle endpoints vereisen een geldig token in de `Authorization: Bearer {token}` header, behalve `/api/auth/**` en `/ws/**`.

**Wachtwoord:** BCrypt gehasht. Minimale lengte: 4 tekens.

**CORS:** Alle origins toegestaan, methoden: GET, POST, PUT, DELETE, OPTIONS.

**Sessies:** Stateless (geen server-side sessies).

---

## 4. Data Modellen

### User
| Veld | Type | Beschrijving |
|---|---|---|
| `id` | String (UUID) | Uniek ID |
| `username` | String | Gebruikersnaam (uniek) |
| `passwordHash` | String | BCrypt hash van wachtwoord |

---

### CategorySettings
| Veld | Type | Beschrijving |
|---|---|---|
| `id` | String | Categorie-ID (bijv. `kotlin`, `flutter`) |
| `name` | String | Weergavenaam |
| `enabled` | Boolean | Of de categorie actief is (default: true) |
| `extraInstructions` | String | Extra AI-instructies voor deze categorie (default: "") |
| `isSystem` | Boolean | Systeemcategorie, niet verwijderbaar (default: false) |

**Standaard categorieën** (aangemaakt als ze ontbreken):
- `kotlin` — Kotlin
- `flutter` — Flutter
- `ai` — Artificiële Intelligentie
- `blockchain` — Blockchain (standaard uitgeschakeld)
- `spring` — Spring Framework
- `web_dev` — Web Development
- `overig` — Overig (systeemcategorie, vangnet)

---

### RssFeedsSettings
| Veld | Type | Beschrijving |
|---|---|---|
| `feeds` | List\<String\> | Lijst van RSS-feed URLs |

---

### RssItem
Ruwe RSS-artikel na ophalen en AI-verwerking.

| Veld | Type | Beschrijving |
|---|---|---|
| `id` | String (UUID) | Uniek ID |
| `title` | String | Artikeltitel |
| `summary` | String | AI-gegenereerde samenvatting (150-250 woorden, Nederlands) |
| `url` | String | Artikel-URL |
| `category` | String | Toegewezen categorie-ID |
| `feedUrl` | String | URL van de RSS-feed waaruit dit item komt |
| `source` | String | Naam van de bron |
| `snippet` | String | Ruwe RSS-tekst, max 1000 tekens (HTML gestript) |
| `publishedDate` | String? | Publicatiedatum in ISO-formaat `YYYY-MM-DD` (nullable) |
| `timestamp` | String | ISO-8601 tijdstip van opslaan |
| `processedAt` | String? | ISO-8601 tijdstip van AI-verwerking (nullable) |
| `inFeed` | Boolean | Of AI dit item geselecteerd heeft voor de persoonlijke feed |
| `feedReason` | String | AI-uitleg waarom dit item wel/niet in de feed staat |
| `isRead` | Boolean | Gelezen door gebruiker |
| `starred` | Boolean | Bewaard door gebruiker |
| `liked` | Boolean? | Feedback: true=leuk, false=niet relevant, null=geen feedback |
| `topics` | List\<String\> | 2-3 canonieke onderwerpen (Nederlands, door AI bepaald) |
| `feedItemId` | String? | Gekoppeld FeedItem ID (als `inFeed=true`) |

---

### FeedItem
Gecureerd, rijk artikel voor de persoonlijke feed.

| Veld | Type | Beschrijving |
|---|---|---|
| `id` | String | Uniek ID |
| `title` | String | Artikeltitel |
| `summary` | String | Uitgebreide AI-samenvatting (400-600 woorden, Nederlands) |
| `url` | String | Artikel-URL |
| `category` | String | Categorie-ID |
| `source` | String | Naam van de bron |
| `sourceRssIds` | List\<String\> | IDs van gekoppelde RssItems |
| `sourceUrls` | List\<String\> | Externe bron-URLs |
| `topics` | List\<String\> | Onderwerpen |
| `feedReason` | String | Uitleg voor opname in feed |
| `isRead` | Boolean | Gelezen door gebruiker |
| `starred` | Boolean | Bewaard door gebruiker |
| `liked` | Boolean? | Feedback van gebruiker |
| `createdAt` | String | ISO-8601 aanmaaktijdstip |
| `publishedDate` | String? | Publicatiedatum `YYYY-MM-DD` (nullable) |
| `isSummary` | Boolean | `true` als dit de dagelijkse AI-samenvatting is (default: false) |

---

### NewsRequest
Een verwerkingsverzoek (ad-hoc of automatisch dagelijkse update).

| Veld | Type | Beschrijving |
|---|---|---|
| `id` | String | Uniek ID |
| `subject` | String | Onderwerp van het verzoek |
| `sourceItemId` | String? | ID van het bronartikel (bij "meer hierover") |
| `sourceItemTitle` | String? | Titel van het bronartikel |
| `preferredCount` | Int | Gewenst aantal resultaten (default: 2) |
| `maxCount` | Int | Maximum aantal resultaten (default: 5) |
| `extraInstructions` | String | Extra instructies voor AI |
| `maxAgeDays` | Int | Maximum leeftijd artikelen in dagen (default: 3) |
| `status` | RequestStatus | `PENDING` \| `PROCESSING` \| `DONE` \| `FAILED` \| `CANCELLED` |
| `createdAt` | String | ISO-8601 aanmaaktijdstip |
| `completedAt` | String? | ISO-8601 voltooiingstijdstip |
| `newItemCount` | Int | Aantal nieuw gevonden items |
| `costUsd` | Double | Geschatte AI-kosten in USD |
| `isDailyUpdate` | Boolean | Of dit een automatische dagelijkse update is |
| `isDailySummary` | Boolean | Of dit een dagelijkse samenvatting is |
| `summaryText` | String | (Deprecated) samenvatting tekst |
| `categoryResults` | List\<CategoryResult\> | Per-categorie statistieken |
| `processingStartedAt` | String? | ISO-8601 starttijdstip verwerking |
| `durationSeconds` | Int | Verwerkingsduur in seconden |

**RequestStatus waarden:**
- `PENDING` — Wacht op verwerking
- `PROCESSING` — Wordt verwerkt
- `DONE` — Succesvol afgerond
- `FAILED` — Mislukt
- `CANCELLED` — Geannuleerd door gebruiker

---

### CategoryResult
Per-categorie statistieken binnen een NewsRequest.

| Veld | Type | Beschrijving |
|---|---|---|
| `categoryId` | String | Categorie-ID |
| `categoryName` | String | Categorienaam |
| `articleCount` | Int | Aantal gevonden artikelen |
| `costUsd` | Double | AI-kosten voor deze categorie |
| `searchResultCount` | Int | Aantal zoekresultaten |
| `filteredCount` | Int | Aantal na filtering |

---

### Podcast
| Veld | Type | Beschrijving |
|---|---|---|
| `id` | String | Uniek ID |
| `title` | String | Podcasttitel (bijv. "DevTalk 12, 2025-05-07 — Kotlin, Flutter") |
| `periodDescription` | String | Periode omschrijving (bijv. "afgelopen week") |
| `periodDays` | Int | Periode in dagen voor nieuwsselectie |
| `durationMinutes` | Int | Gewenste duur in minuten |
| `status` | PodcastStatus | Status (zie onder) |
| `createdAt` | String | ISO-8601 aanmaaktijdstip |
| `scriptText` | String? | Volledig podcastscript (alleen in detail-endpoint) |
| `topics` | List\<String\> | Besproken onderwerpen |
| `audioPath` | String? | Pad naar MP3-bestand op server |
| `durationSeconds` | Int? | Werkelijke duur van de audio |
| `costUsd` | Double | Geschatte totale kosten |
| `customTopics` | List\<String\> | Door gebruiker opgegeven onderwerpen (optioneel) |
| `ttsProvider` | TtsProvider | `OPENAI` \| `ELEVENLABS` |
| `podcastNumber` | Int | Oplopend volgnummer per gebruiker |
| `generationSeconds` | Int? | Generatieduur in seconden |

**PodcastStatus waarden:** `PENDING` → `DETERMINING_TOPICS` → `GENERATING_SCRIPT` → `GENERATING_AUDIO` → `DONE` / `FAILED`

---

### TopicEntry
Onderwerp-geschiedenis per gebruiker (intern, niet direct via API).

| Veld | Type | Beschrijving |
|---|---|---|
| `topic` | String | Onderwerp (Nederlands) |
| `firstSeen` | String | Eerste keer gezien (ISO-8601) |
| `lastSeenNews` | String? | Laatste keer in nieuws |
| `lastSeenPodcast` | String? | Laatste keer in podcast |
| `newsCount` | Int | Aantal keer in nieuws gezien |
| `podcastMentionCount` | Int | Aantal keer genoemd in podcast |
| `podcastDeepCount` | Int | Aantal keer diepgaand behandeld in podcast |
| `likedCount` | Int | Aantal keer geliket door gebruiker |
| `starredCount` | Int | Aantal keer bewaard door gebruiker |

---

## 5. REST API Endpoints

> Alle endpoints vereisen `Authorization: Bearer {token}` header, behalve waar anders aangegeven.

---

### 5.1 Authenticatie — `/api/auth`
(Geen authenticatie vereist)

#### `POST /api/auth/register`
Registreer een nieuwe gebruiker.

**Request body:**
```json
{ "username": "string", "password": "string" }
```

**Response (201 Created):**
```json
{ "token": "string", "username": "string" }
```

**Foutgevallen:**
- `409 Conflict` — Gebruikersnaam al in gebruik
- `400 Bad Request` — Wachtwoord te kort (min. 4 tekens)

---

#### `POST /api/auth/login`
Log in en ontvang een JWT token.

**Request body:**
```json
{ "username": "string", "password": "string" }
```

**Response (200 OK):**
```json
{ "token": "string", "username": "string" }
```

**Foutgevallen:**
- `401 Unauthorized` — Ongeldige inloggegevens

---

### 5.2 Instellingen — `/api/settings`

#### `GET /api/settings`
Haal categorie-instellingen op. Als er nog geen instellingen zijn, worden de standaard categorieën aangemaakt en teruggegeven.

**Response (200 OK):** `List<CategorySettings>`
```json
[
  { "id": "kotlin", "name": "Kotlin", "enabled": true, "extraInstructions": "", "isSystem": false },
  ...
]
```

---

#### `PUT /api/settings`
Sla categorie-instellingen op. Systeemcategorieën worden altijd toegevoegd als ze ontbreken.

**Request body:** `List<CategorySettings>`

**Response (200 OK):** `List<CategorySettings>` (opgeslagen staat)

---

### 5.3 RSS-feed URLs — `/api/rss-feeds`

#### `GET /api/rss-feeds`
Haal de geconfigureerde RSS-feed URLs op.

**Response (200 OK):**
```json
{ "feeds": ["https://example.com/feed.xml", ...] }
```

---

#### `PUT /api/rss-feeds`
Sla RSS-feed URLs op.

**Request body:**
```json
{ "feeds": ["https://example.com/feed.xml", ...] }
```

**Response (200 OK):** `RssFeedsSettings`

---

### 5.4 RSS-items — `/api/rss`

#### `GET /api/rss`
Haal alle RSS-items op, gesorteerd op timestamp aflopend.

**Response (200 OK):** `List<RssItem>`

---

#### `POST /api/rss/refresh`
Trigger handmatig een dagelijkse update (RSS ophalen + AI-verwerking). Asynchroon uitgevoerd.

**Response (200 OK):**
```json
{ "status": "ok" }
```

---

#### `PUT /api/rss/{id}/read`
Markeer RSS-item als gelezen.

**Response (200 OK):** `{ "status": "ok" }`

---

#### `PUT /api/rss/{id}/unread`
Markeer RSS-item als ongelezen.

**Response (200 OK):** `{ "status": "ok" }`

---

#### `PUT /api/rss/{id}/star`
Toggle ster op RSS-item (bewaard/niet bewaard). Werkt ook bij op onderwerp-geschiedenis.

**Response (200 OK):** `{ "status": "ok" }`

---

#### `PUT /api/rss/{id}/feedback`
Sla like/dislike feedback op voor een RSS-item. Werkt ook bij op onderwerp-geschiedenis.

**Request body:**
```json
{ "liked": true }    // true, false, of null (feedback verwijderen)
```

**Response (200 OK):** `{ "status": "ok" }`

---

#### `DELETE /api/rss/{id}`
Verwijder een RSS-item.

**Response (200 OK):** `{ "status": "ok" }`

---

#### `DELETE /api/rss/cleanup`
Verwijder oude RSS-items op basis van criteria.

**Query parameters:**
| Parameter | Type | Default | Beschrijving |
|---|---|---|---|
| `olderThanDays` | Int | 30 | Verwijder items ouder dan N dagen |
| `keepStarred` | Boolean | true | Bewaar gesteunde items |
| `keepLiked` | Boolean | true | Bewaar gelikete items |
| `keepUnread` | Boolean | false | Bewaar ongelezen items |

**Response (200 OK):**
```json
{ "removed": 12 }
```

---

### 5.5 Feed-items — `/api/feed`

#### `GET /api/feed`
Haal alle feed-items op, gesorteerd op createdAt aflopend. Bevat ook de dagelijkse samenvatting (`isSummary: true`).

**Response (200 OK):** `List<FeedItem>`

---

#### `PUT /api/feed/{id}/read`
Markeer feed-item als gelezen.

**Response (200 OK):** `{ "status": "ok" }`

---

#### `PUT /api/feed/{id}/unread`
Markeer feed-item als ongelezen.

**Response (200 OK):** `{ "status": "ok" }`

---

#### `PUT /api/feed/{id}/star`
Toggle ster op feed-item. Werkt ook bij op onderwerp-geschiedenis.

**Response (200 OK):** `{ "status": "ok" }`

---

#### `PUT /api/feed/{id}/feedback`
Sla like/dislike feedback op voor een feed-item. Werkt ook bij op onderwerp-geschiedenis.

**Request body:** `{ "liked": true | false | null }`

**Response (200 OK):** `{ "status": "ok" }`

---

#### `DELETE /api/feed/{id}`
Verwijder een feed-item.

**Response (200 OK):** `{ "status": "ok" }`

---

#### `DELETE /api/feed/cleanup`
Verwijder oude feed-items (zelfde parameters als `/api/rss/cleanup`).

**Response (200 OK):** `{ "removed": 12 }`

---

### 5.6 Verzoeken — `/api/requests`

#### `GET /api/requests`
Haal alle verzoeken op voor de ingelogde gebruiker.

**Response (200 OK):** `List<NewsRequest>`

---

#### `POST /api/requests`
Maak een nieuw ad-hoc verzoek aan. Wordt direct asynchroon verwerkt.

**Request body:**
```json
{
  "subject": "string",
  "sourceItemId": "string (optioneel)",
  "sourceItemTitle": "string (optioneel)",
  "preferredCount": 2,
  "maxCount": 5,
  "extraInstructions": "string (optioneel)",
  "maxAgeDays": 3
}
```

**Response (201 Created):** `NewsRequest` (status: PENDING)

---

#### `DELETE /api/requests/{id}`
Verwijder een verzoek. Verzoeken met ID-prefix `daily-update-` of `daily-summary-` kunnen **niet** verwijderd worden (worden genegeerd of geven fout).

**Response (204 No Content)**

---

#### `POST /api/requests/{id}/rerun`
Herstart een verzoek (reset naar PENDING, asynchroon verwerkt). Werkt voor alle verzoektypen.

**Response (200 OK):** `NewsRequest` (met gereset status)

---

#### `POST /api/requests/{id}/cancel`
Annuleer een actief verzoek. Als het verzoek PROCESSING is, wordt de achtergrondtaak onderbroken zodra dit veilig mogelijk is.

**Response (204 No Content)**

---

### 5.7 Podcasts — `/api/podcasts`

#### `GET /api/podcasts`
Haal alle podcasts op. `scriptText` is **niet** opgenomen in de lijstrespons.

**Response (200 OK):** `List<Podcast>`

---

#### `POST /api/podcasts`
Maak een nieuwe podcast aan en start generatie asynchroon.

**Request body:**
```json
{
  "periodDays": 7,
  "durationMinutes": 15,
  "customTopics": ["Kotlin 2.0", "Flutter Web"],
  "ttsProvider": "OPENAI"
}
```
`customTopics` en `ttsProvider` zijn optioneel. Default TTS provider: OPENAI.

**Response (201 Created):** `Podcast` (status: PENDING)

---

#### `GET /api/podcasts/{id}`
Haal podcastdetail op inclusief volledig `scriptText`.

**Response (200 OK):** `Podcast` | **404** als niet gevonden.

---

#### `GET /api/podcasts/{id}/audio`
Stream de podcast audio als MP3.

**Response (200 OK):** Binary MP3, Content-Type: `audio/mpeg`

Headers: `Accept-Ranges: bytes`, `Cache-Control: no-store`

**404** als audio nog niet beschikbaar.

---

#### `DELETE /api/podcasts/{id}`
Verwijder podcast en bijbehorend audiobestand.

**Response (204 No Content)**

---

## 6. WebSocket

**Pad:** `ws://{host}/ws/requests`

**Authenticatie:** Niet vereist (publiek toegankelijk).

**Richting:** Alleen server → client (broadcast). Berichten van client worden genegeerd.

**Gedrag:**
- Bij verbinding: sessie wordt geregistreerd.
- Bij verbreking: sessie wordt verwijderd.
- Bij elke statuswijziging van een `NewsRequest` (PROCESSING, DONE, FAILED, CANCELLED) wordt het volledige `NewsRequest` object als JSON naar **alle** verbonden sessies gestuurd.
- Kapotte verbindingen worden bij de volgende broadcast verwijderd.

**Berichtformaat:** JSON-serialisatie van `NewsRequest`.

---

## 7. Gedrag & Achtergrondprocessen

### 7.1 Dagelijkse RSS-verwerking (automatisch, elk uur)

Wordt elk uur automatisch uitgevoerd voor elke gebruiker. Handmatig te triggeren via `POST /api/rss/refresh`.

**Pipeline:**
1. Haal alle RSS-feeds op die de gebruiker geconfigureerd heeft (parallel). Filter artikelen ouder dan 4 dagen.
2. Filter artikelen waarvan de URL al bekend is in de opgeslagen RssItems.
3. Voor elk nieuw artikel: vraag Claude om een Nederlandse samenvatting (150-250 woorden), categorie-toewijzing en 2-3 canonieke onderwerpen.
4. Sla alle nieuwe RssItems op (`inFeed: false`).
5. Vraag Claude in één batch-aanroep om 20-40% van de nieuwe items te selecteren voor de persoonlijke feed. Context meegegeven: eerder gelikete/gedislikete items, onderwerp-geschiedenis, bestaande feed-items (exclusief dagelijkse samenvattingen).
6. Update `inFeed` en `feedReason` op de geselecteerde RssItems.
7. Voor elk geselecteerd item: vraag Claude om een uitgebreide Nederlandse FeedItem-samenvatting (400-600 woorden).
8. Sla FeedItems op en koppel `feedItemId` terug op de RssItems.
9. Werk onderwerp-geschiedenis bij op basis van alle nieuwe items met topics.
10. Stuur WebSocket updates bij elke statuswijziging.

**Concurrency:** Per-gebruiker lock voorkomt overlappende runs.

---

### 7.2 Dagelijkse samenvatting (automatisch, 06:00)

Elke dag om 06:00 wordt voor elke gebruiker een dagelijkse samenvatting aangemaakt.

**Pipeline:**
1. Verzamel alle FeedItems van de afgelopen 24 uur + alle RssItems van de afgelopen 7 dagen.
2. Stuur dit naar Claude voor een uitgebreid Nederlandstalig dagelijks nieuwsoverzicht in Markdown-formaat (600-1000 woorden).
3. Sla op als FeedItem met `isSummary: true` en ID `daily-summary-feed-{datum}`. Een eventueel bestaand item met hetzelfde ID wordt eerst verwijderd.

---

### 7.3 Ad-hoc verzoek verwerking

Wordt asynchroon gestart bij `POST /api/requests`.

**Pipeline:**
1. Haal RSS-feeds op die relevant zijn voor het opgegeven onderwerp.
2. Filter op datum (`maxAgeDays`) en dedupliceer tegen bestaande RssItem URLs.
3. Vraag Claude welke kandidaat-artikelen het best passen bij het onderwerp.
4. Haal de volledige tekst op van de geselecteerde artikelen via Tavily `/extract`.
5. Vraag Claude voor elk artikel een Nederlandse samenvatting te genereren.
6. Sla elk artikel direct op als FeedItem zodra het beschikbaar is (streaming aanpak).
7. Werk de status bij na elk item; stuur WebSocket updates.
8. Verzoek ondersteunt annulering: als het verzoek geannuleerd wordt, stopt de verwerking bij het eerstvolgende veilige moment.

---

### 7.4 Podcast generatie

Wordt asynchroon gestart bij `POST /api/podcasts`.

**Statusverloop:** `PENDING` → `DETERMINING_TOPICS` → `GENERATING_SCRIPT` → `GENERATING_AUDIO` → `DONE`

**Pipeline:**
1. Haal RSS-feeds op voor de opgegeven periode (`periodDays`).
2. Laad gebruikersfeedback (gelikete/gedislikete/bewaarde artikeltitels) als context.
3. Als geen `customTopics` opgegeven: vraag Claude om een redactioneel onderwerpenplan op te stellen op basis van de RSS-artikelen (Nederlands, journalistiek format).
4. Vraag Claude een Nederlandstalig interviewscript te genereren in INTERVIEWER/GAST-format, afgestemd op de gewenste duur (~140 woorden per minuut). Met of zonder onderwerpenplan, of met `customTopics`.
5. Vraag Claude om 5-10 onderwerpen te extraheren uit het script.
6. Stel de podcasttitel samen: `"DevTalk {N}, {datum} — {onderwerp1}, {onderwerp2}"`.
7. Werk onderwerp-geschiedenis bij (eerste helft van onderwerpen telt als diepgaand behandeld).
8. Genereer audio via de gekozen TTS-provider, regel voor regel:
   - INTERVIEWER-regels → stem A
   - GAST-regels → stem B
   - Segmenten worden aaneengevoegd tot één MP3-bestand
9. Sla MP3 op als `data/users/{username}/audio/{podcastId}.mp3`.

---

### 7.5 Opstartgedrag

Bij serverstart worden alle verzoeken met status `PENDING` of `PROCESSING` gereset naar `FAILED` (herstel na herstart).

Voor elke bestaande gebruiker worden de vaste verzoekrecords `daily-update-{username}` en `daily-summary-{username}` aangemaakt als ze nog niet bestaan.

---

### 7.6 Onderwerp-geschiedenis

De onderwerp-geschiedenis (`topic_history.json`) wordt bijgehouden per gebruiker en bijgewerkt na:
- Elke RSS-verwerking (topics van nieuwe items)
- Elke podcast-generatie (topics uit script)
- Like/dislike feedback (verhoogt/verlaagt relevantiescore)
- Ster-actie (verhoogt starredCount)

Deze geschiedenis wordt als context meegegeven aan Claude bij:
- Feed-selectie (welke onderwerpen zijn recent genoeg behandeld?)
- Podcast onderwerpenplanning (welke onderwerpen verdienen meer aandacht?)

---

## 8. Externe Systemen

### 8.1 Anthropic Claude (AI backbone)

**API:** `https://api.anthropic.com/v1/messages`

**Configuratie:**
- Hoofd-model (podcastscripts, complexe selectie): configureerbaar, bijv. `claude-sonnet-4-5`
- Samenvattingsmodel (per-artikel summaries): configureerbaar, bijv. `claude-haiku-4-5-20251001`
- API-sleutel: omgevingsvariabele `ANTHROPIC_API_KEY`

**Betrouwbaarheid:**
- Maximaal 3 gelijktijdige aanroepen
- Automatische retry met exponentieel backoff (tot 4 pogingen, startend bij 15 seconden) bij HTTP 429 of verbindingsfouten

**Aanroepen en hun doel:**

| Aanroep | Doel | Input | Output |
|---|---|---|---|
| `summarizeRssItem` | Samenvatting + categorie + topics van één RSS-artikel | Titel, snippet, beschikbare categorieën | Samenvatting (150-250 w), categorie-ID, 2-3 topics |
| `selectFeedItems` | Batch-selectie van artikelen voor feed | Lijst van nieuwe artikelen, liked/disliked context, bestaande feed, topic-geschiedenis | Indices van geselecteerde artikelen (20-40%) |
| `generateFeedItemSummary` | Uitgebreide samenvatting voor feed | Artikel-URL, titel, ruwe tekst | Samenvatting (400-600 woorden, Nederlands) |
| `generateDailySummaryFromRss` | Dagelijks nieuwsoverzicht | Alle FeedItems (24h) + RssItems (7d) | Markdown-briefing (600-1000 woorden) |
| `selectArticles` | Selecteer beste artikelen voor ad-hoc verzoek | Onderwerp, kandidaatartikelen (titel+snippet) | 0-gebaseerde indices van beste keuzes |
| `summarizeArticle` | Samenvatting ad-hoc artikel na full-text fetch | Volledige artikeltekst | 400-woord Nederlandse samenvatting |
| `extractNewsTopics` | Topics uit één artikel | Artikeltekst | 2-3 canonieke topics (Nederlands) |
| `determinePodcastTopics` | Redactioneel onderwerpenplan voor podcast | RSS-artikelen, topic-geschiedenis, feedback | Nederlandstalig editorial plan |
| `generatePodcastScript` | Volledig podcastscript | Onderwerpenplan of custom topics, artikelen, gewenste duur | INTERVIEWER/GAST-format script (Nederlands) |
| `extractPodcastTopics` | Topics uit podcastscript | Scripttext | 5-10 topics |

---

### 8.2 Tavily (webzoekopdrachten & extractie)

**API:** `https://api.tavily.com`

**API-sleutel:** omgevingsvariabele `TAVILY_API_KEY`

**Gebruikte endpoints:**

| Endpoint | Doel | Input | Output |
|---|---|---|---|
| `POST /search` | Zoek artikelen op onderwerp | Zoekopdracht (Engels, 4-8 woorden), max_results, days, optioneel domeinfilter | Lijst van {title, url, snippet, publishedDate} |
| `POST /extract` | Haal volledige artikeltekst op | Lijst van URLs | Map van {url → volledige tekst, max 8000 tekens} |

Tavily wordt **alleen** gebruikt voor ad-hoc verzoeken (`POST /api/requests`), niet voor de reguliere RSS-pipeline.

---

### 8.3 OpenAI TTS (tekst-naar-spraak voor podcasts)

**API:** `https://api.openai.com/v1/audio/speech`

**API-sleutel:** omgevingsvariabele `OPENAI_API_KEY`

**Gebruik:**
- Model: `tts-1`
- INTERVIEWER-regels → stem `onyx`
- GAST-regels → stem `alloy`
- Afspeelsnelheid: 1.2x
- Outputformaat: MP3
- Segmenten worden direct aaneengevoegd

**Kosteninschatting:** ~$15 per 1 miljoen tekens

---

### 8.4 ElevenLabs TTS (alternatieve tekst-naar-spraak)

**API:** `https://api.elevenlabs.io/v1/text-to-speech/{voiceId}`

**API-sleutel:** omgevingsvariabele `ELEVENLABS_API_KEY` (optioneel)

**Gebruik:**
- Model: `eleven_multilingual_v2`
- INTERVIEWER-stem: configureerbaar via `app.elevenlabs.voice-interviewer` (standaard: `Jn7U4vF8ZkmjZIZRn4Uk`)
- GAST-stem: configureerbaar via `app.elevenlabs.voice-guest` (standaard: `h6uBOiAjLKklte8hdYio`)
- Stemstabiliteit: 0.5, similarity_boost: 0.75
- ID3v2/v1-tags en Xing/Info VBR-headers worden uit elk segment gestript vóór aaneenvoeging (voorkomt dat mediaspelers stoppen na het eerste segment)

**Kosteninschatting:** ~$0.30 per 1000 tekens

---

### 8.5 RSS-feeds (nieuwsbronnen)

Gewone HTTP GET-requests naar door de gebruiker geconfigureerde RSS-feed URLs.

**Ondersteunde formaten:** RSS 2.0 en Atom

**Verwerking:**
- Parallelle fetch van alle geconfigureerde feeds
- HTML wordt gestript uit snippets (max 1000 tekens)
- Publicatiedatums worden geparsed in diverse formaten
- Artikelen ouder dan 4 dagen worden gefilterd

---

## 9. Configuratie

Alle configuratie via `application.properties` of omgevingsvariabelen.

| Property | Omgevingsvariabele | Standaard | Beschrijving |
|---|---|---|---|
| `server.port` | — | `8080` | Serverpoort |
| `app.data-dir` | — | `./data` | Root voor JSON-opslag en audio |
| `app.jwt.secret` | — | (hardcoded default) | JWT-signeringssleutel (wijzigen in productie!) |
| `app.anthropic.api-key` | `ANTHROPIC_API_KEY` | — | Verplicht |
| `app.anthropic.model` | — | `claude-sonnet-4-5` | Hoofd Claude-model |
| `app.anthropic.summary-model` | — | `claude-haiku-4-5-20251001` | Model voor samenvattingen |
| `app.anthropic.base-url` | — | `https://api.anthropic.com` | — |
| `app.tavily.api-key` | `TAVILY_API_KEY` | — | Verplicht voor ad-hoc verzoeken |
| `app.openai.api-key` | `OPENAI_API_KEY` | — | Verplicht voor OpenAI TTS |
| `app.openai.base-url` | — | `https://api.openai.com` | — |
| `app.elevenlabs.api-key` | `ELEVENLABS_API_KEY` | — | Optioneel (alleen bij ElevenLabs TTS) |
| `app.elevenlabs.base-url` | — | `https://api.elevenlabs.io` | — |
| `app.elevenlabs.voice-interviewer` | — | `Jn7U4vF8ZkmjZIZRn4Uk` | ElevenLabs stem voor interviewer |
| `app.elevenlabs.voice-guest` | — | `h6uBOiAjLKklte8hdYio` | ElevenLabs stem voor gast |

---

## 10. Geplande taken

| Tijd | Taak |
|---|---|
| Elk uur (`0 0 * * * *`) | RSS ophalen en verwerken voor alle gebruikers |
| Dagelijks 06:00 (`0 0 6 * * *`) | Dagelijkse AI-samenvatting genereren voor alle gebruikers |

---

## 11. Foutafhandeling & Grenzen

- **RSS-verwerking:** Als Claude-aanroep mislukt voor één artikel, wordt dat artikel overgeslagen; verwerking gaat door.
- **Podcast:** Bij een fout in een van de stappen wordt de podcast gemarkeerd als `FAILED`.
- **Ad-hoc verzoek:** Bij een fatale fout wordt het verzoek gemarkeerd als `FAILED`.
- **Annulering:** Verzoeken kunnen geannuleerd worden; de verwerking stopt bij het eerstvolgende controlepunt.
- **Restart-herstel:** Bij serverherstart worden openstaande PENDING/PROCESSING verzoeken gereset naar FAILED.
- **Claude rate limiting:** Bij HTTP 429 wordt automatisch gewacht en opnieuw geprobeerd (exponentieel backoff, max 4 pogingen).
