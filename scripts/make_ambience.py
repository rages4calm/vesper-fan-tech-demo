"""Generate original environmental foley; this does not synthesize the UO music."""
from pathlib import Path
import wave, numpy as np
root=Path(__file__).resolve().parents[1]/'godot/assets/audio'
rng=np.random.default_rng(137)
def write(name,data,sr=22050):
    data=np.clip(data,-1,1)
    with wave.open(str(root/name),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes((data*32767).astype('<i2').tobytes())
sr=22050
t=np.arange(sr*48)/sr
noise=rng.normal(0,1,len(t))
water=np.convolve(noise,np.ones(24)/24,mode='same')
water*=.27+.12*np.sin(t*.61)+.06*np.sin(t*1.3)
water+=np.sin(t*2*np.pi*98+np.sin(t*.5))*.008
# Periodic endpoints avoid a click when looping the recording.
fade=np.minimum(np.minimum(t/.8,(48-t)/.8),1)
write('canal-air.wav',water*fade)
for i in range(4):
    t=np.arange(int(sr*.16))/sr
    n=rng.normal(0,1,len(t))
    n=np.convolve(n,np.ones(5)/5,'same')
    signal=(n*.22+np.sin(t*2*np.pi*(110+i*9))*.1)*np.exp(-t*34)
    write('step-'+str(i)+'.wav',signal)
t=np.arange(int(sr*1.3))/sr
bird=np.sin(2*np.pi*(780*t+90*np.sin(t*8)/(8)))
bird+=.32*np.sin(2*np.pi*(1530*t+110*np.sin(t*7)/(7)))
env=np.maximum(0,np.sin(t*np.pi/1.3))**3*(.65+.35*np.sin(t*18))
write('gull.wav',bird*env*.15)
t=np.arange(sr*3)/sr
bell=(np.sin(t*2*np.pi*440)+.5*np.sin(t*2*np.pi*881)+.2*np.sin(t*2*np.pi*1307))*np.exp(-t*2.8)*.18
write('bell.wav',bell)
print('Original ambience and footsteps created.')
