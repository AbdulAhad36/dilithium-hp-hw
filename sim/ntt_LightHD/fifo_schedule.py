"""Index-only reconstruction of the published LightHD three-FIFO NTT schedule.

Every queue entry is a 92-bit word's four coefficient *indices*. Arithmetic is
intentionally absent: this checks the FIFO ordering and capacity before RTL.
The LightHD article publishes the 32/32/16-word depths but omits the decoder
truth tables, so the read/write rules below are derived from its cited Ni et
al. 2023 FIFO-order description. A passing trace proves this reconstruction's
index pairing, not source-level identity with the authors' implementation.
"""

from __future__ import annotations

from collections import deque

N = 256
LANES = 4
WORDS = N // LANES
STAGE_CYCLES = N // (2 * LANES)
FIFO_DEPTHS = (32, 32, 16)
PIPELINES = (8, 9, 10)  # saved schedules and current first-fold pipeline


def expected_pairs(stage: int, inverse: bool) -> set[tuple[int, int]]:
    length = (1 << stage) if inverse else (128 >> stage)
    return {
        (base + j, base + j + length)
        for base in range(0, N, 2 * length)
        for j in range(length)
    }


def word_pairs(a: tuple[int, ...], b: tuple[int, ...], length: int) -> set[tuple[int, int]]:
    if length >= 4:
        return set(zip(a, b, strict=True))
    words = (a, b)
    return {
        (word[base + j], word[base + j + length])
        for word in words
        for base in range(0, LANES, 2 * length)
        for j in range(length)
    }


def input_words(inverse: bool) -> tuple[list[tuple[int, ...]], list[tuple[int, ...]]]:
    if inverse:
        first = [tuple(range(8 * g, 8 * g + 4)) for g in range(32)]
        second = [tuple(range(8 * g + 4, 8 * g + 8)) for g in range(32)]
    else:
        first = [tuple(range(4 * g, 4 * g + 4)) for g in range(32)]
        second = [tuple(range(128 + 4 * g, 132 + 4 * g)) for g in range(32)]
    return first, second


def source_fifos(stage: int, issue: int, inverse: bool) -> tuple[int, int]:
    length = (1 << stage) if inverse else (128 >> stage)
    if (inverse and stage <= 2) or (not inverse and (stage == 0 or stage >= 6)):
        return 0, 1
    group_cycles = length // LANES
    switch_cycles = group_cycles // 2 if inverse else group_cycles
    block = issue // switch_cycles
    return (0, 2) if block % 2 == 0 else (1, 0)


def destination_fifos(stage: int, issue: int, inverse: bool) -> tuple[int, int]:
    length = (1 << stage) if inverse else (128 >> stage)
    if inverse:
        if stage <= 1 or stage == 7:
            return 0, 1
        group_cycles = length // LANES
        group = issue // group_cycles
        return (0, 1) if group % 2 == 0 else (2, 0)
    if stage >= 5:
        return 0, 1
    group_cycles = length // LANES
    half = group_cycles // 2
    return (0, 1) if issue % group_cycles < half else (2, 0)


def run(inverse: bool, pipeline: int) -> tuple[int, ...]:
    first, second = input_words(inverse)
    fifos = [deque(first), deque(second), deque()]
    pending: dict[int, list[tuple[int, tuple[int, ...]]]] = {}
    seen: list[set[tuple[int, int]]] = [set() for _ in range(8)]
    peak = [len(q) for q in fifos]

    for tick in range(8 * STAGE_CYCLES + pipeline):
        if tick < 8 * STAGE_CYCLES:
            stage, issue = divmod(tick, STAGE_CYCLES)
            source_a, source_b = source_fifos(stage, issue, inverse)
            assert fifos[source_a] and fifos[source_b], (
                "underflow", inverse, tick, stage, issue,
                tuple(len(q) for q in fifos), (source_a, source_b),
            )
            a, b = fifos[source_a].popleft(), fifos[source_b].popleft()
            length = (1 << stage) if inverse else (128 >> stage)
            pairs = word_pairs(a, b, length)
            assert len(pairs) == LANES and all(y - x == length for x, y in pairs), (
                "wrong butterfly pairing", inverse, stage, issue, a, b, pairs,
            )
            assert not (pairs & seen[stage]), ("duplicate pairs", inverse, stage, pairs)
            seen[stage].update(pairs)
            dest_a, dest_b = destination_fifos(stage, issue, inverse)
            pending.setdefault(tick + pipeline, []).extend(((dest_a, a), (dest_b, b)))

        # Outputs become available after the current cycle's FIFO reads. This
        # assumes no same-edge fall-through from butterfly to FIFO read port.
        for fifo_id, word in pending.pop(tick, []):
            fifos[fifo_id].append(word)
        for fifo_id, fifo in enumerate(fifos):
            peak[fifo_id] = max(peak[fifo_id], len(fifo))
            assert len(fifo) <= FIFO_DEPTHS[fifo_id], (
                "FIFO overflow", inverse, tick, fifo_id, len(fifo),
            )

    for stage in range(8):
        assert seen[stage] == expected_pairs(stage, inverse), (
            "stage coverage mismatch", inverse, stage,
            len(expected_pairs(stage, inverse) - seen[stage]),
        )
    assert [len(q) for q in fifos] == [32, 32, 0]
    if inverse:
        result = [index for fifo in fifos[:2] for word in fifo for index in word]
    else:
        result = [index for pair in zip(fifos[0], fifos[1], strict=True)
                  for word in pair for index in word]
    assert result == list(range(N)), ("output order", inverse, result[:32])
    print(f"{'INTT' if inverse else 'NTT'} FIFO INDEX PASS: "
          f"8 stages, 128 pairs/stage, peak words {peak}, "
          f"{8 * STAGE_CYCLES + pipeline} scheduled cycles")
    return tuple(peak)


