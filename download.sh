#!/bin/bash
# Instagram Downloader Skill - Universal Version (Images + Videos)
# 命名规则: {下载ID}_{总数}_{序号}
# 元数据: 视频嵌入文件，图片写入EXIF

URL="$1"
OUTPUT_DIR="/Users/leaof/Downloads/ins"
TEMP_DIR="/Users/leaof/.openclaw/workspace/temp"
FFMPEG="$HOME/.openclaw/ffmpeg"
FFPROBE="$HOME/.openclaw/ffprobe"
START_TIME=$(date +%s)
START_TIME_FMT=$(date +"%H:%M:%S")

# 清理函数 - 下载完成后删除临时文件
cleanup_temp() {
    local download_id="$1"
    if [ -n "$download_id" ]; then
        rm -f "$TEMP_DIR"/${download_id}_*.jpg "$TEMP_DIR"/${download_id}_*.mp4 "$TEMP_DIR"/${download_id}_*.json 2>/dev/null
        echo "🧹 已清理临时文件: ${download_id}"
    fi
}

# 创建输出目录
mkdir -p "$OUTPUT_DIR"
mkdir -p "$TEMP_DIR"

# 提取 shortcode
SHORTCODE=$(echo "$URL" | sed -n 's/.*instagram.com\/p\/\([^\/]*\).*/\1/p')
if [ -z "$SHORTCODE" ]; then
    SHORTCODE=$(echo "$URL" | sed -n 's/.*instagram.com\/reel\/\([^\/]*\).*/\1/p')
fi

echo "📥 开始下载: $URL"
echo "⏱️  开始时间: $START_TIME_FMT"
echo ""

# 先获取元数据判断类型
echo "🔍 获取帖子信息..."
META_JSON=$(python3 -m gallery_dl --cookies-from-browser chrome -j "$URL" 2>/dev/null)

