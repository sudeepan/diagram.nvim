---@class MermaidOptions
---@field background? string
---@field theme? string
---@field scale? number
---@field width? number
---@field height? number
---@field cli_args? string[]

---@type table<string, string>

---@class Renderer<MermaidOptions>
local M = {
  id = "mermaid",
}

-- fs cache
local cache_dir = vim.fn.resolve(vim.fn.stdpath("cache") .. "/diagram-cache/mermaid")
vim.fn.mkdir(cache_dir, "p")

---@param source string
---@param options MermaidOptions
---@return table|nil
M.render = function(source, options)
  local hash = vim.fn.sha256(M.id .. ":" .. source)
  local path = vim.fn.resolve(cache_dir .. "/" .. hash .. ".png")
  if vim.fn.filereadable(path) == 1 then return { file_path = path } end

  -- vim.fn.executable() returns 0 or 1, and 0 is truthy in Lua.
  if vim.fn.executable("mermaidx") == 0 then
    vim.notify(
      "mermaidx not found in PATH. Install it with `pip install mermaidx` (or `pipx install mermaidx`).",
      vim.log.levels.ERROR,
      { title = "Diagram.nvim" }
    )
    return nil
  end

  local tmpsource = vim.fn.tempname()
  vim.fn.writefile(vim.split(source, "\n"), tmpsource)

  -- -q stops mermaidx from printing "saved to ..." on stderr after a successful render.
  local command_parts = {
    "mermaidx",
    "-q",
  }

  -- Add custom CLI arguments if provided
  if options.cli_args and #options.cli_args > 0 then vim.list_extend(command_parts, options.cli_args) end

  -- Add standard arguments
  vim.list_extend(command_parts, {
    "-i",
    tmpsource,
    "-o",
    path,
  })
  if options.background then vim.list_extend(command_parts, { "-b", tostring(options.background) }) end
  if options.theme then vim.list_extend(command_parts, { "-t", tostring(options.theme) }) end
  if options.scale then vim.list_extend(command_parts, { "--scale", tostring(options.scale) }) end
  if options.width then vim.list_extend(command_parts, { "-w", tostring(options.width) }) end
  if options.height then vim.list_extend(command_parts, { "-H", tostring(options.height) }) end

  -- Pass the command as a list so paths with spaces need no shell quoting.
  local stderr_lines = {}
  local job_id = vim.fn.jobstart(command_parts, {
    on_stderr = function(_, data)
      if data then vim.list_extend(stderr_lines, data) end
    end,
    on_exit = function(_, exit_code)
      vim.fn.delete(tmpsource)
      if exit_code ~= 0 then
        local error_msg = vim.trim(table.concat(stderr_lines, "\n"))
        vim.notify(
          "Failed to render mermaid diagram (exit " .. exit_code .. "):\n" .. error_msg,
          vim.log.levels.ERROR,
          { title = "Diagram.nvim" }
        )
      end
    end,
  })
  return { file_path = path, job_id = job_id }
end

return M
