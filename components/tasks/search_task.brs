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
'*              Uses exponential backoff retry strategy to handle transient network failures.
'* @sideeffect Writes m.top.totalResults, m.top.results, and m.top.error.
'*
sub executeSearch()
    ' Build the OMDb search URL. escape() URL-encodes the query (spaces, etc.).
    transfer = createObject("roUrlTransfer")
    query = transfer.escape(m.top.query)
    url = Const().OMDB_BASE_URL + "?apikey=" + Const().OMDB_API_KEY + "&s=" + query + "&page=" + m.top.page.toStr()

    ' Fetch with exponential backoff retry (3 attempts: 1s, 2s, 4s delay)
    rawResponse = httpGetWithRetry(url, 3, 1.0)

    ' NETWORK error — empty response means all retries failed.
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
        item = createObject("roSGNode", "MovieItem")
        item.title      = result["Title"]
        item.year       = result["Year"]
        item.imdbId     = result["imdbID"]
        item.posterUrl  = result["Poster"]
        item.plot       = ""      ' not in the search endpoint — filled by detail fetch
        item.rating     = "N/A"   ' not in the search endpoint — filled by detail fetch
        content.appendChild(item)
    end for

    return content
end function
