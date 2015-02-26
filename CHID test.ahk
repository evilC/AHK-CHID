/*
A script to compare results from CHID vs AHKHID
*/
#SingleInstance force
;Set up the constants

#Include <CHID>
#Include <AHKHID>

;Create GUI
Gui +LastFound -Resize -MaximizeBox -MinimizeBox
Gui, Add, Text, xm ym Section Center w650, AHKHID
Gui, Add, Text, ys Section Center w650, CHID
Gui, Add, ListView, xm yp+25 Section w650 h320 hwndhLVAhkHid, #|Time|VID|PID|UsagePage|Usage|Length|Data
LV_ModifyCol(1,30)
LV_ModifyCol(2,80)
LV_ModifyCol(3,50)
LV_ModifyCol(4,50)
LV_ModifyCol(5,50)
LV_ModifyCol(6,50)
LV_ModifyCol(6,50)

Gui, Add, ListView, ys w650 h320 hwndhLVChid, #|Time|VID|PID|UsagePage|Usage|Btns|Length|Data
LV_ModifyCol(1,30)
LV_ModifyCol(2,80)
LV_ModifyCol(3,50)
LV_ModifyCol(4,50)
LV_ModifyCol(5,50)
LV_ModifyCol(6,50)
LV_ModifyCol(6,50)

;Keep handle
GuiHandle := A_ScriptHwnd

;Intercept WM_INPUT
OnMessage(0x00FF, "InputMsg")

;Show GUI
Gui, Show

;AHKHID_Register(1, 4, A_ScriptHwnd, 0)

HID := new CHID()
pRawInputDevices := new _Struct(WinStructs.RAWINPUTDEVICE)
pRawInputDevices.usUsagePage := 1
;~ pRawInputDevices.usUsage := 4
pRawInputDevices.usUsage := 5
pRawInputDevices.dwFlags |= 0x00002000 ;RIDEV_DEVNOTIFY
pRawInputDevices.hwndTarget := A_ScriptHwnd
pRawInputDevices.dwFlags := 0
HID.RegisterRawInputDevices(pRawInputDevices, 1, sizeof(WinStructs.RAWINPUTDEVICE))

Return

Esc::
GuiClose:
ExitApp

