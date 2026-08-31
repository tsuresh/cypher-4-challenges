#!/usr/bin/env python3
"""Generate i03 capture.txt: the same flag RSA-encrypted with e=3 under three
distinct 1024-bit moduli, no padding (textbook). Håstad's broadcast attack
recovers it. Usage: gen.py 'CYPHER{...}' [out]"""
import sys
from Crypto.Util.number import getPrime, bytes_to_long

def rsa_mod():
    p, q = getPrime(512), getPrime(512)
    return p * q

def main():
    flag = sys.argv[1].encode()
    out = sys.argv[2] if len(sys.argv) > 2 else "capture.txt"
    m = bytes_to_long(flag)
    e = 3
    lines = ["# Ruhunu Bank — same notice, three partners, e=3, no padding.",
             "# Each block: n (hex), e, c (hex) where c = m^e mod n.", ""]
    for i in range(3):
        while True:
            n = rsa_mod()
            if m < n:            # ensure the message fits under each modulus
                break
        c = pow(m, e, n)
        lines += [f"[recipient {i+1}]",
                  f"n = 0x{n:x}",
                  f"e = {e}",
                  f"c = 0x{c:x}", ""]
    open(out, "w").write("\n".join(lines))
    print(f"wrote {out} (flag {len(flag)} bytes)")

if __name__ == "__main__":
    main()
