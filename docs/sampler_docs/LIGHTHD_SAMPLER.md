# LightHD sampler architecture: what they do and how you can improve it

After examining **Section III.C, Figures 3 and 4, and Table II** of the LightHD 2026 paper, I see several opportunities worth investigating for your Dilithium accelerator.

LightHD already has a clever sampler. Its strongest feature is that **two Keccak cores can share sampling hardware without duplicating the entire rejection sampler**.

However, the design is optimized for a particular 64 bit Keccak interface and a carefully scheduled sampling flow. Your 128 bit dual Keccak architecture gives you room to explore a different approach.

The three improvements I would investigate first are:

1. **A 128 bit parallel rejection sampler** that can process more SHAKE candidates per cycle.
2. **An elastic shared sampler**, capable of handling different Keccak output schedules while preserving each polynomial's state.
3. **Improved sampler integration with your existing LightHD NTT architecture**, so sampling, coefficient packing and NTT execution overlap efficiently. **Correction:** Your NTT is an implementation of the same LightHD NTT architecture, not a different conflict free addressed memory or two stage tile design.

These are proposed improvements, not proven deficiencies in LightHD. You would need to compare RTL implementations to establish actual gains.

## 1. How LightHD performs sampling

**SOURCE: FIGURES 1, 3 AND 4, PAGES 4 TO 6**

Their architecture is conceptually:

```text
      Keccak core 0             Keccak core 1
       64 bit output             64 bit output
              \                  /
               \                /
                 Interleaved
                SHAKE output
                     |
                     v
                Shared sampler
       Candidate extraction and validity
                     |
          Buffer + counter
        BufferA + cntA (saved state)
                     |
                     v
          Polynomial coefficients
                     |
                     v
          Pack and store in memory
               for later arithmetic
```

The paper uses four sampling functions.

| Function | Purpose | What the paper says about its implementation |
|---|---|---|
| Matrix A rejection sampler | Generate uniform coefficients modulo \(q\) | Handles eight candidates from three 64 bit words |
| Secret rejection sampler | Generate \(s_1,s_2\) | Divides a 64 bit word into four 16 bit groups processed in parallel |
| SamplingMask | Generate signing vector \(y\) | Included as a dedicated sampling function |
| SampleInBall | Generate sparse challenge \(c\) | Uses distributed RAM |

The paper describes the rejection samplers in detail but does not provide equally detailed cycle level datapaths for SamplingMask and SampleInBall. That is important when evaluating which optimizations are genuinely new.

**Source:** LightHD 2026, Section III.A and III.C, pages 4 and 5.

## 2. Their main trick: sharing the rejection sampler

Imagine Keccak 0 is producing random bytes for polynomial A0.

Its sampler has reached:

```text
Polynomial A0
Accepted coefficients = 120
Partial buffer = some remaining bytes
```

Then Keccak 1 starts producing bytes for polynomial A1.

The sampler cannot simply overwrite A0's counter and buffer, or it will lose its progress.

LightHD solves this by having two sets of state:

| Current state | Saved state |
|---|---|
| `Buffer` | `BufferA` |
| `cnt` | `cntA` |

When the output switches from polynomial A0 to A1, the sampler exchanges these values.

That allows the expensive rejection and selection logic to be reused while the two polynomial streams retain their own progress.

In Figure 4, the paper shows one stream being processed for 17 output beats, followed by a gap and 17 beats from the other stream. It also describes the `Change_flag` signal used to exchange the sampler state.

**This is already a strong area optimization.** I would not try to improve it by simply duplicating the complete sampler. The more interesting opportunity is to make the shared sampler more flexible and improve how much data it can process.

**Source:** LightHD 2026, Section III.C and Figure 4, pages 5 and 6.

## 3. Where LightHD has room for improvement

### Opportunity A: Their sampling datapath is built around 64 bit SHAKE output

LightHD processes 64 bit SHAKE words. For matrix A, it combines three words to obtain eight 24 bit candidates.

**LightHD matrix A sampling:**

```text
  64 bits       64 bits       64 bits
     \             |             /
      \            |            /
              192 total bits
                    |
                    v
       8 candidates, 24 bits each
                    |
                    v
          Validate and compact
                    |
                    v
         Pack accepted coefficients
```

