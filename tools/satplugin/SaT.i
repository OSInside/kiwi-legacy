//=======================================
// Interface definition for libsatsolver
//---------------------------------------
%module "KIWI::SaT"
%{
extern "C"
{
#include "policy.h"
#include "bitmap.h"
#include "evr.h"
#include "hash.h"
#include "poolarch.h"
#include "pool.h"
#include "poolid.h"
#include "pooltypes.h"
#include "queue.h"
#include "solvable.h"
#include "solverdebug.h"
#include "solver.h"
#include "repo.h"
#include "repo_solv.h"
}
#include <sstream>
#include <sys/utsname.h>
%}

//==================================
// Typemap: Allow FILE* as PerlIO
//----------------------------------
#if defined(SWIGPERL)
%typemap(in) FILE* {
    $1 = PerlIO_findFILE(IoIFP(sv_2io($input)));
}
#endif

//==================================
// Extends
//----------------------------------
%include "bitmap.h"
%include "evr.h"
%include "hash.h"
%include "poolarch.h"
%include "poolid.h"
%include "pooltypes.h"
%include "pool.h"
%include "queue.h"
%include "solverdebug.h"
%include "solvable.h"
%include "solver.h"
%include "repo.h"
%include "repo_solv.h"
//==================================
// Extend _Pool struct
//----------------------------------
%extend _Pool {
    _Pool() {
        struct utsname hw;
        Pool *pool = pool_create();
        uname (&hw);
        pool_setarch(pool,hw.machine);
        return pool;
    }

    ~_Pool() {
        pool_free (self);
    }

    int installable (Solvable *s) {
        return pool_installable(self,s);
    }

    void createWhatProvides() {
        pool_createwhatprovides(self);
    }

    void initializeLookupTable (Repo *installed = 0) {
        #ifdef SOLV_VERSION_8
        pool_set_installed (self, installed);
        pool_addfileprovides (self);
        #endif
        pool_createwhatprovides (self);
    }

    Solvable *id2solvable(Id p) {
        return pool_id2solvable(self, p);
    }

    Id selectSolvable (Repo *repo, Solver *solver, char *name) {
        Id id;
        Queue plist;
        int i, end;
        Solvable *s;
        Pool* pool;
        pool = self;
        id = str2id(pool, name, 1);
        queue_init( &plist);
        i = repo ? repo->start : 1;
        end = repo ? repo->start + repo->nsolvables : pool->nsolvables;
        for (; i < end; i++) {
            s = pool->solvables + i;
            if (!pool_installable(pool, s)) {
                continue;
            }
            if (s->name == id) {
                queue_push(&plist, i);
            }
        }
        prune_best_arch_name_version (solver,pool,&plist);
        if (plist.count == 0) {
            //printf("unknown package '%s'\n", name);
            return 0;
        }
        id = plist.elements[0];
        queue_free(&plist);
        return id;
    }

    Repo* createRepo(const char *reponame) {
        return repo_create(self, reponame);
    }
};
%newobject pool_create;
%delobject pool_free;

//==================================
// Extend Queue struct
//----------------------------------
%extend Queue {
    Queue() {
        Queue *q = new Queue();
        queue_init(q);
        return q;
    }

    ~Queue() {
        queue_free(self);
    }

    Id shift() {
        return queue_shift(self);
    }
  
    bool queuePush (Id id) {
        if (id >= 0) {
            queue_push(self, id);
            return 1;
        } else {
            return 0;
        }
    }

    bool isEmpty() {
        return (self->count == 0);
    }

    void clear() {
        queue_empty(self);
    }
};
%newobject queue_init;
%delobject queue_free;

//==================================
// Extend Solvable struct
//----------------------------------
%extend Solvable {
    Id id() {
        if (!self->repo) {
            return 0;
        }
        return self - self->repo->pool->solvables;
    }

    %ignore name;
    const char * name() {
        return id2str(self->repo->pool, self->name);
    }

    %rename("to_s") toString();
    const char * toString() {
        if ( self->repo == NULL ) {
            return "<unknown>";
        }
        return solvable2str(self->repo->pool, self);
    }
}

