"""Local Kokoro speech. No network or credentials are involved in synthesis."""
import os,time,wave
from pathlib import Path
os.environ.setdefault('OMP_NUM_THREADS','4')
import numpy as np
import onnxruntime as ort
from kokoro_onnx import Kokoro

class TypedSession:
    # kokoro-onnx 0.4.7 supplies an integer speed to newer float-speed exports.
    # Match the actual ONNX input schema instead of modifying the installed package.
    def __init__(self,session):self.session=session
    def get_inputs(self):return self.session.get_inputs()
    def run(self,outputs,inputs):
        inputs=dict(inputs)
        for item in self.get_inputs():
            dtype={'tensor(float)':np.float32,'tensor(int64)':np.int64,'tensor(int32)':np.int32}.get(item.type)
            if dtype:inputs[item.name]=np.asarray(inputs[item.name],dtype=dtype)
        return self.session.run(outputs,inputs)

class SpeechEngine:
    def __init__(self,model_dir):
        options=ort.SessionOptions();options.intra_op_num_threads=4;options.inter_op_num_threads=1
        session=ort.InferenceSession(str(Path(model_dir)/'kokoro.onnx'),sess_options=options,providers=['CPUExecutionProvider'])
        self.k=Kokoro.from_session(session,str(Path(model_dir)/'voices.bin'))
        self.k.sess=TypedSession(session)
    def render(self,text,voice,path):
        start=time.perf_counter()
        audio,sr=self.k.create(text,voice=voice,speed=1.0,lang='en-gb' if voice.startswith('b') else 'en-us')
        # Fixed gain, peak protection and a short fade avoid clicks without crushing dynamics.
        audio=np.asarray(audio,dtype=np.float32)
        peak=float(np.max(np.abs(audio))) if len(audio) else 0
        if peak>0:audio*=min(1.5,.82/peak)
        fade=min(240,len(audio)//2)
        if fade:audio[:fade]*=np.linspace(0,1,fade);audio[-fade:]*=np.linspace(1,0,fade)
        Path(path).parent.mkdir(parents=True,exist_ok=True)
        with wave.open(str(path),'wb') as output:
            output.setnchannels(1);output.setsampwidth(2);output.setframerate(sr)
            output.writeframes((np.clip(audio,-1,1)*32767).astype('<i2').tobytes())
        return {'generation_seconds':round(time.perf_counter()-start,3),'duration':round(len(audio)/sr,3),'peak':round(float(np.max(np.abs(audio))),3)}
