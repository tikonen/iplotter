#ifndef __xcpp_dataset_xh
#define __xcpp_dataset_xh
/*
 * Plot - plot time-based data on screen and to file with interactive controls
 * Copyright (C) 2006  Jonas Berlin <xkr47@outerspace.dyndns.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 ****
 * dataset - functions for managing data sets. Usually one instance
 * represents all the data loaded from a single data file.
 */

#ifdef USE_FAM
#include <fam.h>
#endif

#include "array_find.h"
#include "array.h"








#if ARRAY_DEFAULTTYPE_NONE != ARRAY_DEFAULTTYPE_CUSTOM && ARRAY_DEFAULTTYPE_NONE != ARRAY_DEFAULTTYPE_ZERO && ARRAY_DEFAULTTYPE_NONE != ARRAY_DEFAULTTYPE_NONE && ARRAY_DEFAULTTYPE_NONE != ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#error src/dataset.xh:33: Unknown defaulttype ARRAY_DEFAULTTYPE_NONE given to template
#endif

#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
typedef my_time_t *my_time_arr_data_t;
#else
typedef my_time_t my_time_arr_data_t;
#endif

#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_time_arr_DECLARE(VAR_SUFFIX) my_time_arr_data_t *VAR_SUFFIX; my_time_t VAR_SUFFIX ## _dflt; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#else
#define my_time_arr_DECLARE(VAR_SUFFIX) my_time_arr_data_t *VAR_SUFFIX; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#endif

#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_time_arr_set_length(VAR_SUFFIX, size) my_time_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _dflt), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#else
#define my_time_arr_set_length(VAR_SUFFIX, size) my_time_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#endif

#define assert_x(must_be_true) do { if(unlikely(!(must_be_true))) { fprintf(stderr, "Assertion '%s' failed on %s:%d\n", #must_be_true, __FILE__, __LINE__); exit(1); }} while(0)

NONNULL __attribute__((noinline)) static void my_time_arr_set_length_int_alloc_more(my_time_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM
										   my_time_t *dflt,
#endif
										   int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   int baselen;
   if(oldlen > 0) {
      baselen = min(oldlen, (int)(ARRAY_MAX_INC_CHUNK / sizeof(my_time_arr_data_t)));
   } else {
      baselen = 4096 / sizeof(my_time_arr_data_t);
   }

   // round new size upwards to next multiple of baselen
   // if baselen = 512, size = 513 -> 1024
   // if baselen = 512, size = 1024 -> 1024
   // if baselen = 512, size = 1025 -> 1536
   *num_alloc = ceil_div(size, baselen);

   assert_x((oldlen == 0) == (*arr == NULL));
   //printf("realloc %p %p -> ", arr, *arr);
   *arr = realloc_c(*arr, sizeof(my_time_arr_data_t) * *num_alloc);
   //printf("%p %d req %d\n", *arr, *num_alloc, size);
   assert_x(size <= *num_alloc);
   //    printf("%d -> %d = %d\n", oldlen, *num_alloc, *num_alloc - oldlen);

#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM
   memmset(*arr + oldlen, dflt, sizeof(my_time_arr_data_t), *num_alloc - oldlen);
#elif ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_ZERO
   bzero(*arr + oldlen, sizeof(my_time_arr_data_t) * (*num_alloc - oldlen));
#endif
}


NONNULL static inline void my_time_arr_set_length_int(my_time_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
						     my_time_t *dflt,
#endif
						     int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   if(unlikely(oldlen < size)) {
      my_time_arr_set_length_int_alloc_more(arr,
#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM
					   dflt,
#endif
					   count, num_alloc, size);
   }
   if(likely(*count < size)) {
#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      int i;
      for(i=*count; i<size; ++i) {
	 (*arr)[i] = malloc(sizeof(my_time_t));
	 memcpy((*arr)[i], dflt, sizeof(my_time_t));
      }
#endif
   } else {
#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      // it's up to the user to free them
#endif
   }
   *count = size;
}

