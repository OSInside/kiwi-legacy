#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <satsolver/solver.h>
#include <satsolver/repo_solv.h>
#include <satsolver/policy.h>

Id select_solvable (Repo*, Pool*,char*);

int main (void) {
	Pool   *pool   = 0;
	Solver *solver = 0;
	FILE   *fp     = 0;
	int b;
	Queue  queue;
	int fd = open ("tmp/primary", O_RDONLY);
	if (fd == -1) {
		return 1;
	}

	pool = pool_create();

	fp = fdopen(fd, "r");
	Repo *new_repo = repo_create (pool, "empty");
	repo_add_solv (new_repo, fp);
	fclose(fp);
	close (fd);

	Repo *empty_installed = repo_create(pool, "empty");

	pool_createwhatprovides(pool);

	queue_init (&queue);
	queue_push (&queue, SOLVER_INSTALL_SOLVABLE);
	queue_push (&queue, select_solvable(new_repo,pool,"pattern:default"));


	solver = solver_create (pool,empty_installed);

	solver_solve (solver, &queue);
	

	for (b = 0; b < solver->decisionq.count; b++) {
		Id p = solver->decisionq.elements[b];
		//printf ("SOLVER DECISION ID: %d\n",p);
		if (p < 0) {
			//printf ("what does that mean ??\n");
			continue;
		}
		if (p == SYSTEMSOLVABLE) {
			continue;
		}
		Solvable *s = solver->pool->solvables + p;
		printf ("SOLVER NAME: %s\n",id2str(pool, s->name));
	}	
	return 0;
}

Id select_solvable (Repo *repo, Pool* pool,char *name) {
	Id id;
	Queue plist;
	int i, end;
	Solvable *s;

	id = str2id(pool, name, 1);
	queue_init( &plist);
	i = repo ? repo->start : 1;
	end = repo ? repo->start + repo->nsolvables : pool->nsolvables;
	for (; i < end; i++) {
		s = pool->solvables + i;
		//printf ("+++++++ %s\n",id2str(pool, s->name));
		if (!pool_installable(pool, s)) {
			continue;
		}
		if (s->name == id) {
			queue_push(&plist, i);
		}
	}
	prune_best_version_arch(pool, &plist);
	if (plist.count == 0) {
		printf("unknown package '%s'\n", name);
		exit(1);
	}
	id = plist.elements[0];
	queue_free(&plist);
	return id;
}
