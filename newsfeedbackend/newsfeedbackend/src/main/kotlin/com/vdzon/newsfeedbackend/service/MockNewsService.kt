package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.NewsItem
import org.springframework.stereotype.Service
import java.time.Instant
import java.util.UUID

@Service
class MockNewsService {

    private val sampleArticles = listOf(
        NewsItem("", "Kotlin 2.2 brengt verbeterde K2 compiler", "De nieuwe K2 compiler in Kotlin 2.2 biedt tot 40% snellere compilatietijden en verbeterde type-inferentie. JetBrains heeft ook de null-safety checks aangescherpt zodat meer fouten al tijdens het compileren worden gevonden. Multiplatform-projecten profiteren het meest van de verbeteringen.", "https://kotlinlang.org/docs/whatsnew22.html", "kotlin", "", "Kotlin Blog"),
        NewsItem("", "Kotlin Coroutines 1.9 met structured concurrency verbeteringen", "De nieuwste versie van Kotlin Coroutines introduceert verbeterde cancellation-semantiek en een nieuwe SupervisorScope API. Developers kunnen nu eenvoudiger foutpropagatie beheren in complexe asynchrone flows. De performance overhead van coroutines is verder teruggebracht.", "https://github.com/Kotlin/kotlinx.coroutines", "kotlin", "", "GitHub Releases"),
        NewsItem("", "JetBrains Kotlin Multiplatform bereikt stabiele status", "Na jaren van ontwikkeling is Kotlin Multiplatform officieel stabiel verklaard. Teams kunnen nu zonder beperkingen code delen tussen Android, iOS, desktop en web. De tooling in IntelliJ IDEA en Android Studio is sterk verbeterd met betere code completion.", "https://kotlinlang.org/docs/multiplatform.html", "kotlin", "", "JetBrains"),
        NewsItem("", "Flutter 3.32 verbetert webprestaties significant", "Flutter Web krijgt in versie 3.32 een grote performance boost door verbeterd gebruik van WebAssembly. Scroll-animaties zijn vloeiender en de initiële laadtijd is gehalveerd dankzij lazy loading van widgets. Het Impeller-framework is nu standaard actief op alle platforms.", "https://flutter.dev/docs/release/release-notes", "flutter", "", "Flutter Dev"),
        NewsItem("", "Flutter Impeller renderer nu standaard op iOS en Android", "Het nieuwe Impeller grafisch systeem vervangt Skia als standaard renderer in Flutter. Gebruikers merken minder jank bij het eerste frame en soepelere animaties bij hoge frame rates. Ontwikkelaars hoeven niets aan te passen — de upgrade is automatisch.", "https://docs.flutter.dev/perf/impeller", "flutter", "", "Flutter Blog"),
        NewsItem("", "Riverpod 3.0 introduceert automatische state disposal", "De populaire Flutter state management library Riverpod heeft versie 3.0 uitgebracht. Nieuw is de automatische disposal van unused providers, waardoor memory leaks in long-running apps worden voorkomen. De migratie van 2.x is eenvoudig met de meegeleverde codemod.", "https://riverpod.dev", "flutter", "", "Riverpod Docs"),
        NewsItem("", "OpenAI GPT-5 haalt recordscores op coding benchmarks", "Het nieuwste model van OpenAI scoort 87% op de HumanEval coding benchmark en overtreft daarmee alle voorgaande modellen. De context window is vergroot naar 200K tokens, wat het geschikt maakt voor grote codebases. Developers melden een merkbare verbetering bij complexe refactoring-taken.", "https://openai.com/blog/gpt-5", "ai", "", "OpenAI Blog"),
        NewsItem("", "Anthropic Claude 3.7 Sonnet beschikbaar via API", "Claude 3.7 Sonnet biedt een nieuwe 'extended thinking' modus waarbij het model complexe problemen stap voor stap oplost. De nieuwe versie scoort sterk op wiskunde en logica-taken. De API-prijs is gelijk gebleven aan de vorige generatie.", "https://anthropic.com/news/claude-3-7-sonnet", "ai", "", "Anthropic"),
        NewsItem("", "Meta LLaMA 4 als open source beschikbaar gesteld", "Meta heeft LLaMA 4 uitgebracht als open-source model met 405 miljard parameters. Het model is vrij te gebruiken voor commerciële toepassingen en presteert vergelijkbaar met GPT-4 op standaard benchmarks. De community heeft al tientallen fine-tuned versies uitgebracht.", "https://llama.meta.com", "ai", "", "Meta AI"),
        NewsItem("", "Ethereum Pectra-upgrade succesvol geactiveerd", "De Pectra-upgrade van Ethereum is zonder problemen geactiveerd en brengt account abstraction naar het mainnet. Gas fees voor ERC-4337 transacties zijn met 30% gedaald. Wallets kunnen nu transacties sponsoren namens gebruikers, wat de UX sterk verbetert.", "https://ethereum.org/en/upgrades/pectra", "blockchain", "", "Ethereum.org"),
        NewsItem("", "Bitcoin ETF handelsvolume bereikt nieuw record", "De spot Bitcoin ETFs in de VS hadden samen een dagelijks handelsvolume van 8 miljard dollar, een nieuw record. Institutionele beleggers zoals pensioenfondsen verhogen hun allocatie naar digitale assets. Analisten verwachten dat het totale beheerde vermogen de 100 miljard dollar gaat overschrijden.", "https://coindesk.com/markets/bitcoin-etf-volume", "blockchain", "", "CoinDesk"),
        NewsItem("", "Solana verwerkt record 95.000 transacties per seconde", "Het Solana netwerk heeft een nieuw record gezet met 95.000 TPS tijdens een NFT mint event. De Firedancer validator client draagt bij aan de verbeterde stabiliteit. Ontwikkelaars migreren steeds vaker van Ethereum L2s naar Solana vanwege de lage transactiekosten.", "https://solana.com/news", "blockchain", "", "Solana Foundation"),
        NewsItem("", "Spring Boot 4.0 uitgebracht met Jakarta EE 11 ondersteuning", "Spring Boot 4.0 is officieel uitgebracht en vereist Java 17 als minimum. De migratie naar Jakarta EE 11 brengt verbeterde CDI-integratie en snellere opstarttijden. Virtual Threads via Project Loom zijn nu standaard ingeschakeld bij WebMVC applicaties.", "https://spring.io/blog/2025/spring-boot-4-0", "spring", "", "Spring Blog"),
        NewsItem("", "Spring AI 1.0 maakt Spring framework AI-klaar", "De officiële 1.0-release van Spring AI biedt een uniforme API voor OpenAI, Anthropic en lokale LLM-modellen. RAG-pipelines kunnen nu worden gebouwd met een fluent builder API. Integration tests met EmbeddedRedisServer voor vector stores zijn inbegrepen.", "https://spring.io/projects/spring-ai", "spring", "", "Spring.io"),
        NewsItem("", "Quarkus 3.10 verbetert native image grootte met 25%", "Quarkus heeft versie 3.10 uitgebracht met aanzienlijke verbeteringen aan GraalVM native images. De binary grootte is 25% kleiner dan vorige versie door dead code elimination. Startup tijd in containers is nu onder de 10ms bij de meeste standaard applicaties.", "https://quarkus.io/blog/quarkus-3-10", "spring", "", "Quarkus Blog"),
        NewsItem("", "React 19 Server Components nu stabiel", "React 19 brengt Server Components naar stable status, waarmee server-side rendering volledig geïntegreerd is in de componenttree. De nieuwe `use()` hook vereenvoudigt het werken met Promises. Next.js 15 maakt direct gebruik van alle nieuwe features.", "https://react.dev/blog/2024/12/05/react-19", "web_dev", "", "React Blog"),
        NewsItem("", "TypeScript 5.8 met verbeterde type inference", "TypeScript 5.8 introduceert 'infer' varianten voor template literal types en verbetert de inference in conditional types. Developers melden dat migratie van bestaande codebases eenvoudiger is geworden dankzij betere error messages. De compiler is 15% sneller bij grote projecten.", "https://devblogs.microsoft.com/typescript/announcing-typescript-5-8", "web_dev", "", "Microsoft Dev Blog"),
        NewsItem("", "CSS Grid Level 3 goedgekeurd als W3C standaard", "Het W3C heeft CSS Grid Level 3 goedgekeurd, inclusief masonry layout ondersteuning. Firefox en Chrome hebben al experimentele implementaties beschikbaar. Designers kunnen nu complexe magazine-achtige layouts maken zonder JavaScript polyfills.", "https://www.w3.org/TR/css-grid-3", "web_dev", "", "W3C")
    )

    fun fetchArticlesForSubject(subject: String, count: Int): List<NewsItem> {
        // Simuleer 20 seconden ophalen/verwerken
        Thread.sleep(20_000)

        val now = Instant.now().toString()
        return sampleArticles
            .shuffled()
            .take(count)
            .map { template ->
                template.copy(
                    id = UUID.randomUUID().toString(),
                    timestamp = now
                )
            }
    }

    fun fetchDailyNews(): List<NewsItem> {
        val now = Instant.now().toString()
        return sampleArticles.map { template ->
            template.copy(
                id = UUID.randomUUID().toString(),
                timestamp = now
            )
        }
    }
}
