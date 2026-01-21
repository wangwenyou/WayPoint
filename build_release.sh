#!/bin/bash
set -e # 遇到错误立即停止

# --- 配置区域 ---
PROJECT_NAME="WayPoint"
SCHEME_NAME="WayPoint"
OUTPUT_DIR="release_build"
APP_NAME="WayPoint.app"
ZIP_NAME="WayPoint_Universal.zip"
# ----------------

echo "🚀 [1/4] 开始构建 Universal Release 版本..."

# 1. 清理工作区
if [ -d "$OUTPUT_DIR" ]; then
    echo "🧹 清理旧的构建目录..."
    rm -rf "$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"

# 2. 执行归档构建 (Archive)
# -destination 'generic/platform=macOS' 指示 Xcode 构建包含所有标准架构(Universal)的版本
xcodebuild -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$OUTPUT_DIR/DerivedData" \
    archive \
    -archivePath "$OUTPUT_DIR/$PROJECT_NAME.xcarchive" \
    QUIET=YES

echo "📦 [2/4] 从归档中提取应用..."

# 3. 提取 .app
# Archive 的结构中，应用位于 Products/Applications 下
cp -R "$OUTPUT_DIR/$PROJECT_NAME.xcarchive/Products/Applications/$APP_NAME" "$OUTPUT_DIR/$APP_NAME"

# 验证架构 (可选，用于调试)
echo "🔍 验证二进制架构信息:"
lipo -info "$OUTPUT_DIR/$APP_NAME/Contents/MacOS/$PROJECT_NAME"

# 4. 清理中间文件
echo "🧹 [3/4] 清理中间缓存文件..."
rm -rf "$OUTPUT_DIR/DerivedData"
rm -rf "$OUTPUT_DIR/$PROJECT_NAME.xcarchive"

# 5. 压缩
echo "🤐 [4/4] 正在生成 ZIP 包..."
cd "$OUTPUT_DIR"
# 使用 ditto 代替 zip，能更好地保留 macOS 特有的文件属性和权限
ditto -c -k --keepParent "$APP_NAME" "$ZIP_NAME"

echo "✅ 构建成功！"
echo "📂 应用路径: $PWD/$APP_NAME"
echo "📦 压缩包:   $PWD/$ZIP_NAME"
