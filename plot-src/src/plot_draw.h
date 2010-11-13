#ifndef __xcpp_plot_draw_xh
#define __xcpp_plot_draw_xh
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
 * plot_draw - handles the drawing of a plot
 */

#include "array.h"




#include "dataset.h"



#include "grid.h"

#include "paintapi.h"


typedef struct {
      int x1, y1;
      int x2, y2;
} my_plot_rect_t;

typedef enum { LINE_MODE_NORMAL } my_plot_line_mode_t;
typedef enum { TYPE_LINE, TYPE_STEP } my_plot_line_type_t;

#define MAX_SMOOTH 16

typedef struct {
      // plot_draw_lines manages
      paintapi_gc_t *line_gc;
      paintapi_gc_t *line_minmax_gc;
      paintapi_gc_t *horiz_marker_gc; // used by plot2.xc

      // plot_draw sets
      int hline;
      int markers_drawn;

      // caller sets
      paintapi_rgb_t color;
      int dataset_idx;
      int enabled;
      my_plot_line_mode_t mode;
      int smooth_amount;
      my_plot_line_type_t linetype;

      // plot_draw_legend sets
      my_plot_rect_t legend_rect;

      struct {
	    // plot_draw_legend manages
	    paintapi_textlayout_t *legend_layout;

	    // plot_draw_lines manages
	    const my_data_t *data;

	    paintapi_point_t *avgLines;
	    int *avgLinesOffsets;
	    paintapi_point_t *minmaxLines; // one for every x coordinate
	    int *minmax_values_min;
	    int *minmax_values_max;

	    int usedAvgLines;
	    int usedAvgLinesOffsets;
	    int usedMinmaxLines;
      } tmp;

} my_plot_line_info_t;


#if ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_CUSTOM && ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_ZERO && ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_NONE && ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#error src/plot_draw.xh:80: Unknown defaulttype ARRAY_DEFAULTTYPE_CUSTOM given to template
#endif

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
typedef my_plot_line_info_t *my_plot_line_info_arr_data_t;
#else
typedef my_plot_line_info_t my_plot_line_info_arr_data_t;
#endif

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_plot_line_info_arr_DECLARE(VAR_SUFFIX) my_plot_line_info_arr_data_t *VAR_SUFFIX; my_plot_line_info_t VAR_SUFFIX ## _dflt; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#else
#define my_plot_line_info_arr_DECLARE(VAR_SUFFIX) my_plot_line_info_arr_data_t *VAR_SUFFIX; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#endif

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_plot_line_info_arr_set_length(VAR_SUFFIX, size) my_plot_line_info_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _dflt), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#else
#define my_plot_line_info_arr_set_length(VAR_SUFFIX, size) my_plot_line_info_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#endif

#define assert_x(must_be_true) do { if(unlikely(!(must_be_true))) { fprintf(stderr, "Assertion '%s' failed on %s:%d\n", #must_be_true, __FILE__, __LINE__); exit(1); }} while(0)

NONNULL __attribute__((noinline)) static void my_plot_line_info_arr_set_length_int_alloc_more(my_plot_line_info_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM
										   my_plot_line_info_t *dflt,
#endif
										   int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   int baselen;
   if(oldlen > 0) {
      baselen = min(oldlen, (int)(ARRAY_MAX_INC_CHUNK / sizeof(my_plot_line_info_arr_data_t)));
   } else {
      baselen = 4096 / sizeof(my_plot_line_info_arr_data_t);
   }

   // round new size upwards to next multiple of baselen
   // if baselen = 512, size = 513 -> 1024
   // if baselen = 512, size = 1024 -> 1024
   // if baselen = 512, size = 1025 -> 1536
   *num_alloc = ceil_div(size, baselen);

   assert_x((oldlen == 0) == (*arr == NULL));
   //printf("realloc %p %p -> ", arr, *arr);
   *arr = realloc_c(*arr, sizeof(my_plot_line_info_arr_data_t) * *num_alloc);
   //printf("%p %d req %d\n", *arr, *num_alloc, size);
   assert_x(size <= *num_alloc);
   //    printf("%d -> %d = %d\n", oldlen, *num_alloc, *num_alloc - oldlen);

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM
   memmset(*arr + oldlen, dflt, sizeof(my_plot_line_info_arr_data_t), *num_alloc - oldlen);
#elif ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_ZERO
   bzero(*arr + oldlen, sizeof(my_plot_line_info_arr_data_t) * (*num_alloc - oldlen));
#endif
}


