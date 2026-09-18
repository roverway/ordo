import base64
import os
import re
import io
from PIL import Image

src_html_path = "/mnt/Data/Personal/04_others/My_Development/todo/promo/index.html"
dst_html_path = "/mnt/Data/Personal/04_others/My_Development/todo/promo/index.standalone.html"
base_dir = "/mnt/Data/Personal/04_others/My_Development/todo/promo"

with open(src_html_path, "r", encoding="utf-8") as f:
    content = f.read()

# Collect all referenced assets
img_pattern = re.compile(r'["\']((?:dist|shots|assets)/[^"\']+\.(?:png|jpg|jpeg|webp))["\']')
found_paths = sorted(set(img_pattern.findall(content)))
print(f"Unique images to inline: {len(found_paths)}")

assets_dict = {}
total_raw = 0
total_b64 = 0

for rel_p in found_paths:
    abs_p = os.path.join(base_dir, rel_p)
    if not os.path.exists(abs_p):
        print(f"Warning: {abs_p} not found!")
        continue
    
    with Image.open(abs_p) as img:
        buffer = io.BytesIO()
        if 'app_logo' in rel_p:
            img.save(buffer, format="WEBP", lossless=True)
        else:
            # 100% full original resolution, WebP q=88 (PSNR > 47.5 dB)
            img.save(buffer, format="WEBP", quality=88, method=6)
        raw_bytes = buffer.getvalue()
        b64_str = base64.b64encode(raw_bytes).decode("ascii")
        data_uri = f"data:image/webp;base64,{b64_str}"
        assets_dict[rel_p] = data_uri
        total_raw += len(raw_bytes)
        total_b64 += len(b64_str)

print(f"Total raw binary: {total_raw/1024:.1f} KB")
print(f"Total unique Base64: {total_b64/1024:.1f} KB ({total_b64/(1024*1024):.2f} MB)")

# Inject ASSETS dictionary into head
assets_js_entries = [f'  "{k}": "{v}"' for k, v in assets_dict.items()]
assets_js_block = "<script>\nconst EMBEDDED_ASSETS = {\n" + ",\n".join(assets_js_entries) + "\n};\n</script>\n"

# Replace favicon
content = re.sub(
    r'<link rel="icon" type="image/png" href="[^"]+">',
    f'<link rel="icon" type="image/webp" href="{assets_dict["assets/app_logo.png"]}">',
    content
)

# Convert all static <img> src="..." to data-asset="..." and src=""
def img_tag_replace(match):
    full_tag = match.group(0)
    src_m = re.search(r'src=["\']((?:dist|shots|assets)/[^"\']+)["\']', full_tag)
    if src_m:
        asset_key = src_m.group(1)
        if asset_key in assets_dict:
            # use logo directly if logo, otherwise empty placeholder with data-asset
            placeholder = assets_dict["assets/app_logo.png"] if "logo" in asset_key else ""
            new_tag = full_tag.replace(src_m.group(0), f'src="{placeholder}" data-asset="{asset_key}"')
            return new_tag
    return full_tag

content = re.sub(r'<img\s+[^>]+>', img_tag_replace, content)

# Insert EMBEDDED_ASSETS before </head>
content = content.replace("</head>", assets_js_block + "</head>")

# Add DOM hydration for data-asset images
hydration_script = """
<script>
  // Hydrate embedded assets to all images
  document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('img[data-asset]').forEach(img => {
      const key = img.getAttribute('data-asset');
      if (EMBEDDED_ASSETS[key]) {
        img.src = EMBEDDED_ASSETS[key];
      }
    });
  });
</script>
"""
content = content.replace("</body>", hydration_script + "</body>")

with open(dst_html_path, "w", encoding="utf-8") as f:
    f.write(content)

sz_kb = os.path.getsize(dst_html_path) / 1024
sz_mb = sz_kb / 1024
print(f"\n==========================================")
print(f"SUCCESS: Generated {dst_html_path}")
print(f"Total Standalone Size: {sz_kb:.1f} KB ({sz_mb:.2f} MB)")
print(f"==========================================")