InputMsg(wParam, lParam) {
    Critical    ;Or otherwise you could get ERROR_INVALID_HANDLE
	global hLVAhkHid, hLVChid	; UI
    global HID	; CHID
	global II_DEVTYPE, II_DEVHANDLE, DI_HID_VENDORID, DI_HID_PRODUCTID, DI_HID_USAGEPAGE, DI_HID_USAGE, RIM_TYPEHID	; AHKHID
	static msg_id := 0
	
	msg_id++
	time := A_TickCount
	
	; AHKHID
    ; GetRawInputData call, just get header item
    r := AHKHID_GetInputInfo(lParam, II_DEVTYPE) 
    If (r = -1)
        OutputDebug %ErrorLevel%
    If (r = RIM_TYPEHID) {
		; GetRawInputData call, just get header item
        h := AHKHID_GetInputInfo(lParam, II_DEVHANDLE)
		
		; GetRawInputData call, get everything
        Size := AHKHID_GetInputData(lParam, uData)
		
		; GetRawInputDeviceInfo call
		vid := AHKHID_GetDevInfo(h, DI_HID_VENDORID,     True)
		pid := AHKHID_GetDevInfo(h, DI_HID_PRODUCTID,    True)
		UsagePage := AHKHID_GetDevInfo(h, DI_HID_USAGEPAGE, True)
		Usage := AHKHID_GetDevInfo(h, DI_HID_USAGE, True)
		
		; Only show vJoy stick
		;~ if (vid != 0x1234){
		if (vid != 0x45E){
			return
		}
        vid := Format("{:x}",vid)
        pid := Format("{:x}",pid)
		Gui, ListView, % hLVAhkHid
        LV_Add("", msg_id, time, vid, pid, UsagePage, Usage, Size, Bin2Hex(&uData, Size))
    }
	
	; CHID
	pcbSize := HID.GetRawInputData(lParam)
	HID.GetRawInputData(lParam, HID.RID_INPUT,pRawInput, pcbSize)
	;MsgBox % iSize   := NumGet(pRawInput, 16) ;ID_HID_SIZE
	handle := pRawInput.header.hDevice
	devtype := pRawInput.header.dwType
	
	if (pRawInput.header.dwType = HID.RIM_TYPEHID){
		DevSize := HID.GetRawInputDeviceInfo(handle)
		ret := HID.GetRawInputDeviceInfo(handle, HID.RIDI_DEVICEINFO, pData, DevSize)
		vid := pData.hid.dwVendorId
		pid := pData.hid.dwProductId
		UsagePage := pData.hid.usUsagePage
		Usage := pData.hid.usUsage
		
		
		; Only show vJoy stick
		;~ if (vid != 0x1234){
		if (vid != 0x45E){
			return
		}
        vid := Format("{:x}",vid)
        pid := Format("{:x}",pid)
		
		Gui, ListView, % hLVChid
        ;LV_Add("", msg_id, time, vid, pid, UsagePage, Usage,, pcbSize, Bin2Hex(&pData, pcbSize))
		
		; AHKHID stops here in capabilities.
		
		; Get Preparsed Data
		ppSize := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA)
		ret := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA, PreparsedData, ppSize)
		ret := HID.HidP_GetCaps(PreparsedData, Caps)

		if (Caps.NumberInputButtonCaps) {
			; next line makes code CRASH. Same code is used @ line 63, so why does it not work here?
			ret := HID.HidP_GetButtonCaps(0, pButtonCaps, Caps.NumberInputButtonCaps, PreparsedData)
			btns := (Range:=pButtonCaps.Range).UsageMax - Range.UsageMin + 1
			UsageLength := btns
			
			;ToolTip % ret ; all good to this point

			;ToolTip % pRawInput.hid.dwSizeHid
			;ToolTip % sizeof(pRawInput.hid.bRawData)Caps.Usagep
			;ret := HID.HidP_GetUsages(0, Caps.UsagePage, 0, UsageList, UsageLength, PreparsedData, pRawInput.hid.bRawData, pRawInput.hid.dwSizeHid)
			;~ ret := HID.HidP_GetUsages(0, pButtonCaps.UsagePage, 0, UsageList, UsageLength, PreparsedData, pRawInput.hid.bRawData.1[""], pRawInput.hid.dwSizeHid)
			ret := HID.HidP_GetUsages(0, pButtonCaps.UsagePage, 0, UsageList, UsageLength, PreparsedData, pRawInput.hid.bRawData[""], pRawInput.hid.dwSizeHid)
			;MsgBox % "UsagePage: " pButtonCaps.UsagePage "`nUsageLength: " UsageLength "`nReport: " pRawInput.hid.bRawData "`nSize: " pRawInput.hid.dwSizeHid
			;ToolTip % UsageLength
			;if (pButtonCaps.UsagePage=3)
			;MsgBox % "Page: " UsageLength ;pButtonCaps.UsagePage ": " UsageLength
		
			ToolTip % UsageLength "`n" pButtonCaps.UsagePage "`n" ret "`n" ErrorLevel
			Loop % UsageLength
				MsgBox % NumGet(&UsageList,0, "UShort")
		}
		Gui,ListView,lvDLDBG
        ;LV_Add("", msg_id, time, vid, pid, UsagePage, Usage, btns, pcbSize, Bin2Hex(&pRawInput, pcbSize))
		LV_Add("", msg_id, time, vid, pid, UsagePage, Usage, btns, pcbSize-24, Bin2Hex(pRawInput[]+24, pcbSize-24)) ; AHKHID_GetInputData chops off 24 bytes - match same output
	}
}

;By Laszlo, adapted by TheGood
;http://www.autohotkey.com/forum/viewtopic.php?p=377086#377086
Bin2Hex(addr,len) {
    Static fun, ptr 
    If (fun = "") {
        If A_IsUnicode
            If (A_PtrSize = 8)
                h=4533c94c8bd14585c07e63458bd86690440fb60248ffc2418bc9410fb6c0c0e8043c090fb6c00f97c14180e00f66f7d96683e1076603c8410fb6c06683c1304180f8096641890a418bc90f97c166f7d94983c2046683e1076603c86683c13049ffcb6641894afe75a76645890ac366448909c3
            Else h=558B6C241085ED7E5F568B74240C578B7C24148A078AC8C0E90447BA090000003AD11BD2F7DA66F7DA0FB6C96683E2076603D16683C230668916240FB2093AD01BC9F7D966F7D96683E1070FB6D06603CA6683C13066894E0283C6044D75B433C05F6689065E5DC38B54240833C966890A5DC3
        Else h=558B6C241085ED7E45568B74240C578B7C24148A078AC8C0E9044780F9090F97C2F6DA80E20702D1240F80C2303C090F97C1F6D980E10702C880C1308816884E0183C6024D75CC5FC606005E5DC38B542408C602005DC3
        VarSetCapacity(fun, StrLen(h) // 2)
        Loop % StrLen(h) // 2
            NumPut("0x" . SubStr(h, 2 * A_Index - 1, 2), fun, A_Index - 1, "Char")
        ptr := A_PtrSize ? "Ptr" : "UInt"
        DllCall("VirtualProtect", ptr, &fun, ptr, VarSetCapacity(fun), "UInt", 0x40, "UInt*", 0)
    }
    VarSetCapacity(hex, A_IsUnicode ? 4 * len + 2 : 2 * len + 1)
    DllCall(&fun, ptr, &hex, ptr, addr, "UInt", len, "CDecl")
    VarSetCapacity(hex, -1) ; update StrLen
    Return hex
}
