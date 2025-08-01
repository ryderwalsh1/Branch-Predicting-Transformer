# Makefile for matrix multiplication module

# Compiler and flags
IVERILOG = iverilog
VVP = vvp
GTKWAVE = gtkwave
VFLAGS = -Wall

# Directory structure
TB_DIR = testbenches

# Sequential source files
SEQUENTIAL_SOURCES = sequential_matrix_mult.v
SEQUENTIAL_TESTBENCH = $(TB_DIR)/sequential_matrix_mult_tb.v
SEQUENTIAL_TOP = sequential_matrix_mult_tb

# Systolic array files
SYSTOLIC_SOURCES = systolic_matrix_mult.v
SYSTOLIC_SOURCES_V2 = systolic_matrix_mult_v2.v
SYSTOLIC_TB = $(TB_DIR)/systolic_matrix_mult_tb.v
SYSTOLIC_3X3_TB = $(TB_DIR)/systolic_matrix_mult_3x3_tb.v
SYSTOLIC_5X5_TB = $(TB_DIR)/systolic_matrix_mult_5x5_tb.v
SYSTOLIC_8X8_TB = $(TB_DIR)/systolic_matrix_mult_8x8_tb.v
SYSTOLIC_DEBUG = $(TB_DIR)/systolic_debug.v
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
	./run_with_log.sh sequential_results.txt $(SEQUENTIAL_EXECUTABLE)

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

# Compile and run systolic with logging
systolic-log: systolic-compile systolic-run-log

systolic-compile: $(SYSTOLIC_SOURCES) $(SYSTOLIC_TB)
	$(IVERILOG) $(VFLAGS) -o $(SYSTOLIC_EXECUTABLE) $(SYSTOLIC_TB) $(SYSTOLIC_SOURCES)

systolic-v2: systolic-v2-compile systolic-v2-run

# Compile and run systolic-v2 with logging
systolic-v2-log: systolic-v2-compile systolic-v2-run-log

systolic-v2-compile: $(SYSTOLIC_SOURCES_V2) $(SYSTOLIC_TB)
	$(IVERILOG) $(VFLAGS) -o systolic_v2.vvp $(SYSTOLIC_TB) $(SYSTOLIC_SOURCES_V2)

systolic-v2-run: systolic_v2.vvp
	$(VVP) systolic_v2.vvp

# Run systolic-v2 simulation with logging
systolic-v2-run-log: systolic_v2.vvp
	./run_with_log.sh systolic_v2_results.txt systolic_v2.vvp

systolic-run: $(SYSTOLIC_EXECUTABLE)
	$(VVP) $(SYSTOLIC_EXECUTABLE)

# Run systolic simulation with logging
systolic-run-log: $(SYSTOLIC_EXECUTABLE)
	./run_with_log.sh systolic_results.txt $(SYSTOLIC_EXECUTABLE)

systolic-wave: $(SYSTOLIC_WAVEFORM)
	$(GTKWAVE) $(SYSTOLIC_WAVEFORM) &

systolic-view: systolic-compile systolic-run systolic-wave

systolic-debug: $(SYSTOLIC_DEBUG) $(SYSTOLIC_SOURCES)
	$(IVERILOG) $(VFLAGS) -o systolic_debug.vvp $(SYSTOLIC_DEBUG) $(SYSTOLIC_SOURCES)
	$(VVP) systolic_debug.vvp
	$(GTKWAVE) systolic_debug.vcd &

# 3x3 systolic array test
systolic-3x3: systolic-3x3-compile systolic-3x3-run

systolic-3x3-compile: $(SYSTOLIC_SOURCES_V2) $(SYSTOLIC_3X3_TB)
	$(IVERILOG) $(VFLAGS) -o systolic_3x3.vvp $(SYSTOLIC_3X3_TB) $(SYSTOLIC_SOURCES_V2)

systolic-3x3-run: systolic_3x3.vvp
	$(VVP) systolic_3x3.vvp

systolic-3x3-view: systolic-3x3-compile systolic-3x3-run
	$(GTKWAVE) systolic_matrix_mult_3x3_tb.vcd &

systolic-3x3-log: systolic-3x3-compile
	./run_with_log.sh systolic_3x3_results.txt systolic_3x3.vvp

