import os
import glob

def check_lfs_pointers_and_pngs():
    extensions = ['*.png', '*.jpg', '*.webp', '*.ogg', '*.wav', '*.mp3', '*.ttf', '*.otf', '*.ico', '*.icns']
    lfs_pointers = []
    broken_pngs = []
    
    for ext in extensions:
        # Note: glob with recursive=True requires **/*.ext, but we can just use os.walk
        pass
        
    for root, dirs, files in os.walk('.'):
        if '.git' in dirs:
            dirs.remove('.git')
        if '.godot' in dirs:
            dirs.remove('.godot')
            
        for file in files:
            ext = os.path.splitext(file)[1].lower()
            if ext in ['.png', '.jpg', '.webp', '.ogg', '.wav', '.mp3', '.ttf', '.otf', '.ico', '.icns']:
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'rb') as f:
                        header = f.read(100)
                        if b'version https://git-lfs.github.com/spec/v1' in header:
                            lfs_pointers.append(filepath)
                        elif ext == '.png':
                            if not header.startswith(b'\x89PNG'):
                                broken_pngs.append(filepath)
                except Exception as e:
                    print(f"Error reading {filepath}: {e}")
                    
    print(f"LFS pointers found: {len(lfs_pointers)}")
    for p in lfs_pointers[:10]:
        print(f"  {p}")
    if len(lfs_pointers) > 10:
        print("  ...")
        
    print(f"\nBroken PNGs found (not LFS pointers but bad header): {len(broken_pngs)}")
    for p in broken_pngs[:10]:
        print(f"  {p}")
    if len(broken_pngs) > 10:
        print("  ...")
        
    # Check .gitattributes
    gitattributes_has_lfs = False
    try:
        with open('.gitattributes', 'r') as f:
            if 'filter=lfs' in f.read():
                gitattributes_has_lfs = True
    except:
        pass
    print(f"\n.gitattributes contains filter=lfs: {gitattributes_has_lfs}")

if __name__ == '__main__':
    check_lfs_pointers_and_pngs()
