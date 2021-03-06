#
# common bits used by all libraries
#

# first so "all" becomes default target
all: all-yes

DEFAULT_YASMD=.dbg

ifeq ($(DBG),1)
YASMD=$(DEFAULT_YASMD)
else
YASMD=
endif

ifndef SUBDIR

ifndef V
Q      = @
ECHO   = printf "$(1)\t%s\n" $(2)
BRIEF  = CC CXX OBJCC HOSTCC HOSTLD AS YASM AR LD STRIP CP WINDRES
SILENT = DEPCC DEPHOSTCC DEPAS DEPYASM RANLIB RM

MSG    = $@
M      = @$(call ECHO,$(TAG),$@);
$(foreach VAR,$(BRIEF), \
    $(eval override $(VAR) = @$$(call ECHO,$(VAR),$$(MSG)); $($(VAR))))
$(foreach VAR,$(SILENT),$(eval override $(VAR) = @$($(VAR))))
$(eval INSTALL = @$(call ECHO,INSTALL,$$(^:$(SRC_DIR)/%=%)); $(INSTALL))
endif

ALLFFLIBS = avcodec avdevice avfilter avformat avresample avutil postproc swscale swresample

# NASM requires -I path terminated with /
IFLAGS     := -I$(DST_PATH)/ -I$(SRC_PATH)/
CPPFLAGS   := $(IFLAGS) $(CPPFLAGS)
CFLAGS     += $(ECFLAGS)
CCFLAGS     = $(CPPFLAGS) $(CFLAGS)
OBJCFLAGS  += $(EOBJCFLAGS)
OBJCCFLAGS  = $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS)
ASFLAGS    := $(CPPFLAGS) $(ASFLAGS)
CXXFLAGS   += $(CPPFLAGS) $(CFLAGS)
YASMFLAGS  += $(IFLAGS:%=%/) -Pconfig.asm

HOSTCCFLAGS = $(IFLAGS) $(HOSTCPPFLAGS) $(HOSTCFLAGS)
LDFLAGS    := $(ALLFFLIBS:%=$(LD_PATH)$(DST_PATH)/lib%) $(LDFLAGS)

define COMPILE
       $(call $(1)DEP,$(1))
       $(Q)cd $(SRC_PATH); if [ -n "$(findstring $(SRC_PATH),$<)" ]; then dest=$(subst $(SRC_PATH)/,,$<); else dest=$(DST_PATH)/$<; fi; \
       $(subst @,,$($(1))) $($(1)FLAGS) $($(1)_DEPFLAGS:$(@:.o=.d)=$(DST_PATH)/$(@:.o=.d)) $($(1)_C) $($(1)_O:$@=$(DST_PATH)/$@) $$dest
endef

COMPILE_C = $(call COMPILE,CC)
COMPILE_CXX = $(call COMPILE,CXX)
COMPILE_S = $(call COMPILE,AS)
COMPILE_M = $(call COMPILE,OBJCC)
COMPILE_HOSTC = $(call COMPILE,HOSTCC)

%.o: %.c
	$(COMPILE_C)

%.o: %.cpp
	$(COMPILE_CXX)

%.o: %.m
	$(COMPILE_M)

%.s: %.c
	$(CC) $(CCFLAGS) -S -o $@ $<

%.o: %.S
	$(COMPILE_S)

%_host.o: %.c
	$(COMPILE_HOSTC)

%.o: %.rc
	$(WINDRES) $(IFLAGS) --preprocessor "$(DEPWINDRES) -E -xc-header -DRC_INVOKED $(CC_DEPFLAGS)" -o $@ $<

%.i: %.c
	$(CC) $(CCFLAGS) $(CC_E) $<

%.h.c:
	$(Q)echo '#include "$*.h"' >$@

%.ver: %.v
	$(Q)sed 's/$$MAJOR/$($(basename $(@F))_VERSION_MAJOR)/' $^ | sed -e 's/:/:\
/' -e 's/; /;\
/g' > $@

%.c %.h: TAG = GEN

# Dummy rule to stop make trying to rebuild removed or renamed headers
%.h:
	@:

# Disable suffix rules.  Most of the builtin rules are suffix rules,
# so this saves some time on slow systems.
.SUFFIXES:

# Do not delete intermediate files from chains of implicit rules
$(OBJS):
endif