#define my_time_arr_free(VAR_SUFFIX) my_time_arr_free_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc))

// you can reuse the array after this, it just frees everything and resets counters
NONNULL static void my_time_arr_free_int(my_time_arr_data_t **arr, int *count, int *num_alloc) {
   if(!*arr) return;
   free(*arr);
   *count = 0;
   *num_alloc = 0;
   *arr = NULL;
}

#undef assert_x


#if 0
#define assert_x(must_be_true) do { if(unlikely(!(must_be_true))) { fprintf(stderr, "Assertion '%s' failed on %s:%d\n", #must_be_true, __FILE__, __LINE__); exit(1); }} while(0)
#else
#define assert_x(x)
#endif

#if 0
#define pprintf printf
#else
#define pprintf(...)
#endif

// search whole array for key.. if no match within array either 0 or
// arr_count-1 is returned (except for AFB_RIGHT_OR_MATCH_OVER, which
// might give arr_count)
#define my_time_arr_find(VAR_SUFFIX, key, behaviour) my_time_arr_find_int(VAR_SUFFIX, key, behaviour, 0, VAR_SUFFIX ## _count - 1)

// search within range.. if it goes outside either start or end is
// returned (except for AFB_RIGHT_OR_MATCH_OVER, which might give
// end+1) - the caller is responsible for making sure start, end are
// sane values
#define my_time_arr_find_within(VAR_SUFFIX, key, behaviour, start, end) my_time_arr_find_int(VAR_SUFFIX, key, behaviour, start, end)

//static int my_time_arr_iter; // for profiling
//static int my_time_arr_max;
//static int my_time_arr_min;

WARN_UNUSED_RESULT NONNULL static int my_time_arr_find_int(my_time_t *arr, my_time_t key, array_find_behaviour_t behaviour, int p_min, int p_max) {
   pprintf("ffind %ld from %ld - %ld (%d - %d) behaviour %d\n", key, arr[p_min], arr[p_max], p_min, p_max, behaviour);

   my_time_t d_min = arr[p_min];
   if(key <= d_min) {
      pprintf("  Key %ld <= %ld\n", key, d_min);
      return p_min;
   }

   my_time_t d_max = arr[p_max];
   if(key >= d_max) {
      pprintf("  Key %ld >= %ld\n", key, d_max);
      if(behaviour == AFB_RIGHT_OR_MATCH_OVER && key > d_max) {
	 return p_max + 1;
      }
      return p_max;
   }

   //my_time_arr_iter = 0;
   //my_time_arr_min = 0;
   //my_time_arr_max = 0;

   int iter = 0;

   // loop as long as there is at least one point between p_min and p_max
   while(p_min + 1 < p_max) {
      int p_est;
      if(++iter < 20) {
	 // estimate most probable point where our value should be. I
	 // subtract 2 from p_max - p_min (and add 1 later on) to
	 // avoid getting p_mid == p_min or p_mid == p_max which would
	 // give an endless loop. It also seems to decrease the number
	 // of iterations done than if done correctly :O
	 p_est = (int)((p_max - p_min - 2) * ((double)(key - d_min)) / (d_max - d_min) + p_min + 1);
      } else {
	 // algorithm potentially bad, switch to O(log N) algorithm
	 p_est = (p_max + p_min) / 2;
      }
      my_time_t d_est = arr[p_est];

      //my_time_arr_iter++;

      // if we hit the jackpot => finish, otherwise use our estimate as new min or max
      if(key == d_est) {
	 pprintf("  key %ld found at %d\n", key, p_est);
	 return p_est;
      } else if(key < d_est) {
	 //my_time_arr_min++;
	 p_max = p_est;
	 d_max = d_est;
      } else {
	 //my_time_arr_max++;
	 p_min = p_est;
	 d_min = d_est;
      }
   }

   // if we get here, d_min < key < d_max and p_min + 1 == p_max.. if not, we have a bug above

   assert_x(d_min < key);
   assert_x(key < d_max);
   assert_x(p_min + 1 == p_max);

   pprintf("  key %ld found between %ld - %ld (%d - %d)\n", key, d_min, d_max, p_min, p_max);

   return p_min + (behaviour == AFB_LEFT_OR_MATCH ? 0 : 1);
}

