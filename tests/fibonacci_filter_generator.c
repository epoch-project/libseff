#include "seff.h"
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#define MAKE_GENERATOR_DECORATOR(decorator_name, decorator_data, decorator_behavior) \
    typedef struct {                                                                 \
        seff_coroutine_t *base_generator;                                            \
        decorator_data                                                               \
    } decorator_name##_args;                                                         \
    void *decorator_name(seff_coroutine_t *self, void *_args) {                      \
        decorator_name##_args args = *(decorator_name##_args *)_args;                \
        while (true) {                                                               \
            void *next = seff_resume(args.base_generator, NULL);                     \
            if (args.base_generator->state == FINISHED) {                            \
                return NULL;                                                         \
            } else {                                                                 \
                decorator_behavior;                                                  \
            }                                                                        \
        }                                                                            \
    }

void *fibonacci_generator(seff_coroutine_t *self, void *arg) {
    // The upper limit is passed to the coroutine as a void*
    int64_t a = 1, b = 0;
    while (true) {
        seff_yield(self, (void *)a);
        int64_t tmp = a;
        a = a + b;
        b = tmp;
    }
}

MAKE_GENERATOR_DECORATOR(filter, bool (*predicate)(void *);, {
    if (args.predicate(next)) {
        seff_yield(self, next);
    }
})

MAKE_GENERATOR_DECORATOR(map, void *(*fn)(void *);, { seff_yield(self, args.fn(next)); })

void *twice(void *arg) { return (void *)(2 * (int64_t)arg); }

bool ends_in_six(void *arg) { return 6 == ((int64_t)arg) % 10; }

int main(void) {
    seff_coroutine_t *fib = seff_coroutine_new(fibonacci_generator, NULL);

    map_args twice_fib_args;
    twice_fib_args.base_generator = fib;
    twice_fib_args.fn = twice;
    seff_coroutine_t *twice_fib = seff_coroutine_new(map, &twice_fib_args);

    filter_args filter_fib_args;
    filter_fib_args.base_generator = twice_fib;
    filter_fib_args.predicate = ends_in_six;
    seff_coroutine_t *filter_fib = seff_coroutine_new(filter, &filter_fib_args);

    int64_t next_elt;
    for (int i = 0; i < 1000; i++) {
        next_elt = (int64_t)seff_resume(filter_fib, NULL);
        if (filter_fib->state == FINISHED)
            break;
    }
    printf("%ld\n", next_elt);
}
