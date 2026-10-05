' ─── Initialization ──────────────────────────────────────────────────────────

'**
'* @description Entry point. Resolves nodes, configures the video player, registers
'*              observers, and sets initial focus.
'* @sideeffect Stores node references in m. Registers field observers. Sets focus.
'*
function init()
    resolveNodes()
    initVideoPlayer()
    registerObservers()
    m.search_screen.setFocus(true)
end function

'**
'* @description Resolves all child node references once and stores them in m.
'* @sideeffect Stores m.search_screen, m.details_screen, m.video_player, m.error_dialog.
'*
sub resolveNodes()
    m.search_screen  = m.top.findNode("search_screen")
    m.details_screen = m.top.findNode("details_screen")
    m.video_player   = m.top.findNode("video_player")
    m.error_dialog   = m.top.findNode("error_dialog")
end sub

'**
'* @description Registers field observers for navigation and error events.
'* @sideeffect Registers observers on search_screen and details_screen fields.
'*
sub registerObservers()
    m.search_screen.observeField("movie_selected", "onMovieSelected")
    m.search_screen.observeField("error_message", "onSearchError")
    m.details_screen.observeField("play_pressed", "onPlayPressed")
end sub

' ─── Navigation Handlers ─────────────────────────────────────────────────────

'**
'* @description Shows details_screen for the selected movie (data assigned before display).
'* @param {roAssociativeArray} obj Field change event; obj.getData() is the movie_item node.
'* @sideeffect Hides search_screen, shows details_screen, transfers focus.
'*
sub onMovieSelected(obj)
    movie = obj.getData()
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
    content.url          = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
    content.streamformat = "hls"
    content.title        = "Big Buck Bunny"

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
    m.video_player.setCertificatesFile("common:/certs/ca-bundle.crt")
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
'* @description Stops playback and returns to details_screen.
'* @sideeffect Stops video_player, hides it, shows details_screen, transfers focus.
'*
sub closeVideo()
    m.video_player.control   = "stop"
    m.video_player.visible   = false
    m.details_screen.visible = true
    m.details_screen.setFocus(true)
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
        else if m.details_screen.visible
            m.details_screen.visible = false
            m.search_screen.visible  = true
            m.search_screen.setFocus(true)
            handle = true
        end if
    end if

    return handle
end function
