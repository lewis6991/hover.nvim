export NVIM_TEST_VERSION ?= nightly

$(NVIM_TEST):
	git clone --depth 1 --branch v1.2.0 https://github.com/lewis6991/nvim-test $@
	$@/bin/nvim-test --init

NVIM_TEST_RUNTIME=$(XDG_DATA_HOME)/nvim-test/nvim-test-$(NVIM_TEST_VERSION)/share/nvim/runtime

$(NVIM_TEST_RUNTIME): $(NVIM_TEST)
	$^/bin/nvim-test --init

.PHONY: emmylua-check
emmylua-check: $(NVIM_TEST_RUNTIME)
	VIMRUNTIME=$(NVIM_TEST_RUNTIME) emmylua_check .
