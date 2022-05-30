#SingleInstance Force
#Persistent
#NoEnv
#Include %A_ScriptDir%\ini.ahk
#Include %A_ScriptDir%\Lib\Notify.ahk

global appName := "Drag to Scroll"
global suspendFile := A_ScriptDir "\suspend_list.txt" 

; list of windows to suspend on
suspendWindows := getSuspendWindows(suspendFile) 

; add  groups to suspend 
Loop, % suspendWindows.Length()
  GroupAdd, suspendGroup, % "ahk_exe" . suspendWindows[A_Index]

; Timer to check for windows and suspend if needed
SetTimer, SuspenOnTarget, 1000

; initiate drag to scroll 
GoSub, Init 

Return

SuspenOnTarget() {
  If (WinActive("ahk_group suspendGroup") && A_IsSuspended == 0) {
    GoSub, DragStop ; safety measure. force stop all drags
    Suspend, On
    showNotification("Script Suspended")
    Menu, Tray, Icon, % A_ScriptDir "\res\dragiconpaused.ico" ; doesn't work
  } else if (A_IsSuspended == 1 && !WinActive("ahk_group suspendGroup")) {
    Suspend, Off
    showNotification("Script Resumed")
    Menu, Tray, Icon, %A_ScriptDir%\res\dragicon.ico
    Send, {Ctrl Up} {Ctrl Down} {Ctrl Up} ; to unstuck Ctrl key
  } 
}

getSuspendWindows(f) {
  FileRead, r, % f
  return StrSplit(r, "`n")
}

ApplySettings:
  ; Settings
  ;--------------------------------

  ; Global toggle. Should generally always be false
  Setting("ScrollDisabled", false)

  ; The chosen hotkey button
  ; Should work with pretty much any button, though 
  ; mouse or KB special keys (ctrl, alt, etc) are preferred.
  Setting("Button", "RButton") 

  ; Delay time before drag starts
  ; You must click and release "Button" before this time;
  ; Increase if you are having trouble getting "normal behavior"
  Setting("DragDelay", 150) ; in ms. 

  ; How often to poll for mouse movement & drag
  ; The major time unit for this script, everything happens on this
  ; schedule. Affects script responsiveness, scroll speed, etc.
  Setting("PollFrequency", 10) ; in ms

  ; Speed
  ; Affects the overall speed of scrolling before acceleration
  ; Speed is "normalized" to 1.0 as a default
  Setting("DragThreshold", 0) ; in pixels
  Setting("SpeedX", 1.0)
  Setting("SpeedY", 1.0)

  ; MovementCheck
  ; if enabled, this check will abort dragging
  ; if you have not moved the mouse over MovementThreshold
  ; within the first MovementCheckDelay ms
  ; This is used for compatibility with other button-hold actions
  Setting("UseMovementCheck", false)
  Setting("MovementCheckDelay", 200) ; in ms
  Setting("MovementThreshold", 0) ; in px

  ; scroll method
  ; choose one of: mWheelKey, mWheelMessage, mScrollMessage
  ; WheelMessage & WheelKey are preferred; your results may vary
  Setting("ScrollMethodX", mScrollMessage)
  Setting("ScrollMethodY", mWheelMessage)

  ; invert drag
  ; by default, you "drag" the document; moving up drags the document up,
  ; showing more of the document below. This behavior is the inverse of 
  ; scrolling up, where you see more of the document above.
  ; The invert flag switches the drag to the "scroll" behavior
  Setting("InvertDrag", true)

  ; Edge Scrolling
  ; allows you to hover over a window edge
  ; to continue scrolling, at a fixed rate
  Setting("UseEdgeScrolling", false)
  Setting("EdgeScrollingThreshold", 15) ; in px, distance from window edge
  Setting("EdgeScrollSpeed", 2.0) ; in 'speed'; 1.0 is about 5px/sec drag

  ; Targeting
  ; if Confine is enabled, drag will be immediately halted
  ; if the mouse leaves the target window or control
  ;
  ; it is advisable to not use BOTH confine and EdgeScrolling
  ; in that case, edge scrolling will only work if you
  ; never leave the bounds of the window edge
  Setting("UseControlTargeting", true)
  Setting("ConfineToWindow", false)
  Setting("ConfineToControl", false)

  ; Acceleration & momentum
  Setting("UseAccelerationX", true)
  Setting("UseAccelerationY", true)
  Setting("MomentumThreshold", 0.7) ; in 'speed'. Minimum speed to trigger momentum. 1 is always
  Setting("MomentumStopSpeed", 0.25) ; in 'speed'. Scrolling is stopped when momentum slows to this value
  Setting("MomentumInertia", .5) ; (0 < VALUE < 1) Describes how fast the scroll momentum dampens
  Setting("UseScrollMomentum", false)

  ; Acceleration function
  ; - modify very carefully!!
  ; - default is a pretty modest curve
  ;

  ; Based on the initial speed "arg", accelerate and return the updated value
  ; Think of this function as a graph of drag-speed v.s. scroll-speed.
  ;
  Accelerate(arg)
  { 
    return .006 * arg **3 + arg
  }

  ; double-click checking
  ;
  ; If enabled, a custom action can be performed a double-click is detected.
  ; Simply set UseDoubleClickCheck := true
  ; Define ButtonDoubleClick (below) to do anything you want
  Setting("DoubleClickThreshold", DllCall("GetDoubleClickTime"))
  Setting("UseDoubleClickCheck", false)

  ; Gesture checking
  ; 
  ; If enabled, simple gestures are detected, (only supports flick UDLR)
  ; and gesture events are called for custom actions, 
  ; rather than dragging with momentum.
  Setting("GestureThreshold", 30)
  Setting("GesturePageSize", 15)
  Setting("GestureBrowserNames", "chrome.exe,firefox.exe,iexplore.exe")

  ; Change Mouse Cursor 
  ; If enabled, mouse cursor is set to the cursor specified below
  Setting("ChangeMouseCursor", true)

  ; If the above ChangeMouseCursor setting is true, this determines what cursor style
  ; Choose either: 
  ;       "cursorHand"           -  the original DragToScroll hand icon
  ;       "cursorScrollPointer"  -  the scrollbar and pointer icon (SYNTPRES.ico)
  ;                                 this cursor will mostly stay stationary but you should 
  ;                                 still have the KeepCursorStationary set to 'true'
  Setting("ChangedCursorStyle", "cursorScrollPointer")

  ; If enabled, cursor will stay in its initial position for the duration of the drag
  ; This can look jittery with the "cursorHand" style because it updates based
  ; on the PollFrequency setting above
  Setting("KeepCursorStationary", false)
