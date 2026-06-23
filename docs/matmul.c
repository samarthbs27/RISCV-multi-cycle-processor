/* 3x3 integer matrix multiply — RV32IM mul instruction demonstration.
   _start must be first so the processor (PC=0 at reset) enters the right function. */

static void __attribute__((noinline))
matmul3x3(int C[3][3], const int A[3][3], const int B[3][3]);

int __attribute__((section(".text._start"))) _start() {
    int A[3][3] = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}};
    int B[3][3] = {{9, 8, 7}, {6, 5, 4}, {3, 2, 1}};
    int C[3][3];

    matmul3x3(C, A, B);

    /* Store result at address 0x2C0 (word 176 via a[9:2]), above instruction region */
    volatile int *out = (volatile int *)0x2C0;
    for (int i = 0; i < 9; i++)
        out[i] = ((int *)C)[i];

    while (1);
    return 0;
}

static void __attribute__((noinline))
matmul3x3(int C[3][3], const int A[3][3], const int B[3][3]) {
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++) {
            int s = 0;
            for (int k = 0; k < 3; k++)
                s += A[i][k] * B[k][j];
            C[i][j] = s;
        }
}
