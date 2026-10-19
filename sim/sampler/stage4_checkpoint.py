"""Freeze fresh Stage4 measurements. Never overwrite a checkpoint or archive.

Run at repository root: python sim/sampler/stage4_checkpoint.py 4.7m
Source simulations, comparison, fault gates and full Quartus compile must run first.
"""
import collections
import csv
from datetime import datetime, timedelta, timezone
import hashlib
import io
import json
from pathlib import Path
import re
import sys
import zipfile

R = Path(__file__).resolve().parents[2]
D = R / 'docs/sampler_docs/post_midyear'
S = R / 'sim/sampler'
Q = R / 'quartus/sampler'


def text(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf8', errors='replace')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def coverage(prefix):
    current = ''; seen = set(); categories = {}
    for line in text(S / (prefix + '_code.rpt')).splitlines():
        match = re.match(r'=== Instance: (\S+)', line)
        if match: current = match[1]
        match = re.match(r'\s*(Statements|Branches|Conditions|Expressions|Toggles|States|Transitions)\s+(\d+)\s+(\d+)\s+(\d+)\s+', line)
        if match and re.match(r'/tb_top/dut(?:/|$)', current) and (current, match[1]) not in seen:
            seen.add((current, match[1]))
            item = categories.setdefault(match[1], {'hits': 0, 'bins': 0})
            item['hits'] += int(match[3]); item['bins'] += int(match[2])
    hits = sum(x['hits'] for x in categories.values()); bins = sum(x['bins'] for x in categories.values())
    match = re.search(r'Covergroup Bins\s+(\d+)\s+(\d+)\s+(\d+)', text(S / (prefix + '_functional.rpt')))
    return {'code': {'categories': categories, 'hits': hits, 'bins': bins, 'percent': 100 * hits / bins},
            'functional': {'hits': int(match[2]), 'bins': int(match[1]), 'percent': 100 * int(match[2]) / int(match[1])}}


def main():
    stage = sys.argv[1]
    assert re.fullmatch(r'4\.(?:7|8|9)[a-z]+', stage)
    area = stage.startswith('4.9')
    restored = '--restored-4.7s' in sys.argv[2:]
    native = stage.startswith('4.8') and not restored
    guard_failure = '--guard-failure' in sys.argv[2:]
    stem = stage.replace('.', '_')
    result_path = D / ('STAGE' + stem.upper() + '_RESULTS.json')
    archive_path = D / 'evidence' / ('stage' + stem + '.zip')
    hash_path = Path(str(archive_path) + '.sha256')
    assert not any(p.exists() for p in (result_path, archive_path, hash_path)), 'Refuse existing checkpoint'
    result = json.loads(text(D / 'STAGE4_7L_RESULTS.json'))
    baseline = json.loads(text(D / 'STAGE4_6R_RESULTS.json'))
    result.update(stage=stage, date=datetime.now(timezone(timedelta(hours=5))).date().isoformat(),
                  checkpoint_archive=archive_path.relative_to(R).as_posix())
    main_log = text(S / 'smoke.log')
    match = re.search(r'SAMPLER STAGE4 UVM PASS: (\d+) complete polynomials.*?(\d+) expected errors, (\d+) reset-aborted jobs, (\d+) checked coefficients', main_log)
    assert match and '** Fatal:' not in main_log
    result['source_regression'] = dict(zip(['complete_polynomials', 'expected_errors', 'reset_aborts', 'coefficient_checks'], map(int, match.groups())))
    prep = collections.Counter(re.findall(r'Observed input preparation phase([123]),core([01]) before reset', main_log))
    assert len(prep) == 6 and all(value == 3 for value in prep.values())
    assert '[PREP_RESET_PASS] 18 preparation resets reached' in main_log
    robustness = 'SAMPLER ROBUSTNESS UVM PASS:' in main_log
    if robustness:
        assert '54 rejection-burst jobs,128 metadata errors with same-ID recovery,24 long-backpressure jobs' in main_log
        format_boundaries = 'SAMPLER MASK FORMAT BOUNDARY PASS:6 complete jobs;' in main_log
        expected_jobs = 621 if format_boundaries else 615
        assert result['source_regression']['complete_polynomials'] == expected_jobs
        assert result['source_regression']['expected_errors'] == 182
        witness_rows = list(csv.DictReader((S / 'smoke_checked_robustness.csv').open()))
        assert len(witness_rows) == expected_jobs
        assert sum(14000 <= int(row['id']) < 14054 for row in witness_rows) == 54
        stall_rows = [row for row in witness_rows if 14182 <= int(row['id']) < 14206]
        assert len(stall_rows) == 24 and all(int(row['max_status_stall']) >= 1024 for row in stall_rows)
        burst_rows = {int(row['id']): row for row in witness_rows if 14000 <= int(row['id']) < 14054}
        for job_id, row in burst_rows.items():
            required = (17, 129, 513)[(job_id - 14000) % 3]
            assert int(row['max_rejection_run']) >= required, (job_id, row)
        result['robustness_tests'] = {'rejection_burst_jobs': 54, 'metadata_errors': 128,
                                      'same_id_recoveries': 128, 'long_backpressure_jobs': 24,
                                      'coverage_groups': 23, 'coverage_ceiling': None}
        result['robustness_tests']['mask_format_boundary_jobs'] = 6 if format_boundaries else 0
    result['preparation_reset_tests'] = {'witnesses': sum(prep.values()), 'phases': 3,
                                        'contexts': 2, 'modes': 3, 'same_id_recovery_checked': True}
    for prefix in ('smoke', 'vector', 'performance'):
        log = text(S / (prefix + '.log'))
        assert re.search(r'UVM_ERROR\s*:\s*0', log) and re.search(r'UVM_FATAL\s*:\s*0', log) and '** Fatal:' not in log
    assert 'SAMPLER VECTOR CAPTURE COMPLETE' in text(S / 'vector.log')
    assert 'SAMPLER PERFORMANCE UVM PASS' in text(S / 'performance.log')
    assert 'SAMPLER COMPARE PASS: 104/104 jobs, 19456/19456 coefficients' in text(S / 'compare.log')
    assert '12/12 corruptions rejected' in text(S / 'checker_selftest.log')
    fault_gates = []
    for kind in ('value', 'index', 'tag', 'last', 'status'):
        prefix = 'checker_negative' + ('' if kind == 'value' else '_' + kind)
        log = text(S / (prefix + '.log'))
        assert re.search(r'UVM_FATAL .*\[(?:COEFFICIENT|STATUS)\]', log)
        assert re.search(r'OVERALL FUNCTIONAL COVERAGE \(raw bins\): 0 / \d+', log)
        for suffix in ('checked_jobs', 'checked_outcomes', 'checked_activity', 'checked_protocol'):
            assert not list(csv.DictReader((S / (prefix + '_' + suffix + '.csv')).open()))
        if robustness:
            assert not list(csv.DictReader((S / (prefix + '_checked_robustness.csv')).open()))
        fault_bins = re.search(r'OVERALL FUNCTIONAL COVERAGE \(raw bins\): (\d+) / (\d+)', log)
        fault_gates.append({'kind': kind, 'hits': int(fault_bins[1]),
                            'bins': int(fault_bins[2]), 'witness_rows': 0,
                            'checked_witness_files': 5 if robustness else 4})
    result['coverage'] = {p: coverage(p) for p in ('smoke', 'vector', 'performance')}
    assert all(row['hits'] == 0 and row['bins'] == result['coverage']['smoke']['functional']['bins'] for row in fault_gates)
    result['coverage_fault_gates'] = fault_gates
    if stage == '4.9j':
        result['prior_checkpoint_corrections'] = {
            'STAGE4_9I_RESULTS.json': 'coverage_fault_gates[].bins inherited914;actual archived fault logs show0/1721. Immutable I archive is unchanged;source checks and main coverage remain valid.'}
    rows = list(csv.DictReader((S / 'performance.csv').open()))
    with zipfile.ZipFile(D / 'evidence/stage4_6r.zip') as archive:
        old = list(csv.DictReader(io.StringIO(archive.read('sim/sampler/performance.csv').decode())))
    assert len(rows) == len(old) == 96
    by_id = {row['id']: row for row in old}; deltas = []
    for row in rows:
        previous = by_id[row['id']]
        for key in ('id', 'scenario', 'mode', 'param', 'core', 'jobs', 'stalls', 'output_coefficients', 'generated_coefficients'):
            assert row[key] == previous[key], (row['id'], key)
        assert int(row['output_coefficients']) == 256
        deltas.append({'id': int(row['id']), 'mode': int(row['mode']), 'param': int(row['param']), 'jobs': int(row['jobs']), 'stalls': int(row['stalls']),
                       'latency_delta': int(row['latency_cycles']) - int(previous['latency_cycles']),
                       'input_to_first_delta': int(row['input_to_first_cycles']) - int(previous['input_to_first_cycles']),
                       'relative_cycle_deltas': {k: int(row[k]) - int(row['start_cycle']) - int(previous[k]) + int(previous['start_cycle']) for k in row if k.endswith('_cycle') and k != 'start_cycle'},
                       'all_changed_fields': {k: {'baseline': int(previous[k]), 'trial': int(row[k]), 'delta': int(row[k]) - int(previous[k])} for k in row if row[k] != previous[k]}})
    performance = result['performance']; performance['all96_row_deltas_vs_4_6r'] = deltas
    performance['byte_identical_to_baseline'] = rows == old
    for mode in range(4):
        for stalls in range(2):
            values = [int(x['latency_cycles']) for x in rows if int(x['mode']) == mode and int(x['stalls']) == stalls and x['jobs'] == '1']
            performance['single_latency_ranges'][f'mode{mode}_stalls{stalls}'] = {'min_cycles': min(values), 'max_cycles': max(values)}
    for pair in performance['pair_measurements']:
        subset = [x for x in rows if int(x['scenario']) == pair['scenario']]
        span = max(int(x['last_output_cycle']) for x in subset) - min(int(x['start_cycle']) for x in subset)
        pair.update(span_cycles=span, span_delta=span - pair['baseline_span'], mcoef_per_s_at_100mhz=512 / span * 100)
    summary = text(Q / 'output_files/sampler.sta.summary'); corners = {}
    for corner, kind, slack, tns in re.findall(r"Type\s*:\s*(.*?) Model (Setup|Hold|Minimum Pulse Width) 'clk'\s+Slack\s*:\s*([-\d.]+)\s+TNS\s*:\s*([-\d.]+)", summary):
        corners.setdefault(corner, {})[kind] = {'slack_ns': float(slack), 'tns_ns': float(tns)}
    assert len(corners) == 4
    sta = text(Q / 'output_files/sampler.sta.rpt')
    fmax = {str(t): float(re.search(r'; Slow 1100mV ' + str(t) + r'C Model Fmax Summary.*?;\s*([\d.]+) MHz', sta, re.S)[1]) for t in (85, 0)}
    result['timing'] = {'corners': corners, 'fmax_slow_mhz': fmax, 'worst_fmax_mhz': min(fmax.values()),
                        'worst_setup_ns': min(x['Setup']['slack_ns'] for x in corners.values()), 'worst_hold_ns': min(x['Hold']['slack_ns'] for x in corners.values())}
    fit = text(Q / 'output_files/sampler.fit.rpt')
    def resource(label):
        return int(re.search(r';\s*' + re.escape(label) + r'\s*;\s*([\d,]+)', fit)[1].replace(',', ''))
    labels = {'alms_needed': 'ALMs needed [=A-B+C]', 'alms_final_placement': '[A] ALMs used in final placement [=a+b+c+d]', 'registers': 'Dedicated logic registers', 'combinational_aluts': 'Combinational ALUT usage for logic', 'm10ks': 'M10K blocks', 'mlab_memory_bits': 'Total MLAB memory bits', 'logical_memory_bits': 'Total block memory bits', 'dsp': 'Total DSP Blocks'}
    result['resources'] = {k: resource(v) for k, v in labels.items()}
    result['fitted_register_breakdown'] = {'implementation': resource('-- Design implementation registers'), 'router': resource('-- Routing optimization registers')}
    compile_log = text(Q / 'compile.log'); assert 'Full Compilation was successful' in compile_log
    result['compile_finished'] = re.findall(r'Processing ended:\s*(.+)', compile_log)[-1]
    result['payload_register_guard'] = text(Q / 'critical_paths/secret_payload_registers.rpt')
    if guard_failure:
        assert re.search(r'Expected\s*64 mapped registers for packed_write_mask_r; found\s*31', text(Q / 'critical_paths.log'))
        assert 'packed_write_mask_r: 31 registers' in result['payload_register_guard']
        assert 'Retimed Register' in text(Q / 'output_files/sampler.fit.rpt')
    else:
        assert 'EXTRACTION/OUTPUT PIPELINE REGISTER GUARD PASS' in result['payload_register_guard']
        assert 'Evaluation of Tcl script report_paths.tcl was successful' in text(Q / 'critical_paths.log')
    result['physical_register_guard_passed'] = not guard_failure
    result['critical_path_summaries'] = {} if guard_failure else {p.name: [line.strip() for line in text(p).splitlines() if re.match(r';\s*-?\d+\.\d+\s*;', line)][:3] for p in (Q / 'critical_paths').glob('*setup.rpt')}
    sources = {name: sha(R / name) for name in result['source_hashes']}
    sources[Path(__file__).resolve().relative_to(R).as_posix()] = sha(Path(__file__))
    source_reuse = next((arg.split('=', 1)[1] for arg in sys.argv[2:] if arg.startswith('--source-reuse=')), None)
    if source_reuse:
        assert re.fullmatch(r'4\.[789][a-z]+', source_reuse)
        previous_check = json.loads(text(D / ('STAGE' + source_reuse.replace('.', '_').upper() + '_RESULTS.json')))
        checked_files = []
        for name, digest in previous_check['source_hashes'].items():
            if name.startswith(('src/', 'tb_uvm/')) or name in ('sim/sampler/run_uvm.do', 'FIPS204_SAMPLER/sampler_vectors.py'):
                assert sha(R / name) == digest, ('Reused source check identity mismatch', name)
                checked_files.append(name)
        assert result['source_regression'] == previous_check['source_regression']
        result['source_verification_reuse'] = {'checkpoint': source_reuse, 'reason': 'Only fitter settings change;RTL/UVM/models/launcher are byte-identical', 'identity_checked_files': checked_files}
    if robustness:
        name = 'tb_uvm/tb_uvm_sampler/sampler_stage4_9_classes.svh'
        sources[name] = sha(R / name)
    for name in baseline['source_hashes']:
        if name.endswith(('sampler_ref_pkg.sv', 'sampler_vectors.py', 'sampler_ref.c')): assert sources[name] == baseline['source_hashes'][name]
    if native:
        for name in ('tb_uvm/tb_uvm_sampler/sampler_stage4_8_classes.svh',
                     'sim/sampler/native128_compare.py'):
            sources[name] = sha(R / name)
    result['source_hashes'] = sources
    result['fitter_seed'] = int(re.search(r'set_global_assignment -name SEED (\d+)', text(Q / 'sampler.qsf'))[1])
    optimization_mode = re.search(r'set_global_assignment -name OPTIMIZATION_MODE "([^"]+)"', text(Q / 'sampler.qsf'))
    result['optimization_mode'] = optimization_mode[1] if optimization_mode else 'BALANCED (default)'
    retiming = re.search(r'set_global_assignment -name PHYSICAL_SYNTHESIS_REGISTER_RETIMING (ON|OFF)', text(Q / 'sampler.qsf'))
    result['physical_register_retiming'] = retiming[1] if retiming else 'Optimization-mode default'
    effective_retiming = re.search(r'Perform Register Retiming for Performance\s*;\s*(On|Off)', fit)
    result['effective_physical_register_retiming'] = effective_retiming[1] if effective_retiming else 'Not reported'
    if retiming and retiming[1] == 'OFF':
        assert effective_retiming and effective_retiming[1] == 'Off'
    evidence_names = set(result['evidence_hashes']) | {p.relative_to(R).as_posix() for p in (Q / 'critical_paths').glob('*.rpt')}
    if guard_failure:
        # The guard stopped before new family reports were generated. Never
        # archive the preceding candidate's path files as evidence of this fit.
        evidence_names = {name for name in evidence_names if '/critical_paths/' not in name or name.endswith('/secret_payload_registers.rpt')}
        evidence_names.add('quartus/sampler/output_files/sampler.map.rpt')
    if robustness:
        evidence_names |= {p.relative_to(R).as_posix() for p in S.glob('*_checked_robustness.csv')}
        evidence_names.add('sim/sampler/smoke_functional_misses.rpt')
    if stage == '4.9j':
        evidence_names.add('sim/sampler/stage4_9j_initial_quartus_syntax.log')
    if native or restored: evidence_names.add('sim/sampler/native128_comparison.json')
    result['evidence_hashes'] = {name: sha(R / name) for name in sorted(evidence_names)}
    target_pass = result['timing']['worst_setup_ns'] >= 0 and result['timing']['worst_hold_ns'] >= 0 and min(fmax.values()) >= 150
    frequency_goal = min(fmax.values()) >= 150
    result['frequency_goal_achieved'] = frequency_goal
    result['timing_target_closed'] = target_pass
    performance['rate_projection'] = {'clock_mhz': result['constraint_mhz'], 'timing_qualified': target_pass,
                                      'source_tb_clock_mhz': 100,
                                      'formula': 'Mcoeff/s=256*clock_MHz/latency_cycles;microseconds=cycles/clock_MHz'}
    performance['single_rates_at_constraint'] = {
        mode: {'mcoeff_per_s_min': 256 * result['constraint_mhz'] / values['max_cycles'],
               'mcoeff_per_s_max': 256 * result['constraint_mhz'] / values['min_cycles'],
               'latency_us_min': values['min_cycles'] / result['constraint_mhz'],
               'latency_us_max': values['max_cycles'] / result['constraint_mhz']}
        for mode, values in performance['single_latency_ranges'].items()}
    for pair in performance['pair_measurements']:
        pair['mcoeff_per_s_at_constraint'] = 512 * result['constraint_mhz'] / pair['span_cycles']
    result.update(selected_candidate=target_pass, selected_design=stage if target_pass else '4.6r',
                  status='Stage4 source PASS;153.85MHz timing ' + ('PASS' if target_pass else 'FAIL'),
                  decision='Frequency and constraint targets achieved;user acceptance pending' if target_pass else ('150+MHz Fmax achieved;6.5ns closure pending;stay Stage4' if frequency_goal else '150+MHz target unmet;continue Stage4'),
                  next='Stay Stage4;user acceptance pending' if target_pass else 'Cut fresh worst paths;preserve6.5ns target')
    if native:
        assert 'SAMPLER NATIVE128 UVM PASS:578 lower/upper count pairs;24 stage resets;' in main_log
        result['native128'] = {'implemented': True, 'max_input_bytes_per_token': 16,
                              'candidate_bounds': {'matrix': 6, 'secret': 32, 'mask': 8},
                              'collector_entries_per_context': 64,
                              'output_coefficients_per_cycle': 1,
                              'new_input_word_each_cycle': False,
                              'challenge': 'Sequential byte path unchanged',
                              'reset_stage_targets': 24, 'secret_count_pairs': 578}
        result['acceptance']['native128'] = 'Implemented trial;user acceptance pending'
        result['comparison_vs_4_7s'] = json.loads(text(S / 'native128_comparison.json'))
        result.update(selected_candidate=False, selected_design='4.7s',
                      decision='Native128 trial measured;not automatically selected;review timing and area against4.7s',
                      next='Redesign narrow collector/commit buffering and pipeline secret merge withinStage4')
    if restored:
        retained = json.loads(text(D / 'STAGE4_7S_RESULTS.json'))
        for name, digest in retained['source_hashes'].items():
            if name != 'sim/sampler/stage4_checkpoint.py':
                assert sha(R / name) == digest, ('Restore identity mismatch', name)
        result.update(selected_design='4.7s', selected_candidate=target_pass,
                      architecture='Exact4.7s RTL/UVM/build restored after rejected4.8a',
                      decision='Reject native4.8a;retain revalidated4.7s',
                      next='Native128 narrow-commit and pipelined-merge redesign withinStage4')
        result['acceptance']['native128'] = 'Rejected4.8a archived;active design uses64-bit chunks'
        result['rejected_native_trial'] = 'STAGE4_8A_RESULTS.json'
        sources['sim/sampler/native128_compare.py'] = sha(S / 'native128_compare.py')
        result['source_hashes'] = sources
    if area:
        benchmark_stage = next((arg.split('=', 1)[1] for arg in sys.argv[2:] if arg.startswith('--baseline=')), None)
        assert benchmark_stage, 'Area trials require an explicit retained --baseline checkpoint'
        assert re.fullmatch(r'4\.[789][a-z]+', benchmark_stage), 'Invalid baseline'
        benchmark_path = D / ('STAGE' + benchmark_stage.replace('.', '_').upper() + '_RESULTS.json')
        benchmark = json.loads(text(benchmark_path))
        assert benchmark['selected_candidate'], 'Area baseline must be a retained candidate,not a rejected trial'
        result['area_metric'] = 'alms_final_placement'
        result['target_fmax_mhz'] = benchmark['timing']['worst_fmax_mhz']
        with zipfile.ZipFile(R / benchmark['checkpoint_archive']) as archive:
            benchmark_csv = archive.read('sim/sampler/performance.csv')
            benchmark_rows = list(csv.DictReader(io.StringIO(benchmark_csv.decode())))
        previous = {row['id']: row for row in benchmark_rows}
        assert len(previous) == len(rows) == 96
        for row in rows:
            for key in ('mode', 'param', 'core', 'jobs', 'stalls', 'generated_coefficients', 'output_coefficients'):
                assert row[key] == previous[row['id']][key], (row['id'], key)
        latency_deltas = {row['id']: int(row['latency_cycles']) - int(previous[row['id']]['latency_cycles']) for row in rows}
        comparison = {
            'baseline': benchmark_stage, 'priority': 'Preserve or improve Fmax and throughput;reduce placed ALMs',
            'area_metric': 'alms_final_placement',
            'alms_delta': result['resources']['alms_final_placement'] - benchmark['resources']['alms_final_placement'],
            'alms_reduction_percent': 100 * (1 - result['resources']['alms_final_placement'] / benchmark['resources']['alms_final_placement']),
            'fmax_delta_mhz': result['timing']['worst_fmax_mhz'] - benchmark['timing']['worst_fmax_mhz'],
            'all96_latency_deltas': latency_deltas,
            'all96_csv_byte_identical': (S / 'performance.csv').read_bytes() == benchmark_csv,
            'area_improved': result['resources']['alms_final_placement'] < benchmark['resources']['alms_final_placement'],
            'fmax_preserved': result['timing']['worst_fmax_mhz'] >= benchmark['timing']['worst_fmax_mhz'],
            'cycles_preserved_or_improved': all(delta <= 0 for delta in latency_deltas.values())}
        retained = target_pass and all(comparison[key] for key in ('area_improved', 'fmax_preserved', 'cycles_preserved_or_improved'))
        result['comparison_vs_' + benchmark_stage.replace('.', '_')] = comparison
        result.update(baseline_checkpoint=benchmark_path.name,
                      selected_candidate=retained, selected_design=stage if retained else benchmark_stage,
                      decision='Retain lower-area candidate with preserved Fmax/cycles;user acceptance pending' if retained else 'Area trial fails priority gate;preserve' + benchmark_stage,
                      next='Stay Stage4;continue measured area/performance optimization')
        result['acceptance']['native128'] = 'Not active;rejected4.8a remains archived'
    result['limitations'] = ['Source verification only;no new functional netlist verification', 'Internal timing only;no board IO or security signoff', 'Defined functional bins finite;unwaived raw code misses remain']
    if guard_failure:
        assert area
        result.update(selected_candidate=False, selected_design=benchmark_stage,
                      status='Source PASS;timing PASS;original-register structural guard FAIL',
                      decision='Retiming changes mask register mapping;not selected without structural validation',
                      next='Repeat with physical register retiming disabled;keep all structural guards')
        result['limitations'].append('Original mask register guard fails after physical retiming;no retimed functional netlist validation')
    result['changes'] = [arg for arg in sys.argv[2:] if not arg.startswith('--')] or ['See archived source hashes and parent checkpoint for precise RTL differences']
    documents = ['README.md', 'AGENTS.md', '.codex/PLAN.md'] + [
        'docs/sampler_docs/post_midyear/' + name for name in
        ('SAMPLER_PLAN.md', 'SPECIFICATION.md', 'THROUGHPUT.md', 'COVERAGE.md', 'SAMPLER_VIRTUAL_PIN_CONFIG.md')]
    if robustness:
        documents.append('docs/sampler_docs/post_midyear/SAMPLER_VERIFICATION_TESTPLAN.md')
        documents += ['sim/sampler/README.md', 'tb_uvm/tb_uvm_sampler/README.md', 'quartus/sampler/README.md']
    result['documentation_hashes'] = {name: sha(R / name) for name in documents}
    hashes = {**sources, **result['evidence_hashes'], **result['documentation_hashes']}
    assert all(sha(R / name) == digest for name, digest in hashes.items())
    with result_path.open('x', encoding='utf8') as out: json.dump(result, out, indent=2); out.write('\n')
    with archive_path.open('xb') as out:
        with zipfile.ZipFile(out, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            archive.write(result_path, result_path.relative_to(R).as_posix())
            for name in sorted(hashes): archive.write(R / name, name)
    digest = sha(archive_path)
    with hash_path.open('x', encoding='utf8') as out: out.write(digest + '  ' + archive_path.name + '\n')
    with zipfile.ZipFile(archive_path) as archive:
        assert archive.testzip() is None
        assert all(hashlib.sha256(archive.read(name)).hexdigest() == digest for name, digest in hashes.items())
    summary = {k: result[k] for k in ('stage', 'resources', 'timing', 'source_regression', 'status')}
    summary['resources'] = {k: v for k, v in result['resources'].items() if k != 'alms_needed'}
    print(json.dumps(summary, indent=2))
    print('CREATE-ONLY CHECKPOINT PASS:', result_path, digest)


if __name__ == '__main__': main()
