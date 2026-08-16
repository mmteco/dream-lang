CC = clang
CFLAGS = -Wall -Wextra -g -O2 -std=c11
LDFLAGS =

COMMON_OBJS = memory.o dynarray.o utf8.o dict.o

# 目标
all: test

# 测试程序
test_memory: $(COMMON_OBJS) test_memory.o
	$(CC) $(LDFLAGS) -o $@ $^ -pthread

test_union: $(COMMON_OBJS) union.o test_union.o
	$(CC) $(LDFLAGS) -o $@ $^ -pthread

test_string: $(COMMON_OBJS) str.o test_string_ops.o
	$(CC) $(LDFLAGS) -o $@ $^ -pthread

test_runtime_safety: $(COMMON_OBJS) str.o bytes.o file.o tuple.o union.o test_runtime_safety.o
	$(CC) $(LDFLAGS) -o $@ $^ -pthread

# 对象文件
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# 运行测试
test: test_memory test_union test_string test_runtime_safety
	./test_memory
	./test_union
	./test_string
	./test_runtime_safety

# 清理
clean:
	rm -f *.o test_memory test_union test_string test_runtime_safety

# 依赖关系
memory.o: memory.c memory.h union.h utf8.h
dynarray.o: dynarray.c dynarray.h memory.h
utf8.o: utf8.c utf8.h
runtime.o: runtime.c
union.o: union.c union.h memory.h
test_memory.o: test_memory.c memory.h dynarray.h
test_union.o: test_union.c union.h
str.o: str.c str.h dynarray.h memory.h utf8.h
bytes.o: bytes.c bytes.h dynarray.h
file.o: file.c file.h dynarray.h
dict.o: dict.c dict.h dynarray.h
tuple.o: tuple.c tuple.h dict.h dynarray.h
test_string_ops.o: test_string_ops.c str.h
test_runtime_safety.o: test_runtime_safety.c bytes.h dict.h file.h str.h tuple.h union.h

.PHONY: all test clean
