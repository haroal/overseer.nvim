local files = require("overseer.files")
local overseer = require("overseer")
local log = require("overseer.log")

---@type overseer.TemplateDefinition
local tmpl = {
  priority = 60,
  params = {
    subcmd = { optional = true },
    args = { type = "list", delimiter = " ", default = {} },
  },
  builder = function(params)
    local cmd = { "mix" }
    local args = params.args or {}
    if params.subcmd then
      table.insert(args, 1, params.subcmd)
    end
    return {
      cmd = cmd,
      args = args,
    }
  end,
}

return {
  cache_key = function(opts)
    return vim.fn.fnamemodify(vim.fn.findfile("mix.exs", opts.dir .. ";"), ":p")
  end,
  condition = {
    callback = function(opts)
      if not files.exists(files.join(opts.dir, "mix.exs")) then
        return false, "No mix.exs file found"
      end
      return true
    end,
  },
  generator = function(opts, cb)
    local ret = {}
    local jid = vim.fn.jobstart({
      "mix",
      "help",
    }, {
      cwd = opts.dir,
      stdout_buffered = true,
      on_stdout = vim.schedule_wrap(function(j, output)
        for _, line in ipairs(output) do
          local task_name = line:match("mix (%S+)%s")
          table.insert(
            ret,
            overseer.wrap_template(
              tmpl,
              { name = string.format("mix %s", task_name) },
              { subcmd = task_name }
            )
          )
        end
        table.insert(ret, overseer.wrap_template(tmpl, { name = "mix", priority = 65 }))
      end),
      on_exit = vim.schedule_wrap(function(j, output)
        cb(ret)
      end),
    })
    if jid == 0 then
      log:error("Passed invalid arguments to 'mix'")
      cb(ret)
    elseif jid == -1 then
      log:error("'mix' is not executable")
      cb(ret)
    end
  end,
}
