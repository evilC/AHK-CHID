; REQUIRES TEST BUILD OF AHK FROM http://ahkscript.org/boards/viewtopic.php?f=24&t=5802#p33610
#Include <_Struct>
#singleinstance force
#Include CHID.ahk

Gui +Resize -MaximizeBox -MinimizeBox
Gui, Add, Listview, w651 h400 vlvDL gSelectDevice AltSubmit +Grid,#|Name|Btns|Axes|POVs|VID|PID|UsPage|Usage
LV_Modifycol(1,20)
LV_Modifycol(2,180)
LV_Modifycol(3,40)
LV_Modifycol(4,140)
LV_Modifycol(5,50)
LV_Modifycol(6,50)
LV_Modifycol(7,50)
LV_Modifycol(8,50)
LV_Modifycol(9,50)
Gui, Show,, Joystick Info

HID := new CHID()
NumDevices := HID.GetRawInputDeviceList()
HID.GetRawInputDeviceList(DeviceList,NumDevices)
DevSize := HID.GetRawInputDeviceInfo(DeviceList[1].hDevice)

AxisNames := ["X","Y","Z","RX","RY","RZ","SL0","SL1"]
DevData := []

Loop % NumDevices {
    ; Get device Handle
	dev := DeviceList[A_Index]
	if (dev.dwType != 2){
		continue
	}
	handle := DeviceList[A_Index].hDevice
    
    ; Get Device Info
	HID.GetRawInputDeviceInfo(handle, ,Data, DevSize)
    DevData[A_Index] := Data
    
    ; Find Human name from registry
    VID := Format("{:04x}", Data.hid.dwVendorID)
    StringUpper,VID, VID
    PID := Format("{:04x}", Data.hid.dwProductID)
    StringUpper,PID, PID
    if (Data.hid.dwVendorID = 0x45E && Data.hid.dwProductID = 0x28E){
        ; Dirty hack for now, cannot seem to read "SYSTEM\CurrentControlSet\Control\MediaProperties\PrivateProperties\Joystick\OEM\VID_045E&PID_028E"
        human_name := "XBOX 360 Controller"
    } else {
        key := "SYSTEM\CurrentControlSet\Control\MediaProperties\PrivateProperties\Joystick\OEM\VID_" VID "&PID_" PID
        RegRead, human_name, HKLM, % key, OEMName
    }
    ; Decode capabilities
    ppSize := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA)
    ret := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA, PreparsedData, ppSize)
    ret := HID.HidP_GetCaps(PreparsedData, Caps)
    Axes := ""
    Hats := 0
    btns := 0

    ; Buttons
    if (Caps.NumberInputButtonCaps) {
        HID.HidP_GetButtonCaps(0, pButtonCaps, Caps.NumberInputButtonCaps, PreparsedData)
        btns := (Range:=pButtonCaps.1.Range).UsageMax - Range.UsageMin + 1
    }
    ; Axes / Hats
    if (Caps.NumberInputValueCaps) {
        HID.HidP_GetValueCaps(0, pValueCaps, Caps.NumberInputValueCaps, PreparsedData)
        AxisCaps := {}
                Loop % Caps.NumberInputValueCaps {
            Type := (Range:=pValueCaps[A_Index].Range).UsageMin
            if (Type = 0x39){
                ; Hat
                Hats++
            } else if (Type >= 0x30 && Type <= 0x38) {
                ; If one of the known 8 standard axes
                Type -= 0x2F
                if (Axes != ""){
                    Axes .= ","
                }
                Axes .= AxisNames[Type]
                AxisCaps[AxisNames[Type]] := 1
            }
        }
        Axes := ""
        Count := 0
        ; Sort Axis Names into order
        Loop % AxisNames.MaxIndex() {
            if (AxisCaps[AxisNames[A_Index]] = 1){
                if (Count){
                    Axes .= ","
                }
                Axes .= AxisNames[A_Index]
                Count++
            }
        }
    }
    ; Update LV
    if (!btns && Axes = "" && !Hats){
        continue
    }
    if (human_name = ""){
        human_name := "Unknown"
    }
	LV_Add(,A_INDEX, human_name, btns, Axes, Hats, VID, PID, Data.hid.usUsagePage, Data.hid.usUsage )
}

;LV_Modifycol()
return

