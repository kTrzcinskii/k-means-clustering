CC=nvcc
# this g++-9 and -arch=sm_35 is only for it to work on university machine (GPUNODE2)
# the last flag disables warning error (it seems like sm_35 is deprecated)
C_FLAGS_NODE2=-ccbin /usr/bin/g++-9 -arch=sm_35 -Wno-deprecated-gpu-targets
SRC=src/main.cu
TARGET=k_means_clustering

node2: ${TARGET}-NODE2
node3: ${TARGET}-NODE3

${TARGET}-NODE2:
	${CC} ${C_FLAGS_NODE2} -o ${TARGET} ${SRC}

${TARGET}-NODE3:
	${CC} -o ${TARGET} ${SRC}

clean:
	rm -f ${TARGET}

.PHONY: clean
