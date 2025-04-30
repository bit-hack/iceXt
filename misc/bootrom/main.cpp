typedef unsigned char   uint8_t;
typedef unsigned short  uint16_t;
typedef unsigned long   uint32_t;
typedef char            bool;

#define true            0x1
#define false           0x0

void port_out(uint8_t data) {
    uint8_t d = data;
    __asm
    {
        mov al, d
        out 0x2a, al
    }
}

extern "C" void cmain()
{
    uint8_t x = 0;
    for (;;) {
        for (x = 0; x < 32; ++x) {
            port_out(x);
        }
        for (x = 0; x < 32; ++x) {
            port_out(x ^ 31);
        }
    }
}
