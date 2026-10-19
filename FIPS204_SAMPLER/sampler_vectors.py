"""One-file sampler workflow: prepare -> Questa capture -> compare.

Expected coefficients come from the FIPS formulas below, never from the DUT.
Seed cases are also checked against the unchanged repository C reference.
Only Python's standard library is needed; prepare additionally needs GCC.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SIM = ROOT / "sim/sampler"
Q = 8380417
N = 256
PARAMS = ((2, 1 << 17, 39), (4, 1 << 19, 49), (2, 1 << 19, 60))
MODES = ("A", "secret", "mask", "challenge")
REF_NAMES = ("poly.c", "poly.h", "params.h", "config.h", "fips202.c", "fips202.h",
             "symmetric-shake.c", "symmetric.h", "ntt.c", "ntt.h", "reduce.c",
             "reduce.h", "rounding.c", "rounding.h")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def sample(mode, param, data):
    """Return (canonical coefficients, bytes used). Short input returns a prefix.

    Challenge is mutable until complete, so an incomplete challenge returns [].
    Scalar arithmetic/whole-stream bit conversion is independent of the RTL's
    lane compactor, residual/chunk implementation and compact RAM controller.
    """
    eta, gamma, tau = PARAMS[param]
    values = []
    used = 0
    if mode == 0:
        for pos in range(0, len(data) - 2, 3):
            used = pos + 3
            value = int.from_bytes(data[pos:pos + 3], "little") & 0x7fffff
            if value < Q:
                values.append(value)
            if len(values) == N:
                break
    elif mode == 1:
        for used, byte in enumerate(data, 1):
            for nibble in (byte & 15, byte >> 4):
                if nibble < (15 if eta == 2 else 9):
                    values.append((eta - (nibble % 5 if eta == 2 else nibble)) % Q)
                if len(values) == N:
                    return values, used
    elif mode == 2:
        width = gamma.bit_length()
        bits = int.from_bytes(data, "little")
        for index in range(min(N, 8 * len(data) // width)):
            value = (bits >> (index * width)) & ((1 << width) - 1)
            values.append((gamma - value) % Q)
        used = (len(values) * width + 7) // 8
    elif mode == 3:
        if len(data) < 8:
            return [], len(data)
        signs = int.from_bytes(data[:8], "little")
        values = [0] * N
        used = 8
        for i in range(N - tau, N):
            while True:
                if used == len(data):
                    return [], used
                j = data[used]
                used += 1
                if j <= i:
                    break
            values[i] = values[j]
            values[j] = 1 - 2 * (signs & 1)
            signs >>= 1
        values = [v % Q for v in values]
    else:
        raise ValueError("unknown sampler mode")
    return values, used


def build_c_references(cc):
    compiler = shutil.which(cc)
    if not compiler:
        raise ValueError(f"GCC not found: {cc}; use prepare --cc C:/MinGW/bin/gcc.exe")
    build = SIM / "reference_build"
    build.mkdir(parents=True, exist_ok=True)
    ref = ROOT / "dilithium-sw-model/ref"
    wrapper = ROOT / "tb_uvm/tb_uvm_sampler/reference_check.c"
    programs = []
    for level in (2, 3, 5):
        exe = build / f"reference_{level}.exe"
        command = [compiler, "-std=c99", "-O2", f"-DDILITHIUM_MODE={level}",
                   "-I", str(ref), str(wrapper)]
        command += [str(ref / n) for n in ("poly.c", "fips202.c", "symmetric-shake.c",
                                          "ntt.c", "reduce.c", "rounding.c")]
        subprocess.run(command + ["-o", str(exe)], check=True, capture_output=True, text=True)
        programs.append(exe)
    return programs, subprocess.check_output([compiler, "--version"], text=True).splitlines()[0]


def boundary_bytes(mode, param, core):
    eta, gamma, tau = PARAMS[param]
    if mode == 0:
        raw = (0, Q - 1, Q, 0xffffff, 0x800001, 0xffe000, 0x800000)
        return b"".join(v.to_bytes(3, "little") for _ in range(80) for v in raw)
    if mode == 1:
        return bytes((i & 15) | (((i * 5 + core) & 15) << 4) for i in range(512))
    if mode == 2:
        fields = (0, 2 * gamma - 1, gamma, gamma - 1, gamma + 1, 1, 2 * gamma - 2)
        width = gamma.bit_length()
        bits = sum(fields[(i + core) % len(fields)] << (i * width) for i in range(N))
        return bits.to_bytes(N * width // 8, "little")
    data = bytearray(bytes.fromhex("2900a5ff81f00f55"))
    for i in range(N - tau, N):
        if i < 255:
            data.extend((255, i + 1))
        data.append((0 if i % 3 == 0 else i if i % 3 == 1 else 7) if core == 0 else 0)
    return bytes(data)


def packets(case, variant):
    """Partition until the exact final needed byte; do not request another beat after stop."""
    if "bad_bytes" in case:
        return [(case["bad_bytes"], 1, 0)]
    data = case["data"]
    sizes = (16,) if variant % 2 == 0 else (1, 15, 7, 8, 2, 3, 9, 4, 12, 5, 6, 10, 11, 13, 14, 16)
    result = []
    pos = 0
    while pos < len(data):
        chunk = data[pos:pos + sizes[len(result) % len(sizes)]]
        pos += len(chunk)
        result.append((len(chunk), int(pos == len(data)), int.from_bytes(chunk, "little")))
    return result


def prepare(cc):
    programs, compiler = build_c_references(cc)
    cases = []
    groups = []
    c_checked = 0

    def add(core, mode, param, data, label, values=None, code=0, abort=False, **metadata):
        case = dict(core=core, id=1000 + len(cases), mode=mode, param=param,
                    data=data, label=label, values=values or [], code=code, abort=abort, **metadata)
        cases.append(case)
        return case

    for param in range(3):
        for variant in range(2):
            for mode in range(4):
                pair = []
                for core in range(2):
                    length = 32 if mode == 0 else (32, 48, 64)[param] if mode == 3 else 64
                    label = f"seed-p{param}-{MODES[mode]}-v{variant}-core{core}"
                    seed = hashlib.shake_256(label.encode()).digest(length)
                    nonce = ((1 + core) << 8 | (2 - core)) if mode == 0 else (variant * (4, 5, 7)[param] + core)
                    if mode == 2:
                        nonce += 256
                    absorbed = seed + (nonce.to_bytes(2, "little") if mode != 3 else b"")
                    xof = hashlib.shake_128 if mode == 0 else hashlib.shake_256
                    stream = xof(absorbed).digest(4096)
                    values, used = sample(mode, param, stream)
                    if len(values) != N:
                        raise ValueError("seed budget exhausted; extend the same XOF, never pad")
                    c_values = list(map(int, subprocess.check_output(
                        [str(programs[param]), str(mode), str(nonce), seed.hex()], text=True).split()))
                    if c_values != values:
                        raise ValueError(f"Python/C reference mismatch: {label}")
                    c_checked += 1
                    pair.append(add(core, mode, param, stream[:used], label, values,
                                    seed=seed.hex(), nonce=nonce, family="seed-derived"))
                groups.append(pair)
        for mode in range(4):
            pair = []
            for core in range(2):
                selected_mode = mode if core == 0 else (mode + 1) % 4
                raw = boundary_bytes(selected_mode, param, core)
                values, used = sample(selected_mode, param, raw)
                if len(values) != N:
                    raise ValueError("boundary stimulus incomplete")
                pair.append(add(core, selected_mode, param, raw[:used], "explicit boundaries",
                                values, family="explicit-bytes"))
            groups.append(pair)

    # Finite streams that cannot produce any complete output group.
    for param in range(3):
        for mode in range(4):
            raw = b"\xff" * 16 if mode in (0, 1) else b"\x00" * (1 if mode == 2 else 7)
            groups.append([add((param + mode) % 2, mode, param, raw,
                               "finite exhausted source", code=1, family="negative")])
    for mode in range(4):
        groups.append([add(mode % 2, mode, 3, b"", "invalid parameter", code=3, family="negative")])
        for bad in (0, 17):
            groups.append([add(mode % 2, mode, 0, b"", "invalid valid-byte count", code=4,
                               bad_bytes=bad, family="negative")])
    for mode in range(4):
        raw = b"\xff" if mode == 1 else b"\x00"
        groups.append([add(mode % 2, mode, 0, raw, "reset incomplete state", abort=True, family="reset")])
    # Demonstrate slot recovery after all reset cases, using independently checked data.
    for mode in range(4):
        raw = boundary_bytes(mode, 2, 0)
        values, used = sample(mode, 2, raw)
        groups.append([add(mode % 2, mode, 2, raw[:used], "post-reset slot reuse", values,
                           family="explicit-bytes")])

    counts = (len(cases), sum(c["code"] == 0 and not c["abort"] for c in cases),
              sum(c["code"] != 0 for c in cases), sum(c["abort"] for c in cases))
    run_id = uuid.uuid4().hex
    inputs = [f"H {run_id} " + " ".join(map(str, counts)), "R"]
    for group_index, group in enumerate(groups):
        for c in group:
            inputs.append(f"J {c['core']} {c['id']} {c['mode']} {c['param']}")
            c["packets"] = packets(c, group_index)
        for step in range(max(len(c["packets"]) for c in group)):
            for c in group:
                if step < len(c["packets"]):
                    n, last, word = c["packets"][step]
                    inputs.append(f"B {c['core']} {n} {last} {word:032x}")
        inputs.append("R" if group[0]["abort"] else "W")
    inputs.append("E")
    expected = [f"H {run_id}"]
    for c in cases:
        core, job = c["core"], c["id"]
        expected.append(f"J {core} {job} {c['mode']} {c['param']}")
        for i, value in enumerate(c["values"]):
            expected.append(f"C {core} {job} {i} {value} {int(i == 255)}")
        nbytes = sum(n for n, _, _ in c["packets"] if 1 <= n <= 16)
        expected.append(f"A {core} {job} 0 {nbytes}" if c["abort"] else
                        f"S {core} {job} {c['code']} {len(c['values'])} {nbytes}")
    coefficients = sum(len(c["values"]) for c in cases)
    expected.append("F " + " ".join(map(str, (*counts, coefficients))))
    (HERE / "sampler_inputs.txt").write_text("\n".join(inputs) + "\n", encoding="ascii")
    (HERE / "sampler_expected.txt").write_text("\n".join(expected) + "\n", encoding="ascii")
    files = [ROOT / "dilithium-sw-model/ref" / n for n in REF_NAMES]
    files += [ROOT / "tb_uvm/tb_uvm_sampler/reference_check.c", Path(__file__),
              ROOT / "docs/FIPS/NIST.FIPS.204.pdf"]
    # Bind captures to the prepared RTL/harness as well as the software model.
    # Source changes require a new prepare/manifest, preventing an old PASS from
    # being presented as evidence for a modified design.
    files += sorted((ROOT / "src/sampler").glob("*.sv"))
    files += sorted((ROOT / "tb_uvm/tb_uvm_sampler").glob("*.sv"))
    files += sorted((ROOT / "tb_uvm/tb_uvm_sampler").glob("*.svh"))
    files += [ROOT / "sim/sampler/run_uvm.do"]
    manifest = dict(format=1, run_id=run_id, provenance="locally generated FIPS-derived; not official standalone NIST vectors",
                    official_sources_checked="2026-10-16", official_discovery="ACVP KeyGen/SigGen/SigVer; no standalone sampler suite identified in reviewed sources",
                    sources=["https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.204.pdf",
                             "https://pages.nist.gov/ACVP/draft-celi-acvp-ml-dsa.html",
                             "https://github.com/usnistgov/ACVP-Server/tree/master/gen-val/json-files"],
                    algorithms="FIPS 204 Algorithms 29-34; Python hashlib SHAKE128/SHAKE256",
                    c_reference_commit=subprocess.check_output(["git", "log", "-1", "--format=%H", "--", "dilithium-sw-model/ref"], cwd=ROOT, text=True).strip(),
                    c_reference_scope="sampling functions only; not a full ML-DSA implementation certification",
                    c_seed_cases_checked=c_checked, compiler=compiler, python=sys.version.split()[0],
                    totals=dict(jobs=counts[0], success=counts[1], errors=counts[2], aborted=counts[3], coefficients=coefficients),
                    source_hashes={p.relative_to(ROOT).as_posix(): sha(p) for p in files},
                    vector_hashes={n: sha(HERE / n) for n in ("sampler_inputs.txt", "sampler_expected.txt")},
                    cases=[{k: v for k, v in c.items() if k not in ("data", "values", "packets")} |
                           dict(input_bytes=len(c["data"]), packet_count=len(c["packets"])) for c in cases])
    (HERE / "provenance.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"PREPARE PASS: {counts[0]} jobs, {counts[1]} complete polynomials, {counts[2]} expected errors, {counts[3]} resets")
    print(f"Independent Python/C equality: {c_checked} seed cases, {c_checked*N} coefficients")
    print(f"Expected RTL comparisons: {coefficients}; manifest {run_id}")


def parse_records(text):
    """Validate each job's order/lifecycle, permitting arbitrary cross-job interleaving."""
    rows = {}
    live = {}
    seen = {}
    header = None
    footer = None
    jobs = success = errors = aborted = coefficients = 0
    for line_number, line in enumerate(text.splitlines(), 1):
        parts = line.split()
        if not parts:
            raise ValueError(f"blank record at line {line_number}")
        tag = parts[0]
        if footer is not None:
            raise ValueError("extra record after footer")
        if tag == "H":
            if header is not None or rows or len(parts) != 2 or len(parts[1]) != 32:
                raise ValueError("invalid/duplicate header")
            int(parts[1], 16)
            header = parts[1]
            continue
        if header is None:
            raise ValueError("header missing")
        if tag == "F":
            footer = tuple(map(int, parts[1:]))
            if live or footer != (jobs, success, errors, aborted, coefficients):
                raise ValueError("missing completion or incorrect footer totals")
            continue
        sizes = {"J": 5, "C": 6, "S": 6, "A": 5}
        if tag not in sizes or len(parts) != sizes[tag]:
            raise ValueError(f"unknown/malformed record at line {line_number}")
        values = tuple(map(int, parts[1:]))
        core, job = values[:2]
        if core not in (0, 1) or not 0 <= job <= 65535:
            raise ValueError("invalid core/job")
        if tag == "J":
            if core in live or ("J", core, job) in rows or not all(0 <= v <= 3 for v in values[2:]):
                raise ValueError("duplicate/invalid descriptor or premature slot reuse")
            live[core] = job
            seen[core] = 0
            jobs += 1
        elif live.get(core) != job:
            raise ValueError("unowned coefficient/status")
        if tag == "C":
            index, value, last = values[2:]
            if index != seen[core] or not 0 <= index < N or not 0 <= value < Q or last != int(index == 255):
                raise ValueError(f"invalid index/value/last for job {job} index {index}")
            seen[core] += 1
            coefficients += 1
        elif tag in ("S", "A"):
            code = values[2] if tag == "S" else None
            count, nbytes = values[-2:]
            if count != seen[core] or nbytes < 0 or (tag == "S" and code not in range(5)):
                raise ValueError("invalid completion count/status")
            if tag == "A":
                aborted += 1
            elif code == 0:
                if count != N:
                    raise ValueError("incomplete successful polynomial")
                success += 1
            else:
                errors += 1
            del live[core]
        key = (tag, core, job, values[2]) if tag == "C" else (tag, core, job)
        if key in rows:
            raise ValueError("duplicate record")
        rows[key] = values
    if header is None or footer is None:
        raise ValueError("capture incomplete: header/footer missing")
    return header, rows, footer


