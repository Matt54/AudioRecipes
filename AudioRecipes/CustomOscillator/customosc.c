#include "customosc.h"

#include <stdlib.h>
#include <math.h>
#include "soundpipe.h"
#include <stdbool.h>

int sp_customosc_create(sp_customosc **customosc)
{
    *customosc = malloc(sizeof(sp_customosc));
    return SP_OK;
}

int sp_customosc_destroy(sp_customosc **customosc)
{
    free(*customosc);
    return SP_NOT_OK;
}

int sp_customosc_init(sp_data *sp, sp_customosc *customosc, SPFLOAT iphs)
{
    customosc->freq = 440.0;
    customosc->amp = 0.2;
    customosc->iphs = fabs(iphs);
    customosc->inc = 0;
    if (customosc->iphs >= 0){
        customosc->lphs = ((int32_t)(customosc->iphs * SP_FT_MAXLEN)) & SP_FT_PHMASK;
    }

    return SP_OK;
}

int sp_customosc_compute(sp_data *sp, sp_customosc *customosc, sp_ftbl *ft_other, SPFLOAT *in, SPFLOAT *out, bool shouldInc)
{
    sp_ftbl *ftp;
    SPFLOAT amp, cps, fract, v1, v2, *ft;
    int32_t phs, lobits;
    int32_t pos;
    SPFLOAT sicvt = ft_other->sicvt;

    ftp = ft_other;
    lobits = ft_other->lobits;
    amp = customosc->amp;
    cps = customosc->freq;
    phs = customosc->lphs;
    ft = ftp->tbl;
    
    customosc->inc = (int32_t)lrintf(cps * sicvt); // rounds to nearest integer

    fract = ((phs) & ftp->lomask) * ftp->lodiv;
    pos = phs>>lobits;
    v1 = *(ft + pos);
    v2 = *(ft + ((pos + 1) % ftp->size));
    *out = (v1 + (v2 - v1) * fract) * amp;
    phs += customosc->inc;
    phs &= SP_FT_PHMASK;

    if (shouldInc) {
        customosc->lphs = phs;
    }
    return SP_OK;
}
