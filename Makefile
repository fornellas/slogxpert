help:

##
## Variables
##

# Make

SHELL := /bin/bash
.ONESHELL:

MAKE_MAJOR_VERSION := $(word 1, $(subst ., , $(MAKE_VERSION)))
MAKE_REQUIRED_MAJOR_VERSION := 4
MAKE_BAD_VERSION := $(shell [ $(MAKE_MAJOR_VERSION) -lt $(MAKE_REQUIRED_MAJOR_VERSION) ] && echo true)
ifeq ($(MAKE_BAD_VERSION),true)
  $(error Make version is below $(MAKE_REQUIRED_MAJOR_VERSION), please update it.)
endif

# uname

SHELL_UNAME_S := uname -s
UNAME_S := $(shell $(SHELL_UNAME_S))
ifneq ($(.SHELLSTATUS),0)
$(error $(SHELL_UNAME_S): $(UNAME_S))
endif

SHELL_UNAME_M := uname -m
UNAME_M := $(shell $(SHELL_UNAME_M))
ifneq ($(.SHELLSTATUS),0)
$(error $(SHELL_UNAME_M): $(UNAME_M))
endif

# Cache

ifeq ($(UNAME_S),Linux)
XDG_CACHE_HOME ?= $(HOME)/.cache
else
ifeq ($(UNAME_S),Darwin)
XDG_CACHE_HOME ?= $(HOME)/Library/Caches
else
$(error Unsupported system: $(UNAME_S))
endif
endif

CACHE_PATH ?= $(XDG_CACHE_HOME)/slogxt

# Go

SHELL_GO_VERSION := cat go.mod | awk '/^go /{print $$2}'
export GOVERSION := go$(shell $(SHELL_GO_VERSION))
ifneq ($(.SHELLSTATUS),0)
  $(error $(SHELL_GO_VERSION): $(GOVERSION))
endif

SHELL_GOOS := case $(UNAME_S) in Linux) echo linux;; Darwin) echo darwin;; *) echo Unknown system $(UNAME_S) 1>&2 ; exit 1 ;; esac
export GOOS ?= $(shell $(SHELL_GOOS))
ifneq ($(.SHELLSTATUS),0)
  $(error $(SHELL_GOOS): $(GOOS))
endif

SHELL_GOARCH_NATIVE := case $(UNAME_M) in i[23456]86) echo 386;; x86_64) echo amd64;; armv6l|armv7l) echo arm;; aarch64|arm64) echo arm64;; *) echo Unknown machine $(UNAME_M) 1>&2 ; exit 1 ;; esac
GOARCH_NATIVE := $(shell $(SHELL_GOARCH_NATIVE))
ifneq ($(.SHELLSTATUS),0)
  $(error $(SHELL_GOARCH_NATIVE): $(GOARCH_NATIVE))
endif

export GOARCH ?= $(GOARCH_NATIVE)

SHELL_GOARCH_DOWNLOAD := case $(GOARCH_NATIVE) in 386) echo 386;; amd64) echo amd64;; arm) echo armv6l;; arm64) echo arm64;; *) echo GOARCH $(GOARCH_NATIVE) 1>&2 ; exit 1 ;; esac
GOARCH_DOWNLOAD ?= $(shell $(SHELL_GOARCH_DOWNLOAD))
ifneq ($(.SHELLSTATUS),0)
  $(error $(SHELL_GOARCH_DOWNLOAD): $(GOARCH_DOWNLOAD))
endif

GOROOT_PREFIX := $(CACHE_PATH)/GOROOT
GOROOT := $(GOROOT_PREFIX)/$(GOVERSION).$(GOOS)-$(GOARCH_DOWNLOAD)

export GOBIN := $(GOROOT)/bin
export GOTOOLDIR := $(GOBIN)
GO := $(GOBIN)/go
PATH := $(GOBIN):$(PATH)

export GOPATH := $(CACHE_PATH)/GOPATH
PATH := $(GOPATH)/bin:$(PATH)

export GOCACHE := $(CACHE_PATH)/GOCACHE

export GOMODCACHE := $(CACHE_PATH)/GOMODCACHE

# Go source

SHELL_GO_MODULE := cat go.mod | awk '/^module /{print $$2}'
export GO_MODULE := $(shell $(SHELL_GO_MODULE))
ifneq ($(.SHELLSTATUS),0)
  $(error $(SHELL_GO_MODULE): $(GO_MODULE))
endif

GO_SOURCE_FILES := $$(find $$PWD -name \*.go ! -path '$(CACHE_PATH)/*')

# goimports

GOIMPORTS := $(GO) tool goimports
GOIMPORTS_LOCAL := $(GO_MODULE)

# govulncheck