This is good for LightHD's 64 bit interface.

But your complete dual Keccak design has a 128 bit output interface.

A 128 bit word contains 16 bytes. Matrix A sampling needs three bytes per candidate.

Therefore:

\[
\frac{16}{3}=5.33\text{ candidates per clock on average}
\]

An efficient 128 bit candidate extractor could operate like this:

| Input clock | New bytes | Candidates extracted | Leftover bytes |
|---|---:|---:|---:|
| 1 | 16 | 5 | 1 |
| 2 | 16 | 5 | 2 |
| 3 | 16 | 6 | 0 |
| Total | 48 | 16 | 0 |

These are candidates before rejection, assuming one complete 128 bit input beat arrives each clock.

This gives you a potential improvement:

**A 128 bit candidate extractor with parallel validity checking and compaction.**

Instead of validating candidates using a 64 bit front end, you can extract five or six candidates when a full 128 bit word arrives.

For example:

```text
128 bit SHAKE output
        |
        v
Byte alignment buffer
        |
        v
24 bit candidate extraction
        |
   +----+----+----+----+----+
   |    |    |    |    |    |
  C0   C1   C2   C3   C4   C5
   |    |    |    |    |    |
   v    v    v    v    v    v
  Validity checking in parallel
        |
        v
   Valid compactor
        |
        v
  Polynomial write buffer
```

A detail specific to your design makes this interesting.

You previously measured SHAKE128 output throughput of approximately 1.3 GB/s at 148 MHz. That corresponds to about 8.78 output bytes per clock on average.

A single 64 bit sampler input can consume at most eight bytes per clock at that frequency. Therefore, if your matrix sampling workload sustained that same byte production rate, an equivalent 64 bit input would become a bottleneck.

**But this is not proof that your existing sampler needs six parallel candidate lanes.** The SHAKE sampling workload may produce a different activity pattern from your long output throughput benchmark. Measure its burst rate and backpressure first.

The cost of a wider candidate extractor is additional comparators, selection logic and routing.

### Opportunity B: Their interleaving follows a carefully controlled schedule

LightHD's Keccak cores operate with a fixed 26 cycle offset. They exchange sampler context according to the planned output schedule.

**Source:** LightHD 2026, Section III.C and Figure 3, page 5.

This is efficient because the authors know when the two data streams should arrive.

For your architecture, I would investigate making the sampler **stream aware rather than depending on predetermined switching points**.

For example, imagine the following output sequence:

```text
Clock      Source       Polynomial

100        Keccak 0     A0
101        Keccak 0     A0
102        Keccak 1     A1
103        Keccak 0     A0
104        Keccak 1     A1
105        Keccak 1     A1
```

A flexible sampler can handle this if every accepted beat has a stream identifier and each active stream has its own context.

For example:

```text
Sampler context 0
    polynomial ID
    leftover bytes
    accepted count
    output address

Sampler context 1
    polynomial ID
    leftover bytes
    accepted count
    output address
```

When a beat arrives, the sampler chooses the correct context, processes the data, then writes the updated state back.

This can allow independently scheduled Keccak jobs, variable output timing and better tolerance of stalls.

However, **LightHD does not demonstrate that arbitrary scheduling is required for its workload**, so this would be a flexibility improvement rather than a demonstrated speed improvement.

It also introduces control complexity. If switching contexts every clock becomes expensive, you could process short batches of beats from one stream before switching.

### Opportunity C: Improve the sampler's area efficiency

This is another interesting detail from the paper.

**LightHD synthesis resources**

Xilinx Artix 7, Table II, page 10.

| Module | Area |
|---|---:|
| Dual SHA3 | 6,019 LUTs |
| Entire sampling block | 4,035 LUTs |
| Polynomial multiplication | 2,601 LUTs |
| Total signer side | 20,623 LUTs |

The complete sampling block also uses 1,157 flip flops and no dedicated BRAM blocks, although its SampleInBall uses distributed RAM.

**Source:** LightHD 2026, Table II, page 10.

