__kernel void matrix_mul(
    const int M,           // Number of rows in A and C
    const int N,           // Number of columns in B and C
    const int K,           // Number of columns in A and rows in B
    __global const float* A,
    __global const float* B,
    __global float* C)
{
    // Get the global IDs for row and column
    int row = get_global_id(0); // Index in range [0, M-1]
    int col = get_global_id(1); // Index in range [0, N-1]

    // Check bounds to handle matrices that aren't multiples of work-group size
    if (row < M && col < N) {
        float acc = 0.0f;
        for (int i = 0; i < K; i++) {
            // A[row][i] * B[i][col]
            acc += A[row * K + i] * B[i * N + col];
        }
        // Store the result in C[row][col]
        C[row * N + col] = acc;
    }
}
