; NOT WORKING AT THE MOMENT, SEE TEST NORMAL.AHK FOR CURRENT BLEEDING EDGE
; A set of helper classes to simplify the code required to get data via HID.
; Makes use of meta-functions (ie __Get) to reduce the need for function calls, and reduce the burden on your code to decide which API calls to make and when.
#Include CHID.ahk
Class CHID_Helper Extends CHID {
	__Get(aParam){
		if (aParam = "DeviceList"){
			this.DeviceList := new this._CDeviceList(this)
		} else if (aParam = "DeviceInfo"){
			this.DeviceList := new this._CDeviceInfo(this)
		}
	}
	
	; A class to wrap GetRawInputDeviceList calls.
	; Properties:
	; NumDevices			- The number of devices.
	; [n] (Indexed Array)	- The RAWINPUTDEVICELIST structure for device n
	
	Class _CDeviceList {
		__New(root){
			; Store link to main class containing DLL call funcs
			this._root := root
			
		}
		
		__Get(aParam){
			if (aParam = "NumDevices"){
				; Querying number of devices
				this.NumDevices := this._root.GetRawInputDeviceList()
			} else if (aParam is numeric){
				if (!ObjHasKey(this, "_Device")){
					this._Device := new this._CDevice(this._root)
				}
				return this._Device[aParam]
			}
		}
		
		Class _CDevice {
			__New(root){
				this._root := root
				this._root.GetRawInputDeviceList(RAWINPUTDEVICELIST, this._root.DeviceList.NumDevices)
				this._RAWINPUTDEVICELIST := RAWINPUTDEVICELIST
			}
			
			__Get(aParam){
				if (aParam is numeric){
					return this._RAWINPUTDEVICELIST[aParam]
				}
			}
		}
	}
	
	Class _CDeviceInfo {
		__New(root){
			this._root := root
		}
		
		__Get(aParam){
			if (aParam = "Info"){
				
			}
		}
	}
	
}