Return

; User-Customizable Handlers
;--------------------------------

; Handlers for gesture actions
; The Up/Down gestures will scroll the page 
; 
GestureU:
  if (WinProcessName = "AcroRd32.exe")
    Send, ^{PgDn}
  else if (Get("ScrollMethodY") = mWheelMessage)
    Loop, % GesturePageSize
    Scroll(-1 * (GesturePageSize-A_Index))
  else
    Send, {PgDn}
Return

GestureD:
  if (WinProcessName = "AcroRd32.exe")
    Send, ^{PgUp}
  else if (Get("ScrollMethodY") = mWheelMessage)
    Loop, % GesturePageSize
    Scroll((GesturePageSize-A_Index))
  else
    Send, {PgUp}
Return

GestureL:
  if WinProcessName in %GestureBrowserNames%
  {
    ToolTip("Back", 1)
    Send {Browser_Back}
  }
  else
    Send {Home}
Return

GestureR:
  if WinProcessName in %GestureBrowserNames%
  {
    ToolTip("Forward", 1)
    Send {Browser_Forward}
  }
  else
    Send {End}
Return

;--------------------------------
;--------------------------------
;--------------------------------
; END OF SETTINGS
; MODIFY BELOW CAREFULLY
;--------------------------------
;--------------------------------
;--------------------------------

; Init
;--------------------------------
Init:
  CoordMode, Mouse, Screen
  Gosub, Constants
  Gosub, Reset
  Gosub, LoadLocalSettings

  ; initialize non-setting & non-reset vars
  ;ScrollDisabled := false
  DragStatus := DS_NEW
  TimeOfLastButtonDown := 0
  TimeOf2ndLastButtonDown:= 0
  TimeOfLastButtonUp := 0

  ; Initialize menus & Hotkeys
  Gosub, MenuInit

  ; Initialize GUI for new cursor
  if (ChangeMouseCursor) && (ChangedCursorStyle = "cursorScrollPointer")
  {
    Gui, 98: Add, Pic, x0 y0 w35 h-1 vMyIconVar hWndMyIconHwnd, %A_ScriptDir%\res\cursor.png ; 0x3 = SS_ICON
    Gui, 98: Color, gray
    Gui, 98: +LastFound -Caption +AlwaysOnTop +ToolWindow
    WinSet, TransColor, gray
  }

Return

; Constants
;--------------------------------
Constants:
  VERSION = 2.5
  DEBUG = 0
  WM_HSCROLL = 0x114
  WM_VSCROLL = 0x115
  WM_MOUSEWHEEL = 0x20A
  WM_MOUSEHWHEEL = 0x20E
  WHEEL_DELTA = 120
  SB_LINEDOWN = 1
  SB_LINEUP = 0
  SB_LINELEFT = 0
  SB_LINERIGHT = 1
  X_ADJUST = .2 ; constant. normalizes user setting Speed to 1.0
  Y_ADJUST = .2 ; constant. normalizes user setting Speed to 1.0
  ;DragStatus
  DS_NEW = 0 ; click has taken place, no action taken yet
  DS_DRAGGING = 1 ; handler has picked up the click, suppressed normal behavior, and started a drag
  DS_HANDLED = 2 ; click is handled; either finished dragging, normal behavior, or double-clicked
  DS_HOLDING = 3 ; drag has been skipped, user is holding down button
  DS_MOMENTUM = 4 ; drag is finished, in the momentum phase
  INI_GENERAL := "General"
  INI_EXCLUDE = ServerSettings
  ; scroll method
  mWheelKey := "WheelKey" ; simulate mousewheel
  mWheelMessage := "WheelMessage" ; send WHEEL messages
  mScrollMessage := "ScrollMessage" ; send SCROLL messages
  URL_DISCUSSION := "https://autohotkey.com/boards/viewtopic.php?f=6&t=38457"
Return

; Cleans up after each drag. 
; Ensures there are no false results from info about the previous drag
;
Reset:
  OldY=
  OldX=
  NewX=
  NewY=
  DiffX=
  DiffY=
  DiffXSpeed=
  DiffYSpeed=
  OriginalX=
  OriginalY=
  CtrlClass=
  WinClass=
  WinProcessName=
  WinHwnd=
  CtrlHwnd=
  NewWinHwnd=
  NewCtrlHwnd=
  Target=
Return

; Implementation
;--------------------------------

