#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdbool.h>
#include "str.h"
#include "utf8.h"

// 声明 runtime.c 中的字符串函数
int string_length(const char* str);
uint32_t string_char_at(const char* str, int index);
char* string_concat(const char* s1, const char* s2);
char* string_substring(const char* str, int start, int end);
int string_find(const char* str, const char* sub);
int string_compare(const char* s1, const char* s2);
char* string_upper(const char* str);
char* string_lower(const char* str);
char* string_strip(const char* str);
bool string_starts_with(const char* str, const char* prefix);
bool string_ends_with(const char* str, const char* suffix);
char* string_replace(const char* str, const char* old, const char* new_str);
bool string_is_digit(char c);
bool string_is_alpha(char c);
bool string_is_whitespace(char c);

void test_string_length() {
    printf("Testing string_length...\n");
    assert(string_length("") == 0);
    assert(string_length("hello") == 5);
    assert(string_length("Hello, World!") == 13);
    printf("  ✓ All length tests passed\n");
}

void test_string_char_at() {
    printf("Testing string_char_at...\n");
    const char* s = "Hello";
    assert(string_char_at(s, 0) == 'H');
    assert(string_char_at(s, 4) == 'o');

    const char* unicode = "A你𐀀";
    assert(string_length(unicode) == 3);
    assert(string_char_at(unicode, 0) == 'A');
    assert(string_char_at(unicode, 1) == 0x4F60);
    assert(string_char_at(unicode, 2) == 0x10000);
    assert(string_char_at(unicode, 3) == 0);

    char long_unicode[121];
    for (int index = 0; index < 40; index++) {
        long_unicode[index * 3] = (char)0xE4;
        long_unicode[index * 3 + 1] = (char)0xBD;
        long_unicode[index * 3 + 2] = (char)0xA0;
    }
    long_unicode[120] = '\0';
    assert(utf8_rune_count(long_unicode) == 40);
    assert(utf8_byte_offset(long_unicode, 20) == 60);
    assert(utf8_byte_offset(long_unicode, 40) == 120);
    assert(utf8_rune_count_prefix(long_unicode, 60) == 20);
    assert(string_char_at(long_unicode, 20) == 0x4F60);
    utf8_cache_forget(long_unicode);
    assert(utf8_rune_count(long_unicode) == 40);
    assert(utf8_byte_offset(long_unicode, 20) == 60);

    printf("  ✓ All char_at tests passed\n");
}

void test_string_concat() {
    printf("Testing string_concat...\n");
    char* result = string_concat("Hello", " World");
    assert(strcmp(result, "Hello World") == 0);
    free(result);

    result = string_concat("", "test");
    assert(strcmp(result, "test") == 0);
    free(result);

    result = string_concat("test", "");
    assert(strcmp(result, "test") == 0);
    free(result);
    printf("  ✓ All concat tests passed\n");
}

void test_string_substring() {
    printf("Testing string_substring...\n");
    const char* s = "Hello World";

    char* result = string_substring(s, 0, 5);
    assert(strcmp(result, "Hello") == 0);
    free(result);

    result = string_substring(s, 6, 11);
    assert(strcmp(result, "World") == 0);
    free(result);

    result = string_substring(s, 0, 0);
    assert(strcmp(result, "") == 0);
    free(result);

    result = string_substring("你好，Dream", 0, 2);
    assert(strcmp(result, "你好") == 0);
    free(result);
    printf("  ✓ All substring tests passed\n");
}

void test_string_find() {
    printf("Testing string_find...\n");
    assert(string_find("Hello World", "World") == 6);
    assert(string_find("Hello World", "Hello") == 0);
    assert(string_find("Hello World", "xyz") == -1);
    assert(string_find("", "test") == -1);
    assert(string_find("你好，世界", "世界") == 3);
    printf("  ✓ All find tests passed\n");
}

void test_string_compare() {
    printf("Testing string_compare...\n");
    assert(string_compare("abc", "abc") == 0);
    assert(string_compare("abc", "xyz") < 0);
    assert(string_compare("xyz", "abc") > 0);
    printf("  ✓ All compare tests passed\n");
}

