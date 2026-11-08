/* BootMon läuft im 16-Bit-Real-Mode, mit DS = ES = SS = 0. */
extern unsigned char boot_drive;

/* BIOS-Teletype: Bildschirmseite 0, helle Schrift. */
static void putc(char c) {
    unsigned short ax = 0x0E00 | (unsigned char)c;
    asm volatile("int $0x10" : "+a"(ax) : "b"(7) : "cc");
}

/* BIOS-Tastatureingabe: Enter liefert '\r'. */
static inline char getc() {
    unsigned short ax = 0;
    asm volatile("int $0x16" : "+a"(ax) :: "cc");
    return ax;
}

static void puts(const char *s) {
    while (*s)
        putc(*s++);
}

/* Genau einen CHS-Sektor lesen; das Carry-Flag meldet einen Fehler. */
static unsigned char read_sector(unsigned char sector) {
    unsigned short ax = 0x0201, bx = 0x7E00;
    unsigned short cx = sector, dx = boot_drive;
    unsigned char failed;
    asm volatile("int $0x13; setc %0"
                 : "=qm"(failed), "+a"(ax), "+b"(bx), "+c"(cx), "+d"(dx)
                 :: "cc", "memory");
    return failed;
}

static void hex_digit(unsigned char digit) {
    putc(digit + (digit < 10 ? '0' : 'A' - 10));
}

static void dump(unsigned short address) {
    for (unsigned char i = 0; i < 16; ++i) {
        unsigned char byte = *(volatile unsigned char *)(unsigned int)address++;
        hex_digit(byte >> 4);
        hex_digit(byte & 15);
        if (i != 15)
            putc(' ');
    }
    puts("\r\n");
}

void main(void) {
    char line[8];
    puts("BootMon!\r\n");
    for (;;) {
        unsigned char length = 0;
        puts("$ ");
        while (length < 7) {
            char c = getc();
            if (c == '\r')
                break;
            line[length++] = c;
            putc(c);
        }
        line[length] = '\0';
        puts("\r\n");
        if (!length)
            continue;

        if (line[0] == 'b' && length == 1) {
            puts("Reboot!\r\n");
            asm volatile("int $0x19" ::: "memory");
        } else if (line[1] == ' ' &&
                   (line[0] == 'm' || line[0] == 'r')) {
            unsigned short address = 0;
            for (const char *p = line + 2; *p; ++p) {
                unsigned char c = *p;
                c -= '0';
                if (c > 9)
                    c -= 7;
                address = (address << 4) | c;
            }
            if (line[0] == 'm') {
                dump(address);
            } else {
                puts(read_sector(address) ? "?\r\n" : "OK\r\n");
            }
        } else {
            puts("?\r\n");
        }
    }
}
