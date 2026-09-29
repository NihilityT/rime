--- 过滤器：单字模式（由 single_char_mode 开关控制）
--- 只过滤词库产生的词组，日期、计算器等 lua 候选不受影响
local table_types = {
    table = true,
    user_table = true,
    completion = true,
    sentence = true,
    phrase = true,
    user_phrase = true,
}

local function wubi86_jidian_single_char_filter(input, env)
    local single = env.engine.context:get_option("single_char_mode")
    for cand in input:iter() do
        if not single or not table_types[cand.type] or utf8.len(cand.text) == 1 then
            yield(cand)
        end
    end
end

return wubi86_jidian_single_char_filter
