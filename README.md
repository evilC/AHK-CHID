# AHK-CHID
A class-based implementation of HID functionality via Windows API calls for [AutoHotkey](http://ahkscript.org).

Inspired by: [AHKHID](https://github.com/jleb/AHKHID).

Dependencies: [_Struct](https://github.com/HotKeyIt/_Struct) , [sizeof()](http://www.autohotkey.net/~HotKeyIt/AutoHotkey/sizeof.htm)


##What?
**HID:** Human Interface Device. A standard for input devices that allows querying the device for information (Axis positions, button states etc) without the need for a dedicated devce driver.

**CHID:** Classed HID. A classed version of the AutoHotkey HID library. To avoid confusion with AHKHID.

CHID is a library for AutoHotkey that seeks to simplify interaction with HID devices. It's primary focus will initially be Joysticks, as joystick support in AHK is currently lacking as much love as keyboard and mouse (Only 6 axes, 1 POV, no up events for buttons, no events at all for axis movement)

##Why?
Because I was unhappy with the following aspects of AHKHID:
* Too much stuff in the global namespace.
* Many functions named differently to the DLL calls they make, repetitions of the same DLL Call across funcs etc.
* Too hard (for me) to understand parts of the code as a lot of it was overly complicated by the need to perform bitwise operations manually.
* Too difficult to use the library, as you got often pure memory STRUCTs back, and had to do bitwise operations to interpret it.
* AHKHID allows you to query device data (ie you get binary info from it), but for devices other than keyboard and mouse, it does not allow you to *interpret* that data. The RawInput API has a set of `HidP_` calls which tell you the *capabilities* of the device, allowing you to read any HID compliant joystick (99% of all sticks on the market) regardless of how many buttons or axes they have. AHKHID does not implement these.

##How? ...
... Does CHID seek to be different?
* Everything encapsulated in a class
  This is a library, the less in the global namespace the better.
* Where possible, one func per DLL call.
  So it is clear in your code what it is doing without having to look at the library source to see which DLL call you are making.
* Code that is easier to understand and use, through the use of HotkeyIt's _Struct.
_Struct is a library that allows you to treat memory structures as if they were arrays.  
Since Windows API calls almost exclusively deal in STRUCTs, this simplifies the code hugely, and reduces the chances of errors creeping in if I did it myself (Which is highly likely)
It abstracts away the really complicated stuff (Pointer sizes - x86 / x64 differences etc), allowing you to write code that looks more like the C examples on MSDN etc.

##Who?
* I am not a windows coder.
* I do not usually work in compiled languages.
* I am not an expert in this field.
* Anyone is more than welcome to contribute to this project.

Therefore, consider this library unproven and not to be used in any critical projects until proven.

##When? ...
... Will it be ready?  
When it is ready.
