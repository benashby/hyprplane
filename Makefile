DESTDIR ?= /
PREFIX  ?= $(DESTDIR)usr/local
BINDIR  ?= $(PREFIX)/bin

.PHONY: install uninstall

install:
	install -v -D -m 0755 scripts/hyprplane        $(BINDIR)/hyprplane
	install -v -D -m 0755 scripts/hyprplane-status $(BINDIR)/hyprplane-status

uninstall:
	rm -f $(BINDIR)/hyprplane $(BINDIR)/hyprplane-status
