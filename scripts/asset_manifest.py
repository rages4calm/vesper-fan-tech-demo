"""Record new assets and notices, retaining the existing release provenance."""
import hashlib,json,importlib.metadata as metadata,shutil
from pathlib import Path
import requests
ROOT=Path(__file__).resolve().parents[1]
notices=ROOT/'docs/licenses/living-town';notices.mkdir(parents=True,exist_ok=True)
sources=[
 ('kokoro-model','https://huggingface.co/hexgrad/Kokoro-82M/raw/main/README.md','Apache-2.0','hexgrad / Kokoro contributors','helper/models/kokoro.onnx'),
 ('kokoro-voices','https://huggingface.co/hexgrad/Kokoro-82M/raw/main/VOICES.md','Apache-2.0','hexgrad / Kokoro contributors','helper/models/voices.bin'),
 ('kokoro-onnx','https://raw.githubusercontent.com/thewh1teagle/kokoro-onnx/main/LICENSE','MIT','thewh1teagle','helper/_internal/kokoro_onnx'),
 ('espeak-ng','https://raw.githubusercontent.com/espeak-ng/espeak-ng/master/COPYING','GPL-3.0-or-later','eSpeak NG contributors','helper/runtime phonemization'),
 ('phonemizer','https://raw.githubusercontent.com/bootphon/phonemizer/master/LICENSE','GPL-3.0-or-later','Mathieu Bernard, Hadrien Titeux and contributors','helper/runtime phonemization'),
 ]
manifest=[]
for name,url,license,creator,file in sources:
    response=requests.get(url,timeout=30);response.raise_for_status();(notices/(name+'.txt')).write_text(response.text,encoding='utf-8')
    record={'asset':name,'source':url,'creator':creator,'license':license,'use':file,'attribution':'License notice retained; see docs/licenses/living-town','retrieved':'2026-09-19'}
    path=ROOT/file
    if path.is_file():record['sha256']=hashlib.sha256(path.read_bytes()).hexdigest();record['bytes']=path.stat().st_size
    manifest.append(record)
for package in [line.split('==')[0] for line in (ROOT/'helper/requirements-lock.txt').read_text().splitlines() if '==' in line]:
    dist=metadata.distribution(package)
    target=notices/package;target.mkdir(exist_ok=True)
    (target/'METADATA.txt').write_text(dist.read_text('METADATA') or '',encoding='utf-8')
    for file in dist.files or []:
        if any(part.lower() in ['license','license.txt','license.md','copying','notice','notice.txt','licenses'] for part in file.parts):
            p=Path(dist.locate_file(file))
            if p.is_file():shutil.copy2(p,target/p.name)
    manifest.append({'asset':package,'version':dist.version,'kind':'runtime dependency','license_notice':'docs/licenses/living-town/'+package,'source':'https://pypi.org/project/'+package+'/'+dist.version+'/'})
for name,source,files in [
 ('Quaternius Fantasy Outfits','https://quaternius.com/packs/modularcharacteroutfitsfantasy.html',['citizen-male.glb','citizen-female.glb']),
 ('Quaternius Universal Base Characters','https://quaternius.com/packs/universalbasecharacters.html',['citizen-male.glb','citizen-female.glb']),
 ('Quaternius Universal Animation Library','https://quaternius.com/packs/universalanimationlibrary.html',['citizen-male.glb','citizen-female.glb','harbor/fisherman.glb'])]:
    manifest.append({'asset':name,'creator':'Quaternius','source':source,'license':'CC0-1.0','files':files,'change':'Reuse of the previously adapted Blender models; talking, walking, fishing and interaction clips enabled for living citizens.','attribution':'Credit retained in CREDITS.md; original license notices in docs/licenses.'})
manifest.append({'asset':str(sum(len(lines) for lines in json.loads((ROOT/'godot/data/voice_catalog.json').read_text()).values()))+' generated NPC speech recordings','creator':'Carl Prewitt Jr. project / local Kokoro synthesis','source':'scripts/build_voice_library.py','license':'Project-specific authored dialogue; model license Apache-2.0','files':'godot/assets/voices/*.wav','change':'New synthetic voices; no real-person imitation or commercial game extraction.'})
manifest.append({'asset':'Crier livery, bell, noticeboard, delivery baskets','creator':'Carl Prewitt Jr. project / Codex assisted procedural geometry','source':'godot/scripts/living_town.gd','license':'Project-specific geometry','files':'make_props()','change':'New geometry, no external asset.'})
manifest.append({'asset':'Vesper local helper source','creator':'Carl Prewitt Jr. project / Codex assisted','license':'GPL-3.0-or-later','source':'helper/','notice':'helper/LICENSE','build':'helper/BUILDING.md'})
for archive in (ROOT/'helper/source-archives').glob('*'):
    manifest.append({'asset':archive.name,'kind':'corresponding source archive','path':str(archive.relative_to(ROOT)).replace(chr(92),'/'),'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'license':'See enclosed component license notices'})
manifest.append({'asset':'Python 3.14 runtime','creator':'Python Software Foundation and contributors','license':'PSF and bundled component notices','license_notice':'docs/licenses/living-town/PYTHON-LICENSE.txt','source':'https://www.python.org/'})
(ROOT/'docs/LIVING-ASSET-MANIFEST.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('Recorded',len(manifest),'asset and dependency entries')
