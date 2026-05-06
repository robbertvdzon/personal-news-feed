package com.vdzon.newsfeedbackend.service

import org.slf4j.LoggerFactory
import org.springframework.http.client.SimpleClientHttpRequestFactory
import org.springframework.stereotype.Service
import org.springframework.web.client.RestClient
import org.w3c.dom.Element
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.stream.Stream
import javax.xml.parsers.DocumentBuilderFactory

@Service
class RssFetchService {
    private val log = LoggerFactory.getLogger(RssFetchService::class.java)

    private val client: RestClient by lazy {
        val factory = SimpleClientHttpRequestFactory().apply {
            setConnectTimeout(10_000)
            setReadTimeout(30_000)
        }
        RestClient.builder().requestFactory(factory).build()
    }

    /** Haalt alle feeds parallel op en combineert de artikelen */
    fun fetchAll(feedUrls: List<String>): List<TavilySearchResult> {
        if (feedUrls.isEmpty()) return emptyList()
        return feedUrls.parallelStream()
            .flatMap { url ->
                try {
                    val items = fetchFeed(url)
                    log.info("RSS feed '{}': {} artikelen", url, items.size)
                    items.stream()
                } catch (e: Exception) {
                    log.warn("RSS ophalen mislukt voor '{}': {}", url, e.message)
                    Stream.empty()
                }
            }
            .toList()
    }

    private fun fetchFeed(url: String): List<TavilySearchResult> {
        val xml = client.get().uri(url)
            .header("User-Agent", "Mozilla/5.0 (compatible; NewsFeedBot/1.0)")
            .retrieve()
            .body(String::class.java) ?: return emptyList()

        val source = extractDomain(url)
        val factory = DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }
        val doc = factory.newDocumentBuilder().parse(xml.byteInputStream())
        doc.documentElement.normalize()

