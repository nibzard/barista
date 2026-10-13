# ABOUTME: Build and test commands for the Apocalypse Barista Godot project.
# ABOUTME: Run "make check" before every commit; run "make run" to play on desktop.

GODOT ?= godot
PROJECT := game

.PHONY: import lint fmt test check run

import:
	$(GODOT) --headless --path $(PROJECT) --import

lint:
	gdformat --check $(PROJECT)/scripts $(PROJECT)/tests
	gdlint $(PROJECT)/scripts $(PROJECT)/tests

fmt:
	gdformat $(PROJECT)/scripts $(PROJECT)/tests

test: import
	cd $(PROJECT) && $(GODOT) --headless --path . \
		--script res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode \
		-a res://tests

check: lint test

run:
	$(GODOT) --path $(PROJECT)
