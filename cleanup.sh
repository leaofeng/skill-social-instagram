#!/bin/bash
# Instagram Downloader - Temp Cleanup Script
# 支持新的命名规则: {下载ID}_{总数}_{序号}
# 支持清理: .jpg, .jpeg, .mp4, .json
# Usage: instagram-cleanup.sh [DOWNLOAD_ID]

TEMP_DIR="/Users/leaof/.openclaw/workspace/temp"
DOWNLOAD_ID="$1"

if [ -z "$DOWNLOAD_ID" ]; then
    # 如果没有指定 DOWNLOAD_ID，清理所有旧的临时文件（超过1小时的）
    echo "🧹 清理超过1小时的旧临时文件..."
    find "$TEMP_DIR" \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.mp4" -o -name "*.json" \) -type f -mmin +60 -exec rm -f {} \; 2>/dev/null
    COUNT=$(find "$TEMP_DIR" \( -name "*.jpg" -o -name "*.mp4" -o -name "*.json" \) -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "✅ 清理完成，剩余 $COUNT 个临时文件"
    exit 0
fi

# 清理指定 DOWNLOAD_ID 的临时文件
# 新命名规则: {DOWNLOAD_ID}_{总数}_{序号}.{扩展名}
echo "🧹 清理临时文件: ${DOWNLOAD_ID}"
rm -f "$TEMP_DIR"/${DOWNLOAD_ID}_*.* 2>/dev/null
rm -f "$TEMP_DIR"/${DOWNLOAD_ID}_*.json 2>/dev/null

echo "✅ 已清理 ${DOWNLOAD_ID} 相关的临时文件"
