--- 过滤器：单字模式（由 single_char_mode 开关控制）
local function wubi86_jidian_single_char_filter(input, env)
    local single = env.engine.context:get_option("single_char_mode")
    for cand in input:iter() do
        if not single or utf8.len(cand.text) == 1 then
            yield(cand)
        end
    end
end

return wubi86_jidian_single_char_filter
