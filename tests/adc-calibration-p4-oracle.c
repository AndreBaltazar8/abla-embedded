// Host-only independent IDF integer-formula oracle, never linked to firmware.
#include <stdint.h>
#include <stdio.h>
extern int32_t abla_p4_adc_voltage_probe(int32_t,int32_t,int32_t,int32_t,int32_t);
static const uint64_t k0[2][4] = {
    {7170501832480995ULL,9960085535084866ULL,14711053224678996ULL,28811493455181565ULL},
    {4900967548489932ULL,7296214814536025ULL,10991620450220592ULL,24421401024626730ULL}
};
static const uint64_t k1[2][4] = {
    {10598497992115ULL,15840076608145ULL,1594266424857ULL,10082311568625ULL},
    {5037402667913ULL,11021577596635ULL,11623930881896ULL,9458501263393ULL}
};
static int oracle(int unit,int atten,int reference,int difference,int raw) {
    static const uint32_t voltage[4] = {600,800,1200,2300};
    int compensation=(difference&8)?-(difference&7):(difference&7);
    raw-=compensation*(4-atten);
    raw=raw<0?0:raw>4095?4095:raw;
    int delta=(reference&512)?-(reference&511):(reference&511);
    uint32_t ref=(atten<2?2300:2350)+delta;
    uint32_t slope=65536U*voltage[atten]/ref;
    uint64_t first=(uint64_t)raw*slope/65536U;
    if (!first) return 0;
    uint64_t denominator=(unit==1 && atten==2)?100000000000000000ULL:10000000000000000ULL;
    int32_t error=-(int32_t)(k0[unit-1][atten]/10000000000000000ULL);
    error+=(int32_t)(first*k1[unit-1][atten]/denominator);
    return (int)first-error;
}
static int check(int unit,int atten,int ref,int diff,int raw) {
    int wanted=oracle(unit,atten,ref,diff,raw);
    int got=abla_p4_adc_voltage_probe(unit,atten,ref,diff,raw);
    if (got==wanted) return 0;
    fprintf(stderr,"P4 ADC mismatch unit=%d atten=%d ref=%d diff=%d raw=%d expected=%d actual=%d\n",unit,atten,ref,diff,raw,wanted,got);
    return 1;
}
int main(void) {
    unsigned long cases=0;
    static const int refs[]={0,511,512,1023};
    static const int raws[]={0,1,7,28,1000,2048,4067,4094,4095};
    for (int u=1;u<=2;u++) for (int a=0;a<4;a++) for (int d=0;d<16;d++) {
        for (unsigned r=0;r<sizeof(refs)/sizeof(refs[0]);r++) for (int raw=0;raw<4096;raw++) {
            if (check(u,a,refs[r],d,raw)) return 1;
            cases++;
        }
        for (int ref=0;ref<1024;ref++) for (unsigned r=0;r<sizeof(raws)/sizeof(raws[0]);r++) {
            if (check(u,a,ref,d,raws[r])) return 1;
            cases++;
        }
    }
    printf("PASS: P4 ADC integer calibration oracle, %lu cases\n",cases);
    return 0;
}
