# On linux: cmake -S . -B build -DCMAKE_BUILD_TYPE=Release 
cmake_minimum_required(VERSION 3.22)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

project(KMeans LANGUAGES CXX CUDA)

add_compile_options(--extended-lambda)

# Add CUDA executable target
add_executable(KMeans src/base_timer.cuh src/consts.cuh src/cpu_timer.cu src/cpu_timer.cuh src/file_io.cu src/file_io.cuh src/gpu_timer.cu src/gpu_timer.cuh src/k_means_clustering_cpu.cuh src/k_means_clustering_gpu_sm.cuh src/k_means_clustering_gpu_thrust.cuh src/k_means_data.cuh src/main.cu src/utils.cu src/utils.cuh)
