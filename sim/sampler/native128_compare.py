"""Compare checked current performance rows against immutable Stage4.7s.

Run from the repository root: python sim/sampler/native128_compare.py
Counts are sampler-only; rates at6.5ns require fresh positive fitted timing.
"""
import argparse
import csv
import io
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT / 'docs/sampler_docs/post_midyear'


def summarize(rows):
    result = {}
    for mode, name in enumerate(('matrix', 'secret', 'mask', 'challenge')):
        selected = [row for row in rows if int(row['mode']) == mode
                    and row['stalls'] == '0' and row['jobs'] == '1']
        assert len(selected) == 6
        entry = {}
        for key in ('latency_cycles', 'input_blocked_cycles', 'chunk_cycles',
                    'max_collector', 'peak_candidates_per_cycle',
                    'peak_processed_bytes_per_cycle', 'input_to_first_cycles'):
            values = [int(row[key]) for row in selected]
            entry[key] = {'min': min(values), 'max': max(values)}
        # With no downstream stalls, each successful job has256 transfers.
        # Between first and last transfers there are255 intervals. Extra
        # intervals are output bubbles, independently of input-block overlays.
        bubbles = [int(row['last_output_cycle']) - int(row['first_output_cycle']) - 255
                   for row in selected]
        assert min(bubbles) >= 0
        entry['output_bubbles_after_first'] = {'min': min(bubbles), 'max': max(bubbles)}
        entry['mcoeff_per_s_at_153_85mhz_if_timing_closes'] = {
            'min': 256 * (1000 / 6.5) / entry['latency_cycles']['max'],
            'max': 256 * (1000 / 6.5) / entry['latency_cycles']['min']}
        result[name] = entry
    return result


def compare(live=False):
    with zipfile.ZipFile(DOC / 'evidence/stage4_7s.zip') as archive:
        baseline = list(csv.DictReader(io.StringIO(
            archive.read('sim/sampler/performance.csv').decode())))
    if live:
        current = list(csv.DictReader((ROOT / 'sim/sampler/performance.csv').open()))
    else:
        with zipfile.ZipFile(DOC / 'evidence/stage4_8a.zip') as archive:
            current = list(csv.DictReader(io.StringIO(
                archive.read('sim/sampler/performance.csv').decode())))
    assert len(baseline) == len(current) == 96
    old = {row['id']: row for row in baseline}
    assert len(old) == 96 and len({row['id'] for row in current}) == 96
    deltas = []
    for row in current:
        previous = old[row['id']]
        for key in ('scenario', 'mode', 'param', 'core', 'jobs', 'stalls',
                    'generated_coefficients', 'output_coefficients'):
            assert previous[key] == row[key], (row['id'], key)
        assert int(row['output_coefficients']) == 256
        deltas.append({'id': int(row['id']), 'mode': int(row['mode']),
                       'latency_delta_cycles': int(row['latency_cycles']) - int(previous['latency_cycles'])})
    return {'baseline': '4.7s', 'trial': 'live' if live else 'archived4.8a',
            'baseline_metrics': summarize(baseline), 'trial_metrics': summarize(current),
            'all96_latency_deltas': deltas,
            'limits': ['Input blocking can overlap output transfer; do not sum overlays.',
                       'One23-bit output/cycle remains the aggregate external ceiling.',
                       'Full-word extraction does not imply one new input word each cycle.',
                       'Timing qualification must come from the matching fresh Quartus build.']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live', action='store_true', help='Compare current CSV instead of archived4.8a')
    print(json.dumps(compare(parser.parse_args().live), indent=2))
