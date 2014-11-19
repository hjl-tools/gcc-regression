ifndef SRC
SRC=src-trunk
endif

ifndef SPEC-GCC
ifeq ($(GCC),gcc-avx)
SPEC-GCC=$(GCC)
else
SPEC-GCC=gcc
endif
endif

SOURCE-DIR=../$(SRC)
BUILD-DIR=bld

include mail.conf

ifneq (,$(wildcard build.conf))
include build.conf
endif

ifneq (,$(wildcard spec.conf))
include spec.conf
endif

ifneq (,$(wildcard tune.mk))
include tune.mk
endif

SPEC-TUNE-FLAGS?=-T all
SPEC-FLAGS?=$(SPEC-TUNE-FLAGS) -n 1 -l -o asc -I all
SPEC-2000-FLAGS?=$(SPEC-FLAGS)
SPEC-2006-FLAGS?=$(SPEC-FLAGS)

TUNE-SPEC-FLAGS?=$(SPEC-TUNE-FLAGS) -l -o asc -I all
TUNE-SPEC-2000-FLAGS?=$(TUNE-SPEC-FLAGS) -n 3
TUNE-SPEC-2006-FLAGS?=$(TUNE-SPEC-FLAGS) -n 1

RUN-SPEC-FLAGS?=$(SPEC-TUNE-FLAGS) -l -o asc -I all
RUN-SPEC-2000-FLAGS?=$(RUN-SPEC-FLAGS) -n 3
RUN-SPEC-2006-FLAGS?=$(RUN-SPEC-FLAGS) -n 1

ifeq (yes,$(LTO_SPEC_CPU))
SPEC-2000-FLAGS+=-e lto
SPEC-2006-FLAGS+=-e lto
TUNE-SPEC-2000-FLAGS+=-e lto
TUNE-SPEC-2006-FLAGS+=-e lto
RUN-SPEC-2000-FLAGS+=-e lto
RUN-SPEC-2006-FLAGS+=-e lto
endif

KILLALL?=killall

CHECK-SPEC?=check-spec-cpu-2000 check-spec-cpu-2006

BUILD-SPEC?=no
CLEAN-SPEC?=yes

ARCH?=$(shell arch)
BUILD-ARCH:=$(shell arch)
NUM-CPUS:=$(shell /usr/bin/getconf _NPROCESSORS_ONLN)
NUM-CPUS:=$(shell if [ $(NUM-CPUS) -ge 12 ]; then echo 12; else echo $(NUM-CPUS);fi)

ifdef RATE
SPEC-2000-FLAGS+=--rate --users $(NUM-CPUS)
SPEC-2006-FLAGS+=--rate --copies $(NUM-CPUS)
RUN-SPEC-2000-FLAGS+=--rate --users $(NUM-CPUS)
RUN-SPEC-2006-FLAGS+=--rate --copies $(NUM-CPUS)
endif

ifeq (16,$(NUM-CPUS))
PARALLELMFLAGS:=-j 8
else
ifeq (1,$(NUM-CPUS))
PARALLELMFLAGS:=-j `expr $(NUM-CPUS) + $(NUM-CPUS)`
else
PARALLELMFLAGS:=-j $(NUM-CPUS)
endif
endif

VERSION=$(shell cat $(SRC)/gcc/BASE-VER)

CONFIG-FLAGS+=$(CONFIG_FLAGS)

PREFIX?=/usr/$(VERSION)
ifeq (yes,$(BUILD-SERVER))
ifneq ($(SRC),src-4.4)
LANG-FLAGS?=--enable-languages=c,c++,fortran,lto
else
LANG-FLAGS?=--enable-languages=c,c++,fortran
endif # src-4.4
CHECK=gcc-tar-file
else # BUILD-SERVER
ifeq (,$(wildcard spec))
CHECK=check-gcc
ifneq ($(SRC),src-4.4)
LANG-FLAGS?=--enable-languages=c,c++,fortran,java,lto,objc
endif
else # spec
CHECK=check-spec
PREFIX=$(PWD)/usr
ifneq ($(SRC),src-4.4)
LANG-FLAGS?=--enable-languages=c,c++,fortran,lto
ifneq ($(SRC),src-4.5)
ifneq ($(SRC),src-4.6)
# Enable x32 if possible
ifneq ($(ENABLE_X32),no)
override ENABLE_X32=yes
endif
endif # src-4.6
endif # src-4.5
else
LANG-FLAGS?=--enable-languages=c,c++,fortran
endif # src-4.4
endif # spec
endif # BUILD-SERVER
CONFIG-FLAGS+=--prefix=$(PREFIX)

