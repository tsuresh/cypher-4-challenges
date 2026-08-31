/* Pearl Telecom SMS gateway — i04 Return to Sender (ret2win).
 * Deliberately vulnerable: unbounded read() into a fixed stack buffer.
 * Compiled No-PIE, no stack canary. win() is unreferenced by design and
 * prints the flag (read from /flag at runtime, injected by the container). */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

void win(void) {
    char buf[200];
    FILE *f = fopen("/flag", "r");
    if (f) {
        if (fgets(buf, sizeof buf, f)) fputs(buf, stdout);
        fclose(f);
    } else {
        char *e = getenv("FLAG");
        puts(e ? e : "CYPHER{flag_not_provisioned}");
    }
    fflush(stdout);
}

void vuln(void) {
    char buf[64];
    puts("Pearl Telecom SMS gateway v1.3");
    puts("Enter message (160 chars max):");
    fflush(stdout);
    read(0, buf, 512);            /* BUG: buffer is 64 bytes */
    printf("Queued: %.20s...\n", buf);
    fflush(stdout);
}

int main(void) {
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    alarm(60);
    vuln();
    return 0;
}
