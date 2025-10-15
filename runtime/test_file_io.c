#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

char* file_read(const char* path);
int file_write(const char* path, const char* content);
int file_exists(const char* path);
int file_append(const char* path, const char* content);
int file_delete(const char* path);

void test_file_write_read() {
    printf("Testing file_write and file_read...\n");

    const char* test_path = "/tmp/dream_test_file.txt";
    const char* test_content = "Hello, Dream File I/O!";

    int write_result = file_write(test_path, test_content);
    assert(write_result == 1);

    char* read_content = file_read(test_path);
    assert(read_content != NULL);
    assert(strcmp(read_content, test_content) == 0);

    free(read_content);
    file_delete(test_path);

    printf("  ✓ All write/read tests passed\n");
}

void test_file_exists() {
    printf("Testing file_exists...\n");

    const char* test_path = "/tmp/dream_test_exists.txt";

    assert(file_exists(test_path) == 0);

    file_write(test_path, "test");
    assert(file_exists(test_path) == 1);

    file_delete(test_path);
    assert(file_exists(test_path) == 0);

    printf("  ✓ All exists tests passed\n");
}

void test_file_append() {
    printf("Testing file_append...\n");

    const char* test_path = "/tmp/dream_test_append.txt";

    file_write(test_path, "Line 1\n");
    file_append(test_path, "Line 2\n");
    file_append(test_path, "Line 3\n");

    char* content = file_read(test_path);
    assert(content != NULL);
    assert(strcmp(content, "Line 1\nLine 2\nLine 3\n") == 0);

    free(content);
    file_delete(test_path);

    printf("  ✓ All append tests passed\n");
}

void test_file_delete() {
    printf("Testing file_delete...\n");

    const char* test_path = "/tmp/dream_test_delete.txt";

    file_write(test_path, "to be deleted");
    assert(file_exists(test_path) == 1);

    int delete_result = file_delete(test_path);
    assert(delete_result == 1);
    assert(file_exists(test_path) == 0);

    int delete_nonexistent = file_delete(test_path);
    assert(delete_nonexistent == 0);

    printf("  ✓ All delete tests passed\n");
}

void test_error_handling() {
    printf("Testing error handling...\n");

    char* nonexistent = file_read("/nonexistent/path/file.txt");
    assert(nonexistent == NULL);

    int write_result = file_write("/nonexistent/path/file.txt", "test");
    assert(write_result == 0);

    printf("  ✓ All error handling tests passed\n");
}

void test_empty_file() {
    printf("Testing empty file...\n");

    const char* test_path = "/tmp/dream_test_empty.txt";

    file_write(test_path, "");
    assert(file_exists(test_path) == 1);

    char* content = file_read(test_path);
    assert(content != NULL);
    assert(strcmp(content, "") == 0);

    free(content);
    file_delete(test_path);

    printf("  ✓ All empty file tests passed\n");
}

void test_large_file() {
    printf("Testing large file...\n");

    const char* test_path = "/tmp/dream_test_large.txt";

    char large_content[10000];
    for (int i = 0; i < 9999; i++) {
        large_content[i] = 'A' + (i % 26);
    }
    large_content[9999] = '\0';

    file_write(test_path, large_content);

    char* read_content = file_read(test_path);
    assert(read_content != NULL);
    assert(strcmp(read_content, large_content) == 0);

    free(read_content);
    file_delete(test_path);

    printf("  ✓ All large file tests passed\n");
}

void demonstrate_usage() {
    printf("\n=== Demonstration: Compiler File I/O Usage ===\n");

    const char* source_path = "/tmp/dream_example_source.dm";
    const char* output_path = "/tmp/dream_example_output.ll";

    const char* dream_source =
        "def add(a: int, b: int) -> int:\n"
        "    return a + b\n"
        "\n"
        "print(add(2, 3))\n";

    printf("Writing Dream source code to file...\n");
    file_write(source_path, dream_source);

    printf("Reading source file...\n");
    char* source = file_read(source_path);
    printf("Source:\n%s\n", source);

    const char* llvm_ir =
        "; Generated LLVM IR\n"
        "define i32 @add(i32 %a, i32 %b) {\n"
        "  %result = add i32 %a, %b\n"
        "  ret i32 %result\n"
        "}\n";

    printf("Writing generated LLVM IR...\n");
    file_write(output_path, llvm_ir);

    printf("Verifying output file exists...\n");
    if (file_exists(output_path)) {
        printf("Output file created successfully!\n");
    }

    free(source);
    file_delete(source_path);
    file_delete(output_path);
}

int main() {
    printf("================================\n");
    printf("Dream File I/O Tests\n");
    printf("================================\n\n");

    test_file_write_read();
    test_file_exists();
    test_file_append();
    test_file_delete();
    test_error_handling();
    test_empty_file();
    test_large_file();

    demonstrate_usage();

    printf("\n================================\n");
    printf("✅ All tests passed!\n");
    printf("================================\n");

    return 0;
}
