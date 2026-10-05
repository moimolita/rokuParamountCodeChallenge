'**
'* @description Application entry point. Creates the SceneGraph screen, initializes
'*              the root scene, and runs the main message loop to keep the app alive.
'*              The loop exits when the user closes the channel (isScreenClosed).
'*
sub main()
    m.port = createObject("roMessagePort")

    screen = createObject("roSGScreen")
    screen.setMessagePort(m.port)
    scene = screen.createScene("home_scene")
    screen.show()

    ' Main message loop — keeps the app alive and listens for system events
    while true
        msg = wait(0, m.port)
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        end if
    end while
end sub
