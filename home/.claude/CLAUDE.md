## Verilog Style

Required for all commercial Verilog modules.

Naming:
- Module name and file name start with `iob_` (e.g. `iob_fifo` in `iob_fifo.v`).
- Port suffixes: inputs `_i`, outputs `_o`, inouts `_io`.
- Signals assigned in a clocked block have the `_reg` suffix.

Structure: each module has at most one of each of these blocks:
- `always @(posedge clk)` for registers.
- `always @(negedge clk)` for registers, only when a negedge register is needed.
- `always @*` for all combinational logic.

Rules:
- Use `assign` only to connect one signal directly to another:
  `assign a = b;` is OK, `assign a = b & c;` is not (put it in `always @*`).
- Write registers yourself in the clocked block. Do not instantiate `iob_reg`.
- Assign each register from only one clock edge (posedge or negedge, never both).
- Avoid parameters. When one is needed, use it only for structure: widths
  (`[W-1:0]`), `generate if (PARAM)` and similar elaboration-time constructs.
  Never combine a parameter with nets in logic: `assign y = x & MASK;`,
  `if (cnt_reg == MAX)` and `y = EN ? a : b;` are not OK.

## Git

- Never add an agent as commit co-author.

## General Coding

- Avoid long comment blocks
- Reduce comments to only necessary explanations or context non-redundant with
  the existing code