So the sampler itself accounts for approximately 20% of the entire signer's LUT count.

That means saving sampler area could make a noticeable difference.

One architecture worth testing would use separate, relatively small decoding paths for the different sampling operations, while sharing only the resources that benefit from sharing.

For example:

```text
              SHAKE data
                  |
                  v
              Mode router
                  |
       +----------+----------+
       |          |          |
       v          v          v
     A / s       Mask      Challenge
   rejection    unpacker    engine
       |          |          |
       +----------+----------+
                  |
                  v
           Output formatter
                  |
                  v
             Memory writer
```

The matrix and secret samplers need rejection logic. Mask sampling needs bit extraction and subtraction. SampleInBall needs indexed coefficient updates.

You could compare a unified architecture against specialized mode datapaths and see which provides the better balance of ALMs, registers, Fmax and cycles.

The main caution is that **full resource sharing is not automatically smaller**. The muxes necessary to support several modes can become expensive.

## 4. The improvement most relevant to your NTT

**Correction to the previous explanation:** Your NTT design is exactly based on LightHD's NTT architecture. It is **not** a separate conflict free addressed memory and two stage tile design. LightHD uses four butterfly units, FIFO based memory and its Pre NTT optimization. Therefore we should not claim that your current NTT offers an architectural advantage over LightHD's NTT.

That means the opportunity lies in **improving the interface and scheduling between your sampler and this existing NTT architecture**, rather than claiming that your NTT is already different.

Normally:

```text
Keccak
   |
   v
Sampler
   |
   v
Store all 256 coefficients
   |
   v
Read coefficients for NTT
   |
   v
NTT processing
```

You could investigate:

```text
Keccak
   |
   v
Parallel sampler
   |
   v
Coefficient compactor
   |
   v
NTT compatible regrouping / packing
   |
   v
Existing LightHD FIFO / memory interface
   |
   v
Existing LightHD NTT datapath
```

The advantage to test is not that you possess a different NTT. It is whether a wider sampler and a better input schedule can feed the **same LightHD NTT** more efficiently, reduce stalls or minimize intermediate buffering.

**But LightHD already does some of this.** Its Pre NTT logic regroups sampled small coefficient polynomials so the NTT can skip its first stage. The paper reports 235 cycles rather than 264 for those inputs.

**Source:** LightHD 2026, Section III.D, Figures 5 and 6, pages 8 and 9.

It also overlaps sampling and NTT execution, allowing NTT to start approximately 380 cycles earlier at security level 5 than waiting for all relevant sampling to finish.

**Source:** LightHD 2026, Section IV, page 9.

So you cannot claim that LightHD lacks sampler to NTT integration.

To improve on it, your work would need to demonstrate something more, such as faster candidate generation, better input scheduling, fewer data rearrangement cycles, fewer stalls or reduced intermediate storage **while retaining the same NTT engine**.

## 5. A limitation worth investigating: waiting for the NTT

One actual scheduling behavior described in LightHD is that during Verify, the SHA3 module can pause while the NTT processes the current polynomial work, then resume when the necessary computation finishes.

**Source:** LightHD 2026, Section IV, pages 9 and 10.

That creates a possible improvement opportunity.

Rather than immediately stopping SHAKE, you might introduce a small elastic buffer:

```text
Keccak 0     Keccak 1
    |            |
    +------+-----+
           |
           v
     Input FIFO
           |
           v
        Sampler
           |
           v
  Coefficient FIFO
           |
           v
       NTT memory
```

The FIFO could absorb short periods of output contention or memory unavailability.

For example:

```text
Clock 100: Keccak produces data
Clock 101: Keccak produces data
Clock 102: NTT memory is busy
Clock 103: NTT memory is busy
Clock 104: NTT memory becomes available
```

Your buffer can preserve the already generated coefficients while NTT memory is busy.

This can improve utilization if the stalls are short and the buffer is sufficiently deep.

However, a FIFO does not eliminate a sustained bandwidth mismatch. If NTT is the bottleneck for a long time, the FIFO eventually fills and Keccak must still stop.

The improvement would have to be demonstrated by fewer idle cycles or better overall KeyGen and Verify latency.

