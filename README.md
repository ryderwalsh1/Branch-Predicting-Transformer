# Branch-Predicting-Transformer

A lightweight transformer model for predicting branch outcomes in x86 assembly code, developed as an ECE475 term project at Princeton University in partnership with classmate Cameron Crow '26.

## Overview

This project implements a novel branch predictor using a transformer architecture, inspired by the success of GPT models in sequence prediction tasks. The model predicts whether branch instructions will be taken by analyzing sequences of assembly instructions and register file states.

### Key Features
- Transformer-based branch prediction with ~933K parameters
- Achieves up to 95.2% prediction accuracy on some test cases
- Designed for potential hardware implementation
- Trained on real x86 instruction traces from Linux utilities

## Authors

- Ryder Walsh (rw7049@princeton.edu)
- Cameron Crow (cc3385@princeton.edu)

## Project Structure

```
.
├── Branch_Predicting_Transformer.ipynb  # Main implementation notebook
├── branchtrace.cpp                      # Intel PIN tool for collecting traces
├── ECE475 Term Project.pdf              # Project report
├── PIN Dumps/                           # Directory containing instruction traces
│   ├── *_ins_trunc.out                  # Instruction trace files
│   └── *_reg_trunc.out                  # Register dump files
├── matrix_mult.v                        # Verilog matrix multiplier module
├── matrix_mult_tb.v                     # Testbench for matrix multiplier
├── Makefile                             # Build automation for Verilog
└── README.md                            # This file
```

## Technical Details

### Architecture

The transformer model consists of:
- **Input Embedding**: Multi-modal embeddings for instructions, registers, immediates, and memory addresses
- **Transformer Blocks**: 3 layers with 4 attention heads each
- **Custom Attention Masking**: Specialized mask for register-instruction relationships
- **Output Head**: Binary classification for branch taken/not taken

### Model Configuration

| Parameter | Value | Description |
|-----------|-------|-------------|
| `n_layer` | 3 | Number of transformer layers |
| `n_head` | 4 | Number of attention heads |
| `d_embd` | 64 | Embedding dimension |
| `d_attn` | 64 | Attention dimension |
| `d_mlp` | 128 | MLP hidden dimension |
| `context_size` | 20 | Maximum instruction sequence length |
| `vocab_size` | 981 | Number of x86 instruction mnemonics |
| Total Parameters | 933,376 | ~1MB model size |

### Data Collection

We use Intel PIN for dynamic binary instrumentation to collect training data:

1. **Instruction Traces**: Each line contains:
   - Program counter (PC)
   - Disassembled instruction
   - Branch information (is_branch, taken/not_taken)
   - Immediate values
   - Source and destination registers

2. **Register Dumps**: Complete state of 16 x86 general-purpose registers at each instruction

### Training Process

1. Parse PIN output files to extract instruction sequences and register states
2. Create training sequences that end at branch instructions
3. Train transformer to predict branch outcome based on preceding context
4. Evaluate on held-out test programs

## Installation and Usage

### Prerequisites

- Intel PIN SDK (for data collection)
- Python 3.x with PyTorch
- CUDA-capable GPU (recommended)

### Data Collection

```bash
# Compile the PIN tool
make obj-intel64/branchtrace.so

# Run PIN on a program to collect traces
pin -t obj-intel64/branchtrace.so \
    -o1 instruction_trace.out \
    -o2 register_trace.out \
    -- /bin/ls
```

### Model Training

1. Open `Branch_Predicting_Transformer.ipynb` in Jupyter/Colab
2. Upload trace files when prompted
3. Run all cells to train the model
4. Model will be evaluated on test programs automatically

## Results

### Performance Summary

| Training Set | Test Program | Accuracy |
|--------------|--------------|----------|
| ls (50K points) | ls | 95.20% |
| ls (50K points) | cat | 75.58% |
| ls (50K points) | date | 81.02% |
| Multiple programs | env | 86-88% |

### Key Findings

1. The model generalizes reasonably well to unseen programs
2. Performance is best when test programs are similar to training data
3. Larger training sets improve generalization
4. The lightweight design maintains good accuracy while being hardware-feasible

## Novel Contributions

### Inference Paradigm

Unlike traditional branch predictors that operate at fetch stage, our transformer:
- Predicts branches up to 20 instructions in advance
- Updates predictions as execution approaches the branch
- Enables pipelining with minimal penalty
- Supports KV caching for efficiency

### Potential Optimizations

1. **KV Caching**: Reuse key/value computations across predictions
2. **Confidence Thresholding**: Finalize predictions early when confidence is high
3. **Bit Resolution Reduction**: Use lower precision weights to save memory
4. **Loop Unrolling**: Predict multiple branches when confident

## Hardware Implementation

### Matrix Multiplication Accelerator

We've developed a parameterizable Verilog matrix multiplier module for potential hardware acceleration of the transformer's attention mechanism:

#### Features
- **Parameterizable dimensions**: Supports any M×K × K×N matrix multiplication
- **Fixed-point arithmetic**: 16-bit data with 8 fractional bits
- **Sequential design**: One MAC operation per cycle
- **Memory efficient**: Internal storage for all matrices

#### Usage
```bash
# Compile and run testbench
make all

# View waveforms
make view

# Clean generated files
make clean
```

#### Example Instantiation
For attention computation with context size 15:
```verilog
// Q×K^T multiplication
matrix_mult #(.M(15), .N(15), .K(64)) qkt_mult (...);

// (Q×K^T)×V multiplication  
matrix_mult #(.M(15), .N(64), .K(15)) attn_mult (...);
```

## Limitations and Future Work

- Current latency may be too high for direct hardware implementation
- Limited to sequences of 20 instructions
- Requires pre-training on representative workloads
- Memory footprint (~1MB) larger than traditional predictors
- Matrix multiplier currently sequential (future: systolic array)

## References

1. Deleep, A. (2024). Augmenting Dynamic Branch Predictors with Static Transformer Guided Clustering. Imperial College London.
2. Jiménez, D. A., & Lin, C. Dynamic Branch Prediction with Perceptrons. University of Texas at Austin.
3. Intel 64 and IA-32 Architectures Software Developer's Manual Volume 1: Basic Architecture

## License

This project was developed for academic purposes as part of ECE475 at Princeton University.