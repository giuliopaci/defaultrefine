#ifndef __G2PEXPORTS_H__
#define __G2PEXPORTS_H__

#ifdef _WIN32
    #if defined(BUILD_LIBG2P) || defined(_USRDLL)
        #ifndef LIBG2P_STATIC
            #define LIBG2P_EXTERN __declspec(dllexport)
            #define LIBG2P_EXTERN_C extern "C" __declspec(dllexport)
        #else
            #define LIBG2P_EXTERN
            #define LIBG2P_EXTERN_C extern "C"
        #endif
    #else
        #ifndef LIBG2P_STATIC
            #define LIBG2P_EXTERN __declspec(dllimport)
            #define LIBG2P_EXTERN_C extern "C" __declspec(dllimport)
        #else
            #define LIBG2P_EXTERN
            #define LIBG2P_EXTERN_C extern "C"
        #endif
    #endif
#else
    #define LIBG2P_EXTERN
    #define LIBG2P_EXTERN_C extern "C"
#endif

#endif /* __G2PEXPORTS_H__ */