## 6. What I would be careful not to change

LightHD explicitly states that its secret dependent operations use constant timing and that its sampler consumes a fixed amount of SHA3 output in its chosen schedule.

**Source:** LightHD 2026, Section V, page 10.

So don't make your sampler faster by accidentally compromising cryptographic correctness.

In particular, rejection sampling must preserve the required distribution. A fixed sampling budget must also handle the exceptional case where not enough candidates are accepted. You cannot return an incomplete or incorrectly padded polynomial.

The reference to follow is [NIST FIPS 204](https://nvlpubs.nist.gov/nistpubs/fips/nist.fips.204.pdf), which defines the rejection and sampling algorithms.

Another detail: the paper's preliminary description appears to reverse the SHAKE variants for `ExpandA` and `ExpandS`. The official FIPS 204 algorithms use SHAKE128 for matrix A and SHAKE256 for the secret sampler. Follow FIPS 204 when designing the RTL, rather than that sentence in the paper.

**Source:** LightHD 2026, Section II.A, page 3, and NIST FIPS 204.

## 7. What I would actually build first for your project

Given your existing dual Keccak and your **LightHD based NTT implementation**, this would be my proposed experimental architecture:

```text
              Keccak 0      Keccak 1
                  \          /
                   \        /
                Tagged input router
          128 bit stream with job ID
                       |
                       v
                 Context storage
       Independent counters and residual bytes
                       |
                       v
              Parallel candidate
                  processing
        Extraction, validation, compaction
                       |
                       v
               Coefficient FIFO
             and NTT compatible
              input regrouping
                       |
                       v
               Existing LightHD
               NTT FIFO / memory
                and NTT datapath
```

The most useful performance report would be a comparison of several configurations:

| Measurement | Basic sampler | Proposed sampler |
|---|---|---|
| Matrix A polynomial cycles | Measure | Measure |
| Secret polynomial cycles | Measure | Measure |
| Accepted coefficients per cycle | Measure | Measure |
| Keccak stalled cycles | Measure | Measure |
| NTT idle cycles | Measure | Measure |
| Fmax | Quartus | Quartus |
| ALMs and M10Ks | Quartus | Quartus |
| Full KeyGen latency | Measure | Measure |
| Full Sign latency | Measure | Measure |
| Full Verify latency | Measure | Measure |

You could test a 64 bit baseline, a 128 bit input with shared context, and then the version with NTT compatible packing. That would isolate the benefit and hardware cost of each modification.

Most importantly, the Keccak only throughput results of 1.3 GB/s for SHAKE128 and 1.1 GB/s for SHAKE256 do not tell you the sampler's performance yet. You need to measure how the Keccak behaves when supplying real Dilithium sampler workloads.

### My preferred research direction

I would prioritize **an efficient 128 bit, stream aware rejection sampler with improved scheduling and direct integration into the existing LightHD NTT interface**.

It's well matched to your existing hardware, has measurable architectural questions, and allows you to compare throughput, memory traffic and area rather than merely claiming that your sampler is wider.

I would leave aggressive SampleInBall optimization for a later phase, because that procedure has sequential shuffle dependencies and the paper doesn't reveal enough about its implementation to establish a meaningful baseline from the publication alone.

The goal is not just to beat LightHD's sampler in isolation. It is to demonstrate that **your Keccak, sampler and the same NTT architecture used by LightHD work together more efficiently**, especially in complete KeyGen, Sign and Verify operations. That would be a stronger result for your Dilithium research.

---

## Sources

1. Ziying Ni et al., *LightHD: A Lightweight and High-Performance Hardware Accelerator of CRYSTALS-Dilithium*, IEEE Transactions on Computers, Vol. 75, No. 5, May 2026. DOI: [10.1109/TC.2026.3666457](https://doi.org/10.1109/TC.2026.3666457). Especially Section III.C and Section III.D, Figures 1, 3, 4, 5 and 6, Section IV, and Table II.
2. [NIST FIPS 204, Module Lattice Based Digital Signature Standard](https://nvlpubs.nist.gov/nistpubs/fips/nist.fips.204.pdf).
