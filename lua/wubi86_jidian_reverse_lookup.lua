local function init(env)
    env.full_pinyin = Component.Translator(env.engine, "reverse_lookup", "reverse_lookup_translator")
    env.flypy = Component.Translator(env.engine, "flypy_lookup", "reverse_lookup_translator")
end

local function translate(input, segment, env)
    local translator = env.flypy
    if env.engine.context:get_option("full_pinyin_reverse_lookup") then
        translator = env.full_pinyin
    end
    local translation = translator:query(input, segment)
    if translation then
        for candidate in translation:iter() do
            yield(candidate)
        end
    end
end

return { init = init, func = translate }
