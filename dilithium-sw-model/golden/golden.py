#!/usr/bin/env python3
"""Run the local C golden model with explicit inputs and readable traces."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
MODEL = HERE.parent
REF = MODEL / 'ref'
REPO = MODEL.parent
BUILD = HERE / 'build'
LEVELS = {2: 'ML-DSA-44', 3: 'ML-DSA-65', 5: 'ML-DSA-87'}
SIZES = {2: (1312, 2560, 2420), 3: (1952, 4032, 3309), 5: (2592, 4896, 4627)}
SOURCES = ['packing.c', 'polyvec.c', 'poly.c', 'ntt.c', 'reduce.c',
           'rounding.c', 'fips202.c', 'symmetric-shake.c']
NIST_NAMES = {'keygen': 'ML-DSA-keyGen-FIPS204', 'sign': 'ML-DSA-sigGen-FIPS204',
              'verify': 'ML-DSA-sigVer-FIPS204'}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')


def traced_source():
    """Insert observation-only calls in a GENERATED copy, with exact anchor guards."""
    text = (REF / 'sign.c').read_text()

    def after(anchor, code, count=1):
        nonlocal text
        if text.count(anchor) != count:
            raise ValueError(f'Reference changed: trace anchor count for {anchor!r}')
        text = text.replace(anchor, anchor + '\n' + code)

    after('key = rhoprime + CRHBYTES;',
          '  trace_bytes("rho",rho,SEEDBYTES);\n  trace_bytes("rhoprime",rhoprime,CRHBYTES);\n  trace_bytes("key",key,SEEDBYTES);')
    after('polyvec_matrix_expand(mat, rho);', '  trace_matrix(mat);', 3)
    after('polyveck_uniform_eta(&s2, rhoprime, L);',
          '  trace_polys("s1",s1.vec,L);\n  trace_polys("s2",s2.vec,K);')
    after('polyvecl_ntt(&s1hat);', '  trace_polys("s1_hat",s1hat.vec,L);')
    anchor = 'polyveck_power2round(&t1, &t0, &t1);'
    after(anchor, '  trace_polys("t1",t1.vec,K);\n  trace_polys("t0",t0.vec,K);')
    text = text.replace(anchor, 'trace_polys("t",t1.vec,K);\n  ' + anchor)
    after('unpack_sk(rho, tr, key, &t0, &s1, &s2, sk);',
          '  trace_bytes("rho",rho,SEEDBYTES);\n  trace_polys("s1",s1.vec,L);\n  trace_polys("s2",s2.vec,K);\n  trace_polys("t0",t0.vec,K);')
    after('shake256_squeeze(mu, CRHBYTES, &state);', '  trace_bytes("mu",mu,CRHBYTES);', 2)
    after('shake256_squeeze(rhoprime, CRHBYTES, &state);', '  trace_bytes("rhoprime",rhoprime,CRHBYTES);')
    after('polyvecl_uniform_gamma1(&y, rhoprime, nonce++);',
          '  trace_attempt();\n  trace_polys("y",y.vec,L);')
    after('polyvecl_ntt(&z);', '  trace_polys("z_hat",z.vec,L);', 2)
    anchor = 'polyveck_decompose(&w1, &w0, &w1);'
    after(anchor, '  trace_polys("w1",w1.vec,K);\n  trace_polys("w0",w0.vec,K);')
    text = text.replace(anchor, 'trace_polys("w",w1.vec,K);\n  ' + anchor)
    after('poly_challenge(&cp, sig);',
          '  trace_bytes("c_tilde",sig,CTILDEBYTES);\n  trace_polys("c",&cp,1);')
    after('poly_challenge(&cp, c);', '  trace_polys("c",&cp,1);')
    for expr, reason in [('polyvecl_chknorm(&z, GAMMA1 - BETA)', 'z norm'),
                         ('polyveck_chknorm(&w0, GAMMA2 - BETA)', 'w0-cs2 norm'),
                         ('polyveck_chknorm(&h, GAMMA2)', 'ct0 norm'),
                         ('n > OMEGA', 'hint weight')]:
        old = f'if({expr})\n    goto rej;'
        if text.count(old) != 1:
            raise ValueError('Reference rejection anchor changed: ' + expr)
        text = text.replace(old, f'if({expr}) {{ trace_reject("{reason}"); goto rej; }}')
    after('pack_sig(sig, sig, &z, &h);',
          '  if(trace_file) fputs("ACCEPTED ATTEMPT\\n",trace_file);\n  trace_polys("z",z.vec,L);\n  trace_polys("hint",h.vec,K);')
    after('unpack_pk(rho, &t1, pk);',
          '  trace_bytes("rho",rho,SEEDBYTES);\n  trace_polys("t1",t1.vec,K);')
    after('polyveck_use_hint(&w1, &w1, &h);',
          '  trace_polys("hint",h.vec,K);\n  trace_polys("w1_recovered",w1.vec,K);')
    after('shake256_squeeze(c2, CTILDEBYTES, &state);',
          '  trace_bytes("c_tilde_received",c,CTILDEBYTES);\n  trace_bytes("c_tilde_recomputed",c2,CTILDEBYTES);')
    return text


def compiler():
    candidate = os.environ.get('CC', 'gcc')
    path = shutil.which(candidate)
    if not path:
        raise ValueError('gcc was not found. Put GCC on PATH, or set CC to its executable path.')
    return str(Path(path).resolve())


def build(level, trace):
    BUILD.mkdir(exist_ok=True)
    cc = compiler()
    version = subprocess.run([cc, '--version'], check=True, capture_output=True, text=True).stdout
    files = sorted(list(REF.glob('*.h')) + [REF / 'sign.c'] + [REF / x for x in SOURCES])
    files += [HERE / 'bridge.c', Path(__file__)]
    hashes = {str(p.relative_to(MODEL)): digest(p) for p in files}
    spec = {'compiler': cc, 'version': version, 'level': level, 'trace': trace, 'sources': hashes}
    stamp = hashlib.sha256(json.dumps(spec, sort_keys=True).encode()).hexdigest()
    suffix = '.exe' if os.name == 'nt' else ''
    exe = BUILD / f'golden_{level}{"_trace" if trace else ""}{suffix}'
    manifest = exe.with_suffix('.build.json')
    if exe.exists() and manifest.exists():
        saved = read_json(manifest)
        if saved.get('stamp') == stamp and saved.get('binary_sha256') == digest(exe):
            return exe, saved
    if trace:
        (BUILD / 'sign_trace.inc').write_text(traced_source(), encoding='utf-8')
    command = [cc, '-std=c99', '-O2', '-Wall', '-Wextra', f'-DDILITHIUM_MODE={level}',
               '-I', str(REF), '-I', str(BUILD)]
    if trace:
        command.append('-DGOLDEN_TRACE')
    command += [str(HERE / 'bridge.c')] + [str(REF / x) for x in SOURCES] + ['-o', str(exe)]
    run = subprocess.run(command, capture_output=True, text=True)
    if run.returncode:
        raise ValueError('C build failed:\n' + run.stdout + run.stderr)
    saved = dict(spec, stamp=stamp, binary_sha256=digest(exe), command=command,
                 generated_trace_sha256=digest(BUILD / 'sign_trace.inc') if trace else None)
    write_json(manifest, saved)
    print(f'Built level {level}' + (' with trace' if trace else ''))
    return exe, saved


def hex_bytes(value, name):
    if not isinstance(value, str):
        raise ValueError(f'{name} must be a hex string')
    try:
        return bytes.fromhex(value)
    except ValueError as e:
        raise ValueError(f'{name}: invalid hex') from e


def normalize(case):
    level = int(case['level'])
    if level not in LEVELS:
        raise ValueError('level must be 2, 3 or 5')
    op = case['operation'].lower()
    if op not in ('keygen', 'sign', 'verify', 'roundtrip'):
        raise ValueError('operation must be keygen, sign, verify or roundtrip')
    result = dict(case, level=level, operation=op)
    for key in ['seed', 'rnd', 'sk', 'pk', 'signature', 'message', 'context']:
        if key in result:
            result[key] = hex_bytes(result[key], key).hex()
    for key, length in [('seed', 32), ('rnd', 32), ('sk', SIZES[level][1]), ('pk', SIZES[level][0])]:
        if key in result and len(bytes.fromhex(result[key])) != length:
            raise ValueError(f'{key} must contain {length} bytes for level {level}')
    if len(bytes.fromhex(result.get('context', ''))) > 255:
        raise ValueError('context exceeds 255 bytes')
    if result.get('interface', 'external') not in ('external', 'internal'):
        raise ValueError('interface must be external or internal')
    if result.get('interface') == 'internal' and result.get('context'):
        raise ValueError('Internal message interface has no context; supply already formatted message')
    if op in ('keygen', 'roundtrip') and 'seed' not in result:
        raise ValueError('KeyGen requires an explicit 32-byte seed')
    if op in ('sign', 'roundtrip'):
        if 'rnd' not in result:
            raise ValueError('Signing requires rnd: use 32 zero bytes for deterministic signing')
        if op == 'sign' and 'sk' not in result:
            raise ValueError('Signing requires sk')
    if op == 'verify' and not all(k in result for k in ('pk', 'signature')):
        raise ValueError('Verify requires pk and signature')
    if op in ('sign', 'verify', 'roundtrip') and 'message' not in result:
        raise ValueError('Supply message explicitly; an empty string means an empty message')
    return result


def call_c(case, op, trace_path, manifest_cache):
    level = case['level']
    key = (level, trace_path is not None)
    if key not in manifest_cache:
        manifest_cache[key] = build(*key)
    exe, _ = manifest_cache[key]
    ctx = bytes.fromhex(case.get('context', ''))
    prefix = b'' if case.get('interface') == 'internal' else bytes([0, len(ctx)]) + ctx
    fields = [case.get(k, '') for k in ('seed', 'rnd', 'sk', 'pk', 'signature', 'message')]
    fields.append(prefix.hex())
    payload = '\n'.join(x or '-' for x in fields) + '\n'
    run = subprocess.run([str(exe), op, str(trace_path) if trace_path else '-'],
                         input=payload, capture_output=True, text=True, timeout=60)
    if run.returncode:
        raise ValueError(f'{op} C adapter failed ({run.returncode}): {run.stderr}')
    output = {}
    for line in run.stdout.splitlines():
        k, v = line.split(' = ', 1)
        output[k] = (v == 'true') if k == 'valid' else v
    return output


def differences(actual, expected):
    checks = []
    for field, wanted in expected.items():
        got = actual.get(field)
        if isinstance(wanted, bool):
            ok = type(got) is bool and got == wanted
            detail = f'actual={got}, expected={wanted}'
        else:
            a = hex_bytes(got, field) if got is not None else b''
            b = hex_bytes(wanted, field)
            ok = got is not None and a == b
            offset = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
            detail = f'{len(a)}/{len(b)} bytes'
            if not ok:
                av = f'{a[offset]:02x}' if offset < len(a) else 'EOF'
                bv = f'{b[offset]:02x}' if offset < len(b) else 'EOF'
                detail += f'; first mismatch byte {offset}: actual={av}, expected={bv}'
        checks.append({'field': field, 'pass': ok, 'detail': detail})
    return checks


def load_nist(args):
    cases, skipped, sources = [], [], {}
    operations = NIST_NAMES if args.operation == 'all' else [args.operation]
    for op in operations:
        folder = REPO / 'NIST' / NIST_NAMES[op]
        for name in ['prompt.json', 'expectedResults.json', 'provenance.json']:
            p = folder / name
            sources[str(p.relative_to(REPO))] = digest(p)
        # Record current file hashes, but allow locally edited vector files.
        prompt = read_json(folder / 'prompt.json')
        expected = read_json(folder / 'expectedResults.json')
        expected = {(g['tgId'], t['tcId']): t for g in expected['testGroups'] for t in g['tests']}
        level_counts = {}
        for group in prompt['testGroups']:
            level = next(k for k, v in LEVELS.items() if v == group['parameterSet'])
            if args.level != 'all' and level != int(args.level):
                continue
            for test in group['tests']:
                if args.tc_id is not None and test['tcId'] != args.tc_id:
                    continue
                identity = f'{op}_L{level}_tg{group["tgId"]}_tc{test["tcId"]}'
                reason = None
                if op != 'keygen':
                    if group['signatureInterface'] == 'external' and group['preHash'] != 'pure':
                        reason = 'HashML-DSA prehash mode is not implemented by this adapter'
                    elif group['signatureInterface'] == 'internal' and group.get('externalMu'):
                        reason = 'External-mu API is not exposed by the unchanged C reference'
                if reason:
                    skipped.append({'id': identity, 'reason': reason,
                                    'suite': NIST_NAMES[op], 'operation': op, 'level': level,
                                    'tgId': group['tgId'], 'tcId': test['tcId'],
                                    'mode': 'prehash' if group['signatureInterface'] == 'external' else 'external-mu'})
                    continue
                if args.limit is not None and level_counts.get(level, 0) >= args.limit:
                    continue
                level_counts[level] = level_counts.get(level, 0) + 1
                answer = expected[(group['tgId'], test['tcId'])]
                c = dict(test, id=identity, level=level, operation=op,
                         interface=group.get('signatureInterface', 'external'),
                         origin={'suite': NIST_NAMES[op], 'tgId': group['tgId'], 'tcId': test['tcId']})
                if op == 'keygen':
                    c['expected'] = {k: answer[k] for k in ('pk', 'sk')}
                elif op == 'sign':
                    c['rnd'] = '00' * 32 if group['deterministic'] else test['rnd']
                    c['expected'] = {'signature': answer['signature']}
                else:
                    c['expected'] = {'valid': answer['testPassed']}
                cases.append(normalize(c))
    if not cases:
        raise ValueError('No supported cases selected. ' + '; '.join(x['reason'] for x in skipped[:1]))
    return cases, skipped, sources


def skipped_group_summary(skipped):
    groups = {}
    for item in skipped or []:
        key = (item['operation'], item['level'], item['tgId'], item['mode'])
        groups[key] = groups.get(key, 0) + 1
    return [f"  {op.upper()} level={level} tgId={tgid}: {mode}; {count} cases skipped"
            for (op, level, tgid, mode), count in groups.items()]


def run_cases(cases, out, trace, skipped=None, sources=None, overwrite=False):
    out = out.resolve()
    if out.exists() and any(out.iterdir()) and not overwrite:
        raise ValueError(f'{out} already contains files. Choose another --out, or explicitly use --overwrite.')
    # Even --overwrite only replaces this runner's named files, never deletes a directory.
    out.mkdir(parents=True, exist_ok=True)
    if trace:
        (out / 'traces').mkdir(exist_ok=True)
    cache, results = {}, []
    for i, c in enumerate(cases):
        tag = f'{i+1:04d}_{c["operation"]}_L{c["level"]}'
        def step(op, current):
            p = out / 'traces' / f'{tag}_{op}.txt' if trace else None
            return call_c(current, op, p, cache)
        if c['operation'] == 'roundtrip':
            answer = step('keygen', c)
            current = dict(c, **answer)
            answer.update(step('sign', current))
            current.update(answer)
            answer.update(step('verify', current))
            checks = differences(answer, {'valid': True})
        else:
            answer = step(c['operation'], c)
            checks = []
        checks += differences(answer, c.get('expected', {}))
        results.append({'id': c['id'], 'level': c['level'], 'operation': c['operation'],
                        'outputs': answer, 'checks': checks})
    failures = sum(not x['pass'] for r in results for x in r['checks'])
    compared = sum(bool(r['checks']) for r in results)
    data = {'schema': 'dilithium-golden-v1', 'cases': results}
    write_json(out / 'inputs.json', {'cases': cases})
    write_json(out / 'outputs.json', data)
    write_json(out / 'expected.json', {'schema': 'dilithium-golden-v1', 'cases': [
        {'id': c['id'], 'level': c['level'], 'operation': c['operation'], 'outputs': c['expected']}
        for c in cases if c.get('expected')]})
    write_json(out / 'provenance.json', {'reference': 'Local dilithium-sw-model/ref; original C algorithms unchanged',
        'nist_sources': sources or {}, 'builds': [m for _, m in cache.values()],
        'skipped': skipped or [], 'trace': trace,
        'note': 'Comparison uses stored expected bytes/status; expected values are not generated by C.'})
    lines = [f'Cases executed: {len(results)}; cases with checks: {compared}; failed checks: {failures}',
             f'Skipped unsupported NIST cases: {len(skipped or [])}',
             'NIST expected bytes/status establish output agreement; intermediate traces are local C observations.', '']
    for r in results:
        lines.append(r['id'])
        lines.extend(f'  {"PASS" if x["pass"] else "FAIL"} {x["field"]}: {x["detail"]}' for x in r['checks'])
        if not r['checks']:
            lines.append('  GENERATED ONLY: no expected output supplied')
    summary = skipped_group_summary(skipped)
    lines += ['', 'Skipped groups:'] + summary
    lines += ['', 'Skipped cases:'] + [f'{x["id"]}: {x["reason"]}' for x in skipped or []]
    (out / 'comparison.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    (out / 'outputs_sw.txt').write_text(output_text(results), encoding='ascii')
    print(lines[0]); print(lines[1])
    if summary:
        print('Skipped groups:')
        print('\n'.join(summary))
    print('Files:', out)
    return 1 if failures else 0


def output_text(cases):
    lines = []
    for case in cases:
        lines.append(f'[{case["id"]}] level={case["level"]} operation={case["operation"]}')
        lines.extend(f'{k} = {str(v).lower() if isinstance(v, bool) else v}'
                     for k, v in case['outputs'].items())
        lines.append('')
    return '\n'.join(lines)


def read_outputs(path):
    if path.suffix.lower() != '.txt':
        return read_json(path)['cases']
    cases, current = [], None
    for line in path.read_text(encoding='ascii').splitlines():
        if not line.strip():
            continue
        header = re.fullmatch(r'\[(.+)\] level=(2|3|5) operation=(keygen|sign|verify|roundtrip)', line)
        if header:
            current = dict(id=header[1], level=int(header[2]), operation=header[3], outputs={})
            cases.append(current)
        else:
            if current is None or ' = ' not in line:
                raise ValueError('Malformed output line: ' + line[:80])
            field, value = line.split(' = ', 1)
            if field not in ('pk', 'sk', 'signature', 'valid') or field in current['outputs']:
                raise ValueError('Unknown/duplicate output field: ' + field)
            if field == 'valid':
                if value not in ('true', 'false'):
                    raise ValueError('Verify status must be true or false')
                value = value == 'true'
            else:
                value = hex_bytes(value, field).hex()
            current['outputs'][field] = value
    if not cases or any(not c['outputs'] for c in cases):
        raise ValueError('Empty output file or case')
    return cases


def compare(actual_path, expected_path, report):
    actual, expected = read_outputs(actual_path), read_outputs(expected_path)
    def index(rows):
        result = {}
        for c in rows:
            key = (c['id'], c['level'], c['operation'])
            if key in result:
                raise ValueError('Duplicate comparison case: ' + repr(key))
            result[key] = c
        return result
    a, b = index(actual), index(expected)
    failures, lines = 0, []
    if not b:
        raise ValueError('Expected file contains no cases')
    for key, c in b.items():
        if key not in a:
            lines.append(f'FAIL missing case {key}'); failures += 1; continue
        if not c['outputs']:
            raise ValueError('Expected case has no output fields: ' + repr(key))
        for x in differences(a[key]['outputs'], c['outputs']):
            failures += not x['pass']
            lines.append(f'{"PASS" if x["pass"] else "FAIL"} {key} {x["field"]}: {x["detail"]}')
    for key in a.keys() - b.keys():
        lines.append(f'FAIL unexpected case {key}'); failures += 1
    summary = f'Compared {len(b)} cases; failures: {failures}'
    report.write_text(summary + '\n' + '\n'.join(lines) + '\n', encoding='utf-8')
    print(summary); print('Report:', report.resolve())
    return 1 if failures else 0


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest='command', required=True)
    n = sub.add_parser('nist', help='Run stored official NIST inputs against stored expected results')
    n.add_argument('--operation', choices=['all', *NIST_NAMES], default='all')
    n.add_argument('--level', choices=['all', '2', '3', '5'], default='all')
    n.add_argument('--tc-id', type=int, help='Case ID within the chosen suite')
    n.add_argument('--limit', type=int, help='Maximum supported cases per operation and level')
    c = sub.add_parser('custom', help='Run your own JSON inputs')
    c.add_argument('--input', type=Path, required=True)
    for parser in (n, c):
        parser.add_argument('--out', type=Path, default=HERE / 'output')
        parser.add_argument('--trace', action='store_true', help='Write actual matrices and intermediates (can be large)')
        parser.add_argument('--overwrite', action='store_true', help='Replace named outputs in an existing output folder')
    cmp = sub.add_parser('compare', help='Compare outputs.json with expected.json or another outputs.json')
    cmp.add_argument('--actual', type=Path, required=True)
    cmp.add_argument('--expected', type=Path, required=True)
    cmp.add_argument('--report', type=Path, default=HERE / 'comparison.txt')
    args = p.parse_args()
    if args.command == 'compare':
        return compare(args.actual, args.expected, args.report)
    if args.command == 'nist':
        if args.limit is not None and args.limit < 1:
            raise ValueError('--limit must be positive')
        cases, skipped, sources = load_nist(args)
    else:
        data = read_json(args.input)
        cases = [normalize(c) for c in data['cases']]
        if not cases:
            raise ValueError('Input contains no cases')
        skipped, sources = [], {str(args.input.resolve()): digest(args.input)}
    ids = [(c['id'], c['level'], c['operation']) for c in cases]
    if len(set(ids)) != len(ids):
        raise ValueError('Duplicate input case identities')
    return run_cases(cases, args.out, args.trace, skipped, sources, args.overwrite)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        print(f'ERROR: {error}', file=sys.stderr)
        sys.exit(2)
