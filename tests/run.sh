#!/bin/sh
# 运行全部测试：tests/run.sh
# 未安装 Squirrel 时跳过集成测试
set -e
cd "$(dirname "$0")/.."

echo "== 单元测试 (lua_test.lua)"
lua tests/lua_test.lua

if [ -d "/Library/Input Methods/Squirrel.app" ]; then
    echo "== 集成测试 (integration_test.lua)"
    lua tests/integration_test.lua
else
    echo "== 跳过集成测试：未安装 Squirrel"
fi
