# 通用扁平哈希索引表（连续 list[int] 存储，零堆碎片，自适应容量）

from lex import (
    module_env_file_at,
    module_candidate_files
)

def hash_int_list_get(values: list[int], index: int) -> int:
    if index < 0 or index >= len(values):
        return 0
    return values[index]

def hash_int_list_set(values: list[int], index: int, value: int):
    while len(values) <= index:
        append(values, 0)
    values[index] = value

# 定义文件（def_file）是否对调用点（caller_offset）可见：按 per-module 规则快速判定
def hash_file_visible(caller_offset: int, source: str, name_start: int, name_end: int, def_file: int) -> bool:
    let caller_file = module_env_file_at(caller_offset)
    if caller_file < 0:
        caller_file = 0
    if caller_file == def_file:
        return true
    let candidate_files: list[int] = []
    if module_candidate_files(caller_offset, source, name_start, name_end, candidate_files) != 0:
        return false
    let candidate_index = 0
    let candidate_count = len(candidate_files)
    while candidate_index < candidate_count:
        if hash_int_list_get(candidate_files, candidate_index) == def_file:
            return true
        candidate_index = candidate_index + 1
    return false

def hir_file_visible(caller_offset: int, source: str, name_start: int, name_end: int, def_file: int) -> bool:
    return hash_file_visible(caller_offset, source, name_start, name_end, def_file)

def hash_index_calc_mask(item_count: int) -> int:
    let cap = 64
    while cap < item_count * 2 and cap < 65536:
        cap = cap * 2
    return cap - 1

struct HashIndex:
    heads: list[int]
    next: list[int]
    hashes: list[int]
    mask: int

    def find(self, source: str, source_start: int, source_end: int,
        starts: list[int], ends: list[int], files: list[int], caller_offset: int) -> int:
        let name_len = source_end - source_start
        let name_hash = __c_fnv_hash_range(source, source_start, source_end)
        let bucket = name_hash & self.mask
        if bucket < 0:
            bucket = 0 - bucket
        let item_index = hash_int_list_get(self.heads, bucket)
        let caller_file = module_env_file_at(caller_offset)
        if caller_file < 0:
            caller_file = 0
        while item_index >= 0:
            if hash_int_list_get(self.hashes, item_index) == name_hash:
                let s_start = hash_int_list_get(starts, item_index)
                let s_end = hash_int_list_get(ends, item_index)
                if s_end - s_start == name_len:
                    if source[source_start:source_end] == source[s_start:s_end]:
                        let def_file = 0
                        if item_index < len(files):
                            def_file = hash_int_list_get(files, item_index)
                        if caller_file == def_file or hash_file_visible(caller_offset, source, source_start, source_end, def_file):
                            return item_index
            item_index = hash_int_list_get(self.next, item_index)
        return -1

    def find_func(self, source: str, source_start: int, source_end: int,
        starts: list[int], ends: list[int], files: list[int], receiver_flags: list[int], caller_offset: int) -> int:
        let name_len = source_end - source_start
        let name_hash = __c_fnv_hash_range(source, source_start, source_end)
        let bucket = name_hash & self.mask
        if bucket < 0:
            bucket = 0 - bucket
        let item_index = hash_int_list_get(self.heads, bucket)
        let caller_file = module_env_file_at(caller_offset)
        if caller_file < 0:
            caller_file = 0
        while item_index >= 0:
            if hash_int_list_get(self.hashes, item_index) == name_hash:
                let s_start = hash_int_list_get(starts, item_index)
                let s_end = hash_int_list_get(ends, item_index)
                if s_end - s_start == name_len:
                    if source[source_start:source_end] == source[s_start:s_end]:
                        let def_file = 0
                        if item_index < len(files):
                            def_file = hash_int_list_get(files, item_index)
                        if caller_file == def_file or hash_file_visible(caller_offset, source, source_start, source_end, def_file):
                            if item_index >= len(receiver_flags) or hash_int_list_get(receiver_flags, item_index) == 0:
                                return item_index
            item_index = hash_int_list_get(self.next, item_index)
        return -1

    def find_pair(self, source: str, source_start: int, source_end: int,
        pairs: list[int], files: list[int], caller_offset: int) -> int:
        let name_len = source_end - source_start
        let name_hash = __c_fnv_hash_range(source, source_start, source_end)
        let bucket = name_hash & self.mask
        if bucket < 0:
            bucket = 0 - bucket
        let item_index = hash_int_list_get(self.heads, bucket)
        let caller_file = module_env_file_at(caller_offset)
        if caller_file < 0:
            caller_file = 0
        while item_index >= 0:
            if hash_int_list_get(self.hashes, item_index) == name_hash:
                let s_start = hash_int_list_get(pairs, item_index * 2)
                let s_end = hash_int_list_get(pairs, item_index * 2 + 1)
                if s_end - s_start == name_len:
                    if source[source_start:source_end] == source[s_start:s_end]:
                        let def_file = 0
                        if item_index < len(files):
                            def_file = hash_int_list_get(files, item_index)
                        if caller_file == def_file or hash_file_visible(caller_offset, source, source_start, source_end, def_file):
                            return item_index
            item_index = hash_int_list_get(self.next, item_index)
        return -1

def hash_index_build(source: str, starts: list[int], ends: list[int]) -> HashIndex:
    let count = len(starts)
    let mask = hash_index_calc_mask(count)
    let cap = mask + 1
    let heads: list[int] = []
    let i = 0
    while i < cap:
        append(heads, -1)
        i = i + 1
    let next: list[int] = []
    let hashes: list[int] = []
    let item_idx = 0
    while item_idx < count:
        let s_start = hash_int_list_get(starts, item_idx)
        let s_end = hash_int_list_get(ends, item_idx)
        let hash = __c_fnv_hash_range(source, s_start, s_end)
        append(hashes, hash)
        let bucket = hash & mask
        if bucket < 0:
            bucket = 0 - bucket
        append(next, hash_int_list_get(heads, bucket))
        hash_int_list_set(heads, bucket, item_idx)
        item_idx = item_idx + 1
    return HashIndex{
        heads: heads,
        next: next,
        hashes: hashes,
        mask: mask
    }

def hash_index_build_pairs(source: str, pairs: list[int]) -> HashIndex:
    let count = len(pairs) / 2
    let mask = hash_index_calc_mask(count)
    let cap = mask + 1
    let heads: list[int] = []
    let i = 0
    while i < cap:
        append(heads, -1)
        i = i + 1
    let next: list[int] = []
    let hashes: list[int] = []
    let item_idx = 0
    while item_idx < count:
        let s_start = hash_int_list_get(pairs, item_idx * 2)
        let s_end = hash_int_list_get(pairs, item_idx * 2 + 1)
        let hash = __c_fnv_hash_range(source, s_start, s_end)
        append(hashes, hash)
        let bucket = hash & mask
        if bucket < 0:
            bucket = 0 - bucket
        append(next, hash_int_list_get(heads, bucket))
        hash_int_list_set(heads, bucket, item_idx)
        item_idx = item_idx + 1
    return HashIndex{
        heads: heads,
        next: next,
        hashes: hashes,
        mask: mask
    }
