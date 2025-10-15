#ifndef DREAM_FILE_OPS_H
#define DREAM_FILE_OPS_H

char* file_read(const char* path);
int file_write(const char* path, const char* content);
int file_exists(const char* path);
int file_append(const char* path, const char* content);
int file_delete(const char* path);

#endif
