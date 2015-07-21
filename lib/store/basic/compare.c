#include <stddef.h>
#include <stdio.h>
#include <string.h>

typedef struct {
  size_t  mv_size;
  void *  mv_data;
} MDB_val;

typedef struct {
  int field_len;
  int value_len;
} hash_element_t;


int compare_set_objs(const MDB_val *a, const MDB_val *b)
{
  return 1;
}

int compare_queue_objs(const MDB_val *a, const MDB_val *b)
{
  return (*(long *)a->mv_data > *(long *)b->mv_data) ? -1 :
    *(long *)a->mv_data < *(long *)b->mv_data;
}

int compare_hash_objs(const MDB_val *a, const MDB_val *b)
{
  int diff;
  ssize_t len_diff;
  unsigned int len;
  hash_element_t *hash_a = (hash_element_t *) a->mv_data;
  hash_element_t *hash_b = (hash_element_t *) b->mv_data;
  void *key_a = (void *)hash_a + sizeof(hash_element_t);
  void *key_b = (void *)hash_b + sizeof(hash_element_t);

  len = hash_a->field_len;
  len_diff = (ssize_t) hash_a->field_len - (ssize_t) hash_b->field_len;
  if (len_diff > 0) {
    len = hash_b->field_len;
    len_diff = 1;
  }

  diff = memcmp(key_a, key_b, len);
  return diff ? diff : len_diff<0 ? -1 : len_diff;
}