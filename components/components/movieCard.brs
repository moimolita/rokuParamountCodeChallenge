' ─── Lifecycle ───────────────────────────────────────────────────────────────

'**
'* @description Resolves node references and observes itemContent for data binding.
'* @sideeffect Stores m.poster, m.title, m.year. Registers a scoped observer.
'*
function init()
    m.poster = m.top.findNode("poster")
    m.title  = m.top.findNode("title")
    m.year   = m.top.findNode("year")

    ' MarkupGrid sets itemContent on each card AFTER instantiation, so we observe it
    ' here. Scoped: cards are recycled on scroll — scoped observers auto-remove on
    ' recycle, preventing ghost callbacks.
    m.top.observeFieldScoped("itemContent", "onMovieChanged")
end function

' ─── Field Observer ───────────────────────────────────────────────────────────

'**
'* @description Fired when MarkupGrid assigns a MovieItem. Binds poster/title/year.
'* @param {roAssociativeArray} obj Field change event; obj.getData() is the MovieItem.
'* @sideeffect Updates m.poster.uri, m.title.text, m.year.text.
'*
sub onMovieChanged(obj)
    movie = obj.getData()

    ' Guard against invalid data or node refs not ready.
    if movie = invalid then return
    if m.poster = invalid then return

    ' Grid cards are small — request a reduced-width poster to save bandwidth and
    ' texture memory across the many cards in a paginated grid.
    m.poster.uri = buildPosterUrl(movie.posterUrl, Const().POSTER_GRID)
    m.title.text = movie.title
    m.year.text  = movie.year
end sub
