#
# Copyright (C) 2023-24 Hamish Coleman
#
# Our default make target
all:

export CC
export AR
export EXE
export CFLAGS
export LDFLAGS
export LDLIBS_LOCAL
export LDLIBS_EXTRA
export CONFIG_HOST_OS

VERSION:=$(shell scripts/version.sh)
CFLAGS+=-DVERSION='"$(VERSION)"'
BUILDDATE+=$(shell scripts/version.sh date)
CFLAGS+=-DBUILDDATE='"$(BUILDDATE)"'

-include config.mak

ifndef CONFIG_HOST
# TODO:
# dont error if we are installing build-deps or other non-compile action
$(error Please run ./configure)
endif

#Ultrasparc64 users experiencing SIGBUS should try the following gcc options
#(thanks to Robert Gibbon)
PLATOPTS_SPARC64=-mcpu=ultrasparc -pipe -fomit-frame-pointer -ffast-math -finline-functions -fweb -frename-registers -mapp-regs

OPENSSL_CFLAGS=$(shell pkg-config openssl; echo $$?)
ifeq ($(OPENSSL_CFLAGS), 0)
  CFLAGS+=$(shell pkg-config --cflags-only-I openssl)
endif

WARN=-Wall
CFLAGS+=$(DEBUG) $(OPTIMIZATION) $(WARN) $(OPTIONS) $(PLATOPTS)

# Quick sanity check on our build environment
UNAME_S := $(shell uname -s)
ifndef UNAME_S
# This could happen if the Makefile is unable to run "uname", which can
# happen if the shell has a bad path (or is the wrong shell)
$(error Could not run uname command, cannot continue)
endif

export MKDIR
export INSTALL
export INSTALL_PROG
export INSTALL_DOC
export SBINDIR

MKDIR=mkdir -p
INSTALL=install
INSTALL_PROG=$(INSTALL) -m755
INSTALL_DOC=$(INSTALL) -m644

# DESTDIR set in debian make system
PREFIX?=$(DESTDIR)/$(CONFIG_PREFIX)

SBINDIR=$(PREFIX)/sbin
MANDIR?=$(PREFIX)/share/man
MAN1DIR=$(MANDIR)/man1
MAN7DIR=$(MANDIR)/man7
MAN8DIR=$(MANDIR)/man8


#######################################
# All the additiona needed for using the n3n library
#
CFLAGS+=-I$(abspath include)
LDFLAGS+=-L$(abspath src)

N2N_OBJS=\
	src/aes.o \
	src/auth.o \
	src/cc20.o \
	src/conffile.o \
	src/conffile_defs.o \
	src/curve25519.o \
	src/edge_management.o \
	src/edge_utils.o \
	src/header_encryption.o \
	src/hexdump.o \
	src/initfuncs.o \
	src/json.o \
	src/logging.o \
	src/management.o \
	src/minilzo.o \
	src/n2n.o \
	src/n2n_port_mapping.o \
	src/n2n_regex.o \
	src/network_traffic_filter.o \
	src/pearson.o \
	src/peer_info.o \
	src/random_numbers.o \
	src/resolve.o \
	src/sn_management.o \
	src/sn_selection.o \
	src/sn_utils.o \
	src/speck.o \
	src/test_hashing.o \
	src/tf.o \
	src/transform.o \
	src/transform_aes.o \
	src/transform_cc20.o \
	src/transform_lzo.o \
	src/transform_none.o \
	src/transform_null.o \
	src/transform_speck.o \
	src/transform_tf.o \
	src/transform_zstd.o \
	src/tuntap_freebsd.o \
	src/tuntap_linux.o \
	src/tuntap_netbsd.o \
	src/tuntap_osx.o \
	src/wire.o \

ifneq (,$(findstring mingw,$(CONFIG_HOST_OS)))
N2N_OBJS+=src/win32/edge_utils_win32.o
N2N_OBJS+=src/win32/getopt1.o
N2N_OBJS+=src/win32/getopt.o
N2N_OBJS+=src/win32/wintap.o
N2N_OBJS+=src/win32/edge_rc.o
endif

