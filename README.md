# social-instagram

> Instagram 图片/视频下载工具 | Instagram Image/Video Downloader

---

## 简介 | Introduction

**中文：**

一个用于下载 Instagram 图片、视频和 Reels 的命令行工具。支持批量下载、自动命名和 EXIF 元数据写入。

**English:**

A command-line tool for downloading Instagram images, videos, and Reels. Supports batch downloading, automatic naming, and EXIF metadata injection.

---

## 功能特性 | Features

| 中文 | English |
|------|---------|
| 下载单图/多图/视频/Reels | Download single/multiple images, videos, and Reels |
| 智能命名格式：`{作者}_{日期}_{时间}_{总数}_{序号}.jpg` | Smart naming: `{author}_{date}_{time}_{total}_{index}.jpg` |
| 自动写入 EXIF 元数据 | Automatic EXIF metadata injection |
| 支持 gallery-dl + yt-dlp 双引擎 | Dual-engine support: gallery-dl + yt-dlp |

---

## 安装依赖 | Installation

```bash
# 安装 gallery-dl
pip3 install gallery-dl

# 安装 yt-dlp（备用引擎）
brew install yt-dlp

# 需要 Chrome 浏览器用于 cookies
# Chrome browser required for cookies
```

---

## 使用方法 | Usage

```bash
# 下载 Instagram 帖子 | Download Instagram post
bash download.sh "https://www.instagram.com/p/xxxxx/"

# 清理临时文件 | Clean up temp files
bash cleanup.sh {download_id}
```

---

## 输出示例 | Output Example

```
~/Downloads/ins/
├── author_20240224_143022_5_1.jpg       # 图片文件
├── author_20240224_143022_5_1.jpg.json  # 元数据文件
├── author_20240224_143022_5_2.jpg
└── ...
```

---

## 技术栈 | Tech Stack

- [gallery-dl](https://github.com/mikf/gallery-dl) - 图片下载引擎
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - 视频下载引擎（备用）
- Python Pillow - EXIF 元数据写入
- Chrome Cookies - 认证

---

## 元数据说明 | Metadata

下载的图片包含以下 EXIF 信息：

| 字段 | 说明 |
|------|------|
| `ImageDescription` | Instagram 原始链接 |
| `UserComment` | 完整 JSON 元数据（作者、点赞数等）|
| `Artist` | 作者用户名 |

The downloaded images contain the following EXIF metadata:
- `ImageDescription`: Original Instagram URL
- `UserComment`: Complete JSON metadata (author, likes, etc.)
- `Artist`: Author username

---

## 作者 | Author

[leaofeng](https://github.com/leaofeng)

---

## 许可证 | License

MIT
