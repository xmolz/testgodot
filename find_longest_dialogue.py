import os
import glob
import re
import json

def strip_bbcode(text):
    # Strip any brackets like [i], [speed=0.5], [color=...], etc.
    return re.sub(r'\[[^\]]+\]', '', text)

def analyze_dialogue_files(dir_path):
    all_lines = []
    
    # Find all .dialogue files
    pattern = os.path.join(dir_path, "**", "*.dialogue")
    files = glob.glob(pattern, recursive=True)
    
    for file_path in files:
        rel_path = os.path.relpath(file_path, dir_path)
        with open(file_path, 'r', encoding='utf-8') as f:
            for line_idx, line in enumerate(f):
                line_num = line_idx + 1
                stripped = line.strip()
                
                # Exclude comments, labels, commands, control flow, jumps, etc.
                if not stripped:
                    continue
                if stripped.startswith('#'):
                    continue
                if stripped.startswith('~'):
                    continue
                if stripped.startswith('do ') or stripped.startswith('do\t'):
                    continue
                if stripped.startswith('set ') or stripped.startswith('set\t'):
                    continue
                if stripped.startswith('if ') or stripped.startswith('if\t') or stripped.startswith('if('):
                    continue
                if stripped.startswith('elif ') or stripped.startswith('elif\t') or stripped.startswith('elif('):
                    continue
                if stripped.startswith('else'):
                    continue
                if stripped.startswith('while ') or stripped.startswith('for '):
                    continue
                if stripped.startswith('=>'):
                    continue
                if stripped.startswith('[='):
                    continue
                if stripped.startswith('import '):
                    continue
                
                # Check for choices
                is_choice = stripped.startswith('-')
                
                # Try to parse Character Prefix vs Dialogue Text
                # Dialogue Manager splits character speech by the first ': ' (colon and space)
                colon_idx = stripped.find(': ')
                
                character = None
                dialogue_text = stripped
                
                # If there's a choice hyphen, we strip it for text analysis if it's a choice dialogue
                if is_choice:
                    choice_stripped = stripped[1:].strip()
                    colon_idx_choice = choice_stripped.find(': ')
                    if colon_idx_choice != -1:
                        prefix = choice_stripped[:colon_idx_choice].strip()
                        if '"' not in prefix and "'" not in prefix and len(prefix) < 50:
                            character = prefix
                            dialogue_text = choice_stripped[colon_idx_choice + 2:].strip()
                    else:
                        dialogue_text = choice_stripped
                else:
                    if colon_idx != -1:
                        prefix = stripped[:colon_idx].strip()
                        # Verify prefix looks like a character name (no quotes, not extremely long)
                        if '"' not in prefix and "'" not in prefix and len(prefix) < 50:
                            character = prefix
                            dialogue_text = stripped[colon_idx + 2:].strip()
                
                clean_dialogue = strip_bbcode(dialogue_text)
                
                all_lines.append({
                    'file': rel_path,
                    'full_path': file_path,
                    'line_num': line_num,
                    'is_choice': is_choice,
                    'has_prefix': character is not None,
                    'character': character,
                    'raw_line': stripped,
                    'dialogue_text': dialogue_text,
                    'clean_dialogue': clean_dialogue,
                    'len_raw_line': len(stripped),
                    'len_raw_dialogue': len(dialogue_text),
                    'len_clean_dialogue': len(clean_dialogue)
                })
                
    return all_lines

def print_top_lines(lines, key, title, limit=10):
    sorted_lines = sorted(lines, key=lambda x: x[key], reverse=True)
    print(f"\n--- {title} (Sorted by {key}) ---")
    for i, item in enumerate(sorted_lines[:limit]):
        print(f"{i+1}. Length: {item[key]} | File: {item['file']}:{item['line_num']}")
        print(f"   Character: {item['character']}")
        print(f"   Raw Line: {item['raw_line']}")
        print(f"   Clean Text: {item['clean_dialogue']}")
        print("-" * 50)

if __name__ == "__main__":
    dir_path = r"C:\Godot\If I Remember Correctly\testgodot\dialogue"
    all_items = analyze_dialogue_files(dir_path)
    
    # Exclude choice lines from main dialogue pools unless specifically needed
    dialogue_only = [x for x in all_items if not x['is_choice']]
    prefixed_only = [x for x in dialogue_only if x['has_prefix']]
    
    print(f"Total dialogue/narration lines found: {len(dialogue_only)}")
    print(f"Total prefixed character lines found: {len(prefixed_only)}")
    
    # 1. Longest prefixed character dialogue by Clean Text Length
    print_top_lines(prefixed_only, 'len_clean_dialogue', "Prefixed Character Lines - Clean Text Length")
    
    # 2. Longest prefixed character dialogue by Raw Line Length
    print_top_lines(prefixed_only, 'len_raw_line', "Prefixed Character Lines - Raw Line Length")
    
    # 3. Longest overall dialogue/narration by Clean Text Length
    print_top_lines(dialogue_only, 'len_clean_dialogue', "All Dialogue Lines - Clean Text Length")
    
    # 4. Longest overall dialogue/narration by Raw Line Length
    print_top_lines(dialogue_only, 'len_raw_line', "All Dialogue Lines - Raw Line Length")
    
    # Save the data to a JSON file for any further inspection
    with open("longest_dialogue_results.json", "w", encoding="utf-8") as f:
        json.dump(all_items, f, indent=2, ensure_ascii=False)