NONNULL static inline void my_plot_line_info_arr_set_length_int(my_plot_line_info_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
						     my_plot_line_info_t *dflt,
#endif
						     int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   if(unlikely(oldlen < size)) {
      my_plot_line_info_arr_set_length_int_alloc_more(arr,
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM
					   dflt,
#endif
					   count, num_alloc, size);
   }
   if(likely(*count < size)) {
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      int i;
      for(i=*count; i<size; ++i) {
	 (*arr)[i] = malloc(sizeof(my_plot_line_info_t));
	 memcpy((*arr)[i], dflt, sizeof(my_plot_line_info_t));
      }
#endif
   } else {
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      // it's up to the user to free them
#endif
   }
   *count = size;
}

#define my_plot_line_info_arr_free(VAR_SUFFIX) my_plot_line_info_arr_free_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc))

// you can reuse the array after this, it just frees everything and resets counters
NONNULL static void my_plot_line_info_arr_free_int(my_plot_line_info_arr_data_t **arr, int *count, int *num_alloc) {
   if(!*arr) return;
   free(*arr);
   *count = 0;
   *num_alloc = 0;
   *arr = NULL;
}

#undef assert_x


typedef struct {
      // caller sets
      my_plot_line_info_arr_DECLARE(line);

      // caller sets
      my_dataset_t *dataset;

} my_plot_line_info_set_t;


#if ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_CUSTOM && ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_ZERO && ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_NONE && ARRAY_DEFAULTTYPE_CUSTOM != ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#error src/plot_draw.xh:91: Unknown defaulttype ARRAY_DEFAULTTYPE_CUSTOM given to template
#endif

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
typedef my_plot_line_info_set_t *my_plot_line_info_set_arr_data_t;
#else
typedef my_plot_line_info_set_t my_plot_line_info_set_arr_data_t;
#endif

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_plot_line_info_set_arr_DECLARE(VAR_SUFFIX) my_plot_line_info_set_arr_data_t *VAR_SUFFIX; my_plot_line_info_set_t VAR_SUFFIX ## _dflt; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#else
#define my_plot_line_info_set_arr_DECLARE(VAR_SUFFIX) my_plot_line_info_set_arr_data_t *VAR_SUFFIX; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#endif

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_plot_line_info_set_arr_set_length(VAR_SUFFIX, size) my_plot_line_info_set_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _dflt), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#else
#define my_plot_line_info_set_arr_set_length(VAR_SUFFIX, size) my_plot_line_info_set_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#endif

#define assert_x(must_be_true) do { if(unlikely(!(must_be_true))) { fprintf(stderr, "Assertion '%s' failed on %s:%d\n", #must_be_true, __FILE__, __LINE__); exit(1); }} while(0)

NONNULL __attribute__((noinline)) static void my_plot_line_info_set_arr_set_length_int_alloc_more(my_plot_line_info_set_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM
										   my_plot_line_info_set_t *dflt,
#endif
										   int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   int baselen;
   if(oldlen > 0) {
      baselen = min(oldlen, (int)(ARRAY_MAX_INC_CHUNK / sizeof(my_plot_line_info_set_arr_data_t)));
   } else {
      baselen = 4096 / sizeof(my_plot_line_info_set_arr_data_t);
   }

   // round new size upwards to next multiple of baselen
   // if baselen = 512, size = 513 -> 1024
   // if baselen = 512, size = 1024 -> 1024
   // if baselen = 512, size = 1025 -> 1536
   *num_alloc = ceil_div(size, baselen);

   assert_x((oldlen == 0) == (*arr == NULL));
   //printf("realloc %p %p -> ", arr, *arr);
   *arr = realloc_c(*arr, sizeof(my_plot_line_info_set_arr_data_t) * *num_alloc);
   //printf("%p %d req %d\n", *arr, *num_alloc, size);
   assert_x(size <= *num_alloc);
   //    printf("%d -> %d = %d\n", oldlen, *num_alloc, *num_alloc - oldlen);

#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM
   memmset(*arr + oldlen, dflt, sizeof(my_plot_line_info_set_arr_data_t), *num_alloc - oldlen);
#elif ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_ZERO
   bzero(*arr + oldlen, sizeof(my_plot_line_info_set_arr_data_t) * (*num_alloc - oldlen));
#endif
}


