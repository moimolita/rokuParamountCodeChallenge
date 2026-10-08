' ─── Initialization ──────────────────────────────────────────────────────────

'**
'* @description Entry point. Resolves nodes, registers observers, creates the search
'*              task, seeds a default search, and focuses the keyboard.
'* @sideeffect Stores node references and pagination state in m. Registers observers.
'*
function init()
    resolveNodes()
    registerObservers()
    initPaginationState()
    createSearchTask()
    populateGrid(Const().DEFAULT_QUERY) ' Default search so the grid isn't empty on entry (OMDb rejects empty queries).
    m.searchKeyboard.setFocus(true)     ' Focus the keyboard so the user can type immediately.
end function

'**
'* @description Resolves all node references once and stores them in m.
'* @sideeffect Stores grid, keyboard, timer, hint, and detail-pane node references.
'*
sub resolveNodes()
    m.movieGrid      = m.top.findNode("movieGrid")
    m.searchKeyboard = m.top.findNode("searchKeyboard")
    m.hintLabel      = m.top.findNode("hintLabel")
    m.debounceTimer  = m.top.findNode("debounceTimer")

    ' Detail pane nodes
    m.detailPoster  = m.top.findNode("detailPoster")
    m.detailTitleBg = m.top.findNode("detailTitleBg")
    m.detailTitle   = m.top.findNode("detailTitle")
    m.detailYear    = m.top.findNode("detailYear")
    m.detailPlot    = m.top.findNode("detailPlot")
end sub

'**
'* @description Registers observers for grid focus/selection, keyboard input,
'*              debounce timer, and own visibility.
'* @sideeffect Registers field observers on the grid, keyboard, timer, and m.top.
'*
sub registerObservers()
    m.movieGrid.observeField("itemFocused",  "onItemFocused")
    m.movieGrid.observeField("itemSelected", "onItemSelected")
    m.searchKeyboard.observeField("text", "onSearchTextChanged")
    m.debounceTimer.observeField("fire", "onDebounceFired")
    m.top.observeField("visible", "onVisibleChanged")
end sub

'**
'* @description Initializes the scroll-based pagination state.
'* @sideeffect Stores pagination state in m.
'*
sub initPaginationState()
    m.currentQuery  = ""          ' active search term (to request its next page)
    m.currentPage   = 1           ' last page requested (OMDb returns 10 per page)
    m.isLoadingMore = false       ' true while a load-more is in flight (prevents double-fire and tells onResultsReady to append vs replace)
    m.totalResults  = 0           ' total count from OMDb (to know when to stop paging)
    m.pendingQuery  = ""          ' text awaiting the debounce timer before searching
    m.moviesContent = invalid     ' cached ContentNode tree (for focus/selection handlers)
end sub

'**
'* @description Creates the search task once and observes its results output.
'* @sideeffect Stores m.searchTask and registers its results observer.
'*
sub createSearchTask()
    m.searchTask = createObject("roSGNode", "SearchTask")
    m.searchTask.observeField("results", "onResultsReady")
end sub

' ─── Grid Population ──────────────────────────────────────────────────────────

'**
'* @description Starts a NEW search (resets pagination, replaces the grid). Short
'*              queries (<3 chars) show a hint and keep the previous results.
'* @param {String} query Search term (min 3 chars to actually search).
'* @sideeffect Resets pagination state and runs the search task.
'*
sub populateGrid(query as string)
    if query.len() < Const().MIN_QUERY_LEN
        m.hintLabel.text = "Type at least " + Const().MIN_QUERY_LEN.toStr() + " characters to search"
        m.hintLabel.visible = true
        return
    end if

    m.hintLabel.visible = false
    m.currentQuery  = query
    m.currentPage   = 1
    m.isLoadingMore = false   ' NEW search → onResultsReady will REPLACE the grid
    runSearch()
end sub

'**
'* @description Loads the next page of the current query and appends it to the grid.
'* @sideeffect Increments m.currentPage, sets m.isLoadingMore, runs the task.
'*
sub loadMore()
    m.currentPage   = m.currentPage + 1
    m.isLoadingMore = true    ' LOAD MORE → onResultsReady will APPEND
    runSearch()
end sub

'**
'* @description Runs the search task with the current query + page (set inputs then run).
'* @sideeffect Sets m.searchTask.query/page and triggers control="RUN".
'*
sub runSearch()
    m.searchTask.query = m.currentQuery
    m.searchTask.page  = m.currentPage
    m.searchTask.control = "RUN"
end sub

