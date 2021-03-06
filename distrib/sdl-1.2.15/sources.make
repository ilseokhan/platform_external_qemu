# This is included from the main Android emulator build script
# to declare the SDL-related sources, compiler flags and libraries
#

SDL_OLD_LOCAL_PATH := $(LOCAL_PATH)

LOCAL_PATH := $(call my-dir)

SDL_CFLAGS := -I$(LOCAL_PATH)/include
SDL_LDLIBS :=
SDL_STATIC_LIBRARIES :=

SDL_SOURCES :=

ifeq ($(HOST_OS),linux)
    SDL_CONFIG_LOADSO_DLOPEN := yes
    SDL_CONFIG_THREAD_PTHREAD := yes
    SDL_CONFIG_THREAD_PTHREAD_RECURSIVE_MUTEX_NP := yes
    SDL_CONFIG_TIMER_UNIX := yes
    SDL_CONFIG_VIDEO_X11 := yes
    SDL_CONFIG_VIDEO_X11_DPMS := yes
    SDL_CONFIG_VIDEO_X11_XINERAMA := yes
    SDL_CONFIG_VIDEO_X11_XME := yes
    SDL_CONFIG_MAIN_DUMMY := yes

    SDL_CFLAGS += -D_GNU_SOURCE=1 -D_REENTRANT
    SDL_LDLIBS += -lm -ldl -lpthread -lrt
endif

ifeq ($(HOST_OS),freebsd)
    SDL_CONFIG_LOADSO_DLOPEN := yes
    SDL_CONFIG_THREAD_PTHREAD := yes
    SDL_CONFIG_THREAD_PTHREAD_RECURSIVE_MUTEX := yes
    SDL_CONFIG_TIMER_UNIX := yes
    SDL_CONFIG_VIDEO_X11 := yes
    SDL_CONFIG_VIDEO_X11_DPMS := yes
    SDL_CONFIG_VIDEO_X11_XINERAMA := yes
    SDL_CONFIG_VIDEO_X11_XME := yes
    SDL_CONFIG_MAIN_DUMMY := yes

    SDL_CFLAGS += -D_GNU_SOURCE=1 -D_REENTRANT
    SDL_LDLIBS += -lm -ldl -lpthread
endif

ifeq ($(HOST_OS),darwin)
    SDL_CONFIG_LOADSO_DLCOMPAT := yes
    SDL_CONFIG_THREAD_PTHREAD := yes
    SDL_CONFIG_THREAD_PTHREAD_RECURSIVE_MUTEX := yes
    SDL_CONFIG_TIMER_UNIX := yes
    SDL_CONFIG_VIDEO_QUARTZ := yes
    SDL_CONFIG_MAIN_MACOSX := yes

    SDL_CFLAGS += -D_GNU_SOURCE=1 -DTHREAD_SAFE
    FRAMEWORKS := OpenGL Cocoa ApplicationServices Carbon IOKit
    SDL_LDLIBS += $(FRAMEWORKS:%=-Wl,-framework,%)

    # SDK 10.6+ deprecates __dyld_func_lookup required by dlcompat_init_func
    # in SDL_dlcompat.o this module depends.  Instruct linker to resolve it
    # at runtime.
    OSX_VERSION_MAJOR := $(shell echo $(mac_sdk_version) | cut -d . -f 2)
    OSX_VERSION_MAJOR_GREATER_THAN_OR_EQUAL_TO_6 := $(shell [ $(OSX_VERSION_MAJOR) -ge 6 ] && echo true)
    ifeq ($(OSX_VERSION_MAJOR_GREATER_THAN_OR_EQUAL_TO_6),true)
        LOCAL_LDLIBS += -Wl,-undefined,dynamic_lookup
    endif
endif

ifeq ($(HOST_OS),windows)
    SDL_CONFIG_LOADSO_WIN32 := yes
    SDL_CONFIG_THREAD_WIN32 := yes
    SDL_CONFIG_TIMER_WIN32 := yes
    SDL_CONFIG_VIDEO_WINDIB := yes
    SDL_CONFIG_MAIN_WIN32 := yes

    SDL_CFLAGS += -D_GNU_SOURCE=1 -Dmain=SDL_main -DNO_STDIO_REDIRECT=1
    SDL_LDLIBS += -luser32 -lgdi32 -lwinmm
endif


# the main src/ sources
#
SRCS := SDL.c \
        SDL_error.c \
        SDL_fatal.c \

SRCS += events/SDL_active.c \
	events/SDL_events.c \
	events/SDL_expose.c \
	events/SDL_keyboard.c \
	events/SDL_mouse.c \
	events/SDL_quit.c \
	events/SDL_resize.c \

SRCS += file/SDL_rwops.c

SRCS += stdlib/SDL_getenv.c \
        stdlib/SDL_iconv.c \
        stdlib/SDL_malloc.c \
        stdlib/SDL_qsort.c \
        stdlib/SDL_stdlib.c \
        stdlib/SDL_string.c

SRCS += cpuinfo/SDL_cpuinfo.c

SDL_SOURCES += $(SRCS:%=src/%)

# the LoadSO sources
#

SRCS :=

ifeq ($(SDL_CONFIG_LOADSO_DLOPEN),yes)
  SRCS += dlopen/SDL_sysloadso.c
  SDL_LDLIBS += -ldl
endif

ifeq ($(SDL_CONFIG_LOADSO_DLCOMPAT),yes)
  SRCS += macosx/SDL_dlcompat.c
endif

ifeq ($(SDL_CONFIG_LOADSO_WIN32),yes)
  SRCS += win32/SDL_sysloadso.c