# 5x5 systolic array comprehensive test
systolic-5x5: systolic-5x5-compile systolic-5x5-run

systolic-5x5-compile: $(SYSTOLIC_SOURCES_V2) $(SYSTOLIC_5X5_TB)
	$(IVERILOG) $(VFLAGS) -o systolic_5x5.vvp $(SYSTOLIC_5X5_TB) $(SYSTOLIC_SOURCES_V2)

systolic-5x5-run: systolic_5x5.vvp
	$(VVP) systolic_5x5.vvp

systolic-5x5-view: systolic-5x5-compile systolic-5x5-run
	$(GTKWAVE) systolic_matrix_mult_5x5_tb.vcd &

systolic-5x5-log: systolic-5x5-compile
	./run_with_log.sh systolic_5x5_results.txt systolic_5x5.vvp

# 8x8 systolic array performance test
systolic-8x8: systolic-8x8-compile systolic-8x8-run

systolic-8x8-compile: $(SYSTOLIC_SOURCES_V2) $(SYSTOLIC_8X8_TB)
	$(IVERILOG) $(VFLAGS) -o systolic_8x8.vvp $(SYSTOLIC_8X8_TB) $(SYSTOLIC_SOURCES_V2)

systolic-8x8-run: systolic_8x8.vvp
	$(VVP) systolic_8x8.vvp

systolic-8x8-log: systolic-8x8-compile
	./run_with_log.sh systolic_8x8_results.txt systolic_8x8.vvp

# Comprehensive test suite - run all systolic tests
systolic-comprehensive: systolic-3x3 systolic-5x5 systolic-8x8

# Clean all generated files
clean:
	rm -f *.vvp *.vcd *.txt

# Help target
help:
	@echo "Available targets:"
	@echo ""
	@echo "Sequential matrix multiplier:"
	@echo "  make sequential      - Compile and run sequential matrix multiplication (default)"
	@echo "  make sequential-log  - Compile and run with output saved to timestamped file"
	@echo "  make sequential-view - Compile, run, and view waveforms"
	@echo "  make sequential-clean - Clean sequential generated files"
	@echo ""
	@echo "Systolic array targets:"
	@echo "  make systolic        - Compile and run systolic array implementation (4x3 * 3x2)"
	@echo "  make systolic-log    - Compile and run systolic with output saved to timestamped file"
	@echo "  make systolic-v2     - Compile and run improved systolic array (v2)"
	@echo "  make systolic-v2-log - Compile and run systolic-v2 with output saved to timestamped file"
	@echo "  make systolic-3x3    - Compile and run 3x3 systolic array test"
	@echo "  make systolic-3x3-view - Run 3x3 test and view waveforms"
	@echo "  make systolic-3x3-log - Run 3x3 test with output logging"
	@echo "  make systolic-5x5    - Compile and run 5x5 comprehensive test suite"
	@echo "  make systolic-5x5-log - Run 5x5 test with output logging"
	@echo "  make systolic-8x8    - Compile and run 8x8 performance test"
	@echo "  make systolic-8x8-log - Run 8x8 test with output logging"
	@echo "  make systolic-comprehensive - Run all systolic tests (3x3, 5x5, 8x8)"
	@echo "  make systolic-view   - Compile, run systolic array and view waveforms"
	@echo "  make systolic-debug  - Run debug testbench for systolic array"
	@echo ""
	@echo "General targets:"
	@echo "  make clean           - Remove all generated files"
	@echo "  make help            - Show this help message"

.PHONY: sequential sequential-compile sequential-run sequential-run-log sequential-wave sequential-view sequential-clean sequential-log clean help systolic systolic-compile systolic-run systolic-run-log systolic-wave systolic-view systolic-log systolic-v2 systolic-v2-compile systolic-v2-run systolic-v2-run-log systolic-v2-log systolic-debug systolic-3x3 systolic-3x3-compile systolic-3x3-run systolic-3x3-view systolic-3x3-log systolic-5x5 systolic-5x5-compile systolic-5x5-run systolic-5x5-view systolic-5x5-log systolic-8x8 systolic-8x8-compile systolic-8x8-run systolic-8x8-log systolic-comprehensive