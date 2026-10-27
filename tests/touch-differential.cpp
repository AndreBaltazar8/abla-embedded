// Host-only independent semantic model of M5Unified Touch_Class::update_detail.
// Compare observable fields, not packed-point metadata in Abla prev/base slots.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <initializer_list>

extern "C" int32_t abla_touch_transition(int64_t, uint32_t, int32_t,
    int32_t, int32_t, uint32_t, uint32_t, uint32_t, uint32_t);

struct Detail {
    int x=0, y=0, px=0, py=0, bx=0, by=0;
    unsigned size=0, id=0, state=0, clicks=0;
    uint32_t since=0;
};
static bool step(Detail& d, uint32_t now, int op, int x, int y,
                 unsigned size, unsigned id, unsigned hold, unsigned flick) {
    if (!d.state && op != 1) return false;
    const unsigned stable = d.state & ~2u;
    unsigned next = stable;
    if (op == 0) {
        next = (stable & 1) ? ((stable | 2) & ~1u) : 0;
        if (next == 2) { d.since=now; d.clicks=(d.clicks+1)&255; }
    } else if (op == 2) {
        if (!(stable&1)) next=0;
        else {
            d.px=d.x; d.py=d.y;
            if (stable==1 && uint32_t(now-d.since)>hold) next=7;
        }
    } else {
        d.px=d.x; d.py=d.y; d.size=size; d.id=id;
        if (!(stable&8)) {
            const unsigned distance = unsigned(std::abs(d.bx-x) > std::abs(d.by-y)
                ? std::abs(d.bx-x) : std::abs(d.by-y));
            if (!(stable&1)) {
                if (uint32_t(now-d.since)>hold || distance>4*(flick+1)) d.clicks=0;
                d.x=d.bx=d.px=x; d.y=d.by=d.py=y; d.since=now; next=3;
            } else if (distance>flick) {
                d.px=d.bx; d.py=d.by; next=stable|11;
            } else if (stable==1 && uint32_t(now-d.since)>hold) next=7;
        }
        if (next&8) { d.x=x; d.y=y; }
    }
    d.state=next;
    return true;
}
static uint64_t pack(int x,int y,unsigned size=0,unsigned id=0) {
    return uint16_t(x) | (uint64_t(uint16_t(y))<<16) | (uint64_t(size)<<32)
        | (uint64_t(id&7)<<48) | (uint64_t(id&8)<<49) | (uint64_t(1)<<51);
}
static uint32_t randomWord() {
    static uint32_t s=0x73294019;
    s^=s<<13; s^=s>>17; s^=s<<5; return s;
}
static unsigned checks=0;
static bool check(Detail& d, uint64_t* storage, uint32_t now, int op,
                  int x,int y,unsigned size,unsigned id,unsigned hold,unsigned flick) {
    const bool expected=step(d,now,op,x,y,size,id,hold,flick);
    const int actual=abla_touch_transition(int64_t(uintptr_t(storage)),now,op,
        x,y,size,id,hold,flick);
    const auto p=storage[0], prev=storage[1], base=storage[2], tail=storage[3];
    ++checks;
    if (actual!=int(expected) || int16_t(p)!=d.x || int16_t(p>>16)!=d.y ||
        ((p>>32)&65535)!=d.size || (((p>>48)&7)|((p>>49)&8))!=d.id ||
        int16_t(prev)!=d.px || int16_t(prev>>16)!=d.py ||
        int16_t(base)!=d.bx || int16_t(base>>16)!=d.by ||
        uint32_t(tail)!=d.since || ((tail>>32)&255)!=d.state ||
        ((tail>>40)&255)!=d.clicks) {
        std::fprintf(stderr,"touch mismatch check=%u op=%d now=%u hold=%u flick=%u state=%llu/%u\n",
            checks,op,now,hold,flick,static_cast<unsigned long long>((tail>>32)&255),d.state);
        return false;
    }
    return true;
}
int main() {
    const unsigned states[]={0,1,2,3,5,6,7,9,10,11,13,14,15};
    const unsigned thresholds[]={0,1,8,255,65535};
    // Exact boundary and one-past-boundary from every reachable state.
    for (unsigned state:states) for (unsigned hold:thresholds)
    for (unsigned flick:thresholds) for (int op=0;op<3;++op)
    for (unsigned elapsed: {0u,hold,hold+1}) for (int delta: {-32768,-9,-8,0,8,9,32767}) {
        Detail d; d.state=state; d.clicks=255; d.since=0xfffffff0;
        uint64_t storage[4]={pack(0,0),pack(0,0),pack(0,0),
            uint64_t(d.since)|(uint64_t(state)<<32)|(uint64_t(255)<<40)};
        if (!check(d,storage,d.since+elapsed,op,delta,-delta-1,65535,15,hold,flick)) return 1;
    }
    // Continuous histories exercise state retention, repeated taps and wrap.
    for (unsigned hold:thresholds) for (unsigned flick:thresholds) {
        Detail d;
        uint64_t storage[4]={};
        uint32_t now=0xffffff00;
        for (unsigned i=0;i<10000;++i) {
            now+=randomWord()%32;
            int x=d.bx+int(randomWord()%21)-10;
            int y=d.by+int(randomWord()%21)-10;
            if (!check(d,storage,now,int(randomWord()%3),int16_t(x),int16_t(y),
                randomWord()&65535,randomWord()&15,hold,flick)) return 1;
        }
    }
    std::printf("PASS touch differential: %u transitions\n",checks);
}
