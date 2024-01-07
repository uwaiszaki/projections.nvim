local utils = require("projections.utils")
local config = require("projections.config").config
local Workspace = require("projections.workspace")
local Project = require("projections.project")

local Session = {}
Session.__index = Session

---@alias SessionInfo { path: Path, project: Project }

-- Returns the path of the session file as well as project information
-- Returns nil if path is not a valid project path
---@param spath string The path to project root
---@return nil | SessionInfo
---@nodiscard
function Session.info(spath)
	-- check if path is some project's root
	local path = Path.new(spath)
	local project_name = path:basename()
	local workspace_path = path:parent()
	local all_workspaces = Workspace.get_workspaces()
	local workspace = nil
	-- vim.notify(vim.inspect(all_workspaces))
	vim.notify("Workspace Path: " .. vim.inspect(workspace_path))
	vim.notify("Project Name: " .. project_name)

	for _, ws in ipairs(all_workspaces) do
		if workspace_path == ws.path then
			workspace = ws
			break
		end
	end
	if workspace == nil then
		vim.notify("Workspace is nil")
	end
	if workspace ~= nil then
		vim.notify("Workspace: " .. workspace.path)
	end
	if workspace == nil or not workspace:is_project(project_name) then
		return nil
	end

	local filename = Session.session_filename(tostring(workspace_path), project_name)
	return {
		path = config.sessions_directory .. filename,
		project = Project.new(project_name, workspace),
	}
end

-- Returns the session filename for project
---@param workspace_path string The path to workspace
---@param project_name string Name of project
---@return string
---@nodiscard
function Session.session_filename(workspace_path, project_name)
	local path_hash = utils._fnv1a(workspace_path)
	return string.format("%s_%u.vim", project_name, path_hash)
end

-- Ensures sessions directory is available
---@return boolean
function Session._ensure_sessions_directory()
	return vim.fn.mkdir(tostring(config.sessions_directory), "p") == 1
end

-- Attempts to store the session
---@param spath string Path to the project root
---@return boolean
function Session.store(spath)
	Session._ensure_sessions_directory()
	local session_info = Session.info(spath)
	if session_info == nil then
		return false
	end
	return Session.store_to_session_file(tostring(session_info.path))
end

-- Attempts to store to session file
---@param spath string Path to the session file
---@returns boolean
function Session.store_to_session_file(spath)
	if config.store_hooks.pre ~= nil then
		config.store_hooks.pre()
	end
	-- TODO: correctly indicate errors here!
	vim.cmd("mksession! " .. vim.fn.fnameescape(spath))
	if config.store_hooks.post ~= nil then
		config.store_hooks.post()
	end
	return true
end

-- Attempts to restore a session
---@param spath string Path to the project root
---@return boolean
function Session.restore(spath)
	Session._ensure_sessions_directory()
	local session_info = Session.info(spath)
	if session_info == nil or not session_info.path:is_file() then
		return false
	end
	return Session.restore_from_session_file(tostring(session_info.path))
end

-- Attempts to restore a session from session file
---@param spath string Path to session file
---@return boolean
function Session.restore_from_session_file(spath)
	if config.restore_hooks.pre ~= nil then
		config.restore_hooks.pre()
	end
	-- TODO: correctly indicate errors here!
	vim.cmd("silent! source " .. vim.fn.fnameescape(spath))
	if config.restore_hooks.post ~= nil then
		config.restore_hooks.post()
	end
	return true
end

-- Get latest session
---@return nil | Path
---@nodiscard
function Session.latest()
	local latest_session = nil
	local latest_timestamp = 0

	for _, filename in ipairs(vim.fn.readdir(tostring(config.sessions_directory))) do
		local session = config.sessions_directory .. filename
		local timestamp = vim.fn.getftime(tostring(session))
		if timestamp > latest_timestamp then
			latest_session = session
			latest_timestamp = timestamp
		end
	end
	return latest_session
end

-- Restore latest session
---@return boolean
function Session.restore_latest()
	local latest_session = Session.latest()
	if latest_session == nil then
		return false
	end
	return Session.restore_from_session_file(tostring(latest_session))
end

return Session
