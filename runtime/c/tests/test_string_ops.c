#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdbool.h>
#include "str.h"
#include "utf8.h"

// 声明 str.c 中的字符串函数
int __c_str_len(const char* str);
uint32_t __c_str_char_at(const char* str, int index);
char* __c_str_concat(const char* s1, const char* s2);
char* __c_str_substring(const char* str, int start, int end);
int __c_str_find(const char* str, const char* sub);
int __c_str_compare(const char* s1, const char* s2);
char* __c_str_upper(const char* str);
char* __c_str_lower(const char* str);
char* __c_str_strip(const char* str);
bool __c_str_starts_with(const char* str, const char* prefix);
bool __c_str_ends_with(const char* str, const char* suffix);
char* __c_str_replace(const char* str, const char* old, const char* new_str);
bool __c_str_is_digit(char c);
bool __c_str_is_alpha(char c);
bool __c_str_is_whitespace(char c);

void test_string_length() {
    printf("Testing string_length...\n");
    assert(__c_str_len("") == 0);
    assert(__c_str_len("hello") == 5);
    assert(__c_str_len("Hello, World!") == 13);
    printf("  ✓ All length tests passed\n");
}

void test_string_char_at() {
    printf("Testing string_char_at...\n");
    const char* s = "Hello";
    assert(__c_str_char_at(s, 0) == 'H');
    assert(__c_str_char_at(s, 4) == 'o');

    const char* unicode = "A你𐀀";
    assert(__c_str_len(unicode) == 3);
    assert(__c_str_char_at(unicode, 0) == 'A');
    assert(__c_str_char_at(unicode, 1) == 0x4F60);
    assert(__c_str_char_at(unicode, 2) == 0x10000);
    assert(__c_str_char_at(unicode, 3) == 0);

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
    assert(__c_str_char_at(long_unicode, 20) == 0x4F60);
    utf8_cache_forget(long_unicode);
    assert(utf8_rune_count(long_unicode) == 40);
    assert(utf8_byte_offset(long_unicode, 20) == 60);

    printf("  ✓ All char_at tests passed\n");
}

void test_string_concat() {
    printf("Testing string_concat...\n");
    char* result = __c_str_concat("Hello", " World");
    assert(strcmp(result, "Hello World") == 0);
    free(result);

    result = __c_str_concat("", "test");
    assert(strcmp(result, "test") == 0);
    free(result);

    result = __c_str_concat("test", "");
    assert(strcmp(result, "test") == 0);
    free(result);
    printf("  ✓ All concat tests passed\n");
}

void test_string_substring() {
    printf("Testing string_substring...\n");
    const char* s = "Hello World";

    char* result = __c_str_substring(s, 0, 5);
    assert(strcmp(result, "Hello") == 0);
    free(result);

    result = __c_str_substring(s, 6, 11);
    assert(strcmp(result, "World") == 0);
    free(result);

    result = __c_str_substring(s, 0, 0);
    assert(strcmp(result, "") == 0);
    free(result);

    result = __c_str_substring("你好，Dream", 0, 2);
    assert(strcmp(result, "你好") == 0);
    free(result);
    printf("  ✓ All substring tests passed\n");
}

void test_string_find() {
    printf("Testing string_find...\n");
    assert(__c_str_find("Hello World", "World") == 6);
    assert(__c_str_find("Hello World", "Hello") == 0);
    assert(__c_str_find("Hello World", "xyz") == -1);
    assert(__c_str_find("", "test") == -1);
    assert(__c_str_find("你好，世界", "世界") == 3);
    printf("  ✓ All find tests passed\n");
}

void test_string_compare() {
    printf("Testing string_compare...\n");
    assert(__c_str_compare("abc", "abc") == 0);
    assert(__c_str_compare("abc", "xyz") < 0);
    assert(__c_str_compare("xyz", "abc") > 0);
    printf("  ✓ All compare tests passed\n");
}