include $(SRC_PATH)/arch.mak

OBJS      += $(OBJS-yes)
SLIBOBJS  += $(SLIBOBJS-yes)
FFLIBS    := $($(NAME)_FFLIBS) $(FFLIBS-yes) $(FFLIBS)
TESTPROGS += $(TESTPROGS-yes)

LDLIBS       = $(FFLIBS:%=%$(BUILDSUF))
FFEXTRALIBS := $(LDLIBS:%=$(LD_LIB)) $(EXTRALIBS)

OBJS      := $(sort $(OBJS:%=$(SUBDIR)%))
SLIBOBJS  := $(sort $(SLIBOBJS:%=$(SUBDIR)%))
TESTOBJS  := $(TESTOBJS:%=$(SUBDIR)%) $(TESTPROGS:%=$(SUBDIR)%-test.o)
TESTPROGS := $(TESTPROGS:%=$(SUBDIR)%-test$(EXESUF))
HOSTOBJS  := $(HOSTPROGS:%=$(SUBDIR)%.o)
HOSTPROGS := $(HOSTPROGS:%=$(SUBDIR)%$(HOSTEXESUF))
TOOLS     += $(TOOLS-yes)
TOOLOBJS  := $(TOOLS:%=tools/%.o)
TOOLS     := $(TOOLS:%=tools/%$(EXESUF))
HEADERS   += $(HEADERS-yes)

PATH_LIBNAME = $(foreach NAME,$(1),lib$(NAME)/$($(2)LIBNAME))
DEP_LIBS := $(foreach lib,$(FFLIBS),$(call PATH_LIBNAME,$(lib),$(CONFIG_SHARED:yes=S)))
STATIC_DEP_LIBS := $(foreach lib,$(FFLIBS),$(call PATH_LIBNAME,$(lib)))

SRC_DIR    := $(SRC_PATH)/lib$(NAME)
ALLHEADERS := $(subst $(SRC_DIR)/,$(SUBDIR),$(wildcard $(SRC_DIR)/*.h $(SRC_DIR)/$(ARCH)/*.h))
SKIPHEADERS += $(ARCH_HEADERS:%=$(ARCH)/%) $(SKIPHEADERS-)
SKIPHEADERS := $(SKIPHEADERS:%=$(SUBDIR)%)
HOBJS        = $(filter-out $(SKIPHEADERS:.h=.h.o),$(ALLHEADERS:.h=.h.o))
checkheaders: $(HOBJS)
.SECONDARY:   $(HOBJS:.o=.c)

alltools: $(TOOLS)

$(HOSTOBJS): %.o: %.c
	$(COMPILE_HOSTC)

$(HOSTPROGS): %$(HOSTEXESUF): %.o
	$(HOSTLD) $(HOSTLDFLAGS) $(HOSTLD_O) $^ $(HOSTLIBS)

$(OBJS):     | $(sort $(dir $(OBJS)))
$(HOBJS):    | $(sort $(dir $(HOBJS)))
$(HOSTOBJS): | $(sort $(dir $(HOSTOBJS)))
$(SLIBOBJS): | $(sort $(dir $(SLIBOBJS)))
$(TESTOBJS): | $(sort $(dir $(TESTOBJS)))
$(TOOLOBJS): | tools

OBJDIRS := $(OBJDIRS) $(dir $(OBJS) $(HOBJS) $(HOSTOBJS) $(SLIBOBJS) $(TESTOBJS))

CLEANSUFFIXES     = *.d *.o *~ *.h.c *.map *.ver *.ver-sol2 *.ho *.gcno *.gcda *$(DEFAULT_YASMD).asm
DISTCLEANSUFFIXES = *.pc
LIBSUFFIXES       = *.a *.lib *.so *.so.* *.dylib *.dll *.def *.dll.a

define RULES
clean::
	$(RM) $(OBJS) $(OBJS:.o=.d) $(OBJS:.o=$(DEFAULT_YASMD).d)
	$(RM) $(HOSTPROGS)
	$(RM) $(TOOLS)
endef

$(eval $(RULES))

-include $(wildcard $(OBJS:.o=.d) $(HOSTOBJS:.o=.d) $(TESTOBJS:.o=.d) $(HOBJS:.o=.d) $(SLIBOBJS:.o=.d)) $(OBJS:.o=$(DEFAULT_YASMD).d)
