/* h12 Serendib Machine — a tiny stack VM that validates the flag through
 * bytecode, not native instructions. The bytecode lives in section .vmcode and
 * is generated per build from the flag (see gen.py). The flag never appears as
 * a literal string anywhere in the binary — only as the inverse of the VM's
 * transform + constant tables.
 *
 * Opcodes:
 *   0x01 PUSH <imm>   push one immediate byte
 *   0x02 IN           read one byte of user input, push it
 *   0x03 XOR          b=pop; a=pop; push(a ^ b)
 *   0x04 ADD          b=pop; a=pop; push((a + b) & 0xff)
 *   0x05 CMP          b=pop; a=pop; if(a != b) bad=1
 *   0x06 HALT         stop; accept iff bad==0 and all input consumed
 */
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "program.h"   /* defines: prog[] in section .vmcode, PROG_LEN, FLAG_LEN */

int main(void) {
    unsigned char inp[256];
    unsigned char st[512];
    int sp = 0, ip = 0, bad = 0, inpos = 0;

    setvbuf(stdout, NULL, _IONBF, 0);
    fputs("Serendib Machine — enter licence key: ", stdout);
    int n = read(0, inp, sizeof inp);
    if (n <= 0) return 1;
    while (n > 0 && (inp[n-1] == '\n' || inp[n-1] == '\r')) n--;   /* strip newline */

    while (ip < PROG_LEN) {
        unsigned char op = prog[ip++];
        switch (op) {
            case 0x01: st[sp++] = prog[ip++]; break;                 /* PUSH imm */
            case 0x02: st[sp++] = (inpos < n) ? inp[inpos++] : 0xff; break; /* IN */
            case 0x03: { unsigned char b=st[--sp], a=st[--sp]; st[sp++]=a^b; } break;
            case 0x04: { unsigned char b=st[--sp], a=st[--sp]; st[sp++]=(a+b)&0xff; } break;
            case 0x05: { unsigned char b=st[--sp], a=st[--sp]; if(a!=b) bad=1; } break;
            case 0x06: goto done;
            default: bad = 1; goto done;
        }
    }
done:
    if (!bad && inpos == n && n == FLAG_LEN) puts("ACCESS GRANTED");
    else puts("ACCESS DENIED");
    return 0;
}
