# Dilithium Sampling Explained

Let's understand all **4 types of sampling in Dilithium** using actual byte examples.

Imagine your Keccak hardware produces these bytes:

```text
03 21 FF 08 A4 17 00 92 ...
```

These are pseudorandom bytes.

**The sampler reads these bytes and converts them into polynomial coefficients.**

But the conversion depends on what Dilithium needs.

| Sampler | What it produces |
|---|---|
| 1. Matrix A sampler | Large numbers between 0 and 8,380,416 |
| 2. Secret sampler | Small numbers such as −2, −1, 0, 1, 2 |
| 3. Mask sampler | Larger positive and negative numbers |
| 4. SampleInBall | Mostly zeros, with a fixed number of +1 and −1 values |

All four use pseudorandom bytes, but they interpret those bytes differently.

The examples below use illustrative SHAKE output bytes so we can follow the conversion easily. They are not claimed to be outputs for any particular seed.

## 1. Matrix A sampling

**Uses SHAKE128**

**Goal:** Generate 256 coefficients, each between 0 and 8,380,416.

Suppose SHAKE gives:

```text
01 02 03   FF FF 7F   00 00 00
```

The sampler reads 3 bytes at a time and extracts a 23 bit number.

**Candidate 1 — Accept**

`01 02 03` → **197,121**

**Candidate 2 — Reject**

`FF FF 7F` → **8,388,607**

This number exceeds the maximum allowed value.

**Candidate 3 — Accept**

`00 00 00` → **0**

So the resulting polynomial starts:

```text
A = [197121, 0, ...]
```

The sampler continues until it has accepted 256 coefficients.

**Important:** Rejecting numbers above the modulus keeps the accepted values uniformly distributed.

## 2. Secret sampling for s1 and s2

**Uses SHAKE256**

**Goal:** Generate 256 small coefficients, such as −2, −1, 0, 1, 2.

Let's use Dilithium 2, where \(\eta=2\).

Suppose Keccak outputs:

```text
21 F4 03
```

This time the sampler divides each byte into two 4 bit values, called *nibbles*.

For example:

```text
Byte = 0x21

Lower nibble = 1
Upper nibble = 2
```

For this parameter set, each valid nibble is converted using:

\[
coefficient = 2-(nibble \bmod 5)
\]

with nibble `15` rejected.

| Byte | Nibble | Converted coefficient |
|---|---|---|
| `21` | 1 | +1 |
| `21` | 2 | 0 |
| `F4` | 4 | −2 |
| `F4` | 15 | Rejected |
| `03` | 3 | −1 |
| `03` | 0 | +2 |

So your output becomes:

```text
s1 = [1, 0, −2, −1, 2, ...]
```

Continue until 256 coefficients are generated.

For Dilithium 3, \(\eta=4\), so the allowed range becomes −4 through +4 and the nibble conversion rule changes.

**Difference from A:** The matrix sampler produces large coefficients, while this sampler produces tiny secret coefficients.

## 3. Mask sampling for y

**Uses SHAKE256**

**Goal:** Generate a temporary polynomial \(y\) used during signing.

This sampler generates larger signed coefficients.

For Dilithium 2:

\[
\gamma_1=131072
\]

The sampler extracts consecutive groups of 18 bits from SHAKE output.

Suppose the first bytes are:

```text
03 00 02 ...
```

The first 18 bits represent:

\[
t=131075
\]

The conversion is:

\[
y=\gamma_1-t
\]

Therefore:

\[
y=131072-131075=\boxed{−3}
\]

So the first coefficient is:

```text
y[0] = −3
```

For other extracted values:

| Extracted value \(t\) | Output \(y\) |
|---:|---:|
| 131,070 | +2 |
| 131,072 | 0 |
| 131,075 | −3 |
| 0 | +131,072 |

The resulting polynomial might look like:

```text
y = [−3, 2, 0, 81924, −17280, ...]
```

The example values illustrate the mapping, rather than one continuous SHAKE output stream.

Unlike matrix A sampling, this does **not** need to reject coefficient candidates. The fixed width bit groups map directly into the required signed range.

Also, the 18 bit groups are packed continuously. The sampler must retain any leftover bits between byte boundaries.

## 4. SampleInBall for challenge c

**Uses SHAKE256**

This sampler is quite different.

**Goal:** Generate a polynomial containing only 0, +1 and −1, with an exact number of nonzero coefficients.

For Dilithium 2, exactly 39 of the 256 coefficients must be nonzero.

Suppose SHAKE provides:

