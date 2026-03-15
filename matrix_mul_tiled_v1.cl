#define TILE_SIZE 16

__kernel void matrix_mul_tiled(
    __global float* A,
    __global float* B,
    __global float* C,
    int M, int N, int K
) {
    // Thread and tile indices
    int tx = get_local_id(0);
    int ty = get_local_id(1);
    int gx = get_global_id(0);
    int gy = get_global_id(1);

    // Shared memory tiles
    __local float Asub[TILE_SIZE][TILE_SIZE];
    __local float Bsub[TILE_SIZE][TILE_SIZE];

    float sum = 0.0f;

    // Loop over tiles
    for (int t = 0; t < (K + TILE_SIZE - 1) / TILE_SIZE; t++) {
        // Load data into shared memory
        int a_idx = gy * K + t * TILE_SIZE + tx;
        int b_idx = (t * TILE_SIZE + ty) * N + gx;

        Asub[ty][tx] = (gy < M && (t * TILE_SIZE + tx) < K) ? A[a_idx] : 0.0f;
        Bsub[ty][tx] = ((t * TILE_SIZE + ty) < K && gx < N) ? B[b_idx] : 0.0f;

        // Synchronize threads in workgroup
        barrier(CLK_LOCAL_MEM_FENCE);

        // Compute partial product
        for (int k = 0; k < TILE_SIZE; k++) {
            sum += Asub[ty][k] * Bsub[k][tx];
        }

        // Synchronize before loading next tile
        barrier(CLK_LOCAL_MEM_FENCE);
    }

    // Write result
    if (gy < M && gx < N) {
        C[gy * N + gx] = sum;
    }
}   
