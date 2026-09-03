-- unpack_session.applescript — unpack every packed (.eip) image in one
-- Capture One session, including any images that land in the session's
-- Trash collection during the process.
--
-- Usage:
--   osascript unpack_session.applescript /path/to/Session/Session.cosessiondb [trash-policy]
--
-- trash-policy: "unpack-trash" (default) or "delete-trash"
--
-- Prints one line on success:
--   OK all_images=N unpacked_ok=N unpacked_fail=N trash_before=N trash_handled=N trash_fail=N trash_remaining=N
-- or "ERROR <message>" / raises with a Capture One error message on failure.
--
-- Closes any OTHER open Capture One documents first so "document 1" is
-- always unambiguously the session just opened — safe to run back-to-back
-- across many sessions without leftover state from a previous run/crash.

on run argv
	if (count of argv) < 1 then
		return "ERROR usage: osascript unpack_session.applescript /path/to/Session.cosessiondb [unpack-trash|delete-trash]"
	end if
	set sessionPath to item 1 of argv
	set trashPolicy to "unpack-trash"
	if (count of argv) > 1 then set trashPolicy to item 2 of argv

	-- Build the file reference OUTSIDE the `tell` block — inside it, Capture
	-- One's own "file" terms shadow the standard one and "POSIX file" fails
	-- with "Can't get POSIX file ..." (-1728).
	set sessionFile to (POSIX file sessionPath) as alias

	tell application "Capture One 23"
		activate

		repeat with d in documents
			try
				close d
			end try
		end repeat

		open sessionFile
		delay 2
		set doc to document 1

		set allImages to images of collection "All Images" of doc
		set allCount to count of allImages
		set unpackedOk to 0
		set unpackedFail to 0
		set unpackedSkip to 0
		repeat with img in allImages
			if packed of img then
				try
					unpack img
					set unpackedOk to unpackedOk + 1
				on error
					set unpackedFail to unpackedFail + 1
				end try
			else
				set unpackedSkip to unpackedSkip + 1
			end if
		end repeat

		set trashImages to images of collection "Trash" of doc
		set trashCount to count of trashImages
		set trashHandled to 0
		set trashFailed to 0
		if trashPolicy is "unpack-trash" then
			repeat with img in trashImages
				if packed of img then
					try
						unpack img
						set trashHandled to trashHandled + 1
					on error
						set trashFailed to trashFailed + 1
					end try
				end if
			end repeat
		else if trashPolicy is "delete-trash" then
			repeat with img in trashImages
				try
					delete img
					set trashHandled to trashHandled + 1
				on error
					set trashFailed to trashFailed + 1
				end try
			end repeat
		end if

		set remainingTrash to count of (images of collection "Trash" of doc)

		close doc

		return "OK all_images=" & allCount & " unpacked_ok=" & unpackedOk & " unpacked_fail=" & unpackedFail & " unpacked_skip=" & unpackedSkip & " trash_before=" & trashCount & " trash_handled=" & trashHandled & " trash_fail=" & trashFailed & " trash_remaining=" & remainingTrash
	end tell
end run
