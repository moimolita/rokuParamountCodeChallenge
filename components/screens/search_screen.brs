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
    m.search_keyboard.setFocus(true)    ' Focus the keyboard so the user can type immediately.
end function

'**
'* @description Resolves all node references once and stores them in m.
'* @sideeffect Stores grid, keyboard, timer, hint, and detail-pane node references.
'*
sub resolveNodes()
    m.movie_grid      = m.top.findNode("movie_grid")
    m.search_keyboard = m.top.findNode("search_keyboard")
    m.hint_label      = m.top.findNode("hint_label")
    m.debounce_timer  = m.top.findNode("debounce_timer")

    ' Detail pane nodes
    m.detail_poster   = m.top.findNode("detail_poster")
    m.detail_title_bg = m.top.findNode("detail_title_bg")
    m.detail_title    = m.top.findNode("detail_title")
    m.detail_year     = m.top.findNode("detail_year")
    m.detail_plot     = m.top.findNode("detail_plot")
end sub

'**
'* @description Registers observers for grid focus/selection, keyboard input,
'*              debounce timer, and own visibility.
'* @sideeffect Registers field observers on the grid, keyboard, timer, and m.top.
'*
sub registerObservers()
    m.movie_grid.observeField("itemFocused",  "onItemFocused")
    m.movie_grid.observeField("itemSelected", "onItemSelected")
    m.search_keyboard.observeField("text", "onSearchTextChanged")
    m.debounce_timer.observeField("fire", "onDebounceFired")
    m.top.observeField("visible", "onVisibleChanged")
end sub

'**
'* @description Initializes the scroll-based pagination state.
'* @sideeffect Stores pagination state in m.
'*
sub initPaginationState()
    m.current_query   = ""          ' active search term (to request its next page)
    m.current_page    = 1           ' last page requested (OMDb returns 10 per page)
    m.is_loading_more = false       ' true while a load-more is in flight (prevents double-fire and tells onResultsReady to append vs replace)
    m.total_results   = 0           ' total count from OMDb (to know when to stop paging)
    m.pending_query   = ""          ' text awaiting the debounce timer before searching
    m.movies_content  = invalid     ' cached ContentNode tree (for focus/selection handlers)
end sub

'**
'* @description Creates the search task once and observes its results output.
'* @sideeffect Stores m.search_task and registers its results observer.
'*
sub createSearchTask()
    m.search_task = createObject("roSGNode", "search_task")
    m.search_task.observeField("results", "onResultsReady")
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
        m.hint_label.text = "Type at least " + Const().MIN_QUERY_LEN.toStr() + " characters to search"
        m.hint_label.visible = true
        return
    end if

    m.hint_label.visible = false
    m.current_query   = query
    m.current_page    = 1
    m.is_loading_more = false   ' NEW search → onResultsReady will REPLACE the grid
    runSearch()
end sub

'**
'* @description Loads the next page of the current query and appends it to the grid.
'* @sideeffect Increments m.current_page, sets m.is_loading_more, runs the task.
'*
sub loadMore()
    m.current_page    = m.current_page + 1
    m.is_loading_more = true    ' LOAD MORE → onResultsReady will APPEND
    runSearch()
end sub

'**
'* @description Runs the search task with the current query + page (set inputs then run).
'* @sideeffect Sets m.search_task.query/page and triggers control="RUN".
'*
sub runSearch()
    m.search_task.query = m.current_query
    m.search_task.page  = m.current_page
    m.search_task.control = "RUN"
end sub