void test_string_upper_lower() {
    printf("Testing string_upper and string_lower...\n");

    char* result = string_upper("hello");
    assert(strcmp(result, "HELLO") == 0);
    free(result);

    result = string_upper("Hello World!");
    assert(strcmp(result, "HELLO WORLD!") == 0);
    free(result);

    result = string_lower("HELLO");
    assert(strcmp(result, "hello") == 0);
    free(result);

    result = string_lower("Hello World!");
    assert(strcmp(result, "hello world!") == 0);
    free(result);

    result = string_upper("Καλημέρα Привет");
    assert(strcmp(result, "ΚΑΛΗΜΈΡΑ ПРИВЕТ") == 0);
    free(result);

    result = string_lower("ΚΑΛΗΜΈΡΑ ПРИВЕТ");
    assert(strcmp(result, "καλημέρα привет") == 0);
    free(result);
    printf("  ✓ All upper/lower tests passed\n");
}

void test_string_strip() {
    printf("Testing string_strip...\n");

    char* result = string_strip("  hello  ");
    assert(strcmp(result, "hello") == 0);
    free(result);

    result = string_strip("hello");
    assert(strcmp(result, "hello") == 0);
    free(result);

    result = string_strip("   ");
    assert(strcmp(result, "") == 0);
    free(result);

    result = string_strip("\t\nhello\n\t");
    assert(strcmp(result, "hello") == 0);
    free(result);
    printf("  ✓ All strip tests passed\n");
}

void test_string_starts_ends_with() {
    printf("Testing string_starts_with and string_ends_with...\n");

    assert(string_starts_with("Hello World", "Hello"));
    assert(!string_starts_with("Hello World", "World"));
    assert(!string_starts_with("Hello", "Hello World"));

    assert(string_ends_with("Hello World", "World"));
    assert(!string_ends_with("Hello World", "Hello"));
    assert(!string_ends_with("World", "Hello World"));
    printf("  ✓ All starts_with/ends_with tests passed\n");
}

void test_string_replace() {
    printf("Testing string_replace...\n");

    char* result = string_replace("Hello World", "World", "Dream");
    assert(strcmp(result, "Hello Dream") == 0);
    free(result);

    result = string_replace("foo bar foo", "foo", "baz");
    assert(strcmp(result, "baz bar baz") == 0);
    free(result);

    result = string_replace("hello", "xyz", "abc");
    assert(strcmp(result, "hello") == 0);
    free(result);

    result = string_replace("hello", "", "x");
    assert(strcmp(result, "hello") == 0);
    free(result);

    result = string_replace("one two", "two", "three");
    assert(strcmp(result, "one three") == 0);
    free(result);
    printf("  ✓ All replace tests passed\n");
}

void test_char_classification() {
    printf("Testing character classification...\n");

    assert(string_is_digit('0'));
    assert(string_is_digit('5'));
    assert(string_is_digit('9'));
    assert(!string_is_digit('a'));

    assert(string_is_alpha('a'));
    assert(string_is_alpha('Z'));
    assert(!string_is_alpha('0'));
    assert(!string_is_alpha(' '));

    assert(string_is_whitespace(' '));
    assert(string_is_whitespace('\t'));
    assert(string_is_whitespace('\n'));
    assert(!string_is_whitespace('a'));
    printf("  ✓ All character classification tests passed\n");
}

void demonstrate_usage() {
    printf("\n=== Demonstration: Lexer-like Usage ===\n");

    const char* source = "  let x = 42  ";
    printf("Source: \"%s\"\n", source);

    // Strip whitespace
    char* trimmed = string_strip(source);
    printf("After strip: \"%s\"\n", trimmed);

    // Find keywords
    if (string_starts_with(trimmed, "let")) {
        printf("Found keyword: let\n");
    }

    // Extract identifier
    char* identifier = string_substring(trimmed, 4, 5);
    printf("Identifier: \"%s\"\n", identifier);

    // Check if character is digit
    if (string_find(trimmed, "42") != -1) {
        printf("Found number literal: 42\n");
        char first_digit = string_char_at(trimmed, string_find(trimmed, "42"));
    printf("First digit is: %c, is_digit=%s\n", first_digit,
           string_is_digit(first_digit) ? "true" : "false");
    }

    free(trimmed);
    free(identifier);
}

int main() {
    printf("================================\n");
    printf("Dream String Operations Tests\n");
    printf("================================\n\n");

    test_string_length();
    test_string_char_at();
    test_string_concat();
    test_string_substring();
    test_string_find();
    test_string_compare();
    test_string_upper_lower();
    test_string_strip();
    test_string_starts_ends_with();
    test_string_replace();
    test_char_classification();

    demonstrate_usage();

    printf("\n================================\n");
    printf("✅ All tests passed!\n");
    printf("================================\n");

    return 0;
}
