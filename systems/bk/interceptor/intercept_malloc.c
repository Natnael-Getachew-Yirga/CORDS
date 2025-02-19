#define _GNU_SOURCE

#include <stdio.h>
#include <dlfcn.h>
#include <stdlib.h>
#include <stdbool.h>
#include <time.h>
#include <sys/time.h>

static void* (*real_malloc)(size_t) = NULL;
static time_t start_time = 0;
static bool timing_initialized = false;
static int delay_seconds = 15; // Default delay of 10 seconds
static bool delay_over_notified = false;

static void mtrace_init(void)
{
    real_malloc = dlsym(RTLD_NEXT, "malloc");
    if (NULL == real_malloc) {
        fprintf(stderr, "Error in `dlsym`: %s\n", dlerror());
    }
    
    // Get delay from environment variable if set
    char* delay_str = getenv("MALLOC_FAIL_DELAY");
    if (delay_str != NULL) {
        delay_seconds = atoi(delay_str);
    }
    fprintf(stderr, "Malloc interceptor initialized with %d second delay\n", delay_seconds);
}

// Function to decide whether to fail or not
bool should_fail() {
    if (!timing_initialized) {
        start_time = time(NULL);
        timing_initialized = true;
        return false; // Don't fail during initialization
    }

    // Check if enough time has passed
    time_t current_time = time(NULL);
    if (difftime(current_time, start_time) < delay_seconds) {
        return false; // Don't fail during the delay period
    }
    
    if (!delay_over_notified) {
        fprintf(stderr, "Malloc interception active: failures may occur now.\n");
        delay_over_notified = true;
    }

    static bool rand_initialized = false;
    if (!rand_initialized) {
        srand(time(NULL));
        rand_initialized = true;
    }

    // Get failure probability from environment variable or use default
    double failure_probability = 0.01; // Default 1%
    char* prob_str = getenv("MALLOC_FAIL_PROBABILITY");
    if (prob_str != NULL) {
        failure_probability = atof(prob_str);
    }

    double normalized_value = (double)rand() / (RAND_MAX + 1.0);
    return normalized_value < failure_probability;
}

void *malloc(size_t size)
{
    if(real_malloc == NULL) {
        mtrace_init();
    }

    void *p = NULL;
    
    if (should_fail()){
        time_t current = time(NULL);
        fprintf(stderr, "Simulating malloc failure at %ld seconds after start (size=%zu)\n", 
                (long)difftime(current, start_time), size);
        return NULL;
    }

    fprintf(stderr, "malloc(%zu) = ", size);
    p = real_malloc(size);
    fprintf(stderr, "%p\n", p);
    return p;
}