#undef pprintf
#undef assert_x


#if ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_CUSTOM && ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_ZERO && ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_NONE && ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#error src/dataset.xh:35: Unknown defaulttype ARRAY_DEFAULTTYPE_CUSTOM given to template
#endif

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
typedef my_data_t *my_data_arr_data_t;
#else
typedef my_data_t my_data_arr_data_t;
#endif

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_data_arr_DECLARE(VAR_SUFFIX) my_data_arr_data_t *VAR_SUFFIX; my_data_t VAR_SUFFIX ## _dflt; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#else
#define my_data_arr_DECLARE(VAR_SUFFIX) my_data_arr_data_t *VAR_SUFFIX; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#endif

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_data_arr_set_length(VAR_SUFFIX, size) my_data_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _dflt), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#else
#define my_data_arr_set_length(VAR_SUFFIX, size) my_data_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#endif

#define assert_x(must_be_true) do { if(unlikely(!(must_be_true))) { fprintf(stderr, "Assertion '%s' failed on %s:%d\n", #must_be_true, __FILE__, __LINE__); exit(1); }} while(0)

NONNULL __attribute__((noinline)) static void my_data_arr_set_length_int_alloc_more(my_data_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM
										   my_data_t *dflt,
#endif
										   int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   int baselen;
   if(oldlen > 0) {
      baselen = min(oldlen, (int)(ARRAY_MAX_INC_CHUNK / sizeof(my_data_arr_data_t)));
   } else {
      baselen = 4096 / sizeof(my_data_arr_data_t);
   }

   // round new size upwards to next multiple of baselen
   // if baselen = 512, size = 513 -> 1024
   // if baselen = 512, size = 1024 -> 1024
   // if baselen = 512, size = 1025 -> 1536
   *num_alloc = ceil_div(size, baselen);

   assert_x((oldlen == 0) == (*arr == NULL));
   //printf("realloc %p %p -> ", arr, *arr);
   *arr = realloc_c(*arr, sizeof(my_data_arr_data_t) * *num_alloc);
   //printf("%p %d req %d\n", *arr, *num_alloc, size);
   assert_x(size <= *num_alloc);
   //    printf("%d -> %d = %d\n", oldlen, *num_alloc, *num_alloc - oldlen);

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM
   memmset(*arr + oldlen, dflt, sizeof(my_data_arr_data_t), *num_alloc - oldlen);
#elif ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_ZERO
   bzero(*arr + oldlen, sizeof(my_data_arr_data_t) * (*num_alloc - oldlen));
#endif
}


NONNULL static inline void my_data_arr_set_length_int(my_data_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
						     my_data_t *dflt,
#endif
						     int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   if(unlikely(oldlen < size)) {
      my_data_arr_set_length_int_alloc_more(arr,
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM
					   dflt,
#endif
					   count, num_alloc, size);
   }
   if(likely(*count < size)) {
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      int i;
      for(i=*count; i<size; ++i) {
	 (*arr)[i] = malloc(sizeof(my_data_t));
	 memcpy((*arr)[i], dflt, sizeof(my_data_t));
      }
#endif
   } else {
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      // it's up to the user to free them
#endif
   }
   *count = size;
}

#define my_data_arr_free(VAR_SUFFIX) my_data_arr_free_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc))

// you can reuse the array after this, it just frees everything and resets counters
NONNULL static void my_data_arr_free_int(my_data_arr_data_t **arr, int *count, int *num_alloc) {
   if(!*arr) return;
   free(*arr);
   *count = 0;
   *num_alloc = 0;
   *arr = NULL;
}

#undef assert_x


