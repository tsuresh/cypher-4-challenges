#!/usr/bin/env python3
"""h15 Quiet on the Wire — generate a pcap of DNS-tunnel exfiltration.

Wire format: the flag is zlib-compressed, XORed with a 4-byte key, base32-encoded,
chunked across DNS query labels. Query 0 announces the key (init.<keyhex>.<domain>);
queries 1..N carry ordered chunks (<seq>.<b32chunk>.<domain>). Decoy DNS traffic is
mixed in. Written by hand (no scapy). Usage: gen.py 'CYPHER{...}' out.pcap
"""
import sys, os, struct, zlib, base64, random

DOMAIN = "sync.ceylon-cdn.net"

def ip_checksum(hdr):
    s = 0
    for i in range(0, len(hdr), 2):
        s += (hdr[i] << 8) + hdr[i+1]
    s = (s >> 16) + (s & 0xffff); s += (s >> 16)
    return (~s) & 0xffff

def qname(name):
    out = b""
    for lbl in name.split("."):
        out += bytes([len(lbl)]) + lbl.encode()
    return out + b"\x00"

def dns_query(qid, name, qtype=1):
    dns = struct.pack(">HHHHHH", qid, 0x0100, 1, 0, 0, 0)
    dns += qname(name) + struct.pack(">HH", qtype, 1)
    return dns

def udp(sport, dport, payload):
    return struct.pack(">HHHH", sport, dport, 8 + len(payload), 0) + payload

def ipv4(src, dst, payload):
    total = 20 + len(payload)
    hdr = struct.pack(">BBHHHBBH4s4s", 0x45, 0, total, random.randint(0, 65535),
                      0x4000, 64, 17, 0, bytes(int(x) for x in src.split(".")),
                      bytes(int(x) for x in dst.split(".")))
    ck = ip_checksum(hdr)
    hdr = hdr[:10] + struct.pack(">H", ck) + hdr[12:]
    return hdr + payload

def eth(payload):
    return bytes.fromhex("00155d0a0b0c") + bytes.fromhex("00155d0a0b01") + b"\x08\x00" + payload

def record(ts, pkt):
    return struct.pack("<IIII", ts, 0, len(pkt), len(pkt)) + pkt

def b32nopad(b):
    return base64.b32encode(b).decode().rstrip("=").lower()

def main():
    flag = sys.argv[1].encode()
    out = sys.argv[2] if len(sys.argv) > 2 else "capture.pcap"
    rnd = random.Random(flag)
    key = bytes(rnd.randint(0, 255) for _ in range(4))
    blob = zlib.compress(flag, 9)
    enc = bytes(blob[i] ^ key[i % 4] for i in range(len(blob)))
    b32 = b32nopad(enc)
    # chunk into <=40-char labels
    chunks = [b32[i:i+40] for i in range(0, len(b32), 40)]

    client, dnsrv = "10.10.0.37", "10.10.0.2"
    recs = []
    ts = 1_757_060_000
    # exfil queries (with a little decoy interleaving)
    exfil = [("init", key.hex())] + [(f"{i+1:03d}", c) for i, c in enumerate(chunks)]
    decoys = ["www.google.com", "ntp.ubuntu.com", "graph.facebook.com",
              "settings-win.data.microsoft.com", "api.ape-ride.lk", "clients4.google.com"]
    qid = 0x1000
    seqpkts = []
    for seq, payload in exfil:
        name = f"{seq}.{payload}.{DOMAIN}"
        seqpkts.append(dns_query(qid, name, qtype=16)); qid += 1
    # interleave decoys among exfil to add noise, but keep exfil order intact
    order = []
    di = 0
    for p in seqpkts:
        if rnd.random() < 0.4 and di < len(decoys)*3:
            order.append(dns_query(qid, rnd.choice(decoys), 1)); qid += 1; di += 1
        order.append(p)
    for pkt in order:
        recs.append(record(ts, eth(ipv4(client, dnsrv, udp(rnd.randint(30000,60000), 53, pkt)))))
        ts += rnd.randint(1, 3)

    gh = struct.pack("<IHHiIII", 0xa1b2c3d4, 2, 4, 0, 0, 65535, 1)
    open(out, "wb").write(gh + b"".join(recs))
    print(f"wrote {out} ({len(chunks)} exfil chunks, key={key.hex()})")

if __name__ == "__main__":
    main()
