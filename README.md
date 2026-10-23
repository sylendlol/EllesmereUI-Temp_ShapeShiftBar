# EllesmereUI-Temp_ShapeShiftBar

<img width="1722" height="1387" alt="image" src="https://github.com/user-attachments/assets/92577279-d5c4-4845-834b-d4f1b40ae74f" />
<img width="1751" height="1388" alt="image" src="https://github.com/user-attachments/assets/5fe9f5ae-a7a8-4c6b-989d-eea19856680a" />




Problem: On WoW Forever, event forms like the zombie debuff put their abilities on a temporary bar, at action page 32 (GetTempShapeshiftBarIndex()). The game reports this with the [shapeshift] macro condition. EllesmereUI v9.6.1 pages Action Bar 1 for override, vehicle, possess and bonus bars, but its paging rules (EUI_ActionBars_Paging.lua) have no [shapeshift] clause. EUI also hides Blizzard’s main bar, which would normally handle this. So the zombie spells don’t appear on any bar.

Fix: a small standalone add-on, EllesmereUI_TempShapeshiftBar, that changes no EllesmereUI files. It builds the same paging rules EUI uses for Action Bar 1 and adds [shapeshift] <index> to them. It then registers the result on Action Bar 1 itself. It does this again whenever EUI rebuilds the bar’s paging, for example after a settings change. In combat it waits until combat ends. While in the form, Action Bar 1 shows the zombie abilities on the usual keybinds, and switches back when the form ends.