/*
typedef void my_dataset_update_cb_t(my_dataset_t *dataset, void *user_data);

// used by dataset internally to store listeners
typedef struct {
      my_dataset_update_cb_t *cb;
      void *user_data;
} my_dataset_update_listener_t;


#if ARRAY_DEFAULTTYPE_NONE != ARRAY_DEFAULTTYPE_CUSTOM && ARRAY_DEFAULTTYPE_NONE != ARRAY_DEFAULTTYPE_ZERO && ARRAY_DEFAULTTYPE_NONE != ARRAY_DEFAULTTYPE_NONE && ARRAY_DEFAULTTYPE_NONE != ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#error src/dataset.xh:46: Unknown defaulttype ARRAY_DEFAULTTYPE_NONE given to template
#endif

#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
typedef my_dataset_update_listener_t *my_dataset_update_listener_arr_data_t;
#else
typedef my_dataset_update_listener_t my_dataset_update_listener_arr_data_t;
#endif

#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_dataset_update_listener_arr_DECLARE(VAR_SUFFIX) my_dataset_update_listener_arr_data_t *VAR_SUFFIX; my_dataset_update_listener_t VAR_SUFFIX ## _dflt; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#else
#define my_dataset_update_listener_arr_DECLARE(VAR_SUFFIX) my_dataset_update_listener_arr_data_t *VAR_SUFFIX; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#endif

#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_dataset_update_listener_arr_set_length(VAR_SUFFIX, size) my_dataset_update_listener_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _dflt), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#else
#define my_dataset_update_listener_arr_set_length(VAR_SUFFIX, size) my_dataset_update_listener_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#endif

#define assert_x(must_be_true) do { if(unlikely(!(must_be_true))) { fprintf(stderr, "Assertion '%s' failed on %s:%d\n", #must_be_true, __FILE__, __LINE__); exit(1); }} while(0)

NONNULL __attribute__((noinline)) static void my_dataset_update_listener_arr_set_length_int_alloc_more(my_dataset_update_listener_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM
										   my_dataset_update_listener_t *dflt,
#endif
										   int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   int baselen;
   if(oldlen > 0) {
      baselen = min(oldlen, (int)(ARRAY_MAX_INC_CHUNK / sizeof(my_dataset_update_listener_arr_data_t)));
   } else {
      baselen = 4096 / sizeof(my_dataset_update_listener_arr_data_t);
   }

   // round new size upwards to next multiple of baselen
   // if baselen = 512, size = 513 -> 1024
   // if baselen = 512, size = 1024 -> 1024
   // if baselen = 512, size = 1025 -> 1536
   *num_alloc = ceil_div(size, baselen);

   assert_x((oldlen == 0) == (*arr == NULL));
   //printf("realloc %p %p -> ", arr, *arr);
   *arr = realloc_c(*arr, sizeof(my_dataset_update_listener_arr_data_t) * *num_alloc);
   //printf("%p %d req %d\n", *arr, *num_alloc, size);
   assert_x(size <= *num_alloc);
   //    printf("%d -> %d = %d\n", oldlen, *num_alloc, *num_alloc - oldlen);

#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM
   memmset(*arr + oldlen, dflt, sizeof(my_dataset_update_listener_arr_data_t), *num_alloc - oldlen);
#elif ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_ZERO
   bzero(*arr + oldlen, sizeof(my_dataset_update_listener_arr_data_t) * (*num_alloc - oldlen));
#endif
}


NONNULL static inline void my_dataset_update_listener_arr_set_length_int(my_dataset_update_listener_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
						     my_dataset_update_listener_t *dflt,
#endif
						     int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   if(unlikely(oldlen < size)) {
      my_dataset_update_listener_arr_set_length_int_alloc_more(arr,
#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM
					   dflt,
#endif
					   count, num_alloc, size);
   }
   if(likely(*count < size)) {
#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      int i;
      for(i=*count; i<size; ++i) {
	 (*arr)[i] = malloc(sizeof(my_dataset_update_listener_t));
	 memcpy((*arr)[i], dflt, sizeof(my_dataset_update_listener_t));
      }
#endif
   } else {
#if ARRAY_DEFAULTTYPE_NONE == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      // it's up to the user to free them
#endif
   }
   *count = size;
}

#define my_dataset_update_listener_arr_free(VAR_SUFFIX) my_dataset_update_listener_arr_free_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc))

// you can reuse the array after this, it just frees everything and resets counters
NONNULL static void my_dataset_update_listener_arr_free_int(my_dataset_update_listener_arr_data_t **arr, int *count, int *num_alloc) {
   if(!*arr) return;
   free(*arr);
   *count = 0;
   *num_alloc = 0;
   *arr = NULL;
}

#undef assert_x

*/