src/management.c: src/management_index.html.h
src/management.c: src/management_script.js.h

src/libn3n.a: $(N2N_OBJS)
	@echo "  AR      $@"
	@$(AR) rcs $@ $^
SUBDIR_LIBS+=src/libn3n.a

#######################################
# Add non system library version of natpmp
# TODO: this library doesnt compile for win64 without a patch
#
ifdef THIRDPARTY_LIBNATPMP
CFLAGS+=-I$(abspath thirdparty/libnatpmp)
CFLAGS+=-DNATPMP_STATICLIB=1
CFLAGS+=-DHAVE_LIBNATPMP=1
LDFLAGS+=-L$(abspath thirdparty/libnatpmp)
LDLIBS_EXTRA+=-lnatpmp

thirdparty/libnatpmp/libnatpmp.a:
	$(MAKE) -C $(dir $@) $(notdir $@)
SUBDIR_LIBS+=thirdparty/libnatpmp/libnatpmp.a
SUBDIR_CLEAN+=thirdparty/libnatpmp
endif

#######################################
# Add non system library version of miniupnpc
#
ifdef THIRDPARTY_MINIUPNPC
CFLAGS+=-I$(abspath thirdparty/miniupnp/miniupnpc)
CFLAGS+=-DMINIUPNP_STATICLIB=1
CFLAGS+=-DHAVE_LIBMINIUPNPC=1
LDFLAGS+=-L$(abspath thirdparty/miniupnp/miniupnpc/build)
LDLIBS_EXTRA+=-lminiupnpc

thirdparty/miniupnp/miniupnpc/build/libminiupnpc.a:
	$(MAKE) -C thirdparty/miniupnp/miniupnpc build/libminiupnpc.a
SUBDIR_LIBS+=thirdparty/miniupnp/miniupnpc/build/libminiupnpc.a
SUBDIR_CLEAN+=thirdparty/miniupnp/miniupnpc
endif

#######################################
# All the additions needed for using the connslot library
#
CFLAGS+=-I$(abspath libs)
LDFLAGS+=-L$(abspath libs/connslot)
LDLIBS_LOCAL+=-lconnslot

libs/connslot/libconnslot.a:
	$(MAKE) -C $(dir $@) $(notdir $@) httpd-test
SUBDIR_LIBS+=libs/connslot/libconnslot.a
SUBDIR_CLEAN+=libs/connslot

#######################################

# As source files pass the linter, they can be added here (If all the source
# is passing the linter tests, this can be refactored)
LINT_CCODE=\
	apps/ \
	include/ \
	src/ \
	tools/ \

# Some files currently cause the linter to fail, so they need to be excluded
# TODO: change either the files or the linter to remove these failures
LINT_EXCLUDE=include/uthash.h|include/lzodefs.h|src/minilzo.c

DOCS=edge.8.gz supernode.1.gz n3n.7.gz

# This is the list of Debian/Ubuntu packages that are needed during the build.
# Mostly of use in automated build systems.
BUILD_DEP:=\
	autoconf \
	build-essential \
	flake8 \
	gcovr \
	libcap-dev \
	libzstd-dev \
	shellcheck \
	uncrustify \
	yamllint \
	jq \

SUBDIRS+=tools
SUBDIRS+=apps

COVERAGEDIR?=coverage

.PHONY: all
all: version $(DOCS) subdirs apps

.PHONY: version
# This allows breaking the build if the version.sh script discovers
# any inconsistancies
version:
	@scripts/version.sh >/dev/null
	@echo "Build for version: $(VERSION)"

.PHONY: subdirs
subdirs: $(SUBDIR_LIBS)
	for dir in $(SUBDIRS); do $(MAKE) -C $$dir; done
SUBDIR_CLEAN+=$(SUBDIRS)

src/win32/edge.rc: src/win32/edge.manifest
src/win32/edge_rc.o: src/win32/edge.rc
	$(WINDRES) $< -O coff -o $@