def check_equal(expected, actual):
    want_id, want, want_totals = expected
    got_id, got, got_totals = actual
    if got_id != want_id:
        raise ValueError("stale/wrong manifest ID; rerun capture after prepare")
    if want_totals != got_totals:
        raise ValueError(f"totals mismatch: expected {want_totals}, observed {got_totals}")
    if want.keys() != got.keys():
        raise ValueError(f"missing records {list(want.keys()-got.keys())[:3]}; extra records {list(got.keys()-want.keys())[:3]}")
    for key, value in want.items():
        if got[key] != value:
            raise ValueError(f"mismatch {key}: expected {value}, observed {got[key]}")


def load_expected():
    manifest = json.loads((HERE / "provenance.json").read_text())
    for name, digest in manifest["vector_hashes"].items():
        if sha(HERE / name) != digest:
            raise ValueError(f"vector changed since prepare: {name}")
    for name, digest in manifest["source_hashes"].items():
        if sha(ROOT / name) != digest:
            raise ValueError(f"source/reference/generator changed since prepare: {name}")
    expected = parse_records((HERE / "sampler_expected.txt").read_text())
    if expected[0] != manifest["run_id"]:
        raise ValueError("manifest/expected ID mismatch")
    return expected


def compare(outputs):
    expected = load_expected()
    check_equal(expected, parse_records(outputs.read_text()))
    jobs, success, errors, aborted, coefficients = expected[2]
    message = (f"SAMPLER COMPARE PASS: {jobs}/{jobs} jobs, {coefficients}/{coefficients} coefficients; "
               f"{success} complete, {errors} expected errors, {aborted} reset-aborted\n")
    (SIM / "compare.log").write_text(message)
    print(message, end="")