; Hotkey Handler for button down
;
ButtonDown:
  ;~ if (WinActive("ahk_exe firefox.exe")) { ; testing
  ;~ ToolTip buttondown
  ;~ return
  ;~ }
  Critical
  ; Critical forces a hotkey handler thread to be attended to handling any others.
  ; If not, a rapid click could cause the Button-Up event to be processed
  ; before Button-Down, thanks to AHK's pseudo-multithreaded handling of hotkeys.
  ;
  ; Thanks to 'Guest' for an update to these hotkey routines.
  ; This update further cleans up, bigfixes, and simplifies the updates.

  ; Initialize DragStatus, indicating a new click
  DragStatus := DS_NEW
  GoSub, Reset

  ; Keep track of the last two click times.
  ; This allows us to check for double clicks.
  ;
  ; Move the previously recorded time out, for the latest button press event.
  ; Record the current time at the last click
  ; The stack has only 2 spaces; older values are discarded.
  TimeOf2ndLastButtonDown := TimeOfLastButtonDown
  TimeOfLastButtonDown := A_TickCount

  ; Capture the original position mouse position
  ; Window and Control Hwnds being hovered over
  ; for use w/ "Constrain" mode & messaging
  ; Get class names, and process name for per-app settings
  MouseGetPos, OriginalX, OriginalY, WinHwnd, CtrlHwnd, 3
  MouseGetPos, ,,, CtrlClass, 1
  WinGetClass, WinClass, ahk_id %WinHwnd%
  WinGet, WinProcessName, ProcessName, ahk_id %WinHwnd%
  WinGet, WinProcessID, PID, ahk_id %WinHwnd%
  WinProcessPath := GetModuleFileNameEx(WinProcessID)

  ; Figure out the target
  if (UseControlTargeting && CtrlHwnd)
    Target := "Ahk_ID " . CtrlHwnd
  else if (WinHwnd)
    Target := "Ahk_ID " . WinHwnd
  else
    Target := ""

  ;ToolTip("Target: " . Target . "    ID-WC:" . WinHwnd . "/" . CtrlHwnd . "     X/Y:" . OriginalX . "/" . OriginalY . "     Class-WC:" . WinClass . "/" CtrlClass . "     Process:" . WinProcessPath)
  ;ToolTip("Process Name:" . WinProcessName . "Process:" . WinProcessPath)

  ; if we're using the WheelKey method for this window,
  ; activate the window, so that the wheel key messages get picked up
  if (Get("ScrollMethodY") = mWheelKey && !WinActive("ahk_id " . WinHwnd))
    WinActivate, ahk_id %WinHwnd% 

  ; Optionally start a timer to see if 
  ; user is holding but not moving the mouse
  if (Get("UseMovementCheck"))
    SetTimer, MovementCheck, % -1 * Abs(MovementCheckDelay)

  gosub, StartPhase

  if (!Get("ScrollDisabled"))
  {
    ; if scrolling is enabled,
    ; schedule the drag to start after the delay.
    ; specifying a negative interval forces the timer to run once
    SetTimer, DragStart, % -1 * Abs(DragDelay)
  }
  else
    GoSub, HoldStart
Return

; Hotkey Handler for button up
;
ButtonUp:
  ; abort any pending checks to click/hold mouse
  ; and release any holds already started.
  SetTimer, MovementCheck, Off
  if (DragStatus == DS_HOLDING && GetKeyState(Button))
    GoSub, HoldStop

  ; If status is STILL NEW (not a gesture either)
  ; then user has quick press-released, without moving.
  ; Skip dragging, and treat like a normal click.
  if (DragStatus == DS_NEW)
    GoSub, DragSkip

  ; update icons & cursor
  ; done before handling momentum since we've already released the button
  GoSub UpdateTrayIcon
  if (ChangeMouseCursor)
  {
    RestoreSystemCursor()
    if (ChangedCursorStyle = "cursorScrollPointer")
      Gui, 98: Hide
  }

  ; check for and apply momentum
  if (DragStatus == DS_DRAGGING)
    GoSub, DragMomentum

  Gosub, EndPhase

  ; Always stop the drag.
  ; This marks the status as HANDLED,
  ; and cleans up any drag that may have started.
  GoSub, DragStop
Return

DisabledButtonDown:
  Send, {%Button% Down}
Return

DisabledButtonUp:
  Send, {%Button% Up}
Return

; Handler for dragging
; Checking to see if scrolling should take place
; for both horizontal and vertical scrolling.
;
; This handler repeatedly calls itself to continue
; the drag once it has been started. Dragging will continue
; until stopped by calling DragStop, halting the timmer.
;
DragStart:
  ; double check that the click wasn't already handled
  if (DragStatus == DS_HANDLED)
    return

  ; schedule the next run of this handler
  SetTimer, DragStart, % -1 * Abs(PollFrequency)

  ; if status is still NEW
  ; user is starting to drag
  ; initialize scrolling
  if (DragStatus == DS_NEW)
  {
    ; Update the status, we're dragging now
    DragStatus := DS_DRAGGING

    ; Update the cursor & trayicon
    SetTrayIcon(hIconDragging)
    if (ChangeMouseCursor)
    {
      if (ChangedCursorStyle = "cursorScrollPointer")
      {
        ;// show GUI with scrolling icon
        Gui, 98: Show, x%OriginalX% y%OriginalY% NoActivate
        Gui, 98: +LastFound
        WinSet, AlwaysOnTop, On
        ;// "hide" cursor by replacing it with blank cursor (from the AHK help file for DllCall command)
        VarSetCapacity(AndMask, 32*4, 0xFF)
        VarSetCapacity(XorMask, 32*4, 0)
        SetSystemCursor(DllCall("CreateCursor", "uint", 0, "int", 0, "int", 0, "int", 32, "int", 32, "uint", &AndMask, "uint", &XorMask))
      } 
      else
        SetSystemCursor(hIconDragging)
    }

    ; set up for next pass
    ; to find the difference (New - Old)
    OldX := OriginalX
    OldY := OriginalY
  }
  Else
  {
    ; DragStatus is now DRAGGING
    ; get the new mouse position and new hovering window
    MouseGetPos, NewX, NewY, NewWinHwnd, NewCtrlHwnd, 3

    ;ToolTip % "@(" . NewX . "X , " . NewY . "Y) ctrl_" . CtrlClass . "   win_" . WinClass . "     " . WinProcessName

    ; If the old and new HWNDs do not match,
    ; We have moved out of the original window.
    ; If "Constrain" mode is on, stop scrolling.
    if (ConfineToControl && CtrlHwnd != NewCtrlHwnd)
      GoSub DragStop
    if (ConfineToWindow && WinHwnd != NewWinHwnd)
      GoSub DragStop

    ; Calculate/Scroll - X
    ; Find the absolute difference in X values
    ; i.e. the amount the mouse moved in _this iteration_ of the DragStart handler
    ; If the distance the mouse moved is over the threshold,
    ; then scroll the window & update the coords for the next pass
    DiffX := NewX - OldX
    if (abs(DiffX) > DragThreshold)
    {
      SetTimer, MovementCheck, Off
      Scroll(DiffX, true)
      if (DragThreshold > 0) && (!KeepCursorStationary)
        OldX := NewX
    }

    ; Calculate/Scroll  - Y
    ; SAME AS X
    DiffY := NewY - OldY
    if (abs(DiffY) > DragThreshold)
    {
      SetTimer, MovementCheck, Off
      Scroll(DiffY)
      if (DragThreshold > 0) && (!KeepCursorStationary)
        OldY := NewY
    }

    if (KeepCursorStationary)
      MouseMove, OriginalX, OriginalY
    else if (ChangedCursorStyle = "cursorScrollPointer")
      Gui, 98: Show, x%NewX% y%NewY% NoActivate

    ; Check for window edge scrolling 
    GoSub CheckEdgeScrolling

    ; a threshold of 0 means we update coords
    ; and attempt to drag every iteration.
    ; whereas with a positive non-zero threshold,
    ; coords are updated only when threshold crossing (above)
    if (DragThreshold <= 0) && (!KeepCursorStationary)
    {
      OldX := NewX
      OldY := NewY
    }
  }
