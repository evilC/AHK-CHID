; REQUIRES TEST BUILD OF AHK FROM http://ahkscript.org/boards/viewtopic.php?f=24&t=5802#p33610
#include <CHID>
AHKHID_UseConstants()
#singleinstance force

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
Gui, Add, Listview, w651 h400 vlvDLDBG AltSubmit +Grid,Tick|Text
LV_Modifycol(1,80)

Gui, Show,, Joystick Info

HID := new CHID()
NumDevices := HID.GetRawInputDeviceList()
HID.GetRawInputDeviceList(DeviceList,NumDevices)
DevSize := HID.GetRawInputDeviceInfo(DeviceList[1].hDevice)

AxisNames := ["X","Y","Z","RX","RY","RZ","SL0","SL1"]
DevData := []

SelectedDevice := 0

Gui,ListView,lvDL
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
    global SelectedDevice
	
    If (!pcbSize:=HID.GetRawInputData(lParam))
		return
	;~ if (pcbSize!=iSize)
		;~ MsgBox % pcbSize "-" iSize
	if (-1 = ret := HID.GetRawInputData(lParam,,pRawInput, pcbSize))
        return
	;~ MsgBox % SelectedDevice "-" pRawInput.header.hDevice "-" handle
	;~ Sleep 500
    handle := pRawInput.header.hDevice
	if (handle = 0)
		MsgBox error handle 0
	if (handle != SelectedDevice){
		return
	}
    devtype := pRawInput.header.dwType
    if (devtype != HID.RIM_TYPEHID){
        return
    }

    ; Get device info - this does not really need to be done on WM_INPUT, it's just for checks
    DevSize := HID.GetRawInputDeviceInfo(handle)
    HID.GetRawInputDeviceInfo(handle, HID.RIDI_DEVICEINFO, pData, DevSize)
    UsagePage := pData.hid.usUsagePage
    Usage := pData.hid.usUsage
    vid := pData.hid.dwVendorId
    pid := pData.hid.dwProductId
    vid := Format("{:x}",vid)
    pid := Format("{:x}",pid)
    
    ; Get Preparsed Data
    ppSize := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA)
    ret := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA, PreparsedData, ppSize)
    ret := HID.HidP_GetCaps(PreparsedData, Caps)
	;~ OutputDebug % ret "-" ppSize "-" HID.ErrMsg()
    if (ret != 0){
        MsgBox 3
    }
    ;return
    Axes := ""
    Hats := 0
    btns := 0
    ; Buttons
	
    if (Caps.NumberInputButtonCaps) {
        ; next line makes code CRASH. Same code is used @ line 63, so why does it not work here?
        HID.HidP_GetButtonCaps(0, pButtonCaps, Caps.NumberInputButtonCaps, PreparsedData)
		btns := (Range:=pButtonCaps.1.Range).UsageMax - Range.UsageMin + 1
        UsageLength := btns
        
        Gui,ListView,lvDLDBG
        LV_Add("",A_TickCount,"UsagePage/Usage: " UsagePage "/" Usage "  |  vid/pid: " VID "/" PID "  |  Buttons: " btns)
        ;ret := HID.HidP_GetUsages(0, pButtonCaps.1.UsagePage, 0, UsageList, UsageLength, PreparsedData, pRawInput.hid.bRawData, pRawInput.hid.dwSizeHid)
    }
    return

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
    ;LV_Add("",A_TickCount,Axes)
	;LV_Add("",A_TickCount,"UsagePage/Usage: " UsagePage "/" Usage "  |  vid/pid: " VID "/" PID "  |  Buttons: " btns "  |  Axes: " Count)
    ;MsgBox % "buttons: " btns
}

SelectDevice:
    LV_GetText(s, LV_GetNext())
    if (A_GuiEvent = "i" && s > 0){
        ; Register Device
        handle := DeviceList[s].hDevice
        rid := new _struct(WinStructs.RAWINPUTDEVICE)
        rid.usUsagePage := DevData[s].hid.usUsagePage
        rid.usUsage := DevData[s].hid.usUsage
        rid.hwndTarget := WinExist("A") ; A_ScriptHwnd
        ;rid.Flags := HID.RIDEV_INPUTSINK
        rid.dwFlags := 0
        
        ret := HID.RegisterRawInputDevices(rid, 1)
        SelectedDevice := handle
        OnMessage(0x00FF, "InputMsg")
        ;msgbox % ret
    }
    return

Esc::
GuiClose:
	ExitApp