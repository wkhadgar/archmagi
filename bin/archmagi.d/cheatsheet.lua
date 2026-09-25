-- Usage: lua cheatsheet.lua <binds.lua> [--with-dispatch]
-- Default emits DISPLAY per line; --with-dispatch emits
-- DISPLAY <TAB> HYPRCTL_ARG so the shell can fire the picked bind.

local binds_file = arg[1]
if not binds_file then
    io.stderr:write("cheatsheet.lua: missing binds file path\n")
    os.exit(1)
end
local with_dispatch = arg[2] == "--with-dispatch"

local recorded = {}

-- Every access below hl.dsp returns another proxy so nested calls like
-- hl.dsp.window.close() resolve without a real Hyprland context.
local function nsProxy(prefix)
    return setmetatable({}, {
        __index = function(_, k)
            return nsProxy((prefix and (prefix .. ".") or "") .. k)
        end,
        __call = function(_, ...)
            return { __dispatcher = prefix, args = { ... } }
        end,
    })
end

hl = { dsp = nsProxy("dsp") }

-- hl.bind captures; every other hl.* call is a no-op.
setmetatable(hl, {
    __index = function(_, k)
        return function(...)
            if k == "bind" then
                local a = { ... }
                table.insert(recorded, { keys = a[1], dispatcher = a[2], opts = a[3] or {} })
            end
        end
    end,
})

dofile(binds_file)

local home_prefix  = os.getenv("HOME") .. "/.local/bin/"
local tilde_prefix = "~/.local/bin/"

local function strip_localbin(s)
    if s:sub(1, #home_prefix)  == home_prefix  then return s:sub(#home_prefix  + 1) end
    if s:sub(1, #tilde_prefix) == tilde_prefix then return s:sub(#tilde_prefix + 1) end
    return s
end

-- Only escapes backslashes and double quotes; `$USER` etc. survive to the
-- shell that runs exec_cmd.
local function q(s)
    return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

local function wsval(v)
    if type(v) == "number" then return tostring(v) end
    return q(v)
end

-- Lua expression for `hyprctl dispatch` (Hyprland 0.56+ wraps arg as
-- `return hl.dispatch(<arg>)`). Empty string = row is unfirable.
local function to_dispatch(d)
    if type(d) ~= "table" or not d.__dispatcher then return "" end
    local name = d.__dispatcher:gsub("^dsp%.", "")
    local a1   = d.args[1]

    if name == "exec_cmd" then                 return "hl.dsp.exec_cmd(" .. q(a1 or "") .. ")" end
    if name == "window.close" then             return "hl.dsp.window.close()"                  end
    if name == "window.pseudo" then            return "hl.dsp.window.pseudo()"                 end
    if name == "window.drag" then              return "hl.dsp.window.drag()"                   end
    if name == "window.resize" then            return "hl.dsp.window.resize()"                 end
    if name == "exit" then                     return "hl.dsp.exit()"                          end
    if name == "workspace.toggle_special" then return "hl.dsp.workspace.toggle_special(" .. q(a1 or "") .. ")" end

    if name == "focus" and type(a1) == "table" then
        if a1.direction then return "hl.dsp.focus({direction=" .. q(a1.direction) .. "})"      end
        if a1.workspace then return "hl.dsp.focus({workspace=" .. wsval(a1.workspace) .. "})"  end
    end
    if name == "window.move" and type(a1) == "table" and a1.workspace then
        return "hl.dsp.window.move({workspace=" .. wsval(a1.workspace) .. "})"
    end

    return ""
end

local function inspect(d)
    if type(d) ~= "table" or not d.__dispatcher then return tostring(d) end
    local name = d.__dispatcher:gsub("^dsp%.", "")
    local a1   = d.args[1]

    if name == "exec_cmd" then                          return strip_localbin(tostring(a1 or "")) end
    if name == "window.close" then                      return "killactive"                       end
    if name == "window.pseudo" then                     return "pseudo"                           end
    if name == "window.drag" then                       return "movewindow"                       end
    if name == "window.resize" then                     return "resizewindow"                     end
    if name == "exit" then                              return "exit"                             end
    if name == "workspace.toggle_special" then          return "togglespecialworkspace " .. tostring(a1 or "") end

    if name == "focus" and type(a1) == "table" then
        if a1.direction then return "movefocus " .. a1.direction end
        if a1.workspace then return "workspace " .. tostring(a1.workspace) end
    end
    if name == "window.move" and type(a1) == "table" and a1.workspace then
        return "movetoworkspace " .. tostring(a1.workspace)
    end

    return name
end

-- Drop the workspace-1..10 loop-generated binds; they'd flood the rofi list.
local function should_skip(b)
    if type(b.dispatcher) ~= "table" then return false end
    local d  = b.dispatcher.__dispatcher
    local a1 = b.dispatcher.args[1]
    if (d == "dsp.focus" or d == "dsp.window.move")
        and type(a1) == "table" and type(a1.workspace) == "number" then
        return true
    end
    return false
end

local function prettify(keys)
    local last_plus = keys:find(" %+ [^ +]*$")
    local mod, key
    if last_plus then
        mod = keys:sub(1, last_plus - 1):gsub("^%s*", ""):gsub("%s*$", "")
        key = keys:sub(last_plus + 3):gsub("^%s*", ""):gsub("%s*$", "")
    else
        mod = ""
        key = keys:gsub("^%s*", ""):gsub("%s*$", "")
    end

    if key == "slash" and mod:find("SHIFT") then
        key = "?"
        -- "SUPER + SHIFT" -> "SUPER"
        mod = mod:gsub("%s*%+%s*SHIFT", ""):gsub("SHIFT%s*%+%s*", "")
        mod = mod:gsub("^%s+", ""):gsub("%s+$", "")
    elseif key == "slash"   then key = "/"
    elseif key == "left"    then key = "<-"
    elseif key == "right"   then key = "->"
    elseif key == "up"      then key = "^"
    elseif key == "down"    then key = "v"
    elseif key == "PRINT"   then key = "PrtSc"
    elseif key == "SUPER_L" then key = "Super"
    end

    if mod == "" then return key end
    return mod .. " + " .. key
end

for _, b in ipairs(recorded) do
    if not should_skip(b) then
        local desc    = (b.opts and b.opts.desc) or inspect(b.dispatcher)
        local display = string.format("%-25s ->  %s", prettify(b.keys), desc)
        if with_dispatch then
            print(display .. "\t" .. to_dispatch(b.dispatcher))
        else
            print(display)
        end
    end
end
