#include <stdint.h>
#include <stdio.h>
#include <math.h>
#include <string.h>
extern int64_t abla_imu_calibration_limits_test(int64_t,int64_t,int64_t,uint32_t,uint32_t,int32_t,int32_t);
extern int64_t abla_imu_calibration_f32_test(int64_t,int64_t,int64_t,int32_t,int32_t,int32_t,int32_t);
extern int64_t abla_imu_calibration_offset_test(int64_t,int64_t,int64_t,int32_t,int32_t,int32_t,int32_t,int32_t);
// Mirrors M5Unified calibration(), with defined wide input subtraction so
// extreme offsets don't rely on the upstream signed-overflow undefined behavior.
static float referenceGain(int64_t dx,int64_t dy,int64_t dz,float radius,float tolerance,int stillness,int strength) {
    if (!stillness || !strength) return 0;
    float x=dx,y=dy,z=dz;
    float distance=0;
    distance+=x*x; distance+=y*y; distance+=z*z;
    distance=sqrtf(distance*(1.0f/(65536.0f*65536.0f)));
    if (distance<1.0f) return 0;
    float error=distance-radius;
    float force=fabsf(error);
    if (force<=tolerance) return 0;
    if (error<0) force=-force;
    float gain=force*(stillness*strength)/(distance*(255.0f*255.0f));
    return gain;
}
int main(void) {
    uint32_t state=17;
    for (unsigned i=0;i<200000;++i) {
        state=state*1664525+1013904223; int64_t x=(int32_t)state;
        state=state*1664525+1013904223; int64_t y=(int32_t)state;
        state=state*1664525+1013904223; int64_t z=(int32_t)state;
        if ((i&7)==0) { x/=65536; y/=65536; z/=65536; }
        if ((i&7)==1) { x*=2; y*=2; z*=2; }
        int radius=(i%3==0)?4096:(i%3==1)?0:256;
        int tolerance=(i%3==0)?2:(i%3==1)?0:42;
        int stillness=i&255, strength=(i>>8)&255;
        float gain=referenceGain(x,y,z,radius,tolerance,stillness,strength);
        int64_t expected=(int64_t)roundf((float)x*gain);
        int64_t actual=abla_imu_calibration_f32_test(x,y,z,radius,tolerance,stillness,strength);
        if (expected!=actual) {
            fprintf(stderr,"case %u: got %lld expected %lld\n",i,(long long)actual,(long long)expected); return 1;
        }
        int32_t offset=(int32_t)(state^0x55555555);
        float updated=(float)offset+roundf((float)x*gain);
        // Out-of-int32 C conversion is undefined; do not make it an oracle.
        if (gain==0 || ((double)updated>=-2147483648.0 && (double)updated<2147483648.0)) {
            int64_t saved=gain==0?offset:(int32_t)updated;
            int64_t result=abla_imu_calibration_offset_test(x,y,z,radius,tolerance,stillness,strength,offset);
            if (saved!=result) {
                fprintf(stderr,"offset case %u: got %lld expected %lld\n",i,(long long)result,(long long)saved); return 1;
            }
        }
    }
    float scale=49120.0f/32760.0f, radius=384.0f/scale, tolerance=64.0f/scale;
    uint32_t rb,tb; memcpy(&rb,&radius,4); memcpy(&tb,&tolerance,4);
    for (int i=-100000;i<=100000;++i) {
        int64_t x=16777216+(int64_t)i*64,y=30000,z=-17000;
        float gain=referenceGain(x,y,z,radius,tolerance,255,255);
        int64_t expected=(int64_t)roundf((float)x*gain);
        if (abla_imu_calibration_limits_test(x,y,z,rb,tb,255,255)!=expected) return 2;
    }
    puts("PASS: 200000 delta cases, stored offsets, and 200001 fractional-limit cases");
    return 0;
}
