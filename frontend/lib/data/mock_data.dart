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
        'Anthropic heeft een nieuwe versie van zijn Claude-model uitgebracht die significant beter presteert op complexe redeneer- en wiskundetaken. Het model scoort hoger dan GPT-4o op meerdere standaardbenchmarks en is direct beschikbaar via de API.',
    url: 'https://www.anthropic.com/news/claude-3-5-sonnet',
    category: 'ai',
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    source: 'Anthropic Blog',
  ),
  NewsItem(
    id: '2',
    title: 'Google DeepMind onthult Gemini 2.0 met multimodale mogelijkheden',
    summary:
        'Google DeepMind heeft Gemini 2.0 aangekondigd, een model dat tekst, afbeeldingen, audio en video tegelijk kan verwerken. Het model is beschikbaar voor ontwikkelaars via Google AI Studio en ondersteunt een contextvenster van twee miljoen tokens.',
    url: 'https://deepmind.google/technologies/gemini/',
    category: 'ai',
    timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    source: 'Google DeepMind',
  ),
  NewsItem(
    id: '3',
    title: 'Meta open-sourct Llama 3.2 met verbeterde instructieopvolging',
    summary:
        'Meta heeft de broncode van Llama 3.2 vrijgegeven, inclusief modellen in verschillende groottes van 1B tot 90B parameters. De nieuwe versie presteert significant beter op het volgen van complexe instructies en is geoptimaliseerd voor gebruik op mobiele apparaten.',
    url: 'https://ai.meta.com/blog/llama-3-2/',
    category: 'ai',
    timestamp: DateTime.now().subtract(const Duration(hours: 8)),
    source: 'Meta AI Blog',
  ),
  NewsItem(
    id: '4',
    title: 'OpenAI o3 behaalt menselijk niveau op ARC-AGI benchmark',
    summary:
        'Het nieuwe o3-model van OpenAI heeft voor het eerst de ARC-AGI benchmark op menselijk niveau behaald, een test die specifiek is ontworpen om te meten of AI generaliseerbaar kan redeneren. Dit wordt door onderzoekers gezien als een belangrijke mijlpaal richting algemene kunstmatige intelligentie.',
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
        'Het Ethereum-netwerk heeft de Pectra-hardfork succesvol afgerond. De upgrade introduceert EIP-7251 waardoor validators meer dan 32 ETH kunnen staken, en EIP-7702 dat accountabstractie voor gewone adressen mogelijk maakt. Dit vereenvoudigt gebruikerservaringen aanzienlijk.',
    url: 'https://ethereum.org/en/roadmap/pectra/',
    category: 'crypto',
    timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    source: 'Ethereum Foundation',
  ),
  NewsItem(
    id: '6',
    title: 'El Salvador breidt Bitcoin-wetgeving uit naar bedrijven',
    summary:
        'El Salvador heeft nieuwe regelgeving aangenomen die grote bedrijven verplicht Bitcoin te accepteren als betaalmiddel. Het land gebruikt de ervaringen uit de afgelopen drie jaar om het juridisch kader verder te verfijnen en wil een model worden voor andere landen.',
    url: 'https://www.nayibbukele.com',
    category: 'crypto',
    timestamp: DateTime.now().subtract(const Duration(hours: 6)),
    source: 'CoinDesk',
  ),
  NewsItem(
    id: '7',
    title: 'Solana introduceert Firedancer-client voor hogere doorvoer',
    summary:
        'Jump Crypto heeft de Firedancer-validator client voor Solana gelanceerd op mainnet. De nieuwe client kan tot 1 miljoen transacties per seconde verwerken, wat een grote stap vooruit is ten opzichte van de huidige capaciteit. Dit maakt Solana geschikter voor grootschalige applicaties.',
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
        'In een drieënhalf uur durend gesprek bespreekt Lex Fridman met OpenAI-CEO Sam Altman de ontwikkeling richting AGI, de veiligheidsuitdagingen, en hoe AI de samenleving zal veranderen. Een aanrader voor iedereen die de visie achter OpenAI wil begrijpen.',
    url: 'https://lexfridman.com/sam-altman-3/',
    category: 'podcasts',
    timestamp: DateTime.now().subtract(const Duration(hours: 4)),
    source: 'Lex Fridman Podcast',
  ),
  NewsItem(
    id: '9',
    title: 'Software Engineering Daily: Rust in productie bij grote bedrijven',
    summary:
        'In deze aflevering van Software Engineering Daily vertellen ingenieurs van Microsoft, Google en Amazon hoe zij Rust inzetten voor veiligheidskritische systemen. Ze bespreken de leercurve, tooling en de concrete voordelen die ze hebben ervaren in vergelijking met C++.',
    url: 'https://softwareengineeringdaily.com/rust-production',
    category: 'podcasts',
    timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    source: 'Software Engineering Daily',
  ),
  NewsItem(
    id: '10',
    title: 'CoRecursive: De geschiedenis van Git met Linus Torvalds',
    summary:
        'Adam Gordon Bell heeft een zeldzaam gesprek met Linus Torvalds over de oorsprong van Git, waarom hij het in twee weken bouwde, en welke ontwerpbeslissingen hij achteraf anders zou maken. Een bijzondere kans om de man achter zowel Linux als Git te horen.',
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
        'De Rust 2024 Edition is officieel uitgebracht met verbeteringen voor async programmeren, nieuwe patroonmatchingmogelijkheden en een verbeterde borrow checker. De migratie vanuit Rust 2021 is grotendeels geautomatiseerd via cargo fix.',
    url: 'https://blog.rust-lang.org/2024/10/17/Rust-2024.html',
    category: 'software',
    timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    source: 'Rust Blog',
  ),
  NewsItem(
    id: '12',
    title: 'Flutter 3.27 verbetert performantie op Android en voegt Wasm-ondersteuning toe',
    summary:
        'Google heeft Flutter 3.27 uitgebracht met aanzienlijke prestatieverbeteringen op Android dankzij de nieuwe Impeller rendering engine. Daarnaast is er experimentele ondersteuning voor WebAssembly, waarmee Flutter web-apps sneller laden en draaien.',
    url: 'https://medium.com/flutter/flutter-3-27',
    category: 'software',
    timestamp: DateTime.now().subtract(const Duration(hours: 7)),
    source: 'Flutter Medium Blog',
  ),
  NewsItem(
    id: '13',
    title: 'TypeScript 5.7 introduceert verbeterde type-inferentie voor generics',
    summary:
        'Microsoft heeft TypeScript 5.7 uitgebracht met een verbeterd inferentiesysteem voor complexe generics, betere foutmeldingen en een snellere compilertijd. De nieuwe versie verlaagt ook het geheugengebruik bij grote codebases met gemiddeld 20%.',
    url: 'https://devblogs.microsoft.com/typescript/announcing-typescript-5-7/',
    category: 'software',
    timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
    source: 'Microsoft Dev Blog',
  ),
];
