#
# TOP MAKEFILE
#

SIM_DIR=./hardware/simulation/icarus

#
# SIMULATE
#
sim:
	make -C $(SIM_DIR) run

sim-waves:
	gtkwave -a $(SIM_DIR)/../waves.gtkw $(SIM_DIR)/*.vcd &

sim-clean:
	make -C $(SIM_DIR) clean

#
# CLEAN ALL
#
clean-all: sim-clean

.PHONY: sim sim-waves sim-clean \
	clean-all
