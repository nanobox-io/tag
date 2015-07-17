#include <stddef.h>
#include <stdio.h>

typedef struct {
  size_t  mv_size;
  void *  mv_data;
} MDB_val;


int compare_set_objs(const MDB_val *a, const MDB_val *b)
{
  return 1;
}

int compare_queue_objs(const MDB_val *a, const MDB_val *b)
{
  return (*(long *)a->mv_data < *(long *)b->mv_data) ? -1 :
    *(long *)a->mv_data > *(long *)b->mv_data;
}