; REQUIRES TEST BUILD OF AHK FROM http://ahkscript.org/boards/viewtopic.php?f=24&t=5802#p33610
#include <CHID>
#singleinstance force
SetBatchLines -1

Gui +Resize -MaximizeBox -MinimizeBox
Gui, Add, Listview, w651 h200 vlvDL gSelectDevice AltSubmit +Grid,#|Name|Btns|Axes|POVs|VID|PID|UsPage|Usage
LV_Modifycol(1,20)
LV_Modifycol(2,180)
LV_Modifycol(3,40)
LV_Modifycol(4,140)
LV_Modifycol(5,50)
LV_Modifycol(6,50)
LV_Modifycol(7,50)
LV_Modifycol(8,50)
LV_Modifycol(9,50)

Gui, Add, Text, % "hwndhAxes w300 h200 xm y220"
Gui, Add, Text, % "hwndhButtons w300 h200 x331 y220"

Gui, Show,, Joystick Info

HID := new CHID()
NumDevices := HID.GetRawInputDeviceList()
HID.GetRawInputDeviceList(DeviceList,NumDevices)
HID.GetRawInputDeviceInfo(DeviceList[1].hDevice, HID.RIDI_DEVICEINFO, 0, DevSize)
AxisNames := ["X","Y","Z","RX","RY","RZ","SL0","SL1"]
DevData := []

SelectedDevice := 0
CapsArray := {}
ButtonCapsArray := {}
AxisCapsArray := {}
ValueCapsArray := {}
AxesArray := {}
PageArray := {}

