CC = clang
CFLAGS = -Wall -Wextra -g -O2 -std=c11
LDFLAGS =
INCLUDES = -Icore -Iwrappers
CURL_CFLAGS = $(shell curl-config --cflags 2>/dev/null)
CURL_LIBS = $(shell curl-config --libs 2>/dev/null || echo -lcurl)

CORE_OBJS = core/memory.o core/dynarray.o core/utf8.o core/dict.o
WRAPPER_OBJS =

all: test

test_memory: $(CORE_OBJS) tests/test_memory.o
	$(CC) $(LDFLAGS) -o $@ $^ -pthread

test_union: $(CORE_OBJS) core/union.o tests/test_union.o
	$(CC) $(LDFLAGS) -o $@ $^ -pthread

test_string: $(CORE_OBJS) core/str.o wrappers/str.o tests/test_string_ops.o
	$(CC) $(LDFLAGS) -o $@ $^ -pthread

test_runtime_safety: $(CORE_OBJS) core/str.o core/bytes.o core/tuple.o core/union.o core/value.o wrappers/str.o wrappers/bytes.o wrappers/file.o wrappers/net.o wrappers/http.o tests/test_runtime_safety.o
	$(CC) $(LDFLAGS) -o $@ $^ -pthread $(CURL_LIBS)

core/%.o: core/%.c
	$(CC) $(CFLAGS) $(CURL_CFLAGS) $(INCLUDES) -c $< -o $@

wrappers/%.o: wrappers/%.c
	$(CC) $(CFLAGS) $(CURL_CFLAGS) $(INCLUDES) -c $< -o $@

tests/%.o: tests/%.c
	$(CC) $(CFLAGS) $(CURL_CFLAGS) $(INCLUDES) -c $< -o $@

test: test_memory test_union test_string test_runtime_safety
	./test_memory
	./test_union
	./test_string
	./test_runtime_safety

clean:
	rm -f core/*.o wrappers/*.o tests/*.o test_memory test_union test_string test_runtime_safety

core/memory.o: core/memory.c core/memory.h core/union.h core/utf8.h
core/dynarray.o: core/dynarray.c core/dynarray.h core/memory.h
core/utf8.o: core/utf8.c core/utf8.h
core/union.o: core/union.c core/union.h core/memory.h
core/value.o: core/value.c core/value.h core/union.h core/memory.h
core/str.o: core/str.c core/str.h core/dynarray.h core/memory.h core/utf8.h
core/bytes.o: core/bytes.c core/bytes.h core/dynarray.h
core/dict.o: core/dict.c core/dict.h core/dynarray.h
core/tuple.o: core/tuple.c core/tuple.h core/dict.h core/dynarray.h
wrappers/str.o: wrappers/str.c core/str.h core/utf8.h
wrappers/bytes.o: wrappers/bytes.c core/bytes.h core/memory.h core/dynarray.h
wrappers/file.o: wrappers/file.c wrappers/file.h core/dynarray.h
wrappers/net.o: wrappers/net.c wrappers/net.h core/memory.h
wrappers/http.o: wrappers/http.c wrappers/http.h core/memory.h

tests/test_memory.o: tests/test_memory.c core/memory.h core/dynarray.h
tests/test_union.o: tests/test_union.c core/union.h
tests/test_string_ops.o: tests/test_string_ops.c core/str.h
tests/test_runtime_safety.o: tests/test_runtime_safety.c core/bytes.h core/dict.h wrappers/file.h wrappers/net.h core/str.h core/tuple.h core/union.h
