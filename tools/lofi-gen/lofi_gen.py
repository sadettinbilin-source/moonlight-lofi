#!/usr/bin/env python3
"""Original lofi generator: pure numpy/scipy synthesis, no samples. All output 100% owned by the user.
Usage: python3 lofi_gen.py --seed 1 --key D --bpm 78 --prog ii-V-I-vi --out out/track.wav
"""
import argparse, numpy as np
from scipy.signal import butter, sosfilt, sosfiltfilt
from scipy.io import wavfile
SR=44100
NOTES={'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}
# degree -> (root semitone offset, chord intervals) jazzy 7/9 voicings
CH={'I':(0,[0,4,7,11,14]),'ii':(2,[0,3,7,10,14]),'iii':(4,[0,3,7,10]),'IV':(5,[0,4,7,11,14]),
    'V':(7,[0,4,7,10,14]),'vi':(9,[0,3,7,10,14]),'bVII':(10,[0,4,7,11]),'iv':(5,[0,3,7,10,14])}
PROGS={'ii-V-I-vi':['ii','V','I','vi'],'I-vi-ii-V':['I','vi','ii','V'],'IV-iii-ii-I':['IV','iii','ii','I'],
       'vi-IV-I-V':['vi','IV','I','V'],'I-IV-iv-I':['I','IV','iv','I'],'ii-V-iii-vi':['ii','V','iii','vi']}
mtof=lambda m:440*2**((m-69)/12)
def lp(x,f,o=2): return sosfilt(butter(o,f,'low',fs=SR,output='sos'),x)
def hp(x,f,o=2): return sosfilt(butter(o,f,'high',fs=SR,output='sos'),x)
def rhodes(f,dur,vel,rng):
    n=int((dur+1.5)*SR); t=np.arange(n)/SR
    env=np.exp(-t*1.6)*(1-np.exp(-t*300)); idx=1.8*vel*np.exp(-t*6)+0.3
    det=1+rng.uniform(-.002,.002)
    s=np.sin(2*np.pi*f*det*t+idx*np.sin(2*np.pi*f*t))+0.25*np.sin(2*np.pi*2*f*t)*np.exp(-t*3)
    rel=np.clip((dur+1.5-t)/1.5,0,1)  # fade over release
    return s*env*rel*vel
def bass(f,dur,vel):
    n=int((dur+.3)*SR); t=np.arange(n)/SR
    env=(1-np.exp(-t*80))*np.exp(-t*1.2)*np.clip((dur+.3-t)/.3,0,1)
    return np.tanh(1.5*(np.sin(2*np.pi*f*t)+.3*np.sin(4*np.pi*f*t)))*env*vel
def kick(rng):
    t=np.arange(int(.5*SR))/SR; f=45+90*np.exp(-t*30)
    return np.tanh(2*np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-t*7))*.9
def snare(rng):
    t=np.arange(int(.35*SR))/SR; nz=lp(hp(rng.standard_normal(len(t)),900),6000)
    return (.6*nz*np.exp(-t*18)+.4*np.sin(2*np.pi*185*t)*np.exp(-t*25))*.55
def hat(rng,open_=False):
    t=np.arange(int(.2*SR))/SR; nz=hp(rng.standard_normal(len(t)),7000,4)
    return nz*np.exp(-t*(12 if open_ else 60))*.18
def add(buf,x,i):  # wrap-around add => seamless loop
    n=len(buf); i%=n; k=min(len(x),n-i); buf[i:i+k]+=x[:k]
    if len(x)>k: buf[:len(x)-k]+=x[k:]