```text
Sign bytes:
01 00 00 00 00 00 00 00

Position bytes:
FA 05 07 ...
```

The first 8 bytes provide sign bits. Subsequent bytes help select positions.

In the first iteration for Dilithium 2, the sampler needs a position number no greater than 217.

```text
FA = 250 → reject
05 =   5 → accept
```

The first sign bit is `1`, so the value assigned is `−1`.

```text
c[5] = −1
```

Next, the sampler considers `07`:

```text
07 = 7 → accept
```

The second sign bit is `0`, so:

```text
c[7] = +1
```

The polynomial now temporarily looks like:

```text
Index       Value

0             0
1             0
2             0
3             0
4             0
5            −1
6             0
7            +1
8             0
...
```

The real algorithm continues with a shuffle operation, which can move previously assigned coefficients. Eventually it produces exactly 39 nonzero coefficients for Dilithium 2.

For the three security levels:

| Level | Nonzero coefficients |
|---|---:|
| Dilithium 2 | 39 |
| Dilithium 3 | 49 |
| Dilithium 5 | 60 |

This is the `SampleInBall` procedure defined in NIST FIPS 204.

## Now connect everything to your hardware

Your dual Keccak subsystem can supply the random bytes for all these operations.

```text
Dual Keccak
Pseudorandom byte stream
21 F4 03 92 7A ...
      │
      ▼
Sampler controller
Selects the required sampling operation
      │
      ├── Matrix A: Large uniform values
      ├── Secret s1, s2: Small signed values
      ├── Mask y: Bounded signed values
      └── Challenge c: Sparse ±1 values
      │
      ▼
Polynomial memory
256 coefficients per polynomial
```

The important difference for your RTL is how each sampler consumes SHAKE output:

| Sampler | Parsing rule | Rejects values? |
|---|---|---|
| Matrix A | 3 bytes per candidate | Yes |
| Secret | Two 4 bit candidates per byte | Yes |
| Mask | 18 or 20 consecutive bits | No |
| Challenge | Sign bits and position bytes | Invalid position candidates |

**The main takeaway:** Keccak does the random bit generation. The sampler does the interpretation, acceptance, conversion and coefficient counting.

For your dual core design, one particularly important architectural decision is whether to use two separate samplers or **one shared sampler with separate saved state for each Keccak stream**, similar to LightHD. That choice affects area, data flow and whether the sampler can keep up with both cores.

---

You're right. I skipped the actual bit conversions and didn't explain where the numbers came from. That made the examples confusing.

Let's go through both samplers properly, using longer SHAKE outputs and multiple iterations, exactly as the hardware would process them.

First, two important clarifications:

1. **Mask sampling:** `03 00 02` represents 131,075 because Dilithium reads the bits in little endian order. The three bytes form `0x020003`, which is 131,075 in decimal. However, the sampler actually consumes 18 bits per coefficient, not necessarily three whole bytes.
2. **SampleInBall:** The number 39 is a fixed Dilithium 2 security parameter. The position selection algorithm does not simply accept every number below 256. Its acceptance limit changes as the algorithm progresses.

I'll use illustrative SHAKE output bytes and show exactly how they are consumed.

## 3. Mask sampling for y, explained properly

### A. What exactly is \(\gamma_1=131072\)?

The symbol \(\gamma_1\), pronounced *gamma one*, is a fixed parameter in Dilithium.

It determines the range of the temporary random coefficients in the signing vector \(y\).

For Dilithium 2:

\[
\gamma_1=2^{17}=131072
\]

So every coefficient of \(y\) must satisfy:

\[
-131071\le y_i\le131072
\]

It does not come from Keccak. It is defined by the Dilithium parameter set.

| Security level | \(\gamma_1\) | Bits per coefficient |
|---|---:|---:|
| Dilithium 2 | 131,072 | 18 |
| Dilithium 3 | 524,288 | 20 |
| Dilithium 5 | 524,288 | 20 |

These are specified in NIST FIPS 204.

Why 18 bits for Dilithium 2?

Because:

\[
2^{18}=262144
\]

So 18 bits represent numbers from 0 through 262,143, which is exactly the number of possible coefficient values in the allowed range.

### B. Let's take a longer SHAKE256 output

Suppose SHAKE generates the following 18 bytes:

**Example SHAKE output**

```text
03 00 02 00 E8 FF 1F 00 00
FF FF FF FF 07 D4 30 A8 61
```

These are illustrative bytes deliberately chosen to demonstrate different coefficient values.

