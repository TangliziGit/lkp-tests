all: install

# wakeup:
# 	$(MAKE) -C bin/event wakeup

install:
	bash sbin/install-dependencies.sh

.PHONY: doc
doc:
	lkp gen-doc > ./doc/tests.md

tests/%.md: tests/%.yaml
	lkp gen-doc $<

ctags:
	ctags -R --links=no