Return

; Handler for stopping and cleaning up after a drag is started
; We should always call this after every click is handled
;
DragStop:
  ; stop drag timer immediately
  SetTimer, DragStart, Off

  ; finish drag
  DragStatus := DS_HANDLED
Return

; Handler for skipping a drag
; This just passes the mouse click.
;
DragSkip:
  DragStatus := DS_HANDLED
  Send {%Button%}
Return

; Entering the HOLDING state
HoldStart:
  ; abort any pending drag, update status, start holding
  SetTimer, DragStart, Off
  DragStatus := DS_HOLDING
  Send, {%Button% Down}
  GoSub UpdateTrayIcon
  if (ChangeMouseCursor)
  {
    RestoreSystemCursor()
    if (ChangedCursorStyle = "cursorScrollPointer")
      Gui, 98: Hide
  }
Return

; Exiting the HOLDING state. 
; Should probably mark DragStatus as handled
HoldStop:
  DragStatus := DS_HANDLED
  Send {%Button% Up}
  GoSub UpdateTrayIcon
Return

; This handler allows a click-hold to abort dragging,
; if the mouse has not moved beyond a threshold
MovementCheck:
  Critical
  ; Calculate the distance moved, pythagorean thm
  MouseGetPos, MoveX, MoveY
  MoveDist := sqrt((OriginalX - MoveX)**2 + (OriginalY - MoveY)**2)

  ; if we havent moved past the threshold start hold
  if (MoveDist <= MovementThreshold)
    GoSub, HoldStart
  Critical, Off
Return

; Handler to apply momentum at DragStop
; This code continues to scroll the window if
; a "fling" action is detected, where the user drags
; and releases the drag while moving at a minimum speed
;
DragMomentum:

  ; Check for abort cases
  ;  momentum disabled
  ;  below threshold to use momentum
  if (abs(DiffYSpeed) <= MomentumThreshold)
    return
  if (!Get("UseScrollMomentum"))
    return

  ; passed checks, now using momentum
  DragStatus := DS_MOMENTUM

  ; Immediately stop dragging, 
  ; momentum should not respond to mouse movement
  SetTimer, DragStart, Off

  ; capture the speed when mouse released
  ; we want to gradually slow to scroll speed
  ; down to a stop from this initial speed
  mSpeed := DiffYSpeed * (Get("InvertDrag")?-1:1)

  Loop
  {
    ; stop case: status changed, indicating a user abort
    ; another hotkey thread has picked up execution from here
    ; simply exit, do not reset.
    if (DragStatus != DS_MOMENTUM)
      Exit

    ; stop case: momentum slowed to minum speed
    if (abs(mSpeed) <= MomentumStopSpeed)
      return

    ; for each iteration in the loop,
    ; reduce the momentum speed linearly
    ; scroll the window
    mSpeed *= MomentumInertia
    Scroll(mSpeed, false, "speed")

    Sleep % Abs(PollFrequency)
  }
Return

