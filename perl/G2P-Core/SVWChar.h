/*
 * Below is from the PERL module Win32 version 0.29
 */

#pragma once

#include "ppport.h"

/* Convert SV to wide character string.  The return value must be
 * freed using Safefree().
 */
WCHAR*
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
