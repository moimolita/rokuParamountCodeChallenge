' ─── Initialization ──────────────────────────────────────────────────────────

'**
'* @description Entry point. Creates the search_screen on demand, configures the video player,
'*              registers observers, and sets initial focus.
'* @sideeffect Stores node references in m. Registers field observers. Sets focus to search_screen.
'*
function init()
    resolveNodes()
    initDeviceInfo()       ' Initialize memory monitoring
    printMemoryMetrics("INIT")
    createSearchScreen()
    printMemoryMetrics("AFTER_CREATE_SEARCH")
    initVideoPlayer()
    m.search_screen.setFocus(true)
end function

'**
'* @description Resolves persistent node references (video_player, error_dialog) once and stores in m.
'*              Search_screen and details_screen are created dynamically on demand.
'* @sideeffect Stores m.video_player, m.error_dialog in m.
'*
sub resolveNodes()
    m.video_player = m.top.findNode("video_player")
    m.error_dialog = m.top.findNode("error_dialog")
end sub

' ─── Memory Monitorig ────────────────────────────────────────────────────────

'**
'* @description Initializes the app memory monitor for memory tracking and alerts.
'*              Uses roAppMemoryMonitor to track app-specific memory usage (not device-wide).
'* @sideeffect Stores m.memory_monitor in m. Enables memory warning events.
'*
sub initDeviceInfo()
    m.memory_monitor = createObject("roAppMemoryMonitor")
    if m.memory_monitor <> invalid
        m.memory_monitor.EnableMemoryWarningEvent(true)
    end if
end sub

'**
'* @description Prints memory metrics to console for debugging and validation.
'*              Uses roAppMemoryMonitor to measure this app's specific memory usage.
'*              Helps verify that lazy loading and screen destruction properly free memory.
'* @param {String} label Context label (e.g. "INIT", "AFTER_CREATE_DETAILS")
'* @sideeffect Prints to console. Optionally alerts if memory usage is high.
'*
sub printMemoryMetrics(label as string)
    if m.memory_monitor = invalid then return
    
    percentUsed = m.memory_monitor.GetMemoryLimitPercent()
    
    ' Determine status based on percentage
    statusEmoji = "❓"
    statusName = "UNKNOWN"
    if percentUsed < Const().MEMORY_WARNING_PCT
        statusEmoji = "✓"
        statusName = "HEALTHY"
    else if percentUsed < Const().MEMORY_CRITICAL_PCT
        statusEmoji = "⚠"
        statusName = "WARNING"
    else if percentUsed >= Const().MEMORY_CRITICAL_PCT
        statusEmoji = "⚠⚠⚠"
        statusName = "APP MEMORY CRITICAL"  ' Alert if memory usage is critical
    end if
    
    print "[MEMORY] " + statusEmoji + " " + label + " — App Memory: " + percentUsed.toStr() + "% (" + statusName + ")"
end sub

' ─── Screen Creation (Lazy Loading) ──────────────────────────────────────────

'**
'* @description Creates search_screen dynamically as a child of home_scene.
'*              Called once on init() and kept in memory while user is searching.
'* @sideeffect Creates m.search_screen, attaches it to m.top, registers observers.
'*
sub createSearchScreen()
    m.search_screen = createObject("roSGNode", "SearchScreen")
    m.search_screen.id = "search_screen"
    m.search_screen.visible = true
    m.search_screen.translation = [0, 0]
    m.top.appendChild(m.search_screen)
    
    ' Register observers for navigation and error events
    m.search_screen.observeField("movieSelected", "onMovieSelected")
    m.search_screen.observeField("errorMessage", "onSearchError")
end sub

'**
'* @description Creates details_screen dynamically as a child of home_scene.
'*              Called on demand in onMovieSelected() when user selects a movie.
'* @sideeffect Creates m.details_screen, attaches it to m.top, registers observer.
'*
sub createDetailsScreen()
    m.details_screen = createObject("roSGNode", "DetailsScreen")
    m.details_screen.id = "details_screen"
    m.details_screen.visible = false
    m.details_screen.translation = [0, 0]
    m.top.appendChild(m.details_screen)
    
    ' Register observer for play button events
    m.details_screen.observeField("playPressed", "onPlayPressed")
end sub

'**
'* @description Destroys details_screen to free memory.
'*              Called when user navigates back from details view or video playback ends.
'* @sideeffect Removes m.details_screen from m.top and sets reference to invalid.
'*
sub destroyDetailsScreen()
    if m.details_screen <> invalid
        m.top.removeChild(m.details_screen)
        m.details_screen = invalid
    end if