def selftest(outputs):
    expected = load_expected()
    text = outputs.read_text()
    check_equal(expected, parse_records(text))
    original = text.splitlines()
    ci = next(i for i, line in enumerate(original) if line.startswith("C "))
    si = next(i for i, line in enumerate(original) if line.startswith("S "))
    ji = next(i for i, line in enumerate(original) if line.startswith("J "))
    variants = {}

    def changed(name, row, column, value):
        lines = original.copy()
        fields = lines[row].split()
        fields[column] = str(value)
        lines[row] = " ".join(fields)
        variants[name] = "\n".join(lines) + "\n"

    changed("wrong value", ci, 4, (int(original[ci].split()[4])+1) % Q)
    changed("wrong index", ci, 3, 1)
    changed("wrong last", ci, 5, 1)
    changed("wrong status", si, 3, 1)
    changed("wrong accepted-byte count", si, 5, int(original[si].split()[5])+1)
    changed("wrong descriptor parameter", ji, 4, (int(original[ji].split()[4])+1) % 3)
    changed("stale manifest", 0, 1, "0" * 32)
    variants["missing coefficient"] = "\n".join(original[:ci]+original[ci+1:])+"\n"
    variants["duplicate coefficient"] = "\n".join(original[:ci]+[original[ci]]+original[ci:])+"\n"
    variants["truncated capture"] = "\n".join(original[:-1])+"\n"
    variants["extra record"] = text + original[ci] + "\n"
    variants["unknown record"] = text.replace(original[ci], "X 0 0", 1)
    for name, bad in variants.items():
        try:
            check_equal(expected, parse_records(bad))
        except ValueError:
            continue
        raise ValueError(f"checker accepted corruption: {name}")
    message = f"CHECKER SELFTEST PASS: {len(variants)}/{len(variants)} corruptions rejected; no coverage credited\n"
    (SIM / "checker_selftest.log").write_text(message)
    print(message, end="")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "compare", "selftest"))
    parser.add_argument("--cc", default="gcc", help="GCC executable for prepare's independent C check")
    parser.add_argument("--outputs", type=Path, default=SIM / "sampler_dut_outputs.txt")
    args = parser.parse_args()
    try:
        if args.command == "prepare":
            prepare(args.cc)
        elif args.command == "compare":
            compare(args.outputs)
        else:
            selftest(args.outputs)
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        message = f"SAMPLER {args.command.upper()} FAIL: {exc}\n"
        if args.command == "compare":
            (SIM / "compare.log").write_text(message)
        print(message, file=sys.stderr, end="")
        if isinstance(exc, subprocess.CalledProcessError) and exc.stderr:
            print(exc.stderr, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
