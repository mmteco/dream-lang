#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>
#include "dict.h"

// FNV-1a 核心函数（为测试复制一份）
static unsigned int hash_bytes_fnv1a(const void* data, size_t len) {
    const unsigned char* bytes = (const unsigned char*)data;
    unsigned int hash = 2166136261u;
    for (size_t i = 0; i < len; i++) {
        hash ^= bytes[i];
        hash *= 16777619u;
    }
    return hash;
}

// 计算哈希分布的标准差（衡量均匀性）
double calculate_stddev(int* buckets, int num_buckets) {
    int total_items = 0;

    for (int i = 0; i < num_buckets; i++) {
        total_items += buckets[i];
    }

    double mean = (double)total_items / num_buckets;
    double variance = 0.0;

    for (int i = 0; i < num_buckets; i++) {
        double diff = buckets[i] - mean;
        variance += diff * diff;
    }

    variance /= num_buckets;
    return sqrt(variance);
}

// 测试整数哈希分布
void test_int_hash_distribution() {
    printf("=== 测试整数哈希分布 ===\n\n");

    int capacity = 16;
    int num_keys = 10000;
    int* buckets_old = (int*)calloc(capacity, sizeof(int));
    int* buckets_fnv = (int*)calloc(capacity, sizeof(int));

    // 测试连续整数
    printf("1. 连续整数 (0 到 %d):\n", num_keys - 1);
    for (int i = 0; i < num_keys; i++) {
        int hash_old = (int)(hash_bytes_fnv1a(&i, sizeof(i)) % (unsigned int)capacity);
        int hash_fnv = dict_hash_int(i, capacity);
        buckets_old[hash_old]++;
        buckets_fnv[hash_fnv]++;
    }

    printf("   MurmurHash3 分布: ");
    for (int i = 0; i < capacity; i++) {
        printf("%d ", buckets_old[i]);
    }
    printf("\n");

    printf("   FNV-1a 分布:      ");
    for (int i = 0; i < capacity; i++) {
        printf("%d ", buckets_fnv[i]);
    }
    printf("\n");

    double stddev_old = calculate_stddev(buckets_old, capacity);
    double stddev_fnv = calculate_stddev(buckets_fnv, capacity);
    printf("   MurmurHash3 标准差: %.2f\n", stddev_old);
    printf("   FNV-1a 标准差:      %.2f\n", stddev_fnv);
    printf("   (标准差越小分布越均匀)\n\n");

    // 清零桶
    memset(buckets_old, 0, capacity * sizeof(int));
    memset(buckets_fnv, 0, capacity * sizeof(int));

    // 测试随机整数
    printf("2. 随机整数:\n");
    srand(42);
    for (int i = 0; i < num_keys; i++) {
        int key = rand();
        int hash_old = (int)(hash_bytes_fnv1a(&key, sizeof(key)) % (unsigned int)capacity);
        int hash_fnv = dict_hash_int(key, capacity);
        buckets_old[hash_old]++;
        buckets_fnv[hash_fnv]++;
    }

    printf("   MurmurHash3 分布: ");
    for (int i = 0; i < capacity; i++) {
        printf("%d ", buckets_old[i]);
    }
    printf("\n");

    printf("   FNV-1a 分布:      ");
    for (int i = 0; i < capacity; i++) {
        printf("%d ", buckets_fnv[i]);
    }
    printf("\n");

    stddev_old = calculate_stddev(buckets_old, capacity);
    stddev_fnv = calculate_stddev(buckets_fnv, capacity);
    printf("   MurmurHash3 标准差: %.2f\n", stddev_old);
    printf("   FNV-1a 标准差:      %.2f\n\n", stddev_fnv);

    free(buckets_old);
    free(buckets_fnv);
}

// 测试字符串哈希分布
void test_string_hash_distribution() {
    printf("=== 测试字符串哈希分布 ===\n\n");

    int capacity = 16;
    int* buckets = (int*)calloc(capacity, sizeof(int));

    // 常见字符串
    const char* test_strings[] = {
        "hello", "world", "dream", "language", "compiler",
        "python", "javascript", "typescript", "rust", "golang",
        "hash", "table", "dictionary", "map", "set",
        "array", "list", "vector", "queue", "stack",
        "tree", "graph", "node", "edge", "vertex",
        "algorithm", "data", "structure", "search", "sort",
        "insert", "delete", "update", "select", "query",
        "key", "value", "pair", "tuple", "record",
        "function", "method", "object", "instance",
        "variable", "constant", "parameter", "argument", "return"
    };

    int num_strings = sizeof(test_strings) / sizeof(test_strings[0]);

    printf("测试 %d 个常见字符串:\n", num_strings);
    for (int i = 0; i < num_strings; i++) {
        int hash = dict_hash_string(test_strings[i], capacity);
        buckets[hash]++;
    }

    printf("分布: ");
    for (int i = 0; i < capacity; i++) {
        printf("%d ", buckets[i]);
    }
    printf("\n");

    double stddev = calculate_stddev(buckets, capacity);
    printf("标准差: %.2f\n", stddev);
    printf("(理想值约为 %.2f, 即 sqrt(n/m) 其中 n=%d, m=%d)\n\n",
           sqrt((double)num_strings / capacity), num_strings, capacity);

    free(buckets);
}

// 测试哈希碰撞
void test_hash_collisions() {
    printf("=== 测试哈希碰撞 ===\n\n");

    int capacity = 16;
    int num_tests = 1000;

    printf("插入 %d 个连续整数到容量为 %d 的哈希表:\n", num_tests, capacity);

    int* buckets = (int*)calloc(capacity, sizeof(int));
    int max_chain = 0;
    int total_chain_length = 0;

    for (int i = 0; i < num_tests; i++) {
        int hash = dict_hash_int(i, capacity);
        buckets[hash]++;
        if (buckets[hash] > max_chain) {
            max_chain = buckets[hash];
        }
    }

    for (int i = 0; i < capacity; i++) {
        total_chain_length += buckets[i];
    }

    printf("最大链长: %d\n", max_chain);
    printf("平均链长: %.2f\n", (double)total_chain_length / capacity);
    printf("负载因子: %.2f\n", (double)num_tests / capacity);

    printf("\n各桶链长分布:\n");
    for (int i = 0; i < capacity; i++) {
        printf("桶 %2d: ", i);
        for (int j = 0; j < buckets[i]; j++) {
            if (j % 10 == 0 && j > 0) printf("|");
            printf("*");
        }
        printf(" (%d)\n", buckets[i]);
    }

    free(buckets);
}

int main() {
    printf("\n");
    printf("╔════════════════════════════════════════════╗\n");
    printf("║   Dream 字典哈希算法测试                  ║\n");
    printf("╚════════════════════════════════════════════╝\n");
    printf("\n");

    test_int_hash_distribution();
    test_string_hash_distribution();
    test_hash_collisions();

    printf("\n测试完成！\n\n");

    return 0;
}
