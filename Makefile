# Makefile for packaging tasks
# Usage:
#   make help        # show available targets (auto-generated from '##' comments)
#   make srpm        # download upstream tag tarball and build SRPM
#   make copr        # submit upstream tag URL build to COPR (requires copr-cli)
#   make clean       # remove local temporary files (releases/)

RPMBUILD ?= $(HOME)/rpmbuild
SOURCES := $(RPMBUILD)/SOURCES
SRPMS := $(RPMBUILD)/SRPMS

# Try to detect version from the spec: prefer %global buildtag, fallback to
# Version:, allow override: make srpm VERSION=1.0.0
VERSION ?= $(shell awk '/%global[[:space:]]+buildtag/ { print $$3; exit } /^Version[[:space:]]*:/ { n = index($$0,":"); v = substr($$0, n+1); gsub(/^[[:space:]]+|[[:space:]]+$$/, "", v); print v; exit }' mtree.spec)

# Upstream source URL (defaults to jashank/mtree-netbsd tag tarball)
SOURCE_URL ?= https://github.com/jashank/mtree-netbsd/archive/refs/tags/$(VERSION).tar.gz
SOURCETARBALL := $(SOURCES)/mtree-netbsd-$(VERSION).tar.gz
# Default COPR user/project (override with COPR_USER or COPR_PROJECT)
COPR_USER ?= dioni21
COPR_PROJECT ?= $(COPR_USER)/jonny-utils
# Package inside the COPR project for this SRPM (override with COPR_PKG)
COPR_PKG ?= mtree-netbsd



default: rpm

# Note: mtree depends on libnbcompat for build/runtime.
# The spec (`mtree.spec`) declares `BuildRequires: libnbcompat-devel` and `Requires: libnbcompat`.
# On Fedora/RHEL: install with `sudo dnf install libnbcompat libnbcompat-devel`.
# Upstream: https://github.com/archiecobbs/libnbcompat
#
## Check build dependencies (libnbcompat)
check-deps: ## Verify build dependencies are installed (checks libnbcompat via rpm)
	@echo "Checking for libnbcompat-devel via rpm -q..."
	@if rpm -q libnbcompat-devel >/dev/null 2>&1; then \
		echo "libnbcompat-devel found"; \
	else \
		exit 1; \
	fi

# Default tag used for test submissions (use COPR_TAG=<tag> to override)
# If you pass a plain suffix (e.g. COPR_TAG=foo) it will be converted to 'custom:foo'.
# If left empty, a timestamped tag 'custom:autotest-<epoch>' will be used.
COPR_TAG ?= custom:autotest-$(shell date +%s)

.PHONY: all srpm rpm prepare-dirs download-sources clean-sources copr copr-srpm help clean distclean
all: help

## Show available targets and their descriptions
help: ## Show this help
	@echo "Makefile targets:"
	@awk ' /^##/ { sub(/^##[ \t]*/,""); if (desc) desc = desc " " $$0; else desc = $$0; next } /^[a-zA-Z0-9][^:]*:/ { split($$0,a,":"); name=a[1]; if (desc) { printf "%s\t%s\n", name, desc; desc="" } } END { if (desc) printf "%s\t%s\n", name, desc }' $(MAKEFILE_LIST) | sort | awk -F'\t' '{ printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 }'
	@echo ""

## Ensures RPM build tree exists under $(RPMBUILD)
prepare-dirs:
	@echo "Ensuring RPM build tree exists under $(RPMBUILD)"
	@mkdir -p \
		$(RPMBUILD)/SOURCES \
		$(RPMBUILD)/BUILD \
		$(RPMBUILD)/RPMS \
		$(RPMBUILD)/SRPMS \
		$(RPMBUILD)/BUILDROOT

