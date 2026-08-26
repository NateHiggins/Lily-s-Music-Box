PLEASE REMAIN ON THE LINE — friends build {{BUILD_NUMBER}}
Version {{VERSION}} · commit {{SHORT_SHA}} · not for redistribution

INSTALL
Unzip the whole folder. Keep PleaseRemainOnTheLine.exe and
PleaseRemainOnTheLine.pck beside one another. Run the EXE from that folder.

WINDOWS WARNING
This private test build is not code-signed. Windows SmartScreen may warn because
the file has no established reputation. Continue only because you trust the
person who gave you this exact build. The accompanying .sha256 file lets you
verify that your ZIP is byte-for-byte the issued artifact.

INPUT
Keyboard/mouse and controller routes are implemented. Controller-only completion
of the entire first route is still awaiting human verification; please report
the exact controller model and the last action that worked if you get stuck.
Escape/Menu opens Building Services. B cancels. Controller look sensitivity,
invert-Y, dead zone and response curve are available there and on the title.

MICROPHONE — READ BEFORE PLAY
The optional Songbook recording activity can open your microphone and save a
vocal recording locally. Nothing in production uploads that recording. Until
the consent audit is implemented, avoid the Songbook activity or deny the OS
microphone request if you do not want audio recorded. This capability is under
active review for friends builds.

WEATHER AND NETWORK
Live local weather is off by default; Queens, New York is the fallback. If you
opt in and type a location, that text is sent to geocoding/weather providers.
Like any internet request, providers can also observe connection metadata such
as your IP address. The game contains no analytics or crash uploader currently
known to us.

LOCAL FILES
Settings, saves, screenshots and optional Songbook vocals live under Godot's
user-data folder named PleaseRemainOnTheLine. Removing the unzipped game does
not automatically remove that user data. Ask for platform-specific removal
instructions before deleting anything you want to keep.

REPORT A PROBLEM
Include friends build {{BUILD_NUMBER}}, version {{VERSION}}, commit
{{SHORT_SHA}}, operating system, CPU/GPU/RAM, input device, the route boundary,
what you expected, what happened, and whether it repeats. Do not attach a log,
recording or screenshot containing personal information without reviewing it
and explicitly consenting to share it.
