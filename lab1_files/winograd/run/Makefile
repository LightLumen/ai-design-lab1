#VCS = vcs +v2k -override_timescale=1ns/1ps -full64 -fsdb -debug_all -sverilog +vcs+flush+all -o simv -l compile.log -Mupdate
VCS = vcs +v2k +vc -sverilog -timescale=1ns/1ps +vcs+lic+wait -debug_access+r -l compile.log +multisource_int_delays +neg_tchk +plusarg_save +overlap +warn=noSDFCOM_UHICD,noSDFCOM_IWSBA,noSDFCOM_IANE,noSDFCOM_PONF -full64 -cc gcc +libext+.v+.vlib+.vh 
TB_NAME = winograd_1d_tb
FILE_LIST = winograd

all: com sim verdi

rerun: com sim

com:
	$(VCS) -f ./$(FILE_LIST).f

sim:
	./simv -l simulation.log

verdi:
	verdi -top $(TB_NAME) -sv -f ./$(FILE_LIST).f \
	-ssf $(TB_NAME).fsdb &
 
clean:
	rm -rf ./csrc *.daidir ./csrc  						\
	*.log  *.vpd  *.vdb  simv* *.key  stack*  vc_hdrs.h				\
	+race.out* novas.conf novas_dump.log verdi* *fsdb* apb2apb_async	   