endif

SDL_SOURCES += $(SRCS:%=src/loadso/%)

# the Thread sources
#

SRCS := SDL_thread.c

ifeq ($(SDL_CONFIG_THREAD_PTHREAD),yes)
  SRCS += pthread/SDL_syscond.c \
          pthread/SDL_sysmutex.c \
          pthread/SDL_syssem.c \
          pthread/SDL_systhread.c
endif

ifeq ($(SDL_CONFIG_THREAD_WIN32),yes)
  SRCS += win32/SDL_sysmutex.c \
          win32/SDL_syssem.c \
          win32/SDL_systhread.c
endif

SDL_SOURCES += $(SRCS:%=src/thread/%)

# the Timer sources
#

SRCS := SDL_timer.c

ifeq ($(SDL_CONFIG_TIMER_UNIX),yes)
  SRCS += unix/SDL_systimer.c
endif

ifeq ($(SDL_CONFIG_TIMER_WIN32),yes)
  SRCS += win32/SDL_systimer.c
endif

SDL_SOURCES += $(SRCS:%=src/timer/%)

# the Video sources
#

SRCS := SDL_RLEaccel.c \
	SDL_blit.c \
	SDL_blit_0.c \
	SDL_blit_1.c \
	SDL_blit_A.c \
	SDL_blit_N.c \
	SDL_bmp.c \
	SDL_cursor.c \
	SDL_gamma.c \
	SDL_pixels.c \
	SDL_stretch.c \
	SDL_surface.c \
	SDL_video.c \
	SDL_yuv.c \
	SDL_yuv_mmx.c \
	SDL_yuv_sw.c \

SRCS += dummy/SDL_nullevents.c \
        dummy/SDL_nullmouse.c \
        dummy/SDL_nullvideo.c

ifeq ($(SDL_CONFIG_VIDEO_WINDIB),yes)
  SRCS += windib/SDL_dibevents.c \
          windib/SDL_dibvideo.c \
          wincommon/SDL_sysevents.c \
          wincommon/SDL_sysmouse.c \
          wincommon/SDL_syswm.c \
          wincommon/SDL_wingl.c
endif

ifeq ($(SDL_CONFIG_VIDEO_QUARTZ),yes)
  SRCS += quartz/SDL_QuartzGL.m \
          quartz/SDL_QuartzVideo.m \
          quartz/SDL_QuartzWM.m \
          quartz/SDL_QuartzWindow.m \
          quartz/SDL_QuartzEvents.m
endif

ifeq ($(SDL_CONFIG_VIDEO_X11),yes)
  SRCS += x11/SDL_x11dyn.c \
          x11/SDL_x11dga.c \
          x11/SDL_x11events.c \
          x11/SDL_x11gamma.c \
          x11/SDL_x11gl.c \
          x11/SDL_x11image.c \
          x11/SDL_x11modes.c \
          x11/SDL_x11mouse.c \
          x11/SDL_x11video.c \
          x11/SDL_x11wm.c \
          x11/SDL_x11yuv.c
endif

ifeq ($(SDL_CONFIG_VIDEO_X11_DGAMOUSE),yes)
  SRCS += x11/SDL_x11dga.c
endif

ifeq ($(SDL_CONFIG_VIDEO_X11_XME),yes)
  SRCS += Xext/XME/xme.c
endif

ifeq ($(SDL_CONFIG_VIDEO_X11_XINERAMA),yes)
  SRCS += Xext/Xinerama/Xinerama.c
endif

ifeq ($(SDL_CONFIG_VIDEO_X11_XV),yes)
  SRCS += Xext/Xv/Xv.c
endif

SDL_SOURCES += $(SRCS:%=src/video/%)

$(call start-emulator-library,emulator_libSDL)
LOCAL_C_INCLUDES += $(LOCAL_PATH)/include
LOCAL_SRC_FILES := $(SDL_SOURCES)
$(call end-emulator-library)

ifdef EMULATOR_BUILD_64BITS
$(call start-emulator-library,emulator_lib64SDL)
LOCAL_SRC_FILES := $(SDL_SOURCES)
LOCAL_C_INCLUDES += $(LOCAL_PATH)/include
LOCAL_CFLAGS += -m64 -fPIC
$(call end-emulator-library)
endif  # EMULATOR_BUILD_64BITS

## Build libSDLmain
##

SRCS :=

ifeq ($(SDL_CONFIG_MAIN_DUMMY),yes)
  SRCS += dummy/SDL_dummy_main.c
endif

ifeq ($(SDL_CONFIG_MAIN_MACOSX),yes)
  SRCS += macosx/SDLMain.m
endif

ifeq ($(SDL_CONFIG_MAIN_WIN32),yes)
  SRCS += win32/SDL_win32_main.c
endif

SDLMAIN_SOURCES := $(SRCS:%=src/main/%)

$(call start-emulator-library,emulator_libSDLmain)
LOCAL_C_INCLUDES += $(LOCAL_PATH)/include
LOCAL_SRC_FILES := $(SDLMAIN_SOURCES)
$(call end-emulator-library)

ifdef EMULATOR_BUILD_64BITS
  $(call start-emulator-library,emulator_lib64SDLmain)
  LOCAL_C_INCLUDES += $(LOCAL_PATH)/include
  LOCAL_SRC_FILES := $(SDLMAIN_SOURCES)
  LOCAL_CFLAGS += -m64
  $(call end-emulator-library)
endif  # EMULATOR_BUILD_64BITS

# Restore LOCAL_PATH
LOCAL_PATH := $(SDL_OLD_LOCAL_PATH)
