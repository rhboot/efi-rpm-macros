default : all

TOPDIR = $(shell echo $$PWD)

include $(TOPDIR)/Makefile.version

define get-config
$(shell git config --local --get "efi.$(1)")
endef

EFI_ESP_ROOT	?= $(call get-config,esp-root)
ifeq ($(EFI_ESP_ROOT),)
override EFI_ESP_ROOT=/boot/efi
endif
EFI_ARCHES	?= $(call get-config,arches)
ifeq ($(EFI_ARCHES),)
override EFI_ARCHES="x86_64 aarch64 %{arm} %{ix86} riscv64"
endif
EFI_VENDOR	?= $(call get-config,vendor)

DESTDIR ?= $(call get-config,destdir)

RPM = $(shell command -v rpm)
ifeq (${RPM},)
$(error rpm could not be found)
endif
MACRODIR = $(call get-config,macrodir)
ifeq (${MACRODIR},)
MACRODIR = $(shell ${RPM} --eval '%{_rpmmacrodir}')
endif
ifeq (${MACRODIR},)
$(error rpm macro directory could not be found)
endif
CONFIGDIR = $(call get-config,configdir)
ifeq (${CONFIGDIR},)
CONFIGDIR = $(shell ${RPM} --eval '%{_rpmconfigdir}')
endif
ifeq (${CONFIGDIR},)
$(error rpm config directory could not be found)
endif
PRERELEASE ?=

# TARGETS = macros.efi macros.efi-srpm efi-rpm-macros.spec brp-boot-efi-times
TARGETS = macros.efi-srpm efi-rpm-macros.spec brp-boot-efi-times

check_efi_vendor :
ifeq ($(EFI_VENDOR),)
	$(error EFI_VENDOR must be set)
endif

all : | check_efi_vendor
all : $(TARGETS)

clean :
	@rm -vf $(TARGETS)

install : | check_efi_vendor
install : $(TARGETS)
	install -d -m 0755 $(DESTDIR)/$(MACRODIR)
	# install -m 0644 macros.efi $(DESTDIR)/$(MACRODIR)/
	install -m 0644 macros.efi-srpm $(DESTDIR)/$(MACRODIR)/
	install -d -m 0755 $(DESTDIR)/$(CONFIGDIR)/
	install -m 0755 brp-boot-efi-times $(DESTDIR)/$(CONFIGDIR)/
	if [[ "$(EFI_ESP_ROOT)" != /boot ]] ; then \
		install -d -m 0755 $(DESTDIR)/boot ; \
	fi
	install -d -m 0700 $(DESTDIR)/$(EFI_ESP_ROOT)
	install -d -m 0700 $(DESTDIR)/$(EFI_ESP_ROOT)/EFI
	install -d -m 0700 $(DESTDIR)/$(EFI_ESP_ROOT)/EFI/BOOT
	install -d -m 0700 $(DESTDIR)/$(EFI_ESP_ROOT)/EFI/$(EFI_VENDOR)

$(TARGETS) :
% : %.in
	@echo creating $@
	@sed	\
		-e 's,@@EFI_ESP_ROOT@@,$(EFI_ESP_ROOT),g' \
		-e 's,@@EFI_ARCHES@@,$(EFI_ARCHES),g' \
		-e 's,@@EFI_VENDOR@@,$(EFI_VENDOR),g' \
		-e 's,@@EFI_RPM_MACROS_VERSION@@,$(VERSION),g' \
		-e 's,@@EFI_PRERELEASE@@,$(PRERELEASE),g' \
		-e 's,@@EFI_SOURCE_VERSION@@,$(SOURCE_VERSION),g' \
		-e 's,@@RPM_CONFIG_DIR@@,$(CONFIGDIR),g' \
		<$^ >$@

test-archive: efi-rpm-macros.spec.in
	@rm -vf efi-rpm-macros.spec
	@$(MAKE) PRERELEASE=~1 VERSION=\$(($(VERSION)+1)) SOURCE_VERSION=$(VERSION) efi-rpm-macros.spec
	@rm -rf /tmp/efi-rpm-macros-$(VERSION) /tmp/efi-rpm-macros-$(VERSION)-tmp
	@mkdir -p /tmp/efi-rpm-macros-$(VERSION)-tmp
	@git archive --format=tar $(shell git branch | awk '/^*/ { print $$2 }') | ( cd /tmp/efi-rpm-macros-$(VERSION)-tmp/ ; tar x )
	@git diff | ( cd /tmp/efi-rpm-macros-$(VERSION)-tmp/ ; patch -s -p1 -b -z .gitdiff )
	@mv /tmp/efi-rpm-macros-$(VERSION)-tmp/ /tmp/efi-rpm-macros-$(VERSION)/
	@cp efi-rpm-macros.spec /tmp/efi-rpm-macros-$(VERSION)/
	@dir=$$PWD; cd /tmp; tar -c --bzip2 -f $$dir/efi-rpm-macros-$(VERSION).tar.bz2 efi-rpm-macros-$(VERSION)
	@rm -rf /tmp/efi-rpm-macros-$(VERSION)
	@echo "The archive is in efi-rpm-macros-$(VERSION).tar.bz2"

GITTAG ?= $(shell bash -c "echo $$(($(VERSION) + 1))")

bumpver :
	@echo VERSION ?= $(GITTAG) > Makefile.version
	@git add Makefile.version
	git commit -m "Bump version to $(GITTAG)" -s

tag:
	git tag -s $(GITTAG) refs/heads/main

archive: bumpver tag
	@rm -vf efi-rpm-macros.spec
	@$(MAKE) VERSION=$(GITTAG) SOURCE_VERSION=$(GITTAG) efi-rpm-macros.spec
	@rm -rf /tmp/efi-rpm-macros-$(GITTAG) /tmp/efi-rpm-macros-$(GITTAG)-tmp
	@mkdir -p /tmp/efi-rpm-macros-$(GITTAG)-tmp
	@git archive --format=tar $(GITTAG) | ( cd /tmp/efi-rpm-macros-$(GITTAG)-tmp/ ; tar x )
	@mv /tmp/efi-rpm-macros-$(GITTAG)-tmp/ /tmp/efi-rpm-macros-$(GITTAG)/
	@cp efi-rpm-macros.spec /tmp/efi-rpm-macros-$(GITTAG)/
	@dir=$$PWD; cd /tmp; tar -c --bzip2 -f $$dir/efi-rpm-macros-$(GITTAG).tar.bz2 efi-rpm-macros-$(GITTAG)
	@rm -rf /tmp/efi-rpm-macros-$(GITTAG)
	@echo "The archive is in efi-rpm-macros-$(GITTAG).tar.bz2"

.PHONY : default all clean install test-archive bumpver tag archive
