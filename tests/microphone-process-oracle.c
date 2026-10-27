// Algorithm adapted from M5Unified, Copyright (c) 2021 M5Stack, MIT.
// See THIRD_PARTY_NOTICES.md.
#include <stdint.h>
#include <stdio.h>
#include <string.h>
// Native non-PIE static storage stays below4GiB, matching NativeBuffer ABI.
extern int32_t abla_microphone_process_example(uint32_t,uint32_t,int32_t,uint32_t,int32_t,int32_t,int32_t,int32_t,int32_t,int32_t);
static uint32_t state[10], split[10];
static int16_t input[128];
static uint8_t actual[512], expected[512], chunked[512];
static uint32_t addr(void *p) { return (uint32_t)(uintptr_t)p; }
// Independent scalar transcription of pinned M5Unified Mic_Class processing.
static int oracle(int os,int gain,int filter,int flags) {
    int32_t dc=0,prev[2]={0},sum[2]={0}; int count=0,written=0;
    float scale=(float)gain/(os*2);
    for(int n=0;n<64;n++) {
        sum[0]+=input[n*2];sum[1]+=input[n*2+1];
        if(++count!=os) continue;
        int32_t v[4]={sum[(flags&4)?1:0],sum[(flags&4)?0:1]};
        if(flags&2) { v[0]-=2048*os;v[1]-=2048*os; }
        dc-=((v[0]+v[1])*8+dc+16)>>5;
        for(int i=0;i<2;i++) {
            v[i]+=(dc+8)>>4;
            if(filter) { v[i]=(v[i]*(256-filter)+prev[i]*filter+128)>>8;prev[i]=v[i]; }
            v[i]*=scale;
        }
        int countOut=2;
        if(!!(flags&1)!=!!(flags&8)) {
            if(flags&1) { v[0]=(v[0]+v[1]+1)>>1;countOut=1; }
            else { v[3]=v[2]=v[1];v[1]=v[0];countOut=4; }
        }
        for(int i=0;i<countOut;i++) {
            int value=v[i];
            if(flags&16) {
                if(value < -32752)value=-32752;if(value>32751)value=32751;
                expected[written*2]=(uint8_t)value;expected[written*2+1]=(uint8_t)(value>>8);
            } else {
                value=((value+128)>>8)+128;
                expected[written]=(uint8_t)(value<0?0:value>255?255:value);
            }
            written++;
        }
        sum[0]=sum[1]=0;count=0;
    }
    return written;
}
int main(void) {
    for(int n=0;n<128;n++) input[n]=(int16_t)((n*7919u+12345u)&65535);
    for(int os=1;os<=8;os++) for(int flags=0;flags<32;flags++)
    for(int gain=0;gain<=255;gain+=17) for(int f=0;f<4;f++) {
        int filter=(int[]){0,1,128,255}[f];
        int count=oracle(os,gain,filter,flags), stride=(flags&16)?2:1;
        int result=abla_microphone_process_example(addr(state),addr(input),64,addr(actual),512,os,gain,filter,flags,1);
        if(result!=count || memcmp(actual,expected,count*stride)) {
            fprintf(stderr,"oracle mismatch os=%d flags=%d gain=%d filter=%d\n",os,flags,gain,filter);return 1;
        }
        int offset=0;
        for(int n=0;n<64;n++) {
            result=abla_microphone_process_example(addr(split),addr(input+n*2),1,addr(chunked+offset*stride),512-offset*stride,os,gain,filter,flags,n==0);
            if(result<0)return 2;offset+=result;
        }
        if(offset!=count || memcmp(actual,chunked,count*stride) || memcmp(state,split,sizeof(state)))return 3;
    }
    uint32_t saved[10];memcpy(saved,state,sizeof state);
    if(abla_microphone_process_example(addr(state),addr(input),64,addr(actual),0,1,1,0,16,0)!=-1 || memcmp(saved,state,sizeof state))return 4;
    if(abla_microphone_process_example(addr(state),addr(input),0,addr(actual),0,1,1,0,16,0)!=0 || memcmp(saved,state,sizeof state))return 5;
    if(abla_microphone_process_example(addr(state),addr(input),64,addr(input),256,1,1,0,16,0)!=-1 || memcmp(saved,state,sizeof state))return 6;
    if(abla_microphone_process_example(addr(state),addr(input),64,addr(state),40,1,1,0,0,0)!=-1 || memcmp(saved,state,sizeof state))return 7;
    puts("PASS:16384 oracle profiles, streaming split parity, short-output rejection");return 0;
}
