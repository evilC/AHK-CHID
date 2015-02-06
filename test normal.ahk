#Include <_Struct>
#singleinstance force
#Include CHID.ahk

Gui +Resize -MaximizeBox -MinimizeBox
Gui, Add, Listview, w400 h300 vlvDL gSelectDevice AltSubmit,#|Name|VID|PID|UsagePage|Usage|Buttons
Gui, Show

HID := new CHID()
NumDevices := HID.GetRawInputDeviceList()
HID.GetRawInputDeviceList(DeviceList,NumDevices)
DevSize := HID.GetRawInputDeviceInfo(DeviceList[1].hDevice)

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
    if (Caps.NumberInputButtonCaps) {
      HID.HidP_GetButtonCaps(0, pButtonCaps, Caps.NumberInputButtonCaps, PreparsedData)
      btns := (Range:=pButtonCaps.1.Range).UsageMax - Range.UsageMin + 1
    } else btns:=0
    ; Update LV
	LV_Add(,A_INDEX, human_name, VID, PID, Data.hid.usUsagePage, Data.hid.usUsage, btns )
}

LV_Modifycol()
return

InputMsg(wParam, lParam) {
    global HID
    ;SoundBeep, 500, 100
    r := HID.GetRawInputData(lParam,,Data)
    ;msgbox % A_ThisFunc ": " r
    if (r > 0){
        tooltip % Data.hid.dwUsagePage
    }
    ;ri := new _Struct(WinStructs.RAWINPUT,,lParam)
    ;if (ri.header.Type = 2){
        ;tooltip % ri.header.hDevice
        ;tooltip % Data.hid.dwUsagePage
    ;}
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