typedef struct {
      my_data_arr_DECLARE(data);
      my_data_t min, max;
      my_data_t prev;
      my_data_t diffmin;

      // defaultname = column name as present in file
      char *defaultname; // in UTF-8, NULL if no name available

      // updated by user
      // name = column name to show in gui, can be edited by user
      char *name; // in UTF-8, "item-123" if no name available
      boolean_t name_locked; // set to true to not update this when calling update_dataset()
      void *user_data;
} my_dataset_item_t;


#if ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_CUSTOM && ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_ZERO && ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_NONE && ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#error src/dataset.xh:65: Unknown defaulttype ARRAY_DEFAULTTYPE_CUSTOM given to template
#endif

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
typedef my_dataset_item_t *my_dataset_item_arr_data_t;
#else
typedef my_dataset_item_t my_dataset_item_arr_data_t;
#endif

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_dataset_item_arr_DECLARE(VAR_SUFFIX) my_dataset_item_arr_data_t *VAR_SUFFIX; my_dataset_item_t VAR_SUFFIX ## _dflt; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#else
#define my_dataset_item_arr_DECLARE(VAR_SUFFIX) my_dataset_item_arr_data_t *VAR_SUFFIX; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#endif

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_dataset_item_arr_set_length(VAR_SUFFIX, size) my_dataset_item_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _dflt), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#else
#define my_dataset_item_arr_set_length(VAR_SUFFIX, size) my_dataset_item_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#endif

#define assert_x(must_be_true) do { if(unlikely(!(must_be_true))) { fprintf(stderr, "Assertion '%s' failed on %s:%d\n", #must_be_true, __FILE__, __LINE__); exit(1); }} while(0)

NONNULL __attribute__((noinline)) static void my_dataset_item_arr_set_length_int_alloc_more(my_dataset_item_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM
										   my_dataset_item_t *dflt,
#endif
										   int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   int baselen;
   if(oldlen > 0) {
      baselen = min(oldlen, (int)(ARRAY_MAX_INC_CHUNK / sizeof(my_dataset_item_arr_data_t)));
   } else {
      baselen = 4096 / sizeof(my_dataset_item_arr_data_t);
   }

   // round new size upwards to next multiple of baselen
   // if baselen = 512, size = 513 -> 1024
   // if baselen = 512, size = 1024 -> 1024
   // if baselen = 512, size = 1025 -> 1536
   *num_alloc = ceil_div(size, baselen);

   assert_x((oldlen == 0) == (*arr == NULL));
   //printf("realloc %p %p -> ", arr, *arr);
   *arr = realloc_c(*arr, sizeof(my_dataset_item_arr_data_t) * *num_alloc);
   //printf("%p %d req %d\n", *arr, *num_alloc, size);
   assert_x(size <= *num_alloc);
   //    printf("%d -> %d = %d\n", oldlen, *num_alloc, *num_alloc - oldlen);

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM
   memmset(*arr + oldlen, dflt, sizeof(my_dataset_item_arr_data_t), *num_alloc - oldlen);
#elif ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_ZERO
   bzero(*arr + oldlen, sizeof(my_dataset_item_arr_data_t) * (*num_alloc - oldlen));
#endif
}


