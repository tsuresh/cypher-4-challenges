#!/usr/bin/env bash
# h15 healthcheck / scripted solve: build the pcap for a test flag, then parse it
# (pure Python, no scapy/tshark), reassemble the DNS-tunnel chunks in order, peel
# the XOR+zlib layers, and confirm the recovered flag matches.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAG="${CHAL_FLAG-}"; [ -n "$FLAG" ] || FLAG='CYPHER{dns_tunnel_base32_xor_zlib}'
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
PY=""; [ -x "$HERE/../../../.venv/bin/python" ] && PY="$HERE/../../../.venv/bin/python" || PY=python3

"$PY" "$HERE/gen.py" "$FLAG" "$WORK/capture.pcap" >/dev/null

REC="$("$PY" - "$WORK/capture.pcap" <<'PY'
import sys, struct, base64, zlib
DOMAIN="sync.ceylon-cdn.net"
data=open(sys.argv[1],"rb").read()
assert data[:4] in (b"\xd4\xc3\xb2\xa1", b"\xa1\xb2\xc3\xd4")   # LE / BE pcap magic
off=24; names=[]
while off+16<=len(data):
    ts_s,ts_u,incl,orig=struct.unpack_from("<IIII",data,off); off+=16
    pkt=data[off:off+incl]; off+=incl
    if len(pkt)<14+20+8: continue
    ihl=(pkt[14]&0x0f)*4
    ipend=14+ihl
    if pkt[14+9]!=17: continue                       # not UDP
    dport=struct.unpack_from(">H",pkt,ipend+2)[0]
    if dport!=53: continue
    dns=pkt[ipend+8:]
    # parse first question name
    p=12; labels=[]
    while p<len(dns) and dns[p]!=0:
        l=dns[p]; labels.append(dns[p+1:p+1+l].decode("latin1")); p+=1+l
    names.append(".".join(labels))

# keep only our exfil domain queries
q=[n for n in names if n.endswith(DOMAIN)]
key=None; chunks={}
for n in q:
    head=n[:-(len(DOMAIN)+1)]           # strip ".DOMAIN"
    parts=head.split(".",1)
    if parts[0]=="init":
        key=bytes.fromhex(parts[1]); continue
    seq=int(parts[0]); chunks[seq]=parts[1]
b32="".join(chunks[k] for k in sorted(chunks))
pad="="*((-len(b32))%8)
enc=base64.b32decode(b32.upper()+pad)
blob=bytes(enc[i]^key[i%4] for i in range(len(enc)))
flag=zlib.decompress(blob).decode()
sys.stdout.write(flag)
PY
)"
echo "recovered: $REC"
[[ "$REC" == "$FLAG" ]] && { echo "h15 healthcheck rc=0"; exit 0; }
echo "h15 healthcheck FAILED (got: $REC)"; exit 1