def run_pre_ntt(pipeline: int) -> tuple[int, ...]:
    """Check the small-secret first-stage LUT output regrouping and 7 stages."""
    first, second = input_words(inverse=False)
    fifos = [deque(), deque(), deque()]
    seen = [set() for _ in range(8)]
    for issue, (a, b) in enumerate(zip(first, second, strict=True)):
        seen[0].update(word_pairs(a, b, 128))
        da, db = destination_fifos(0, issue, inverse=False)
        fifos[da].append(a)
        fifos[db].append(b)
    assert seen[0] == expected_pairs(0, inverse=False)
    assert [len(q) for q in fifos] == [32, 16, 16]
    pending: dict[int, list[tuple[int, tuple[int, ...]]]] = {}
    peak = [len(q) for q in fifos]
    for tick in range(7 * STAGE_CYCLES + pipeline):
        if tick < 7 * STAGE_CYCLES:
            stage, issue = divmod(tick, STAGE_CYCLES)
            stage += 1
            sa, sb = source_fifos(stage, issue, inverse=False)
            assert fifos[sa] and fifos[sb], ("pre-NTT underflow", tick)
            a, b = fifos[sa].popleft(), fifos[sb].popleft()
            pairs = word_pairs(a, b, 128 >> stage)
            assert len(pairs) == LANES
            assert not (pairs & seen[stage])
            seen[stage].update(pairs)
            da, db = destination_fifos(stage, issue, inverse=False)
            pending.setdefault(tick + pipeline, []).extend(((da, a), (db, b)))
        for fifo_id, word in pending.pop(tick, []):
            fifos[fifo_id].append(word)
        for fifo_id, fifo in enumerate(fifos):
            peak[fifo_id] = max(peak[fifo_id], len(fifo))
            assert len(fifo) <= FIFO_DEPTHS[fifo_id], ("pre-NTT overflow", tick)
    assert all(seen[stage] == expected_pairs(stage, inverse=False)
               for stage in range(8))
    result = [index for pair in zip(fifos[0], fifos[1], strict=True)
              for word in pair for index in word]
    assert result == list(range(N))
    print(f"PRE-NTT FIFO INDEX PASS: stage-0 regrouping and 7 remaining stages, "
          f"peak words {peak}, {7 * STAGE_CYCLES + pipeline} scheduled cycles")
    return tuple(peak)


if __name__ == "__main__":
    for pipe in PIPELINES:
        forward_peak = run(inverse=False, pipeline=pipe)
        inverse_peak = run(inverse=True, pipeline=pipe)
        pre_peak = run_pre_ntt(pipeline=pipe)
        if pipe in (9, 10):
            # The legal controller is data independent and has no pause in
            # RUN. All 256 issues and the complete drain are enumerated above.
            # FIFO3 is not used by standard loading/output, so this establishes
            # its whole-job upper bound under the supported external protocol.
            assert forward_peak == inverse_peak == (32, 32, 11)
            assert pre_peak == (32, 32, 16)
            print(f"FIFO REACHABILITY PASS: PIPE={pipe} standard FIFO3 peak=11/16; "
                  "full is unreachable in legal NTT/INTT jobs; Pre peaks=32/32/16")