'**
'* @description Observer for search_task.results. Handles errors, then replaces
'*              (new search) or appends (load more) the results into the grid.
'* @param {roAssociativeArray} obj Field change event carrying the results ContentNode.
'* @sideeffect Updates m.movie_grid.content and m.movies_content, or shows an error.
'*
sub onResultsReady(obj)
    content = obj.getData()

    ' Error handling first — the task sets "error" alongside an empty results tree.
    taskError = m.search_task.error
    if taskError = "no_results"
        m.hint_label.text = "No movies found. Try another search."
        m.hint_label.visible = true
        m.movie_grid.content = createObject("roSGNode", "ContentNode")
        m.movies_content = invalid
        m.total_results = 0
        return
    else if taskError = "network"
        ' Bubble the hard error up — home_scene shows the modal.
        m.top.error_message = "Connection error. Please check your network and try again."
        return
    end if

    m.hint_label.visible = false
    m.total_results = m.search_task.totalResults

    if m.is_loading_more = true
        ' LOAD MORE — append new children to the EXISTING tree so the grid keeps
        ' scroll position and focus (no reassigning .content).
        for each child in content.getChildren(-1, 0)
            m.movies_content.appendChild(child)
        end for
        m.is_loading_more = false
    else
        ' NEW search — replace the whole tree.
        m.movie_grid.content = content
        m.movies_content = content
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
    if m.movies_content = invalid then return

    movie = m.movies_content.getChild(index)
    if movie = invalid then return

    ' Medium poster for the pane: larger than grid cards, smaller than details.
    m.detail_poster.uri = buildPosterUrl(movie.poster_url, Const().POSTER_PANE)
    m.detail_title.text = movie.title
    m.detail_year.text  = movie.year
    m.detail_plot.text  = movie.plot

    ' Pane background is always visible (XML). Reveal content on first focus; use the
    ' poster's visibility as the "first focus" flag.
    if m.detail_poster.visible = false
        m.detail_poster.visible   = true
        m.detail_title_bg.visible = true
        m.detail_title.visible    = true
        m.detail_year.visible     = true
        m.detail_plot.visible     = true
    end if

    ' Preload the next page before the user hits the edge (wider threshold gives
    ' fast scrolling more margin). Guards: not already loading, and more pages exist.
    loaded = m.movies_content.getChildCount()
    if index >= loaded - Const().PAGE_PRELOAD_THRESHOLD and m.is_loading_more = false and hasMorePages() = true
        loadMore()
    end if
end sub

'**
'* @description True if more results remain to load for the current query.
'* @returns {Boolean} Whether another page can be fetched.
'*
function hasMorePages() as boolean
    if m.movies_content = invalid then return false
    return m.movies_content.getChildCount() < m.total_results
end function

' ─── Visibility Handler ───────────────────────────────────────────────────────

'**
'* @description Restores grid focus when the screen becomes visible again.
'* @sideeffect Calls setFocus on m.movie_grid when becoming visible.
'*
sub onVisibleChanged()
    if m.top.visible = false then return
    if m.movie_grid = invalid then return
    m.movie_grid.setFocus(true)
end sub

' ─── Search Handler ───────────────────────────────────────────────────────────

'**
'* @description On each keystroke, stores the text and restarts the debounce timer
'*              so the search runs once the user pauses (not once per letter).
'* @param {roAssociativeArray} obj Field change event carrying the current text.
'* @sideeffect Updates m.pending_query and restarts m.debounce_timer.
'*
sub onSearchTextChanged(obj)
    m.pending_query = obj.getData()
    m.debounce_timer.control = "stop"
    m.debounce_timer.control = "start"
end sub

'**
'* @description Fires after the debounce pause; runs the search for the pending query.
'* @sideeffect Triggers the search via populateGrid.
'*
sub onDebounceFired()
    populateGrid(m.pending_query)
end sub

' ─── Selection Handler ────────────────────────────────────────────────────────

'**
'* @description On OK, writes the selected movie_item to movie_selected (observed by
'*              home_scene to navigate to details_screen).
'* @param {roAssociativeArray} obj Field change event carrying the selected item index.
'* @sideeffect Writes to m.top.movie_selected.
'*
sub onItemSelected(obj)
    index = obj.getData()
    if m.movies_content = invalid then return

    movie = m.movies_content.getChild(index)
    if movie = invalid then return

    m.top.movie_selected = movie
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
        if key = "right" and m.search_keyboard.isInFocusChain()
            m.movie_grid.setFocus(true)
            handle = true
        else if key = "left" and m.movie_grid.isInFocusChain()
            m.search_keyboard.setFocus(true)
            handle = true
        end if
    end if

    return handle
end function