def render(seed=1,key='D',bpm=80,prog='ii-V-I-vi',length=150.0,swing=0.58):
    rng=np.random.default_rng(seed)
    bars=round(length*bpm/240); bpm=bars*240/length  # exact loop length
    beat=60/bpm; bar=4*beat; N=int(round(length*SR))
    keys=np.zeros(N);bs=np.zeros(N);dr=np.zeros(N);mel=np.zeros(N)
    root=48+NOTES[key]; P=PROGS[prog] if prog in PROGS else prog.split('-')
    K,S,H,HO=kick(rng),snare(rng),hat(rng),hat(rng,True)
    scale=[0,2,4,7,9,12,14,16]  # pentatonic-ish
    motif=[(rng.integers(0,8),rng.choice([.5,1,1.5]))for _ in range(6)]
    kpat=[0,1.75,2.5] if seed%2 else [0,2.25,2.5]
    for b in range(bars):
        deg=P[b%len(P)]; r,iv=CH[deg]; t0=b*bar
        # chord: slightly strummed, voiced around C4
        for j,v in enumerate(iv):
            m=root+12+r+v
            while m>72:m-=12
            vel=.22*rng.uniform(.85,1.05)
            add(keys,rhodes(mtof(m),bar*.95,vel,rng),int((t0+j*.012+rng.uniform(0,.01))*SR))
        if rng.random()<.4:  # offbeat re-hit
            for v in iv[:3]: add(keys,rhodes(mtof(root+12+r+v),beat,.12,rng),int((t0+2.5*beat)*SR))
        # bass: root, fifth pickup
        add(bs,bass(mtof(root-12+r),beat*2.6,.5),int(t0*SR))
        add(bs,bass(mtof(root-12+r+(7 if rng.random()<.6 else 12)),beat*.9,.35),int((t0+3*beat)*SR))
        # drums w/ swing on 16ths
        sec=(b//8)%4
        for s in range(16):
            tt=t0+(s//2)*(beat/2)+((s%2)*beat/2*2*swing if s%2 else 0)
            tt=t0+s*beat/4+ (beat/4*(2*swing-1) if s%2 else 0)
            hum=rng.normal(0,.006)
            if s/4 in kpat: add(dr,K*rng.uniform(.85,1),int((tt+hum)*SR))
            if s in(4,12): add(dr,S*rng.uniform(.85,1),int((tt+hum+.01)*SR))
            if s%2==0 or rng.random()<.25:
                add(dr,(HO if s==14 and rng.random()<.3 else H)*rng.uniform(.5,1),int((tt+hum)*SR))
        # melody: motif on alternating 4-bar phrases, rests elsewhere
        if (b//4)%2==1 and sec!=0:
            tt=t0
            for d,l in motif:
                if tt-t0>=bar*.9 or rng.random()<.25: tt+=l*beat; continue
                m=root+24+scale[d]+(0 if rng.random()<.8 else 2)
                add(mel,rhodes(mtof(m),l*beat*.9,.16,rng),int(tt*SR)); tt+=l*beat
    t=np.arange(N)/SR
    keys=lp(keys,3200); mel=lp(mel,3500)
    keys*=1+.15*np.sin(2*np.pi*4.5*t)  # rhodes tremolo
    bs=lp(bs,600,4)
    # sidechain-ish duck on beats
    duck=1-.25*np.exp(-((t%beat))*10)
    mix=keys*duck*1.0+mel*.9+bs*duck*.9+dr*.8
    # textures: vinyl crackle + rain, loop-safe (generated periodic over N via wrap)
    crack=np.zeros(N); idx=rng.integers(0,N,int(length*25)); crack[idx]=rng.standard_normal(len(idx))*rng.uniform(.05,.4,len(idx))
    crack=lp(hp(crack,1500),7000)*.25
    hiss=lp(hp(rng.standard_normal(N),2000),8000)*.004
    rain=lp(hp(rng.standard_normal(N),400),4500)*.02
    rain*=1+.3*np.sin(2*np.pi*t/length*3)  # integer cycles -> seamless
    mix=mix+crack+hiss+rain
    # tape wobble: modulated delay, periodic over loop
    wob=0.0018*(1+np.sin(2*np.pi*t*round(.6*length)/length))+.0004*np.sin(2*np.pi*t*round(5*length)/length)
    pos=(np.arange(N)-wob*SR)%N
    i0=np.floor(pos).astype(int); fr=pos-i0
    mix=mix[i0]*(1-fr)+mix[(i0+1)%N]*fr
    # global warmth: lowpass, gentle saturation; filter circularly for seamlessness
    pad=SR*2; ext=np.concatenate([mix[-pad:],mix,mix[:pad]])
    ext=sosfiltfilt(butter(2,6500,'low',fs=SR,output='sos'),ext); ext=hp(ext,30)
    mix=ext[pad:-pad]; mix=np.tanh(mix*1.2)/1.2
    mix/=np.max(np.abs(mix))*1.12
    st=np.stack([mix,np.roll(mix,int(.0007*SR))*.97+.03*mix],1)  # subtle width
    return st,bpm
if __name__=='__main__':
    a=argparse.ArgumentParser()
    a.add_argument('--seed',type=int,default=1);a.add_argument('--key',default='D')
    a.add_argument('--bpm',type=float,default=80);a.add_argument('--prog',default='ii-V-I-vi')
    a.add_argument('--length',type=float,default=150);a.add_argument('--out',default='out/track.wav')
    o=a.parse_args(); x,b=render(o.seed,o.key,o.bpm,o.prog,o.length)
    wavfile.write(o.out,SR,(x*32767).astype(np.int16)); print(f'wrote {o.out} bpm={b:.2f}')
