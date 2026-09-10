"""Package the already tested Windows binary and its public documentation."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
import shutil

ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'build/Vesper'
OUT=ROOT/'build/release'
OUT.mkdir(parents=True,exist_ok=True)
for name in ['README.md','CREDITS.md','LICENSE.md']:
    shutil.copy2(ROOT/name,BUILD/name)
shutil.copytree(ROOT/'docs',BUILD/'docs',dirs_exist_ok=True)
files=sorted(path for path in BUILD.rglob('*') if path.is_file())
lines=[]
for path in files:
    lines.append(hashlib.sha256(path.read_bytes()).hexdigest()+'  '+path.relative_to(BUILD).as_posix())
(BUILD/'SHA256SUMS.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8')
archive_path=OUT/'Vesper-Fan-Tech-Demo-v0.3.2-Windows-x64.zip'
with ZipFile(archive_path,'w',compression=ZIP_DEFLATED,compresslevel=5) as archive:
    for file in sorted(BUILD.rglob('*')):
        if file.is_file():archive.write(file,'Vesper-Fan-Tech-Demo/'+file.relative_to(BUILD).as_posix())
with ZipFile(archive_path) as archive:
    assert archive.testzip() is None
checks=[]
for file in sorted(OUT.glob('*.zip')):
    checks.append(hashlib.sha256(file.read_bytes()).hexdigest()+'  '+file.name)
(OUT/'SHA256SUMS.txt').write_text('\n'.join(checks)+'\n',encoding='utf-8')
print(f'Packaged {archive_path.name}: {archive_path.stat().st_size} bytes',flush=True)