; Implementation of Scroll
;
; Summary:
;  This is the business end, it simulates input to scroll the window.
;  This handler is called when the mouse cursor has been click-dragged
;  past the drag threshold.
;
;  Arguments:
;  * arg
;   - measured in Pixels, can just pass mouse coords difference
;   - the sign determins direction: positive is down or right
;   - the magnitude determines speed
;  * horizontal
;   - Any non-zero/null/empty value 
;     will scroll horizontally instead of vertically
;  * format
;   - Used in some rare cases where passing in 'speed' instead of px
;
;  The goal is to take the amount dragged (arg), and convert it into
;  an appropriate amount of scroll in the window (Factor).
;  First we scale the drag-ammount, according to speed and acceleration
;  to the final scroll amount.
;  Then we scroll the window, according to the method selected.
;
Scroll(arg, horizontal="", format="px")
{
  global
  local Direction, Factor, Method, wparam

  ; get the speed and direction from arg arg
  Direction := ( arg < 0 ? -1 : 1 ) * ( Get("InvertDrag") ? -1 : 1 )
  Factor := abs( arg )

  ; Special "hidden" setting, for edge cases (visual studio 2010)
  if (horizontal && Get("InvertDragX"))
    Direction *= -1

  ; Do the math to convert this raw px measure into scroll speed
  if (format = "px")
  {
    ; Scale by the user-set scroll speed & const adjust
    if (!horizontal)
      Factor *= Get("SpeedY") * Y_ADJUST
    else
      Factor *= Get("SpeedX") * X_ADJUST

    ; Scale by the acceleration function, if enabled
    if (!horizontal && Get("UseAccelerationY"))
      Factor := Accelerate(Factor)
    if (horizontal && Get("UseAccelerationX"))
      Factor := Accelerate(Factor)
  }

  ;if (!horizontal) ToolTip, Speed: %arg% -> %Factor%

  ; Capture the current speed
  if (!horizontal)
    DiffYSpeed := Factor * Direction
  else
    DiffXSpeed := Factor * Direction

  ; Get the requested scroll method    
  if (!horizontal)
    Method := Get("ScrollMethodY")
  else
    Method := Get("ScrollMethodX")

  ; Do scroll
  ;  According to selected method
  ;  wparam is used in all methods, as the final "message" to send.
  ;  All methods check for direction by comparing (NewY < OldY)
  if (Method = mWheelMessage)
  {
    ; format wparam; one wheel tick scaled by yFactor
    ; format and send the message to the original window, at the original mouse location
    wparam := WHEEL_DELTA * Direction * Factor
    ;ToolTip, %arg% -> %factor% -> %wparam%
    if (!horizontal)
      PostMessage, WM_MOUSEWHEEL, (wparam<<16), (OriginalY<<16)|OriginalX,, %Target%
    else
    {
      wparam *= -1 ; reverse the direction for horizontal
      PostMessage, WM_MOUSEHWHEEL, (wparam<<16), (OriginalY<<16)|OriginalX,, %Target%
    }
  }
  else if (Method = mWheelKey)
  {
    ; format wparam; either WheelUp or WheelDown
    ; send as many messages needed to scroll at the desired speed
    if (!horizontal)
      wparam := Direction < 0 ? "{WheelDown}" : "{WheelUp}"
      else
        wparam := Direction < 0 ? "{WheelRight}" : "{WheelLeft}"

        Loop, %Factor%
          Send, %wparam%
      }
      else if (Method = mScrollMessage)
      {
        ; format wparam; either LINEUP, LINEDOWN, LINELEFT, or LINERIGHT
        ; send as many messages needed to scroll at the desired speed
        if (!horizontal)
        {
          wparam := Direction < 0 ? SB_LINEDOWN : SB_LINEUP
          Loop, %Factor%
            PostMessage, WM_VSCROLL, wparam, 0,, Ahk_ID %CtrlHwnd%
        }
        else
        {
          wparam := Direction < 0 ? SB_LINERIGHT : SB_LINELEFT
          Loop, %Factor%
            PostMessage, WM_HSCROLL, wparam, 0,, Ahk_ID %CtrlHwnd%
        }
      }
    }

    ; Handler to check for edge scrolling
    ; Activated when the mouse is dragging and stops
    ; within a set threshold of the window's edge
    ; Causes the window to keep scrolling at a set rate
    ;
    CheckEdgeScrolling:
      if (!Get("UseEdgeScrolling"))
        return

      ; Get scrolling window position
      WinGetPos, WinX, WinY, WinWidth, WinHeight, ahk_id %WinHwnd%
      ; Find mouse position relative to the window
      WinMouseX := NewX - WinX
      WinMouseY := NewY - WinY

      ; find which edge we're closest to and the distance to it
      InLowerHalf := (WinMouseY > WinHeight/2)
      EdgeDistance := (InLowerHalf) ? Abs( WinHeight - WinMouseY ) : Abs( WinMouseY )
      ;atEdge := (EdgeDistance <= EdgeScrollingThreshold ? " @Edge" : "")         ;debug 
      ;ToolTip, %WinHwnd%: %WinMouseY% / %WinHeight% -> %EdgeDistance%  %atEdge%  ;debug

      ; if we're close enough, scroll the window
      if (EdgeDistance <= EdgeScrollingThreshold)
      {
        ; prep and call scrolling
        ; the second arg requests the scroll at the set speed without accel
        arg := (InLowerHalf ? 1 : -1) * (Get("InvertDrag") ? -1 : 1) * Get("EdgeScrollSpeed")
        Scroll(arg, false, "speed")
      }
    Return

    ; Settings Functions
    ;--------------------------------

    ; A wrapper around the GetSetting function.
    ; Returns the ini GetSetting value, or the
    ; in-memory global variable of the same name.
    ;
    ; Provides and easy and seamless wrapper to 
    ; overlay user preferences on top of app settings.
    ;
    Get(name, SectionName="")
    {
      global
      local temp

      if (DEBUG)
      {
        temp := %name%
        return temp 
      }

      temp := GetSetting(name, SectionName)
      if (temp != "")
        return temp
      else
      {
        temp := %name%
        return temp 
      }
    }

    ; Retrieves a named setting from the global ini
    ; This function operates both as a "search" of
    ; the ini, as well as a named get. You can optionally
    ; specify a section name to retrieve a specific value.
    ;
    ; By Default, this searches the ini file in any of
    ; a set of valid SectionNames. The default section 'General'
    ; is a last resort, if an app specific setting was not found.
    ; Section names are searched for the target control class,
    ; window class, and process name. If any of these named sections
    ; exist in ini, its key value is returned first.
    ;
    GetSetting(name, SectionName="")
    {
      global INI_GENERAL
      global CtrlClass, WinClass, WinProcessName, WinProcessPath
      global ini, ConfigSections

      ; find the section, using the cached list
      if (!SectionName)
      {
        ; by control class
        IfNotEqual, CtrlClass
        If CtrlClass in %ConfigSections%
          SectionName := CtrlClass
        ; by window class
        IfNotEqual, WinClass
        If WinClass in %ConfigSections%
          SectionName := WinClass
        ; by process name
        IfNotEqual, WinProcessName
        If WinProcessName in %ConfigSections%
          SectionName := WinProcessName
        ; by process path
        IfNotEqual, WinProcessPath, 
        If WinProcessPath in %ConfigSections%
          SectionName := WinProcessPath

        ; last chance
        if (!SectionName)
          SectionName := INI_GENERAL
      }

      ;get the value
      temp := ini_getValue(ini, SectionName, name)

      ; check for special keywords
      if (temp = "false")
        temp := 0
      if (temp = "true")
        temp := 1

      ;if (SectionName != INI_GENERAL)
      ;  ToolTip, % "Request " . name . ":`n" . ini_getSection(ini, SectionName)

    return temp
  }

  ; Saves a setting/variable to the ini file
  ; in the given section name (default General)
  ; with the given value, or the current variable value
  ;
  SaveSetting(name, value="", SectionName="General")
  {
    ; prep value
    global
    local keyList, temp

    if (SectionName = "")
    {
      MsgBox, 16, DtS, Setting Save Failed `nEmpty SectionName
    return
  }

  keyList := ini_getAllKeyNames(ini, SectionName)
  if (!value)
    value := %name%

  ; if no section
  if SectionName not in %ConfigSections%
  {
    if (!ini_insertSection(ini, SectionName, name . "=" . value))
    {
      MsgBox, 16, DtS, Setting Save Failed `ninsertSection %ErrorLevel%
    return
  }
  ConfigSections := ini_getAllSectionNames(ini)
}
; if no value
else if name not in %keyList%
{
  if (!ini_insertKey(ini, SectionName, name . "=" . value))
  {
    MsgBox, 16, DtS, Setting Save Failed `ninsertKey %ErrorLevel%
    return
  }
}
; value exists, Update
else
{
  if (!ini_replaceValue(ini, SectionName, name, value))
  {
    MsgBox, 16, DtS, Setting Save Failed `nreplaceValue %ErrorLevel%
    return
  }
}