POST_INFO=$(echo "$META_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    post = data[0][1]
    # 判断类型
    is_video = False
    video_url = None
    if len(data) > 1 and data[1][0] == 3:
        node = data[1][2]
        if node.get('video_url'):
            is_video = True
            video_url = node.get('video_url')
    
    print(f\"POST_ID:{post.get('post_id', '')}\")
    print(f\"AUTHOR:{post.get('username', 'unknown')}\")
    print(f\"FULLNAME:{post.get('fullname', '')}\")
    print(f\"CAPTION:{post.get('description', '')[:300]}\")
    print(f\"LIKES:{post.get('likes', 0)}\")
    print(f\"COUNT:{post.get('count', 0)}\")
    print(f\"DATE:{post.get('post_date', '')}\")
    print(f\"IS_VIDEO:{is_video}\")
    print(f\"VIDEO_URL:{video_url if video_url else ''}\")
    print(f\"TYPE:{'video' if is_video else 'image'}\")
except Exception as e:
    print(f'ERROR:{e}')
    print('POST_ID:')
    print('AUTHOR:unknown')
" 2>/dev/null)

# 解析信息
POST_ID=$(echo "$POST_INFO" | grep "^POST_ID:" | cut -d':' -f2-)
AUTHOR=$(echo "$POST_INFO" | grep "^AUTHOR:" | cut -d':' -f2-)
FULLNAME=$(echo "$POST_INFO" | grep "^FULLNAME:" | cut -d':' -f2-)
CAPTION=$(echo "$POST_INFO" | grep "^CAPTION:" | cut -d':' -f2-)
LIKES=$(echo "$POST_INFO" | grep "^LIKES:" | cut -d':' -f2)
COUNT=$(echo "$POST_INFO" | grep "^COUNT:" | cut -d':' -f2)
POST_DATE=$(echo "$POST_INFO" | grep "^DATE:" | cut -d':' -f2-)
IS_VIDEO=$(echo "$POST_INFO" | grep "^IS_VIDEO:" | cut -d':' -f2)
TYPE=$(echo "$POST_INFO" | grep "^TYPE:" | cut -d':' -f2)

# 构建下载ID (格式: 作者_YYYYMMDD_HHMMSS)
TIME_PART=$(echo "$START_TIME_FMT" | sed 's/://g')
DOWNLOAD_ID="${AUTHOR}_$(date +%Y%m%d)_${TIME_PART}"

echo "📋 帖子类型: ${TYPE:-未知}"
echo "👤 作者: @$AUTHOR"
echo "🆔 下载ID: $DOWNLOAD_ID"
echo ""

# 下载内容
cd "$OUTPUT_DIR" || exit 1

if [ "$TYPE" = "video" ]; then
    echo "🎬 检测到视频，开始下载..."
    # 尝试 gallery-dl 下载视频
    python3 -m gallery_dl --cookies-from-browser chrome -o base-directory="$OUTPUT_DIR" -o directory="" "$URL" 2>&1
    
    # 找到下载的视频文件
    VIDEO_FILE=$(ls -t "$OUTPUT_DIR"/${POST_ID}*.mp4 2>/dev/null | head -1)
    
    if [ -n "$VIDEO_FILE" ]; then
        NEW_NAME="${DOWNLOAD_ID}_1_1.mp4"
        mv "$VIDEO_FILE" "$OUTPUT_DIR/$NEW_NAME"
        echo "✅ 视频下载成功: $NEW_NAME"
        
        # 构建元数据JSON
        METADATA_JSON=$(python3 -c "
import json
data = {
    'source_url': '$URL',
    'download_id': '$DOWNLOAD_ID',
    'author': '$AUTHOR',
    'author_fullname': '$FULLNAME',
    'caption': '''${CAPTION}''',
    'likes': $LIKES,
    'post_date': '$POST_DATE',
    'download_time': '$(date +%Y-%m-%dT%H:%M:%S)'
}
print(json.dumps(data, ensure_ascii=False, indent=2))
")
        
        # 嵌入元数据到视频文件
        echo "📝 嵌入元数据到视频..."
        TEMP_VIDEO="${OUTPUT_DIR}/${NEW_NAME}.tmp"
        
        "$FFMPEG" -i "$OUTPUT_DIR/$NEW_NAME" -metadata "comment=$METADATA_JSON" -metadata "description=${CAPTION}" -metadata "artist=${AUTHOR}" -metadata "title=${DOWNLOAD_ID}" -codec copy -y "$TEMP_VIDEO" 2>/dev/null
        
        if [ -f "$TEMP_VIDEO" ]; then
            mv "$TEMP_VIDEO" "$OUTPUT_DIR/$NEW_NAME"
            echo "✅ 元数据嵌入成功"
        else
            echo "⚠️  元数据嵌入失败，保存为sidecar文件"
            echo "$METADATA_JSON" > "${OUTPUT_DIR}/${NEW_NAME}.json"
        fi
        
        cp "$OUTPUT_DIR/$NEW_NAME" "$TEMP_DIR"/ 2>/dev/null
        echo "$METADATA_JSON" > "$TEMP_DIR/${NEW_NAME}.json"
        
        VID_COUNT=1
        IMG_COUNT=0
    else
        echo "⚠️  gallery-dl 下载视频失败，尝试 yt-dlp..."
        python3 -m yt_dlp --cookies-from-browser chrome -o "${POST_ID}.%(ext)s" "$URL" 2>&1
        
        VIDEO_FILE=$(ls -t "$OUTPUT_DIR"/${POST_ID}*.mp4 2>/dev/null | head -1)
        if [ -n "$VIDEO_FILE" ]; then
            NEW_NAME="${DOWNLOAD_ID}_1_1.mp4"
            mv "$VIDEO_FILE" "$OUTPUT_DIR/$NEW_NAME"
            
            TEMP_VIDEO="${OUTPUT_DIR}/${NEW_NAME}.tmp"
            "$FFMPEG" -i "$OUTPUT_DIR/$NEW_NAME" -metadata "comment=$METADATA_JSON" -metadata "description=${CAPTION}" -metadata "artist=${AUTHOR}" -metadata "title=${DOWNLOAD_ID}" -codec copy -y "$TEMP_VIDEO" 2>/dev/null
            
            if [ -f "$TEMP_VIDEO" ]; then
                mv "$TEMP_VIDEO" "$OUTPUT_DIR/$NEW_NAME"
                echo "✅ 元数据嵌入成功"
            else
                echo "⚠️  元数据嵌入失败，保存为sidecar文件"
                echo "$METADATA_JSON" > "${OUTPUT_DIR}/${NEW_NAME}.json"
            fi
            
            cp "$OUTPUT_DIR/$NEW_NAME" "$TEMP_DIR"/ 2>/dev/null
            echo "$METADATA_JSON" > "$TEMP_DIR/${NEW_NAME}.json"
            VID_COUNT=1
            IMG_COUNT=0
        else
            VID_COUNT=0
            IMG_COUNT=0
        fi
    fi
else
    echo "📷 检测到图片，开始下载..."
    python3 -m gallery_dl --cookies-from-browser chrome -o base-directory="$OUTPUT_DIR" -o directory="" "$URL" 2>&1
    
    DOWNLOADED_FILES=($(ls -t "$OUTPUT_DIR"/${POST_ID}_*.jpg 2>/dev/null))
    
    if [ ${#DOWNLOADED_FILES[@]} -eq 0 ] && [ -f "$OUTPUT_DIR"/${POST_ID}.jpg ]; then
        DOWNLOADED_FILES=("$OUTPUT_DIR/${POST_ID}.jpg")
    fi
    
    TOTAL_FILES=${#DOWNLOADED_FILES[@]}
    IMG_COUNT=$TOTAL_FILES
    VID_COUNT=0
    
    if [ $TOTAL_FILES -gt 0 ]; then
        echo "📝 重命名文件并写入EXIF (${TOTAL_FILES} 张)..."
        
        IFS=$'\n' SORTED_FILES=($(ls -t "$OUTPUT_DIR"/${POST_ID}*.jpg 2>/dev/null))
        unset IFS
        
        COUNTER=1
        for FILE in "${SORTED_FILES[@]}"; do
            if [ -f "$FILE" ]; then
                EXT="${FILE##*.}"
                NEW_NAME="${DOWNLOAD_ID}_${TOTAL_FILES}_${COUNTER}.${EXT}"
                mv "$FILE" "$OUTPUT_DIR/$NEW_NAME"
                
                # 使用Python写入EXIF元数据
                python3 - "$OUTPUT_DIR/$NEW_NAME" "$URL" "$DOWNLOAD_ID" "${TOTAL_FILES}_${COUNTER}" "$AUTHOR" "$FULLNAME" "$CAPTION" "$LIKES" "$POST_DATE" "$(date +%Y-%m-%dT%H:%M:%S)" << 'PYEOF'
import sys
from PIL import Image
import json

img_path = sys.argv[1]
source_url = sys.argv[2]
download_id = sys.argv[3]
file_index = sys.argv[4]
author = sys.argv[5]
author_fullname = sys.argv[6]
caption = sys.argv[7]
likes = int(sys.argv[8])
post_date = sys.argv[9]
download_time = sys.argv[10]

try:
    img = Image.open(img_path)
    exif = img.getexif()
    if exif is None:
        exif = {}
    
    metadata = {
        "source_url": source_url,
        "download_id": download_id,
        "file_index": file_index,
        "author": author,
        "author_fullname": author_fullname,
        "caption": caption,
        "likes": likes,
        "post_date": post_date,
        "download_time": download_time
    }
    metadata_str = json.dumps(metadata, ensure_ascii=False)
    
    exif[0x9286] = metadata_str.encode('utf-8')
    exif[0x010E] = source_url.encode('utf-8')  # ImageDescription 写入下载链接
    exif[0x0131] = author.encode('utf-8')
    
    img.save(img_path, exif=exif)
    print(f"✅ EXIF写入成功: {img_path}")
    
except Exception as e:
    print(f"⚠️  EXIF写入失败: {e}", file=sys.stderr)
    json_path = img_path + ".json"
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)
    print(f"✅ Sidecar文件已保存: {json_path}")
PYEOF
                
                echo "   ${COUNTER}. $NEW_NAME (EXIF已写入)"
                cp "$OUTPUT_DIR/$NEW_NAME" "$TEMP_DIR"/ 2>/dev/null
                COUNTER=$((COUNTER + 1))
            fi
        done
        
        echo "✅ 图片下载完成: ${TOTAL_FILES} 张 (EXIF元数据已写入)"
    else
        echo "⚠️  未找到下载的图片文件"
        IMG_COUNT=0
    fi
fi

# 计算耗时
END_TIME=$(date +%s)
END_TIME_FMT=$(date +"%H:%M:%S")
ELAPSED=$((END_TIME - START_TIME))
ELAPSED_MIN=$((ELAPSED / 60))
ELAPSED_SEC=$((ELAPSED % 60))

if [ ${#CAPTION} -gt 200 ]; then
    CAPTION="${CAPTION:0:200}..."
fi

# 输出完成报告
echo ""
echo "📥 下载完成报告"
echo "━━━━━━━━━━━━━━━━━━━━"
echo "🆔 下载ID: ${DOWNLOAD_ID}"
echo "📍 帖子链接: $URL"
echo "👤 作者: @$AUTHOR" $([ -n "$FULLNAME" ] && echo "($FULLNAME)")
if [ -n "$CAPTION" ]; then
    echo "📝 内容: $CAPTION"
fi
echo "🩷 点赞: $LIKES"
if [ "$IMG_COUNT" -gt 0 ]; then
    echo "📷 图片数量: $IMG_COUNT 张 (EXIF元数据已写入)"
fi
if [ "$VID_COUNT" -gt 0 ]; then
    echo "🎬 视频数量: $VID_COUNT 个 (元数据已嵌入文件)"
fi
echo "📂 下载地址: $OUTPUT_DIR"
echo "⏱️  下载时间: $START_TIME_FMT - $END_TIME_FMT (${ELAPSED_MIN}分${ELAPSED_SEC}秒)"
echo "━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "----- MARKDOWN_FORMAT (控制台输出) -----"
echo "# Instagram 下载报告"
echo ""
echo "**下载ID**: \`${DOWNLOAD_ID}\`"
echo "**帖子链接**: $URL"
echo "**作者**: @$AUTHOR $([ -n "$FULLNAME" ] && echo "($FULLNAME)")"
echo "**下载时间**: $(date +%Y-%m-%d) $START_TIME_FMT ~ $END_TIME_FMT"
echo ""
echo "## 统计数据"
echo "| 项目 | 数值 |"
echo "|------|------|"
echo "| 点赞 | $LIKES |"
echo "| 图片 | ${IMG_COUNT} 张 |"
echo "| 视频 | ${VID_COUNT} 个 |"
echo ""
echo "## 元数据"
echo "- **图片**: EXIF元数据 (UserComment字段)"
echo "- **视频**: 元数据已嵌入文件 (ffmpeg)"

echo ""
echo "----- JSON_FORMAT (控制台输出) -----"
python3 -c "
import json
data = {
    'download_id': '$DOWNLOAD_ID',
    'source_url': '$URL',
    'author': '$AUTHOR',
    'likes': ${LIKES:-0},
    'images': ${IMG_COUNT:-0},
    'videos': ${VID_COUNT:-0}
}
print(json.dumps(data, ensure_ascii=False, indent=2))
"

echo ""
echo "✅ 下载完成！"
echo ""
echo "🧹 清理临时文件:"
echo "   bash ~/.openclaw/skills/social/social-instagram/cleanup.sh ${DOWNLOAD_ID}"