#CONFIG-FLAGS+=--enable-checking=assert
CONFIG-FLAGS+=--enable-clocale=gnu --with-system-zlib
CONFIG-FLAGS+=--enable-shared
CONFIG-FLAGS+=--with-demangler-in-ld

#CONFIG-FLAGS+=--with-cpu=nocona
#CONFIG-FLAGS+=--disable-bootstrap
#CONFIG-FLAGS=--enable-languages=c,c++,fortran --disable-bootstrap

ifeq ($(ENABLE_X32),yes)
# Enable x32 run-time libraries.
CONFIG-FLAGS+=--with-multilib-list=m32,m64,mx32
ifeq ($(SRC),src-4.7)
# Enable only C, C++, Fortran and Objective C for x32 in GCC 4.7.
LANG-FLAGS=--enable-languages=c,c++,fortran,objc
endif
else
ifeq ($(SRC),src-trunk)
#WITH-PLL=yes
endif
endif

ifeq ($(WITH-PLL),yes)
GNU-PREFIX=/opt/gnu
CONFIG-FLAGS+=--enable-cloog-backend=isl
ifeq (x86_64,$(ARCH))
CONFIG-FLAGS+=--with-ppl-include=$(GNU-PREFIX)/include
CONFIG-FLAGS+=--with-ppl-lib=$(GNU-PREFIX)/lib64
CONFIG-FLAGS+=--with-cloog-include=$(GNU-PREFIX)/include
CONFIG-FLAGS+=--with-cloog-lib=$(GNU-PREFIX)/lib64
else
CONFIG-FLAGS+=--with-ppl=$(GNU-PREFIX)
CONFIG-FLAGS+=--with-cloog=$(GNU-PREFIX)
endif
endif

FLAGS-TO-PASS=

ifeq (,$(findstring --disable-bootstrap, $(CONFIG-FLAGS)))
BUILD=bootstrap-lean
ifeq (yes,$(PROFILEDBOOTSTRAP))
BUILD=profiledbootstrap
else
BUILD=bootstrap
endif
else
BUILD=all
BOOT_CFLAGS=-g
FLAGS-TO-PASS+=BOOT_CFLAGS="$(BOOT_CFLAGS)"
FLAGS-TO-PASS+=CFLAGS="$(BOOT_CFLAGS)"
endif

ifeq (yes,$(LTO_BUILD))
CONFIG-FLAGS+=--with-build-config=bootstrap-lto
# Disable libcc1 with bootstrap-lto.
CONFIG-FLAGS+=--disable-libcc1
ifeq (yes,$(PROFILEDBOOTSTRAP))
# Disable -Werror with bootstrap-lto and profiledbootstrap.
CONFIG-FLAGS+=--disable-werror
endif
endif

#FLAGS-TO-PASS+=CXXFLAGS="$(BOOT_CFLAGS)"

ifndef ARCHES
ARCHES=$(ARCH)
ifeq (x86_64,$(ARCH))
ifeq ($(ENABLE_X32),yes)
ARCHES+=x32
endif
ARCHES+=i686
endif
endif

ifeq (x86_64,$(ARCH))
ifeq ($(ENABLE_X32),yes)
RUNTESTFLAGS=--target_board='unix{-mx32}'
else
RUNTESTFLAGS=--target_board='unix{-m32,}'
endif
FLAGS-TO-PASS+=RUNTESTFLAGS="$(RUNTESTFLAGS)"
endif

ifeq (x86_64,$(BUILD-ARCH))
ifeq (i686,$(ARCH))
CC=gcc -m32
CXX=g++ -m32
FLAGS-TO-PASS+=CC="$(CC)"
FLAGS-TO-PASS+=CXX="$(CXX)"
CONFIG-FLAGS+=$(ARCH)-linux
endif
endif

ifeq (ia64,$(ARCH))
PRCTL=prctl --unaligned=always-signal
else
CONFIG-FLAGS+=--with-fpmath=sse
endif

ifdef CURRENT_LOG
CURRENT_LOG_MAIL=$(CURRENT_LOG).mail
else
CURRENT_LOG_MAIL=nohup.mail
endif

TIME=/usr/bin/time

RELEASE-DIR=$(PWD)/release

gcc: config $(BUILD)

gcc-%:
	$(MAKE) gcc SRC=src-$*

.DEFAULT:
	$(TIME) $(MAKE) $(PARALLELMFLAGS) -C $(BUILD-DIR) $@ \
		$(FLAGS-TO-PASS)

check:
	$(TIME) $(PRCTL) $(MAKE) $(PARALLELMFLAGS) -C $(BUILD-DIR) -k $@ \
		$(FLAGS-TO-PASS)

report:
	cd $(BUILD-DIR) && \
	  $(SOURCE-DIR)/contrib/test_summary | sh