; finally save the setings
ini_save(ini)
if (ErrorLevel)
  MsgBox, 16, DtS, Settings File Write Failed
}

; An initialization function for settings
; The given variable name should be created
; with the value loaded from ini General Section
; or, if not set, the provided default 
;
Setting(variableName, defaultValue)
{
  global
  local value

  %variableName%_d := defaultValue

  if variableName not in %SettingsList%
    SettingsList .= (SettingsList != "" ? "," : "") . variableName

  value := GetSetting(variableName, INI_GENERAL)
  if (value != "")
    %variableName% := value
  else
    %variableName% := defaultValue
}

; check and reload of settings
;
LoadLocalSettings:
  Critical
  ini_load(temp)
  changed := (temp != ini)

  if (temp = "" && SettingsList = "")
    GoSub, ApplySettings

  if (A_ThisMenuItem != "")
    ToolTip("Reloading Settings..." . (changed ? " Change detected." : ""))

  if (!changed || temp = "")
    return

  ; apply new ini
  ini := temp
  GoSub, LoadLocalSettingSections
  GoSub, ApplySettings
  Critical, Off
Return

LoadLocalSettingSections:
  ; apply new config sections
  ConfigSections=
  ConfigProfileSections=
  temp := ini_getAllSectionNames(ini)
  Loop, Parse, temp, `,
  {
    ConfigSections .= (ConfigSections != "" ? "," : "") . A_LoopField
    if A_LoopField not in %INI_EXCLUDE%
      ConfigProfileSections .= (ConfigProfileSections != "" ? "," : "") . A_LoopField
  }
Return

;
; Retrieve the full path of a process with ProcessID
; thanks to HuBa & shimanov
; http://www.autohotkey.com/forum/viewtopic.php?t=18550
;
GetModuleFileNameEx(ProcessID) ; modified version of shimanov's function
{
  if A_OSVersion in WIN_95, WIN_98, WIN_ME
    Return

  ; #define PROCESS_VM_READ           (0x0010)
  ; #define PROCESS_QUERY_INFORMATION (0x0400)
  hProcess := DllCall( "OpenProcess", "UInt", 0x10|0x400, "Int", False, "UInt", ProcessID)
  if (ErrorLevel or hProcess = 0)
    Return
  FileNameSize := 260 * (A_IsUnicode ? 2 : 1)
  VarSetCapacity(ModuleFileName, FileNameSize, 0)
  CallResult := DllCall("Psapi.dll\GetModuleFileNameEx", "Ptr", hProcess, "Ptr", 0, "Str", ModuleFileName, "UInt", FileNameSize)
  DllCall("CloseHandle", "Ptr", hProcess)
Return ModuleFileName
}

; Settings Gui : App Settings
;--------------------------------

GuiAppSettings:
  if (!GuiAppBuilt)
    GoSub, GuiAppSettingsBuild
  Gui, 2:Show,, DtS App Settings
  GoSub, GuiAppSectionLoad
Return

GuiAppSettingsBuild:
  GuiAppBuilt := true
  Gui +Delimiter|
  Gui, 2:Default
  Gui, Add, Text, x10 y5, Process name (chrome.exe) or window class:
  Gui, Add, ComboBox, x10 y20 w225 h20 r10 vGuiAppSection gGuiAppSectionChange
  Gui, Add, Button, x240 y20 w20 h20 gGuiAppSectionRemove , -
  Gui, Add, GroupBox, x10 y42 w250 h76 , Scroll Method
  Gui, Add, Text, x20 y63 w10 h10 , Y
  Gui, Add, Text, x20 y93 w10 h10 , X
  Gui, Add, DropDownList, x32 y60 w218 h20 r3 Choose1 vGuiScrollMethodY , WheelMessage|WheelKey|ScrollMessage
  Gui, Add, DropDownList, x32 y90 w218 h20 r3 Choose1 vGuiScrollMethodX , WheelMessage|WheelKey|ScrollMessage

  Gui, Add, GroupBox, x10 y120 w250 h80 , Speed && Acceleration
  Gui, Add, Text, x20 y143 w10 h20 , Y
  Gui, Add, Edit, x30 y140 w40 h20 vGuiSpeedY
  Gui, Add, UpDown
  Gui, Add, CheckBox, x75 y140 w50 h20 vGuiUseAccelerationY , Accel
  Gui, Add, Text, x140 y143 w10 h20 , X
  Gui, Add, Edit, x150 y140 w40 h20 vGuiSpeedX
  Gui, Add, UpDown
  Gui, Add, CheckBox, x195 y140 w50 h20 vGuiUseAccelerationX , Accel
  Gui, Add, CheckBox, x20 y165 w100 h20 vGuiUseEdgeScrolling , Edge Scrolling
  Gui, Add, Edit, x150 y170 w40 h20 vGuiEdgeScrollSpeed
  Gui, Add, UpDown
  Gui, Add, Text, x195 y168 w60 r2, Edge Speed

  Gui, Add, GroupBox, x10 y200 w250 h110 , Options
  Gui, Add, CheckBox, x20 y220 w170 h20 vGuiScrollDisabled , Scroll Disabled
  Gui, Add, CheckBox, x20 y240 w170 h20 vGuiUseScrollMomentum , Scroll Momentum
  Gui, Add, CheckBox, x20 y260 w170 h20 vGuiInvertDrag , Invert Drag
  Gui, Add, CheckBox, x20 y280 w170 h20 vGuiUseMovementCheck , Movement Check
  Gui, Add, Button, x10 y315 w120 h30 Default gGuiAppApply , Apply
  Gui, Add, Button, x140 y315 w120 h30 gGuiClose , Close
Return

GuiAppSectionLoad:
  Gui, +Delimiter`,
  GuiControlGet, temp,, GuiAppSection
  GuiControl, , GuiAppSection, % "," . ConfigProfileSections
  if temp in %ConfigProfileSections%
    GuiControl, ChooseString, GuiAppSection, %temp%
  else
    GuiControl, Choose, GuiAppSection, 1
  GoSub, GuiAppSectionChange
Return