GOVULNCHECK := $(GO) tool govulncheck
LINT_GOVULNCHECK_DISABLE :=

# staticcheck

STATICCHECK := $(GO) tool staticcheck
export STATICCHECK_CACHE := $(CACHE_PATH)/staticcheck

# misspell

MISSPELL := $(GO) tool misspell

# gocyclo

GOCYCLO_IGNORE_REGEX := '.*\.pb\.go'
GOCYCLO := $(GO) tool gocyclo
GOCYCLO_OVER := 15

# ineffassign

INEFFASSIGN := $(GO) tool ineffassign

# go test

GO_TEST := $(GO) tool gotest

GO_TEST_FLAGS :=

define go_test_build_flags
$(value GO_TEST_BUILD_FLAGS_$(1))
endef

GO_TEST_BUILD_FLAGS :=
# https://go.dev/doc/articles/race_detector#Requirements
ifneq ($(GO_TEST_BUILD_FLAGS_NO_RACE),1)
ifeq ($(GOOS)/$(GOARCH),linux/amd64)
GO_TEST_BUILD_FLAGS_linux_amd64 := -race $(GO_TEST_BUILD_FLAGS)
endif
ifeq ($(GOOS)/$(GOARCH),linux/ppc64le)
GO_TEST_BUILD_FLAGS_linux_ppc64le := -race $(GO_TEST_BUILD_FLAGS)
endif
# https://github.com/golang/go/issues/29948
# ifeq ($(GOOS)/$(GOARCH),linux/arm64)
#_LINUX_ARM64 GO_TEST_BUILD_FLAGS := -race $(GO_TEST_BUILD_FLAGS)
# endif
ifeq ($(GOOS)/$(GOARCH),freebsd/amd64)
GO_TEST_BUILD_FLAGS_freebsd_amd64 := -race $(GO_TEST_BUILD_FLAGS)
endif
ifeq ($(GOOS)/$(GOARCH),netbsd/amd64)
GO_TEST_BUILD_FLAGS_netbsd_amd64 := -race $(GO_TEST_BUILD_FLAGS)
endif
ifeq ($(GOOS)/$(GOARCH),darwin/amd64)
GO_TEST_BUILD_FLAGS_darwin_amd64 := -race $(GO_TEST_BUILD_FLAGS)
endif
ifeq ($(GOOS)/$(GOARCH),darwin/arm64)
GO_TEST_BUILD_FLAGS_darwin_arm64 := -race $(GO_TEST_BUILD_FLAGS)
endif
ifeq ($(GOOS)/$(GOARCH),windows/amd64)
GO_TEST_BUILD_FLAGS_windows_amd64 := -race $(GO_TEST_BUILD_FLAGS)
endif
endif

GO_TEST_PACKAGES_DEFAULT := $(GO_MODULE)/...
GO_TEST_PACKAGES := $(GO_TEST_PACKAGES_DEFAULT)

GO_TEST_BINARY_FLAGS :=
ifneq ($(GO_TEST_NO_COVER),1)
GO_TEST_BINARY_FLAGS := -coverprofile cover.txt -coverpkg $(GO_TEST_PACKAGES) $(GO_TEST_BINARY_FLAGS)
endif
GO_TEST_BINARY_FLAGS := -count=1 $(GO_TEST_BINARY_FLAGS)
GO_TEST_BINARY_FLAGS := -failfast $(GO_TEST_BINARY_FLAGS)

GO_TEST_BINARY_FLAGS_EXTRA :=

GCOV2LCOV := $(GO) tool gcov2lcov

GO_TEST_MIN_COVERAGE := 50

# go build

GO_BUILD_FLAGS_COMMON :=

# rrb

RRB := $(GO) tool rrb
RRB_DEBOUNCE ?= 500ms
RRB_IGNORE_PATTERN ?=
RRB_LOG_LEVEL ?= info
RRB_PATTERN ?= '**/*.go' Makefile
RRB_MAKE_TARGET ?= ci
RRB_EXTRA_CMD ?= true

##
## Help
##

.PHONY: help
help:

##
## Clean
##

.PHONY: help-clean
help-clean:
	@echo 'clean: clean all files'
help: help-clean

.PHONY: clean
clean:

##
## Install Tools
##

.PHONY: help-install-tools
help-install-tools:
	@echo 'install-tools: installs all tool dependencies'
help: help-install-tools

.PHONY: install-tools
install-tools:

# Go

.PHONY: install-go
install-go:
	set -e
	if [ -d $(GOROOT) ] ; then exit ; fi
	rm -rf $(GOROOT_PREFIX)/go
	mkdir -p $(GOROOT_PREFIX)
	curl -sSfL  https://go.dev/dl/$(GOVERSION).$(GOOS)-$(GOARCH_DOWNLOAD).tar.gz | \
		tar -zx -C $(GOROOT_PREFIX) && \
		touch $(GOROOT_PREFIX)/go &&
		mv $(GOROOT_PREFIX)/go $(GOROOT)
