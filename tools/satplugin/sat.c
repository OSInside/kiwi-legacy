#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <satsolver/solver.h>
#include <satsolver/poolarch.h>
#include <satsolver/solverdebug.h>
#include <satsolver/repo_solv.h>
#include <satsolver/policy.h>
#include <sys/utsname.h>

Id select_solvable (Repo*, Pool*,Solver*,char*);

int main (void) {
	Pool   *pool   = 0;
	Solver *solver = 0;
	FILE   *fp     = 0;
	struct utsname hw;
	int b;
	Queue  queue;
	int fd = open ("/var/cache/kiwi/satsolver/51c98db6cde4ff149b3cf5bbfcb57567", O_RDONLY);
	if (fd == -1) {
		return 1;
	}

	pool = pool_create();
	uname (&hw);
	
	printf ("Using Architecture: %s\n",hw.machine);	
	pool_setarch (pool,hw.machine);

	fp = fdopen(fd, "r");
	Repo *new_repo = repo_create (pool, "empty");
	repo_add_solv (new_repo, fp);
	fclose(fp);
	close (fd);

	Repo *empty_installed = repo_create(pool, "empty");

	#ifdef SOLV_VERSION_8
	pool_set_installed (pool, empty_installed);
	pool_addfileprovides (pool);
	#endif
	pool_createwhatprovides(pool);

	#ifdef SOLV_VERSION_8
	solver = solver_create (pool);
	#else
	solver = solver_create (pool,empty_installed);
	#endif

	queue_init (&queue);
	queue_push (&queue, SOLVER_INSTALL_SOLVABLE);
    queue_push (&queue, select_solvable(new_repo,pool,solver,"libcurl-devel"));

	#if 0
	queue_push (&queue, SOLVER_INSTALL_SOLVABLE);
	queue_push (
		&queue, select_solvable(new_repo,pool,solver,"pattern:apparmor")
	);
	queue_push (&queue, SOLVER_INSTALL_SOLVABLE);
	queue_push (
		&queue, select_solvable(new_repo,pool,solver,"pattern:apparmor_opt")
	);
	queue_push (&queue, SOLVER_INSTALL_SOLVABLE);
	queue_push (
		&queue, select_solvable(new_repo,pool,solver,"pattern:base")
	);
	queue_push (&queue, SOLVER_INSTALL_SOLVABLE);
	queue_push (
		&queue, select_solvable(new_repo,pool,solver,"pattern:devel_C_C++")
	);
	queue_push (&queue, SOLVER_INSTALL_SOLVABLE);
	queue_push (
		&queue, select_solvable(new_repo,pool,solver,"pattern:devel_qt4")
	);
	#endif

	solver_solve (solver, &queue);
	
	if (solver->problems.count) {
		#if SATSOLVER_VERSION_MINOR >= 14
		solver_printallsolutions(solver);
		#else
		solver_printsolutions(solver, &queue);
		#endif
	}

	unsigned long size = solver_calc_installsizechange (solver);
	printf ("REQUIRED SIZE: %ldkB\n",size);

	size = 0;
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
		unsigned int bytes = solvable_lookup_num(s, SOLVABLE_INSTALLSIZE, 0);
		const char* ver = solvable_lookup_str(s,SOLVABLE_EVR);
		const char* arc = solvable_lookup_str(s,SOLVABLE_ARCH);
		size += bytes;
		printf ("SOLVER NAME: %s %ukB %s %s\n", id2str(pool, s->name),bytes,ver,arc);
	}	
	printf ("REQUIRED SIZE: %ldkB\n",size);
	return 0;
}



Id select_solvable (Repo *repo, Pool* pool,Solver* solver,char *name) {
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
	prune_best_arch_name_version (solver,pool,&plist);
	if (plist.count == 0) {
		printf("unknown package '%s'\n", name);
		exit(1);
	}
	id = plist.elements[0];
	queue_free(&plist);
	return id;
}
