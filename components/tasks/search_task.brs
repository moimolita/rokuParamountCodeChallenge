' ─── Lifecycle ───────────────────────────────────────────────────────────────

'**
'* @description Registers the function Roku runs when the task is set to control="RUN".
'* @sideeffect Sets m.top.functionName.
'*
sub init()
    m.top.functionName = "executeSearch"
end sub

' ─── Network ──────────────────────────────────────────────────────────────────

'**
'* @description Runs on the task thread: fetches a page of OMDb search results,
'*              parses them, and publishes totalResults + a movie_item tree (or an error).
'* @sideeffect Writes m.top.totalResults, m.top.results, and m.top.error.
'*
sub executeSearch()
    request = createObject("roUrlTransfer")

    ' SSL — required for HTTPS, or the request fails silently.
    request.setCertificatesFile("common:/certs/ca-bundle.crt")
    request.initClientCertificates()

    ' Build the OMDb search URL. escape() URL-encodes the query (spaces, etc.).
    query = request.escape(m.top.query)
    url = Const().OMDB_BASE_URL + "?apikey=" + Const().OMDB_API_KEY + "&s=" + query + "&page=" + m.top.page.toStr()
    request.setUrl(url)

    ' GET with an explicit timeout. A blocking getToString() has no timeout and can
    ' hang forever with no network; this always returns within the timeout.
    rawResponse = httpGetWithTimeout(request, Const().HTTP_TIMEOUT_MS)

    ' NETWORK error — empty response means the request failed or timed out.
    if rawResponse = "" or rawResponse = invalid
        m.top.totalResults = 0
        m.top.error = "network"
        m.top.results = createObject("roSGNode", "ContentNode")
        return
    end if

    parsed = parseJSON(rawResponse)

    ' NO RESULTS / bad response — OMDb reports failure in "Response" ("False").
    if parsed = invalid or parsed["Response"] <> "True"
        m.top.totalResults = 0
        m.top.error = "no_results"
        m.top.results = createObject("roSGNode", "ContentNode")
        return
    end if

    ' SUCCESS — clear any previous error. OMDb returns totalResults as a STRING;
    ' convert to integer and set it BEFORE results so the observer sees it.
    m.top.error = ""
    if parsed["totalResults"] <> invalid
        m.top.totalResults = parsed["totalResults"].toInt()
    else
        m.top.totalResults = 0
    end if

    m.top.results = buildMovieNodes(parsed)
end sub

' ─── Helpers ──────────────────────────────────────────────────────────────────

'**
'* @description Builds a ContentNode tree of movie_item nodes from a parsed OMDb
'*              response. Plot/rating are left empty (filled later by the detail fetch).
'* @param {Object} parsed Parsed OMDb JSON, or invalid.
'* @returns {roSGNode} ContentNode with movie_item children (empty on bad response).
'*
function buildMovieNodes(parsed as object) as object
    content = createObject("roSGNode", "ContentNode")

    if parsed = invalid then return content
    if parsed["Response"] <> "True" then return content

    for each result in parsed["Search"]
        item = createObject("roSGNode", "movie_item")
        item.title      = result["Title"]
        item.year       = result["Year"]
        item.imdb_id    = result["imdbID"]
        item.poster_url = result["Poster"]
        item.plot       = ""      ' not in the search endpoint — filled by detail fetch
        item.rating     = "N/A"   ' not in the search endpoint — filled by detail fetch
        content.appendChild(item)
    end for

    return content
end function

'**
'* @description HTTP GET with an explicit timeout. Uses asyncGetToString() + wait()
'*              so the call always returns within timeoutMs (cancels on timeout).
'* @param {Object} request A configured roUrlTransfer (url + SSL already set).
'* @param {Integer} timeoutMs Max milliseconds to wait for the response.
'* @returns {String} The response body, or "" on failure/timeout.
'*
function httpGetWithTimeout(request as object, timeoutMs as integer) as string
    port = createObject("roMessagePort")
    request.setMessagePort(port)

    if request.asyncGetToString() = false then return ""

    msg = wait(timeoutMs, port)
    if type(msg) = "roUrlEvent" then return msg.getString()

    ' Timed out — cancel and report empty.
    request.asyncCancel()
    return ""
end function