install-tools: install-go

.PHONY: clean-install-go
clean-install-go:
	rm -rf $(GOROOT_PREFIX)
	rm -rf $(GOCACHE)
	find $(GOMODCACHE) -print0 | xargs -0 chmod u+w
	rm -rf $(GOMODCACHE)
	rm -rf $(GOPATH)
clean: clean-install-go

##
## Generate
##

# go generate

.PHONY: go-generate
go-generate: install-go
	$(GO) generate ./...

##
## Lint
##

# lint

.PHONY: help-lint
help-lint:
	@echo 'lint: runs all linters'
	@echo '  use LINT_GOVULNCHECK_DISABLE=1 to disable govulncheck (faster)'
help: help-lint

.PHONY: lint
lint:

# go mod tidy

.PHONY: go-mod-tidy
go-mod-tidy: install-go go-generate
	$(GO) mod tidy
lint: go-mod-tidy

# goimports

.PHONY: goimports
goimports: install-go go-mod-tidy
	$(GOIMPORTS) -w -local $(GOIMPORTS_LOCAL) $(GO_SOURCE_FILES)
lint: goimports

# govulncheck

ifneq ($(LINT_GOVULNCHECK_DISABLE),1)
.PHONY: govulncheck
govulncheck: go-generate install-go go-mod-tidy
	$(GOVULNCHECK) $(GO_MODULE)/...
lint: govulncheck
endif

# staticcheck

.PHONY: staticcheck
staticcheck: install-go go-mod-tidy go-generate goimports
	$(STATICCHECK) $(GO_MODULE)/...
lint: staticcheck

.PHONY: clean-staticcheck
clean-staticcheck:
	rm -rf $(STATICCHECK_CACHE)
clean: clean-staticcheck

# misspell

.PHONY: misspell
misspell: install-go go-mod-tidy go-generate
	$(MISSPELL) -error $(GO_SOURCE_FILES)
lint: misspell

# gocyclo

.PHONY: gocyclo
gocyclo: install-go go-generate go-mod-tidy
	$(GOCYCLO) -over $(GOCYCLO_OVER) -avg -ignore $(GOCYCLO_IGNORE_REGEX) .

lint: gocyclo

# ineffassign

.PHONY: ineffassign
ineffassign: install-go go-generate go-mod-tidy
	$(INEFFASSIGN) ./...

lint: ineffassign

# go vet

.PHONY: go-vet
go-vet: install-go go-mod-tidy go-generate
	$(GO) vet ./...
lint: go-vet