        return when (val rootTag = doc.documentElement.localName ?: doc.documentElement.tagName) {
            "rss"  -> parseRss(doc, source)
            "feed" -> parseAtom(doc, source)
            "RDF"  -> parseRss(doc, source)  // RSS 1.0
            else   -> { log.warn("Onbekend feed formaat '{}' voor '{}'", rootTag, url); emptyList() }
        }
    }

    // ── RSS 2.0 ───────────────────────────────────────────────────────────────

    private fun parseRss(doc: org.w3c.dom.Document, source: String): List<TavilySearchResult> {
        val items = doc.getElementsByTagName("item")
        return (0 until items.length).mapNotNull { i ->
            val item = items.item(i) as? Element ?: return@mapNotNull null
            val title = item.childText("title") ?: return@mapNotNull null
            val link  = item.childText("link")  ?: return@mapNotNull null
            if (!link.startsWith("http")) return@mapNotNull null
            val pubDate = item.childText("pubDate")?.let { parseRssDate(it) }
            val content = item.contentEncoded() ?: item.childText("description") ?: ""
            TavilySearchResult(
                title = title.trim(),
                url   = link.trim(),
                source = source,
                snippet = content.stripHtml().take(1000),
                publishedDate = pubDate
            )
        }
    }

    // ── Atom ──────────────────────────────────────────────────────────────────

    private fun parseAtom(doc: org.w3c.dom.Document, source: String): List<TavilySearchResult> {
        val entries = doc.getElementsByTagName("entry")
        return (0 until entries.length).mapNotNull { i ->
            val entry = entries.item(i) as? Element ?: return@mapNotNull null
            val title = entry.childText("title") ?: return@mapNotNull null
            val link  = entry.atomLink() ?: return@mapNotNull null
            if (!link.startsWith("http")) return@mapNotNull null
            val pubDate = (entry.childText("published") ?: entry.childText("updated"))
                ?.let { parseAtomDate(it) }
            val content = entry.childText("content") ?: entry.childText("summary") ?: ""
            TavilySearchResult(
                title = title.trim(),
                url   = link.trim(),
                source = source,
                snippet = content.stripHtml().take(1000),
                publishedDate = pubDate
            )
        }
    }

    // ── DOM helpers ───────────────────────────────────────────────────────────

    private fun Element.childText(tag: String): String? {
        val nodes = getElementsByTagName(tag)
        if (nodes.length == 0) return null
        return nodes.item(0)?.textContent?.trim()?.takeIf { it.isNotEmpty() }
    }

    private fun Element.contentEncoded(): String? {
        var nodes = getElementsByTagNameNS("http://purl.org/rss/1.0/modules/content/", "encoded")
        if (nodes.length == 0) nodes = getElementsByTagName("content:encoded")
        return nodes.item(0)?.textContent?.trim()?.takeIf { it.isNotEmpty() }
    }

    private fun Element.atomLink(): String? {
        val links = getElementsByTagName("link")
        // Voorkeur: rel=alternate of geen rel
        for (i in 0 until links.length) {
            val el   = links.item(i) as? Element ?: continue
            val rel  = el.getAttribute("rel")
            val href = el.getAttribute("href")
            if (href.isNotEmpty() && (rel.isEmpty() || rel == "alternate")) return href
        }
        // Fallback: elke link met href
        for (i in 0 until links.length) {
            val el   = links.item(i) as? Element ?: continue
            val href = el.getAttribute("href")
            if (href.isNotEmpty()) return href
        }
        // Fallback RSS: tekst-node
        for (i in 0 until links.length) {
            val text = links.item(i)?.textContent?.trim()
            if (!text.isNullOrEmpty() && text.startsWith("http")) return text
        }
        return null
    }

    // ── Datum parseren ────────────────────────────────────────────────────────

    private val rssDateFormats = listOf(
        "EEE, dd MMM yyyy HH:mm:ss z",   // Tue, 06 May 2026 10:00:00 GMT
        "EEE, dd MMM yyyy HH:mm:ss Z",   // Tue, 06 May 2026 10:00:00 +0000
        "EEE, d MMM yyyy HH:mm:ss z",    // Tue, 6 May 2026 10:00:00 GMT  (enkele dag)
        "EEE, d MMM yyyy HH:mm:ss Z",    // Tue, 6 May 2026 10:00:00 +0000
        "dd MMM yyyy HH:mm:ss z",        // 06 May 2026 10:00:00 GMT
        "dd MMM yyyy HH:mm:ss Z",        // 06 May 2026 10:00:00 +0000
        "d MMM yyyy HH:mm:ss z",         // 6 May 2026 10:00:00 GMT
        "d MMM yyyy HH:mm:ss Z",         // 6 May 2026 10:00:00 +0000
    ).map { DateTimeFormatter.ofPattern(it, Locale.ENGLISH) }

    private fun parseRssDate(date: String): String? {
        val clean = date.trim()
        for (fmt in rssDateFormats) {
            try {
                return OffsetDateTime.parse(clean, fmt)
                    .withOffsetSameInstant(ZoneOffset.UTC).toLocalDate().toString()
            } catch (_: Exception) {}
        }
        // Fallback: zoek YYYY-MM-DD patroon in de string
        return Regex("""\d{4}-\d{2}-\d{2}""").find(clean)?.value
    }

    private fun parseAtomDate(date: String): String? = try {
        OffsetDateTime.parse(date.trim()).withOffsetSameInstant(ZoneOffset.UTC).toLocalDate().toString()
    } catch (_: Exception) {
        date.take(10).takeIf { it.matches(Regex("""\d{4}-\d{2}-\d{2}""")) }
    }

    // ── String helpers ────────────────────────────────────────────────────────

    private fun String.stripHtml(): String =
        replace(Regex("<[^>]*>"), " ")
            .replace("&nbsp;", " ").replace("&amp;", "&")
            .replace("&lt;", "<").replace("&gt;", ">")
            .replace("&quot;", "\"").replace(Regex("&#\\d+;"), "")
            .replace(Regex("\\s+"), " ").trim()

    private fun extractDomain(url: String): String = try {
        java.net.URI(url).host?.removePrefix("www.") ?: url
    } catch (_: Exception) { url }
}
