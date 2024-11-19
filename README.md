# K-Means Clustering using Cuda

## Loading data

Data is loaded from `txt` file with following structure:

```
N K
x1_{0} x2_{0} ... x{DIM}_{0}
.       .      .        .
.       .      .        .
.       .      .        .
x1_{N} x2_{N} ... x{DIM}_{N}
```

where:

- `N` - number of points
- `K` - number of clusters
- each line contains coordinates of i-th point separated by space

Additionally:

- `DIM` - dimension of the space (number of each point's coordinates) - template parameter

## Algorithm

Pseudo code can be found at [http://www.eecs.northwestern.edu/~wkliao/Kmeans/index.html](http://www.eecs.northwestern.edu/~wkliao/Kmeans/index.html).

Main part of the algorithm can be split into two parts:

### Find new centroid for each point

In this part we create thread for each point and calculate new centroid for each one in parallel.

### Find new centroids

After calculating centroid for each point we want to find new centroids. For this task we have two different methods:

#### First method

Firstly for each point we create thread and add points coordinates (divided by number of points assigned to given centroid) to a accumulator stored in shared memory.
It may be the case that points assigned to given centroid are not stored in one block. As shared memory is block-scoped, after finishing all the threads for each centroid we need to collect its results from across the blocks which contain this centroid points (we do it by adding all centroid's accumulators together and dividing by number of them). This way we end up with new centroids.

#### Second method

In second method we will use Thrust API. Firsly, we will use `thrust::sort` to group points with same membership to be next to each other. Next, we will use `thrust::reduce_by_key` to calculate mean for each cluster and this way getting new centroids

The main part will be run in loop until threshold condition is met. Each time new kernel will be launched, as we need block synchronization between loop steps.
