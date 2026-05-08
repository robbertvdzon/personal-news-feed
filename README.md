# Personal News Feed

Een zelf-gehoste, persoonlijke nieuwslezer met AI-curation, podcastgeneratie en multi-user ondersteuning.

## Wat doet de app?

- Haalt RSS-feeds op en laat AI per artikel een Nederlandstalige samenvatting maken
- Selecteert automatisch de meest relevante artikelen voor jouw persoonlijke feed, op basis van je leesgedrag, likes en sterren
- Verwerkt ad-hoc zoekopdrachten: geef een onderwerp op en de AI zoekt en vat actuele artikelen samen
- Genereert dagelijks een AI-nieuwsoverzicht
- Genereert podcasts (script + audio) op basis van recente nieuwsartikelen, in een interview-format met twee stemmen
- Ondersteunt meerdere gebruikers, elk met volledig eigen data en instellingen

## Opbouw

| Map | Inhoud |
|-----|--------|
| `specs/` | Specificaties (zie hieronder) |
| `newsfeedbackend/` | Spring Boot backend (Kotlin, Maven) |
| `frontend/` | Flutter app (iOS, Android, web) |

## Hoe dit gebouwd is

Deze app is als POC gemaakt met vibe-coding met Claude Code gemaakt met als doen om volledige specs te maken voor het opnieuw maken van de code, maar dan spc-first (in een andere repo: https://github.com/robbertvdzon/personal-news-feed) 

## Technologie

**Backend:** Spring Boot 4.x · Kotlin · Maven · Spring Modulith · Poort 8080

**Frontend:** Flutter · Dart · Riverpod

**AI:** Anthropic Claude (samenvatting, selectie, podcast) · Tavily (websearch) · OpenAI TTS / ElevenLabs (podcast audio)
