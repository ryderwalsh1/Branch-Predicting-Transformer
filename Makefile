# Makefile for matrix multiplication module

# Compiler and flags
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave
VFLAGS = -Wall

# Sequential source files
SEQUENTIAL_SOURCES = sequential_matrix_mult.v
SEQUENTIAL_TESTBENCH = sequential_matrix_mult_tb.v
SEQUENTIAL_TOP = sequential_matrix_mult_tb

# Systolic array files
SYSTOLIC_SOURCES = systolic_matrix_mult.v
SYSTOLIC_SOURCES_V2 = systolic_matrix_mult_v2.v
SYSTOLIC_TB = systolic_matrix_mult_tb.v
SYSTOLIC_DEBUG = systolic_debug.v
SYSTOLIC_TOP = systolic_matrix_mult_tb

# Output files
SEQUENTIAL_EXECUTABLE = $(SEQUENTIAL_TOP).vvp
SEQUENTIAL_WAVEFORM = $(SEQUENTIAL_TOP).vcd
SYSTOLIC_EXECUTABLE = $(SYSTOLIC_TOP).vvp
SYSTOLIC_WAVEFORM = $(SYSTOLIC_TOP).vcd

# Default target
sequential: sequential-compile sequential-run

# Compile and run with logging
sequential-log: sequential-compile sequential-run-log

# Compile the design and testbench
sequential-compile: $(SEQUENTIAL_SOURCES) $(SEQUENTIAL_TESTBENCH)
	$(IVERILOG) $(VFLAGS) -o $(SEQUENTIAL_EXECUTABLE) $(SEQUENTIAL_TESTBENCH) $(SEQUENTIAL_SOURCES)

# Run the simulation
sequential-run: $(SEQUENTIAL_EXECUTABLE)
	$(VVP) $(SEQUENTIAL_EXECUTABLE)

# Run the simulation and save output to file
sequential-run-log: $(SEQUENTIAL_EXECUTABLE)
	$(VVP) $(SEQUENTIAL_EXECUTABLE) | tee matrix_mult_results.txt

# Open waveform viewer
sequential-wave: $(SEQUENTIAL_WAVEFORM)
	$(GTKWAVE) $(SEQUENTIAL_WAVEFORM) &

# Clean generated files
sequential-clean:
	rm -f $(SEQUENTIAL_EXECUTABLE) $(SEQUENTIAL_WAVEFORM)
	rm -f *.vvp *.vcd

# Run simulation and view waveforms
sequential-view: sequential-compile sequential-run sequential-wave

# Systolic array targets
systolic: systolic-compile systolic-run

systolic-compile: $(SYSTOLIC_SOURCES) $(SYSTOLIC_TB)
	$(IVERILOG) $(VFLAGS) -o $(SYSTOLIC_EXECUTABLE) $(SYSTOLIC_TB) $(SYSTOLIC_SOURCES)

systolic-v2: systolic-v2-compile systolic-v2-run

systolic-v2-compile: $(SYSTOLIC_SOURCES_V2) $(SYSTOLIC_TB)
	$(IVERILOG) $(VFLAGS) -o systolic_v2.vvp $(SYSTOLIC_TB) $(SYSTOLIC_SOURCES_V2)

systolic-v2-run: systolic_v2.vvp
	$(VVP) systolic_v2.vvp

systolic-run: $(SYSTOLIC_EXECUTABLE)
	$(VVP) $(SYSTOLIC_EXECUTABLE)

systolic-wave: $(SYSTOLIC_WAVEFORM)
	$(GTKWAVE) $(SYSTOLIC_WAVEFORM) &

systolic-view: systolic-compile systolic-run systolic-wave

systolic-debug: $(SYSTOLIC_DEBUG) $(SYSTOLIC_SOURCES)
	$(IVERILOG) $(VFLAGS) -o systolic_debug.vvp $(SYSTOLIC_DEBUG) $(SYSTOLIC_SOURCES)
	$(VVP) systolic_debug.vvp
	$(GTKWAVE) systolic_debug.vcd &

# Clean all generated files
clean:
	rm -f *.vvp *.vcd *.txt

# Help target
help:
	@echo "Available targets:"
	@echo ""
	@echo "Sequential matrix multiplier:"
	@echo "  make sequential      - Compile and run sequential matrix multiplication (default)"
	@echo "  make sequential-log  - Compile and run with output saved to file"
	@echo "  make sequential-view - Compile, run, and view waveforms"
	@echo "  make sequential-clean - Clean sequential generated files"
	@echo ""
	@echo "Systolic array targets:"
	@echo "  make systolic        - Compile and run systolic array implementation"
	@echo "  make systolic-v2     - Compile and run improved systolic array (v2)"
	@echo "  make systolic-view   - Compile, run systolic array and view waveforms"
	@echo "  make systolic-debug  - Run debug testbench for systolic array"
	@echo ""
	@echo "General targets:"
	@echo "  make clean           - Remove all generated files"
	@echo "  make help            - Show this help message"

.PHONY: sequential sequential-compile sequential-run sequential-run-log sequential-wave sequential-view sequential-clean clean help systolic systolic-compile systolic-run systolic-wave systolic-view systolic-v2 systolic-v2-compile systolic-v2-run systolic-debug