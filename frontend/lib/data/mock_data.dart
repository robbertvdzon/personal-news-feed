import '../models/news_item.dart';
import '../models/category.dart';

final List<Category> mockCategories = [
  Category(
    id: 'ai',
    name: 'AI',
    enabled: true,
    extraInstructions: 'Focus op praktische toepassingen en nieuwe modellen',
  ),
  Category(
    id: 'crypto',
    name: 'Crypto',
    enabled: true,
    extraInstructions: 'Niet over prijsnieuws, maar technische ontwikkelingen',
  ),
  Category(
    id: 'podcasts',
    name: 'Podcasts',
    enabled: true,
    extraInstructions: '',
  ),
  Category(
    id: 'software',
    name: 'Software ontwikkeling',
    enabled: true,
    extraInstructions: '',
  ),
];

final List<NewsItem> mockNewsItems = [
  // AI
  NewsItem(
    id: '1',
    title: 'Anthropic lanceert Claude 3.5 Sonnet met verbeterd redeneren',
    summary:
        'Anthropic heeft een nieuwe versie van zijn Claude-taalmodel uitgebracht die significant beter presteert op complexe redeneer- en wiskundetaken. Het model scoort hoger dan GPT-4o op meerdere standaardbenchmarks, waaronder MMLU, HumanEval en een reeks nieuwe redeneer-evaluaties die Anthropic intern heeft ontwikkeld.\n\n'
        'De verbetering zit hem met name in zogeheten "chain-of-thought reasoning": het model denkt stap voor stap na voordat het een antwoord geeft, waardoor het aanzienlijk minder fouten maakt bij meerstaps-wiskundeproblemen en logische puzzels. Gebruikers die de nieuwe versie al hebben getest, rapporteren dat het model beter omgaat met ambiguïteit in instructies en minder snel hallucineert.\n\n'
        'Claude 3.5 Sonnet is direct beschikbaar via de Anthropic API en via Claude.ai. De prijs per token blijft gelijk aan de vorige versie, wat de upgrade aantrekkelijk maakt voor bestaande klanten. Anthropic benadrukt dat het model ook veiliger is: interne red-team-tests lieten zien dat de kans op schadelijke output verder is gedaald ten opzichte van Claude 3 Sonnet.\n\n'
        'Concurrent OpenAI reageerde al met een blogpost waarin zij benadrukken dat GPT-4o op specifieke taken nog steeds voorop loopt, maar analisten beschouwen dit als marketingretoriek. De consensus in de onderzoeksgemeenschap is dat de twee modellen nu ruwweg gelijkwaardig zijn, afhankelijk van de taak.',
    url: 'https://www.anthropic.com/news/claude-3-5-sonnet',
    category: 'ai',
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    source: 'Anthropic Blog',
  ),
  NewsItem(
    id: '2',
    title: 'Google DeepMind onthult Gemini 2.0 met multimodale mogelijkheden',
    summary:
        'Google DeepMind heeft Gemini 2.0 aangekondigd, een model dat tekst, afbeeldingen, audio en video tegelijk kan verwerken en genereren. Dit maakt het technisch gezien het eerste grootschalige model dat volledig natively multimodaal is: niet een taalmodel met losse modules erbij, maar één architectuur die alle modaliteiten integreert.\n\n'
        'Het model ondersteunt een contextvenster van twee miljoen tokens — grofweg anderhalf miljoen woorden — wat het in staat stelt om lange documenten, boeken of uren aan videomateriaal in één sessie te verwerken. Google demonstreerde dit tijdens de aankondiging door het model een volledige speelfilm te laten samenvatten en er detailvragen over te stellen.\n\n'
        'Voor ontwikkelaars is Gemini 2.0 beschikbaar via Google AI Studio en de Vertex AI-clouddienst. Google heeft ook een lichte versie uitgebracht, Gemini 2.0 Flash, die sneller en goedkoper is en bedoeld is voor toepassingen waarbij latentie kritisch is, zoals chatbots in de klantenservice.\n\n'
        'Een opvallend detail is de integratie met Google Search: het model kan in real time zoeken en zijn antwoorden verrijken met actuele informatie. Privacy-onderzoekers plaatsen wel vraagtekens bij de hoeveelheid data die deze integratie over gebruikers kan verzamelen.',
    url: 'https://deepmind.google/technologies/gemini/',
    category: 'ai',
    timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    source: 'Google DeepMind',
  ),
  NewsItem(
    id: '3',
    title: 'Meta open-sourct Llama 3.2 met verbeterde instructieopvolging',
    summary:
        'Meta heeft de volledige broncode en modelgewichten van Llama 3.2 vrijgegeven onder een open licentie. De release omvat modellen in vier groottes: 1B, 3B, 11B en 90B parameters. De kleinste versies zijn geoptimaliseerd voor gebruik op mobiele apparaten en edge-hardware, terwijl het 90B-model bedoeld is voor servertoepassingen.\n\n'
        'Ten opzichte van Llama 3.1 is de instructieopvolging fors verbeterd. Waar het vorige model soms moeite had met complexe, meerlagige instructies, presteert Llama 3.2 daar beduidend beter op. Ook de ondersteuning voor niet-Engelstalige talen is uitgebreid, met expliciet verbeterde prestaties voor Nederlands, Duits, Frans en Spaans.\n\n'
        'De release is strategisch interessant: Meta positioneert Llama als tegenwicht voor de gesloten modellen van OpenAI en Google. Door het model open source te maken, trekt het een groot ecosysteem van developers aan die fine-tuning uitvoeren, wat de kwaliteit van afgeleide modellen ten goede komt.\n\n'
        'Juridisch blijft het ingewikkeld: de licentie verbiedt gebruik door bedrijven met meer dan 700 miljoen maandelijkse actieve gebruikers zonder expliciete toestemming van Meta — een clausule die critici omschrijven als "open source met een asterisk".',
    url: 'https://ai.meta.com/blog/llama-3-2/',
    category: 'ai',
    timestamp: DateTime.now().subtract(const Duration(hours: 8)),
    source: 'Meta AI Blog',
  ),
  NewsItem(
    id: '4',
    title: 'OpenAI o3 behaalt menselijk niveau op ARC-AGI benchmark',
    summary:
        'Het nieuwe o3-model van OpenAI heeft voor het eerst de ARC-AGI benchmark op menselijk niveau behaald. ARC-AGI is een testset die specifiek is ontworpen om te meten of AI kan generaliseren naar onbekende situaties — iets wat traditionele taalmodellen slecht kunnen omdat zij patronen herkennen in trainingsdata in plaats van echt te redeneren.\n\n'
        'De menselijke baseline voor ARC-AGI ligt op ongeveer 85%. GPT-4o haalde slechts 5%, en Claude 3 Opus 21%. OpenAI o3, met hoge rekenbudgetten ingesteld, behaalde 87,5% — daarmee voor het eerst boven het menselijk gemiddelde. Dit wordt door de makers van de benchmark, François Chollet, beoordeeld als een echte doorbraak, al benadrukt hij dat de testkosten per taak extreem hoog zijn.\n\n'
        'Wat o3 anders maakt dan voorgaande modellen, is het gebruik van een zoektechniek die lijkt op Monte Carlo Tree Search: het model genereert meerdere mogelijke redeneerketens, evalueert ze intern, en kiest de meest belovende. Dit kost aanzienlijk meer rekentijd maar leidt tot betere resultaten bij problemen die nauwkeurig redeneren vereisen.\n\n'
        'Of dit AGI is, blijft omstreden. Veel onderzoekers wijzen erop dat hoge scores op één benchmark niet gelijkstaan aan algemene intelligentie, maar de sprong is groot genoeg om serieus te nemen.',
    url: 'https://openai.com/blog/o3',
    category: 'ai',
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
    source: 'OpenAI Blog',
  ),

  // Crypto
  NewsItem(
    id: '5',
    title: 'Ethereum voltooit Pectra-upgrade met verbeterde staking',
    summary:
        'Het Ethereum-netwerk heeft de Pectra-hardfork succesvol afgerond na maanden van testen op de Holesky en Sepolia testnetten. De upgrade bundelt twee belangrijke Ethereum Improvement Proposals die de validator-laag en de gebruikerservaring ingrijpend veranderen.\n\n'
        'EIP-7251 verhoogt het maximale saldo per validator van 32 ETH naar 2048 ETH. Dit heeft grote gevolgen: grote stakers hoeven minder validators te draaien, wat de operationele complexiteit en kosten verlaagt. Tegelijkertijd vermindert het de druk op het peer-to-peer netwerk, dat momenteel overbelast is met honderden duizenden validators.\n\n'
        'EIP-7702 maakt accountabstractie mogelijk voor externe adressen. Concreet betekent dit dat gebruikers transacties kunnen batchen, gasprijzen kunnen betalen in andere tokens dan ETH, en ingewikkelde permissiestructuren kunnen instellen op hun gewone wallet. Dit is een grote stap richting een vriendelijkere gebruikerservaring.\n\n'
        'De upgrade verliep zonder noemenswaardige problemen. Validator-clients als Lighthouse, Prysm en Teku hadden allemaal tijdig geüpdatete versies beschikbaar. De Ethereum-gemeenschap beschouwt dit als een van de soepelste upgrades in de geschiedenis van het netwerk.',
    url: 'https://ethereum.org/en/roadmap/pectra/',
    category: 'crypto',
    timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    source: 'Ethereum Foundation',
  ),
  NewsItem(
    id: '6',
    title: 'El Salvador breidt Bitcoin-wetgeving uit naar bedrijven',
    summary:
        'El Salvador heeft nieuwe wetgeving aangenomen die grote bedrijven verplicht Bitcoin te accepteren als wettig betaalmiddel naast de Amerikaanse dollar. De wet bouwt voort op de baanbrekende Bitcoin Law uit 2021, die het land als eerste ter wereld Bitcoin tot wettig betaalmiddel maakte.\n\n'
        'De nieuwe regelgeving richt zich specifiek op bedrijven met meer dan 50 werknemers of een jaaromzet van meer dan een miljoen dollar. Kleinere bedrijven blijven vrijgesteld, zoals ook in de originele wet het geval was.\n\n'
        'President Nayib Bukele presenteerde de uitbreiding als bewijs dat het Bitcoin-experiment werkt. Volgens officiële cijfers hebben ruim twee miljoen Salvadoranen de Chivo-wallet gedownload, al zijn externe analyses kritischer: veel gebruikers zouden de app slechts éénmalig hebben gebruikt voor het uitbetaalde welkomstbonusbedrag van dertig dollar.\n\n'
        'Internationaal is de reactie gemengd. Het IMF, dat El Salvador een lening van 1,4 miljard dollar verstrekte onder de voorwaarde dat de Bitcoin-verplichtingen voor burgers werden verzacht, heeft opnieuw zorgen geuit. Meerdere Latijns-Amerikaanse landen volgen de situatie op de voet als potentieel model — of als waarschuwend voorbeeld.',
    url: 'https://www.coindesk.com/policy/el-salvador-bitcoin',
    category: 'crypto',
    timestamp: DateTime.now().subtract(const Duration(hours: 6)),
    source: 'CoinDesk',
  ),
  NewsItem(
    id: '7',
    title: 'Solana introduceert Firedancer-client voor hogere doorvoer',
    summary:
        'Jump Crypto heeft de Firedancer-validatorclient voor Solana gelanceerd op het mainnet. Firedancer is een volledig nieuwe implementatie van de Solana-protocolclient, geschreven in C en geoptimaliseerd voor maximale doorvoer op moderne serverhardware.\n\n'
        'In benchmarks verwerkte Firedancer meer dan een miljoen transacties per seconde op dedicated hardware — een orde van grootte meer dan de huidige Solana-client aankan. In de praktijk is de netwerkcapaciteit altijd lager dan de theoretische piekwaarde, maar de verbetering is aanzienlijk genoeg om Solana serieus te positioneren voor grootschalige toepassingen.\n\n'
        'De introductie van een tweede client is ook belangrijk voor de netwerkrobuustheid. Solana heeft in het verleden meerdere uitval-incidenten gehad waarbij een bug in de officiële client het hele netwerk lamlegde. Met twee onafhankelijke implementaties is dat risico kleiner: een bug in de ene client treft niet automatisch ook de andere.\n\n'
        'Firedancer draait momenteel op ongeveer 3% van de validators. Jump Crypto verwacht dit aandeel in de komende maanden te laten groeien naarmate meer validators de stabielere productieversie adopteren. De client is open source beschikbaar op GitHub.',
    url: 'https://jumpcrypto.com/firedancer/',
    category: 'crypto',
    timestamp: DateTime.now().subtract(const Duration(hours: 10)),
    source: 'The Block',
  ),

  // Podcasts
  NewsItem(
    id: '8',
    title: 'Lex Fridman interviewt Sam Altman over de toekomst van AGI',
    summary:
        'In een gesprek van ruim drie uur bespreekt Lex Fridman met OpenAI-CEO Sam Altman hoe de organisatie denkt over de ontwikkeling richting kunstmatige algemene intelligentie, welke veiligheidsmaatregelen er worden genomen, en hoe AI de samenleving fundamenteel zal veranderen.\n\n'
        'Altman is opvallend open over de interne spanningen bij OpenAI. Hij erkent dat de organisatiestructuur — een non-profit die een commerciële dochteronderneming aanstuurt — inherente spanning met zich meebrengt, maar verdedigt het model als de beste manier om zowel voldoende kapitaal op te halen als de missie veilig te bewaken.\n\n'
        'Het interessantste gedeelte gaat over de tijdlijn voor AGI. Altman herhaalt zijn eerdere uitspraak dat AGI "binnen ons bereik" is en schat dat systemen die de meeste kenniswerkers kunnen overtreffen al binnen vijf jaar beschikbaar zijn. Fridman dringt aan op concretere definities, maar Altman blijft opzettelijk vaag — vermoedelijk om verwachtingen te managen.\n\n'
        'Een aanrader voor iedereen die de filosofie en het zelfbeeld van de meest invloedrijke AI-organisatie ter wereld wil begrijpen. Het gesprek is beschikbaar op YouTube, Spotify en Apple Podcasts.',
    url: 'https://lexfridman.com/sam-altman-3/',
    category: 'podcasts',
    timestamp: DateTime.now().subtract(const Duration(hours: 4)),
    source: 'Lex Fridman Podcast',
  ),
  NewsItem(
    id: '9',
    title: 'Software Engineering Daily: Rust in productie bij grote bedrijven',
    summary:
        'In deze aflevering van Software Engineering Daily vertellen ingenieurs van Microsoft, Google en Amazon over hun ervaringen met Rust in productiesystemen. Het gesprek is technisch maar toegankelijk, en geeft een realistisch beeld van zowel de voordelen als de uitdagingen van Rust op grote schaal.\n\n'
        'De Microsoft-ingenieur beschrijft hoe het Windows-team delen van de kernel begint te herschrijven in Rust, na jarenlange beveiligingsproblemen met C en C++. Meer dan 70% van de kritieke kwetsbaarheden in Windows zijn geheugenbeheerproblemen — precies het type bugs dat Rust door zijn ownership-systeem voorkomt.\n\n'
        'De Google-ingenieur focust op Rust in de Android-codebase. Google heeft twee jaar geleden Rust aangewezen als voorkeurstaal voor nieuwe systeemcode in Android, en rapporteert een significante daling in geheugen-gerelateerde kwetsbaarheden in de nieuwste Android-versies.\n\n'
        'Amazon bespreekt het gebruik van Rust in AWS-infrastructuur, met name in Firecracker — de microVM-technologie achter AWS Lambda. De leercurve blijft een terugkerend thema: alle drie de bedrijven benadrukken dat onboarding van Rust meer tijd kost dan andere talen, maar dat de investering zich terugbetaalt in minder kwetsbaarheden en minder debugging.',
    url: 'https://softwareengineeringdaily.com/rust-production',
    category: 'podcasts',
    timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    source: 'Software Engineering Daily',
  ),
  NewsItem(
    id: '10',
    title: 'CoRecursive: De geschiedenis van Git met Linus Torvalds',
    summary:
        'Adam Gordon Bell heeft een zeldzaam gesprek gevoerd met Linus Torvalds over de oorsprong van Git. Torvalds staat niet bekend om zijn mediavriendelijkheid, maar in dit interview is hij verrassend open en geestig over de twee weken waarin hij Git schreef, in april 2005.\n\n'
        'De directe aanleiding was de breuk tussen de Linux-kernelontwikkelaars en BitKeeper. Toen de gratis licentie werd ingetrokken, besloot Torvalds — gefrustreerd door alle bestaande alternatieven — zijn eigen systeem te schrijven. Zijn vereisten waren radicaal: het moest snel zijn, gedistribueerd, en de integriteit van de codebase moest cryptografisch afdwingbaar zijn.\n\n'
        'Torvalds vertelt openhartig over beslissingen die hij achteraf anders zou nemen. De naamgeving van commando\'s en een paar interne datastructuren zijn dingen die hem nog steeds storen. Maar de basisarchitectuur — de content-addressable object store — beschouwt hij als juist en tijdloos.\n\n'
        'Bijzonder is het gedeelte over de adoptie: Torvalds had verwacht dat Git een niche-tool zou blijven voor de Linux-kernel. De explosieve verspreiding naar vrijwel elk softwareproject ter wereld heeft hem verrast. De populariteit van GitHub ziet hij met gemengde gevoelens: enorm nuttig, maar ook een zorgwekkende centralisatie van wat een gedistribueerd systeem is.',
    url: 'https://corecursive.com/git-linus-torvalds/',
    category: 'podcasts',
    timestamp: DateTime.now().subtract(const Duration(days: 2)),
    source: 'CoRecursive',
  ),

  // Software ontwikkeling
  NewsItem(
    id: '11',
    title: 'Rust 2024 Edition brengt nieuwe async-syntaxis en verbeterde ergonomie',
    summary:
        'De Rust 2024 Edition is officieel uitgebracht als onderdeel van Rust 1.85. Net als de edities van 2018 en 2021 introduceert de 2024 Edition geen nieuwe features, maar consolideert zij bestaande verbeteringen en maakt zij een aantal breaking changes mogelijk die de taal consistenter maken.\n\n'
        'De belangrijkste verandering betreft async programmeren. In de 2024 Edition zijn async closures stabiel geworden — een feature waar de community al jaren op wacht. Async closures maken het aanzienlijk makkelijker om hogere-orde functies te schrijven die asynchroon gedrag accepteren, wat terugkerende boilerplate in async Rust sterk vermindert.\n\n'
        'Daarnaast introduceert de 2024 Edition strengere regels voor de borrow checker, specifiek rondom temporaire waarden in match-expressies. Dit breekt een kleine hoeveelheid bestaande code, maar dicht een klasse van subtiele bugs die lastig te debuggen waren.\n\n'
        'De migratie vanuit Rust 2021 is grotendeels geautomatiseerd: `cargo fix --edition` handelt de meeste aanpassingen af. Voor de meeste projecten zal de migratie minder dan een uur duren. De Rust-gemeenschap heeft de traditie om edities backwards-compatibel te houden netjes voortgezet.',
    url: 'https://blog.rust-lang.org/2024/10/17/Rust-2024.html',
    category: 'software',
    timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    source: 'Rust Blog',
  ),
  NewsItem(
    id: '12',
    title: 'Flutter 3.27 verbetert performantie op Android en voegt Wasm-ondersteuning toe',
    summary:
        'Google heeft Flutter 3.27 uitgebracht, de grootste release van het afgelopen jaar. De twee meest opvallende veranderingen zijn de stabiele introductie van de Impeller rendering engine op Android en experimentele WebAssembly-ondersteuning voor het webplatform.\n\n'
        'Impeller vervangt de oude Skia-gebaseerde rendering pipeline. Op iOS was Impeller al de standaard sinds Flutter 3.10; Android volgde later vanwege de grotere variëteit in GPU-drivers. Impeller compileert shaders vooraf in plaats van tijdens het draaien van de app, wat jank vrijwel elimineert. In benchmarks is de gemiddelde framerate 12% hoger dan met de Skia-backend.\n\n'
        'De WebAssembly-ondersteuning is experimenteel maar veelbelovend. Flutter-apps die naar Wasm compileren laden gemiddeld 40% sneller dan de JavaScript-variant, en draaien merkbaar vloeiender. De Dart-runtime in Wasm maakt garbage collection goedkoper en biedt betere integratie met de browser-sandbox.\n\n'
        'Verder zijn er verbeteringen aan de Material 3-widgetbibliotheek, betere ondersteuning voor adaptieve layouts op tablets, en een snellere hot reload op grote projecten. De release bevat ook bijna driehonderd bugfixes, waarvan een twintigtal kritisch voor productietoepassingen.',
    url: 'https://medium.com/flutter/flutter-3-27',
    category: 'software',
    timestamp: DateTime.now().subtract(const Duration(hours: 7)),
    source: 'Flutter Medium Blog',
  ),
  NewsItem(
    id: '13',
    title: 'TypeScript 5.7 introduceert verbeterde type-inferentie voor generics',
    summary:
        'Microsoft heeft TypeScript 5.7 uitgebracht, met als meest opvallende verbetering een grondig herzien inferentiesysteem voor complexe generische types. Wie wel eens het cryptische foutbericht "Type instantiation is excessively deep and possibly infinite" heeft gezien, zal blij zijn: in veel van die gevallen slaagt de compiler nu wel.\n\n'
        'De verbetering komt van een herwerking van het type-inferentie-algoritme, dat nu efficiënter omgaat met recursieve en conditionele types. Dit is relevant voor codebases die sterk getyped werken met generics, zoals veel ORM-bibliotheken, state management-oplossingen en validatiebibliotheken.\n\n'
        'Naast de inferentieverbetering heeft TypeScript 5.7 ook betere foutmeldingen. De compiler geeft nu in meer gevallen een concrete suggestie naast de foutmelding — een feature die developers die van Rust of Elm komen al jaren misten. Intern zijn ook optimalisaties doorgevoerd die de compilertijd op grote codebases met gemiddeld 17% verlagen en het geheugengebruik met 20% reduceren.\n\n'
        'Een kleinere maar welkome toevoeging is de mogelijkheid om `import type` te gebruiken in JSDoc-commentaren, wat betere type-checking geeft in JavaScript-projecten die TypeScript alleen als linter gebruiken. De release is volledig backwards-compatibel met TypeScript 5.6.',
    url: 'https://devblogs.microsoft.com/typescript/announcing-typescript-5-7/',
    category: 'software',
    timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
    source: 'Microsoft Dev Blog',
  ),
];
