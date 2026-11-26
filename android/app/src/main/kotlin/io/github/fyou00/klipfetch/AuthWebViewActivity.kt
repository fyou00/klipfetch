package io.github.fyou00.klipfetch

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Bundle
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import java.util.Locale

class AuthWebViewActivity : Activity() {

    companion object {
        const val EXTRA_PLATFORM = "platform"
        const val EXTRA_LOGIN_URL = "loginUrl"
        const val EXTRA_COOKIE_URLS = "cookieUrls"
        const val EXTRA_AUTH_COOKIE_NAMES = "authCookieNames"

        const val RESULT_NETSCAPE_COOKIES = "netscapeCookies"
        const val RESULT_COOKIE_COUNT = "cookieCount"
        const val RESULT_HAS_AUTH_COOKIE = "hasAuthCookie"

        private const val CHROME_MOBILE_USER_AGENT =
            "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 " +
                "(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"

        private val KNOWN_HTTP_ONLY_NAMES = setOf(
            "sessionid",
            "sid_tt",
            "sessionid_ss",
            "uid_tt",
            "s_v_web_id",
            "sapisid",
            "sid",
            "hsid",
            "ssid",
            "apisid",
            "login_info",
            "__secure-1psid",
            "__secure-3psid",
            "rur",
            "mid",
            "ig_did",
            "ds_user_id",
        )
    }

    private lateinit var webView: WebView
    private lateinit var progressBar: ProgressBar
    private lateinit var statusView: TextView
    private lateinit var cookieUrls: List<String>
    private lateinit var authCookieNames: Set<String>
    private var platformLabel: String = "Platform"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val rawPlatform = intent.getStringExtra(EXTRA_PLATFORM) ?: "platform"
        platformLabel = when (rawPlatform.lowercase(Locale.US)) {
            "instagram" -> "Instagram"
            "tiktok" -> "TikTok"
            "youtube" -> "YouTube"
            else -> rawPlatform.replaceFirstChar { it.titlecase(Locale.US) }
        }
        val loginUrl = intent.getStringExtra(EXTRA_LOGIN_URL) ?: "https://www.instagram.com/"
        cookieUrls = intent.getStringArrayListExtra(EXTRA_COOKIE_URLS)
            ?.filter { it.isNotBlank() }
            ?.ifEmpty { listOf(loginUrl) }
            ?: listOf(loginUrl)
        authCookieNames = intent.getStringArrayListExtra(EXTRA_AUTH_COOKIE_NAMES)
            ?.map { it.trim().lowercase(Locale.US) }
            ?.toSet()
            ?: emptySet()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#F5F2EC"))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }

        WindowCompat.getInsetsController(window, root).isAppearanceLightStatusBars = true

