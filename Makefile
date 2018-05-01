default : all

TOPDIR = $(shell echo $$PWD)

include $(TOPDIR)/Makefile.version

DESTDIR ?=
RPM = $(shell command -v rpm)
ifeq (${RPM},)
$(error rpm could not be found)
endif
MACRODIR = $(shell ${RPM} --eval '%{_rpmmacrodir}')
ifeq (${MACRODIR},)
$(error rpm macro directory could not be found)
endif

EFI_ESP_ROOT	?= /boot/efi
EFI_ARCHES	?= x86_64 aarch64 %{arm} %{ix86}
EFI_VENDOR	?=

TARGETS = macros.efi efi-rpm-macros.spec

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
	install -m 0644 macros.efi $(DESTDIR)/$(MACRODIR)/

$(TARGETS) :
% : %.in
	@echo creating $@
	@sed	\
		-e 's,@@EFI_ESP_ROOT@@,$(EFI_ESP_ROOT),g' \
		-e 's,@@EFI_ARCHES@@,$(EFI_ARCHES),g' \
		-e 's,@@EFI_VENDOR@@,$(EFI_VENDOR),g' \
		-e 's,@@EFI_RPM_MACROS_VERSION@@,$(VERSION),g' \
		<$^ >$@

GITTAG ?= $(shell bash -c "echo $$(($(VERSION) + 1))")

test-archive: efi-rpm-macros.spec
	@rm -rf /tmp/efi-rpm-macros-$(VERSION) /tmp/efi-rpm-macros-$(VERSION)-tmp
	@mkdir -p /tmp/efi-rpm-macros-$(VERSION)-tmp
	@git archive --format=tar $(shell git branch | awk '/^*/ { print $$2 }') | ( cd /tmp/efi-rpm-macros-$(VERSION)-tmp/ ; tar x )
	@git diff | ( cd /tmp/efi-rpm-macros-$(VERSION)-tmp/ ; patch -s -p1 -b -z .gitdiff )
	@mv /tmp/efi-rpm-macros-$(VERSION)-tmp/ /tmp/efi-rpm-macros-$(VERSION)/
	@cp efi-rpm-macros.spec /tmp/efi-rpm-macros-$(VERSION)/
	@dir=$$PWD; cd /tmp; tar -c --bzip2 -f $$dir/efi-rpm-macros-$(VERSION).tar.bz2 efi-rpm-macros-$(VERSION)
	@rm -rf /tmp/efi-rpm-macros-$(VERSION)
	@echo "The archive is in efi-rpm-macros-$(VERSION).tar.bz2"

bumpver :
	@echo VERSION ?= $(GITTAG) > Makefile.version
	@git add Makefile.version
	git commit -m "Bump version to $(GITTAG)" -s

tag:
	git tag -s $(GITTAG) refs/heads/master

archive: bumpver tag efi-rpm-macros.spec
	@rm -rf /tmp/efi-rpm-macros-$(GITTAG) /tmp/efi-rpm-macros-$(GITTAG)-tmp
	@mkdir -p /tmp/efi-rpm-macros-$(GITTAG)-tmp
	@git archive --format=tar $(GITTAG) | ( cd /tmp/efi-rpm-macros-$(GITTAG)-tmp/ ; tar x )
	@mv /tmp/efi-rpm-macros-$(GITTAG)-tmp/ /tmp/efi-rpm-macros-$(GITTAG)/
	@cp efi-rpm-macros.spec /tmp/efi-rpm-macros-$(GITTAG)/
	@dir=$$PWD; cd /tmp; tar -c --bzip2 -f $$dir/efi-rpm-macros-$(GITTAG).tar.bz2 efi-rpm-macros-$(GITTAG)
	@rm -rf /tmp/efi-rpm-macros-$(GITTAG)
	@echo "The archive is in efi-rpm-macros-$(GITTAG).tar.bz2"

.PHONY : default all clean install test-archive bumpver tag archive
