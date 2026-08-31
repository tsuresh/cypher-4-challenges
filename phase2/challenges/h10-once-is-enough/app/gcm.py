#!/usr/bin/env python3
"""Minimal, spec-correct AES-GCM + GF(2^128) helpers, shared by the oracle and the
solver. Validated against the NIST GCM test vector (see selftest below)."""
from Crypto.Cipher import AES

def _ecb(key, block):
    return AES.new(key, AES.MODE_ECB).encrypt(block)

# ---- GF(2^128) with the GHASH bit ordering ----
R = 0xe1 << 120

def gf_mul(x: int, y: int) -> int:
    z = 0; v = x
    for i in range(128):
        if (y >> (127 - i)) & 1:
            z ^= v
        if v & 1:
            v = (v >> 1) ^ R
        else:
            v >>= 1
    return z

def gf_pow(a: int, e: int) -> int:
    r = 1 << 127            # multiplicative identity in this representation (P(x)=1 -> MSB set)
    # identity element for gf_mul as defined is the block 0x80000...0 (bit 127 set).
    base = a
    while e:
        if e & 1:
            r = gf_mul(r, base)
        base = gf_mul(base, base)
        e >>= 1
    return r

def gf_inv(a: int) -> int:
    return gf_pow(a, (1 << 128) - 2)

def gf_sqrt(a: int) -> int:
    return gf_pow(a, 1 << 127)

def _b2i(b): return int.from_bytes(b, "big")
def _i2b(i): return i.to_bytes(16, "big")

def ghash(H: int, aad: bytes, ct: bytes) -> int:
    def blocks(d):
        d = d + b"\x00" * ((-len(d)) % 16)
        return [d[i:i+16] for i in range(0, len(d), 16)]
    y = 0
    for blk in blocks(aad):
        y = gf_mul(y ^ _b2i(blk), H)
    for blk in blocks(ct):
        y = gf_mul(y ^ _b2i(blk), H)
    L = (len(aad) * 8).to_bytes(8, "big") + (len(ct) * 8).to_bytes(8, "big")
    y = gf_mul(y ^ _b2i(L), H)
    return y

def _inc32(block: bytes) -> bytes:
    pre, ctr = block[:12], int.from_bytes(block[12:], "big")
    return pre + ((ctr + 1) & 0xffffffff).to_bytes(4, "big")

def _ctr_keystream(key, j0, nblocks):
    out = b""; ctr = _inc32(j0)
    for _ in range(nblocks):
        out += _ecb(key, ctr); ctr = _inc32(ctr)
    return out

def gcm_encrypt(key, nonce, pt, aad=b""):
    assert len(nonce) == 12
    H = _b2i(_ecb(key, b"\x00" * 16))
    j0 = nonce + b"\x00\x00\x00\x01"
    ks = _ctr_keystream(key, j0, (len(pt) + 15) // 16)
    ct = bytes(a ^ b for a, b in zip(pt, ks))
    S = _b2i(_ecb(key, j0))
    tag = _i2b(ghash(H, aad, ct) ^ S)
    return ct, tag

def gcm_decrypt(key, nonce, ct, tag, aad=b""):
    H = _b2i(_ecb(key, b"\x00" * 16))
    j0 = nonce + b"\x00\x00\x00\x01"
    exp = _i2b(ghash(H, aad, ct) ^ _b2i(_ecb(key, j0)))
    if exp != tag:
        raise ValueError("tag mismatch")
    ks = _ctr_keystream(key, j0, (len(ct) + 15) // 16)
    return bytes(a ^ b for a, b in zip(ct, ks))

def _selftest():
    # NIST GCM test case 1 (AES-128, all zero key/IV, single zero block)
    key = bytes(16); iv = bytes(12); pt = bytes(16)
    ct, tag = gcm_encrypt(key, iv, pt)
    assert ct.hex() == "0388dace60b6a392f328c2b971b2fe78", ct.hex()
    assert tag.hex() == "ab6e47d42cec13bdf53a67b21257bddf", tag.hex()
    assert gcm_decrypt(key, iv, ct, tag) == pt
    return True

if __name__ == "__main__":
    print("gcm selftest:", "OK" if _selftest() else "FAIL")
