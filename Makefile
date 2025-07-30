# Makefile for matrix multiplication module

# Compiler and flags
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave
VFLAGS = -Wall

# Source files
SOURCES = matrix_mult.v
TESTBENCH = matrix_mult_tb.v
TOP = matrix_mult_tb

# Output files
EXECUTABLE = $(TOP).vvp
WAVEFORM = $(TOP).vcd

# Default target
all: compile run

# Compile the design and testbench
compile: $(SOURCES) $(TESTBENCH)
	$(IVERILOG) $(VFLAGS) -o $(EXECUTABLE) $(TESTBENCH) $(SOURCES)

# Run the simulation
run: $(EXECUTABLE)
	$(VVP) $(EXECUTABLE)

# Open waveform viewer
wave: $(WAVEFORM)
	$(GTKWAVE) $(WAVEFORM) &

# Clean generated files
clean:
	rm -f $(EXECUTABLE) $(WAVEFORM)
	rm -f *.vvp *.vcd

# Run simulation and view waveforms
view: compile run wave

# Help target
help:
	@echo "Available targets:"
	@echo "  make all     - Compile and run simulation (default)"
	@echo "  make compile - Compile Verilog files"
	@echo "  make run     - Run simulation"
	@echo "  make wave    - Open waveform viewer"
	@echo "  make view    - Compile, run, and view waveforms"
	@echo "  make clean   - Remove generated files"
	@echo "  make help    - Show this help message"

.PHONY: all compile run wave clean view help