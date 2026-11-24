-- 集成测试：用 Squirrel 自带的真实 librime + librime-lua 部署当前配置并模拟按键
-- 运行：lua tests/integration_test.lua   （在配置目录下执行，需要已安装 Squirrel 和 clang）
-- 在临时目录中部署，不影响正在使用的输入法和用户词库

local FRAMEWORKS = "/Library/Input Methods/Squirrel.app/Contents/Frameworks"
local tmp = os.getenv("TMPDIR") or "/tmp/"
local work = tmp .. "rime_integration_test"
local probe = work .. "/rime_probe"
local user_dir = work .. "/user"

local function sh(cmd)
    local ok = os.execute(cmd)
    if not ok then error("command failed: " .. cmd) end
end

local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

-- 准备：编译探针，复制配置到隔离目录 -------------------------------------
sh("rm -rf " .. q(work) .. " && mkdir -p " .. q(user_dir))
sh(("clang -o %s tests/rime_probe.c -Itests -L%s -lrime.1 -Wl,-rpath,%s")
    :format(q(probe), q(FRAMEWORKS), q(FRAMEWORKS)))
sh("cp -R *.yaml lua " .. q(user_dir) .. " 2>/dev/null; rm -f " .. q(user_dir .. "/user.yaml"))

-- 运行探针，返回 { keys = {候选...} } 和 stderr 内容
local function run(schema, options, keys_list)
    local args = { q(probe), q(user_dir), q(schema) }
    for k, v in pairs(options or {}) do args[#args + 1] = q(k .. "=" .. (v and 1 or 0)) end
    args[#args + 1] = "--"
    for _, k in ipairs(keys_list) do args[#args + 1] = q(k) end
    local err_file = work .. "/stderr.txt"
    local p = io.popen(table.concat(args, " ") .. " 2>" .. q(err_file))
    local result = {}
    for line in p:lines() do
        local fields = {}
        for f in (line .. "\t"):gmatch("(.-)\t") do fields[#fields + 1] = f end
        result[table.remove(fields, 1)] = fields
    end
    local ok = p:close()
    local f = io.open(err_file); local err = f:read("a"); f:close()
    return result, err, ok
end

-- 断言 ------------------------------------------------------------------
local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL " .. name .. (detail and ("\n  " .. detail) or ""))
    end
end

local function contains(list, text)
    for _, v in ipairs(list or {}) do if v == text then return true end end
    return false
end

local function all_single_char(list)
    for _, v in ipairs(list or {}) do
        if utf8.len(v) ~= 1 and not v:match("^[%d%p%s]+$") then return false, v end
    end
    return true
end

local function show(list) return "[" .. table.concat(list or {}, "] [") .. "]" end

local keys = { "date", "time", "week", "gggg", "a", "gg", "znihao", "znihc" }

-- 部署与 lua 加载 --------------------------------------------------------
local normal, err, ok = run("wubi86_jidian", { single_char_mode = false }, keys)
check("探针正常退出", ok, err)
check("部署/lua 无 ERROR 日志", not err:match("\nE%d") and not err:match("^E%d"), err)

-- 日期时间（真实 lua_translator） ---------------------------------------
check("date 出日期", contains(normal.date, os.date("%Y-%m-%d")), show(normal.date))
check("time 出时间", contains(normal.time, os.date("%H:%M")), show(normal.time))
check("week 出星期", contains(normal.week, "星期" .. ({ "日", "一", "二", "三", "四", "五", "六" })[os.date("%w") + 1]),
    show(normal.week))

-- 普通五笔输入 ------------------------------------------------------------
check("gggg 首选为 王", (normal.gggg or {})[1] == "王", show(normal.gggg))
check("单字模式关：a 有词组候选", not all_single_char(normal.a), show(normal.a))

-- 单字模式开（真实 lua_filter + 真实候选类型） ----------------------------
local single = run("wubi86_jidian", { single_char_mode = true }, keys)
for _, k in ipairs({ "a", "gg" }) do
    local only, bad = all_single_char(single[k])
    check("单字模式开：" .. k .. " 只有单字", only, "漏出词组 " .. tostring(bad) .. "：" .. show(single[k]))
    check("单字模式开：" .. k .. " 仍有候选", #(single[k] or {}) > 0, show(single[k]))
end
check("单字模式开：date 仍出日期", contains(single.date, os.date("%Y-%m-%d")), show(single.date))
check("单字模式开：time 仍出时间", contains(single.time, os.date("%H:%M")), show(single.time))

-- 全拼和小鹤共用 z 前缀，按开关选择其一。
local full_pinyin, full_pinyin_err, full_pinyin_ok = run("wubi86_jidian", { full_pinyin_reverse_lookup = true }, { "znihao", "znihc" })
check("默认使用小鹤双拼反查", contains(normal.znihc, "你好") and not contains(normal.znihao, "你好"))
check("切换到全拼反查", full_pinyin_ok and contains(full_pinyin.znihao, "你好") and not contains(full_pinyin.znihc, "你好"), full_pinyin_err)

sh("rm -rf " .. q(work))
print(("\n%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
