// Host-only independent IDF integer formula; never linked into firmware.
#include <stdint.h>
#include <stdio.h>
extern int32_t abla_c5_adc_voltage_probe(int32_t,int32_t,int32_t,int32_t);
static int oracle(int a,int ref,int diff,int raw) {
    static const uint64_t k[4][3]={{2941017829027464ULL,7368674918527ULL,0},
        {3224276125615327ULL,5325658467636ULL,0},
        {3307554632960901ULL,409244304226ULL,0},
        {1463642578413965ULL,3349642363147ULL,11676836451ULL}};
    static const int volts[]={600,800,1200,2300};
    if(a<0||a>3||ref<0||ref>1023||diff<0||diff>15||raw<0||raw>4095) return -1;
    raw-=((diff&8)?-(diff&7):(diff&7))*(4-a);
    raw=raw<0?0:raw>4095?4095:raw;
    int reference=(a<2?2250:2300)+((ref&512)?-(ref&511):(ref&511));
    uint64_t first=(uint64_t)raw*(65536U*volts[a]/reference)/65536U;
    if(!first) return 0;
    int constant=k[a][0]/(a==3?1000000000000000ULL:10000000000000000ULL);
    int linear=first*k[a][1]/(a<2?10000000000000000ULL:1000000000000000ULL);
    int square=first*first*k[a][2]/10000000000000000ULL;
    int error=a==3?constant-linear+square:-constant+linear+square;
    return first-error;
}
static unsigned long cases;
static int check(int a,int r,int d,int raw) {
    int expected=oracle(a,r,d,raw),actual=abla_c5_adc_voltage_probe(a,r,d,raw);
    cases++;
    if(actual==expected) return 0;
    fprintf(stderr,"C5 ADC a%d r%d d%d raw%d expected%d actual%d\n",a,r,d,raw,expected,actual);
    return 1;
}
int main(void) {
    const int refs[]={0,511,512,1023},raws[]={0,1,7,28,1000,2048,4067,4094,4095};
    for(int a=0;a<4;a++) for(int d=0;d<16;d++) {
        for(unsigned r=0;r<4;r++) for(int raw=0;raw<4096;raw++) if(check(a,refs[r],d,raw)) return 1;
        for(int r=0;r<1024;r++) for(unsigned i=0;i<9;i++) if(check(a,r,d,raws[i])) return 1;
    }
    if(check(-1,0,0,0)||check(4,0,0,0)||check(0,-1,0,0)||check(0,1024,0,0)||check(0,0,-1,0)||check(0,0,16,0)||check(0,0,0,-1)||check(0,0,0,4096)) return 1;
    printf("PASS: C5 ADC independent integer oracle, %lu cases\n",cases);
    return 0;
}
