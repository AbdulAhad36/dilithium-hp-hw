"""Real SHAKE -> sampling -> memory -> NTT: independent file comparison.

Subsystem fixtures are local; nist_keygen uses pinned official NIST ACVP files.
One script prepares inputs and separately compares captured RTL outputs.
"""
import argparse
import hashlib
import importlib.util
import json
import random
import shutil
import subprocess
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
NIST_KEYGEN = ROOT / 'NIST/ML-DSA-keyGen-FIPS204'
NIST_COMMIT = '2972def23bf9f3680c2c531561ed9bdd0f1086ad'
NIST_HASHES = {
    'prompt.json':'43e81ad820e495dbcad086fe27c1008393a8c32100bbbff77c558c3f06dcefef',
    'expectedResults.json':'361f47ca19d592adcc66ff2cb591686ad785fea157b295648738bed6921a68df',
}
REF = ROOT / 'FIPS204_SAMPLER/sampler_vectors.py'
spec = importlib.util.spec_from_file_location('sampler_reference', REF)
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)
NTT_REF = ROOT / 'FIPS204_NTT/ntt_vectors.py'
ntt_spec = importlib.util.spec_from_file_location('ntt_reference', NTT_REF)
ntt_reference = importlib.util.module_from_spec(ntt_spec)
ntt_spec.loader.exec_module(ntt_reference)