We have 18 bytes:

\[
18\times8=144\text{ bits}
\]

Each coefficient needs 18 bits.

Therefore:

\[
144/18=8\text{ coefficients}
\]

So these 18 bytes give us the first **8 coefficients of y**.

### C. How are the bits actually divided?

The sampler reads consecutive groups of 18 bits, starting with the least significant bit of the first byte.

**Bit allocation**

| Coefficient | SHAKE bit positions |
|---|---|
| y[0] | 0..17 |
| y[1] | 18..35 |
| y[2] | 36..53 |
| y[3] | 54..71 |
| y[4] | 72..89 |
| y[5] | 90..107 |
| y[6] | 108..125 |
| y[7] | 126..143 |

Each coefficient consumes exactly 18 consecutive bits. The labels show bit positions within the SHAKE byte stream.

Notice that coefficient boundaries do not always match byte boundaries.

Now let's extract them one by one.

### D. Iteration 1: Calculate y[0]

Read bits 0 through 17.

These come from:

```text
Byte 0 = 03
Byte 1 = 00
Byte 2 = 02 (only its lowest 2 bits)
```

Combining them in little endian order:

\[
t_0=3+(0\times256)+(2\times65536)
\]

\[
\boxed{t_0=131075}
\]

This is also hexadecimal `0x20003`.

Now apply the mask conversion:

\[
y_0=\gamma_1-t_0
\]

\[
y_0=131072-131075
\]

\[
\boxed{y_0=-3}
\]

That is where the 131,075 came from.

### E. Iteration 2: Calculate y[1]

We already consumed the lowest two bits of byte `02`.

We must now continue from its remaining six bits, then consume the next byte and four bits of the following byte.

```text
Byte 2 = 02  (upper 6 bits)
Byte 3 = 00  (all 8 bits)
Byte 4 = E8  (lowest 4 bits)
```

The actual extraction is:

```systemverilog
t1 = (byte2 >> 2)
   | (byte3 << 6)
   | ((byte4 & 8'h0F) << 14);
```

Substituting the values gives:

\[
t_1=131072
\]

Therefore:

\[
y_1=131072-131072
\]

\[
\boxed{y_1=0}
\]

### F. Iterations 3 through 8

The exact same process continues.

No new rule is introduced. We just read the next 18 bits and subtract the extracted number from \(\gamma_1\).

| Iteration | SHAKE bit positions | Extracted \(t\) | Final \(y=\gamma_1-t\) |
|---|---|---:|---:|
| 1 | 0 to 17 | 131,075 | −3 |
| 2 | 18 to 35 | 131,072 | 0 |
| 3 | 36 to 53 | 131,070 | +2 |
| 4 | 54 to 71 | 0 | +131,072 |
| 5 | 72 to 89 | 262,143 | −131,071 |
| 6 | 90 to 107 | 131,071 | +1 |
| 7 | 108 to 125 | 200,000 | −68,928 |
| 8 | 126 to 143 | 100,000 | +31,072 |

These numbers are all decoded from the same 18 byte stream above.

So after eight iterations:

```text
y[0] =      −3
y[1] =       0
y[2] =       2
y[3] =  131072
y[4] = −131071
y[5] =       1
y[6] =  −68928
y[7] =   31072
```

The polynomial currently contains:

\[
y=[-3,0,2,131072,-131071,1,-68928,31072,\ldots]
\]

The sampler continues until it has generated 256 coefficients.

For Dilithium 2, it needs:

\[
256\times18=4608\text{ bits}
\]

or:

\[
\boxed{576\text{ SHAKE output bytes per polynomial}}
\]

For Dilithium 3 and 5, where coefficients need 20 bits, it requires 640 bytes per polynomial.

That is the actual bit unpacking process specified for `ExpandMask` in FIPS 204, Algorithm 34.

**Remember:** Mask sampling does not reject extracted values. All possible 18 bit values map into the permitted signed range.

---

## 4. SampleInBall for challenge c

This one works completely differently from mask sampling.

Let's answer your questions first.

### A. Where did the number 39 come from?

The challenge polynomial \(c\) always has 256 coefficients.

But those coefficients can only be:

\[
-1,\quad 0,\quad +1
\]

Dilithium requires exactly a certain number of them to be nonzero.

That number is called \(\tau\), pronounced *tau*.

| Security level | \(\tau\) | Nonzero coefficients | Zero coefficients |
|---|---:|---:|---:|
| Dilithium 2 | 39 | 39 | 217 |
| Dilithium 3 | 49 | 49 | 207 |
| Dilithium 5 | 60 | 60 | 196 |

