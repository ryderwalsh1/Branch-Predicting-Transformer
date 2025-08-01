#!/bin/bash

# Script to run Verilog simulation and capture output
# Usage: ./run_with_log.sh [output_filename] [vvp_file]

OUTPUT_FILE=${1:-"matrix_mult_results.txt"}
VVP_FILE=${2:-"sequential_matrix_mult_tb.vvp"}
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
TIMESTAMPED_FILE="${OUTPUT_FILE%.txt}_${TIMESTAMP}.txt"

echo "Running matrix multiplication testbench..."
echo "Output will be saved to: $OUTPUT_FILE"
echo "Timestamped copy will be saved to: $TIMESTAMPED_FILE"
echo

# Run the simulation and capture output
vvp "$VVP_FILE" 2>&1 | tee "$OUTPUT_FILE"

# Create a timestamped copy
cp "$OUTPUT_FILE" "$TIMESTAMPED_FILE"

# Add summary at the end
echo >> "$OUTPUT_FILE"
echo "=== Simulation completed at $(date) ===" >> "$OUTPUT_FILE"

# Count pass/fail
PASS_COUNT=$(grep -c "PASS:" "$OUTPUT_FILE")
FAIL_COUNT=$(grep -c "ERROR:" "$OUTPUT_FILE")

echo "Summary: $PASS_COUNT passed, $FAIL_COUNT failed" >> "$OUTPUT_FILE"

# Display summary to console
echo
echo "Simulation complete!"
echo "Results saved to: $OUTPUT_FILE"
echo "Summary: $PASS_COUNT passed, $FAIL_COUNT failed"