# ============================================================
# PS-04 ASYNCHRONOUS FIFO
# SKY130A / OpenLane 2
# Timing Constraints
# ============================================================

# ------------------------------------------------------------
# WRITE CLOCK
# 100 MHz
# Period = 10 ns
# ------------------------------------------------------------

create_clock -name wr_clk \
    -period 10.0 \
    -waveform {0.0 5.0} \
    [get_ports wr_clk]


# ------------------------------------------------------------
# READ CLOCK
# ~71.43 MHz
# Period = 14 ns
# ------------------------------------------------------------

create_clock -name rd_clk \
    -period 14.0 \
    -waveform {0.0 7.0} \
    [get_ports rd_clk]


# ------------------------------------------------------------
# ASYNCHRONOUS CLOCK DOMAINS
#
# wr_clk and rd_clk have no fixed phase relationship.
# Therefore ordinary synchronous timing analysis must not
# be performed between these two clock domains.
# ------------------------------------------------------------

set_clock_groups -asynchronous \
    -group [get_clocks wr_clk] \
    -group [get_clocks rd_clk]


# ------------------------------------------------------------
# INPUT DELAYS - WRITE DOMAIN
# ------------------------------------------------------------

set_input_delay -clock wr_clk -max 2.0 \
    [get_ports {wr_en wr_data[*] afull_threshold[*]}]

set_input_delay -clock wr_clk -min 0.5 \
    [get_ports {wr_en wr_data[*] afull_threshold[*]}]


# ------------------------------------------------------------
# INPUT DELAYS - READ DOMAIN
# ------------------------------------------------------------

set_input_delay -clock rd_clk -max 2.0 \
    [get_ports {rd_en aempty_threshold[*]}]

set_input_delay -clock rd_clk -min 0.5 \
    [get_ports {rd_en aempty_threshold[*]}]


# ------------------------------------------------------------
# RESET
#
# Asynchronous reset is not treated as normal data timing.
# ------------------------------------------------------------

set_false_path -from [get_ports arst_n]


# ------------------------------------------------------------
# OUTPUT DELAYS - WRITE DOMAIN
# ------------------------------------------------------------

set_output_delay -clock wr_clk -max 2.0 \
    [get_ports {full afull}]

set_output_delay -clock wr_clk -min 0.5 \
    [get_ports {full afull}]


# ------------------------------------------------------------
# OUTPUT DELAYS - READ DOMAIN
# ------------------------------------------------------------

set_output_delay -clock rd_clk -max 2.0 \
    [get_ports {empty aempty rd_data[*]}]

set_output_delay -clock rd_clk -min 0.5 \
    [get_ports {empty aempty rd_data[*]}]


# ------------------------------------------------------------
# CLOCK UNCERTAINTY
#
# Small conservative margin for clock jitter/skew.
# ------------------------------------------------------------

set_clock_uncertainty 0.2 [get_clocks wr_clk]
set_clock_uncertainty 0.2 [get_clocks rd_clk]


# ------------------------------------------------------------
# CLOCK TRANSITION
# ------------------------------------------------------------

set_clock_transition 0.2 [get_clocks wr_clk]
set_clock_transition 0.2 [get_clocks rd_clk]


# ------------------------------------------------------------
# MAXIMUM TRANSITION
# ------------------------------------------------------------

set_max_transition 0.5 [current_design]


# ============================================================
# END OF SDC
# ============================================================