**39 is not calculated from the SHAKE output.** It is a predefined cryptographic parameter selected as part of Dilithium 2's security design.

It controls how many \(+1\) and \(−1\) entries appear in the challenge. Increasing it changes the challenge space and the cost of later arithmetic.

FIPS 204 specifies these values in its parameter table.

So for Dilithium 2, we need a polynomial looking something like:

```text
c = [0, 0, −1, 0, +1, 0, 0, ...]
```

At the end:

```text
Total coefficients     256

Values equal to 0      217
Values equal to +1     some
Values equal to −1     some

Total nonzero values    39
```

The exact number of positive versus negative values is not fixed. Their sum must be 39.

### B. Where do the position bytes come from?

They come from **the very same SHAKE256 output stream**.

Suppose SHAKE256 generates:

```text
29 00 00 00 00 00 00 00 FA 05 07 05 DC F5 0F 07 0A E0 ...
```

The sampler interprets this stream in two sections.

**SHAKE256 output**

```text
29 00 00 00 00 00 00 00
```

First 8 bytes: sign information

```text
FA 05 07 05 DC F5 0F 07 0A E0 ...
```

Remaining bytes: position candidates

There are not two separate SHAKE operations.

The sampler simply takes the first 8 bytes to decide signs, then continues reading the same stream to select positions.

This is exactly how NIST's `SampleInBall` algorithm operates.

### C. How are the signs decided?

Let's examine the very first byte:

```text
Hexadecimal = 29
Binary      = 00101001
```

The bits are consumed from the least significant bit first.

**First sign byte: `0x29`**

| Bit position | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
|---|---|---|---|---|---|---|---|---|
| Value | 0 | 0 | 1 | 0 | 1 | 0 | 0 | 1 |

Bit numbers are shown below. The sampler starts from bit 0 on the right.

The conversion rule is simple:

\[
\text{sign bit }0\Rightarrow +1
\]

\[
\text{sign bit }1\Rightarrow -1
\]

So the eight sign bits produce:

| Iteration | Bit | Sign |
|---|---:|---:|
| 1 | 1 | −1 |
| 2 | 0 | +1 |
| 3 | 0 | +1 |
| 4 | 1 | −1 |
| 5 | 0 | +1 |
| 6 | 1 | −1 |
| 7 | 0 | +1 |
| 8 | 0 | +1 |

The next 31 signs will come from the remaining sign bytes. In our example, they are zeros, so those additional signs will all be positive.

### D. How do the positions get chosen?

Here is the part I didn't explain properly earlier.

For Dilithium 2:

\[
256-\tau=256-39=217
\]

The sampler starts a loop with:

```text
i = 217
```

It runs until:

```text
i = 255
```

So there are exactly:

\[
255-217+1=39
\]

iterations.

In every iteration, it reads a random byte \(j\) from SHAKE and accepts it only if:

\[
\boxed{j\le i}
\]

Why?

Because this is a variation of the **Fisher Yates shuffle**. At each iteration, we want a uniformly random position among indices 0 through \(i\).

If \(i=217\), then there are 218 eligible positions.

SHAKE gives a byte between 0 and 255, so values from 218 through 255 must be discarded.

Using modulo 218 instead would bias the position probabilities.

Notice:

**A number can be below 256 and still be rejected**, because the current upper limit is \(i\), not always 255.

### E. Let's execute the first eight iterations

Initially:

```text
c[0]   = 0
c[1]   = 0
...
c[255] = 0
```

All 256 values are zero.

The SHAKE position bytes are:

```text
FA 05 07 05 DC F5 0F 07 0A E0
```

#### Iteration 1

Current loop index:

```text
i = 217
```

Read the first position candidate:

```text
j = FA = 250
```

Check:

\[
250>217
\]

Reject it.

Read the next byte:

```text
j = 05 = 5
```

Check:

\[
5\le217
\]

Accept.

The algorithm performs:

```text
c[217] = c[5]
c[5]   = −1
```

Since everything was previously zero:

```text
c[217] = 0
c[5]   = −1
```

We now have one nonzero coefficient.

#### Iteration 2

```text
i = 218
```

Next SHAKE byte:

```text
j = 07 = 7
```

Accept, because:

\[
7\le218
\]

Second sign bit is zero, meaning +1.

```text
c[218] = c[7] = 0
c[7]   = +1
```

Current nonzero coefficients:

```text
c[5] = −1
c[7] = +1
```