//==================================
// Extend Solver struct
//----------------------------------
%extend Solver {
    Solver ( Pool *pool, Repo *installed = 0 ) {
        #ifdef SOLV_VERSION_8
        return solver_create(pool);
        #else
        return solver_create(pool, installed);
        #endif
    }

    ~Solver() { solver_free(self); }

    void solve (Queue *job) {
        solver_solve(self, job);
    }

    unsigned long getInstallSizeKBytes (void) {
        return solver_calc_installsizechange (self);
    }

    SV* getInstallList (Pool *pool) {
        int b = 0;
        SV *result = 0;
        int len = self->decisionq.count;
        HV *hash = newHV();
        SV **svs = (SV**) malloc(len*sizeof(SV*));

        for (b = 0; b < len; b++) {
            Id p = self->decisionq.elements[b];
            if (p < 0) {
                continue; // ignore conflict
            }
            if (p == SYSTEMSOLVABLE) {
                continue; // ignore system solvable
            }
            Solvable *s = self->pool->solvables + p;
            int t;
            char ct[50] = "unknown";
            // lookup package install size
            unsigned int bytes=solvable_lookup_num(s, SOLVABLE_INSTALLSIZE, 0);
            // lookup package version
            const char* vers = solvable_lookup_str(s,SOLVABLE_EVR);
            // lookup package architecture
            const char* arch = solvable_lookup_str(s,SOLVABLE_ARCH);
            // lockup package name
            const char* myel = (char*)id2str(pool, s->name);
            // lockup package checksum
            const char* chs = solvable_lookup_checksum(s,SOLVABLE_CHECKSUM,&t);
            if (t == REPOKEY_TYPE_SHA256) {
                sprintf (ct,"sha256");
            } else if (t == REPOKEY_TYPE_SHA1) {
                sprintf (ct,"sha1");
            } else if (t == REPOKEY_TYPE_MD5) {
                sprintf (ct,"md5");
            }
            // lookup repo name
            const char* rname = repo_name(s->repo);
            // store data into perl hash
            int l = sizeof (char) * 
                (strlen(vers)+1+strlen(arch)+strlen(chs)+strlen(rname)+1+20);
            char* val = (char*)malloc (l);
            memset (val,'\0',l);
            sprintf (val,"%u:%s:%s:%s=%s:%s",bytes,arch,vers,ct,chs,rname);
            svs[b] = sv_newmortal();
            hv_store(hash,
                myel,strlen(myel),
                newSVpv(val,strlen(val)),0
            );
        }
        free (svs);
        result = newRV((SV*)hash);
        sv_2mortal (result);
        return result;
    }

    int getProblemsCount (void) {
        Solver* solv = self;
        return solv->problems.count;
    }

    char* getSolutions (Queue *job) {
        Solver* solv = self;
        char name[]  = "/tmp/sat-XXXXXX";
        char* result = (char*)malloc(strlen(name));
        memset (result,'\0',strlen(name));
        int origout;
        int status = mkstemp (name);
        if (status == -1) {
            return result;
        }
        origout = dup2 (1,origout);
        FILE* fp = freopen(name,"w",stdout);
        %#if SATSOLVER_VERSION_MINOR >= 14
        solver_printallsolutions(solv);
        %#else
        solver_printsolutions(solv, job);
        %#endif
        fclose (fp);
        dup2 (origout,1);
        strcpy (result,name);   
        return result;
    }
};

//==================================
// Extend Repo struct
//----------------------------------
%nodefaultdtor Repo;
%extend Repo {
    Solvable *add_solvable() {
        return pool_id2solvable(self->pool, repo_add_solvable(self));
    }

    void addSolvable (FILE *fp) {
        repo_add_solv(self, fp);
    }
};

//==================================
// Typemap: Allow Id struct as input
//----------------------------------
%typemap(in) Id {
    $1 = (int) NUM2INT($input);
    printf("Received an integer : %d\n",$1);
}   
