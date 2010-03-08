#include "dataset.xh"
#include "system.xh"

int main(int arg_count, char **arg) {
   return read_dataset(arg[1], NULL, NULL) ? 0 : 1;
}

boolean_t system_check_events(void) {
   return 0;
}

char *filename_to_utf8(const char *filename) {
   return g_filename_to_utf8(filename, (gssize)-1, NULL, NULL, NULL);
}

/*
 * Local variables:
 * c-file-style: "ellemtel"
 * c-file-offsets: ((c . c-lineup-dont-change) (statement-cont . (lambda (le) (if (save-excursion (goto-char (cdr le)) (looking-at "return")) (c-lineup-java-inher le) (c-lineup-math le)))))
 * End:
 */
