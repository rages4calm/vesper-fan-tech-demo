"""Loopback-only bounded decisions and asynchronous local voice jobs."""
import argparse,concurrent.futures,datetime,hashlib,json,os,secrets,sys,threading,time,winreg
from pathlib import Path
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
import requests
from speech_engine import SpeechEngine

ROOT=Path(sys.executable).parent if getattr(sys,'frozen',False) else Path(__file__).parent
CONFIG=json.loads((ROOT/'config.json').read_text())
DATA=Path(os.environ.get('VESPER_HELPER_DATA',str(Path(os.environ['LOCALAPPDATA'])/'VesperLivingTown')))
DATA.mkdir(parents=True,exist_ok=True)
# One owner of this user's budget ledger. Windows releases the mutex on exit,
# including crashes; a second launcher can still play with cached voices/rules.
if __name__=='__main__':
    import ctypes
    kernel=ctypes.WinDLL('kernel32',use_last_error=True)
    kernel.CreateMutexW.argtypes=[ctypes.c_void_p,ctypes.c_bool,ctypes.c_wchar_p]
    kernel.CreateMutexW.restype=ctypes.c_void_p
    ledger_mutex=kernel.CreateMutexW(None,False,'Local\\VesperTownBudget_'+hashlib.sha256(str(DATA.resolve()).encode()).hexdigest()[:24])
    if not ledger_mutex or ctypes.get_last_error()==183:
        raise SystemExit('Another Vesper helper already owns this budget ledger. Close that game to enable live decisions here.')
CACHE=DATA/'voice-cache';CACHE.mkdir(exist_ok=True)
TOKEN=secrets.token_urlsafe(32)
KEY=os.environ.get('TYPESAFE_API_KEY','')
if not KEY:
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER,'Environment') as r:KEY=winreg.QueryValueEx(r,'TYPESAFE_API_KEY')[0]
    except OSError:pass
lock=threading.Lock();jobs={};engine=None;last_request=0.;backoff_until=0.;failures=0
voice_pool=concurrent.futures.ThreadPoolExecutor(max_workers=1)
day=datetime.date.today().isoformat()
ledger_path=DATA/'usage.json'
try:ledger=json.loads(ledger_path.read_text())
except (OSError,ValueError):ledger={}
if ledger.get('day')!=day:ledger={'day':day,'requests':0,'input_tokens':0,'output_tokens':0,'estimated_usd':0.,'reserved_usd':0.}
latencies=[];last_error='';voice_metrics=[]

