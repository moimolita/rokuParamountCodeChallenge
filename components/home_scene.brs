' ─── Initialization ──────────────────────────────────────────────────────────

'**
'* @description Entry point. Creates the searchScreen on demand, configures the video player,
'*              registers observers, and sets initial focus.
'* @sideeffect Stores node references in m. Registers field observers. Sets focus to searchScreen.
'*
function init()
    resolveNodes()
    initMemoryMonitor()    ' Initialize memory monitoring
    printMemoryMetrics("INIT")
    createSearchScreen()
    printMemoryMetrics("AFTER_CREATE_SEARCH")
    initVideoPlayer()
    m.searchScreen.setFocus(true)
end function

'**
'* @description Resolves persistent node references (videoPlayer, errorDialog) once and stores in m.
'*              searchScreen and detailsScreen are created dynamically on demand.
'* @sideeffect Stores m.videoPlayer, m.errorDialog in m.
'*
sub resolveNodes()
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.errorDialog = m.top.findNode("errorDialog")
end sub

' ─── Memory Monitoring ───────────────────────────────────────────────────────

'**
'* @description Initializes the app memory monitor for memory tracking and alerts.
'*              Uses roAppMemoryMonitor to track app-specific memory usage (not device-wide).
'* @sideeffect Stores m.memoryMonitor in m. Enables memory warning events.
'*
sub initMemoryMonitor()
    m.memoryMonitor = createObject("roAppMemoryMonitor")
    if m.memoryMonitor <> invalid
        m.memoryMonitor.EnableMemoryWarningEvent(true)
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
    if m.memoryMonitor = invalid then return

    percentUsed = m.memoryMonitor.GetMemoryLimitPercent()

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
'* @description Creates searchScreen dynamically as a child of home_scene.
'*              Called once on init() and kept in memory while user is searching.
'* @sideeffect Creates m.searchScreen, attaches it to m.top, registers observers.
'*
sub createSearchScreen()
    m.searchScreen = createObject("roSGNode", "SearchScreen")
    m.searchScreen.id = "searchScreen"
    m.searchScreen.visible = true
    m.searchScreen.translation = [0, 0]
    m.top.appendChild(m.searchScreen)

    ' Register observers for navigation and error events
    m.searchScreen.observeField("movieSelected", "onMovieSelected")
    m.searchScreen.observeField("errorMessage", "onSearchError")
end sub

'**
'* @description Creates detailsScreen dynamically as a child of home_scene.
'*              Called on demand in onMovieSelected() when user selects a movie.
'* @sideeffect Creates m.detailsScreen, attaches it to m.top, registers observer.
'*
sub createDetailsScreen()
    m.detailsScreen = createObject("roSGNode", "DetailsScreen")
    m.detailsScreen.id = "detailsScreen"
    m.detailsScreen.visible = false
    m.detailsScreen.translation = [0, 0]
    m.top.appendChild(m.detailsScreen)

    ' Register observer for play button events
    m.detailsScreen.observeField("playPressed", "onPlayPressed")
end sub

'**
'* @description Destroys detailsScreen to free memory.
'*              Called when user navigates back from details view or video playback ends.
'* @sideeffect Removes m.detailsScreen from m.top and sets reference to invalid.
'*
sub destroyDetailsScreen()
    if m.detailsScreen <> invalid
        m.top.removeChild(m.detailsScreen)
        m.detailsScreen = invalid
    end if
end sub

' ─── Navigation Handlers ─────────────────────────────────────────────────────

'**
'* @description Shows detailsScreen for the selected movie (creates it on demand if needed).
'*              Data is assigned before making visible.
'* @param {roAssociativeArray} obj Field change event; obj.getData() is the MovieItem node.
'* @sideeffect Creates detailsScreen if it doesn't exist. Hides searchScreen, shows detailsScreen, transfers focus.
'*
sub onMovieSelected(obj)
    movie = obj.getData()

    ' Create detailsScreen on demand (first time user selects a movie)
    if m.detailsScreen = invalid
        createDetailsScreen()
        printMemoryMetrics("AFTER_CREATE_DETAILS")
    end if

    m.detailsScreen.movie = movie   ' assign data BEFORE making visible
    m.searchScreen.visible  = false
    m.detailsScreen.visible = true
    m.detailsScreen.setFocus(true)
end sub

'**
'* @description Shows the global modal error dialog for a hard error from searchScreen.
'* @param {roAssociativeArray} obj Field change event carrying the error message.
'* @sideeffect Shows the modal errorDialog via showError.
'*
sub onSearchError(obj)
    message = obj.getData()
    if message <> "" then showError(message)
end sub

'**
'* @description Starts playback of the sample HLS stream.
'* @param {roAssociativeArray} obj Field change event from detailsScreen.playPressed.
'* @sideeffect Hides detailsScreen, shows videoPlayer, starts playback.
'*
sub onPlayPressed(obj)
    m.detailsScreen.visible = false
    m.videoPlayer.visible   = true
    m.videoPlayer.setFocus(true)

    content = createObject("roSGNode", "ContentNode")
    content.url          = Const().SAMPLE_STREAM_URL
    content.streamformat = Const().SAMPLE_STREAM_FORMAT
    content.title        = Const().SAMPLE_STREAM_TITLE

    m.videoPlayer.content = content
    m.videoPlayer.control = "play"
end sub

' ─── Video Player ─────────────────────────────────────────────────────────────

'**
'* @description Configures the Video node with SSL, cookies, and a state observer.
'* @sideeffect Mutates m.videoPlayer. Registers a scoped observer on its "state" field.
'*
sub initVideoPlayer()
    m.videoPlayer.enableCookies()
    m.videoPlayer.setCertificatesFile(Const().SSL_CERTIFICATES_FILE)
    m.videoPlayer.initClientCertificates()
    m.videoPlayer.notificationInterval = 1
    m.videoPlayer.observeFieldScoped("state", "onPlayerStateChanged")
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
'* @description Stops playback, returns to searchScreen, and cleans up detailsScreen.
'* @sideeffect Stops videoPlayer, hides it, shows searchScreen, destroys detailsScreen, transfers focus.
'*
sub closeVideo()
    m.videoPlayer.control   = "stop"
    m.videoPlayer.visible   = false
    destroyDetailsScreen()
    printMemoryMetrics("AFTER_DESTROY_DETAILS")
    m.searchScreen.visible  = true
    m.searchScreen.setFocus(true)
end sub

' ─── Error Handling ───────────────────────────────────────────────────────────

'**
'* @description Shows a modal error dialog with the given message.
'* @param {String} message Human-readable error message to show the user.
'* @sideeffect Mutates m.errorDialog fields. Assigns it to m.top.dialog for modal focus.
'*
sub showError(message as string)
    m.errorDialog.title   = "Error"
    m.errorDialog.message = message
    m.errorDialog.visible = true
    m.top.dialog = m.errorDialog   ' required for modal focus capture
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
        if m.videoPlayer.visible
            closeVideo()
            handle = true
        else if m.detailsScreen <> invalid and m.detailsScreen.visible
            destroyDetailsScreen()
            printMemoryMetrics("AFTER_DESTROY_DETAILS_BACK")
            m.searchScreen.visible  = true
            m.searchScreen.setFocus(true)
            handle = true
        end if
    end if

    return handle
end function
