local telescope = require("telescope")
local entry_display = require("telescope.pickers.entry_display")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values

local function project_finder(opts)
	local workspaces = require("projections.workspace").get_workspaces()
	local projects = {}
	-- local curr_project_path = nil
	local Session = require("projections.session")
	local curr_project_path, _ = Session.get_current_project_info()
	-- if Session._ensure_sessions_directory() then
	-- 	local latest_session = Session.latest()
	-- 	if latest_session ~= nil then
	-- 		vim.notify("Current Session = " .. tostring(latest_session))
	--            local curr_path = Path.new(tostring(latest_session))
	--            -- local project_name
	-- 		local session_info = Session.info(tostring(latest_session))
	-- 		vim.notify("Current Session Info = " .. vim.inspect(session_info))
	-- 		if session_info ~= nil then
	-- 			local project = session_info.project
	-- 			if project ~= nil then
	-- 				curr_project_path = project:path()
	-- 				vim.notify("Current Project Path = " .. curr_project_path)
	-- 			end
	-- 		end
	-- 	end
	-- end
	-- if curr_project_path ~= nil then
	-- 	vim.notify("Current Project = " .. curr_project_path)
	-- end

	for _, ws in ipairs(workspaces) do
		for _, project in ipairs(ws:projects()) do
			table.insert(projects, project)
		end
	end

	return finders.new_table({
		results = projects,
		entry_maker = opts.entry_maker or function(project)
			return {
				display = function(e)
					local display = entry_display.create({
						items = { { width = 35 }, { remaining = true } },
						separator = " ",
					})
					local project_path = e.value
					local project_name = e.name
					--
					-- -- -- Prepend the symbol if the project is the active session
					if project_path == curr_project_path then
						project_name = " -> " .. project_name
					end
					return display({ project_name, { e.value, "Comment" } })
				end,
				name = project.name,
				value = tostring(project:path()),
				ordinal = tostring(project:path()),
			}
		end,
	})
end

local find_projects = function(opts)
	opts = opts or {}

	-- Sort by recent implemented by
	-- hooking into the default scoring function, of generic_sorter
	-- we check if prompt is empty, if so, score by file modification time (inverted)
	-- if prompt is not empty, use the default scoring function
	local config = require("projections.config").config
	local Session = require("projections.session")
	local sorter = conf.generic_sorter(opts)
	local default_scoring_function = sorter.scoring_function
	sorter.scoring_function = function(_sorter, prompt, line, ...)
		if prompt == "" then
			local session_filename = Session.session_filename(vim.fn.fnamemodify(line, ":h"), vim.fs.basename(line))
			return 1 / math.abs(vim.fn.getftime(tostring(config.sessions_directory .. session_filename)))
		end
		return default_scoring_function(_sorter, prompt, line, ...)
	end

	local switcher = require("projections.switcher")
	pickers
		.new(opts, {
			prompt_title = "Projects",
			finder = project_finder(opts),
			sorter = sorter,
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if opts.action == nil then
						opts.action = function(selected)
							if selected ~= nil and selected.value ~= vim.loop.cwd() then
								switcher.switch(selected.value)
							end
						end
					end
					opts.action(selection)
				end)
				return true
			end,
		})
		:find()
end

return telescope.register_extension({
	setup = function(_, _) end,
	exports = { projections = find_projects },
})
