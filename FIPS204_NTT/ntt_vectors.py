"""Prepare FIPS 204-derived NTT cases and compare captured DUT coefficients.

Usage from the repository root:
    py FIPS204_NTT/ntt_vectors.py prepare
    # From sim/: vsim -c -do "do run_ntt_vectors.do; quit -f"
    py FIPS204_NTT/ntt_vectors.py compare

This is an independent normal-domain arithmetic model, not an official NIST
standalone NTT vector file. The existing SystemVerilog model is left intact.
"""

from __future__ import annotations

import argparse
import random
import re
from pathlib import Path

Q = 8_380_417
N = 256
ZETA = 1753
N_INV = pow(N, -1, Q)
VECTOR_DIR = Path(__file__).resolve().parent
ROOT = VECTOR_DIR.parent
INPUTS = VECTOR_DIR / "ntt_inputs.txt"
EXPECTED = VECTOR_DIR / "ntt_expected.txt"
OBSERVED = ROOT / "sim" / "ntt_dut_outputs.txt"
OPS = {"NTT", "INTT", "PWM", "ROUNDTRIP", "MUL"}
HEX_COEFF = re.compile(r"[0-9a-fA-F]{1,6}\Z")


def bit_reverse_8(value: int) -> int:
    return int(f"{value:08b}"[::-1], 2)


TWIDDLES = [pow(ZETA, bit_reverse_8(i), Q) for i in range(N)]


def forward(poly: list[int]) -> list[int]:
    out = poly.copy()
    k = 0
    length = N // 2
    while length:
        for start in range(0, N, 2 * length):
            k += 1
            zeta = TWIDDLES[k]
            for j in range(start, start + length):
                t = zeta * out[j + length] % Q
                out[j + length] = (out[j] - t) % Q
                out[j] = (out[j] + t) % Q
        length //= 2
    return out


def inverse(poly: list[int]) -> list[int]:
    out = poly.copy()
    k = N
    length = 1
    while length < N:
        for start in range(0, N, 2 * length):
            k -= 1
            zeta = -TWIDDLES[k]
            for j in range(start, start + length):
                t = out[j]
                out[j] = (t + out[j + length]) % Q
                out[j + length] = zeta * (t - out[j + length]) % Q
        length *= 2
    return [value * N_INV % Q for value in out]


def pointwise(a: list[int], b: list[int]) -> list[int]:
    return [x * y % Q for x, y in zip(a, b, strict=True)]


def schoolbook(a: list[int], b: list[int]) -> list[int]:
    out = [0] * N
    for i, x in enumerate(a):
        for j, y in enumerate(b):
            index = i + j
            sign = 1
            if index >= N:
                index -= N
                sign = -1
            out[index] = (out[index] + sign * x * y) % Q
    return out


def direct_forward(poly: list[int]) -> list[int]:
    """FIPS 204 NTT as polynomial evaluation at the odd zeta powers."""
    result = []
    for i in range(N):
        root = pow(ZETA, 2 * bit_reverse_8(i) + 1, Q)
        power = 1
        value = 0
        for coefficient in poly:
            value += coefficient * power
            power = power * root % Q
        result.append(value % Q)
    return result


def direct_inverse(spectrum: list[int]) -> list[int]:
    """Inverse evaluation formula; independent of the butterfly schedule."""
    result = [0] * N
    for i, value in enumerate(spectrum):
        inverse_root = pow(ZETA, -(2 * bit_reverse_8(i) + 1), Q)
        power = 1
        for j in range(N):
            result[j] += value * power
            power = power * inverse_root % Q
    return [value * N_INV % Q for value in result]


def check_reference() -> None:
    rng = random.Random(0x204)
    assert ZETA != 1 and pow(ZETA, 512, Q) == 1 and pow(ZETA, 256, Q) == Q - 1
    assert N * N_INV % Q == 1
    for _ in range(3):
        a = [rng.randrange(Q) for _ in range(N)]
        b = [rng.randrange(Q) for _ in range(N)]
        assert forward(a) == direct_forward(a), "Butterfly NTT differs from direct evaluation"
        assert inverse(a) == direct_inverse(a), "Butterfly INTT differs from inverse formula"
        assert inverse(forward(a)) == a, "NTT round trip failed"
        assert inverse(pointwise(forward(a), forward(b))) == schoolbook(a, b), (
            "NTT multiply differs from independent schoolbook multiply"
        )


def build_cases() -> list[tuple[str, str, list[int], list[int] | None]]:
    rng = random.Random(0x2042026)
    zero = [0] * N
    maximum = [Q - 1] * N
    delta_0 = [0] * N
    delta_0[0] = 1
    delta_255 = [0] * N
    delta_255[255] = Q - 1
    ramp = [i % Q for i in range(N)]
    random_a = [rng.randrange(Q) for _ in range(N)]
    random_b = [rng.randrange(Q) for _ in range(N)]
    bounded = [rng.randrange(-2, 3) % Q for _ in range(N)]
    return [
        ("ntt_zero", "NTT", zero, None),
        ("ntt_max", "NTT", maximum, None),
        ("ntt_delta_0", "NTT", delta_0, None),
        ("ntt_delta_255", "NTT", delta_255, None),
        ("ntt_ramp", "NTT", ramp, None),
        ("ntt_random", "NTT", random_a, None),
        ("ntt_bounded", "NTT", bounded, None),
        ("intt_zero", "INTT", zero, None),
        ("intt_max", "INTT", maximum, None),
        ("intt_random", "INTT", random_b, None),
        ("intt_from_ntt", "INTT", forward(random_a), None),
        ("pwm_zero", "PWM", zero, random_b),
        ("pwm_max", "PWM", maximum, maximum),
        ("pwm_random", "PWM", random_a, random_b),
        ("roundtrip_delta", "ROUNDTRIP", delta_255, None),
        ("roundtrip_random", "ROUNDTRIP", random_a, None),
        ("mul_delta", "MUL", delta_255, random_b),
        ("mul_random", "MUL", random_a, random_b),
    ]


