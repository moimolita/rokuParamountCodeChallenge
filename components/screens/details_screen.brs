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
    m.playButton.setFocus(true)
end function

'**
'* @description Resolves all node references once and stores them in m.
'* @sideeffect Stores poster, title, year, rating, plot, and playButton references.
'*
sub resolveNodes()
    m.detailPoster = m.top.findNode("detailPoster")
    m.detailTitle  = m.top.findNode("detailTitle")
    m.detailYear   = m.top.findNode("detailYear")
    m.detailRating = m.top.findNode("detailRating")
    m.detailPlot   = m.top.findNode("detailPlot")
    m.playButton   = m.top.findNode("playButton")
end sub

'**
'* @description Registers observers for the detail fetch, own visibility, and the
'*              Play button activation.
'* @sideeffect Registers observers on detailTask, m.top, and playButton.
'*
sub registerObservers()
    m.top.observeField("visible", "onVisibleChanged")
    ' Play is activated by two keys: OK (consumed by the Button → buttonSelected)
    ' and the physical play key (not consumed → onKeyEvent). Both call triggerPlay.
    m.playButton.observeField("buttonSelected", "onPlaySelected")
end sub

'**
'* @description Creates the lazy detail task and observes its plot/rating outputs.
'* @sideeffect Stores m.detailTask and registers its plot/rating observers.
'*
sub createDetailsTask()
    m.detailTask = createObject("roSGNode", "DetailTask") ' Lazy detail task (observed below)
    m.detailTask.observeField("plot",   "onDetailPlotReady")
    m.detailTask.observeField("rating", "onDetailRatingReady")
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
    if m.detailTitle = invalid then return

    ' Basic data from the search result — shown immediately. Large poster.
    m.detailPoster.uri = buildPosterUrl(movie.posterUrl, Const().POSTER_DETAIL)
    m.detailTitle.text = movie.title
    m.detailYear.text  = movie.year

    ' Plot + rating come from the detail fetch — blank while it's in flight.
    m.detailRating.text = ""
    m.detailPlot.text   = ""

    ' Fire the lazy detail fetch for this movie (set input then run).
    m.detailTask.imdbId = movie.imdbId
    m.detailTask.control = "RUN"
end sub

' ─── Detail Fetch Handlers ────────────────────────────────────────────────────

'**
'* @description Fills the plot label when the detail fetch finishes.
'* @param {roAssociativeArray} obj Field change event carrying the plot string.
'* @sideeffect Updates m.detailPlot.text.
'*
sub onDetailPlotReady(obj)
    m.detailPlot.text = obj.getData()
end sub

'**
'* @description Fills the rating label when the detail fetch finishes.
'* @param {roAssociativeArray} obj Field change event carrying the rating string.
'* @sideeffect Updates m.detailRating.text.
'*
sub onDetailRatingReady(obj)
    m.detailRating.text = "Rating: " + obj.getData()
end sub

' ─── Visibility Handler ───────────────────────────────────────────────────────

'**
'* @description Restores focus to the Play button when the screen becomes visible.
'* @sideeffect Calls setFocus on m.playButton when becoming visible.
'*
sub onVisibleChanged()
    if m.top.visible = false then return
    if m.playButton = invalid then return
    m.playButton.setFocus(true)
end sub

' ─── Play Activation ──────────────────────────────────────────────────────────

'**
'* @description Handles the OK activation reported by the Button (buttonSelected).
'* @sideeffect Via triggerPlay — writes m.top.playPressed.
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
'* @sideeffect Writes m.top.playPressed — observed by home_scene to launch video.
'*
sub triggerPlay()
    m.top.playPressed = true
end sub