GuiAppSectionRemove:
  GuiControlGet, GuiAppSection
  if (GuiAppSection = INI_GENERAL)
  {
    Msgbox, 16, DtS Configuration, Cannot delete the general settings section
    Return
  }
  MsgBox, 36, DtS Configuration, Are you sure you want to delete settings for this section?`n %GuiAppSection%
  IfMsgBox, Yes
  {
    ini_replaceSection(ini, GuiAppSection)
    ini_save(ini)
    GoSub, LoadLocalSettingSections
    GoSub, GuiAppSectionLoad
  } 
Return

GuiAppSectionChange:
  GuiControlGet, GuiAppSection
  if (GuiAppSection not in ConfigProfileSections)
    return
  ;DDLs
  temp=ScrollMethodX,ScrollMethodY
  Loop, Parse, temp, `,
    GuiControl, Choose, Gui%A_LoopField%, % Get(A_LoopField, GuiAppSection)
  ;Checkboxes & Edit boxes
  temp=UseAccelerationX,UseAccelerationY,UseEdgeScrolling,ScrollDisabled,UseScrollMomentum,InvertDrag,UseMovementCheck,SpeedX,SpeedY,EdgeScrollSpeed
  Loop, Parse, temp, `,
    GuiControl,, Gui%A_LoopField%, % Get(A_LoopField, GuiAppSection)
Return

GuiAppApply:
  GuiControlGet, GuiAppSection
  if (GuiAppSection = "")
  {
    MsgBox, Type in an application's process name, or window class, or process path
    GuiControl, Focus, GuiAppSection
    return
  }
  temp=ScrollMethodX,ScrollMethodY,UseAccelerationX,UseAccelerationY,UseEdgeScrolling,ScrollDisabled,UseScrollMomentum,InvertDrag,UseMovementCheck,SpeedX,SpeedY,EdgeScrollSpeed
  Loop, Parse, temp, `,
  {
    GuiControlGet, value,, Gui%A_LoopField%
    SaveSetting(A_LoopField, value, GuiAppSection)
  }

  GoSub, LoadLocalSettingSections
  GoSub, GuiAppSectionLoad
Return

; Settings Gui : All Settings
;--------------------------------

GuiAllSettings:
  if (!GuiAllBuilt)
    GoSub, BuildGuiAllSettings
  Gui, 3:Show,, DtS All Settings
Return

BuildGuiAllSettings:
  GuiAllBuilt := true
  Gui, 3:Default
  wSp := 5, wCH := 20, wCW := 150, wOffset := 60, wCX := wSp*2 + wCW, wCX2 := wSp*4 + wCW*2, wCX3 := wSp*5 + wCW*3
  Gui, Add, Text, x%wSp% y%wSp%, This lists all settings registered with this script. `nChanging values and pressing 'Ok' immediately updates the setting in memory, `nand writes your changes to the ini General section
  Loop, Parse, SettingsList, `,
  {
    if (A_LoopField = "")
      continue

    temp := A_LoopField . "_d"
    color := ( %A_LoopField% == %temp% ? "" : "cBlue")
    temp := %A_LoopField%

    left := !left 
    if (left)
    {
      Gui, Add, Text, x%wSp% y%wOffset% w%wCW% h%wCH% right, %A_LoopField%
      Gui, Add, Edit, x%wCX% y%wOffset% w%wCW% h%wCH% center %color% v%A_LoopField% gGuiAllEvent, %temp%
    }
    else
    {
      Gui, Add, Text, x%wCX2% y%wOffset% w%wCW% h%wCH% right, %A_LoopField%
      Gui, Add, Edit, x%wCX3% y%wOffset% w%wCW% h%wCH% center %color% v%A_LoopField% gGuiAllEvent, %temp%
      wOffset += wCH + wSp
    }
  }

  if (left)
    wOffset += wCH + wSp * 3
  else
    wOffset += wSp * 2

  Gui, Font, bold
  Gui, Add, Button, x%wCX% y%wOffset% w%wCW% h%wCH% Default gGuiAllOk, Ok
  Gui, Add, Button, x%wCX2% y%wOffset% w%wCW% h%wCH% gGuiClose, Cancel
  wOffset += wCH + wSp
Return

GuiAllEvent:
  GuiControlGet, value,, %A_GuiControl%
  temp := A_GuiControl . "_d"
  temp := %temp%

  if (temp != value)
    GuiControl, +cBlue, %A_GuiControl%
  else
    GuiControl, +cDefault, %A_GuiControl%
Return

GuiAllOk:
  GuiControlGet, temp, ,Button
  Hotkey, %temp%,, UseErrorLevel
  if ErrorLevel in 5,6
  {
    HotKey, %Button%, Off
    HotKey, %Button% Up, Off
    HotKey, ^%Button%, Off
    HotKey, ^%Button% Up, Off
  }

  Gui, Submit
  Loop, Parse, SettingsList, `,
  {
    if (A_LoopField = "")
      continue
    SaveSetting(A_LoopField)
  }
  GoSub, mnuEnabledInit
Return

GuiClose:
  Gui, %A_Gui%:Cancel
Return

; Menu
;--------------------------------

; This section builds the menu of system-tray icon for this script
; MenuInit is called in the auto-exec section of this script at the top.
;
MenuInit:

  ;
  ; SCRIPT SUBMENU
  ;

  Menu, mnuScript, ADD, Reload, mnuScriptReload
  Menu, mnuScript, ADD, Reload Settings, LoadLocalSettings

  Menu, mnuScript, ADD, Debug, mnuScriptDebug

  Menu, mnuScript, ADD
  if (!A_IsCompiled)
    Menu, mnuScript, ADD, Open/Edit Script, mnuScriptEdit
  Menu, mnuScript, ADD, Open Directory, mnuScriptOpenDir
  Menu, mnuScript, ADD, Open Settings File, mnuScriptOpenSettingsIni
  IfExist, Readme.txt
    Menu, mnuScript, ADD, Open Readme, mnuScriptOpenReadme
  Menu, mnuScript, Add, Open Discussion, mnuScriptOpenDiscussion

  ;
  ; SETTINGS SUBMENU
  ;

  Menu, mnuSettings, ADD, All Settings, GuiAllSettings
  Menu, mnuSettings, ADD, App Specific Settings, GuiAppSettings

  ;
  ; TRAY MENU
  ;

  ; remove standard, and add name (w/ reload)
  Menu, Tray, NoStandard
  Menu, Tray, Icon, %A_ScriptDir%\res\dragicon.ico
  Menu, Tray, Add, Drag To Scroll v%VERSION%, dummy
  Menu, Tray, Default, Drag To Scroll v%VERSION%
  Menu, Tray, add, Toggle Pause, togglePause
  Menu, Tray, Add, Edit, Edit
  Menu, Tray, Add, Reload, Reload

  ; Enable/Disable
  ; Add the menu item and initialize its state
  ;~ Menu, Tray, ADD, Enabled, mnuEnabled
  GoSub, mnuEnabledInit

  ; submenus
  ;~ Menu, Tray, ADD, Script, :mnuScript
  ;~ Menu, TRAY, ADD, Settings, :mnuSettings

  ; exit
  Menu, TRAY, ADD
  Menu, TRAY, ADD, Exit, mnuExit

