CC = clang
CFLAGS = -Wall -Wextra -g -O2 -std=c11
LDFLAGS =

SRCS = memory.c dynarray.c runtime.c union.c utf8.c bytes.c utf8_wrapper.c bytes_wrapper.c
OBJS = $(SRCS:.c=.o)
TEST_SRCS = test_memory.c
TEST_OBJS = $(TEST_SRCS:.c=.o)

# 目标
all: test_memory test_union

# 测试程序
test_memory: memory.o dynarray.o test_memory.o
	$(CC) $(LDFLAGS) -o $@ $^

test_union: union.o memory.o test_union.o
	$(CC) $(LDFLAGS) -o $@ $^

# 对象文件
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# 运行测试
test: test_memory test_union
	./test_memory
	./test_union

# 清理
clean:
	rm -f *.o test_memory test_union

# 依赖关系
memory.o: memory.c memory.h
dynarray.o: dynarray.c dynarray.h memory.h
runtime.o: runtime.c
union.o: union.c union.h memory.h
test_memory.o: test_memory.c memory.h dynarray.h
test_union.o: test_union.c union.h

.PHONY: all test clean
