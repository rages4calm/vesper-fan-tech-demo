"""Reassemble tested release files on GitHub; verify every byte against local manifests.

This transports existing binaries, not a rebuild. Players receive ordinary ZIPs.
Only called by the manually dispatched, hash-pinned release-assembly workflow.
"""
from pathlib import Path
import hashlib,json,os,subprocess,urllib.request,zipfile

ROOT=Path('assembly').resolve()
ROOT.mkdir(exist_ok=True)
OUT=ROOT/'out';OUT.mkdir(exist_ok=True)
TRANSPORT=ROOT/'Vesper-v0.6.1-Assembly.zip'
def digest(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def extract_member(z,name,dest):
    target=(dest/name).resolve()
    if not target.is_relative_to(dest.resolve()):raise ValueError('Unsafe archive path')
    target.parent.mkdir(parents=True,exist_ok=True)
    with z.open(name) as source,target.open('wb') as output:
        import shutil
        shutil.copyfileobj(source,output)
def verify(path,row):
    assert path.stat().st_size==row['bytes'] and digest(path)==row['sha256'],row['path']
assert digest(TRANSPORT)==os.environ['TRANSPORT_SHA256']
with zipfile.ZipFile(TRANSPORT) as z:
    raw=z.read('manifest.json');manifest=json.loads(raw)
    for name in z.namelist():extract_member(z,name,ROOT/'payload')
for name,sha in manifest['base'].items():assert digest(ROOT/name)==sha,name

old_windows=zipfile.ZipFile(ROOT/'Vesper-Fan-Tech-Demo-v0.3.2-Windows-x64.zip')
old_source=zipfile.ZipFile(ROOT/'Vesper-v0.3.2-Source-Assets.zip')
windows=ROOT/'windows';source=ROOT/'source'
for row in manifest['windows']:
    p=windows/row['path'];p.parent.mkdir(parents=True,exist_ok=True)
    if 'patch' in row:
        entry='Vesper-Fan-Tech-Demo/'+row['path']
        extract_member(old_windows,entry,ROOT/'base')
        subprocess.run([os.environ['XDELTA'],'-d','-s',str(ROOT/'base'/entry),str(ROOT/'payload'/row['patch']),str(p)],check=True)
    elif 'url' in row:
        urllib.request.urlretrieve(row['url'],p)
    else:
        import shutil
        shutil.copy2(ROOT/'payload/windows'/row['path'],p)
    verify(p,row)
for row in manifest['source']:
    p=source/row['path'];p.parent.mkdir(parents=True,exist_ok=True)
    changed=ROOT/'payload/source'/row['path']
    if changed.exists():
        import shutil
        shutil.copy2(changed,p)
    else:extract_member(old_source,row['path'],source)
    verify(p,row)

outputs=[]
for folder,rows,name,prefix in [
    (windows,manifest['windows'],'Vesper-Fan-Tech-Demo-v0.6.1-Windows-x64.zip','Vesper-Fan-Tech-Demo/'),
    (source,manifest['source'],'Vesper-v0.6.1-Source-Assets.zip','')]:
    target=OUT/name
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=5) as z:
        for row in rows:z.write(folder/row['path'],prefix+row['path'])
    with zipfile.ZipFile(target) as z:
        assert z.testzip() is None
        for row in rows:
            with z.open(prefix+row['path']) as f:assert hashlib.file_digest(f,'sha256').hexdigest()==row['sha256']
    outputs.append({'name':name,'bytes':target.stat().st_size,'sha256':digest(target)})
report={'transport_sha256':digest(TRANSPORT),'manifest_sha256':hashlib.sha256(raw).hexdigest(),
        'windows_files_verified':len(manifest['windows']),'source_files_verified':len(manifest['source']),
        'all_uncompressed_files_match_tested_local_build':True,'outputs':outputs}
(OUT/'ASSEMBLY-VERIFICATION.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