'**
'* @description Observer for SearchTask.results. Handles errors, then replaces
'*              (new search) or appends (load more) the results into the grid.
'* @param {roAssociativeArray} obj Field change event carrying the results ContentNode.
'* @sideeffect Updates m.movieGrid.content and m.moviesContent, or shows an error.
'*
sub onResultsReady(obj)
    content = obj.getData()

    ' Error handling first — the task sets "error" alongside an empty results tree.
    taskError = m.searchTask.error
    if taskError = "no_results"
        m.hintLabel.text = "No movies found. Try another search."
        m.hintLabel.visible = true
        m.movieGrid.content = createObject("roSGNode", "ContentNode")
        m.moviesContent = invalid
        m.totalResults = 0
        return
    else if taskError = "network"
        ' Bubble the hard error up — home_scene shows the modal.
        m.top.errorMessage = "Connection error. Please check your network and try again."
        return
    end if

    m.hintLabel.visible = false
    m.totalResults = m.searchTask.totalResults

    if m.isLoadingMore = true
        ' LOAD MORE — append new children to the EXISTING tree so the grid keeps
        ' scroll position and focus (no reassigning .content).
        for each child in content.getChildren(-1, 0)
            m.moviesContent.appendChild(child)
        end for
        m.isLoadingMore = false
    else
        ' NEW search — replace the whole tree.
        m.movieGrid.content = content
        m.moviesContent = content
    end if
end sub

' ─── Grid Handlers ────────────────────────────────────────────────────────────

'**
'* @description On grid focus change: updates the detail pane and triggers
'*              scroll-based pagination near the end of the loaded items.
'* @param {roAssociativeArray} obj Field change event carrying the focused item index.
'* @sideeffect Updates detail pane nodes; may call loadMore().
'*
sub onItemFocused(obj)
    index = obj.getData()
    if m.moviesContent = invalid then return

    movie = m.moviesContent.getChild(index)
    if movie = invalid then return

    ' Medium poster for the pane: larger than grid cards, smaller than details.
    m.detailPoster.uri = buildPosterUrl(movie.posterUrl, Const().POSTER_PANE)
    m.detailTitle.text = movie.title
    m.detailYear.text  = movie.year
    m.detailPlot.text  = movie.plot

    ' Pane background is always visible (XML). Reveal content on first focus; use the
    ' poster's visibility as the "first focus" flag.
    if m.detailPoster.visible = false
        m.detailPoster.visible   = true
        m.detailTitleBg.visible  = true
        m.detailTitle.visible    = true
        m.detailYear.visible     = true
        m.detailPlot.visible     = true
    end if

    ' Preload the next page before the user hits the edge (wider threshold gives
    ' fast scrolling more margin). Guards: not already loading, and more pages exist.
    loaded = m.moviesContent.getChildCount()
    if index >= loaded - Const().PAGE_PRELOAD_THRESHOLD and m.isLoadingMore = false and hasMorePages() = true
        loadMore()
    end if
end sub

'**
'* @description True if more results remain to load for the current query.
'* @returns {Boolean} Whether another page can be fetched.
'*
function hasMorePages() as boolean
    if m.moviesContent = invalid then return false
    return m.moviesContent.getChildCount() < m.totalResults
end function

' ─── Visibility Handler ───────────────────────────────────────────────────────

'**
'* @description Restores grid focus when the screen becomes visible again.
'* @sideeffect Calls setFocus on m.movieGrid when becoming visible.
'*
sub onVisibleChanged()
    if m.top.visible = false then return
    if m.movieGrid = invalid then return
    m.movieGrid.setFocus(true)
end sub

' ─── Search Handler ───────────────────────────────────────────────────────────

'**
'* @description On each keystroke, stores the text and restarts the debounce timer
'*              so the search runs once the user pauses (not once per letter).
'* @param {roAssociativeArray} obj Field change event carrying the current text.
'* @sideeffect Updates m.pendingQuery and restarts m.debounceTimer.
'*
sub onSearchTextChanged(obj)
    m.pendingQuery = obj.getData()
    m.debounceTimer.control = "stop"
    m.debounceTimer.control = "start"
end sub

'**
'* @description Fires after the debounce pause; runs the search for the pending query.
'* @sideeffect Triggers the search via populateGrid.
'*
sub onDebounceFired()
    populateGrid(m.pendingQuery)
end sub

' ─── Selection Handler ────────────────────────────────────────────────────────

'**
'* @description On OK, writes the selected movie_item to movieSelected (observed by
'*              home_scene to navigate to DetailsScreen).
'* @param {roAssociativeArray} obj Field change event carrying the selected item index.
'* @sideeffect Writes to m.top.movieSelected.
'*
sub onItemSelected(obj)
    index = obj.getData()
    if m.moviesContent = invalid then return

    movie = m.moviesContent.getChild(index)
    if movie = invalid then return

    m.top.movieSelected = movie
end sub

' ─── Focus Navigation ─────────────────────────────────────────────────────────

'**
'* @description D-pad focus hand-off: RIGHT keyboard→grid, LEFT grid→keyboard.
'* @param {String} key Name of the key pressed.
'* @param {Boolean} press True on key down, false on key up.
'* @returns {Boolean} True if focus was moved (event consumed).
'*
function onKeyEvent(key as string, press as boolean) as boolean
    handle = false

    if press
        if key = "right" and m.searchKeyboard.isInFocusChain()
            m.movieGrid.setFocus(true)
            handle = true
        else if key = "left" and m.movieGrid.isInFocusChain()
            m.searchKeyboard.setFocus(true)
            handle = true
        end if
    end if

    return handle
end function
