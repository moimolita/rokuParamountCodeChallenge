' ─── Lifecycle ───────────────────────────────────────────────────────────────

'**
'* @description Registers the function Roku runs when the task is set to control="RUN".
'* @sideeffect Sets m.top.functionName.
'*
sub init()
    m.top.functionName = "fetchDetail"
end sub

' ─── Network ──────────────────────────────────────────────────────────────────

'**
'* @description Runs on the task thread: fetches full detail (plot + rating) for one
'*              movie via the OMDb detail endpoint (?i={imdbID}&plot=full).
'* @sideeffect Writes m.top.plot and m.top.rating.
'*
sub fetchDetail()
    request = createObject("roUrlTransfer")

    ' SSL — required for HTTPS, or the request fails silently.
    request.setCertificatesFile("common:/certs/ca-bundle.crt")
    request.initClientCertificates()

    ' Detail endpoint: i={imdbID}&plot=full returns Plot + imdbRating.
    id = request.escape(m.top.imdb_id)
    url = Const().OMDB_BASE_URL + "?apikey=" + Const().OMDB_API_KEY + "&i=" + id + "&plot=full"
    request.setUrl(url)

    rawResponse = request.getToString()
    parsed = parseJSON(rawResponse)

    ' Guard — bad JSON or failed API response. Leave outputs at their defaults.
    if parsed = invalid then return
    if parsed["Response"] <> "True" then return

    ' sanitize() turns OMDb's "N/A" into a friendly fallback.
    m.top.plot   = sanitize(parsed["Plot"], "No plot available.")
    m.top.rating = sanitize(parsed["imdbRating"], "N/A")
end sub

' ─── Helpers ──────────────────────────────────────────────────────────────────

'**
'* @description Normalizes an OMDb field value: "N/A" or invalid → the fallback.
'* @param {Dynamic} value Raw field value from the OMDb JSON.
'* @param {String} fallback Value to return when the field is "N/A" or missing.
'* @returns {String} The value, or the fallback.
'*
function sanitize(value as dynamic, fallback as string) as string
    if value = invalid then return fallback
    if value = "N/A" then return fallback
    return value
end function
