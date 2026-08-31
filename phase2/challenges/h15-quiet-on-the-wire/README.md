# h15 — Quiet on the Wire (Sethsuwa Health)

**Category:** Forensics / DNS-tunnel exfil · **Difficulty:** Hard · **Points:** 400 (dynamic)

## Intended solve
The pcap looks quiet — mostly DNS. An implant exfiltrated data as a series of **DNS subdomain
queries** (chunked, base32), which is why there's no obvious HTTP/TLS payload.

```sh
# 1) Pull the queried names, in order, for the exfil domain:
tshark -r capture.pcap -Y 'dns.flags.response==0 && dns.qry.name contains ".exfil.example"' \
  -T fields -e frame.number -e dns.qry.name | sort -n

# 2) Each label is a base32 chunk with a sequence prefix. Strip the domain, order by sequence,
#    concatenate, base32-decode:
python3 reassemble.py            # -> a blob
# 3) Second layer: the blob is XOR'd (key in an early beacon TXT answer) then zlib-compressed:
python3 -c 'import zlib; open("out","wb").write(zlib.decompress(xor(blob, key)))'
cat out                          # CYPHER{...}
```

## Infra & safety
- **Attachment-only** pcap (no live infra). All hosts/domains are synthetic. Two decode layers
  (order+base32, then XOR+zlib) keep it Hard without being guessable. Same flag for all teams.

## Remediation (Blue Team Brief)
Monitor DNS for high query volume, long/random labels, and rare TLDs; use DNS firewalling/RPZ and
egress allow-lists; a workstation making thousands of unique subdomain lookups to one domain is a
tunnelling red flag.