# Remember to keep the two CC lines in sync
$(info CC is: $(CC) $(CFLAGS) $(CPPFLAGS) -c -o $$@ $$<)
%.o: %.c
	@echo "  CC      $@"
	@$(CC) $(CFLAGS) $(CPPFLAGS) -c -o $@ $<

%.gz : %
	gzip -n -c $< > $@

%.h : %
	libs/connslot/file2strbufc $< $(basename $(notdir $<)) >$@

.PHONY: test test.units test.integration
test: test.builtin test.units test.integration

test.units: subdirs		# needs tools
	scripts/test_harness.sh tests/tests_units.list

test.integration: subdirs	# needs apps
	scripts/test_harness.sh tests/tests_integration.list

test.builtin: subdirs		# needs apps
	scripts/test_harness.sh tests/tests_builtin.list

.PHONY: lint lint.python lint.ccode lint.shell lint.yaml
lint: lint.python lint.ccode lint.shell lint.yaml

lint.python:
	flake8 scripts/n3n-ctl scripts/n3n-httpd scripts/n3n-convert_old_conf

lint.ccode:
	scripts/indent.sh -e '$(LINT_EXCLUDE)' $(LINT_CCODE)

lint.shell:
	shellcheck scripts/*.sh

lint.yaml:
	yamllint .

# To generate coverage information, run configure with
# CFLAGS="-fprofile-arcs -ftest-coverage" LDFLAGS="--coverage"
# and run the desired tests.  Ensure that package gcovr is installed
# and then run "make cover"
.PHONY: cover
cover:
	mkdir -p $(COVERAGEDIR)
	gcovr -s --html --html-details --output=$(COVERAGEDIR)/index.html

# Use coverage data to generate gcov text report files.
# Unfortunately, these end up in the wrong directory due to the
# makefile layout
# The steps to use this are similar to the "make cover" above
.PHONY: gcov
gcov:
	gcov $(N2N_OBJS)
	$(MAKE) -C tools gcov
	$(MAKE) -C apps gcov

# This is a convinent target to use during development or from a CI/CD system
.PHONY: build-dep

ifneq (,$(findstring darwin,$(CONFIG_HOST_OS)))
build-dep: build-dep-brew
else
build-dep: build-dep-dpkg
endif

.PHONY: build-dep-dpkg
build-dep-dpkg:
	sudo apt install $(BUILD_DEP)

.PHONY: build-dep-brew
build-dep-brew:
	brew install automake gcovr

.PHONY: clean.cov
clean.cov:
	rm -f \
		src/*.gcno src/*.gcda \
		apps/*.gcno apps/*.gcda \
		tools/*.gcno tools/*.gcda

.PHONY: clean
clean: clean.cov
	rm -rf $(N2N_OBJS) $(SUBDIR_LIBS) $(DOCS) $(COVERAGEDIR)/ *.dSYM *~
	rm -f tests/*.out
	for dir in $(SUBDIR_CLEAN); do $(MAKE) -C $$dir clean; done

.PHONY: distclean
distclean:
	rm -f tests/*.out src/*.indent src/*.unc-backup*
	rm -rf autom4te.cache/
	rm -f config.mak config.log config.status configure include/config.h include/config.h.in
	rm -f edge.8.gz n3n.7.gz supernode.1.gz
	rm -f packages/debian/config.log packages/debian/config.status
	rm -rf packages/debian/autom4te.cache/
	rm -f packages/rpm/config.log packages/rpm/config.status

.PHONY: install
install: apps tools edge.8.gz supernode.1.gz n3n.7.gz
	echo "MANDIR=$(MANDIR)"
	$(MKDIR) $(SBINDIR) $(MAN1DIR) $(MAN7DIR) $(MAN8DIR)
	$(MAKE) -C apps install SBINDIR=$(abspath $(SBINDIR))
	$(MAKE) -C tools install SBINDIR=$(abspath $(SBINDIR))
	$(INSTALL_DOC) edge.8.gz $(MAN8DIR)/
	$(INSTALL_DOC) supernode.1.gz $(MAN1DIR)/
	$(INSTALL_DOC) n3n.7.gz $(MAN7DIR)/
