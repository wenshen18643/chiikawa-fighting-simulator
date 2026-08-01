import os
import sys
import re

LUAU_DIRECTIVES = {'--!strict', '--!nocheck', '--!nonstrict', '--!nolint'}

def strip_luau_comments(code: str) -> str:
    i = 0
    n = len(code)
    out = []
    
    while i < n:
        # Check for Luau compiler directives at start of line
        if code[i:i+3] == '--!':
            end_line = code.find('\n', i)
            if end_line == -1:
                end_line = n
            line_content = code[i:end_line].strip()
            first_token = line_content.split()[0] if line_content else ''
            if first_token in LUAU_DIRECTIVES:
                out.append(code[i:end_line])
                i = end_line
                continue
        
        # String single quotes `'`
        if code[i] == "'":
            out.append("'")
            i += 1
            while i < n:
                ch = code[i]
                out.append(ch)
                i += 1
                if ch == '\\' and i < n:
                    out.append(code[i])
                    i += 1
                elif ch == "'":
                    break
            continue

        # String double quotes `"`
        if code[i] == '"':
            out.append('"')
            i += 1
            while i < n:
                ch = code[i]
                out.append(ch)
                i += 1
                if ch == '\\' and i < n:
                    out.append(code[i])
                    i += 1
                elif ch == '"':
                    break
            continue

        # Multiline string `[=[` or `[[`
        if code[i] == '[':
            m = re.match(r'\[(=*)\[', code[i:])
            if m:
                eq_len = len(m.group(1))
                close_delim = ']' + '=' * eq_len + ']'
                full_delim = m.group(0)
                out.append(full_delim)
                i += len(full_delim)
                close_pos = code.find(close_delim, i)
                if close_pos != -1:
                    out.append(code[i:close_pos + len(close_delim)])
                    i = close_pos + len(close_delim)
                else:
                    out.append(code[i:])
                    i = n
                continue
            else:
                out.append(code[i])
                i += 1
                continue

        # Comment `--`
        if code[i:i+2] == '--':
            # Check if block comment `--[=[` or `--[[`
            m = re.match(r'--\[(=*)\[', code[i:])
            if m:
                eq_len = len(m.group(1))
                close_delim = ']' + '=' * eq_len + ']'
                i += len(m.group(0))
                close_pos = code.find(close_delim, i)
                if close_pos != -1:
                    i = close_pos + len(close_delim)
                else:
                    i = n
                continue
            else:
                # Single line comment: skip until newline
                end_line = code.find('\n', i)
                if end_line != -1:
                    i = end_line
                else:
                    i = n
                continue
        
        out.append(code[i])
        i += 1

    result = "".join(out)
    
    # Cleanup trailing whitespace on lines and excess blank lines
    lines = result.split('\n')
    cleaned_lines = []
    for line in lines:
        rline = line.rstrip()
        cleaned_lines.append(rline)
    
    # Remove consecutive empty lines if there are more than 1
    final_lines = []
    empty_count = 0
    for line in cleaned_lines:
        if line == '':
            empty_count += 1
            if empty_count <= 1:
                final_lines.append(line)
        else:
            empty_count = 0
            final_lines.append(line)
            
    return '\n'.join(final_lines).strip() + '\n'

def process_directory(target_dir: str):
    processed = 0
    modified = 0
    for root, _, files in os.walk(target_dir):
        for file in files:
            if file.endswith('.lua') or file.endswith('.luau'):
                file_path = os.path.join(root, file)
                processed += 1
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                
                stripped = strip_luau_comments(content)
                if stripped != content:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(stripped)
                    modified += 1
                    print(f"Stripped comments from: {file_path}")

    print(f"\nDone. Processed {processed} files, modified {modified} files.")

if __name__ == '__main__':
    target = sys.argv[1] if len(sys.argv) > 1 else 'src'
    process_directory(target)
