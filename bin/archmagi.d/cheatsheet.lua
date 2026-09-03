-- Parser for archmagi cheatsheet: loads a Hyprland Lua binds file with a stubbed
-- `hl` API that records only hl.bind(...) calls, then emits one "KEYS -> DESC"
-- row per bind — with workspace-1..10 loop entries skipped, key names
-- prettified, and the ~/.local/bin/ prefix stripped from exec commands.
--
-- Usage: lua cheatsheet.lua <binds.lua path>
-- Output: one line per bind, meant to be piped into rofi -dmenu.

local binds_file = arg[1]
if not binds_file then
    io.stderr:write("cheatsheet.lua: missing binds file path\n")
    os.exit(1)
end

local recorded = {}

-- Namespace proxy: every nested access returns another proxy, and calling any
-- terminal produces a { __dispatcher, args } record we can pretty-print later.
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

-- Any hl.<something>(...) other than hl.bind is a no-op. hl.bind captures.
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

-- ---- Rendering ----

local home_prefix  = os.getenv("HOME") .. "/.local/bin/"
local tilde_prefix = "~/.local/bin/"

local function strip_localbin(s)
    if s:sub(1, #home_prefix)  == home_prefix  then return s:sub(#home_prefix  + 1) end
    if s:sub(1, #tilde_prefix) == tilde_prefix then return s:sub(#tilde_prefix + 1) end
    return s
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

local function should_skip(b)
    -- Filter workspace-N and movetoworkspace-N loop-generated binds (N in 1..10).
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
    -- Split on last " + " to separate mods from key.
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
        -- Strip "SHIFT" and the surrounding "+" so "SUPER + SHIFT" -> "SUPER".
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
        local desc = (b.opts and b.opts.desc) or inspect(b.dispatcher)
        print(string.format("%-25s ->  %s", prettify(b.keys), desc))
    end
end