# go-update
.PHONY: go-update
go-update: install-go
	set -e
	set -o pipefail
	$(GO) mod edit -go $$(curl -s https://go.dev/VERSION?m=text | head -n 1 | cut -c 3-)
	$(MAKE) $(MFLAGS) install-go
update-deps: go-update

# go get -u

.PHONY: go-get-u-t
go-get-u-t: install-go go-mod-tidy
	$(GO) get -u ./...
update-deps: go-get-u-t

##
## Test
##

# test

.PHONY: help-test
help-test:
	@echo 'test: runs all tests:'
	@echo '  use GO_TEST_BUILD_FLAGS to set test build flags (see `go test build`)'
	@echo '  use GO_TEST_FLAGS to set test flags (see `go help test`)'
	@echo '  use GO_TEST_PACKAGES to set packages to test (default: $(GO_TEST_PACKAGES_DEFAULT))'
	@echo '  use GO_TEST_BINARY_FLAGS_EXTRA to pass extra flags to the test binary (see `go help testflag`)'
	@echo '  use GO_TEST_NO_COVER=1 to disable code coverage (faster)'
	@echo '  use GO_TEST_BUILD_FLAGS_NO_RACE=1 to disable -race build flag (faster)'
help: help-test

.PHONY: test

# gotest

.PHONY: gotest
gotest: install-go go-generate
	$(GO_TEST) \
		$(GO_BUILD_FLAGS_COMMON) \
		$(call go_test_build_flags,$(GOOS)_$(GOARCH_NATIVE)) \
		$(GO_TEST_FLAGS) \
		$(GO_TEST_PACKAGES) \
		$(GO_TEST_BINARY_FLAGS) \
		$(GO_TEST_BINARY_FLAGS_EXTRA)
gotest:
test: gotest

.PHONY: clean-gotest
clean-gotest:
	$(GO) env &>/dev/null && $(GO) clean -r -testcache
	$(GO) env &>/dev/null && $(GO) clean -r -cache -modcache
	rm -f cover.txt cover.html
clean: clean-gotest

# cover.html

ifneq ($(GO_TEST_NO_COVER),1)
.PHONY: cover.html
cover.html: install-go gotest
	$(GO) tool cover -html cover.txt -o cover.html
test: cover.html

.PHONY: clean-cover.html
clean-cover.html:
	rm -f cover.html
clean: clean-cover.html

# cover.lcov

.PHONY: cover.lcov
cover.lcov: install-go gotest
	$(GCOV2LCOV) -infile cover.txt -outfile cover.lcov
test: cover.lcov

.PHONY: clean-cover.lcov
clean-cover.lcov:
	rm -f cover.lcov
clean: clean-cover.lcov

# test-coverage

ifeq ($(GOOS),linux)
.PHONY: test-coverage
test-coverage: install-go cover.txt
	PERCENT=$$($(GO) tool cover -func cover.txt | awk '/^total:/{print $$NF}' | tr -d % | cut -d. -f1) && \
		echo "Coverage: $$PERCENT%" && \
		if [ $$PERCENT -lt $(GO_TEST_MIN_COVERAGE) ] ; then \
			echo "Minimum coverage required: $(GO_TEST_MIN_COVERAGE)%" ; \
			exit 1 ; \
		fi
test: test-coverage
endif

endif

##
## examples
##

.PHONY: help-examples
help-examples:
	@echo 'examples: run all examples'
help: help-examples

.PHONY: examples
examples: install-go
	for e in examples/* ; do cd $$e && go run . && cd - ; done

.PHONY: clean-examples
clean-examples:
		rm -f examples/MultiHandler/application.log
clean: clean-examples

##
## ci
##

.PHONY: help-ci
help-ci:
	@echo 'ci: runs the whole build'
	@echo 'ci-dev: similar to ci, but uses options that speed up the build, at the expense of minimal signal loss;'
help: help-ci

.PHONY: ci
ci: lint test examples

.PHONY: ci-dev
ci-dev:
	$(MAKE) $(MFLAGS) MAKELEVEL= ci \
		LINT_GOVULNCHECK_DISABLE=1 \
		GO_TEST_NO_COVER=1 \
		GO_TEST_BUILD_FLAGS_NO_RACE=1

##
## update
##

.PHONY: help-update-deps
help-update-deps:
	@echo 'update-deps: Update all dependencies'
help: help-update-deps

.PHONY: update-deps
update-deps:

##
## rrb
##

ifeq ($(GOOS),linux)

.PHONY: help-rrb
help-rrb:
	@echo 'rrb: rerun build automatically on file changes'
	@echo ' use RRB_DEBOUNCE to set debounce (default: $(RRB_DEBOUNCE))'
	@echo ' use RRB_IGNORE_PATTERN to set ignore pattern (default: $(RRB_IGNORE_PATTERN))'
	@echo ' use RRB_LOG_LEVEL to set log level (default: $(RRB_LOG_LEVEL))'
	@echo ' use RRB_PATTERN to set the pattern (default: $(RRB_PATTERN))'
	@echo ' use RRB_MAKE_TARGET to set the make target (default: $(RRB_MAKE_TARGET))'
	@echo ' use RRB_EXTRA_CMD to set a command to run after the build is successful (default: $(RRB_EXTRA_CMD))'
	@echo 'rrb-dev: similar to rrb, but with RRB_MAKE_TARGET=ci-dev'
help: help-rrb

.PHONY: rrb
rrb: install-go
	$(RRB) \
		--debounce $(RRB_DEBOUNCE) \
		$(foreach pattern,$(RRB_IGNORE_PATTERN),--ignore-pattern $(pattern)) \
		--log-level $(RRB_LOG_LEVEL) \
		$(foreach pattern,$(RRB_PATTERN),--pattern $(pattern)) \
		-- \
		sh -c "$(MAKE) $(MFLAGS) $(RRB_MAKE_TARGET) && $(RRB_EXTRA_CMD)"

.PHONY: rrb-dev
rrb-dev:
	$(MAKE) $(MFLAGS) MAKELEVEL= \
		rrb \
			RRB_MAKE_TARGET=ci-dev

endif

##
## shell
##

.PHONY: help-shell
help-shell:
	@echo 'shell: starts a development shell'
help: help-shell

.PHONY: shell
shell: install-tools
	@echo Make targets:
	@$(MAKE) help MAKELEVEL=
	@PATH=$(GOBIN):$(GOTOOLDIR):$(PATH) \
		GOOS=$(GOOS) \
		GOARCH=$(GOARCH) \
		GOROOT=$(GOROOT) \
		GOCACHE=$(GOCACHE) \
		GOMODCACHE=$(GOMODCACHE) \
		STATICCHECK_CACHE=$(STATICCHECK_CACHE) \
		bash --rcfile .bashrc
