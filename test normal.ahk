#Include <_Struct>
#singleinstance force
#Include CHID.ahk

Gui +Resize -MaximizeBox -MinimizeBox
Gui, Add, Listview, w400 h300 vlvDL gSelectDevice AltSubmit,#|Type|Handle|VID|PID|UsagePage|Usage|Name|Buttons
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
	key := "SYSTEM\CurrentControlSet\Control\MediaProperties\PrivateProperties\Joystick\OEM\VID_" Format("{:04x}", Data.hid.VendorID) "&PID_" Format("{:04x}", Data.hid.ProductID)
	Regread, human_name, HKLM, % key, OEMName
    
    ; Decode capabilities
    ppSize := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA)
    ret := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA, PreparsedData, ppSize)
    ret := HID.HidP_GetCaps(PreparsedData, Caps)
    HID.HidP_GetButtonCaps(0, pButtonCaps, Caps.NumberInputButtonCaps, PreparsedData)
    ;btns := pButtonCaps[1].Range.UsageMax - pButtonCaps[1].Range.UsageMin + 1
    ;btns := pButtonCaps[1]
    ;btns := pButtonCaps.Range.UsageMax - pButtonCaps.Range.UsageMin + 1
    
    ; Update LV
	LV_Add(,A_INDEX, CHID.RIM_TYPE[dev.dwType], handle, Data.hid.VendorID, Data.hid.ProductId, Data.hid.UsagePage, Data.hid.Usage, human_name, btns )
}

LV_Modifycol()
return

InputMsg(wParam, lParam) {
    global HID
    
    r := HID.GetRawInputData(lParam,,Data)
    msgbox % A_ThisFunc ": " r
    if (r > 0){
        tooltip % Data.hid.UsagePage
    }
    ;ri := new _Struct(WinStructs.RAWINPUT,,lParam)
    ;if (ri.header.Type = 2){
        ;tooltip % ri.header.Device
        ;tooltip % Data.hid.UsagePage
    ;}
}

SelectDevice:
    LV_GetText(s, LV_GetNext())
    if (A_GuiEvent = "i" && s > 0){
        ; Register Device
        handle := DeviceList[s].hDevice
        rid := new _struct(WinStructs.RAWINPUTDEVICE)
        rid.UsagePage := DevData[s].hid.UsagePage
        rid.Usage := DevData[s].hid.Usage
        rid.Target := A_ScriptHwnd
        ;rid.Flags := HID.RIDEV_INPUTSINK
        rid.Flags := 0
        
        ret := HID.RegisterRawInputDevices(rid, 1)
        OnMessage(0x00FF, "InputMsg")
        ;msgbox % ret
    }
    return

GuiSize:
    Anchor("lvDL", "wh")
	return

Esc::
GuiClose:
	ExitApp

;Anchor by Titan, adapted by TheGood
;http://www.autohotkey.com/forum/viewtopic.php?p=377395#377395
Anchor(i, a = "", r = false) {
    static c, cs = 12, cx = 255, cl = 0, g, gs = 8, gl = 0, gpi, gw, gh, z = 0, k = 0xffff, ptr
    If z = 0
        VarSetCapacity(g, gs * 99, 0), VarSetCapacity(c, cs * cx, 0), ptr := A_PtrSize ? "Ptr" : "UInt", z := true
    If (!WinExist("ahk_id" . i)) {
        GuiControlGet, t, Hwnd, %i%
        If ErrorLevel = 0
            i := t
        Else ControlGet, i, Hwnd, , %i%
    }
    VarSetCapacity(gi, 68, 0), DllCall("GetWindowInfo", "UInt", gp := DllCall("GetParent", "UInt", i), ptr, &gi)
        , giw := NumGet(gi, 28, "Int") - NumGet(gi, 20, "Int"), gih := NumGet(gi, 32, "Int") - NumGet(gi, 24, "Int")
    If (gp != gpi) {
        gpi := gp
        Loop, %gl%
            If (NumGet(g, cb := gs * (A_Index - 1)) == gp, "UInt") {
                gw := NumGet(g, cb + 4, "Short"), gh := NumGet(g, cb + 6, "Short"), gf := 1
                Break
            }
        If (!gf)
            NumPut(gp, g, gl, "UInt"), NumPut(gw := giw, g, gl + 4, "Short"), NumPut(gh := gih, g, gl + 6, "Short"), gl += gs
    }
    ControlGetPos, dx, dy, dw, dh, , ahk_id %i%
    Loop, %cl%
        If (NumGet(c, cb := cs * (A_Index - 1), "UInt") == i) {
            If a =
            {
                cf = 1
                Break
            }
            giw -= gw, gih -= gh, as := 1, dx := NumGet(c, cb + 4, "Short"), dy := NumGet(c, cb + 6, "Short")
                , cw := dw, dw := NumGet(c, cb + 8, "Short"), ch := dh, dh := NumGet(c, cb + 10, "Short")
            Loop, Parse, a, xywh
                If A_Index > 1
                    av := SubStr(a, as, 1), as += 1 + StrLen(A_LoopField)
                        , d%av% += (InStr("yh", av) ? gih : giw) * (A_LoopField + 0 ? A_LoopField : 1)
            DllCall("SetWindowPos", "UInt", i, "UInt", 0, "Int", dx, "Int", dy
                , "Int", InStr(a, "w") ? dw : cw, "Int", InStr(a, "h") ? dh : ch, "Int", 4)
            If r != 0
                DllCall("RedrawWindow", "UInt", i, "UInt", 0, "UInt", 0, "UInt", 0x0101) ; RDW_UPDATENOW | RDW_INVALIDATE
            Return
        }
    If cf != 1
        cb := cl, cl += cs
    bx := NumGet(gi, 48, "UInt"), by := NumGet(gi, 16, "Int") - NumGet(gi, 8, "Int") - gih - NumGet(gi, 52, "UInt")
    If cf = 1
        dw -= giw - gw, dh -= gih - gh
    NumPut(i, c, cb, "UInt"), NumPut(dx - bx, c, cb + 4, "Short"), NumPut(dy - by, c, cb + 6, "Short")
        , NumPut(dw, c, cb + 8, "Short"), NumPut(dh, c, cb + 10, "Short")
    Return, true
}