"""Real SHAKE -> sampling -> memory -> NTT: independent file comparison.

Subsystem fixtures are local; nist_keygen/nist_sign use pinned NIST ACVP files.
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

def bench_path(name):
    """Resolve reusable focused tests and oracles after verification cleanup."""
    base=ROOT/'tb/tb_dilithium'
    for folder in (base,base/'unit',base/'reference',base/'reference/legacy',base/'support'):
        candidate=folder/name
        if candidate.is_file():return candidate
    raise FileNotFoundError('Missing focused bench/reference: '+name)

NIST_KEYGEN = ROOT / 'NIST/ML-DSA-keyGen-FIPS204'
NIST_COMMIT = '2972def23bf9f3680c2c531561ed9bdd0f1086ad'
NIST_HASHES = {
    'prompt.json':'43e81ad820e495dbcad086fe27c1008393a8c32100bbbff77c558c3f06dcefef',
    'expectedResults.json':'361f47ca19d592adcc66ff2cb591686ad785fea157b295648738bed6921a68df',
}
NIST_SIGN = ROOT / 'NIST/ML-DSA-sigGen-FIPS204'
NIST_SIGN_HASHES = {
    'prompt.json':'447749d72817b211160d243311ce32302f3023e59c355b0f70be2bd3e9e7830d',
    'expectedResults.json':'228d011bbe274aeb93e22eea1e0d57b78f43795cf6a64fb5ef1e626485a0bedb',
}
NIST_VERIFY = ROOT / 'NIST/ML-DSA-sigVer-FIPS204'
NIST_VERIFY_HASHES = {
    'prompt.json':'aeba1135e5dbda1681369cc7a7598c3d53e492d1c9881098556ba4dbe067b376',
    'expectedResults.json':'99c5b82abf37bdf6f7bd11c6976e4d8007d70f9953dc13566232404647865bb8',
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
            str(ROOT/'tb/tb_dilithium/reference/sign_process_reference.c'),*[str(ref/n) for n in ('poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],check=True,capture_output=True,text=True)
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
                    str(ROOT/'tb/tb_dilithium/reference/process_reference.c'),str(ROOT/'dilithium-sw-model/ref/rounding.c'),
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
    sources = [Path(__file__).resolve(), REF, NTT_REF, ROOT/'sim/dilithium/run.do',ROOT/'sim/dilithium/setup_cyclonev.tcl']
    sources += [NIST_KEYGEN/n for n in (*NIST_HASHES,'provenance.json')]
    sources += [NIST_SIGN/n for n in (*NIST_SIGN_HASHES,'provenance.json')]
    sources += [NIST_VERIFY/n for n in (*NIST_VERIFY_HASHES,'provenance.json')]
    sources += [ROOT/'tb/tb_dilithium/reference/process_reference.c',ROOT/'tb/tb_dilithium/reference/bitpkg_reference.c',ROOT/'tb/tb_dilithium/reference/keygen_reference.c',ROOT/'tb/tb_dilithium/reference/sign_process_reference.c',ROOT/'tb/tb_dilithium/reference/sign_decode_reference.c',ROOT/'tb/tb_dilithium/reference/sign_hash_reference.c']
    sources += [ROOT/'tb/tb_dilithium/reference/sign_prepare_reference.c',ROOT/'tb/tb_dilithium/reference/sign_matrix_reference.c',ROOT/'tb/tb_dilithium/reference/sign_challenge_reference.c',ROOT/'tb/tb_dilithium/reference/sign_challenge_transform_reference.c']
    sources += [ROOT/'tb/tb_dilithium/reference/sign_products_reference.c']
    sources += [ROOT/'tb/tb_dilithium/reference/sign_accept_reference.c']
    sources += [ROOT/'tb/tb_dilithium/reference/sign_retry_reference.c']
    sources += [ROOT/'tb/tb_dilithium/reference/full_sign_reference.c']
    sources += [ROOT/'tb/tb_dilithium/reference/verify_reference.c']
    sources += [ROOT/'dilithium-sw-model/ref'/n for n in ('rounding.c','rounding.h','params.h','config.h','poly.c','poly.h','reduce.c','reduce.h','ntt.c','ntt.h','symmetric-shake.c','symmetric.h','fips202.c','fips202.h','sign.c','sign.h','polyvec.c','polyvec.h','packing.c','packing.h','randombytes.h')]
    sources += sorted((ROOT/'src/keccak').glob('*.sv'))
    sources += sorted((ROOT/'src/sampler').glob('*.sv'))
    sources += sorted((ROOT/'src/controller').rglob('*.sv'))
    sources += sorted((ROOT/'src/ntt').glob('*.sv'))
    sources += sorted((ROOT/'tb/tb_dilithium').rglob('*.sv'))
    h = hashlib.sha256((body+expected+math_body+process_body+full_keygen_expected_artifact('reference')+full_sign_expected_artifact('reference')).encode())
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
    check_sign_prepare_c()
    check_sign_hash_c()
    check_sign_mask_c()
    check_sign_matrix_c()
    check_sign_challenge_c()
    check_sign_transform_c()
    check_sign_products_c()
    check_sign_accept_c()
    check_sign_retry_c()
    check_sign_encode_c()
    check_sign_decode_c()
    check_sign_process_c()
    check_process_c()
    check_bitpkg_c()
    build_full_keygen_c()
    build_full_sign_c()
    check_nist_keygen_c()
    check_nist_sign_c()
    check_verify_c()
    rows, token, stimuli, golden, arithmetic, process = artifacts()
    (HERE/'stage5_sign_challenge_inputs.txt').write_text(sign_challenge_artifact(token),encoding='ascii')
    (HERE/'stage5_sign_transform_inputs.txt').write_text(sign_transform_artifact(token),encoding='ascii')
    (HERE/'stage5_sign_products_inputs.txt').write_text(sign_products_artifact(token),encoding='ascii')
    (HERE/'stage5_sign_accept_inputs.txt').write_text(sign_accept_artifact(token),encoding='ascii')
    (HERE/'stage5_sign_retry_inputs.txt').write_text(sign_retry_artifact(token),encoding='ascii')
    (HERE/'stage5_sign_encode_inputs.txt').write_text(sign_encode_artifact(token),encoding='ascii')
    (HERE/'stage5_full_sign_inputs.txt').write_text(full_sign_input_artifact(token),encoding='ascii')
    (HERE/'stage5_full_sign_expected.txt').write_text(full_sign_expected_artifact(token),encoding='ascii')
    (HERE/'stage5_nist_sign_inputs.txt').write_text(full_sign_input_artifact(token,nist=True),encoding='ascii')
    (HERE/'stage5_nist_sign_expected.txt').write_text(nist_sign_expected_artifact(token),encoding='ascii')
    (HERE/'stage5_nist_sign_audit.csv').write_text(nist_sign_corpus()[1],encoding='ascii')
    (HERE/'stage5_verify_decode_inputs.txt').write_text(verify_decode_artifact(token),encoding='ascii')
    (HERE/'stage5_verify_prepare_inputs.txt').write_text(verify_prepare_artifact(token),encoding='ascii')
    (HERE/'stage5_verify_math_inputs.txt').write_text(verify_math_artifact(token),encoding='ascii')
    (HERE/'stage5_verify_equation_inputs.txt').write_text(verify_equation_artifact(token),encoding='ascii')
    (HERE/'stage5_full_verify_inputs.txt').write_text(full_verify_artifact(token),encoding='ascii')
    (HERE/'stage5_nist_verify_inputs.txt').write_text(full_verify_artifact(token,nist=True),encoding='ascii')
    (HERE/'stage5_nist_verify_expected.txt').write_text(nist_verify_expected_artifact(token),encoding='ascii')
    (HERE/'stage5_nist_verify_audit.csv').write_text(nist_verify_corpus()[1],encoding='ascii')
    (HERE/'stage5_sign_matrix_inputs.txt').write_text(sign_matrix_artifact(token),encoding='ascii')
    (HERE/'stage5_sign_mask_inputs.txt').write_text(sign_mask_artifact(token),encoding='ascii')
    (HERE/'stage5_sign_prepare_inputs.txt').write_text(sign_prepare_artifact(token),encoding='ascii')
    (HERE/'stage5_sign_load_inputs.txt').write_text(sign_load_artifact(token),encoding='ascii')
    (HERE/'stage5_sign_hash_inputs.txt').write_text(sign_hash_artifact(token),encoding='ascii')
    (HERE/'stage5_sign_decode_inputs.txt').write_text(sign_decode_artifact(token),encoding='ascii')
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
        (HERE/'stage5_sign_challenge_inputs.txt').read_text() != sign_challenge_artifact(token) or
        (HERE/'stage5_sign_transform_inputs.txt').read_text() != sign_transform_artifact(token) or
        (HERE/'stage5_sign_products_inputs.txt').read_text() != sign_products_artifact(token) or
        (HERE/'stage5_sign_accept_inputs.txt').read_text() != sign_accept_artifact(token) or
        (HERE/'stage5_sign_retry_inputs.txt').read_text() != sign_retry_artifact(token) or
        (HERE/'stage5_sign_encode_inputs.txt').read_text() != sign_encode_artifact(token) or
        (HERE/'stage5_full_sign_inputs.txt').read_text() != full_sign_input_artifact(token) or
        (HERE/'stage5_full_sign_expected.txt').read_text() != full_sign_expected_artifact(token) or
        (HERE/'stage5_nist_sign_inputs.txt').read_text() != full_sign_input_artifact(token,nist=True) or
        (HERE/'stage5_nist_sign_expected.txt').read_text() != nist_sign_expected_artifact(token) or
        (HERE/'stage5_nist_sign_audit.csv').read_text() != nist_sign_corpus()[1] or
        (HERE/'stage5_verify_decode_inputs.txt').read_text() != verify_decode_artifact(token) or
        (HERE/'stage5_verify_prepare_inputs.txt').read_text() != verify_prepare_artifact(token) or
        (HERE/'stage5_verify_math_inputs.txt').read_text() != verify_math_artifact(token) or
        (HERE/'stage5_verify_equation_inputs.txt').read_text() != verify_equation_artifact(token) or
        (HERE/'stage5_full_verify_inputs.txt').read_text() != full_verify_artifact(token) or
        (HERE/'stage5_nist_verify_inputs.txt').read_text() != full_verify_artifact(token,nist=True) or
        (HERE/'stage5_nist_verify_expected.txt').read_text() != nist_verify_expected_artifact(token) or
        (HERE/'stage5_nist_verify_audit.csv').read_text() != nist_verify_corpus()[1] or
        (HERE/'stage5_sign_matrix_inputs.txt').read_text() != sign_matrix_artifact(token) or
        (HERE/'stage5_sign_mask_inputs.txt').read_text() != sign_mask_artifact(token) or
        (HERE/'stage5_sign_prepare_inputs.txt').read_text() != sign_prepare_artifact(token) or
        (HERE/'stage5_sign_load_inputs.txt').read_text() != sign_load_artifact(token) or
        (HERE/'stage5_sign_hash_inputs.txt').read_text() != sign_hash_artifact(token) or
        (HERE/'stage5_sign_decode_inputs.txt').read_text() != sign_decode_artifact(token) or
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
                        str(ROOT/'tb/tb_dilithium/reference/keygen_reference.c'),
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
    # Working vector files may be edited; saved provenance is informational.
    objects={}
    for name in NIST_HASHES:
        obj=json.loads((NIST_KEYGEN/name).read_text(encoding='utf-8-sig'))
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
        gamma=(131072,524288,524288)[p] if p<3 else 131072
        choices=range(1024) if op==0 else range(-4095,4097) if op==1 else range(44 if p==0 else 16) if op==3 else range(-gamma+1,gamma+1) if op==4 else range(-eta,eta+1)
        edge=[choices[0],choices[-1],0,choices[min(1,len(choices)-1)],choices[-2]]
        signed=[(0 if pattern==0 else choices[0] if pattern==1 else choices[-1] if pattern==2 else
                 edge[i%len(edge)] if pattern==3 else edge[i%2] if pattern==4 else rng.choice(choices)) for i in range(256)]
        values=[x%q for x in signed]
        if fault_kind==4:values[fault_index]=1024 if op==0 else q-4096 if op==1 else (44 if p==0 else 16) if op==3 else q-gamma if op==4 else eta+1
        if fault_kind==5:values[fault_index]=gamma+1
        if fault_kind==6:values[fault_index]=q
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
    for op,p in ((0,3),(1,3),(2,3),(3,3)):add(op,p,code=1)
    for op in range(3):
        for phase in range(2):
            jid=32000+op*2+phase
            add(op,op%3,abort=phase,jid=jid);add(op,op%3,jid=jid)
    for p in range(3):
        for pattern in range(6):add(3,p,pattern)
        for index in (0,137):add(3,p,fault_index=index,fault_kind=4,code=2)
        for phase in range(2):add(3,p,abort=phase,jid=65535);add(3,p,jid=65535)
    for kind,index in ((1,137),(2,137),(3,255)):add(3,kind-1,fault_index=index,fault_kind=kind,code=3)
    for p in range(3):
        for pattern in range(6):add(4,p,pattern)
        for kind,index in ((4,0),(5,137),(6,255)):add(4,p,fault_index=index,fault_kind=kind,code=2)
        for kind,index in ((1,137),(2,137),(3,255)):add(4,p,fault_index=index,fault_kind=kind,code=3)
        for phase in range(2):add(4,p,abort=phase,jid=65535);add(4,p,jid=65535)
        add(5+p,p,code=1)
    add(4,3,code=1)
    assert len(result)==188
    return result


def bitpkg_input_artifact(token):
    return f'{token} {len(bitpkg_cases())}\n'+''.join(
        f"{c['i']} {c['op']} {c['p']} {c['id']} {c['abort']} {c['code']} {c['fault_index']} {c['fault_kind']}\n"+
        ' '.join(f'{x:06x}' for x in c['values'])+'\n' for c in bitpkg_cases())


def bitpkg_encoded(op,p,value):
    q=ntt_reference.Q;eta=4 if p==1 else 2
    signed=value if value<=(q-1)//2 else value-q
    return (value,10) if op==0 else (4096-signed,13) if op==1 else (value,6 if p==0 else 4) if op==3 else ((131072 if p==0 else 524288)-signed,18 if p==0 else 20) if op==4 else (eta-signed,4 if eta==4 else 3)


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
                        str(ROOT/'tb/tb_dilithium/reference/bitpkg_reference.c'),
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
    require(opened==188 and (success,errors,aborts)==(108,62,18) and footer==[opened,done,aborts,inputs,outputs,errors],'Campaign totals')
    return (f'DILITHIUM STAGE5K BITPKG COMPARE PASS:188 commands,108 successful packets,62 expected errors,18 reset aborts;'
            f'{inputs} accepted coefficients,{outputs} exact64-bit output words;all t1/t0/eta/w1/z formats;stalls and same-ID recovery\n')


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


def decode_key_math(sk,p,limit=None):
    """Integer bit slicing,independent of the RTL reservoir/FSM."""
    k,l=((4,4),(6,5),(8,7))[p];eta=4 if p==1 else 2
    offset=128;result=[]
    for section,polys in enumerate((l,k,k)):
        width=13 if section==2 else 4 if eta==4 else 3;size=32*width
        for poly in range(polys):
            packed=int.from_bytes(sk[offset:offset+size],'little')
            for index in range(256):
                end=8*offset+(index+1)*width
                if limit is not None and end>limit*8:return result,None
                raw=(packed>>(width*index))&((1<<width)-1);center=4096 if section==2 else eta
                result.append((section,poly,index,(center-raw)%8380417,int(index==255),int(section==2 and poly==k-1 and index==255),end,raw<=2*eta or section==2))
            offset+=size
    assert offset==len(sk)
    return result,None


@lru_cache(maxsize=1)
def sign_decode_cases():
    rows=[];rng=random.Random(0x5D4A)
    def add(sk,p,fault_word=-1,fault=0,abort=0,jid=None,official=False):
        rows.append(dict(i=len(rows),sk=sk,p=p,fault_word=fault_word,fault=fault,abort=abort,
            id=(65500+len(rows))&65535 if jid is None else jid,official=official))
    for c in nist_keygen_cases():add(c['sk'],c['p'],official=True)
    synthetic=[]
    for p,(k,l) in enumerate(((4,4),(6,5),(8,7))):
        eta=4 if p==1 else 2
        for pattern in range(3):
            sk=hashlib.shake_256(f'sign-decode-{p}-{pattern}'.encode()).digest(128)
            for section,polys in enumerate((l,k,k)):
                width=13 if section==2 else 4 if eta==4 else 3;maximum=8191 if section==2 else 2*eta
                for poly in range(polys):
                    values=[rng.randrange(maximum+1) if pattern==2 else (i+poly)%(maximum+1) if pattern==1 else [0,maximum,1,maximum-1][i%4] for i in range(256)]
                    sk+=sum(v<<(width*i) for i,v in enumerate(values)).to_bytes(32*width,'little')
            add(sk,p);synthetic.append((p,sk))
        base=synthetic[-1][1];width=4 if eta==4 else 3
        # Every unused eta code,at varied coefficient/word positions.
        for raw in range(2*eta+1,1<<width):
            index=(raw*37)%256;bits=int.from_bytes(base[128:],'little');shift=index*width
            bits=(bits & ~(((1<<width)-1)<<shift)) | (raw<<shift)
            add(base[:128]+bits.to_bytes(len(base)-128,'little'),p)
        # Last s2 coefficient invalid:all preceding polynomials are tentative.
        index=(l+k)*256-1;bits=int.from_bytes(base[128:],'little');shift=index*width
        bits=(bits & ~(((1<<width)-1)<<shift)) | ((2*eta+1)<<shift)
        add(base[:128]+bits.to_bytes(len(base)-128,'little'),p);add(base,p)
    base=synthetic[0][1];add(base,3)
    for word in (0,1,15,16,17,len(base)//8-1):add(base,0,word,1) # wrong word index
    for value in (0,1,7,9,15):add(base,0,17,value+10) # invalid byte count
    for word in (0,15,16,len(base)//8-1):add(base,0,word,2) # wrong last
    for phase in range(1,6):
        p=phase%3;sk=next(sk for cp,sk in synthetic if cp==p)
        add(sk,p,abort=phase,jid=1234)
        add(next(value for cp,value in reversed(synthetic) if cp==p),p,jid=1234)
    return rows


@lru_cache(maxsize=1)
def sign_load_cases():
    rows=[dict(c,base=(0,16,32,40)[c['i']%4],sentinel=63) for c in sign_decode_cases()]
    for p,total in enumerate((12,17,23)):
        sk=next(c['sk'] for c in rows if c['p']==p and c['official'])
        for base,sentinel in ((64-total,0),(64-total,63),(65-total,63)):
            rows.append(dict(i=len(rows),sk=sk,p=p,id=4321,fault_word=-1,fault=0,abort=0,
                             official=False,base=base,sentinel=sentinel))
    return rows


def sign_load_artifact(token):
    rows=sign_load_cases()
    return f'{token} {len(rows)}\n'+''.join(f"{c['i']} {c['p']} {c['id']} {c['base']} {c['sentinel']} {c['fault_word']} {c['fault']} {c['abort']} {len(c['sk'])} {c['sk'].hex()}\n" for c in rows)


@lru_cache(maxsize=1)
def sign_prepare_cases():
    rows=[]
    for c in sign_load_cases():
        n=(12,17,23,23)[c['p']];plan=set(range(c['base'],c['base']+n))
        work=next(r for r in range(64) if r not in plan and r!=c['sentinel'])
        rows.append(dict(c,work=work,inject=0,target=0))
    for p,n in enumerate((12,17,23)):
        original=next(c for c in rows if c['p']==p and c['official'])
        for inject,target,work,abort in [(0,0,original['base'],0),(0,0,original['sentinel'],0),
              (1,0,original['work'],0),(1,n-1,original['work'],0),(2,n//2,original['work'],0),
              (3,n-1,original['work'],0),(4,0,original['work'],0),(5,0,original['work'],0),(6,0,original['work'],6)]:
            rows.append(dict(original,i=len(rows),id=1234,official=False,work=work,inject=inject,target=target,abort=abort))
    return rows


def sign_prepare_artifact(token):
    rows=sign_prepare_cases()
    return f'{token} {len(rows)}\n'+''.join(f"{c['i']} {c['p']} {c['id']} {c['base']} {c['work']} {c['sentinel']} {c['fault_word']} {c['fault']} {c['abort']} {c['inject']} {c['target']} {len(c['sk'])} {c['sk'].hex()}\n" for c in rows)


@lru_cache(maxsize=None)
def sign_prepare_math(sk,p):
    raw=decode_key_math(sk,p)[0]
    # Polynomial evaluation at odd roots is independent of RTL/C butterfly
    # scheduling. Retain results across checker mutations,not across sources.
    transformed=tuple(tuple(ntt_reference.direct_forward([r[3] for r in raw[j:j+256]])) for j in range(0,len(raw),256))
    return raw,transformed


def check_sign_prepare_c():
    gcc=shutil.which('gcc');build=HERE/'reference_build';build.mkdir(exist_ok=True)
    if not gcc:raise ValueError('GCC required for signing preparation oracle')
    count=coefficients=0
    for p,level in enumerate((2,3,5)):
        exe=build/f'sign_prepare_reference_{level}.exe';ref=ROOT/'dilithium-sw-model/ref'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ref),str(ROOT/'tb/tb_dilithium/reference/sign_prepare_reference.c'),
            *[str(ref/n) for n in ('packing.c','poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],check=True,capture_output=True,text=True)
        rows=[c for c in sign_prepare_cases() if c['p']==p]
        answer=subprocess.run([str(exe)],input=''.join(' '.join(map(str,c['sk']))+'\n' for c in rows),capture_output=True,text=True,check=True).stdout.splitlines()
        if len(answer)!=len(rows):raise ValueError('Signing preparation C count')
        for c,line in zip(rows,answer,strict=True):
            expected=[v for poly in sign_prepare_math(c['sk'],p)[1] for v in poly]
            if list(map(int,line.split()))!=expected:raise ValueError('Python direct-evaluation/C poly_ntt mismatch')
            count+=1;coefficients+=len(expected)
    message=f'PYTHON_C_SIGN_PREPARE_PASS:{count} key fixtures,{coefficients} transformed coefficients;unchanged C unpack_sk/poly_ntt versus independent direct polynomial evaluation\n'
    (HERE/'stage5_sign_prepare_c_reference.log').write_text(message);print(message,end='')


def verify_sign_prepare(lines):
    _,token=check();rows=sign_prepare_cases()
    if not lines or lines[0]!='S '+token:raise ValueError('Prepare stale source')
    by={};footer=None
    for line in lines[1:]:
        f=line.split()
        if not f:raise ValueError('Prepare blank record')
        if f[0]=='F':
            if footer is not None or line!=lines[-1]:raise ValueError('Prepare footer order')
            footer=list(map(int,f[1:]));continue
        i=int(f[1])
        if not 0<=i<len(rows):raise ValueError('Prepare unknown case')
        by.setdefault(i,[]).append(line)
    if set(by)!=set(range(len(rows))):raise ValueError('Prepare missing case')
    completed=errors=aborts=writes=reads=transforms=official=pre_count=forward_count=0
    for c in rows:
        i=c['i'];p=c['p'];jid=c['id'];base=c['base'];scratch=c['work'];sentinel=c['sentinel'];inj=c['inject'];target=c['target'];sk=c['sk']
        total=(12,17,23,23)[p];small=(8,11,15,15)[p];plan=((1<<total)-1)<<base
        raw=[] if p==3 else decode_key_math(sk,p)[0];bad=next((n for n,r in enumerate(raw) if not r[7]),None)
        pre_code=1 if p==3 else 2 if base+total>64 or plan&(1<<scratch) else 3 if scratch==sentinel else 4 if plan&(1<<sentinel) else 0
        load_code=3 if c['fault'] else 2 if bad is not None else 0
        code=pre_code or (4 if load_code else 6 if inj in (2,3,4,5) else 5 if inj==1 else 0)
        detail=4 if pre_code==4 else load_code if not pre_code and load_code else 1 if not pre_code and inj==1 else 0
        events=[s.split() for s in by[i]];kinds=('C','W','L','B','N','O','R','G','X','U','Z','P','Q','H','D','V','I','E','A','T')
        parts={k:[f for f in events if f[0]==k] for k in kinds}
        if any(f[0] not in kinds for f in events):raise ValueError('Prepare unknown record')
        if parts['C']!=[['C',str(i),str(p),str(jid),str(base),str(scratch),str(sentinel)]] or events[0][0]!='C':raise ValueError('Prepare command snapshot')
        if len(parts['T'])!=1 or len(parts['T'][0])!=11:raise ValueError('Prepare witnesses')
        witness=list(map(int,parts['T'][0][2:]))
        if witness[8]<=0:raise ValueError('Prepare missing outer-owner witness')
        if c['abort']:
            if parts['D'] or parts['A']!=[['A',str(i),str(c['abort'])]]:raise ValueError('Prepare reset outcome')
            aborts+=1
        else:
            if parts['A'] or parts['D']!=[['D',str(i),str(code),str(detail),str(jid)]]:raise ValueError(f'Prepare result case{i}')
            if witness[0]<7:raise ValueError('Prepare completion hold missing')
            completed+=1;errors+=int(code!=0);official+=int(c['official'] and code==0)
        needed=0 if pre_code else c['fault_word']+1 if c['fault'] else (raw[bad][6]+63)//64 if bad is not None else len(sk)//8
        if c['abort']==1:needed=3
        if len(parts['W'])!=needed:raise ValueError(f'Prepare input word count case{i}')
        for j,f in enumerate(parts['W']):
            index=j^int(c['fault']==1 and j==c['fault_word']);n=c['fault']-10 if c['fault']>=10 and j==c['fault_word'] else 8
            last=int(j==len(sk)//8-1)^int(c['fault']==2 and j==c['fault_word'])
            if f!=['W',str(i),str(index),str(n),str(last),f'{int.from_bytes(sk[8*j:8*j+8],"little"):016x}']:raise ValueError('Prepare absorbed key bytes')
        expected_raw=[] if pre_code or c['abort']==1 else decode_key_math(sk,p,limit=c['fault_word']*8)[0] if c['fault'] else raw[:bad] if bad is not None else raw
        xraw=[f for f in parts['X'] if f[2]=='0']
        if xraw!=[['X',str(i),'0',str(base+n//256),str(r[2]),f'{r[3]:06x}',str(r[4])] for n,r in enumerate(expected_raw)]:raise ValueError('Prepare raw scalar prefix')
        if parts['L']!=([] if pre_code else [['L',str(i),str(p),str(jid),str(base)]]):raise ValueError('Prepare load descriptor')
        load_finished=not pre_code and c['abort']!=1
        b_expected=[]
        if load_finished:
            mask=plan if load_code==0 else 0
            b_expected=[['B',str(i),str(jid),str(load_code),f'{mask:016x}',str(jid^(inj==4)),str(load_code),f'{mask^((1<<base) if inj==5 else 0):016x}']]
        if parts['B']!=b_expected:raise ValueError('Prepare load retirement metadata')
        do_transforms=not pre_code and load_code==0 and inj not in (4,5) and c['abort']!=1
        math=sign_prepare_math(sk,p)[1] if do_transforms else ()
        n_expected=0 if not do_transforms else 1 if c['abort'] in (2,3,4,6) else target+1 if inj in (1,2,3) else total
        if len(parts['N'])!=n_expected:raise ValueError('Prepare transform count')
        o_expected=n_expected-(1 if c['abort'] in (2,3,6) else 0)
        if len(parts['O'])!=o_expected:raise ValueError('Prepare transform retirement count')
        slots={};pending={};current=None;handles=[base+j for j in range(total)];work=scratch;next_op=0
        load_seen=False;parent_done=False;published=False;cleared=False;normal_releases=0;input_words=raw_written=0
        for f in events:
            kind=f[0]
            if kind=='W':input_words+=1
            elif kind=='G':
                region,owner,mode,param,domain=map(int,f[2:])
                if region in slots or region==sentinel or owner!=jid or param!=p:raise ValueError('Prepare allocation ownership')
                if not load_seen:
                    ordinal=region-base
                    if not 0<=ordinal<total or domain or mode!=(1 if ordinal<small else 3):raise ValueError('Prepare raw allocation')
                    expected=tuple(r[3] for r in raw[ordinal*256:(ordinal+1)*256])
                else:
                    if current is None or current['bad_source'] or region!=work or domain!=1:raise ValueError('Prepare transform allocation')
                    ordinal=current['ordinal'];expected=math[ordinal]
                    if mode!=(1 if ordinal<small else 3):raise ValueError('Prepare transformed mode')
                slots[region]=dict(ordinal=ordinal,expected=expected,values=[],acks=set(),sent=set(),complete=False,domain=domain,mode=mode)
                if len(slots)>total+1:raise ValueError('Prepare exceeds one scratch region')
            elif kind=='X':
                phase,region,index=int(f[2]),int(f[3]),int(f[4]);s=slots.get(region)
                if s is None or s['complete'] or index!=len(s['values']) or index>=256 or phase!=s['domain'] or int(f[5],16)!=s['expected'][index] or int(f[6])!=int(index==255):raise ValueError('Prepare scalar/FFT write')
                if phase==0:
                    if raw[raw_written][6]>input_words*64:raise ValueError('Prepare wrote before source bits')
                    raw_written+=1
                elif current is None or current['ordinal']!=s['ordinal']:raise ValueError('Prepare transform write outside owner')
                s['values'].append(int(f[5],16))
            elif kind=='P':
                region,w=int(f[2]),int(f[3]);s=slots.get(region);key=(region,w)
                if s is None or len(s['values'])<4*w+4 or w in s['sent'] or key in pending:raise ValueError('Prepare packed request lifecycle')
                packed=sum(v<<(23*j) for j,v in enumerate(s['values'][4*w:4*w+4]))
                if int(f[4],16)!=packed:raise ValueError('Prepare physical packed data')
                pending[key]=True;s['sent'].add(w)
            elif kind=='Q':
                region,w=map(int,f[2:]);key=(region,w)
                if key not in pending or region not in slots:raise ValueError('Prepare orphan ACK')
                del pending[key];slots[region]['acks'].add(w)
            elif kind=='U':
                region,finish=map(int,f[2:]);s=slots.get(region)
                if s is None or s['complete'] or any(r==region for r,w in pending):raise ValueError('Prepare finish ownership')
                if finish==0:
                    if len(s['values'])!=256 or s['acks']!=set(range(64)):raise ValueError('Prepare finish before64 ACKs')
                    s['complete']=True
                elif finish!=1 or s['domain']!=0 or load_code==0:raise ValueError('Prepare invalid partial discard')
                else:del slots[region]
            elif kind=='Z':
                region=int(f[2]);s=slots.get(region)
                if s is None or not s['complete'] or s['domain']!=0 or load_code==0 or load_seen:raise ValueError('Prepare decoder rollback ownership')
                del slots[region]
            elif kind=='B':
                if load_seen:raise ValueError('Prepare duplicate load done')
                if load_code==0 and (set(slots)!=set(range(base,base+total)) or not all(s['complete'] for s in slots.values())):raise ValueError('Prepare load result before memory commits')
                if load_code!=0 and slots:raise ValueError('Prepare loader error not drained')
                load_seen=True
            elif kind=='N':
                ordinal,op,source,dest,aid,owner=map(int,f[2:]);bad_source=inj==1 and ordinal==target
                if not do_transforms or current is not None or ordinal!=next_op or source!=handles[ordinal] or dest!=work or dest in slots or owner!=jid or aid!=(jid^int(bad_source)) or op!=(3 if ordinal<small else 0):raise ValueError('Prepare NTT schedule/owner')
                if source not in slots or not slots[source]['complete'] or slots[source]['domain']!=0:raise ValueError('Prepare NTT source not raw/complete')
                if op==3 and not all(v<=4 or v>=8380413 for v in slots[source]['values']):raise ValueError('Prepare invalid Pre-NTT eligibility')
                current=dict(ordinal=ordinal,source=source,dest=dest,bad_source=bad_source,retired=False)
                if op==3:pre_count+=1
                else:forward_count+=1
            elif kind=='O':
                ordinal,aid,dest,status,vid,vregion,vstatus=map(int,f[2:])
                if current is None or current['retired'] or ordinal!=current['ordinal']:raise ValueError('Prepare unmatched NTT completion')
                expected_status=int(current['bad_source'])
                if (aid,dest,status,vid,vregion,vstatus)!=(jid,work,expected_status,jid^int(inj==2 and ordinal==target),work^int(inj==3 and ordinal==target),expected_status):raise ValueError('Prepare NTT result metadata')
                if status==0 and (work not in slots or not slots[work]['complete']):raise ValueError('Prepare NTT completed before write ACKs')
                if status!=0 and work in slots:raise ValueError('Rejected transform allocated output')
                current['retired']=True
            elif kind=='R':
                why,region=map(int,f[2:]);s=slots.get(region)
                if s is None or not s['complete'] or any(r==region for r,w in pending):raise ValueError('Prepare release wrong allocation')
                if why==0:
                    if current is None or not current['retired'] or current['bad_source'] or region!=current['source'] or (inj in (2,3) and current['ordinal']==target):raise ValueError('Prepare released source before validated transform')
                    handles[next_op]=work;work=region;next_op+=1;normal_releases+=1;current=None
                elif why==1:
                    if code==0 or published or parent_done:raise ValueError('Prepare error release lifecycle')
                elif why==2:
                    if not cleared or not parent_done or code!=0:raise ValueError('Prepare context clear lifecycle')
                else:raise ValueError('Prepare unknown release kind')
                del slots[region]
            elif kind=='H':
                mask=sum(1<<r for r in handles);packed=sum(r<<(6*j) for j,r in enumerate(handles))
                expected=['H',str(i),str(jid),str(p),f'{mask:016x}',f'{packed:035x}',sk[:32][::-1].hex(),sk[32:64][::-1].hex(),sk[64:128][::-1].hex()]
                if published or code!=0 or next_op!=total or current is not None or set(slots)!=set(handles) or pending or f!=expected or not all(s['complete'] and s['domain']==1 for s in slots.values()):raise ValueError('Prepare early/wrong published context')
                published=True
            elif kind=='D':
                if parent_done or pending or (code==0 and not published) or (code!=0 and slots):raise ValueError('Prepare result before publication/cleanup')
                parent_done=True
            elif kind=='V':
                ordinal,region,w,owner,mode,param,domain,small_flag=map(int,f[2:10]);data=int(f[10],16)
                if not parent_done:raise ValueError('Prepare consumer before result')
                if ordinal<0:
                    msg=bytes((i+j)&255 for j in range(66));poly=reference.sample(2,0,hashlib.shake_256(msg).digest(4096))[0]
                    if (region,owner,mode,param,domain)!=(sentinel,60000,2,0,0):raise ValueError('Prepare unrelated sentinel metadata')
                else:
                    if not published or cleared or ordinal>=total or region!=handles[ordinal] or region not in slots or (owner,mode,param,domain)!=(jid,1 if ordinal<small else 3,p,1):raise ValueError('Prepare transformed read metadata')
                    poly=math[ordinal]
                expected_data=sum(v<<(23*j) for j,v in enumerate(poly[4*w:4*w+4]))
                if not 0<=w<64 or data!=expected_data or small_flag!=int(all(v<=4 or v>=8380413 for v in poly)):raise ValueError('Prepare transformed/sentinel read values')
            elif kind=='I':
                if not parent_done or cleared or not published or f!=['I',str(i),str(jid),str(handles[0]),f'{sum(v<<(23*j) for j,v in enumerate(math[0][:4])):023x}']:raise ValueError('Prepare pending-read clear barrier')
            elif kind=='E':
                if not parent_done or not published or cleared or len(parts['I'])!=1:raise ValueError('Prepare clear acceptance')
                cleared=True
        # Reset checkpoints have exact accepted operation/write prefixes.
        transform_values=len([f for f in parts['X'] if f[2]=='1'])
        expected_values=31 if c['abort']==3 else 0 if c['abort'] in (1,2,6) else 256 if c['abort']==4 else 256*(target if inj==1 else target+1) if do_transforms and inj in (1,2,3) else 256*total if do_transforms else 0
        if transform_values!=expected_values:raise ValueError(f'Prepare transformed prefix case{i}')
        if c['abort']:
            if parts['V'] or parts['I'] or parts['E'] or published!=(c['abort']==5):raise ValueError('Prepare reset leaked context/read')
        elif code==0:
            expected_reads=[(j,r,w) for j,r in enumerate(handles) for w in range(64)]+[(-1,sentinel,w) for w in range(64)]
            # Periodic channel gates need not stall every individual key.
            # The first key deterministically witnesses every child channel;
            # retention/clear and host exclusion are required for every key.
            if not cleared or slots or len(parts['I'])!=1 or len(parts['E'])!=1 or normal_releases!=total or witness[1]<9 or witness[7]<6 or (i==0 and min(witness[j] for j in (2,3,4,5,6))<=0):raise ValueError(f'Prepare retained/cleared key witnesses case{i}')
            if [tuple(map(int,f[2:5])) for f in parts['V']]!=expected_reads:raise ValueError('Prepare incomplete transformed readback')
        else:
            if published or parts['I'] or parts['E'] or slots or [tuple(map(int,f[2:5])) for f in parts['V']]!=[(-1,sentinel,w) for w in range(64)]:raise ValueError('Prepare failure not fully cleaned')
        writes+=len(parts['X']);reads+=len(parts['V']);transforms+=len(parts['N'])
    if footer!=[len(rows),completed,errors,aborts,writes,reads,transforms]:raise ValueError('Prepare totals')
    return f'STAGE5N4D_SIGN_PREPARE_COMPARE_PASS:{len(rows)} keys,{completed} completions,{errors} expected errors,{aborts} resets,{writes} exact scalar writes,{reads} exact packed reads,{transforms} transform requests({pre_count} Pre-NTT/{forward_count} forward);{official}/75 official KeyGen SKs prepared;one scratch,retained context,rollback/clear and physical ACKs checked\n'


def verify_sign_load(lines,shared=False):
    _,token=check();rows=sign_load_cases()
    if not lines or lines[0]!='H '+token:raise ValueError('Load stale token')
    by={};footer=None
    for line in lines[1:]:
        f=line.split()
        if not f:raise ValueError('Load blank event')
        if f[0]=='F':
            if footer is not None or line!=lines[-1]:raise ValueError('Load footer order')
            footer=list(map(int,f[1:]));continue
        i=int(f[1])
        if not 0<=i<len(rows):raise ValueError('Load case ID')
        by.setdefault(i,[]).append(line)
    if set(by)!=set(range(len(rows))):raise ValueError('Load missing case')
    completed=errors=aborts=values=reads=official=0
    for c in rows:
        i=c['i'];p=c['p'];sk=c['sk'];events=[s.split() for s in by[i]];kinds=('C','W','L','X','P','K','U','Z','D','A','T','V','S')
        parts={k:[f for f in events if f[0]==k] for k in kinds}
        if any(f[0] not in kinds for f in events):raise ValueError('Load unknown event')
        if parts['C']!=[['C',str(i),str(p),str(c['id']),str(c['base']),str(c['sentinel'])]] or events[0][0]!='C':raise ValueError('Load command')
        total=(12,17,23,23)[p];k,l=((4,4),(6,5),(8,7),(8,7))[p];base=c['base']
        plan=((1<<total)-1)<<base
        gold=[] if p==3 else decode_key_math(sk,p)[0]
        bad=next((n for n,r in enumerate(gold) if not r[7]),None)
        code=1 if p==3 else 5 if base+total>64 else 4 if plan&(1<<c['sentinel']) else 3 if c['fault'] else 2 if bad is not None else 0
        expected=[] if code in (1,4,5) else decode_key_math(sk,p,limit=c['fault_word']*8)[0] if c['fault'] else gold[:bad] if bad is not None else gold
        if c['abort']:
            prefix={1:0,2:256,3:0,4:len(gold)-1,5:len(gold)}[c['abort']]
            expected=gold[:prefix]
            if parts['D'] or parts['A']!=[['A',str(i),str(c['abort'])]] or parts['S'] or parts['V']:raise ValueError('Load reset retirement')
            aborts+=1
        else:
            result=plan if code==0 else 0
            header=[v[::-1].hex() for v in (sk[:32],sk[32:64],sk[64:128])] if code==0 else ['0'*64,'0'*64,'0'*128]
            if parts['A'] or parts['D']!=[['D',str(i),str(code),str(c['id']),f'{result:016x}',*header]]:raise ValueError(f'Load completion/header case{i}')
            if parts['S']!=[['S',str(i),str(c['sentinel'])]]:raise ValueError('Load sentinel preservation missing')
            completed+=1;errors+=int(code!=0);official+=int(c['official'] and code==0)
        # Compare ALL accepted scalar writes,including failed and reset prefixes.
        xgold=[]
        for n,r in enumerate(expected):
            reg=base+n//256
            xgold.append(['X',str(i),str(reg),str(r[2]),f'{r[3]:06x}',str(r[4])])
        if parts['X']!=xgold:raise ValueError(f'Load scalar prefix case{i}')
        needed=0 if code in (1,4,5) else c['fault_word']+1 if c['fault'] else (gold[bad][6]+63)//64 if bad is not None else len(sk)//8
        if c['abort']:needed={1:3,2:16+(256*(4 if p==1 else 3))//64,3:17,4:len(sk)//8,5:len(sk)//8}[c['abort']]
        if len(parts['W'])!=needed:raise ValueError(f'Load accepted words case{i}:{len(parts["W"])}!={needed}')
        for j,f in enumerate(parts['W']):
            index=j^(int(c['fault']==1 and j==c['fault_word']))
            n=c['fault']-10 if c['fault']>=10 and j==c['fault_word'] else 8
            last=int(j==len(sk)//8-1)^int(c['fault']==2 and j==c['fault_word'])
            if f!=['W',str(i),str(index),str(n),str(last),f'{int.from_bytes(sk[8*j:8*j+8],"little"):016x}']:raise ValueError('Load encoded input')
        allocated={};committed=set();pending={};acks={};word_inputs=0;written=0;published=False
        for f in events:
            kind=f[0]
            if kind=='W':word_inputs+=1
            elif kind=='L':
                reg,owner,mode,param=map(int,f[2:]);ordinal=len(allocated)
                if reg!=base+ordinal or ordinal>=total or reg==c['sentinel'] or owner!=c['id'] or param!=p or mode!=(1 if ordinal<l+k else 3):raise ValueError('Load allocation metadata')
                allocated[reg]=[];acks[reg]=set()
            elif kind=='X':
                reg,index=int(f[2]),int(f[3])
                if reg not in allocated or len(allocated[reg])!=index or expected[written][6]>word_inputs*64:raise ValueError('Load write ownership/source causality')
                allocated[reg].append(int(f[4],16));written+=1
            elif kind=='P':
                reg,w=int(f[2]),int(f[3]);key=(reg,w)
                if reg not in allocated or len(allocated[reg])<4*w+4 or key in pending or w in acks[reg]:raise ValueError('Load packed request order')
                packed=sum(v<<(23*j) for j,v in enumerate(allocated[reg][4*w:4*w+4]))
                if int(f[4],16)!=packed:raise ValueError('Load packing mismatch')
                pending[key]=packed
            elif kind=='K':
                reg,w=map(int,f[2:]);key=(reg,w)
                if key not in pending:raise ValueError('Load orphan memory ACK')
                del pending[key];acks[reg].add(w)
            elif kind=='U':
                reg,finish=map(int,f[2:])
                if reg not in allocated or any(r==reg for r,w in pending) or reg in committed:raise ValueError('Load finish ownership')
                if finish==0:
                    if len(allocated[reg])!=256 or acks[reg]!=set(range(64)):raise ValueError('Load success before all ACKs')
                    committed.add(reg)
                elif finish!=1 or len(allocated[reg])==256:raise ValueError('Load bad rollback finish')
            elif kind=='Z':
                reg=int(f[2])
                if reg not in committed or published:raise ValueError('Load rollback released wrong owner')
                committed.remove(reg)
            elif kind=='D':
                if pending or (code==0 and committed!=set(range(base,base+total))) or (code!=0 and committed):raise ValueError('Load non-atomic retirement')
                published=True
            elif kind=='V' and (not published or code!=0):raise ValueError('Load read before publication')
        if not c['abort']:
            # Errors must finish their one partial allocation and free EVERY earlier polynomial.
            finished=[int(f[2]) for f in parts['U']]
            allocations=0 if code in (1,4,5) else total if code==0 else len(expected)//256+1
            if len(allocated)!=allocations:raise ValueError('Load unexpected allocation count')
            if set(finished)!=set(allocated) or len(finished)!=len(set(finished)):raise ValueError('Load active allocation leak')
            vgold=[]
            if code==0:
                for ordinal in range(total):
                    poly=[r[3] for r in gold[256*ordinal:256*(ordinal+1)]]
                    small=int(all(v<=4 or v>=8380413 for v in poly))
                    for w in range(64):
                        packed=sum(v<<(23*j) for j,v in enumerate(poly[4*w:4*w+4]))
                        vgold.append(['V',str(i),str(base+ordinal),str(w),str(c['id']),str(1 if ordinal<l+k else 3),str(p),'0',str(small),f'{packed:023x}'])
            if parts['V']!=vgold:raise ValueError(f'Load exact bank readback case{i}')
        if len(parts['T'])!=1 or len(parts['T'][0])!=8:raise ValueError('Load witnesses')
        columns=(2,3,5,7) if shared else (2,3,4,5)
        if code==0 and min(int(parts['T'][0][j]) for j in columns)<=0 and not c['abort']:raise ValueError('Load required stalls/private visibility not reached')
        if code==2 and bad is not None and bad>256 and (not parts['Z'] or (not shared and int(parts['T'][0][6])<=0)):raise ValueError('Load late rollback not reached')
        values+=len(parts['X']);reads+=len(parts['V'])
    if footer!=[len(rows),completed,errors,aborts,values,reads]:raise ValueError('Load totals')
    return f'STAGE5N4C1_SIGN_LOAD_COMPARE_PASS:{len(rows)} commands,{completed} completions,{errors} expected errors,{aborts} resets,{values} exact scalar writes,{reads} exact packed readbacks;{official}/75 official KeyGen secret keys loaded;all ACKs,whole-key publication and rollback checked\n'


def verify_sign_load_service(lines):
    auxiliary={'B','G','J','E','I','N','Y','O'}
    message=verify_sign_load([s for s in lines if s.split()[0] not in auxiliary],shared=True)
    by={};lifecycle={}
    for s in lines[1:]:
        f=s.split()
        if f[0] in auxiliary:by.setdefault(int(f[1]),[]).append(f)
        if f[0] in ('C','D','A','Y','O'):lifecycle.setdefault(int(f[1]),[]).append(f[0])
    rows=sign_load_cases()
    if set(by)!=set(range(len(rows))):raise ValueError('Shared load auxiliary cases')
    for c in rows:
        i=c['i'];events=by[i];parts={k:[f for f in events if f[0]==k] for k in auxiliary}
        if len(parts['B'])!=1 or len(parts['B'][0])!=12:raise ValueError('Shared load arbitration witness shape')
        counts=list(map(int,parts['B'][0][2:]));blocking=i in (0,25,50)
        if counts[:8]!=[6 if blocking else 0]*8 or counts[8]!=1 or counts[9]<=0:raise ValueError('Shared load priority/owner witnesses')
        # Sentinel is produced by real SHAKE256/ExpandMask before every key.
        msg=bytes((i+j)&255 for j in range(66))
        poly=reference.sample(2,0,hashlib.shake_256(msg).digest(4096))[0]
        words=[sum(v<<(23*j) for j,v in enumerate(poly[4*w:4*w+4])) for w in range(64)]
        if blocking:
            if len(parts['G'])!=1 or len(parts['G'][0])!=3 or int(parts['G'][0][2]) not in (0,1):raise ValueError('Shared load raw descriptor')
            core=parts['G'][0][2];expected=hashlib.shake_256(b'').digest(17)
            if len(parts['J'])!=2:raise ValueError('Shared load raw result count')
            for n,f in enumerate(parts['J']):
                size=16 if n==0 else 1
                if f[2:5]!=[core,'61000',str(size)] or int(f[5],16)&((1<<(8*size))-1)!=int.from_bytes(expected[16*n:16*n+size],'little'):raise ValueError('Shared load raw bytes/owner')
            if parts['E']!=[['E',str(i),core,'61000']]:raise ValueError('Shared load raw retirement')
            if parts['I']!=[['I',str(i),'60000',str(c['sentinel']),f'{words[0]:023x}']]:raise ValueError('Shared load pending public read')
            kinds=[f[0] for f in events if f[0] in ('G','J','E','I')]
            if kinds!=['G','J','J','E','I']:raise ValueError('Shared load peer order')
        elif any(parts[k] for k in ('G','J','E','I')):raise ValueError('Unexpected shared load blocker stream')
        expected=[] if c['abort'] else [['N',str(i),str(c['sentinel']),str(w),'60000','2','0','0',str(int(all(v<=4 or v>=8380413 for v in poly))),f'{words[w]:023x}'] for w in range(64)]
        if parts['N']!=expected:raise ValueError('Shared load sentinel data/metadata preservation')
        good=not c['abort'] and c['p']!=3 and c['base']+(12,17,23,23)[c['p']]<=64 and not (((1<<(12,17,23,23)[c['p']])-1)<<c['base'])&(1<<c['sentinel']) and not c['fault'] and all(r[7] for r in decode_key_math(c['sk'],c['p'])[0])
        if parts['Y']!=([['Y',str(i),str(c['base']),str(c['id']),str(c['p'])]] if good else []) or parts['O']!=([['O',str(i),'0','60001','0','0']] if good else []):raise ValueError('Shared key-to-CNB owner handoff')
        if lifecycle.get(i)!=(['C','A'] if c['abort'] else ['C','D','Y','O'] if good else ['C','D']):raise ValueError('Shared key owner handoff order')
    return message.replace('STAGE5N4C1_SIGN_LOAD_COMPARE_PASS','STAGE5N4C2_SIGN_LOAD_SERVICE_COMPARE_PASS')+'SHARED_LOAD_ARBITRATION_PASS:3 levels,8 prior-owner blocking phases each,138 acceptance edges and held exclusive ownership;3 actual raw hashes and pending reads;133 sampled sentinel polynomials preserved;95 real key-to-CNB owner handoffs\n'


def sign_decode_artifact(token):
    rows=sign_decode_cases()
    return f'{token} {len(rows)}\n'+''.join(f"{c['i']} {c['p']} {c['id']} {c['fault_word']} {c['fault']} {c['abort']} {len(c['sk'])} {c['sk'].hex()}\n" for c in rows)


def check_sign_decode_c():
    gcc=shutil.which('gcc');build=HERE/'reference_build';build.mkdir(exist_ok=True)
    if not gcc:raise ValueError('GCC required for secret-key decoding oracle')
    count=coefficients=0
    for p,level in enumerate((2,3,5)):
        exe=build/f'sign_decode_reference_{level}.exe';ref=ROOT/'dilithium-sw-model/ref'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ref),str(ROOT/'tb/tb_dilithium/reference/sign_decode_reference.c'),
            *[str(ref/n) for n in ('packing.c','poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],check=True,capture_output=True,text=True)
        rows=[c for c in sign_decode_cases() if c['p']==p]
        answer=subprocess.run([str(exe)],input=''.join(' '.join(map(str,c['sk']))+'\n' for c in rows),capture_output=True,text=True,check=True).stdout.splitlines()
        if len(answer)!=len(rows):raise ValueError('C decode count')
        for c,line in zip(rows,answer,strict=True):
            f=line.split();sk=c['sk'];gold,_=decode_key_math(sk,p)
            if f[:3]!=[sk[:32].hex(),sk[32:64].hex(),sk[64:128].hex()] or list(map(int,f[3:]))!=[r[3] for r in gold]:raise ValueError('Python/C secret-key decode mismatch')
            count+=1;coefficients+=len(gold)
    message=f'PYTHON_C_SIGN_DECODE_PASS:{count} key fixtures,{coefficients} coefficients;unchanged C unpack_sk/pack_sk roundtrip,all3 levels\n'
    (HERE/'stage5_sign_decode_c_reference.log').write_text(message);print(message,end='')


def verify_sign_decode(lines):
    _,token=check();rows=sign_decode_cases()
    if not lines or lines[0]!='H '+token:raise ValueError('Decode stale token')
    by={};footer=None
    for s in lines[1:]:
        f=s.split()
        if f[0]=='F':
            if footer is not None or s!=lines[-1]:raise ValueError('Decode footer order')
            footer=list(map(int,f[1:]));continue
        i=int(f[1])
        if not 0<=i<len(rows):raise ValueError('Unknown decode case')
        by.setdefault(i,[]).append(f)
    if set(by)!=set(range(len(rows))):raise ValueError('Missing decode case')
    complete=errors=aborts=official=coefficients=0
    for c in rows:
        i=c['i'];events=by[i];kinds=('C','W','B','P','D','A','T');parts={k:[f for f in events if f[0]==k] for k in kinds}
        if any(f[0] not in kinds for f in events):raise ValueError('Unknown decode event')
        if parts['C']!=[['C',str(i),str(c['p']),str(c['id'])]]:raise ValueError('Decode command')
        if len(parts['T'])!=1 or len(parts['T'][0])!=6:raise ValueError('Decode witnesses')
        witness=list(map(int,parts['T'][0][2:]))
        if witness[0]<4:raise ValueError('Decode completion/reset hold absent')
        sk=c['sk'];p=c['p'];word_count=len(sk)//8
        gold=[] if p==3 else decode_key_math(sk,p)[0]
        invalid=next((j for j,r in enumerate(gold) if not r[7]),None)
        code=1 if p==3 else 3 if c['fault'] else 2 if invalid is not None else 0
        if code==0 and not c['abort'] and min(witness[1:])<=0:raise ValueError('Decode stalled header/output/input not exercised')
        needed=0 if p==3 else c['fault_word']+1 if c['fault'] else (gold[invalid][6]+63)//64 if invalid is not None else word_count
        if not c['abort'] and len(parts['W'])!=needed:raise ValueError(f'Decode accepted-word count case{i}')
        for j,f in enumerate(parts['W']):
            index=j^(1 if c['fault']==1 and j==c['fault_word'] else 0)
            last=int(j==word_count-1)^(int(c['fault']==2 and j==c['fault_word']))
            n=c['fault']-10 if c['fault']>=10 and j==c['fault_word'] else 8
            if f!=['W',str(i),str(index),str(n),str(last),f'{int.from_bytes(sk[8*j:8*j+8],"little"):016x}']:raise ValueError('Decode input stream')
        header=[['B',str(i),str(c['id']),sk[:32][::-1].hex(),sk[32:64][::-1].hex(),sk[64:128][::-1].hex()]]
        if c['abort']:
            if parts['D'] or parts['A']!=[['A',str(i),str(c['abort'])]]:raise ValueError('Decode reset leaked completion')
            expected_words={1:3,2:16,3:17,4:word_count,5:word_count}[c['abort']]
            expected_coeffs={1:0,2:0,3:0,4:len(gold)-1,5:len(gold)}[c['abort']]
            if len(parts['W'])!=expected_words or len(parts['P'])!=expected_coeffs:raise ValueError('Decode reset checkpoint/prefix')
            if parts['B']!=([] if c['abort']<=2 else header):raise ValueError('Decode reset header')
            gold=gold[:expected_coeffs];aborts+=1
        else:
            if parts['A'] or parts['D']!=[['D',str(i),str(code),str(c['id'])]]:raise ValueError('Decode status')
            if parts['B']!=([] if p==3 or (c['fault'] and c['fault_word']<16) else header):raise ValueError('Decode header')
            if c['fault']:gold=decode_key_math(sk,p,limit=c['fault_word']*8)[0]
            elif invalid is not None:gold=gold[:invalid]
            complete+=1;errors+=int(code!=0);official+=int(c['official'])
        expected=[['P',str(i),str(c['id']),*[str(x) for x in r[:3]],f'{r[3]:06x}',str(r[4]),str(r[5])] for r in gold]
        if parts['P']!=expected:raise ValueError(f'Decode coefficients/metadata case{i}')
        # Prevent output before enough source bits were actually accepted.
        words=outputs=0;header_seen=False
        for f in events:
            if f[0]=='W':words+=1
            elif f[0]=='B':
                if words!=16:raise ValueError('Early decoder header')
                header_seen=True
            elif f[0]=='P':
                if not header_seen or gold[outputs][6]>words*64:raise ValueError('Early decoder coefficient')
                outputs+=1
            elif f[0]=='D' and f[2]=='0' and outputs!=len(gold):raise ValueError('Early decoder success')
        coefficients+=len(gold)
    if footer!=[len(rows),complete,errors,aborts,coefficients]:raise ValueError('Decode totals')
    return f'STAGE5N4A_SIGN_DECODE_COMPARE_PASS:{len(rows)} commands,{complete} completions,{errors} expected errors,{aborts} reset aborts,{coefficients} exact coefficients;{official}/75 published NIST secret keys decoded\n'


@lru_cache(maxsize=1)
def sign_hash_cases():
    """Local FIPS-derived message fixtures;no full signature vector claim."""
    rows=[]
    def add(op,p,ctx=0,mlen=0,nonce=0,fault=0,fault_word=0,abort=0,jid=None,link=-1,pattern=0):
        i=len(rows);material=hashlib.shake_256(f'sign-hash-{i}-{pattern}'.encode()).digest(256)
        tr,key,rnd,mu,seed=material[:64],material[64:96],material[96:128],material[128:192],material[192:256]
        if pattern==1:rnd=bytes(32)
        if link>=0:
            if op in (1,2):mu=rows[link]['digest']
            if op==3:seed=rows[link]['digest']
        highs=[]
        if op==0:body=hashlib.shake_256(f'sign-body-{i}'.encode()).digest(ctx+mlen)
        elif op==2:
            k=(4,6,8,4)[p];width=6 if p==0 else 4;maximum=43 if p==0 else 15
            highs=[(j*17+i)%(maximum+1) for j in range(256*k)]
            body=sum(v<<(j*width) for j,v in enumerate(highs)).to_bytes(32*k*width,'little')
        else:body=b''
        prefix=tr+b'\0'+bytes([ctx&255]) if op==0 else key+rnd+mu if op==1 else mu if op==2 else seed+nonce.to_bytes(2,'little')
        message=prefix+body;code=1 if p==3 or (op==0 and ctx>255) or len(message)>65535 else 2 if fault else 0
        emitted=b'' if code==1 else (prefix+body[:8*fault_word]).ljust(len(message),b'\0') if fault else message
        outlen=0 if op==3 else (32,48,64,32)[p] if op==2 else 64
        digest=hashlib.shake_256(emitted).digest(outlen or 64) if code!=1 else b''
        values=reference.sample(2,p,hashlib.shake_256(message).digest(4096))[0] if op==3 and code==0 else []
        rows.append(dict(i=i,op=op,p=p,id=(65000+i)&65535 if jid is None else jid,ctx=ctx,mlen=mlen,nonce=nonce,
            fault=fault,fw=fault_word,abort=abort,link=link,peer=int(i%5==0 and code!=1 and abort==0),
            tr=tr,key=key,rnd=rnd,mu=mu,seed=seed,body=body,highs=highs,message=message,emitted=emitted,
            outlen=outlen,digest=digest,values=values,code=code))
    for p in range(3):
        # Actual RTL digests are forwarded to the dependent descriptors in TB.
        first=len(rows);add(0,p,ctx=7,mlen=169)
        second=len(rows);add(1,p,link=first,pattern=int(p==0));add(2,p,link=first);add(3,p,nonce=65535,link=second)
        for ctx,mlen in [(0,0),*[(0,n) for n in range(1,10)],(1,0),(7,1),(8,7),(9,8),(255,0),(255,137),
                         *[(0,n) for n in (69,70,71,135,136,137,271,272,273)],(0,65469),(255,65214)]:add(0,p,ctx=ctx,mlen=mlen)
        add(1,p);add(1,p,pattern=1);add(2,p)
        for nonce in (0,1,(4,5,7)[p]-1,(4,5,7)[p],255,256,65534):add(3,p,nonce=nonce)
        for fw,fault in [(0,1),(0,2),(0,3),(1,1),(1,2),(1,3)]:add(0,p,ctx=1,mlen=9,fault=fault,fault_word=fw)
        add(2,p,fault=1,fault_word=95)
        add(0,p,ctx=256);add(0,p,mlen=65470);add(0,p,ctx=255,mlen=65215)
    for op in range(4):add(op,3)
    for phase in range(1,6):
        jid=42000+phase;op=3 if phase==5 else (phase-1)%3
        add(op,phase%3,ctx=7 if op==0 else 0,mlen=137 if op==0 else 0,nonce=65535,abort=phase,jid=jid)
        add(op,phase%3,ctx=7 if op==0 else 0,mlen=137 if op==0 else 0,nonce=65535,jid=jid)
    return rows


def sign_hash_artifact(token):
    rows=sign_hash_cases();body=[]
    for c in rows:
        fixed=' '.join(str(c[k]) for k in ('i','op','p','id','ctx','mlen','nonce','fault','fw','abort','link','peer'))
        fields=' '.join(c[k][::-1].hex() for k in ('tr','key','rnd','mu','seed'))
        body.append(f"{fixed} {fields} {len(c['body'])} {c['body'].hex() or '-'}")
    return f'{token} {len(rows)}\n'+'\n'.join(body)+'\n'


def check_sign_hash_c():
    gcc=shutil.which('gcc');build=HERE/'reference_build';build.mkdir(exist_ok=True)
    if not gcc:raise ValueError('GCC required for signing hash oracle')
    count=octets=masks=0
    for p,level in enumerate((2,3,5)):
        exe=build/f'sign_hash_reference_{level}.exe';ref=ROOT/'dilithium-sw-model/ref'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ref),str(ROOT/'tb/tb_dilithium/reference/sign_hash_reference.c'),
            *[str(ref/n) for n in ('polyvec.c','poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],check=True,capture_output=True,text=True)
        rows=[c for c in sign_hash_cases() if c['p']==p and c['code']!=1];stdin=[]
        for c in rows:
            values=list(c['tr']+c['key']+c['rnd']+c['mu']+c['seed']+c['body'])
            stdin.append(' '.join(map(str,[c['op'],c['ctx'],c['mlen'],c['nonce'],len(c['body']),*values,*c['highs']])))
        answer=subprocess.run([str(exe)],input='\n'.join(stdin)+'\n',capture_output=True,text=True,check=True).stdout.splitlines()
        if len(answer)!=len(rows):raise ValueError('Signing hash C count')
        for c,line in zip(rows,answer,strict=True):
            f=line.split();digest=hashlib.shake_256(c['message']).digest(c['outlen'] or 64)
            if bytes.fromhex(f[0])!=c['message'] or bytes.fromhex(f[1])!=digest or list(map(int,f[2:]))!=c['values']:raise ValueError('Python/C signing hash mismatch')
            count+=1;octets+=len(c['message']);masks+=int(c['op']==3)
    message=f'PYTHON_C_SIGN_HASH_PASS:{count} formatted messages,{octets} bytes,{masks} mask polynomials;unchanged C SHAKE/w1 packing/mask sampling\n'
    (HERE/'stage5_sign_hash_c_reference.log').write_text(message);print(message,end='')


def verify_sign_hash(lines):
    _,token=check();rows=sign_hash_cases()
    if not lines or lines[0]!='H '+token:raise ValueError('Signing hash stale token')
    by={};footer=None;previous_case=-1
    for s in lines[1:]:
        f=s.split()
        if f[0]=='F':
            if footer is not None or s!=lines[-1]:raise ValueError('Signing hash footer order')
            footer=list(map(int,f[1:]));continue
        i=int(f[1])
        if not 0<=i<len(rows):raise ValueError('Unknown signing hash case')
        if i<previous_case:raise ValueError('Signing hash case events reordered')
        previous_case=i
        by.setdefault(i,[]).append(f)
    if set(by)!=set(range(len(rows))):raise ValueError('Missing signing hash case')
    done=errors=aborts=hashbytes=coefficients=words=peers=links=0;next_core=0
    for c in rows:
        i=c['i'];ev=by[i];kinds=('C','D','P','W','R','H','G','Q','L','S','E','V','A','T');part={k:[f for f in ev if f[0]==k] for k in kinds}
        if any(f[0] not in kinds for f in ev):raise ValueError('Unknown signing hash event')
        if part['C']!=[['C',str(i),str(c['op']),str(c['p']),str(c['id'])]]:raise ValueError('Signing hash command')
        if len(part['T'])!=1 or len(part['T'][0])!=8:raise ValueError('Signing hash witnesses')
        witness=list(map(int,part['T'][0][2:]))
        if witness[0]<4:raise ValueError('Missing signing hash held retirement/reset')
        if c['code']!=1 and not c['abort'] and witness[1]==0:raise ValueError('No signing hash descriptor stall')
        if c['abort']:
            if part['E'] or part['A']!=[['A',str(i),str(c['abort'])]]:raise ValueError('Signing hash reset completion leak')
            aborts+=1
        else:
            if part['A'] or part['E']!=[['E',str(i),str(c['id']),str(c['code'])]]:raise ValueError('Signing hash absorption completion')
            done+=1;errors+=int(c['code']!=0)
        if c['code']==1:
            if any(part[k] for k in ('D','P','W','R','H','G','Q','S','V')):raise ValueError('Invalid signing descriptor touched service')
            continue
        if part['D'] and ev.index(part['D'][0])<ev.index(part['C'][0]):raise ValueError('Signing descriptor before command')
        if part['W'] and (not part['D'] or ev.index(part['W'][0])<ev.index(part['D'][0])):raise ValueError('Signing absorption before descriptor')
        if part['R'] and (not part['W'] or ev.index(part['R'][0])<ev.index(part['W'][-1])):raise ValueError('Signing digest before absorption')
        if part['S'] and part['R'] and ev.index(part['S'][0])<ev.index(part['R'][-1]):raise ValueError('Signing retirement before digest accepted')
        if part['E'] and any(ev.index(f)>ev.index(part['E'][0]) for f in part['S']+part['Q']):raise ValueError('Formatter released before service owners')
        if part['V'] and (not part['S'] or ev.index(part['V'][0])<ev.index(part['S'][0])):raise ValueError('Mask read before completion')
        if part['Q'] and (not part['H'] or ev.index(part['Q'][0])<ev.index(part['H'][-1])):raise ValueError('Peer retirement before output')
        if part['L'] and ev.index(part['L'][0])>ev.index(part['C'][0]):raise ValueError('Digest not forwarded before command')
        peer_core=next_core
        if part['G']!=([['G',str(i),str(peer_core)]] if c['peer'] else []):raise ValueError('Peer descriptor/core')
        if c['peer']:next_core^=1
        core=next_core
        expect_desc=['D',str(i),str(int(c['op']==3)),str(c['id']),str(c['p']),str(len(c['message'])),str(c['outlen']),str(core)]
        if part['D']!=([expect_desc] if c['abort']!=1 else []):raise ValueError('Signing hash descriptor')
        if part['D']:next_core^=1
        message=c['emitted'];wanted=[]
        for j in range((len(message)+7)//8):
            octets=message[8*j:8*j+8]
            wanted.append(['W',str(i),str(j),str(len(octets)),str(int(8*(j+1)>=len(message))),f'{int.from_bytes(octets,"little"):016x}'])
        if part['W']!=(wanted[:len(part['W'])] if c['abort'] else wanted):raise ValueError(f'Signing absorption bytes case{i}')
        if c['abort']:
            expected_words=0 if c['abort']==1 else 2 if c['abort']==2 else len(wanted)
            if len(part['W'])!=expected_words or any(part[k] for k in ('R','S','V','H','Q')):raise ValueError('Signing reset checkpoint/prefix')
        words+=len(part['W'])
        payload=[];nwords=(len(c['body'])+7)//8
        for j in range(nwords):
            valid=min(8,len(c['body'])-8*j);index=j;last=int(j==nwords-1)
            if c['fault'] and j==c['fw']:
                if c['fault']==1:index^=1
                elif c['fault']==2:valid=0
                else:last^=1
            value=int.from_bytes(c['body'][8*j:8*j+8]+bytes([255])*(8-min(8,len(c['body'])-8*j)),'little')
            payload.append(['P',str(i),str(index),str(valid),str(last),f'{value:016x}'])
            if c['fault'] and j==c['fw']:break
        if part['P']!=(payload[:len(part['P'])] if c['abort'] else payload):raise ValueError('Signing payload protocol')
        if not c['abort'] and c['op']!=3:
            actual=b''
            for j,f in enumerate(part['R']):
                if len(f)!=7 or list(map(int,f[2:6]))!=[j,c['id'],core,16]:raise ValueError('Signing hash output tags/core/bytes')
                actual+=int(f[6],16).to_bytes(16,'little')
            if actual!=c['digest'] or part['S']!=[['S',str(i),str(c['id']),str(core)]]:raise ValueError('Signing SHAKE output/retirement')
            hashbytes+=len(actual)
        elif not c['abort']:
            expected=[]
            for j in range(64):expected.append(['V',str(i),str(j),f'{sum(c["values"][4*j+k]<<(23*k) for k in range(4)):023x}',str(c['id']),str(c['p']),'0'])
            if part['V']!=expected or part['S']!=[['S',str(i),str(c['id']),str(core)]]:raise ValueError('Signing mask coefficients/retirement')
            coefficients+=256
        if c['peer']:
            expected_peer=hashlib.shake_256(b'').digest(16)
            if part['H']!=[['H',str(i),str(peer_core),str(53000+i),expected_peer[::-1].hex()]] or part['Q']!=[['Q',str(i),str(53000+i),str(peer_core)]]:raise ValueError('Peer raw output/stream separation')
            peers+=1
        elif part['H'] or part['Q']:raise ValueError('Unexpected peer output')
        if c['link']>=0:
            if part['L']!=[['L',str(i),str(c['link']),(c['seed'] if c['op']==3 else c['mu'])[::-1].hex()]]:raise ValueError('Dependent digest forwarding')
            links+=1
        elif part['L']:raise ValueError('Unexpected digest forwarding')
        if c['abort']:next_core=0
        if not c['abort'] and c['code']!=1:
            if part['V'] and c['op']!=3:raise ValueError('Raw request allocated polynomial')
            if witness[2]==0 or witness[3]==0 or witness[5]==0:raise ValueError('Missing signing hash absorption/output/ownership witnesses')
    if footer!=[len(rows),done,errors,aborts,words,hashbytes,coefficients,peers]:raise ValueError('Signing hash totals')
    return f'STAGE5N4B_SIGN_HASH_COMPARE_PASS:{len(rows)} commands,{done} completions,{errors} expected errors,{aborts} reset aborts;{words} absorption words,{hashbytes} exact SHAKE bytes,{coefficients} mask coefficients;{peers} peer-core jobs,{links} dependent digest forwards\n'


@lru_cache(maxsize=None)
def sign_challenge_material(p,nonce):
    m=sign_matrix_material(p,nonce);width=6 if p==0 else 4
    high=[v for poly in m['high'] for v in poly]
    packed=sum(v<<(width*j) for j,v in enumerate(high)).to_bytes(len(high)*width//8,'little')
    digest=hashlib.shake_256(m['mu']+packed).digest((32,48,64)[p])
    challenge=tuple(reference.sample(3,p,hashlib.shake_256(digest).digest(4096))[0])
    if sum(v!=0 for v in challenge)!=(39,49,60)[p] or any(v not in (0,1,8380416) for v in challenge):raise ValueError('Challenge oracle weight/range')
    return dict(m,packed=packed,digest=digest,challenge=challenge)


@lru_cache(maxsize=1)
def sign_challenge_cases():
    rows=[]
    for p,l in enumerate((4,5,7)):
        def add(inject=0,abort=0,nonce=0,jid=None):
            code,detail={0:(0,0),1:(3,0),2:(3,0),3:(4,2),4:(4,3),5:(6,0),6:(6,0),7:(6,0),8:(6,0),9:(6,0),10:(6,0),11:(5,7),12:(1,0),13:(2,0)}[inject]
            i=len(rows);rows.append(dict(i=i,p=p,id=40000+i if jid is None else jid,nonce=nonce,inject=inject,abort=abort,code=code,detail=detail))
        add();add(nonce=l,jid=65535)
        for inject in range(1,14):add(inject=inject)
        for abort in range(1,7):add(abort=abort);add()
    return rows


def sign_challenge_artifact(token):
    rows=sign_challenge_cases()
    return f'{token} {len(rows)}\n'+''.join(' '.join(str(c[k]) for k in ('i','p','id','nonce','inject','abort'))+
        f" {m['rnd'][::-1].hex()} {len(m['sk'])} {m['sk'].hex()} {m['body'].hex()}\n" for c in rows for m in [sign_challenge_material(c['p'],c['nonce'])])


def check_sign_challenge_c():
    gcc=shutil.which('gcc');ref=ROOT/'dilithium-sw-model/ref';count=packedbytes=digestbytes=values=0
    if not gcc:raise ValueError('GCC required for challenge oracle')
    for p,level in enumerate((2,3,5)):
        exe=HERE/f'reference_build/sign_challenge_reference_{level}.exe'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ref),str(ROOT/'tb/tb_dilithium/reference/sign_challenge_reference.c'),
            *[str(ref/n) for n in ('polyvec.c','poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],check=True,capture_output=True,text=True)
        rows=[sign_challenge_material(p,n) for n in (0,(4,5,7)[p])]
        answer=subprocess.run([str(exe)],input=''.join(' '.join(map(str,[*m['mu'],*[v for poly in m['high'] for v in poly]]))+'\n' for m in rows),capture_output=True,text=True,check=True).stdout.splitlines()
        if len(answer)!=len(rows):raise ValueError('Challenge C fixture count')
        for m,line in zip(rows,answer,strict=True):
            f=line.split()
            if bytes.fromhex(f[0])!=m['packed'] or bytes.fromhex(f[1])!=m['digest'] or tuple(map(int,f[2:]))!=m['challenge']:raise ValueError('Python/C challenge disagreement')
            count+=1;packedbytes+=len(m['packed']);digestbytes+=len(m['digest']);values+=256
    message=f'PYTHON_C_SIGN_CHALLENGE_PASS:{count} fixtures,{packedbytes} packed w1 bytes,{digestbytes} ctilde bytes,{values} challenge coefficients;unchanged C pack/SHAKE/SampleInBall\n'
    (HERE/'stage5_sign_challenge_c_reference.log').write_text(message);print(message,end='')


@lru_cache(maxsize=None)
def sign_products_material(p,nonce):
    m=sign_challenge_material(p,nonce);q=8380417;k,l=((4,4),(6,5),(8,7))[p]
    raw,hats=sign_prepare_math(m['sk'],p);secrets=[tuple(r[3] for r in raw[j:j+256]) for j in range(0,len(raw),256)]
    # Sparse negacyclic schoolbook convolution,independent of both NTT schedules.
    signs=[(i,1 if v==1 else -1) for i,v in enumerate(m['challenge']) if v]
    products=[]
    for secret in secrets:
        values=[0]*256
        for offset,sign in signs:
            for j,a in enumerate(secret):
                index=offset+j;values[index%256]+=sign*a*(1 if index<256 else -1)
        products.append(tuple(v%q for v in values))
    chat=tuple(ntt_reference.direct_forward(list(m['challenge'])))
    pwm=tuple(tuple(a*b%q for a,b in zip(chat,secret,strict=True)) for secret in hats)
    z=tuple(tuple((a+b)%q for a,b in zip(y,c,strict=True)) for y,c in zip(m['y'],products[:l],strict=True))
    low=tuple(tuple((a-b)%q for a,b in zip(y,c,strict=True)) for y,c in zip(m['low'],products[l:l+k],strict=True))
    return dict(m,products=tuple(products),pwm=pwm,z=z,corrected=low,ct0=tuple(products[l+k:]),chat=chat)


@lru_cache(maxsize=None)
def sign_retry_chain(p,start):
    n=start;l=(4,5,7)[p];chain=[]
    while n+l<=65536:
        m=sign_accept_material(p,n);chain.append((n,m));n+=l
        if not m['reason']:return tuple(chain),0,n
        if len(chain)>128:raise ValueError('Bound local reference fixtures;not an RTL retry limit')
    return tuple(chain),6,n


def sign_retry_cases():
    rows=[]
    def add(p,start,inject=0,abort=0):
        chain,code,n=sign_retry_chain(p,start);i=len(rows)
        rows.append(dict(i=i,p=p,nonce=start,inject=inject,abort=abort,id=45000+i,code=2 if inject else code,
            stage={1:0,2:0,3:1,4:5}.get(inject,0),detail={1:4,2:5,3:3,4:5}.get(inject,0)))
    for p,clean in enumerate((4,0,28)):
        start=(0,455,0)[p]
        add(p,start);add(p,clean);add(p,65536-(4,5,7)[p]);add(p,65536)
        if p==1:add(p,5)
        for fault in range(1,5):add(p,start,inject=fault)
        phases=[1,4,5]+([2] if p==0 else [3] if p==2 else [])
        for phase in phases:add(p,start,abort=phase);add(p,clean)
    return rows


def sign_retry_artifact(token):
    rows=sign_retry_cases()
    return f'{token} {len(rows)}\n'+''.join(f"{c['i']} {c['p']} {c['id']} {c['nonce']} {c['inject']} {c['abort']} "
        f"{m['rnd'][::-1].hex()} {m['sk'].hex()} {m['body'].hex()}\n" for c in rows for m in [sign_matrix_material(c['p'],0)])


def verify_sign_retry(lines):
    _,token=check();rows=sign_retry_cases()
    if not lines or lines[0]!='G '+token:raise ValueError('Retry stale capture')
    by={};footer=None;previous=-1
    tags=('K','C','S','D','M','L','O','I','H','Q','J','W','T','BAD','A','COM','F','X','Z','R','E','V','BARRIER','TAKE','B')
    for line in lines[1:]:
        f=line.split()
        if not f:raise ValueError('Blank retry record')
        if f[0]=='END':
            if footer is not None:raise ValueError('Duplicate retry footer')
            footer=list(map(int,f[1:]));continue
        if footer is not None or f[0] not in tags:raise ValueError('Unknown/trailing retry record')
        i=int(f[1])
        if i<previous or i>=len(rows):raise ValueError('Retry case order')
        previous=i;by.setdefault(i,[]).append(f)
    totals=[len(rows),0,0,0,0,0,0,0,0,0,0];oldp=None;needkey=True
    sentinel=tuple(reference.sample(2,0,hashlib.shake_256(b'').digest(4096))[0])
    for c in rows:
        i,p=c['i'],c['p'];k,l=((4,4),(6,5),(8,7))[p];nkeys=l+2*k;m0=sign_matrix_material(p,0)
        chain,natural_code,final_nonce=sign_retry_chain(p,c['nonce']);events=by.get(i,[])
        def ev(t):return [f for f in events if f[0]==t]
        def packed(a):return sum(r<<(6*j) for j,r in enumerate(a))
        kh=[31,*range(nkeys-1)];ymap=list(range(32,32+l));keymap=sum(1<<r for r in kh);protected=keymap|(1<<50);ymask=sum(1<<r for r in ymap)
        free=[r for r in range(64) if not(protected|ymask)>>r&1];hats=free[:l];lo=free[2*l:2*l+k];hi=free[2*l+k:2*l+2*k]
        acc,scratch=free[2*l+2*k:2*l+2*k+2]
        matmap=sum(1<<r for r in hats+lo+hi);cr=next(r for r in range(64) if not(protected|ymask|matmap)>>r&1)
        vecmap=sum(1<<r for r in lo+hi+[hats[0]]);pfree=[r for r in range(64) if not(protected|ymask|vecmap)>>r&1];ct0=pfree[:k];pwm,inv=pfree[k:k+2]
        rawmap=ymask|sum(1<<r for r in lo+hi+ct0);spare=next(r for r in range(64) if not(protected|rawmap)>>r&1)
        hints=[spare,*lo[:k-1]];acceptedmap=ymask|sum(1<<r for r in hints)
        if oldp!=p:needkey=True
        if ev('K')!=([['K',str(i),str(p),f'{keymap:016x}',m0['sk'][:32][::-1].hex()]] if needkey else []):raise ValueError('Retry actual key publication')
        if ev('C')!=[['C',str(i),*[str(c[x]) for x in ('p','id','nonce','inject','abort')]]]:raise ValueError('Retry command record')
        totals[10]+=int(needkey);needkey=bool(c['abort']);oldp=p
        ledger={r:dict(complete=True,id=100+p if r!=50 else 60000) for r in range(64) if protected>>r&1}
        def mask():return sum(1<<r for r in ledger)
        attempt=0;current=None;nextstage=0;nextbase=c['nonce'];await_retry=False;failed=False;ended=False;published=False;taken=False
        raw=None;job=None;rawcount={};jobcount={};maskdone=set();model=None;reject_count=0;readorder=[];row_col=-1
        for f in events:
            tag=f[0]
            if tag=='S':
                a,nonce,stage=map(int,f[2:])
                if current is not None or failed or await_retry or nextstage>5 or stage!=nextstage or nonce!=nextbase or nonce+l>65536:raise ValueError('Retry child schedule/nonce wrap')
                if stage==0:
                    attempt+=1;model=sign_accept_material(p,nonce);totals[4]+=1
                elif stage==1 and attempt not in maskdone:raise ValueError('Retry matrix before complete mask publication')
                if a!=attempt:raise ValueError('Retry attempt counter')
                current=stage
            elif tag=='D':
                a,nonce,stage,code,detail,jid,valid=map(int,f[2:9]);regions=int(f[9],16);rj,reason,weight=map(int,f[10:])
                if current!=stage or a!=attempt or nonce!=nextbase or raw is not None or job is not None:raise ValueError('Retry premature child publication')
                error=(c['inject']==1 and attempt==1 and stage==0 or c['inject']==2 and attempt==2 and stage==0 or c['inject']==3 and attempt==2 and stage==1 or c['inject']==4 and attempt==2 and stage==5)
                ecode={1:4,2:5,3:3,4:5}.get(c['inject'],0) if error else 0
                expectedmap=0 if ecode else (ymask,matmap,1<<cr,vecmap,rawmap,0 if model['reason'] else acceptedmap)[stage]
                want=[int(error==False),int(stage==5 and not error and bool(model['reason'])),model['reason'] if stage==5 and not error else 0,model['weight'] if stage==5 and not error else 0]
                if (code,detail,jid,valid,rj,reason,weight)!=(ecode,int(error and c['inject']==3),c['id'],*want) or regions!=expectedmap:raise ValueError('Retry child error/verdict/metadata')
                if regions & ~mask() or any(not ledger[r]['complete'] for r in ledger if regions>>r&1):raise ValueError('Retry incomplete child result')
                globalmap=protected|expectedmap|(ymask if stage in (1,2,3) else 0)|(matmap if stage==2 else 0)
                if mask()!=globalmap:raise ValueError('Retry child workspace leak/early release')
                if stage==0 and not error:
                    if rawcount.get(attempt,0)!=(2 if attempt==1 else 0) or jobcount.get(attempt,0)!=l:raise ValueError('Retry seed rehash or incomplete mask vector')
                failed=bool(error);current=None
                if stage==5 and not error:
                    if rj:await_retry=True;reject_count+=1;totals[5]+=1
                    else:nextstage=6
                else:nextstage=stage+1
            elif tag=='M':
                a,nonce=int(f[2]),int(f[3]);want=['M',str(i),str(attempt),str(nextbase),f'{ymask:016x}',f'{packed(ymap):011x}',m0['mu'][::-1].hex(),m0['seed'][::-1].hex()]
                if a in maskdone or current is not None or nextstage!=1 or f!=want:raise ValueError('Retry changed private seed/mu or mask handles')
                maskdone.add(a)
            elif tag=='L':
                want=['L',str(i),str(attempt),str(nextbase),str(nextbase+l),f'{protected:016x}',m0['mu'][::-1].hex(),m0['seed'][::-1].hex()]
                if not await_retry or current is not None or f!=want or mask()!=protected:raise ValueError('Retry atomic header transfer/payload discard')
                await_retry=False;nextstage=0;nextbase+=l
            elif tag=='O':
                a,nonce,stage,core,jid,length,outlen,mode=map(int,f[2:])
                if raw is not None or current!=stage or a!=attempt or nonce!=nextbase or core not in (0,1) or jid!=c['id'] or mode!=1:raise ValueError('Retry raw request ownership')
                if stage==0:
                    if attempt!=1 or rawcount.get(attempt,0)>=2:raise ValueError('Retry replayed initial hash')
                    if rawcount.get(attempt,0)==0:
                        body=m0['body'] if c['inject']!=1 else m0['body'][:16]+bytes(160)
                        message=m0['sk'][64:128]+b'\0\7'+body
                    else:message=m0['sk'][32:64]+m0['rnd']+m0['mu']
                    out=64;rawcount[attempt]=rawcount.get(attempt,0)+1
                elif stage==2:message=m0['mu']+model['packed'];out=len(model['digest'])
                else:raise ValueError('Retry unexpected raw client')
                if (length,outlen)!=(len(message),out):raise ValueError('Retry hash descriptor length')
                raw=dict(message=message,digest=hashlib.shake_256(message).digest(out),core=core,words=0,bytes=0);totals[6]+=1
            elif tag=='I':
                if raw is None:raise ValueError('Retry orphan hash input')
                w=int(f[2]);data=int(f[3],16);m=raw['message'];offset=8*w
                if w!=raw['words'] or offset>=len(m) or data!=int.from_bytes(m[offset:offset+8].ljust(8,b'\0'),'little'):raise ValueError('Retry hash absorption bytes')
                raw['words']+=1
            elif tag=='H':
                if raw is None:raise ValueError('Retry orphan digest')
                core,jid,n=map(int,f[2:5]);data=int(f[5],16);offset=raw['bytes']
                if (core,jid,n)!=(raw['core'],c['id'],16) or offset+16>len(raw['digest']) or data!=int.from_bytes(raw['digest'][offset:offset+16],'little'):raise ValueError('Retry exact SHAKE output')
                raw['bytes']+=n
            elif tag=='Q':
                if raw is None or list(map(int,f[2:]))!=[raw['core'],c['id']] or raw['bytes']!=len(raw['digest']) or raw['words']!=(len(raw['message'])+7)//8:raise ValueError('Retry hash retired before complete input/output')
                raw=None
            elif tag=='J':
                a,nonce,j,core,jid,region,mode,length,param=map(int,f[2:])
                if current!=0 or job is not None or raw is not None or a!=attempt or nonce!=nextbase or j!=jobcount.get(attempt,0) or not 0<=j<l or core not in (0,1) or (jid,region,mode,length,param)!=(c['id'],ymap[j],2,66,p):raise ValueError('Retry mask job descriptor/nonce order')
                job=dict(j=j,core=core,region=region,words=0,values=0,message=m0['seed']+(nonce+j).to_bytes(2,'little'))
                totals[7]+=1
            elif tag=='W':
                if job is None:raise ValueError('Retry orphan sampler input')
                w=int(f[2]);data=int(f[3],16)
                if w!=job['words'] or not 0<=w<9 or data!=int.from_bytes(job['message'][w*8:w*8+8].ljust(8,b'\0'),'little'):raise ValueError('Retry ExpandMask seed/nonce bytes')
                job['words']+=1
            elif tag=='X':
                a,nonce,j,region,index=map(int,f[2:7]);value=int(f[7],16)
                if job is None or (a,nonce,j,region)!=(attempt,nextbase,job['j'],job['region']) or index!=job['values'] or not 0<=index<256 or value!=model['y'][j][index]:raise ValueError('Retry exact fresh mask coefficient')
                job['values']+=1;totals[8]+=1
            elif tag=='T':
                if job is None or job['words']!=9 or job['values']!=256 or list(map(int,f[2:]))!=[job['core'],c['id']^int(c['inject']==2 and attempt==2 and job['j']==1),0]:raise ValueError('Retry mask status/commit')
                jobcount[attempt]=jobcount.get(attempt,0)+1;job=None
            elif tag=='A':
                region,rewrite,jid,mode,param,domain=map(int,f[2:8]);before=int(f[8],16)
                expected_id=c['id']
                # Existing row MAC uses explicit temporary tags,modulo16 bits.
                if current==1 and region==acc:
                    if rewrite:
                        if not 0<=row_col<l-1 or scratch not in ledger or not ledger[scratch]['complete']:raise ValueError('Retry row ADD before PWM commit')
                        row_col+=1;expected_id=(c['id']+3+2*row_col)&65535
                    else:row_col=0;expected_id=(c['id']+1)&65535
                elif current==1 and region==scratch:
                    if not 0<=row_col<l-1:raise ValueError('Retry row temporary column')
                    expected_id=(c['id']+2+2*(row_col+1))&65535
                if current==0:role=(2,0) if region in ymap else None
                elif current==1:
                    role=(2,1) if region in hats else (0,1) if region in free[l:2*l]+[acc,scratch] else (0,0) if region in lo+hi+[free[2*l+2*k+2]] else None
                elif current==2:role=(3,0) if region==cr else None
                elif current==3:role=(3,1) if region==hats[0] else None
                elif current==4:role=(3,1) if region==pwm else (3,0) if region in ct0+[inv] else (2,0) if region in ymap else (0,0) if region in lo else None
                elif current==5:role=(0,0) if region in lo+hints else None
                else:role=None
                if (mode,domain)!=role:raise ValueError('Retry allocation role/domain')
                if not 0<=region<64 or protected>>region&1 or before!=mask() or jid!=expected_id or param!=p or not 0<=mode<=3 or domain not in (0,1) or bool(rewrite)!=(region in ledger) or rewrite and not ledger[region]['complete']:raise ValueError(f'Retry physical allocation/rewrite ownership:case{i},record{f},ledger{mask():016x}')
                ledger[region]=dict(complete=False,id=jid,mode=mode,param=param,domain=domain)
            elif tag=='COM':
                region,jid,code,count=map(int,f[2:])
                if region not in ledger or protected>>region&1 or ledger[region]['complete'] or jid!=ledger[region]['id'] or count>256 or code==0 and count!=256:raise ValueError('Retry physical commit/discard')
                if code:del ledger[region]
                else:ledger[region]['complete']=True
            elif tag=='F':
                region=int(f[2]);before=int(f[3],16)
                if region not in ledger or protected>>region&1 or before!=mask() or not ledger[region]['complete']:raise ValueError('Retry foreign/early/duplicate release')
                del ledger[region]
            elif tag=='R':
                want=['R',str(i),f'{acceptedmap:016x}',f'{packed(ymap):011x}',f'{packed(hints):012x}',str(len(model['digest'])),f'{int.from_bytes(model["digest"],"little"):0128x}']
                if published or failed or current is not None or nextstage!=6 or mask()!=protected|acceptedmap or f!=want:raise ValueError('Retry whole accepted candidate publication')
                published=True
            elif tag=='E':
                if c['inject']:
                    na=1 if c['inject']==1 else 2;nr=na-1;nn=c['nonce']+nr*l
                else:na=len(chain);nr=sum(bool(a['reason']) for _,a in chain);nn=final_nonce
                if ended or c['abort'] or current is not None or raw is not None or job is not None or list(map(int,f[2:]))!=[c['id'],c['code'],c['stage'],c['detail'],na,nr,nn] or attempt!=na or reject_count!=nr or bool(published)!=(c['code']==0) or c['code'] and mask()!=protected:raise ValueError('Retry final success/error/exhaustion counters')
                ended=True
            elif tag=='TAKE':
                if taken or not ended or c['code'] or not i%2 or f!=['TAKE',str(i),f'{acceptedmap:016x}']:raise ValueError('Retry accepted context take')
                taken=True
            elif tag=='V':
                typ,j,region,word,jid,mode,param,domain=map(int,f[2:10]);data=int(f[10],16)
                if not ended:raise ValueError('Retry early consumer')
                if typ in (0,1):
                    if c['code']:raise ValueError('Retry error credited accepted payload')
                    poly=model['z' if typ==0 else 'hints'][j];meta=((ymap if typ==0 else hints)[j],c['id'],2 if typ==0 else 0,p,0)
                elif typ==4:poly=sign_prepare_math(m0['sk'],p)[1][j];meta=(kh[j],100+p,1 if j<l+k else 3,p,1)
                elif typ==5:poly=sentinel;meta=(50,60000,2,0,0)
                else:raise ValueError('Retry unknown read kind')
                if not 0<=word<64 or (region,jid,mode,param,domain)!=meta or data!=sum(poly[4*word+b]<<(23*b) for b in range(4)):raise ValueError('Retry exact candidate/key/sentinel read')
                readorder.append((typ,j,word));totals[9]+=1
            elif tag=='BARRIER':
                if not ended or c['code'] or int(f[2],16)!=sum(model['z'][0][b]<<(23*b) for b in range(4)):raise ValueError('Retry pending-read barrier')
        bad={3:['BAD',str(i),str(ymap[0]),str(c['id']^1),str(c['id'])],4:['BAD',str(i),str(c['id']),str(c['id']^1),'0']}
        if ev('BAD')!=([bad[c['inject']]] if c['inject'] in (3,4) else []):raise ValueError('Retry missing/false hardware error injection')
        if c['abort']:
            phase=c['abort'];a=len(chain) if phase==4 else 2;nr=a-1
            if ev('Z')!=[['Z',str(i),str(phase),str(9 if phase==5 else 5 if phase==4 else 2),str(4 if phase==2 else 5 if phase in (3,4) else 0),str(a),str(nr)]] or ev('E') or ev('R') or ev('B') or ev('V') or attempt!=a or reject_count!=nr:raise ValueError('Retry reset/fatal point or false completion credit')
            if phase in (1,5) and (job is None or not 32<=job['values']<=36):raise ValueError('Retry reset mask prefix')
            if phase==4 and (current is not None or nextstage!=6 or mask()!=protected|acceptedmap):raise ValueError('Retry held-result reset')
            if raw is not None:raise ValueError('Retry unexpected interrupted hash')
            totals[3]+=1
        else:
            expected=[]
            if not c['code']:expected=[(typ,j,w) for typ,length in ((0,l),(1,k)) for j in range(length) for w in range(64)]
            expected += [(4,j,w) for j in range(nkeys) for w in range(64)]+[(5,0,w) for w in range(64)]
            if not ended or ev('Z') or mask()!=protected or readorder!=expected or ev('B')!=[['B',str(i),f'{protected:016x}']] or len(ev('BARRIER'))!=int(c['code']==0) or bool(ev('TAKE'))!=bool(i%2 and c['code']==0):raise ValueError('Retry final memory/read/retention ledger')
            totals[1]+=1;totals[2]+=int(c['code']!=0)
    if footer!=totals:raise ValueError(f'Retry totals mismatch:{footer}!={totals}')
    return f'STAGE5N4H4_SIGN_RETRY_COMPARE_PASS:{totals[0]} commands,{totals[1]-totals[2]} accepted,{totals[2]} expected errors/exhaustions,{totals[3]} aborts,{totals[4]} attempts,{totals[5]} genuine rejections,{totals[6]} raw hashes,{totals[7]} mask jobs,{totals[8]} exact mask coefficients,{totals[9]} packed reads,{totals[10]} key preparations\n'


@lru_cache(maxsize=1)
def nist_verify_corpus(include_internal=False):
    objects={}
    for name in NIST_VERIFY_HASHES:
        obj=json.loads((NIST_VERIFY/name).read_text(encoding='utf-8-sig'))
        if (obj['algorithm'],obj['mode'],obj['revision'],obj['vsId'])!=('ML-DSA','sigVer','FIPS204',42):
            raise ValueError('NIST Verify metadata')
        objects[name]=obj
    expected={}
    for g in objects['expectedResults.json']['testGroups']:
        for t in g['tests']:
            key=(g['tgId'],t['tcId'])
            if key in expected or type(t['testPassed']) is not bool:raise ValueError('NIST Verify duplicate/verdict')
            expected[key]=t['testPassed']
    seen=set();rows=[];counts=[0]*3;reasons={};audit=['tgId,tcId,parameterSet,selection,official_testPassed']
    for g in objects['prompt.json']['testGroups']:
        if g['testType']!='AFT' or len(g['tests'])!=15:raise ValueError('NIST Verify group')
        p=('ML-DSA-44','ML-DSA-65','ML-DSA-87').index(g['parameterSet'])
        reason=('selected' if g.get('preHash')=='pure' else 'unsupported_prehash') if g['signatureInterface']=='external' else (
            'unsupported_external_mu' if g.get('externalMu') is True else 'unsupported_internal_message_API')
        if include_internal and g['signatureInterface']=='internal' and g.get('externalMu') is False:reason='selected'
        for t in g['tests']:
            key=(g['tgId'],t['tcId'])
            if key in seen or (reason=='selected' and key not in expected):raise ValueError('NIST Verify input/verdict identity')
            seen.add(key);reasons[reason]=reasons.get(reason,0)+1;audit.append(','.join(map(str,[*key,g['parameterSet'],reason,int(expected[key]) if key in expected else ''])))
            if reason!='selected':continue
            pk=bytes.fromhex(t['pk']);sig=bytes.fromhex(t['signature']);ctx=bytes.fromhex(t.get('context',''));msg=bytes.fromhex(t['message'])
            if len(pk)!=(1312,1952,2592)[p] or len(sig)!=(2420,3309,4627)[p] or len(ctx)>255 or (64 if g['signatureInterface']=='internal' else 66)+len(ctx)+len(msg)>65535:raise ValueError('NIST Verify lengths')
            rows.append(dict(p=p,pk=pk,sig=sig,ctx=ctx,msg=msg,tg=key[0],tc=key[1],valid=expected[key],internal=g['signatureInterface']=='internal'));counts[p]+=1
    if not set(expected).issubset(seen) or counts!=[30 if include_internal else 15]*3:
        raise ValueError('NIST Verify audit coverage')
    return rows,'\n'.join(audit)+'\n'


def verify_unpack_math(kind,p,data):
    """Whole-frame integer slicing + literal sparse-index canonical rules."""
    k,l=((4,4),(6,5),(8,7))[p];width=10 if kind==0 else 18 if p==0 else 20
    header=data[:32 if kind==0 else (32,48,64)[p]]
    count=256*(k if kind==0 else l);packed=int.from_bytes(data[len(header):len(header)+count*width//8],'little')
    raw=[(packed>>(j*width))&((1<<width)-1) for j in range(count)]
    if kind==0:return header,[v<<13 for v in raw],[],False
    gamma=(131072,524288,524288)[p];bound=gamma-(78,196,120)[p]
    z=[(gamma-v)%8380417 for v in raw];bad_norm=any(min(v,8380417-v)>=bound for v in z)
    omega=(80,55,75)[p];suffix=data[-omega-k:];h=[];pos=0
    for poly in range(k):
        end=suffix[omega+poly]
        if not pos<=end<=omega or any(suffix[j]<=suffix[j-1] for j in range(pos+1,end)):return header,z,None,bad_norm
        indices=set(suffix[pos:end]);h.extend(int(j in indices) for j in range(256));pos=end
    if any(suffix[pos:omega]):return header,z,None,bad_norm
    return header,z,h,bad_norm


def make_verify_signature(p,mode=3,z_override=None):
    k,l=((4,4),(6,5),(8,7))[p];gamma=(131072,524288,524288)[p];bound=gamma-(78,196,120)[p];width=18 if p==0 else 20;omega=(80,55,75)[p]
    z=[(0,bound-1,1-bound,1,-1)[j%5] for j in range(l*256)]
    if z_override is not None:z[z_override[0]]=z_override[1]
    encoded=sum((gamma-v)<<(width*j) for j,v in enumerate(z)).to_bytes(32*width*l,'little')
    hints=[[] for _ in range(k)]
    if mode==1:hints[0]=[0];hints[-1]=[255]
    if mode==2:hints[-1]=list(range(omega))
    if mode==3:hints=[[0,128,255] for _ in range(k)]
    suffix=bytearray(omega+k);pos=0
    for j,h in enumerate(hints):suffix[pos:pos+len(h)]=bytes(h);pos+=len(h);suffix[omega+j]=pos
    return hashlib.shake_256(f'verify-ctilde-{p}-{mode}'.encode()).digest((32,48,64)[p])+encoded+suffix


@lru_cache(maxsize=1)
def verify_decode_cases():
    rows=[]
    def add(kind,p,data,declared=None,fw=-1,fault=0,abort=0,origin='directed',tc=0):
        i=len(rows);rows.append(dict(i=i,kind=kind,p=p,id=65535 if i==0 else 0 if i==1 else 50000+i,data=data,
            declared=len(data) if declared is None else declared,fw=fw,fault=fault,abort=abort,origin=origin,tc=tc))
    for c in nist_verify_corpus()[0]:
        add(0,c['p'],c['pk'],origin='NIST_Verify',tc=c['tc']);add(1,c['p'],c['sig'],origin='NIST_Verify',tc=c['tc'])
    for c in nist_sign_cases():add(1,c['p'],c['signature'],origin='NIST_Sign',tc=c['tc'])
    for c in nist_keygen_cases():add(0,c['p'],c['pk'],origin='NIST_KeyGen',tc=c['tc'])
    for p in range(3):
        pk=next(c['pk'] for c in nist_keygen_cases() if c['p']==p);sig=make_verify_signature(p);omega=(80,55,75)[p];k,l=((4,4),(6,5),(8,7))[p];ct=(32,48,64)[p]
        for payload in (bytes(len(pk)),bytes([255])*len(pk),bytes((j*17+3)&255 for j in range(len(pk)))):add(0,p,payload)
        for mode in range(4):add(1,p,make_verify_signature(p,mode))
        bound=(131072,524288,524288)[p]-(78,196,120)[p]
        for index,z in [(0,bound),(17,-bound),(l*256-1,(131072,524288,524288)[p]),(l*256-1,1-(131072,524288,524288)[p])]:add(1,p,make_verify_signature(p,z_override=(index,z)))
        for fault in range(5):
            data=bytearray(sig);start=len(data)-omega-k
            if fault==0:data[start+omega]=omega+1
            if fault==1:data[start+omega+1]=0
            if fault==2:data[start+1]=data[start]
            if fault==3:data[start+1]=0;data[start]=128
            if fault==4:data[start+3*k]=1
            add(1,p,bytes(data))
        for kind,data in ((0,pk),(1,sig)):
            for delta in (-1,1):add(kind,p,data,declared=len(data)+delta)
            for fault,fw in ((1,0),(2,(32 if kind==0 else ct)//8+1),(3,0),(3,(len(data)-1)//8),(4,0),(5,(len(data)-1)//8)):
                add(kind,p,data,fault=fault,fw=fw)
            add(kind,p,data[:-1],declared=len(data));add(kind,p,data+b'\xa5',declared=len(data))
    for kind in (0,1):add(kind,3,rows[kind]['data'])
    for phase in range(1,8):
        p=(phase-1)%3;data=make_verify_signature(p);add(1,p,data,abort=phase);add(1,p,data)
    for phase in (2,6):
        p=1;pk=next(c['pk'] for c in nist_keygen_cases() if c['p']==p);add(0,p,pk,abort=phase);add(0,p,pk)
    return rows


def verify_decode_words(c):
    data=c['data'];out=[]
    for w in range((len(data)+7)//8):
        part=data[8*w:8*w+8];size=len(part);index=w;last=int(8*(w+1)>=len(data))
        if w==c['fw']:
            if c['fault']==1:index^=1024
            if c['fault']==2:size=0
            if c['fault']==3:last^=1
            if c['fault']==4:size=9
            if c['fault']==5:size-=1
        out.append(['I',str(c['i']),str(index),str(size),str(last),f"{int.from_bytes(part+bytes([255])*(8-len(part)),'little'):016x}"])
    return out


def verify_decode_gold(c):
    kind,p=c['kind'],c['p'];words=verify_decode_words(c)
    expected=(1312,1952,2592)[p] if kind==0 and p<3 else (2420,3309,4627)[p] if p<3 else 0
    if p==3 or c['declared']!=expected:return 1,b'',[],0
    hw=(32 if kind==0 else (32,48,64)[p])//8;data=c['data'][:expected].ljust(expected,b'\0')
    header,z,h,norm=verify_unpack_math(kind,p,data);width=10 if kind==0 else 18 if p==0 else 20
    def poly_rows(values,section):
        return [(section,j//256,j%256,v,int(j%256==255),int(j==len(values)-1 and (kind==0 or section==2))) for j,v in enumerate(values)]
    out=poly_rows(z,kind);code=0;consumed=len(words)
    bad_word=next((j for j,f in enumerate(words) if int(f[2])!=j or int(f[3])!=min(8,expected-8*j) or int(f[4])!=int(8*j+min(8,expected-8*j)==expected)),None)
    norm_index=next((j for j,v in enumerate(z) if kind and min(v,8380417-v)>=(131072,524288,524288)[p]-(78,196,120)[p]),None)
    norm_words=hw+((norm_index+1)*width+63)//64 if norm_index is not None else None
    if bad_word is not None and (norm_words is None or bad_word<norm_words):
        code=3;consumed=bad_word+1;out=out[:max(0,(bad_word-hw)*64//width)];header=header if bad_word>=hw else b''
    elif norm_index is not None:code=2;consumed=norm_words;out=out[:norm_index]
    elif kind and h is None:code=2
    elif kind:out+=poly_rows(h,2)
    return code,header,out,consumed


def verify_decode_artifact(token):
    rows=verify_decode_cases()
    return f'{token} {len(rows)}\n'+''.join(' '.join(map(str,[c['i'],c['kind'],c['p'],c['id'],c['declared'],len(c['data']),c['fw'],c['fault'],c['abort'],verify_decode_gold(c)[0]]))+' '+c['data'].hex()+'\n' for c in rows)


def verify_verify_decode(lines):
    _,token=check();cases=verify_decode_cases()
    if not lines or lines[0]!='V '+token:raise ValueError('Verify decoder stale capture')
    position=1;totals=[0]*6;stalls=[0]*3;origins={};sig_success=sig_invalid=0
    shapes={'C':6,'I':6,'H':5,'P':9,'D':4,'Z':4,'T':5}
    for c in cases:
        i=c['i'];events=[]
        while position<len(lines) and not lines[position].startswith('END '):
            f=lines[position].split()
            if not f or f[0] not in shapes or len(f)!=shapes[f[0]]:raise ValueError('Verify decoder event shape')
            case=int(f[1])
            if case>i:break
            if case!=i:raise ValueError('Verify decoder event order')
            events.append(f);position+=1
        def ev(tag):return [f for f in events if f[0]==tag]
        def require(ok,why):
            if not ok:raise ValueError(f'Verify decoder case{i}: '+why)
        require(ev('C')==[['C',str(i),str(c['kind']),str(c['p']),str(c['id']),str(c['declared'])]] and events[0][0]=='C','Command snapshot')
        code,header,gold,nwords=verify_decode_gold(c);words=verify_decode_words(c);actual=ev('I')
        require(actual==words[:len(actual)] and len(actual)<=len(words),'Original accepted frame bytes/index/last')
        hs=ev('H');ps=ev('P');prefix=[]
        for section,poly,index,value,last_poly,last_frame in gold[:len(ps)]:
            prefix.append(['P',str(i),str(c['id']),str(section),str(poly),str(index),f'{value:06x}',str(last_poly),str(last_frame)])
        require(len(ps)<=len(gold) and ps==prefix,'Independent exact decoded coefficient prefix')
        header_row=['H',str(i),str(c['id']),str(len(header)),f'{int.from_bytes(header,"little"):0128x}'] if header else None
        if c['abort']:
            phase=c['abort'];expected_state={1:1,2:2,3:3,4:4,5:8,6:8 if c['kind'] else 3,7:9}[phase]
            require(ev('Z')==[['Z',str(i),str(phase),str(expected_state)]] and not ev('D') and not ev('T') and events[-1][0]=='Z','Reset boundary')
            require(hs==([] if phase in (1,2) else [header_row]),'Reset header ownership')
            hw=(32 if not c['kind'] else (32,48,64)[c['p']])//8
            zcount=(4,5,7)[c['p']]*256
            if phase==1:require(len(actual)==2 and not ps,'Header input prefix reset')
            if phase==2:require(len(actual)==hw and not ps,'Held header reset')
            if phase==3:require(not ps and len(actual)>hw,'Held first coefficient reset')
            if phase==4:require(len(ps)==zcount and hw+(zcount*(18 if c['p']==0 else 20))//64<len(actual)<len(words),'Hint suffix input reset')
            if phase==5:require(len(ps)==zcount and actual==words,'Held first dense hint reset')
            if phase==6:require(len(ps)==len(gold)-1 and actual==words,'Held final coefficient reset')
            if phase==7:require(len(ps)==len(gold) and actual==words,'Held completion reset')
            totals[3]+=1
        else:
            require(ev('D')==[['D',str(i),str(c['id']),str(code)]] and not ev('Z') and [f[0] for f in events[-2:]]==['D','T'],'Completion code/order')
            require(len(ps)==len(gold) and len(actual)==nwords and hs==([header_row] if header else []),'Complete decoded data and consumed input')
            ts=ev('T');require(len(ts)==1 and all(int(x)>=0 for x in ts[0][2:]),'Stall witness')
            for j,x in enumerate(ts[0][2:]):stalls[j]+=int(x)
            totals[1]+=1;totals[2]+=int(code!=0)
            if c['kind']:sig_success+=code==0;sig_invalid+=code==2
        totals[0]+=1;totals[4]+=len(actual);totals[5]+=len(ps);origins[c['origin']]=origins.get(c['origin'],0)+1
    if position!=len(lines)-1 or lines[position]!='END '+' '.join(map(str,totals)) or not all(stalls):raise ValueError('Verify decoder totals/trailing data/stalls')
    return f'STAGE5V1_VERIFY_DECODE_COMPARE_PASS:{totals[0]} commands/{totals[1]} completions/{totals[2]} expected errors/{totals[3]} resets;{totals[4]} exact input words/{totals[5]} exact decoded values;{sig_success} structurally accepted signatures/{sig_invalid} norm-or-hint rejects;origins{origins};stall clocks{stalls};NOT main RTL Verify\n'


VERIFY_SENTINEL_SEED=hashlib.shake_256(b'Verify isolated foreign-region owner').digest(66)


@lru_cache(maxsize=1)
def verify_prepare_cases():
    rows=[];official=nist_verify_corpus()[0]
    def add(p,pk,sig,scenario=0,abort=0,base=None,origin='directed',tc=0):
        i=len(rows);k,l=((4,4),(6,5),(8,7))[min(p,2)];total=2*k+l
        base=(i*7)%(65-total) if base is None else base
        sentinel=63 if not base<=63<base+total else 0
        if scenario==3:base=65-total
        if scenario==4:sentinel=base
        declared=(2420,3309,4627)[min(p,2)]-(scenario==2)
        if scenario==1:p=3
        if scenario==14:sig=make_verify_signature(p,z_override=(17,(131072,524288,524288)[p]-(78,196,120)[p]))
        if scenario==15:
            sig=bytearray(make_verify_signature(p));sig[-(80,55,75)[p]-k+1]=sig[-(80,55,75)[p]-k];sig=bytes(sig)
        if scenario==16:pk=pk[:-1]
        if scenario==17:sig=sig[:-1]
        if scenario==18:sig=sig+b'\xa5'
        c=dict(i=i,p=p,id=65535 if i==0 else 0 if i==1 else 51000+i,base=base,scenario=scenario,abort=abort,
               adopt=i%2,declared=declared,sentinel=sentinel,pk=pk,sig=sig,origin=origin,tc=tc)
        if scenario in (1,2):code,detail=1,0
        elif scenario==3:code,detail=3,0
        elif scenario==4:code,detail=3,4
        elif scenario==5:code,detail=2,0
        elif scenario in (19,20,21):code,detail=6,0
        else:
            pkcode=verify_decode_gold(verify_prepare_frame(c,0))[0]
            sigcode=verify_decode_gold(verify_prepare_frame(c,1))[0]
            code,detail=(4,pkcode) if pkcode else (5,sigcode) if sigcode else (0,0)
        c.update(code=code,detail=detail);rows.append(c)
    for c in official:add(c['p'],c['pk'],c['sig'],origin='NIST_Verify',tc=c['tc'])
    for p in range(3):
        c=next(c for c in official if c['p']==p and c['valid']);pk,sig=c['pk'],c['sig'];k,l=((4,4),(6,5),(8,7))[p]
        add(p,pk,sig,base=64-2*k-l)
        for scenario in range(1,22):add(p,pk,sig,scenario=scenario)
    for phase in range(1,12):
        c=next(c for c in official if c['p']==(phase-1)%3 and c['valid'])
        add(c['p'],c['pk'],c['sig'],abort=phase);add(c['p'],c['pk'],c['sig'])
    return rows


def verify_prepare_frame(c,kind):
    p=min(c['p'],2);s=c['scenario'];fault=0;fw=-1
    if not kind and s in (6,7,8,9):fault={6:1,7:2,8:3,9:3}[s];fw={6:0,7:5,8:0,9:(len(c['pk'])-1)//8}[s]
    if kind and s in (10,11,12,13):fault={10:1,11:2,12:3,13:3}[s];fw={10:0,11:(5,7,9)[p],12:0,13:(len(c['sig'])-1)//8}[s]
    return dict(i=c['i'],kind=kind,p=p,id=c['id'],data=c['sig'] if kind else c['pk'],
                declared=(2420,3309,4627)[p] if kind else (1312,1952,2592)[p],fw=fw,fault=fault)


def verify_prepare_artifact(token):
    return f'{token} {len(verify_prepare_cases())} {VERIFY_SENTINEL_SEED.hex()}\n'+''.join(
        ' '.join(map(str,[c[n] for n in ('i','p','id','base','scenario','abort','adopt','declared','sentinel','code','detail')]))+
        ' '+c['pk'].hex()+' '+c['sig'].hex()+'\n' for c in verify_prepare_cases())


def verify_verify_prepare(lines,token=None):
    if token is None:_,token=check()
    if not lines or lines[0]!='V '+token:raise ValueError('Verify preparation stale capture')
    cases=verify_prepare_cases();position=1;totals=[0]*11;errors=successes=coeffs=0
    sentinel_poly=reference.sample(2,0,hashlib.shake_256(VERIFY_SENTINEL_SEED).digest(4096))[0]
    shapes={'C':6,'I':7,'Q':7,'B':4,'O':6,'G':4,'L':8,'A':8,'W':7,'M':6,'F':3,'R':11,
            'HOLD':4,'D':8,'Y':8,'K':5,'TAKE':3,'CLEAR':3,'EXTERNAL_RELEASE':3,'ENDCASE':3,'Z':8}
    for c in cases:
        i=c['i'];p=min(c['p'],2);k,l=((4,4),(6,5),(8,7))[p];base=c['base'];total=2*k+l
        plan=sum(1<<r for r in range(base,min(64,base+total)));sentinel=c['sentinel'];smask=1<<sentinel;events=[]
        while position<len(lines) and not lines[position].startswith('END '):
            f=lines[position].split()
            if not f or f[0] not in shapes or len(f)!=shapes[f[0]]:raise ValueError(f'Verify preparation event shape at{position}: {f[:3]}')
            if int(f[1])>i:break
            if int(f[1])!=i:raise ValueError('Verify preparation event order')
            events.append(f);position+=1
        def ev(tag):return [f for f in events if f[0]==tag]
        def require(ok,why):
            if not ok:raise ValueError(f'Verify preparation case{i}: '+why)
        require(events and events[0][0]=='C' and ev('C')==[['C',str(i),str(c['p']),str(c['id']),str(base),str(c['declared'])]],'command snapshot')
        golds=[verify_decode_gold(verify_prepare_frame(c,kind)) for kind in (0,1)]
        frame_words=[]
        for kind in (0,1):frame_words.append([f[:2]+[str(kind)]+f[2:] for f in verify_decode_words(verify_prepare_frame(c,kind))])
        ins=ev('I');frames=[[f for f in ins if int(f[2])==kind] for kind in (0,1)]
        require(ins==frames[0]+frames[1],'ordered input frames')
        for kind in (0,1):require(frames[kind]==frame_words[kind][:len(frames[kind])],'original accepted input/index/bytes/last')
        preflight=c['scenario'] in range(1,6)
        if preflight:require(not ins,'preflight consumed data')
        if not c['abort'] and not preflight:
            require(len(frames[0])==golds[0][3],'PK consumed length')
            sig_started=not golds[0][0] and c['scenario']!=20
            require(len(frames[1])==(golds[1][3] if sig_started else 0),'signature consumed length')
        # Independent canonical coefficient streams,then physical allocation ledger.
        expected_values={};expected_modes={}
        for kind in (0,1):
            for section,poly,index,value,lp,lf in golds[kind][2]:
                region=base+poly+(0 if section==0 else k if section==1 else k+l)
                expected_values.setdefault(region,[]).append(value);expected_modes[region]=2 if section==1 else 3
        ledger={sentinel:dict(id=62000,mode=2,param=0,values=sentinel_poly.copy(),complete=True)}
        allocated=[];write_counts={};released=[];raw=[];outs=[];q=None;load_kinds=[];authorized=False;foreign_release=False
        read_rows=[];seen_d=False;seen_context=False
        for f in events:
            tag=f[0]
            if tag=='A':
                r,rewrite,jid,mode,param=map(int,f[2:7]);mask=sum(1<<r for r in ledger)
                require(not rewrite and r not in ledger and base<=r<base+total and r==base+len(allocated) and jid==c['id'] and param==p and
                        mode==(2 if k<=r-base<k+l else 3) and int(f[7],16)==mask,'allocation ownership/order/metadata')
                ledger[r]=dict(id=jid,mode=mode,param=p,values=[],complete=False);allocated.append(r)
            elif tag=='W':
                r,jid,index=int(f[2]),int(f[3]),int(f[4]);value=int(f[5],16);last=int(f[6])
                require(r in ledger and r!=sentinel and not ledger[r]['complete'] and jid==ledger[r]['id'] and index==len(ledger[r]['values']) and
                        index<len(expected_values.get(r,[])) and value==expected_values[r][index] and last==int(index==255),'exact scalar coefficient/index/tag/last')
                ledger[r]['values'].append(value);write_counts[r]=write_counts.get(r,0)+1;coeffs+=1
            elif tag=='M':
                r,jid,code,n=map(int,f[2:]);require(r in ledger and not ledger[r]['complete'] and jid==ledger[r]['id'] and n==len(ledger[r]['values']),'finish owner/count')
                if code==0:require(n==256,'complete polynomial length');ledger[r]['complete']=True
                else:require(code==1 and (golds[0][0] or golds[1][0]) and n<256,'partial discard');del ledger[r]
            elif tag=='F':
                r=int(f[2]);require(r in ledger and ledger[r]['complete'],'release existing committed region')
                require((r==sentinel and foreign_release) or (r!=sentinel and (authorized or c['code']!=0 or c['abort']==8)),'release lifetime/foreign preservation')
                del ledger[r];released.append(r)
            elif tag=='Q':
                require(q is None and not preflight and list(map(int,f[3:]))==[c['id'],1,(1312,1952,2592)[p],64] and int(f[2]) in (0,1),'paired SHAKE descriptor')
                q=int(f[2])
            elif tag=='B':
                require(q is not None and int(f[2])==len(raw),'raw absorption sequence');raw.append(int(f[3],16).to_bytes(8,'little'))
            elif tag=='O':
                require(q is not None and int(f[2])==q and int(f[3])==(0xf00d if c['abort']==10 else c['id']) and int(f[4])==16 and len(outs)<4,'raw digest owner/width')
                require(len(raw)==(1312,1952,2592)[p]//8,'digest before full absorption');digest=hashlib.shake_256(b''.join(raw)).digest(64)
                require(int(f[5],16).to_bytes(16,'little')==digest[16*len(outs):16*(len(outs)+1)],'independent exact SHAKE digest');outs.append(f)
            elif tag=='G':require(q is not None and list(map(int,f[2:]))==[q,c['id']] and len(outs)==4,'raw retirement')
            elif tag=='L':
                kind=int(f[2]);require(kind==len(load_kinds),'load retirement order');load_kinds.append(kind)
                code,header,_,_=golds[kind];mask=sum(1<<r for r in range(base+(k if kind else 0),base+(total if kind else k))) if code==0 else 0
                expected_header=header if not code else b'';expected_bytes=len(expected_header)
                require(int(f[3])==(0x1234 if c['scenario']==19 and kind else c['id']) and int(f[4])==code and
                        int(f[5],16)==(0 if c['scenario']==20 and not kind else mask) and int(f[6])==(0 if c['scenario']==21 and kind else expected_bytes) and
                        int(f[7],16)==int.from_bytes(expected_header,'little'),'load status/mask/header')
                if kind:require(len(ev('G'))==1 and events.index(ev('G')[0])<events.index(f),'PK raw retirement before signature')
            elif tag=='R':
                r,w,jid,mode,param,domain,small,error=map(int,f[2:10]);require(r in ledger and ledger[r]['complete'] and 0<=w<64,'read ownership')
                poly=ledger[r]['values'];packed=sum(v<<(23*j) for j,v in enumerate(poly[4*w:4*w+4]))
                require((jid,mode,param,domain,small,error)==(ledger[r]['id'],ledger[r]['mode'],ledger[r]['param'],0,int(all(v<=4 or v>=8380413 for v in poly)),0) and int(f[10],16)==packed,'exact packed read/metadata')
                read_rows.append((r,w))
            elif tag=='D':
                require(not seen_d and not c['abort'],'one held completion');seen_d=True
                mask=sum(1<<r for r in ledger);complete=sum(1<<r for r,v in ledger.items() if v['complete'])
                require(list(map(int,f[2:5]))==[c['id'],c['code'],c['detail']] and int(f[5],16)==mask and int(f[6],16)==complete and int(f[7])==0 and
                        mask==(smask if c['code'] else smask|plan),'completion status/quiescent ownership')
            elif tag=='Y':
                require(seen_d and not c['code'] and not seen_context,'context publication');seen_context=True
                require(list(map(int,f[2:4]))==[p,c['id']] and int(f[4],16)==plan and int(f[5],16)==int.from_bytes(c['pk'][:32],'little') and
                        int(f[6],16)==int.from_bytes(hashlib.shake_256(c['pk']).digest(64),'little') and int(f[7],16)==int.from_bytes(c['sig'][:(32,48,64)[p]],'little'),'rho/tr/ctilde and context ownership')
            elif tag in ('TAKE','CLEAR'):
                require(seen_context and not authorized and int(f[2],16)==plan and tag==('TAKE' if c['adopt'] else 'CLEAR'),'clear/take priority and transfer');authorized=True
            elif tag=='EXTERNAL_RELEASE':require(int(f[2])==sentinel and not foreign_release,'foreign lease retirement');foreign_release=True
            elif tag=='HOLD':require(list(map(int,f[2:]))==[base,0] and seen_context,'pending read blocks clear/take')
            elif tag=='Z':
                visible=sum(1<<r for r,v in ledger.items() if v['complete'])
                if 0 not in load_kinds:visible&=~sum(1<<r for r in range(base,base+k))
                if 1 not in load_kinds:visible&=~sum(1<<r for r in range(base+k,base+total))
                require(c['abort'] and int(f[2])==c['abort'] and int(f[4])==int(c['abort'] in (10,11)) and int(f[6],16)==sum(1<<r for r in ledger) and
                        int(f[7],16)==visible,'reset/fault ownership snapshot')
        # Every accepted PK word reaches raw SHAKE once;errors then zero-fill.
        host_raw=[int(f[6],16).to_bytes(8,'little') for f in frames[0]]
        require(raw== (host_raw+[bytes(8)]*max(0,len(raw)-len(host_raw)))[:len(raw)],'fork delivery or finite zero drain')
        require(not ev('K') or seen_context,'handles without context')
        if c['abort']:
            require(len(ev('Z'))==1 and events[-1][0]=='Z' and not ev('D') and not ev('Y') and not ev('ENDCASE'),'reset terminates tentative owner')
            phase=c['abort'];state=int(ev('Z')[0][3]);require(state==({1:3,2:3,3:3,4:6,5:6,6:8,7:9,8:10,9:4,10:11,11:11}[phase]),'reset state witness')
            if phase==1:require(len(raw)==2,'elastic fork reset prefix')
            if phase==3:require(len(raw)==12,'PK hash reset prefix')
            if phase in (6,7,8):require(sum(write_counts.values())==total*256 and len(outs)==4,'fully prepared reset')
            if phase==9:require(not outs and len(raw)==(1312,1952,2592)[p]//8,'held raw digest reset')
            totals[2]+=1
        else:
            require(seen_d and ev('ENDCASE')==[['ENDCASE',str(i),'0']] and not ledger and foreign_release and events[-1][0]=='ENDCASE' and not ev('Z'),'complete final cleanup')
            if not preflight:require(q is not None and len(raw)==(1312,1952,2592)[p]//8 and len(outs)==4 and len(ev('G'))==1,'finite SHAKE fully retired')
            else:require(q is None and not load_kinds and not allocated and not raw and not outs,'no preflight side effects')
            if c['code']==0:
                require(authorized and seen_context and len(allocated)==total and sum(write_counts.values())==total*256,'complete prepared payload')
                handles=[['K',str(i),str(s),str(j),str(base+j+(0 if s==0 else k if s==1 else k+l))] for s,n in ((0,k),(1,l),(2,k)) for j in range(n)]
                require(sorted(ev('K'))==sorted(handles) and ev('HOLD')==[['HOLD',str(i),str(base),'0']],'all context handles and ownership hold')
                expected_reads=[(r,w) for r in range(base,base+total) for w in range(64)];successes+=1
            else:
                require(not seen_context and not authorized and not ev('K') and not ev('HOLD'),'error publishes no payload');expected_reads=[];errors+=1
                if not preflight:
                    started=[0] if golds[0][0] or c['scenario']==20 else [0,1]
                    require(load_kinds==started,'all started loaders retire')
                    target=sum(len(golds[kind][2]) for kind in started)
                    require(sum(write_counts.values())==target,'all pre-error coefficients checked')
            expected_reads+=([(sentinel,0)] if c['scenario']==5 else [])+[(sentinel,w) for w in range(64)]
            require(read_rows==expected_reads,'complete read sequence including untouched foreign polynomial');totals[1]+=1
        for n,tag in ((0,'C'),(3,'I'),(4,'A'),(5,'W'),(6,'M'),(7,'F'),(8,'R'),(9,'B'),(10,'O')):totals[n]+=len(ev(tag))
    if position!=len(lines)-1 or lines[position]!='END '+' '.join(map(str,totals)):raise ValueError('Verify preparation footer/trailing data')
    return f'STAGE5V2A_VERIFY_PREPARE_COMPARE_PASS:{totals[0]} commands/{successes} prepared contexts/{errors} expected errors/{totals[2]} resets-faults;{coeffs} exact scalar values/{totals[8]} exact packed reads/{totals[9]} raw input words/{totals[10]} digest beats;NOT main RTL Verify\n'


@lru_cache(maxsize=1)
def verify_math_cases():
    rows=[];official=nist_verify_corpus()[0]
    selected=[c for c in official if not verify_unpack_math(1,c['p'],c['sig'])[3] and verify_unpack_math(1,c['p'],c['sig'])[2] is not None]
    def add(c,ctx=None,msg=None,scenario=0,abort=0):
        i=len(rows);p=c['p'];k,l=((4,4),(6,5),(8,7))[p];ctx=c['ctx'] if ctx is None else ctx;msg=c['msg'] if msg is None else msg
        data=ctx+msg;ctxlen=len(ctx);mlen=len(msg)
        if scenario==1:ctxlen=256
        if scenario==2:mlen=65535
        if scenario==11:data=data[:-1]
        if scenario==12:data=data+b'\xa5'
        code=1 if scenario in (1,2,3,4) else 2 if scenario in (5,6,20) else 3 if scenario in range(7,13) else 4 if scenario in (17,18) else 5 if scenario==16 else 6 if scenario in (13,14,19) else 0
        detail=2 if code==3 else 1 if scenario==16 else 0
        rows.append(dict(i=i,p=p,id=65535 if i==0 else 0 if i==1 else 52000+i,base=(7*i)%(65-2*k-l),scenario=scenario,abort=abort,adopt=i%2,
                         ctxlen=ctxlen,mlen=mlen,ctx=ctx,msg=msg,body=data,pk=c['pk'],sig=c['sig'],code=code,detail=detail,origin='NIST_Verify' if ctx==c['ctx'] and msg==c['msg'] and not scenario and not abort else 'directed',tc=c['tc']))
    for c in selected:add(c)
    for p in range(3):
        c=next(c for c in selected if c['p']==p and c['valid'])
        for ctx,msg in ((b'',b''),(b'',b'X'),(bytes(range(255)),b'Z'),(b'\x01',bytes(range(7))),(bytes(range(7)),bytes(range(9))),(bytes(range(8)),bytes(range(17)))):add(c,ctx,msg)
        for scenario in (*range(1,15),16,17,18,19,20):add(c,b'ctx',bytes(range(49)),scenario=scenario)
    for phase in range(1,13):
        c=next(c for c in selected if c['p']==(phase-1)%3 and c['valid']);add(c,b'ctx',bytes(range(49)),abort=phase);add(c,b'ctx',bytes(range(49)))
    return rows


@lru_cache(maxsize=None)
def verify_math_material(p,pk,sig,ctx,msg,internal=False):
    rho,t1,_,_=verify_unpack_math(0,p,pk);ctilde,z,h,norm=verify_unpack_math(1,p,sig)
    if h is None or norm:raise ValueError('Verify math requires structurally valid upstream context')
    tr=hashlib.shake_256(pk).digest(64);formatted=tr+(b'' if internal else b'\0'+bytes([len(ctx)]))+ctx+msg
    mu=hashlib.shake_256(formatted).digest(64);c=reference.sample(3,p,hashlib.shake_256(ctilde).digest(4096))[0]
    raw=[t1[j:j+256] for j in range(0,len(t1),256)]+[z[j:j+256] for j in range(0,len(z),256)]+[h[j:j+256] for j in range(0,len(h),256)]
    return dict(rho=rho,ctilde=ctilde,tr=tr,mu=mu,formatted=formatted,c=c,raw=raw,
                t1hat=[ntt_reference.forward(t1[j:j+256]) for j in range(0,len(t1),256)],
                zhat=[ntt_reference.forward(z[j:j+256]) for j in range(0,len(z),256)],chat=ntt_reference.forward(c))


def verify_math_artifact(token):
    return f'{token} {len(verify_math_cases())} {VERIFY_SENTINEL_SEED.hex()}\n'+''.join(
        ' '.join(str(c[n]) for n in ('i','p','id','base','scenario','abort','adopt','ctxlen','mlen','code','detail'))+' '+c['pk'].hex()+' '+c['sig'].hex()+' '+(c['body'].hex() or '-')+'\n' for c in verify_math_cases())


def verify_math_payload(c):
    out=[];data=c['body']
    for w in range((len(data)+7)//8):
        part=data[8*w:8*w+8];n=len(part);index=1024 if c['scenario']==7 and w==0 else w
        size=0 if c['scenario']==8 and w==0 else n;last=int(8*(w+1)>=len(data))
        if c['scenario']==9 and w==0:last=1
        if c['scenario']==10 and last:last=0
        out.append(['I',str(c['i']),str(index),str(size),str(last),f'{int.from_bytes(part+bytes([255])*(8-n),"little"):016x}'])
    return out


def verify_verify_math(lines,token=None):
    if token is None:_,token=check()
    if not lines or lines[0]!='V '+token:raise ValueError('Verify math stale capture')
    position=1;totals=[0]*14;success=errors=pre_ntt=0;shapes={'INIT':7,'C':5,'T':3,'I':6,'Q':7,'B':4,'O':6,'G':4,'X':4,'J':8,'S':4,'H':5,'N':8,'V':5,'A':9,'W':6,'M':5,'F':3,'R':11,'HOLD':4,'D':8,'Y':8,'K':5,'TAKE':3,'CLEAR':3,'PREP_CLEAR':3,'EXTERNAL_RELEASE':3,'ENDCASE':3,'Z':7}
    sentinel_poly=reference.sample(2,0,hashlib.shake_256(VERIFY_SENTINEL_SEED).digest(4096))[0]
    for c in verify_math_cases():
        i,p,base=c['i'],c['p'],c['base'];k,l=((4,4),(6,5),(8,7))[p];total=2*k+l;sentinel=63 if base+total<=63 else 0
        material=verify_math_material(p,c['pk'],c['sig'],c['ctx'],c['msg']);initial=sum(1<<r for r in range(base,base+total));events=[]
        while position<len(lines) and not lines[position].startswith('END '):
            f=lines[position].split()
            if not f or f[0] not in shapes or len(f)!=shapes[f[0]]:raise ValueError(f'Verify math event shape at{position}: {f[:3]}')
            if int(f[1])>i:break
            if int(f[1])!=i:raise ValueError('Verify math event order')
            events.append(f);position+=1
        def ev(tag):return [f for f in events if f[0]==tag]
        def require(ok,why):
            if not ok:raise ValueError(f'Verify math case{i}: '+why)
        require(events and events[0][0]=='INIT' and ev('INIT')==[['INIT',str(i),str(p),str(c['id']),str(base),str(sentinel),f'{initial:016x}']],'actual upstream setup')
        require(ev('C')==[['C',str(i),str(c['id']),str(c['ctxlen']),str(c['mlen'])]],'command snapshot')
        payload=ev('I');expected_payload=verify_math_payload(c);require(payload==expected_payload[:len(payload)],'original payload framing')
        ledger={base+j:dict(values=poly.copy(),id=c['id'],mode=2 if k<=j<k+l else 3,param=p,domain=0,complete=True) for j,poly in enumerate(material['raw'])}
        ledger[sentinel]=dict(values=sentinel_poly.copy(),id=62000,mode=2,param=0,domain=0,complete=True)
        adopted=False;authorized=False;prepclear=False;foreign=False;published=False;pending=None;q=None;raw=[];out=[];seed=[];c_region=None;op_count=0;finished_ops=0;readrows=[];handles={};destinations=[];released_sources=[];sample_core=None
        for f in events:
            tag=f[0]
            if tag=='T':require(not adopted and int(f[2],16)==initial,'one atomic upstream take');adopted=True
            elif tag=='Q':
                require(adopted and q is None and list(map(int,f[3:]))==[c['id'],1,66+c['ctxlen']+c['mlen'],64] and int(f[2]) in (0,1),'mu descriptor');q=int(f[2])
            elif tag=='B':require(q is not None and int(f[2])==len(raw),'mu absorption index');raw.append(int(f[3],16).to_bytes(8,'little'))
            elif tag=='O':
                require(q is not None and int(f[2])==q and int(f[3])==(0xf00d if c['abort']==11 else c['id']) and int(f[4])==16 and len(out)<4,'mu output identity')
                msg=b''.join(raw)[:66+c['ctxlen']+c['mlen']];require(len(msg)==66+c['ctxlen']+c['mlen'],'mu absorption before squeeze')
                require(int(f[5],16).to_bytes(16,'little')==hashlib.shake_256(msg).digest(64)[16*len(out):16*(len(out)+1)],'exact independent mu digest');out.append(f)
            elif tag=='G':require(list(map(int,f[2:]))==[q,c['id']] and len(out)==4,'mu retirement')
            elif tag=='X':require(list(map(int,f[2:]))==[0xf00d if c['scenario']==19 else c['id'],2 if c['code']==3 else 0] and len(ev('G'))==1,'formatter retirement/status')
            elif tag=='J':
                require(adopted and c_region is None and list(map(int,f[3:5]))==[c['id'],p] and list(map(int,f[6:]))==[3,(32,48,64)[p]] and len(ev('G'))==1,'challenge descriptor')
                c_region=int(f[5]);sample_core=int(f[2]);require(c_region==next(r for r in range(64) if r not in ledger),'first free challenge region');pending=dict(region=c_region,values=material['c'],mode=3,domain=0)
            elif tag=='S':require(c_region is not None and int(f[2])==len(seed) and int(f[3],16).to_bytes(8,'little')==material['ctilde'][8*len(seed):8*(len(seed)+1)],'original ctilde absorption');seed.append(f)
            elif tag=='H':
                edge=events.index(f);same_finish=edge+1<len(events) and events[edge+1]==['M',str(i),str(c_region),'0','256']
                require(list(map(int,f[2:]))==[sample_core,0xf00d if c['scenario']==13 else c['id'],0] and len(seed)==(32,48,64)[p]//8 and len(ledger[c_region]['values'])==256 and (ledger[c_region]['complete'] or same_finish),'challenge completion and same-edge memory finish')
            elif tag=='N':
                ordinal,op,src,sid,dest,jid=map(int,f[2:]);require(adopted and ordinal==op_count and ordinal<k+l+1 and op==(3 if ordinal==k+l else 0) and jid==c['id'] and sid==(c['id']^1 if c['scenario']==16 else c['id']),'NTT operation metadata/Pre-NTT')
                expected_source=base+ordinal if ordinal<k+l else c_region
                require(src==expected_source and src in ledger and ledger[src]['complete'] and not ledger[src]['domain'] and dest not in ledger,'source lease/domain and free rotating work region')
                if ordinal==0:require(dest==next(r for r in range(64) if r not in ledger),'initial free NTT workspace')
                else:require(dest==released_sources[-1],'one rotating scratch region')
                if c['scenario']!=16:pending=dict(region=dest,values=ntt_reference.forward(ledger[src]['values']),mode=ledger[src]['mode'],domain=1)
                destinations.append((src,dest));op_count+=1;pre_ntt+=int(op==3)
            elif tag=='V':
                require(finished_ops<op_count and list(map(int,f[2:]))==[0xf00d if c['scenario']==14 else c['id'],1 if c['scenario']==16 else 0,destinations[finished_ops][1]],'NTT completion metadata')
                finished_ops+=1
            elif tag=='A':
                r,jid,mode,param,raw_domain,rewrite,compute=map(int,f[2:]);domain=raw_domain if compute else int(mode==0)
                require(pending is not None and r==pending['region'] and r not in ledger and jid==c['id'] and param==p and mode==pending['mode'] and domain==pending['domain'] and compute==pending['domain'] and not rewrite,'physical destination allocation')
                ledger[r]=dict(values=[],expected=pending['values'],id=jid,mode=mode,param=param,domain=domain,complete=False);pending=None
            elif tag=='W':
                r,index,value,last=int(f[2]),int(f[3]),int(f[4],16),int(f[5]);require(r in ledger and not ledger[r]['complete'] and index==len(ledger[r]['values']) and index<256 and value==ledger[r]['expected'][index] and last==int(index==255),'exact sampler/NTT scalar output')
                ledger[r]['values'].append(value)
            elif tag=='M':
                r,code,n=map(int,f[2:]);require(r in ledger and not ledger[r]['complete'] and code==0 and n==len(ledger[r]['values'])==256,'full polynomial commit');ledger[r]['complete']=True
            elif tag=='F':
                r=int(f[2]);require(r in ledger and ledger[r]['complete'],'release existing complete lease')
                if r==sentinel:require(foreign,'foreign lease lifetime')
                elif r in [s for s,d in destinations[:finished_ops]] and len(released_sources)<finished_ops and not c['code'] and not authorized and not prepclear:
                    j=len(released_sources);require(j<finished_ops and r==destinations[j][0],'source released only after transform retirement');released_sources.append(r)
                else:require(authorized or prepclear or (adopted and c['code']) or c['abort']==10,'cleanup ownership')
                del ledger[r]
            elif tag=='D':
                require(not c['abort'] and len(ev('D'))==1 and list(map(int,f[2:5]))==[c['id'],c['code'],c['detail']],'held math completion')
                mask=sum(1<<r for r in ledger);complete=sum(1<<r for r,v in ledger.items() if v['complete'])
                require(int(f[5],16)==mask and int(f[6],16)==complete and int(f[7])==0,'retired physical ownership')
                if c['code'] and adopted:require(mask==1<<sentinel,'adopted error fully cleans context')
                if not adopted:require(mask==initial|(1<<sentinel),'pre-adoption errors preserve upstream owner')
            elif tag=='Y':
                require(not c['code'] and not published and list(map(int,f[2:4]))==[p,c['id']] and int(f[4],16)==sum(1<<r for r in ledger if r!=sentinel) and
                        int(f[5],16)==int.from_bytes(material['rho'],'little') and int(f[6],16)==int.from_bytes(material['mu'],'little') and int(f[7],16)==int.from_bytes(material['ctilde'],'little'),'exact prepared headers/mu/mask');published=True
            elif tag=='K':
                section,poly,r=map(int,f[2:]);require(published and (section,poly) not in handles,'unique published handle');handles[section,poly]=r
                target=material['t1hat'][poly] if section==0 else material['zhat'][poly] if section==1 else material['raw'][k+l+poly] if section==2 else material['chat']
                require(r in ledger and ledger[r]['values']==target and ledger[r]['domain']==int(section!=2),'exact result handle mapping and domain')
            elif tag=='R':
                r,w,jid,mode,param,domain,small,error=map(int,f[2:10]);require(r in ledger and ledger[r]['complete'] and 0<=w<64,'read committed owner')
                a=ledger[r];packed=sum(v<<(23*j) for j,v in enumerate(a['values'][4*w:4*w+4]))
                require((jid,mode,param,domain,small,error)==(a['id'],a['mode'],a['param'],a['domain'],int(all(v<=4 or v>=8380413 for v in a['values'])),0) and int(f[10],16)==packed,'exact read data/domain/metadata');readrows.append((r,w))
            elif tag=='HOLD':require(published and list(map(int,f[2:]))==[destinations[-1][1],0],'pending read blocks handoff')
            elif tag in ('CLEAR','TAKE'):
                require(published and not authorized and tag==('TAKE' if c['adopt'] else 'CLEAR') and int(f[2],16)==sum(1<<r for r in ledger if r!=sentinel),'clear/take priority and mask');authorized=True
            elif tag=='PREP_CLEAR':require(not adopted and not prepclear and int(f[2],16)==initial,'upstream owner cleanup');prepclear=True
            elif tag=='EXTERNAL_RELEASE':require(int(f[2])==sentinel and not foreign,'sentinel explicit owner release');foreign=True
            elif tag=='Z':
                complete=sum(1<<r for r,v in ledger.items() if v['complete'])
                if finished_ops<len(destinations):complete&=~(1<<destinations[-1][0])
                require(c['abort'] and int(f[2])==c['abort'] and int(f[4])==int(c['abort'] in (11,12)) and int(f[5],16)==sum(1<<r for r in ledger) and int(f[6],16)==complete,'reset/fault physical snapshot')
        # Pure FIPS204 mu is H(tr||00||ctxlen||ctx||M). A malformed beat is
        # excluded and the formatter drains with zeros;unused tail bits are zero.
        formatted=material['tr']+b'\0'+bytes([len(c['ctx'])]);body_good=b'';consumed=0
        for j,f in enumerate(payload):
            expect=min(8,len(c['ctx'])+len(c['msg'])-8*j)
            if int(f[2])!=j or int(f[3])!=expect or int(f[4])!=int(8*j+expect==len(c['ctx'])+len(c['msg'])):break
            body_good+=int(f[5],16).to_bytes(8,'little')[:expect];consumed+=1
        if c['code']==3:formatted+=body_good+bytes(len(c['ctx'])+len(c['msg'])-len(body_good))
        else:formatted+=c['ctx']+c['msg']
        expected_raw=[formatted[j:j+8].ljust(8,b'\0') for j in range(0,len(formatted),8)]
        require(raw==expected_raw[:len(raw)],'independent formatted absorption/zero drain')
        if c['abort']:
            phase=c['abort'];states={1:2,2:4,3:4,4:7,5:8,6:12,7:12,8:15,9:16,10:17,11:18,12:18}
            require(len(ev('Z'))==1 and int(ev('Z')[0][3])==states[phase] and events[-1][0]=='Z' and not ev('D') and not ev('Y') and not ev('ENDCASE'),'bounded reset state/visibility')
            require(adopted==(phase!=1),'atomic reset adoption boundary')
            if phase==2:require(len(raw)==3,'mu prefix reset')
            if phase==3:require(not out and len(raw)==len(expected_raw),'held digest reset')
            if phase==4:require(len(seed)==1,'challenge absorption reset')
            if phase in (8,9,10):require(op_count==finished_ops==k+l+1 and len(released_sources)==k+l+1,'fully prepared reset boundary')
            totals[3]+=1
        else:
            require(len(ev('D'))==1 and ev('ENDCASE')==[['ENDCASE',str(i),'0']] and events[-1][0]=='ENDCASE' and not ledger and not ev('Z'),'final cleanup/completion')
            if ev('J'):require(len(ev('J'))==len(ev('H'))==1 and len(seed)==(32,48,64)[p]//8,'one complete challenge sampling retirement')
            else:require(not ev('H') and not seed,'no orphan challenge records')
            if adopted:require(len(raw)==len(expected_raw) and len(out)==4 and len(ev('G'))==len(ev('X'))==1,'mu and formatter fully retire')
            else:require(not raw and not out and not ev('J') and not ev('N') and prepclear,'rejected command does not adopt/use engines')
            if not c['code']:
                require(published and authorized and op_count==finished_ops==k+l+1 and len(seed)==(32,48,64)[p]//8 and len(released_sources)==k+l+1,'all transforms including Pre-NTT complete')
                expected_keys={(s,j) for s,n in ((0,k),(1,l),(2,k),(3,1)) for j in range(n)};require(set(handles)==expected_keys and len(set(handles.values()))==total+1,'complete unique result handles')
                require(payload==expected_payload and len(ev('T'))==1 and len(ev('HOLD'))==1,'whole message and handoff');success+=1
                expected_reads=[(r,w) for r in sorted(handles.values()) for w in range(64)]
            else:
                require(not published and not handles and not ev('HOLD'),'error exposes no result');errors+=1;expected_reads=[]
                if c['code']==3:require(len(payload)==consumed+1,'stop after first malformed payload word')
            expected_reads+=([(sentinel,0)] if c['scenario']==6 else [])+[(sentinel,w) for w in range(64)]
            require(readrows==expected_reads and foreign,'every result/foreign word read exactly');totals[2]+=1
        for n,tag in ((0,'C'),(1,'T'),(4,'I'),(5,'A'),(6,'W'),(7,'M'),(8,'F'),(9,'R'),(10,'B'),(11,'O'),(12,'N')):totals[n]+=len(ev(tag))
    totals[13]=len(verify_math_cases())
    if position!=len(lines)-1 or lines[position]!='END '+' '.join(map(str,totals)):raise ValueError('Verify math footer/trailing records')
    return f'STAGE5V2B_VERIFY_MATH_COMPARE_PASS:{totals[0]} commands/{success} transformed contexts/{errors} expected errors/{totals[3]} resets-faults;{totals[6]} exact scalar writes/{totals[9]} packed reads/{totals[12]} NTT commands including{pre_ntt} Pre-NTTs;{totals[10]} exact mu words/{totals[11]} digest beats;NOT final RTL Verify verdicts\n'


def use_hint_math(p,a,h):
    if p==3 or a>=8380417 or h>1:return 1,0
    high,low=mathematical_decompose(a,p)
    return 0,high if not h else (high+(1 if low>0 else -1))%(44 if p==0 else 16)


@lru_cache(maxsize=1)
def use_hint_cases():
    rows=[]
    for p in range(3):
        gamma=95232 if p==0 else 261888;maximum=44 if p==0 else 16
        values={0,1,8380415,8380416}
        for j in range(maximum+1):
            for center in (2*gamma*j,2*gamma*j+gamma):
                values.update(center+d for d in (-1,0,1) if 0<=center+d<8380417)
        for a in sorted(values):
            for h in (0,1):rows.append((p,a,h,*use_hint_math(p,a,h)))
        for a in (0,1,8380416):
            for h in (2,64,4194304):rows.append((p,a,h,*use_hint_math(p,a,h)))
        for a in (8380417,8380418,8388607):
            for h in (0,1):rows.append((p,a,h,*use_hint_math(p,a,h)))
    for h in (0,1,64):rows.append((3,0,h,*use_hint_math(3,0,h)))
    return rows


@lru_cache(maxsize=1)
def verify_equation_cases():
    rows=[];original=nist_verify_corpus()[0]
    selected=[c for c in original if verify_unpack_math(1,c['p'],c['sig'])[2] is not None and not verify_unpack_math(1,c['p'],c['sig'])[3]]
    def add(c,scenario=0,abort=0,mutation=0):
        i=len(rows);p=c['p'];k,l=((4,4),(6,5),(8,7))[p];sig=c['sig'];ctx=c['ctx'];msg=c['msg']
        if mutation==1:msg=(bytes([msg[0]^1])+msg[1:]) if msg else b'\xa5'
        if mutation==2:sig=bytes([sig[0]^1])+sig[1:]
        if mutation==3:sig=make_verify_signature(p)
        code=1 if scenario in (1,2) else 2 if scenario in (3,4,16) else 3 if scenario==5 else 5 if scenario==13 else 6 if scenario in (9,10) else 7 if scenario in (6,7,8,11,12,15) else 0
        rows.append(dict(i=i,p=p,id=65535 if i==0 else 0 if i==1 else 53000+i,base=(7*i)%(65-2*k-l),scenario=scenario,abort=abort,code=code,detail=1 if scenario==13 else 0,
                         pk=c['pk'],sig=sig,ctx=ctx,msg=msg,origin='NIST_Verify' if i<len(selected) else 'directed',tc=c['tc'],official=c['valid'] if not mutation else None))
    for c in selected:add(c)
    for p in range(3):
        c=next(c for c in selected if c['p']==p and c['valid'])
        for mutation in (1,2,3):add(c,mutation=mutation)
    for scenario in (*range(1,14),15,16):
        for p in range(3) if scenario in (9,10,11,12) else [(scenario-1)%3]:
            add(next(c for c in selected if c['p']==p and c['valid']),scenario=scenario)
    for phase in range(1,11):
        c=next(c for c in selected if c['p']==(phase-1)%3 and c['valid']);add(c,abort=phase);add(c)
    return rows


@lru_cache(maxsize=None)
def verify_equation_material(p,pk,sig,ctx,msg,internal=False):
    data=verify_math_material(p,pk,sig,ctx,msg,internal=internal);k,l=((4,4),(6,5),(8,7))[p];q=8380417
    matrix=[[reference.sample(0,p,hashlib.shake_128(data['rho']+bytes([j,r])).digest(4096))[0] for j in range(l)] for r in range(k)]
    spectra=[];w=[];high=[];packed=b'';width=6 if p==0 else 4
    for r in range(k):
        a=[(sum(matrix[r][j][n]*data['zhat'][j][n] for j in range(l))-data['chat'][n]*data['t1hat'][r][n])%q for n in range(256)]
        spectra.append(a);poly=ntt_reference.inverse(a);w.append(poly)
        h=data['raw'][k+l+r];hi=[use_hint_math(p,v,bit)[1] for v,bit in zip(poly,h,strict=True)];high.append(hi)
        packed+=sum(v<<(width*j) for j,v in enumerate(hi)).to_bytes(width*32,'little')
    digest=hashlib.shake_256(data['mu']+packed).digest((32,48,64)[p])
    return dict(**data,matrix=matrix,spectra=spectra,w=w,high=high,packed=packed,digest=digest,accept=digest==data['ctilde'])


def verify_equation_artifact(token):
    rows=verify_equation_cases();units=use_hint_cases()
    return f'{token} {len(rows)} {len(units)} {VERIFY_SENTINEL_SEED.hex()}\n'+''.join(' '.join(map(str,a))+'\n' for a in units)+''.join(
        ' '.join(str(c[n]) for n in ('i','p','id','base','scenario','abort','code','detail'))+f" {len(c['ctx'])} {len(c['msg'])} "+c['pk'].hex()+' '+c['sig'].hex()+' '+((c['ctx']+c['msg']).hex() or '-')+'\n' for c in rows)


def verify_verify_equation(lines,token=None):
    if token is None:_,token=check()
    if not lines or lines[0]!='V '+token:raise ValueError('Verify equation stale capture')
    units=use_hint_cases();position=1;totals=[len(units)]+[0]*15;valid=invalid=errors=0;peak=0
    for u,row in enumerate(units):
        if position>=len(lines) or lines[position]!='U '+str(u)+' '+' '.join(map(str,row)):raise ValueError('UseHint boundary result/order')
        position+=1
    shapes={'INIT':10,'K':5,'C':8,'T':3,'J':10,'S':6,'H':5,'N':12,'O':5,'P':12,'B':5,'PC':6,'V':7,'E':8,'PD':7,'L':6,'Q':7,'I':4,'D0':6,'G':4,'FMT':4,'R':12,'A':9,'W':7,'M':5,'F':3,'D':10,'X':11,'PREP_CLEAR':3,'EXTERNAL_RELEASE':3,'ENDCASE':3,'Z':7}
    sentinel_poly=reference.sample(2,0,hashlib.shake_256(VERIFY_SENTINEL_SEED).digest(4096))[0];modulus=8380417
    for c in verify_equation_cases():
        i,p,base=c['i'],c['p'],c['base'];k,l=((4,4),(6,5),(8,7))[p];total=2*k+l;sentinel=63 if base+total<=63 else 0;events=[]
        while position<len(lines) and not lines[position].startswith('END '):
            f=lines[position].split()
            if not f or f[0] not in shapes or len(f)!=shapes[f[0]]:raise ValueError(f'Verify equation shape at{position}: {f[:3]}')
            if int(f[1])>i:break
            if int(f[1])!=i:raise ValueError('Verify equation case order')
            events.append(f);position+=1
        def ev(tag):return [f for f in events if f[0]==tag]
        def require(ok,why):
            if not ok:raise ValueError(f'Verify equation case{i}: '+why)
        material=verify_equation_material(p,c['pk'],c['sig'],c['ctx'],c['msg'])
        rawmask=sum(1<<r for r in range(base,base+total));free=[r for r in range(64) if not rawmask>>r&1 and r!=sentinel]
        # The actual precursor uses one rotating transform scratch region.
        dest=[free[1]]+[base+j-1 for j in range(1,k+l+1)]
        handles={(0,j):dest[j] for j in range(k)}|{(1,j):dest[k+j] for j in range(l)}|{(2,j):base+k+l+j for j in range(k)}|{(3,0):dest[k+l]}
        initial=sum(1<<r for r in handles.values())
        require(events and events[0]==['INIT',str(i),str(p),str(c['id']),str(base),str(sentinel),f'{initial:016x}',f"{int.from_bytes(material['rho'],'little'):064x}",f"{int.from_bytes(material['mu'],'little'):0128x}",f"{int.from_bytes(material['ctilde'],'little'):0128x}"],'actual prepared context/headers')
        require(ev('INIT')==[events[0]],'one upstream setup record')
        expected_k=[['K',str(i),str(s),str(j),str(r)] for (s,j),r in handles.items()]
        require(sorted(ev('K'))==sorted(expected_k),'unique exact upstream handles')
        ledger={}
        for (s,j),r in handles.items():
            poly=material['t1hat'][j] if s==0 else material['zhat'][j] if s==1 else material['raw'][k+l+j] if s==2 else material['chat']
            ledger[r]=dict(values=poly.copy(),id=c['id'],mode=2 if s==1 else 3,param=p,domain=int(s!=2),complete=True)
        ledger[sentinel]=dict(values=sentinel_poly.copy(),id=62000,mode=2,param=0,domain=0,complete=True)
        plan=[r for r in range(64) if r not in ledger][:l+k+2];areg=plan[:l];acc,product=plan[l:l+2];wreg=plan[l+2:]
        command_context_id=c['id']^1 if c['scenario']==2 else c['id'];second=handles[0,0] if c['scenario']==1 else handles[0,1]
        require(ev('C')==[['C',str(i),str(c['id']),str(command_context_id),str(p),f'{initial:016x}',str(handles[0,0]),str(second)]],'accepted command snapshot')
        adopted=foreign=prepclear=False;pending=None;sample=None;ntt=None;process=None;pack=None;hashcore=None;raw=[];digest=[];payload=[]
        jobs=opordinal=procordinal=0;nttdone=procdone=0;packrows=0;rawretired=fmtretired=False;readsequence=[];sentinel_reads=[];finished=False
        expected_ops=[];expected_procs=[]
        for row in range(k):
            for col in range(l):
                expected_ops.append((row,0,col,2,areg[col],handles[1,col],c['id'],c['id'],acc if col==0 else product,c['id']))
                if col:expected_procs.append((row,0,0,acc,product,acc,c['id'],c['id'],c['id'],1))
            expected_ops.extend([(row,1,l-1,2,handles[3,0],handles[0,row],c['id'],c['id'],product,c['id']),
                                 (row,2,l-1,1,acc,handles[0,row],c['id'],c['id'],wreg[row],c['id'])])
            expected_procs.append((row,1,1,acc,product,acc,c['id'],c['id'],c['id'],1))
        for f in events:
            tag=f[0]
            if tag=='T':require(not adopted and int(f[2],16)==initial,'one atomic adoption');adopted=True
            elif tag=='J':
                row,col,core,jid,mode,param,r,n=map(int,f[2:]);require(adopted and sample is None and jobs<k*l and (row,col)==divmod(jobs,l) and (jid,mode,param,r,n)==(c['id'],0,p,areg[col],34) and core in (0,1),'matrix sampling command/region')
                sample=dict(row=row,col=col,core=core,seed=[],region=r);pending=dict(region=r,values=material['matrix'][row][col],mode=0,domain=1,rewrite=0,compute=0);jobs+=1
            elif tag=='S':
                require(sample is not None and list(map(int,f[2:5]))==[sample['row'],sample['col'],len(sample['seed'])],'matrix seed index')
                seed=material['rho']+bytes([sample['col'],sample['row']]);j=len(sample['seed']);require(int(f[5],16).to_bytes(8,'little')==seed[8*j:8*j+8].ljust(8,b'\0') and j<5,'exact rho/column/row input');sample['seed'].append(f)
            elif tag=='H':
                require(sample is not None and list(map(int,f[2:]))==[sample['core'],0xf00d if c['scenario']==6 else c['id'],0] and len(sample['seed'])==5 and len(ledger[sample['region']]['values'])==256,'sampler completion identity');sample=None
            elif tag=='N':
                fields=tuple(map(int,f[2:]));require(adopted and opordinal<len(expected_ops) and ntt is None and process is None,'exclusive NTT request')
                expected=list(expected_ops[opordinal]);
                if c['scenario']==13:expected[6]^=1
                require(fields==tuple(expected),'ordered PWM/inverse operands and identifiers');row,phase,col,op,a,b,aid,bid,d,jid=fields
                require(a in ledger and ledger[a]['complete'] and ledger[a]['domain']==1 and (op==1 or (b in ledger and ledger[b]['complete'] and ledger[b]['domain']==1)) and d not in ledger,'complete transform-domain sources/free destination')
                values=ntt_reference.inverse(ledger[a]['values']) if op==1 else [(x*y)%modulus for x,y in zip(ledger[a]['values'],ledger[b]['values'],strict=True)]
                if c['scenario']!=13:pending=dict(region=d,values=values,mode=ledger[a]['mode'],domain=int(op!=1),rewrite=0,compute=1)
                ntt=dict(a=a,b=b,dest=d,op=op);opordinal+=1
            elif tag=='O':
                require(ntt is not None and list(map(int,f[2:]))==[0xf00d if c['scenario']==7 else c['id'],1 if c['scenario']==13 else 0,ntt['dest']],'NTT completion identity/code')
                if c['scenario']!=13:require(ntt['dest'] in ledger and ledger[ntt['dest']]['complete'],'NTT commit before completion')
                ntt=None;nttdone+=1
            elif tag=='P':
                fields=tuple(map(int,f[2:]));require(adopted and procordinal<len(expected_procs) and fields==expected_procs[procordinal] and process is None and ntt is None,'ordered in-place ADD/SUB command')
                row,phase,op,a,b,d,jid,aid,bid,inplace=fields;require(all(r in ledger and ledger[r]['complete'] and ledger[r]['domain']==1 for r in (a,b)),'complete arithmetic sources')
                values=[(x+(-y if op else y))%modulus for x,y in zip(ledger[a]['values'],ledger[b]['values'],strict=True)]
                pending=dict(region=d,values=values,mode=0,domain=1,rewrite=1,compute=1);process=dict(a=a,b=b,dest=d);procordinal+=1
            elif tag=='B':
                require(process is not None and list(map(int,f[2:]))==[0xf00d if c['scenario']==8 else c['id'],0,process['dest']] and ledger[process['dest']]['complete'],'arithmetic commit/completion');process=None;procdone+=1
            elif tag=='A':
                r,rewrite,compute,domain,mode,param,jid=map(int,f[2:]);effective=domain if compute else int(mode==0)
                require(pending is not None and (r,rewrite,compute,mode,effective)==(pending['region'],pending['rewrite'],pending['compute'],pending['mode'],pending['domain']) and (param,jid)==(p,c['id']) and (r in ledger)==bool(rewrite),'physical allocation metadata/lifetime')
                ledger[r]=dict(values=[],expected=pending['values'],id=jid,mode=mode,param=param,domain=effective,complete=False);pending=None;peak=max(peak,len(ledger)-1)
            elif tag=='W':
                r,jid,index,value,last=int(f[2]),int(f[3]),int(f[4]),int(f[5],16),int(f[6]);require(r in ledger and not ledger[r]['complete'] and jid==ledger[r]['id'] and index==len(ledger[r]['values'])<256 and value==ledger[r]['expected'][index] and last==int(index==255),'exact independent scalar coefficient');ledger[r]['values'].append(value)
            elif tag=='M':
                r,code,n=map(int,f[2:]);require(r in ledger and not ledger[r]['complete'] and code==0 and len(ledger[r]['values'])==n==256,'full polynomial commit');ledger[r]['complete']=True
            elif tag=='F':
                r=int(f[2]);require(r in ledger and ledger[r]['complete'],'release existing complete lease')
                if r==sentinel:require(foreign,'foreign sentinel remains owned')
                elif not adopted:require(prepclear,'upstream owner authorizes release')
                elif r not in areg+[acc,product]:require(c['code']!=0 or c['abort']==8 or (rawretired and fmtretired),'retained inputs/results survive until hash retirement')
                if ntt:require(r not in (ntt['a'],ntt['b'],ntt['dest']),'no NTT use after release')
                if process:require(r not in (process['a'],process['b'],process['dest']),'no arithmetic use after release')
                del ledger[r]
            elif tag=='PC':
                row,jid,op,param=map(int,f[2:]);require(pack is None and row==packrows<k and (jid,op,param)==(c['id'],3,p) and opordinal==len(expected_ops) and procordinal==len(expected_procs),'shared packer starts after equation');pack=dict(row=row,values=[],outputs=0);packrows+=1
            elif tag=='R':
                purpose,row,word,r,jid,mode,param,domain,error=map(int,f[2:11]);require(r in ledger and ledger[r]['complete'] and pack is not None and row==pack['row'] and 0<=word<64,'read committed W/hint owner')
                ordinal=len(readsequence);expected_purpose=ordinal%2;expected_row=ordinal//128;expected_word=(ordinal//2)%64
                a=ledger[r];expect_r=wreg[row] if expected_purpose==0 else handles[2,row]
                require((row,word)==(expected_row,expected_word) and (purpose==expected_purpose or (purpose==2 and c['code'] in (6,7))) and r==expect_r,'read purpose/handle and pending drain response')
                expected_id=0xf00d if c['scenario']==9 and purpose==1 and row==word==0 else a['id']
                value=sum(v<<(23*j) for j,v in enumerate(a['values'][4*word:4*word+4]))
                if c['scenario']==10 and purpose==1 and row==word==0:value=(value>>23<<23)|64
                require((jid,mode,param,domain,error)==(expected_id,a['mode'],a['param'],a['domain'],0) and int(f[11],16)==value,'exact packed read/metadata with explicit injection');readsequence.append((purpose,row,word))
            elif tag=='V':
                row,index,value,last,drain=int(f[2]),int(f[3]),int(f[4],16),int(f[5]),int(f[6]);require(pack is not None and row==pack['row'] and index==len(pack['values'])<256 and drain in (0,1) and last==int(index==255),'packer scalar order/last')
                require((not drain or c['code'] in (6,7)) and value==(0 if drain else material['high'][row][index]),'exact UseHint output or explicit zero drain');pack['values'].append(value)
            elif tag=='E':
                row,jid,index,n,last,value=int(f[2]),int(f[3]),int(f[4]),int(f[5]),int(f[6]),int(f[7],16);require(pack is not None and row==pack['row'],'packer output owner')
                width=6 if p==0 else 4;word=pack['outputs'];expected_index=1 if c['scenario']==11 and row==word==0 else word;size=24 if p==0 else 16
                require((jid,index,n,last)==(c['id'],expected_index,8,int(word==size-1)) and word<size and len(pack['values'])*width>=64*(word+1),'packed word metadata/data availability')
                packed=sum(v<<(width*j) for j,v in enumerate(pack['values']));require(value==((packed>>(64*word))&((1<<64)-1)),'independent little-bit-order packing');pack['outputs']+=1
            elif tag=='PD':
                row,jid,code,sent,words=map(int,f[2:]);require(pack is not None and (row,jid,code,sent,words)==(pack['row'],0xf00d if c['scenario']==12 else c['id'],0,256,24 if p==0 else 16) and len(pack['values'])==256 and pack['outputs']==words,'full packer retirement');pack=None
            elif tag=='L':
                index,n,last,value=int(f[2]),int(f[3]),int(f[4]),int(f[5],16);require(hashcore is not None and index==len(payload) and not any(a[1]==0 for a in payload),'formatter payload ordering')
                if n==0:require(c['code'] in (6,7) and last==0 and value==0,'explicit malformed zero-drain trigger')
                else:require(n==8 and last==int((index+1)*8==len(material['packed'])) and value==int.from_bytes(material['packed'][index*8:index*8+8],'little'),'exact corrected w1 body word')
                payload.append((index,n,last,value))
            elif tag=='Q':
                core,jid,mode,n,out=map(int,f[2:]);require(hashcore is None and core in (0,1) and (jid,mode,n,out)==(c['id'],1,64+len(material['packed']),(32,48,64)[p]),'challenge recomputation SHAKE descriptor');hashcore=core
            elif tag=='I':require(hashcore is not None and int(f[2])==len(raw),'raw absorption order');raw.append(int(f[3],16).to_bytes(8,'little'))
            elif tag=='D0':
                core,jid,n,value=int(f[2]),int(f[3]),int(f[4]),int(f[5],16);require((core,jid,n)==(hashcore,0xf00d if c['abort']==9 else c['id'],16) and len(digest)<(2,3,4)[p] and len(raw)*8==64+len(material['packed']),'digest identity/complete absorption')
                expected=hashlib.shake_256(b''.join(raw)).digest((32,48,64)[p]);require(value==int.from_bytes(expected[16*len(digest):16*(len(digest)+1)],'little'),'exact independent SHAKE digest');digest.append(f)
            elif tag=='G':require(not rawretired and list(map(int,f[2:]))==[hashcore,c['id']] and len(digest)==(2,3,4)[p],'raw hash retirement');rawretired=True
            elif tag=='FMT':require(not fmtretired and rawretired and list(map(int,f[2:]))==[0xf00d if c['scenario']==15 else c['id'],2 if c['scenario'] in (9,10,11,12) else 0],'formatter status/retirement');fmtretired=True
            elif tag=='D':
                require(not c['abort'] and not finished and list(map(int,f[2:5]))==[c['id'],c['code'],c['detail']],'held controller completion');finished=True
                mask=sum(1<<r for r in ledger);complete=sum(1<<r for r,a in ledger.items() if a['complete']);require((int(f[7],16),int(f[8],16),int(f[9]))==(mask,complete,0),'completion ownership/retired services')
                require(mask==((1<<sentinel) if adopted else initial|(1<<sentinel)),'cleanup before completion/preserve unadopted context')
                if c['code']==0:
                    require(int(f[5])==int(material['accept']) and int(f[6],16)==int.from_bytes(material['digest'],'little') and rawretired and fmtretired and pack is None,'exact final challenge and valid/invalid verdict')
                    if c['origin']=='NIST_Verify':require(material['accept']==c['official'],'original NIST verdict')
                    valid+=int(material['accept']);invalid+=int(not material['accept'])
                else:require(int(f[5])==int(f[6],16)==0,'error has no cryptographic verdict');errors+=1
            elif tag=='PREP_CLEAR':require(not adopted and not prepclear and int(f[2],16)==initial,'upstream owner cleanup');prepclear=True
            elif tag=='X':
                r,word,jid,mode,param,domain,small,error=map(int,f[2:10]);require(r==sentinel and (jid,mode,param,domain,small,error)==(62000,2,0,0,0,0) and 0<=word<64 and int(f[10],16)==sum(v<<(23*j) for j,v in enumerate(sentinel_poly[4*word:4*word+4])),'foreign sentinel exact readback');sentinel_reads.append(word)
            elif tag=='EXTERNAL_RELEASE':require(not foreign and int(f[2])==sentinel,'explicit foreign owner release');foreign=True
            elif tag=='Z':
                complete=sum(1<<r for r,a in ledger.items() if a['complete'])
                if ntt:complete&=~(1<<ntt['a']);complete&=~(1<<ntt['b']) if ntt['op']!=1 else (1<<64)-1
                if process:complete&=~(1<<process['a']);complete&=~(1<<process['b'])
                require(c['abort'] and int(f[2])==c['abort'] and int(f[4])==int(c['abort'] in (9,10)) and int(f[5],16)==sum(1<<r for r in ledger) and int(f[6],16)==complete,'reset/fault exact physical ownership snapshot')
        expected_raw=material['mu']+b''.join(v.to_bytes(8,'little') for _,n,_,v in payload if n)
        expected_raw+=bytes(64+len(material['packed'])-len(expected_raw))
        require(raw==[expected_raw[j:j+8] for j in range(0,len(expected_raw),8)][:len(raw)],'formatted mu/body and zero-drain absorption')
        if c['abort']:
            phase=c['abort'];states={1:3,2:5,3:5,4:7,5:10,6:23,7:25,8:27,9:29,10:29}
            require(len(ev('Z'))==1 and int(ev('Z')[0][3])==states[phase] and events[-1][0]=='Z' and not ev('D') and not ev('ENDCASE') and adopted==(phase!=1),'bounded reset/fault phase')
            if phase==2:require(sample is not None and len(sample['seed'])==2,'matrix seed prefix reset')
            if phase in (3,4,5):require(any(len(a['values'])==17 and not a['complete'] for a in ledger.values()),'partial write reset')
            if phase==6:require(pack is not None and len(pack['values'])==17,'UseHint/packer reset')
            if phase in (7,9):require(len(raw)*8==len(expected_raw),'complete absorption before held/fault digest')
            if phase==8:require(rawretired and fmtretired,'cleanup reset after hash retirement')
        else:
            require(finished and ev('ENDCASE')==[['ENDCASE',str(i),'0']] and events[-1][0]=='ENDCASE' and not ledger and not ev('Z') and foreign,'final cleanup/no leaks')
            require(sentinel_reads==([0] if c['scenario']==3 else [])+list(range(64)),'all foreign words preserved')
            require(sample is None and ntt is None and process is None and pack is None and pending is None,'no unfinished child/allocation')
            if adopted:require(c['code']!=0 or (jobs==k*l and opordinal==nttdone==len(expected_ops) and procordinal==procdone==len(expected_procs) and packrows==k and len(payload)*8==len(material['packed'])),'whole equation/packing/hash executed')
            else:require(prepclear and not any(ev(t) for t in ('J','N','P','PC','Q','R','W','A')),'pre-adoption rejection has no child side effects')
            if c['code']==0:require(readsequence==[(purpose,row,w) for row in range(k) for w in range(64) for purpose in (0,1)],'every W/hint word read exactly')
        for col,tags in ((1,('C',)),(2,('T',)),(3,('D',)),(4,('Z',)),(5,('A',)),(6,('W',)),(7,('M',)),(8,('F',)),(9,('R','X')),(10,('N',)),(11,('P',)),(12,('V',)),(13,('E',)),(14,('I',)),(15,('D0',))):totals[col]+=sum(len(ev(t)) for t in tags)
    if position!=len(lines)-1 or lines[position]!='END '+' '.join(map(str,totals)):raise ValueError('Verify equation footer/trailing records')
    return f'STAGE5V3_VERIFY_EQUATION_COMPARE_PASS:{totals[1]} commands/{valid} valid/{invalid} cryptographic invalid/{errors} expected protocol errors/{totals[4]} resets-faults;{totals[0]} UseHint cases;{totals[6]} exact writes/{totals[9]} packed reads;{totals[10]} NTT/{totals[11]} ADD-SUB;peak{peak} private regions;component only,main Verify not connected\n'


@lru_cache(maxsize=1)
def full_verify_cases():
    rows=[];official=nist_verify_corpus()[0]
    def add(c,op=2,fault=0,abort=0,mutation=0,override='',jid=None):
        i=len(rows);p=c['p'];ctx=c['ctx'];msg=c['msg'];sig=c['sig']
        if mutation==1:msg=(bytes([msg[0]^1])+msg[1:]) if msg else b'\xa5'
        if mutation==2:sig=bytes([sig[0]^1])+sig[1:]
        if mutation==3:sig=make_verify_signature(p)
        if mutation==4:ctx=b'';msg=b''
        if mutation==5:ctx=bytes(range(255));msg=b'\xa5'
        code=2 if op==3 else 1 if override in ('param','ctx','length') else 3 if 1<=fault<=8 else 4 if 9<=fault<=12 else 6 if fault in (15,16,17) else 0
        stage=1 if code==3 or fault==15 else 2 if code==4 or fault==16 else 3 if fault==17 else 0
        detail=(4 if fault<=4 else 5) if code==3 else 3 if code==4 else 0
        rows.append(dict(i=i,op=op,p=3 if override=='param' else p,id=65535 if i==0 else 0 if i==1 else 55000+i if jid is None else jid,
            fault=fault,abort=abort,code=code,stage=stage,detail=detail,pk=c['pk'],sig=sig,ctx=ctx,msg=msg,
            ctxlen=256 if override=='ctx' else len(ctx),mlen=65535 if override=='length' else len(msg),
            siglen=0 if override=='sig0' else len(sig)-1 if override=='sigshort' else len(sig)+1 if override=='siglong' else len(sig),
            rnd=bytes(32),xi=bytes(32),sk=b'',origin='NIST_Verify' if i<45 else 'directed',official=c['valid'] if i<45 else None,tc=c['tc']))
    for c in official:add(c)
    good=[next(c for c in official if c['p']==p and c['valid']) for p in range(3)]
    add(good[0],op=0);key=next(c for c in nist_keygen_cases() if c['p']==0);rows[-1].update(xi=key['xi'],pk=key['pk'],sk=key['sk'])
    add(good[0],op=1);source=full_sign_cases()[0];rows[-1].update(ctx=source['ctx'],msg=source['msg'],ctxlen=source['ctxlen'],mlen=source['mlen'],sk=source['sk'],rnd=source['rnd'],pk=source['pk'])
    for c in good:
        for mutation in (1,2,3,4,5):add(c,mutation=mutation)
    for override in ('param','ctx','length'):add(good[0],override=override)
    add(good[0],op=3)
    for c in good:
        for override in ('sig0','sigshort','siglong'):add(c,override=override)
    for fault in (*range(1,13),15,16,17):add(good[(fault-1)%3],fault=fault)
    for phase in range(1,15):add(good[(phase-1)%3],abort=phase,jid=400+phase);add(good[(phase-1)%3],jid=400+phase)
    assert len(rows)==118
    return rows


def nist_verify_cases():
    rows=full_verify_cases()[:45]
    assert len(rows)==45 and all(c['origin']=='NIST_Verify' and c['op']==2 and not(c['fault'] or c['abort'] or c['code']) for c in rows)
    return rows


def nist_verify_expected_artifact(token):
    # Published testPassed verdicts; this file never feeds the RTL.
    rows=nist_verify_cases()
    return f'{token} {len(rows)}\n'+''.join(f"{c['i']} {c['p']} {c['tc']} {int(c['official'])}\n" for c in rows)


def full_verify_artifact(token,nist=False):
    rows=nist_verify_cases() if nist else full_verify_cases()
    return f'{token} {len(rows)}\n'+''.join(' '.join(str(c[n]) for n in ('i','op','p','id','fault','abort','code','stage','detail','ctxlen','mlen','siglen'))+
        f" {c['rnd'][::-1].hex()} {c['xi'][::-1].hex()} "+(c['sk'] if c['op']==1 else c['pk']).hex()+' '+(c['sig'].hex() if c['op']==2 else '-')+' '+((c['ctx']+c['msg']).hex() or '-')+'\n' for c in rows)


def full_verify_frame(c,frame):
    data=(c['sk'],c['ctx']+c['msg'])[frame] if c['op']==1 else (c['pk'],c['sig'],c['ctx']+c['msg'])[frame]
    rows=[]
    for w in range((len(data)+7)//8):
        part=data[8*w:8*w+8];size=len(part);last=int(8*(w+1)>=len(data));index=w
        fault=c['fault']-4*frame
        if fault==1 and w==0:index=1024
        if fault==2 and w==0:size=0
        if fault==3 and w==0:last=1
        if fault==4 and last:last=0
        rows.append(['I',str(c['i']),str(frame),str(index),str(size),str(last),f"{int.from_bytes(part+bytes([255])*(8-len(part)),'little'):016x}"])
    return rows


def full_verify_decode(c,kind):
    fault=c['fault']-4*kind;proxy=dict(i=c['i'],kind=kind,p=c['p'],data=c['pk'] if kind==0 else c['sig'],declared=len(c['pk']) if kind==0 else c['siglen'],fw=0 if fault in (1,2,3) else (len(c['sig' if kind else 'pk'])-1)//8 if fault==4 else -1,
        fault=1 if fault==1 else 2 if fault==2 else 3 if fault in (3,4) else 0)
    return verify_decode_gold(proxy)


def full_verify_expected(c):
    if c['op']!=2 or c['code'] or c['p']==3 or c['siglen']!=len(c['sig']):return False
    if full_verify_decode(c,1)[0]!=0:return False
    return verify_equation_material(c['p'],c['pk'],c['sig'],c['ctx'],c['msg'])['accept']


def check_full_verify_c():
    count=valid=invalid=0
    for p,level in enumerate((2,3,5)):
        unique={(c['pk'],c['sig'],c['ctx'],c['msg']) for c in full_verify_cases() if c['p']==p and c['op']==2 and c['code']==0 and c['siglen']==len(c['sig'])}
        for pk,sig,ctx,msg in sorted(unique):
            cmd=' '.join(map(str,[2,len(pk),len(sig),len(ctx),len(msg),*pk,*sig,*ctx,*msg]))+'\n'
            answer=subprocess.run([str(HERE/f'reference_build/verify_reference_{level}.exe')],input=cmd,check=True,capture_output=True,text=True).stdout.strip()
            _,_,h,norm=verify_unpack_math(1,p,sig);expected=False if h is None or norm else verify_equation_material(p,pk,sig,ctx,msg)['accept']
            if answer!=f'V {int(expected)}':raise ValueError('Full Verify Python/C verdict disagreement')
            count+=1;valid+=expected;invalid+=not expected
    for c in full_verify_cases():
        if c['origin']=='NIST_Verify' and full_verify_expected(c)!=c['official']:raise ValueError('Full Verify oracle/NIST disagreement')
    message=f'C_PYTHON_FULL_VERIFY_PASS:{count} distinct inputs/{valid} valid/{invalid} invalid;all45 official pure verdicts agree (9 valid/36 invalid);main RTL still requires capture/compare\n'
    (HERE/'stage5_full_verify_c_reference.log').write_text(message);print(message,end='')


def verify_full_verify(lines,token=None,nist=False):
    if token is None:_,token=check()
    if not lines or lines[0]!='H '+token:raise ValueError('Full Verify stale capture')
    shapes={'C':10,'I':7,'KEY':8,'SIG':7,'LD':6,'LC':8,'CH':8,'Y':9,'K':6,'T':4,'Q':8,'B':5,'O':7,'G':5,'J':11,'S':5,'H':6,'N':10,'ND':6,'P':10,'PD':5,'PC':6,'V':6,'E':8,'PKD':5,'R':11,'A':10,'W':7,'M':6,'F':3,'REFUSE':3,'D':10,'Z':8,'ENDCASE':3}
    position=1;totals=[0]*13;valid=invalid=errors=official=0;peak=[0,0,0];verify_peak=[0,0,0];checked_keys=checked_signatures=0
    for c in (nist_verify_cases() if nist else full_verify_cases()):
        i,p=c['i'],c['p'];events=[]
        while position<len(lines) and not lines[position].startswith('END '):
            f=lines[position].split()
            if not f or f[0] not in shapes or len(f)!=shapes[f[0]]:raise ValueError(f'Full Verify shape at{position}: {f[:3]}')
            if int(f[1])>i:break
            if int(f[1])!=i:raise ValueError('Full Verify case order')
            events.append(f);position+=1
        def ev(tag):return [f for f in events if f[0]==tag]
        def require(ok,why):
            if not ok:raise ValueError(f'Full Verify case{i}: '+why)
        require(events and events[0][0]=='C' and ev('C')==[['C',str(i),str(c['op']),str(p),str(c['id']),str(c['ctxlen']),str(c['mlen']),str(c['siglen']),c['rnd'][::-1].hex(),c['xi'][::-1].hex()]],'accepted command snapshot')
        frames=[full_verify_frame(c,j) for j in range(2 if c['op']==1 else 3)] if c['op'] in (1,2) else []
        seen=[0]*len(frames);previous_frame=0
        for f in ev('I'):
            frame=int(f[2]);require(frames and 0<=frame<len(frames) and frame>=previous_frame and seen[frame]<len(frames[frame]) and f==frames[frame][seen[frame]],'actual input frame data/index/bytes/last')
            if frame>previous_frame:require(seen[previous_frame]==len(frames[previous_frame]),'next frame before prior last')
            previous_frame=frame;seen[frame]+=1
        material=None
        if c['op']==2 and p<3 and c['siglen']==len(c['sig']):
            sigcode=full_verify_decode(c,1)[0]
            _,_,h,norm=verify_unpack_math(1,p,c['sig'])
            if h is not None and not norm:material=verify_equation_material(p,c['pk'],c['sig'],c['ctx'],c['msg'])
        ledger={};pending=None;load=None;sample=None;ntt=None;process=None;raw={};pack=None;contexts={};handles={};takes=set();children={};packrows=0;readseq=[];wregions=[];ncounts={};keybytes=[bytearray(),bytearray()];sigbytes=bytearray()
        k,l=((4,4),(6,5),(8,7))[min(p,2)];q=8380417
        def mask():return sum(1<<r for r in ledger)
        def prepare_raw(phase):
            if phase==1:
                body=b''.join(int(f[6],16).to_bytes(8,'little') for f in ev('I') if f[2]=='0')
                return (body+bytes(max(0,len(c['pk'])-len(body))))[:len(c['pk'])]
            if phase==2:
                data=b'';body=c['ctx']+c['msg']
                for f in [f for f in ev('I') if f[2]=='2']:
                    index,n,last=map(int,f[3:6]);expected=min(8,len(body)-len(data))
                    if index*8!=len(data) or n!=expected or last!=int(len(data)+expected==len(body)):break
                    data+=int(f[6],16).to_bytes(8,'little')[:n]
                data+=bytes(len(body)-len(data))
                return hashlib.shake_256(c['pk']).digest(64)+b'\0'+bytes([len(c['ctx'])])+data
            require(material is not None,'equation hash only on structural-valid input');return material['mu']+material['packed']
        for f in events:
            tag=f[0]
            if tag=='LD':
                kind,jid,base,n=map(int,f[2:]);require(c['op']==2 and load is None and kind in (0,1) and (jid,base,n)==(c['id'],0 if kind==0 else k,len(c['pk']) if kind==0 else c['siglen']),'frame loader descriptor')
                gold=full_verify_decode(c,kind);load=dict(kind=kind,gold=gold,base=base,regions=sum(1<<r for r in range(base,base+(k if kind==0 else k+l))))
            elif tag=='LC':
                kind,jid,code=int(f[2]),int(f[3]),int(f[4]);require(load is not None and kind==load['kind'] and jid==c['id'] and code==load['gold'][0],'frame loader completion code')
                require(int(f[5],16)==(load['regions'] if code==0 else 0) and int(f[6])==(len(load['gold'][1]) if code==0 else 0) and int(f[7],16)==(int.from_bytes(load['gold'][1],'little') if code==0 else 0),'frame header/mask publication');load=None
            elif tag=='J':
                phase,row,col,core,jid,mode,param,r,n=map(int,f[2:]);require(material is not None and sample is None and phase in (2,3) and (jid,param)==(c['id'],p) and core in (0,1),'sampler ownership/identity')
                require((mode,n)==((3,(32,48,64)[p]) if phase==2 else (0,34)),'sampler mode/length')
                message=material['ctilde'] if phase==2 else material['rho']+bytes([col,row]);values=material['c'] if phase==2 else material['matrix'][row][col]
                sample=dict(phase=phase,core=core,region=r,message=message,words=0);pending=dict(r=r,values=values,mode=mode,domain=int(mode==0),rewrite=0,compute=0)
            elif tag=='S':
                phase,index,value=int(f[2]),int(f[3]),int(f[4],16);require(sample is not None and phase==sample['phase'] and index==sample['words'] and index<(len(sample['message'])+7)//8 and value==int.from_bytes(sample['message'][8*index:8*index+8].ljust(8,b'\0'),'little'),'sampler seed bytes/index');sample['words']+=1
            elif tag=='H':
                require(sample is not None and list(map(int,f[2:]))==[sample['phase'],sample['core'],c['id'],0] and sample['words']==(len(sample['message'])+7)//8 and len(ledger[sample['region']]['values'])==256,'sample retirement');sample=None
            elif tag=='N':
                phase,op,a,b,d,aid,bid,jid=map(int,f[2:]);require(phase in (2,3) and ntt is None and process is None and (aid,bid,jid)==(c['id'],0 if phase==2 else c['id'],c['id']) and a in ledger and ledger[a]['complete'] and d not in ledger,'NTT source and destination lease')
                require((phase==2 and op in (0,3) and ledger[a]['domain']==0) or (phase==3 and op in (1,2) and ledger[a]['domain']==1),'NTT operation/domain')
                if op==2:require(b in ledger and ledger[b]['complete'] and ledger[b]['domain']==1,'PWM second source')
                if op==3:require(all(v in (0,1,q-1) for v in ledger[a]['values']),'Pre-NTT challenge eligibility')
                values=ntt_reference.forward(ledger[a]['values']) if op in (0,3) else ntt_reference.inverse(ledger[a]['values']) if op==1 else [x*y%q for x,y in zip(ledger[a]['values'],ledger[b]['values'],strict=True)]
                pending=dict(r=d,values=values,mode=ledger[a]['mode'],domain=int(op!=1),rewrite=0,compute=1);ntt=dict(phase=phase,op=op,a=a,b=b,d=d);ncounts[phase,op]=ncounts.get((phase,op),0)+1
                if phase==3 and op==1:wregions.append(d)
            elif tag=='ND':require(ntt is not None and list(map(int,f[2:]))==[ntt['phase'],c['id'],0,ntt['d']] and ledger[ntt['d']]['complete'],'NTT retirement');ntt=None
            elif tag=='P':
                op,a,b,d,aid,bid,jid,inplace=map(int,f[2:]);require(c['op']==2 and process is None and ntt is None and op in (0,1) and inplace==1 and a==d and (aid,bid,jid)==(c['id'],)*3 and all(r in ledger and ledger[r]['complete'] and ledger[r]['domain']==1 for r in (a,b)),'in-place process sources/domain')
                pending=dict(r=d,values=[(x+(-y if op else y))%q for x,y in zip(ledger[a]['values'],ledger[b]['values'],strict=True)],mode=0,domain=1,rewrite=1,compute=1);process=dict(a=a,b=b,d=d)
            elif tag=='PD':require(process is not None and list(map(int,f[2:]))==[c['id'],0,process['d']] and ledger[process['d']]['complete'],'process retirement');process=None
            elif tag=='A':
                r,rewrite,compute,rawdomain,mode,param,jid=map(int,f[2:9]);domain=rawdomain if compute else int(mode==0)
                require(int(f[9],16)==mask() and (r in ledger)==bool(rewrite) and param==p and (jid==c['id'] if c['op']==2 else 0<=jid<65536),'allocation metadata/physical map')
                values=None
                if c['op']==2:
                    if load is not None:
                        ordinal=r-load['base'];values=[v for s,j,x,v,lp,lf in load['gold'][2] if ordinal==(j if load['kind']==0 or s==1 else l+j)]
                        require(0<=ordinal<(k if load['kind']==0 else k+l) and (mode,domain,rewrite,compute)==(3 if load['kind']==0 or ordinal>=l else 2,0,0,1),'frame allocation role/domain')
                    else:
                        require(pending is not None and (r,rewrite,compute,mode,domain)==(pending['r'],pending['rewrite'],pending['compute'],pending['mode'],pending['domain']),'compute/sample allocation intent');values=pending['values'];pending=None
                ledger[r]=dict(values=[],expected=values,id=jid,mode=mode,param=param,domain=domain,complete=False);peak[min(p,2)]=max(peak[min(p,2)],len(ledger))
                if c['op']==2:verify_peak[min(p,2)]=max(verify_peak[min(p,2)],len(ledger))
            elif tag=='W':
                r,jid,index,value,last=int(f[2]),int(f[3]),int(f[4]),int(f[5],16),int(f[6]);require(c['op']==2 and r in ledger and not ledger[r]['complete'] and jid==ledger[r]['id'] and index==len(ledger[r]['values']) and index<len(ledger[r]['expected']) and value==ledger[r]['expected'][index] and last==int(index==255),'exact decoded/sampled/NTT/process coefficient');ledger[r]['values'].append(value)
            elif tag=='M':
                r,jid,code,n=map(int,f[2:]);require(r in ledger and not ledger[r]['complete'] and jid==ledger[r]['id'] and 0<=n<=256,'memory finish ownership')
                if c['op']==2:require(n==len(ledger[r]['values']),'finish exact written count')
                if code==0:require(n==256,'full commit');ledger[r]['complete']=True
                else:require(code==1 and c['op']==2 and load is not None,'discard only current failed frame');del ledger[r]
            elif tag=='F':
                r=int(f[2]);require(r in ledger and ledger[r]['complete'],'release complete owned lease')
                if ntt:require(r not in (ntt['a'],ntt['d']) and (ntt['op']!=2 or r!=ntt['b']),'release after NTT retirement')
                if process:require(r not in process.values(),'release after process retirement')
                del ledger[r]
            elif tag=='Y':
                phase,param,jid=int(f[2]),int(f[3]),int(f[4]);require(phase not in contexts and phase in (1,2) and param==p and jid in ((c['id'],0xf00d) if c['fault']==14+phase else (c['id'],)),'context identity/publication')
                require(int(f[5],16)==mask() and int(f[6],16)==int.from_bytes(c['pk'][:32],'little') and int(f[7],16)==int.from_bytes(hashlib.shake_256(c['pk']).digest(64) if phase==1 else material['mu'],'little') and int(f[8],16)==int.from_bytes(c['sig'][:(32,48,64)[p]],'little'),'exact context headers/mask');contexts[phase]=int(f[5],16)
            elif tag=='K':
                phase,section,poly,r=map(int,f[2:]);require(phase in contexts and (phase,section,poly) not in handles and r in ledger and ledger[r]['complete'],'unique committed context handle')
                if phase==1:
                    values=verify_unpack_math(0,p,c['pk'])[1][256*poly:256*(poly+1)] if section==0 else verify_unpack_math(1,p,c['sig'])[1 if section==1 else 2][256*poly:256*(poly+1)];domain=0
                else:values=material['t1hat'][poly] if section==0 else material['zhat'][poly] if section==1 else material['raw'][k+l+poly] if section==2 else material['chat'];domain=int(section!=2)
                require(ledger[r]['values']==values and ledger[r]['domain']==domain,'exact published polynomial/domain');handles[phase,section,poly]=r
            elif tag=='T':
                phase=int(f[2]);require(phase in (2,3) and phase not in takes and phase-1 in contexts and int(f[3],16)==contexts[phase-1],'one atomic context take');takes.add(phase)
            elif tag=='CH':
                phase,jid,code,detail,accept=map(int,f[2:7]);require(phase not in children and phase in (1,2,3) and jid==(0xf00d if c['fault']==14+phase else c['id']),'child completion metadata')
                expected=(0,0)
                if phase==1:
                    pkcode=full_verify_decode(c,0)[0];sgcode=full_verify_decode(c,1)[0]
                    expected=(4,pkcode) if pkcode else (5,sgcode) if sgcode else (0,0)
                elif phase==2 and 9<=c['fault']<=12:expected=(3,2)
                require((code,detail)==expected,'child completion status')
                require(accept==(int(material['accept']) if phase==3 else 0) and int(f[7],16)==(int.from_bytes(material['digest'],'little') if phase==3 else 0),'child exact equation digest/verdict');children[phase]=code
            elif tag=='Q':
                phase,core,jid,mode,n,out=map(int,f[2:]);require(phase in (1,2,3) and phase not in raw and (jid,mode,n,out)==(c['id'],1,len(prepare_raw(phase)),(32,48,64)[p] if phase==3 else 64) and core in (0,1),'raw descriptor/stage')
                raw[phase]=dict(core=core,words=[],beats=0,done=False)
            elif tag=='B':
                phase,index,value=int(f[2]),int(f[3]),int(f[4],16);require(phase in raw and index==len(raw[phase]['words']),'raw input index');raw[phase]['words'].append(value.to_bytes(8,'little'))
            elif tag=='O':
                phase,core,jid,n,value=int(f[2]),int(f[3]),int(f[4]),int(f[5]),int(f[6],16);require(phase in raw and (core,jid,n)==(raw[phase]['core'],0xf00d if c['abort']==13 and phase==2 else c['id'],16),'raw digest identity/width')
                a=raw[phase];message=prepare_raw(phase);require(b''.join(a['words'])[:len(message)]==message and len(a['words'])==(len(message)+7)//8,'full independent absorption before squeeze')
                out=(32,48,64)[p] if phase==3 else 64;digest=hashlib.shake_256(message).digest(out);require(a['beats']<out//16 and value==int.from_bytes(digest[16*a['beats']:16*(a['beats']+1)],'little'),'exact raw digest');a['beats']+=1
            elif tag=='G':
                phase,core,jid=map(int,f[2:]);require(phase in raw and not raw[phase]['done'] and (core,jid)==(raw[phase]['core'],c['id']) and raw[phase]['beats']==((2,3,4)[p] if phase==3 else 4),'raw retirement');raw[phase]['done']=True
            elif tag=='PC':
                row,jid,op,param=map(int,f[2:]);require(pack is None and row==packrows<k and (jid,op,param)==(c['id'],3,p),'packer command');pack=dict(row=row,values=[],words=0);packrows+=1
            elif tag=='V':
                row,index,value,last=int(f[2]),int(f[3]),int(f[4],16),int(f[5]);require(pack is not None and row==pack['row'] and index==len(pack['values'])<256 and value==material['high'][row][index] and last==int(index==255),'UseHint exact scalar');pack['values'].append(value)
            elif tag=='E':
                row,jid,index,n,last,value=int(f[2]),int(f[3]),int(f[4]),int(f[5]),int(f[6]),int(f[7],16);words=24 if p==0 else 16
                require(pack is not None and (row,jid,index,n,last)==(pack['row'],c['id'],pack['words'],8,int(pack['words']==words-1)) and index<words and len(pack['values'])*(6 if p==0 else 4)>=64*(index+1) and value==int.from_bytes(material['packed'][(row*words+index)*8:(row*words+index+1)*8],'little'),'exact packed w1 bytes');pack['words']+=1
            elif tag=='PKD':require(pack is not None and list(map(int,f[2:]))==[pack['row'],c['id'],0] and len(pack['values'])==256 and pack['words']==(24 if p==0 else 16),'packer retirement');pack=None
            elif tag=='R':
                r,w,jid,mode,param,domain,small,error=map(int,f[2:10]);require(r in ledger and ledger[r]['complete'] and (jid,mode,param,domain,small,error)==(ledger[r]['id'],ledger[r]['mode'],p,0,int(all(v<=4 or v>=q-4 for v in ledger[r]['values'])),0) and int(f[10],16)==sum(v<<(23*j) for j,v in enumerate(ledger[r]['values'][4*w:4*w+4])),'exact packed W/h read');readseq.append((r,w))
                ordinal=len(readseq)-1;row=ordinal//128;word=(ordinal//2)%64
                require(pack is not None and row==pack['row'] and row<len(wregions) and (r,w)==(handles[2,2,row] if ordinal%2 else wregions[row],word),'W/h alternating handle and word order')
            elif tag in ('KEY','SIG'):
                if tag=='KEY':
                    jid,kind,index,n,last=map(int,f[2:7]);expected=(c['pk'],c['sk'])[kind];require(c['op']==0 and jid==c['id'] and kind in (0,1) and index*8==len(keybytes[kind]) and n==8 and last==int(len(keybytes[kind])+8==len(expected)) and int(f[7],16).to_bytes(8,'little')==expected[len(keybytes[kind]):len(keybytes[kind])+8],'mixed KeyGen exact bytes');keybytes[kind]+=int(f[7],16).to_bytes(8,'little')
                else:
                    jid,index,n,last=map(int,f[2:6]);expected=full_sign_reference()[0];octets=int(f[6],16).to_bytes(8,'little');require(c['op']==1 and jid==c['id'] and index*8==len(sigbytes) and n==min(8,len(expected)-len(sigbytes)) and last==int(len(sigbytes)+n==len(expected)) and octets[:n]==expected[len(sigbytes):len(sigbytes)+n] and not any(octets[n:]),'mixed Sign exact bytes');sigbytes+=octets[:n]
            elif tag=='D':
                require(not c['abort'] and list(map(int,f[2:6]))==[c['id'],c['code'],c['stage'],c['detail']] and int(f[6])==int(full_verify_expected(c)),'main completion/verdict')
                require(int(f[7],16)==mask() and int(f[8],16)==sum(1<<r for r,a in ledger.items() if a['complete']) and int(f[9])==0 and (c['op']==0 or mask()==0),'main cleanup before verdict')
            elif tag=='Z':
                require(c['abort'] and list(map(int,f[2:6]))==[c['abort'],7,14 if c['abort']==11 else 15 if c['abort'] in (13,14) else {1:2,2:2,3:5,4:3,5:5,6:5,7:6,8:8,9:8,10:8,12:8}[c['abort']],int(c['abort'] in (13,14))] and int(f[6],16)==mask(),'reset/fatal phase ownership')
                complete=sum(1<<r for r,a in ledger.items() if a['complete'])
                if ntt:complete&=~(1<<ntt['a']);complete&=~(1<<ntt['b']) if ntt['op']==2 else (1<<64)-1
                if process:complete&=~(1<<process['a']);complete&=~(1<<process['b'])
                if load:complete&=~load['regions']
                require(int(f[7],16)==complete,'reset/fatal exact visible complete map')
        for phase,a in raw.items():
            message=prepare_raw(phase);expected=[message[j:j+8].ljust(8,b'\0') for j in range(0,len(message),8)];require(a['words']==expected[:len(a['words'])],'raw input prefix/tail/zero drain')
            if not c['abort']:require(a['done'] and a['words']==expected,'raw request fully retired')
        if c['abort']:
            require(len(ev('Z'))==1 and not ev('D') and not ev('ENDCASE') and events[-1][0]=='Z','bounded reset/fault abort')
            if c['abort'] in (1,2,3):require(seen[c['abort']-1]==(3 if c['abort']==3 else 9),'exact accepted-frame reset prefix')
            if c['abort'] in (4,7):require(c['abort']//3 in contexts,'published context handoff reset')
            if c['abort'] in (5,6,8,9):require(any(not a['complete'] and len(a['values'])==17 for a in ledger.values()),'partial polynomial reset boundary')
            if c['abort']==10:require(pack is not None and len(pack['values'])==17,'packer input reset boundary')
            if c['abort'] in (11,12):require(3 in raw and raw[3]['done'] and children.get(2)==0,'verdict/cleanup after equation hash retirement')
        else:
            require(len(ev('D'))==1 and ev('REFUSE')==[['REFUSE',str(i),'4']] and ev('ENDCASE')==[['ENDCASE',str(i),'0']] and events[-1][0]=='ENDCASE' and not ledger and not ev('Z'),'final ownership/held-completion refusal')
            require(load is None and sample is None and ntt is None and process is None and pack is None and pending is None,'retired children/allocations')
            if c['op']==2 and c['code']==0:
                accept=full_verify_expected(c);valid+=accept;invalid+=not accept
                if c['origin']=='NIST_Verify':require(accept==c['official'],'published NIST verdict');official+=1
                if material is not None and c['siglen']==len(c['sig']):
                    require(set(children)=={1,2,3} and takes=={2,3} and set(raw)=={1,2,3} and seen==list(map(len,frames)) and ncounts=={(2,0):k+l,(2,3):1,(3,2):k*(l+1),(3,1):k} and packrows==k and len(readseq)==128*k,'whole main Verify chain/frames/Pre-NTT/equation')
                    for phase in (1,2):require({s:sum(1 for a,b,j in handles if a==phase and b==s) for s in range(4)}==({0:k,1:l,2:k,3:0} if phase==1 else {0:k,1:l,2:k,3:1}),'complete context handle set')
                elif c['siglen']==len(c['sig']):require(children=={1:5} and not takes and set(raw)=={1} and not ev('N') and not ev('J'),'structural invalid signature stops before arithmetic')
                else:require(not any(ev(t) for t in ('I','A','LD','J','N','Q','CH')),'wrong signature length rejects before input')
            elif c['code']:errors+=1
            if c['op']==0:require([bytes(b) for b in keybytes]==[c['pk'],c['sk']] and not sigbytes,'complete mixed KeyGen');checked_keys+=1
            elif c['op']==1:require(bytes(sigbytes)==full_sign_reference()[0] and not any(keybytes),'complete mixed Sign');checked_signatures+=1
        for col,tags in ((0,('C',)),(1,('D',)),(2,('Z',)),(3,('I',)),(4,('A',)),(5,('W',)),(6,('M',)),(7,('F',)),(8,('N',)),(9,('P',)),(10,('R',)),(11,('B',)),(12,('O',))):totals[col]+=sum(len(ev(t)) for t in tags)
    if position!=len(lines)-1 or lines[position]!='END '+' '.join(map(str,totals)):raise ValueError('Full Verify footer/trailing event')
    if nist and (totals[0],valid,invalid,errors,totals[2],official)!=(45,9,36,0,0,45):raise ValueError('Official Verify qualification count')
    marker='STAGE6_NIST_VERIFY' if nist else 'STAGE5V4_FULL_VERIFY'
    return f'{marker}_COMPARE_PASS:{totals[0]} commands/{valid} valid/{invalid} invalid/{errors} expected errors/{totals[2]} resets-faults;official{official}/45 verdicts agree;{checked_keys} mixed KeyGen/{checked_signatures} mixed Sign;{totals[5]} exact Verify writes/{totals[10]} reads;Verify private peaks{verify_peak};whole-campaign peaks{peak}\n'


def check_verify_c():
    gcc=shutil.which('gcc');ref=ROOT/'dilithium-sw-model/ref';build=HERE/'reference_build';count=coeffs=valid=invalid=hashes=0
    if not gcc:raise ValueError('GCC required for Verify reference')
    for p,level in enumerate((2,3,5)):
        exe=build/f'verify_reference_{level}.exe'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ref),str(ROOT/'tb/tb_dilithium/reference/verify_reference.c'),
            *[str(ref/n) for n in ('sign.c','packing.c','polyvec.c','poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],check=True,capture_output=True,text=True)
        unique={(c['kind'],c['data']) for c in verify_decode_cases() if c['p']==p}
        for kind,data in sorted(unique):
            answer=subprocess.run([str(exe)],input=' '.join(map(str,[kind,len(data),*data]))+'\n',check=True,capture_output=True,text=True).stdout.split()
            expected=(1312,1952,2592)[p] if kind==0 else (2420,3309,4627)[p]
            if len(data)!=expected:
                if answer!=['D','1']:raise ValueError('C decoder length')
                continue
            header,z,h,norm=verify_unpack_math(kind,p,data)
            gold=['P',header.hex(),*map(str,z)] if kind==0 else ['S',str(int(h is None)),str(int(norm)),header.hex(),*map(str,z),*map(str,h or [])]
            if answer!=gold:raise ValueError('Python/C Verify decoder disagreement')
            count+=1;coeffs+=len(z)+len(h or [])
        for c in [c for c in nist_verify_corpus()[0] if c['p']==p]:
            answer=subprocess.run([str(exe)],input=' '.join(map(str,[2,len(c['pk']),len(c['sig']),len(c['ctx']),len(c['msg']),*c['pk'],*c['sig'],*c['ctx'],*c['msg']]))+'\n',check=True,capture_output=True,text=True).stdout.strip()
            if answer!=f"V {int(c['valid'])}":raise ValueError(f"C disagrees with NIST Verify tc{c['tc']}")
            valid+=c['valid'];invalid+=not c['valid']
        for pk in sorted({c['pk'] for c in verify_prepare_cases() if c['p']==p and len(c['pk'])==(1312,1952,2592)[p]}):
            answer=subprocess.run([str(exe)],input=' '.join(map(str,[3,len(pk),*pk]))+'\n',check=True,capture_output=True,text=True).stdout.strip()
            if answer!='T '+hashlib.shake_256(pk).digest(64).hex():raise ValueError('C/Python Verify public-key hash disagreement')
            hashes+=1
    message=f'PYTHON_C_VERIFY_DECODE_PASS:{count} distinct frames/{coeffs} coefficients;unchanged unpack_pk/unpack_sig/CNB. NIST_C_VERIFY_PASS:45/45 official pure verdicts,{valid} valid/{invalid} invalid;software only,not main RTL Verify\n'
    (HERE/'stage5_verify_c_reference.log').write_text(message);print(message,end='')
    message=f'PYTHON_C_VERIFY_PK_HASH_PASS:{hashes} distinct public keys/64-byte tr each;unchanged production SHAKE256\n'
    (HERE/'stage5_verify_prepare_c_reference.log').write_text(message);print(message,end='')
    count=values=0
    for p,level in enumerate((2,3,5)):
        unique={(c['pk'],c['sig'],c['ctx'],c['msg']) for c in verify_math_cases() if c['p']==p}
        for pk,sig,ctx,msg in sorted(unique):
            data=verify_math_material(p,pk,sig,ctx,msg)
            answer=subprocess.run([str(build/f'verify_reference_{level}.exe')],input=' '.join(map(str,[4,len(pk),len(sig),len(ctx),len(msg),*pk,*sig,*ctx,*msg]))+'\n',check=True,capture_output=True,text=True).stdout.split()
            polys=data['t1hat']+data['zhat']+[data['chat']];gold=['U',data['mu'].hex(),*map(str,data['c']),*map(str,[v for a in polys for v in a])]
            if answer!=gold:raise ValueError('Python/C Verify mu/challenge/NTT disagreement')
            count+=1;values+=256+sum(map(len,polys))
    message=f'PYTHON_C_VERIFY_MATH_PASS:{count} distinct inputs/mu digests/{values} challenge-and-NTT coefficients;unchanged SHAKE256,poly_challenge,poly_shiftl,poly_ntt\n'
    (HERE/'stage5_verify_math_c_reference.log').write_text(message);print(message,end='')
    count=coeffs=valid=invalid=unit_count=0
    for p,level in enumerate((2,3,5)):
        exe=str(build/f'verify_reference_{level}.exe');units=[a for a in use_hint_cases() if a[0]==p and a[3]==0]
        answer=subprocess.run([exe],input=''.join(f'6 {a} {h}\n' for _,a,h,_,_ in units),check=True,capture_output=True,text=True).stdout.splitlines()
        if answer!=[f'H {high}' for _,_,_,_,high in units]:raise ValueError('Python/C UseHint boundary disagreement')
        unit_count+=len(units)
        unique={(c['pk'],c['sig'],c['ctx'],c['msg']) for c in verify_equation_cases() if c['p']==p}
        for pk,sig,ctx,msg in sorted(unique):
            a=verify_equation_material(p,pk,sig,ctx,msg)
            answer=subprocess.run([exe],input=' '.join(map(str,[5,len(pk),len(sig),len(ctx),len(msg),*pk,*sig,*ctx,*msg]))+'\n',check=True,capture_output=True,text=True).stdout.split()
            values=[v for row in a['matrix'] for poly in row for v in poly]+[v for poly in a['w']+a['high'] for v in poly]
            gold=['E',a['mu'].hex(),a['digest'].hex(),str(int(a['accept'])),*map(str,values),a['packed'].hex()]
            if answer!=gold:raise ValueError('Python/C Verify equation/UseHint/packing/digest disagreement')
            count+=1;coeffs+=len(values)
        for c in [c for c in verify_equation_cases() if c['p']==p and c['origin']=='NIST_Verify']:
            verdict=verify_equation_material(p,c['pk'],c['sig'],c['ctx'],c['msg'])['accept']
            if verdict!=c['official']:raise ValueError('Derived equation disagrees with published NIST verdict')
            valid+=verdict;invalid+=not verdict
    message=f'PYTHON_C_VERIFY_EQUATION_PASS:{count} distinct inputs/{coeffs} matrix-equation-UseHint coefficients;{unit_count} valid UseHint boundary inputs;original35 official verdicts{valid} valid/{invalid} invalid agree;remaining10 malformed official cases belong to prior gates\n'
    (HERE/'stage5_verify_equation_c_reference.log').write_text(message);print(message,end='')
    check_full_verify_c()


@lru_cache(maxsize=1)
def nist_sign_corpus(include_internal=False):
    """Audit all360 original cases; select only supported external pure signing.

    ACVP 'external' means the public Sign API, NOT externally supplied mu.
    Deterministic signing supplies all-zero rnd; randomized signing uses the
    original prompt's rnd. Expected bytes always come from NIST, never C/RTL.
    """
    objects={}
    for name in NIST_SIGN_HASHES:
        obj=json.loads((NIST_SIGN/name).read_text(encoding='utf-8-sig'))
        if (obj['algorithm'],obj['mode'],obj['revision'],obj['vsId'],obj['isSample'])!=('ML-DSA','sigGen','FIPS204',42,False):
            raise ValueError('Wrong NIST Sign metadata')
        objects[name]=obj
    expected={}
    for g in objects['expectedResults.json']['testGroups']:
        for t in g['tests']:
            key=(g['tgId'],t['tcId'])
            if key in expected:raise ValueError('Duplicate NIST Sign expected case')
            expected[key]=bytes.fromhex(t['signature'])
    result=[];seen=set();counts=[[0,0] for _ in range(3)];reasons={}
    audit=['tgId,tcId,parameterSet,deterministic,signatureInterface,preHash,externalMu,message_bytes,context_bytes,selection']
    groups=objects['prompt.json']['testGroups']
    for g in groups:
        if g['testType']!='AFT' or type(g['deterministic']) is not bool or len(g['tests'])!=15:
            raise ValueError('NIST Sign group schema')
        p=('ML-DSA-44','ML-DSA-65','ML-DSA-87').index(g['parameterSet'])
        if g['signatureInterface']=='external':
            if g.get('preHash') not in ('pure','preHash'):raise ValueError('Unknown NIST prehash mode')
            reason='selected' if g['preHash']=='pure' else 'unsupported_prehash'
        elif g['signatureInterface']=='internal' and type(g.get('externalMu')) is bool:
            reason='unsupported_external_mu' if g['externalMu'] else 'unsupported_internal_message_API'
        else:raise ValueError('Unknown NIST signing interface')
        if include_internal and g['signatureInterface']=='internal' and g.get('externalMu') is False:reason='selected'
        for t in g['tests']:
            key=(g['tgId'],t['tcId'])
            if key in seen or key not in expected:raise ValueError('NIST Sign input/answer identity')
            seen.add(key);sig=expected[key];sk=bytes.fromhex(t['sk'])
            if (len(sk),len(sig))!=((2560,2420),(4032,3309),(4896,4627))[p]:raise ValueError('NIST Sign key/signature size')
            if g['deterministic']:
                if 'rnd' in t:raise ValueError('Unexpected deterministic randomness')
                rnd=bytes(32)
            else:
                rnd=bytes.fromhex(t['rnd'])
                if len(rnd)!=32:raise ValueError('NIST Sign rnd size')
            msg=bytes.fromhex(t['message']) if 'message' in t else b''
            ctx=bytes.fromhex(t['context']) if 'context' in t else b''
            if len(ctx)>255:raise ValueError('NIST context size')
            if reason=='selected' and (64 if g['signatureInterface']=='internal' else 66)+len(ctx)+len(msg)>65535:raise ValueError('Supported NIST message exceeds descriptor')
            reasons[reason]=reasons.get(reason,0)+1
            audit.append(','.join(map(str,[*key,g['parameterSet'],int(g['deterministic']),g['signatureInterface'],g.get('preHash',''),
                g.get('externalMu',''),len(msg),len(ctx),reason])))
            if reason!='selected':continue
            counts[p][int(not g['deterministic'])]+=1
            result.append(dict(i=len(result),op=1,p=p,id=t['tcId'],flavor=-1,fault=0,abort=0,code=0,stage=0,detail=0,
                ctx=ctx,msg=msg,rnd=rnd,ctxlen=len(ctx),mlen=len(msg),xi=bytes(32),sk=sk,body=ctx+msg,
                signature=sig,tg=key[0],tc=key[1],deterministic=g['deterministic'],internal=g['signatureInterface']=='internal'))
    if seen!=set(expected) or counts!=[[30,30] if include_internal else [15,15]]*3:
        raise ValueError('Incomplete NIST Sign selection/audit')
    return result,'\n'.join(audit)+'\n'


def nist_sign_cases(include_internal=False):return nist_sign_corpus(include_internal)[0]


def nist_sign_expected_artifact(token):
    rows=nist_sign_cases()
    return f'{token} {len(rows)}\n'+''.join(f"{c['i']} {c['tg']} {c['tc']} {c['p']} {int(c['deterministic'])} {c['signature'].hex()}\n" for c in rows)


def check_nist_sign_c():
    rows=nist_sign_cases()
    for p,level in enumerate((2,3,5)):
        selected=[c for c in rows if c['p']==p]
        answer=subprocess.run([str(HERE/f'reference_build/full_sign_reference_{level}.exe'),'--sign-only'],
            input=''.join(' '.join(map(str,[c['ctxlen'],c['mlen'],*c['rnd'],*c['sk'],*c['body']]))+'\n' for c in selected),
            check=True,capture_output=True,text=True).stdout.splitlines()
        if len(answer)!=len(selected):raise ValueError('NIST/C Sign count')
        for c,line in zip(selected,answer,strict=True):
            if bytes.fromhex(line)!=c['signature']:raise ValueError(f"C differs from NIST Sign tgId{c['tg']} tcId{c['tc']}")
    message=f'NIST_C_SIGN_PASS:90/90 published signatures/{sum(len(c["signature"]) for c in rows)} bytes;15 deterministic+15 randomized per level;270 unsupported cases audited;original SK/ctx/message/rnd only,no expected input,no PK/Verify claim\n'
    (HERE/'stage5_nist_sign_c_reference.log').write_text(message);print(message,end='')


@lru_cache(maxsize=1)
def full_sign_cases():
    rows=[]
    def add(p=0,flavor=0,op=1,fault=0,abort=0,override='',jid=None):
        sourcep=min(p,2);m=sign_matrix_material(sourcep,0);key=next(c for c in nist_keygen_cases() if c['p']==sourcep)
        ctx,msg,rnd=((m['body'][:7],m['body'][7:],m['rnd']),
            (b'',b'',bytes(32)),(bytes(range(255)),b'\xa5',hashlib.sha256(bytes([sourcep])).digest()),
            (b'',b'\x5a',bytes([sourcep+1])*32))[flavor]
        code=2 if op>=2 else 1 if p==3 or override else 3 if 1<=fault<=5 else 4 if fault else 0
        i=len(rows);rows.append(dict(i=i,op=op,p=p,id=(60000+i)&65535 if jid is None else jid,flavor=flavor,
            fault=fault,abort=abort,code=code,stage=1 if code==3 else 2 if code==4 else 0,detail=4 if code==3 else 2 if code==4 else 0,
            ctx=ctx,msg=msg,rnd=rnd,ctxlen=256 if override=='ctx' else len(ctx),mlen=65535 if override=='length' else len(msg),
            xi=key['xi'],pk=key['pk'],sk=key['sk'],body=ctx+msg))
    for p in range(3):
        for f in range(4):add(p,f,jid=65535 if p==2 and f==3 else 0 if p==1 and f==1 else None)
        if p==0:add(op=0)
    add(p=3);add(override='ctx');add(override='length');add(op=3);add(op=3)
    for f in range(1,10):add(fault=f)
    for phase in range(1,10):add(abort=phase,jid=300+phase);add(jid=300+phase)
    assert len(rows)==45
    return rows


def full_sign_input_artifact(token,nist=False):
    rows=nist_sign_cases() if nist else full_sign_cases()
    return f'{token} {len(rows)}\n'+''.join(' '.join(str(c[k]) for k in ('i','op','p','id','flavor','fault','abort','code','stage','detail','ctxlen','mlen'))+
        f" {c['rnd'][::-1].hex()} {c['xi'][::-1].hex()} {c['sk'].hex()} {c['body'].hex() or '-'}\n" for c in rows)


@lru_cache(maxsize=1)
def full_sign_reference():
    result={};unique={}
    for c in full_sign_cases():
        if c['op']!=1 or c['code']!=0:continue
        key=(c['p'],c['flavor'])
        if key not in unique:
            exe=HERE/f"reference_build/full_sign_reference_{(2,3,5)[c['p']]}.exe"
            if not exe.is_file():raise ValueError('Run prepare to build full Sign reference')
            answer=subprocess.run([str(exe)],input=' '.join(map(str,[len(c['ctx']),len(c['msg']),*c['rnd'],*c['pk'],*c['sk'],*c['body']]))+'\n',
                check=True,capture_output=True,text=True).stdout.splitlines()
            if len(answer)!=1:raise ValueError('C full Sign result count')
            sig=bytes.fromhex(answer[0])
            if len(sig)!=(2420,3309,4627)[c['p']]:raise ValueError('C full Sign length')
            if c['flavor']==0 and sig!=signature_bytes(c['p'],sign_retry_chain(c['p'],0)[0][-1][1]):raise ValueError('Python/C full Sign disagreement')
            unique[key]=sig
        result[c['i']]=unique[key]
    return result


def build_full_sign_c():
    gcc=shutil.which('gcc');ref=ROOT/'dilithium-sw-model/ref'
    if not gcc:raise ValueError('GCC required for full Sign oracle')
    for p,level in enumerate((2,3,5)):
        exe=HERE/f'reference_build/full_sign_reference_{level}.exe'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ref),str(ROOT/'tb/tb_dilithium/reference/full_sign_reference.c'),
            *[str(ref/n) for n in ('sign.c','packing.c','polyvec.c','poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],
            check=True,capture_output=True,text=True)
    full_sign_reference.cache_clear();gold=full_sign_reference()
    unique={(c['p'],c['flavor']):gold[c['i']] for c in full_sign_cases() if c['i'] in gold}
    message=f'C_FULL_SIGN_REFERENCE_PASS:{len(unique)} distinct original-input fixtures/{sum(map(len,unique.values()))} bytes;unchanged production Sign+Verify;3 also match independent Python math;{len(gold)} Sign scenarios including abort-prefix oracles\n'
    (HERE/'stage5_full_sign_c_reference.log').write_text(message);print(message,end='')


def full_sign_expected_artifact(token):
    rows=full_sign_cases();gold=full_sign_reference()
    return f'{token} {len(rows)}\n'+''.join(f"{c['i']} "+(gold[c['i']].hex() if c['i'] in gold else '-')+'\n' for c in rows)


def full_sign_frame(c,frame):
    body=c['sk'] if frame==0 else c['body'];rows=[];fault=c['fault']
    for w in range((len(body)+7)//8):
        data=body[8*w:8*w+8];size=len(data);last=int(8*(w+1)>=len(body));index=w
        value=int.from_bytes(data+bytes([255])*(8-size),'little')
        if frame==0:
            if fault==1 and w==2:index=1026
            if fault==2 and w==0:size=0
            if fault==3 and w==17:last=1
            if fault==4 and last:last=0
            if fault==5 and w==16:value=(value&~255)|255
        else:
            if fault==6 and w==0:index=9
            if fault==7 and w==0:size=0
            if fault==8 and w==0:last=1
            if fault==9 and last:last=0
        rows.append(['I',str(c['i']),str(frame),str(index),str(size),str(last),f'{value:016x}'])
    return rows


def verify_full_sign(lines,nist=False):
    _,token=check();cases=nist_sign_cases() if nist else full_sign_cases()
    gold={c['i']:c['signature'] for c in cases} if nist else full_sign_reference()
    if not lines or lines[0]!='H '+token:raise ValueError('Full Sign freshness')
    groups={};footer=None;previous=-1
    for line in lines[1:]:
        f=line.split()
        if not f or footer is not None:raise ValueError('Full Sign empty/trailing event')
        if f[0]=='END':footer=list(map(int,f[1:]));continue
        if f[0] not in ('C','I','S','K','N','A','M','F','Z','D','B','GATE','REFUSE'):raise ValueError('Full Sign unknown event')
        i=int(f[1])
        if i<previous or i>=len(cases):raise ValueError('Full Sign case order')
        previous=i;groups.setdefault(i,[]).append(f)
    totals=[0]*9;success=errors=bytes_checked=0;peaks={0:0,1:0,2:0}
    for c in cases:
        i=c['i'];p=c['p'];events=groups.get(i,[])
        def ev(tag):return [f for f in events if f[0]==tag]
        def require(ok,text):
            if not ok:raise ValueError(f'Full Sign case{i}: '+text)
        require(ev('C')==[['C',str(i),str(c['op']),str(p),str(c['id']),str(c['ctxlen']),str(c['mlen']),c['rnd'][::-1].hex(),c['xi'][::-1].hex()]],'Accepted command metadata')
        require(events and events[0][0]=='C','Access before command')
        frames=[full_sign_frame(c,f) for f in (0,1)];inputs=ev('I');seen=[0,0];last_frame=0
        for f in inputs:
            frame=int(f[2]);require(c['op']==1 and c['code']!=1 and frame in (0,1) and frame>=last_frame,'Unexpected input/frame order')
            require(seen[frame]<len(frames[frame]) and f==frames[frame][seen[frame]],'Actual accepted frame bytes/index/last')
            if frame==1:require(seen[0]==len(frames[0]),'Message before complete key frame')
            seen[frame]+=1;last_frame=frame
        signature=bytearray();sigwords=0;siglast=False;keydata=[bytearray(),bytearray()];keylast=[False,False];keytype=0
        slots={};alloc=commit=release=0
        def mask():return sum(1<<r for r in slots)
        for f in events:
            tag=f[0]
            if tag=='S':
                require(c['op']==1 and c['code']==0 and not siglast,'Unowned/errored/extra signature')
                jid,index,size,last=map(int,f[2:6]);value=int(f[6],16);expected=gold[i]
                require(jid==c['id'] and index==sigwords and size==min(8,len(expected)-len(signature)) and last==int(len(signature)+size==len(expected)),'Signature framing')
                octets=value.to_bytes(8,'little');require(octets[:size]==expected[len(signature):len(signature)+size] and not any(octets[size:]),'Exact signature bytes/tail padding')
                signature+=octets[:size];sigwords+=1;siglast=bool(last)
            elif tag=='K':
                require(c['op']==0 and c['code']==0,'Key stream during non-KeyGen request')
                jid,kind,index,size,last=map(int,f[2:7]);value=int(f[7],16)
                require(kind in (0,1) and kind>=keytype and not keylast[kind] and jid==c['id'] and index*8==len(keydata[kind]) and size==8,'Key word framing')
                if kind:require(keylast[0],'Secret key before public key end')
                expected=(c['pk'],c['sk'])[kind];octets=value.to_bytes(8,'little')
                require(octets==expected[len(keydata[kind]):len(keydata[kind])+8] and last==int(len(keydata[kind])+8==len(expected)),'Mixed-request exact key bytes')
                keydata[kind]+=octets;keylast[kind]=bool(last);keytype=kind
            elif tag=='A':
                r,rewrite,jid,mode,param=map(int,f[2:7]);require(0<=r<64 and rewrite in (0,1) and 0<=jid<65536 and 0<=mode<=3 and param==p and int(f[7],16)==mask(),'Physical allocation metadata/map')
                require((not rewrite and r not in slots) or (rewrite and r in slots and slots[r]['complete']),'Allocation/rewrite ownership')
                slots[r]=dict(id=jid,complete=False);alloc+=1;peaks[p]=max(peaks.get(p,0),len(slots))
            elif tag=='M':
                r,jid,code,count=map(int,f[2:]);require(r in slots and not slots[r]['complete'] and jid==slots[r]['id'] and 0<=count<=256,'Physical commit ownership')
                if code==0:require(count==256,'Incomplete committed polynomial');slots[r]['complete']=True
                else:del slots[r]
                commit+=1
            elif tag=='F':
                r=int(f[2]);require(r in slots and slots[r]['complete'],'Unowned/incomplete/duplicate release');del slots[r];release+=1
            elif tag in ('D','Z'):
                value=int(f[9] if tag=='D' else f[6],16);require(value==mask(),'Terminal physical memory map')
                if tag=='D' and c['op']!=0:require(not slots,'Sign completion before full cleanup')
        ns=ev('N');l=(4,5,7)[p] if p<3 else 0
        require(ns==[['N',str(i),str(j+1),str(j*l)] for j in range(len(ns))],'Monotonic guarded attempt nonces')
        tags=[f[0] for f in events]
        if c['abort']:
            phase=c['abort'];require(len(ev('Z'))==1 and not ev('D') and not ev('B') and tags[-1]=='Z','Abort terminal')
            z=ev('Z')[0];require(int(z[2])==phase and int(z[3])==5 and int(z[5])==int(phase==8),'Main reset/fatal boundary')
            require(list(map(int,z[7:]))==([0,0,0] if phase<3 else [1,0,0] if phase==3 else [2,1,4] if phase==4 else [2,1,8]),'Reset prefix attempt counters')
            if phase==1:require(seen==[9,0] and int(z[4])==2,'SK prefix reset')
            if phase==2:require(seen==[len(frames[0]),0] and int(z[4])==2,'Key transformation reset')
            if phase==3:require(seen[0]==len(frames[0]) and 0<seen[1]<len(frames[1]) and int(z[4])==5,'Initial hash reset')
            if phase>=4:require(seen==list(map(len,frames)),'Post-input reset truncated frames')
            if phase==4:require(len(ns)==2 and not signature and int(z[4])==5,'Genuine retry reset')
            if phase==5:require(sigwords==13 and not siglast and int(z[4])==8,'Held z output reset')
            if phase==6:require(len(signature)==len(gold[i])-len(gold[i])%8 and not siglast and int(z[4])==8,'Held final word reset')
            if phase==7:require(bytes(signature)==gold[i] and siglast and not slots and int(z[4])==14,'Held main completion reset')
            if phase==8:require(int(z[4])==15,'Fatal did not halt Sign')
            if phase==9:require(int(z[4])==8 and len(signature)==32+4*576,'Pending hint read reset')
            require(not ev('REFUSE') and not ev('GATE'),'Unexpected abort probes');totals[2]+=1
        else:
            require(len(ev('D'))==1 and ev('B')==[['B',str(i),'0000000000000000']] and tags[-1]=='B' and not slots and not ev('Z'),'Completed job final ownership')
            d=ev('D')[0];require(list(map(int,d[2:6]))==[c['id'],c['code'],c['stage'],c['detail']],'Main completion metadata')
            counters=list(map(int,d[6:9]))
            if c['op']==1 and c['code']==0:
                require(bytes(signature)==gold[i] and siglast and seen==list(map(len,frames)) and ns and counters==[len(ns),len(ns)-1,len(ns)*l],'Complete Sign frames/bytes/counters')
                if c['flavor']==0:require(len(ns)==(2,1,5)[p],'Known genuine retry count')
                require(ev('REFUSE')==[['REFUSE',str(i),'4']],'Busy request refusal witness');success+=1;bytes_checked+=len(signature)
            elif c['op']==0:
                require(bytes(keydata[0])==c['pk'] and bytes(keydata[1])==c['sk'] and all(keylast) and not signature and not inputs and not ns and counters==[0,0,0],'Complete mixed KeyGen')
                require(len(ev('GATE'))==1 and int(ev('GATE')[0][2])>0,'KeyGen cleanup lease witness')
            else:
                require(not signature and not ev('K') and not ev('REFUSE'),'Errored job exposed output');errors+=1
                if c['code'] in (1,2):require(not inputs and not ns and counters==[0,0,0] and alloc==0,'Preflight/unsupported side effect')
                elif c['code']==3:
                    wanted={1:3,2:1,3:18,4:len(frames[0]),5:17}[c['fault']]
                    require(seen==[wanted,0] and not ns and counters==[0,0,0],'Malformed SK prefix/rollback')
                elif c['code']==4:require(seen==[len(frames[0]),len(frames[1]) if c['fault']==9 else 1] and len(ns)==1 and counters==[1,0,0],'Malformed message prefix/drain')
            if c['op']!=0:require(not ev('GATE'),'Unexpected cleanup gate')
            totals[1]+=1
        totals[0]+=1;totals[3]+=len(inputs);totals[4]+=sigwords;totals[5]+=len(ev('K'));totals[6]+=alloc;totals[7]+=commit;totals[8]+=release
    if footer!=totals:raise ValueError(f'Full Sign counters {footer}!={totals}')
    marker='STAGE5N4H7_NIST_SIGN' if nist else 'STAGE5N4H6_FULL_SIGN'
    mixed=sum(c['op']==0 for c in cases)
    return f'{marker}_COMPARE_PASS:{totals[0]} commands,{success} complete signatures/{bytes_checked} bytes,{mixed} mixed KeyGen,{errors} expected errors,{totals[2]} resets/faults;{totals[3]} input words,{totals[4]} signature words,{totals[5]} key words,{totals[6]}/{totals[7]}/{totals[8]} physical allocations/finishes/releases;peak regions{peaks}\n'


def sign_encode_cases():
    specs=[(0,0,0)]+[(0,4,k) for k in range(1,15)]+[(0,4,0),
        (1,0,0),(1,0,15),(1,0,0),
        (2,0,0),(2,65529,0),(2,28,16),(2,28,17),(2,28,0)]
    return [dict(i=i,p=p,nonce=n,kind=k,id=48000+p,
        abort=(8<=k<=14 or k==17),code=1 if 1<=k<=3 else 2 if k==4 else 3 if k else 0)
        for i,(p,n,k) in enumerate(specs)]


def sign_encode_artifact(token):
    rows=sign_encode_cases()
    return f'{token} {len(rows)}\n'+''.join(f"{c['i']} {c['p']} {c['id']} {c['nonce']} {c['kind']} "
        f"{m['rnd'][::-1].hex()} {m['sk'].hex()} {m['body'].hex()}\n" for c in rows for m in [sign_matrix_material(c['p'],0)])


def signature_bytes(p,m):
    q=8380417;gamma=(131072,524288,524288)[p];width=18 if p==0 else 20
    packed=bytearray(m['digest'])
    for poly in m['z']:
        bits=0
        for i,x in enumerate(poly):
            centered=x if x<=q//2 else x-q;v=gamma-centered
            if not 0<=v<(1<<width):raise ValueError('Unencodable signature z')
            bits|=v<<(i*width)
        packed+=bits.to_bytes(256*width//8,'little')
    indices=[];counts=[];omega=(80,55,75)[p]
    for poly in m['hints']:
        if any(x not in (0,1) for x in poly):raise ValueError('Nonbinary signature hint')
        indices.extend(i for i,x in enumerate(poly) if x);counts.append(len(indices))
    if len(indices)>omega:raise ValueError('Signature hint overflow')
    packed+=bytes(indices)+bytes(omega-len(indices))+bytes(counts)
    if len(packed)!=(2420,3309,4627)[p]:raise ValueError('Signature format length')
    return bytes(packed)


def check_sign_encode_c():
    gcc=shutil.which('gcc');ref=ROOT/'dilithium-sw-model/ref';fixtures=total=full=0
    if not gcc:raise ValueError('GCC required for signature oracle')
    for p,level in enumerate((2,3,5)):
        exe=HERE/f'reference_build/sign_encode_reference_{level}.exe'
        subprocess.run([gcc,'-std=c99','-O2','-DENCODE_SIGNATURE',f'-DDILITHIUM_MODE={level}','-I',str(ref),
            str(ROOT/'tb/tb_dilithium/reference/sign_retry_reference.c'),
            *[str(ref/n) for n in ('sign.c','packing.c','polyvec.c','poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],check=True,capture_output=True,text=True)
        for start in sorted({c['nonce'] for c in sign_encode_cases() if c['p']==p}):
            m=sign_matrix_material(p,0);chain,code,n=sign_retry_chain(p,start)
            if code:raise ValueError('Encoder fixture must reach acceptance')
            answer=subprocess.run([str(exe)],input=' '.join(map(str,[start,*m['sk'],*m['body'],*m['rnd']]))+'\n',capture_output=True,text=True,check=True).stdout.splitlines()
            rows=[s[2:] for s in answer if s.startswith('P ')]
            expected=signature_bytes(p,chain[-1][1])
            if len(rows)!=1 or bytes.fromhex(rows[0])!=expected:raise ValueError('Python/C complete signature mismatch')
            fixtures+=1;total+=len(expected);full+=int(start==0)
    message=f'PYTHON_C_SIGN_ENCODE_PASS:{fixtures} fixtures,{total} whole signature bytes;{full} also match unchanged full crypto_sign_signature_internal;other starts use unchanged pack_sig after independent C retries\n'
    (HERE/'stage5_sign_encode_c_reference.log').write_text(message);print(message,end='')


def verify_sign_encode(lines):
    _,token=check();cases=sign_encode_cases()
    if not lines or lines[0]!='G '+token:raise ValueError('Encode freshness')
    grouped={};footer=None;previous=-1
    for line in lines[1:]:
        f=line.split()
        if not f:raise ValueError('Empty encode record')
        if footer is not None:raise ValueError('Encode record after footer')
        if f[0]=='END':footer=list(map(int,f[1:]));continue
        if f[0] not in ('K','R','C','T','U','V','O','F','D','Z','B','HOLD') or len(f)<2:raise ValueError('Unknown encode record')
        i=int(f[1])
        if i<previous or i>=len(cases):raise ValueError('Encode case identity/order')
        previous=i
        grouped.setdefault(i,[]).append(f)
    totals=[0]*8;success=errors=byte_count=0;needkey=True;oldp=None
    for c in cases:
        i=c['i'];p=c['p'];kind=c['kind'];evs=grouped.get(i,[])
        def ev(k):return [f for f in evs if f[0]==k]
        def require(ok,text):
            if not ok:raise ValueError(f'Encode case{i}: '+text)
        chain,code,n=sign_retry_chain(p,c['nonce']);m=chain[-1][1];sig=signature_bytes(p,m)
        k,l=((4,4),(6,5),(8,7))[p];protected=sum(1<<r for r in [31,*range(l+2*k-1),50])
        keymap=protected^(1<<50)
        if oldp!=p:needkey=True
        require(ev('K')==([['K',str(i),str(p),f'{keymap:016x}',sign_matrix_material(p,0)['sk'][:32][::-1].hex()]] if needkey else []),'Prepared-key identity')
        needkey=c['abort'];oldp=p
        outid=c['id']+256
        require(ev('HOLD')==([['HOLD',str(i),str(outid),'292','2',str(c['id']^1),'0706050403020100']] if kind==7 else []),'Held output / bad hint response witness')
        require(not code and len(ev('R'))==1 and ev('C')==[['C',str(i),str(p),str(outid),str(c['nonce']),str(kind)]],'Start/accepted upstream result')
        r=ev('R')[0];require(list(map(int,r[2:5]))==[len(chain),len(chain)-1,n],'Retry counters')
        mask=int(r[5],16);z=[(int(r[6],16)>>(6*j))&63 for j in range(l)];h=[(int(r[7],16)>>(6*j))&63 for j in range(k)]
        handles=z+h
        require(len(set(handles))==l+k and sum(1<<v for v in handles)==mask and not mask&protected and
            int(r[8])==(32,48,64)[p] and int(r[9],16)==int.from_bytes(m['digest'],'little'),'Accepted descriptor/digest')
        preflight=1<=kind<=3
        require(ev('T')==([] if preflight else [['T',str(i),f'{mask:016x}']]),'Atomic take ownership')
        read_order=[(reg,w,mode,poly) for mode,regs,polys in ((2,z,m['z']),(0,h,m['hints'])) for reg,poly in zip(regs,polys,strict=True) for w in range(64)]
        requests=responses=word=0;pending=None;released=[];encoded=bytearray();last_seen=False
        expected_stream=sig
        if kind==6:expected_stream=sig[:(32,48,64)[p]+l*(576 if p==0 else 640)]+bytes(range((80,55,75)[p]))
        if kind==7:expected_stream=sig[:(32,48,64)[p]+l*(576 if p==0 else 640)]+bytes(range(8))
        for f in evs:
            tag=f[0]
            if tag=='U':
                require(not preflight and pending is None and requests<len(read_order),'Read ownership/order')
                reg,w,mode,poly=read_order[requests]
                require(list(map(int,f[2:]))==[reg,w],'Read address')
                pending=(reg,w,mode,poly);requests+=1
            elif tag=='V':
                require(pending is not None,'Response without request');reg,w,mode,poly=pending
                vals=poly[4*w:4*w+4];jid=c['id'];rmode=mode;err=0
                if kind==4 and mode==2 and w==0:vals=[8380417-131072,*vals[1:]]
                if kind==5 and mode==0 and w==0:vals=[2,*vals[1:]]
                if (kind==6 or kind==7 and w<2) and mode==0:vals=[1]*4
                if kind==7 and mode==0 and w>=2 or kind==8 and mode==2:jid^=1
                if kind==15 and mode==0:rmode=2
                if kind==16 and mode==0:err=1
                data=sum(v<<(23*j) for j,v in enumerate(vals))
                require(list(map(int,f[2:9]))==[reg,w,jid,rmode,p,0,err] and int(f[9],16)==data,'Packed response metadata/value')
                pending=None;responses+=1
            elif tag=='O':
                require(not preflight and not last_seen,'Output without owner/after last')
                jid,index,size,last=map(int,f[2:6]);value=int(f[6],16)
                require(jid==outid and index==word and 1<=size<=8 and
                    size==(min(8,len(sig)-len(encoded)) if kind!=6 else 8) and
                    last==int(len(encoded)+size==len(sig)),'Signature word framing')
                payload=value.to_bytes(8,'little')
                require(payload[:size]==expected_stream[len(encoded):len(encoded)+size] and not any(payload[size:]),'Signature exact bytes/padding')
                encoded+=payload[:size];word+=1;last_seen=bool(last)
            elif tag=='F':
                region=int(f[2]);require(region in handles and region not in released and not protected>>region&1,'Duplicate/foreign release')
                released.append(region)
        tags=[f[0] for f in evs]
        require(tags.index('R')<tags.index('C') and (preflight or tags.index('C')<tags.index('T')),'Publication/take order')
        endtag='Z' if c['abort'] else 'D'
        require(tags[-1]=='Z' if c['abort'] else tags[-2:]==['D','B'],'Terminal event order')
        if not preflight:
            require(all(j>tags.index('T') for j,t in enumerate(tags) if t in ('U','V','O','F')),'Access before adoption')
            require(not ev('F') or tags.index('F')>max([j for j,t in enumerate(tags) if t in ('U','V','O')],default=-1),'Release before last access')
        require(responses<=requests<=responses+1,'Outstanding read count')
        if c['abort']:
            require(len(ev('Z'))==1 and not ev('D') and not ev('B'),'Reset/fatal terminal')
            zrec=ev('Z')[0];expected_state={8:15,9:3,10:7,11:9,12:12,13:14,14:15,17:6}[kind]
            require(list(map(int,zrec[2:]))==[kind,expected_state,int(kind in (8,14))],'Abort boundary')
            if kind==12:require(len(encoded)==len(sig)-(len(sig)%8) and not last_seen,'Held final word reset')
            if kind==13:require(bytes(encoded)==sig and last_seen and sorted(released)==sorted(handles),'Held completion reset')
            if kind==17:require(pending is not None,'Pending response reset')
            totals[3]+=1
        else:
            require(pending is None and ev('D')==[['D',str(i),str(outid),str(c['code'])]] and
                ev('B')==[['B',str(i),f'{protected:016x}']],'Completion/final protected map')
            if c['code']==0:
                require(bytes(encoded)==sig and last_seen and responses==(l+k)*64,'Complete signature/read count');success+=1;byte_count+=len(sig)
            else:
                require(not last_seen and len(encoded)<len(sig),'Error credited complete bytes');errors+=1
                if preflight:require(not encoded and not requests and not released,'Preflight side effect')
                if kind==4:require(len(encoded)==(32,48,64)[p],'Invalid first z coefficient prefix')
                if kind in (5,15,16):require(len(encoded)==(32,48,64)[p]+l*(576 if p==0 else 640),'Malformed first hint prefix')
                if kind in (6,7):require(bytes(encoded)==expected_stream,'Omega overflow/held hint error prefix')
            require(sorted(released)==([] if preflight else sorted(handles)),'Whole-context cleanup')
            totals[2]+=1
        totals[0]+=1;totals[1]+=len(ev('T'));totals[4]+=word;totals[5]+=responses;totals[6]+=len(released);totals[7]+=len(ev('K'))
    if footer!=totals:raise ValueError(f'Encode totals {footer}!={totals}')
    return f'STAGE5N4H5_SIGN_ENCODE_COMPARE_PASS:{totals[0]} commands,{success} full signatures/{byte_count} bytes,{errors} expected errors,{totals[3]} reset/fault aborts,{totals[1]} takes,{totals[4]} exact output words,{totals[5]} exact packed reads,{totals[6]} releases,{totals[7]} actual key preparations\n'


def check_sign_retry_c():
    gcc=shutil.which('gcc');ref=ROOT/'dilithium-sw-model/ref';fixtures=attempts=values=0
    if not gcc:raise ValueError('GCC required for complete retry oracle')
    for p,level in enumerate((2,3,5)):
        exe=HERE/f'reference_build/sign_retry_reference_{level}.exe'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ref),str(ROOT/'tb/tb_dilithium/reference/sign_retry_reference.c'),
            *[str(ref/n) for n in ('packing.c','polyvec.c','poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],check=True,capture_output=True,text=True)
        for start in sorted({c['nonce'] for c in sign_retry_cases() if c['p']==p}):
            m=sign_matrix_material(p,0);chain,code,n=sign_retry_chain(p,start)
            answer=subprocess.run([str(exe)],input=' '.join(map(str,[start,*m['sk'],*m['body'],*m['rnd']]))+'\n',capture_output=True,text=True,check=True).stdout.splitlines()
            expected=['H '+m['mu'].hex()+' '+m['seed'].hex()]
            for nonce,a in chain:expected.append(f"A {nonce} {a['reason']} {a['weight']}")
            if not code:
                a=chain[-1][1];data=[v for name in ('z','hints') for poly in a[name] for v in poly]
                expected.append(f"S {n} {a['digest'].hex()} "+' '.join(map(str,data)));values+=len(data)
            expected.append(f'E {n}')
            if [s.split() for s in answer]!=[s.split() for s in expected]:raise ValueError(f'Python/C retry disagreement level{level},start{start}')
            fixtures+=1;attempts+=len(chain)
    message=f'PYTHON_C_SIGN_RETRY_PASS:{fixtures} starting fixtures,{attempts} full attempts,{values} accepted z/hint coefficients;unchanged C SHAKE/sampling/matrix/NTT/products/norm/MakeHint\n'
    (HERE/'stage5_sign_retry_c_reference.log').write_text(message);print(message,end='')


@lru_cache(maxsize=None)
def sign_accept_material(p,nonce):
    m=sign_products_material(p,nonce);q=8380417
    g1=(131072,524288,524288)[p];g2=(95232,261888,261888)[p];beta=(78,196,120)[p]
    norms=tuple(tuple(int(any(min(x,q-x)>=bound for x in poly)) for poly in m[name])
        for name,bound in zip(('z','corrected','ct0'),(g1-beta,g2-beta,g2)))
    combined=tuple(tuple((x+y)%q for x,y in zip(a,b,strict=True)) for a,b in zip(m['corrected'],m['ct0'],strict=True))
    # Mathematical HighBits inequality, independent of the RTL optimized predicate.
    hints=tuple(tuple(int(mathematical_decompose((h*2*g2+x)%q,p)[0]!=h) for x,h in zip(a,b,strict=True))
        for a,b in zip(combined,m['high'],strict=True))
    weights=tuple(map(sum,hints));reason=next((g+1 for g,flags in enumerate(norms) if any(flags)),0);weight=0
    if not reason:
        for w in weights:
            weight+=w
            if weight>(80,55,75)[p]:reason=4;break
    return dict(m,norms=norms,combined=combined,hints=hints,weights=weights,reason=reason,weight=weight)


def sign_accept_cases():
    rows=[]
    def add(p,nonce,inject=0,abort=0):
        i=len(rows);rows.append(dict(i=i,p=p,nonce=nonce,inject=inject,abort=abort,id=40000+i,
            code=1 if inject==1 else 2 if inject==2 else 3 if inject in (3,5) else 4 if inject==4 else 5 if inject in (6,7) else 0,
            detail=int(inject in (3,4,5))))
    for p,clean in enumerate((4,0,28)):
        add(p,clean);add(p,(0,5,0)[p])
        if p==1:add(p,455) # Genuine norm-clean candidate with56 hints,omega55.
        if p==2:add(p,7)   # Genuine r0 rejection rather than z rejection.
        for fault in range(1,8):add(p,clean,inject=fault)
        for phase in range(1,6):add(p,clean,abort=phase);add(p,clean)
    return rows


def sign_accept_artifact(token):
    rows=sign_accept_cases()
    return f'{token} {len(rows)}\n'+''.join(f"{c['i']} {c['p']} {c['id']} {c['nonce']} {c['inject']} {c['abort']} "
        f"{m['rnd'][::-1].hex()} {m['sk'].hex()} {m['body'].hex()}\n" for c in rows for m in [sign_accept_material(c['p'],c['nonce'])])


def check_sign_accept_c():
    gcc=shutil.which('gcc');ref=ROOT/'dilithium-sw-model/ref';fixtures=values=0
    if not gcc:raise ValueError('GCC required for norm/hint oracle')
    for p,level in enumerate((2,3,5)):
        exe=HERE/f'reference_build/sign_accept_reference_{level}.exe'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ref),str(ROOT/'tb/tb_dilithium/reference/sign_accept_reference.c'),
            *[str(ref/n) for n in ('poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],check=True,capture_output=True,text=True)
        rows=[sign_accept_material(p,n) for n in sorted({c['nonce'] for c in sign_accept_cases() if c['p']==p})]
        answer=subprocess.run([str(exe)],input=''.join('1 '+' '.join(map(str,[v for name in ('z','corrected','ct0','high') for a in m[name] for v in a]))+'\n' for m in rows),capture_output=True,text=True,check=True).stdout.splitlines()
        if len(answer)!=len(rows):raise ValueError('Norm/hint C fixture count')
        for m,line in zip(rows,answer,strict=True):
            gold=[v for flags in m['norms'] for v in flags]+list(m['weights'])+[v for name in ('combined','hints') for a in m[name] for v in a]
            if list(map(int,line.split()))!=gold:raise ValueError('Mathematical HighBits/C norm/MakeHint mismatch')
            fixtures+=1;values+=len(gold)
    message=f'PYTHON_C_SIGN_ACCEPT_PASS:{fixtures} fixtures,{values} norm flags/weights/combined/hint values;mathematical HighBits versus unchanged C norm/MakeHint\n'
    (HERE/'stage5_sign_accept_c_reference.log').write_text(message);print(message,end='')


def verify_sign_accept(lines):
    _,token=check();rows=sign_accept_cases()
    if not lines or lines[0]!='G '+token:raise ValueError('Acceptance stale token')
    by={};footer=None;previous=-1
    tags=('K','M','U','H','S','Y','N','C','T','O','Q','P','R','X','F','D','E','V','BARRIER','A','L','B','Z')
    for line in lines[1:]:
        f=line.split()
        if not f:raise ValueError('Blank acceptance event')
        if f[0]=='END':
            if footer is not None:raise ValueError('Duplicate acceptance footer')
            footer=list(map(int,f[1:]));continue
        if footer is not None or f[0] not in tags:raise ValueError('Unknown/trailing acceptance event')
        i=int(f[1])
        if i<previous or i>=len(rows):raise ValueError('Acceptance event order')
        previous=i;by.setdefault(i,[]).append(f)
    totals=[len(rows),0,0,0,0,0,0,0,0,0,0];needkey=True;oldp=None;retained=False
    sentinel=tuple(reference.sample(2,0,hashlib.shake_256(b'').digest(4096))[0])
    for c in rows:
        i,p=c['i'],c['p'];k,l=((4,4),(6,5),(8,7))[p];n=l+2*k;m=sign_accept_material(p,c['nonce']);events=by.get(i,[])
        def ev(t):return [f for f in events if f[0]==t]
        def packed(v):return sum(r<<(6*j) for j,r in enumerate(v))
        if oldp!=p:needkey=True;retained=False
        kh=[31,*range(n-1)];z=list(range(32,32+l));keymask=sum(1<<r for r in kh);ymask=sum(1<<r for r in z)
        base=keymask|ymask|(1<<50);work=[r for r in range(64) if not base>>r&1][:2*l+2*k+3]
        hats=work[:l];lo=work[2*l:2*l+k];hi=work[2*l+k:2*l+2*k];chat=hats[0]
        matmap=sum(1<<r for r in hats+lo+hi);vecmap=sum(1<<r for r in lo+hi+[chat]);free=[r for r in range(64) if not(base|vecmap)>>r&1]
        ct0=free[:k];source=base|sum(1<<r for r in lo+hi+ct0);rawmap=source & ~(keymask|(1<<50));spare=next(r for r in range(64) if not source>>r&1)
        hints=[spare,*lo[:k-1]];resultmap=ymask|sum(1<<r for r in hints);source_id=35000+p
        blocks={r for r in range(64) if not source>>r&1} if c['inject']==2 else set();initial=source|sum(1<<r for r in blocks)
        if ev('K')!=([['K',str(i),str(p),f'{keymask:016x}',m['sk'][:32][::-1].hex()]] if needkey else []):raise ValueError('Acceptance key preparation')
        if ev('M')!=([['M',str(i),str(c['nonce']),f'{ymask:016x}',f'{packed(z):011x}',m['mu'][::-1].hex(),m['seed'][::-1].hex()]] if not retained else []):raise ValueError('Acceptance mask preparation')
        if ev('U')!=([['U',str(i),str(10000+p),f'{matmap:016x}',f'{packed(hats):011x}',f'{packed(lo):012x}',f'{packed(hi):012x}']] if not retained else []):raise ValueError('Acceptance matrix preparation')
        source_c=next(r for r in range(64) if not(base|matmap)>>r&1)
        if ev('H')!=([['H',str(i),str(20000+p),str(source_c),f'{int.from_bytes(m["digest"],"little"):0128x}']] if not retained else []):raise ValueError('Acceptance challenge preparation')
        if ev('S')!=([['S',str(i),'0',str(25000+p),f'{vecmap:016x}',str(chat),f'{packed(lo):012x}',f'{packed(hi):012x}',f'{int.from_bytes(m["digest"],"little"):0128x}']] if not retained else []):raise ValueError('Acceptance transform preparation')
        if ev('Y')!=[['Y',str(i),str(source_id),f'{rawmap:016x}',f'{packed(z):011x}',f'{packed(lo):012x}',f'{packed(hi):012x}',f'{packed(ct0):012x}',str(10000+p),str(len(m['digest'])),str(c['nonce']+l),m['mu'][::-1].hex(),m['seed'][::-1].hex(),f'{int.from_bytes(m["digest"],"little"):0128x}']]:raise ValueError('Acceptance upstream products publication')
        if ev('N')!=[['N',str(i),f'{initial:016x}']] or ev('C')!=[['C',str(i),*[str(c[x]) for x in ('p','id','nonce','inject','abort')]]]:raise ValueError('Acceptance initial/command ledger')
        totals[8]+=int(needkey);totals[9]+=int(not retained);totals[10]+=int(not retained)
        oldp=p;needkey=bool(c['abort']);retained=c['inject'] in (1,2) and not c['abort']
        steps=[];stop=False
        for g,flags in enumerate(m['norms']):
            for j,flag in enumerate(flags):
                steps.append(('NORM',g,j))
                if flag:stop=True;break
            if stop:break
        if not stop:
            weight=0
            for j in range(k):
                steps.extend([('ADD',2,j),('HINT',2,j)]);weight+=m['weights'][j]
                if weight>(80,55,75)[p]:break
        cursor=0;current=None;adopted=False;failed=False;ended=False;published=False;taken=False
        owned=set();reserved={r for r in range(64) if initial>>r&1};pending_free=[];pending_external=[];external=set();readorder=[]
        reason=weight=0
        for f in events:
            kind=f[0]
            if kind=='T':
                if adopted or c['inject'] in (1,2) or f!=['T',str(i),f'{initial:016x}',str(spare)]:raise ValueError('Acceptance whole ownership transfer')
                adopted=True;owned=set(z+lo+hi+ct0);totals[5]+=1
            elif kind in ('O','P'):
                if not adopted or current is not None or failed or reason or pending_free or cursor>=len(steps):raise ValueError('Acceptance dependent/out-of-order command')
                want,g,j=steps[cursor];reject=(c['inject']==3 and want=='NORM' or c['inject']==4 and want=='ADD' or c['inject']==5 and want=='HINT')
                tagbad=(c['inject']==6 and want=='NORM' or c['inject']==7 and want=='ADD')
                dest=hints[0] if want=='NORM' else lo[j] if want=='ADD' else hints[j]
                values=None if want=='NORM' else m['combined'][j] if want=='ADD' else m['hints'][j]
                if kind=='O':
                    if want not in ('NORM','HINT'):raise ValueError('Acceptance sign/ADD schedule')
                    a=(z,lo,ct0)[g][j] if want=='NORM' else lo[j]
                    expected=[g,j,1 if want=='NORM' else 2,g,a,hi[j],dest,(source_id if want=='NORM' else c['id'])^int(reject and want=='NORM'),(10000+p)^int(reject and want=='HINT'),c['id']]
                else:
                    if want!='ADD':raise ValueError('Acceptance ADD/sign schedule')
                    expected=[j,0,1,lo[j],ct0[j],lo[j],source_id^int(reject),source_id,c['id']]
                if list(map(int,f[2:]))!=expected or want=='HINT' and dest in reserved:raise ValueError('Acceptance exact descriptor/alias')
                current=dict(kind=want,g=g,j=j,dest=dest,values=values,count=0,reject=reject,tagbad=tagbad,state=8 if want=='ADD' else 11)
            elif kind=='X':
                j,state,region,index=map(int,f[2:6]);value=int(f[6],16)
                if current is None or current['kind']=='NORM' or current['reject'] or j!=current['j'] or state!=current['state'] and not(state==20 and c['abort']==5) or region!=current['dest'] or index!=current['count'] or index>=256 or value!=current['values'][index]:raise ValueError('Acceptance exact combined/hint write')
                current['count']+=1;totals[6]+=1
            elif kind in ('Q','R'):
                if current is None or (kind=='R')!=(current['kind']=='ADD'):raise ValueError('Acceptance unexpected child done')
                a=current;want,g,j=a['kind'],a['g'],a['j'];flag=m['norms'][g][j] if want=='NORM' else 0;w=m['weights'][j] if want=='HINT' else 0
                expected=[g,j,int(a['reject']),c['id']^int(a['tagbad']),a['dest'],0,0 if a['reject'] else flag,0 if a['reject'] else w] if kind=='Q' else [j,int(a['reject']),c['id']^int(a['tagbad']),a['dest']]
                if list(map(int,f[2:]))!=expected or a['count']!=(0 if want=='NORM' or a['reject'] else 256):raise ValueError('Acceptance exact child verdict/weight/commit')
                failed=a['reject'] or a['tagbad']
                if want=='HINT' and not a['reject']:owned.add(a['dest']);reserved.add(a['dest'])
                if not failed:
                    if want=='NORM' and flag:reason=g+1
                    if want=='HINT':
                        weight+=w
                        if weight>(80,55,75)[p]:reason=4
                        else:pending_free=[(13,lo[j]),(14,hi[j]),(15,ct0[j])]
                cursor+=1;current=None
            elif kind=='F':
                state,region=map(int,f[2:])
                if region not in reserved:raise ValueError('Acceptance duplicate/unreserved release')
                if state==0:
                    if region not in external and region not in blocks:raise ValueError('Acceptance foreign external release')
                    pending_external.append(region);external.discard(region)
                else:
                    if region not in owned:raise ValueError('Acceptance foreign owned release')
                    if state in (13,14,15):
                        if current is not None or failed or reason or not pending_free or pending_free.pop(0)!=(state,region):raise ValueError('Acceptance premature last-read release')
                    elif state==19:
                        if not failed and not reason and not ended:raise ValueError('Acceptance premature attempt discard')
                    else:raise ValueError('Acceptance unexpected release phase')
                    owned.remove(region)
                reserved.remove(region)
            elif kind=='D':
                reject=bool(m['reason']);want=['D',str(i),str(int(reject)),f'{0 if reject else resultmap:016x}',f'{0 if reject else packed(z):011x}',f'{0 if reject else packed(hints):012x}',str(0 if reject else source_id),str(0 if reject else len(m['digest'])),str(c['nonce']+l),m['mu'][::-1].hex(),m['seed'][::-1].hex(),f'{0 if reject else int.from_bytes(m["digest"],"little"):0128x}']
                if published or c['code'] or c['abort'] or current is not None or failed or pending_free or cursor!=len(steps) or owned!=(set() if reject else set(z+hints)) or f!=want:raise ValueError('Acceptance whole result/retry header publication')
                published=True
            elif kind=='E':
                if ended or c['abort'] or list(map(int,f[2:]))!=[c['id'],c['code'],c['detail'],int(bool(m['reason']) and not c['code']),0 if c['code'] else m['reason'],0 if c['code'] else m['weight']] or not c['code'] and not published or c['code'] and owned:raise ValueError('Acceptance error versus algorithmic rejection')
                ended=True
            elif kind=='A':
                payload=0 if m['reason'] else resultmap
                if taken or not ended or not i%2 or c['code'] or f!=['A',str(i),f'{payload:016x}',str(c['nonce']+l),m['mu'][::-1].hex(),m['seed'][::-1].hex()]:raise ValueError('Acceptance retry/accepted ownership handoff')
                taken=True;external=set(owned);owned.clear()
            elif kind=='L':
                if not pending_external or int(f[2])!=pending_external.pop(0):raise ValueError('Acceptance external release ACK')
            elif kind=='V':
                typ,j,region,word,jid,mode,param,domain=map(int,f[2:10]);data=int(f[10],16)
                if typ in (7,8,9,10):
                    if adopted or ended:raise ValueError('Acceptance late input read')
                    poly=m[('z','corrected','high','ct0')[typ-7]][j];meta=((z,lo,hi,ct0)[typ-7][j],10000+p if typ==9 else source_id,(2,0,0,3)[typ-7],p,0)
                else:
                    if not ended:raise ValueError('Acceptance premature result/key read')
                    if typ==0:poly=m['z'][j];meta=(z[j],source_id,2,p,0)
                    elif typ==1:poly=m['hints'][j];meta=(hints[j],c['id'],0,p,0)
                    elif typ==4:poly=sign_prepare_math(m['sk'],p)[1][j];meta=(kh[j],100+p,1 if j<l+k else 3,p,1)
                    elif typ in (5,6):
                        if typ==6 and (region not in blocks or j!=region):raise ValueError('Acceptance unknown blocker read')
                        poly=sentinel;meta=(50 if typ==5 else region,60000,2,0,0)
                    else:raise ValueError('Acceptance unknown read kind')
                if not 0<=word<64 or (region,jid,mode,param,domain)!=meta or data!=sum(poly[4*word+b]<<(23*b) for b in range(4)):raise ValueError('Acceptance exact bank read/metadata')
                readorder.append((typ,j,word));totals[7]+=1
            elif kind=='BARRIER':
                poly=sentinel if m['reason'] else m['z'][0]
                if c['code'] or not ended or int(f[2],16)!=sum(poly[b]<<(23*b) for b in range(4)):raise ValueError('Acceptance pending-read barrier')
        expected=[(7,j,w) for j in range(l) for w in range(64)]+[(typ,j,w) for j in range(k) for typ in (8,9,10) for w in range(64)]
        if c['abort']:
            phase=c['abort'];state={1:5,2:8,3:11,4:17,5:20}[phase]
            if ev('Z')!=[['Z',str(i),str(phase),str(state),str(0 if phase==1 else 2),str(0 if phase!=4 else k-1)]] or ev('D') or ev('E') or ev('B') or not adopted:raise ValueError('Acceptance reset/fault location/credit')
            if phase in (2,3,5) and (current is None or not 32<=current['count']<=36):raise ValueError('Acceptance partial-write abort prefix')
            if phase==4 and (current is not None or cursor!=len(steps) or owned!=set(z+hints)):raise ValueError('Acceptance held accepted-result reset')
            totals[4]+=1
        else:
            final=source if c['inject'] in (1,2) else keymask|(1<<50)
            if not ended or ev('Z') or owned or external or pending_external or ev('B')!=[['B',str(i),f'{final:016x}']] or reserved!={r for r in range(64) if final>>r&1}:raise ValueError('Acceptance final memory ledger')
            if not c['code'] and not m['reason']:expected += [(0,j,w) for j in range(l) for w in range(64)]+[(1,j,w) for j in range(k) for w in range(64)]
            expected += [(4,j,w) for j in range(n) for w in range(64)]+[(5,0,w) for w in range(64)]+[(6,r,w) for r in sorted(blocks) for w in range(64)]
            if len(ev('BARRIER'))!=int(c['code']==0) or bool(ev('A'))!=bool(i%2 and not c['code']):raise ValueError('Acceptance missing clear/take/read barrier')
            if c['inject'] in (1,2) and (adopted or ev('O') or ev('P') or ev('X')):raise ValueError('Acceptance preflight side effects')
            totals[1]+=1;totals[2]+=int(bool(m['reason']) and not c['code']);totals[3]+=int(c['code']!=0)
        if readorder!=expected:raise ValueError('Acceptance missing/duplicate/out-of-order bank read')
    if footer!=totals:raise ValueError(f'Acceptance totals mismatch:{footer}!={totals}')
    return f'STAGE5N4H3_SIGN_ACCEPT_COMPARE_PASS:{totals[0]} commands,{totals[1]-totals[2]-totals[3]} accepted,{totals[2]} genuine algorithmic rejections,{totals[3]} expected errors,{totals[4]} aborts,{totals[5]} whole takes,{totals[6]} exact combined/hint writes,{totals[7]} packed reads;actual preparations {totals[8:]}\n'


def sign_products_cases():
    rows=[]
    def add(p,nonce=0,inject=0,abort=0):
        i=len(rows);rows.append(dict(i=i,p=p,nonce=nonce,inject=inject,abort=abort,id=65535 if nonce else 35000+i,
            code=1 if inject==1 else 2 if inject==2 else 3 if inject in (3,4) else 4 if inject==5 else 5 if inject in (6,7) else 0,
            detail=int(inject in (3,4,5))))
    for p,l in enumerate((4,5,7)):
        add(p);add(p,l)
        for fault in range(1,8):add(p,inject=fault)
        for phase in range(1,7):add(p,abort=phase);add(p)
    return rows


def sign_products_artifact(token):
    rows=sign_products_cases()
    return f'{token} {len(rows)}\n'+''.join(f"{c['i']} {c['p']} {c['id']} {c['nonce']} {c['inject']} {c['abort']} "
        f"{m['rnd'][::-1].hex()} {m['sk'].hex()} {m['body'].hex()}\n" for c in rows for m in [sign_products_material(c['p'],c['nonce'])])


def check_sign_products_c():
    gcc=shutil.which('gcc');ref=ROOT/'dilithium-sw-model/ref';fixtures=values=0
    if not gcc:raise ValueError('GCC required for response-product oracle')
    for p,level in enumerate((2,3,5)):
        exe=HERE/f'reference_build/sign_products_reference_{level}.exe'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ref),str(ROOT/'tb/tb_dilithium/reference/sign_products_reference.c'),
            *[str(ref/n) for n in ('packing.c','poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],check=True,capture_output=True,text=True)
        rows=[sign_products_material(p,n) for n in (0,(4,5,7)[p])]
        answer=subprocess.run([str(exe)],input=''.join(' '.join(map(str,[*m['sk'],*m['digest'],*[v for poly in m['y'] for v in poly],*[v for poly in m['low'] for v in poly]]))+'\n' for m in rows),capture_output=True,text=True,check=True).stdout.splitlines()
        if len(answer)!=2:raise ValueError('Response C fixture count')
        for m,line in zip(rows,answer,strict=True):
            gold=[v for poly in (*m['products'],*m['z'],*m['corrected']) for v in poly]
            if list(map(int,line.split()))!=gold:raise ValueError('Sparse schoolbook/C response-product mismatch')
            fixtures+=1;values+=len(gold)
    message=f'PYTHON_C_SIGN_PRODUCTS_PASS:{fixtures} fixtures,{values} product/z/corrected coefficients;sparse schoolbook versus unchanged C unpack/NTT/Montgomery/INTT/add/sub\n'
    (HERE/'stage5_sign_products_c_reference.log').write_text(message);print(message,end='')


def verify_sign_products(lines):
    _,token=check();rows=sign_products_cases()
    if not lines or lines[0]!='G '+token:raise ValueError('Products stale token')
    by={};footer=None;previous=-1
    for line in lines[1:]:
        f=line.split()
        if not f:raise ValueError('Blank products event')
        if f[0]=='END':
            if footer is not None:raise ValueError('Duplicate products footer')
            footer=list(map(int,f[1:]));continue
        if footer is not None or f[0] not in ('K','M','U','H','S','N','C','T','O','Q','P','R','X','F','D','E','V','BARRIER','A','L','B','Z'):raise ValueError('Unknown/trailing products event')
        i=int(f[1])
        if i<previous or i>=len(rows):raise ValueError('Products event order')
        previous=i;by.setdefault(i,[]).append(f)
    totals=[len(rows),0,0,0,0,0,0,0,0,0];needkey=True;oldp=oldnonce=None;retained=False
    sentinel=tuple(reference.sample(2,0,hashlib.shake_256(b'').digest(4096))[0])
    for c in rows:
        i,p=c['i'],c['p'];k,l=((4,4),(6,5),(8,7))[p];n=l+2*k;m=sign_products_material(p,c['nonce']);events=by.get(i,[])
        def ev(t):return [f for f in events if f[0]==t]
        def packed(v):return sum(r<<(6*j) for j,r in enumerate(v))
        if oldp!=p:needkey=True;retained=False;oldnonce=None
        reuse=retained and oldnonce==c['nonce'];kh=[31,*range(n-1)];ymap=list(range(32,32+l));keymask=sum(1<<r for r in kh);ymask=sum(1<<r for r in ymap)
        base=keymask|ymask|(1<<50);work=[r for r in range(64) if not base>>r&1][:2*l+2*k+3]
        hats=work[:l];lo=work[2*l:2*l+k];hi=work[2*l+k:2*l+2*k];matmap=sum(1<<r for r in hats+lo+hi)
        source_c=next(r for r in range(64) if not(base|matmap)>>r&1);chat=hats[0];vecmap=sum(1<<r for r in lo+hi+[chat]);source=base|vecmap
        free=[r for r in range(64) if not source>>r&1];blocks=set(free[k+1:]) if c['inject']==2 else set();initial=source|sum(1<<r for r in blocks)
        ct0=free[:k];pwm,inv=free[k:k+2];plan=sum(1<<r for r in ct0+[pwm,inv]);resultmap=ymask|sum(1<<r for r in lo+hi+ct0)
        if ev('K')!=([['K',str(i),str(p),f'{keymask:016x}',m['sk'][:32][::-1].hex()]] if needkey else []):raise ValueError('Products actual key publication')
        if ev('M')!=([['M',str(i),str(c['nonce']),f'{ymask:016x}',f'{packed(ymap):011x}',m['mu'][::-1].hex(),m['seed'][::-1].hex()]] if not reuse else []):raise ValueError('Products actual mask/header publication')
        if ev('U')!=([['U',str(i),str(10000+p),f'{matmap:016x}',f'{packed(hats):011x}',f'{packed(lo):012x}',f'{packed(hi):012x}']] if not reuse else []):raise ValueError('Products actual matrix publication')
        if ev('H')!=([['H',str(i),str(20000+p),str(source_c),f'{int.from_bytes(m["digest"],"little"):0128x}']] if not reuse else []):raise ValueError('Products actual challenge publication')
        if ev('S')!=[['S',str(i),str(int(reuse)),str(25000+p),f'{vecmap:016x}',str(chat),f'{packed(lo):012x}',f'{packed(hi):012x}',f'{int.from_bytes(m["digest"],"little"):0128x}']]:raise ValueError('Products transformed source publication')
        if ev('N')!=[['N',str(i),f'{initial:016x}',f'{ymask:016x}',f'{vecmap:016x}',f'{packed(ymap):011x}',f'{packed(lo):012x}',f'{packed(hi):012x}',str(chat)]] or ev('C')!=[['C',str(i),*[str(c[x]) for x in ('p','id','nonce','inject','abort')]]]:raise ValueError('Products source/command ledger')
        totals[7]+=int(needkey);totals[8]+=int(not reuse);totals[9]+=int(not reuse)
        oldp=p;oldnonce=c['nonce'];needkey=bool(c['abort']);retained=c['inject'] in (1,2) and not c['abort']
        steps=[(g,j,kind) for g,length in enumerate((l,k,k)) for j in range(length) for kind in (('PWM','INV','PROC') if g<2 else ('PWM','INV'))]
        cursor=0;current=None;adopted=False;failed=False;published=False;ended=False;taken=False;dropped=False
        owned=set();reserved={r for r in range(64) if initial>>r&1};pending_free=[];pending_external=[];external=set();readorder=[]
        def at(g,j):return j if g==0 else l+j if g==1 else l+k+j
        for f in events:
            kind=f[0]
            if kind=='T':
                if adopted or c['inject'] in (1,2) or f!=['T',str(i),f'{initial:016x}',f'{plan:016x}',f'{packed(ct0):012x}',str(pwm),str(inv)]:raise ValueError('Products atomic ownership/plan')
                adopted=True;owned=set(ymap+lo+hi+[chat]);totals[4]+=1
            elif kind in ('O','P'):
                if not adopted or current is not None or failed or pending_free or cursor>=len(steps):raise ValueError('Products unowned/out-of-order command')
                g,j,want=steps[cursor];expectedkind='PROC' if kind=='P' else ('PWM' if int(f[4])==2 else 'INV')
                if tuple(map(int,f[2:4]))!=(g,j) or expectedkind!=want:raise ValueError('Products schedule order')
                reject=(c['inject']==3 and want=='PWM' and g==0 and j==0 or c['inject']==4 and want=='INV' and g==1 and j==1 or c['inject']==5 and want=='PROC' and g==1 and j==1)
                tagbad=(c['inject']==6 and want=='INV' and g==2 and j==1 or c['inject']==7 and want=='PROC' and g==0 and j==0)
                if want=='PWM':
                    expected=[g,j,2,chat,25000+p,kh[at(g,j)],(100+p)^int(reject),pwm,c['id']];dest=pwm;values=m['pwm'][at(g,j)];state=5
                elif want=='INV':
                    dest=ct0[j] if g==2 else inv;expected=[g,j,1,pwm,c['id']^int(reject),kh[at(g,j)],100+p,dest,c['id']];values=m['products'][at(g,j)];state=8
                else:
                    dest=ymap[j] if g==0 else lo[j];aid=(1000+p if g==0 else 10000+p)^int(reject)
                    expected=[g,j,g,1,dest,inv,dest,aid,c['id'],c['id']];values=m['z' if g==0 else 'corrected'][j];state=11
                if list(map(int,f[2:]))!=expected or want!='PROC' and dest in reserved:raise ValueError('Products exact service descriptor/alias')
                current=dict(g=g,j=j,kind=want,dest=dest,values=values,count=0,reject=reject,tagbad=tagbad,state=state)
            elif kind=='X':
                g,j,state,region,index=map(int,f[2:7]);value=int(f[7],16)
                if current is None or current['reject'] or (g,j)!=(current['g'],current['j']) or state!=current['state'] and not(state==20 and c['abort']==6) or region!=current['dest'] or index!=current['count'] or index>=256 or value!=current['values'][index]:raise ValueError('Products exact intermediate scalar write')
                current['count']+=1;totals[5]+=1
            elif kind in ('Q','R'):
                if current is None or (kind=='R')!=(current['kind']=='PROC'):raise ValueError('Products unexpected child result')
                a=current
                if list(map(int,f[2:]))!=[a['g'],a['j'],int(a['reject']),c['id']^int(a['tagbad']),a['dest']] or a['count']!=(0 if a['reject'] else 256):raise ValueError('Products child retirement/value count')
                if not a['reject']:owned.add(a['dest']);reserved.add(a['dest'])
                failed=a['reject'] or a['tagbad'];cursor+=1;current=None
                if not failed and (a['kind']=='PROC' or a['kind']=='INV' and a['g']==2):pending_free=[pwm,inv] if a['g']<2 else [pwm]
            elif kind=='F':
                state,region=map(int,f[2:])
                if region not in reserved:raise ValueError('Products duplicate/unreserved release')
                if state==0:
                    if region not in external and region not in blocks:raise ValueError('Products foreign external release')
                    pending_external.append(region);external.discard(region)
                else:
                    if region not in owned:raise ValueError('Products foreign owned release')
                    if state in (13,14):
                        if current is not None or failed or not pending_free or pending_free.pop(0)!=region or (state==13)!=(region==pwm):raise ValueError('Products early/wrong scratch release')
                    elif state==16:
                        if cursor!=len(steps) or current is not None or pending_free or failed or region!=chat or dropped:raise ValueError('Products early challenge release')
                        dropped=True
                    elif state==19:
                        if not failed and not ended:raise ValueError('Products premature cleanup')
                    else:raise ValueError('Products release phase')
                    owned.remove(region)
                reserved.remove(region)
            elif kind=='D':
                want=['D',str(i),f'{resultmap:016x}',f'{packed(ymap):011x}',f'{packed(lo):012x}',f'{packed(hi):012x}',f'{packed(ct0):012x}',str(10000+p),str(len(m['digest'])),str(c['nonce']+l),m['mu'][::-1].hex(),m['seed'][::-1].hex(),f'{int.from_bytes(m["digest"],"little"):0128x}']
                if published or c['code'] or c['abort'] or not dropped or failed or current is not None or owned!=set(ymap+lo+hi+ct0) or f!=want:raise ValueError('Products private/whole context publication')
                published=True
            elif kind=='E':
                if ended or c['abort'] or list(map(int,f[2:]))!=[c['id'],c['code'],c['detail']] or not c['code'] and not published or c['code'] and owned:raise ValueError('Products held completion/rollback')
                ended=True
            elif kind=='A':
                if taken or not ended or c['nonce']==0 or f!=['A',str(i),f'{resultmap:016x}',str(c['nonce']+l),m['mu'][::-1].hex(),m['seed'][::-1].hex()] or owned!=set(ymap+lo+hi+ct0):raise ValueError('Products next-owner/header transfer')
                taken=True;external=set(owned);owned.clear()
            elif kind=='L':
                if not pending_external or int(f[2])!=pending_external.pop(0):raise ValueError('Products external release acknowledgment')
            elif kind=='V':
                if not ended:raise ValueError('Products early consumer')
                typ,j,region,word,jid,mode,param,domain=map(int,f[2:10]);data=int(f[10],16)
                if typ==0:poly=m['z'][j];meta=(ymap[j],c['id'],2,p,0)
                elif typ==1:poly=m['corrected'][j];meta=(lo[j],c['id'],0,p,0)
                elif typ==2:poly=m['high'][j];meta=(hi[j],10000+p,0,p,0)
                elif typ==3:poly=m['ct0'][j];meta=(ct0[j],c['id'],3,p,0)
                elif typ==4:poly=sign_prepare_math(m['sk'],p)[1][j];meta=(kh[j],100+p,1 if j<l+k else 3,p,1)
                elif typ in (5,6):
                    if typ==6 and (region not in blocks or j!=region):raise ValueError('Products unknown blocker')
                    poly=sentinel;meta=(50 if typ==5 else region,60000,2,0,0)
                elif typ==7:poly=m['y'][j];meta=(ymap[j],1000+p,2,p,0)
                elif typ==8:poly=m['low'][j];meta=(lo[j],10000+p,0,p,0)
                elif typ==9:poly=m['chat'];meta=(chat,25000+p,3,p,1)
                else:raise ValueError('Products unknown read kind')
                if not 0<=word<64 or (region,jid,mode,param,domain)!=meta or data!=sum(poly[4*word+b]<<(23*b) for b in range(4)):raise ValueError('Products exact final/source read')
                readorder.append((typ,j,word));totals[6]+=1
            elif kind=='BARRIER':
                if c['code'] or not ended or int(f[2],16)!=sum(m['z'][0][b]<<(23*b) for b in range(4)):raise ValueError('Products pending-read barrier')
        if c['abort']:
            points={1:(5,0,0),2:(8,0,0),3:(11,0,0),4:(5,2,1),5:(17,2,0),6:(20,1,1)}
            if ev('Z')!=[['Z',str(i),str(c['abort']),*map(str,points[c['abort']])]] or ev('D') or ev('E') or ev('V') or ev('B') or not adopted:raise ValueError('Products reset/fault credit or point')
            if c['abort']==5:
                if not dropped or owned!=set(ymap+lo+hi+ct0):raise ValueError('Products held-done reset prefix')
            elif current is None or not 32<=current['count']<=36:raise ValueError('Products partial reset prefix')
            totals[3]+=1
        else:
            final=source if c['inject'] in (1,2) else keymask|(1<<50)
            if not ended or ev('Z') or owned or external or pending_external or ev('B')!=[['B',str(i),f'{final:016x}']]:raise ValueError('Products final ownership ledger')
            expected=[]
            if not c['code']:expected=[(0,j,w) for j in range(l) for w in range(64)]+[(typ,j,w) for j in range(k) for typ in (1,2,3) for w in range(64)]
            elif c['inject'] in (1,2):expected=[(7,j,w) for j in range(l) for w in range(64)]+[(typ,j,w) for j in range(k) for typ in (8,2) for w in range(64)]+[(9,0,w) for w in range(64)]
            expected += [(4,j,w) for j in range(n) for w in range(64)]+[(5,0,w) for w in range(64)]+[(6,r,w) for r in sorted(blocks) for w in range(64)]
            if readorder!=expected or len(ev('BARRIER'))!=int(c['code']==0) or bool(ev('A'))!=bool(c['nonce']):raise ValueError('Products missing/duplicate reads/header barrier')
            if c['inject'] in (1,2) and (adopted or ev('O') or ev('P') or ev('X')):raise ValueError('Products preflight side effects')
            if reserved!={r for r in range(64) if final>>r&1}:raise ValueError('Products reserved-map leak')
            totals[1]+=1;totals[2]+=int(c['code']!=0)
    if footer!=totals:raise ValueError(f'Products totals mismatch:{footer}!={totals}')
    return f'STAGE5N4H2_SIGN_PRODUCTS_COMPARE_PASS:{totals[0]} commands,{totals[1]-totals[2]} successes,{totals[2]} expected errors,{totals[3]} aborts,{totals[4]} atomic takes,{totals[5]} exact intermediate writes,{totals[6]} packed reads;actual key/mask/matrix preparations {totals[7:]}\n'


def sign_transform_cases():
    rows=[]
    def add(p,nonce=0,inject=0,abort=0):
        i=len(rows);rows.append(dict(i=i,p=p,nonce=nonce,inject=inject,abort=abort,id=65535 if nonce else 30000+i,
            code=1 if inject in (1,2) else 3 if inject==3 else 4 if inject==4 else 0,detail=int(inject==3)))
    for p,l in enumerate((4,5,7)):
        add(p);add(p,l)
        for fault in range(1,6):add(p,inject=fault)
        for phase in range(1,6):add(p,abort=phase);add(p)
    return rows


def sign_transform_artifact(token):
    rows=sign_transform_cases()
    return f'{token} {len(rows)}\n'+''.join(f"{c['i']} {c['p']} {c['id']} {c['nonce']} {c['inject']} {c['abort']} "
        f"{m['rnd'][::-1].hex()} {m['sk'].hex()} {m['body'].hex()}\n" for c in rows for m in [sign_challenge_material(c['p'],c['nonce'])])


def check_sign_transform_c():
    gcc=shutil.which('gcc');ref=ROOT/'dilithium-sw-model/ref';fixtures=0
    if not gcc:raise ValueError('GCC required for challenge-transform oracle')
    for p,level in enumerate((2,3,5)):
        exe=HERE/f'reference_build/sign_transform_reference_{level}.exe'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ref),str(ROOT/'tb/tb_dilithium/reference/sign_challenge_transform_reference.c'),
            *[str(ref/n) for n in ('poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],check=True,capture_output=True,text=True)
        rows=[sign_challenge_material(p,n) for n in (0,(4,5,7)[p])]
        answer=subprocess.run([str(exe)],input=''.join(str(len(m['digest']))+' '+m['digest'].hex()+'\n' for m in rows),capture_output=True,text=True,check=True).stdout.splitlines()
        if len(answer)!=2:raise ValueError('Challenge-transform C fixture count')
        for m,line in zip(rows,answer,strict=True):
            gold=tuple(m['challenge'])+tuple(ntt_reference.direct_forward(list(m['challenge'])))
            if tuple(map(int,line.split()))!=gold:raise ValueError('Python/C challenge-transform mismatch')
            fixtures+=1
    message=f'PYTHON_C_SIGN_TRANSFORM_PASS:{fixtures} fixtures,1536 c and1536 chat coefficients;unchanged C poly_challenge/poly_ntt\n'
    (HERE/'stage5_sign_transform_c_reference.log').write_text(message);print(message,end='')


def verify_sign_transform(lines):
    _,token=check();rows=sign_transform_cases()
    if not lines or lines[0]!='G '+token:raise ValueError('Transform stale token')
    by={};footer=None;previous=-1
    for line in lines[1:]:
        f=line.split()
        if not f:raise ValueError('Blank transform event')
        if f[0]=='END':
            if footer is not None:raise ValueError('Duplicate transform footer')
            footer=list(map(int,f[1:]));continue
        if footer is not None or f[0] not in ('K','M','U','H','N','C','T','O','Q','F','X','D','E','V','BARRIER','A','L','B','Z'):raise ValueError('Unknown/trailing transform event')
        i=int(f[1])
        if i<previous or i>=len(rows):raise ValueError('Transform event order')
        previous=i;by.setdefault(i,[]).append(f)
    totals=[len(rows),0,0,0,0,0,0];needkey=True;oldp=oldnonce=None;preparations=[0,0,0]
    sentinel=tuple(reference.sample(2,0,hashlib.shake_256(b'').digest(4096))[0])
    for c in rows:
        i,p=c['i'],c['p'];k,l=((4,4),(6,5),(8,7))[p];n=l+2*k;m=sign_challenge_material(p,c['nonce']);chat=ntt_reference.direct_forward(list(m['challenge']))
        events=by.get(i,[])
        def ev(t):return [f for f in events if f[0]==t]
        def packed(v):return sum(r<<(6*j) for j,r in enumerate(v))
        if p!=oldp:needkey=True;oldnonce=None
        kh=[31,*range(n-1)];ymap=list(range(32,32+l));keymask=sum(1<<r for r in kh);ymask=sum(1<<r for r in ymap);base=keymask|ymask|(1<<50)
        free=[r for r in range(64) if not base>>r&1];work=free[:2*l+2*k+3];hats=work[:l];lo=work[2*l:2*l+k];hi=work[2*l+k:2*l+2*k]
        hatmask=sum(1<<r for r in hats);outmask=sum(1<<r for r in lo+hi);matmap=hatmask|outmask
        src_c=next(r for r in range(64) if not (base|matmap)>>r&1)
        initial=base|matmap|(1<<src_c);blockers={r for r in range(64) if not initial>>r&1} if c['inject']==5 else set()
        initial|=sum(1<<r for r in blockers);dest=next(r for r in range(64) if not (initial & ~hatmask)>>r&1)
        newmask=needkey or oldnonce!=c['nonce']
        if ev('K')!=([['K',str(i),str(p),f'{keymask:016x}',m['sk'][:32][::-1].hex()]] if needkey else []):raise ValueError('Transform real key publication')
        if ev('M')!=([['M',str(i),str(c['nonce']),f'{ymask:016x}',f'{packed(ymap):011x}',m['mu'][::-1].hex(),m['seed'][::-1].hex()]] if newmask else []):raise ValueError('Transform real mask publication')
        if ev('U')!=[['U',str(i),str(10000+p),f'{matmap:016x}',f'{packed(hats):011x}',f'{packed(lo):012x}',f'{packed(hi):012x}']]:raise ValueError('Transform real matrix publication')
        if ev('H')!=[['H',str(i),str(20000+p),str(src_c),f'{int.from_bytes(m["digest"],"little"):0128x}']]:raise ValueError('Transform real challenge publication')
        if ev('N')!=[['N',str(i),f'{initial:016x}',f'{matmap:016x}',f'{packed(hats):011x}',f'{packed(lo):012x}',f'{packed(hi):012x}']] or ev('C')!=[['C',str(i),*[str(c[x]) for x in ('p','id','nonce','inject','abort')]]]:raise ValueError('Transform source/command ledger')
        preparations[0]+=int(needkey);preparations[1]+=int(newmask);preparations[2]+=1;oldp=p;oldnonce=c['nonce'];needkey=bool(c['abort'])
        owned=set();reserved={r for r in range(64) if initial>>r&1};adopted=False;issued=False;retired=False;published=False;ended=False;taken=False;scalar=[];readorder=[];external=[];pending_external=[];hat_releases=[]
        for f in events:
            kind=f[0]
            if kind=='T':
                if adopted or c['inject'] in (1,2) or c['abort']==1 or int(f[2],16)!=initial:raise ValueError('Transform atomic handoff ledger')
                adopted=True;owned=set(hats+lo+hi+[src_c]);totals[4]+=1
            elif kind=='O':
                if not adopted or issued or hat_releases!=sorted(hats) or list(map(int,f[2:]))!=[0,src_c,(20000+p)^int(c['inject']==3),dest,c['id']] or dest in reserved:raise ValueError('Transform NTT ownership/descriptor')
                issued=True
            elif kind=='X':
                state,region,index=map(int,f[2:5]);value=int(f[5],16)
                if not issued or retired or c['inject']==3 or state not in (6,12) or state==12 and c['abort']!=5 or region!=dest or index!=len(scalar) or index>=256 or value!=chat[index]:raise ValueError('Transform exact NTT scalar write')
                scalar.append(value);totals[5]+=1
            elif kind=='Q':
                expectedcode=int(c['inject']==3)
                if not issued or retired or list(map(int,f[2:]))!=[expectedcode,c['id']^int(c['inject']==4),dest] or len(scalar)!=(0 if expectedcode else 256):raise ValueError('Transform NTT result/retirement')
                retired=True
                if not expectedcode:owned.add(dest);reserved.add(dest)
            elif kind=='F':
                state,region=map(int,f[2:])
                if state==0:
                    if region not in reserved or not(taken and region in external or region in blockers):raise ValueError('Transform unowned external release')
                    reserved.remove(region);pending_external.append(region)
                else:
                    if not adopted or region not in owned:raise ValueError('Transform foreign/duplicate release')
                    if state==3:
                        if len(hat_releases)>=len(hats) or region!=sorted(hats)[len(hat_releases)]:raise ValueError('Transform dead-yhat release')
                        hat_releases.append(region)
                    elif state==8:
                        if not retired or c['code'] or region!=src_c or dest not in owned:raise ValueError('Transform early raw-c release')
                    elif state==11:
                        if not ended and not c['code']:raise ValueError('Transform premature cleanup')
                    else:raise ValueError('Transform wrong release phase')
                    owned.remove(region);reserved.remove(region)
            elif kind=='D':
                expectedmap=outmask|(1<<dest)
                if published or c['code'] or c['abort'] or not retired or owned!=set(lo+hi+[dest]) or [int(f[2],16),*map(int,f[3:6])]!=[expectedmap,dest,10000+p,len(m['digest'])] or int(f[6],16)!=int.from_bytes(m['digest'],'little'):raise ValueError('Transform whole-result publication')
                published=True
            elif kind=='E':
                if ended or c['abort'] or list(map(int,f[2:]))!=[c['id'],c['code'],c['detail']] or not c['code'] and not published or c['code'] and owned:raise ValueError('Transform completion/rollback')
                ended=True
            elif kind=='A':
                if taken or not ended or c['inject']!=5 or int(f[2],16)!=outmask|(1<<dest) or owned!=set(lo+hi+[dest]):raise ValueError('Transform outbound transfer')
                taken=True;external=sorted(owned);owned.clear()
            elif kind=='L':
                region=int(f[2])
                if not pending_external or pending_external.pop(0)!=region:raise ValueError('Transform external release acknowledgment')
            elif kind=='V':
                if not ended:raise ValueError('Transform early public read')
                typ,j,region,word,jid,mode,param,domain=map(int,f[2:10]);data=int(f[10],16)
                if typ==0:poly=chat;metadata=(dest,c['id'],3,p,1)
                elif typ in (1,2):poly=m['low' if typ==1 else 'high'][j];metadata=((lo if typ==1 else hi)[j],10000+p,0,p,0)
                elif typ==3:poly=sign_prepare_math(m['sk'],p)[1][j];metadata=(kh[j],100+p,1 if j<l+k else 3,p,1)
                elif typ==4:poly=m['y'][j];metadata=(ymap[j],1000+p,2,p,0)
                elif typ in (5,6):
                    if typ==6 and (region not in blockers or j!=region):raise ValueError('Transform unknown blocker')
                    poly=sentinel;metadata=(50 if typ==5 else region,60000,2,0,0)
                elif typ==7:poly=m['hats'][j];metadata=(hats[j],10000+p,2,p,1)
                elif typ==8:poly=m['challenge'];metadata=(src_c,20000+p,3,p,0)
                else:raise ValueError('Unknown transform read kind')
                if not 0<=word<64 or (region,jid,mode,param,domain)!=metadata or data!=sum(poly[4*word+b]<<(23*b) for b in range(4)):raise ValueError('Transform exact read/preservation')
                readorder.append((typ,j,word));totals[6]+=1
            elif kind=='BARRIER':
                if c['code'] or not ended or int(f[2],16)!=sum(chat[b]<<(23*b) for b in range(4)):raise ValueError('Transform pending-read barrier')
        if c['abort']:
            if len(ev('Z'))!=1 or list(map(int,ev('Z')[0][2:]))!=[c['abort'],{1:2,2:3,3:6,4:9,5:12}[c['abort']]] or ev('D') or ev('E') or ev('V') or ev('B'):raise ValueError('Transform reset got success credit')
            if c['abort']==1 and (adopted or issued):raise ValueError('Blocked handoff reset moved ownership')
            if c['abort']==2 and len(hat_releases)!=1:raise ValueError('Transform release reset prefix')
            if c['abort'] in (3,5) and not 32<=len(scalar)<=36:raise ValueError('Transform partial NTT reset prefix')
            if c['abort']==4 and (not retired or owned!=set(lo+hi+[dest])):raise ValueError('Transform held-result reset prefix')
            totals[3]+=1
        else:
            if not ended or owned or ev('Z') or ev('B')!=[['B',str(i),f'{base:016x}']] or pending_external:raise ValueError('Transform final cleanup ledger')
            expected=[]
            if not c['code']:expected=[(0,0,w) for w in range(64)]+[(typ,r,w) for r in range(k) for typ in (1,2) for w in range(64)]
            elif c['inject'] in (1,2):expected=[(7,j,w) for j in range(l) for w in range(64)]+[(typ,r,w) for r in range(k) for typ in (1,2) for w in range(64)]+[(8,0,w) for w in range(64)]
            expected += [(3,j,w) for j in range(n) for w in range(64)]+[(4,j,w) for j in range(l) for w in range(64)]+[(5,0,w) for w in range(64)]+[(6,r,w) for r in sorted(blockers) for w in range(64)]
            if readorder!=expected or len(ev('BARRIER'))!=int(c['code']==0) or bool(ev('A'))!=(c['inject']==5):raise ValueError('Transform missing/duplicate consumer/transfer witness')
            if c['inject'] in (1,2) and (adopted or issued or ev('F')):raise ValueError('Transform preflight side effects')
            if c['inject'] not in (1,2) and reserved!=set(r for r in range(64) if base>>r&1):raise ValueError('Transform physical ownership leak')
            totals[1]+=1;totals[2]+=int(c['code']!=0)
    if footer!=totals:raise ValueError(f'Transform totals mismatch:{footer}!={totals}')
    return f'STAGE5N4H1_SIGN_TRANSFORM_COMPARE_PASS:{totals[0]} commands,{totals[1]-totals[2]} successes,{totals[2]} expected errors,{totals[3]} aborts,{totals[4]} atomic source transfers,{totals[5]} exact chat scalar writes,{totals[6]} packed reads;real preparations key/mask/matrix {preparations}\n'


def verify_sign_challenge(lines):
    _,token=check();rows=sign_challenge_cases()
    if not lines or lines[0]!='G '+token:raise ValueError('Challenge stale token')
    by={};footer=None;previous=-1
    for line in lines[1:]:
        f=line.split()
        if not f:raise ValueError('Blank challenge event')
        if f[0]=='END':
            if footer is not None:raise ValueError('Duplicate challenge footer')
            footer=list(map(int,f[1:]));continue
        if footer is not None or f[0] not in ('K','M','U','N','C','B','L','I','O','T','P','H','W','R','Q','J','A','S','X','F','D','E','V','BARRIER','ST','Z'):raise ValueError('Unknown/trailing challenge event')
        i=int(f[1])
        if i<previous or i>=len(rows):raise ValueError('Challenge event order')
        previous=i;by.setdefault(i,[]).append(f)
    totals=[len(rows),0,0,0,0,0,0,0,0,0,0];allstalls=[0]*7;needkey=True;oldp=oldnonce=None
    sentinel=tuple(reference.sample(2,0,hashlib.shake_256(b'').digest(4096))[0])
    for c in rows:
        i,p=c['i'],c['p'];k,l=((4,4),(6,5),(8,7))[p];n=l+2*k;m=sign_challenge_material(p,c['nonce']);events=by.get(i,[])
        def ev(t):return [f for f in events if f[0]==t]
        if p!=oldp:needkey=True;oldnonce=None
        keyregions=[31,*range(n-1)];ymap=list(range(32,32+l));keymask=sum(1<<r for r in keyregions);maskmap=sum(1<<r for r in ymap)
        base=keymask|maskmap|(1<<50);free=[r for r in range(64) if not base>>r&1];work=free[:2*l+2*k+3]
        hats=work[:l];lo=work[2*l:2*l+k];hi=work[2*l+k:2*l+2*k];matmap=sum(1<<r for r in hats+lo+hi)
        def packed(v):return sum(r<<(6*j) for j,r in enumerate(v))
        newmat=needkey or oldnonce!=c['nonce']
        if ev('K')!=([['K',str(i),str(p),f'{keymask:016x}',m['sk'][:32][::-1].hex()]] if needkey else []):raise ValueError('Challenge retained key publication')
        if ev('M')!=([['M',str(i),str(c['nonce']),f'{maskmap:016x}',f'{packed(ymap):011x}',m['mu'][::-1].hex(),m['seed'][::-1].hex()]] if newmat else []):raise ValueError('Challenge real mask/hash publication')
        if ev('U')!=([['U',str(i),str(10000+p),f'{matmap:016x}',f'{packed(hats):011x}',f'{packed(lo):012x}',f'{packed(hi):012x}']] if newmat else []):raise ValueError('Challenge real matrix publication')
        totals[9]+=int(needkey);totals[10]+=int(newmat);oldp=p;oldnonce=c['nonce'];needkey=bool(c['abort'])
        source=base|matmap;blockers={r for r in range(64) if not source>>r&1} if c['inject']==13 else set()
        initial=source|sum(1<<r for r in blockers);dest=next((r for r in range(64) if not initial>>r&1),0)
        if ev('N')!=[['N',str(i),f'{initial:016x}']] or ev('C')!=[['C',str(i),*[str(c[x]) for x in ('p','id','nonce','inject','abort')]]]:raise ValueError('Challenge command/reservation mismatch')
        packet=None;started=[];retired=[];payload=bytearray();abandoned=False;rawinput=bytearray();rawdata=bytearray();rawcore=None;rawdone=False
        samplecore=None;sampleinput=bytearray();samples=[];status=False;owned=False;ended=False;published=False;read_order=[];released=[];last_read=None
        for f in events:
            kind=f[0]
            if kind=='B':
                poly,op,param,jid=map(int,f[2:])
                if packet is not None or poly!=len(started) or poly>=k or (op,param,jid)!=(3,p,c['id']):raise ValueError('Challenge pack command/retirement')
                packet=dict(poly=poly,sent=0,bits=0,count=0,words=0,failed=False);started.append(poly);last_read=None
            elif kind=='L':
                poly,word,region,jid,mode,param,domain=map(int,f[2:9]);data=int(f[9],16)
                if packet is None or poly!=packet['poly'] or word>=64 or region!=hi[poly]:raise ValueError('Challenge source-read ownership')
                expected_id=(10000+p)^(1 if c['inject']==1 and poly==0 and word==0 else 0)
                expected_mode=3 if c['inject']==2 and poly==k-1 and word==7 else 0
                gold=sum(m['high'][poly][4*word+b]<<(23*b) for b in range(4))
                if c['inject']==3 and poly==1 and word==5:gold=(gold & ~((1<<23)-1))|(44 if p==0 else 16)
                if (jid,mode,param,domain)!=(expected_id,expected_mode,p,0) or data!=gold:raise ValueError('Challenge exact observed source read')
                last_read=(poly,word,data)
            elif kind=='I':
                poly,index,last=map(int,f[2:5]);value=int(f[5],16);state=int(f[6])
                if packet is None or poly!=packet['poly'] or packet['failed'] or packet['sent']>=256:raise ValueError('Challenge unowned pack input')
                r=packet;number=r['sent'];expected_index=number^(1 if c['inject']==4 and poly==0 and number==37 else 0)
                if index!=expected_index or last!=int(number==255) or state not in (7,10):raise ValueError('Challenge pack input frame')
                if state==10:expected=0
                else:
                    if last_read is None or last_read[:2]!=(poly,number//4):raise ValueError('Pack input without cached bank word')
                    expected=(last_read[2]>>(23*(number%4)))&((1<<23)-1)
                if value!=expected:raise ValueError('Challenge scalar source/zero-drain value')
                r['sent']+=1;totals[4]+=1
                if value>(43 if p==0 else 15) or index!=number:
                    r['failed']=True;r['bits']=0;r['count']=0
                else:r['bits']|=value<<r['count'];r['count']+=(6 if p==0 else 4)
            elif kind=='O':
                poly,jid,index,size,last=map(int,f[2:7]);data=int(f[7],16)
                if packet is None or packet['poly']!=poly or packet['failed'] or packet['count']<64:raise ValueError('Challenge packed output without valid bits')
                r=packet;expectedid=c['id']^(1 if c['inject']==5 and poly==1 and r['words']==3 else 0)
                if (jid,index,size,last)!=(expectedid,r['words'],8,int(r['sent']==256 and r['count']==64)) or data!=(r['bits']&((1<<64)-1)):raise ValueError('Challenge exact packed bytes/tag')
                r['bits']>>=64;r['count']-=64;r['words']+=1;totals[5]+=1
            elif kind=='T':
                poly,jid,code=map(int,f[2:]);expectedcode=2 if c['inject']==3 and poly==1 else 3 if c['inject']==4 and poly==0 else 0
                if packet is None or poly!=packet['poly'] or jid!=c['id']^(1 if c['inject']==6 and poly==k-1 else 0) or code!=expectedcode:raise ValueError('Challenge pack result')
                if not code and (packet['sent']!=256 or packet['count']!=0):raise ValueError('Short completed packed polynomial')
                if code and not packet['failed']:raise ValueError('Unexercised packing error')
                retired.append(poly);packet=None
            elif kind=='P':
                index,size,last=map(int,f[2:5]);data=int(f[5],16)
                if abandoned or index!=len(payload)//8:raise ValueError('Challenge payload index/abandon')
                if size==0:abandoned=True
                elif size==8:
                    if data!=int.from_bytes(m['packed'][len(payload):len(payload)+8],'little') or last!=int(len(payload)+8==len(m['packed'])):raise ValueError('Challenge actual w1 byte forwarding')
                    payload.extend(data.to_bytes(8,'little'))
                else:raise ValueError('Challenge payload bytes')
            elif kind=='H':
                jid,length,outlen,core=map(int,f[2:])
                if rawcore is not None or (jid,length,outlen)!=(c['id'],64+len(m['packed']),len(m['digest'])) or core not in (0,1):raise ValueError('Challenge hash descriptor')
                rawcore=core
            elif kind=='W':
                index,size=map(int,f[2:4]);data=int(f[4],16);offset=len(rawinput)
                available=m['mu']+payload
                if abandoned:available=available.ljust(64+len(m['packed']),b'\0')
                if rawcore is None or rawdone or index!=offset//8 or size!=8 or offset+8>len(available) or data!=int.from_bytes(available[offset:offset+8],'little'):raise ValueError('Challenge exact hash absorption/drain')
                rawinput.extend(data.to_bytes(8,'little'))
            elif kind=='R':
                jid,core,size=map(int,f[2:5]);data=int(f[5],16)
                if len(rawinput)!=64+len(m['packed']) or rawdone:raise ValueError('Early challenge digest')
                digest=hashlib.shake_256(rawinput).digest(len(m['digest']));offset=len(rawdata)
                expectedid=c['id']^(1 if c['inject']==7 else 0);expectedsize=15 if c['inject']==8 else 16
                if (jid,core,size)!=(expectedid,rawcore,expectedsize) or offset>=len(digest) or data!=int.from_bytes(digest[offset:offset+16],'little'):raise ValueError('Challenge hash bytes/tag')
                rawdata.extend(data.to_bytes(16,'little'));totals[6]+=1
            elif kind=='Q':
                if rawdone or len(rawdata)!=len(m['digest']) or list(map(int,f[2:]))!=[c['id']^(1 if c['inject']==9 else 0),rawcore]:raise ValueError('Challenge hash retirement')
                rawdone=True
            elif kind=='J':
                jid,param,length,region,core=map(int,f[2:])
                if samplecore is not None or not rawdone or len(retired)!=k or c['inject'] in range(1,10) or bytes(payload)!=m['packed'] or bytes(rawdata)!=m['digest'] or (jid,param,length,region)!=(c['id'],p,len(m['digest']),dest):raise ValueError('Invalid challenge hash forwarded to sampler')
                samplecore=core
            elif kind=='A':
                word=int(f[2]);data=int(f[3],16)
                if samplecore is None or word!=len(sampleinput)//8 or len(sampleinput)>=len(m['digest']) or data!=int.from_bytes(m['digest'][8*word:8*word+8],'little'):raise ValueError('Challenge sampler seed bytes')
                sampleinput.extend(data.to_bytes(8,'little'))
            elif kind=='X':
                state,region,index=map(int,f[2:5]);value=int(f[5],16)
                if state not in (13,17) or state==17 and c['abort']!=6 or bytes(sampleinput)!=m['digest'] or region!=dest or index!=len(samples) or index>=256 or value!=m['challenge'][index]:raise ValueError('Exact SampleInBall write')
                samples.append(value);totals[7]+=1
            elif kind=='S':
                if status or len(samples)!=256 or list(map(int,f[2:]))!=[c['id']^(1 if c['inject']==10 else 0),samplecore,7 if c['inject']==11 else 0]:raise ValueError('Challenge sampler retirement')
                status=True;owned=True
            elif kind=='F':
                region=int(f[2])
                if region in blockers:blockers.remove(region)
                elif region==dest and owned:owned=False;released.append(region)
                else:raise ValueError('Challenge foreign/duplicate release')
            elif kind=='D':
                if c['code'] or c['abort'] or published or not status or not owned or list(map(int,f[2:4]))!=[dest,len(m['digest'])] or int(f[4],16)!=int.from_bytes(m['digest'],'little'):raise ValueError('Premature/wrong challenge publication')
                published=True
            elif kind=='E':
                if ended or c['abort'] or list(map(int,f[2:]))!=[c['id'],c['code'],c['detail']] or not c['code'] and not published or c['code'] and owned:raise ValueError('Challenge parent completion/cleanup')
                ended=True
            elif kind=='V':
                if not ended:raise ValueError('Challenge early consumer')
                typ,j,region,word,jid,mode,param,domain=map(int,f[2:10]);data=int(f[10],16)
                if typ==0:
                    if c['code']:raise ValueError('Failed challenge read')
                    poly=m['challenge'];expected=(dest,c['id'],3,p,0)
                elif typ==1:poly=sign_prepare_math(m['sk'],p)[1][j];expected=(keyregions[j],100+p,1 if j<l+k else 3,p,1)
                elif typ==2:poly=m['y'][j];expected=(ymap[j],1000+p,2,p,0)
                elif typ==3:poly=m['hats'][j];expected=(hats[j],10000+p,2,p,1)
                elif typ==4:poly=m['low'][j];expected=(lo[j],10000+p,0,p,0)
                elif typ==5:poly=m['high'][j];expected=(hi[j],10000+p,0,p,0)
                elif typ==6:poly=sentinel;expected=(50,60000,2,0,0)
                elif typ==7:
                    if region not in blockers or j!=region:raise ValueError('Unknown challenge blocker read')
                    poly=sentinel;expected=(region,60000,2,0,0)
                else:raise ValueError('Unknown challenge read kind')
                if not 0<=word<64 or (region,jid,mode,param,domain)!=expected or data!=sum(poly[4*word+b]<<(23*b) for b in range(4)):raise ValueError('Challenge result/source preservation')
                read_order.append((typ,j,word));totals[8]+=1
            elif kind=='BARRIER':
                if c['code'] or not ended or int(f[2],16)!=sum(m['challenge'][b]<<(23*b) for b in range(4)):raise ValueError('Challenge clear/read barrier')
        if c['abort']:
            if len(ev('Z'))!=1 or int(ev('Z')[0][2])!=c['abort'] or ev('D') or ev('E') or ev('V'):raise ValueError('Challenge reset received success credit')
            if c['abort']==1 and totals is not None and sum(1 for f in ev('I'))!=17:raise ValueError('Challenge input reset prefix')
            if c['abort']==2 and ev('O'):raise ValueError('Challenge held output reset prefix')
            if c['abort']==3 and len(rawdata)!=16:raise ValueError('Challenge digest reset prefix')
            if c['abort'] in (4,6) and not 32<=len(samples)<=38:raise ValueError('Challenge partial sample reset prefix')
            if c['abort']==5 and (not status or len(samples)!=256):raise ValueError('Challenge held-done reset prefix')
            totals[3]+=1
        else:
            if not ended or ev('Z') or len(ev('ST'))!=1 or owned or blockers:raise ValueError('Challenge missing completion/cleanup/witness')
            expected_reads=[(0,0,w) for w in range(64)] if not c['code'] else []
            expected_reads += [(1,j,w) for j in range(n) for w in range(64)]+[(typ,j,w) for j in range(l) for typ in (2,3) for w in range(64)]+[(typ,r,w) for r in range(k) for typ in (4,5) for w in range(64)]+[(6,0,w) for w in range(64)]
            initial_blockers=[r for r in range(64) if (initial & ~source)>>r&1]
            expected_reads += [(7,r,w) for r in initial_blockers for w in range(64)]
            if read_order!=expected_reads or len(ev('BARRIER'))!=int(c['code']==0):raise ValueError('Challenge missing/duplicate read/barrier')
            if c['inject'] in (12,13) and (started or rawcore is not None or samplecore is not None):raise ValueError('Challenge preflight side effects')
            if c['code'] and samplecore is not None and c['inject'] not in (10,11):raise ValueError('Invalid dependent challenge job')
            if c['code'] in (3,4) and not abandoned:raise ValueError('Failed pack/read did not terminate hash payload')
            if rawcore is not None and not rawdone:raise ValueError('Challenge error before physical raw retirement')
            for j,v in enumerate(map(int,ev('ST')[0][2:])):allstalls[j]+=v
            totals[1]+=1;totals[2]+=int(c['code']!=0)
    if footer!=totals or not all(allstalls):raise ValueError(f'Challenge totals/stalls mismatch:{footer}!={totals}')
    return f'STAGE5N4G_SIGN_CHALLENGE_COMPARE_PASS:{totals[0]} commands,{totals[1]-totals[2]} successes,{totals[2]} expected errors,{totals[3]} reset/fault aborts,{totals[4]} pack inputs,{totals[5]} packed words,{totals[6]*16} digest bytes,{totals[7]} challenge scalar writes,{totals[8]} packed reads,{totals[9]} key preparations,{totals[10]} source mask/matrix vectors;stalls {allstalls}\n'


@lru_cache(maxsize=None)
def sign_matrix_material(p,nonce):
    sk=next(c['sk'] for c in sign_decode_cases() if c['p']==p and c['official'])
    k,l=((4,4),(6,5),(8,7))[p];q=ntt_reference.Q
    body=hashlib.shake_256(f'sign-matrix-body-{p}'.encode()).digest(176)
    rnd=hashlib.shake_256(f'sign-matrix-rnd-{p}'.encode()).digest(32)
    mu=hashlib.shake_256(sk[64:128]+b'\0\7'+body).digest(64)
    seed=hashlib.shake_256(sk[32:64]+rnd+mu).digest(64)
    y=tuple(tuple(reference.sample(2,p,hashlib.shake_256(seed+(nonce+j).to_bytes(2,'little')).digest(4096))[0]) for j in range(l))
    hats=tuple(tuple(ntt_reference.direct_forward(list(v))) for v in y)
    matrix=tuple(tuple(tuple(reference.sample(0,p,hashlib.shake_128(sk[:32]+bytes((j,r))).digest(4096))[0]) for j in range(l)) for r in range(k))
    products=[];accum=[];w=[];low=[];high=[]
    for r in range(k):
        row=tuple(tuple(a*b%q for a,b in zip(matrix[r][j],hats[j],strict=True)) for j in range(l));products.append(row)
        prefix=[];total=(0,)*256
        for v in row:total=tuple((a+b)%q for a,b in zip(total,v,strict=True));prefix.append(total)
        accum.append(tuple(prefix));poly=tuple(ntt_reference.direct_inverse(list(total)));w.append(poly)
        pairs=[mathematical_decompose(v,p) for v in poly]
        high.append(tuple(v[0] for v in pairs));low.append(tuple(v[1]%q for v in pairs))
    return dict(sk=sk,body=body,rnd=rnd,mu=mu,seed=seed,y=y,hats=hats,matrix=matrix,products=tuple(products),
                accum=tuple(accum),w=tuple(w),low=tuple(low),high=tuple(high))


@lru_cache(maxsize=1)
def sign_matrix_cases():
    rows=[]
    for p,l in enumerate((4,5,7)):
        def add(inject=0,abort=0,nonce=0,jid=None):
            code,detail={0:(0,0),1:(2,0),2:(3,1),3:(7,0),4:(7,0),5:(5,1),6:(7,0),7:(6,1),8:(7,0)}[inject]
            i=len(rows);rows.append(dict(i=i,p=p,id=30000+i if jid is None else jid,nonce=nonce,inject=inject,abort=abort,code=code,detail=detail))
        add();add(nonce=l,jid=65535)
        for inject in range(1,9):add(inject=inject)
        for abort in range(1,7):add(abort=abort);add()
    return rows


def sign_matrix_artifact(token):
    rows=sign_matrix_cases()
    return f'{token} {len(rows)}\n'+''.join(' '.join(str(c[k]) for k in ('i','p','id','nonce','inject','abort'))+
        f" {m['rnd'][::-1].hex()} {len(m['sk'])} {m['sk'].hex()} {m['body'].hex()}\n"
        for c in rows for m in [sign_matrix_material(c['p'],c['nonce'])])


def check_sign_matrix_c():
    gcc=shutil.which('gcc');ref=ROOT/'dilithium-sw-model/ref';count=values=0
    if not gcc:raise ValueError('GCC required for signing matrix oracle')
    for p,level in enumerate((2,3,5)):
        exe=HERE/f'reference_build/sign_matrix_reference_{level}.exe'
        subprocess.run([gcc,'-std=c99','-O2',f'-DDILITHIUM_MODE={level}','-I',str(ref),str(ROOT/'tb/tb_dilithium/reference/sign_matrix_reference.c'),
            *[str(ref/n) for n in ('polyvec.c','poly.c','rounding.c','reduce.c','ntt.c','symmetric-shake.c','fips202.c')],'-o',str(exe)],check=True,capture_output=True,text=True)
        materials=[(n,sign_matrix_material(p,n)) for n in (0,(4,5,7)[p])]
        answer=subprocess.run([str(exe)],input=''.join(' '.join(map(str,[n,*m['sk'][:32],*m['seed']]))+'\n' for n,m in materials),capture_output=True,text=True,check=True).stdout.splitlines()
        if len(answer)!=2:raise ValueError('Matrix C fixture count')
        for (_,m),line in zip(materials,answer,strict=True):
            polys=[*m['y'],*m['hats'],*[v for row in m['matrix'] for v in row],*m['w'],*m['low'],*m['high']]
            expected=[v for poly in polys for v in poly]
            if list(map(int,line.split()))!=expected:raise ValueError('Matrix Python direct-evaluation/C result mismatch')
            count+=1;values+=len(expected)
    message=f'PYTHON_C_SIGN_MATRIX_PASS:{count} full vector fixtures,{values} coefficients;y,yhat,A,w,w0,w1;direct evaluation/formula versus unchanged C expand/NTT/PWM/INTT/decompose\n'
    (HERE/'stage5_sign_matrix_c_reference.log').write_text(message);print(message,end='')


def verify_sign_matrix(lines):
    _,token=check();rows=sign_matrix_cases()
    if not lines or lines[0]!='H '+token:raise ValueError('Matrix stale token')
    by={};footer=None;previous=-1
    for line in lines[1:]:
        f=line.split()
        if not f:raise ValueError('Blank matrix event')
        if f[0]=='Z':
            if footer is not None:raise ValueError('Duplicate matrix totals')
            footer=list(map(int,f[1:]));continue
        if footer is not None or f[0] not in ('K','M','I','C','G','N','O','J','W','S','R','Q','D','B','X','F','L','P','E','V','T','A'):raise ValueError('Unknown/trailing matrix record')
        i=int(f[1])
        if i<previous or i>=len(rows):raise ValueError('Matrix event order')
        previous=i;by.setdefault(i,[]).append(f)
    totals=[len(rows),0,0,0,0,0,0,0];stalls=[0]*7;peaks={};needkey=True;oldp=None;oldnonce=None
    sentinel=tuple(reference.sample(2,0,hashlib.shake_256(b'').digest(4096))[0])
    for c in rows:
        i,p=c['i'],c['p'];k,l=((4,4),(6,5),(8,7))[p];n=l+2*k;m=sign_matrix_material(p,c['nonce']);events=by.get(i,[])
        def ev(t):return [f for f in events if f[0]==t]
        if ev('C')!=[['C',str(i),*[str(c[x]) for x in ('p','id','nonce','inject','abort')]]]:raise ValueError('Matrix command mismatch')
        if p!=oldp:needkey=True;oldnonce=None
        keyregions=[31,*range(n-1)];ymap=list(range(32,32+l));keymask=sum(1<<r for r in keyregions);maskmap=sum(1<<r for r in ymap)
        if ev('K')!=([['K',str(i),str(p),f'{keymask:016x}',m['sk'][:32][::-1].hex()]] if needkey else []):raise ValueError('Matrix key publication/reuse')
        expectedmask=[['M',str(i),str(c['nonce']),f'{maskmap:016x}',f'{sum(r<<(6*j) for j,r in enumerate(ymap)):011x}',m['mu'][::-1].hex(),m['seed'][::-1].hex()]]
        newmask=needkey or oldnonce!=c['nonce']
        if ev('M')!=(expectedmask if newmask else []):raise ValueError('Matrix mask provenance/reuse')
        totals[6]+=int(needkey);totals[7]+=int(newmask);oldp=p;oldnonce=c['nonce'];needkey=bool(c['abort'])
        initial=keymask|maskmap|(1<<50);free=[r for r in range(64) if not initial>>r&1];needed=2*l+2*k+3;blockers=set()
        if c['inject']==1:
            blockers=set(free[:len(free)-needed+1]);initial|=sum(1<<r for r in blockers);free=[r for r in free if r not in blockers]
        if ev('I')!=[['I',str(i),f'{initial:016x}']]:raise ValueError('Matrix entry reservation map')
        work=free[:needed];hat=work[:l];a=work[l:2*l];lo=work[2*l:2*l+k];hi=work[2*l+k:2*l+2*k]
        acc,scratch,w=work[-3:];plan=sum(1<<r for r in work);persist=set(hat+lo+hi)
        def packed(v):return sum(r<<(6*j) for j,r in enumerate(v))
        expectedplan=[['G',str(i),f'{plan:016x}',f'{packed(hat):011x}',f'{packed(a):011x}',f'{packed(lo):012x}',f'{packed(hi):012x}',str(acc),str(scratch),str(w)]]
        if ev('G')!=([] if c['inject']==1 else expectedplan):raise ValueError('Matrix workspace assignment')
        ns=[];os=[];jobs=[];statuses=[];rowcmd=[];rowdone=[];decomp=[];decdone=[]
        written={};finishes={};owned=set();parent_releases=[];ended=False;published=False;read_order=[];active={};word_counts={}
        @lru_cache(maxsize=None)
        def family(phase,row,col,region):
            if phase==4:
                if row!=0 or col>=l or region!=hat[col]:raise ValueError('Forward write destination')
                return m['hats'][col],256
            if phase==6:
                if row>=k or col>=l or region!=a[col]:raise ValueError('Matrix sample destination')
                return m['matrix'][row][col],256
            if phase==8:
                if col!=l-1 or row>=k:raise ValueError('Row write owner')
                if region==acc:return tuple(v for poly in m['accum'][row] for v in poly),l*256
                if region==scratch:return tuple(v for poly in m['products'][row][1:] for v in poly),(l-1)*256
                if region==w:return m['w'][row],256
                raise ValueError('Unexpected row write region')
            if phase==10:
                if col!=l-1 or row>=k:raise ValueError('Decompose write owner')
                if region==lo[row]:return m['low'][row],256
                if region==hi[row]:return m['high'][row],256
                raise ValueError('Unexpected decompose region')
            raise ValueError('Unowned matrix write phase')
        for f in events:
            kind=f[0]
            if kind=='N':
                col,src,dst,sid,jid=map(int,f[2:]);expectedcol=len(ns)
                if col!=expectedcol or col>=l or src!=ymap[col] or dst!=hat[col] or jid!=c['id'] or sid!=(1000+p)^(1 if c['inject']==2 and col==1 else 0):raise ValueError('Matrix forward request')
                if len(os)!=len(ns):raise ValueError('Forward request before prior retirement')
                ns.append(col);active[4]=(0,col)
            elif kind=='O':
                col,jid,region,code,physical=map(int,f[2:]);expectedcode=1 if c['inject']==2 and col==1 else 0
                if col!=len(os) or col not in ns or region!=hat[col] or physical!=expectedcode or code!=expectedcode or jid!=c['id']^(1 if c['inject']==3 and col==1 else 0):raise ValueError('Matrix forward result')
                if not physical and written.get((4,0,col,region),0)!=256:raise ValueError('Early forward result')
                os.append(col)
            elif kind=='J':
                row,col,jid,region,core=map(int,f[2:]);expected=(len(jobs)//l,len(jobs)%l)
                if (row,col)!=expected or jid!=c['id'] or region!=a[col] or core not in (0,1) or len(os)!=l or len(statuses)!=len(jobs) or region in owned:raise ValueError('Matrix sampling descriptor/workspace reuse')
                if row and (row-1) not in decdone:raise ValueError('Matrix row workspace reused before decomposition')
                jobs.append((row,col,core));active[6]=(row,col)
            elif kind=='W':
                row,col=map(int,f[2:4]);key=(row,col);offset=word_counts.get(key,0)*8;message=m['sk'][:32]+bytes((col,row))
                if not jobs or jobs[-1][:2]!=key or offset>=34 or int(f[4],16)!=int.from_bytes(message[offset:offset+8],'little'):raise ValueError('Matrix exact rho/column/row absorption')
                word_counts[key]=word_counts.get(key,0)+1
            elif kind=='S':
                row,col,jid,core,code=map(int,f[2:]);index=len(statuses)
                if index>=len(jobs) or (row,col,core)!=jobs[index] or jid!=c['id']^(1 if c['inject']==4 and row==1 and col==1 else 0) or code!=0 or word_counts.get((row,col))!=5 or written.get((6,row,col,a[col]))!=256:raise ValueError('Matrix sampling retirement')
                statuses.append((row,col))
            elif kind=='R':
                row,jid,sid=map(int,f[2:]);expectedrow=len(rowcmd)
                if row!=expectedrow or jid!=c['id'] or sid!=c['id']^(1 if c['inject']==5 and row==1 else 0) or len(statuses)!=(row+1)*l:raise ValueError('Matrix row request')
                rowcmd.append(row);active[8]=(row,l-1)
            elif kind=='Q':
                row,jid,region,code,terms=map(int,f[2:]);expectedcode=1 if c['inject']==5 and row==1 else 0
                if row!=len(rowdone) or row not in rowcmd or jid!=c['id']^(1 if c['inject']==6 and row==1 else 0) or region!=w or code!=expectedcode or terms!=(0 if expectedcode else l):raise ValueError('Matrix row retirement')
                if not code:
                    for region_,size in ((acc,l*256),(scratch,(l-1)*256),(w,256)):
                        if written.get((8,row,l-1,region_))!=size:raise ValueError('Incomplete row arithmetic')
                    owned.discard(acc);owned.discard(scratch)
                rowdone.append(row)
            elif kind=='D':
                row,src,dst,high,sid=map(int,f[2:])
                if row!=len(decomp) or row not in rowdone or (src,dst,high)!=(w,lo[row],hi[row]) or sid!=c['id']^(1 if c['inject']==7 and row==1 else 0):raise ValueError('Matrix decomposition request')
                decomp.append(row);active[10]=(row,l-1)
            elif kind=='B':
                row,jid,dst,high,code=map(int,f[2:]);expectedcode=1 if c['inject']==7 and row==1 else 0
                expectedhi=hi[row]^(1 if c['inject']==8 and row==k-1 else 0)
                if row!=len(decdone) or row not in decomp or (jid,dst,high,code)!=(c['id'],lo[row],expectedhi,expectedcode):raise ValueError('Matrix decomposition result')
                if not code and (written.get((10,row,l-1,lo[row]))!=256 or written.get((10,row,l-1,hi[row]))!=256):raise ValueError('Incomplete decomposition')
                decdone.append(row)
            elif kind=='X':
                phase,row,col,region,index=map(int,f[2:7]);key=(phase,row,col,region);offset=written.get(key,0)
                # Injected parent fault halts this client while the actual row
                # engine drains a few more values before GLOBAL reset.
                if phase==16 and c['abort']==6:phase=8;key=(phase,row,col,region);offset=written.get(key,0)
                if active.get(phase)!=(row,col):raise ValueError(f'Unowned matrix scalar write case{i}:{f},active={active}')
                gold,limit=family(phase,row,col,region)
                if offset>=limit or index!=offset%256 or int(f[7],16)!=gold[offset]:raise ValueError('Exact NTT/matrix/PWM/ADD/INTT/decompose write mismatch')
                written[key]=offset+1;totals[4]+=1
            elif kind=='F':
                phase,region,code=map(int,f[2:]);row,col=active[phase];key=(phase,row,col,region);number=finishes.get(key,0)+1
                if code or written.get(key,0)!=number*256:raise ValueError('Matrix finish acknowledgment before full writes/duplicate')
                finishes[key]=number;owned.add(region)
            elif kind=='L':
                phase,region=map(int,f[2:])
                if phase==0:
                    if region not in blockers:raise ValueError('Foreign blocker release')
                    blockers.remove(region)
                else:
                    if region not in owned or phase not in (12,15) or phase==12 and region in persist:raise ValueError('Foreign/premature matrix release')
                    owned.remove(region);parent_releases.append(region)
            elif kind=='P':
                if c['code'] or c['abort'] or published or len(decdone)!=k or owned!=persist:raise ValueError('Premature matrix publication')
                if list(int(v,16) for v in f[2:])!=[sum(1<<r for r in persist),packed(hat),packed(lo),packed(hi)]:raise ValueError('Matrix publication handles')
                published=True
            elif kind=='E':
                if ended or c['abort'] or list(map(int,f[2:]))!=[c['id'],c['code'],c['detail']] or not c['code'] and not published:raise ValueError('Matrix parent completion')
                if c['code'] and owned:raise ValueError('Matrix error done before rollback')
                ended=True
            elif kind=='V':
                if not ended:raise ValueError('Matrix early consumer read')
                typ,j,region,word,jid,mode,param,domain=map(int,f[2:10]);data=int(f[10],16)
                if not 0<=word<64:raise ValueError('Matrix read word')
                if typ<=2:
                    if c['code']:raise ValueError('Read of failed matrix output')
                    regions=(hat,lo,hi)[typ];poly=(m['hats'],m['low'],m['high'])[typ][j]
                    expected=(regions[j],c['id'],2 if typ==0 else 0,p,int(typ==0))
                elif typ==3:
                    poly=sign_prepare_math(m['sk'],p)[1][j];expected=(keyregions[j],100+p,1 if j<l+k else 3,p,1)
                elif typ==4:poly=m['y'][j];expected=(ymap[j],1000+p,2,p,0)
                elif typ==5:poly=sentinel;expected=(50,60000,2,0,0)
                elif typ==6:
                    if region not in blockers or j!=region:raise ValueError('Unknown capacity blocker read')
                    poly=sentinel;expected=(region,60000,2,0,0)
                else:raise ValueError('Unknown matrix read type')
                if (region,jid,mode,param,domain)!=expected or data!=sum(poly[4*word+b]<<(23*b) for b in range(4)):raise ValueError('Matrix result/source/sentinel exact read mismatch')
                read_order.append((typ,j,word));totals[5]+=1
        if c['abort']:
            if len(ev('A'))!=1 or int(ev('A')[0][2])!=c['abort'] or ev('E') or ev('P') or ev('V'):raise ValueError('Matrix abort got completion credit')
            phase=c['abort']
            if phase==1 and (len(ns)!=1 or not 32<=written.get((4,0,0,hat[0]),0)<=36):raise ValueError('NTT reset prefix witness')
            if phase==2 and (len(jobs)!=2 or not 32<=written.get((6,0,1,a[1]),0)<=36):raise ValueError('Matrix sample reset prefix witness')
            if phase in (3,6) and (len(rowcmd)!=1 or not 32<=written.get((8,0,l-1,acc),0)<=38):raise ValueError('Row reset prefix witness')
            if phase==4 and (len(decomp)!=1 or finishes.get((10,0,l-1,lo[0]))!=1 or finishes.get((10,0,l-1,hi[0]),0)!=0):raise ValueError('Decompose dual-commit reset witness')
            if phase==5 and len(decdone)!=k:raise ValueError('Held successful result reset witness')
            totals[3]+=1
        else:
            if not ended or len(ev('T'))!=1 or ev('A') or owned or blockers:raise ValueError('Matrix missing completion/clear/rollback')
            if not c['code']:
                expected_reads=[(0,j,w_) for j in range(l) for w_ in range(64)]+[(typ,r,w_) for r in range(k) for typ in (1,2) for w_ in range(64)]
            else:expected_reads=[]
            expected_reads += [(3,j,w_) for j in range(n) for w_ in range(64)]+[(4,j,w_) for j in range(l) for w_ in range(64)]+[(5,0,w_) for w_ in range(64)]
            initial_blockers=[r for r in range(64) if (initial & ~(keymask|maskmap|(1<<50)))>>r&1]
            expected_reads += [(6,r,w_) for r in initial_blockers for w_ in range(64)]
            if read_order!=expected_reads:raise ValueError('Matrix missing/duplicate readbacks')
            if c['inject']==1 and (ns or jobs or rowcmd or decomp):raise ValueError('Capacity rejection performed work')
            # Verify invalid observed results do not reach their dependent phase.
            limits={2:(2,0,0,0),3:(2,0,0,0),4:(l,l+2,1,1),5:(l,2*l,2,1),6:(l,2*l,2,1),7:(l,2*l,2,2),8:(l,k*l,k,k)}
            if c['inject'] in limits and (len(ns),len(jobs),len(rowcmd),len(decomp))!=limits[c['inject']]:raise ValueError('Bad result forwarded to dependent phase')
            witness=list(map(int,ev('T')[0][2:]));peaks[p]=max(peaks.get(p,0),witness[-1])
            if len(witness)!=8 or any(v<0 for v in witness) or not 0<witness[-1]<=64:raise ValueError('Invalid matrix stall/peak witness')
            for j,value in enumerate(witness[:7]):stalls[j]+=value
            totals[1]+=1;totals[2]+=int(c['code']!=0)
    if footer!=totals or not all(stalls):raise ValueError(f'Matrix totals/witness mismatch:{footer}!={totals}')
    return f'STAGE5N4F_SIGN_MATRIX_COMPARE_PASS:{totals[0]} commands,{totals[1]-totals[2]} successes,{totals[2]} expected errors,{totals[3]} reset/fault aborts,{totals[4]} exact scalar writes,{totals[5]} packed reads,{totals[6]} key preparations,{totals[7]} mask vectors;stall witnesses {stalls};peak allocated with sentinel {peaks}\n'


@lru_cache(maxsize=1)
def sign_mask_cases():
    """Local signing-front-end fixtures using three published NIST SK inputs.

    Expected mu/seed/masks are FIPS-derived,not official signature vectors.
    """
    rows=[]
    for p,l in enumerate((4,5,7)):
        sk=next(c['sk'] for c in sign_decode_cases() if c['p']==p and c['official'])
        def add(ctx=7,mlen=169,nonce=0,base=32,fault=0,abort=0,zero=False):
            i=len(rows);body=hashlib.shake_256(f'mask-body-{p}-{ctx}-{mlen}'.encode()).digest(ctx+mlen)
            rnd=bytes(32) if zero else hashlib.shake_256(f'mask-rnd-{p}'.encode()).digest(32)
            tr,key=sk[64:128],sk[32:64]
            message=tr+b'\0'+bytes([ctx&255])+body
            emitted=message[:66]+bytes(len(body)) if fault==1 else message
            mu=hashlib.shake_256(emitted).digest(64)
            seed=hashlib.shake_256(key+rnd+mu).digest(64)
            code=2 if base+l>64 or nonce+l>65536 or ctx>255 or len(message)>65535 or base==0 else 3 if base==50 else 4 if fault==1 else 5 if fault else 0
            values=tuple(tuple(reference.sample(2,p,hashlib.shake_256(seed+(nonce+j).to_bytes(2,'little')).digest(4096))[0]) for j in range(l)) if nonce+l<=65536 else ()
            rows.append(dict(i=i,p=p,id=20000+i,ctx=ctx,mlen=mlen,nonce=nonce,base=base,fault=fault,abort=abort,
                             sk=sk,body=body,rnd=rnd,message=message,emitted=emitted,mu=mu,seed=seed,values=values,code=code))
        add(ctx=0,mlen=0,zero=True);add();add(ctx=255,mlen=137,nonce=65536-l);add(nonce=l)
        add(base=63);add(base=0);add(base=50);add(ctx=256);add(mlen=65470);add(nonce=65537-l)
        for fault in range(1,7):add(fault=fault)
        for abort in (1,2,3,4,5):add(abort=abort);add(zero=True)
    return rows


def sign_mask_artifact(token):
    rows=sign_mask_cases()
    return f'{token} {len(rows)}\n'+''.join(' '.join(str(c[k]) for k in ('i','p','id','ctx','mlen','nonce','base','fault','abort'))+
        f" {c['rnd'][::-1].hex()} {len(c['sk'])} {c['sk'].hex()} {len(c['body'])} {c['body'].hex() or '-'}\n" for c in rows)


def check_sign_mask_c():
    # Reuse the existing unchanged-C component adapter and executable. Its mu
    # is checked first,then seed,then every vector polynomial at its exact nonce.
    total=octets=polys=0
    for p,level in enumerate((2,3,5)):
        fixtures=[];expected=[]
        for c in sign_mask_cases():
            if c['p']!=p or c['code']==2:continue
            tr,key=c['sk'][64:128],c['sk'][32:64]
            mu=hashlib.shake_256(c['message']).digest(64)
            seed=hashlib.shake_256(key+c['rnd']+mu).digest(64)
            for op,body,nonce in [(0,c['body'],0),(1,b'',0),*[(3,b'',c['nonce']+j) for j in range((4,5,7)[p])]]:
                values=[op,c['ctx'],c['mlen'],nonce,len(body),*tr,*key,*c['rnd'],*mu,*seed,*body]
                fixtures.append(' '.join(map(str,values)))
                message=c['message'] if op==0 else key+c['rnd']+mu if op==1 else seed+nonce.to_bytes(2,'little')
                poly=reference.sample(2,p,hashlib.shake_256(message).digest(4096))[0] if op==3 else []
                expected.append((message,hashlib.shake_256(message).digest(64),poly));polys+=int(op==3)
        answer=subprocess.run([str(HERE/f'reference_build/sign_hash_reference_{level}.exe')],input='\n'.join(fixtures)+'\n',capture_output=True,text=True,check=True).stdout.splitlines()
        if len(answer)!=len(expected):raise ValueError('Mask C fixture count')
        for line,(message,digest,poly) in zip(answer,expected,strict=True):
            f=line.split()
            if bytes.fromhex(f[0])!=message or bytes.fromhex(f[1])!=digest or list(map(int,f[2:]))!=list(poly):raise ValueError('Mask Python/C disagreement')
            total+=1;octets+=len(message)
    message=f'PYTHON_C_SIGN_MASK_PASS:{total} component messages,{octets} bytes,{polys} mask polynomials;three published SK inputs,local FIPS-derived expectations\n'
    (HERE/'stage5_sign_mask_c_reference.log').write_text(message);print(message,end='')


def verify_sign_mask(lines):
    _,token=check();rows=sign_mask_cases()
    if not lines or lines[0]!='H '+token:raise ValueError('Mask stale source token')
    by={};footer=None;previous=-1
    for line in lines[1:]:
        f=line.split()
        if not f:raise ValueError('Mask blank event')
        if f[0]=='F':
            if footer is not None:raise ValueError('Duplicate mask totals')
            footer=list(map(int,f[1:]));continue
        if footer is not None or f[0] not in ('K','C','D','W','R','S','X','L','P','E','V','T','A'):raise ValueError('Unknown/trailing mask event')
        i=int(f[1])
        if i<previous or i>=len(rows):raise ValueError('Mask event order')
        previous=i;by.setdefault(i,[]).append(f)
    totals=[len(rows),0,0,0,0,0,0,0,0];allstalls=[0]*5
    sentinel=reference.sample(2,0,hashlib.shake_256(b'').digest(4096))[0]
    needkey=True
    for c in rows:
        i,p=c['i'],c['p'];l=(4,5,7)[p];n=(12,17,23)[p];events=by.get(i,[])
        def ev(k):return [f for f in events if f[0]==k]
        if ev('C')!=[['C',str(i),*[str(c[k]) for k in ('p','id','ctx','mlen','nonce','base')]]]:raise ValueError('Mask accepted command mismatch')
        keymask=sum(1<<r for r in [31,*range(n-1)])
        if i==0 or rows[i-1]['p']!=p:needkey=True
        expectedkey=[['K',str(i),str(p),str(100+p),f'{keymask:016x}',c['sk'][32:64][::-1].hex(),c['sk'][64:128][::-1].hex()]] if needkey else []
        if ev('K')!=expectedkey:raise ValueError('Mask retained key publication/reuse')
        totals[8]+=int(needkey);needkey=bool(c['abort'])
        desc={};absorbed={};raw={};statuses={};scalar={};releases=[];ended=False
        for f in events:
            k=f[0]
            if k=='D':
                phase,j,jid,length,core=map(int,f[2:]);key=(phase,j)
                expected_phase=0 if not desc else 1 if len(desc)==1 else 3
                expected_j=max(0,len(desc)-2)
                if ended or key in desc or phase!=expected_phase or j!=expected_j or jid!=c['id'] or core not in (0,1):raise ValueError('Mask descriptor sequence')
                if desc:
                    prior=list(desc)[-1]
                    if prior not in statuses or len(absorbed[prior])!=len(desc[prior][0]) or (prior[0]!=3 and len(raw[prior])!=64):raise ValueError('Early mask service handoff')
                message=c['emitted'] if phase==0 else c['sk'][32:64]+c['rnd']+c['mu'] if phase==1 else c['seed']+(c['nonce']+j).to_bytes(2,'little')
                if length!=len(message):raise ValueError('Mask descriptor length')
                desc[key]=(message,core);absorbed[key]=bytearray();raw[key]=bytearray()
            elif k=='W':
                phase,j,w,size=map(int,f[2:6]);key=(phase,j)
                if key not in desc or key in statuses:raise ValueError('Mask absorption owner')
                message=desc[key][0];offset=len(absorbed[key]);expected=message[offset:offset+8]
                if w!=offset//8 or size!=len(expected) or int(f[6],16)!=int.from_bytes(expected,'little'):raise ValueError('Mask exact absorption mismatch')
                absorbed[key].extend(expected);totals[4]+=1
            elif k=='R':
                phase,jid,core,size=map(int,f[2:6]);key=(phase,0)
                if key not in desc or key in statuses or phase==3 or len(absorbed[key])!=len(desc[key][0]):raise ValueError('Mask digest owner')
                expected_id=c['id']^(1 if c['fault']==2 and phase==0 else 0)
                expected_size=15 if c['fault']==3 and phase==1 else 16
                digest=hashlib.shake_256(desc[key][0]).digest(64);offset=len(raw[key])
                if jid!=expected_id or core!=desc[key][1] or size!=expected_size or offset>=64 or int(f[6],16)!=int.from_bytes(digest[offset:offset+16],'little'):raise ValueError('Mask exact digest/tag mismatch')
                raw[key].extend(digest[offset:offset+16]);totals[5]+=16
            elif k=='S':
                phase,j,jid,core=map(int,f[2:6]);key=(phase,j)
                expected_id=c['id']^(1 if (c['fault']==4 and phase==1 or c['fault']==5 and phase==3 and j==2) else 0)
                if key not in desc or key in statuses or jid!=expected_id or core!=desc[key][1] or len(absorbed[key])!=len(desc[key][0]):raise ValueError('Mask service retirement mismatch')
                if phase==3:
                    expected_code=7 if c['fault']==6 and j==l-1 else 0
                    if len(f)!=7 or int(f[6])!=expected_code or len(scalar.get(j,[]))!=256:raise ValueError('Mask sampled status/count')
                elif len(f)!=6 or len(raw[key])!=64:raise ValueError('Mask short digest retirement')
                statuses[key]=True
            elif k=='X':
                region,index=int(f[2]),int(f[3]);j=region-c['base'];values=scalar.setdefault(j,[])
                if (3,j) not in desc or j>=l or index!=len(values) or index>=256 or int(f[4],16)!=c['values'][j][index]:raise ValueError('Mask exact scalar write')
                values.append(int(f[4],16));totals[6]+=1
            elif k=='L':
                region=int(f[2]);j=region-c['base']
                if j not in scalar or len(scalar[j])!=256 or region in releases:raise ValueError('Mask invalid/foreign release')
                releases.append(region)
            elif k=='P':
                if c['code'] or c['abort'] or len(statuses)!=l+2 or ev('E')==[]:raise ValueError('Mask premature publication')
                handles=sum((c['base']+j)<<(6*j) for j in range(l));mask=sum(1<<(c['base']+j) for j in range(l))
                if list(map(lambda s:int(s,16),f[2:]))!=[int.from_bytes(c['mu'],'little'),int.from_bytes(c['seed'],'little'),mask,handles]:raise ValueError('Mask publication data/map')
            elif k=='E':
                if ended or c['abort'] or list(map(int,f[2:]))!=[c['id'],c['code']]:raise ValueError('Mask parent result')
                ended=True
            elif k=='V':
                if not ended:raise ValueError('Mask early consumer')
                kind,j,region,w,jid,mode,param,domain=map(int,f[2:10]);data=int(f[10],16)
                if w>=64:raise ValueError('Mask read index')
                if kind==0:
                    if c['code'] or region!=c['base']+j or jid!=c['id'] or (mode,param,domain)!=(2,p,0):raise ValueError('Mask result metadata')
                    poly=c['values'][j]
                elif kind==1:
                    if region!=([31,*range(n-1)])[j] or jid!=100+p or (mode,param,domain)!=(1 if j<(8,11,15)[p] else 3,p,1):raise ValueError('Retained key metadata changed')
                    poly=sign_prepare_math(c['sk'],p)[1][j]
                elif kind==2:
                    if (j,region,jid,mode,param,domain)!=(0,50,60000,2,0,0):raise ValueError('Sentinel metadata')
                    poly=sentinel
                else:raise ValueError('Unknown mask read kind')
                if data!=sum(poly[4*w+b]<<(23*b) for b in range(4)):raise ValueError('Mask/key/sentinel read data')
                totals[7]+=1
        if c['abort']:
            if ev('A')!=[['A',str(i),str(c['abort'])]] or ev('E') or ev('P') or ev('V') or releases:raise ValueError('Mask reset completion credit')
            phase=0 if c['abort']==1 else 1 if c['abort']==2 else 3
            if not desc or list(desc)[-1][0]!=phase:raise ValueError('Mask reset witness')
            if c['abort'] in (3,5) and (len(scalar.get(0,[]))!=256 or not 30<=len(scalar.get(1,[]))<=34):raise ValueError('Mask partial-vector reset witness')
            if c['abort']==4 and len(statuses)!=l+2:raise ValueError('Mask held-done reset witness')
            totals[3]+=1
        else:
            if not ended or ev('A') or len(ev('T'))!=1 or len(ev('P'))!=int(c['code']==0):raise ValueError('Missing mask completion/witness')
            expected_reads=[(0,j,w) for j in range(l) for w in range(64)] if not c['code'] else []
            expected_reads += [(1,j,w) for j in range(n) for w in range(64)]+[(2,0,w) for w in range(64)]
            if [(int(f[2]),int(f[3]),int(f[5])) for f in ev('V')]!=expected_reads:raise ValueError('Missing/duplicate mask/key/sentinel read')
            if releases!=[c['base']+j for j in sorted(scalar)]:raise ValueError('Mask rollback/clear completeness')
            if c['code'] in (2,3) and desc:raise ValueError('Preflight launched hash')
            if c['code']==4 and list(desc)!=[(0,0)]:raise ValueError('Malformed payload forwarded seed')
            if c['code']==5:
                count_expected=1 if c['fault']==2 else 2 if c['fault'] in (3,4) else 5 if c['fault']==5 else l+2
                if len(desc)!=count_expected:raise ValueError('Invalid service result advanced dependent client')
            if c['code']==0 and len(statuses)!=l+2:raise ValueError('Missing mask vector result')
            for j,value in enumerate(map(int,ev('T')[0][2:])):allstalls[j]+=value
            totals[1]+=1;totals[2]+=int(c['code']!=0)
    if footer!=totals or not all(allstalls):raise ValueError(f'Mask totals/stall witness {footer} != {totals}')
    success=totals[1]-totals[2]
    return f'STAGE5N4E_SIGN_MASK_COMPARE_PASS:{len(rows)} commands,{success} successes,{totals[2]} expected errors,{totals[3]} resets/fault aborts,{totals[4]} exact absorption words,{totals[5]} digest bytes,{totals[6]} scalar writes,{totals[7]} packed reads,{totals[8]} real key preparations;stall witnesses {allstalls}\n'


def compare(stage=2,unit='process'):
    if stage==5 and unit=='nist_verify':
        message=verify_full_verify((HERE/'stage5_nist_verify_outputs.txt').read_text().splitlines(),nist=True)
        (HERE/'stage5_nist_verify_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='full_verify':
        message=verify_full_verify((HERE/'stage5_full_verify_outputs.txt').read_text().splitlines())
        (HERE/'stage5_full_verify_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='verify_equation':
        message=verify_verify_equation((HERE/'stage5_verify_equation_outputs.txt').read_text().splitlines())
        (HERE/'stage5_verify_equation_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='verify_math':
        message=verify_verify_math((HERE/'stage5_verify_math_outputs.txt').read_text().splitlines())
        (HERE/'stage5_verify_math_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='verify_prepare':
        message=verify_verify_prepare((HERE/'stage5_verify_prepare_outputs.txt').read_text().splitlines())
        (HERE/'stage5_verify_prepare_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='verify_decode':
        message=verify_verify_decode((HERE/'stage5_verify_decode_outputs.txt').read_text().splitlines())
        (HERE/'stage5_verify_decode_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='nist_sign':
        message=verify_full_sign((HERE/'stage5_nist_sign_outputs.txt').read_text().splitlines(),nist=True)
        (HERE/'stage5_nist_sign_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='full_sign':
        message=verify_full_sign((HERE/'stage5_full_sign_outputs.txt').read_text().splitlines())
        (HERE/'stage5_full_sign_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_encode':
        message=verify_sign_encode((HERE/'stage5_sign_encode_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_encode_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_retry':
        message=verify_sign_retry((HERE/'stage5_sign_retry_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_retry_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_accept':
        message=verify_sign_accept((HERE/'stage5_sign_accept_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_accept_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_products':
        message=verify_sign_products((HERE/'stage5_sign_products_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_products_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_transform':
        message=verify_sign_transform((HERE/'stage5_sign_transform_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_transform_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_challenge':
        message=verify_sign_challenge((HERE/'stage5_sign_challenge_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_challenge_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_matrix':
        message=verify_sign_matrix((HERE/'stage5_sign_matrix_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_matrix_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_mask':
        message=verify_sign_mask((HERE/'stage5_sign_mask_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_mask_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_prepare':
        message=verify_sign_prepare((HERE/'stage5_sign_prepare_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_prepare_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_load_service':
        message=verify_sign_load_service((HERE/'stage5_sign_load_service_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_load_service_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_load':
        message=verify_sign_load((HERE/'stage5_sign_load_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_load_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_hash':
        message=verify_sign_hash((HERE/'stage5_sign_hash_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_hash_compare.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_decode':
        message=verify_sign_decode((HERE/'stage5_sign_decode_outputs.txt').read_text().splitlines())
        (HERE/'stage5_sign_decode_compare.log').write_text(message);print(message,end='');return
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
    if stage==5 and unit in ('full_verify','nist_verify'):
        nist=unit=='nist_verify';stem='stage5_'+unit
        _,token=check();original=(HERE/(stem+'_outputs.txt')).read_text().splitlines();verify_full_verify(original,token,nist=nist);trials=[]
        tags=('C','I','KEY','SIG','LD','LC','CH','Y','K','T','Q','B','O','G','J','S','H','N','ND','P','PD','PC','V','E','PKD','R','A','W','M','F','REFUSE','D','Z','ENDCASE')
        for tag in (t for t in tags if not nist or t not in ('KEY','SIG','Z')):
            j=next(j for j,s in enumerate(original) if j>0 and s.startswith(tag+' '));f=original[j].split()
            trials.extend([(tag+'_missing',j,None),(tag+'_duplicate',j,'duplicate')])
            for col in sorted({2,len(f)-1}):
                changed=f.copy();changed[col]='0' if int(f[col],16)!=0 else '1';trials.append((f'{tag}_field{col}',j,' '.join(changed)))
        for tag,columns in (('D',(3,4,5,6,7,8)),('I',(3,4,5)),('R',(3,4,5,6,7,8,9)),('N',(3,4,5,6,7,8)),('W',(3,4,5)),('A',(3,4,5,6,7,8))):
            j=next(j for j,s in enumerate(original) if s.startswith(tag+' '));f=original[j].split()
            for col in columns:
                if tag=='N' and col in (5,8):
                    j=next(j for j,s in enumerate(original) if s.startswith('N ') and s.split()[3]=='2');f=original[j].split()
                changed=f.copy();changed[col]='0' if int(f[col],16)!=0 else '1';trials.append((f'{tag}_critical{col}',j,' '.join(changed)))
        for phase in (2,3):
            j=next(j for j,s in enumerate(original) if s.startswith('CH ') and s.split()[2]==str(phase));f=original[j].split();f[-1]='0' if int(f[-1],16) else '1';trials.append((f'child_digest{phase}',j,' '.join(f)))
        j=next(j for j,s in enumerate(original) if s.startswith('D ') and s.split()[6]=='1');f=original[j].split();f[6]='0';trials.append(('false_negative_verdict',j,' '.join(f)))
        trials.extend([('stale',0,'H '+'0'*64),('footer',len(original)-1,None),('trailing',len(original),original[-2])])
        for label,j,replacement in trials:
            changed=original[:j]+([original[j],original[j]] if replacement=='duplicate' else [] if replacement is None else [replacement])+original[j+(j<len(original)):]
            try:verify_full_verify(changed,token,nist=nist)
            except (ValueError,IndexError,KeyError):continue
            raise ValueError('Full Verify checker accepted corruption:'+label)
        marker='STAGE6_NIST_VERIFY' if nist else 'STAGE5V4_FULL_VERIFY'
        message=f'{marker}_CHECKER_SELFTEST_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/(stem+'_checker_selftest.log')).write_text(message);print(message,end='');return
    if stage==5 and unit=='verify_equation':
        _,token=check();original=(HERE/'stage5_verify_equation_outputs.txt').read_text().splitlines();verify_verify_equation(original,token);trials=[]
        for tag in ('U','INIT','K','C','T','J','S','H','N','O','P','B','PC','V','E','PD','L','Q','I','D0','G','FMT','R','A','W','M','F','D','X','PREP_CLEAR','EXTERNAL_RELEASE','ENDCASE','Z'):
            j=next(j for j,s in enumerate(original) if j>0 and s.startswith(tag+' '));f=original[j].split()
            trials.extend([(tag+'_missing',j,None),(tag+'_duplicate',j,'duplicate')])
            for col in sorted({2,len(f)-1}):
                changed=f.copy();changed[col]='0' if int(f[col],16)!=0 else '1';trials.append((f'{tag}_field{col}',j,' '.join(changed)))
        for tag,columns in (('D',(3,4,5,6,7,8)),('R',(3,4,5,6,7,8,9,10)),('W',(3,4,5,6)),('A',(3,4,6,7)),('N',(3,4,5,6,7,8,9,10)),('P',(3,4,5,6,7,8,9,10)),('U',(3,4,5))):
            j=next(j for j,s in enumerate(original) if j>0 and s.startswith(tag+' '));f=original[j].split()
            for col in columns:
                changed=f.copy();changed[col]='0' if int(f[col],16)!=0 else '1';trials.append((f'{tag}_critical{col}',j,' '.join(changed)))
        # alloc_ntt_domain is ignored for sampler allocations. Mutate a
        # compute allocation where that port actually defines stored domain.
        j=next(j for j,s in enumerate(original) if s.startswith('A ') and s.split()[4]=='1');f=original[j].split();f[5]=str(int(f[5])^1)
        trials.append(('compute_domain',j,' '.join(f)))
        trials.extend([('stale',0,'V '+'0'*64),('footer',len(original)-1,None),('trailing',len(original),original[-2])])
        for label,j,replacement in trials:
            changed=original[:j]+([original[j],original[j]] if replacement=='duplicate' else [] if replacement is None else [replacement])+original[j+(j<len(original)):]
            try:verify_verify_equation(changed,token)
            except (ValueError,IndexError,KeyError):continue
            raise ValueError('Verify equation checker accepted corruption:'+label)
        message=f'STAGE5V3_VERIFY_EQUATION_CHECKER_SELFTEST_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_verify_equation_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='verify_math':
        _,token=check();original=(HERE/'stage5_verify_math_outputs.txt').read_text().splitlines();verify_verify_math(original,token);trials=[]
        for tag in ('INIT','C','T','I','Q','B','O','G','X','J','S','H','N','V','A','W','M','F','R','HOLD','D','Y','K','TAKE','CLEAR','PREP_CLEAR','EXTERNAL_RELEASE','ENDCASE','Z'):
            j=next(j for j,s in enumerate(original) if j>0 and s.startswith(tag+' '));f=original[j].split()
            trials.extend([(tag+'_missing',j,None),(tag+'_duplicate',j,'duplicate')])
            for col in sorted({2,len(f)-1}):
                changed=f.copy();changed[col]='0' if int(f[col],16)!=0 else '1';trials.append((f'{tag}_field{col}',j,' '.join(changed)))
        trials.extend([('stale',0,'V '+'0'*64),('footer',len(original)-1,None),('trailing',len(original),original[-2])])
        for label,j,replacement in trials:
            changed=original[:j]+([original[j],original[j]] if replacement=='duplicate' else [] if replacement is None else [replacement])+original[j+(j<len(original)):]
            try:verify_verify_math(changed,token)
            except (ValueError,IndexError,KeyError):continue
            raise ValueError('Verify math checker accepted corruption:'+label)
        message=f'STAGE5V2B_VERIFY_MATH_CHECKER_SELFTEST_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_verify_math_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='verify_prepare':
        _,token=check();original=(HERE/'stage5_verify_prepare_outputs.txt').read_text().splitlines();verify_verify_prepare(original,token);trials=[]
        for tag in ('C','I','Q','B','O','G','L','A','W','M','F','R','HOLD','D','Y','K','TAKE','CLEAR','EXTERNAL_RELEASE','ENDCASE','Z'):
            j=next(j for j,s in enumerate(original) if s.startswith(tag+' '));f=original[j].split()
            trials.extend([(tag+'_missing',j,None),(tag+'_duplicate',j,'duplicate')])
            for col in (2,len(f)-1):
                changed=f.copy();changed[col]='0' if int(f[col],16)!=0 else '1';trials.append((f'{tag}_field{col}',j,' '.join(changed)))
        trials.extend([('stale',0,'V '+'0'*64),('footer',len(original)-1,None),('trailing',len(original),original[-2])])
        for label,j,replacement in trials:
            changed=original[:j]+([original[j],original[j]] if replacement=='duplicate' else [] if replacement is None else [replacement])+original[j+(j<len(original)):]
            try:verify_verify_prepare(changed,token)
            except (ValueError,IndexError,KeyError):continue
            raise ValueError('Verify preparation checker accepted corruption:'+label)
        message=f'STAGE5V2A_VERIFY_PREPARE_CHECKER_SELFTEST_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_verify_prepare_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='verify_decode':
        original=(HERE/'stage5_verify_decode_outputs.txt').read_text().splitlines();verify_verify_decode(original);trials=[]
        for tag,columns in [('C',(2,3,4,5)),('I',(2,3,4,5)),('H',(2,3,4)),('P',(2,3,4,5,6,7,8)),('D',(2,3)),('Z',(2,3))]:
            j=next(j for j,s in enumerate(original) if s.startswith(tag+' '));fields=original[j].split()
            for column in columns:
                base=16 if tag=='I' and column==5 or tag=='H' and column==4 or tag=='P' and column==6 else 10
                f=fields.copy();f[column]=format(int(f[column],base)^1,'x') if base==16 else str(int(f[column])+1)
                trials.append((f'{tag}_field{column}',j,' '.join(f)))
            trials.append((tag+'_missing',j,None));trials.append((tag+'_duplicate',j,'duplicate'))
        trials.extend([('stale',0,'V '+'0'*64),('footer',len(original)-1,None),('trailing',len(original),original[-2])])
        for label,j,replacement in trials:
            changed=original[:j]+([original[j],original[j]] if replacement=='duplicate' else [] if replacement is None else [replacement])+original[j+(j<len(original)):]
            try:verify_verify_decode(changed)
            except (ValueError,IndexError,KeyError):continue
            raise ValueError('Verify decoder checker accepted corruption:'+label)
        message=f'STAGE5V1_VERIFY_DECODE_CHECKER_SELFTEST_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_verify_decode_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit in ('full_sign','nist_sign'):
        nist=unit=='nist_sign';stem='stage5_'+unit
        original=(HERE/(stem+'_outputs.txt')).read_text().splitlines();verify_full_sign(original,nist=nist);trials=[]
        for tag in ('C','I','S','K','N','A','M','F','Z','D','B','GATE','REFUSE','END'):
            indices=[j for j,s in enumerate(original) if s.startswith(tag+' ')]
            for j in [indices[0],indices[-1]] if len(indices)>1 else indices:
                fields=original[j].split()
                for column in range(1,len(fields)):
                    if tag=='A' and column==5:continue # mode is range checked;per-engine data typing is covered by earlier gates
                    changed=original.copy();f=fields.copy()
                    base=16 if (tag=='C' and column>=7 or tag=='I' and column==6 or tag=='S' and column==6 or tag=='K' and column==7 or
                        tag=='A' and column==7 or tag=='Z' and column==6 or tag=='D' and column==9 or tag=='B' and column==2) else 10
                    f[column]='0' if tag=='GATE' and column==2 else format(int(f[column],base)^1,'x') if base==16 else str(int(f[column])+1)
                    changed[j]=' '.join(f);trials.append((f'{tag}_{j}_{column}',changed))
                trials.append((f'{tag}_missing_{j}',original[:j]+original[j+1:]))
                trials.append((f'{tag}_duplicate_{j}',original[:j]+[original[j]]+original[j:]))
        trials.extend([('stale',['H '+'0'*64]+original[1:]),('truncated',original[:-1]),('trailing',original+[original[-2]])])
        for label,changed in trials:
            try:verify_full_sign(changed,nist=nist)
            except (ValueError,IndexError,KeyError):continue
            raise ValueError('Full Sign checker accepted corruption:'+label)
        marker='STAGE5N4H7_NIST_SIGN' if nist else 'STAGE5N4H6_FULL_SIGN'
        message=f'{marker}_CHECKER_SELFTEST_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/(stem+'_checker_selftest.log')).write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_encode':
        original=(HERE/'stage5_sign_encode_outputs.txt').read_text().splitlines();verify_sign_encode(original);trials=[]
        for tag in ('K','R','C','T','U','V','O','F','D','Z','B','HOLD','END'):
            indices=[j for j,s in enumerate(original) if s.startswith(tag+' ')]
            for j in [indices[0],indices[-1]] if len(indices)>1 else indices:
                fields=original[j].split()
                for column in range(1,len(fields)):
                    altered=original.copy();f=fields.copy()
                    hexfield=(tag=='K' and column>=3 or tag=='R' and column in (5,6,7,9) or tag=='T' and column==2 or tag=='V' and column==9 or tag=='O' and column==6 or tag=='B' and column==2 or tag=='HOLD' and column==6)
                    f[column]=format(int(f[column],16)^1,'x') if hexfield else str(int(f[column])+1)
                    altered[j]=' '.join(f);trials.append((f'{tag}_{j}_{column}',altered))
                trials.append((f'{tag}_missing_{j}',original[:j]+original[j+1:]))
                trials.append((f'{tag}_duplicate_{j}',original[:j]+[original[j]]+original[j:]))
        trials.extend([('stale',['G '+'0'*64]+original[1:]),('truncated',original[:-1]),('extra',original+[original[-2]])])
        for label,altered in trials:
            try:verify_sign_encode(altered)
            except (ValueError,IndexError):continue
            raise ValueError('Signature checker accepted corruption:'+label)
        message=f'STAGE5N4H5_SIGN_ENCODE_CHECKER_SELFTEST_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_encode_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_retry':
        original=(HERE/'stage5_sign_retry_outputs.txt').read_text().splitlines();verify_sign_retry(original);trials=[]
        for tag,columns,hexcols in [
            ('S',(2,3,4),()),('D',tuple(range(2,13)),(9,)),('M',(2,3,4,5,6,7),(4,5,6,7)),
            ('L',(2,3,4,5,6,7),(5,6,7)),('O',tuple(range(2,10)),()),('I',(2,3),(3,)),
            ('H',(2,3,4,5),(5,)),('Q',(2,3),()),('J',tuple(range(2,11)),()),('W',(2,3),(3,)),
            ('T',(2,3,4),()),('A',tuple(range(2,9)),(8,)),('COM',(2,3,4,5),()),('F',(2,3),(3,)),
            ('X',tuple(range(2,8)),(7,)),('R',(2,3,4,5,6),(2,3,4,6)),('E',tuple(range(2,9)),()),
            ('V',tuple(range(2,11)),(10,)),('Z',tuple(range(2,7)),())]:
            at=next(j for j,s in enumerate(original) if s.startswith(tag+' '))
            for col in columns:
                altered=original.copy();f=altered[at].split();base=16 if col in hexcols else 10
                f[col]=format(int(f[col],base)^1,'x') if base==16 else str(int(f[col])+1);altered[at]=' '.join(f)
                trials.append((f'{tag}_field{col}',altered))
        for tag in ('C','S','D','M','L','O','I','H','Q','J','W','T','A','COM','F','X','R','E','V','Z','BARRIER','TAKE','B','BAD'):
            at=next(j for j,s in enumerate(original) if s.startswith(tag+' '))
            trials.extend([(f'missing_{tag}',original[:at]+original[at+1:]),(f'duplicate_{tag}',original[:at]+[original[at]]+original[at:])])
        trials.extend([('stale',['G '+'0'*64]+original[1:]),('missing_footer',original[:-1]),('trailing',original+[original[1]])])
        for label,altered in trials:
            try:verify_sign_retry(altered)
            except ValueError:continue
            raise ValueError('Retry checker accepted corruption:'+label)
        message=f'STAGE5N4H4_SIGN_RETRY_CHECKER_SELFTEST_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_retry_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_accept':
        original=(HERE/'stage5_sign_accept_outputs.txt').read_text().splitlines();verify_sign_accept(original);trials=[]
        for tag,columns,hexcolumns in [
            ('Y',(2,3,4,5,6,7,8,9,10,11,12,13),(3,4,5,6,7,11,12,13)),('T',(2,3),(2,)),
            ('O',(2,3,4,5,6,7,8,9,10,11),()),('Q',(2,3,4,5,6,7,8,9),()),
            ('P',(2,3,4,5,6,7,8,9,10),()),('R',(2,3,4,5),()),
            ('X',(2,3,4,5,6),(6,)),('D',(2,3,4,5,6,7,8,9,10,11),(3,4,5,9,10,11)),
            ('E',(2,3,4,5,6,7),()),('V',(2,3,4,5,6,7,8,9,10),(10,)),
            ('A',(2,3,4,5),(2,4,5)),('F',(2,3),()),('Z',(2,3,4,5),())]:
            at=next(j for j,s in enumerate(original) if s.startswith(tag+' '))
            for col in columns:
                altered=original.copy();f=altered[at].split();base=16 if col in hexcolumns else 10
                f[col]=format(int(f[col],base)^1,'x') if base==16 else str(int(f[col])+1);altered[at]=' '.join(f)
                trials.append((f'{tag}_field{col}',altered))
        for tag in ('C','T','O','Q','P','R','X','D','E','V','A','F','Z','BARRIER','B'):
            at=next(j for j,s in enumerate(original) if s.startswith(tag+' '))
            trials.extend([(f'missing_{tag}',original[:at]+original[at+1:]),(f'duplicate_{tag}',original[:at]+[original[at]]+original[at:])])
        trials.extend([('stale',['G '+'0'*64]+original[1:]),('missing_footer',original[:-1]),('trailing',original+[original[1]])])
        for label,altered in trials:
            try:verify_sign_accept(altered)
            except ValueError:continue
            raise ValueError('Acceptance checker accepted corruption:'+label)
        message=f'STAGE5N4H3_SIGN_ACCEPT_CHECKER_SELFTEST_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_accept_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_products':
        original=(HERE/'stage5_sign_products_outputs.txt').read_text().splitlines();verify_sign_products(original);trials=[]
        columns={'K':(3,),'M':(6,),'U':(2,4),'H':(2,4),'S':(2,4,8),'N':(2,5),'C':(3,),
            'T':(2,3,4,5),'O':(3,6,9),'P':(4,5,9),'Q':(4,5),'R':(4,5),'X':(6,7),'F':(2,3),
            'D':(2,6,9,10,11,12),'E':(3,),'V':(6,10),'BARRIER':(2,),'A':(2,3,4,5),'L':(2,),'B':(2,),'Z':(2,3),'END':(6,8)}
        hexcols={'K':{3},'M':{6},'U':{4},'H':{4},'S':{4,8},'N':{2,5},'T':{2,3,4},'X':{7},'D':{2,6,10,11,12},'V':{10},'BARRIER':{2},'A':{2,4,5},'B':{2}}
        for kind,cols in columns.items():
            pos=next(j for j,line in enumerate(original) if line.startswith(kind+' '))
            for col in cols:
                f=original[pos].split();ishex=col in hexcols.get(kind,set());value=int(f[col],16 if ishex else 10)^1
                f[col]=format(value,'x') if ishex else str(value);trials.append((pos,' '.join(f),'replace'))
            trials.append((pos,None,'delete'))
            if kind in ('C','T','O','P','Q','R','D','E','A','B','END'):trials.append((pos,None,'duplicate'))
        rejected=0
        for pos,value,kind in trials:
            altered=original.copy()
            if kind=='replace':altered[pos]=value
            elif kind=='delete':del altered[pos]
            else:altered.insert(pos,altered[pos])
            try:verify_sign_products(altered)
            except (ValueError,IndexError,KeyError):rejected+=1
        if rejected!=len(trials):raise ValueError(f'Products checker accepted {len(trials)-rejected} corrupt captures')
        message=f'SIGN_PRODUCTS_CHECKER_SELFTEST_PASS:{rejected}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_products_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_transform':
        original=(HERE/'stage5_sign_transform_outputs.txt').read_text().splitlines();verify_sign_transform(original);trials=[]
        columns={'K':(3,),'M':(6,),'U':(2,4),'H':(2,3,4),'N':(2,3,4),'C':(3,),'T':(2,),'O':(4,5,6),
            'Q':(2,3),'F':(2,3),'X':(4,5),'D':(2,3,6),'E':(3,),'V':(6,10),'BARRIER':(2,),'A':(2,),'L':(2,),'B':(2,),'Z':(2,3),'END':(5,6)}
        hexcols={'K':{3},'M':{6},'U':{4},'H':{4},'N':{2,3,4},'T':{2},'X':{5},'D':{2,6},'V':{10},'BARRIER':{2},'A':{2},'B':{2}}
        for kind,cols in columns.items():
            pos=next(j for j,line in enumerate(original) if line.startswith(kind+' '))
            for col in cols:
                f=original[pos].split();ishex=col in hexcols.get(kind,set());value=int(f[col],16 if ishex else 10)^1
                f[col]=format(value,'x') if ishex else str(value);trials.append((pos,' '.join(f),'replace'))
            trials.append((pos,None,'delete'))
            if kind in ('C','T','O','Q','D','E','A','B','END'):trials.append((pos,None,'duplicate'))
        rejected=0
        for pos,value,kind in trials:
            altered=original.copy()
            if kind=='replace':altered[pos]=value
            elif kind=='delete':del altered[pos]
            else:altered.insert(pos,altered[pos])
            try:verify_sign_transform(altered)
            except (ValueError,IndexError,KeyError):rejected+=1
        if rejected!=len(trials):raise ValueError(f'Transform checker accepted {len(trials)-rejected} corrupt captures')
        message=f'SIGN_TRANSFORM_CHECKER_SELFTEST_PASS:{rejected}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_transform_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_challenge':
        original=(HERE/'stage5_sign_challenge_outputs.txt').read_text().splitlines();verify_sign_challenge(original);trials=[]
        columns={'K':(3,),'M':(6,),'U':(2,4),'N':(2,),'C':(3,),'B':(3,5),'L':(5,9),'I':(3,5),'O':(3,7),'T':(3,4),'P':(2,5),
                 'H':(2,4),'W':(2,4),'R':(2,5),'Q':(2,),'J':(4,5),'A':(2,3),'S':(2,4),'X':(4,5),'F':(2,),'D':(2,4),'E':(3,),'V':(6,10),'BARRIER':(2,),'Z':(2,),'ST':(),'END':(5,9)}
        for kind,cols in columns.items():
            pos=next(j for j,line in enumerate(original) if line.startswith(kind+' '))
            for col in cols:
                f=original[pos].split();hexcol=(kind=='K' and col==3 or kind=='M' and col==6 or kind=='U' and col==4 or kind=='N' or
                    kind=='L' and col==9 or kind=='I' and col==5 or kind=='O' and col==7 or kind=='P' and col==5 or kind=='W' and col==4 or
                    kind=='R' and col==5 or kind=='A' and col==3 or kind=='X' and col==5 or kind=='D' and col==4 or kind=='V' and col==10 or kind=='BARRIER')
                value=int(f[col],16 if hexcol else 10)^1;f[col]=format(value,'x') if hexcol else str(value);trials.append((pos,' '.join(f),'replace'))
            trials.append((pos,None,'delete'))
            if kind in ('C','B','O','S','D','E','END'):trials.append((pos,None,'duplicate'))
        rejected=0
        for pos,value,kind in trials:
            altered=original.copy()
            if kind=='replace':altered[pos]=value
            elif kind=='delete':del altered[pos]
            else:altered.insert(pos,altered[pos])
            try:verify_sign_challenge(altered)
            except (ValueError,IndexError,KeyError):rejected+=1
        if rejected!=len(trials):raise ValueError(f'Challenge checker accepted {len(trials)-rejected} corrupt captures')
        message=f'SIGN_CHALLENGE_CHECKER_SELFTEST_PASS:{rejected}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_challenge_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_matrix':
        original=(HERE/'stage5_sign_matrix_outputs.txt').read_text().splitlines();verify_sign_matrix(original);trials=[]
        # Bounded fault set:metadata,values,retirement,provenance and missing
        # records for every event class;duplicate key ledger/credit records.
        columns={'G':(2,3,5),'N':(4,5),'O':(3,5),'J':(5,6),'W':(4,),
                 'S':(4,6),'R':(4,),'Q':(3,6),'D':(3,4),'B':(3,5),
                 'X':(6,7),'F':(3,4),'L':(3,),'P':(2,),'E':(3,),'V':(6,8,9,10),
                 'K':(4,),'M':(6,),'I':(2,),'C':(3,),'A':(2,),'T':(),'Z':(5,6)}
        for kind,cols in columns.items():
            pos=next(j for j,line in enumerate(original) if line.startswith(kind+' '))
            for col in cols:
                f=original[pos].split();hexcol=(kind=='G' and col<=6 or kind in ('P','I') or kind=='W' and col==4 or
                    kind=='X' and col==7 or kind=='V' and col==10 or kind=='K' and col>=3 or kind=='M' and col>=3)
                value=int(f[col],16 if hexcol else 10)^1;f[col]=format(value,'x') if hexcol else str(value)
                trials.append((pos,' '.join(f),'replace'))
            trials.append((pos,None,'delete'))
            if kind in ('C','G','X','F','E','Z'):trials.append((pos,None,'duplicate'))
        rejected=0
        for pos,value,kind in trials:
            altered=original.copy()
            if kind=='replace':altered[pos]=value
            elif kind=='delete':del altered[pos]
            else:altered.insert(pos,altered[pos])
            try:verify_sign_matrix(altered)
            except (ValueError,IndexError,KeyError):rejected+=1
        if rejected!=len(trials):raise ValueError(f'Matrix checker accepted {len(trials)-rejected} corrupt captures')
        message=f'SIGN_MATRIX_CHECKER_SELFTEST_PASS:{rejected}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_matrix_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_mask':
        original=(HERE/'stage5_sign_mask_outputs.txt').read_text().splitlines();verify_sign_mask(original);trials=[]
        for kind,columns in {'K':(3,4,5,6),'C':(3,4,5,6,7),'D':(2,3,4,5,6),'W':(2,3,4,5,6),
                             'R':(2,3,4,5,6),'S':(2,3,4,5),'X':(2,3,4),'P':(2,3,4,5),
                             'E':(2,3),'V':(2,3,4,5,6,7,8,9,10),'A':(2,),'T':(),'L':(2,),'F':(1,2,3,4,5,6,7,8,9)}.items():
            pos=next(j for j,line in enumerate(original) if line.startswith(kind+' '))
            for col in columns:
                altered=original.copy();f=altered[pos].split();hexcol=kind=='K' and col>=4 or kind=='W' and col==6 or kind=='R' and col==6 or kind=='X' and col==4 or kind=='P' or kind=='V' and col==10
                value=int(f[col],16 if hexcol else 10)^1;f[col]=format(value,'x') if hexcol else str(value);altered[pos]=' '.join(f);trials.append(altered)
            altered=original.copy();del altered[pos];trials.append(altered)
            altered=original.copy();altered.insert(pos,altered[pos]);trials.append(altered)
        rejected=0
        for lines in trials:
            try:verify_sign_mask(lines)
            except (ValueError,IndexError,KeyError):rejected+=1
        if rejected!=len(trials):raise ValueError(f'Mask checker accepted {len(trials)-rejected} corrupt captures')
        message=f'SIGN_MASK_CHECKER_SELFTEST_PASS:{rejected}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_mask_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_prepare':
        original=(HERE/'stage5_sign_prepare_outputs.txt').read_text().splitlines();verify_sign_prepare(original);trials=[]
        for tag,col,radix in [('C',3,10),('W',5,16),('L',3,10),('B',5,10),('B',7,16),('N',3,10),('N',5,10),('N',6,10),('O',3,10),('O',6,10),('R',3,10),('G',6,10),('X',5,16),('P',4,16),('Q',3,10),('U',3,10),('H',4,16),('H',5,16),('H',6,16),('H',7,16),('H',8,16),('D',2,10),('D',3,10),('V',8,10),('V',10,16),('I',4,16),('A',2,10)]:
            idx=next(i for i,s in enumerate(original) if s.startswith(tag+' '));f=original[idx].split();f[col]=format(int(f[col],radix)^1,'x') if radix==16 else str(int(f[col])^1);trials.append((tag+str(col),idx,' '.join(f)))
        for tag in ('C','W','L','B','N','O','R','G','X','P','Q','U','Z','H','D','V','I','E','A','T'):
            idx=next(i for i,s in enumerate(original) if s.startswith(tag+' '));trials.append(('missing_'+tag,idx,None))
        for col in (2,3,5,6,7,8,9,10):
            idx=next(i for i,s in enumerate(original) if s.startswith('T '));f=original[idx].split();f[col]='0';trials.append(('witness'+str(col),idx,' '.join(f)))
        for label,idx,replacement in trials:
            altered=original.copy()
            if replacement is None:del altered[idx]
            else:altered[idx]=replacement
            try:verify_sign_prepare(altered)
            except (ValueError,IndexError,KeyError,TypeError):continue
            raise ValueError('Prepare checker accepted corruption:'+label)
        message=f'STAGE5N4D_SIGN_PREPARE_CHECKER_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_prepare_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_load_service':
        original=(HERE/'stage5_sign_load_service_outputs.txt').read_text().splitlines();verify_sign_load_service(original);trials=[]
        for tag,columns in [('C',range(2,6)),('W',range(2,6)),('L',range(2,6)),('X',range(2,6)),('P',range(2,5)),('K',range(2,4)),('U',range(2,4)),('Z',[2]),('D',range(2,8)),('V',range(2,10)),('G',[2]),('J',range(2,6)),('E',range(2,4)),('I',range(2,5)),('N',range(2,10)),('B',range(2,12)),('A',[2]),('Y',range(2,5)),('O',range(2,6))]:
            for col in columns:
                idx=next(i for i,s in enumerate(original) if s.startswith(tag+' '));f=original[idx].split()
                radix=16 if (tag=='W' and col==5) or (tag in ('X','P','I') and col==4) or (tag=='D' and col>=4) or (tag in ('V','N') and col==9) or (tag=='J' and col==5) else 10
                # The exclusive-owner counter is a positive witness,not an
                # independently specified cycle total:remove it for this fault.
                f[col]='0' if tag=='B' and col==11 else format(int(f[col],radix)^1,'x') if radix==16 else str(int(f[col])^1)
                trials.append((tag+str(col),idx,' '.join(f)))
        for tag in ('C','W','L','X','P','K','U','Z','D','A','T','V','S','B','G','J','E','I','N','Y','O'):
            idx=next(i for i,s in enumerate(original) if s.startswith(tag+' '));trials.append(('missing_'+tag,idx,None))
        for label,idx,replacement in trials:
            lines=original.copy()
            if replacement is None:del lines[idx]
            else:lines[idx]=replacement
            try:verify_sign_load_service(lines)
            except (ValueError,IndexError,KeyError,TypeError):continue
            raise ValueError('Shared key load checker accepted corruption:'+label)
        message=f'STAGE5N4C2_SIGN_LOAD_SERVICE_CHECKER_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_load_service_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_load':
        original=(HERE/'stage5_sign_load_outputs.txt').read_text().splitlines();verify_sign_load(original);trials=[]
        for tag,columns in [('C',range(2,6)),('W',range(2,6)),('L',range(2,6)),('X',range(2,6)),('P',range(2,5)),('K',range(2,4)),('U',range(2,4)),('Z',[2]),('D',range(2,8)),('V',range(2,10)),('S',[2]),('A',[2])]:
            for col in columns:
                idx=next(i for i,s in enumerate(original) if s.startswith(tag+' '));f=original[idx].split()
                radix=16 if (tag=='W' and col==5) or (tag in ('X','P') and col==4) or (tag=='D' and col>=4) or (tag=='V' and col==9) else 10
                f[col]=format(int(f[col],radix)^1,'x') if radix==16 else str(int(f[col])^1)
                trials.append((tag+str(col),idx,' '.join(f)))
        for tag in ('C','W','L','X','P','K','U','Z','D','A','T','V','S'):
            idx=next(i for i,s in enumerate(original) if s.startswith(tag+' '));trials.append(('missing_'+tag,idx,None))
        for col in range(2,6):
            idx=next(i for i,s in enumerate(original) if s.startswith('T '));f=original[idx].split();f[col]='0';trials.append(('witness'+str(col),idx,' '.join(f)))
        # A late eta failure MUST release already committed polynomials.
        idx=next(i for i,s in enumerate(original) if s.startswith('Z '));event=original[idx];lines=original[:idx]+original[idx+1:]
        after=next(i for i,s in enumerate(lines) if s.startswith('D '+event.split()[1]+' '));lines.insert(after+1,event)
        special=[('rollback_after_done',lines),('footer',original[:-1]),('duplicate',original+[original[-1]]),('stale',['H '+'0'*64]+original[1:])]
        def mutations():
            for label,idx,replacement in trials:
                altered=original.copy()
                if replacement is None:del altered[idx]
                else:altered[idx]=replacement
                yield label,altered
            yield from special
        for label,lines in mutations():
            try:verify_sign_load(lines)
            except (ValueError,IndexError,KeyError,TypeError):continue
            raise ValueError('Signing key load checker accepted corruption:'+label)
        message=f'STAGE5N4C1_SIGN_LOAD_CHECKER_PASS:{len(trials)+len(special)}/{len(trials)+len(special)} corruptions rejected\n'
        (HERE/'stage5_sign_load_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_hash':
        original=(HERE/'stage5_sign_hash_outputs.txt').read_text().splitlines();verify_sign_hash(original);trials=[]
        for tag,columns in [('D',range(2,8)),('P',range(2,6)),('W',range(2,6)),('R',range(2,7)),('S',range(2,4)),('E',range(2,4)),('V',range(2,7)),('H',range(2,5)),('G',[2]),('Q',range(2,4)),('L',range(2,4))]:
            for col in columns:
                idx=next(i for i,s in enumerate(original[1:],1) if s.startswith(tag+' '));f=original[idx].split();base=16 if (tag in ('P','W') and col==5) or (tag=='R' and col==6) or (tag=='V' and col==3) or (tag=='H' and col==4) or (tag=='L' and col==3) else 10
                f[col]=format(int(f[col],base)^1,'x') if base==16 else str(int(f[col])^1);lines=original.copy();lines[idx]=' '.join(f);trials.append((tag+str(col),lines))
        for tag in ('C','D','P','W','R','S','E','V','H','G','Q','L','A','T'):
            idx=next(i for i,s in enumerate(original[1:],1) if s.startswith(tag+' '));trials.append(('missing_'+tag,original[:idx]+original[idx+1:]))
        error_case=next(c['i'] for c in sign_hash_cases() if c['code']==2)
        idx=max(i for i,s in enumerate(original) if s.startswith(f'W {error_case} '));lines=original.copy();f=lines[idx].split();f[5]=f'{int(f[5],16)^1:016x}';lines[idx]=' '.join(f);trials.append(('bad_error_zero_fill',lines))
        for tag,before_tag in [('S','R'),('E','S')]:
            idx=next(i for i,s in enumerate(original) if s.startswith(tag+' '));event=original[idx];case=event.split()[1]
            lines=original[:idx]+original[idx+1:];before=next(i for i,s in enumerate(lines) if s.startswith(f'{before_tag} {case} '));lines.insert(before,event);trials.append(('early_'+tag,lines))
        aborted={str(c['i']) for c in sign_hash_cases() if c['abort']==2}
        idx=next(i for i,s in enumerate(original) if s.startswith('W ') and s.split()[1] in aborted);trials.append(('lost_reset_prefix',original[:idx]+original[idx+1:]))
        for col in (2,3,4,5):
            idx=next(i for i,s in enumerate(original) if s.startswith('T '));f=original[idx].split();f[col]='0';lines=original.copy();lines[idx]=' '.join(f);trials.append(('witness'+str(col),lines))
        trials.extend([('footer',original[:-1]),('duplicate',original+[original[-1]]),('stale',['H '+'0'*64]+original[1:])])
        for label,lines in trials:
            try:verify_sign_hash(lines)
            except (ValueError,IndexError,KeyError,TypeError):continue
            raise ValueError('Signing hash checker accepted corruption:'+label)
        message=f'STAGE5N4B_SIGN_HASH_CHECKER_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_hash_checker_selftest.log').write_text(message);print(message,end='');return
    if stage==5 and unit=='sign_decode':
        original=(HERE/'stage5_sign_decode_outputs.txt').read_text().splitlines();verify_sign_decode(original);trials=[]
        for tag,columns in [('C',range(2,4)),('W',range(2,6)),('B',range(2,6)),('P',range(2,9)),('D',range(2,4))]:
            for col in columns:
                index=next(i for i,s in enumerate(original) if s.startswith(tag+' '));f=original[index].split();base=16 if (tag=='W' and col==5) or (tag=='B' and col>=3) or (tag=='P' and col==6) else 10
                f[col]=format(int(f[col],base)^1,'x') if base==16 else str(int(f[col])^1);lines=original.copy();lines[index]=' '.join(f);trials.append((tag+str(col),lines))
        for tag in ('C','W','B','P','D','A','T'):
            index=next(i for i,s in enumerate(original) if s.startswith(tag+' '));trials.append(('missing_'+tag,original[:index]+original[index+1:]))
        aborted={s.split()[1] for s in original if s.startswith('A ')}
        index=next(i for i,s in enumerate(original) if s.startswith('P ') and s.split()[1] in aborted)
        f=original[index].split();lines=original.copy();f[6]=f'{int(f[6],16)^1:06x}';lines[index]=' '.join(f);trials.append(('reset_prefix_data',lines))
        trials.append(('reset_prefix_missing',original[:index]+original[index+1:]))
        for col in range(2,6):
            index=next(i for i,s in enumerate(original) if s.startswith('T '));f=original[index].split();f[col]='0';lines=original.copy();lines[index]=' '.join(f);trials.append(('witness'+str(col),lines))
        trials.extend([('footer',original[:-1]),('duplicate',original+[original[-1]]),('stale',['H '+'0'*64]+original[1:])])
        for label,lines in trials:
            try:verify_sign_decode(lines)
            except (ValueError,IndexError,KeyError,TypeError):continue
            raise ValueError('Decode checker accepted corruption:'+label)
        message=f'STAGE5N4A_SIGN_DECODE_CHECKER_PASS:{len(trials)}/{len(trials)} corruptions rejected\n'
        (HERE/'stage5_sign_decode_checker_selftest.log').write_text(message);print(message,end='');return
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


def uvm_source_token():
    paths=sorted((ROOT/'src').rglob('*.sv'))+sorted((ROOT/'tb_uvm/tb_uvm_dilithium').glob('*.sv'))
    paths += [Path(__file__),HERE/'run_uvm.do',HERE/'report_uvm_coverage.tcl',HERE/'setup_cyclonev.tcl',ROOT/'quartus/dilithium/dilithium_full.qsf',ROOT/'quartus/dilithium/dilithium.sdc']
    for directory in (NIST_KEYGEN,NIST_SIGN,NIST_VERIFY):paths+=sorted(directory.glob('*.json'))
    h=hashlib.sha256()
    for p in paths:h.update(p.relative_to(ROOT).as_posix().encode());h.update(p.read_bytes())
    return h.hexdigest()


def uvm_artifacts():
    # Published inputs/outputs remain separate. Driver never reads expectations.
    jobs=[];gold=[]
    def add(op,p,jid,seed=bytes(32),rnd=bytes(32),first=b'',second=b'',body=b'',ctx=0,mlen=0,siglen=0,
            pk=b'',sk=b'',signature=b'',accept=0,code=0,abort=0,profile=0,origin='directed'):
        i=len(jobs);jobs.append((i,op,p,jid,ctx,mlen,siglen,profile,abort,seed[::-1].hex(),rnd[::-1].hex(),first.hex() or '-',second.hex() or '-',body.hex() or '-'))
        gold.append((i,code,0,0,accept,pk.hex() or '-',sk.hex() or '-',signature.hex() or '-',origin))
    kg=nist_keygen_cases();sg=nist_sign_cases();vg=nist_verify_corpus()[0]
    def key(p,jid=None,abort=0):
        c=next(c for c in kg if c['p']==p);add(0,p,c['id'] if jid is None else jid,seed=c['xi'],pk=c['pk'] if not abort else b'',sk=c['sk'] if not abort else b'',abort=abort,profile=p,origin='NIST_KeyGen')
    def sign(p,randomized=False,jid=None,abort=0):
        c=next(c for c in sg if c['p']==p and c['deterministic']!=randomized)
        add(1,p,c['id'] if jid is None else jid,rnd=c['rnd'],first=c['sk'],body=c['body'],ctx=c['ctxlen'],mlen=c['mlen'],signature=c['signature'] if not abort else b'',abort=abort,profile=(p+int(randomized))%3,origin='NIST_Sign')
    def verify(p,kind=0,jid=None,abort=0):
        candidates=[c for c in vg if c['p']==p and c['valid']==(kind==0)]
        c=next(c for c in candidates if kind==0 or (verify_unpack_math(1,p,c['sig'])[3] or verify_unpack_math(1,p,c['sig'])[2] is None)==(kind==2))
        add(2,p,c['tc'] if jid is None else jid,first=c['pk'],second=c['sig'],body=c['ctx']+c['msg'],ctx=len(c['ctx']),mlen=len(c['msg']),siglen=len(c['sig']),accept=int(c['valid']) if not abort else 0,abort=abort,profile=p,origin=f'NIST_Verify_{kind}')
    for p in range(3):
        key(p);sign(p);verify(p);sign(p,True);verify(p,1);verify(p,2)
    add(3,0,65535,code=2);add(0,3,0,code=1);add(1,3,65535,code=1);add(2,3,0,code=1)
    add(1,0,901,ctx=256,code=1);add(2,0,902,mlen=65535,siglen=2420,code=1)
    for p in range(3):add(2,p,910+p,siglen=0,profile=p)
    for op in range(3):
        if op==0:key(0,1200,100);key(0,1200)
        elif op==1:sign(0,False,1201,100);sign(0,False,1201)
        else:verify(0,0,1202,100);verify(0,0,1202)
    token=uvm_source_token()
    def serialize(rows):return f'{token} {len(rows)}\n'+''.join(' '.join(map(str,row))+'\n' for row in rows)
    return token,serialize(jobs),serialize(gold)


def uvm_prepare():
    token,inputs,expected=uvm_artifacts()
    (HERE/'uvm_inputs.txt').write_text(inputs,encoding='ascii')
    (HERE/'uvm_expected.txt').write_text(expected,encoding='ascii')
    print(f'UVM_PREPARE_PASS:{len(inputs.splitlines())-1} scenarios;separate published expectations;token {token}')


def uvm_check():
    token,inputs,expected=uvm_artifacts()
    if (HERE/'uvm_inputs.txt').read_text()!=inputs or (HERE/'uvm_expected.txt').read_text()!=expected:raise ValueError('UVM stale fixtures;run uvm_prepare')
    print('UVM_FRESHNESS_PASS:'+token)


def lighthd_ntt_artifacts():
    """Independent FIPS-derived fixtures for direct-bank/scalar NTT comparison."""
    paths = sorted((ROOT / 'src/ntt').glob('*.sv')) + [
        ROOT / 'tb/tb_dilithium/reference/ntt_core_scalar_reference.sv',
        ROOT / 'tb/tb_dilithium/unit/tb_ntt_bank.sv',
        ROOT / 'tb/tb_dilithium/unit/tb_ntt_dma.sv',
        ROOT / 'tb/tb_dilithium/unit/tb_butterfly_fused.sv',
        ROOT / 'tb/tb_dilithium/unit/tb_ntt_decoders.sv',
        ROOT / 'tb/tb_dilithium/unit/tb_memory_switch.sv',
        ROOT / 'tb/tb_dilithium/reference/memory_router_c12_reference.sv',
        ROOT / 'tb/tb_dilithium/reference/process_dma_c12_reference.sv',
        ROOT / 'tb/tb_dilithium/unit/tb_process_ports.sv',
        ROOT / 'tb/tb_dilithium/reference/butterfly_unit_c11_reference.sv',
        HERE / 'setup_cyclonev.tcl',
        ROOT / 'src/controller/datapath/ntt_dma.sv',
        ROOT / 'src/controller/memory/poly_bram.sv',
        ROOT / 'src/controller/memory/memory_banks.sv', ROOT / 'src/controller/memory/bank_request_pipe.sv',
        ROOT / 'src/controller/memory/memory_port.sv',
        ROOT / 'src/controller/memory/memory.sv',
        ROOT / 'src/controller/memory/memory_router.sv',
        ROOT / 'src/controller/memory/bank_fabric.sv',
        Path(__file__), NTT_REF,
    ]
    digest = hashlib.sha256()
    for path in paths:
        digest.update(path.relative_to(ROOT).as_posix().encode())
        digest.update(path.read_bytes())
    token = digest.hexdigest()
    rng = random.Random(20261025)
    cases = []
    for op in range(5):
        for variant in range(32):
            if op == 3:
                a = [rng.randrange(-4, 5) % 8380417 for _ in range(256)]
            else:
                a = [rng.randrange(8380417) for _ in range(256)]
            if variant == 0:
                a = [0] * 256
            elif variant == 1:
                a = [8380416] * 256
            elif variant == 2:
                a = [1] + [0] * 255
            elif variant == 3:
                a = [(i % 9 - 4) % 8380417 for i in range(256)]
            b = [rng.randrange(8380417) for _ in range(256)]
            c = [rng.randrange(8380417) for _ in range(256)]
            out = (ntt_reference.inverse(a) if op == 1 else
                   ntt_reference.pointwise(a, b) if op in (2, 4) else
                   ntt_reference.forward(a))
            if op == 4:
                out = [(x + y) % 8380417 for x, y in zip(out, c)]
            cases.append((op, a, b, c, out))
    inputs = [f'{token} {len(cases)}']
    expected = [f'{token} {len(cases)}']
    for serial, (op, a, b, c, out) in enumerate(cases):
        inputs += [f'{serial} {op}', ' '.join(f'{v:06x}' for v in a),
                   ' '.join(f'{v:06x}' for v in b), ' '.join(f'{v:06x}' for v in c)]
        expected += [str(serial), ' '.join(f'{v:06x}' for v in out)]
    return token, '\n'.join(inputs) + '\n', '\n'.join(expected) + '\n'


def lighthd_sampler_cases():
    result = []
    for original in cases():
        row = dict(original)
        if row['param'] == 3:
            data, values, code = b'', [], 3
        else:
            data = (hashlib.shake_128 if row['mode'] == 0 else hashlib.shake_256)(row['message']).digest(4096)
            values, used = reference.sample(row['mode'], row['param'], data)
            data, code = data[:used], 0
        row.update(data=data, values=values, code=code, bad_bytes=-1)
        result.append(row)
    for mode in range(4):
        for bad_bytes in (0, 17):
            result.append(dict(i=len(result), id=3000+len(result), mode=mode, param=0,
                               abort=False, data=b'', values=[], code=4, bad_bytes=bad_bytes))
    for mode in range(4):
        for slot in range(2):
            data = bytes(10)
            values, _ = reference.sample(mode, 0, data)
            result.append(dict(i=len(result), id=3000+len(result), mode=mode, param=0,
                               abort=False, data=data, values=values, code=1, bad_bytes=-1))
    for mode in range(4):
        for param in range(3):
            for core in range(2):
                data = reference.boundary_bytes(mode, param, core)
                values, used = reference.sample(mode, param, data)
                assert len(values) == 256
                result.append(dict(i=len(result), id=3000+len(result), mode=mode, param=param,
                                   abort=False, data=data[:used], values=values, code=0, bad_bytes=-1))
    assert len(result) == 144
    return result


def lighthd_sampler_artifacts():
    paths = sorted((ROOT / 'src/sampler').glob('*.sv')) + [
        ROOT / 'src/controller/process/secret_regroup.sv',
        ROOT / 'tb/tb_dilithium/reference/sampler_scalar_reference.sv',
        ROOT / 'tb/tb_dilithium/unit/tb_sampler_bank.sv', Path(__file__), REF,
        ROOT / 'src/controller/datapath/sampler_writer.sv',
        ROOT / 'tb/tb_dilithium/unit/tb_sampler_writer.sv',
        ROOT / 'tb/tb_dilithium/unit/tb_sampler_writer_mixed.sv',
        ROOT / 'tb/tb_dilithium/unit/tb_sampler_writer_queue.sv',
        ROOT / 'tb/tb_dilithium/support/bank_fixture.sv',
    ]
    paths += sorted((ROOT/'src/controller/memory').glob('*.sv'))
    paths += [ROOT/'src/controller/memory/poly_bram.sv', ROOT/'src/controller/memory/memory_banks.sv', ROOT/'src/controller/memory/bank_request_pipe.sv']
    digest = hashlib.sha256()
    for path in paths:
        digest.update(path.relative_to(ROOT).as_posix().encode())
        digest.update(path.read_bytes())
    token = digest.hexdigest()
    selected = lighthd_sampler_cases()
    inputs = [f'{token} {len(selected)}']
    expected = [f'{token} {len(selected)}']
    for c in selected:
        inputs.append(f"{c['i']} {c['id']} {c['mode']} {c['param']} {int(c['abort'])} {c['bad_bytes']} {len(c['data'])}")
        if c['data']:
            inputs.append(' '.join(f'{byte:02x}' for byte in c['data']))
        expected.append(f"{c['i']} {c['code']} {int(c['abort'])} {len(c['values'])}")
        if c['values']:
            expected.append(' '.join(f'{v:06x}' for v in c['values']))
    return token, '\n'.join(inputs)+'\n', '\n'.join(expected)+'\n', selected


def lighthd_sampler_prepare():
    token, inputs, expected, selected = lighthd_sampler_artifacts()
    (HERE/'sampler_inputs.txt').write_text(inputs, encoding='ascii')
    (HERE/'sampler_expected.txt').write_text(expected, encoding='ascii')
    print(f'LIGHTHD_SAMPLER_PREPARE_PASS:{len(selected)} jobs;independent FIPS byte-stream formulas;token '+token)


def lighthd_sampler_check():
    token, inputs, expected, _ = lighthd_sampler_artifacts()
    if ((HERE/'sampler_inputs.txt').read_text()!=inputs or
            (HERE/'sampler_expected.txt').read_text()!=expected):
        raise ValueError('Direct sampler stale fixtures;run lighthd_sampler_prepare')
    print('LIGHTHD_SAMPLER_FRESHNESS_PASS:'+token)


def lighthd_sampler_compare():
    lighthd_sampler_check()
    token, _, _, selected = lighthd_sampler_artifacts()
    for kind in ('bank', 'scalar'):
        lines = (HERE/f'sampler_{kind}_outputs.txt').read_text().splitlines()
        if not lines or lines[0]!=f'{token} {len(selected)}':
            raise ValueError('Direct sampler capture header mismatch')
        live = {};values = {};groups = {};retired = set();footer = False
        for line in lines[1:]:
            parts=line.split();tag=parts[0]
            if footer:
                raise ValueError('Records after sampler footer')
            if tag=='F':
                if len(parts)!=2 or int(parts[1])!=len(selected) or live or len(retired)!=len(selected):
                    raise ValueError('Incomplete sampler footer')
                footer=True;continue
            serial=int(parts[1]);c=selected[serial]
            if tag=='J':
                core,job,mode,param=map(int,parts[2:])
                if core in live or serial in values or (job,mode,param)!=(c['id'],c['mode'],c['param']):
                    raise ValueError('Sampler descriptor/ownership mismatch')
                live[core]=serial;values[serial]=[];groups[serial]=[];continue
            if serial not in live.values():
                raise ValueError('Unowned sampler result')
            if tag=='C':
                index,value= int(parts[2]),int(parts[3],16)
                if index!=len(values[serial]) or index>=len(c['values']) or value!=c['values'][index]:
                    raise ValueError(f'Sampler coefficient mismatch {kind} job{serial} index{index}')
                values[serial].append(value)
            elif tag=='G':
                word,value=int(parts[2]),int(parts[3],16)
                if kind!='bank' or c['mode']!=1 or word!=len(groups[serial]) or word>=16:
                    raise ValueError('Unexpected regrouped word')
                indices=[128*(word//8)+8*(word%8)+j for j in range(8)]
                indices += [v+64 for v in indices]
                if max(indices)>=len(c['values']):
                    raise ValueError('Regrouped word exceeds independently sampled prefix')
                packed=sum(((c['values'][i] if c['values'][i]<=4 else c['values'][i]-8380417)&15)<<(4*j)
                           for j,i in enumerate(indices))
                if value!=packed:
                    raise ValueError(f'Regrouped secret mismatch job{serial} word{word}')
                groups[serial].append(value)
            elif tag in ('S','A'):
                if (tag=='A')!=bool(c['abort']) or (tag=='S' and int(parts[2])!=c['code']):
                    raise ValueError(f'Sampler status/reset mismatch {kind} job{serial}: '
                                     f'{line}; expected status {c["code"]}, abort {c["abort"]}')
                if tag=='S' and c['code']==0:
                    if len(values[serial])!=256 or (kind=='bank' and c['mode']==1 and len(groups[serial])!=16):
                        raise ValueError('Incomplete sampled/regrouped polynomial')
                core=next(k for k,v in live.items() if v==serial)
                del live[core];retired.add(serial)
            else:
                raise ValueError('Unknown direct sampler record')
        if not footer:
            raise ValueError('Direct sampler footer missing')
        print(f'LIGHTHD_SAMPLER_COMPARE_PASS:{kind} {len(retired)} jobs/'
              f'{sum(map(len,values.values()))} checked coefficients/'
              f'{sum(map(len,groups.values()))} regrouped words')


def lighthd_memory_words(c):
    values=c['values']
    if c['mode']!=1:
        return [sum(v<<(23*lane) for lane,v in enumerate(values[w:w+4])) for w in range(0,256,4)]
    words=[]
    for word in range(16):
        indices=[128*(word//8)+8*(word%8)+j for j in range(8)]
        indices += [i+64 for i in indices]
        words.append(sum(((values[i] if values[i]<=4 else values[i]-8380417)&15)<<(4*j)
                         for j,i in enumerate(indices)))
    return words


def lighthd_writer_compare():
    lighthd_sampler_check()
    token,_,_,selected=lighthd_sampler_artifacts()
    selected=[c for c in selected if not c['abort'] and c['code']==0]
    want=[token,str(len(selected))]
    for c in selected:
        words=lighthd_memory_words(c)
        want += [str(c['i']),str(len(words))]+[f'{w:023x}' for w in words]
    got=(HERE/'sampler_writer_outputs.txt').read_text().split()
    if got!=want:
        index=next((i for i,(a,b) in enumerate(zip(got,want)) if a!=b),min(len(got),len(want)))
        raise ValueError(f'Sampler RAM-word mismatch at token {index};length {len(got)} expected {len(want)}')
    print(f'LIGHTHD_SAMPLER_WRITER_COMPARE_PASS:{len(selected)} full polynomials/'
          f'{sum(len(lighthd_memory_words(c)) for c in selected)} real-RAM words')


def lighthd_writer_mixed_artifacts():
    base, _, _, cases = lighthd_sampler_artifacts()
    chosen = [c for c in cases if c['param']!=3 and not c['abort'] and c['bad_bytes']<0 and len(c['data'])>10]
    secrets = [c for c in chosen if c['mode']==1]
    normal = [c for c in chosen if c['mode']!=1]
    ordered = []
    for c in secrets:
        ordered.extend((c, normal.pop(0)))
    ordered += normal
    assert len(ordered)==112
    token=hashlib.sha256((base+'writer-mixed-v1:'+','.join(str(c['i']) for c in ordered)).encode()).hexdigest()
    inputs=[f'{token} {len(ordered)}'];expected=[token,str(len(ordered))]
    for c in ordered:
        inputs += [f"{c['i']} {c['id']} {c['mode']} {c['param']} 0 -1 {len(c['data'])}",
                   ' '.join(f'{b:02x}' for b in c['data'])]
        words=lighthd_memory_words(c)
        expected += [str(c['i']),str(len(words))]+[f'{w:023x}' for w in words]
    return token,'\n'.join(inputs)+'\n','\n'.join(expected)+'\n'


def lighthd_writer_mixed_prepare():
    token,inputs,expected=lighthd_writer_mixed_artifacts()
    (HERE/'writer_mixed_inputs.txt').write_text(inputs,encoding='ascii')
    (HERE/'writer_mixed_expected.txt').write_text(expected,encoding='ascii')
    print('LIGHTHD_WRITER_MIXED_PREPARE_PASS:112 successful polynomials/reordered secret-normal pairs;token '+token)


def lighthd_writer_mixed_compare():
    token,inputs,expected=lighthd_writer_mixed_artifacts()
    if (HERE/'writer_mixed_inputs.txt').read_text()!=inputs or (HERE/'writer_mixed_expected.txt').read_text()!=expected:
        raise ValueError('Mixed writer fixtures are stale;run lighthd_writer_mixed_prepare')
    want=expected.split()
    for kind in ('same','different'):
        got=(HERE/f'writer_mixed_{kind}_outputs.txt').read_text().split()
        if got!=want:
            index=next((i for i,(a,b) in enumerate(zip(got,want)) if a!=b),min(len(got),len(want)))
            raise ValueError(f'Mixed writer {kind}-bank mismatch at token {index};length {len(got)} expected {len(want)}')
        print(f'LIGHTHD_WRITER_MIXED_COMPARE_PASS:{kind} banks/112 polynomials/5824 actual-RAM words;token '+token)


def lighthd_chain_artifacts():
    paths=sorted((ROOT/'src/keccak').glob('*.sv'))+sorted((ROOT/'src/sampler').glob('*.sv'))
    paths+=sorted((ROOT/'src/controller').rglob('*.sv'))
    paths+=[ROOT/'src/controller/datapath/keccak_sampler.sv',ROOT/'src/controller/memory/poly_bram.sv',
            ROOT/'src/controller/memory/memory_banks.sv', ROOT/'src/controller/memory/bank_request_pipe.sv',ROOT/'tb/tb_dilithium/support/bank_fixture.sv',
            ROOT/'tb/tb_dilithium/unit/tb_hash_sampler.sv',Path(__file__),REF]
    digest=hashlib.sha256()
    for path in paths:
        digest.update(path.relative_to(ROOT).as_posix().encode());digest.update(path.read_bytes())
    token=digest.hexdigest();selected=cases()
    inputs=[f'{token} {len(selected)}']
    valid=[c for c in selected if not c['abort'] and c['code']==0]
    expected=[f'{token} {len(valid)+3}']
    for c in selected:
        inputs.append(f"{c['i']} {c['id']} {c['mode']} {c['param']} {int(c['abort'])} {len(c['message'])} {c['message'].hex() or '-'}")
    for c in valid:
        words=lighthd_memory_words(c)
        expected += [f"P {c['i']} {len(words)}"]+[f'{w:023x}' for w in words]
    for serial in range(3):
        message=bytes((i*17+serial)&255 for i in range((0,33,136)[serial]))
        output=(hashlib.shake_128 if serial==0 else hashlib.shake_256)(message).digest(64)
        expected += [f'H {serial} 4']+[f'{int.from_bytes(output[i:i+16],"little"):032x}' for i in range(0,64,16)]
    return token,'\n'.join(inputs)+'\n','\n'.join(expected)+'\n'


def lighthd_chain_prepare():
    token,inputs,expected=lighthd_chain_artifacts()
    (HERE/'chain_inputs.txt').write_text(inputs,encoding='ascii')
    (HERE/'chain_expected.txt').write_text(expected,encoding='ascii')
    print('LIGHTHD_CHAIN_PREPARE_PASS:104 sampling commands+3 raw hashes;token '+token)


def lighthd_chain_compare():
    token,inputs,expected=lighthd_chain_artifacts()
    if ((HERE/'chain_inputs.txt').read_text()!=inputs or
        (HERE/'chain_expected.txt').read_text()!=expected):raise ValueError('Stale LightHD chain fixtures')
    got=(HERE/'hash_sampler_outputs.txt').read_text().split();want=expected.split()
    if got!=want:
        index=next((i for i,(a,b) in enumerate(zip(got,want)) if a!=b),min(len(got),len(want)))
        raise ValueError(f'Keccak/sampler/RAM mismatch at token {index};length {len(got)} expected {len(want)}')
    print('LIGHTHD_CHAIN_COMPARE_PASS:88 full sampled polynomials/192 raw hash bytes;token '+token)


def lighthd_keygen_artifacts():
    paths=sorted((ROOT/'src/keccak').glob('*.sv'))+sorted((ROOT/'src/sampler').glob('*.sv'))
    paths+=sorted((ROOT/'src/ntt').glob('*.sv'))
    # Match the actual compact KeyGen compilation boundary. Later Sign-only
    # modules must not be mislabeled as tested by this operation's capture.
    paths += [ROOT/p for p in ('src/controller/helpers/dilithium_pkg.sv',
        'src/controller/keygen.sv','src/controller/datapath/datapath.sv',
        'src/controller/datapath/hash_sampler.sv','src/controller/datapath/sampler_writer.sv',
        'src/controller/datapath/load_decode.sv','src/controller/process/bitunpkg.sv',
        'src/controller/datapath/ntt_dma.sv','src/controller/datapath/process_dma.sv',
        'src/controller/process/secret_regroup.sv','src/controller/process/poly_process.sv',
        'src/controller/process/bitpkg.sv','src/controller/memory/memory_port.sv',
        'src/controller/memory/memory.sv','src/controller/memory/memory_router.sv',
        'src/controller/memory/bank_fabric.sv')]
    paths+=[ROOT/'src/controller/datapath/keccak_sampler.sv',ROOT/'src/controller/memory/poly_bram.sv',
            ROOT/'src/controller/memory/memory_banks.sv', ROOT/'src/controller/memory/bank_request_pipe.sv',ROOT/'src/controller/process/power2round.sv',
            ROOT/'src/controller/process/cnb.sv',ROOT/'src/controller/process/mhint.sv',
            ROOT/'tb/tb_dilithium/tb_keygen.sv',Path(__file__)]
    digest=hashlib.sha256()
    for path in paths:
        digest.update(path.relative_to(ROOT).as_posix().encode());digest.update(path.read_bytes())
    token=digest.hexdigest();selected=nist_keygen_cases()
    inputs=[f'{token} {len(selected)}']
    for c in selected:
        inputs.append(f"{c['i']} {c['p']} {c['id']} {int.from_bytes(c['xi'],'little'):064x} keygen_L{(2,3,5)[c['p']]}_tg{c['tg']}_tc{c['tc']}")
    return token,'\n'.join(inputs)+'\n',selected


def lighthd_keygen_prepare():
    token,inputs,_=lighthd_keygen_artifacts()
    (HERE/'keygen_inputs.txt').write_text(inputs,encoding='ascii')
    print('LIGHTHD_KEYGEN_PREPARE_PASS:75 pinned official NIST seeds;token '+token)


def lighthd_keygen_protocol_cases(selected):
    result=[]
    for i in range(20):
        source=25*i if i<3 else 25*(((i-3)//2)%3) if i<19 else 0
        c=dict(selected[source]);c['id']=5000+i if i<3 else 6000+(i-3)//2 if i<19 else 7000
        c['reset']=3<=i<19 and (i-3)%2==0
        if i<3:c.update(p=3,code=1,pk=b'',sk=b'')
        result.append(c)
    return result


def lighthd_keygen_compare(protocol=False):
    token,inputs,selected=lighthd_keygen_artifacts()
    if (HERE/'keygen_inputs.txt').read_text()!=inputs:raise ValueError('Stale compact KeyGen fixtures')
    if protocol:selected=lighthd_keygen_protocol_cases(selected)
    captured=(HERE/('keygen_protocol_outputs.txt' if protocol else 'keygen_outputs.txt')).read_text()
    total=lighthd_keygen_compare_text(captured,token,selected)
    print((f'LIGHTHD_KEYGEN_PROTOCOL_COMPARE_PASS:20 commands/9 complete published keypairs/3 rejects/8 reset prefixes/{total} checked bytes;token ' if protocol else
           f'LIGHTHD_KEYGEN_NIST_COMPARE_PASS:75 complete published keypairs/{total} bytes;token ')+token)


def lighthd_keygen_compare_text(captured,token,selected):
    count=len(selected);lines=captured.splitlines()
    if not lines or lines[0]!=f'{token} {count}':raise ValueError('Compact KeyGen capture token/count')
    current=None;seen=set();keys=[bytearray(),bytearray()];last_type=0;footer=False;total=0
    for line in lines[1:]:
        parts=line.split()
        if footer:raise ValueError('Records after compact KeyGen footer')
        if parts[0]=='J':
            serial,p,job=map(int,parts[1:])
            if current is not None or serial!=len(seen) or serial in seen or serial not in range(count):raise ValueError('Compact KeyGen duplicate/live job')
            current=selected[serial]
            if (p,job)!=(current['p'],current['id']):raise ValueError('Compact KeyGen command identity')
            seen.add(serial);keys=[bytearray(),bytearray()];last_type=0
        elif parts[0]=='K':
            if current is None:raise ValueError('Unowned compact key word')
            kind,index,byte_count,last=int(parts[1]),int(parts[2]),int(parts[4]),int(parts[5])
            if kind not in (0,1) or kind<last_type or index*8!=len(keys[kind]) or byte_count!=8:raise ValueError('Compact key ordering/size')
            if kind==1 and len(keys[0])!=len(current['pk']):raise ValueError('Secret key started before complete public key')
            value=int(parts[3],16).to_bytes(8,'little');wanted=current['pk' if kind==0 else 'sk']
            if value!=wanted[index*8:index*8+8] or bool(last)!=(index*8+8==len(wanted)):
                raise ValueError(f"Compact KeyGen differs from published NIST tg{current['tg']} tc{current['tc']} {'SK' if kind else 'PK'} word{index}")
            keys[kind].extend(value);last_type=kind;total+=8
        elif parts[0]=='D':
            if len(parts)!=3 or int(parts[2])<=0 or current is None or current.get('reset') or int(parts[1])!=current['code'] or tuple(map(bytes,keys))!=(current['pk'],current['sk']):raise ValueError('Incomplete compact KeyGen command')
            current=None
        elif parts==['A']:
            if current is None or not current.get('reset'):raise ValueError('Unexpected compact KeyGen reset')
            current=None
        elif parts[0]=='F':
            if current is not None or len(seen)!=count or parts!=['F',str(count)]:raise ValueError('Incomplete compact KeyGen campaign')
            footer=True
        else:raise ValueError('Unknown compact KeyGen capture record')
    if not footer:raise ValueError('Compact KeyGen footer missing')
    return total


def lighthd_keygen_selftest():
    token,_,selected=lighthd_keygen_artifacts();selected=lighthd_keygen_protocol_cases(selected)
    lines=[f'{token} 20']
    for serial,c in enumerate(selected):
        lines.append(f"J {serial} {c['p']} {c['id']}")
        if c.get('reset'):
            lines.append('A');continue
        for kind,key in enumerate((c['pk'],c['sk'])):
            for i in range(0,len(key),8):
                lines.append(f'K {kind} {i//8} {int.from_bytes(key[i:i+8],"little"):016x} 8 {int(i+8==len(key))}')
        lines.append(f"D {c['code']} 1")
    lines.append('F 20')
    lighthd_keygen_compare_text('\n'.join(lines),token,selected)
    changes=[]
    def replace(index,text):
        altered=lines.copy();altered[index]=text;changes.append('\n'.join(altered))
    key=next(i for i,line in enumerate(lines) if line.startswith('K '))
    successful_done=next(i for i,line in enumerate(lines) if line=='D 0 1')
    reset=lines.index('A')
    for index,text in [(0,'invalid 20'),(0,token+' 19'),(1,'J 0 0 5000'),(1,'J 0 3 5001'),
                       (1,'J 1 3 5000'),(2,'D 0 1'),(2,'A'),(2,'D 1 0'),(2,'D 1 -1'),
                       (key,'K 0 0 0000000000000000 8 0'),(key,'K 1 0 0000000000000000 8 0'),
                       (key,lines[key].replace('K 0 0 ','K 0 1 ',1)),
                       (key,lines[key].rsplit(' 8 ',1)[0]+' 7 0'),
                       (key,lines[key].rsplit(' ',1)[0]+' 1'),
                       (key,'K 0 0 10000000000000000 8 0'),(key,'UNKNOWN'),
                       (successful_done,'D 1 1'),(successful_done,'A'),(reset,'D 0 1'),
                       (len(lines)-1,'F 19')]:replace(index,text)
    for index in (key,successful_done,len(lines)-1):
        changes.append('\n'.join(lines[:index]+lines[index+1:]))
    changes += ['\n'.join(lines+['K 0 0 0000000000000000 8 0']),
                '\n'.join(lines[:key]+[lines[key]]+lines[key:])]
    for changed in changes:
        try:lighthd_keygen_compare_text(changed,token,selected)
        except (ValueError,OverflowError):continue
        raise AssertionError('Compact KeyGen checker accepted corruption')
    print(f'LIGHTHD_KEYGEN_CHECKER_SELFTEST_PASS:{len(changes)} corruptions rejected;valid published-key control accepted')


def lighthd_sign_load_artifacts():
    # Includes the ACTUAL shared datapath and its nested writer/codec,not a
    # separately instantiated decoder-only substitute.
    paths=sorted((ROOT/'src/keccak').glob('*.sv'))+sorted((ROOT/'src/sampler').glob('*.sv'))
    paths+=sorted((ROOT/'src/ntt').glob('*.sv'))
    paths += [ROOT/p for p in ('src/controller/helpers/dilithium_pkg.sv',
        'src/controller/sign_input.sv','src/controller/datapath/datapath.sv',
        'src/controller/datapath/hash_sampler.sv','src/controller/datapath/sampler_writer.sv',
        'src/controller/datapath/load_decode.sv','src/controller/datapath/ntt_dma.sv',
        'src/controller/datapath/process_dma.sv','src/controller/process/bitunpkg.sv',
        'src/controller/process/poly_process.sv','src/controller/process/bitpkg.sv',
        'src/controller/process/secret_regroup.sv','src/controller/process/power2round.sv',
        'src/controller/process/cnb.sv','src/controller/process/mhint.sv',
        'src/controller/datapath/keccak_sampler.sv','src/controller/memory/poly_bram.sv',
        'src/controller/memory/memory_banks.sv', 'src/controller/memory/bank_request_pipe.sv','src/controller/memory/memory_port.sv',
        'src/controller/memory/memory.sv','src/controller/memory/memory_router.sv',
        'src/controller/memory/bank_fabric.sv','tb/tb_dilithium/support/service_fixture.sv',
        'tb/tb_dilithium/unit/tb_sign_input.sv')]
    paths.append(Path(__file__))
    digest=hashlib.sha256()
    for path in paths:
        digest.update(path.relative_to(ROOT).as_posix().encode());digest.update(path.read_bytes())
    token=digest.hexdigest();official=nist_keygen_cases();selected=[dict(c,action=0,expected_code=0) for c in official]
    for p in range(3):
        base=official[25*p]
        for action in range(1,11):
            c=dict(base,id=10000+100*p+action,action=action,expected_code=1 if action==1 else 2 if action==4 else 3 if action<8 else -1)
            if action==4:
                raw=bytearray(c['sk']);width=4 if p==1 else 3;eta=4 if p==1 else 2
                raw[128]=(raw[128]&~((1<<width)-1))|(2*eta+1);c['sk']=bytes(raw)
            selected += [c,dict(base,id=c['id'],action=0,expected_code=0)]
    inputs=[f'{token} {len(selected)}'];expected=[f'{token} {len(selected)}']
    for serial,c in enumerate(selected):
        inputs.append(f"{serial} {c['p']} {c['id']} {c['action']} {c['expected_code']} {len(c['sk'])} {c['sk'].hex()}")
        expected.append(f"J {serial} {3 if c['action']==1 else c['p']} {c['id']}")
        if c['expected_code']<0:expected.append('A');continue
        if c['expected_code']==0:
            sk=c['sk'];expected.append(f"H {int.from_bytes(sk[:32],'little'):064x} {int.from_bytes(sk[32:64],'little'):064x} {int.from_bytes(sk[64:128],'little'):0128x}")
            decoded,_=decode_key_math(sk,c['p']);k,l=((4,4),(6,5),(8,7))[c['p']]
            for section,polys in enumerate((l,k,k)):
                for poly in range(polys):
                    values=[r[3] for r in decoded if r[0]==section and r[1]==poly]
                    words=lighthd_memory_words(dict(mode=1 if section<2 else 0,values=values))
                    expected.append(f'P {section} {poly} {len(words)}');expected += [f'{w:023x}' for w in words]
        expected.append(f"D {c['expected_code']}")
    expected.append(f'F {len(selected)}')
    return token,'\n'.join(inputs)+'\n','\n'.join(expected)+'\n'


def lighthd_sign_load_prepare():
    token,inputs,expected=lighthd_sign_load_artifacts()
    (HERE/'sign_load_inputs.txt').write_text(inputs,encoding='ascii')
    (HERE/'sign_load_expected.txt').write_text(expected,encoding='ascii')
    print('LIGHTHD_SIGN_LOAD_PREPARE_PASS:135 actual-datapath cases;token '+token)


def lighthd_sign_load_compare():
    token,inputs,expected=lighthd_sign_load_artifacts()
    if ((HERE/'sign_load_inputs.txt').read_text()!=inputs or
        (HERE/'sign_load_expected.txt').read_text()!=expected):raise ValueError('Stale actual-datapath SK-load fixtures')
    got=(HERE/'sign_load_outputs.txt').read_text().split();want=expected.split()
    if got!=want:
        index=next((i for i,(a,b) in enumerate(zip(got,want)) if a!=b),min(len(got),len(want)))
        raise ValueError(f'Actual-datapath SK-load mismatch at token {index};length {len(got)} expected {len(want)}')
    print('LIGHTHD_SIGN_LOAD_COMPARE_PASS:135 commands/105 complete published SKs/21 rejects/9 resets;all headers/raw bank words exact;token '+token)


@lru_cache(maxsize=180)
def lighthd_sign_model(original,include_internal=False):
    """Independent arithmetic/counter trace;published signatures remain expected."""
    c=nist_sign_cases(include_internal)[original];p=c['p'];q=8380417;k,l=((4,4),(6,5),(8,7))[p]
    gamma1=(131072,524288,524288)[p];gamma2=(95232,261888,261888)[p];beta=(78,196,120)[p];omega=(80,55,75)[p]
    raw=decode_key_math(c['sk'],p)[0]
    secrets=[[r[3] for r in raw[j:j+256]] for j in range(0,len(raw),256)]
    hats=[ntt_reference.forward(poly) for poly in secrets]
    mu=hashlib.shake_256(c['sk'][64:128]+(b'' if c.get('internal',False) else bytes((0,c['ctxlen'])))+c['body']).digest(64)
    seed=hashlib.shake_256(c['sk'][32:64]+c['rnd']+mu).digest(64)
    matrix=[[reference.sample(0,p,hashlib.shake_128(c['sk'][:32]+bytes((j,row))).digest(4096))[0]
             for j in range(l)] for row in range(k)]
    chain=[]
    for base in range(0,65537-l,l):
        y=[reference.sample(2,p,hashlib.shake_256(seed+(base+j).to_bytes(2,'little')).digest(4096))[0] for j in range(l)]
        yhat=[ntt_reference.forward(poly) for poly in y]
        w=[ntt_reference.inverse([sum(matrix[row][j][i]*yhat[j][i] for j in range(l))%q for i in range(256)]) for row in range(k)]
        pairs=[[mathematical_decompose(value,p) for value in poly] for poly in w]
        high=[[pair[0] for pair in poly] for poly in pairs];low=[[pair[1]%q for pair in poly] for poly in pairs]
        width=6 if p==0 else 4;flat=[v for poly in high for v in poly]
        packed=sum(value<<(width*i) for i,value in enumerate(flat)).to_bytes(len(flat)*width//8,'little')
        digest=hashlib.shake_256(mu+packed).digest((32,48,64)[p])
        challenge=reference.sample(3,p,hashlib.shake_256(digest).digest(4096))[0];chat=ntt_reference.forward(challenge)
        products=[ntt_reference.inverse(ntt_reference.pointwise(chat,hat)) for hat in hats]
        z=[[(a+b)%q for a,b in zip(yj,sj)] for yj,sj in zip(y,products[:l])]
        r0=[[(a-b)%q for a,b in zip(wj,sj)] for wj,sj in zip(low,products[l:l+k])]
        ct0=products[l+k:]
        norms=[tuple(any(min(v,q-v)>=bound for v in poly) for poly in polys)
               for polys,bound in ((z,gamma1-beta),(r0,gamma2-beta),(ct0,gamma2))]
        combined=[[(a+b)%q for a,b in zip(x,t)] for x,t in zip(r0,ct0)]
        hints=[[int(mathematical_decompose((h*2*gamma2+x)%q,p)[0]!=h) for x,h in zip(poly,hi)] for poly,hi in zip(combined,high)]
        weights=tuple(map(sum,hints));violations=tuple(i+1 for i,flags in enumerate(norms) if any(flags))
        if sum(weights)>omega:violations+=(4,)
        chain.append(dict(base=base,digest=digest,norms=norms,weights=weights,violations=violations))
        if not violations:
            if signature_bytes(p,dict(digest=digest,z=z,hints=hints))!=c['signature']:
                raise ValueError(f"Independent compact Sign model differs from NIST tg{c['tg']} tc{c['tc']}")
            return dict(mu=mu,seed=seed,chain=tuple(chain),attempts=len(chain),next_nonce=base+l)
    raise ValueError('Published signing input exhausted all16-bit sampling nonces')


def lighthd_sign_artifacts():
    # A full-operation source fingerprint,including the original FIPS formatter.
    paths=sorted((ROOT/'src/keccak').glob('*.sv'))+sorted((ROOT/'src/sampler').glob('*.sv'))+sorted((ROOT/'src/ntt').glob('*.sv'))
    paths+=sorted((ROOT/'src/controller').rglob('*.sv'))
    paths += [ROOT/p for p in ('src/controller/datapath/keccak_sampler.sv','src/controller/memory/poly_bram.sv',
        'src/controller/memory/memory_banks.sv', 'src/controller/memory/bank_request_pipe.sv','src/controller/process/power2round.sv','src/controller/process/cnb.sv',
        'src/controller/process/mhint.sv','src/controller/process/sign_hash_message.sv','tb/tb_dilithium/tb_sign.sv',
        'tb/tb_dilithium/tb_sign_protocol.sv','tb/tb_dilithium/unit/tb_memory_geometry.sv',
        'tb/tb_dilithium/unit/tb_memory_admission.sv','tb/tb_dilithium/unit/tb_area_arithmetic.sv')]
    paths += [Path(__file__),REF,NTT_REF]
    digest=hashlib.sha256()
    for path in paths:
        digest.update(path.relative_to(ROOT).as_posix().encode());digest.update(path.read_bytes())
    token=digest.hexdigest();rows=nist_sign_cases()
    models=[lighthd_sign_model(i) for i in range(len(rows))]
    diagnostic=[min((c for c in rows if c['p']==p),key=lambda c:(models[c['i']]['attempts'],c['ctxlen']+c['mlen'])) for p in range(3)]
    def serialize(selected):
        result=[f'{token} {len(selected)}']
        for serial,c in enumerate(selected):
            result.append(f"{serial} {c['i']} {c['p']} {c['id']} {c['ctxlen']} {c['mlen']} {len(c['sk'])} {len(c['body'])} "
                          f"{int.from_bytes(c['rnd'],'little'):064x} {c['sk'].hex()} {c['body'].hex() or '-'} sign_L{(2,3,5)[c['p']]}_tg{c['tg']}_tc{c['tc']}")
        return '\n'.join(result)+'\n'
    return token,serialize(rows),serialize(diagnostic),rows,diagnostic


def lighthd_sign_prepare():
    token,inputs,diagnostic,rows,selected=lighthd_sign_artifacts()
    (HERE/'sign_inputs.txt').write_text(inputs,encoding='ascii')
    (HERE/'sign_diagnostic_inputs.txt').write_text(diagnostic,encoding='ascii')
    print('LIGHTHD_SIGN_PREPARE_PASS:90 official inputs;independent arithmetic/nonce traces match all published signatures;token '+token)
    print('SIGN_DIAGNOSTIC_ORIGINAL_CASES:'+','.join(f"{c['i']}(level{c['p']},attempts{lighthd_sign_model(c['i'])['attempts']})" for c in selected))


def lighthd_sign_compare(diagnostic=False,captured=None,quiet=False):
    token,inputs,small,rows,selected=lighthd_sign_artifacts()
    if ((HERE/'sign_inputs.txt').read_text()!=inputs or
        (HERE/'sign_diagnostic_inputs.txt').read_text()!=small):raise ValueError('Stale compact Sign fixtures')
    if not diagnostic:selected=rows
    file=HERE/('sign_diagnostic_outputs.txt' if diagnostic else 'sign_outputs.txt')
    lines=(file.read_text() if captured is None else captured).splitlines();count=len(selected)
    if not lines or lines[0]!=f'{token} {count}':raise ValueError('Compact Sign token/count mismatch')
    current=None;signature=bytearray();seen=0;challenges=0;rejected=set();footer=False;total=0
    for line in lines[1:]:
        parts=line.split();tag=parts[0]
        if footer:raise ValueError('Records after compact Sign footer')
        if tag=='J':
            serial,original,p,job=map(int,parts[1:])
            if current is not None or serial!=seen or serial>=count:raise ValueError('Compact Sign command order')
            current=selected[serial];model=lighthd_sign_model(current['i'])
            if (original,p,job)!=(current['i'],current['p'],current['id']):raise ValueError('Compact Sign identity')
            signature=bytearray();challenges=0;rejected=set();seen+=1
        elif tag=='C':
            if current is None:raise ValueError('Unowned signing challenge')
            attempt,base,length=map(int,parts[1:4]);value=int(parts[4],16).to_bytes(64,'little')[:length]
            if attempt!=challenges+1 or attempt>len(model['chain']):raise ValueError('Compact Sign attempt sequence')
            expected=model['chain'][attempt-1]
            if base!=expected['base'] or length!=len(expected['digest']) or value!=expected['digest']:
                raise ValueError(f"Compact Sign challenge differs from independent model case{current['i']} attempt{attempt}")
            challenges+=1
        elif tag=='R':
            if current is None:raise ValueError('Unowned rejection')
            attempt,reason,index=map(int,parts[1:])
            if attempt!=challenges or attempt in rejected or attempt>=model['attempts']:raise ValueError('False/duplicate signing rejection')
            expected=model['chain'][attempt-1]
            if reason not in expected['violations']:raise ValueError('Signing rejection has no mathematical justification')
            if reason<4 and (index>=len(expected['norms'][reason-1]) or not expected['norms'][reason-1][index]):raise ValueError('Wrong rejected polynomial')
            if reason==4 and sum(expected['weights'][:index+1])<=(80,55,75)[current['p']]:raise ValueError('Hint prefix has not exceeded omega')
            rejected.add(attempt)
        elif tag=='S':
            if current is None:raise ValueError('Unowned signature word')
            index,value,byte_count,last=int(parts[1]),int(parts[2],16),int(parts[3]),int(parts[4]);wanted=current['signature']
            if index*8!=len(signature) or byte_count!=min(8,len(wanted)-len(signature)) or byte_count<=0:raise ValueError('Compact signature word order/length')
            if last not in (0,1) or value>> (8*byte_count) or value.to_bytes(8,'little')[:byte_count]!=wanted[len(signature):len(signature)+byte_count] or bool(last)!=(len(signature)+byte_count==len(wanted)):
                raise ValueError(f"Compact signature differs from published NIST tg{current['tg']} tc{current['tc']} word{index}")
            signature+=value.to_bytes(8,'little')[:byte_count];total+=byte_count
        elif tag=='D':
            if current is None:raise ValueError('Unowned signing completion')
            code,stage,detail,attempts,rejections,nonce,cycles=map(int,parts[1:])
            if (code,stage,detail)!=(0,0,0) or bytes(signature)!=current['signature'] or attempts!=model['attempts'] or rejections!=attempts-1 or nonce!=model['next_nonce'] or cycles<=0:
                raise ValueError('Compact Sign completion/counters mismatch')
            if challenges!=attempts or rejected!=set(range(1,attempts)):raise ValueError('Missing signing challenge/rejection trace')
            current=None
        elif tag=='F':
            if current is not None or seen!=count or parts!=['F',str(count)]:raise ValueError('Incomplete compact Sign campaign')
            footer=True
        else:raise ValueError('Unknown compact Sign record')
    if not footer:raise ValueError('Compact Sign footer missing')
    if not quiet:print(f'LIGHTHD_SIGN_NIST_COMPARE_PASS:{count} complete published signatures/{total} bytes;all attempt hashes and rejection reasons justified;token '+token)


def lighthd_sign_protocol_compare(captured=None,quiet=False):
    """Published bytes plus exact error/reset/recovery schedule; no RTL oracle."""
    token,inputs,small,_,selected=lighthd_sign_artifacts()
    if ((HERE/'sign_inputs.txt').read_text()!=inputs or
        (HERE/'sign_diagnostic_inputs.txt').read_text()!=small):raise ValueError('Stale compact Sign protocol fixtures')
    plan=[(0,-1,-1,i) for i in range(3)]
    for p in range(3):
        for bad in range(7):plan.extend(((p,-1,bad,-1),(p,-1,-1,-1)))
    for phase in range(12):plan.extend(((phase%3,phase,-1,-1),(phase%3,-1,-1,-1)))
    lines=((HERE/'sign_protocol_outputs.txt').read_text() if captured is None else captured).splitlines()
    def check(condition,message):
        if not condition:raise ValueError('Compact Sign protocol: '+message)
    check(bool(lines) and lines[0]==f'{token} 69','token/count')
    case=-1;active=False;signature=bytearray();total=prefix=0;counts=[0,0,0];footer=False
    # State numbers are the fixed reset targets in the compact Sign FSM.
    reset_states=(2,2,5,7,11,13,16,20,23,35,58,62)
    for line in lines[1:]:
        a=line.split();tag=a[0];check(not footer,'records after footer')
        if tag=='J':
            check(not active and case+1<len(plan),'command order');case+=1
            p,phase,bad,command=plan[case];current=selected[p]
            check(tuple(map(int,a[1:]))==(case,current['i'],phase,bad,command),'command identity/scenario')
            active=True;signature=bytearray();phase_seen=False
        elif tag=='S':
            check(active,'unowned signature');index=int(a[1]);value=int(a[2],16);amount,last=map(int,a[3:]);wanted=current['signature']
            check(index*8==len(signature) and 0<amount==min(8,len(wanted)-len(signature)),'signature order/length')
            check(value>>(8*amount)==0 and value.to_bytes(8,'little')[:amount]==wanted[len(signature):len(signature)+amount],'published signature bytes/padding')
            check(last==int(len(signature)+amount==len(wanted)),'signature last');signature+=value.to_bytes(8,'little')[:amount]
        elif tag=='P':
            check(active and phase>=0 and not phase_seen,'unexpected reset target')
            got_phase,state,committed=map(int,a[1:]);check(got_phase==phase and state==reset_states[phase] and 0<=committed<=256,'wrong reset phase')
            if phase==1:check(32<=committed<256,'partial key load not reached')
            phase_seen=True
        elif tag=='A':
            check(active and phase>=0 and phase_seen and a==['A',str(len(signature))],'reset record')
            check((phase==11 and len(signature)>=(32,48,64)[p]) or (phase!=11 and not signature),'reset prefix length')
            prefix+=len(signature);counts[0]+=1;active=False
        elif tag=='D':
            check(active and phase<0,'unexpected completion')
            code=1 if command>=0 else 3 if 0<=bad<4 else 4 if bad>=4 else 0
            stage=1 if code==3 else 2 if code==4 else 0
            detail=(2 if bad==2 else 3) if code==3 else 2 if code==4 else 0
            check(tuple(map(int,a[1:]))==(code,stage,detail,len(signature)),'completion code/stage/detail/length')
            if code:check(not signature,'error emitted signature');counts[1]+=1
            else:check(signature==current['signature'],'incomplete published recovery');counts[2]+=1;total+=len(signature)
            active=False
        elif tag=='F':
            check(not active and case==68 and tuple(map(int,a[1:]))==(69,12,24,33) and counts==[12,24,33],'incomplete campaign');footer=True
        else:raise ValueError('Unknown compact Sign protocol record')
    check(footer,'missing footer')
    if not quiet:print(f'LIGHTHD_SIGN_PROTOCOL_COMPARE_PASS:69 commands/24 errors/12 targeted resets/33 published recoveries/{total} full bytes/{prefix} reset-prefix bytes;token '+token)


def lighthd_sign_selftest():
    """Corrupt captured results, prove the actual independent checkers reject."""
    original=(HERE/'sign_outputs.txt').read_text()
    protocol=(HERE/'sign_protocol_outputs.txt').read_text()
    full_checker=lambda text:lighthd_sign_compare(captured=text,quiet=True)
    protocol_checker=lambda text:lighthd_sign_protocol_compare(captured=text,quiet=True)
    full_checker(original);protocol_checker(protocol);faults=[]
    for text,checker in ((original,full_checker),(protocol,protocol_checker)):
        rows=text.splitlines()
        faults.extend(((checker,'0'*64+' '+rows[0].split()[1]+'\n'+'\n'.join(rows[1:])+'\n'),
                       (checker,'\n'.join(rows[:-1])+'\n'),(checker,text+rows[-1]+'\n')))
        tags={'J':(1,2),'S':(1,2,3,4),'D':tuple(range(1,len(next(row.split() for row in rows if row.startswith('D ')))))}
        if checker is full_checker:tags.update({'C':(1,2,3,4),'R':(1,2,3)})
        else:tags.update({'P':(1,2,3),'A':(1,)})
        for tag,fields in tags.items():
            index=next(i for i,row in enumerate(rows) if row.startswith(tag+' '))
            for field in fields:
                changed=rows.copy();parts=changed[index].split()
                base=16 if (tag=='S' and field==2) or (tag=='C' and field==4) else 10
                value=int(parts[field],base)^1
                if checker is full_checker and tag=='D' and field==7:value=0
                if checker is full_checker and tag=='R' and field==3:value=999
                parts[field]=format(value,'x') if base==16 else str(value)
                changed[index]=' '.join(parts);faults.append((checker,'\n'.join(changed)+'\n'))
            dropped=rows[:index]+rows[index+1:];faults.append((checker,'\n'.join(dropped)+'\n'))
            repeated=rows[:index]+[rows[index]]+rows[index:];faults.append((checker,'\n'.join(repeated)+'\n'))
        # Unused high bytes on the short final word must be zero.
        index=next(i for i,row in enumerate(rows) if row.startswith('S ') and int(row.split()[3])<8)
        changed=rows.copy();parts=changed[index].split();parts[2]=format(int(parts[2],16)|(1<<(8*int(parts[3]))),'x')
        changed[index]=' '.join(parts);faults.append((checker,'\n'.join(changed)+'\n'))
    for index,(checker,text) in enumerate(faults):
        try:checker(text)
        except (ValueError,OverflowError,IndexError):continue
        raise ValueError(f'Compact Sign comparator accepted deliberate fault{index}')
    print(f'LIGHTHD_SIGN_CHECKER_SELFTEST_PASS:{len(faults)}/{len(faults)} deliberate corruptions rejected')


def lighthd_hint_math(p,data):
    """Literal FIPS suffix rules; this is not a complete signature verdict."""
    if p==3:return 1,[]
    k=(4,6,8)[p];omega=(80,55,75)[p];start=0;polynomials=[]
    if len(data)!=omega+k:return 3,[]
    for end in data[omega:]:
        if not start<=end<=omega:return 2,[]
        indices=list(data[start:end])
        if indices!=sorted(set(indices)):return 2,[]
        polynomials.append(set(indices));start=end
    if any(data[start:omega]):return 2,[]
    return 0,[sum((1<<lane) for lane in range(4) if 4*word+lane in poly) for poly in polynomials for word in range(64)]


def lighthd_hint_cases():
    rows=[]
    def add(p,data,origin,fault=0,abort=-1,job=None):
        i=len(rows);rows.append(dict(i=i,p=p,data=bytes(data),origin=origin,fault=fault,abort=abort,id=9000+i if job is None else job))
    for c in nist_verify_corpus()[0]:
        length=(84,61,83)[c['p']];add(c['p'],c['sig'][-length:],'NIST_signature_suffix')
    for p in range(3):
        k=(4,6,8)[p];omega=(80,55,75)[p]
        def encode(polys):
            indices=[];ends=[]
            for poly in polys:indices+=poly;ends.append(len(indices))
            return bytes(indices+[0]*(omega-len(indices))+ends)
        empty=encode([[] for _ in range(k)])
        dense=encode([list(range(omega))]+[[] for _ in range(k-1)])
        boundary=encode([[7,8,63,64,127,128,254,255] for _ in range(k)])
        last=encode([[] for _ in range(k-1)]+[[255]])
        for data in (empty,dense,boundary,last):add(p,data,'FIPS_derived')
        malformed=[]
        x=bytearray(empty);x[omega]=omega+1;malformed.append(x)
        x=bytearray(dense);x[omega+1]=omega-1;malformed.append(x)
        x=bytearray(dense);x[1]=x[0];malformed.append(x)
        x=bytearray(dense);x[0],x[1]=x[1],x[0];malformed.append(x)
        x=bytearray(empty);x[0]=1;malformed.append(x)
        for data in malformed:add(p,data,'noncanonical_suffix')
        for fault in range(1,6):add(p,boundary,'transport_fault',fault=fault)
        for phase in range(3):
            job=11000+p*10+phase
            add(p,dense,'reset',abort=phase,job=job);add(p,dense,'same_ID_recovery',job=job)
    add(3,bytes(84),'invalid_parameter')
    return rows


def lighthd_hint_artifacts():
    paths=[ROOT/'src/controller/process/hintunpkg.sv',ROOT/'tb/tb_dilithium/unit/tb_hintunpkg.sv',Path(__file__)]
    paths += [ROOT/n for n in ('src/controller/process/hint_codec.sv','src/controller/helpers/dilithium_pkg.sv',
        'tb/tb_dilithium/support/hint_compat.sv','tb/tb_dilithium/unit/tb_hint_shared.sv',
        'tb/tb_dilithium/reference/hintpkg_c13_reference.sv','tb/tb_dilithium/reference/hintunpkg_c13_reference.sv')]
    paths.append(ROOT/'tb/tb_dilithium/reference/hint_decode_stage_reference.sv')
    paths+=sorted(NIST_VERIFY.glob('*.json'));digest=hashlib.sha256()
    for path in paths:digest.update(path.relative_to(ROOT).as_posix().encode());digest.update(path.read_bytes())
    token=digest.hexdigest();rows=lighthd_hint_cases();inputs=[f'{token} {len(rows)}'];expected=[f'{token} {len(rows)}']
    for c in rows:
        code,masks=lighthd_hint_math(c['p'],c['data'])
        if c['fault']:code,masks=3,[]
        inputs.append(f"{c['i']} {c['p']} {c['id']} {c['fault']} {c['abort']} {len(c['data'])} {c['data'].hex()}")
        expected.append(f"J {c['i']} {code} {len(masks)}")
        expected.extend(f'H {index//64} {index%64} {mask:x}' for index,mask in enumerate(masks))
    return token,'\n'.join(inputs)+'\n','\n'.join(expected)+'\n',rows


def lighthd_hint_prepare():
    token,inputs,expected,rows=lighthd_hint_artifacts()
    (HERE/'hint_inputs.txt').write_text(inputs,encoding='ascii');(HERE/'hint_expected.txt').write_text(expected,encoding='ascii')
    print(f'LIGHTHD_HINT_PREPARE_PASS:{len(rows)} cases;45 suffixes extracted from pinned official signatures plus FIPS-derived boundaries/faults/resets;not standalone NIST vectors;token '+token)


def lighthd_hint_compare(captured=None,quiet=False):
    token,inputs,expected,rows=lighthd_hint_artifacts()
    if (HERE/'hint_inputs.txt').read_text()!=inputs or (HERE/'hint_expected.txt').read_text()!=expected:raise ValueError('Stale hint decoder fixtures')
    lines=((HERE/'hint_outputs.txt').read_text() if captured is None else captured).splitlines()
    if not lines or lines[0]!=f'{token} {len(rows)}':raise ValueError('Hint decoder token/count')
    current=None;seen=0;word=0;footer=False;total=0;resets=0
    for line in lines[1:]:
        a=line.split();tag=a[0]
        if footer:raise ValueError('Hint records after footer')
        if tag=='J':
            if current is not None or seen>=len(rows):raise ValueError('Hint command order')
            current=rows[seen];seen+=1;word=0;code,masks=lighthd_hint_math(current['p'],current['data'])
            if current['fault']:code,masks=3,[]
            if tuple(map(int,a[1:]))!=(current['i'],current['p'],current['id']):raise ValueError('Hint identity')
        elif tag=='H':
            if current is None or word>=len(masks) or tuple(map(int,a[1:3]))!=(word//64,word%64) or int(a[3],16)!=masks[word]:raise ValueError('Hint mask/order differs from literal FIPS rules')
            word+=1;total+=1
        elif tag=='D':
            if current is None or current['abort']>=0 or a!=['D',str(code)] or word!=len(masks):raise ValueError('Hint completion/canonicality')
            current=None
        elif tag=='A':
            if current is None or current['abort']<0 or a!=['A',str(current['abort'])]:raise ValueError('Unexpected hint reset')
            if (current['abort']<2 and word) or (current['abort']==2 and not 2<=word<len(masks)):raise ValueError('Hint reset prefix')
            current=None;resets+=1
        elif tag=='F':
            if current is not None or seen!=len(rows) or a!=['F',str(len(rows))] or resets!=9:raise ValueError('Incomplete hint campaign')
            footer=True
        else:raise ValueError('Unknown hint decoder record')
    if not footer:raise ValueError('Missing hint decoder footer')
    if not quiet:print(f'LIGHTHD_HINT_COMPARE_PASS:{len(rows)} cases/{total} exact x4 masks/9 resets;canonical suffix checks only,not full Verify verdicts;token '+token)


def lighthd_hint_selftest():
    text=(HERE/'hint_outputs.txt').read_text();lighthd_hint_compare(text,True);lines=text.splitlines();faults=[]
    for tag,fields in (('J',(1,2,3)),('H',(1,2,3)),('D',(1,)),('A',(1,))):
        index=next(i for i,line in enumerate(lines) if line.startswith(tag+' '))
        for field in fields:
            changed=lines.copy();parts=changed[index].split();base=16 if tag=='H' and field==3 else 10
            value=int(parts[field],base)^1;parts[field]=format(value,'x') if base==16 else str(value);changed[index]=' '.join(parts);faults.append('\n'.join(changed)+'\n')
        faults.extend(('\n'.join(lines[:index]+lines[index+1:])+'\n','\n'.join(lines[:index]+[lines[index]]+lines[index:])+'\n'))
    faults.extend(('\n'.join(lines[:-1])+'\n',text+lines[-1]+'\n'))
    for bad in faults:
        try:lighthd_hint_compare(bad,True)
        except (ValueError,IndexError):continue
        raise ValueError('Hint checker accepted a deliberate corruption')
    print(f'LIGHTHD_HINT_CHECKER_SELFTEST_PASS:{len(faults)}/{len(faults)} deliberate corruptions rejected')


def lighthd_verify_input_cases():
    official=nist_verify_corpus()[0];rows=[]
    def add(c,origin,fault=0,abort=-1,param=None,declared=None,job=None):
        i=len(rows);rows.append(dict(c,i=i,origin=origin,fault=fault,abort=abort,param=c['p'] if param is None else param,
            declared=len(c['sig']) if declared is None else declared,id=13000+i if job is None else job))
    for c in official:add(c,'NIST_raw_input')
    for p in range(3):
        c=next(c for c in official if c['p']==p and c['valid'])
        for fault in range(1,13):add(c,'transport_fault',fault=fault)
        add(c,'bad_parameter',param=3);add(c,'wrong_signature_length',declared=len(c['sig'])-1)
        for phase in range(3):
            job=14000+p*10+phase
            recovery=next(x for x in reversed(official) if x['p']==p and x['valid'] and x['sig']!=c['sig'])
            add(c,'reset',abort=phase,job=job);add(recovery,'same_ID_recovery_different_input',job=job)
    return rows


def lighthd_verify_input_gold(c):
    if c['param']==3:return 1,{}
    if c['declared']!=len(c['sig']):return 2,{}
    if c['fault']:return 3,{}
    _,t1,_,_=verify_unpack_math(0,c['p'],c['pk'])
    _,z,h,bad_norm=verify_unpack_math(1,c['p'],c['sig'])
    if bad_norm or h is None:return 2,{}
    words={}
    for bank,base,values in ((0,448,t1),(2,0,z),(1,64,h)):
        for index in range(0,len(values),4):words[bank,base+index//4]=sum(v<<(23*lane) for lane,v in enumerate(values[index:index+4]))
    return 0,words


def lighthd_verify_input_artifacts():
    paths=sorted((ROOT/'src/keccak').glob('*.sv'))+sorted((ROOT/'src/sampler').glob('*.sv'))+sorted((ROOT/'src/ntt').glob('*.sv'))
    paths+=sorted((ROOT/'src/controller').rglob('*.sv'))
    paths += [ROOT/p for p in ('src/controller/datapath/keccak_sampler.sv','src/controller/memory/poly_bram.sv',
        'src/controller/memory/memory_banks.sv', 'src/controller/memory/bank_request_pipe.sv','src/controller/process/power2round.sv','src/controller/process/cnb.sv',
        'src/controller/process/mhint.sv','tb/tb_dilithium/support/service_fixture.sv','tb/tb_dilithium/unit/tb_verify_input.sv')]
    paths.append(Path(__file__));paths+=sorted(NIST_VERIFY.glob('*.json'));digest=hashlib.sha256()
    for path in paths:digest.update(path.relative_to(ROOT).as_posix().encode());digest.update(path.read_bytes())
    token=digest.hexdigest();rows=lighthd_verify_input_cases();inputs=[f'{token} {len(rows)}'];expected=[f'{token} {len(rows)}']
    for c in rows:
        inputs.append(f"{c['i']} {c['param']} {c['id']} {c['fault']} {c['abort']} {c['declared']} {len(c['pk'])} {len(c['sig'])} {c['pk'].hex()} {c['sig'].hex()}")
        code,words=lighthd_verify_input_gold(c);expected.append(f"J {c['i']} {code} {len(words)}")
        expected.extend(f'M {bank} {address} {word:023x}' for (bank,address),word in sorted(words.items()))
    return token,'\n'.join(inputs)+'\n','\n'.join(expected)+'\n',rows


def lighthd_verify_input_prepare():
    token,inputs,expected,rows=lighthd_verify_input_artifacts()
    (HERE/'verify_input_inputs.txt').write_text(inputs,encoding='ascii');(HERE/'verify_input_expected.txt').write_text(expected,encoding='ascii')
    print(f'LIGHTHD_VERIFY_INPUT_PREPARE_PASS:{len(rows)} commands;45 pinned official PK/SIG inputs plus transport/reset tests;raw input qualification only;token '+token)


def lighthd_verify_input_compare(captured=None,quiet=False):
    token,inputs,expected,rows=lighthd_verify_input_artifacts()
    if (HERE/'verify_input_inputs.txt').read_text()!=inputs or (HERE/'verify_input_expected.txt').read_text()!=expected:raise ValueError('Stale compact Verify input fixtures')
    lines=((HERE/'verify_input_outputs.txt').read_text() if captured is None else captured).splitlines()
    if not lines or lines[0]!=f'{token} {len(rows)}':raise ValueError('Compact Verify input token/count')
    current=None;seen=0;actual={};header=False;footer=False;readbacks=resets=valid=invalid=errors=0
    for line in lines[1:]:
        a=line.split();tag=a[0]
        if footer:raise ValueError('Verify input records after footer')
        if tag=='J':
            if current is not None or seen>=len(rows):raise ValueError('Verify input command order')
            current=rows[seen];seen+=1;actual={};header=False;code,words=lighthd_verify_input_gold(current)
            if tuple(map(int,a[1:]))!=(current['i'],current['param'],current['id']):raise ValueError('Verify input identity')
        elif tag=='T':
            if current is None or code or current['abort']>=0 or header:raise ValueError('Unqualified Verify header')
            got=[int(v,16) for v in a[1:]];want=[int.from_bytes(current['pk'][:32],'little'),int.from_bytes(hashlib.shake_256(current['pk']).digest(64),'little'),int.from_bytes(current['sig'][:(32,48,64)[current['p']]],'little')]
            if got!=want:raise ValueError('Verify rho/tr/ctilde differs from independent input/hash')
            header=True
        elif tag=='M':
            if current is None or code or not header or current['abort']>=0:raise ValueError('Unqualified Verify raw bank read')
            key=tuple(map(int,a[1:3]));value=int(a[3],16)
            if key in actual or key not in words or value!=words[key]:raise ValueError('Verify raw t1/z/hint bank word differs from independent unpack')
            actual[key]=value;readbacks+=1
        elif tag=='D':
            if current is None or current['abort']>=0 or a!=['D',str(code)] or actual!=words or header!=(code==0):raise ValueError('Verify raw context completion')
            if code==0:valid+=1
            elif code==2:invalid+=1
            else:errors+=1
            current=None
        elif tag=='A':
            if current is None or current['abort']<0 or a!=['A',str(current['abort'])] or actual or header:raise ValueError('Verify input reset')
            resets+=1;current=None
        elif tag=='F':
            if current is not None or seen!=len(rows) or a!=['F',str(len(rows))] or resets!=9:raise ValueError('Incomplete Verify input campaign')
            footer=True
        else:raise ValueError('Unknown compact Verify input record')
    if not footer:raise ValueError('Missing compact Verify input footer')
    if not quiet:print(f'LIGHTHD_VERIFY_INPUT_COMPARE_PASS:{len(rows)} commands/{valid} qualified raw contexts/{invalid} signature-encoding invalids/{errors} expected errors/9 resets/{readbacks} exact bank words;not full Verify verdicts;token '+token)


def lighthd_verify_artifacts():
    token,_,_,_=lighthd_verify_input_artifacts()
    digest=hashlib.sha256(token.encode());digest.update((ROOT/'tb/tb_dilithium/unit/tb_verify.sv').read_bytes())
    digest.update((ROOT/'src/controller/process/sign_hash_message.sv').read_bytes());digest.update(REF.read_bytes());digest.update(NTT_REF.read_bytes())
    token=digest.hexdigest();rows=[]
    for i,c in enumerate(nist_verify_corpus()[0]):
        row=dict(c,i=i,id=65535 if i==0 else 0 if i==1 else 15000+i)
        _,_,h,bad_norm=verify_unpack_math(1,c['p'],c['sig']);row['structural_bad']=bad_norm or h is None
        material=None if row['structural_bad'] else verify_equation_material(c['p'],c['pk'],c['sig'],c['ctx'],c['msg'])
        if (False if material is None else material['accept'])!=c['valid']:raise ValueError('Independent Verify arithmetic differs from official verdict')
        row['material']=material;rows.append(row)
    selected=[next(c for c in rows if c['p']==p and c['valid']) for p in range(3)]
    def serialize(chosen):
        result=[f'{token} {len(chosen)}']
        for serial,c in enumerate(chosen):
            body=c['ctx']+c['msg'];result.append(f"{serial} {c['i']} {c['p']} {c['id']} {len(c['ctx'])} {len(c['msg'])} {len(c['pk'])} {len(c['sig'])} {len(body)} {c['pk'].hex()} {c['sig'].hex()} {body.hex() or '-'}")
        return '\n'.join(result)+'\n'
    return token,serialize(rows),serialize(selected),rows,selected


def lighthd_verify_prepare():
    token,inputs,small,_,_=lighthd_verify_artifacts()
    (HERE/'verify_inputs.txt').write_text(inputs,encoding='ascii');(HERE/'verify_diagnostic_inputs.txt').write_text(small,encoding='ascii')
    print('LIGHTHD_VERIFY_PREPARE_PASS:45 official pure/external inputs;independent arithmetic matches9 valid/36 invalid published verdicts;token '+token)


def lighthd_verify_compare(diagnostic=False,captured=None,quiet=False):
    token,inputs,small,rows,selected=lighthd_verify_artifacts()
    if (HERE/'verify_inputs.txt').read_text()!=inputs or (HERE/'verify_diagnostic_inputs.txt').read_text()!=small:raise ValueError('Stale compact Verify fixtures')
    if not diagnostic:selected=rows
    path=HERE/('verify_diagnostic_outputs.txt' if diagnostic else 'verify_outputs.txt')
    lines=(path.read_text() if captured is None else captured).splitlines()
    if not lines or lines[0]!=f'{token} {len(selected)}':raise ValueError('Compact Verify token/count')
    current=None;seen=0;digests=0;seen_digest=False;footer=False;valid=invalid=0
    for line in lines[1:]:
        a=line.split();tag=a[0]
        if footer:raise ValueError('Compact Verify records after footer')
        if tag=='J':
            if current is not None or seen>=len(selected):raise ValueError('Compact Verify command order')
            current=selected[seen]
            if tuple(map(int,a[1:]))!=(seen,current['i'],current['p'],current['id']):raise ValueError('Compact Verify command identity')
            seen+=1;seen_digest=False
        elif tag=='C':
            if current is None or current['material'] is None or seen_digest:raise ValueError('Unqualified/duplicate verification digest')
            wanted=int.from_bytes(current['material']['digest'],'little')
            if len(a)!=2 or int(a[1],16)!=wanted:raise ValueError('Verify equation digest differs from independent arithmetic')
            seen_digest=True;digests+=1
        elif tag=='D':
            if current is None:raise ValueError('Unowned Verify completion')
            code,stage,detail,accept,cycles=map(int,a[1:])
            if (code,stage,detail)!=(0,0,0) or accept!=int(current['valid']) or cycles<=0 or seen_digest!=(current['material'] is not None):raise ValueError('Verify verdict/digest gate differs from official result')
            valid+=accept;invalid+=1-accept;current=None
        elif tag=='F':
            if current is not None or seen!=len(selected) or a!=['F',str(len(selected))]:raise ValueError('Incomplete compact Verify campaign')
            footer=True
        else:raise ValueError('Unknown compact Verify record')
    if not footer:raise ValueError('Missing compact Verify footer')
    if not quiet:print(f'LIGHTHD_VERIFY_NIST_COMPARE_PASS:{len(selected)} published verdicts/{valid} valid/{invalid} invalid/{digests} exact independent equation digests;token '+token)


def lighthd_main_artifacts(operation='all'):
    if operation not in ('all','keygen','sign','verify'):raise ValueError('Unknown main operation')
    # Only prepare arithmetic/reference data for the requested operations.
    keys=nist_keygen_cases() if operation in ('all','keygen') else []
    signs=nist_sign_cases(True) if operation in ('all','sign') else []
    base=operation;verify_rows=[]
    if operation in ('all','verify'):
        for i,c in enumerate(nist_verify_corpus(True)[0]):
            row=dict(c,i=i)
            _,_,h,bad_norm=verify_unpack_math(1,c['p'],c['sig'])
            row['structural_bad']=bad_norm or h is None
            material=None if row['structural_bad'] else verify_equation_material(c['p'],c['pk'],c['sig'],c['ctx'],c['msg'],internal=c.get('internal',False))
            if (False if material is None else material['accept'])!=c['valid']:
                raise ValueError('Independent Verify arithmetic differs from expected verdict')
            row['material']=material;verify_rows.append(row)
    models=[lighthd_sign_model(i,True) for i in range(len(signs))];rows=[]
    # Preserve prompt order within each operation: all KeyGen, then Sign, then Verify.
    for op,collection in ((0,keys),(1,signs),(2,verify_rows)):
        for i,c in enumerate(collection):
            serial=len(rows)
            rows.append(dict(i=serial,op=op,original=c['i'],p=c['p'],id=0 if serial==0 else 65535 if serial==1 else 16000+serial,
                c=c,model=models[i] if op==1 else None))
    chosen=[]
    for op,collection in ((0,keys),(1,signs),(2,verify_rows)):
        if not collection:continue
        for p in range(3):
            for internal in ((False,) if op==0 else (False,True)):
                candidates=[c for c in rows if c['op']==op and c['p']==p and c['c'].get('internal',False)==internal]
                if not candidates:continue
                if op==1:chosen.append(min(candidates,key=lambda row:(row['model']['attempts'],len(row['c']['body']))))
                else:chosen.append(next(c for c in candidates if op==0 or c['c']['valid']))
    digest=hashlib.sha256((base+operation).encode());digest.update((ROOT/'tb/tb_dilithium/tb_main.sv').read_bytes())
    digest.update(Path(__file__).read_bytes());digest.update(REF.read_bytes());digest.update(NTT_REF.read_bytes())
    for source in sorted((ROOT/'src').rglob('*.sv')):
        digest.update(source.relative_to(ROOT).as_posix().encode());digest.update(source.read_bytes())
    digest.update((ROOT/'src/controller/dilithium_fpga.sv').read_bytes())
    for name in ('tb_process_ranges.sv','cnb_c15_reference.sv',
                 'mhint_c15_reference.sv','tb_process.sv','tb_process_dma.sv','process_c16_reference.sv',
                 'bitunpkg_c16_reference.sv','hint_decode_stage_reference.sv',
                 'tb_process_alu.sv','tb_bitunpkg_ring.sv','process_c17_reference.sv',
                 'verify_c17_reference.sv','tb_process_payload.sv','tb_verify_lifetime.sv',
                 'tb_sampler_writer.sv','tb_sampler_writer_mixed.sv','tb_sampler_writer_queue.sv',
                 'sign_input_c20_reference.sv','sign_c20_reference.sv',
                 'verify_input_c20_reference.sv','verify_c20_reference.sv',
                 'tb_controller_lifetimes.sv','bitunpkg_c21_reference.sv',
                 'tb_unpack_counter.sv','tb_operand_queue.sv',
                 'bitunpkg_c22_reference.sv','tb_decode_fields.sv',
                 'bitpkg_c22_reference.sv','tb_pack_fields.sv','tb_pack_stream.sv',
                 'tb_unpack_pipeline.sv','tb_bank_pipe.sv',
                 'hint_codec_c22_reference.sv','tb_hint_prefix.sv','tb_keccak_registered_launch.sv'):
        path=bench_path(name)
        digest.update(path.relative_to(ROOT).as_posix().encode());digest.update(path.read_bytes())
    for folder in (NIST_KEYGEN,NIST_SIGN,NIST_VERIFY):
        for path in sorted(folder.glob('*.json')):digest.update(path.read_bytes())
    token=digest.hexdigest()
    def serialize(selected):
        result=[f'{token} {len(selected)}']
        for serial,row in enumerate(selected):
            c=row['c'];op=row['op'];frames=[] if op==0 else [c['sk'],c['body']] if op==1 else [c['pk'],c['sig'],c['ctx']+c['msg']]
            context=0 if op==0 else c['ctxlen'] if op==1 else len(c['ctx']);message=0 if op==0 else c['mlen'] if op==1 else len(c['msg'])
            seed=c['xi'] if op==0 else bytes(32);rnd=c['rnd'] if op==1 else bytes(32)
            siglen=0 if op==0 else len(c['signature']) if op==1 else len(c['sig'])
            lengths=[len(x) for x in frames]+[0]*(3-len(frames));data=[x.hex() or '-' for x in frames]+['-']*(3-len(frames))
            result.append(' '.join(map(str,(serial,op,row['original'],row['p'],row['id'],context,message,siglen,len(frames),*lengths)))+
                f" {int.from_bytes(seed,'little'):064x} {int.from_bytes(rnd,'little'):064x} "+' '.join(data)+f" {('keygen','sign','verify')[op]}_L{(2,3,5)[row['p']]}_tg{c['tg']}_tc{c['tc']} {int(c.get('internal',False))}")
        return '\n'.join(result)+'\n'
    return token,serialize(rows),serialize(chosen),rows,chosen


def main_prepare_cache_key(operation,output_dir):
    # Current content hashes,not pinned provenance:edited vectors invalidate the cache.
    roots=[ROOT/'src',ROOT/'tb/tb_dilithium',REF.parent,NTT_REF.parent]
    paths={Path(__file__),ROOT/'quartus/dilithium/dilithium_full.qsf',REF,NTT_REF}
    for root in roots:
        paths.update(p for p in root.rglob('*') if p.is_file() and p.suffix in ('.sv','.svh','.vh','.c','.h','.py'))
    for folder in (NIST_KEYGEN,NIST_SIGN,NIST_VERIFY):paths.update(folder.glob('*.json'))
    digest=hashlib.sha256(('main_prepare_cache_v1|'+operation+'|'+str(output_dir.resolve())).encode())
    for path in sorted(paths):digest.update(str(path.resolve()).encode());digest.update(path.read_bytes())
    return digest.hexdigest()


def lighthd_main_prepare(operation='all',output_dir=None,cache_dir=None):
    output_dir=HERE if output_dir is None else Path(output_dir).resolve()
    output_dir.mkdir(parents=True,exist_ok=True)
    names=['main_inputs.txt','main_diagnostic_inputs.txt']
    if operation=='all':names.append('main_protocol_inputs.txt')
    cache=None if cache_dir is None else Path(cache_dir)/'main_prepare.stamp'
    fingerprint=main_prepare_cache_key(operation,output_dir) if cache else None
    if cache and cache.exists():
        lines=cache.read_text(encoding='ascii').splitlines()
        expected=[fingerprint]
        if all((output_dir/name).exists() for name in names):
            expected += [hashlib.sha256((output_dir/name).read_bytes()).hexdigest()+' '+name for name in names]
            if lines==expected:
                print(f'MAIN_PREPARE_CACHE_HIT:{operation};source,reference,NIST and prepared-file content unchanged')
                return
    token,inputs,small,rows,chosen=lighthd_main_artifacts(operation)
    (output_dir/names[0]).write_text(inputs,encoding='ascii');(output_dir/names[1]).write_text(small,encoding='ascii')
    if operation=='all':
        _,protocol,_=lighthd_main_protocol_artifacts()
        (output_dir/names[2]).write_text(protocol,encoding='ascii')
    if cache:
        cache.parent.mkdir(parents=True,exist_ok=True)
        cache.write_text(fingerprint+'\n'+'\n'.join(hashlib.sha256((output_dir/name).read_bytes()).hexdigest()+' '+name for name in names)+'\n',encoding='ascii')
    counts=[sum(c['op']==op for c in rows) for op in range(3)]
    print(f'MAIN_PREPARE_PASS:{operation};{len(rows)} commands={counts[0]} KeyGen+{counts[1]} Sign+{counts[2]} Verify;diagnostic{len(chosen)};token '+token)


def lighthd_main_protocol_artifacts():
    token,inputs,_,rows,chosen=lighthd_main_artifacts();lines=inputs.splitlines()[1:];selected=[]
    def base(op,p):
        candidates=[row for row in rows if row['op']==op and row['p']==p and not row['c'].get('internal',False)]
        if op==1:return min((row for row in candidates if row['c']['body']),key=lambda row:(row['model']['attempts'],len(row['c']['body'])))
        if op==2:return next(row for row in candidates if row['c']['valid'] and row['c']['ctx']+row['c']['msg'])
        return candidates[0]
    def add(c,scenario=0,abort=-1,job=None):
        serial=len(selected);selected.append(dict(c,scenario=scenario,abort=abort,busy=int(scenario==0 and abort<0),id=18000+serial if job is None else job))
    bad=[(1,0,p) for p in range(3)]+[(2,op,op) for op in range(3)]
    bad += [(3,op,p) for op in (1,2) for p in range(3)]+[(4,op,0) for op in (1,2)]+[(5,2,p) for p in range(3)]
    bad += [(scenario,op,p) for scenario,op in ((6,1),(7,1),(8,2),(9,2),(10,2)) for p in range(3)]
    for scenario,op,p in bad:
        job=18000+len(selected);add(base(op,p),scenario=scenario,job=job);add(base((op+1)%3,p),job=job)
    for phase in range(12):
        op=phase//4;p=phase%3;job=19000+phase
        add(base(op,p),abort=phase,job=job);add(base((op+1)%3,p),job=job)
    assert len(selected)==88
    encoded=[f'{token} {len(selected)}']
    for serial,c in enumerate(selected):
        a=lines[c['i']].split();a[0]=str(serial);a[4]=str(c['id'])
        encoded.append(' '.join(a)+f" {c['scenario']} {c['abort']} {c['busy']}")
    return token,'\n'.join(encoded)+'\n',selected


def lighthd_main_protocol_compare(captured=None,quiet=False):
    _,inputs,selected=lighthd_main_protocol_artifacts()
    if (HERE/'main_protocol_inputs.txt').read_text()!=inputs:raise ValueError('Stale compact main protocol fixtures')
    text=(HERE/'main_protocol_outputs.txt').read_text() if captured is None else captured
    return lighthd_main_compare(captured=text,quiet=quiet,protocol_rows=selected)


def lighthd_main_compare(diagnostic=False,captured=None,quiet=False,protocol_rows=None,operation='all',output_dir=None):
    directory=HERE if output_dir is None else Path(output_dir).resolve()
    token,inputs,small,rows,chosen=lighthd_main_artifacts(operation)
    if (directory/'main_inputs.txt').read_text()!=inputs or (directory/'main_diagnostic_inputs.txt').read_text()!=small:raise ValueError('Stale compact main fixtures')
    selected=protocol_rows if protocol_rows is not None else chosen if diagnostic else rows
    path=directory/('main_diagnostic_outputs.txt' if diagnostic else 'main_outputs.txt')
    lines=(path.read_text() if captured is None else captured).splitlines()
    if not lines or lines[0]!=f'{token} {len(selected)}':raise ValueError('Compact main token/count')
    current=None;seen=0;footer=False;counts=[0,0,0];byte_count=0;verdicts=[0,0];digests=0;resets=errors=encoding_invalid=0
    for line in lines[1:]:
        a=line.split();tag=a[0]
        if footer:raise ValueError('Main records after footer')
        if tag=='J':
            if current is not None or seen>=len(selected):raise ValueError('Main command order')
            current=selected[seen];c=current['c'];op=current['op'];model=current['model']
            scenario=current.get('scenario',0);abort=current.get('abort',-1)
            if tuple(map(int,a[1:]))!=(seen,op,current['original'],current['p'],current['id']):raise ValueError('Main command identity')
            seen+=1;keys=[bytearray(),bytearray()];signature=bytearray();attempts=0;rejected=set();seen_digest=False
        elif tag=='K':
            if current is None or op!=0:raise ValueError('Unowned main key word')
            kind,index,value,amount,last=int(a[1]),int(a[2]),int(a[3],16),int(a[4]),int(a[5])
            if kind not in (0,1):raise ValueError('Main key type')
            wanted=c['pk'] if kind==0 else c['sk'];have=keys[kind]
            if kind!=(0 if len(keys[0])<len(c['pk']) else 1) or index*8!=len(have) or not 0<amount==min(8,len(wanted)-len(have)):raise ValueError('Main key order/length')
            if value>>(8*amount) or value.to_bytes(8,'little')[:amount]!=wanted[len(have):len(have)+amount] or last!=int(len(have)+amount==len(wanted)):raise ValueError('Main key differs from published NIST bytes')
            have+=value.to_bytes(8,'little')[:amount];byte_count+=amount
        elif tag=='S':
            if current is None or op!=1:raise ValueError('Unowned main signature')
            index,value,amount,last=int(a[1]),int(a[2],16),int(a[3]),int(a[4]);wanted=c['signature']
            if index*8!=len(signature) or not 0<amount==min(8,len(wanted)-len(signature)) or value>>(8*amount) or value.to_bytes(8,'little')[:amount]!=wanted[len(signature):len(signature)+amount] or last!=int(len(signature)+amount==len(wanted)):raise ValueError('Main signature differs from published NIST bytes')
            signature+=value.to_bytes(8,'little')[:amount];byte_count+=amount
        elif tag=='A':
            if current is None or op!=1:raise ValueError('Unowned main Sign challenge')
            attempt,base,length=map(int,a[1:4]);value=int(a[4],16).to_bytes(64,'little')[:length]
            if attempt!=attempts+1 or attempt>model['attempts']:raise ValueError('Main signing attempt sequence')
            step=model['chain'][attempt-1]
            if base!=step['base'] or length!=len(step['digest']) or value!=step['digest']:raise ValueError('Main signing challenge differs from independent arithmetic')
            attempts+=1
        elif tag=='R':
            if current is None or op!=1:raise ValueError('Unowned main rejection')
            attempt,reason,index=map(int,a[1:])
            if attempt!=attempts or attempt in rejected or not 1<=attempt<model['attempts']:raise ValueError('Main rejection sequence')
            step=model['chain'][attempt-1]
            if reason not in step['violations'] or (reason<4 and (not 0<=index<len(step['norms'][reason-1]) or not step['norms'][reason-1][index])) or (reason==4 and sum(step['weights'][:index+1])<=(80,55,75)[current['p']]):raise ValueError('Main rejection lacks mathematical justification')
            rejected.add(attempt)
        elif tag=='C':
            if current is None or op!=2 or c['material'] is None or seen_digest or len(a)!=2 or int(a[1],16)!=int.from_bytes(c['material']['digest'],'little'):raise ValueError('Main Verify equation digest differs from independent arithmetic')
            seen_digest=True;digests+=1
        elif tag=='D':
            if current is None:raise ValueError('Unowned main completion')
            code,stage,detail,accept,reported_attempts,rejections,nonce,cycles=map(int,a[1:])
            if abort>=0:raise ValueError('Reset scenario completed instead of aborting')
            if scenario:
                expected=(2,0,0) if scenario==1 else (1,0,0) if scenario in (2,3,4) else (0,0,0) if scenario==5 else (4,2,2) if scenario in (7,10) else (3,1,3)
                if (code,stage,detail)!=expected or accept or (reported_attempts,rejections,nonce)!=(0,0,0) or any(keys) or signature or attempts or rejected or seen_digest or cycles<=0:
                    raise ValueError('Main protocol error/invalidity or premature crypto output')
                if code:errors+=1
                else:encoding_invalid+=1
                current=None;continue
            if (code,stage,detail)!=(0,0,0) or accept!=(int(c['valid']) if op==2 else 0) or cycles<=0:raise ValueError('Main completion/verdict')
            if op==0 and (keys!=[bytearray(c['pk']),bytearray(c['sk'])] or (reported_attempts,rejections,nonce)!=(0,0,0)):raise ValueError('Incomplete main keypair/foreign Sign counters')
            if op==1 and (signature!=c['signature'] or attempts!=model['attempts'] or rejected!=set(range(1,attempts)) or (reported_attempts,rejections,nonce)!=(attempts,attempts-1,model['next_nonce'])):raise ValueError('Incomplete main signature/retry counters')
            if op==2 and (seen_digest!=(c['material'] is not None) or (reported_attempts,rejections,nonce)!=(0,0,0)):raise ValueError('Main Verify digest/foreign Sign counters')
            if op==2:verdicts[0 if accept else 1]+=1
            counts[op]+=1;current=None
        elif tag=='X':
            if current is None or abort<0 or a!=['X',str(abort)] or seen_digest:raise ValueError('Unexpected main reset')
            if abort==3:
                if op!=0 or len(keys[0])<160 or len(keys[0])>=len(c['pk']) or keys[1]:raise ValueError('Main key-prefix reset target')
            elif abort==7:
                if op!=1 or not 80<=len(signature)<len(c['signature']):raise ValueError('Main signature-prefix reset target')
            elif any(keys) or signature:raise ValueError('Output before requested reset phase')
            resets+=1;current=None
        elif tag=='F':
            if current is not None or seen!=len(selected) or a!=['F',str(len(selected))]:raise ValueError('Incomplete main campaign')
            if protocol_rows is not None and (resets,errors,encoding_invalid,sum(counts))!=(12,29,3,44):raise ValueError('Incomplete main protocol classifications')
            footer=True
        else:raise ValueError('Unknown compact main record')
    if not footer:raise ValueError('Missing compact main footer')
    if not quiet:
        if protocol_rows is not None:print(f'LIGHTHD_MAIN_PROTOCOL_COMPARE_PASS:{seen} commands/29 errors/3 normal invalids/12 resets/44 published recoveries/{byte_count} checked key-signature prefix/full bytes;token '+token)
        else:print(f'LIGHTHD_MAIN_NIST_COMPARE_PASS:{seen} commands/{counts[0]} KeyGen/{counts[1]} Sign/{counts[2]} Verify/{byte_count} exact published key-signature bytes/{digests} independent Verify digests/{verdicts[0]} valid/{verdicts[1]} invalid;token '+token)


def lighthd_main_selftest():
    checkers=((lambda text:lighthd_main_compare(captured=text,quiet=True),HERE/'main_outputs.txt'),
              (lambda text:lighthd_main_protocol_compare(captured=text,quiet=True),HERE/'main_protocol_outputs.txt'))
    faults=[]
    for checker,path in checkers:
        text=path.read_text();checker(text);lines=text.splitlines()
        for tag,fields in (('J',(1,2,3,4,5)),('K',(1,2,3,4,5)),('S',(1,2,3,4)),('A',(1,2,3,4)),('R',(1,2,3)),('C',(1,)),('D',(1,2,3,4,5,6,7,8)),('X',(1,))):
            candidates=[i for i,line in enumerate(lines) if line.startswith(tag+' ')]
            if not candidates:continue
            index=candidates[0]
            for field in fields:
                changed=lines.copy();parts=changed[index].split();base=16 if (tag=='K' and field==3) or (tag=='S' and field==2) or (tag=='A' and field==4) or tag=='C' else 10
                value=int(parts[field],base)^1
                if tag=='D' and field==8:value=0
                if tag=='R' and field==3:value=999
                parts[field]=format(value,'x') if base==16 else str(value);changed[index]=' '.join(parts);faults.append((checker,'\n'.join(changed)+'\n'))
            faults.extend(((checker,'\n'.join(lines[:index]+lines[index+1:])+'\n'),(checker,'\n'.join(lines[:index]+[lines[index]]+lines[index:])+'\n')))
        faults.extend(((checker,'\n'.join(lines[:-1])+'\n'),(checker,text+lines[-1]+'\n')))
    for checker,text in faults:
        try:checker(text)
        except (ValueError,OverflowError,IndexError):continue
        raise ValueError('Compact main checker accepted a deliberate corruption')
    print(f'LIGHTHD_MAIN_CHECKER_SELFTEST_PASS:{len(faults)}/{len(faults)} deliberate corruptions rejected')


def lighthd_prepare():
    token, inputs, expected = lighthd_ntt_artifacts()
    (HERE / 'ntt_inputs.txt').write_text(inputs, encoding='ascii')
    (HERE / 'ntt_expected.txt').write_text(expected, encoding='ascii')
    print('LIGHTHD_NTT_PREPARE_PASS:160 cases/40960 coefficients;FIPS-derived '
          'Python arithmetic,not official NIST standalone NTT vectors;token ' + token)


def lighthd_check():
    token, inputs, expected = lighthd_ntt_artifacts()
    if ((HERE / 'ntt_inputs.txt').read_text() != inputs or
            (HERE / 'ntt_expected.txt').read_text() != expected):
        raise ValueError('Direct-bank NTT stale fixtures;run lighthd_prepare')
    print('LIGHTHD_NTT_FRESHNESS_PASS:' + token)


def lighthd_compare_text(captured):
    token, _, expected = lighthd_ntt_artifacts()
    got = captured.split()
    want = expected.split()
    if len(got) != len(want):
        raise ValueError(f'Direct-bank NTT capture length {len(got)} != {len(want)}')
    for index, (actual, reference_value) in enumerate(zip(got, want)):
        if actual != reference_value:
            raise ValueError(f'Direct-bank NTT mismatch token/index {index}: '
                             f'{actual} != {reference_value}')
    return token


def lighthd_compare():
    lighthd_check()
    token = lighthd_compare_text((HERE / 'ntt_outputs.txt').read_text())
    print('LIGHTHD_NTT_COMPARE_PASS:160 cases/40960 coefficients;token ' + token)


def lighthd_dma_compare():
    lighthd_check()
    token = lighthd_compare_text((HERE / 'ntt_dma_outputs.txt').read_text())
    print('LIGHTHD_NTT_DMA_COMPARE_PASS:160 real-RAM operations/40960 coefficients;token ' + token)


def lighthd_selftest():
    _, _, expected = lighthd_ntt_artifacts()
    parts = expected.split()
    mutations = []
    for index in [0, 1, 2, 3, 259, len(parts) - 1]:
        changed = parts.copy()
        changed[index] = 'invalid' if index < 3 else f'{(int(changed[index],16)+1)%8380417:06x}'
        mutations.append(' '.join(changed))
    mutations += [' '.join(parts[:-1]), ' '.join(parts + ['000000'])]
    for mutation in mutations:
        try:
            lighthd_compare_text(mutation)
        except ValueError:
            continue
        raise AssertionError('Direct-bank NTT checker accepted corruption')
    print(f'LIGHTHD_NTT_CHECKER_SELFTEST_PASS:{len(mutations)} corruptions rejected')


def lighthd_counter_selftest():
    """Finite window-qualified counter/error model;RTL semantic tests are separate."""
    from itertools import product
    s=(ROOT/'src/controller/process/bitunpkg.sv').read_text()
    assert 'count_consume=!rst && state==FEED && enough && window_valid_r && output_ready_i;' in s
    assert 'count_r[7]^count_r[6],~count_r[6],count_r[5:0]' in s
    assert 'if(window_valid_r && enough && bad_value)begin done_code_o<=2;state<=REPORT;count_r<=0;end' in s
    nchecks=0
    for n,g,window,bad,ready,push,frame in product(range(256),(16,24,40,48,52,64,72,80),*[range(2)]*5):
        enough=n>=g
        pop=enough and window and not bad and ready
        consume=enough and window and ready
        expected=(n-(g if pop else 0)+(64 if push and not frame else 0))&255
        base=(n-g)&255 if consume else n
        got=((base&63)|((((base>>6)^1)&1)<<6)|((((base>>7)^(base>>6))&1)<<7)) if push and not frame else base
        if (push and frame) or (window and enough and bad):expected=got=0
        assert expected==got,(n,g,window,bad,ready,push,frame)
        nchecks+=1
    print(f'LIGHTHD_COUNTER_PRIORITY_MODEL_PASS:{nchecks} count/group/window/control combinations;actual RTL semantic proof is separate,not NIST or coverage credit')


def lighthd_owner_selftest():
    """Compare registered-owner equations with an independent next-state model.

    Actual RTL equivalence is also asserted on every native simulation clock;
    this finite model check includes illegal enum states and fault quarantine.
    """
    from itertools import product
    source=ROOT/'src/controller/dilithium.sv';s=source.read_text();count=0
    assert 'state==RETIRE && !(child_ready && response.idle)' in s
    assert 'if(fault_o || (state==EXECUTE && child_done && child_id!=id_r))owner_select_next=0;' in s
    assert 'Registered main owner differs from original state decode' in s
    for state,op,start,fire,badop,badcmd,done,take,ready,idle,fault,wrong in product(range(8),range(4),range(4),*[range(2)]*9):
        nextstate=state;nextop=op
        if state==0:
            if fire:nextop=start;nextstate=3 if badop or badcmd else 1
        elif state==1:
            if done and take:nextstate=2
        elif state==2:
            if ready and idle:nextstate=0
        elif state==3:
            if take:nextstate=0
        else:nextstate=4
        if fault or (state==1 and done and wrong):nextstate=4
        original=(1<<nextop) if nextstate in (1,2) and nextop<3 else 0
        candidate=0
        if state==0 and fire and not badop and not badcmd:candidate=(1<<start) if start<3 else 0
        elif state==1 or (state==2 and not (ready and idle)):candidate=(1<<op) if op<3 else 0
        if fault or (state==1 and done and wrong):candidate=0
        assert original==candidate,(state,op,start,fire,badop,badcmd,done,take,ready,idle,fault,wrong)
        count+=1
    print(f'LIGHTHD_OWNER_MODEL_PASS:{count} combinations;RTL assertions checked separately;source '+hashlib.sha256(source.read_bytes()).hexdigest())


if __name__ == '__main__':
    # Stable public commands; historical spellings remain accepted for saved runners.
    command_aliases={'main_prepare': 'lighthd_main_prepare', 'main_compare': 'lighthd_main_compare', 'main_diagnostic_compare': 'lighthd_main_diagnostic_compare', 'main_protocol_compare': 'lighthd_main_protocol_compare', 'main_selftest': 'lighthd_main_selftest', 'keygen_prepare': 'lighthd_keygen_prepare', 'keygen_compare': 'lighthd_keygen_compare', 'keygen_protocol_compare': 'lighthd_keygen_protocol_compare', 'keygen_selftest': 'lighthd_keygen_selftest', 'sign_prepare': 'lighthd_sign_prepare', 'sign_compare': 'lighthd_sign_compare', 'sign_diagnostic_compare': 'lighthd_sign_diagnostic_compare', 'sign_protocol_compare': 'lighthd_sign_protocol_compare', 'sign_selftest': 'lighthd_sign_selftest', 'verify_prepare': 'lighthd_verify_prepare', 'verify_compare': 'lighthd_verify_compare', 'verify_diagnostic_compare': 'lighthd_verify_diagnostic_compare'}
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('command',choices=list(command_aliases)+['prepare','check','compare','selftest','uvm_prepare','uvm_check',
        'lighthd_prepare','lighthd_check','lighthd_compare','lighthd_dma_compare','lighthd_selftest','lighthd_owner_selftest','lighthd_counter_selftest',
        'lighthd_sampler_prepare','lighthd_sampler_check','lighthd_sampler_compare','lighthd_writer_compare',
        'lighthd_writer_mixed_prepare','lighthd_writer_mixed_compare',
        'lighthd_chain_prepare','lighthd_chain_compare','lighthd_keygen_prepare','lighthd_keygen_compare','lighthd_keygen_protocol_compare','lighthd_keygen_selftest',
        'lighthd_sign_load_prepare','lighthd_sign_load_compare','lighthd_sign_prepare','lighthd_sign_compare','lighthd_sign_diagnostic_compare',
        'lighthd_sign_protocol_compare','lighthd_sign_selftest','lighthd_hint_prepare','lighthd_hint_compare','lighthd_hint_selftest',
        'lighthd_verify_input_prepare','lighthd_verify_input_compare','lighthd_verify_prepare','lighthd_verify_compare','lighthd_verify_diagnostic_compare',
        'lighthd_main_prepare','lighthd_main_compare','lighthd_main_diagnostic_compare','lighthd_main_protocol_compare','lighthd_main_selftest'])
    p.add_argument('--operation',choices=['all','keygen','sign','verify'],default='all',help='Select main capture operations')
    p.add_argument('--output-dir',type=Path,help='Main-capture input/output directory;default sim/dilithium')
    p.add_argument('--cache-dir',type=Path,help='Cache unchanged main preparation using content hashes')
    p.add_argument('--stage',type=int,choices=[2,3,4,5],default=4)
    p.add_argument('--unit',choices=['process','hash_format','shared_hash','bank_memory','bank_store','bank_ntt','bank_process','row','seed_row','keygen','rounded_keygen','bitpkg','full_keygen','nist_keygen','sign_process','sign_dma','sign_service','sign_prepare','sign_decode','sign_hash','sign_load','sign_load_service','sign_mask','sign_matrix','sign_challenge','sign_transform','sign_products','sign_accept','sign_retry','sign_encode','full_sign','nist_sign','verify_decode','verify_prepare','verify_math','verify_equation','full_verify','nist_verify'],default='process',
                   help='Select a Stage5 gate; nist_keygen compares all75 official NIST cases')
    try:
        args=p.parse_args();command=command_aliases.get(args.command,args.command)
        if command=='check':
            check();print('STAGE2 VECTOR FRESHNESS PASS')
        elif command=='prepare':prepare()
        elif command=='uvm_prepare':uvm_prepare()
        elif command=='uvm_check':uvm_check()
        elif command.startswith('lighthd_'):
            {'lighthd_prepare':lighthd_prepare,'lighthd_check':lighthd_check,'lighthd_owner_selftest':lighthd_owner_selftest,'lighthd_counter_selftest':lighthd_counter_selftest,
             'lighthd_compare':lighthd_compare,'lighthd_dma_compare':lighthd_dma_compare,'lighthd_selftest':lighthd_selftest,
             'lighthd_sampler_prepare':lighthd_sampler_prepare,'lighthd_sampler_check':lighthd_sampler_check,
             'lighthd_sampler_compare':lighthd_sampler_compare,'lighthd_writer_compare':lighthd_writer_compare,
             'lighthd_writer_mixed_prepare':lighthd_writer_mixed_prepare,'lighthd_writer_mixed_compare':lighthd_writer_mixed_compare,
             'lighthd_chain_prepare':lighthd_chain_prepare,'lighthd_chain_compare':lighthd_chain_compare,
             'lighthd_keygen_prepare':lighthd_keygen_prepare,'lighthd_keygen_compare':lighthd_keygen_compare,
             'lighthd_keygen_protocol_compare':lambda:lighthd_keygen_compare(True),'lighthd_keygen_selftest':lighthd_keygen_selftest,
             'lighthd_sign_load_prepare':lighthd_sign_load_prepare,'lighthd_sign_load_compare':lighthd_sign_load_compare,
             'lighthd_sign_prepare':lighthd_sign_prepare,'lighthd_sign_compare':lighthd_sign_compare,
             'lighthd_sign_diagnostic_compare':lambda:lighthd_sign_compare(True),
             'lighthd_sign_protocol_compare':lighthd_sign_protocol_compare,'lighthd_sign_selftest':lighthd_sign_selftest,
             'lighthd_hint_prepare':lighthd_hint_prepare,'lighthd_hint_compare':lighthd_hint_compare,'lighthd_hint_selftest':lighthd_hint_selftest,
             'lighthd_verify_input_prepare':lighthd_verify_input_prepare,'lighthd_verify_input_compare':lighthd_verify_input_compare,
             'lighthd_verify_prepare':lighthd_verify_prepare,'lighthd_verify_compare':lighthd_verify_compare,
             'lighthd_verify_diagnostic_compare':lambda:lighthd_verify_compare(True),
             'lighthd_main_prepare':lambda:lighthd_main_prepare(args.operation,args.output_dir,args.cache_dir),'lighthd_main_compare':lambda:lighthd_main_compare(operation=args.operation,output_dir=args.output_dir),
             'lighthd_main_diagnostic_compare':lambda:lighthd_main_compare(True,operation=args.operation,output_dir=args.output_dir),
             'lighthd_main_protocol_compare':lighthd_main_protocol_compare,'lighthd_main_selftest':lighthd_main_selftest}[command]()
        else:{'compare':compare,'selftest':selftest}[command](args.stage,args.unit)
    except (ValueError,OSError,AssertionError,subprocess.SubprocessError) as e:
        raise SystemExit('DILITHIUM REFERENCE FAIL: '+str(e))
