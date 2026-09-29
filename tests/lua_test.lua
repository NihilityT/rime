-- lua/ 下脚本的回归测试（模拟 librime-lua 运行时，不依赖 Rime）
-- 运行：lua tests/lua_test.lua   （在 Rime 配置目录下执行）

package.path = "./lua/?.lua;" .. package.path

-- 模拟 librime-lua 提供的全局对象 ------------------------------------------
local out
function yield(cand) table.insert(out, cand) end
function Candidate(type, start, _end, text, comment)
    return { type = type, start = start, _end = _end, text = text, comment = comment }
end

local seg = { start = 0, _end = 0 }

local function run_translator(fn, input)
    out = {}
    fn(input, seg)
    return out
end

local function make_input(list)
    return { iter = function()
        local i = 0
        return function() i = i + 1; return list[i] end
    end }
end

local function make_env(options)
    return { engine = { context = { get_option = function(_, name) return options[name] end } } }
end

local function run_filter(fn, list, options)
    out = {}
    fn(make_input(list), make_env(options or {}))
    return out
end

local function texts(cands)
    local t = {}
    for _, c in ipairs(cands) do t[#t + 1] = c.text end
    return table.concat(t, " ")
end

-- 断言 ------------------------------------------------------------------
local passed, failed = 0, 0
local function eq(name, actual, expected)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(("FAIL %s\n  expected: %s\n  actual:   %s"):format(name, tostring(expected), tostring(actual)))
    end
end

-- 日期时间 --------------------------------------------------------------
local date = require("wubi86_jidian_date_translator")
eq("date 首选为 ISO 日期", run_translator(date, "date")[1].text, os.date("%Y-%m-%d"))
eq("time 首选为 时:分", run_translator(date, "time")[1].text, os.date("%H:%M"))
eq("datetime", run_translator(date, "datetime")[1].text:match("^%d+%-%d+%-%d+ %d+:%d+:%d+$") ~= nil, true)
eq("week 首选为 周X", run_translator(date, "week")[1].text:match("^周") ~= nil, true)
eq("month 有候选", #run_translator(date, "month") > 0, true)
eq("普通编码无候选", #run_translator(date, "gggg"), 0)

-- 单字模式过滤器（带开关） -----------------------------------------------
local single = require("wubi86_jidian_single_char_filter")
local cands = {
    { text = "工", type = "table" },
    { text = "工作", type = "table" },
    { text = "造词", type = "user_table" },
    { text = "补全词", type = "completion" },
    { text = "2026-09-29", type = "date" },
    { text = "15:30", type = "time" },
}
eq("单字模式开：去掉词组，保留 lua 候选",
    texts(run_filter(single, cands, { single_char_mode = true })), "工 2026-09-29 15:30")
eq("单字模式关：全部保留",
    texts(run_filter(single, cands, { single_char_mode = false })), "工 工作 造词 补全词 2026-09-29 15:30")

-- 单字优先 / 纯单字 -------------------------------------------------------
local first = require("wubi86_jidian_single_char_first_filter")
eq("单字优先：单字排前且保留词组",
    texts(run_filter(first, { { text = "工作" }, { text = "工" }, { text = "式" } })), "工 式 工作")

local only = require("wubi86_jidian_single_char_only")
eq("纯单字：只留单字",
    texts(run_filter(only, { { text = "工作" }, { text = "工" } })), "工")

-- 语法检查：lua/ 下所有文件都能加载 ----------------------------------------
for file in io.popen("ls lua/*.lua"):lines() do
    local ok, err = loadfile(file)
    eq("语法 " .. file, ok ~= nil, true)
    if not ok then print("  " .. err) end
end

print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
