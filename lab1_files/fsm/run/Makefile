VCS = vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+r -f fsm.f -o simv -l compile.log

.PHONY: rerun com sim clean

rerun: com sim

com:
	$(VCS)

sim:
	./simv -l simulation.log

clean:
	rm -rf simv simv.daidir csrc ucli.key compile.log simulation.log