NONNULL static inline void my_plot_line_info_set_arr_set_length_int(my_plot_line_info_set_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
						     my_plot_line_info_set_t *dflt,
#endif
						     int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   if(unlikely(oldlen < size)) {
      my_plot_line_info_set_arr_set_length_int_alloc_more(arr,
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM
					   dflt,
#endif
					   count, num_alloc, size);
   }
   if(likely(*count < size)) {
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      int i;
      for(i=*count; i<size; ++i) {
	 (*arr)[i] = malloc(sizeof(my_plot_line_info_set_t));
	 memcpy((*arr)[i], dflt, sizeof(my_plot_line_info_set_t));
      }
#endif
   } else {
#if ARRAY_DEFAULTTYPE_CUSTOM == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      // it's up to the user to free them
#endif
   }
   *count = size;
}

#define my_plot_line_info_set_arr_free(VAR_SUFFIX) my_plot_line_info_set_arr_free_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc))

// you can reuse the array after this, it just frees everything and resets counters
NONNULL static void my_plot_line_info_set_arr_free_int(my_plot_line_info_set_arr_data_t **arr, int *count, int *num_alloc) {
   if(!*arr) return;
   free(*arr);
   *count = 0;
   *num_alloc = 0;
   *arr = NULL;
}

#undef assert_x


typedef struct {

      my_time_t timestamp;

      const char *bookmark; /* malloc */

      // location of bookmark pole in view coordinates
      int xoffset;

      // location bookmark text node in view coordinates
      my_plot_rect_t note_rect;

} my_plot_bookmark_t;


#if ARRAY_DEFAULTTYPE_ZERO != ARRAY_DEFAULTTYPE_CUSTOM && ARRAY_DEFAULTTYPE_ZERO != ARRAY_DEFAULTTYPE_ZERO && ARRAY_DEFAULTTYPE_ZERO != ARRAY_DEFAULTTYPE_NONE && ARRAY_DEFAULTTYPE_ZERO != ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#error src/plot_draw.xh:107: Unknown defaulttype ARRAY_DEFAULTTYPE_ZERO given to template
#endif

#if ARRAY_DEFAULTTYPE_ZERO == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
typedef my_plot_bookmark_t *my_plot_bookmark_arr_data_t;
#else
typedef my_plot_bookmark_t my_plot_bookmark_arr_data_t;
#endif

#if ARRAY_DEFAULTTYPE_ZERO == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_ZERO == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_plot_bookmark_arr_DECLARE(VAR_SUFFIX) my_plot_bookmark_arr_data_t *VAR_SUFFIX; my_plot_bookmark_t VAR_SUFFIX ## _dflt; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#else
#define my_plot_bookmark_arr_DECLARE(VAR_SUFFIX) my_plot_bookmark_arr_data_t *VAR_SUFFIX; int VAR_SUFFIX ## _count; int VAR_SUFFIX ## _alloc;
#endif

#if ARRAY_DEFAULTTYPE_ZERO == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_ZERO == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
#define my_plot_bookmark_arr_set_length(VAR_SUFFIX, size) my_plot_bookmark_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _dflt), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#else
#define my_plot_bookmark_arr_set_length(VAR_SUFFIX, size) my_plot_bookmark_arr_set_length_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc), size)
#endif

#define assert_x(must_be_true) do { if(unlikely(!(must_be_true))) { fprintf(stderr, "Assertion '%s' failed on %s:%d\n", #must_be_true, __FILE__, __LINE__); exit(1); }} while(0)

