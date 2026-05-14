#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

typedef struct {
    const char *label;
    int duration;
    int status;
} thread_job_t;

void *run_stage_command(void *arg) {
    thread_job_t *job = (thread_job_t *)arg;

    fprintf(stderr, "[THREAD] start %s\n", job->label);

    sleep(job->duration);

    job->status = 0;

    fprintf(stderr, "[THREAD] done %s status=%d\n",
            job->label, job->status);

    return NULL;
}

int main() {
    pthread_t t1, t2;

    thread_job_t job1 = {"Job A", 2, 1};
    thread_job_t job2 = {"Job B", 3, 1};

    pthread_create(&t1, NULL, run_stage_command, &job1);
    pthread_create(&t2, NULL, run_stage_command, &job2);

    pthread_join(t1, NULL);
    pthread_join(t2, NULL);

    printf("All threads finished\n");

    return 0;
}
