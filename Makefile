.DEFAULT_GOAL := help

PROGRAMS := simple_client midisine

%: %.zig
	zig build-exe $< -lc -ljack

# Clean up all generated executables
clean:
	rm -f $(PROGRAMS) *.o

HELP_FORMAT := "  \033[36m%-30s\033[0m %s\n"
.PHONY: help
help:
	@echo Available programs:
	@echo
	@printf $(HELP_FORMAT) simple_client "Simple client that generates a sine wave"
	@printf $(HELP_FORMAT) midisine "Client that handles MIDI input and generates a sine wave"
	@echo
	@echo Type make followed by the program name to build it
	@echo
