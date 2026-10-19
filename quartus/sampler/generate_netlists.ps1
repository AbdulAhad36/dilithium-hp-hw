param([string]$QuartusBin = 'F:\altera\quartus\bin64')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    if (!(Test-Path 'output_files/sampler.fit.summary')) { throw 'Compile sampler.qpf first.' }
    # Freeze the accepted RTL/settings before touching either export database.
    $preflight = @'
from pathlib import Path
import hashlib,json,collections
r=Path('../..').resolve()
j=json.loads((r/'docs/sampler_docs/post_midyear/STAGE4_9R_RESULTS.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
files=sorted((r/'src/sampler').glob('*.sv'))+[Path('sampler.qpf').resolve(),Path('sampler.qsf').resolve(),Path('sampler.sdc').resolve()]
for p in files:
 key=p.relative_to(r).as_posix()
 if key.endswith('.qsf'):
  import zipfile
  with zipfile.ZipFile(r/'docs/sampler_docs/post_midyear/evidence/stage4_9r.zip') as z:old=z.read(key).decode()
  rows=lambda s:collections.Counter(x.strip() for x in s.splitlines() if x.strip() and not x.lstrip().startswith('#'))
  assert rows(p.read_text())==rows(old),'QSF assignments differ from accepted build'
 else:assert sha(p)==j['source_hashes'][key],f'Accepted source/settings differ: {key}'
fit=Path('output_files/sampler.fit.rpt').read_text(errors='replace')
assert '3,537 / 56,480' in fit,'Expected actual placed ALMs missing'
out=Path('netlist_provenance.json')
record={'baseline':'4.9r','status':'exporting; not verification PASS','source_hashes':{p.relative_to(r).as_posix():sha(p) for p in files},'accepted_checkpoint_sha256':sha(r/'docs/sampler_docs/post_midyear/STAGE4_9R_RESULTS.json')}
out.write_text(json.dumps(record,indent=2)+'\n')
print('Accepted RTL/settings identity verified; QSF assignment ordering normalized.')
'@
    python -c $preflight
    if ($LASTEXITCODE -ne 0) { throw 'Accepted-build preflight failed.' }
    & "$QuartusBin\quartus_eda.exe" sampler --simulation --functional=off --tool=questasim --format=verilog --output_directory=simulation_postfit --write_settings_files=off *> stage5_postfit_eda.log
    if ($LASTEXITCODE -ne 0) { throw 'Post-fit export failed; see stage5_postfit_eda.log.' }
    $synthDir = Join-Path $PSScriptRoot 'postsynth_build'
    New-Item -ItemType Directory -Path $synthDir -Force | Out-Null
    if (Test-Path (Join-Path $synthDir 'output_files/sampler.fit.summary')) { throw 'Synthesis-only helper contains a fitted database.' }
    $qsf = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'sampler.qsf'))
    [System.IO.File]::WriteAllText((Join-Path $synthDir 'sampler.qsf'), $qsf.Replace('../../src/', '../../../src/'))
    Copy-Item -LiteralPath 'sampler.qpf','sampler.sdc' -Destination $synthDir -Force
    Push-Location $synthDir
    try {
        & "$QuartusBin\quartus_map.exe" sampler *> ../stage5_postsynth_map.log
        if ($LASTEXITCODE -ne 0) { throw 'Synthesis failed; see stage5_postsynth_map.log.' }
        & "$QuartusBin\quartus_eda.exe" sampler --simulation --functional=on --tool=questasim --format=verilog --output_directory=../simulation_postsynth --write_settings_files=off *> ../stage5_postsynth_eda.log
        if ($LASTEXITCODE -ne 0) { throw 'Synthesis export failed; see stage5_postsynth_eda.log.' }
    } finally { Pop-Location }
    $recordExports = @'
from pathlib import Path
import hashlib,json,datetime
r=Path('../..').resolve();p=Path('netlist_provenance.json');j=json.loads(p.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert all(sha(r/n)==h for n,h in j['source_hashes'].items()),'Source/settings changed during export'
files=[Path('simulation_postsynth/sampler.vo'),Path('simulation_postfit/sampler.vo')]
assert all(p.is_file() and p.stat().st_size>1000 for p in files),'Missing netlist'
assert sha(files[0])!=sha(files[1]),'Synthesis and fit netlists must be distinct'
assert not Path('postsynth_build/output_files/sampler.fit.summary').exists(),'Synthesis helper must not be fitted'
j.update(status='exported; simulation pending',generated_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),netlist_hashes={p.resolve().relative_to(r).as_posix():sha(p) for p in files},export_method={'post_synthesis':'synthesis-only helper quartus_map then quartus_eda --functional=on','post_fit':'accepted fitted database quartus_eda --functional=off; Cyclone V functional-only export'})
p.write_text(json.dumps(j,indent=2)+'\n');print('DISTINCT SAMPLER NETLIST HASHES RECORDED')
'@
    python -c $recordExports
    if ($LASTEXITCODE -ne 0) { throw 'Export provenance validation failed.' }
    Write-Host 'SAMPLER NETLIST EXPORT COMPLETE: synthesis-only helper and active fitted database.'
} finally { Pop-Location }
