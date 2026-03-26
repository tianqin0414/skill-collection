---
name: electronic-seal
description: Generate Chinese company electronic seals (电子公章) and stamp them onto Word documents. Use when the user asks to create a company seal, stamp/盖章 a document, add an electronic seal to a contract or authorization letter, or any task involving 公章/电子章/盖章.
---

# Electronic Seal (电子公章)

Generate Chinese company electronic seals and stamp them onto `.docx` documents.

## Dependencies

Scripts require `Pillow` and `python-docx`. If not installed, create a venv:

```bash
python3 -m venv /tmp/seal_venv
/tmp/seal_venv/bin/pip install Pillow python-docx
```

Then run scripts with `/tmp/seal_venv/bin/python3`.

## Workflow

### 1. Generate a seal

```bash
python3 scripts/generate_seal.py "公司名称" -o /path/to/seal.png
```

Options:
- `-s SIZE` — pixel size (default 400)
- `--star-text TEXT` — text below star, e.g. "合同专用章"
- `--color HEX` — color (default #C81E1E)

### 2. Stamp a document

```bash
python3 scripts/stamp_docx.py input.docx /path/to/seal.png -o output.docx -m "授权人（盖章）" "被授权人（盖章）"
```

Options:
- `-m MARKERS` — paragraph text markers where seal is inserted
- `-w WIDTH` — seal width in inches (default 1.5)
- `-o OUTPUT` — output path (default: `input_stamped.docx`)

### 3. Combined example

```bash
# Generate seal
python3 scripts/generate_seal.py "上海则落科技有限公司" -o /tmp/seal.png

# Stamp onto authorization letter
python3 scripts/stamp_docx.py 授权函.docx /tmp/seal.png -o 授权函_已盖章.docx \
  -m "授权人（盖章）" "被授权人（盖章）"
```

## Programmatic use

Both scripts expose importable functions:

```python
from generate_seal import generate_seal
from stamp_docx import stamp_document

generate_seal("公司名", "/tmp/seal.png", size=400, star_text="", color_hex="#C81E1E")
stamp_document("input.docx", "/tmp/seal.png", "output.docx", markers=["盖章"], width=1.5)
```

## Notes

- Seal is PNG with transparent background, suitable for overlaying
- Font auto-detected from system (macOS/Linux/Windows)
- For documents with text replacement needed, do replacements first, then stamp
