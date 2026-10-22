# NTT — Explained From Scratch

A plain-language guide to the Number Theoretic Transform (NTT) and how this
project's hardware implements it. No math background assumed. If you can read
a list of numbers, you can read this.

> For the formal RTL/verification details see
> [ntt-design-and-verification.md](ntt-design-and-verification.md). This file is
> the intuition; that file is the spec.

---

## Part 1: What are we even working with?

In Dilithium (the digital signature algorithm we're building hardware for), the
basic "thing" we manipulate is **a list of 256 numbers**.

That's it. A list. Like:

```
[ 5, 12, 3, 99, 41, ... ]   ← 256 numbers long
```

Mathematicians call this list a "polynomial," but don't let that word scare you.
**It's just a list of 256 numbers.** Every number in the list is somewhere
between 0 and 8,380,416 (we'll explain that weird upper limit later).

Dilithium spends almost all its time doing one operation: **multiplying two of
these lists together.**

---

## Part 2: Why multiplying two lists is a nightmare

When you "multiply" two lists of 256 numbers, it's NOT like multiplying them
element by element. It's messier — every number in list A has to interact with
every number in list B.

Think of it like a handshake party: list A has 256 people, list B has 256
people, and **every A-person must shake hands with every B-person.**

That's `256 × 256 = 65,536` handshakes. Every handshake is a multiplication. On
a chip running at 100 million cycles per second, doing 65,536 multiplications
*every single time* you multiply two lists — and Dilithium does this thousands
of times per signature — is **way too slow.**

We need a shortcut.

---

## Part 3: The shortcut idea (the "aha")

Here's the key trick. An analogy you might know.

**Remember logarithms from school?** The whole point was: multiplying big
numbers is hard, but *adding* is easy. So you'd:

1. Convert both numbers to their logarithm ("log domain")
2. **Add** them (easy!)
3. Convert back

You turned a hard problem (multiply) into an easy one (add) by **going into a
different "world," doing the easy thing, and coming back.**

**The NTT does exactly this for our lists.**

- The hard thing: "handshake-party" multiplication of two lists (65,536 ops)
- The NTT trick:
  1. Transform list A into a different "world" → the **NTT domain**
  2. Transform list B into that same world
  3. In that world, multiplication becomes **dead simple**: just multiply
     position-by-position. `A[0]×B[0]`, `A[1]×B[1]`, … — only **256
     multiplications**, not 65,536.
  4. Transform the result back to the normal world

The transform "in" and "out" isn't free — but it costs only about 1,000
operations each, way cheaper than 65,536.
**Total: ~2,300 operations instead of 65,536. Roughly 28× faster.**

So **NTT = the magic doorway** that turns hard list-multiplication into easy
position-by-position multiplication.

`NTT` stands for "Number Theoretic Transform." Ignore the name. It's just "the
doorway."

---

## Part 4: How does the doorway actually work?

The transform works by **mixing the list with itself**, in rounds.

Picture your 256 numbers in a tall column. The NTT does **8 rounds of mixing**
(8 because 256 = 2 multiplied by itself 8 times).

In each round, you go through the list, **grab numbers in pairs**, and run each
pair through a tiny machine called a **butterfly**. The butterfly takes the two
numbers in and spits two mixed-up numbers back out.

Why 8 rounds? Because one round only mixes neighbors a little. After 8 rounds,
*every* number has been blended with *every* other number — which is what fully
"transforms" the list into the new world.

---

## Part 5: The butterfly — the tiny mixing machine

This is the heart of everything. The butterfly takes **two numbers** (call them
`a` and `b`) plus one **special spinning number** (called a *twiddle factor*,
written `ζ` — Greek letter "zeta"), and produces two new numbers.

For the **forward** trip through the doorway, the butterfly does this:

```
First, spin b:        t = b × ζ
Then mix:             new_a = a + t
                      new_b = a − t
```

It literally just: takes b, rotates it by the twiddle, then makes a sum and a
difference. Two numbers in, two numbers out. That's a butterfly. (The name comes
from the shape when you draw the wiring — two lines crossing like wings.)

The **twiddle factor `ζ`** is a "spinning" number. Different butterflies use
different twiddles. We pre-computed all 256 of them and baked them into a lookup
table in the chip — that's the `twiddle_rom` file. The chip just looks up
"which twiddle do I need right now" instead of calculating it.

---

## Part 5b: Where the twiddle factors come from

### When is a twiddle applied?

Inside **every** butterfly, as its **first step**: `t = b × ζ`. One butterfly
uses exactly one twiddle. A full forward transform = 1,024 butterflies = 1,024
twiddle multiplications.

### Which twiddle? — butterflies are grouped

Not every butterfly in a round uses the same twiddle. Each round splits its 128
butterflies into **groups**, and a group shares one twiddle:

| Round | Pair gap | # groups | Butterflies/group | Distinct twiddles |
|---|---|---|---|---|
| 0 | 128 | 1   | 128 | **1**   |
| 1 | 64  | 2   | 64  | 2   |
| 2 | 32  | 4   | 32  | 4   |
| 3 | 16  | 8   | 16  | 8   |
| 4 | 8   | 16  | 8   | 16  |
| 5 | 4   | 32  | 4   | 32  |
| 6 | 2   | 64  | 2   | 64  |
| 7 | 1   | 128 | 1   | **128** |

So round 0 = one group (all 128 butterflies share one twiddle); round 7 = 128
groups (every butterfly has its own). Total distinct twiddles used:
`1+2+…+128 = 255` — which is why the ROM holds ~256 entries. The controller
walks a counter `k` through the ROM, bumping it by 1 each time it starts a new
group.

### How each twiddle value is computed

The twiddles are computed **once, offline**, by a script — never on-chip. Two
constants from `ntt_pkg.sv`:

- `q = 8,380,417` — the modulus
- `ζ = 1753` — a **512th root of unity** (see Part 5c for why 512)

The recipe (from the `twiddle_rom.sv` header):

```
twiddle[i] = ζ ^ bitreverse8(i)   mod q          for i = 0 .. 255
```

Two operations:

1. **`ζ ^ k mod q`** — raise 1753 to a power, wrapping mod q (repeated
   multiply-and-wrap).
2. **`bitreverse8(i)`** — take the 8-bit index `i` and flip its bit order.
   E.g. `i = 1 = 00000001` → reversed `10000000 = 128`.

Worked examples (check them against the ROM table):

- `twiddle[0]   = ζ^bitrev(0)   = ζ^0   = 1`
- `twiddle[1]   = ζ^bitrev(1)   = ζ^128 = 4,808,194`
- `twiddle[128] = ζ^bitrev(128) = ζ^1   = 1753`

The bit-reversal **pre-shuffles** the powers of ζ into exactly the order the
rounds consume them — so the forward controller can walk the table `0,1,2,3,…`
in plain ascending order. The script runs this formula 256 times and dumps the
results as the constant `rom = '{ ... }` array in `twiddle_rom.sv`. At runtime
the ROM is a pure lookup: present an address, get the twiddle one clock later.

---

## Part 5c: Why a 512th root of unity (not 256th)?

Dilithium's polynomials live in the ring `Z_q[x] / (x²⁵⁶ + 1)`. That **`+1`** is
the whole reason.

When you multiply two degree-256 polynomials, terms overshoot degree 256 and
must fold back down. Two kinds of fold:

- **Cyclic ring `x²⁵⁶ − 1`:** `x²⁵⁶ = +1` — overshooting terms wrap back
  **unchanged**. Plain wrap-around, like a clock.
- **Negacyclic ring `x²⁵⁶ + 1`** (Dilithium's): `x²⁵⁶ = −1` — overshooting
  terms wrap back **negated**. They flip sign.

The plain NTT trick is built for the cyclic case. To absorb the negation we need
a special number `ζ` with:

```
ζ²⁵⁶ = −1      ← absorbs the "+1" in the ring
ζ⁵¹² = +1      ← ...which (since (−1)² = 1) makes ζ a 512th root of unity
```

A 256th root `ω` only gives `ω²⁵⁶ = +1` — useless for the negation. Only a
**512th root** has the `ζ²⁵⁶ = −1` property. And `512 = 2 × 256 = 2n`.

Intuitively `ζ` is the **square root** of the ordinary 256th root (`ζ² = ω`) —
that extra "half a root" is the **negacyclic twist**. Because the twiddles are
powers of the 512th root, every butterfly automatically carries the sign-twist,
so the `+1` in the ring is handled for free — no separate "apply minus signs"
pass. `ζ = 1753` is exactly such a number mod `q`.

---

## Part 6: One round, in detail

Let's do round 0. We have 256 numbers. We pair them up like this:

```
pair number 0   → and number 128
pair number 1   → and number 129
pair number 2   → and number 130
...
pair number 127 → and number 255
```

That's **128 pairs**, so **128 butterflies** in this round.

Round 1 pairs them differently (closer together). Round 2 closer still. By
round 7, pairs are right next to each other: (0,1), (2,3), (4,5)…

**Every round = 128 butterflies. 8 rounds = 1,024 butterflies per list.**
That's the whole forward transform for one list.

After all 8 rounds, your list is now "in the NTT world."

### It happens in place — each round feeds the next

`a` and `b` are the two numbers of a pair. The butterfly **writes its two
outputs (`new_a`, `new_b`) back into the same memory slots it read from.** So
after round 0, the 256-number list has been completely overwritten with mixed
values — round 1 reads *those*, never the original input.

The key move: each round **re-pairs** the list with a smaller gap. Follow slot 0:

```
Round 0:  slot 0 paired with slot 128   (gap 128)
Round 1:  slot 0 paired with slot 64    (gap 64)
Round 2:  slot 0 paired with slot 32
Round 3:  slot 0 paired with slot 16
Round 4:  slot 0 paired with slot 8
Round 5:  slot 0 paired with slot 4
Round 6:  slot 0 paired with slot 2
Round 7:  slot 0 paired with slot 1     (gap 1)
```

Round 0 blends slot 0 with the far half of the list; by round 7 it blends with
its immediate neighbour. Across all 8 rounds — through this chain — every slot
ends up blended with all 256 values. One list, the same 256 memory slots,
rewritten in place 8 times:

```
input ──round 0──► v1 ──round 1──► v2 ──► ... ──round 7──► Â (transformed)
```

---

## Part 7: Coming back out (the inverse NTT)

Once you've multiplied two lists position-by-position in the NTT world, you need
to come back to the normal world. That's the **inverse NTT** (`OP_INTT`). It's
the same 8 rounds of butterflies, with **three differences** from forward:

### 1. The butterfly is reordered — GS instead of CT

Forward uses the **Cooley–Tukey (CT)** butterfly — *spin, then mix*:

```
t     = b × ζ
new_a = a + t
new_b = a − t
```

Inverse uses the **Gentleman–Sande (GS)** butterfly — *mix, then spin*:

```
new_a = a + b
new_b = (a − b) × ζ        ← subtract FIRST, then multiply by twiddle
```

Same three operations (add, subtract, twiddle-multiply), just **reordered** —
and that reordering is exactly what makes GS *undo* what CT did. The same
`butterfly_unit.sv` hardware does both; a mode bit (`BF_CT` / `BF_GS`) switches
it.

### 2. The rounds run with the gap *growing*

Forward gaps shrink `128 → 64 → … → 1`. Inverse gaps grow `1 → 2 → … → 128`.
The twiddles are walked in the **mirrored order**, and each inverse twiddle is
the **modular negation** of the forward one (`inverse_ζ = q − ζ`). The core does
that negation itself — no second ROM, the same 256-entry table is reused.

### 3. A final SCALE step

After the 8 GS rounds the result has the right pattern but every number is too
big by a factor of 256. The last step multiplies **all 256 coefficients** by one
fixed constant:

```
N_INV = 8,347,681      (= 256⁻¹ mod q,  from ntt_pkg.sv)
```

`OP_INTT` includes this `1/N` scaling automatically.

### The magic guarantee

```
list ──forward NTT (CT, gap shrinks)──► Â ──inverse NTT (GS, gap grows, +SCALE)──► list
```

**Transform a list in and straight back out, and you get the exact same list.**
That round-trip is the first thing the testbench checks — the "did we wire this
up right" sanity test.

---

## Part 8: The whole multiply, end to end

Putting Parts 4–7 together, multiplying list A by list B is **four steps**:

```
1.  List A  ──8 rounds of CT butterflies──►  Â     (A in NTT world)
2.  List B  ──8 rounds of CT butterflies──►  B̂     (B in NTT world)

3.  Ĉ = Â * B̂   ← position-by-position:
                  Ĉ[0]=Â[0]×B̂[0], Ĉ[1]=Â[1]×B̂[1], ...
                  just 256 cheap multiplications

4.  Ĉ  ──8 rounds of GS butterflies + SCALE──►  C  (the real answer)
```

Key facts to keep straight:

- **A and B are transformed independently.** A's NTT has nothing to do with
  B's. You **never** put a number from A and a number from B into the same
  butterfly during the transform. They are two separate trips through the
  doorway.
- **Butterfly count:** 1,024 per forward transform. Two lists → 2,048
  butterflies for the forward stage. Plus another 1,024 for the inverse.
- The cheap part (step 3) is the *only* place A and B numbers meet — and even
  there it's just `A[i]×B[i]`, position by position.

---

## Part 9: One detail — the weird number 8,380,417

Every number in our lists stays between 0 and 8,380,416. Whenever a butterfly's
sum or product gets bigger than that, we **wrap it around** (like a clock: after
12 comes 1 again). This wrapping is called "modulo."

That number, `q = 8,380,417`, is special — it was hand-picked so the whole NTT
trick mathematically works. Wrapping around it is called **modular reduction**,
and doing it fast is itself a small puzzle — that's what the `mod_mul` file
(a q-specific shift-and-add reduction) solves. For now just know: **every add
and multiply in a butterfly is followed by a "wrap it back into range" step.**

---

## Part 10: How the HARDWARE does all this

Our design is two boxes, one inside the other.

### Outer box — `ntt_engine` — the receptionist

- Receives the 256 numbers one at a time over a wire (the "stream"), stacks them
  into memory.
- Says "go" to the inner box.
- Waits for "done."
- Reads the 256 results back out, sends them out over the wire.

### Inner box — `ntt_core` — the worker

- Holds the 256 numbers in a memory.
- Has a **2×2 butterfly tile** (four butterfly machines), the **twiddle lookup
  table** (`twiddle_rom`), and a **controller** (a state machine).
- Each clock tick: pull **4 coefficients** from memory → look up the twiddles →
  run them through the **4 butterflies** → write the results back to memory.
- The tile does **2 NTT stages at once**, so the 8 stages collapse into
  **4 memory passes** (`N_PASSES = 4` in `ntt_pkg.sv`), not 8.
- After the 4 passes (and the SCALE step if going backwards): raise the
  "done" flag.

### Source files

| File | Role |
|---|---|
| `ntt_engine.sv` | Outer box — stream in/out, start/done handshake |
| `ntt_core.sv`   | Inner box — memory + controller + datapath |
| `butterfly_unit.sv` | The CT/GS butterfly mixing machine |
| `twiddle_rom.sv` | Pre-computed table of all twiddle factors `ζ` |
| `mod_mul.sv` | Fast "wrap back into range" (q-specific shift-add modular reduction) |
| `ntt_pkg.sv` | Parameters: `q = 8,380,417`, `N = 256`, etc. |

---

## Part 11: Sequential vs. parallel — what runs when

**The two forward transforms (A and B) run *sequentially*, not in parallel.**

There is **one `ntt_core`** — one worker box, with **one 2×2 butterfly tile**
inside it. That single core can only transform one list at a time:

```
1. Load list A into the core's memory
2. Core runs 8 rounds on A   → Â        (1,024 butterflies)
3. Read Â out, load list B in
4. Core runs 8 rounds on B   → B̂        (1,024 butterflies)
5. ... then the cheap multiply, then the inverse
```

A finishes completely, *then* B starts. Same hardware reused for both — and
reused again for the inverse transform (the core just switches from "CT mode"
to "GS mode"). It is **one machine doing three jobs in sequence**, not three
separate machines.

**Why not two cores in true parallel?** You could — that's 2× the chip area
(two butterfly tiles, two memories) for 2× the speed. A classic area-vs-speed
tradeoff. Our design keeps **one core** because the priority is *correct first*,
and because — see below — one core is already reasonably fast.

### How fast is one core?

The core does **4 butterflies every clock tick** (the 2×2 tile), and collapses
the 8 NTT stages into **4 memory passes**. So a full transform is roughly
`4 passes × 64 ticks ≈ 256 clock cycles` plus a little control overhead — in
the same ballpark as the best published designs (EMINEM 271, the 4-butterfly
memory designs ~270). It is **not** a slow "one butterfly at a time" first
version; the 2×2 tile is the design from the start, because that is current
best practice (see the design-and-verification doc, §4).

The parallelism is **inside one transform** (4 butterflies at once) — *not*
across the two lists. A and B still run sequentially on the one core; each
individual transform is just done 4-wide.

### Two ways this could have been built — and why we chose ours

There are two hardware styles for an NTT (the design doc calls them Family A and
Family B):

| | **Iterative / memory-based** (our choice) | **Streaming / pipelined (MDC)** |
|---|---|---|
| Idea | coefficients sit still in memory; **one** butterfly tile **loops** over them, stage after stage | **8** butterfly blocks wired in a line; coefficients **flow through** once |
| Slogan | move the workers to the data | move the data past the workers |
| Cost | needs a clever conflict-free memory address scheme | needs delay-lines + commutators; pays a big **pipeline-fill** penalty |
| Verifying it | easy — fixed, predictable latency | hard — delay-line bookkeeping |

"**Iterative**" just means the same butterfly hardware is *reused* in a loop —
like a software `for` loop, repetition over **time** — instead of building 8
separate copies, replication over **space**.

We chose **iterative / memory-based** because for a one-shot 256-point NTT the
streaming style wastes hundreds of cycles just filling its pipeline, and because
the fixed, predictable iterative design is far easier to verify in a thesis
timeline.

---

## The whole thing in one breath

> Dilithium constantly multiplies lists of 256 numbers. Doing that directly is
> 65,536 operations — too slow. So we use the **NTT**: a doorway into another
> "world" where list-multiplication becomes simple position-by-position
> multiplication. You step through the doorway by running your list through
> **8 rounds of butterfly mixing**. A butterfly is a tiny machine: two numbers +
> a twiddle factor → two mixed numbers. Our hardware is a worker box
> (`ntt_core`) that marches a controller through those 8 stages — 4 butterflies
> per tick via a 2×2 tile, 8 stages collapsed into 4 memory passes — plus a
> receptionist box (`ntt_engine`) that handles getting numbers in and out. Lists
> A and B are transformed one after another on the same core.

---

## Glossary

| Term | Plain meaning |
|---|---|
| Polynomial | A list of 256 numbers |
| NTT | The "doorway" — a transform into a world where multiply is cheap |
| Forward NTT | Going *into* the NTT world |
| Inverse NTT | Coming *back* to the normal world |
| Butterfly | Tiny machine: 2 numbers + twiddle → 2 mixed numbers |
| Twiddle factor (`ζ`) | The "spinning" number a butterfly mixes with |
| CT butterfly | Forward-direction butterfly (spin, then mix) |
| GS butterfly | Inverse-direction butterfly (mix, then spin) |
| Round / stage | One full sweep of 128 butterflies over the list |
| Group | Butterflies in a round that share one twiddle |
| 2×2 butterfly tile | 4 butterflies/cycle, 2 NTT stages per memory pass |
| Iterative NTT | One butterfly tile *looped* over the data (vs. 8 fixed blocks) |
| Pipeline-fill penalty | Cycles a streaming design wastes before its first output |
| Root of unity | A number whose powers cycle back to 1 |
| 512th root (`ζ=1753`) | `ζ⁵¹²=1` and `ζ²⁵⁶=−1` — the negacyclic-capable root |
| Negacyclic ring | `x²⁵⁶+1`: overshooting terms wrap back *negated* |
| `bitreverse8` | Flip the bit order of an 8-bit index |
| SCALE | Final inverse-NTT step: multiply everything by `n⁻¹` |
| `q = 8,380,417` | The modulus — numbers wrap around it like a clock |
| `N_INV = 8,347,681` | `256⁻¹ mod q` — the SCALE constant |
| Modular reduction | "Wrap the number back into range" |