Gui,ListView,lvDL
Loop % NumDevices {
    ; Get device Handle
	dev := DeviceList[A_Index]
	if (dev.dwType != 2){
		continue
	}
	handle := DeviceList[A_Index].hDevice
    
    ; Get Device Info
    Data := new _Struct("WinStructs.RID_DEVICE_INFO",{cbSize:Size})
	HID.GetRawInputDeviceInfo(handle, HID.RIDI_DEVICEINFO, Data[], DevSize)
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
    HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA, 0, ppSize)
    VarSetCapacity(PreparsedData, ppSize)
    ret := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA, &PreparsedData, ppSize)
    CapsArray[handle] := new _Struct("WinStructs.HIDP_CAPS")
    ret := HID.HidP_GetCaps(PreparsedData, CapsArray[handle][])
    Axes := ""
    Hats := 0
    btns := 0

    ; Buttons
    if (CapsArray[handle].NumberInputButtonCaps) {
        ButtonCapsArray[handle] := new _Struct("WinStructs.HIDP_BUTTON_CAPS[" CapsArray[handle].NumberInputButtonCaps "]")
        HID.HidP_GetButtonCaps(0, ButtonCapsArray[handle][], CapsArray[handle].NumberInputButtonCaps, PreparsedData)
        btns := (Range:=ButtonCapsArray[handle].1.Range).UsageMax - Range.UsageMin + 1
    }
    ; Axes / Hats
    if (CapsArray[handle].NumberInputValueCaps) {
        ValueCapsArray[handle] := new _Struct("WinStructs.HIDP_VALUE_CAPS[" CapsArray[handle].NumberInputValueCaps "]")
        HID.HidP_GetValueCaps(0, ValueCapsArray[handle][], CapsArray[handle].NumberInputValueCaps, PreparsedData)
        AxesArray[handle] := {}
        PageArray[handle] := {}
        AxisCaps := {}
        Loop % CapsArray[handle].NumberInputValueCaps {
            AxesArray[handle][A_Index] := ValueCapsArray[handle][A_Index].Range.UsageMin
            PageArray[handle][A_Index] := ValueCapsArray[handle][A_Index].UsagePage
            Type := (Range:=ValueCapsArray[handle][A_Index].Range).UsageMin
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

return

InputMsg(wParam, lParam) {
    Critical
    global HID
    global SelectedDevice
    global hAxes, hButtons
    global PreparsedData, ppSize, CapsArray, ButtonCapsArray, ValueCapsArray, AxesArray, PageArray
	
    QPX(true)

    If (!pcbSize:=HID.GetRawInputData(lParam))
		return
    
	if (-1 = ret := HID.GetRawInputData(lParam,,pRawInput, pcbSize))
        return
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

    if (pRawInput.header.dwType = HID.RIM_TYPEHID){
		; Get Preparsed Data
        ; GetRawInputDeviceInfo
        ; Pre Optimization: 14-15
        ; All but size returning removed: 7-8
        ; Size returning removed: 6-7
        
		ret := HID.GetRawInputDeviceInfo(handle, HID.RIDI_PREPARSEDDATA, &PreparsedData, ppSize)
		
        ; HidP_GetCaps
        ; 
		; Decode button states
        ; Pre Optimization: 1100-1300
        ; Struct static: 200-350
        ; Use Caps decoded on startup: ~0
        
		;ret := HID.HidP_GetCaps(PreparsedData, Caps[])
        
		s := "Pressed Buttons:`n`n"
		if (CapsArray[handle].NumberInputButtonCaps) {
			; ToDo: Loop through ButtonCapsArray[handle][x] - Caps.NumberInputButtonCaps might not be 1
            ; HidP_GetButtonCaps
            ; Pre Optimization: ~6500
            ; No point making struct static as would need array of 8
            ; Button Caps decoded on startup: ~0
            
			btns := (Range:=ButtonCapsArray[handle].1.Range).UsageMax - Range.UsageMin + 1
			UsageLength := btns
            
            ; HidP_GetUsages
            ; Pre Optimization: ~4250
            ; Static Struct: ~4000
			static UsageList := new _Struct("UShort[128]")
			ret := HID.HidP_GetUsages(0, ButtonCapsArray[handle].UsagePage, 0, UsageList[], UsageLength, PreparsedData, pRawInput.hid.bRawData[""], pRawInput.hid.dwSizeHid)
            ;VarSetCapacity(RawData, 4)
            ;NumPut(0,&RawData)
			Loop % UsageLength {
				if (A_Index > 1){
					s .= ","
				}
				s .= UsageList[A_Index]
				;s .= NumGet(UsageList,(A_Index -1) * 2, "Ushort")
                ;s .= NumGet(&UsageList,(A_Index-1)*4,"UShort")
			}
		}
        GuiControl,,% hButtons, % s
		
        s:= "Axes:`n`n"
		; Decode Axis States
		if (CapsArray[handle].NumberInputValueCaps){
            ; HidP_GetValueCaps
            ; Pre Optimization: ~7500
            ; Value Caps decoded on startup: ~0
			
            ; HidP_GetUsageValue Loop (Values for 6-axis xbox pad)
            ; Pre Optimization: ~108000
            ; RawData and Size retrieved only once: ~106000
            ; Page and Min retrieved only once: ~50000
            ; Axes (UsageMin) and Page cached: ~1600
            VarSetCapacity(value, 4)
            RawData := pRawInput.hid.bRawData[""]
            Size := pRawInput.hid.dwSizeHid

			Loop % CapsArray[handle].NumberInputValueCaps {
				;r := HID.HidP_GetUsageValue(0, ValueCapsArray[handle][A_Index].UsagePage, 0, ValueCapsArray[handle][A_Index].Range.UsageMin, value, PreparsedData, RawData, Size)
				r := HID.HidP_GetUsageValue(0, PageArray[handle][A_Index], 0, AxesArray[handle][A_Index], value, PreparsedData, RawData, Size)
				value := NumGet(value,0,"Short")
				;s .= HID.AxisHexToName[ValueCapsArray[handle][A_Index].Range.UsageMin] " axis: " value "`n"
				;s .= HID.AxisHexToName[Range.UsageMin] " axis: " value "`n"
				s .= HID.AxisHexToName[AxesArray[handle][A_Index]] " axis: " value "`n"
			}
		}
        Ti := QPX(false)
        ToolTip % "Process Time (Inc UI Ouptut): " Ti
        GuiControl,,% hAxes, % s
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