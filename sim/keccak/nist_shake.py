"""Prepare NIST SHAKE vectors and compare captured DUT outputs.

Run before simulation: python sim/keccak/nist_shake.py prepare
Run after simulation:  python sim/keccak/nist_shake.py compare
The testbench reads only the input file. Comparison is a direct hex-string
check against NIST's published output, not a SHAKE calculation.
"""

import argparse
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCES = (
    "SHAKE128ShortMsg.rsp",
    "SHAKE128LongMsg.rsp",
    "SHAKE128VariableOut.rsp",
    "SHAKE256ShortMsg.rsp",
    "SHAKE256LongMsg.rsp",
    "SHAKE256VariableOut.rsp",
)


def read_cases(path):
    """Yield (case number, input bytes, output bytes) from one NIST file."""
    fixed_output_bits = None
    fixed_input_bits = None
    fields = {}
    case_number = 0

    for line_number, raw_line in enumerate(path.read_text(encoding="ascii").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            setting = line[1:-1].split("=", 1)
            if len(setting) == 2:
                name, value = (item.strip() for item in setting)
                if name == "Outputlen":
                    fixed_output_bits = int(value)
                elif name == "Input Length":
                    fixed_input_bits = int(value)
            continue
        if "=" not in line:
            raise ValueError(f"{path.name}:{line_number}: unrecognized line")

        key, value = (item.strip() for item in line.split("=", 1))
        if key in ("Len", "COUNT") and fields:
            raise ValueError(f"{path.name}:{line_number}: incomplete case")
        if key in fields:
            raise ValueError(f"{path.name}:{line_number}: duplicate {key}")
        fields[key] = value
        if key != "Output":
            continue

        input_bits = int(fields.get("Len", fixed_input_bits))
        output_bits = int(fields.get("Outputlen", fixed_output_bits))
        if input_bits < 0 or output_bits <= 0 or input_bits % 8 or output_bits % 8:
            raise ValueError(f"{path.name}:{line_number}: unsupported bit length")
        # NIST writes Msg=00 for the zero-length message. Len=0 is authoritative.
        message = b"" if input_bits == 0 else bytes.fromhex(fields["Msg"])
        expected = bytes.fromhex(fields["Output"])
        if len(message) != input_bits // 8 or len(expected) != output_bits // 8:
            raise ValueError(f"{path.name}:{line_number}: length does not match hex data")
        yield case_number, message, expected
        case_number += 1
        fields = {}

    if fields or case_number == 0:
        raise ValueError(f"{path.name}: incomplete or empty response file")


def prepare(args):
    inputs = ["# id mode message_hex_or_dash output_bytes"]
    expected_outputs = ["# id nist_expected_hex"]
    total = 0
    for source in SOURCES:
        path = ROOT / "NIST" / source
        mode = 0 if source.startswith("SHAKE128") else 1
        count = 0
        for number, message, expected in read_cases(path):
            if args.max_per_file is not None and count >= args.max_per_file:
                continue
            case_id = f"{path.stem}_{number:04d}"
            inputs.append(f"{case_id} {mode} {message.hex() or '-'} "
                          f"{len(expected)}")
            expected_outputs.append(f"{case_id} {expected.hex()}")
            count += 1
        print(f"NIST file prepared: {source}: {count} cases")
        total += count

    args.inputs.parent.mkdir(parents=True, exist_ok=True)
    args.expected.parent.mkdir(parents=True, exist_ok=True)
    args.inputs.write_text("\n".join(inputs) + "\n", encoding="ascii")
    args.expected.write_text("\n".join(expected_outputs) + "\n", encoding="ascii")
    print(f"Prepared {total} cases: {args.inputs} and {args.expected}")
    return 0


def rows(path, columns):
    if not path.is_file():
        raise ValueError(f"Missing {path}")
    for number, raw in enumerate(path.read_text(encoding="ascii").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if len(fields) != columns:
            raise ValueError(f"{path}:{number}: expected {columns} columns")
        yield number, fields


def hex_bytes(value, where):
    if value == "-":
        return ""
    try:
        data = bytes.fromhex(value)
    except ValueError as exc:
        raise ValueError(f"{where}: invalid hex") from exc
    if data.hex() != value.lower():
        raise ValueError(f"{where}: hex must contain complete bytes")
    return data.hex()


def compare(args):
    lengths = {}
    for number, (case_id, mode, message, output_bytes) in rows(args.inputs, 4):
        where = f"{args.inputs}:{number}"
        if case_id in lengths:
            raise ValueError(f"{where}: duplicate case {case_id}")
        if mode not in ("0", "1"):
            raise ValueError(f"{where}: invalid SHAKE mode")
        hex_bytes(message, where)
        length = int(output_bytes)
        if length < 1:
            raise ValueError(f"{where}: output length must be positive")
        lengths[case_id] = length
    if not lengths:
        raise ValueError("Input file has no cases")

    expected = {}
    for number, (case_id, output) in rows(args.expected, 2):
        where = f"{args.expected}:{number}"
        if case_id in expected:
            raise ValueError(f"{where}: duplicate case {case_id}")
        expected[case_id] = hex_bytes(output, where)
    if expected.keys() != lengths.keys():
        raise ValueError("Input and NIST expected files have different case IDs")
    for case_id, output in expected.items():
        if len(output) != 2 * lengths[case_id]:
            raise ValueError(f"{case_id}: NIST output length disagrees with input file")

    actual = {}
    for number, (case_id, core, output) in rows(args.actual, 3):
        where = f"{args.actual}:{number}"
        if core not in ("0", "1"):
            raise ValueError(f"{where}: invalid core ID {core}")
        key = (case_id, int(core))
        if key in actual:
            raise ValueError(f"{where}: duplicate DUT result for {case_id} core {core}")
        actual[key] = hex_bytes(output, where)

    failures = []
    for core in (0, 1):
        passed = 0
        for case_id in lengths:
            key = (case_id, core)
            if key not in actual:
                failures.append(f"MISSING {case_id} core {core}")
            elif actual[key] != expected[case_id]:
                got = actual[key]
                want = expected[case_id]
                failures.append(
                    f"MISMATCH {case_id} core {core}: "
                    f"got {len(got)//2} bytes {got[:64]}...; "
                    f"NIST {len(want)//2} bytes {want[:64]}..."
                )
            else:
                passed += 1
        print(f"Core {core}: {passed}/{len(lengths)} NIST outputs match")
    for case_id, core in actual:
        if case_id not in lengths:
            failures.append(f"UNEXPECTED {case_id} core {core}")
    for failure in failures[:20]:
        print(failure)
    if len(failures) > 20:
        print(f"... {len(failures) - 20} more failures")
    if failures:
        print(f"NIST COMPARE FAIL: {len(failures)} missing, mismatched, or extra results")
        return 1
    print(f"NIST COMPARE PASS: {2 * len(lengths)} DUT outputs match published NIST vectors")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    prepare_cmd = commands.add_parser("prepare", help="create the two NIST files before simulation")
    prepare_cmd.add_argument("--max-per-file", type=int,
                             help="export only the first N cases from each file")
    prepare_cmd.add_argument("--inputs", type=Path,
                             default=ROOT / "sim" / "keccak" / "nist_shake_inputs.txt")
    prepare_cmd.add_argument("--expected", type=Path,
                             default=ROOT / "sim" / "keccak" / "nist_shake_expected.txt")
    compare_cmd = commands.add_parser("compare", help="compare DUT captures after simulation")
    compare_cmd.add_argument("--inputs", type=Path,
                             default=ROOT / "sim" / "keccak" / "nist_shake_inputs.txt")
    compare_cmd.add_argument("--expected", type=Path,
                             default=ROOT / "sim" / "keccak" / "nist_shake_expected.txt")
    compare_cmd.add_argument("--actual", type=Path,
                             default=ROOT / "sim" / "keccak" / "nist_shake_dut_outputs.txt")
    args = parser.parse_args()
    if args.command == "prepare" and args.max_per_file is not None and args.max_per_file < 1:
        parser.error("--max-per-file must be positive")
    try:
        if args.command == "prepare":
            return prepare(args)
        return compare(args)
    except (ValueError, OSError) as exc:
        print(f"NIST {args.command.upper()} FAIL: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