NONNULL static inline void my_dataset_item_arr_set_length_int(my_dataset_item_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
						     my_dataset_item_t *dflt,
#endif
						     int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   if(unlikely(oldlen < size)) {
      my_dataset_item_arr_set_length_int_alloc_more(arr,
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM
					   dflt,
#endif
					   count, num_alloc, size);
   }
   if(likely(*count < size)) {
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      int i;
      for(i=*count; i<size; ++i) {
	 (*arr)[i] = malloc(sizeof(my_dataset_item_t));
	 memcpy((*arr)[i], dflt, sizeof(my_dataset_item_t));
      }
#endif
   } else {
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      // it's up to the user to free them
#endif
   }
   *count = size;
}

#define my_dataset_item_arr_free(VAR_SUFFIX) my_dataset_item_arr_free_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc))

// you can reuse the array after this, it just frees everything and resets counters
NONNULL static void my_dataset_item_arr_free_int(my_dataset_item_arr_data_t **arr, int *count, int *num_alloc) {
   if(!*arr) return;
   free(*arr);
   *count = 0;
   *num_alloc = 0;
   *arr = NULL;
}

#undef assert_x


typedef enum { TIMETYPE_EPOCH, TIMETYPE_START } timetype_t;

typedef enum { TIMESTAMP_BASE_SEC, TIMESTAMP_BASE_MILLIS, TIMESTAMP_BASE_DAYS } timestamp_base_t;

typedef struct {
      my_time_arr_DECLARE(time);
      my_time_t ts, te;
      my_time_t last_parsed_nonadjusted_timestamp; // used when multiple same timestamps are seen to see check if they still are the same

      my_dataset_item_arr_DECLARE(item);

      char *path_system; // malloced (in FILESYSTEM charset)
      char *path_utf8; // malloced (in UTF-8 charset)
      const char *defaultname; // points to path_utf8 substring
      char *name; // malloced (originally strdup), updated by user
      char *parse_errors; // delimited by '\n' (UTF-8)
      size_t parse_errors_pos;
      size_t parse_errors_size;

      timetype_t timetype;

      my_time_t last_modified; // file timestamp

      my_time_t min_time_diff; // the smallest difference detected
			       // between two timestamps in the file

      // updated by user
      my_time_t maxdiff; // maximum difference between two timestamps before it's a discontinued dataset
      void *user_data;

      // stuff below is for update_dataset() .. don't use it, it's not a part of the api
      long filepos; // how much of file has been read, used when tailing
      my_time_t timeoff; // time offset to add to all entries
      timestamp_base_t timestamp_base;
      int refcount;
      char **labels;
      int numlabels;

#ifdef USE_FAM
      // stuff used by FAM
      FAMRequest fr;
      boolean_t fam_monitored;
#endif

//      my_dataset_update_listener_arr_DECLARE(update_listener);

} my_dataset_t;

typedef void progress_cb_t(double fraction, void *user_data);

// returns refed dataset
WARN_UNUSED_RESULT NONNULL_ARG(1) my_dataset_t *read_dataset_int(const char *file, int maxlines, progress_cb_t *cb, void *user_data);

// returns refed dataset
WARN_UNUSED_RESULT NONNULL static inline my_dataset_t *scan_dataset(const char *file, int maxlines) {
   return read_dataset_int(file, maxlines, 0, 0);
}

// returns refed dataset
WARN_UNUSED_RESULT NONNULL_ARG(1) static inline my_dataset_t *read_dataset(const char *file, progress_cb_t *cb, void *user_data) {
   return read_dataset_int(file, -1, cb, user_data);
}

WARN_UNUSED_RESULT NONNULL my_dataset_t *read_dataset_preview(const char *file, int maxsamples);

// return 0 if there was a problem, 1 if nothing changed, 2 if new data was loaded
int update_dataset(my_dataset_t *dataset);

/*
void add_dataset_listener(my_dataset_t *dataset, my_dataset_update_cb_t *cb, void *user_data);
void remove_dataset_listener(my_dataset_t *dataset, my_dataset_update_cb_t *cb, void *user_data);
*/

NONNULL void ref_dataset(my_dataset_t *dataset);
NONNULL int unref_dataset(my_dataset_t *dataset);

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
#endif