def log(kind,**values):
    with (DATA/'telemetry.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps({'time':time.time(),'kind':kind,**values})+'\n')

def persist():
    tmp=ledger_path.with_suffix('.tmp');tmp.write_text(json.dumps(ledger));os.replace(tmp,ledger_path)

def decide(data):
    global last_request,backoff_until,failures,last_error
    state=data.get('state',{});options=data.get('options',{})
    if not isinstance(options,dict) or not 2<=len(options)<=12:raise ValueError('Supply 2 to 12 valid actions')
    if len(json.dumps(data))>10000:raise ValueError('Decision state too large')
    fallback=data.get('fallback',next(iter(options)))
    if fallback not in options:fallback=next(iter(options))
    result={'choice':fallback,'mode':'rules fallback','reason':'AI unavailable'}
    question={'type':'choice','instructions':data.get('instructions','Choose the best currently valid action for this person, considering their personality, needs, commitments and observed facts. Do not invent information.'),'criteria':options}
    body={'model':CONFIG['model'],'state':state,'questions':{'next':question}}
    # Conservative per-request reservation. Request cap remains a second hard bound.
    reserve=(len(json.dumps(body).encode('utf-8'))*4+4096)*CONFIG['input_price_per_million_usd']/1e6
    with lock:
        if not KEY or not CONFIG['ai_enabled']:result['reason']='No key or AI disabled';return result
        if ledger['requests']>=CONFIG['daily_request_limit'] or ledger['reserved_usd']+reserve>CONFIG['daily_spend_limit_usd']:result['reason']='Daily request or spending limit reached';return result
        now=time.monotonic()
        if now<backoff_until or now-last_request<CONFIG['minimum_request_interval_seconds']:result['reason']='Cooldown';return result
        last_request=now;ledger['requests']+=1;ledger['reserved_usd']+=reserve;persist()
    start=time.perf_counter()
    try:
        response=requests.post('https://api.typesafe.ai/v1/systemone',json=body,headers={'Authorization':'Bearer '+KEY},timeout=CONFIG['network_timeout_seconds'])
        if not response.ok:raise RuntimeError('TypeSafe HTTP '+str(response.status_code))
        value=response.json();answer=value['answers']['next'];choice=answer['choice']
        if choice not in options:raise ValueError('Invalid action returned')
        usage=value['usage'];latency=round((time.perf_counter()-start)*1000)
        with lock:
            ledger['input_tokens']+=int(usage['input_tokens']);ledger['output_tokens']+=int(usage.get('output_tokens',0))
            actual=int(usage['input_tokens'])*CONFIG['input_price_per_million_usd']/1e6
            ledger['estimated_usd']+=actual
            ledger['reserved_usd']=max(ledger['estimated_usd'],ledger['reserved_usd']-reserve+actual)
            latencies.append(latency);latencies[:]=latencies[-100:];persist();failures=0;last_error=''
        log('decision',latency_ms=latency,usage=usage,choice=choice,model=value['model'],confidence=answer.get('confidence'),actor=state.get('name','player') if isinstance(state,dict) else 'unknown')
        return {'choice':choice,'mode':'live Jev','model':value['model'],'confidence':answer.get('confidence',0),'latency_ms':latency,'usage':usage}
    except Exception as e:
        with lock:
            failures+=1;last_error=type(e).__name__ if isinstance(e,requests.RequestException) else str(e)[:100]
            backoff_until=time.monotonic()+min(120,15*2**min(failures,3))
        result['reason']=last_error;log('decision_failure',reason=last_error);return result

def synth(job_id,text,voice):
    global engine
    try:
        path=CACHE/(job_id+'.wav')
        if path.exists():stats={'cached':True,'generation_seconds':0}
        else:
            if engine is None:engine=SpeechEngine(ROOT/'models')
            stats=engine.render(text,voice,path);stats['cached']=False
        with lock:jobs[job_id]={'ready':True,'id':job_id,**stats};voice_metrics.append(stats);voice_metrics[:]=voice_metrics[-50:]
        log('speech',voice=voice,characters=len(text),**stats)
        total=sum(p.stat().st_size for p in CACHE.glob('*.wav'))
        for old in sorted(CACHE.glob('*.wav'),key=lambda p:p.stat().st_mtime):
            if total<CONFIG['voice_cache_limit_mb']*1024*1024:break
            if old!=path:total-=old.stat().st_size;old.unlink(missing_ok=True)
    except Exception as e:
        with lock:jobs[job_id]={'ready':False,'error':type(e).__name__}
        log('speech_failure',error=type(e).__name__)

class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args):pass
    def send(self,value,status=200,kind='application/json'):
        data=json.dumps(value).encode() if kind=='application/json' else value
        self.send_response(status);self.send_header('Content-Type',kind);self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
    def allowed(self):
        if self.headers.get('Origin') or not secrets.compare_digest(self.headers.get('X-Vesper-Token',''),TOKEN):self.send({'error':'Unauthorized'},403);return False
        return True
    def do_GET(self):
        if not self.allowed():return
        if self.path=='/status':
            with lock:state={'ai':'available' if KEY and CONFIG['ai_enabled'] else 'offline','usage':dict(ledger),'latencies_ms':latencies[-20:],'failures':failures,'last_error':last_error,'request_limit':CONFIG['daily_request_limit'],'spend_limit_usd':CONFIG['daily_spend_limit_usd'],'voice':'local Kokoro','voice_jobs':len(jobs),'voice_metrics':voice_metrics[-10:]}
            self.send(state)
        elif self.path.startswith('/voice/'):
            name=self.path.split('/')[-1];wav=name.endswith('.wav');job_id=name.removesuffix('.wav')
            if len(job_id)!=64 or any(c not in '0123456789abcdef' for c in job_id):self.send({'error':'Invalid id'},400);return
            if wav:
                file=CACHE/(job_id+'.wav')
                if file.exists():self.send(file.read_bytes(),kind='audio/wav')
                else:self.send({'error':'Not ready'},404)
            else:
                with lock:job=dict(jobs.get(job_id,{'ready':False}))
                self.send(job)
        else:self.send({'error':'Unknown operation'},404)
    def do_POST(self):
        if not self.allowed():return
        try:
            length=int(self.headers.get('Content-Length','0'))
            if not 0<length<=16384:raise ValueError('Invalid request size')
            data=json.loads(self.rfile.read(length))
            if self.path=='/decision':self.send(decide(data))
            elif self.path=='/voice':
                text=str(data.get('text','')).strip();voice=str(data.get('voice','bm_george'))
                if not 1<=len(text)<=400 or voice not in ['bm_george','bm_daniel','am_michael','bf_emma','bf_isabella','bm_fable','af_heart']:raise ValueError('Invalid voice request')
                job_id=hashlib.sha256((voice+'|'+text).encode()).hexdigest()
                with lock:
                    if len(jobs)>200:jobs.clear()
                    if job_id not in jobs:
                        jobs[job_id]={'ready':False,'id':job_id};voice_pool.submit(synth,job_id,text,voice)
                self.send({'id':job_id})
            elif self.path=='/shutdown':
                self.send({'ok':True});threading.Thread(target=self.server.shutdown,daemon=True).start()
            else:self.send({'error':'Unknown operation'},404)
        except (ValueError,KeyError,TypeError):self.send({'error':'Invalid request'},400)
        except Exception: self.send({'error':'Operation failed'},500)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--connection',required=True);args=parser.parse_args()
    server=ThreadingHTTPServer(('127.0.0.1',0),Handler);server.daemon_threads=True
    connection=Path(args.connection);connection.parent.mkdir(parents=True,exist_ok=True)
    connection.write_text(json.dumps({'url':'http://127.0.0.1:'+str(server.server_port),'token':TOKEN}))
    try:server.serve_forever(poll_interval=.2)
    finally:server.server_close();connection.unlink(missing_ok=True);voice_pool.shutdown(wait=True,cancel_futures=True)
