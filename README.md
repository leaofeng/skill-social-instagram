# social-instagram

Instagram 图片/视频下载工具

## 功能

- 下载 Instagram 图片、视频、Reels
- 支持多图相册批量下载
- 自动写入 EXIF 元数据（图片来源、作者、点赞数等）
- 智能命名：{作者}_{日期}_{时间}_{总数}_{序号}.jpg
- 支持 gallery-dl 和 yt-dlp 双引擎

## 安装依赖

```bash
# 安装 gallery-dl
pip3 install gallery-dl

# 安装 yt-dlp（备用）
brew install yt-dlp

# 需要 Chrome 浏览器（用于 cookies）
```

## 使用方法

```bash
# 下载 Instagram 帖子
bash download.sh "https://www.instagram.com/p/xxxxx/"

# 清理临时文件
bash cleanup.sh {下载ID}
```

## 输出示例

```
~/Downloads/ins/
├── author_20240224_143022_5_1.jpg
├── author_20240224_143022_5_1.jpg.json  # 元数据
├── author_20240224_143022_5_2.jpg
└── ...
```

## 技术栈

- gallery-dl
- yt-dlp
- Python Pillow (EXIF 写入)
- Chrome cookies

## 作者

leaofeng
