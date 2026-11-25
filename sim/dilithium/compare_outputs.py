"""Compare software/hardware text outputs without running either model."""

import argparse
import re
from pathlib import Path


HEADER = re.compile(r"\[(.+)\] level=(2|3|5) operation=(keygen|sign|verify)")
FIELDS = {"keygen": {"pk", "sk"}, "sign": {"signature"}, "verify": {"valid"}}


def read_cases(path, operation):
    cases = {}
    current = None
    for number, raw in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        match = HEADER.fullmatch(line)
        if match:
            key = (match[1], int(match[2]), match[3])
            if key in cases:
                raise ValueError(f"{path}:{number}: duplicate case {key[0]}")
            current = {}
            cases[key] = current
            continue
        if current is None or " = " not in line:
            raise ValueError(f"{path}:{number}: invalid output line")
        field, value = line.split(" = ", 1)
        if field not in FIELDS[key[2]] or field in current:
            raise ValueError(f"{path}:{number}: unexpected/duplicate field {field}")
        if field == "valid":
            if value not in ("true", "false"):
                raise ValueError(f"{path}:{number}: valid must be true or false")
            current[field] = value == "true"
        else:
            if not re.fullmatch(r"(?:[0-9a-fA-F]{2})+", value):
                raise ValueError(f"{path}:{number}: {field} must contain hex byte pairs")
            current[field] = bytes.fromhex(value)
    if not cases:
        raise ValueError(f"{path}: no cases found")
    for key, fields in cases.items():
        if fields.keys() != FIELDS[key[2]]:
            raise ValueError(f"{path}: {key[0]} requires {sorted(FIELDS[key[2]])}")
    return {key: fields for key, fields in cases.items()
            if operation == "all" or key[2] == operation}


def compare(sw, hw):
    lines = []
    failed_cases = failed_fields = 0
    counts = {op: 0 for op in FIELDS}
    for key in dict.fromkeys([*sw, *hw]):
        label, level, operation = key
        counts[operation] += 1
        prefix = f"[{label}] level={level} operation={operation}"
        if key not in sw or key not in hw:
            lines.append(f"FAIL {prefix}: missing from {'software' if key not in sw else 'hardware'} file")
            failed_cases += 1
            continue
        failures = []
        for field in sorted(FIELDS[operation]):
            expected, actual = sw[key][field], hw[key][field]
            if expected == actual:
                continue
            failed_fields += 1
            if field == "valid":
                failures.append(f"valid: SW={str(expected).lower()} HW={str(actual).lower()}")
            else:
                offset = next((i for i, (a, b) in enumerate(zip(expected, actual)) if a != b),
                              min(len(expected), len(actual)))
                a = f"{expected[offset]:02x}" if offset < len(expected) else "<end>"
                b = f"{actual[offset]:02x}" if offset < len(actual) else "<end>"
                failures.append(f"{field}: SW={len(expected)} bytes HW={len(actual)} bytes; "
                                f"first difference at byte {offset} (0-based): SW={a} HW={b}")
        failed_cases += bool(failures)
        lines.append(f"{'FAIL' if failures else 'PASS'} {prefix}")
        lines.extend(f"  {failure}" for failure in failures)
    total = sum(counts.values())
    summary = (f"Cases: {total}; passed: {total - failed_cases}; failed: {failed_cases}; "
               f"mismatched fields: {failed_fields}\n"
               f"KeyGen: {counts['keygen']}; Sign: {counts['sign']}; Verify: {counts['verify']}")
    return summary, lines, failed_cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sw", type=Path, required=True, help="Software output text file")
    parser.add_argument("--hw", type=Path, required=True, help="Hardware output text file")
    parser.add_argument("--operation", choices=["all", *FIELDS], default="all",
                        help="Compare all cases present (default), or select one operation")
    parser.add_argument("--report", type=Path, default=Path("comparison_hw_sw.txt"))
    args = parser.parse_args()
    try:
        if args.report.resolve() in (args.sw.resolve(), args.hw.resolve()):
            raise ValueError("Report must not overwrite an input file")
        sw = read_cases(args.sw, args.operation)
        hw = read_cases(args.hw, args.operation)
        if not sw and not hw:
            raise ValueError(f"No {args.operation} cases found in either file")
        summary, lines, failures = compare(sw, hw)
        args.report.write_text(f"SW: {args.sw.resolve()}\nHW: {args.hw.resolve()}\n"
                               f"Operation: {args.operation}\n{summary}\n\n" +
                               "\n".join(lines) + "\n", encoding="utf-8")
        print(summary)
        for line in lines:
            if line.startswith(("FAIL", "  ")):
                print(line)
        print("Report:", args.report.resolve())
        return 1 if failures else 0
    except (OSError, ValueError) as error:
        print("ERROR:", error)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
