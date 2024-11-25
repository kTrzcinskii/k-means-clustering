#ifndef K_MEANS_CLUSTERING_GPU_SM
#define K_MEANS_CLUSTERING_GPU_SM

#include <thrust/host_vector.h>
#include <cmath>

#include "k_means_data.cuh"
#include "utils.cuh"
#include "consts.cuh"

namespace KMeansClusteringGPUSM
{
    template <size_t DIM>
    __device__ float pointToClusterDistance(KMeansData::KMeansDataGPU *d_data, size_t pointIndex, size_t clusterIndex)
    {
        float distance = 0;
        for (size_t d = 0; d < DIM; d++)
        {
            float diff = KMeansData::Helpers<DIM>::GetCoord(d_data->d_pointsValues, d_data->pointsCount, pointIndex, d) - KMeansData::Helpers<DIM>::GetCoord(d_data->d_clustersValues, d_data->clustersCount, clusterIndex, d);

            distance += diff * diff;
        }
        return sqrt(distance);
    }

    template <size_t DIM>
    __device__ size_t findNearestCluster(KMeansData::KMeansDataGPU *d_data, size_t pointIndex)
    {
        float minDist = pointToClusterDistance<DIM>(d_data, pointIndex, 0);
        size_t minDistIndex = 0;
        for (size_t j = 1; j < d_data->clustersCount; j++)
        {
            float dist = pointToClusterDistance<DIM>(d_data, pointIndex, j);
            if (dist < minDist)
            {
                minDist = dist;
                minDistIndex = j;
            }
        }
        return minDistIndex;
    }

    // Function for finding new membership for each point
    // Each thread should be responsible for single point
    template <size_t DIM>
    __global__ void calculateMembershipAndNewClusters(KMeansData::KMeansDataGPU *d_data, float *d_newClusters, uint *d_newClustersMembershipCount, size_t *d_memberships /*, bool *hasAnyChanged*/)
    {
        auto threadId = blockDim.x * blockIdx.x + threadIdx.x;

        extern __shared__ char sharedMemory[];
        float *s_clusters = reinterpret_cast<float *>(sharedMemory);
        uint *s_clustersMembershipCount = reinterpret_cast<uint *>(&s_clusters[d_data->clustersCount * DIM]);
        // bool *s_hasChanged = reinterpret_cast<bool *>(&s_clustersMembershipCount[d_data->clustersCount * DIM]);

        // if (threadId == 0)
        // {
        //     s_hasChanged[0] = false;
        // }

        if (threadId < d_data->clustersCount * DIM)
        {
            s_clusters[threadId] = d_data->d_clustersValues[threadId];
        }
        if (threadId < d_data->pointsCount)
        {
            // FIXME:
            // s_clustersMembershipCount[threadId] = 0;
        }

        // Ensure shared memory is properly initialized
        __syncthreads();

        if (threadId < d_data->pointsCount)
        {
            auto nearestClusterIndex = findNearestCluster<DIM>(d_data, threadId);
            for (size_t d = 0; d < DIM; d++)
            {
                // FIXME:
                // atomicAdd(&s_clusters[d * d_data->clustersCount + nearestClusterIndex], KMeansData::Helpers<DIM>::GetCoord(d_data->d_pointsValues, d_data->pointsCount, threadId, d));
                // atomicAdd(&s_clustersMembershipCount[nearestClusterIndex], 1);
            }
            // auto previousClusterIndex = d_memberships[threadId];
            // if (previousClusterIndex != nearestClusterIndex)
            {
                // atomicOr(s_hasChanged, true);
                // d_memberships[threadId] = nearestClusterIndex;
            }
        }

        // Finish all calculation made on shared memory
        __syncthreads();

        if (threadId < d_data->clustersCount * DIM)
        {
            // if (threadId == 0)
            // {
            //     atomicOr(hasAnyChanged, s_hasChanged[0]);
            // }
            // FIXME:
            // d_newClusters[blockIdx.x * d_data->clustersCount + threadId] = s_clusters[threadId];
        }

        if (threadId < d_data->clustersCount)
        {
            // FIXME:
            // d_newClustersMembershipCount[blockIdx.x * d_data->clustersCount + threadId] = s_clustersMembershipCount[threadId];
        }
    }

