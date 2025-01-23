.DEFAULT_GOAL := help

PROGRAMS := simple_client midisine capture_client

%: %.zig
	zig build-exe $< -lc -ljack -lsndfile

# Clean up all generated executables
clean:
	rm -f $(PROGRAMS) *.o

HELP_FORMAT := "  \033[36m%-30s\033[0m %s\n"
.PHONY: help
help:
	@echo Available programs:
	@echo
	@printf $(HELP_FORMAT) simple_client "Simple client that generates a sine wave"
	@printf $(HELP_FORMAT) midisine "Handles MIDI input and generates a sine wave"
	@printf $(HELP_FORMAT) capture_client "[WIP] Record audio and export output in WAVE file"
	@echo
	@echo Type make followed by the program name to build it
	@echo
