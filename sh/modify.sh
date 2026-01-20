#!/bin/bash

# Spider.jar Init 方法修改脚本
# 将 String packageName = context.getPackageName(); 修改为硬编码的包名

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

# 修改包名获取逻辑
echo "2. 修改包名获取逻辑 (String packageName = \"com.fongmi.android.tv\")..."
SMALI_FILE="$TEMP_DIR/smali/com/github/catvod/spider/Init.smali"

if [ ! -f "$SMALI_FILE" ]; then
    echo "错误: 无法找到 $SMALI_FILE"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 使用 perl 进行正则替换：将 getPackageName 调用替换为常量字符串，并注销随后的 move-result-object 指令
# 支持多种 smali 格式（包括带 L 前缀或不带，点分隔或斜杠分隔等）
perl -i -0777 -pe 's/invoke-virtual \{p0\}, [^;]+;->getPackageName\(\)Ljava\/lang\/String;(\s+)move-result-object (v\d+)/const-string $2, "com.fongmi.android.tv"$1nop/g' "$SMALI_FILE"

# 验证是否修改成功
if ! grep -q "com.fongmi.android.tv" "$SMALI_FILE"; then
    echo "错误: 修改失败，未能在文件中找到目标字符串"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# 重新打包
echo "3. 重新打包..."
java -jar apktool.jar b "$TEMP_DIR" -o "$OUTPUT_JAR" >/dev/null 2>&1

# 清理临时文件
echo "4. 清理临时文件..."
rm -rf "$TEMP_DIR"

echo "完成! 输出文件: $OUTPUT_JAR"
