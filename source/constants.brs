' ─── Application constants (global) ──────────────────────────────────────────
' BrightScript has no `const` keyword; the standard pattern is a function returning
' an associative array of named values. Each consuming component must declare this
' script in its XML. Use as: Const().POSTER_GRID

'**
'* @description Returns the application's named constants (poster sizes, OMDb config,
'*              search tuning). Centralizes magic numbers/strings so they are defined once.
'* @returns {roAssociativeArray} Named constant values.
'*
function Const() as object
    return {
        OMDB_BASE_URL: "https://www.omdbapi.com/",   ' OMDb endpoint base
        OMDB_API_KEY:  "5f57a942",                   ' OMDb API key

        DEFAULT_QUERY: "batman",                     ' seeded on entry (empty query is rejected)
        MIN_QUERY_LEN: 3,                            ' min chars before querying OMDb

        POSTER_GRID:   200,                          ' poster width in the grid cards
        POSTER_PANE:   300,                          ' poster width in the detail pane
        POSTER_DETAIL: 514,                          ' poster width on the details screen

        PAGE_PRELOAD_THRESHOLD: 8,                   ' preload next page within N of the end
        HTTP_TIMEOUT_MS: 15000                       ' async search request timeout (ms)
    }
end function