NONNULL __attribute__((noinline)) static void my_plot_bookmark_arr_set_length_int_alloc_more(my_plot_bookmark_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_ZERO == ARRAY_DEFAULTTYPE_CUSTOM
										   my_plot_bookmark_t *dflt,
#endif
										   int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   int baselen;
   if(oldlen > 0) {
      baselen = min(oldlen, (int)(ARRAY_MAX_INC_CHUNK / sizeof(my_plot_bookmark_arr_data_t)));
   } else {
      baselen = 4096 / sizeof(my_plot_bookmark_arr_data_t);
   }

   // round new size upwards to next multiple of baselen
   // if baselen = 512, size = 513 -> 1024
   // if baselen = 512, size = 1024 -> 1024
   // if baselen = 512, size = 1025 -> 1536
   *num_alloc = ceil_div(size, baselen);

   assert_x((oldlen == 0) == (*arr == NULL));
   //printf("realloc %p %p -> ", arr, *arr);
   *arr = realloc_c(*arr, sizeof(my_plot_bookmark_arr_data_t) * *num_alloc);
   //printf("%p %d req %d\n", *arr, *num_alloc, size);
   assert_x(size <= *num_alloc);
   //    printf("%d -> %d = %d\n", oldlen, *num_alloc, *num_alloc - oldlen);

#if ARRAY_DEFAULTTYPE_ZERO == ARRAY_DEFAULTTYPE_CUSTOM
   memmset(*arr + oldlen, dflt, sizeof(my_plot_bookmark_arr_data_t), *num_alloc - oldlen);
#elif ARRAY_DEFAULTTYPE_ZERO == ARRAY_DEFAULTTYPE_ZERO
   bzero(*arr + oldlen, sizeof(my_plot_bookmark_arr_data_t) * (*num_alloc - oldlen));
#endif
}


NONNULL static inline void my_plot_bookmark_arr_set_length_int(my_plot_bookmark_arr_data_t **arr,
#if ARRAY_DEFAULTTYPE_ZERO == ARRAY_DEFAULTTYPE_CUSTOM || ARRAY_DEFAULTTYPE_ZERO == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
						     my_plot_bookmark_t *dflt,
#endif
						     int *count, int *num_alloc, int size) {
   int oldlen = *num_alloc;
   if(unlikely(oldlen < size)) {
      my_plot_bookmark_arr_set_length_int_alloc_more(arr,
#if ARRAY_DEFAULTTYPE_ZERO == ARRAY_DEFAULTTYPE_CUSTOM
					   dflt,
#endif
					   count, num_alloc, size);
   }
   if(likely(*count < size)) {
#if ARRAY_DEFAULTTYPE_ZERO == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      int i;
      for(i=*count; i<size; ++i) {
	 (*arr)[i] = malloc(sizeof(my_plot_bookmark_t));
	 memcpy((*arr)[i], dflt, sizeof(my_plot_bookmark_t));
      }
#endif
   } else {
#if ARRAY_DEFAULTTYPE_ZERO == ARRAY_DEFAULTTYPE_CUSTOM_MALLOC
      // it's up to the user to free them
#endif
   }
   *count = size;
}

#define my_plot_bookmark_arr_free(VAR_SUFFIX) my_plot_bookmark_arr_free_int(&(VAR_SUFFIX), &(VAR_SUFFIX ## _count), &(VAR_SUFFIX ## _alloc))

// you can reuse the array after this, it just frees everything and resets counters
NONNULL static void my_plot_bookmark_arr_free_int(my_plot_bookmark_arr_data_t **arr, int *count, int *num_alloc) {
   if(!*arr) return;
   free(*arr);
   *count = 0;
   *num_alloc = 0;
   *arr = NULL;
}

#undef assert_x