end sub

' ─── Navigation Handlers ─────────────────────────────────────────────────────

'**
'* @description Shows details_screen for the selected movie (creates it on demand if needed).
'*              Data is assigned before making visible.
'* @param {roAssociativeArray} obj Field change event; obj.getData() is the movie_item node.
'* @sideeffect Creates details_screen if it doesn't exist. Hides search_screen, shows details_screen, transfers focus.
'*
sub onMovieSelected(obj)
    movie = obj.getData()
    
    ' Create details_screen on demand (first time user selects a movie)
    if m.details_screen = invalid
        createDetailsScreen()
        printMemoryMetrics("AFTER_CREATE_DETAILS")
    end if
    
    m.details_screen.movie = movie   ' assign data BEFORE making visible
    m.search_screen.visible  = false
    m.details_screen.visible = true
    m.details_screen.setFocus(true)
end sub

'**
'* @description Shows the global modal error dialog for a hard error from search_screen.
'* @param {roAssociativeArray} obj Field change event carrying the error message.
'* @sideeffect Shows the modal error_dialog via showError.
'*
sub onSearchError(obj)
    message = obj.getData()
    if message <> "" then showError(message)
end sub

'**
'* @description Starts playback of the sample HLS stream.
'* @param {roAssociativeArray} obj Field change event from details_screen.play_pressed.
'* @sideeffect Hides details_screen, shows video_player, starts playback.
'*
sub onPlayPressed(obj)
    m.details_screen.visible = false
    m.video_player.visible   = true
    m.video_player.setFocus(true)

    content = createObject("roSGNode", "ContentNode")
    content.url          = Const().SAMPLE_STREAM_URL
    content.streamformat = Const().SAMPLE_STREAM_FORMAT
    content.title        = Const().SAMPLE_STREAM_TITLE

    m.video_player.content = content
    m.video_player.control = "play"
end sub

' ─── Video Player ─────────────────────────────────────────────────────────────

'**
'* @description Configures the Video node with SSL, cookies, and a state observer.
'* @sideeffect Mutates m.video_player. Registers a scoped observer on its "state" field.
'*
sub initVideoPlayer()
    m.video_player.enableCookies()
    m.video_player.setCertificatesFile(Const().SSL_CERTIFICATES_FILE)
    m.video_player.initClientCertificates()
    m.video_player.notificationInterval = 1
    m.video_player.observeFieldScoped("state", "onPlayerStateChanged")
end sub

'**
'* @description Closes the video when playback finishes or errors.
'* @param {roAssociativeArray} obj Field change event carrying the new state string.
'*
sub onPlayerStateChanged(obj)
    state = obj.getData()
    if state = "finished" or state = "error"
        closeVideo()
    end if
end sub

'**
'* @description Stops playback, returns to search_screen, and cleans up details_screen.
'* @sideeffect Stops video_player, hides it, shows search_screen, destroys details_screen, transfers focus.
'*
sub closeVideo()
    m.video_player.control   = "stop"
    m.video_player.visible   = false
    destroyDetailsScreen()
    printMemoryMetrics("AFTER_DESTROY_DETAILS")
    m.search_screen.visible  = true
    m.search_screen.setFocus(true)
end sub

' ─── Error Handling ───────────────────────────────────────────────────────────

'**
'* @description Shows a modal error dialog with the given message.
'* @param {String} message Human-readable error message to show the user.
'* @sideeffect Mutates m.error_dialog fields. Assigns it to m.top.dialog for modal focus.
'*
sub showError(message as string)
    m.error_dialog.title   = "Error"
    m.error_dialog.message = message
    m.error_dialog.visible = true
    m.top.dialog = m.error_dialog   ' required for modal focus capture
end sub

' ─── Key Events ───────────────────────────────────────────────────────────────

'**
'* @description Handles the global Back key (single-exit-point pattern).
'* @param {String} key Name of the key pressed (e.g. "back", "OK").
'* @param {Boolean} press True on key down, false on key up.
'* @returns {Boolean} True if consumed (app stays alive); false closes the app on root.
'*
function onKeyEvent(key as string, press as boolean) as boolean
    handle = false

    if key = "back" and press
        if m.video_player.visible
            closeVideo()
            handle = true
        else if m.details_screen <> invalid and m.details_screen.visible
            destroyDetailsScreen()
            printMemoryMetrics("AFTER_DESTROY_DETAILS_BACK")
            m.search_screen.visible  = true
            m.search_screen.setFocus(true)
            handle = true
        end if
    end if

    return handle
end function