## Download upstream tag tarball to $(SOURCETARBALL)
download-sources: prepare-dirs
	@echo "Downloading $(SOURCE_URL) -> $(SOURCETARBALL)"
	@curl -fsSL "$(SOURCE_URL)" -o "$(SOURCETARBALL)" || (echo "Failed to download $(SOURCE_URL)"; exit 1)
	@echo "Download complete"

## Build SRPM from spec: mtree.spec
srpm: download-sources
	@echo "Building SRPM from spec: mtree.spec"
	@rpmbuild -bs mtree.spec || (echo "rpmbuild failed"; exit 1)
	@echo "SRPM(s) created under $(SRPMS)"

## Build binary RPMs from spec and collect main RPM + SRPM into releases/
rpm: download-sources
	@echo "Building binary RPMs from spec: mtree.spec"
	@rpmbuild -ba mtree.spec || (echo "rpmbuild failed"; exit 1)
	@echo "Binary RPM(s) created under $(RPMBUILD)/RPMS"
	@mkdir -p releases
	@echo "Locating main binary RPM (excluding devel/debug packages)"
	@main=$$(find "$(RPMBUILD)/RPMS" -type f -name "mtree-netbsd-$(VERSION)-*.rpm" ! -name "*-devel-*.rpm" ! -name "*-debuginfo-*.rpm" ! -name "*-debugsource-*.rpm" | sort | tail -n1); \
	if [ -n "$$main" ]; then cp -v "$$main" releases/; else echo "Main RPM not found"; fi; \
	# copy SRPM too
	@srpm=$$(ls "$(SRPMS)"/mtree-netbsd-$(VERSION)-*.src.rpm 2>/dev/null | tail -n1); \
	if [ -n "$$srpm" ]; then cp -v "$$srpm" releases/; else echo "SRPM not found in $(SRPMS)"; fi; \
	echo "Releases copied to releases/"

## Submit SRPM to COPR (delegates to copr-srpm)
copr:
	@echo "COPR builds must be submitted with an SRPM; delegating to 'copr-srpm'"
	@$(MAKE) copr-srpm

## Build SRPM and upload SRPM to COPR (requires copr-cli)
copr-srpm: srpm
	@echo "Locating SRPM in $(SRPMS)"
	@srpm=$$(ls "$(SRPMS)"/mtree-netbsd-$(VERSION)-*.src.rpm 2>/dev/null | tail -n1); \
	if [ -z "$$srpm" ]; then echo "SRPM not found in $(SRPMS)"; exit 1; fi; \
	COPR_CMD=$$(command -v copr-cli || command -v copr); \
	if [ -z "$$COPR_CMD" ]; then echo "copr-cli not found; install with: sudo dnf install copr-cli"; exit 1; fi; \
	echo "Using COPR command: $$COPR_CMD"; \
	echo "Uploading $$srpm for package $(COPR_PKG) to COPR project $(COPR_PROJECT) using $$COPR_CMD"; \
	tmp=$$(mktemp /tmp/copr.XXXXXX); \
	if $$COPR_CMD build "$(COPR_PROJECT)" "$$srpm" >$$tmp 2>&1; then \
		tail -n +1 $$tmp; rm -f $$tmp; \
	else \
		cat $$tmp; \
		if grep -q "does not exist" $$tmp; then \
			echo "Project $(COPR_PROJECT) does not exist on COPR. Create it or override COPR_PROJECT: make copr-srpm COPR_PROJECT=<owner>/mtree-netbsd"; \
		else \
			echo "copr build failed"; \
		fi; rm -f $$tmp; exit 1; \
	fi

## Remove downloaded source tarball
clean-sources:
	@echo "Removing $(SOURCETARBALL)"
	rm -f "$(SOURCETARBALL)"
	@echo "Done"

## Remove local temporary files (releases only)
clean:
	@echo "Removing local temp directories"
	rm -rf releases
	@echo "Done"

## Full cleanup: run clean and clean-sources
distclean: clean clean-sources
	@echo "Full cleanup done"

# EOF