typedef struct {
      // caller sets
      int plot_xe, plot_ye;

      // caller sets
      my_time_t xstart, xend; // the full x range
      double xmin, xmax;
      double ymin, ymax;

      // caller sets
      my_plot_line_info_set_arr_DECLARE(line_set);

      // caller sets
      paintapi_t *paintapi;

      // caller sets the *_color ones, plot_draw sets the *_gc ones
      struct {
	    paintapi_rgb_t minor_color;
	    paintapi_gc_t *minor_gc;

	    paintapi_rgb_t major_color;
	    paintapi_gc_t *major_gc;

	    paintapi_rgb_t zerogrid_color;
	    paintapi_gc_t *zerogrid_gc;

	    paintapi_rgb_t sep_color;
	    paintapi_gc_t *sep_gc;

	    paintapi_rgb_t label_color;
	    paintapi_gc_t *label_gc;

	    // caller sets
	    paintapi_font_t *font_xaxis;
	    paintapi_font_t *font_yaxis;
      } grid;

      struct {
	    paintapi_rgb_t bg_color;
	    paintapi_gc_t *bg_gc;

	    paintapi_rgb_t border_color;
	    paintapi_gc_t *border_gc;

	    paintapi_rgb_t text_color;
	    paintapi_gc_t *text_gc;

	    // caller sets
	    enum { LEGEND_HIDE, LEGEND_SHOW_LEFT, LEGEND_SHOW_RIGHT } show;
	    paintapi_font_t *font;

	    // plot_draw_legend sets
	    my_plot_rect_t rect;
      } legend;

      struct {
	    paintapi_rgb_t color;
	    paintapi_gc_t *gc;

	    paintapi_rgb_t text_color;
	    paintapi_gc_t *text_gc;

	    // plot_draw_bookmarks sets
	    int triangle_size;

	    // caller sets
	    my_plot_bookmark_arr_DECLARE(bookmark);
	    enum { BOOKMARKS_HIDE, BOOKMARKS_SHOW_POLE_ONLY, BOOKMARKS_SHOW_LABEL_ONLY, BOOKMARKS_SHOW } show;

      } bookmarks;

      struct {
	    paintapi_rgb_t text_color;
	    paintapi_gc_t *text_gc;

	    paintapi_font_t *font;
      } logo;

      // plot_draw sets
      double last_render_time;
      int value_axis_width;
      int plot_yde;
      int time_stamp_width;
      int font_height;

      // caller sets
      boolean_t show_disabled;
      boolean_t inverse_colors;
      double samples_per_pixel;
      boolean_t draw_min_max_lines;
      boolean_t draw_average_line;
      my_time_t time_off; /* if non-zero, x axis time is printed relative to this */

      struct {
	    // managed by plot_draw_lines
	    struct {
		  // stuff in this struct also exists in my_plot_line_info_t.tmp
		  paintapi_point_t *avgLines;
		  int *avgLinesOffsets;
		  paintapi_point_t *minmaxLines; // one for every x coordinate
		  int *minmax_values_min;
		  int *minmax_values_max;
	    } line;
	    double h_div_vdiff;
	    int *sample_x_allocated;
	    int *sample_x; // sample_x[-1] <-> sample_x_allocated[0]

	    // managed by plot_draw_grids
	    grid_t time_grid;
	    time_field_t min_diff_field;
	    time_field_t max_diff_field;
      } tmp;

} my_plot_draw_t;

static inline boolean_t rect_equal(my_plot_rect_t *r1, my_plot_rect_t *r2)
{
   return r1->x1 == r2->x1 && r1->y1 == r2->y1 &&
	  r1->x2 == r2->x2 && r1->y2 == r2->y2;
}

static inline boolean_t rect_is_in(my_plot_rect_t *r, int x, int y)
{
   return (x >= r->x1 && x <= r->x2) &&
	  (y >= r->y1 && y <= r->y2);
}

void place_bookmark_note(my_plot_draw_t *plot, int bic, my_plot_rect_t *candidaterect, int dist); // TODO name
void plot_draw_sort_bookmarks(my_plot_draw_t *plot);

void plot_draw(my_plot_draw_t *plot);
void plot_draw_grid_precalc(my_plot_draw_t *plot);
void plot_draw_value_grid(my_plot_draw_t *plot);
void plot_draw_time_grid(my_plot_draw_t *plot);
void plot_draw_lines(my_plot_draw_t *plot);
void plot_draw_legend(my_plot_draw_t *plot);
void plot_draw_bookmarks(my_plot_draw_t *plot);
void plot_draw_logo(my_plot_draw_t *plot);

void plot_draw_calc_x_minmax(my_plot_draw_t *plot, my_time_t *pmin, my_time_t *pmax, my_time_t *pdiffmin);
int plot_draw_calc_y_minmax(my_plot_draw_t *plot, double *pmin, double *pmax, double *pdiffmin, boolean_t include_disabled);

