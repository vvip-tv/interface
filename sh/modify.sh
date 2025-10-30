#!/bin/bash

# Spider.jar Init 方法精简脚本
# 移除包名验证，只保留 m4a() 调用

set -e

INPUT_JAR="spider.jar"
OUTPUT_JAR="../jar/spider.jar"
TEMP_DIR="temp_$$"

# 检查输入文件
if [ ! -f "$INPUT_JAR" ]; then
    echo "错误: 找不到 $INPUT_JAR"
    exit 1
fi

# 检查 apktool
if [ ! -f "apktool.jar" ]; then
    echo "错误: 找不到 apktool.jar"
    exit 1
fi

echo "开始处理 $INPUT_JAR ..."

# 反编译
echo "1. 反编译..."
java -jar apktool.jar d "$INPUT_JAR" -o "$TEMP_DIR" -f >/dev/null 2>&1

# 修改 init 方法
echo "2. 精简 init 方法（仅保留 m4a 调用）..."
SMALI_FILE="$TEMP_DIR/smali/com/github/catvod/spider/Init.smali"

# 创建新的 init 方法（移除包名检查，只调用 m4a）
cat > /tmp/new_init_method.smali << 'EOF'
.method public static init(Landroid/content/Context;)V
    .locals 1

    :try_start_0
    invoke-static {}, Lcom/github/catvod/spider/Init;->get()Lcom/github/catvod/spider/Init;

    move-result-object v0

    check-cast p0, Landroid/app/Application;

    iput-object p0, v0, Lcom/github/catvod/spider/Init;->c:Landroid/app/Application;

    invoke-static {}, Lcom/github/catvod/spider/Init;->a()V
    :try_end_0
    .catch Ljava/lang/Exception; {:try_start_0 .. :try_end_0} :catch_0

    goto :goto_0

    :catch_0
    move-exception v0

    invoke-virtual {v0}, Ljava/lang/Exception;->printStackTrace()V

    :goto_0
    return-void
.end method
EOF

# 找到 init 方法的开始和结束行号
START_LINE=$(grep -n "^\.method public static init(Landroid/content/Context;)V" "$SMALI_FILE" | cut -d: -f1)
END_LINE=$(awk "NR>$START_LINE && /^\.end method/ {print NR; exit}" "$SMALI_FILE")

if [ -z "$START_LINE" ] || [ -z "$END_LINE" ]; then
    echo "错误: 无法找到 init 方法"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 备份原文件
cp "$SMALI_FILE" "$SMALI_FILE.bak"

# 替换 init 方法
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "${START_LINE},${END_LINE}d" "$SMALI_FILE"
    sed -i '' "${START_LINE}r /tmp/new_init_method.smali" "$SMALI_FILE"
else
    # Linux
    sed -i "${START_LINE},${END_LINE}d" "$SMALI_FILE"
    sed -i "${START_LINE}r /tmp/new_init_method.smali" "$SMALI_FILE"
fi

# 清理临时文件
rm -f /tmp/new_init_method.smali

# 重新打包
echo "3. 重新打包..."
java -jar apktool.jar b "$TEMP_DIR" -o "$OUTPUT_JAR" >/dev/null 2>&1

# 清理临时文件
echo "4. 清理临时文件..."
rm -rf "$TEMP_DIR"

echo "完成! 输出文件: $OUTPUT_JAR"