def cases():
    result = []
    def add(mode, param, label, length=None, abort=False, job_id=None):
        i = len(result)
        length = (34 if mode == 0 else 66 if mode in (1, 2) else 32) if length is None else length
        message = hashlib.shake_256(label.encode()).digest(length)
        # Raw absorbed messages exercise the engine connection; full seed/nonce
        # formatting is a later controller/version contract.
        if param == 3:
            values, code = [], 3
        else:
            stream = (hashlib.shake_128 if mode == 0 else hashlib.shake_256)(message).digest(4096)
            values, _ = reference.sample(mode, param, stream)
            assert len(values) == 256
            code = 0
        result.append(dict(i=i, id=1000+i if job_id is None else job_id,
                           mode=mode, param=param, message=message,
                           abort=abort, code=code, values=values))
    # Twelve pairs establish both contexts in every mode/parameter combination.
    for mode in range(4):
        for param in range(3):
            for slot in range(2):
                add(mode, param, f'base-{mode}-{param}-{slot}')
    # All sixteen ordered mode pairs, including independent live peer modes.
    for first in range(4):
        for second in range(4):
            param = (first+second) % 3
            add(first, param, f'mixed-{first}-{second}-a')
            add(second, param, f'mixed-{first}-{second}-b')
    # Empty/partial/multi-rate absorption; unused high input bytes are poisoned.
    lengths = [0, 1, 7, 8, 9, 33, 34, 65, 66, 135, 136, 137,
               167, 168, 169, 271, 272, 273, 335, 336, 337, 15, 16, 17]
    for i, length in enumerate(lengths):
        add(i % 4, (i//4) % 3, f'length-{i}', length)
    assert len(result) == 80
    for mode in range(4):
        for slot in range(2):
            add(mode, 3, f'invalid-{mode}-{slot}')
    for phase in range(4):
        for slot in range(2):
            add((phase+slot) % 4, phase % 3, f'abort-{phase}-{slot}', abort=True,
                job_id=2000+phase*2+slot)
        for slot in range(2):
            add((phase+slot) % 4, phase % 3, f'recover-{phase}-{slot}',
                job_id=2000+phase*2+slot)
    assert len(result) == 104
    return result


def mathematical_decompose(a,p):
    gamma=95232 if p==0 else 261888
    high=(a+gamma-1)//(2*gamma)
    return (0,a-8380417) if high==(8380416//(2*gamma)) else (high,a-high*2*gamma)


@lru_cache(maxsize=1)
def sign_process_cases():
    rows=[];rng=random.Random(0x5D2026)
    def add(op,p,kind,jid,index,data,high=None,abort=0,last=None):
        rows.append(dict(i=len(rows),op=op,p=p,kind=kind,id=jid,index=index,
            last=int(index==63) if last is None else last,abort=abort,
            data=data,high=[63]*4 if high is None and op!=2 else ([0]*4 if high is None else high)))
    def packet(op,p,kind=3,pattern=3,jid=None,end=63,abort=False):
        jid=(10000+len(rows))&65535 if jid is None else jid
        g=95232 if p==0 else 261888;beta=(78,196,120)[p]
        bound=((131072 if p==0 else 524288)-beta,g-beta,g)[kind] if op==1 else 0
        maximum=43 if p==0 else 15;omega=(80,55,75)[p]
        edges=sorted({0,1,8380415,8380416}|{a for h in range(maximum+2) for d in range(-2,3)
            if 0<=(a:=h*2*g+g+d)<8380417})
        hint_edges=[(v,h) for h in (0,1,maximum) for v in (-g-1,-g,-g+1,-1,0,1,g-1,g,g+1)]
        for index in range(end+1):
            a=[];high=[]
            for lane in range(4):
                n=4*index+lane
                if op==0:
                    value=0 if pattern==0 else edges[n%len(edges)] if pattern==1 else 8380416 if pattern==2 else rng.randrange(8380417)
                    h=63
                elif op==1:
                    value=(0 if pattern==0 else ((bound-1,bound,bound+1,1-bound,-bound,-bound-1)[n] if n<6 else 0)
                           if pattern==1 else (bound if n==255 else 0) if pattern==2 else rng.randrange(-bound-5,bound+6))%8380417
                    h=63
                else:
                    value,h=(0,n%(maximum+1)) if pattern==0 else (g+1,n%(maximum+1)) if pattern==1 else hint_edges[n%len(hint_edges)] if pattern==2 else (rng.randrange(-4190208,4190209),rng.randrange(maximum+1)) if pattern==3 else (g+1 if n<omega+int(pattern==5) else 0,n%(maximum+1))
                    value%=8380417
                a.append(value);high.append(h)
            add(op,p,kind,jid,index,a,high,abort=int(abort and index==end))
    for p in range(3):
        for pattern in range(4):packet(0,p,pattern=pattern)
        for kind in range(3):
            for pattern in range(4):packet(1,p,kind,pattern)
        for pattern in range(6):packet(2,p,pattern=pattern)
    for op in range(3):
        for phase,end in enumerate((6,63)):
            jid=60000+op*2+phase
            packet(op,op,kind=0 if op==1 else 3,pattern=1 if op==1 else 3,jid=jid,end=end,abort=True)
            packet(op,op,kind=0 if op==1 else 3,pattern=0 if op==1 else 3,jid=jid)
    # Each malformed packet is followed by a complete fresh packet.
    invalid=[dict(op=3,p=0,kind=0,index=0,data=[0]*4)]
    for op in range(3):
        invalid.append(dict(op=op,p=3,kind=0,index=0,data=[0]*4))
        for lane in range(4):
            for value in (8380417,8388607):
                data=[0]*4;data[lane]=value
                invalid.append(dict(op=op,p=op,kind=0,index=0,data=data))
        invalid += [dict(op=op,p=op,kind=0,index=1,data=[0]*4),dict(op=op,p=op,kind=0,index=0,data=[0]*4,last=1)]
    invalid.append(dict(op=1,p=0,kind=3,index=0,data=[0]*4))
    for lane in range(4):
        high=[0]*4;high[lane]=16
        invalid.append(dict(op=2,p=1,kind=0,index=0,data=[0]*4,high=high))
    for c in invalid:
        jid=(20000+len(rows))&65535;add(jid=jid,**c);packet(0,0,jid=jid)
    for field,value in [('id',65535),('p',1),('op',2),('kind',1),('index',0),('index',2)]:
        jid=(30000+len(rows))&65535
        add(1,0,0,jid,0,[0]*4)
        c=dict(op=1,p=0,kind=0,jid=jid,index=1,data=[0]*4,high=[0]*4)
        c['jid' if field=='id' else field]=value;add(**c);packet(1,0,0,jid=jid)
    return rows


def sign_lane(op,p,kind,a,h):
    if p==3 or op==3 or a>=8380417 or (op==1 and kind==3) or (op==2 and h>(43 if p==0 else 15)):
        return (1,0,0,0,0)
    if op==0:
        high,low=mathematical_decompose(a,p);return (0,high,low,0,0)
    center=a if a<=4190208 else a-8380417
    if op==1:
        g=95232 if p==0 else 261888;beta=(78,196,120)[p]
        bound=((131072 if p==0 else 524288)-beta,g-beta,g)[kind]
        return (0,0,0,0,int(abs(center)>=bound))
    alpha=190464 if p==0 else 523776
    # Independent high-bit-change definition,not the RTL's threshold predicate.
    return (0,0,0,int(mathematical_decompose((h*alpha+center)%8380417,p)[0]!=h),0)


@lru_cache(maxsize=1)
def sign_process_expected():
    result=[];active=None;prefix_fail=weight=0
    for c in sign_process_cases():
        key=(c['id'],c['op'],c['p'],c['kind'] if c['op']==1 else None)
        values=[sign_lane(c['op'],c['p'],c['kind'],a,h) for a,h in zip(c['data'],c['high'],strict=True)]
        bad=any(v[0] for v in values) or c['last']!=int(c['index']==63) or (active is None and c['index']!=0) or (active is not None and active!=(key,c['index']))
        high=low=hints=rejects=fail=count=0
        if not bad:
            high=sum(v[1]<<(6*i) for i,v in enumerate(values));low=sum((v[2]&((1<<19)-1))<<(19*i) for i,v in enumerate(values))
            hints=sum(v[3]<<i for i,v in enumerate(values));rejects=sum(v[4]<<i for i,v in enumerate(values))
            fail=int(bool(prefix_fail or rejects)) if c['op']==1 else 0
            count=weight+hints.bit_count() if c['op']==2 else 0
        result.append((int(bad),high,low,hints,rejects,fail,count))
        if bad or c['last'] or c['abort']:active=None;prefix_fail=weight=0
        else:active=(key,c['index']+1);prefix_fail=fail;weight=count
    return result


def sign_process_input_artifact(token):
    rows=sign_process_cases()
    return f'{token} {len(rows)}\n'+''.join(' '.join(str(c[k]) for k in ('i','op','p','kind','id','index','last','abort'))+
        f" {sum(a<<(23*i) for i,a in enumerate(c['data'])):023x} {sum(h<<(6*i) for i,h in enumerate(c['high'])):06x}\n" for c in rows)


def sign_process_expected_artifact(token):
    rows=sign_process_expected()
    return f'{token} {len(rows)}\n'+''.join(f'{i} {e} {h:06x} {l:019x} {hint} {lane} {reject} {weight}\n'
        for i,(e,h,l,hint,lane,reject,weight) in enumerate(rows))


def check_sign_process_c():
    gcc=shutil.which('gcc');build=HERE/'reference_build';build.mkdir(exist_ok=True);reports=[]
    if not gcc:raise ValueError('GCC required for signing-process references')
    for p,level in enumerate((2,3,5)):
        exe=build/f'sign_process_reference_{level}.exe';ref=ROOT/'dilithium-sw-model/ref'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ref),
            str(ROOT/'tb/tb_dilithium/sign_process_reference.c'),*[str(ref/n) for n in ('poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],check=True,capture_output=True,text=True)
        report=subprocess.run([str(exe),'--selftest'],check=True,capture_output=True,text=True).stdout
        if not report.startswith('C_DECOMPOSE_EXHAUSTIVE_PASS:8380417'):raise ValueError('C decomposition exhaustive marker')
        reports.append(report)
        selected=[(c,a,h) for c in sign_process_cases() if c['p']==p for a,h in zip(c['data'],c['high'],strict=True)]
        output=subprocess.run([str(exe)],input=''.join(f"{c['op']} {c['kind']} {a} {h}\n" for c,a,h in selected),check=True,capture_output=True,text=True).stdout.splitlines()
        if len(output)!=len(selected):raise ValueError('C signing-process row count')
        for (c,a,h),line in zip(selected,output,strict=True):
            if tuple(map(int,line.split()))!=sign_lane(c['op'],c['p'],c['kind'],a,h):raise ValueError('Python/C signing mismatch at case'+str(c['i']))
        reports.append(f"PYTHON_C_SIGN_PROCESS_PASS:level{level},{len(selected)} scalar lane fixtures\n")
    report=''.join(reports);(HERE/'stage5_sign_process_c_reference.log').write_text(report);print(report,end='')


def verify_sign_process(lines):
    _,token=check();rows=sign_process_cases();golden=sign_process_expected()
    if not lines or lines[0]!='H '+token:raise ValueError('Signing-process freshness')
    opened=done=aborts=errors=packets=resets=0;pending=[];footer=None
    for line in lines[1:]:
        f=line.split();kind=f[0]
        if footer is not None:raise ValueError('Signing-process record after footer')
        if kind=='X':
            if pending:raise ValueError('Unaccounted reset input')
            resets+=1;continue
        if kind=='F':footer=list(map(int,f[1:]));continue
        i=int(f[1])
        if kind=='J':
            if i!=opened or opened>=len(rows):raise ValueError('Signing-process acceptance order')
            pending.append(i);opened+=1;continue
        if not pending or pending.pop(0)!=i:raise ValueError('Signing-process result ownership')
        c=rows[i];e=golden[i]
        if kind=='A':
            if not c['abort']:raise ValueError('Unexpected signing abort')
            aborts+=1;continue
        expected=[e[0],c['op'],c['p'],c['kind'],c['id'],c['index'],c['last']]
        if kind!='P' or c['abort'] or list(map(int,f[2:9]))!=expected or [int(f[9],16),int(f[10],16),*map(int,f[11:])]!=list(e[1:]):
            raise ValueError('Signing-process output mismatch at case'+str(i))
        done+=1;errors+=e[0];packets+=int(not e[0] and c['last'])
    if pending or opened!=len(rows) or resets!=7 or aborts!=6 or footer is None or footer[:4]!=[opened,done,aborts,errors] or len(footer)!=8 or min(footer[4:7])<=0 or footer[7]!=packets:
        raise ValueError('Signing-process campaign incomplete')
    return f'DILITHIUM_STAGE5N2_SIGN_PROCESS_COMPARE_PASS:{opened} accepted x4 groups,{done} exact results,{errors} expected errors,{aborts} reset aborts,{packets} complete polynomials;all3 levels,Decompose/CNB/Mhint,stalls,replacement,ownership and recovery\n'


@lru_cache(maxsize=1)
def arithmetic_vectors():
    rows=cases(); result=[]
    ntt_reference.check_reference()
    for p in range(3):
        a=rows[2*p]['values'];s=rows[6+2*p]['values']
        ia=ntt_reference.direct_inverse(a);ns=ntt_reference.direct_forward(s)
        pwm=ntt_reference.pointwise(a,ns)
        product=ntt_reference.schoolbook(ia,s)
        assert ntt_reference.direct_inverse(pwm)==product
        for poly in (ia,ns,s,ns,ntt_reference.pointwise(ns,ns),pwm,product):
            result.append(poly)
    for i in (12,18):
        result += [ntt_reference.direct_forward(rows[i]['values']), rows[i]['values']]
    result.append(ntt_reference.direct_forward(rows[7]['values']))
    assert len(result)==26
    return result


@lru_cache(maxsize=1)
def process_cases():
    result=[]
    def add(op,a,b=0,abort=False,job_id=None,bad_last=False):
        i=len(result);index=i%256;last=int(index==255)^int(bad_last)
        error=int(op==3 or a>=8_380_417 or (op<2 and b>=8_380_417) or bad_last)
        residue=high=low=packed=0
        if not error:
            if op==0:residue=(a+b)%8_380_417
            elif op==1:residue=(a-b)%8_380_417
            else:
                high,low=divmod(a,8192)
                if low>4096:high+=1;low-=8192
                packed=4096-low
        result.append([i,op,a,b,9000+i//2 if job_id is None else job_id,index,last,
                       int(abort),error,residue,high,low,packed])
    for op,a,b,recover_op,recover_a,recover_b in [
        (0,0,8_380_416,0,8_380_416,8_380_416),
        (1,0,8_380_416,2,4096,8_388_607),
        (2,4097,0,2,8_380_416,0)]:
        add(op,a,b,True);add(recover_op,recover_a,recover_b)
    for high in range(1024):
        for offset in (0,1,4094,4095,4096,4097,4098,8190,8191):
            a=high*8192+offset
            if a<8_380_417:add(2,a,8_388_607) # unused B must not affect rounding
    boundaries=sorted({0,1,4096,4097,4_190_208,8_380_415,8_380_416})
    for op in (0,1):
        for a in boundaries:
            for b in boundaries:add(op,a,b)
    rng=random.Random(0x5A2026)
    for _ in range(512):
        a=rng.randrange(8_380_417);b=rng.randrange(8_380_417)
        add(0,a,b);add(1,a,b)
    for op in range(3):
        add(op,8_380_417);add(op,8_388_607)
        add(op,1,8_380_417,bad_last=(op==2));add(op,1,bad_last=True)
    add(3,0)
    assert len(result)<16000 and sum(r[7] for r in result)==3
    return result


def check_process_c():
    gcc=shutil.which('gcc')
    if not gcc:raise ValueError('GCC is needed by prepare for the independent process reference')
    build=HERE/'reference_build';build.mkdir(exist_ok=True)
    exe=build/'process_reference.exe'
    subprocess.run([gcc,'-std=c99','-O2','-DDILITHIUM_MODE=2','-I',str(ROOT/'dilithium-sw-model/ref'),
                    str(ROOT/'tb/tb_dilithium/process_reference.c'),str(ROOT/'dilithium-sw-model/ref/rounding.c'),
                    '-o',str(exe)],check=True,capture_output=True,text=True)
    report=subprocess.run([str(exe),'--selftest'],check=True,capture_output=True,text=True).stdout
    if not report.startswith('C_PROCESS_REFERENCE_PASS:8380417 '):raise ValueError('C reference selftest marker missing')
    rows=process_cases()
    values=subprocess.run([str(exe)],input=''.join(f'{r[1]} {r[2]} {r[3]}\n' for r in rows),
                          check=True,capture_output=True,text=True).stdout.splitlines()
    if len(values)!=len(rows):raise ValueError('C process oracle count')
    for r,line in zip(rows,values,strict=True):
        observed=list(map(int,line.split()))
        if r[6]!=int(r[5]==255):observed=[1,0,0,0,0] # framing is checked by the transport
        if observed!=r[8:13]:raise ValueError('Python/C process mismatch at case'+str(r[0]))
    report+=f'PYTHON_C_PROCESS_PASS:{len(rows)} arithmetic/framing cases\n'
    (HERE/'stage5_c_reference.log').write_text(report);print(report,end='')


def artifacts():
    rows = cases()
    stimuli, golden = [], []
    for c in rows:
        stimuli.append(f"{c['i']} {c['id']} {c['mode']} {c['param']} {int(c['abort'])} {len(c['message'])} {c['message'].hex() or '-'}")
        golden.append(f"{c['i']} {c['code']} {int(c['abort'])} {len(c['values'])} " +
                      ' '.join(f'{v:06x}' for v in c['values']))
    body = '\n'.join(stimuli)+'\n'
    expected = '\n'.join(golden)+'\n'
    math_body='\n'.join(str(i)+' '+' '.join(f'{v:06x}' for v in poly)
                        for i,poly in enumerate(arithmetic_vectors()))+'\n'
    process_body='\n'.join(' '.join(map(str,r)) for r in process_cases())+'\n'
    sources = [Path(__file__).resolve(), REF, NTT_REF, ROOT/'sim/dilithium/run.do']
    sources += [NIST_KEYGEN/n for n in (*NIST_HASHES,'provenance.json')]
    sources += [ROOT/'tb/tb_dilithium/process_reference.c',ROOT/'tb/tb_dilithium/bitpkg_reference.c',ROOT/'tb/tb_dilithium/keygen_reference.c',ROOT/'tb/tb_dilithium/sign_process_reference.c']
    sources += [ROOT/'dilithium-sw-model/ref'/n for n in ('rounding.c','rounding.h','params.h','config.h','poly.c','poly.h','reduce.c','reduce.h','ntt.c','ntt.h','symmetric-shake.c','symmetric.h','fips202.c','fips202.h','sign.c','sign.h','polyvec.c','polyvec.h','packing.c','packing.h','randombytes.h')]
    sources += sorted((ROOT/'src/keccak').glob('*.sv'))
    sources += sorted((ROOT/'src/sampler').glob('*.sv'))
    sources += sorted((ROOT/'src/controller').rglob('*.sv'))
    sources += sorted((ROOT/'src/ntt').glob('*.sv'))
    sources += sorted((ROOT/'tb/tb_dilithium').glob('*.sv'))
    h = hashlib.sha256((body+expected+math_body+process_body+full_keygen_expected_artifact('reference')).encode())
    for p in sources:
        h.update(p.relative_to(ROOT).as_posix().encode()); h.update(p.read_bytes())
    token = h.hexdigest()
    header = f'{token} {len(rows)}\n'
    return rows, token, header+body, header+expected, f'{token} 26\n'+math_body, f'{token} {len(process_cases())}\n'+process_body


@lru_cache(maxsize=1)
def hash_format_cases():
    """Final FIPS 204 KeyGen messages; level labels remain 2/3/5.

    Locally generated component vectors, not published NIST full-operation KATs.
    """
    result=[]
    def add(op,p,seed,row=0,column=0,nonce=0,abort=0,job_id=None):
        i=len(result);k,l=[(4,4),(6,5),(8,7),(0,0)][p]
        error=int(p==3 or op==3 or (op==1 and (row>=k or column>=l)) or
                  (op==2 and nonce>=k+l))
        message=b''
        if not error:
            if op==0:message=seed[:32]+bytes([k,l])
            elif op==1:message=seed[:32]+bytes([column,row])
            else:message=seed[:64]+nonce.to_bytes(2,'little')
        mode=int(op!=1);outlen=128 if op==0 else 0
        # Bound the test service to32 output bytes for sample-message checks.
        # The RTL descriptor remains continuous (outlen0); this test does not sample.
        digest=((hashlib.shake_256 if mode else hashlib.shake_128)(message).digest(
            128 if op==0 else 32)) if not error else b''
        result.append(dict(i=i,op=op,p=p,seed=seed.ljust(64,b'\xa5'),row=row,column=column,
                           nonce=nonce,abort=abort,id=12000+i if job_id is None else job_id,
                           error=error,message=message,mode=mode,outlen=outlen,digest=digest))
    for phase in (1,2,3):
        seed=hashlib.shake_256(f'abort{phase}'.encode()).digest(32)
        add(0,phase-1,seed,abort=phase,job_id=11999+phase)
        add(0,phase-1,bytes(x^255 for x in seed),job_id=11999+phase)
    for p,(k,l) in enumerate(((4,4),(6,5),(8,7))):
        for seed in (bytes(32),bytes([255])*32,bytes(range(32))):add(0,p,seed)
        expanded=hashlib.shake_256(bytes(range(32))+bytes([k,l])).digest(128)
        for row in range(k):
            for column in range(l):add(1,p,expanded[:32],row=row,column=column)
        for nonce in range(k+l):add(2,p,expanded[32:96],nonce=nonce)
        add(1,p,expanded[:32],row=k)
        add(1,p,expanded[:32],column=l)
        add(2,p,expanded[32:96],nonce=k+l)
    for op in range(3):add(op,3,bytes(64))
    add(3,0,bytes(64));add(2,0,bytes(64),nonce=65535)
    return result


def hash_format_artifact(token):
    rows=hash_format_cases()
    body='\n'.join(f"{r['i']} {r['op']} {r['p']} {r['id']} {r['row']} {r['column']} "
                   f"{r['nonce']} {r['abort']} {r['error']} "
                   f"{int.from_bytes(r['seed'],'little'):0128x} "
                   f"{int.from_bytes(r['message'],'little'):0132x}" for r in rows)+'\n'
    return f'{token} {len(rows)}\n'+body


@lru_cache(maxsize=1)
def shared_hash_cases():
    rows=[];expanded={}
    def add(kind,p=0,mode=1,abort=0,seed=b'',message=b'',outlen=128,nonce=0,row=0,column=0,job_id=None):
        i=len(rows);error=int(kind==1 and p==3)
        if kind==1:
            message=b'' if error else seed+bytes([(4,6,8)[p],(4,5,7)[p]])
        if kind==2:
            material=expanded[p]
            message=(material[:32]+bytes([column,row])) if mode==0 else material[32:96]+nonce.to_bytes(2,'little')
            outlen=0
        digest=b'' if error or kind==2 else (hashlib.shake_256 if mode else hashlib.shake_128)(message).digest(outlen)
        values=[]
        if kind==2:
            values,_=reference.sample(mode,p,(hashlib.shake_128 if mode==0 else hashlib.shake_256)(message).digest(4096))
        rows.append(dict(i=i,kind=kind,p=p,mode=mode,abort=abort,seed=seed.ljust(32,b'\0'),message=message,
                         outlen=outlen,nonce=nonce,row=row,column=column,id=13000+i if job_id is None else job_id,
                         error=error,digest=digest,values=values))
    for phase in (1,2,3):
        add(1,abort=phase,seed=hashlib.shake_256(f'shared-abort-{phase}'.encode()).digest(32),job_id=12990+phase)
        add(1,seed=hashlib.shake_256(f'shared-recover-{phase}'.encode()).digest(32),job_id=12990+phase)
    for p,(k,l) in enumerate(((4,4),(6,5),(8,7))):
        seed=hashlib.shake_256(f'shared-main-{p}'.encode()).digest(32)
        expanded[p]=hashlib.shake_256(seed+bytes([k,l])).digest(128)
        add(1,p,seed=seed)
        add(2,p,mode=0,row=k-1,column=l-1)
        add(2,p,mode=1,nonce=k+l-1)
    add(1,3,seed=bytes(32))
    for i,(length,outlen) in enumerate(((0,1),(1,15),(7,16),(8,17),(136,137),(169,169),(273,272),(34,32))):
        add(0,mode=i%2,message=hashlib.shake_256(f'raw-{i}'.encode()).digest(length),outlen=outlen)
    add(0,message=bytes(range(17)),outlen=128)
    add(2,1,mode=0,row=5,column=4)
    return rows


def shared_hash_artifact(token):
    rows=shared_hash_cases()
    body='\n'.join(f"{r['i']} {r['kind']} {r['p']} {r['id']} {r['mode']} {r['abort']} "
                   f"{len(r['message'])} {r['outlen']} {r['nonce']} {r['row']} {r['column']} "
                   f"{int.from_bytes(r['seed'],'little'):064x} "
                   f"{int.from_bytes(r['message'],'little'):0800x}" for r in rows)+'\n'
    return f'{token} {len(rows)}\n'+body


@lru_cache(maxsize=1)
def bank_memory_cases():
    rows=[];rng=random.Random(0xB4921024)
    def add(phase,b,p,write,address,data=0):
        rows.append([len(rows),phase,b,p,write,address,data])
    for b in range(4):
        for p in range(2):
            for j in range(512):add(0,b,p,1,2*j+p,rng.getrandbits(92))
            for j in range(1024):add(1,b,p,0,j)
            for j in range(16):add(2,b,p,int(p==0),0,rng.getrandbits(92))
            add(3,b,p,1,5,(1<<92)-1 if p else 0)
            add(4,b,p,p,9,rng.getrandbits(92))
            for j in range(300):add(5,b,p,rng.randrange(2),rng.randrange(1024),rng.getrandbits(92))
            add(6,b,p,1,10+p,((b+1)<<80)|((p+1)<<64)|0xABCDEF)
            add(7,b,p,1,20+p,(1<<92)-1) # never accepted:blocked offer canceled by reset
            for address in (10,11,20,21):add(8,b,p,0,address)
    return rows


def bank_memory_artifact(token):
    rows=bank_memory_cases()
    return f'{token} {len(rows)}\n'+'\n'.join(' '.join(map(str,r[:6]))+f' {r[6]:023x}' for r in rows)+'\n'


def prepare():
    check_sign_process_c()
    check_process_c()
    check_bitpkg_c()
    build_full_keygen_c()
    check_nist_keygen_c()
    rows, token, stimuli, golden, arithmetic, process = artifacts()
    (HERE/'stage5_sign_dma_inputs.txt').write_text(sign_dma_artifact(token),encoding='ascii')
    (HERE/'stage5_sign_process_inputs.txt').write_text(sign_process_input_artifact(token),encoding='ascii')
    (HERE/'stage5_sign_process_expected.txt').write_text(sign_process_expected_artifact(token),encoding='ascii')
    (HERE/'stage2_inputs.txt').write_text(stimuli, encoding='ascii')
    (HERE/'stage2_expected.txt').write_text(golden, encoding='ascii')
    (HERE/'stage4_expected.txt').write_text(arithmetic, encoding='ascii')
    (HERE/'stage5_process_inputs.txt').write_text(process, encoding='ascii')
    (HERE/'stage5_hash_inputs.txt').write_text(hash_format_artifact(token),encoding='ascii')
    (HERE/'stage5_shared_inputs.txt').write_text(shared_hash_artifact(token),encoding='ascii')
    (HERE/'stage5_banks_inputs.txt').write_text(bank_memory_artifact(token),encoding='ascii')
    (HERE/'stage5_process_banks_inputs.txt').write_text(process_bank_artifact(token),encoding='ascii')
    (HERE/'stage5_full_keygen_inputs.txt').write_text(full_keygen_input_artifact(token),encoding='ascii')
    (HERE/'stage5_full_keygen_expected.txt').write_text(full_keygen_expected_artifact(token),encoding='ascii')
    (HERE/'stage5_nist_keygen_inputs.txt').write_text(nist_keygen_input_artifact(token),encoding='ascii')
    (HERE/'stage5_nist_keygen_expected.txt').write_text(nist_keygen_expected_artifact(token),encoding='ascii')
    (HERE/'stage5_bitpkg_inputs.txt').write_text(bitpkg_input_artifact(token),encoding='ascii')
    (HERE/'stage5_keygen_inputs.txt').write_text(keygen_input_artifact(token),encoding='ascii')
    (HERE/'stage5_seed_inputs.txt').write_text(seed_input_artifact(token),encoding='ascii')
    (HERE/'stage5_row_samples.txt').write_text(row_sample_artifact(token),encoding='ascii')
    (HERE/'stage5_row_expected.txt').write_text(row_expected_artifact(token),encoding='ascii')
    print(f'PREPARE PASS:{len(rows)} sampling cases plus26 arithmetic expectations;token {token}')


def check():
    rows, token, stimuli, golden, arithmetic, process = artifacts()
    if ((HERE/'stage2_inputs.txt').read_text() != stimuli or
        (HERE/'stage5_sign_dma_inputs.txt').read_text() != sign_dma_artifact(token) or
        (HERE/'stage5_sign_process_inputs.txt').read_text() != sign_process_input_artifact(token) or
        (HERE/'stage5_sign_process_expected.txt').read_text() != sign_process_expected_artifact(token) or
        (HERE/'stage2_expected.txt').read_text() != golden or
        (HERE/'stage4_expected.txt').read_text() != arithmetic or
        (HERE/'stage5_process_inputs.txt').read_text() != process or
        (HERE/'stage5_hash_inputs.txt').read_text() != hash_format_artifact(token) or
        (HERE/'stage5_shared_inputs.txt').read_text() != shared_hash_artifact(token) or
        (HERE/'stage5_banks_inputs.txt').read_text() != bank_memory_artifact(token) or
        (HERE/'stage5_process_banks_inputs.txt').read_text() != process_bank_artifact(token) or
        (HERE/'stage5_full_keygen_inputs.txt').read_text() != full_keygen_input_artifact(token) or
        (HERE/'stage5_full_keygen_expected.txt').read_text() != full_keygen_expected_artifact(token) or
        (HERE/'stage5_nist_keygen_inputs.txt').read_text() != nist_keygen_input_artifact(token) or
        (HERE/'stage5_nist_keygen_expected.txt').read_text() != nist_keygen_expected_artifact(token) or
        (HERE/'stage5_bitpkg_inputs.txt').read_text() != bitpkg_input_artifact(token) or
        (HERE/'stage5_keygen_inputs.txt').read_text() != keygen_input_artifact(token) or
        (HERE/'stage5_seed_inputs.txt').read_text() != seed_input_artifact(token) or
        (HERE/'stage5_row_samples.txt').read_text() != row_sample_artifact(token) or
        (HERE/'stage5_row_expected.txt').read_text() != row_expected_artifact(token)):
        raise ValueError('Stale source/reference/vector files: rerun prepare and capture')
    return rows, token


def verify(lines):
    rows, token = check()
    if not lines or lines[0] != 'H '+token:
        raise ValueError('Capture token differs;rerun simulation after prepare')
    opened, counts, finished = {}, {}, {}
    total_values = 0
    footer = None
    for line in lines[1:]:
        f = line.split()
        if f[0] == 'F':
            if footer is not None: raise ValueError('Duplicate footer')
            footer = list(map(int, f[1:]));continue
        i, core = map(int, f[1:3])
        if not 0 <= i < len(rows) or core not in (0, 1): raise ValueError('Unknown job/core')
        c = rows[i]
        if f[0] == 'J':
            if i in opened or int(f[3]) != c['id']: raise ValueError('Repeated/wrong descriptor')
            opened[i] = core;counts[i] = 0;continue
        if opened.get(i) != core or i in finished: raise ValueError('Unowned/retired output')
        if f[0] == 'C':
            index, value, last = int(f[3]), int(f[4],16), int(f[5])
            if index != counts[i] or index >= len(c['values']) or value != c['values'][index] or last != int(index==255):
                raise ValueError(f'Coefficient mismatch:case{i},index{index},observed{value}')
            counts[i] += 1;total_values += 1
        elif f[0] == 'S':
            if c['abort'] or int(f[3]) != c['code'] or counts[i] != len(c['values']):
                raise ValueError(f'Wrong status/count for case{i}')
            finished[i] = 'S'
        elif f[0] == 'A':
            if not c['abort'] or int(f[3]) != counts[i]: raise ValueError('Unexpected abort/count')
            finished[i] = 'A'
        else:raise ValueError('Unknown capture record')
    if len(opened) != 104 or len(finished) != 104 or footer != [104,88,8,8,total_values]:
        raise ValueError('Missing/extra jobs or incorrect footer')
    combinations = {(opened[c['i']],c['mode'],c['param']) for c in rows if not c['abort'] and c['code']==0}
    if len(combinations) != 24:raise ValueError('Missing mode/parameter/context combination')
    message = (f'DILITHIUM STAGE2 COMPARE PASS:104 jobs,88 complete,8 expected errors,8 reset aborts;'
               f'{total_values} exact coefficients (22528 complete-polynomial values plus checked aborted prefixes);'
               '24 mode/parameter/context combinations\n')
    return message


def verify_memory(lines):
    rows, token = check()
    if not lines or lines[0] != 'H '+token:
        raise ValueError('Memory capture token differs')
    opened, counts, finished, read_counts = {}, {}, {}, {}
    slots, live = {}, {}
    writes = reads = invalid = releases = resets = 0
    footer = None
    for line in lines[1:]:
        if footer is not None: raise ValueError('Record after memory footer')
        f = line.split()
        kind = f[0]
        if kind == 'F':
            footer = list(map(int, f[1:])); continue
        if kind == 'X':
            if live: raise ValueError('Reset omitted live-job abort records')
            slots.clear(); resets += 1; continue
        if kind in ('E', 'L'):
            slot = int(f[1])
            if not 0 <= slot < 4: raise ValueError('Bad memory slot')
            if kind == 'E':
                if slot in slots and slots[slot][1]: raise ValueError('Readable slot reported error')
                if not 0 <= int(f[2]) < 256: raise ValueError('Bad invalid-read index')
                invalid += 1
            else:
                if slot not in slots or not slots[slot][1]: raise ValueError('Release of incomplete slot')
                if read_counts.get(slots[slot][0], 0) != 256: raise ValueError('Released before full readback')
                del slots[slot]; releases += 1
            continue
        if kind not in ('J', 'W', 'S', 'A', 'R'): raise ValueError('Unknown memory record')
        i = int(f[1])
        if not 0 <= i < len(rows): raise ValueError('Bad memory case')
        c = rows[i]
        if kind == 'J':
            core, slot, job_id = map(int, f[2:])
            if core not in (0, 1) or core in live or not 0 <= slot < 4 or slot in slots:
                raise ValueError('Memory allocation reused live owner')
            if i in opened or job_id != c['id']: raise ValueError('Repeated/wrong memory descriptor')
            opened[i] = (core, slot); counts[i] = read_counts[i] = 0
            slots[slot] = (i, False); live[core] = i
        elif kind == 'R':
            slot, index = map(int, f[2:4])
            if slots.get(slot) != (i, True) or opened.get(i, (None,None))[1] != slot:
                raise ValueError('Read before commit, after release/reset, or from wrong slot')
            if index != read_counts.get(i) or index >= 256: raise ValueError('Read order/count mismatch')
            if (int(f[4],16) != c['values'][index] or
                list(map(int,f[5:])) != [c['id'],c['mode'],c['param'],int(c['mode']==0)]):
                raise ValueError('Memory data or metadata mismatch')
            reads += 1; read_counts[i] += 1
        else:
            core = int(f[2])
            if live.get(core) != i: raise ValueError('Write/status without live owner')
            slot = opened[i][1]
            if kind == 'W':
                index = int(f[3])
                if index != counts[i] or index >= len(c['values']): raise ValueError('Write index mismatch')
                if int(f[4],16) != c['values'][index] or int(f[5]) != int(index==255):
                    raise ValueError('Write data/last mismatch')
                counts[i] += 1; writes += 1
            else:
                if kind == 'S':
                    if c['abort'] or int(f[3]) != c['code'] or counts[i] != len(c['values']):
                        raise ValueError('Incorrect memory completion')
                    if c['code']==0: slots[slot] = (i,True)
                    else: del slots[slot]
                elif not c['abort'] or int(f[3]) != counts[i]:
                    raise ValueError('Incorrect memory abort')
                finished[i] = kind; del live[core]
    successful = [c['i'] for c in rows if not c['abort'] and c['code']==0]
    combinations = {(opened[i][0],rows[i]['mode'],rows[i]['param']) for i in successful}
    if (len(opened)!=104 or len(finished)!=104 or live or slots or
        footer != [104,88,8,8,writes,reads] or reads!=22528 or releases!=88 or
        invalid<90 or resets!=5 or len(combinations)!=24 or any(read_counts[i]!=256 for i in successful)):
        raise ValueError('Incomplete memory lifecycle/readback gate')
    return (f'DILITHIUM STAGE3 COMPARE PASS:104 jobs,88 complete,8 expected errors,8 reset aborts;'
            f'{writes} exact writes,22528 exact readbacks;88 releases,{invalid} invalid reads,5 resets\n')


@lru_cache(maxsize=128)
def arithmetic_result(operation, a, b=()):
    if operation in (0,3): return tuple(ntt_reference.direct_forward(list(a)))
    if operation==1:return tuple(ntt_reference.direct_inverse(list(a)))
    return tuple(ntt_reference.pointwise(list(a),list(b)))


def verify_ntt(lines,banked=False):
    rows, token=check()
    if not lines or lines[0]!='H '+token:raise ValueError('NTT capture token differs')
    slots={};jobs={};live={};operations={};pending=None;footer=None
    samples=successes=rejections=aborts=writes=results=reads=resets=loads=releases=invalid=0
    op_kinds=set();rejection_kinds=set();sample_modes=set();regions=set();physical=acks=0
    capacity=64 if banked else 4;witnesses=None
    def eligibility(o):
        if banked and (o['dest']==o['a'] or (o['op']==2 and o['dest']==o['b'])):return 3
        a=slots.get(o['a']);b=slots.get(o['b']);op=o['op']
        if (a is None or a['state']!='complete' or a['id']!=o['aid'] or
            (op==2 and (b is None or b['state']!='complete' or b['id']!=o['bid']))):return 1
        if ((op in (0,3) and a['domain']) or (op in (1,2) and not a['domain']) or
            (op==3 and any(4<v<ntt_reference.Q-4 for v in a['values'])) or
            (op==2 and (not b['domain'] or b['param']!=a['param']))):return 2
        return 0
    for line in lines[1:]:
        if footer is not None:raise ValueError('Records after NTT footer')
        f=line.split();kind=f[0]
        if kind=='F':footer=list(map(int,f[1:]));continue
        if banked and kind=='G':
            if witnesses is not None:raise ValueError('Duplicate bank witnesses')
            witnesses=list(map(int,f[1:]));continue
        if kind=='X':
            if live or pending is not None:raise ValueError('Reset lacks abort/retirement records')
            slots.clear();resets+=1;continue
        if banked and kind in ('P','Q'):
            family=f[1];owner,region,word=map(int,f[2:5])
            if family not in ('S','N'):raise ValueError('Invalid packed writer')
            o=jobs.get(owner) if family=='S' else operations.get(owner)
            if o is None or (family=='S' and (live.get(o['core'])!=owner or o['done'])) or (family=='N' and (pending!=owner or o['code']!=0)):
                raise ValueError('Packed word without owner')
            dest=o['slot'] if family=='S' else o['dest']
            values=slots[dest]['values'];pc=o.get('packed',0);ac=o.get('acks',0)
            if region!=dest or not 0<=word<64:raise ValueError('Packed region/address mismatch')
            if kind=='P':
                expected=sum(values[4*word+lane]<<(23*lane) for lane in range(4))
                if word!=pc or o['count']<4*(word+1) or int(f[5],16)!=expected:raise ValueError('Packed value/order mismatch')
                o['packed']=pc+1;physical+=1
            else:
                if word!=ac or ac>=pc:raise ValueError('Packed acknowledgement without write')
                o['acks']=ac+1;acks+=1
            continue
        if kind=='J':
            j,c,core,s,jobid=map(int,f[1:])
            if (j!=samples or not 0<=c<len(rows) or rows[c]['code']!=0 or core not in (0,1) or
                core in live or not 0<=s<capacity or s in slots or pending is not None):
                raise ValueError('Bad sampled allocation')
            jobs[j]=dict(case=c,core=core,slot=s,count=0,done=False);live[core]=j
            r=rows[c];slots[s]=dict(id=jobid,mode=r['mode'],param=r['param'],domain=int(r['mode']==0),
                                  values=r['values'],state='writing',reads=0)
            sample_modes.add(r['mode']);regions.add(s);samples+=1;continue
        if kind in ('W','S'):
            j=int(f[1]);job=jobs.get(j)
            if job is None or live.get(job['core'])!=j or job['done']:raise ValueError('Sample without owner')
            s=slots[job['slot']]
            if kind=='W':
                index=int(f[2])
                if index!=job['count'] or index>=256 or int(f[3],16)!=s['values'][index] or int(f[4])!=int(index==255):
                    raise ValueError('Sample write mismatch')
                job['count']+=1;writes+=1
            else:
                if job['count']!=256 or list(map(int,f[2:]))!=[s['id'],0]:raise ValueError('Premature/wrong sample status')
                if banked and (job.get('packed')!=64 or job.get('acks')!=64):raise ValueError('Sample published before packed acknowledgements')
                s['state']='complete';job['done']=True;del live[job['core']]
            continue
        if kind=='O':
            run,op,a,aid,b,bid,resultid=map(int,f[1:8])
            if run!=len(operations) or op not in range(4) or a not in range(capacity) or b not in range(capacity) or pending is not None or live:
                raise ValueError('Overlapping/invalid compute command')
            operations[run]=dict(op=op,a=a,aid=aid,b=b,bid=bid,id=resultid,code=None,count=0,loads=0,done=False)
            if banked:operations[run]['dest']=int(f[8])
            pending=run;continue
        if kind in ('V','T','K','D','B'):
            run=int(f[1]);o=operations.get(run)
            if o is None or pending!=run or o['done']:raise ValueError('NTT event without live operation')
            if kind=='V':
                code,dest=map(int,f[2:])
                if o['code'] is not None or code!=eligibility(o):raise ValueError('Wrong reservation/domain decision')
                if banked and dest!=o['dest']:raise ValueError('Changed requested destination')
                o['code']=code;o['dest']=dest
                if code==0:
                    if dest not in range(capacity) or dest in slots:raise ValueError('Overwritten live polynomial')
                    a=slots[o['a']];b=slots.get(o['b'])
                    o['a_values']=tuple(a['values']);o['b_values']=tuple(b['values']) if o['op']==2 else ()
                    o['expected']=arithmetic_result(o['op'],o['a_values'],o['b_values'])
                    a['state']='in_use'
                    if o['op']==2:b['state']='in_use'
                    slots[dest]=dict(id=o['id'],mode=a['mode'],param=a['param'],domain=int(o['op']!=1),
                                     values=o['expected'],state='writing',reads=0)
                    regions.add(dest)
                elif not banked and dest!=0:raise ValueError('Rejected reservation returned destination')
            elif kind=='T':
                index,s,jobid,coefficient=map(int,f[2:6]);value=int(f[6],16)
                source=o['a'] if index<256 else o['b'];srcid=o['aid'] if index<256 else o['bid']
                expected=o.get('a_values',()) if index<256 else o.get('b_values',())
                if (o['code']!=0 or index!=o['loads'] or not expected or index>=len(o['a_values'])+len(o['b_values']) or
                    s!=source or jobid!=srcid or coefficient!=index%256 or value!=expected[index%256]):
                    raise ValueError('DMA operand/value/tag/order mismatch')
                o['loads']+=1;loads+=1
            elif kind=='K':
                index=int(f[2])
                if (o['code']!=0 or o['loads']!=(512 if o['op']==2 else 256) or index!=o['count'] or index>=256 or
                    int(f[3],16)!=o['expected'][index] or int(f[4])!=int(index==255)):
                    raise ValueError('NTT output/last mismatch')
                o['count']+=1;results+=1
            elif kind=='D':
                code,dest,resultid=map(int,f[2:])
                if code!=o['code'] or dest!=o['dest'] or resultid!=o['id']:raise ValueError('Wrong compute retirement')
                if code==0:
                    if o['count']!=256 or o['loads']!=(512 if o['op']==2 else 256):raise ValueError('Premature compute commit')
                    if banked and (o.get('packed')!=64 or o.get('acks')!=64):raise ValueError('Result published before packed acknowledgements')
                    slots[dest]['state']='complete';slots[o['a']]['state']='complete'
                    if o['op']==2:slots[o['b']]['state']='complete'
                    successes+=1;op_kinds.add(o['op'])
                else:
                    if o['count'] or o['loads']:raise ValueError('Rejected compute changed arithmetic')
                    rejections+=1;rejection_kinds.add(code)
                o['done']=True;pending=None
            else:
                if o['code']!=0 or int(f[2])!=o['count']:raise ValueError('Bad compute abort')
                o['done']=True;pending=None;aborts+=1
            continue
        if kind in ('R','E','L'):
            s=int(f[1]);v=slots.get(s)
            if not 0<=s<capacity:raise ValueError('Bad read/release slot')
            if kind=='E':
                if v is not None and v['state']=='complete':raise ValueError('Readable slot rejected')
                if not 0<=int(f[2])<256:raise ValueError('Bad rejected read index')
                invalid+=1
            elif kind=='L':
                if (v is None or v['state']!='complete' or v['reads']!=256 or
                    (banked and pending is not None and (s==operations[pending]['a'] or
                     (operations[pending]['op']==2 and s==operations[pending]['b'])))):
                    raise ValueError('Release of locked/incomplete/unread slot')
                del slots[s];releases+=1
            else:
                index=int(f[2])
                if (v is None or v['state']!='complete' or index!=v['reads'] or index>=256 or
                    int(f[3],16)!=v['values'][index] or
                    list(map(int,f[4:]))!=[v['id'],v['mode'],v['param'],v['domain']]+(
                      [int(all(x<=4 or x>=ntt_reference.Q-4 for x in v['values']))] if banked else [])):
                    raise ValueError('Stored NTT value/domain/metadata mismatch')
                v['reads']+=1;reads+=1
            continue
        raise ValueError('Unknown Stage4 capture record')
    commands=54 if banked else 50;reject_count=21 if banked else 17
    if (footer!=[16,commands,30,reject_count,3,4096,results,11776] or samples!=16 or len(operations)!=commands or
        (successes,rejections,aborts,writes,reads,resets,releases)!=(30,reject_count,3,4096,11776,4,43) or
        (not banked and loads!=9745) or
        slots or live or pending is not None or any(not j['done'] for j in jobs.values()) or
        any(not o['done'] for o in operations.values()) or op_kinds!={0,1,2,3} or
        rejection_kinds!=({1,2,3} if banked else {1,2}) or sample_modes!={0,1,2,3} or invalid!=6):
        raise ValueError(f'Incomplete Stage4 gate:{samples,len(operations),successes,rejections,aborts,writes,results,reads,resets,loads,releases}')
    if banked:
        aborted_ops=[o for o in operations.values() if o['code']==0 and o['count']<256]
        if ([o['loads'] for o in aborted_ops][1:]!=[256,256] or
            not 17<=aborted_ops[0]['loads']<=18 or [o['count'] for o in aborted_ops][:2]!=[0,0] or
            not 32<=aborted_ops[2]['count']<=33 or {s//16 for s in regions}!={0,1,2,3} or
            not any(o['code']==0 and o['a']//16==o['dest']//16 for o in operations.values())):
            raise ValueError('Incomplete bank/abort campaign')
        if witnesses is None or witnesses[0]<18 or witnesses[1:]!=[33,4,120]:raise ValueError('Missing ownership witnesses')
        return (f'DILITHIUM STAGE5F BANK NTT COMPARE PASS:16 sample jobs,54 commands,30 results,21 rejections,3 aborts;'
                f'4096 sample coefficients,{loads} DMA values,{results} NTT outputs,2944 exact packed readbacks;'
                f'{physical} packed writes,{acks} acknowledgements;all four banks\n')
    return (f'DILITHIUM STAGE4 COMPARE PASS:16 sampled jobs,50 commands,30 arithmetic results,17 rejected,3 reset aborts;'
            f'4096 sampled coefficients,{loads} DMA operands,{results} NTT outputs,11776 exact stored readbacks\n')


def verify_process(lines):
    _,token=check();rows=process_cases()
    if not lines or lines[0]!='H '+token:raise ValueError('Process capture token differs')
    opened=set();finished=set();queue=[];footer=None;resets=complete=aborts=errors=0
    for line in lines[1:]:
        if footer is not None:raise ValueError('Record after process footer')
        f=line.split();kind=f[0]
        if kind=='F':footer=list(map(int,f[1:]));continue
        if kind=='X':
            if queue:raise ValueError('Reset omitted accepted abort')
            resets+=1;continue
        if kind not in ('J','P','A'):raise ValueError('Unknown process record')
        i=int(f[1])
        if not 0<=i<len(rows):raise ValueError('Unknown process case')
        r=rows[i]
        if kind=='J':
            if i!=len(opened) or i in opened or queue:raise ValueError('Process input sequence/elastic ownership')
            opened.add(i);queue.append(i)
        else:
            if not queue or queue.pop(0)!=i or i in finished:raise ValueError('Output/abort without matching input')
            if kind=='A':
                if not r[7]:raise ValueError('Unexpected process abort')
                aborts+=1
            else:
                if r[7] or list(map(int,f[2:]))!=r[8:13]+[r[4],r[5],r[6],r[1]]:
                    raise ValueError('Process arithmetic/rounding/framing/tag mismatch')
                complete+=1;errors+=r[8]
            finished.add(i)
    if (len(opened)!=len(rows) or len(finished)!=len(rows) or queue or resets!=4 or aborts!=3 or
        complete!=len(rows)-3 or errors!=13 or footer!=[len(rows),complete,3,13]):
        raise ValueError('Incomplete process gate')
    return (f'DILITHIUM STAGE5 PROCESS COMPARE PASS:{len(rows)} accepted,{complete} exact outputs,'
            '3 reset aborts,13 expected errors;all canonical high-part rounding boundaries exercised\n')


def verify_hash_format(lines):
    _,token=check();rows=hash_format_cases()
    if not lines or lines[0]!='H '+token:raise ValueError('Hash-format capture token')
    opened=set();finished=set();state=None;totals=[0]*6;footer=None;resets=0;cores=set()
    for line in lines[1:]:
        if footer is not None:raise ValueError('Record after hash-format footer')
        f=line.split();kind=f[0]
        if kind=='X':
            if state is not None:raise ValueError('Reset without formatter abort')
            resets+=1;continue
        if kind=='F':footer=list(map(int,f[1:]));continue
        i=int(f[1])
        if not 0<=i<len(rows):raise ValueError('Unknown formatter case')
        r=rows[i]
        if kind=='J':
            if state is not None or i!=len(opened):raise ValueError('Formatter ownership/sequence')
            opened.add(i);state=dict(i=i,d=0,w=0,v=0,s=0);totals[0]+=1;continue
        if state is None or state['i']!=i:raise ValueError('Unowned formatter event')
        if kind=='D':
            if r['error'] or state['d'] or list(map(int,f[2:]))!=[r['mode'],len(r['message']),r['outlen']]:
                raise ValueError('SHAKE descriptor mismatch')
            state['d']=1
        elif kind=='W':
            n=state['w'];word=r['message'][8*n:8*n+8].ljust(8,b'\0')
            if not state['d'] or int(f[2])!=n or n*8>=len(r['message']) or int(f[3],16)!=int.from_bytes(word,'little'):
                raise ValueError('Seed/nonce absorption message mismatch')
            state['w']+=1;totals[4]+=1
        elif kind=='V':
            n=state['v'];core=int(f[4]);offset=16*n
            if (not state['d'] or state['w']!=(len(r['message'])+7)//8 or int(f[2])!=n or
                int(f[3])!=16 or core not in (0,1) or offset>=len(r['digest']) or
                int(f[5],16)!=int.from_bytes(r['digest'][offset:offset+16],'little')):
                raise ValueError('SHAKE output mismatch')
            if n and core!=state['core']:raise ValueError('Hash core changed within job')
            state['core']=core;cores.add(core);state['v']+=1;totals[5]+=1
        elif kind=='S':
            if state['s'] or list(map(int,f[2:]))!=[r['id'],r['error']]:raise ValueError('Formatter completion mismatch')
            if state['w']!=(len(r['message'])+7)//8:raise ValueError('Completion before full message')
            state['s']=1;totals[1]+=1;totals[2]+=r['error']
        elif kind=='A':
            if not r['abort'] or int(f[2])!=r['abort'] or state['s'] or state['v']:
                raise ValueError('Unexpected formatter abort')
            if (state['d'],state['w'])!=[(0,0),(1,2),(1,5)][r['abort']-1]:raise ValueError('Wrong reset phase')
            totals[3]+=1;finished.add(i);state=None
        elif kind=='E':
            if r['abort'] or not state['s'] or state['d']!=int(not r['error']) or state['v']!=len(r['digest'])//16:
                raise ValueError('Incomplete formatter/hash result')
            finished.add(i);state=None
        else:raise ValueError('Unknown formatter record')
    if (state is not None or len(opened)!=len(rows) or len(finished)!=len(rows) or resets!=4 or
        cores!={0,1} or totals!=footer or totals[3]!=3):raise ValueError('Incomplete formatter gate')
    return (f'DILITHIUM STAGE5 HASH FORMAT COMPARE PASS:{totals[0]} accepted,'
            f'{totals[1]} completions,{totals[2]} expected errors,3 reset aborts;'
            f'{totals[4]} absorption words,{16*totals[5]} exact SHAKE bytes;'
            'all102 matrix entries and34 secret nonces across levels2/3/5\n')


def verify_shared_hash(lines):
    _,token=check();rows=shared_hash_cases()
    if not lines or lines[0]!='H '+token:raise ValueError('Shared hash capture token')
    jobs={};owners={};finished=set();resets=0;footer=None;totals=[0]*7
    for line in lines[1:]:
        if footer is not None:raise ValueError('Record after shared footer')
        f=line.split();kind=f[0]
        if kind=='X':
            if owners or any(i not in finished for i in jobs):raise ValueError('Reset omitted live owner/abort')
            resets+=1;continue
        if kind=='F':footer=list(map(int,f[1:]));continue
        i=int(f[1])
        if not 0<=i<len(rows):raise ValueError('Unknown shared case')
        r=rows[i]
        if kind=='J':
            if i in jobs:raise ValueError('Duplicate shared command')
            jobs[i]=dict(desc=False,w=0,n=0,c=0,d=False);totals[0]+=1;continue
        if i not in jobs or i in finished:raise ValueError('Unowned/retired shared event')
        s=jobs[i]
        if kind in ('R','S'):
            core=int(f[2])
            if core not in (0,1) or core in owners or s['desc'] or r['error']:
                raise ValueError('Descriptor overwrote owner')
            expected=([r['id'],r['mode'],r['p'],len(r['message'])] if kind=='S' else
                      [r['id'],r['mode'],len(r['message']),r['outlen']])
            if list(map(int,f[3:]))!=expected or (kind=='S')!=(r['kind']==2):raise ValueError('Shared descriptor mismatch')
            s['desc']=True;s['core']=core;owners[core]=i;totals[2 if kind=='S' else 1]+=1
        elif kind in ('W','P'):
            n=s['w'];word=r['message'][8*n:8*n+8].ljust(8,b'\0')
            if (not s['desc'] or (kind=='P')!=(r['kind']==2) or int(f[2])!=n or
                n*8>=len(r['message']) or int(f[3],16)!=int.from_bytes(word,'little')):
                raise ValueError('Shared absorption mismatch')
            s['w']+=1
        elif kind=='O':
            core,job_id,offset,n=map(int,f[2:6]);rate=136 if r['mode'] else 168
            expected_n=min(16,len(r['digest'])-s['n'],rate-s['n']%rate)
            expected=r['digest'][s['n']:s['n']+n]
            if (r['kind']==2 or owners.get(core)!=i or job_id!=r['id'] or offset!=s['n'] or
                n!=expected_n or n<=0 or s['w']!=(len(r['message'])+7)//8 or
                int(f[6],16)&((1<<(8*n))-1)!=int.from_bytes(expected,'little')):
                raise ValueError(f'Shared raw bytes/tag mismatch:case{i},offset{offset}')
            s['n']+=n;totals[5]+=n
        elif kind=='D':
            core,job_id=map(int,f[2:])
            if owners.get(core)!=i or job_id!=r['id'] or s['d'] or s['n']!=len(r['digest']):
                raise ValueError('Premature/wrong raw completion')
            s['d']=True;del owners[core]
            if r['kind']==0:finished.add(i)
        elif kind=='Z':
            error,job_id,p=map(int,f[2:5]);material=bytes(128) if r['error'] else r['digest']
            expected=[int.from_bytes(material[:32],'little'),int.from_bytes(material[32:96],'little'),
                      int.from_bytes(material[96:128],'little')]
            if (r['kind']!=1 or r['abort'] or [error,job_id,p]!=[r['error'],r['id'],r['p']] or
                list(int(v,16) for v in f[5:])!=expected or s['desc']!=bool(not error) or
                (not error and not s['d'])):raise ValueError('Seed material/metadata mismatch')
            totals[3]+=1;finished.add(i)
        elif kind=='C':
            core,job_id,index=map(int,f[2:5])
            if (r['kind']!=2 or owners.get(core)!=i or job_id!=r['id'] or index!=s['c'] or index>=256 or
                int(f[5],16)!=r['values'][index] or int(f[6])!=int(index==255) or
                s['w']!=(len(r['message'])+7)//8):raise ValueError('Derived-seed sampler mismatch')
            s['c']+=1;totals[6]+=1
        elif kind=='T':
            core,code=map(int,f[2:])
            if owners.get(core)!=i or r['kind']!=2 or code!=0 or s['c']!=256:raise ValueError('Sampling completion mismatch')
            del owners[core];finished.add(i)
        elif kind=='A':
            if not r['abort'] or int(f[2])!=r['abort']:raise ValueError('Unexpected shared abort')
            if (s['w'],s['n'],s['d'])!=[(2,0,False),(5,16,False),(5,128,True)][r['abort']-1]:
                raise ValueError('Shared reset phase mismatch')
            if owners.get(s.get('core'))==i:del owners[s['core']]
            totals[4]+=1;finished.add(i)
        else:raise ValueError('Unknown shared event')
    if (len(jobs)!=len(rows) or len(finished)!=len(rows) or owners or resets!=4 or totals!=footer or
        totals!=[26,18,7,7,3,1699,1792]):raise ValueError('Incomplete shared hash gate')
    return ('DILITHIUM STAGE5 SHARED HASH COMPARE PASS:26 commands,18 raw hashes,7 sampled polynomials,'
            '7 seed results(including1 expected parameter error),3 reset aborts;1699 exact SHAKE bytes,'
            '1792 exact coefficients from RTL-collected seeds;both raw and sampled ownership checked\n')


def verify_bank_memory(lines):
    _,token=check();rows=bank_memory_cases()
    if not lines or lines[0]!='H '+token:raise ValueError('Bank capture token')
    memory={};pending={};opened=set();finished=set();expected={};totals=[0]*5;resets=0;footer=None
    for line in lines[1:]:
        if footer is not None:raise ValueError('Record after bank footer')
        f=line.split();kind=f[0]
        if kind=='F':footer=list(map(int,f[1:]));continue
        if kind=='X':
            if pending:raise ValueError('Reset omitted bank response abort')
            resets+=1;continue # payload survives reset;ownership does not
        i=int(f[1])
        if not 0<=i<len(rows):raise ValueError('Unknown bank command')
        r=rows[i];_,phase,b,p,write,address,data=r;port=(b,p)
        if kind=='J':
            cycle=int(f[2])
            if i in opened or port in pending or phase==7 or list(map(int,f[3:7]))!=[b,p,write,address] or int(f[7],16)!=data:
                raise ValueError('Bank accepted request/order mismatch')
            opened.add(i);pending[port]=i;expected[i]=(cycle,None if write else memory.get((b,address)))
            if not write and expected[i][1] is None:raise ValueError('Read of uninitialized test word')
            if write:memory[b,address]=data
            totals[0]+=1
        elif kind=='R':
            cycle=int(f[2])
            if pending.get(port)!=i or i in finished or list(map(int,f[3:7]))!=[b,p,write,address] or cycle<=expected[i][0]:
                raise ValueError('Bank response ownership/latency mismatch')
            if not write and int(f[7],16)!=expected[i][1]:raise ValueError(f'Bank read mismatch:bank{b},word{address}')
            del pending[port];finished.add(i);totals[1]+=1;totals[4 if write else 3]+=1
        elif kind=='A':
            if phase!=6 or list(map(int,f[2:]))!=[b,p] or pending.get(port)!=i:raise ValueError('Unexpected bank abort')
            del pending[port];finished.add(i);totals[2]+=1
        else:raise ValueError('Unknown bank record')
    required={r[0] for r in rows if r[1]!=7}
    reads=sum(r[4]==0 for r in rows if r[1]!=7)
    if (opened!=required or finished!=required or pending or resets!=2 or totals!=footer or
        totals!=[len(required),len(required)-8,8,reads,len(required)-8-reads]):raise ValueError('Incomplete bank gate')
    return (f'DILITHIUM STAGE5 BANKS COMPARE PASS:{totals[0]} accepted,{totals[1]} responses,'
            f'{totals[3]} exact92-bit reads,{totals[4]} write acknowledgements,8 reset-aborted acknowledgements;'
            'all4096 words initialized/read across four1024x92-bit banks;8 blocked offers canceled\n')


def verify_bank_store(lines):
    rows,token=check()
    if not lines or lines[0]!='H '+token:raise ValueError('Bank-store capture token')
    jobs={};owners={};regions={};totals=[0]*8;resets=0;invalid=0;footer=None;fault_gate=False
    def slot_for(i):return {1:16,16:1,3:17,17:3}.get(i%64,i%64)
    def packed(r,w):return sum(v<<(23*k) for k,v in enumerate(r['values'][4*w:4*w+4]))
    for line in lines[1:]:
        if footer is not None:raise ValueError('Record after bank-store footer')
        f=line.split();kind=f[0]
        if kind=='F':footer=list(map(int,f[1:]));continue
        if kind=='G':
            if fault_gate or f!=['G','8']:raise ValueError('Missing protocol fault gate')
            fault_gate=True;continue
        if kind=='X':
            if owners:raise ValueError('Bank reset omitted live-job abort')
            regions.clear();resets+=1;continue
        if kind=='L':
            s=int(f[1]);i=regions.get(s)
            if i is None or jobs[i]['done']!='S' or rows[i]['code'] or jobs[i]['read']!=64:
                raise ValueError('Release uncommitted/unread region')
            del regions[s];continue
        if kind=='E':
            s,w=map(int,f[1:]);i=regions.get(s)
            if not 0<=s<64 or not 0<=w<64 or (i is not None and jobs[i]['done']=='S'):
                raise ValueError('Readable region reported as error')
            invalid+=1;continue
        i=int(f[1])
        if not 0<=i<len(rows):raise ValueError('Unknown bank-store job')
        r=rows[i]
        if kind=='J':
            core,s,job_id=map(int,f[2:])
            if i in jobs or core not in (0,1) or core in owners or s in regions or s!=slot_for(i) or job_id!=r['id']:
                raise ValueError('Bank region/context ownership overwrite')
            jobs[i]=dict(core=core,slot=s,n=0,k=0,b=0,read=0,done=None);owners[core]=i;regions[s]=i;totals[0]+=1;continue
        if i not in jobs:raise ValueError('Bank-store event without command')
        j=jobs[i];s=j['slot']
        if kind=='R':
            small=int(all(v<=4 or v>=8_380_413 for v in r['values']))
            if (regions.get(s)!=i or j['done']!='S' or r['code'] or int(f[2])!=s or int(f[3])!=j['read'] or
                j['read']>=64 or int(f[4],16)!=packed(r,j['read']) or
                list(map(int,f[5:]))!=[r['id'],r['mode'],r['param'],int(r['mode']==0),small]):
                raise ValueError('Bank packed readback/metadata mismatch')
            j['read']+=1;totals[7]+=1;continue
        if j['done'] is not None or owners.get(j['core'])!=i or regions.get(s)!=i:
            raise ValueError('Bank traffic after retirement/abort')
        if kind=='W':
            core,index,value,last=int(f[2]),int(f[3]),int(f[4],16),int(f[5])
            if core!=j['core'] or index!=j['n'] or index>=len(r['values']) or value!=r['values'][index] or last!=int(index==255):
                raise ValueError('Bank input coefficient mismatch')
            j['n']+=1;totals[4]+=1
        elif kind=='K':
            if int(f[2])!=s or int(f[3])!=j['k'] or 4*j['k']+4>j['n'] or int(f[4],16)!=packed(r,j['k']):
                raise ValueError('Packed four-lane physical write mismatch')
            j['k']+=1;totals[5]+=1
        elif kind=='B':
            if int(f[2])!=s or int(f[3])!=j['b'] or j['b']>=j['k']:raise ValueError('Bank acknowledgement order/owner')
            j['b']+=1;totals[6]+=1
        elif kind=='S':
            if (r['abort'] or list(map(int,f[2:]))!=[j['core'],r['code']] or j['n']!=len(r['values']) or
                (r['code']==0 and (j['k'],j['b'])!=(64,64))):raise ValueError('Premature bank publication')
            j['done']='S';del owners[j['core']];totals[2 if r['code'] else 1]+=1
            if r['code']:del regions[s]
        elif kind=='A':
            if not r['abort'] or list(map(int,f[2:]))!=[j['core'],j['n']]:raise ValueError('Wrong bank reset abort')
            j['done']='A';del owners[j['core']];totals[3]+=1
        else:raise ValueError('Unknown bank-store record')
    combinations={(j['core'],rows[i]['mode'],rows[i]['param']) for i,j in jobs.items() if not rows[i]['code'] and not rows[i]['abort']}
    if (len(jobs)!=104 or owners or any(j['done'] is None for j in jobs.values()) or totals!=footer or
        totals[:4]!=[104,88,8,8] or totals[7]!=5632 or resets!=5 or invalid!=11 or not fault_gate or len(combinations)!=24 or
        any(j['read']!=64 for i,j in jobs.items() if not rows[i]['code'] and not rows[i]['abort'])):
        raise ValueError('Incomplete connected bank-store gate')
    return (f'DILITHIUM STAGE5 STORE COMPARE PASS:104 jobs,88 complete,8 expected errors,8 reset aborts;'
            f'{totals[4]} exact coefficients,{totals[5]} packed writes,{totals[6]} write acks;'
            '5632 exact92-bit read words=22528 complete coefficients;all64 regions/24 mode-parameter-core combinations;'
            '8 protocol fault kinds contained\n')


@lru_cache(maxsize=1)
def process_bank_program():
    program=[];owners={}
    def emit(kind,op=0,a=0,b=0,dest=0,high=0,aid=0,bid=0,jobid=0,code=0,wait=-1,abort=-1):
        program.append((kind,op,a,b,dest,high,aid,bid,jobid,code,wait,abort))
    def sample(case,region,jobid=None):
        jobid=cases()[case]['id'] if jobid is None else jobid
        emit('S',case,region,jobid=jobid);owners[region]=jobid
    def read(region,invalid=False):emit('R',region,int(invalid))
    def reset():emit('X');owners.clear()
    def ntt(op,a,b,dest):
        jobid=12000+len(program);emit('N',op,a,b,dest,aid=owners[a],bid=owners[b],jobid=jobid)
        owners[dest]=jobid;read(dest)
    def process(op,a,b,dest,high=0,code=0,da=0,db=0,wait=-1,abort=-1):
        jobid=14000+len(program)
        emit('P',op,a,b,dest,high,owners.get(a,0)+da,owners.get(b,0)+db,jobid,code,wait,abort)
        if abort>=0:owners.clear();return
        if code==0:
            if wait>=0:del owners[wait]
            owners[dest]=jobid
            if op==2:owners[high]=jobid
            read(dest)
            if op==2:read(high)
    reset()
    for p in range(3):
        sample(2*p,0);sample(6+2*p,17);sample(7+2*p,18);sample(12+2*p,19)
        process(0,17,18,1);process(1,1,18,2)
        ntt(0,17,17,32);ntt(0,18,18,33);ntt(2,0,32,48)
        process(0,48,48,49);process(1,49,48,50);ntt(1,50,50,51)
        process(0,51,17,52);process(2,52,0,3,4);ntt(0,3,3,34)
        process(1,18,17,5);process(2,19,0,6,7)
        process(0,32,33,4,wait=4);process(2,52,0,8,4,wait=4)
        sample(6+2*((p+1)%3),20)
        process(3,17,18,9,code=4);process(0,17,18,9,code=1,da=1)
        process(0,17,62,9,code=1);process(0,17,18,9,code=1,db=1)
        process(0,32,17,9,code=2);process(0,17,20,9,code=2);process(2,32,0,9,10,code=2)
        process(0,17,18,17,code=3);process(1,17,18,18,code=3)
        process(2,17,0,9,17,code=3);process(2,17,0,9,9,code=3)
        for region in sorted(owners):read(region)
        reset()
    for phase in range(4):
        sample(6,0);read(0)
        process(0 if phase<2 else 2,0,0,1,17,abort=phase)
        read(0,True);read(1,True);read(17,True)
        sample(7,0,cases()[6]['id']);process(2,0,0,1,17);read(0);reset()
    return tuple(program)


def process_bank_artifact(token):
    rows=process_bank_program()
    return f'{token} {len(rows)}\n'+'\n'.join(' '.join(map(str,row)) for row in rows)+'\n'


def verify_process_banks(lines):
    rows,token=check();program=process_bank_program();q=ntt_reference.Q
    if not lines or lines[0]!='H '+token:raise ValueError('Bank process capture token')
    slots={};pending=None;finished=set();read_counts={};reset_steps=set();witness=None;footer=None
    samples=ntts=processes=aborts=values=words=acks=reads=success=reject=inputs=outputs=atomic_seen=0
    def expect(test,message):
        if not test:raise ValueError(message)
    for line in lines[1:]:
        expect(footer is None,'Record after process footer');f=line.split();kind=f[0]
        if kind=='F':footer=list(map(int,f[1:]));continue
        if kind=='G':
            expect(witness is None,'Duplicate process witnesses');witness=list(map(int,f[1:]));continue
        step=int(f[1]);expect(0<=step<len(program),'Invalid program step');r=program[step]
        action,op,a,b,dest,high,aid,bid,jobid,code,wait,abort=r
        if kind=='X':
            expect(pending is None and step not in reset_steps,'Reset without abort/retirement')
            expect(action=='X' or (action=='P' and abort>=0 and step in finished),'Unexpected process reset')
            slots.clear();reset_steps.add(step)
            if action=='X':finished.add(step)
            continue
        if kind in ('J','O','C'):
            expect(pending is None and step not in finished,'Overlapping bank process command')
            p=dict(step=step,kind=action,op=op,id=jobid,code=0,alloc={},expected={},bindings={},commits=set(),
                   loads=0,inputs=0,outputs=0,ntt_outputs=0,wait_released=wait<0,low=[],high=[])
            if kind=='J':
                case,core,region,observedid=map(int,f[2:]);expect(action=='S' and [case,region,observedid]==[op,a,jobid] and core in (0,1),'Sample command mismatch')
                c=rows[case];expect(c['code']==0,'Unexpected bad sample case')
                p['expected'][a]=dict(id=jobid,mode=c['mode'],param=c['param'],domain=int(c['mode']==0),data=tuple(c['values']))
                p['sample_core']=core;samples+=1
            else:
                expected_args=[op,a,b,dest,aid,bid,jobid] if kind=='O' else [op,a,b,dest,high,aid,bid,jobid]
                expect(action==('N' if kind=='O' else 'P') and list(map(int,f[2:]))==expected_args,'Compute command mismatch')
                ar=slots.get(a);br=slots.get(b);binary=(op==2 if action=='N' else op<2)
                status=0
                if action=='P' and op==3:status=4
                elif dest==a or (binary and dest==b) or (action=='P' and op==2 and (high==a or high==dest)):status=3
                elif ar is None or ar['state']!='complete' or ar['id']!=aid or (binary and (br is None or br['state']!='complete' or br['id']!=bid)):status=1
                elif action=='N':
                    if ((op in (0,3) and ar['domain']) or (op in (1,2) and not ar['domain']) or
                        (op==3 and any(4<x<q-4 for x in ar['data'])) or
                        (op==2 and (not br['domain'] or ar['param']!=br['param']))):status=2
                elif (op==2 and ar['domain']) or (binary and (ar['domain']!=br['domain'] or ar['param']!=br['param'])):status=2
                expect(status==code,'Prepared process decision disagrees with independent model');p['code']=status
                if status==0:
                    p['a']=ar['data'];p['b']=br['data'] if binary else ();p['sources']={a,b} if binary else {a}
                    if action=='N':data=arithmetic_result(op,p['a'],p['b']);domain=int(op!=1)
                    elif op<2:
                        data=tuple((x+y if op==0 else x-y)%q for x,y in zip(p['a'],p['b'],strict=True));domain=ar['domain']
                    else:
                        highs=tuple((x+4095)//8192 for x in p['a']);lows=tuple(x-8192*h for x,h in zip(p['a'],highs,strict=True))
                        p['low']=lows;p['high']=highs;data=tuple(x%q for x in lows);domain=0
                        p['expected'][high]=dict(id=jobid,mode=ar['mode'],param=ar['param'],domain=0,data=highs)
                    p['expected'][dest]=dict(id=jobid,mode=ar['mode'],param=ar['param'],domain=domain,data=data)
                if action=='N':ntts+=1
                else:processes+=1
            pending=p;continue
        if kind in ('R','E'):
            expect(pending is None and action=='R','Public read while process owns bank')
            region=int(f[2]);expect(region==op,'Read region mismatch');s=slots.get(region)
            if kind=='E':
                expect(a==1 and s is None and step not in finished,'Readable/reset region incorrectly rejected');finished.add(step);continue
            word=int(f[3]);expect(a==0 and s is not None and s['state']=='complete' and word==read_counts.get(step,0) and word<64,'Word read order/publication mismatch')
            expected=sum(s['data'][4*word+lane]<<(23*lane) for lane in range(4))
            metadata=[s['id'],s['mode'],s['param'],s['domain'],int(all(x<=4 or x>=q-4 for x in s['data']))]
            expect(int(f[4],16)==expected and list(map(int,f[5:]))==metadata,'Bank process stored data/metadata mismatch')
            read_counts[step]=word+1;s['reads']+=1;reads+=1
            if word==63:finished.add(step)
            continue
        if kind=='L':
            region=int(f[2]);s=slots.get(region)
            expect(pending is not None and pending['step']==step and wait==region and not pending['wait_released'] and
                   region not in pending['sources'] and s is not None and s['state']=='complete' and s['reads']>=64,
                   'Released source/incomplete/unread/wrong waiting destination')
            del slots[region];pending['wait_released']=True;continue
        expect(pending is not None and pending['step']==step,'Process event without accepted command');p=pending
        if kind=='Y':
            expect(action=='P' and op==2 and p['code']==0 and dest in p['commits'] and
                   list(map(int,f[2:]))==[dest,high,0,0,1,0],'Power2Round partial publication visible/wrong witness')
            atomic_seen+=1;continue
        if kind=='V':
            core,region,vid,mode,param,domain=map(int,f[2:]);expected=p['expected'].get(region)
            expect(p['code']==0 and core in (0,1) and core not in p['bindings'] and region not in slots and expected is not None and
                   [vid,mode,param,domain]==[expected['id'],expected['mode'],expected['param'],expected['domain']],'Wrong process allocation/overwrite')
            if action=='P':expect(core==int(op==2 and region==high),'Power2Round destination/core mismatch')
            if action=='N':expect(core==0,'NTT result allocated wrong packer')
            if action=='S':expect(core==p['sample_core'],'Sample packer changed core')
            slots[region]=dict(**expected,state='writing',count=0,packed=0,acks=0,reads=0)
            p['bindings'][core]=region;p['alloc'][region]=core;continue
        if kind=='W':
            core,index=int(f[2]),int(f[3]);region=p['bindings'].get(core);s=slots.get(region)
            expect(s is not None and s['state']=='writing' and index==s['count'] and index<256 and
                   int(f[4],16)==s['data'][index] and int(f[5])==int(index==255),'Process coefficient write/tag/value/order mismatch')
            s['count']+=1;values+=1;continue
        if kind in ('P','Q'):
            region,word=map(int,f[2:4]);s=slots.get(region)
            expect(region in p['alloc'] and s is not None and s['state']=='writing' and word<64,'Packed process event without owner')
            if kind=='P':
                expected=sum(s['data'][4*word+lane]<<(23*lane) for lane in range(4))
                expect(word==s['packed'] and s['count']>=4*(word+1) and int(f[4],16)==expected,'Packed process value/address/order mismatch')
                s['packed']+=1;words+=1
            else:
                expect(word==s['acks'] and word<s['packed'],'Packed acknowledgement without prior write');s['acks']+=1;acks+=1
            continue
        if kind=='U':
            core=int(f[2]);region=p['bindings'].get(core);s=slots.get(region)
            expect(s is not None and s['count']==256 and s['packed']==64 and s['acks']==64 and region not in p['commits'],'Premature/duplicate process publication')
            p['commits'].add(region);continue
        if kind=='T':
            region,index=int(f[2]),int(f[3]);value=int(f[4],16);n=p['loads'];source=a if n<256 else b
            data=p['a'] if n<256 else p['b']
            expect(action=='N' and p['code']==0 and data and n<(512 if op==2 else 256) and region==source and index==n%256 and value==data[index],'Banked NTT DMA mismatch')
            p['loads']+=1;continue
        if kind=='N':
            index=int(f[2]);expect(action=='N' and p['code']==0 and index==p['ntt_outputs'] and index<256 and
                p['loads']==(512 if op==2 else 256) and int(f[3],16)==p['expected'][dest]['data'][index] and
                int(f[4])==int(index==255),'Chained NTT output mismatch')
            p['ntt_outputs']+=1;continue
        if kind=='I':
            index=int(f[2]);expect(action=='P' and p['code']==0 and index==p['inputs'] and index<256 and
                int(f[3],16)==p['a'][index] and (op==2 or int(f[4],16)==p['b'][index]),'Process DMA input mismatch')
            p['inputs']+=1;inputs+=1;continue
        if kind=='K':
            index=int(f[2]);expect(action=='P' and p['code']==0 and index==p['outputs'] and index<p['inputs'],'Process output without ordered input')
            residue=p['expected'][dest]['data'][index] if op<2 else 0
            h=p['high'][index] if op==2 else 0;l=p['low'][index] if op==2 else 0;t0=4096-l if op==2 else 0
            expect(list(map(int,f[3:6]))==[0,op,jobid] and int(f[6],16)==residue and
                   list(map(int,f[7:]))==[h,l,t0,int(index==255)],'Process arithmetic/rounding/tag mismatch')
            p['outputs']+=1;outputs+=1;continue
        if kind in ('S','D'):
            if kind=='S':expect(action=='S' and list(map(int,f[2:]))==[jobid,0],'Sample retirement mismatch')
            else:
                expect(f[2]==action and list(map(int,f[3:]))==[p['code'],jobid,dest,high],'Process retirement metadata mismatch')
                if p['code']==0:
                    expect(p['wait_released'],'Busy destination was silently overwritten')
                    expect((action=='N' and p['ntt_outputs']==256) or (action=='P' and p['inputs']==256 and p['outputs']==256),'Incomplete arithmetic completion')
                    if action=='P':success+=1
                else:
                    expect(not p['alloc'] and p['inputs']==0 and p['outputs']==0,'Rejected process had side effects');reject+=1
            expect(set(p['expected'])==p['commits'],'Completion before every destination committed')
            for region in p['alloc']:slots[region]['state']='complete'
            finished.add(step);pending=None;continue
        if kind=='A':
            phase,seen=map(int,f[2:]);expect(action=='P' and phase==abort and phase in range(4) and seen==p['inputs'],'Wrong process reset target')
            expect((phase==0 and seen==0) or (phase==1 and seen==9) or
                   (phase==2 and seen==9 and slots[dest]['count']==9 and slots[high]['count']==8) or
                   (phase==3 and p['commits']=={dest} and p['outputs']==256),'Reset did not reach required process boundary')
            aborts+=1;finished.add(step);pending=None;continue
        raise ValueError('Unknown bank process record:'+kind)
    expect(finished==set(range(len(program))) and pending is None and not slots,'Missing/unfinished process program actions')
    expect((samples,ntts,processes,aborts,success,reject)==(23,15,71,4,34,33),'Incomplete process campaign')
    expect(footer==[samples,ntts,processes,aborts,values,words,reads],'Process footer differs from observed ledger')
    expect(witness==[36,188,4,atomic_seen] and atomic_seen>=6,'Missing process ownership/atomicity witnesses')
    return (f'DILITHIUM STAGE5G BANK PROCESS COMPARE PASS:23 sample jobs,15 NTT commands,71 process commands;'
            f'34 process successes,33 expected rejections,4 reset aborts;{inputs} process inputs,{outputs} exact process outputs;'
            f'{values} coefficient writes,{words} packed writes,{acks} acknowledgements,{reads} exact92-bit reads\n')


@lru_cache(maxsize=1)
def row_cases():
    result=[]
    for p,(k,l) in enumerate(((4,4),(6,5),(8,7))):
        xi=hashlib.sha256(f'banked-row-level-{p}'.encode()).digest()
        material=hashlib.shake_256(xi+bytes((k,l))).digest(128)
        for mode,row,col in [(1,0,j) for j in range(l)]+[(0,i,j) for i in range(2) for j in range(l)]:
            message=(material[32:96]+col.to_bytes(2,'little')) if mode else material[:32]+bytes((col,row))
            stream=(hashlib.shake_128 if mode==0 else hashlib.shake_256)(message).digest(4096)
            values,_=reference.sample(mode,p,stream);i=len(result)
            result.append(dict(case=i,id=2000+i,mode=mode,param=p,row=row,col=col,message=message,values=tuple(values)))
    assert len(result)==48
    return result


def row_sample_artifact(token):
    return f'{token} 48\n'+'\n'.join(f"{c['case']} {c['id']} {c['mode']} {c['param']} {c['row']} {c['col']} {len(c['message'])} {c['message'].hex()}" for c in row_cases())+'\n'


@lru_cache(maxsize=6)
def row_expected(p,row):
    table={(c['mode'],c['param'],c['row'],c['col']):c['values'] for c in row_cases()}
    total=[0]*256
    for j in range((4,5,7)[p]):
        product=arithmetic_result(2,table[0,p,row,j],arithmetic_result(0,table[1,p,0,j]))
        total=[(x+y)%ntt_reference.Q for x,y in zip(total,product,strict=True)]
    return arithmetic_result(1,tuple(total))


def row_expected_artifact(token):
    return f'{token} 6\n'+'\n'.join(f'{p} {row} '+' '.join(f'{v:06x}' for v in row_expected(p,row)) for p in range(3) for row in range(2))+'\n'


def row_scenarios():
    return sum(([(p,0,-1,-1)]+[(p,1,v,-1) for v in range(9)]+[(p,1,-1,-1)] for p in range(3)),[])+sum(([(0,0,-1,phase),(0,1,-1,-1)] for phase in range(7)),[])


def verify_rows(lines):
    _,token=check();q=ntt_reference.Q;fixtures=row_cases();scenarios=row_scenarios()
    if not lines or lines[0]!='H '+token:raise ValueError('Row capture freshness')
    lookup={(c['mode'],c['param'],c['row'],c['col']):c for c in fixtures}
    slots={};child=None;row=None;serial=0;runs=0;footer=None;witness=None
    samples=ntts=processes=good=bad=aborts=values=words=acks=reads=rewrites=readbacks=0
    completed=set();public_reads={};partial=None
    def require(ok,message):
        if not ok:raise ValueError(message)
    def meta(s):return [s['id'],s['mode'],s['param'],s['domain']]
    for line in lines[1:]:
        require(footer is None,'Record after row footer');f=line.split();kind=f[0]
        if kind=='F':footer=list(map(int,f[1:]));continue
        if kind=='G':require(witness is None,'Duplicate row witnesses');witness=list(map(int,f[1:]));continue
        if kind=='B':
            require(row is None and child is None and runs<len(scenarios),'Overlapping/extra row')
            run,param,index,acc,tmp,out,rid=map(int,f[1:8]);p,expected_row,variant,phase=scenarios[runs];l=(4,5,7)[p]
            require(run==runs and param==(3 if variant==0 else p) and index==((4,6,8)[p] if variant==1 else expected_row) and
                acc==(48 if variant==2 else 1 if variant==3 else 16) and [tmp,out,rid]==[17,18,5000+16*p],'Wrong row command/scenario')
            descriptors=[list(map(int,f[8+4*j:12+4*j])) for j in range(7)]
            require(len(f)==36,'Wrong row descriptor length')
            for j in range(7):
                expected=[0,0,0,0]
                if j<l:
                    a=lookup[0,p,expected_row,j];s=lookup[1,p,0,j];expected=[48+j,a['id'],32+j,3000+s['case']]
                    if j==0:
                        if variant==4:expected[1]^=1
                        if variant==5:expected[3]^=1
                        if variant==6:expected[:2]=[62,lookup[0,(p+1)%3,0,0]['id']]
                        if variant==7:expected[2:]=[1,s['id']]
                        if variant==8:expected[:2]=[61,0]
                require(descriptors[j]==expected,'Wrong row operand descriptor')
            code=0
            if param==3 or index>=(4,6,8)[param]:code=4
            elif len({acc,tmp,out})!=3 or any(r in (acc,tmp,out) for d in descriptors[:l] for r in (d[0],d[2])) or any(r in slots for r in (acc,tmp,out)):code=3
            else:
                for a,aid,s,sid in descriptors[:l]:
                    ar=slots.get(a);sr=slots.get(s)
                    if ar is None or sr is None or ar['state']!='complete' or sr['state']!='complete' or ar['id']!=aid or sr['id']!=sid:code=1;break
                    if not ar['domain'] or not sr['domain'] or ar['param']!=param or sr['param']!=param:code=2;break
            expected_code=4 if variant in (0,1) else 3 if variant in (2,3) else 1 if variant in (4,5,8) else 2 if variant in (6,7) else 0
            require(code==expected_code,'Row eligibility differs from scenario')
            row=dict(run=run,p=p,index=expected_row,l=l,desc=descriptors,acc=acc,tmp=tmp,out=out,id=rid,code=code,
                     phase='error' if code else 'pwm',column=0,terms=0,abort=phase,acc_id=0)
            runs+=1;continue
        if kind=='DROW':
            require(row is not None and child is None,'Row completion without owner');r=row
            require(list(map(int,f[1:]))==[r['run'],r['code'],r['id'],r['out'],0 if r['code'] else r['l']],'Row completion identity/count mismatch')
            if r['code']==0:
                require(r['abort']<0 and r['phase']=='report' and r['acc'] not in slots and r['tmp'] not in slots and
                    slots[r['out']]['data']==row_expected(r['p'],r['index']),'Incomplete/incorrect whole row')
                good+=1;completed.add((r['p'],r['index']))
            else:require(r['phase']=='error','Rejected row changed engines');bad+=1
            row=None;continue
        if kind=='Z':
            require(row is not None and child is None,'Row abort without retirement');r=row;phase=r['abort']
            require(list(map(int,f[1:]))==[r['run'],phase] and phase in range(7),'Wrong row abort phase')
            if phase==0:require(r['terms']==0 and r['phase']=='pwm' and partial is None,'Validation reset wrong boundary')
            elif phase in (1,5):require(partial is not None and partial['kind']=='N' and partial['outputs']==0 and
                partial['loads']==(512 if phase==1 else 256),'Engine reset wrong boundary')
            elif phase==2:require(r['terms']==1 and r['phase']=='pwm' and partial is None,'First accumulator reset wrong boundary')
            elif phase==3:require(partial is not None and partial['kind']=='P' and partial['inputs']==9 and partial['outputs']==8 and
                slots[r['acc']]['count']==8,'Destructive update reset wrong boundary')
            elif phase==4:require(r['terms']==2 and r['phase']=='free_scratch' and partial is None,'Scratch-release reset wrong boundary')
            else:require(r['terms']==4 and r['phase']=='report' and slots[r['out']]['data']==row_expected(0,0),'Held row completion reset wrong boundary')
            row=None;partial=None;aborts+=1;continue
        if kind=='X':
            require(row is None and child is None,'Reset lacks abort/retirement');slots.clear();public_reads.clear();continue
        if kind=='L':
            region,internal=map(int,f[1:]);s=slots.get(region)
            require(child is None and s is not None and s['state']=='complete','Release of active/invalid polynomial')
            if internal:
                require(row is not None and row['code']==0,'Unowned row release')
                if row['phase']=='free_scratch':
                    require(region==row['tmp'],'Row released retained operand instead of scratch')
                    if row['column']==row['l']-1:row['phase']='inverse'
                    else:row['column']+=1;row['phase']='pwm'
                else:require(row['phase']=='free_acc' and region==row['acc'],'Wrong accumulator release');row['phase']='report'
            else:require(row is None,'External release during row')
            del slots[region];continue
        if kind in ('R','E'):
            require(row is None and child is None and int(f[1])==serial-1,'Public read during row/child')
            region=int(f[2]);s=slots.get(region)
            if kind=='E':require(s is None,'Live region rejected');continue
            word=int(f[3]);require(s is not None and s['state']=='complete' and word==public_reads.get(region,0),'Public word order/ownership')
            expected=sum(s['data'][4*word+j]<<(23*j) for j in range(4))
            require(int(f[4],16)==expected and list(map(int,f[5:]))==meta(s)+[int(all(x<=4 or x>=q-4 for x in s['data']))],'Whole-row readback mismatch')
            public_reads[region]=(word+1)%64;reads+=1;continue
        if kind in ('J','O','C'):
            require(child is None and int(f[1])==serial,'Overlapping/out-of-order row child');serial+=1
            c=dict(serial=serial-1,expected={},bindings={},commits=set(),inputs=0,outputs=0,loads=0,memory_reads=0)
            if kind=='J':
                case,core,region,jid=map(int,f[2:]);fixture=fixtures[case]
                require(row is None and jid==fixture['id'] and core in (0,1),'Wrong fixture sampling command')
                c.update(kind='S',id=jid,core=core)
                c['expected'][region]=dict(id=jid,mode=fixture['mode'],param=fixture['param'],domain=int(fixture['mode']==0),data=fixture['values'],case=case)
                samples+=1
            else:
                if kind=='O':op,a,b,dest,aid,bid,jid=map(int,f[2:]);inplace=False
                else:op,a,b,dest,high,aid,bid,jid,inplace=map(int,f[2:]);require(high==0 and op==0 and inplace==1,'Unexpected row process operation')
                ar=slots.get(a);br=slots.get(b);binary=kind=='C' or op==2
                require(ar is not None and ar['state']=='complete' and ar['id']==aid and
                    (not binary or (br is not None and br['state']=='complete' and br['id']==bid and ar['param']==br['param'])),'Wrong child source owner')
                if row is not None:
                    r=row;j=r['column'];require(r['code']==0,'Rejected row issued arithmetic')
                    if kind=='C':
                        require(r['phase']=='add' and [a,b,dest,aid,bid,jid]==[r['acc'],r['tmp'],r['acc'],r['acc_id'],r['id']+2+2*j,r['id']+3+2*j],'Row ADD schedule mismatch')
                    elif op==2:
                        require(r['phase']=='pwm' and [a,aid,b,bid]==r['desc'][j] and dest==(r['acc'] if j==0 else r['tmp']) and
                            jid==r['id']+(1 if j==0 else 2+2*j),'Row PWM schedule mismatch')
                    else:require(r['phase']=='inverse' and op==1 and [a,dest,aid,jid]==[r['acc'],r['out'],r['acc_id'],r['id']],'Row inverse schedule mismatch')
                else:require(kind=='O' and op in (0,3) and ar['mode']==1 and not ar['domain'] and
                    (op!=3 or all(x<=4 or x>=q-4 for x in ar['data'])) and
                    a==fixtures[ar['case']]['col']+1 and dest==a+31,'Unexpected external row operation')
                if kind=='C':require(ar['domain']==br['domain'] and dest==a,'Invalid in-place ADD domain/alias');data=tuple((x+y)%q for x,y in zip(ar['data'],br['data'],strict=True));domain=ar['domain'];processes+=1;rewrites+=1
                else:
                    require((op in (0,3) and not ar['domain']) or (op==1 and ar['domain']) or (op==2 and ar['domain'] and br['domain']),'Wrong NTT child domain')
                    data=arithmetic_result(op,ar['data'],br['data'] if op==2 else ());domain=int(op!=1);ntts+=1
                c.update(kind='P' if kind=='C' else 'N',op=op,a=a,b=b,dest=dest,aid=aid,bid=bid,id=jid,old_a=ar['data'],old_b=br['data'] if binary else (),inplace=bool(inplace))
                c['expected'][dest]=dict(id=jid,mode=ar['mode'],param=ar['param'],domain=domain,data=data,case=ar['case'])
            child=c;continue
        require(child is not None and int(f[1])==child['serial'],'Row child event has no owner');c=child
        if kind=='V':
            core,region,jid,mode,param,domain=map(int,f[2:]);expected=c['expected'].get(region)
            require(core in (0,1) and core not in c['bindings'] and expected is not None and [jid,mode,param,domain]==meta(expected),'Wrong row destination allocation')
            if c.get('inplace'):require(region==c['a'] and slots[region]['state']=='complete','In-place destination ownership lost')
            else:require(region not in slots,'Row overwrote retained polynomial')
            slots[region]=dict(**expected,state='writing',count=0,packed=0,acks=0);public_reads.pop(region,None);c['bindings'][core]=region;continue
        if kind=='W':
            core,index=int(f[2]),int(f[3]);s=slots.get(c['bindings'].get(core))
            require(s is not None and s['state']=='writing' and index==s['count'] and index<256 and int(f[4],16)==s['data'][index] and int(f[5])==int(index==255),'Row scalar write mismatch')
            s['count']+=1;values+=1;continue
        if kind in ('P','Q'):
            region,word=map(int,f[2:4]);s=slots.get(region)
            require(region in c['bindings'].values() and s is not None and s['state']=='writing' and word<64,'Unowned row packed write/ack')
            if kind=='P':
                require(word==s['packed'] and s['count']>=4*(word+1) and int(f[4],16)==sum(s['data'][4*word+j]<<(23*j) for j in range(4)),'Row packed word mismatch')
                s['packed']+=1;words+=1
            else:require(word==s['acks'] and word<s['packed'],'Row ack without write');s['acks']+=1;acks+=1
            continue
        if kind=='U':
            core=int(f[2]);region=c['bindings'].get(core);s=slots.get(region)
            require(s is not None and s['count']==256 and s['packed']==64 and s['acks']==64 and region not in c['commits'],'Row premature commit')
            c['commits'].add(region);continue
        if kind=='M':
            region,word=int(f[2]),int(f[3]);n=c['memory_reads'];expected_region=c['a'] if n%2==0 else c['b'];data=c['old_a'] if n%2==0 else c['old_b']
            require(c['kind']=='P' and n<128 and region==expected_region and word==n//2 and
                int(f[4],16)==sum(data[4*word+j]<<(23*j) for j in range(4)) and
                int(f[5])==(c['id'] if region==c['dest'] else c['bid']) and int(f[6])==(4*word if region==c['dest'] else 256),'Read-before-overwrite word/owner/order violated')
            c['memory_reads']+=1;readbacks+=1;continue
        if kind=='I':
            index=int(f[2]);require(c['kind']=='P' and index==c['inputs'] and index<256 and c['memory_reads']==2*(index//4+1) and
                int(f[3],16)==c['old_a'][index] and int(f[4],16)==c['old_b'][index],'Row ADD cache/input mismatch')
            c['inputs']+=1;continue
        if kind=='K':
            index=int(f[2]);require(c['kind']=='P' and index==c['outputs'] and index<c['inputs'] and
                list(map(int,f[3:6]))==[0,0,c['id']] and int(f[6],16)==c['expected'][c['dest']]['data'][index] and
                list(map(int,f[7:]))==[0,0,0,int(index==255)],'Row ADD arithmetic mismatch')
            c['outputs']+=1;continue
        if kind=='T':
            region,index=int(f[2]),int(f[3]);n=c['loads'];data=c['old_a'] if n<256 else c['old_b']
            require(c['kind']=='N' and data and n<(512 if c['op']==2 else 256) and region==(c['a'] if n<256 else c['b']) and
                index==n%256 and int(f[4],16)==data[index],'Row NTT DMA mismatch');c['loads']+=1;continue
        if kind=='N':
            index=int(f[2]);require(c['kind']=='N' and index==c['outputs'] and index<256 and
                c['loads']==(512 if c['op']==2 else 256) and int(f[3],16)==c['expected'][c['dest']]['data'][index] and int(f[4])==int(index==255),'Row NTT output mismatch')
            c['outputs']+=1;continue
        if kind in ('S','D'):
            if kind=='S':require(c['kind']=='S' and list(map(int,f[2:]))==[c['id'],0],'Row sampling status mismatch')
            else:
                require(f[2]==c['kind'] and list(map(int,f[3:]))==[0,c['id'],c['dest'],0] and c['outputs']==256,'Row child completion mismatch')
                if c['kind']=='P':require(c['inputs']==256 and c['memory_reads']==128,'Incomplete row update')
            require(set(c['expected'])==c['commits'],'Row child retired without durable commit')
            for region in c['bindings'].values():slots[region]['state']='complete'
            if row is not None:
                r=row
                if c['kind']=='P':r['acc_id']=c['id'];r['terms']+=1;r['phase']='free_scratch'
                elif c['op']==1:r['phase']='free_acc'
                elif r['column']==0:r['acc_id']=c['id'];r['terms']=1;r['column']=1;r['phase']='pwm'
                else:r['phase']='add'
            child=None;continue
        if kind=='A':require(row is not None and row['abort']>=0,'Unexpected child abort');partial=c;child=None;continue
        raise ValueError('Unknown row event:'+kind)
    require(footer==[samples,ntts,processes,good,bad,aborts,values,words,reads] and
        [samples,ntts,processes,good,bad,aborts]==[163,161,55,13,27,7] and runs==47 and completed=={(p,i) for p in range(3) for i in range(2)} and
        row is None and child is None and not slots and witness==[160,4] and rewrites==55,'Incomplete whole-row campaign')
    return (f'DILITHIUM STAGE5H ROW COMPARE PASS:13 complete rows,27 rejections,7 reset aborts;'
        f'163 sampled jobs,161 NTT commands,55 in-place ADDs;{values} scalar writes,{words} packed writes,{acks} acks;'
        f'{reads} exact92-bit public reads,{readbacks} read-before-overwrite words;levels2/3/5 and retained-source reuse\n')






def full_keygen_cases():
    specs=[(0,0,500,-1),(0,1,1500,-1),(0,2,65500,-1),
           (0,3,700,-1),(1,0,701,-1),(2,0,702,-1)]
    for phase in range(5):specs += [(0,0,4000+phase,phase),(0,0,4000+phase,-1)]
    return [dict(i=i,op=op,p=p,id=jid,abort=abort,
                 code=2 if op!=0 else 1 if p==3 else 0,
                 xi=hashlib.sha256(f'full-keygen-{i}'.encode()).digest())
            for i,(op,p,jid,abort) in enumerate(specs)]


def full_keygen_input_artifact(token):
    return f'{token} 16\n'+''.join(f"{c['i']} {c['op']} {c['p']} {c['id']} {c['abort']} {int.from_bytes(c['xi'],'little'):064x}\n"
                                 for c in full_keygen_cases())


def build_full_keygen_c():
    gcc=shutil.which('gcc')
    if not gcc:raise ValueError('GCC required for whole-KeyGen C reference')
    files=('sign.c','polyvec.c','packing.c','poly.c','reduce.c','rounding.c','ntt.c','symmetric-shake.c','fips202.c')
    for level in (2,3,5):
        exe=HERE/'reference_build'/f'keygen_reference_{level}.exe'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ROOT/'dilithium-sw-model/ref'),
                        str(ROOT/'tb/tb_dilithium/keygen_reference.c'),
                        *[str(ROOT/'dilithium-sw-model/ref'/name) for name in files],'-o',str(exe)],
                       check=True,capture_output=True,text=True)
    full_keygen_reference.cache_clear()
    golden=full_keygen_reference()
    message=f'C_FULL_KEYGEN_REFERENCE_PASS:{len(golden)} deterministic keypairs,all3 levels;unchanged software keypair with test-only xi injection\n'
    (HERE/'stage5_full_keygen_c_reference.log').write_text(message);print(message,end='')


@lru_cache(maxsize=1)
def full_keygen_reference():
    result={}
    for p,level in enumerate((2,3,5)):
        rows=[c for c in full_keygen_cases() if c['p']==p and c['code']==0]
        exe=HERE/'reference_build'/f'keygen_reference_{level}.exe'
        if not exe.is_file():raise ValueError('Run prepare to build full-KeyGen references')
        output=subprocess.run([str(exe)],input=''.join(' '.join(map(str,c['xi']))+'\n' for c in rows),
                              check=True,capture_output=True,text=True).stdout.splitlines()
        if len(output)!=len(rows):raise ValueError('C full-KeyGen result count')
        for c,line in zip(rows,output,strict=True):
            pk,sk=map(bytes.fromhex,line.split())
            if (len(pk),len(sk))!=((1312,2560),(1952,4032),(2592,4896))[p]:raise ValueError('Reference key lengths')
            if pk[:32]!=sk[:32] or hashlib.shake_256(pk).digest(64)!=sk[64:128]:raise ValueError('Reference public-key hash/seed binding')
            result[c['i']]=(pk,sk)
    return result


def full_keygen_expected_artifact(token):
    golden=full_keygen_reference()
    return f'{token} 16\n'+''.join(f"{c['i']} "+
        (golden[c['i']][0].hex()+' '+golden[c['i']][1].hex() if c['i'] in golden else '- -')+'\n' for c in full_keygen_cases())


@lru_cache(maxsize=1)
def nist_keygen_cases():
    """Join official seeds and published keys by (tgId,tcId);never synthesize expected keys."""
    provenance=json.loads((NIST_KEYGEN/'provenance.json').read_text())
    if provenance['commit']!=NIST_COMMIT:raise ValueError('NIST corpus revision changed')
    objects={}
    for name,digest in NIST_HASHES.items():
        raw=(NIST_KEYGEN/name).read_bytes()
        item=next(x for x in provenance['files'] if x['name']==name)
        expected_url=f'https://raw.githubusercontent.com/usnistgov/ACVP-Server/{NIST_COMMIT}/gen-val/json-files/ML-DSA-keyGen-FIPS204/{name}'
        if hashlib.sha256(raw).hexdigest()!=digest or item['sha256']!=digest or item['bytes']!=len(raw) or item['url']!=expected_url:
            raise ValueError('NIST corpus/provenance hash mismatch:'+name)
        obj=json.loads(raw)
        if (obj['algorithm'],obj['mode'],obj['revision'],obj['vsId'])!=('ML-DSA','keyGen','FIPS204',42):
            raise ValueError('Wrong NIST algorithm/revision/vector set')
        objects[name]=obj
    expected={}
    for group in objects['expectedResults.json']['testGroups']:
        for test in group['tests']:
            key=(group['tgId'],test['tcId'])
            if key in expected:raise ValueError('Duplicate NIST expected case')
            expected[key]=(bytes.fromhex(test['pk']),bytes.fromhex(test['sk']))
    result=[];seen=set();counts=[0,0,0]
    for group in objects['prompt.json']['testGroups']:
        if group['testType']!='AFT':raise ValueError('Unsupported NIST test type')
        p=('ML-DSA-44','ML-DSA-65','ML-DSA-87').index(group['parameterSet'])
        for test in group['tests']:
            key=(group['tgId'],test['tcId'])
            if key in seen or key not in expected:raise ValueError('NIST input/expected identity mismatch')
            seen.add(key);xi=bytes.fromhex(test['seed']);pk,sk=expected[key]
            if len(xi)!=32 or (len(pk),len(sk))!=((1312,2560),(1952,4032),(2592,4896))[p]:
                raise ValueError('NIST seed/key lengths')
            if pk[:32]!=sk[:32] or hashlib.shake_256(pk).digest(64)!=sk[64:128]:
                raise ValueError('NIST published seed/hash binding')
            i=len(result);counts[p]+=1
            result.append(dict(i=i,op=0,p=p,id=(65500+i)&65535,abort=-1,code=0,
                               xi=xi,pk=pk,sk=sk,tg=key[0],tc=key[1]))
    if seen!=set(expected) or counts!=[25,25,25]:raise ValueError('Incomplete NIST corpus;expected all75 cases')
    return result


def nist_keygen_input_artifact(token):
    rows=nist_keygen_cases()
    return f'{token} {len(rows)}\n'+''.join(f"{c['i']} 0 {c['p']} {c['id']} -1 {int.from_bytes(c['xi'],'little'):064x}\n" for c in rows)


def nist_keygen_expected_artifact(token):
    rows=nist_keygen_cases()
    # index tgId tcId parameter-code seed(hex byte order) published-PK published-SK
    return f'{token} {len(rows)}\n'+''.join(f"{c['i']} {c['tg']} {c['tc']} {c['p']} {c['xi'].hex()} {c['pk'].hex()} {c['sk'].hex()}\n" for c in rows)


def check_nist_keygen_c():
    rows=nist_keygen_cases()
    for p,level in enumerate((2,3,5)):
        selected=[c for c in rows if c['p']==p]
        output=subprocess.run([str(HERE/'reference_build'/f'keygen_reference_{level}.exe')],
            input=''.join(' '.join(map(str,c['xi']))+'\n' for c in selected),check=True,capture_output=True,text=True).stdout.splitlines()
        if len(output)!=len(selected):raise ValueError('NIST/C result count')
        for c,line in zip(selected,output,strict=True):
            if tuple(map(bytes.fromhex,line.split()))!=(c['pk'],c['sk']):
                raise ValueError(f"C differs from NIST tgId{c['tg']} tcId{c['tc']}")
    message='NIST_C_KEYGEN_PASS:75/75 complete published keypairs,25 per parameter set;no locally generated expected keys\n'
    (HERE/'stage5_nist_keygen_c_reference.log').write_text(message);print(message,end='')


def verify_full_keygen(lines,nist=False):
    _,token=check();fixtures=nist_keygen_cases() if nist else full_keygen_cases()
    golden={c['i']:(c['pk'],c['sk']) for c in fixtures} if nist else full_keygen_reference()
    if not lines or lines[0]!='H '+token:raise ValueError('Full-KeyGen capture freshness')
    current=None;opened=complete=reject=aborts=host_words=hash_words=tr_bytes=read_words=0;footer=None;witness=None;ownership=None
    def require(ok,message):
        if not ok:raise ValueError('Full KeyGen: '+message)
    for line in lines[1:]:
        f=line.split();kind=f[0];require(footer is None,'Record after footer')
        if kind=='X':require(current is None,'Reset without abort ledger');continue
        if kind=='B':
            require(current is None and opened<len(fixtures),'Overlapping start')
            c=fixtures[opened];require(list(map(int,f[1:5]))==[c['i'],c['op'],c['p'],c['id']] and
                int(f[5],16)==int.from_bytes(c['xi'],'little'),'Start/xi identity')
            current=dict(c=c,counts=[0,0],hash=0,tr=0,hash_cmd=False,hash_done=False,done=False,section=0)
            if c['code']==0:
                k,l=((4,4),(6,5),(8,7))[c['p']]
                current['sequence']=[(s,i,w) for s,limit in ((0,k),(1,l),(2,k),(3,k)) for i in range(limit) for w in range(64)]
            opened+=1;continue
        if kind=='Q':
            require(current is None and ownership is None,'Misplaced ownership witness')
            ownership=list(map(int,f[1:]));require(len(ownership)==3 and all(v>0 for v in ownership) and ownership[1]<ownership[0],'Missing owned/cleanup/idle phases');continue
        if kind=='G':require(current is None and witness is None,'Misplaced fork witness');witness=list(map(int,f[1:]));continue
        if kind=='F':require(current is None,'Missing final cleanup/abort');footer=list(map(int,f[1:]));continue
        require(current is not None and int(f[1])==current['c']['i'],'Unowned run event')
        r=current;c=r['c'];pk,sk=golden.get(c['i'],(b'',b''))
        if kind=='H':
            require(c['code']==0 and not r['hash_cmd'] and list(map(int,f[2:]))[:1]==[(c['id']+1024)&65535],'Hash command ownership')
            core,mode,length,outlen=map(int,f[3:])
            require(core in (0,1) and (mode,length,outlen)==(1,len(pk),64),'Hash mode/length')
            r['core']=core;r['hash_cmd']=True;continue
        if kind=='I':
            require(r['hash_cmd'] and r['hash']*8<len(pk),'Surplus/unowned public-key hash input')
            offset=8*r['hash'];require(int(f[2],16).to_bytes(8,'little')==pk[offset:offset+8],'Wrong encoded public-key hash bytes')
            r['hash']+=1;hash_words+=1;continue
        if kind=='T':
            require(r['hash_cmd'] and r['hash']*8==len(pk) and r['tr']<64,'Early/surplus tr output')
            require(list(map(int,f[2:5]))==[(c['id']+1024)&65535,r['core'],16],'tr output ownership')
            expected=hashlib.shake_256(pk).digest(64)
            require(int(f[5],16).to_bytes(16,'little')==expected[r['tr']:r['tr']+16],'tr output mismatch')
            r['tr']+=16;tr_bytes+=16;continue
        if kind=='HD':
            require(r['tr']==64 and not r['hash_done'] and list(map(int,f[2:]))==[(c['id']+1024)&65535,r['core']],'Hash completion order/identity')
            r['hash_done']=True;continue
        if kind=='O':
            jid,typ,index,count,last=map(int,f[2:7]);require(c['code']==0 and typ in (0,1),'Unexpected key output')
            payload=(pk,sk)[typ]
            require(jid==c['id'] and index==r['counts'][typ] and count==8 and 8*index<len(payload) and
                    last==int(8*(index+1)==len(payload)),'Key word count/order/tag/last')
            if typ==1:require(r['counts'][0]*8==len(pk) and r['hash_done'],'Secret key before complete PK/hash')
            else:require(r['counts'][1]==0,'Returned to PK after SK')
            require(int(f[7],16).to_bytes(8,'little')==payload[8*index:8*index+8],'Encoded key byte mismatch')
            r['counts'][typ]+=1;host_words+=1;continue
        if kind=='M':
            section,poly,word,region,jid,param,mode,domain=map(int,f[2:])
            k,l=((4,4),(6,5),(8,7))[c['p']]
            expected_region=(40+poly if section==0 else 1+poly if section==1 else 8+poly if section==2 else 56+poly)
            expected_id=(c['id']+768+poly if section in (0,3) else c['id']+16+poly+(l if section==2 else 0))&65535
            require(section in range(4) and poly<(l if section==1 else k) and word<64 and
                (region,jid,param,mode,domain)==(expected_region,expected_id,c['p'],1 if section in (1,2) else 0,0),'Field read owner/region/domain')
            # Independent field order:PK t1[k],SK s1[l],s2[k],t0[k].
            sequence=r['sequence']
            require(r['section']<len(sequence) and (section,poly,word)==sequence[r['section']],'Field DMA order')
            r['section']+=1;read_words+=1;continue
        if kind=='L':
            region=int(f[2]);protected=set(range(1,8))|set(range(8,16))|set(range(32,39))|set(range(40,48))|set(range(56,64))
            require(region not in protected or r['done'],'Retained source released before whole-operation retirement');continue
        if kind=='D':
            require(c['abort']<0 and not r['done'] and list(map(int,f[2:]))==[c['code'],c['id']],'Completion identity/code')
            if c['code']==0:
                k,l=((4,4),(6,5),(8,7))[c['p']]
                require(r['counts']==[len(pk)//8,len(sk)//8] and r['hash_done'] and r['section']==64*(3*k+l),'Truncated keys/hash/field reads')
                complete+=1
            else:
                require(r['counts']==[0,0] and not r['hash_cmd'] and r['section']==0,'Rejected operation side effects');reject+=1
            r['done']=True;continue
        if kind=='CLEAN':require(r['done'],'Cleanup without retirement');current=None;continue
        if kind=='A':
            phase,host_sent,hash_sent=map(int,f[2:])
            require(phase==c['abort'] and not r['done'],'Reset identity')
            if phase==0:require(host_sent==0 and hash_sent==1 and r['counts']==[0,0] and r['hash']==1,'Hash-first fork reset')
            elif phase==1:require(r['counts']==[13,0],'Partial public-key reset')
            elif phase==2:require(r['tr']==16 and r['counts']==[len(pk)//8,0],'Partial tr reset')
            elif phase==3:require(r['counts']==[len(pk)//8,20],'Partial secret-key reset')
            else:require(r['counts']==[len(pk)//8,len(sk)//8] and r['hash_done'],'Held final completion reset')
            aborts+=1;current=None;continue
        raise ValueError('Unknown full-KeyGen record:'+kind)
    require(opened==len(fixtures) and (complete,reject,aborts)==((75,0,0) if nist else (8,3,5)) and ownership is not None and witness is not None and all(x>0 for x in witness) and
            footer==[complete,reject,aborts,host_words,hash_words,tr_bytes,read_words],'Full-KeyGen campaign totals/fork coverage')
    if nist:
        return (f'DILITHIUM STAGE5M NIST KEYGEN COMPARE PASS:75/75 official ACVP keypairs,25 each ML-DSA-44/65/87;'
                f'{host_words} exact64-bit key words,{host_words*8} exact key bytes,{hash_words} exact PK hash input words,'
                f'{tr_bytes} exact tr bytes,{read_words} field-read metadata records;all keys,cleanup,ID wrap and backpressure checked\n')
    return (f'DILITHIUM STAGE5L FULL KEYGEN COMPARE PASS:8 complete C-reference keypairs,3 expected rejects,5 reset aborts;'
            f'{host_words} exact64-bit key words,{hash_words} exact public-key SHAKE input words,{tr_bytes} exact tr bytes,'
            f'{read_words} checked field read words;all3 levels,independent fork backpressure,ID wrap,cleanup/recovery\n')


@lru_cache(maxsize=1)
def bitpkg_cases():
    result=[];q=ntt_reference.Q;rng=random.Random(0x5B17C)
    def add(op,p,pattern=5,abort=-1,fault_index=-1,fault_kind=0,code=0,jid=None):
        eta=4 if p==1 else 2
        choices=list(range(1024)) if op==0 else list(range(-4095,4097)) if op==1 else list(range(-eta,eta+1))
        edge=[choices[0],choices[-1],0,choices[min(1,len(choices)-1)],choices[-2]]
        signed=[(0 if pattern==0 else choices[0] if pattern==1 else choices[-1] if pattern==2 else
                 edge[i%len(edge)] if pattern==3 else edge[i%2] if pattern==4 else rng.choice(choices)) for i in range(256)]
        values=[x%q for x in signed]
        if fault_kind==4:values[fault_index]=1024 if op==0 else q-4096 if op==1 else eta+1
        i=len(result)
        result.append(dict(i=i,op=op,p=p,id=30000+i if jid is None else jid,abort=abort,code=code,
                           fault_index=fault_index,fault_kind=fault_kind,values=values))
    for op in range(3):
        for p in range(3):
            for pattern in range(6):add(op,p,pattern)
    for op in range(3):
        for p in range(3):
            for index in (0,137):add(op,p,fault_index=index,fault_kind=4,code=2)
    for op in range(3):
        for kind,index in ((1,137),(2,137),(3,255)):add(op,op%3,fault_index=index,fault_kind=kind,code=3)
    for op,p in ((0,3),(1,3),(2,3),(3,0)):add(op,p,code=1)
    for op in range(3):
        for phase in range(2):
            jid=32000+op*2+phase
            add(op,op%3,abort=phase,jid=jid);add(op,op%3,jid=jid)
    assert len(result)==97
    return result


def bitpkg_input_artifact(token):
    return f'{token} 97\n'+''.join(
        f"{c['i']} {c['op']} {c['p']} {c['id']} {c['abort']} {c['code']} {c['fault_index']} {c['fault_kind']}\n"+
        ' '.join(f'{x:06x}' for x in c['values'])+'\n' for c in bitpkg_cases())


def bitpkg_encoded(op,p,value):
    q=ntt_reference.Q;eta=4 if p==1 else 2
    signed=value if value<=(q-1)//2 else value-q
    return (value,10) if op==0 else (4096-signed,13) if op==1 else (eta-signed,4 if eta==4 else 3)


def bitpkg_bytes(c):
    bits=0;offset=0
    for value in c['values']:
        encoded,width=bitpkg_encoded(c['op'],c['p'],value);bits|=encoded<<offset;offset+=width
    return bits.to_bytes(offset//8,'little')


def check_bitpkg_c():
    gcc=shutil.which('gcc')
    if not gcc:raise ValueError('GCC required for Bitpkg software oracle')
    files=['poly.c','reduce.c','rounding.c','ntt.c','symmetric-shake.c','fips202.c']
    count=total=0
    for p,level in enumerate((2,3,5)):
        exe=HERE/'reference_build'/f'bitpkg_reference_{level}.exe'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ROOT/'dilithium-sw-model/ref'),
                        str(ROOT/'tb/tb_dilithium/bitpkg_reference.c'),
                        *[str(ROOT/'dilithium-sw-model/ref'/name) for name in files],'-o',str(exe)],check=True,capture_output=True,text=True)
        rows=[c for c in bitpkg_cases() if c['p']==p and c['code']==0]
        response=subprocess.run([str(exe)],input=''.join(str(c['op'])+' '+' '.join(map(str,c['values']))+'\n' for c in rows),
                                check=True,capture_output=True,text=True).stdout.splitlines()
        if len(response)!=len(rows):raise ValueError('C Bitpkg oracle count')
        for c,line in zip(rows,response,strict=True):
            expected=bitpkg_bytes(c)
            if bytes.fromhex(line)!=expected:raise ValueError('Python/C Bitpkg mismatch')
            count+=1;total+=len(expected)
    message=f'PYTHON_C_BITPKG_PASS:{count} valid polynomial fixtures,{total} bytes;unchanged C poly packers at levels2/3/5\n'
    (HERE/'stage5_bitpkg_c_reference.log').write_text(message);print(message,end='')


def verify_bitpkg(lines):
    _,token=check()
    if not lines or lines[0]!='H '+token:raise ValueError('Bitpkg freshness')
    fixtures=bitpkg_cases();current=None;opened=0;done=aborts=success=errors=inputs=outputs=0;footer=None
    def require(ok,message):
        if not ok:raise ValueError('Bitpkg: '+message)
    for line in lines[1:]:
        f=line.split();kind=f[0];require(footer is None,'Record after footer')
        if kind=='X':require(current is None,'Reset without abort');continue
        if kind=='B':
            require(current is None and opened<len(fixtures),'Overlapping command')
            c=fixtures[opened];require(list(map(int,f[1:]))==[opened,c['op'],c['p'],c['id']],'Descriptor identity')
            current=dict(c=c,inputs=0,words=0,bits=0,count=0,failed=False);opened+=1;continue
        if kind=='F':require(current is None,'Unfinished final packet');footer=list(map(int,f[1:]));continue
        require(current is not None,'Unowned packet event');r=current;c=r['c'];require(int(f[1])==c['i'],'Packet index')
        if kind=='I':
            i=r['inputs'];require(c['code']!=1 and not r['failed'] and i<256,'Unexpected input beat')
            index=i+(1 if c['fault_kind']==1 and i==c['fault_index'] else 0)
            last=int(i==255)
            if i==c['fault_index'] and c['fault_kind']==2:last=1
            if i==c['fault_index'] and c['fault_kind']==3:last=0
            require(list(map(int,f[2:4]))==[index,last] and int(f[4],16)==c['values'][i],'Input framing/data')
            r['inputs']+=1;inputs+=1
            if c['code'] in (2,3) and i==c['fault_index']:
                r['failed']=True;r['count']=0;r['bits']=0
            else:
                encoded,width=bitpkg_encoded(c['op'],c['p'],c['values'][i])
                require(0<=encoded<(1<<width),'Oracle encoding range')
                r['bits']|=encoded<<r['count'];r['count']+=width
            continue
        if kind=='O':
            require(not r['failed'] and r['count']>=64,'Output without enough valid bits')
            require(list(map(int,f[2:5]))==[c['id'],r['words'],8] and
                    int(f[5])==int(r['inputs']==256 and r['count']==64) and int(f[6],16)==(r['bits']&((1<<64)-1)),
                    'Packed output word/order/last/tag')
            r['bits']>>=64;r['count']-=64;r['words']+=1;outputs+=1;continue
        if kind=='D':
            require(c['abort']<0 and list(map(int,f[2:]))==[c['id'],c['code']],'Retirement metadata')
            if c['code']==0:
                require(r['inputs']==256 and r['count']==0 and r['words']*8==len(bitpkg_bytes(c)),'Truncated successful packet');success+=1
            else:
                require((c['code']==1 and r['inputs']==0 and r['words']==0) or r['failed'],'Failure was not exercised');errors+=1
            done+=1;current=None;continue
        if kind=='A':
            phase,seen,words=map(int,f[2:])
            require(phase==c['abort'] and seen==r['inputs'] and words==r['words'],'Reset prefix identity')
            require((phase==0 and seen==17) or (phase==1 and r['count']>=64 and words==0),'Reset boundary')
            current=None;aborts+=1;continue
        raise ValueError('Unknown Bitpkg event:'+kind)
    require(opened==97 and (success,errors,aborts)==(60,31,6) and footer==[opened,done,aborts,inputs,outputs,errors],'Campaign totals')
    return (f'DILITHIUM STAGE5K BITPKG COMPARE PASS:97 commands,60 successful packets,31 expected errors,6 reset aborts;'
            f'{inputs} accepted coefficients,{outputs} exact64-bit output words;all t1/t0/eta formats;stalls and same-ID recovery\n')


def keygen_cases():
    specs=[(0,0,100,-1),(0,1,800,-1),(0,2,65500,-1),
           (0,3,900,-1),(1,0,901,-1),(2,0,902,-1)]
    for phase in range(4):specs += [(0,0,2000+phase,phase),(0,0,2000+phase,-1)]
    return [dict(run=i,op=op,p=p,id=jid,abort=abort,xi=hashlib.sha256(f'keygen-polynomial-{i}'.encode()).digest())
            for i,(op,p,jid,abort) in enumerate(specs)]


def keygen_input_artifact(token):
    return f'{token} 14\n'+''.join(f"{c['run']} {c['op']} {c['p']} {c['id']} {c['abort']} {int.from_bytes(c['xi'],'little'):064x}\n" for c in keygen_cases())


@lru_cache(maxsize=28)
def keygen_expected(run,rounded=False):
    c=keygen_cases()[run];p=c['p'];base=c['id'];q=ntt_reference.Q
    if c['op']!=0 or p==3:return dict(polys={},jobs=[],alloc=[],release=[],material=None,k=0,l=0,rows=[])
    k,l=((4,4),(6,5),(8,7))[p];material=hashlib.shake_256(c['xi']+bytes((k,l))).digest(128)
    polys={};pairs={};jobs=[];alloc=[];release=[];secrets=[];hats=[];rows=[]
    def add(jid,region,mode,domain,values,message=None):
        jid&=65535;polys[jid]=dict(id=jid,region=region,mode=mode,p=p,domain=domain,data=tuple(values))
        alloc.append(jid)
        if message is not None:jobs.append(dict(id=jid,region=region,mode=mode,message=message))
    for n in range(l+k):
        message=material[32:96]+n.to_bytes(2,'little')
        poly,_=reference.sample(1,p,hashlib.shake_256(message).digest(4096));secrets.append(tuple(poly))
        add(base+16+n,1+n if n<l else 8+n-l,1,0,poly,message)
    for j in range(l):
        hats.append(arithmetic_result(0,secrets[j]));add(base+64+j,32+j,1,1,hats[j])
    for i in range(k):
        matrices=[]
        for j in range(l):
            message=material[:32]+bytes((j,i))
            poly,_=reference.sample(0,p,hashlib.shake_128(message).digest(4096));matrices.append(tuple(poly))
            add(base+128+8*i+j,48+j,0,1,poly,message)
        rid=base+256+32*i
        total=arithmetic_result(2,matrices[0],hats[0]);add(rid+1,16,0,1,total)
        for j in range(1,l):
            product=arithmetic_result(2,matrices[j],hats[j]);add(rid+2+2*j,17,0,1,product)
            total=tuple((a+b)%q for a,b in zip(total,product,strict=True));add(rid+3+2*j,16,0,1,total);release.append(17)
        inverse=arithmetic_result(1,total);add(rid,18,0,0,inverse);release.append(16)
        result=tuple((a+b)%q for a,b in zip(inverse,secrets[l+i],strict=True));rows.append(result)
        add(base+512+i,19,0,0,result)
        if rounded:
            high=tuple((x+4095)//8192 for x in result)
            low=tuple((x-8192*h)%q for x,h in zip(result,high,strict=True))
            for region,data in ((56+i,low),(40+i,high)):
                jid=(base+768+i)&65535;alloc.append(jid)
                pairs[region,jid]=dict(id=jid,region=region,mode=0,p=p,domain=0,data=data)
        release += [19,18]+list(range(48,48+l))
    release += list(range(1,1+l))+list(range(32,32+l))+list(range(8,8+k))
    if rounded:release += list(range(56,56+k))+list(range(40,40+k))
    return dict(polys=polys,pairs=pairs,jobs=jobs,alloc=alloc,release=release,material=material,k=k,l=l,rows=rows,secrets=secrets,hats=hats)


def verify_keygen(lines,rounded=False):
    _,token=check()
    if not lines or lines[0]!='H '+token:raise ValueError('KeyGen capture freshness')
    campaign=keygen_cases();current=None;serial=0;slots={};bindings={};footer=None;witness=None
    completed=rejected=aborted=delivered=writes=reads=0
    def require(ok,message):
        if not ok:raise ValueError('KeyGen polynomial: '+message)
    def end_message():
        if current['last_job'] is not None:
            j=current['last_job'];require(bytes(current['words'])==j['message'].ljust(((len(j['message'])+7)//8)*8,b'\0'),'Incomplete sample absorption')
    for line in lines[1:]:
        f=line.split();kind=f[0]
        require(footer is None,'Record after footer')
        if kind=='X':
            require(current is None,'Reset without abort ledger')
            slots.clear();bindings.clear();continue
        if kind=='B':
            require(current is None and serial<len(campaign) and not slots,'Start before cleanup/reset')
            c=campaign[serial];require(list(map(int,f[1:5]))==[serial,c['op'],c['p'],c['id']] and int(f[5],16)==int.from_bytes(c['xi'],'little'),'Start descriptor/xi')
            e=keygen_expected(serial,rounded);current=dict(c=c,e=e,seed=False,jobs=0,alloc=0,release=0,rows=0,
                last_job=None,words=bytearray(),read_words={},done=False);serial+=1;continue
        if kind=='F':
            require(current is None and serial==14,'Missing command completion')
            footer=list(map(int,f[1:]));continue
        if kind=='G':
            require(current is None and witness is None,'Misplaced pending-read witness')
            witness=list(map(int,f[1:]));continue
        require(current is not None,'Unowned event '+kind)
        r=current;c=r['c'];e=r['e'];run=c['run'];polys=e['polys']
        require(int(f[1])==run,'Wrong run tag')
        if kind=='K':
            require(e['material'] is not None and not r['seed'] and r['jobs']==0,'Unowned seed result')
            material=e['material'];require([int(f[2],16),int(f[3],16),int(f[4],16)]==
                [int.from_bytes(material[:32],'little'),int.from_bytes(material[32:96],'little'),int.from_bytes(material[96:],'little')],'Seed result bytes')
            r['seed']=True;continue
        if kind=='J':
            end_message();require(r['seed'] and r['jobs']<len(e['jobs']),'Sampling before seed/surplus job')
            j=e['jobs'][r['jobs']]
            require(list(map(int,f[2:]))==[j['mode'],c['p'],j['region'],j['id']],'Wrong nonce/matrix order or destination')
            r['jobs']+=1;r['last_job']=j;r['words']=bytearray();continue
        if kind=='I':
            require(r['last_job'] is not None,'Unowned sample absorption')
            offset=len(r['words']);data=int(f[2],16).to_bytes(8,'little');expected=r['last_job']['message']
            require(offset<len(expected) and data==expected[offset:offset+8].ljust(8,b'\0'),'RTL sampling message bytes')
            r['words'].extend(data);continue
        if kind=='V':
            core,region,jid=map(int,f[2:])
            require(r['alloc']<len(e['alloc']) and jid==e['alloc'][r['alloc']],'Unexpected allocation order')
            p=e['pairs'][region,jid] if rounded and (region,jid) in e.get('pairs',{}) else polys[jid];require(core in (0,1) and core not in bindings and region==p['region'],'Allocation owner/destination')
            require(region not in slots or (region==16 and slots[region]['complete']),'Unexpected live-region overwrite')
            slots[region]=dict(poly=p,count=0,complete=False);bindings[core]=region;r['alloc']+=1;continue
        if kind=='W':
            core,index=int(f[2]),int(f[3]);value=int(f[4],16);last=int(f[5])
            require(core in bindings,'Write without allocation');s=slots[bindings[core]]
            require(index==s['count'] and index<256 and value==s['poly']['data'][index] and last==int(index==255),'Scalar polynomial value/index/last')
            s['count']+=1;writes+=1;continue
        if kind=='U':
            core=int(f[2]);require(core in bindings,'Commit without allocation');region=bindings.pop(core);s=slots[region]
            require(s['count']==256,'Partial polynomial committed');s['complete']=True;continue
        if kind=='L':
            region=int(f[2]);require(r['release']<len(e['release']) and region==e['release'][r['release']],'Release schedule/lifetime')
            require(region in slots and slots[region]['complete'] and region not in bindings.values(),'Early/stale release')
            del slots[region];r['release']+=1;continue
        if kind=='R':
            region,word=int(f[2]),int(f[3]);require(region in slots and slots[region]['complete'] and word<64,'Unpublished read')
            p=slots[region]['poly'];expected=sum(p['data'][4*word+j]<<(23*j) for j in range(4))
            require(int(f[4],16)==expected and list(map(int,f[5:]))==[p['id'],p['mode'],c['p'],p['domain']],'Read value/metadata')
            key=(region,r['rows']) if region==19 else (region,-1)
            require(word==r['read_words'].get(key,0),'Duplicate/out-of-order read')
            r['read_words'][key]=word+1;reads+=1;continue
        if kind=='E':
            i,region,jid=map(int,f[2:]);require(i==r['rows'] and region==19 and jid==((c['id']+512+i)&65535),'Row output order/identity')
            require(r['read_words'].get((19,i))==64,'Row consumed before complete readback')
            r['rows']+=1;delivered+=1;continue
        if kind=='D':
            code=2 if c['op']!=0 else (1 if c['p']==3 else 0)
            require(c['abort']<0 and not r['done'] and list(map(int,f[2:]))==[code,c['id']],'Final status')
            if code==0:
                end_message();require(r['seed'] and r['rows']==e['k'] and r['jobs']==len(e['jobs']) and r['alloc']==len(e['alloc']) and not bindings,'Incomplete KeyGen polynomial phase')
                for region in list(range(1,1+e['l']))+list(range(32,32+e['l']))+list(range(8,8+e['k']))+(list(range(56,56+e['k']))+list(range(40,40+e['k'])) if rounded else []):
                    require(r['read_words'].get((region,-1))==64,'Missing retained secret/transform readback')
                completed+=1
            else:
                require(not r['seed'] and r['jobs']==0 and r['alloc']==0 and not slots,'Rejected command side effect');rejected+=1
            r['done']=True;continue
        if kind=='CLEAN':
            require(r['done'] and not slots and not bindings and r['release']==len(e['release']),'Incomplete cleanup')
            current=None;continue
        if kind=='A':
            phase,state=map(int,f[2:]);require(phase==c['abort'] and not r['done'],'Abort phase')
            if phase==0:require(state==2 and not r['seed'] and r['jobs']==0,'Seed reset boundary')
            elif phase==1:require(state==4 and slots[1]['count']==8 and not slots[1]['complete'],'Secret prefix reset boundary')
            elif phase==2:require(state==13 and slots[19]['complete'] and r['rows']==0,'Held row reset boundary')
            else:require(state==10 and slots[16]['count'] in (8,9) and not slots[16]['complete'],'Accumulator rewrite reset boundary')
            aborted+=1;current=None;continue
        raise ValueError('Unknown KeyGen polynomial event:'+kind)
    require(footer==[completed,rejected,aborted,delivered,writes,reads] and
            (completed,rejected,aborted,delivered)==(7,3,4,34) and witness==[136] and not slots and not bindings,'Campaign totals')
    return (f'DILITHIUM STAGE5{chr(75) if rounded else chr(74)} {"ROUNDED " if rounded else ""}KEYGEN POLYNOMIAL COMPARE PASS:7 complete operations,3 expected rejects,4 reset aborts;'
            f'34 t=A*s1+s2 rows;{writes} exact scalar writes,{reads} exact92-bit reads;all s1/s2 nonces and all matrix rows at levels2/3/5;'
            'retained secrets,ID wrap,cleanup and sequential reuse checked\n')


def seed_input_artifact(token):
    return f'{token} 3\n'+''.join(f"{p} {int.from_bytes(hashlib.sha256(f'banked-row-level-{p}'.encode()).digest(),'little'):064x}\n" for p in range(3))


def verify_seed_rows(lines):
    """Validate seed ownership and the real absorption stream before row checks."""
    retained=None;param=0;pending=None;filtered=[];seeds=samples=errors=raw_bytes=formatted=0
    negative=[];levels=set()
    def require(ok,message):
        if not ok:raise ValueError('Seed row: '+message)
    for line in lines:
        f=line.split();kind=f[0]
        if kind=='SC':
            require(pending is None,'Overlapping source command')
            op,p,jid,nonce,row,col,region=map(int,f[1:8]);xi=int(f[8],16).to_bytes(32,'little')
            require(xi==(hashlib.sha256(f'banked-row-level-{p}'.encode()).digest() if p<3 else bytes(32)),'Wrong xi input')
            k,l=((4,4),(6,5),(8,7),(0,0))[p]
            code=0
            if op==0:retained=None;code=3 if p==3 else 0
            elif op==3:code=3
            elif retained is None:code=1
            elif p!=param:code=2
            elif (op==1 and (row>=k or col>=l)) or (op==2 and nonce>=k+l):code=3
            message=xi+bytes((k,l)) if op==0 else (
                (retained[:32]+bytes((col,row))) if op==1 and code==0 else
                (retained[32:96]+nonce.to_bytes(2,'little')) if op==2 and code==0 else b'')
            pending=dict(op=op,p=p,id=jid,region=region,code=code,message=message,
                         words=bytearray(),raw=bytearray(),request=False,ended=False,sample=False,status=False)
        elif kind=='SR':
            c=pending;require(c is not None and c['op']==0 and c['code']==0 and not c['request'],'Unowned/duplicate raw request')
            jid,core,mode,length,outlen=map(int,f[1:])
            require((jid,mode,length,outlen)==(c['id'],1,34,128) and core in (0,1),'Raw descriptor metadata')
            c['core']=core;c['request']=True
        elif kind in ('SI','SF'):
            c=pending;require(c is not None and c['code']==0,'Absorption without successful command')
            require((kind=='SI' and c['op']==0 and c['request']) or (kind=='SF' and c['op'] in (1,2) and c['sample']),'Wrong absorption route')
            word=int(f[1],16).to_bytes(8,'little');offset=len(c['words'])
            require(offset<len(c['message']),'Surplus absorption word')
            require(word==c['message'][offset:offset+8].ljust(8,b'\0'),'Incorrect seed/nonce/byte ordering')
            c['words'].extend(word)
        elif kind=='SO':
            c=pending;require(c is not None and c['op']==0 and c['request'] and not c['ended'],'Unowned seed output')
            require(list(map(int,f[1:4]))==[c['id'],c['core'],16],'Seed output identity/length')
            data=int(f[4],16).to_bytes(16,'little');offset=len(c['raw'])
            expected=hashlib.shake_256(c['message']).digest(128)
            require(offset<128 and data==expected[offset:offset+16],'Seed SHAKE mismatch')
            c['raw'].extend(data);raw_bytes+=16
        elif kind=='SE':
            c=pending;require(c is not None and c['request'] and not c['ended'] and len(c['raw'])==128,'Early/duplicate seed completion')
            require(list(map(int,f[1:]))==[c['id'],c['core']],'Seed completion owner')
            c['ended']=True
        elif kind=='SD':
            c=pending;require(c is not None,'Completion without source command')
            jid,code,valid,p=map(int,f[1:5])
            require((jid,code)==(c['id'],c['code']),'Source completion identity/code')
            if code==0:
                require(bytes(c['words'])==c['message'].ljust(8*((len(c['message'])+7)//8),b'\0'),'Incomplete absorption')
                if c['op']==0:
                    require(c['ended'] and len(c['raw'])==128,'Seed published before full hash retirement')
                    retained=bytes(c['raw']);param=c['p'];seeds+=1;levels.add(param)
                else:
                    require(c['sample'] and c['status'],'Sampling completion before memory publication')
                    samples+=1;formatted+=len(c['words'])//8
            else:
                require(not c['request'] and not c['sample'] and not c['words'] and not c['raw'],'Rejected source command had side effects')
                errors+=1;negative.append(jid)
                if c['op']==0:param=c['p']
            require((valid,p)==(int(retained is not None),param),'Retained seed validity/level')
            material=bytes(128) if retained is None else retained
            require([int(f[5],16),int(f[6],16),int(f[7],16)]==[int.from_bytes(material[:32],'little'),int.from_bytes(material[32:96],'little'),int.from_bytes(material[96:],'little')],'Retained rho/rho-prime/K mismatch')
            pending=None
        else:
            if kind=='J':
                c=pending;require(c is not None and c['op'] in (1,2) and c['code']==0 and not c['sample'],'Unowned sample descriptor')
                fixture=row_cases()[int(f[2])]
                require(int(f[5])==c['id'] and int(f[4])==c['region'] and fixture['message']==c['message'],'Seed/sample/region binding')
                c['sample']=True
            if kind=='S':
                c=pending;require(c is not None and c['sample'] and not c['status'] and list(map(int,f[2:]))==[c['id'],0],'Unowned/duplicate sampler retirement')
                c['status']=True
            if kind=='X':
                require(pending is None,'Source reset without explicit abort')
                retained=None;param=0
            filtered.append(line)
    require(pending is None and samples==163 and errors==7 and negative==[6100,6101,6102,6104,6105,6106,6107] and levels=={0,1,2},'Incomplete seed/source campaign')
    message=verify_rows(filtered)
    return (message+f'DILITHIUM STAGE5I SEED ROW COMPARE PASS:{seeds} seed expansions,{raw_bytes} exact SHAKE bytes;'
            f'{samples} RTL-formatted sampling jobs,{formatted} absorption words,7 rejected commands;retained rho/rho-prime/K match hashlib\n')


@lru_cache(maxsize=1)
def sign_dma_cases():
    """Local component cases,not official NIST Sign vectors."""
    result=[];q=8380417;rng=random.Random(0x5D3A)
    def add(op,p,kind=0,style=0,inject=0,abort=0,code=0):
        g=95232 if p==0 else 261888;beta=(78,196,120,78)[p]
        bound=((131072 if p==0 else 524288)-beta,g-beta,g)[min(kind,2)]
        if op==0:a=[rng.randrange(q) for _ in range(256)];a[:8]=[0,g,g+1,q-1,q-g,q-g-1,1,4190208]
        elif op==1:
            a=[0]*256
            if style:a[0]=bound # early failure must survive63 passing groups
            a[4:8]=[bound-1,q-bound+1,0,1]
        else:
            a=([0,g,g+1,q-g,q-g-1,1,q-1,g-1]*32)
        b=[(i%2) for i in range(256)]
        if op==2 and style==1:b[17*4+2]=64 # truncation would incorrectly accept as0
        if op==2 and style==2:b[255]=44 if p==0 else 16
        c=dict(i=len(result),op=op,p=p,kind=kind,style=style,inject=inject,abort=abort,code=code,a=a,b=b)
        result.append(c)
    for p in range(3):
        add(0,p)
        for kind in range(3):
            add(1,p,kind);add(1,p,kind,style=1)
        add(2,p);add(2,p,style=1,code=5);add(2,p) # same-ID recovery without reset
        add(2,p,style=2,code=5);add(0,p)
    # inject1..6:missing source,wrong owner,domain,parameter,alias,occupied dest.
    for inject,code in [(1,1),(2,1),(3,2),(4,2),(5,3),(6,0)]:add(0,0,inject=inject,code=code)
    for op,p,kind in [(3,0,0),(0,3,0),(1,0,3)]:add(op,p,kind,code=4)
    # Late read fault injection goes through the real response handshake.
    # 7 owner,8 parameter,9 mode,10 region,11 word,12 error,13 noncanonical data.
    for inject in range(7,14):
        add(0,1,inject=inject,code=5 if inject==13 else 2 if inject in (8,9) else 1)
        add(0,1)
    # Reset at wait-free,read,partial writes,half-commit,held completion;CNB prefix.
    for phase in range(1,7):
        add(1 if phase==6 else 0,2,style=int(phase==6),inject=6 if phase==1 else 0,abort=phase)
        add(1 if phase==6 else 0,2)
    return result


def sign_dma_artifact(token):
    rows=sign_dma_cases();body=[]
    for c in rows:
        body.append(' '.join(str(c[k]) for k in ('i','op','p','kind','style','inject','abort','code')))
        body.extend(f'{a:06x} {b:06x}' for a,b in zip(c['a'],c['b'],strict=True))
    return f'{token} {len(rows)}\n'+'\n'.join(body)+'\n'


def verify_sign_dma(lines):
    _,token=check();rows=sign_dma_cases()
    if not lines or lines[0]!='H '+token:raise ValueError('DMA stale token')
    groups={};footer=None
    for s in lines[1:]:
        f=s.split()
        if not f:raise ValueError('DMA blank event')
        if f[0]=='F':
            if footer is not None or s!=lines[-1]:raise ValueError('DMA footer order')
            footer=list(map(int,f[1:]));continue
        i=int(f[1])
        if not 0<=i<len(rows):raise ValueError('DMA unknown case')
        groups.setdefault(i,[]).append(f)
    if set(groups)!=set(range(len(rows))) or footer is None:raise ValueError('DMA missing case/footer')
    outputs=errors=aborts=values=acks=0
    for c in rows:
        i=c['i'];events=groups[i];by={k:[f for f in events if f[0]==k] for k in ('C','W','P','Q','U','D','R','A','T')}
        if any(f[0] not in by for f in events):raise ValueError('DMA unknown event')
        if by['C']!=[['C',str(i),str(c['op']),str(c['p']),str(c['kind'])]]:raise ValueError('DMA command')
        if len(by['T'])!=1 or len(by['T'][0])!=10 or min(map(int,by['T'][0][2:]))<0:raise ValueError('DMA witnesses')
        # Mandatory source/done lease,write/response/finish stalls and atomic
        # publication witnesses are checked where those paths are applicable.
        witness=list(map(int,by['T'][0][2:]))
        if witness[0]<3 or witness[5]<3:raise ValueError('DMA missing held completion/reset/source lease witness')
        # A BRAM acknowledgment must follow its request,and successful finish
        # must follow all64 acknowledged writes for that result region.
        pending=set();acknowledged={32:set(),48:set()}
        for f in events:
            if f[0]=='P':
                key=(int(f[2]),int(f[3]))
                if key in pending or key[1] in acknowledged[key[0]]:raise ValueError('DMA duplicate packed request')
                pending.add(key)
            elif f[0]=='Q':
                key=(int(f[2]),int(f[3]))
                if key not in pending:raise ValueError('DMA ack without preceding request')
                pending.remove(key);acknowledged[key[0]].add(key[1])
            elif f[0]=='U':
                region=32 if f[2]=='0' else 48
                if any(k[0]==region for k in pending) or (f[3]=='0' and acknowledged[region]!=set(range(64))):raise ValueError('DMA finish before writes acknowledged')
        if c['abort']:
            if by['D'] or by['R'] or by['A']!=[['A',str(i),str(c['abort'])]]:raise ValueError('DMA reset leaked result')
            # Reset may cancel a partial output word or an unacknowledged
            # request. Every accepted scalar/packed prefix must still be right.
            pairs=[mathematical_decompose(a,c['p']) for a in c['a']]
            payload={32:[lo%8380417 for hi,lo in pairs],48:[hi for hi,lo in pairs]}
            want=[]
            if c['op']==0:
                for k in range(256):
                    for core in (0,1):want.append(['W',str(i),str(core),str(k),f'{payload[32 if core==0 else 48][k]:06x}',str(int(k==255))])
            if by['W']!=want[:len(by['W'])]:raise ValueError('DMA reset scalar prefix')
            for f in by['P']:
                region,k=int(f[2]),int(f[3]);value=sum(payload[region][4*k+j]<<(23*j) for j in range(4))
                if f[4]!=f'{value:023x}':raise ValueError('DMA reset packed prefix')
            if by['U']!=([['U',str(i),'0','0']] if c['abort']==4 else ([['U',str(i),'0','0'],['U',str(i),'1','0']] if c['abort']==5 else [])):
                raise ValueError('DMA reset finish stage')
            values+=len(by['W']);acks+=len(by['Q'])
            aborts+=1;continue
        if by['A']:raise ValueError('DMA unexpected reset')
        op,p=c['op'],c['p'];expected=[];high=[];reject=weight=0
        if c['code']==0:
            if op==0:
                pairs=[mathematical_decompose(a,p) for a in c['a']]
                expected=[lo%8380417 for hi,lo in pairs];high=[hi for hi,lo in pairs]
            elif op==1:
                g=95232 if p==0 else 261888;beta=(78,196,120)[p]
                bound=((131072 if p==0 else 524288)-beta,g-beta,g)[c['kind']]
                reject=int(any(min(a,8380417-a)>=bound for a in c['a']))
            else:
                g=95232 if p==0 else 261888
                expected=[int(mathematical_decompose((h*2*g+a)%8380417,p)[0]!=h) for a,h in zip(c['a'],c['b'],strict=True)]
                weight=sum(expected)
        if by['D']!=[['D',str(i),str(c['code']),'9000','32','0' if c['inject']==5 else '48',str(reject),str(weight)]]:raise ValueError('DMA completion/reductions')
        if events.index(by['D'][0])<max([events.index(f) for f in by['Q']+by['U']]+[0]):raise ValueError('DMA early publication')
        outputs+=1;errors+=int(c['code']!=0)
        # Every scalar write must match the independent oracle,even writes
        # later rolled back. Late injections stop before word17 (68 lanes).
        if c['code']:
            n=68 if c['inject']>=7 or (op==2 and c['style']==1) else 252 if op==2 and c['style']==2 else 0
            pairs=[mathematical_decompose(a,p) for a in c['a']] if op==0 else []
            if op==0:expected=[lo%8380417 for hi,lo in pairs][:n];high=[hi for hi,lo in pairs][:n]
            elif op==2:
                g=95232 if p==0 else 261888
                expected=[int(mathematical_decompose((h*2*g+a)%8380417,p)[0]!=h) for a,h in zip(c['a'][:n],c['b'][:n],strict=True)]
        want=[]
        for k,a in enumerate(expected):
            want.append(['W',str(i),'0',str(k),f'{a:06x}',str(int(k==255))])
            if op==0:want.append(['W',str(i),'1',str(k),f'{high[k]:06x}',str(int(k==255))])
        if by['W']!=want:raise ValueError(f'DMA scalar writes case{i}')
        for tag in ('P','Q'):
            wanted=[]
            for k in range(len(expected)//4):
                for core,payload in [(0,expected)]+([(1,high)] if op==0 else []):
                    record=[tag,str(i),str(32 if core==0 else 48),str(k)]
                    if tag=='P':record.append(f'{sum(payload[4*k+j]<<(23*j) for j in range(4)):023x}')
                    wanted.append(record)
            if by[tag]!=wanted:raise ValueError(f'DMA packed write/ack case{i}')
        if by['U']!=([['U',str(i),str(core),str(int(c['code']!=0))] for core in ([0,1] if op==0 else [0]) ] if expected or (op!=1 and c['inject']>=7) else []):
            raise ValueError(f'DMA finish/rollback case{i}')
        reads=[]
        if c['code']==0:
            for region,payload in [(32,expected)]+([(48,high)] if op==0 else []):
                if not payload:continue
                for k in range(64):reads.append(['R',str(i),str(region),str(k),f'{sum(payload[4*k+j]<<(23*j) for j in range(4)):023x}','9000',str(p),'0'])
            if op!=1 and (witness[1]==0 or witness[2]==0 or witness[3]==0):raise ValueError('DMA missing write/read/finish stalls')
            if op==0 and witness[4]==0:raise ValueError('DMA missing atomic pair witness')
        if by['R']!=reads:raise ValueError(f'DMA readback case{i}')
        values+=len(want);acks+=len(by['Q'])
    if footer!=[len(rows),outputs,errors,aborts]:raise ValueError('DMA footer totals')
    return f'STAGE5N3A_SIGN_DMA_COMPARE_PASS:{len(rows)} commands,{outputs} completions,{errors} expected errors,{aborts} reset aborts;{values} exact scalar writes,{acks} acknowledged packed writes\n'


def verify_sign_service(lines):
    _,token=check();gold=['H '+token];completed=0
    for p in range(3):
        a=cases()[12+2*p]['values'];pairs=[mathematical_decompose(x,p) for x in a]
        low=[lo%8380417 for hi,lo in pairs];high=[hi for hi,lo in pairs];g=95232 if p==0 else 261888
        def reads(tag,phase,region,payload,jid):
            return [f'{tag} {p} {phase} {region} {w} {sum(payload[4*w+j]<<(23*j) for j in range(4)):023x} {jid} {p} 0' for w in range(64)]
        gold.extend(reads('S',0,0,a,100+p))
        for phase in range(11):
            op=0 if phase==0 else 2 if phase in (4,5,8,10) else 1
            cp=(p+1)%3 if phase==7 else p;kind=1 if phase==2 else 2 if phase==3 else 0
            src=32 if phase in (2,3,5,6,7) else 0;b=0 if phase==8 else 48
            dest=32 if phase==0 else 16 if phase==4 else 17 if phase==5 else 18
            gold.append(f'C {p} {phase} {op} {cp} {kind} {src} {b} {dest} {9000+phase}')
            if phase==10:gold.append(f'A {p} {phase}');continue
            code=1 if phase==6 else 2 if phase==7 else 5 if phase==8 else 0
            reject=weight=0;hint=[]
            if op==1 and code==0:
                beta=(78,196,120)[p];bound=((131072 if p==0 else 524288)-beta,g-beta,g)[kind]
                reject=int(any(min(x,8380417-x)>=bound for x in (low if src==32 else a)))
            elif op==2 and code==0:
                hint=[int(mathematical_decompose((hi*2*g+x)%8380417,p)[0]!=hi) for hi,x in zip(high,low if src==32 else a,strict=True)]
                weight=sum(hint)
            gold.append(f'D {p} {phase} {code} {9000+phase} {dest} 48 {reject} {weight}');completed+=1
            if phase==0:gold.extend(reads('R',phase,32,low,9000));gold.extend(reads('R',phase,48,high,9000))
            if phase in (4,5):gold.extend(reads('R',phase,dest,hint,9000+phase))
        # Runtime witness counts vary with ready/valid stalls;the mandatory
        # adversarial paths must all execute,not merely appear as zero totals.
        witness=next((s for s in lines if s.startswith(f'T {p} ')),None)
        if witness is None or len(witness.split())!=9 or any(int(x)<=0 for x in witness.split()[2:]):raise ValueError('Missing shared arbiter/lease/atomic witness')
        gold.append(witness)
    gold.append(f'F {completed} 3 192 768')
    if lines!=gold:
        mismatch=next((i for i,(a,b) in enumerate(zip(lines,gold)) if a!=b),min(len(lines),len(gold)))
        raise ValueError(f'Signing shared-service capture differs at row{mismatch}:actual={lines[mismatch:mismatch+1]},expected={gold[mismatch:mismatch+1]}')
    return 'STAGE5N3_SIGN_SERVICE_COMPARE_PASS:33 commands,30 completions,9 expected errors,3 reset aborts;192 source words,768 exact process words;row/NTT/scalar/read priority,held completion and atomic publication checked\n'


def compare(stage=2,unit='process'):
    if stage==5 and unit=='sign_service':
        message=verify_sign_service((HERE/'stage5_sign_service_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_service_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_dma':
        message=verify_sign_dma((HERE/'stage5_sign_dma_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_dma_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_process':
        message=verify_sign_process((HERE/'stage5_sign_process_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_process_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='nist_keygen':
        message=verify_full_keygen((HERE/'stage5_nist_keygen_outputs.txt').read_text().splitlines(),nist=True)
        (HERE/'stage5_nist_keygen_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='full_keygen':
        message=verify_full_keygen((HERE/'stage5_full_keygen_outputs.txt').read_text().splitlines())
        (HERE/'stage5_full_keygen_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='bitpkg':
        message=verify_bitpkg((HERE/'stage5_bitpkg_outputs.txt').read_text().splitlines())
        (HERE/'stage5_bitpkg_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit in ('keygen','rounded_keygen'):
        message=verify_keygen((HERE/f'stage5_{unit}_outputs.txt').read_text().splitlines(),rounded=unit=='rounded_keygen')
        # Alternate coefficient-domain check for row0 at each level.
        for run in range(3):
            c=keygen_cases()[run];e=keygen_expected(run);total=list(e['secrets'][e['l']])
            for j in range(e['l']):
                a=e['polys'][(c['id']+128+j)&65535]['data']
                product=ntt_reference.schoolbook(arithmetic_result(1,a),e['secrets'][j])
                total=[(x+y)%ntt_reference.Q for x,y in zip(total,product,strict=True)]
            if tuple(total)!=e['rows'][0]:raise ValueError('KeyGen coefficient-domain schoolbook mismatch')
        message+='KEYGEN_POLYNOMIAL_SCHOOLBOOK_PASS:row0 at all3 levels\n'
        (HERE/f'stage5_{unit}_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit in ('row','seed_row'):
        lines=(HERE/f'stage5_{unit}_outputs.txt').read_text().splitlines()
        message=verify_seed_rows(lines) if unit=='seed_row' else verify_rows(lines)
        # Separate coefficient-domain schoolbook check of each reference row.
        table={(c['mode'],c['param'],c['row'],c['col']):c['values'] for c in row_cases()}
        for p in range(3):
            for row in range(2):
                total=[0]*256
                for j in range((4,5,7)[p]):
                    product=ntt_reference.schoolbook(arithmetic_result(1,table[0,p,row,j]),table[1,p,0,j])
                    total=[(x+y)%ntt_reference.Q for x,y in zip(total,product,strict=True)]
                if tuple(total)!=row_expected(p,row):raise ValueError('Whole-row schoolbook mismatch')
        accepted=[s.split() for s in lines if s.startswith('I ')]
        oracle=subprocess.run([str(HERE/'reference_build/process_reference.exe')],
            input=''.join(f'0 {int(f[3],16)} {int(f[4],16)}\n' for f in accepted),
            check=True,capture_output=True,text=True).stdout.splitlines()
        if len(oracle)!=len(accepted):raise ValueError('C row ADD count')
        golden={(int(f[1]),int(f[2])):list(map(int,r.split())) for f,r in zip(accepted,oracle,strict=True)}
        completed=0
        for line in lines:
            if not line.startswith('K '):continue
            f=line.split()
            if [int(f[3]),int(f[6],16),*map(int,f[7:10])]!=golden[int(f[1]),int(f[2])]:raise ValueError('C row ADD mismatch')
            completed+=1
        message+=f'ROW_SCHOOLBOOK_PASS:6 independent full reference rows;C_ROW_ADD_PASS:{len(accepted)} inputs,{completed} completed results\n'
        (HERE/f'stage5_{unit}_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='bank_process':
        lines=(HERE/'stage5_process_banks_outputs.txt').read_text().splitlines()
        message=verify_process_banks(lines)
        accepted=[line.split() for line in lines if line.startswith('I ')]
        stimuli=''.join(f'{process_bank_program()[int(f[1])][1]} {int(f[3],16)} {int(f[4],16)}\n' for f in accepted)
        oracle=subprocess.run([str(HERE/'reference_build/process_reference.exe')],input=stimuli,check=True,capture_output=True,text=True).stdout.splitlines()
        if len(oracle)!=len(accepted):raise ValueError('C bank process count')
        expected={(int(f[1]),int(f[2])):list(map(int,result.split())) for f,result in zip(accepted,oracle,strict=True)}
        completed=0
        for line in lines:
            if not line.startswith('K '):continue
            f=line.split();actual=[int(f[3]),int(f[6],16),*map(int,f[7:10])]
            if actual!=expected[(int(f[1]),int(f[2]))]:raise ValueError('C bank process arithmetic mismatch')
            completed+=1
        c_message=f'C_BANK_PROCESS_PASS:{len(accepted)} accepted operands,{completed} exact completed arithmetic results\n'
        (HERE/'stage5_process_banks_c_reference.log').write_text(c_message)
        message+=c_message
        (HERE/'stage5_process_banks_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='bank_ntt':
        message=verify_ntt((HERE/'stage5_ntt_banks_outputs.txt').read_text().splitlines(),banked=True)
        (HERE/'stage5_ntt_banks_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='bank_store':
        message=verify_bank_store((HERE/'stage5_store_outputs.txt').read_text().splitlines())
        (HERE/'stage5_store_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='bank_memory':
        message=verify_bank_memory((HERE/'stage5_banks_outputs.txt').read_text().splitlines())
        (HERE/'stage5_banks_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='shared_hash':
        message=verify_shared_hash((HERE/'stage5_shared_outputs.txt').read_text().splitlines())
        (HERE/'stage5_shared_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='hash_format':
        message=verify_hash_format((HERE/'stage5_hash_outputs.txt').read_text().splitlines())
        (HERE/'stage5_hash_compare.log').write_text(message);print(message,end='');return
    message={2:verify,3:verify_memory,4:verify_ntt,5:verify_process}[stage]((HERE/f'stage{stage}_outputs.txt').read_text().splitlines())
    (HERE/f'stage{stage}_compare.log').write_text(message);print(message,end='')


def selftest(stage=2,unit='process'):
    if stage==5 and unit=='sign_service':
        original=(HERE/'stage5_sign_service_outputs.txt').read_text().splitlines();verify_sign_service(original);trials=[]
        for tag,col,base in [('C',3,10),('C',4,10),('C',6,10),('C',7,10),('C',8,10),('C',9,10),('D',3,10),('D',4,10),('D',5,10),('D',6,10),('D',7,10),('D',8,10),('S',5,16),('R',5,16),('R',6,10),('R',7,10),('R',8,10)]:
            idx=next(i for i,s in enumerate(original) if s.startswith(tag+' '));f=original[idx].split();lines=original.copy()
            f[col]=format(int(f[col],base)^1,'x') if base==16 else str(int(f[col])^1);lines[idx]=' '.join(f);trials.append((tag+str(col),lines))
        for col in range(2,9):
            idx=next(i for i,s in enumerate(original) if s.startswith('T '));f=original[idx].split();f[col]='0';lines=original.copy();lines[idx]=' '.join(f);trials.append(('witness'+str(col),lines))
        for tag in ('C','D','S','R','A','T'):
            idx=next(i for i,s in enumerate(original) if s.startswith(tag+' '));trials.append(('missing_'+tag,original[:idx]+original[idx+1:]))
        trials.extend([('footer',original[:-1]),('duplicate',original+[original[-1]]),('stale',['H '+'0'*64]+original[1:])])
        for label,lines in trials:
            try:verify_sign_service(lines)
            except (ValueError,IndexError,KeyError,TypeError):continue
            raise ValueError('Shared signing checker accepted corruption:'+label)
        message=f'STAGE5N3_SIGN_SERVICE_CHECKER_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_service_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_dma':
        original=(HERE/'stage5_sign_dma_outputs.txt').read_text().splitlines();verify_sign_dma(original);trials=[]
        for tag,col,base in [('W',4,16),('W',3,10),('W',2,10),('W',5,10),('P',4,16),('Q',2,10),('U',3,10),('D',2,10),('D',3,10),('D',6,10),('D',7,10),('R',4,16),('R',5,10),('R',6,10),('R',7,10),('T',2,10)]:
            idx=next(i for i,s in enumerate(original) if s.startswith(tag+' '));lines=original.copy();f=lines[idx].split()
            f[col]='0' if tag=='T' else format(int(f[col],base)^1,'x') if base==16 else str(int(f[col])^1)
            lines[idx]=' '.join(f);trials.append((tag+str(col),lines))
        for tag in ('C','W','P','Q','U','D','R','A','T'):
            idx=next(i for i,s in enumerate(original) if s.startswith(tag+' '));trials.append(('missing_'+tag,original[:idx]+original[idx+1:]))
        for tag in ('Q','U'):
            idx=next(i for i,s in enumerate(original) if s.startswith(tag+' '));event=original[idx];lines=original[:idx]+original[idx+1:]
            before=next(i for i,s in enumerate(lines) if s.startswith('P '));lines.insert(before,event);trials.append(('early_'+tag,lines))
        aborted={s.split()[1] for s in original if s.startswith('A ')}
        idx=next(i for i,s in enumerate(original) if s.startswith('W ') and s.split()[1] in aborted)
        lines=original.copy();f=lines[idx].split();f[4]=f'{int(f[4],16)^1:06x}';lines[idx]=' '.join(f);trials.append(('reset_write',lines))
        idx=next(i for i,s in enumerate(original) if s.startswith('T '));f=original[idx].split();f[7]='0';lines=original.copy();lines[idx]=' '.join(f);trials.append(('source_lease',lines))
        trials.extend([('footer',original[:-1]),('duplicate',original+[original[-1]]),('stale',['H '+'0'*64]+original[1:])])
        for label,lines in trials:
            try:verify_sign_dma(lines)
            except (ValueError,IndexError,KeyError,TypeError):continue
            raise ValueError('DMA checker accepted corruption:'+label)
        message=f'STAGE5N3A_SIGN_DMA_CHECKER_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_dma_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_process':
        original=(HERE/'stage5_sign_process_outputs.txt').read_text().splitlines();verify_sign_process(original);trials=[]
        for col in range(2,15):
            if col==9:idx=next(i for i,s in enumerate(original) if s.startswith('P ') and s.split()[3]=='0' and int(s.split()[9],16)>0)
            elif col==10:idx=next(i for i,s in enumerate(original) if s.startswith('P ') and s.split()[3]=='0' and int(s.split()[10],16)>0)
            else:idx=next(i for i,s in enumerate(original) if s.startswith('P '))
            changed=original.copy();f=changed[idx].split();base=16 if col in (9,10) else 10
            f[col]=format(int(f[col],base)^1,'x') if base==16 else str(int(f[col])^1)
            changed[idx]=' '.join(f);trials.append(('field_'+str(col),changed))
        for op,col in [(0,9),(0,10),(1,12),(1,13),(2,11),(2,14)]:
            idx=next(i for i,s in enumerate(original) if s.startswith('P ') and s.split()[3]==str(op) and int(s.split()[col],16 if col in (9,10) else 10)>0 and (col!=13 or s.split()[12]=='0'))
            changed=original.copy();f=changed[idx].split();f[col]='0';changed[idx]=' '.join(f);trials.append((f'lost_result_{op}_{col}',changed))
        for kind in ('J','P','A','X'):
            idx=next(i for i,s in enumerate(original[1:],1) if s.startswith(kind+' ') or s==kind)
            trials.append(('missing_'+kind,original[:idx]+original[idx+1:]))
        idx=next(i for i,s in enumerate(original) if s.startswith('J '));trials.append(('duplicate_input',original[:idx]+[original[idx]]+original[idx:]))
        trials += [('missing_footer',original[:-1]),('extra_footer',original+[original[-1]]),('stale_token',['H '+'0'*64]+original[1:])]
        for label,lines in trials:
            try:verify_sign_process(lines)
            except (ValueError,IndexError,KeyError,TypeError):continue
            raise ValueError('Signing-process checker accepted corruption:'+label)
        message=f'STAGE5N2_SIGN_PROCESS_CHECKER_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_process_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='nist_keygen':
        original=(HERE/'stage5_nist_keygen_outputs.txt').read_text().splitlines()
        verify_full_keygen(original,nist=True);trials=[]
        for kind,column,base in [('B',3,10),('B',5,16),('H',2,10),('H',5,10),('I',2,16),
                                 ('T',2,10),('T',5,16),('HD',2,10),('O',2,10),('O',3,10),
                                 ('O',4,10),('O',5,10),('O',6,10),('O',7,16),('M',5,10),
                                 ('M',6,10),('M',8,10),('D',2,10)]:
            index=next(i for i,s in enumerate(original[1:],1) if s.startswith(kind+' '))
            changed=original.copy();f=changed[index].split()
            f[column]=format(int(f[column],base)^1,'x') if base==16 else str(int(f[column])^1)
            changed[index]=' '.join(f);trials.append((kind+str(column),changed))
        for run in (0,25,50):
            for typ in (0,1):
                index=next(i for i in range(len(original)-1,0,-1) if original[i].startswith(f'O {run} ') and original[i].split()[3]==str(typ))
                changed=original.copy();f=changed[index].split();f[7]=f'{int(f[7],16)^(1<<63):016x}'
                changed[index]=' '.join(f);trials.append((f'last_byte_{run}_{typ}',changed))
        for kind in ('H','I','T','HD','O','M','D','CLEAN'):
            index=next(i for i,s in enumerate(original[1:],1) if s.startswith(kind+' '))
            trials.append(('missing_'+kind,original[:index]+original[index+1:]))
        for kind in ('B','O','I'):
            index=next(i for i,s in enumerate(original[1:],1) if s.startswith(kind+' '))
            trials.append(('duplicate_'+kind,original[:index]+[original[index]]+original[index:]))
        index=next(i for i,s in enumerate(original[1:],1) if s.startswith('H '))
        trials.append(('premature_release',original[:index]+['L 0 1']+original[index:]))
        index=next(i for i,s in enumerate(original) if s.startswith('B 74 '))
        trials.append(('missing_final_case',original[:index]+original[-2:]))
        trials += [('stale_token',['H '+'0'*64]+original[1:]),('extra_footer',original+[original[-1]])]
        index=next(i for i,s in enumerate(original) if s.startswith('Q '))
        trials.append(('missing_ownership',original[:index]+original[index+1:]))
        changed=original.copy();f=changed[index].split();f[2]='0';changed[index]=' '.join(f)
        trials.append(('missing_cleanup_ownership',changed))
        for label,lines in trials:
            try:verify_full_keygen(lines,nist=True)
            except (ValueError,IndexError,KeyError,TypeError):continue
            raise ValueError('NIST KeyGen checker accepted corruption:'+label)
        message=f'STAGE5M NIST KEYGEN CHECKER PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_nist_keygen_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='full_keygen':
        original=(HERE/'stage5_full_keygen_outputs.txt').read_text().splitlines();verify_full_keygen(original);trials=[]
        for kind,column,base in [('B',5,16),('H',2,10),('H',5,10),('I',2,16),('T',2,10),('T',5,16),('HD',2,10),
                                 ('O',2,10),('O',3,10),('O',4,10),('O',5,10),('O',6,10),('O',7,16),('M',5,10),
                                 ('M',6,10),('M',8,10),('D',2,10),('A',2,10)]:
            index=next(i for i,s in enumerate(original[1:],1) if s.startswith(kind+' '));changed=original.copy();f=changed[index].split()
            f[column]=format(int(f[column],base)^1,'x') if base==16 else str(int(f[column])^1)
            changed[index]=' '.join(f);trials.append((kind+str(column),changed))
        for kind in ('H','I','T','HD','O','M','D','CLEAN','A'):
            index=next(i for i,s in enumerate(original[1:],1) if s.startswith(kind+' '));trials.append(('missing_'+kind,original[:index]+original[index+1:]))
        for word in (20,319):
            index=next(i for i,s in enumerate(original) if s.startswith('O 0 ') and s.split()[3]=='1' and int(s.split()[4])==word)
            changed=original.copy();f=changed[index].split();f[7]=format(int(f[7],16)^1,'x')
            changed[index]=' '.join(f);trials.append((f'secret_word_{word}',changed))
        index=next(i for i,s in enumerate(original[1:],1) if s.startswith('H '))
        trials.append(('premature_secret_release',original[:index]+['L 0 1']+original[index:]))
        for kind in ('H','O','I'):
            index=next(i for i,s in enumerate(original[1:],1) if s.startswith(kind+' '))
            trials.append(('duplicate_'+kind,original[:index]+[original[index]]+original[index:]))
        trials += [('stale_token',['H '+'0'*64]+original[1:]),('extra_footer',original+[original[-1]])]
        index=next(i for i,s in enumerate(original) if s.startswith('Q '))
        trials.append(('missing_ownership',original[:index]+original[index+1:]))
        changed=original.copy();f=changed[index].split();f[2]='0';changed[index]=' '.join(f)
        trials.append(('missing_cleanup_ownership',changed))
        for label,lines in trials:
            try:verify_full_keygen(lines)
            except (ValueError,IndexError,KeyError,TypeError):continue
            raise ValueError('Full-KeyGen checker accepted corruption:'+label)
        message=f'STAGE5L FULL KEYGEN CHECKER PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_full_keygen_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='bitpkg':
        original=(HERE/'stage5_bitpkg_outputs.txt').read_text().splitlines();verify_bitpkg(original);trials=[]
        for kind,col,base in [('B',2,10),('I',2,10),('I',4,16),('O',2,10),('O',3,10),('O',4,10),('O',5,10),('O',6,16),('D',3,10),('A',3,10)]:
            index=next(i for i,s in enumerate(original) if s.startswith(kind+' '));changed=original.copy();f=changed[index].split()
            f[col]=format(int(f[col],base)^1,'x') if base==16 else str(int(f[col])^1)
            changed[index]=' '.join(f);trials.append((kind+str(col),changed))
        for kind in ('B','I','O','D','A'):
            index=next(i for i,s in enumerate(original) if s.startswith(kind+' '));trials.append(('missing_'+kind,original[:index]+original[index+1:]))
        for label,lines in trials:
            try:verify_bitpkg(lines)
            except (ValueError,IndexError,KeyError,TypeError):continue
            raise ValueError('Bitpkg checker accepted corruption:'+label)
        message=f'STAGE5K BITPKG CHECKER PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_bitpkg_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit in ('keygen','rounded_keygen'):
        original=(HERE/f'stage5_{unit}_outputs.txt').read_text().splitlines()
        validate=lambda lines:verify_keygen(lines,rounded=unit=='rounded_keygen')
        validate(original);trials=[]
        for kind,col,base in [('B',4,10),('B',5,16),('K',2,16),('K',3,16),('K',4,16),('J',4,10),('J',5,10),('I',2,16),
                              ('V',4,10),('W',4,16),('W',3,10),('W',5,10),('R',4,16),('R',5,10),('E',2,10),('D',2,10),('L',2,10),('A',2,10)]:
            index=next(i for i,s in enumerate(original) if s.startswith(kind+' '));changed=original.copy();f=changed[index].split()
            f[col]=format(int(f[col],base)^1,'x') if base==16 else str(int(f[col])^1)
            changed[index]=' '.join(f);trials.append((kind+str(col),changed))
        for kind in ('K','J','I','V','W','U','R','E','D','CLEAN','A'):
            index=next(i for i,s in enumerate(original) if s.startswith(kind+' '));trials.append(('missing_'+kind,original[:index]+original[index+1:]))
        if unit=='rounded_keygen':
            for region in (56,40):
                for kind,column in (('R',4),('R',5),('V',4)):
                    index=next(i for i,s in enumerate(original) if s.startswith(kind+' ') and
                               int(s.split()[2 if kind=='R' else 3])==region)
                    changed=original.copy();f=changed[index].split();base=16 if kind=='R' and column==4 else 10
                    f[column]=format(int(f[column],base)^1,'x') if base==16 else str(int(f[column])^1)
                    changed[index]=' '.join(f);trials.append((f'rounded_{region}_{kind}_{column}',changed))
            first_high=next(i for i,s in enumerate(original) if s.startswith('V ') and int(s.split()[3])==40)
            index=next(i for i in range(first_high,len(original)) if original[i].startswith('U ') and original[i].split()[2]=='1')
            trials.append(('missing_high_commit',original[:index]+original[index+1:]))
        for label,lines in trials:
            try:validate(lines)
            except (ValueError,IndexError,KeyError,TypeError):continue
            raise ValueError('KeyGen checker accepted corruption:'+label)
        label='STAGE5K ROUNDED' if unit=='rounded_keygen' else 'STAGE5J'
        message=f'{label} KEYGEN POLYNOMIAL CHECKER PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/f'stage5_{unit}_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='seed_row':
        original=(HERE/'stage5_seed_row_outputs.txt').read_text().splitlines();verify_seed_rows(original);trials=[]
        for kind,column,base in [('SC',8,16),('SR',4,10),('SI',1,16),('SO',4,16),('SO',1,10),('SE',1,10),
                                  ('SF',1,16),('SD',2,10),('SD',5,16),('SD',6,16),('SD',7,16),('W',4,16),('R',4,16)]:
            index=next(i for i,s in enumerate(original) if s.startswith(kind+' '));changed=original.copy();f=changed[index].split()
            f[column]=format(int(f[column],base)^1,'x') if base==16 else str(int(f[column])^1)
            changed[index]=' '.join(f);trials.append((kind+str(column),changed))
        for kind in ('SC','SR','SI','SO','SE','SF','SD','J','U','DROW'):
            index=next(i for i,s in enumerate(original) if s.startswith(kind+' '));trials.append(('missing_'+kind,original[:index]+original[index+1:]))
        for label,lines in trials:
            try:verify_seed_rows(lines)
            except (ValueError,IndexError,KeyError,TypeError):continue
            raise ValueError('Seed-row checker accepted corruption:'+label)
        message=f'STAGE5I SEED ROW CHECKER PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_seed_row_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='row':
        original=(HERE/'stage5_row_outputs.txt').read_text().splitlines();verify_rows(original);trials=[]
        for kind,column,base,label in [('B',2,10,'row_parameter'),('B',9,10,'matrix_owner'),('B',11,10,'secret_owner'),
            ('DROW',5,10,'completed_term_count'),('C',10,10,'inplace_enable'),('V',7,10,'destination_domain'),
            ('W',4,16,'scalar_write'),('P',4,16,'packed_write'),('Q',3,10,'ack_index'),
            ('M',4,16,'cached_old_word'),('M',6,10,'overwrite_frontier'),('I',3,16,'old_accumulator'),
            ('K',6,16,'ADD_value'),('N',3,16,'NTT_value'),('R',4,16,'row_readback'),('L',1,10,'scratch_release')]:
            index=next(i for i,s in enumerate(original) if s.startswith(kind+' '));changed=original.copy();f=changed[index].split()
            value=int(f[column],base)^1;f[column]=format(value,'x') if base==16 else str(value);changed[index]=' '.join(f);trials.append((label,changed))
        for kind in ('O','C','M','P','Q','U','DROW','Z'):
            index=next(i for i,s in enumerate(original) if s.startswith(kind+' '));trials.append(('missing_'+kind,original[:index]+original[index+1:]))
        trials += [('stale_token',['H '+'0'*64]+original[1:]),('extra_footer',original+[original[-1]])]
        for label,lines in trials:
            try:verify_rows(lines)
            except (ValueError,IndexError,KeyError):continue
            raise ValueError('Row checker accepted corruption:'+label)
        message=f'STAGE5H ROW CHECKER PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_row_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='bank_process':
        original=(HERE/'stage5_process_banks_outputs.txt').read_text().splitlines()
        verify_process_banks(original);trials=[]
        for kind,column,base,label in [('I',3,16,'operand_A'),('I',4,16,'operand_B'),('K',6,16,'ADD_value'),
            ('W',4,16,'write_value'),('W',2,10,'packer_core'),('W',3,10,'write_index'),
            ('P',4,16,'packed_word'),('P',2,10,'packed_region'),('P',3,10,'packed_index'),
            ('Q',3,10,'ack_index'),('V',5,10,'allocation_mode'),('V',7,10,'allocation_domain'),
            ('D',4,10,'done_ID'),('R',4,16,'read_data'),('R',9,10,'small_flag'),('G',4,10,'atomic_witness'),('Y',4,10,'partial_publication')]:
            row=next(i for i,s in enumerate(original) if s.startswith(kind+' '))
            changed=original.copy();f=changed[row].split();value=int(f[column],base)^1
            f[column]=format(value,'x') if base==16 else str(value);changed[row]=' '.join(f);trials.append((label,changed))
        rounding=next(i for i,s in enumerate(original) if s.startswith('K ') and process_bank_program()[int(s.split()[1])][1]==2)
        for column,label in ((7,'P2R_high'),(8,'P2R_low'),(9,'P2R_encoding')):
            changed=original.copy();f=changed[rounding].split();f[column]=str(int(f[column])^1);changed[rounding]=' '.join(f);trials.append((label,changed))
        for kind in ('I','P','Q','U','D','R'):
            row=next(i for i,s in enumerate(original) if s.startswith(kind+' '))
            trials.append(('missing_'+kind,original[:row]+original[row+1:]))
        high_commit=next(i for i,s in enumerate(original) if s.startswith('U ') and s.split()[2]=='1' and process_bank_program()[int(s.split()[1])][0]=='P')
        trials += [('missing_high_commit',original[:high_commit]+original[high_commit+1:]),
                   ('stale_token',['H '+'0'*64]+original[1:]),('duplicate_footer',original+[original[-1]])]
        for label,lines in trials:
            try:verify_process_banks(lines)
            except (ValueError,IndexError,KeyError):continue
            raise ValueError('Bank process checker accepted corruption:'+label)
        message=f'STAGE5G BANK PROCESS CHECKER PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_process_banks_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='bank_ntt':
        original=(HERE/'stage5_ntt_banks_outputs.txt').read_text().splitlines()
        verify_ntt(original,banked=True);trials=[]
        for kind,column,base,label in [('K',3,16,'NTT_value'),('T',6,16,'DMA_value'),('T',4,10,'DMA_id'),
              ('R',3,16,'read_value'),('R',7,10,'domain'),('R',8,10,'small'),('O',4,10,'source_id'),
              ('V',2,10,'reservation'),('D',4,10,'done_id'),('P',5,16,'packed_word'),
              ('P',3,10,'packed_region'),('P',4,10,'packed_index'),('Q',4,10,'ack_index'),('G',4,10,'held_result_witness')]:
            row=next(i for i,s in enumerate(original) if s.startswith(kind+' '))
            changed=original.copy();fields=changed[row].split();value=int(fields[column],base)^1
            fields[column]=format(value,'x') if base==16 else str(value);changed[row]=' '.join(fields)
            trials.append((label,changed))
        for kind in ('K','Q','D'):
            row=next(i for i,s in enumerate(original) if s.startswith(kind+' '))
            trials.append(('missing_'+kind,original[:row]+original[row+1:]))
        trials += [('stale_token',['H '+'0'*64]+original[1:]),('duplicate_footer',original+[original[-1]])]
        for label,lines in trials:
            try:verify_ntt(lines,banked=True)
            except (ValueError,IndexError,KeyError):continue
            raise ValueError('Bank NTT checker accepted corruption:'+label)
        message=f'STAGE5F BANK NTT CHECKER PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_ntt_banks_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='bank_store':
        original=(HERE/'stage5_store_outputs.txt').read_text().splitlines();verify_bank_store(original);trials=[]
        for kind,column,base,label in [('K',4,16,'packed_data'),('K',2,10,'write_region'),('K',3,10,'write_word'),
                                     ('B',3,10,'ack_word'),('R',4,16,'read_data'),('R',5,10,'read_ID'),
                                     ('R',8,10,'domain'),('R',9,10,'bounded'),('S',3,10,'status'),('G',1,10,'fault_gate')]:
            index=next(k for k,s in enumerate(original) if s.startswith(kind+' '));lines=original.copy();f=lines[index].split()
            value=int(f[column],base)^1;f[column]=format(value,'x') if base==16 else str(value);lines[index]=' '.join(f);trials.append((label,lines))
        index=next(k for k,s in enumerate(original) if s.startswith('K '))
        trials += [('missing_write',original[:index]+original[index+1:]),('stale_token',['H '+'0'*64]+original[1:])]
        for label,lines in trials:
            try:verify_bank_store(lines)
            except (ValueError,KeyError,IndexError):continue
            raise ValueError('Bank-store checker accepted corruption:'+label)
        message='STAGE5 STORE CHECKER PASS:12/12 corruptions rejected\n'
        (HERE/'stage5_store_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='bank_memory':
        original=(HERE/'stage5_banks_outputs.txt').read_text().splitlines();verify_bank_memory(original)
        ri=next(i for i,s in enumerate(original) if s.startswith('R ') and s.split()[5]=='0')
        ji=next(i for i,s in enumerate(original) if s.startswith('J '));trials=[]
        for column,base,label in [(7,16,'read_word'),(6,10,'address'),(3,10,'bank'),(4,10,'port'),
                                  (5,10,'write_flag'),(1,10,'command_id')]:
            lines=original.copy();f=lines[ri].split();v=int(f[column],base)^1
            f[column]=format(v,'x') if base==16 else str(v);lines[ri]=' '.join(f);trials.append((label,lines))
        lines=original.copy();f=lines[ri].split();f[2]='0';lines[ri]=' '.join(f);trials.append(('response_latency',lines))
        trials += [('missing_read',original[:ri]+original[ri+1:]),('duplicate_request',original[:ji]+[original[ji]]+original[ji:]),
                   ('stale_token',['H '+'0'*64]+original[1:]),('missing_footer',original[:-1]),
                   ('missing_reset',[s for s in original if not s.startswith('X ')])]
        for label,lines in trials:
            try:verify_bank_memory(lines)
            except (ValueError,IndexError,KeyError):continue
            raise ValueError('Bank checker accepted corruption:'+label)
        message='STAGE5 BANKS CHECKER PASS:12/12 corruptions rejected\n'
        (HERE/'stage5_banks_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='shared_hash':
        original=(HERE/'stage5_shared_outputs.txt').read_text().splitlines();verify_shared_hash(original);trials=[]
        for kind,column,base,label in [('O',6,16,'raw_value'),('O',2,10,'raw_core'),('O',3,10,'raw_ID'),
                                     ('O',5,10,'valid_bytes'),('Z',5,16,'rho'),('Z',6,16,'rho_prime'),
                                     ('Z',7,16,'key'),('C',5,16,'coefficient'),('C',4,10,'coefficient_index'),
                                     ('Z',2,10,'seed_error')]:
            j=next(j for j,s in enumerate(original) if s.startswith(kind+' '));lines=original.copy();f=lines[j].split()
            v=int(f[column],base)^1;f[column]=format(v,'x') if base==16 else str(v);lines[j]=' '.join(f);trials.append((label,lines))
        j=next(j for j,s in enumerate(original) if s.startswith('D '))
        trials += [('missing_raw_completion',original[:j]+original[j+1:]),('stale_token',['H '+'0'*64]+original[1:])]
        for label,lines in trials:
            try:verify_shared_hash(lines)
            except (ValueError,IndexError):continue
            raise ValueError('Shared checker accepted corruption:'+label)
        message='STAGE5 SHARED HASH CHECKER PASS:12/12 corruptions rejected\n'
        (HERE/'stage5_shared_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='hash_format':
        original=(HERE/'stage5_hash_outputs.txt').read_text().splitlines();verify_hash_format(original)
        trials=[]
        for kind,column,label in [('D',2,'mode'),('D',3,'message_length'),('D',4,'output_length'),
                                  ('W',2,'word_index'),('W',3,'absorbed_byte'),('V',2,'output_index'),
                                  ('V',3,'output_bytes'),('V',5,'hash_byte'),('S',2,'ID'),('S',3,'error')]:
            row=next(i for i,s in enumerate(original) if s.startswith(kind+' '))
            lines=original.copy();f=lines[row].split();base=16 if label in ('absorbed_byte','hash_byte') else 10
            f[column]=format(int(f[column],base)^1,'x') if base==16 else str(int(f[column])^1)
            lines[row]=' '.join(f);trials.append((label,lines))
        trials += [('stale_token',['H '+'0'*64]+original[1:]),('missing_footer',original[:-1])]
        for label,lines in trials:
            try:verify_hash_format(lines)
            except (ValueError,IndexError):continue
            raise ValueError('Hash formatter checker accepted corruption:'+label)
        message='STAGE5 HASH FORMAT CHECKER PASS:12/12 corruptions rejected\n'
        (HERE/'stage5_hash_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5:
        original=(HERE/'stage5_outputs.txt').read_text().splitlines();verify_process(original)
        pi=next(i for i,s in enumerate(original) if s.startswith('P '))
        ji=next(i for i,s in enumerate(original) if s.startswith('J '));trials=[]
        for label,col in [('error',2),('residue',3),('high',4),('signed_low',5),('packed_t0',6),
                          ('ID',7),('index',8),('last',9),('operation',10)]:
            lines=original.copy();f=lines[pi].split();f[col]=str(int(f[col])^1);lines[pi]=' '.join(f)
            trials.append((label,lines))
        trials += [('missing_output',original[:pi]+original[pi+1:]),
                   ('duplicate_input',original[:ji]+[original[ji]]+original[ji:]),
                   ('stale_token',['H '+'0'*64]+original[1:])]
        for label,lines in trials:
            try:verify_process(lines)
            except (ValueError,IndexError):continue
            raise ValueError('Process checker accepted corruption:'+label)
        message='STAGE5 PROCESS CHECKER PASS:12/12 corruptions rejected\n'
        (HERE/'stage5_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==4:
        original=(HERE/'stage4_outputs.txt').read_text().splitlines();verify_ntt(original)
        ri=next(i for i,s in enumerate(original) if s.startswith('R '))
        ki=next(i for i,s in enumerate(original) if s.startswith('K '))
        ti=next(i for i,s in enumerate(original) if s.startswith('T '))
        oi=next(i for i,s in enumerate(original) if s.startswith('O '))
        vi=next(i for i,s in enumerate(original) if s.startswith('V '))
        di=next(i for i,s in enumerate(original) if s.startswith('D '))
        trials=[]
        for label,row,column in [('output',ki,3),('DMA_value',ti,6),('DMA_id',ti,4),('read_value',ri,3),
                                 ('domain',ri,7),('source_id',oi,4),('reservation',vi,2),('done_id',di,4)]:
            lines=original.copy();f=lines[row].split();base=16 if label in ('output','DMA_value','read_value') else 10
            changed=int(f[column],base)^1;f[column]=format(changed,'x') if base==16 else str(changed)
            lines[row]=' '.join(f);trials.append((label,lines))
        trials += [('missing_output',original[:ki]+original[ki+1:]),('missing_commit',original[:di]+original[di+1:]),
                   ('stale_token',['H '+'0'*64]+original[1:]),('extra_read',original+[original[ri]])]
        for label,lines in trials:
            try:verify_ntt(lines)
            except (ValueError,IndexError,KeyError):continue
            raise ValueError('NTT checker accepted corruption:'+label)
        message='STAGE4 CHECKER SELFTEST PASS:12/12 corruptions rejected\n'
        (HERE/'stage4_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==3:
        original=(HERE/'stage3_outputs.txt').read_text().splitlines()
        verify_memory(original)
        ri=next(i for i,s in enumerate(original) if s.startswith('R '))
        trials=[]
        for label,column,value in [('value',4,'ffffff'),('slot',2,'4'),('index',3,'1'),
                                    ('job_id',5,'0'),('mode',6,'3'),('parameter',7,'3'),('domain',8,'1')]:
            lines=original.copy();f=lines[ri].split()
            if f[column]==value:value='0'
            f[column]=value;lines[ri]=' '.join(f);trials.append((label,lines))
        ji=next(i for i,s in enumerate(original) if s.startswith('J '))
        si=next(i for i,s in enumerate(original) if s.startswith('S '))
        trials += [('missing_read',original[:ri]+original[ri+1:]),
                   ('duplicate_job',original[:ji]+[original[ji]]+original[ji:]),
                   ('missing_commit',original[:si]+original[si+1:]),
                   ('stale_token',['H '+'0'*64]+original[1:]),
                   ('extra_read',original+[original[ri]])]
        for label,lines in trials:
            try:verify_memory(lines)
            except (ValueError,IndexError):continue
            raise ValueError('Memory checker accepted corruption:'+label)
        message='STAGE3 CHECKER SELFTEST PASS:12/12 corruptions rejected\n'
        (HERE/'stage3_checker_selftest.log').write_text(message);print(message,end='');return
    original=(HERE/'stage2_outputs.txt').read_text().splitlines()
    verify(original)
    ci=next(i for i,s in enumerate(original) if s.startswith('C '))
    ji=next(i for i,s in enumerate(original) if s.startswith('J '))
    si=next(i for i,s in enumerate(original) if s.startswith('S '))
    trials=[]
    for label,row,column,value in [
        ('value',ci,4,lambda v:f'{int(v,16)^1:06x}'),
        ('index',ci,3,lambda v:str(int(v)+1)),
        ('core',ci,2,lambda v:str(int(v)^1)),
        ('job_id',ji,3,lambda v:str(int(v)+1)),
        ('last',ci,5,lambda v:str(int(v)^1)),
        ('status',si,3,lambda v:str(int(v)+1)),
        ('case',ci,1,lambda v:'104'),
        ('footer',len(original)-1,1,lambda v:'103')]:
        lines=original.copy();f=lines[row].split();f[column]=value(f[column]);lines[row]=' '.join(f)
        trials.append((label,lines))
    trials += [('missing_coefficient',original[:ci]+original[ci+1:]),
               ('duplicate_descriptor',original[:ji]+[original[ji]]+original[ji:]),
               ('extra_coefficient',original+[original[ci]]),
               ('stale_capture',['H '+'0'*64]+original[1:])]
    for label,lines in trials:
        try:verify(lines)
        except ValueError:continue
        raise ValueError('Checker accepted corruption:'+label)
    message='STAGE2 CHECKER SELFTEST PASS:12/12 corruptions rejected\n'
    (HERE/'stage2_checker_selftest.log').write_text(message);print(message,end='')


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('command',choices=['prepare','check','compare','selftest'])
    p.add_argument('--stage',type=int,choices=[2,3,4,5],default=4)
    p.add_argument('--unit',choices=['process','hash_format','shared_hash','bank_memory','bank_store','bank_ntt','bank_process','row','seed_row','keygen','rounded_keygen','bitpkg','full_keygen','nist_keygen','sign_process','sign_dma','sign_service'],default='process',
                   help='Select a Stage5 gate; nist_keygen compares all75 official NIST cases')
    try:
        args=p.parse_args();command=args.command
        if command=='check':
            check();print('STAGE2 VECTOR FRESHNESS PASS')
        elif command=='prepare':prepare()
        else:{'compare':compare,'selftest':selftest}[command](args.stage,args.unit)
    except (ValueError,OSError,AssertionError,subprocess.SubprocessError) as e:
        raise SystemExit('DILITHIUM REFERENCE FAIL: '+str(e))
