## Tech stack
- **Frontend:** Flutter (Android + Web)
- **Database:** Firebase Firestore (nog niet gekoppeld, eerst mock)
- **Auth:** Firebase Authentication (nog niet gekoppeld, eerst mock)
- **Backend:** Python microservice (later)
- **Taal in de app:** Nederlands
- **Nieuwsitems taal:** Nederlands

## Categorieën
Categorieën zijn configureerbaar per gebruiker, inclusief 
extra instructies per categorie. Standaard categorieën:

- **AI** – Nieuws over kunstmatige intelligentie, nieuwe 
  modellen, onderzoek, toepassingen
- **Crypto** – Niet zozeer prijsnieuws, maar technische 
  ontwikkelingen, adoptie door grote bedrijven of landen, 
  regelgeving, nieuwe protocollen
- **Podcasts** – Tips voor nieuwe of interessante podcasts 
  om te ontdekken
- **Software ontwikkeling** – Nieuws over programmeertalen, 
  frameworks, tools, best practices

## Firestore datamodel (nog te implementeren)
news_items/
{id}:
title: string
summary: string        ← Nederlandse samenvatting
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

## Flutter app schermen
1. **Login scherm** – Firebase Auth (later)
2. **News feed** – lijst van nieuwsitems als cards
3. **Item detail** – volledige samenvatting + link naar bron
4. **Instellingen** – categorieën aan/uit + extra instructies 
   per categorie bewerken

## Per nieuwsitem tonen
- Categorie label
- Titel
- Korte samenvatting (Nederlands)
- Tijdstip
- 👍 / 👎 knoppen
- Link naar origineel artikel

## Huidige fase: Mock
De app werkt nu met hardcoded mockdata. Geen Firebase connectie 
nodig. Gebruik realistische nep-data voor alle 4 categorieën.

## Coding conventies
- Flutter: gebruik Riverpod voor state management
- Dart package naam: personal_news_feed
- Houd widgets klein en gesplitst in losse bestanden
- Nederlandstalige comments in de code zijn prima