def expected_output(op: str, a: list[int], b: list[int] | None) -> list[int]:
    if op == "NTT":
        return forward(a)
    if op == "INTT":
        return inverse(a)
    if op == "PWM":
        assert b is not None
        return pointwise(a, b)
    if op == "ROUNDTRIP":
        return a.copy()
    assert op == "MUL" and b is not None
    return schoolbook(a, b)


def coeff_line(label: str, values: list[int]) -> str:
    assert len(values) == N and all(0 <= value < Q for value in values)
    return label + " " + " ".join(f"{value:06x}" for value in values) + "\n"


def prepare() -> None:
    check_reference()
    cases = build_cases()
    INPUTS.parent.mkdir(parents=True, exist_ok=True)
    OBSERVED.unlink(missing_ok=True)  # Require a fresh DUT capture before compare.
    with INPUTS.open("w", encoding="ascii", newline="\n") as input_file, EXPECTED.open(
        "w", encoding="ascii", newline="\n"
    ) as expected_file:
        input_file.write(f"COUNT {len(cases)}\n")
        expected_file.write(f"COUNT {len(cases)}\n")
        for case_id, op, a, b in cases:
            input_file.write(f"CASE {case_id} {op}\n")
            input_file.write(coeff_line("A", a))
            if b is not None:
                input_file.write(coeff_line("B", b))
            expected_file.write(f"CASE {case_id} {op}\n")
            expected_file.write(coeff_line("OUT", expected_output(op, a, b)))
    print(f"NTT PREPARE PASS: {len(cases)} cases; reference round trips and schoolbook checks passed")
    print(f"inputs: {INPUTS}\nexpected: {EXPECTED}")


def read_outputs(path: Path) -> list[tuple[str, str, list[int]]]:
    tokens = path.read_text(encoding="ascii").split()
    if len(tokens) < 2 or tokens[0] != "COUNT":
        raise ValueError(f"{path}: missing COUNT header")
    count = int(tokens[1])
    position = 2
    result = []
    for case_number in range(count):
        if position + 4 > len(tokens):
            raise ValueError(f"{path}: incomplete CASE header at case {case_number}")
        if tokens[position] != "CASE":
            raise ValueError(f"{path}: case {case_number} missing CASE marker")
        case_id, op = tokens[position + 1 : position + 3]
        if op not in OPS or tokens[position + 3] != "OUT":
            raise ValueError(f"{path}: bad operation or OUT marker for {case_id}")
        raw = tokens[position + 4 : position + 4 + N]
        if len(raw) != N:
            raise ValueError(f"{path}: incomplete coefficient list for {case_id}")
        for index, value in enumerate(raw):
            if not HEX_COEFF.fullmatch(value):
                raise ValueError(f"{path}: {case_id}[{index}] is not a known hex coefficient: {value}")
        coefficients = [int(value, 16) for value in raw]
        if any(value >= Q for value in coefficients):
            raise ValueError(f"{path}: {case_id} has coefficient outside 0..q-1")
        result.append((case_id, op, coefficients))
        position += 4 + N
    if position != len(tokens):
        raise ValueError(f"{path}: extra data after {count} cases")
    return result


def compare() -> int:
    expected = read_outputs(EXPECTED)
    observed = read_outputs(OBSERVED)
    if len(observed) != len(expected):
        print(f"NTT COMPARE FAIL: expected {len(expected)} cases, got {len(observed)}")
        return 1
    failures = 0
    compared_coefficients = 0
    for (case_id, op, want), (got_id, got_op, got) in zip(expected, observed, strict=True):
        if (got_id, got_op) != (case_id, op):
            print(f"FAIL {case_id}: observed {got_id}/{got_op}, expected {case_id}/{op}")
            failures += 1
            continue
        mismatches = [(index, x, y) for index, (x, y) in enumerate(zip(want, got, strict=True)) if x != y]
        compared_coefficients += N
        if mismatches:
            index, x, y = mismatches[0]
            print(f"FAIL {case_id}/{op}: {len(mismatches)} wrong coefficients; first [{index}] expected {x}, got {y}")
            failures += 1
        else:
            print(f"PASS {case_id}/{op}: {N} coefficients")
    if failures:
        print(f"NTT COMPARE FAIL: {failures}/{len(expected)} cases; {compared_coefficients} coefficients inspected")
        return 1
    print(f"NTT COMPARE PASS: {len(expected)}/{len(expected)} cases, {compared_coefficients}/{compared_coefficients} coefficients")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "compare"))
    command = parser.parse_args().command
    if command == "prepare":
        prepare()
        return 0
    try:
        return compare()
    except (OSError, ValueError) as exc:
        print(f"NTT COMPARE FAIL: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
