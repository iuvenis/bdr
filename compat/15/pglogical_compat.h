#if PG_VERSION_NUM > 130000
#include "access/table.h"
// https://github.com/postgres/postgres/commit/f25968c49697db673f6cd2a07b3f7626779f1827
#define heap_open(r, l)					table_open(r, l)
#define heap_openrv(r, l)				table_openrv(r, l)
#define heap_openrv_extended(r, l, m)	table_openrv_extended(r, l, m)
#define heap_close(r, l)				table_close(r, l)
#endif
