"""Create the matching source asset release attachment (Python standard library)."""
from pathlib import Path
import hashlib
import json
from zipfile import ZipFile, ZIP_DEFLATED

ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'build/release'
DEST.mkdir(parents=True,exist_ok=True)
FILES=sorted((ROOT/'godot/assets').rglob('*'))
manifest=[]
path=DEST/'Vesper-v0.3.2-Source-Assets.zip'
with ZipFile(path,'w',compression=ZIP_DEFLATED,compresslevel=5) as archive:
    for file in FILES:
        if not file.is_file():continue
        if file.name.startswith('uo-') or 'vesper-original' in file.name or file.suffix.lower() in ['.uop','.mul','.pdf']:
            raise ValueError(f'Unexpected restricted source in release asset directory: {file.name}')
        relative=file.relative_to(ROOT).as_posix()
        manifest.append(dict(path=relative,bytes=file.stat().st_size,sha256=hashlib.sha256(file.read_bytes()).hexdigest()))
        archive.write(file,relative)
with ZipFile(path) as archive:
    assert archive.testzip() is None
(ROOT/'docs/SOURCE-ASSETS.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(file=path.name,bytes=path.stat().st_size,files=len(manifest),sha256=hashlib.sha256(path.read_bytes()).hexdigest())),flush=True)
