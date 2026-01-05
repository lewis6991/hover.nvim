VIMRUNTIME=$(shell nvim --headless +'echo $$VIMRUNTIME' +q 2>&1)

.PHONY: emmylua-check
emmylua-check:
	VIMRUNTIME=$(VIMRUNTIME) emmylua_check .