check-gcc:
	 -$(MAKE) check
	  $(MAKE) report

check-spec: install-gcc-spec only-check-spec-cpu

only-check-spec-cpu: $(CHECK-SPEC)

check-spec-cpu-2000-%:
	$(MAKE) ARCHES=$* check-spec-cpu-2000

check-spec-cpu-2006-%:
	$(MAKE) ARCHES=$* check-spec-cpu-2006

speckill:
	-$(KILLALL) -9 runspec
	-$(KILLALL) -9 specmake
	-$(KILLALL) -9 specinvoke
	-$(KILLALL) -9 specperl

check-spec-cpu-%: speckill
	export PATH=$(PREFIX)/bin:$$PATH; \
	export LD_LIBRARY_PATH=$(PREFIX)/libx32:$(PREFIX)/lib64:$(PREFIX)/lib:$$LD_LIBRARY_PATH;\
	pwd=`pwd`; \
	ulimit -s 65536; \
	if [ "$(BUILD-SPEC)" = yes ]; then \
	  action="--action build"; \
	fi; \
	for a in $(ARCHES); do \
	  log=$$pwd/spec/$*/$$a/spec.log; \
	  config=lnx-$$a-$(SPEC-GCC).cfg; \
	  case $$a in \
	  i686) SPEC_FLAGS="$(SPEC-$*-FLAGS) $(SPEC-i686-RUN)";; \
	  x32) SPEC_FLAGS="$(SPEC-$*-FLAGS) $(SPEC-x32-RUN)";; \
	  x86_64) SPEC_FLAGS="$(SPEC-$*-FLAGS) $(SPEC-x86_64-RUN)";; \
	  esac; \
	  if [ $* = 2000 ]; then clean=nuke; \
	  else clean=scrub; fi; \
	  cd $$pwd/spec/$*/$$a/spec && . ./shrc && \
	    runspec -c $$config -a $$clean all > $$log 2>&1 && \
	    runspec -c $$config $$SPEC_FLAGS $$action >> $$log 2>&1; \
	  status=$$?; \
	  echo "With runspec -c $$config $$SPEC_FLAGS" > $$log.error; \
	  if [ $$status = 0 ]; then \
	    grep -i error $$log >> $$log.error && status=1; \
	  fi; \
	  if [ $$status = 0 ]; then \
	    RESULT=Passed; \
	    MAILTO="$(MAILTO)"; \
	  else \
	    RESULT=Failed; \
	    MAILTO="$(MAILTO) $(REGRESSION-MAILTO)"; \
	  fi; \
	  Mail -s "$$RESULT: SPEC CPU $*: `gcc --version | grep gcc` on $$a" \
	    $$MAILTO < $$log.error; \
	done

check-spec-%:
	$(MAKE) check-spec SRC=src-$* GCC=gcc-$*

one-%:
	$(MAKE) one SRC=src-$* GCC=gcc-$*

one:
	if $(MAKE) gcc; then \
	  $(MAKE) $(CHECK); \
	else \
	  if [ -n "$(CURRENT_LOG)" -a -e "$(CURRENT_LOG)" ]; then \
	    head -26 $(CURRENT_LOG) | tail -7 > $(CURRENT_LOG_MAIL); \
	    grep "Error " $(CURRENT_LOG) >> $(CURRENT_LOG_MAIL); \
	    tail -100 $(CURRENT_LOG) >> $(CURRENT_LOG_MAIL); \
	  else \
	    echo "$(FLAGS-TO-PASS) $(SOURCE-DIR)/configure $(CONFIG-FLAGS) $(LANG-FLAGS)" > $(CURRENT_LOG_MAIL); \
	  fi; \
	  Mail -s "Gcc `cat $(SRC)/gcc/REVISION` failed to $(BUILD) on $(ARCH)!" \
	     $(MAILTO) $(REGRESSION-MAILTO) < $(CURRENT_LOG_MAIL); \
	  exit 1; \
	fi

cont:
	if $(MAKE) $(BUILD); then \
	  $(MAKE) check; \
	  $(MAKE) report; \
	else \
	  echo | Mail -s "Gcc `cat $(SRC)/gcc/REVISION` failed to $(BUILD) on $(ARCH)!" \
	    $(MAILTO) $(REGRESSION-MAILTO); \
	  exit 1; \
	fi

# Install
install:
	rm -rf $(RELEASE-DIR)
	$(MAKE) -C $(BUILD-DIR) DESTDIR=$(RELEASE-DIR) $@

