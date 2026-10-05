' ─── Initialization ──────────────────────────────────────────────────────────

'**
'* @description Entry point. Resolves nodes, creates the detail task, registers
'*              observers, and focuses the Play button.
'* @sideeffect Stores node references in m. Registers observers. Sets focus.
'*
function init()
    resolveNodes()
    registerObservers()
    createDetailsTask()
    m.play_button.setFocus(true)
end function

'**
'* @description Resolves all node references once and stores them in m.
'* @sideeffect Stores poster, title, year, rating, plot, and play_button references.
'*
sub resolveNodes()
    m.detail_poster = m.top.findNode("detail_poster")
    m.detail_title  = m.top.findNode("detail_title")
    m.detail_year   = m.top.findNode("detail_year")
    m.detail_rating = m.top.findNode("detail_rating")
    m.detail_plot   = m.top.findNode("detail_plot")
    m.play_button   = m.top.findNode("play_button")
end sub

'**
'* @description Registers observers for the detail fetch, own visibility, and the
'*              Play button activation.
'* @sideeffect Registers observers on detail_task, m.top, and play_button.
'*
sub registerObservers()
    m.top.observeField("visible", "onVisibleChanged")
    ' Play is activated by two keys: OK (consumed by the Button → buttonSelected)
    ' and the physical play key (not consumed → onKeyEvent). Both call triggerPlay.
    m.play_button.observeField("buttonSelected", "onPlaySelected")
end sub

'**
'* @description Creates the lazy detail task and observes its plot/rating outputs.
'* @sideeffect Stores m.detail_task and registers its plot/rating observers.
'*
sub createDetailsTask()
    m.detail_task = createObject("roSGNode", "detail_task") ' Lazy detail task (observed below)
    m.detail_task.observeField("plot",   "onDetailPlotReady")
    m.detail_task.observeField("rating", "onDetailRatingReady")
end sub

' ─── Data Binding ─────────────────────────────────────────────────────────────

'**
'* @description Populates the screen with the selected movie, then fires the lazy
'*              detail fetch for plot + rating.
'* @param {roAssociativeArray} obj Field change event carrying the movie_item node.
'* @sideeffect Updates poster/title/year; blanks plot/rating; runs the detail task.
'*
sub onMovieChanged(obj)
    movie = obj.getData()
    if movie = invalid then return
    if m.detail_title = invalid then return

    ' Basic data from the search result — shown immediately. Large poster.
    m.detail_poster.uri = posterUrl(movie.poster_url, Const().POSTER_DETAIL)
    m.detail_title.text = movie.title
    m.detail_year.text  = movie.year

    ' Plot + rating come from the detail fetch — blank while it's in flight.
    m.detail_rating.text = ""
    m.detail_plot.text   = ""

    ' Fire the lazy detail fetch for this movie (set input then run).
    m.detail_task.imdb_id = movie.imdb_id
    m.detail_task.control = "RUN"
end sub

' ─── Detail Fetch Handlers ────────────────────────────────────────────────────

'**
'* @description Fills the plot label when the detail fetch finishes.
'* @param {roAssociativeArray} obj Field change event carrying the plot string.
'* @sideeffect Updates m.detail_plot.text.
'*
sub onDetailPlotReady(obj)
    m.detail_plot.text = obj.getData()
end sub

'**
'* @description Fills the rating label when the detail fetch finishes.
'* @param {roAssociativeArray} obj Field change event carrying the rating string.
'* @sideeffect Updates m.detail_rating.text.
'*
sub onDetailRatingReady(obj)
    m.detail_rating.text = "Rating: " + obj.getData()
end sub

' ─── Visibility Handler ───────────────────────────────────────────────────────

'**
'* @description Restores focus to the Play button when the screen becomes visible.
'* @sideeffect Calls setFocus on m.play_button when becoming visible.
'*
sub onVisibleChanged()
    if m.top.visible = false then return
    if m.play_button = invalid then return
    m.play_button.setFocus(true)
end sub

' ─── Play Activation ──────────────────────────────────────────────────────────

'**
'* @description Handles the OK activation reported by the Button (buttonSelected).
'* @sideeffect Via triggerPlay — writes m.top.play_pressed.
'*
sub onPlaySelected()
    triggerPlay()
end sub

'**
'* @description Handles the physical play key (not consumed by the Button).
'* @param {String} key Name of the key pressed.
'* @param {Boolean} press True on key down, false on key up.
'* @returns {Boolean} True if the play key was handled.
'*
function onKeyEvent(key as string, press as boolean) as boolean
    handle = false
    if key = "play" and press
        triggerPlay()
        handle = true
    end if
    return handle
end function

'**
'* @description Single source of truth for triggering playback (OK and play key).
'* @sideeffect Writes m.top.play_pressed — observed by home_scene to launch video.
'*
sub triggerPlay()
    m.top.play_pressed = true
end sub