void test_string_upper_lower() {
    printf("Testing string_upper and string_lower...\n");

    char* result = __c_str_upper("hello");
    assert(strcmp(result, "HELLO") == 0);
    free(result);

    result = __c_str_upper("Hello World!");
    assert(strcmp(result, "HELLO WORLD!") == 0);
    free(result);

    result = __c_str_lower("HELLO");
    assert(strcmp(result, "hello") == 0);
    free(result);

    result = __c_str_lower("Hello World!");
    assert(strcmp(result, "hello world!") == 0);
    free(result);

    result = __c_str_upper("Καλημέρα Привет");
    assert(strcmp(result, "ΚΑΛΗΜΈΡΑ ПРИВЕТ") == 0);
    free(result);

    result = __c_str_lower("ΚΑΛΗΜΈΡΑ ПРИВЕТ");
    assert(strcmp(result, "καλημέρα привет") == 0);
    free(result);
    printf("  ✓ All upper/lower tests passed\n");
}

void test_string_strip() {
    printf("Testing string_strip...\n");

    char* result = __c_str_strip("  hello  ");
    assert(strcmp(result, "hello") == 0);
    free(result);

    result = __c_str_strip("hello");
    assert(strcmp(result, "hello") == 0);
    free(result);

    result = __c_str_strip("   ");
    assert(strcmp(result, "") == 0);
    free(result);

    result = __c_str_strip("\t\nhello\n\t");
    assert(strcmp(result, "hello") == 0);
    free(result);
    printf("  ✓ All strip tests passed\n");
}

void test_string_starts_ends_with() {
    printf("Testing string_starts_with and string_ends_with...\n");

    assert(__c_str_starts_with("Hello World", "Hello"));
    assert(!__c_str_starts_with("Hello World", "World"));
    assert(!__c_str_starts_with("Hello", "Hello World"));

    assert(__c_str_ends_with("Hello World", "World"));
    assert(!__c_str_ends_with("Hello World", "Hello"));
    assert(!__c_str_ends_with("World", "Hello World"));
    printf("  ✓ All starts_with/ends_with tests passed\n");
}

void test_string_replace() {
    printf("Testing string_replace...\n");

    char* result = __c_str_replace("Hello World", "World", "Dream");
    assert(strcmp(result, "Hello Dream") == 0);
    free(result);

    result = __c_str_replace("foo bar foo", "foo", "baz");
    assert(strcmp(result, "baz bar baz") == 0);
    free(result);

    result = __c_str_replace("hello", "xyz", "abc");
    assert(strcmp(result, "hello") == 0);
    free(result);

    result = __c_str_replace("hello", "", "x");
    assert(strcmp(result, "hello") == 0);
    free(result);

    result = __c_str_replace("one two", "two", "three");
    assert(strcmp(result, "one three") == 0);
    free(result);
    printf("  ✓ All replace tests passed\n");
}

void test_char_classification() {
    printf("Testing character classification...\n");

    assert(__c_str_is_digit('0'));
    assert(__c_str_is_digit('5'));
    assert(__c_str_is_digit('9'));
    assert(!__c_str_is_digit('a'));

    assert(__c_str_is_alpha('a'));
    assert(__c_str_is_alpha('Z'));
    assert(!__c_str_is_alpha('0'));
    assert(!__c_str_is_alpha(' '));

    assert(__c_str_is_whitespace(' '));
    assert(__c_str_is_whitespace('\t'));
    assert(__c_str_is_whitespace('\n'));
    assert(!__c_str_is_whitespace('a'));
    printf("  ✓ All character classification tests passed\n");
}

void demonstrate_usage() {
    printf("\n=== Demonstration: Lexer-like Usage ===\n");

    const char* source = "  let x = 42  ";
    printf("Source: \"%s\"\n", source);

    // Strip whitespace
    char* trimmed = __c_str_strip(source);
    printf("After strip: \"%s\"\n", trimmed);

    // Find keywords
    if (__c_str_starts_with(trimmed, "let")) {
        printf("Found keyword: let\n");
    }

    // Extract identifier
    char* identifier = __c_str_substring(trimmed, 4, 5);
    printf("Identifier: \"%s\"\n", identifier);

    // Check if character is digit
    if (__c_str_find(trimmed, "42") != -1) {
        printf("Found number literal: 42\n");
        char first_digit = __c_str_char_at(trimmed, __c_str_find(trimmed, "42"));
    printf("First digit is: %c, is_digit=%s\n", first_digit,
           __c_str_is_digit(first_digit) ? "true" : "false");
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