    // Function for updating clusters based on new membership
    // There should be thread spawned for every cluster for every dimension, so CLUSTERS_COUNT * DIM total
    template <size_t DIM>
    __global__ void updateClusters(KMeansData::KMeansDataGPU *d_data, float *d_newClusters, uint *d_newClustersMembershipCount, size_t previousBlocksCount)
    {
        auto threadId = blockDim.x * blockIdx.x + threadIdx.x;
        if (threadId < d_data->clustersCount * DIM)
        {
            // We sum data from each block
            for (size_t b = 0; b < previousBlocksCount; b++)
            {
                // d_data->d_clustersValues[threadId] += d_newClusters[threadId * b];
            }
            // Can we somehow remove this `%` operation? its probably slow
            // FIXME:
            // d_data->d_clustersValues[threadId] /= d_newClustersMembershipCount[threadId % DIM];
        }
    }

    template <size_t DIM>
    Utils::ClusteringResult kMeansClustering(KMeansData::KMeansDataGPU d_data)
    {
        // FIXME: instead of pointsCount it should be max of pointsCount, dim * clustersCount * newClustersBlocksCount
        const uint newClustersBlocksCount = ceil(d_data.pointsCount * 1.0 / Consts::THREADS_PER_BLOCK);
        // FIXME: is it needed?
        const size_t newClustersSharedMemorySize = d_data.clustersCount * DIM * sizeof(float) + d_data.clustersCount * sizeof(uint);
        const uint updateClustersBlocksCount = ceil(d_data.clustersCount * DIM * 1.0 / Consts::THREADS_PER_BLOCK);

        // TODO: check cuda errors
        size_t *d_memberships;
        float *d_newClusters;
        uint *d_newClustersMembershipCount;
        CHECK_CUDA(cudaMalloc(&d_memberships, sizeof(size_t) * d_data.pointsCount));
        // We have separate clustersValues for each block
        CHECK_CUDA(cudaMalloc(&d_newClusters, sizeof(float) * d_data.clustersCount * DIM * newClustersBlocksCount));
        // We have separate clustersCount for each block
        CHECK_CUDA(cudaMalloc(&d_newClustersMembershipCount, sizeof(uint) * d_data.clustersCount * newClustersBlocksCount));
        // We initialize the array that membership[i] = size_t::MAX
        CHECK_CUDA(cudaMemset(d_memberships, 0xFF, sizeof(size_t) * d_data.pointsCount));

        for (size_t k = 0; k < Consts::MAX_ITERATION; k++)
        {
            // bool hasAnyChanged = false;
            CHECK_CUDA(cudaMemset(d_newClusters, 0, sizeof(float) * d_data.clustersCount * DIM * newClustersBlocksCount));
            CHECK_CUDA(cudaMemset(d_newClustersMembershipCount, 0, sizeof(uint) * d_data.clustersCount * newClustersBlocksCount));

            // Kernel callls
            // TODO: set size of shared memory`newClustersSharedMemorySize`
            calculateMembershipAndNewClusters<DIM><<<newClustersBlocksCount, Consts::THREADS_PER_BLOCK>>>(&d_data, d_newClusters, d_newClustersMembershipCount, d_memberships /*,&hasAnyChanged*/);
            CHECK_CUDA(cudaGetLastError());

            updateClusters<DIM><<<updateClustersBlocksCount, Consts::THREADS_PER_BLOCK>>>(&d_data, d_newClusters, d_newClustersMembershipCount, newClustersBlocksCount);
            CHECK_CUDA(cudaGetLastError());
            // if (!hasAnyChanged)
            // {
            //     break;
            // }
        }

        thrust::host_vector<float> clustersValues(d_data.clustersCount * DIM);
        thrust::host_vector<size_t> membership(d_data.pointsCount);

        CHECK_CUDA(cudaDeviceSynchronize());

        CHECK_CUDA(cudaMemcpy(clustersValues.data(), d_data.d_clustersValues, sizeof(float) * clustersValues.size(), cudaMemcpyDeviceToHost));
        CHECK_CUDA(cudaMemcpy(membership.data(), d_memberships, sizeof(size_t) * d_data.pointsCount, cudaMemcpyDeviceToHost));

        cudaFree(d_memberships);
        cudaFree(d_newClusters);
        cudaFree(d_newClustersMembershipCount);

        return Utils::ClusteringResult{
            .clustersValues = clustersValues,
            .membership = membership,
        };
    }
} // KMeansClusteringGPUSM

#endif // K_MEANS_CLUSTERING_GPU_SM