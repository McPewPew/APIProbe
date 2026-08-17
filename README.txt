Azeroth API Probe 0.2.2
=======================

Purpose
-------
This diagnostic addon surveys the Lua runtime and WoW-facing API exposed by
the alpha UE5 client. It does not depend on Ace or any other addon.

Installation
------------
Extract the APIProbe folder into:

  Azeroth\Interface\AddOns\

The final path should be:

  Azeroth\Interface\AddOns\APIProbe\APIProbe.toc

Commands
--------
  /apiprobe             Show the latest summary
  /apiprobe run         Repeat all safe tests
  /apiprobe missing     Show expected globals that are absent/wrong type
  /apiprobe objects     Show UI object/method test results
  /apiprobe globals     Show every global function exposed by the client
  /apiprobe events      Show event registration and captured event arguments
  /apiprobe events on   Enable event capture
  /apiprobe events off  Disable event capture (the frame stays registered)
  /apiprobe events clear
  /apiprobe help

Independent commands
--------------------
These avoid relying on the client's handling of slash-command arguments:

  /apirun            Repeat all automatic tests
  /apishow           Show the summary
  /apibehavior       Show deterministic behavioural tests
  /apinative         Show functions implemented as native/C bindings
  /apilibraries      Show Lua-library contents and tests
  /apiobjects        Show UI-object method and round-trip tests
  /apimissing        Show expected globals that are absent/wrong type
  /apiglobals        Show every global function
  /apievents         Show event registration and captured arguments
  /apimanual         Show tests requiring human observation
  /apitestprint      Call print() with a recognisable message
  /apitestsound      Cycle through standard PlaySound() names

Copying results
---------------
Reports deliberately use plain text. This client does not expose the EditBox
HighlightText or cursor-position methods, so programmatic Select All is not
available; use the SavedVariables file for complete, reliably copyable output.
The on-screen report uses the same fixed-row FauxScrollFrame mechanism as MCP,
because ordinary ScrollFrames do not move their text children in this client.

The latest data is also saved in:

  WTF\Account\<account>\SavedVariables\APIProbe.lua

Safety
------
The automatic run calls only deterministic read-only APIs, pure Lua functions,
and setters on private hidden test objects created by this addon. Potentially
disruptive global functions such as
ReloadUI, Quit, Logout, DeleteCursorItem, CastSpell, UseAction, SendMail, and
guild/group operations are checked for existence only and are never invoked.

Interpretation
--------------
"MISSING" means the named global or object method was not exposed.
"WRONG TYPE" means a name exists but is not the expected Lua type.
"ERROR" means the function/method exists but its safe probe call failed.
"COMPILES ONLY" proves syntax was accepted, not that referenced globals work.
"CALL SUCCEEDED; OUTPUT UNVERIFIED" proves only that the call returned.
"VERIFIED" requires a deterministic result or an independently read state.
"MANUAL ONLY" requires a visible or audible check by the player.

Some entries in the broad expected-global survey are version-specific. A
missing entry is evidence for comparison, not automatically a client bug.
