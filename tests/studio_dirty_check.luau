--!nocheck
-- Studio half of the publish flow: is anything sitting in the script editor that has not reached the
-- DataModel yet?
--
-- An unsaved buffer is invisible to everything downstream — Rojo, this repository, and any hash
-- comparison — so a pull that skips this check can silently leave work behind while reporting
-- success. `ScriptDocument:IsDirty()` is not usable here (it is not exposed to this context), but the
-- editor's own text is: compare `ScriptEditorService:GetEditorSource(script)` with `script.Source`.
--
-- Run with the Studio MCP `execute_luau` tool (datamodel_type = "Edit"), before the hash dump in
-- tests/studio_hashes.luau. Any line reading EDITOR DIFFERS is unsaved work: ask the author to press
-- Ctrl+S in that tab, or take the editor text deliberately, which writes work-in-progress into the
-- repository.

local ScriptEditorService = game:GetService("ScriptEditorService")

local lines = {}
for _, document in ipairs(ScriptEditorService:GetScriptDocuments()) do
	local script = document:GetScript()
	if script == nil then
		continue
	end

	local ok, editorSource = pcall(function()
		return ScriptEditorService:GetEditorSource(script)
	end)
	if not ok then
		table.insert(lines, script:GetFullName() .. "\n   editor text unavailable: " .. tostring(editorSource))
		continue
	end

	table.insert(
		lines,
		string.format(
			"%s\n   DataModel %d bytes | editor %d bytes | %s",
			script:GetFullName(),
			#script.Source,
			#editorSource,
			editorSource == script.Source and "in sync" or "EDITOR DIFFERS (unsaved work)"
		)
	)
end

table.sort(lines)
return #lines .. " open script document(s)\n" .. table.concat(lines, "\n")
