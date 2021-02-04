#ifndef customosc_h
#define customosc_h

#include <stdio.h>
#include "soundpipe.h"
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    SPFLOAT freq, amp, iphs;
    int32_t   lphs;
    int inc;
} sp_customosc;

int sp_customosc_create(sp_customosc **customosc);
int sp_customosc_destroy(sp_customosc **customosc);
int sp_customosc_init(sp_data *sp, sp_customosc *customosc, SPFLOAT iphs);
int sp_customosc_compute(sp_data *sp, sp_customosc *customosc, sp_ftbl *ft, SPFLOAT *in, SPFLOAT *out, bool shouldInc);

#ifdef __cplusplus
} // extern "C"
#endif


#endif /* customcustomosc_h */
