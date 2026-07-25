--!nocheck
-- One-off dev utility: dumps a .rbxm's instance tree and script sources to
-- plain text so third-party binary models can be read/reviewed without
-- opening Roblox Studio. Not part of the game; run manually with:
--   lune run scripts/extract_rbxm.luau -- <input.rbxm> <outputDir>

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local inputPath = process.args[1]
local outputDir = process.args[2]

if not inputPath or not outputDir then
	error("usage: lune run scripts/extract_rbxm.luau -- <input.rbxm> <outputDir>")
end

if fs.isDir(outputDir) then
	fs.removeDir(outputDir)
end
fs.writeDir(outputDir)

local modelFile = fs.readFile(inputPath)
local instances = roblox.deserializeModel(modelFile)

local treeLines = {}
local scriptCount = 0

local function sanitize(name: string): string
	return (name:gsub("[^%w%-%._ ]", "_"))
end

local function walk(instance: Instance, depth: number, pathPrefix: string)
	local indent = string.rep("  ", depth)
	table.insert(treeLines, string.format("%s%s [%s]", indent, instance.Name, instance.ClassName))

	local isScript = instance.ClassName == "Script"
		or instance.ClassName == "LocalScript"
		or instance.ClassName == "ModuleScript"

	local currentPath = pathPrefix .. "/" .. sanitize(instance.Name)

	if isScript then
		local ok, source = pcall(function()
			return (instance :: any).Source
		end)
		if ok and typeof(source) == "string" then
			scriptCount += 1
			local filePath = outputDir .. currentPath .. ".luau"
			local dir = filePath:match("^(.*)/[^/]+$")
			if dir and not fs.isDir(dir) then
				fs.writeDir(dir)
			end
			fs.writeFile(filePath, source)
		end
	end

	for _, child in instance:GetChildren() do
		walk(child, depth + 1, currentPath)
	end
end

for _, root in instances do
	walk(root, 0, "")
end

fs.writeFile(outputDir .. "/_tree.txt", table.concat(treeLines, "\n"))
print(string.format("Extracted %d script(s) from %s into %s", scriptCount, inputPath, outputDir))
