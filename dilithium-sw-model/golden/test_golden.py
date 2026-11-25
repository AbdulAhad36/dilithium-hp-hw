"""Regression for the golden-model adapter; uses stored, unchanged NIST files."""
import argparse
import contextlib
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import re
import tempfile
import unittest

import golden as g


class GoldenTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        args = argparse.Namespace(operation='all', level='all', tc_id=None, limit=None)
        cls.cases, cls.skipped, _ = g.load_nist(args)
        cls.cache = {}
        cls.source_hashes = {p: g.digest(p) for p in g.REF.glob('*') if p.suffix in ('.c', '.h')}

    def test_all_supported_official_cases_and_observation_equivalence(self):
        counts = {}
        valid = {True: 0, False: 0}
        for c in self.cases:
            with self.subTest(id=c['id']):
                original = g.call_c(c, c['operation'], None, self.cache)
                observed = g.call_c(c, c['operation'], Path(os.devnull), self.cache)
                self.assertEqual(original, observed, 'Trace hooks changed output')
                self.assertTrue(all(x['pass'] for x in g.differences(original, c['expected'])))
                key = (c['operation'], c['level'])
                counts[key] = counts.get(key, 0) + 1
                if c['operation'] == 'verify':
                    valid[original['valid']] += 1
        self.assertEqual(len(self.cases), 345)
        self.assertEqual(len(self.skipped), 0)
        for level in (2, 3, 5):
            self.assertEqual(counts['keygen', level], 25)
            self.assertEqual(counts['sign', level], 60)
            self.assertEqual(counts['verify', level], 30)
        self.assertGreater(valid[True], 0)
        self.assertGreater(valid[False], 0)
        print('\nOfficial checks and traced/untraced equality:', counts, 'Verify statuses:', valid)

    def test_keygen_trace_is_from_the_actual_returned_key(self):
        with tempfile.TemporaryDirectory(dir=g.BUILD) as name:
            for level in (2, 3, 5):
                c = next(c for c in self.cases if c['level'] == level and c['operation'] == 'keygen')
                p = Path(name) / f'trace{level}.txt'
                answer = g.call_c(c, 'keygen', p, self.cache)
                content = p.read_text()
                polys, label = {}, None
                for line in content.splitlines():
                    if re.match(r'^[A-Za-z].* =$', line):
                        label = line[:-2].strip()
                        polys[label] = []
                    elif line.startswith('  coeff['):
                        polys[label].extend(map(int, line.split(':', 1)[1].split()))
                pk = bytes.fromhex(answer['pk'])
                self.assertIn('rho = ' + pk[:32].hex(), content)
                k, l = {2: (4, 4), 3: (6, 5), 5: (8, 7)}[level]
                self.assertEqual(sum(x.startswith('A_hat[') for x in polys), k*l)
                self.assertTrue(all(len(v) == 256 for v in polys.values()))
                for row in range(k):
                    packed = int.from_bytes(pk[32+row*320:32+(row+1)*320], 'little')
                    expected = [(packed >> (10*i)) & 1023 for i in range(256)]
                    self.assertEqual(polys[f't1[{row}]'], expected)
                    self.assertEqual(polys[f't[{row}]'], [a*8192+b for a,b in zip(
                        polys[f't1[{row}]'], polys[f't0[{row}]'])])
                self.assertEqual(sum(x.startswith('s1[') for x in polys), l)

    def test_custom_roundtrip_and_tamper_all_levels(self):
        for level in (2, 3, 5):
            for message, context in [('', ''), ('00ff0102', '00ff'), ('ff'*8192, '01'*255)]:
                c = g.normalize({'id': 'own', 'level': level, 'operation': 'roundtrip',
                    'seed': bytes(range(32)).hex(), 'rnd': 'a5'*32,
                    'message': message, 'context': context})
                c.update(g.call_c(c, 'keygen', None, self.cache))
                c.update(g.call_c(c, 'sign', None, self.cache))
                self.assertTrue(g.call_c(c, 'verify', None, self.cache)['valid'])
                c['signature'] = ('01' if c['signature'][:2] == '00' else '00') + c['signature'][2:]
                self.assertFalse(g.call_c(c, 'verify', None, self.cache)['valid'])

    def test_compare_reports_first_byte_missing_case_and_wrong_status(self):
        self.assertIn('first mismatch byte 1', g.differences({'pk': 'aabb'}, {'pk': 'aacc'})[0]['detail'])
        self.assertFalse(g.differences({'pk': 'aa'}, {'pk': 'aabb'})[0]['pass'])
        self.assertFalse(g.differences({'valid': False}, {'valid': True})[0]['pass'])
        with tempfile.TemporaryDirectory(dir=g.BUILD) as name:
            p = Path(name)
            expected = {'cases': [{'id': 'case', 'level': 2, 'operation': 'keygen', 'outputs': {'pk': 'aabb'}}]}
            g.write_json(p/'expected.json', expected)
            for actual, rc in [(expected, 0), ({'cases': []}, 1),
                ({'cases': [dict(expected['cases'][0], outputs={'pk': 'aacc'})]}, 1)]:
                g.write_json(p/'actual.json', actual)
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(g.compare(p/'actual.json', p/'expected.json', p/'report.txt'), rc)

    def test_reject_bad_inputs_and_reject_overwrite(self):
        base = {'id': 'x', 'level': 2, 'operation': 'roundtrip', 'seed': '00'*32,
                'rnd': '00'*32, 'message': '', 'context': ''}
        for patch in [{'level': 4}, {'seed': '00'}, {'rnd': None}, {'message': 'zz'}, {'context': '00'*256}]:
            with self.subTest(patch=patch), self.assertRaises(ValueError):
                g.normalize(dict(base, **patch))
        c = dict(base); del c['rnd']
        with self.assertRaises(ValueError): g.normalize(c)
        with tempfile.TemporaryDirectory(dir=g.BUILD) as name:
            p = Path(name); (p/'user.txt').write_text('keep')
            with self.assertRaises(ValueError): g.run_cases([], p, False)
            self.assertEqual((p/'user.txt').read_text(), 'keep')

    @classmethod
    def tearDownClass(cls):
        for path, old in cls.source_hashes.items():
            if g.digest(path) != old:
                raise AssertionError(f'Original reference changed: {path}')


if __name__ == '__main__':
    g.BUILD.mkdir(exist_ok=True)
    unittest.main(verbosity=2)