        ViewCompat.setOnApplyWindowInsetsListener(root) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }

        val toolbar = buildToolbar()
        val toolbarDivider = View(this).apply {
            setBackgroundColor(Color.parseColor("#E4DDD3"))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(1),
            )
        }
        progressBar = ProgressBar(
            this,
            null,
            android.R.attr.progressBarStyleHorizontal,
        ).apply {
            max = 100
            progress = 0
            visibility = View.GONE
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(3),
            )
        }

        webView = WebView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f,
            )
        }

        configureWebView(webView)

        root.addView(toolbar)
        root.addView(toolbarDivider)
        root.addView(progressBar)
        root.addView(webView)
        setContentView(root)

        webView.loadUrl(loginUrl)
    }

    private fun buildToolbar(): LinearLayout {
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.parseColor("#FFFCF7"))
            setPadding(dp(8), dp(8), dp(10), dp(8))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        }

        val closeBtn = Button(this).apply {
            text = "Close"
            isAllCaps = false
            background = null
            setTextColor(Color.parseColor("#5F5852"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(dp(8), dp(6), dp(8), dp(6))
            minWidth = 0
            minimumWidth = 0
            setOnClickListener {
                setResult(RESULT_CANCELED)
                finish()
            }
        }

        val titleCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(6), 0, dp(6), 0)
            layoutParams = LinearLayout.LayoutParams(
                0,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                1f,
            )
        }

        val titleView = TextView(this).apply {
            text = "Sign in to $platformLabel"
            setTextColor(Color.parseColor("#1B1816"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            typeface = Typeface.DEFAULT_BOLD
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }

        statusView = TextView(this).apply {
            text = "Log in, then tap Save Session"
            setTextColor(Color.parseColor("#5F5852"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
        }

        titleCol.addView(titleView)
        titleCol.addView(statusView)

        val reloadBtn = Button(this).apply {
            text = "Reload"
            isAllCaps = false
            background = null
            setTextColor(Color.parseColor("#5F5852"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(dp(8), dp(6), dp(8), dp(6))
            minWidth = 0
            minimumWidth = 0
            setOnClickListener {
                webView.reload()
            }
        }

        val saveBackground = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(18).toFloat()
            setColor(Color.parseColor("#BF3909"))
        }

        val saveBtn = Button(this).apply {
            text = "Save Session"
            isAllCaps = false
            background = saveBackground
            setTextColor(Color.parseColor("#FFFDF9"))
            typeface = Typeface.DEFAULT_BOLD
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setPadding(dp(14), dp(6), dp(14), dp(6))
            minHeight = dp(36)
            minimumHeight = dp(36)
            setOnClickListener {
                captureAndReturnCookies()
            }
        }

        bar.addView(closeBtn)
        bar.addView(titleCol)
        bar.addView(reloadBtn)
        bar.addView(saveBtn)
        return bar
    }

    @Suppress("SetJavaScriptEnabled")
    private fun configureWebView(view: WebView) {
        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        cookieManager.setAcceptThirdPartyCookies(view, true)

        view.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            useWideViewPort = true
            loadWithOverviewMode = true
            userAgentString = CHROME_MOBILE_USER_AGENT
        }

        view.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                if (newProgress in 1..99) {
                    progressBar.visibility = View.VISIBLE
                    progressBar.progress = newProgress
                } else {
                    progressBar.visibility = View.GONE
                }
            }
        }

        view.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?,
            ): Boolean {
                val url = request?.url ?: return false
                val scheme = url.scheme?.lowercase(Locale.US)
                // Keep auth navigation inside the embedded WebView and ignore external app schemes.
                return scheme != "http" && scheme != "https"
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                refreshDetectedSessionStatus()
            }
        }
    }

    private fun refreshDetectedSessionStatus() {
        val snapshot = collectCapturedCookies()
        if (snapshot.hasAuthCookie) {
            statusView.text = "Session detected (${snapshot.cookieCount} cookies), tap Save"
            statusView.setTextColor(Color.parseColor("#166E36"))
        } else if (snapshot.cookieCount > 0) {
            statusView.text = "${snapshot.cookieCount} cookies loaded, sign in then Save"
            statusView.setTextColor(Color.parseColor("#8A5300"))
        }
    }

    private fun captureAndReturnCookies() {
        val cookieManager = CookieManager.getInstance()
        cookieManager.flush()
        val snapshot = collectCapturedCookies()
        val data = Intent().apply {
            putExtra(RESULT_NETSCAPE_COOKIES, snapshot.netscapeContent)
            putExtra(RESULT_COOKIE_COUNT, snapshot.cookieCount)
            putExtra(RESULT_HAS_AUTH_COOKIE, snapshot.hasAuthCookie)
        }
        setResult(RESULT_OK, data)
        finish()
    }

    private data class CapturedCookieSnapshot(
        val netscapeContent: String,
        val cookieCount: Int,
        val hasAuthCookie: Boolean,
    )

    private data class NetscapeCookieKey(
        val domain: String,
        val name: String,
    )

    private data class NetscapeCookieRecord(
        val domain: String,
        val name: String,
        val value: String,
        val httpOnly: Boolean,
    )

    private fun collectCapturedCookies(): CapturedCookieSnapshot {
        val cookieManager = CookieManager.getInstance()
        val targetUrls = LinkedHashSet<String>(cookieUrls.size + 2).apply {
            addAll(cookieUrls)
            webView.url?.takeIf { it.startsWith("http://") || it.startsWith("https://") }?.let {
                add(it)
            }
        }

        val collected = LinkedHashMap<NetscapeCookieKey, NetscapeCookieRecord>()
        var hasAuthCookie = false

        for (rawUrl in targetUrls) {
            val host = Uri.parse(rawUrl).host?.lowercase(Locale.US) ?: continue
            val domain = canonicalNetscapeDomain(host)
            val rawHeader = cookieManager.getCookie(rawUrl) ?: continue
            for (pair in rawHeader.split(';')) {
                val eq = pair.indexOf('=')
                if (eq <= 0) continue
                val name = pair.substring(0, eq).trim()
                val value = pair.substring(eq + 1).trim()
                if (name.isEmpty()) continue
                val lowerName = name.lowercase(Locale.US)
                val isAuth = authCookieNames.contains(lowerName)
                if (isAuth) {
                    hasAuthCookie = true
                }
                val isHttpOnly = isAuth || KNOWN_HTTP_ONLY_NAMES.contains(lowerName)
                val key = NetscapeCookieKey(domain = domain, name = name)
                collected[key] = NetscapeCookieRecord(
                    domain = domain,
                    name = name,
                    value = value,
                    httpOnly = isHttpOnly,
                )
            }
        }

        val lines = StringBuilder("# Netscape HTTP Cookie File\n")
        for (record in collected.values) {
            val domainField = if (record.httpOnly) {
                "#HttpOnly_${record.domain}"
            } else {
                record.domain
            }
            lines.append(domainField)
                .append('\t')
                .append("TRUE")
                .append('\t')
                .append("/")
                .append('\t')
                .append("TRUE")
                .append('\t')
                .append("2147483647")
                .append('\t')
                .append(record.name)
                .append('\t')
                .append(record.value)
                .append('\n')
        }

        return CapturedCookieSnapshot(
            netscapeContent = lines.toString(),
            cookieCount = collected.size,
            hasAuthCookie = hasAuthCookie,
        )
    }

    private fun canonicalNetscapeDomain(host: String): String {
        val clean = host.trimStart('.')
        return when {
            clean == "instagram.com" || clean.endsWith(".instagram.com") -> ".instagram.com"
            clean == "cdninstagram.com" || clean.endsWith(".cdninstagram.com") -> ".cdninstagram.com"
            clean == "tiktok.com" || clean.endsWith(".tiktok.com") -> ".tiktok.com"
            clean == "tiktokv.com" || clean.endsWith(".tiktokv.com") -> ".tiktokv.com"
            clean == "youtube.com" || clean.endsWith(".youtube.com") -> ".youtube.com"
            clean == "google.com" || clean.endsWith(".google.com") -> ".google.com"
            else -> ".$clean"
        }
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics,
        ).toInt()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK && webView.canGoBack()) {
            webView.goBack()
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onDestroy() {
        webView.stopLoading()
        webView.destroy()
        super.onDestroy()
    }
}
