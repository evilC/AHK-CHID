; REQUIRES AHK >= v1.1.20.00

#include CHID.ahk

#singleinstance force
SetBatchLines -1
OutputDebug, DBGVIEWCLEAR

jt := new JoystickTester()
return

class JoystickTester extends CHID {
	GUI_WIDTH := 661
	
	__New(){
		base.__New()
		Gui, Add, Text, % "xm Center w" this.GUI_WIDTH, % "Select a Joystick to subscribe to WM_INPUT messages for that UsagePage/Usage."
		Gui, Add, Listview, % "hwndhLV w" this.GUI_WIDTH " h150 +AltSubmit +Grid",Handle|GUID|Name|Btns|Axes|POVs|VID|PID|UsPage|Usage
		this.hLV := hLV
		LV_Modifycol(1,50)
		LV_Modifycol(2,40)
		LV_Modifycol(3,130)
		LV_Modifycol(4,40)
		LV_Modifycol(5,140)
		LV_Modifycol(6,50)
		LV_Modifycol(7,50)
		LV_Modifycol(8,50)
		LV_Modifycol(9,50)
		LV_Modifycol(10,50)
		
		Gui, Add, GroupBox, % "x10 y180 w190 h115", Axis states
		
		Top := 200
		Left := 12
		rows := 4
		cols := 2
		label_width := 20
		item_Width := 50
		item_height := 25
		col_width := 110
		
		this.GuiAxisStates := []
		Loop % rows {
			row := A_Index - 1
			axis := (row * cols) + 1
			Loop % cols {
				col := A_Index -1
				Gui, Add, Text, % "x" Left + (col * col_width) " y" Top + (row * item_height) " w" label_width " center hwndhwnd", % this.AxisNames[axis]
				Gui, Add, Text, % "x" Left + (col * col_width) + label_width " y" Top + (row * item_height) " w" item_width " center hwndhwnd"
				this.GuiAxisStates[axis] := hwnd
				axis++
			}
		}

		Gui, Add, GroupBox, % "x10 y300 w190 h100", Hat states
		Top := 320
		rows := 2
		cols := 2
		
		this.GuiHatStates := []
		Loop % rows {
			row := A_Index - 1
			hat := (row * cols) + 1
			Loop % cols {
				col := A_Index -1
				Gui, Add, Text, % "x" Left + (col * col_width) " y" Top + (row * item_height) " w" label_width " center hwndhwnd", % hat ":"
				Gui, Add, Text, % "x" Left + (col * col_width) + label_width " y" Top + (row * item_height) " w" item_width " center hwndhwnd"
				this.GuiHatStates[hat] := hwnd
				hat++
			}
		}

		Gui, Add, GroupBox, % "x208 y180 w" this.GUI_WIDTH - 200 " h220", Button states
		
		Top := 200
		Left := 210
		rows := 8
		cols := 16
		item_Width := 28
		item_height := 25
		this.GuiButtonStates := []
		Loop % rows {
			row := A_Index - 1
			btn := (row * cols) + 1
			Loop % cols {
				col := A_Index - 1
				Gui, Add, Text, % "x" Left + (col * item_width) " y" Top + (row * item_height) " w" item_width " center hwndhwnd", % Btn
				this.GuiButtonStates[btn] := hwnd
				btn++
			}
		}
		


		
		Gui, Add, Text, xm Section, % "Time to process WM_INPUT message (Including time to assemble debug strings, but not update UI), in seconds: "
		Gui, Add, Text, % "hwndhProcessTime w50 ys"
		this.hProcessTime := hProcessTime
		Gui, Show, y0, CHID Joystick Tester
		
		fn := this.DeviceSelected.Bind(this)
		GuiControl +g, % this.hLV, % fn
		
		for handle, device in this.DevicesByHandle {
			if (!device.NumButtons && !device.NumAxes){
				; Ignore devices with no buttons or axes
				continue
			}
			LV_Add(, handle, device.GUID, device.HumanName, device.NumButtons, device.AxisString, device.NumPOVs, device.VID, device.PID, device.UsagePage, device.Usage )
		}
	}
	
	DeviceSelected(){
		static LastSelected := -1
		; Listviews fire g-labels on down event and up event of click, filter out up event
		LV_GetText(handle, LV_GetNext())
		if (A_GuiEvent = "i"){
			fn := this.AxisChanged.Bind(this)
			this.DevicesByHandle[handle].RegisterAxisCallback(fn)
			fn := this.HatChanged.Bind(this)
			this.DevicesByHandle[handle].RegisterHatCallback(fn)
			fn := this.ButtonChanged.Bind(this)
			this.DevicesByHandle[handle].RegisterButtonCallback(fn)
			
			Loop 128 {
				GuiControl, +cblack, % this.GuiButtonStates[A_Index]
				GuiControl, , % this.GuiButtonStates[A_Index], % A_Index
			}
			Loop 8 {
				GuiControl, , % this.GuiAxisStates[A_Index], % ""
			}
			Loop 4 {
				GuiControl, , % this.GuiHatStates[A_Index], % ""
			}
		}
		return 1
	}
	
	; The state of one or more buttons changed - walk the ButtonDelta array to see what changed.
	ButtonChanged(device){
		LV_GetText(handle, LV_GetNext())
		if (device.handle = handle){
			Loop % device.ButtonDelta.MaxIndex(){
				; Update the GUI
				if (device.ButtonDelta[A_Index].state){
					col := "+cred"
				} else {
					col := "+cblack"
				}
				GuiControl, % col, % this.GuiButtonStates[device.ButtonDelta[A_Index].button]
				GuiControl, , % this.GuiButtonStates[device.ButtonDelta[A_Index].button], % device.ButtonDelta[A_Index].button
			}
			; ToDo - remove from here as end of this routine is no longer end of WM_INPUT
			GuiControl, , % this.hProcessTime, % device._ProcessTime
		}
	}

	; The state of an Axis changed
	AxisChanged(device){
		LV_GetText(handle, LV_GetNext())
		if (device.handle = handle){
			Loop % device.AxisDelta.MaxIndex(){
				; Update the GUI
				GuiControl, , % this.GuiAxisStates[device.AxisDelta[A_Index].axis], % device.AxisDelta[A_Index].state
			}
			; ToDo - remove from here as end of this routine is no longer end of WM_INPUT
			GuiControl, , % this.hProcessTime, % device._ProcessTime
		}
	}
	
	; The state of a Hat changed
	HatChanged(device){
		LV_GetText(handle, LV_GetNext())
		if (device.handle = handle){
			Loop % device.HatDelta.MaxIndex(){
				; Update the GUI
				GuiControl, , % this.GuiHatStates[device.HatDelta[A_Index].hat], % device.HatDelta[A_Index].state
			}
			; ToDo - remove from here as end of this routine is no longer end of WM_INPUT
			GuiControl, , % this.hProcessTime, % device._ProcessTime
		}
	}
}

Esc::
GuiClose:
	ExitApp