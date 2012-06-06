#pragma once

#include "ppport.h"

/*
 * Below is from the PERL module Lucene version 0.18
 */

wchar_t *
SvToWChar(pTHX_ SV *arg)
{
    wchar_t *ret;
    // Get string length of argument. This works for PV, NV and IV.
    // The STRLEN typdef is needed to ensure that this will work correctly
    // in a 64-bit environment.
    STRLEN arg_len;
    SvPV(arg, arg_len);

    // Alloc memory for wide char string.  This could be a bit more
    // then necessary.
    Newz(0, ret, arg_len + 1, wchar_t);

    U8 *src = (U8 *)SvPV_nolen(arg);
    wchar_t *dst = ret;

    if (SvUTF8(arg)) {
        // UTF8 to wide char mapping
        STRLEN len;
        while (*src) {
            *dst++ = utf8_to_uvuni(src, &len);
            src += len;
        }
    } else {
        // char to wide char mapping
        while (*src) {
            *dst++ = (wchar_t)*src++;
        }
    }
    *dst = 0;
    return ret;
}

SV *
WCharToSv(pTHX_ wchar_t *src, SV *dest)
{
    U8 *dst;
    U8 *d;

    // Alloc memory for wide char string.  This is clearly wider
    // then necessary in most cases but no choice.
    Newz(0, dst, 3 * wcslen(src) + 1, U8);

    d = dst;
    while (*src) {
        d = uvuni_to_utf8(d, *src++);
    }
    *d = 0;

    sv_setpv(dest, (char *)dst);
    sv_utf8_decode(dest);

    Safefree(dst);
    return dest;
}

/*
 * Below is from the PERL module Win32 version 0.29
 */

#if defined(_WIN32)

/* Convert SV to wide character string.  The return value must be
 * freed using Safefree().
 */
WCHAR *
sv_to_wstr(pTHX_ SV *sv)
{
    DWORD wlen;
    WCHAR *wstr;
    STRLEN len;
    char *str = SvPV(sv, len);
    UINT cp = SvUTF8(sv) ? CP_UTF8 : CP_ACP;

#if defined(_WIN32)
    wlen = MultiByteToWideChar(cp, 0, str, len + 1, NULL, 0);
    New(0, wstr, wlen, WCHAR);
    MultiByteToWideChar(cp, 0, str, len + 1, wstr, wlen);
#else
#  error Not implemented
#endif

    return wstr;
}

/* Convert wide character string to mortal SV.  Use UTF8 encoding
 * if the string cannot be represented in the system codepage.
 */
SV *
wstr_to_sv(pTHX_ WCHAR *wstr)
{
    size_t wlen = wcslen(wstr) + 1;
    BOOL use_default = FALSE;
    int len =
#if defined(_WIN32)
		WideCharToMultiByte(CP_ACP, WC_NO_BEST_FIT_CHARS, wstr, wlen, NULL, 0, NULL, NULL);
#else
#  error Not implemented
#endif
    SV *sv = sv_2mortal(newSV(len));

#if defined(_WIN32)
    len = WideCharToMultiByte(CP_ACP, WC_NO_BEST_FIT_CHARS, wstr, wlen, SvPVX(sv), len, NULL, &use_default);
#else
#  error Not implemented
#endif
    if (use_default) {
#if defined(_WIN32)
        len = WideCharToMultiByte(CP_UTF8, 0, wstr, wlen, NULL, 0, NULL, NULL);
#else
#  error Not implemented
#endif
        sv_grow(sv, len);
#if defined(_WIN32)
        len = WideCharToMultiByte(CP_UTF8, 0, wstr, wlen, SvPVX(sv), len, NULL, NULL);
#else
#  error Not implemented
#endif
        SvUTF8_on(sv);
    }
    /* Shouldn't really ever fail since we ask for the required length first, but who knows... */
    if (len) {
        SvPOK_on(sv);
        SvCUR_set(sv, len - 1);
    }
    return sv;
}

#endif /* _WIN32 */

