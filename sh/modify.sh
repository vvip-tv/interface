#!/bin/bash

# Spider.jar Init 方法修改脚本
# 直接绕过 init() 中的所有验证检查，跳到成功路径

set -e

INPUT_JAR="spider.jar"
OUTPUT_JAR="../jar/spider.jar"
TEMP_DIR="temp_$$"

if [ ! -f "$INPUT_JAR" ]; then
    echo "错误: 找不到 $INPUT_JAR"
    exit 1
fi

if [ ! -f "apktool.jar" ]; then
    echo "错误: 找不到 apktool.jar"
    exit 1
fi

echo "开始处理 $INPUT_JAR ..."

echo "1. 反编译..."
java -jar apktool.jar d "$INPUT_JAR" -o "$TEMP_DIR" -f >/dev/null 2>&1

SMALI_FILE="$TEMP_DIR/smali/com/github/catvod/spider/Init.smali"

if [ ! -f "$SMALI_FILE" ]; then
    echo "错误: 无法找到 $SMALI_FILE"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 找到 init() 方法起始行
INIT_LINE=$(grep -n "\.method public static init" "$SMALI_FILE" | head -1 | cut -d: -f1)
echo "init() 方法起始行: $INIT_LINE"

# 找到成功路径的特征代码：invoke-static {}, ...->get()...Init;
# 这是验证通过后的第一个调用，结构稳定不变
SUCCESS_LINE=$(tail -n +$INIT_LINE "$SMALI_FILE" | grep -n "invoke-static {}, Lcom/github/catvod/spider/Init;->get" | head -1 | cut -d: -f1)
SUCCESS_LINE=$((INIT_LINE + SUCCESS_LINE - 1))
echo "成功路径起始行: $SUCCESS_LINE"

if [ -z "$INIT_LINE" ] || [ -z "$SUCCESS_LINE" ] || [ "$SUCCESS_LINE" -le "$INIT_LINE" ]; then
    echo "错误: 无法定位 init() 方法或成功路径"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 找到成功路径前的标签行（:try_start_0 或 :cond_X 等）
# 从 SUCCESS_LINE 往上找最近的标签行
LABEL_LINE=$SUCCESS_LINE
while [ $LABEL_LINE -gt $INIT_LINE ]; do
    LABEL_LINE=$((LABEL_LINE - 1))
    LINE_CONTENT=$(sed -n "${LABEL_LINE}p" "$SMALI_FILE")
    if echo "$LINE_CONTENT" | grep -qE '^\s+:(try_start|cond|goto)'; then
        break
    fi
done
echo "成功路径标签行: $LABEL_LINE"

# 删除范围：从 .locals 下一行到成功路径标签行前一行
START_LINE=$((INIT_LINE + 2))
END_LINE=$((LABEL_LINE - 1))
echo "删除验证代码行范围: $START_LINE - $END_LINE"

# 删除验证代码，插入 goto 跳到成功路径标签
sed -i '' "${START_LINE},${END_LINE}d" "$SMALI_FILE"

# 获取成功路径的标签名
LABEL_NAME=$(sed -n "${START_LINE}p" "$SMALI_FILE" | grep -oE ':[a-zA-Z0-9_]+')
echo "成功路径标签: $LABEL_NAME"

sed -i '' "${START_LINE}i\\
\\
    goto/16 ${LABEL_NAME}
" "$SMALI_FILE"

echo "2. 绕过验证完成: goto/16 ${LABEL_NAME}"

echo "3. 重新打包..."
java -jar apktool.jar b "$TEMP_DIR" -o "$OUTPUT_JAR" >/dev/null 2>&1

echo "4. 清理临时文件..."
rm -rf "$TEMP_DIR"

echo "完成! 输出文件: $OUTPUT_JAR"