# Create a binary tar ball
gcc-tar-file: install
	cd $(RELEASE-DIR); \
	VERSION=$$(cat $(SOURCE-DIR)/gcc/BASE-VER); \
	PHASE=$$(cat $(SOURCE-DIR)/gcc/DEV-PHASE); \
	if [ -n "$$PHASE" ]; then \
	  PHASE="-$$(cat $(SOURCE-DIR)/gcc/DATESTAMP)"; \
	fi; \
	tar --owner=root --group=root -cj \
	  -f gcc-$$VERSION$$PHASE.$(ARCH).tar.bz2 .$(PREFIX)

install-gcc-spec:
	rm -rf $(PREFIX)
	$(MAKE) -C $(BUILD-DIR) install

config: clobber
	mkdir -p $(BUILD-DIR)
	cd $(BUILD-DIR); \
	$(FLAGS-TO-PASS) $(SOURCE-DIR)/configure \
		$(CONFIG-FLAGS) $(LANG-FLAGS)

clobber:
	rm -rf $(BUILD-DIR)

build-spec-cpu: build-spec-cpu-2000 build-spec-cpu-2006

build-spec-cpu-%:
	$(MAKE) $(subst build-,tune-,$@) BUILD-SPEC=yes 

tune-spec-cpu: tune-spec-cpu-2000 tune-spec-cpu-2006

tune-spec-cpu-%:
	-$(KILLALL) -9 runspec
	-$(KILLALL) -9 specmake
	-$(KILLALL) -9 specinvoke
	export PATH=$(PREFIX)/bin:$$PATH; \
	export LD_LIBRARY_PATH=$(PREFIX)/libx32:$(PREFIX)/lib64:$(PREFIX)/lib:$$LD_LIBRARY_PATH;\
	pwd=`pwd`; \
	RESULT=Passed; \
	ulimit -s 65536; \
	if [ "$(BUILD-SPEC)" = yes ]; then \
	  action="--action build"; \
	fi; \
	if [ "$(CLEAN-SPEC)" = yes ]; then \
	  for a in $(ARCHES); do \
	    config=lnx-$$a-$(SPEC-GCC).cfg; \
	    if [ $* = 2000 ]; then clean=nuke; \
	    else clean=scrub; fi; \
	    cd $$pwd/spec/$*/$$a/spec && . ./shrc && \
	      runspec -c $$config -a $$clean all; \
	  done; \
	fi; \
	for a in $(ARCHES); do \
	  config=lnx-$$a-$(SPEC-GCC).cfg; \
	  case $$a in \
	  i686) RUNS="$(RUNS-i686)";; \
	  x32) RUNS="$(RUNS-x32)";; \
	  x86_64) RUNS="$(RUNS-x86_64)";; \
	  esac; \
	  for r in $$RUNS; do \
	    cd $$pwd/spec/$*/$$a/spec && . ./shrc && \
	      runspec -c $$config $(TUNE-SPEC-$*-FLAGS) -e $$r $$action; \
	    if [ $$? != 0 ] ; then \
	      RESULT=Failed; \
	    fi; \
	  done; \
	done; \
	echo "With $$RUNS on $(ARCHES)" | \
	  Mail -s "$$RESULT: SPEC CPU $*: `gcc --version | grep gcc`" $(MAILTO)

run-spec-cpu: run-spec-cpu-2000 run-spec-cpu-2006

run-spec-cpu-%:
	export PATH=$(PREFIX)/bin:$$PATH; \
	export LD_LIBRARY_PATH=$(PREFIX)/libx32:$(PREFIX)/lib64:$(PREFIX)/lib:$$LD_LIBRARY_PATH;\
	pwd=`pwd`; \
	RESULT=Passed; \
	ulimit -s 65536; \
	for a in $(ARCHES); do \
	  config=lnx-$$a-$(SPEC-GCC).cfg; \
	  cd $$pwd/spec/$*/$$a/spec && . ./shrc && \
	    runspec -c $$config $(RUN-SPEC-$*-FLAGS); \
	  if [ $$? != 0 ] ; then \
	    RESULT=Failed; \
	  fi; \
	done; \
	echo "With $(RUN-SPEC-FLAGS) on $(ARCHES)" | \
	  Mail -s "$$RESULT: SPEC CPU $*: `gcc --version | grep gcc`" $(MAILTO)

move-spec-cpu: move-spec-cpu-2000 move-spec-cpu-2006

move-spec-cpu-2000:
	if [ -n "$(LOG)" -a -f "$(LOG)" ]; then \
	  grep ASCII $(LOG) | grep CINT2000 |  \
	    awk '{ print $$4 }' | GCC=./usr/bin/gcc xargs specmv; \
	fi

move-spec-cpu-2006:
	if [ -n "$(LOG)" -a -f "$(LOG)" ]; then \
	  grep ASCII $(LOG) | grep CINT2006 |  \
	    awk '{ print $$4 }' | GCC=./usr/bin/gcc xargs specmv; \
	fi