Return

Edit:
  Edit
return

; Menu Handlers
;--------------------------------

; Simple menu handlers for 'standard' replacements
mnuScriptReload:
Reload:
  Reload
Return

mnuScriptDebug: 
  ListLines
Return

mnuScriptOpenDir: 
  Run, %A_ScriptDir%
Return

mnuScriptEdit:
  Edit
Return

mnuScriptOpenSettingsIni:
  IfExist, DragToScroll.ini
    Run DragToScroll.ini
  Else
    MsgBox, 16, DtS, DragToScroll.ini not found...
Return

mnuScriptOpenReadme:
  IfExist, Readme.txt
    Run, Readme.txt
  Else
    MsgBox, 16, DtS, Readme.txt not found...
Return

mnuScriptOpenDiscussion:
  Run, %URL_DISCUSSION%
Return

mnuExit:
  ExitApp
Return

; This section defines the handlers for these above menu items
; Each handler has an inner 'init' label that allows the handler to
; both to set the initial value and to change the value, keeping the menu in sync.
; Each handler either sets, or toggles the associated property
;

dummy:
return

togglePause:
  Suspend, toggle
  Pause,toggle,1
return 

mnuEnabled:
  ScrollDisabled := !ScrollDisabled
  ToolTip("Scrolling " . (ScrollDisabled ? "Disabled" : "Enabled"), 1)
  GoSub, DragStop ; safety measure. force stop all drags
mnuEnabledInit:
  if (!ScrollDisabled)
  {
    ;~ Menu, TRAY, Check, Enabled
    ;~ Menu, TRAY, tip, Drag To Scroll v%VERSION%
    HotKey, %Button%, ButtonDown, On
    HotKey, %Button% Up, ButtonUp, On
    HotKey, ^%Button%, DisabledButtonDown, On
    HotKey, ^%Button% Up, DisabledButtonUp, On
    HotKey, ~LButton, ToolTipCancel, On
  }
  else
  {
    ;~ Menu, TRAY, Uncheck, Enabled
    ;~ Menu, TRAY, tip, Drag To Scroll v%VERSION% (Disabled)
    HotKey, %Button%, Off
    HotKey, %Button% Up, Off
    HotKey, ^%Button%, Off
    HotKey, ^%Button% Up, Off
  }

  Gosub, UpdateTrayIcon
Return

; Update the tray icon for the current script
; to the icon represented by the handle
;
SetTrayIcon(iconHandle)
{
  PID := DllCall("GetCurrentProcessId"), VarSetCapacity( NID,444,0 ), NumPut( 444,NID )
  DetectHiddenWindows, On
  NumPut( WinExist( A_ScriptFullPath " ahk_class AutoHotkey ahk_pid " PID),NID,4 )
  DetectHiddenWindows, Off
  NumPut( 1028,NID,8 ), NumPut( 2,NID,12 ), NumPut( iconHandle,NID,20 )
  DllCall( "shell32\Shell_NotifyIcon", UInt,0x1, UInt,&NID )
}

; Set the mouse cursor
; Thanks go to Serenity -- http://www.autohotkey.com/forum/topic35600.html
;
SetSystemCursor(cursorHandle)
{
  Cursors = 32512,32513,32514,32515,32516,32640,32641,32642,32643,32644,32645,32646,32648,32649,32650,32651
  Loop, Parse, Cursors, `,
  {
    temp := DllCall( "CopyIcon", UInt,cursorHandle)
    DllCall( "SetSystemCursor", Uint,temp, Int,A_Loopfield )
  }
}

RestoreSystemCursor()
{
  DllCall( "SystemParametersInfo", UInt,0x57, UInt,0, UInt,0, UInt,0 )
}

; Update the tray icon automatically
; to the Enabled or Disabled state
; Called by the menu handler
;
UpdateTrayIcon:
  if (ScrollDisabled)
    SetTrayIcon(hIconDisabled)
  else
    SetTrayIcon(hIconEnabled)
Return

; Function wrapper to set a tooltip with automatic timeout
;
ToolTip(Text, visibleSec=2)
{
  ToolTip, %Text%
  SetTimer, ToolTipCancel, % abs(visibleSec) * -1000
return 

ToolTipCancel:
  ToolTip
Return
}

; My Own Modifications

StartPhase: ; On Button Down
return
SetTimer, Check_for_PressedDown_Keys, 50
return

EndPhase: ; On Button Up
return
gosub, Check_for_PressedDown_Keys_OFF
ToolTip
return

Check_for_PressedDown_Keys_OFF:
  SetTimer, Check_for_PressedDown_Keys, Off
return

Check_for_PressedDown_Keys:
  GetKeyState, keystate, LButton
  if keystate = D 
  {
    ToolTip, You just pressed LButton but you can modify this
    gosub, Check_for_PressedDown_Keys_OFF
  } else { 

  } return  

showNotification(message) {
  Notify:=Notify(15)
  Notify.AddWindow(message
  , {Title: "Drag To Scroll" , TitleColor: "White"
  , Background: "Grey", Color: "White", Font: "Consolas"
  , FlashColor: "0xA8CEFF"
  , ShowDelay:200, Radius:15
  , Time: 3000, Size: 20, Flash: 500
  , Icon: A_ScriptDir "\res\dragicon.ico"
  , Animate: "Blend"})
}