Total: 2.

#### Iteration 3: This explains why signs appear to flip

```text
i = 219
```

Next SHAKE byte:

```text
j = 05 = 5
```

Accepted.

But here's something important:

**Position 5 already contains −1!**

The algorithm says:

```text
c[219] = c[5]
c[5]   = new sign
```

So the first assignment gives:

```text
c[219] = −1
```

The third sign bit is 0, so the second assignment gives:

```text
c[5] = +1
```

Now:

```text
c[5]   = +1
c[7]   = +1
c[219] = −1
```

**What happened to position 5?**

| Before | After |
|---|---|
| −1 | +1 |
| c[5] | c[5] |

The original −1 was moved into `c[219]`, and a new +1 was placed at `c[5]`.

So the sign is not randomly flipping because Keccak changed its mind.

**The sampler is moving existing values and placing new ones.**

This ensures that each iteration increases the total number of nonzero coefficients by exactly one.

#### Iterations 4 through 8

Let's continue with the next SHAKE bytes.

| Iteration | \(i\) | SHAKE candidate | Result | New sign |
|---|---:|---|---|---|
| 4 | 220 | `DC` = 220 | Accept | −1 |
| 5 | 221 | `F5` = 245 | Reject | Not used |
| 5 continued | 221 | `0F` = 15 | Accept | +1 |
| 6 | 222 | `07` = 7 | Accept | −1 |
| 7 | 223 | `0A` = 10 | Accept | +1 |
| 8 | 224 | `E0` = 224 | Accept | +1 |

In iteration 6, position 7 previously contained +1.

So:

```text
c[222] = c[7] = +1
c[7]   = −1
```

Again, an old value moves and a new sign is inserted.

### F. What does the polynomial look like after eight iterations?

**Nonzero coefficients after iteration 8**

| Position | Value | Position | Value |
|---|---|---|---|
| c[5] | +1 | c[7] | −1 |
| c[10] | +1 | c[15] | +1 |
| c[219] | −1 | c[220] | −1 |
| c[222] | +1 | c[224] | +1 |

All other 248 coefficients are still zero.

There are now exactly eight nonzero coefficients.

Continue the algorithm for the remaining 31 iterations.

The loop ultimately reaches:

```text
i = 255
```

At that point every possible byte from 0 through 255 is acceptable, because:

\[
j\le255
\]

After all 39 iterations:

```text
Nonzero coefficients = 39
Zero coefficients    = 217
Total                = 256
```

This is guaranteed by the shuffle algorithm, regardless of how many SHAKE position candidates were rejected along the way.

### G. Why not simply choose 39 positions without all this moving?

Because selecting 39 positions independently can produce duplicates.

For example:

```text
Position 5
Position 7
Position 5 again
```

If we simply overwrite position 5, we might finish with fewer than 39 nonzero locations.

The shuffle procedure avoids that problem by moving an existing value to an unused index before placing the new value.

This is why those two assignments matter:

```systemverilog
c[i] = c[j];
c[j] = sign;
```

They ensure the number of nonzero coefficients increases by one in each iteration.

The algorithm is designed to sample uniformly from the allowed sparse challenge polynomials.

---

## Final comparison between Mask and SampleInBall

| Property | Mask sampling | SampleInBall |
|---|---|---|
| Input | SHAKE256 bytes | SHAKE256 bytes |
| Output | Polynomial \(y\) | Polynomial \(c\) |
| Coefficient range | Large signed values | Only 0, +1, −1 |
| Bit parsing | Consecutive 18 or 20 bit fields | First 8 bytes for signs, then position bytes |
| Candidate rejection | No | Yes, for invalid positions |
| Shuffling | No | Yes |
| Number of nonzero values | Not fixed | Exactly \(\tau\) |
| Primary use | Hide secret information during signing | Generate the cryptographic challenge |

For your RTL, these really are two different hardware datapaths:

**Mask sampler:** Bit unpacker, subtractor using \(\gamma_1\), coefficient counter and output packing.

**SampleInBall:** Sign register, position byte reader, rejection comparator, 256 coefficient storage, indexed read and write logic, and an FSM implementing the shuffle.

The most important distinction is that **mask sampling is a straightforward bit conversion, while SampleInBall is a stateful algorithm that repeatedly updates a 256 coefficient polynomial**.

Reference: [NIST FIPS 204](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.204.pdf), particularly Algorithm 19 (BitUnpack), Algorithm 29 (SampleInBall) and Algorithm 34 (ExpandMask).