boolean_t plot_draw_check_if_hit_legend_box(my_plot_draw_t *draw, int x, int y);
my_plot_line_info_t *plot_draw_check_if_hit_legend_item(my_plot_draw_t *draw, int x, int y, int *lsip, int *lip);
void *gc_new_with_color(my_plot_draw_t *plot, paintapi_rgb_t color); // TODO name

// init, deinit, clone -related functions below

// the init functions are "static inits" i.e. they should not allocate memory unless the memory is also static i.e. shared
void plot_draw_init(my_plot_draw_t *plot);
void plot_draw_init_bookmarks(my_plot_draw_t *plot);
void plot_draw_init_grids(my_plot_draw_t *plot);
void plot_draw_init_legend(my_plot_draw_t *plot);
void plot_draw_init_lines(my_plot_draw_t *plot);
void plot_draw_init_logo(my_plot_draw_t *plot);

void plot_draw_deinit(my_plot_draw_t *plot);
void plot_draw_deinit_bookmarks(my_plot_draw_t *plot);
void plot_draw_deinit_grids(my_plot_draw_t *plot);
void plot_draw_deinit_legend(my_plot_draw_t *plot);
void plot_draw_deinit_lines(my_plot_draw_t *plot);
void plot_draw_deinit_logo(my_plot_draw_t *plot);

void plot_draw_clone(my_plot_draw_t *n, my_plot_draw_t *o);
void plot_draw_clone_bookmarks(my_plot_draw_t *n, my_plot_draw_t *o);
void plot_draw_clone_grids(my_plot_draw_t *n, my_plot_draw_t *o);
void plot_draw_clone_legend(my_plot_draw_t *n, my_plot_draw_t *o);
void plot_draw_clone_lines(my_plot_draw_t *n, my_plot_draw_t *o);
void plot_draw_clone_logo(my_plot_draw_t *n, my_plot_draw_t *o);

void plot_draw_remove_all_data_files(my_plot_draw_t *plot);
void plot_draw_remove_data_file(my_plot_draw_t *plot, int idx);

void plot_draw_setup_gcs(my_plot_draw_t *plot);
void plot_draw_setup_bookmark_gcs(my_plot_draw_t *plot);
void plot_draw_setup_grid_gcs(my_plot_draw_t *plot);
void plot_draw_setup_legend_gcs(my_plot_draw_t *plot);
void plot_draw_setup_line_gcs(my_plot_draw_t *plot);
void plot_draw_setup_logo_gcs(my_plot_draw_t *plot);

void plot_draw_reset_gcs(my_plot_draw_t *plot);
void plot_draw_reset_bookmark_gcs(my_plot_draw_t *plot);
void plot_draw_reset_grid_gcs(my_plot_draw_t *plot);
void plot_draw_reset_legend_gcs(my_plot_draw_t *plot);
void plot_draw_reset_line_gcs(my_plot_draw_t *plot);
void plot_draw_reset_line_info_gcs(my_plot_draw_t *plot, my_plot_line_info_t *p);
void plot_draw_reset_logo_gcs(my_plot_draw_t *plot);

DEPRECATED static inline void plot_setup_gcs(my_plot_draw_t *plot) {
   plot_draw_setup_gcs(plot);
}

DEPRECATED static inline void plot_draw_reset_gc(my_plot_draw_t *plot) {
   plot_draw_reset_gcs(plot);
}

DEPRECATED static inline void plot_draw_reset_line_info_gc(my_plot_draw_t *plot, my_plot_line_info_t *p) {
   plot_draw_reset_line_info_gcs(plot, p);
}

#define gc_free_and_zero(x) do { if(plot->paintapi) { plot->paintapi->gc_free(plot->paintapi, x); } else if(x) { fprintf(stderr, "Non-null gc when paintapi is null\n"); } x = NULL; } while(0)

/* do we want these ?
void plot_draw_image2datacoord(my_plot_draw_t *plot, double image_x, double image_y);
void plot_draw_data2imagecoord(my_plot_draw_t *plot, double image_x, double image_y);
*/

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
#endif