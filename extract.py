#!/usr/bin/env python3
"""
Instagram 原图提取器
从 Instagram 帖子页面提取高清原图 URL
"""
import re
import sys
import json
import gzip
import urllib.request
import ssl

def extract_instagram_images(url):
    """从 Instagram 帖子 URL 提取原图链接"""
    
    # 创建带代理的 opener
    proxy_handler = urllib.request.ProxyHandler({
        'http': 'http://127.0.0.1:7890',
        'https': 'http://127.0.0.1:7890'
    })
    
    # 禁用 SSL 验证（用于测试）
    ssl_context = ssl.create_default_context()
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE
    
    opener = urllib.request.build_opener(proxy_handler)
    urllib.request.install_opener(opener)
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Connection': 'keep-alive',
    }
    
    req = urllib.request.Request(url, headers=headers)
    
    try:
        with urllib.request.urlopen(req, context=ssl_context, timeout=30) as response:
            data = response.read()
            # 检查是否是 gzip 压缩
            if response.info().get('Content-Encoding') == 'gzip':
                html = gzip.decompress(data).decode('utf-8', errors='ignore')
            else:
                html = data.decode('utf-8', errors='ignore')
            # 保存 HTML 用于调试
            with open('/tmp/instagram_debug.html', 'w', encoding='utf-8') as f:
                f.write(html[:50000])  # 只保存前 50KB
            print(f"页面大小: {len(html)} 字符")
            print(f"前 500 字符: {html[:500]}")
    except Exception as e:
        print(f"请求失败: {e}")
        return []
    
    # 方法1: 提取 _sharedData JSON
    images = []
    
    shared_data_match = re.search(r'window\._sharedData\s*=\s*({.+?});</script>', html)
    if shared_data_match:
        try:
            data = json.loads(shared_data_match.group(1))
            media = data.get('entry_data', {}).get('PostPage', [{}])[0].get('graphql', {}).get('shortcode_media', {})
            
            if media.get('__typename') == 'GraphSidecar':
                # 多图帖子
                edges = media.get('edge_sidecar_to_children', {}).get('edges', [])
                for edge in edges:
                    node = edge.get('node', {})
                    if node.get('__typename') == 'GraphImage':
                        img_url = node.get('display_url')
                        if img_url:
                            images.append(img_url)
                    elif node.get('__typename') == 'GraphVideo':
                        video_url = node.get('video_url')
                        if video_url:
                            images.append(video_url)
            else:
                # 单图或视频
                if media.get('__typename') == 'GraphImage':
                    img_url = media.get('display_url')
                    if img_url:
                        images.append(img_url)
                elif media.get('__typename') == 'GraphVideo':
                    video_url = media.get('video_url')
                    if video_url:
                        images.append(video_url)
        except json.JSONDecodeError as e:
            print(f"JSON 解析失败: {e}")
    
    # 方法2: 提取所有 scontent CDN 链接作为后备
    if not images:
        cdn_urls = re.findall(r'https://scontent[^\s"<>]+', html)
        # 过滤出图片 URL（通常包含 .jpg 或 _n.jpg）
        for url in cdn_urls:
            if '.jpg' in url or '.webp' in url:
                # 清理 URL 参数
                clean_url = url.split('\\')[0].split('"')[0].split(',')[0]
                if clean_url not in images:
                    images.append(clean_url)
    
    return images

if __name__ == '__main__':
    url = sys.argv[1] if len(sys.argv) > 1 else "https://www.instagram.com/p/DU-lFVWjNGB/"
    
    print(f"正在提取: {url}")
    print("-" * 50)
    
    images = extract_instagram_images(url)
    
    if images:
        print(f"\n找到 {len(images)} 个媒体文件:\n")
        for i, img_url in enumerate(images, 1):
            print(f"{i}. {img_url}")
    else:
        print("\n未找到媒体文件")
        sys.exit(1)