InputMsg(wParam, lParam) {
    global HID
    
    bufferSize := HID.GetRawInputData(lParam)
    ret := HID.GetRawInputData(lParam,,pRawInput, bufferSize)
    if (ret = -1){
        return
    }
    handle := pRawInput.header.hDevice
    if (handle){
        ppSize := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA)
        ret := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA, PreparsedData, ppSize)
        ret := HID.HidP_GetCaps(PreparsedData, Caps)
        Axes := ""
        Hats := 0
        btns := 0

        ; Buttons
        if (Caps.NumberInputButtonCaps) {
            HID.HidP_GetButtonCaps(0, pButtonCaps, Caps.NumberInputButtonCaps, PreparsedData)
            btns := (Range:=pButtonCaps.1.Range).UsageMax - Range.UsageMin + 1
        }
        ; Axes / Hats
        if (Caps.NumberInputValueCaps) {
            HID.HidP_GetValueCaps(0, pValueCaps, Caps.NumberInputValueCaps, PreparsedData)
            AxisCaps := {}
                    Loop % Caps.NumberInputValueCaps {
                Type := (Range:=pValueCaps[A_Index].Range).UsageMin
                if (Type = 0x39){
                    ; Hat
                    Hats++
                } else if (Type >= 0x30 && Type <= 0x38) {
                    ; If one of the known 8 standard axes
                    Type -= 0x2F
                    if (Axes != ""){
                        Axes .= ","
                    }
                    Axes .= AxisNames[Type]
                    AxisCaps[AxisNames[Type]] := 1
                }
            }
            Axes := ""
            Count := 0
            ; Sort Axis Names into order
            Loop % AxisNames.MaxIndex() {
                if (AxisCaps[AxisNames[A_Index]] = 1){
                    if (Count){
                        Axes .= ","
                    }
                    Axes .= AxisNames[A_Index]
                    Count++
                }
            }
        }
        ;MsgBox % "buttons: " btns
    }
}

SelectDevice:
    LV_GetText(s, LV_GetNext())
    if (A_GuiEvent = "i" && s > 0){
        ; Register Device
        handle := DeviceList[s].hDevice
        rid := new _struct(WinStructs.RAWINPUTDEVICE)
        rid.usUsagePage := DevData[s].hid.usUsagePage
        rid.usUsage := DevData[s].hid.usUsage
        rid.hwndTarget := A_ScriptHwnd
        ;rid.Flags := HID.RIDEV_INPUTSINK
        rid.dwFlags := 0
        
        ret := HID.RegisterRawInputDevices(rid, 1)
        OnMessage(0x00FF, "InputMsg")
        ;msgbox % ret
    }
    return

GuiSize:
    AutoXYWH("lvDL", "wh")
	return

Esc::
GuiClose:
	ExitApp

; =================================================================================
; Function:     AutoXYWH
;   Move and resize control automatically when GUI resized.
; Parameters:
;   ctrl_list  - ControlID list separated by "|".
;                ControlID can be a control HWND, associated variable name or ClassNN.
;   Attributes - Can be one or more of x/y/w/h
;   Redraw     - True to redraw controls
; Examples:
;   AutoXYWH("Btn1|Btn2", "xy")
;   AutoXYWH(hEdit      , "wh")
; ---------------------------------------------------------------------------------
; AHK version : 1.1.13.01
; Tested On   : Windows XP SP3 (x86)
; Release date: 2014-1-2
; Author      : tmplinshi
; =================================================================================
AutoXYWH(ctrl_list, Attributes, Redraw = False)
{
    static cInfo := {}, New := []

    Loop, Parse, ctrl_list, |
    {
        ctrl := A_LoopField

        if ( cInfo[ctrl]._x = "" )
        {
            GuiControlGet, i, Pos, %ctrl%
            _x := A_GuiWidth  - iX
            _y := A_GuiHeight - iY
            _w := A_GuiWidth  - iW
            _h := A_GuiHeight - iH
            _a := RegExReplace(Attributes, "i)[^xywh]")
            cInfo[ctrl] := { _x:_x, _y:_y, _w:_w, _h:_h, _a:StrSplit(_a) }
        }
        else
        {
            if ( cInfo[ctrl]._a.1 = "" )
                Return

            New.x := A_GuiWidth  - cInfo[ctrl]._x
            New.y := A_GuiHeight - cInfo[ctrl]._y
            New.w := A_GuiWidth  - cInfo[ctrl]._w
            New.h := A_GuiHeight - cInfo[ctrl]._h

            for i, a in cInfo[ctrl]["_a"]
                Options .= a New[a] A_Space
            
            GuiControl, % Redraw ? "MoveDraw" : "Move", % ctrl, % Options
        }
    }
}
