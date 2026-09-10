"""Original synthesized foley for the public demo; contains no UO recordings.

Requires NumPy. All waveforms below are generated from oscillators/noise.
"""
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / 'godot/assets/audio'
ROOT.mkdir(parents=True, exist_ok=True)
SR = 22050
RNG = np.random.default_rng(3082)

def noise(count, smoothing=5):
    return np.convolve(RNG.normal(0, 1, count), np.ones(smoothing)/smoothing, mode='same')

def write(name, data):
    data = np.asarray(data)
    fade = np.minimum(np.arange(len(data))/100, (len(data)-np.arange(len(data))-1)/300)
    data *= np.clip(fade, 0, 1)
    data = np.clip(data, -.85, .85)
    with wave.open(str(ROOT / ('demo-'+name+'.wav')), 'wb') as output:
        output.setnchannels(1); output.setsampwidth(2); output.setframerate(SR)
        output.writeframes((data*32767).astype('<i2').tobytes())

def thunk(t, at, pitch, gain):
    age=np.maximum(0,t-at)
    return (t>=at)*gain*np.exp(-age*30)*(np.sin(2*np.pi*pitch*age)+.4*np.sin(2*np.pi*pitch*1.7*age))

t=np.arange(int(SR*1.4))/SR
creak=(np.sin(2*np.pi*(175*t+7*np.sin(t*17)))+.4*np.sin(2*np.pi*345*t))
creak*=np.maximum(0,np.sin(np.pi*t/1.4))**2*.085
write('door-open',creak+noise(len(t),18)*np.exp(-t*2)*.13+thunk(t,.04,110,.20))
write('door-close',creak[::-1]*.5+thunk(t,.24,74,.35)+thunk(t,.3,146,.12))
write('chest',creak*.8+thunk(t,.05,95,.25)+thunk(t,1.0,160,.1))
write('pack',noise(len(t),12)*np.exp(-t*5)*.35+thunk(t,.08,120,.1))
write('page',noise(len(t),3)*np.maximum(0,np.sin(np.minimum(t/.6,1)*np.pi))**2*.15)
coins=np.zeros(len(t))
for at,pitch in [(0.04,1700),(.15,2350),(.27,1950)]:
    age=np.maximum(0,t-at)
    coins+=(t>=at)*np.exp(-age*14)*(.14*np.sin(2*np.pi*pitch*age)+.06*np.sin(2*np.pi*pitch*1.47*age))
write('coins',coins)
eat=np.zeros(len(t))
for at in [.05,.29,.52]:
    age=np.maximum(0,t-at)
    eat+=(t>=at)*noise(len(t),3)*np.exp(-age*28)*.25
write('eat',eat)
write('hammer',thunk(t,.03,95,.4)+thunk(t,.05,280,.1))
write('bird',.1*np.sin(2*np.pi*(1400*t+18*np.sin(13*t)))*np.maximum(0,np.sin(np.pi*t/1.4))**4)
splash=noise(len(t),9)*np.exp(-t*3)*.38
for at in [.15,.32,.43,.61]:
    age=np.maximum(0,t-at)
    splash+=(t>=at)*.065*np.sin(2*np.pi*(440*age+180*age**2))*np.exp(-age*19)
write('splash',splash)
print('Created ten original public-demo effects.')
